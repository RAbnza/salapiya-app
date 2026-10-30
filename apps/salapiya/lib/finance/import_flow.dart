import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../local/finance_domain.dart';
import '../local/local_finance_controller.dart';
import '../p0/exact_money.dart';
import 'bounded_file_read.dart';
import 'import_data.dart';

/// Rules that name no field, and the field each is about. A test holds these
/// to the rules' own words.
const importRuleFields = [
  ('Match all six columns', 'mapping:date'),
  ('A date doesn’t match the date format', 'dateInterpretation'),
  ('Enter a date before this account’s start', 'earlierDate'),
  ('The earlier balance plus the rows', 'earlierAmount'),
  ('Choose an active cash account', 'account'),
];

const _couldntFinish =
    'The import couldn’t finish. What you chose is kept, and rows already imported stay in your records.';

/// The same retained id and values on every try, so a lost response never
/// sends a row twice.
Future<void> submitCashImport(
  LocalFinancialController c,
  String kind,
  Map<String, String> values,
  String id,
  Future<void> Function()? synchronize,
) async {
  final old = await c.store.db.getAll(
    'SELECT payload FROM local_command WHERE id=? UNION ALL SELECT payload FROM connected_intent WHERE id=?',
    [id, id],
  );
  final command = old.isEmpty
      ? LocalCommand(
          id: id,
          owner: c.store.owner,
          expectedVersion: c.snapshot.version,
          kind: kind,
          values: values,
        )
      : LocalCommand.decode(id, old.first['payload'] as String);
  if (command.kind != kind ||
      command.values.length != values.length ||
      values.entries.any((e) => command.values[e.key] != e.value)) {
    reject(
      'This step was already sent with other details. Start a new import.',
    );
  }
  await c.store.commit(command);
  await c.reload();
  if (c.connected) {
    if (synchronize == null) {
      reject('Reconnect to finish this import. What you chose is kept.');
    }
    await synchronize();
    await c.reload();
  }
  if ((await c.store.db.getAll('SELECT id FROM local_command WHERE id=?', [
    id,
  ])).isEmpty) {
    final state = await c.store.db.getAll(
      'SELECT state,reason FROM connected_intent WHERE id=?',
      [id],
    );
    reject(
      state.firstOrNull?['state'] == 'review'
          ? 'This import wasn’t accepted: ${state.first['reason']}. What you chose is kept.'
          : 'This is saved on this device and waiting to sync.',
    );
  }
}

/// An import under way: its protected draft and the commands that move it on,
/// one step at a time. Every id is kept in the draft before it's sent, so a
/// step that stopped halfway picks up where it was.
class ImportFlow extends ChangeNotifier {
  ImportFlow(this.c, this.synchronize);
  final LocalFinancialController c;
  final Future<void> Function()? synchronize;

  static const operation = 'cash-import:review';

  Map<String, String> draft = {};
  String draftId = newLocalId();
  bool busy = false, loading = true, stopping = false;
  String? error, message;

  /// The field [error] is about, when it's about one.
  String? errorField;

  /// Rows saved or imported so far in the step that's running.
  int done = 0;

  LocalRevision? get head => c.snapshot.current
      .where((r) => r.id == draft['batch'] && financeType(r) == 'cashImport')
      .firstOrNull;
  LocalRevision? get preview => c.snapshot.current
      .where(
        (r) =>
            r.id == draft['preview'] && financeType(r) == 'cashImportPreview',
      )
      .firstOrNull;
  LocalRevision? get decision => c.snapshot.current
      .where(
        (r) =>
            r.id == draft['decision'] && financeType(r) == 'cashImportDecision',
      )
      .firstOrNull;

  /// How this import stands in the records, once its file is saved there.
  ImportBatch? get batch =>
      importBatches(c.snapshot)
          .where((b) => b.id == draft['batch'])
          .firstOrNull;

  int get rowCount => int.tryParse(draft['rowCount'] ?? '') ?? 0;
  List<String> get header => draft['header'] == null
      ? const []
      : (jsonDecode(draft['header']!) as List).cast<String>();

  Future<void> restore() async {
    try {
      final saved = await c.store.draft(operation);
      if (saved != null) {
        draft = Map<String, String>.from(saved['values'] as Map);
        draftId = saved['command'] as String;
        if (preview != null) {
          _defaultChoices(cashImportRows(preview!));
          await persist();
        }
      }
    } catch (_) {
      error = 'Your saved import couldn’t be read. Reopen your profile.';
    }
    loading = false;
    notifyListeners();
  }

  void _defaultChoices(List<Map<String, dynamic>> rows) {
    draft.removeWhere((key, _) => key.startsWith('raw'));
    for (var i = 0; i < rows.length; i++) {
      draft.putIfAbsent('choice$i', () => _firstChoice(rows[i]));
    }
  }

  String _firstChoice(Map<String, dynamic> row) => jsonEncode({
    'include': (row['errors'] as List).isEmpty,
    'acknowledgeDuplicates': false,
    'category': row['kind'] == 'income' ? 'category-income' : 'category-food',
  });

  Future<void> writes = Future.value();
  Future<void> persist() {
    final captured = Map<String, String>.from(draft), id = draftId;
    writes = writes
        .catchError((Object _) {})
        .then((_) => c.store.saveDraft(operation, id, captured));
    return writes;
  }

  /// What's typed on Match columns, saved as it changes.
  void change(String key, String value) {
    draft[key] = value;
    unawaited(
      persist().catchError((Object _) {
        error =
            'This couldn’t be saved. Keep this page open and check storage.';
        notifyListeners();
      }),
    );
    notifyListeners();
  }

  /// Runs a step, keeping what went wrong on its field or the page.
  Future<void> run(Future<void> Function() action) async {
    busy = true;
    error = errorField = message = null;
    notifyListeners();
    try {
      await action();
    } on LocalRuleException catch (e) {
      error = e.message;
      errorField = e.field;
      for (final (text, field) in importRuleFields) {
        if (e.message.contains(text)) errorField ??= field;
      }
    } on FormatException catch (e) {
      error = e.message;
    } catch (_) {
      error = _couldntFinish;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Picks a file and starts a fresh draft from it. False when none was
  /// chosen.
  Future<bool> pick() async {
    if (draft['process'] != null) {
      reject(
        'An import step is still waiting for its result. Continue the import first.',
      );
    }
    final file = await FilePicker.pickFile();
    if (file == null) return false;
    final length = await file.length();
    if (length == null || length > 1024 * 1024) {
      reject('Choose a CSV file saved as UTF-8, up to 1 MB.');
    }
    final bytes = await readBoundedFinancialFile(file, 1024 * 1024);
    start(file.name, bytes);
    await persist();
    return true;
  }

  /// A new draft from a chosen file's name and contents.
  void start(String name, List<int> bytes) {
    final rows = parseCashCsv(bytes);
    draftId = newLocalId();
    draft = {
      'batch': newLocalId(),
      'preview': newLocalId(),
      'decision': newLocalId(),
      'headDate': civilToday(),
      'fileName': name.length > 200 ? name.substring(0, 200) : name,
      'checksum': sha256.convert(bytes).toString(),
      'header': jsonEncode(rows.first),
      'rowCount': '${rows.length - 1}',
      'account':
          c.snapshot.accounts.where((a) => !a.archived).firstOrNull?.id ?? '',
      'dateInterpretation': 'YYYY-MM-DD',
      'cutoffStrategy': 'after_opening',
      'earlierDate': '',
      'earlierAmount': '0.00',
      for (final e in const {
        'date': 'date',
        'kind': 'kind',
        'amountMinor': 'amount_minor',
        'classification': 'classification',
        'description': 'description',
        'reference': 'reference',
      }.entries)
        'mapping:${e.key}': rows.first.contains(e.value) ? e.value : '',
      for (var i = 1; i < rows.length; i++) 'raw${i - 1}': jsonEncode(rows[i]),
    };
    error = errorField = message = null;
  }

  Map<String, String> headValues() {
    final assumptions = {
      'sourceFormat': 'pmp-cash-activity',
      'formatVersion': 1,
      'currency': 'PHP',
      'account': draft['account'],
      'mapping': {
        for (final key in [
          'date',
          'kind',
          'amountMinor',
          'classification',
          'description',
          'reference',
        ])
          key: draft['mapping:$key'],
      },
      'dateInterpretation': draft['dateInterpretation'],
      'cutoffStrategy': draft['cutoffStrategy'],
      'earlierDate': draft['cutoffStrategy'] == 'rebase_history'
          ? draft['earlierDate']
          : null,
      'earlierMinor': draft['cutoffStrategy'] == 'rebase_history'
          ? '${parsePhp(draft['earlierAmount'] ?? '')}'
          : null,
    };
    return {
      'name': draft['fileName'] ?? 'Cash activity file',
      'date': draft['headDate']!,
      'header': draft['header']!,
      'rowCount': draft['rowCount']!,
      'checksum': draft['checksum']!,
      'assumptions': jsonEncode(assumptions),
    };
  }

  /// Saves the file's rows and asks for the review.
  Future<void> stage() async {
    await persist();
    if (head == null) {
      await submitCashImport(
        c,
        'cashImport',
        headValues(),
        draft['batch']!,
        synchronize,
      );
    }
    final count = int.parse(draft['rowCount']!);
    for (var offset = 0; offset < count; offset += 16) {
      final size = (count - offset).clamp(0, 16);
      final id = importStableId(
        c.store.owner,
        draft['batch']!,
        'stage/$offset',
      );
      final existing = c.snapshot.revisions.any((r) => r.id == id);
      if (!existing) {
        await submitCashImport(
          c,
          'cashImportChunk',
          {
            'name': 'Original CSV staging rows',
            'date': draft['headDate']!,
            'batch': draft['batch']!,
            'offset': '$offset',
            'rowCount': '$size',
            for (var i = 0; i < size; i++)
              'row$i':
                  draft['raw${offset + i}'] ??
                  reject(
                    'Some rows are missing from this saved import. Choose the file again.',
                  ),
          },
          id,
          synchronize,
        );
      }
      done = offset + size;
      notifyListeners();
    }
    final existing = await c.store.db.getAll(
      'SELECT payload FROM local_command WHERE id=? UNION ALL SELECT payload FROM connected_intent WHERE id=?',
      [draft['preview'], draft['preview']],
    );
    final values = existing.isEmpty
        ? {
            'name': 'Immutable cash CSV preview',
            'date': civilToday(),
            'batch': draft['batch']!,
          }
        : LocalCommand.decode(
            draft['preview']!,
            existing.first['payload'] as String,
          ).values;
    await submitCashImport(
      c,
      'cashImportPreview',
      values,
      draft['preview']!,
      synchronize,
    );
    _defaultChoices(cashImportRows(preview!));
    await persist();
  }

  Map<String, dynamic> choice(int i) =>
      Map<String, dynamic>.from(jsonDecode(draft['choice$i']!) as Map);

  Future<void> updateChoice(int i, String key, Object value) async {
    final updated = choice(i)..[key] = value;
    draft['choice$i'] = jsonEncode(updated);
    notifyListeners();
    await persist();
  }

  /// Rows the user has chosen to include so far.
  List<int> get chosen {
    final total = preview == null ? 0 : cashImportRows(preview!).length;
    return [
      for (var i = 0; i < total; i++)
        if (choice(i)['include'] == true) i,
    ];
  }

  /// Rows included with a possible duplicate nobody has confirmed.
  List<int> get unconfirmed {
    final rows = cashImportRows(preview!);
    return [
      for (final i in chosen)
        if ((rows[i]['warnings'] as List).isNotEmpty &&
            choice(i)['acknowledgeDuplicates'] != true)
          i,
    ];
  }

  /// Whether these choices need consent to go below zero. Rows that can't go
  /// in don't count: the rule refuses them first.
  bool get needsConsent {
    final rows = cashImportRows(preview!);
    final valid = [
      for (final i in chosen)
        if ((rows[i]['errors'] as List).isEmpty) i,
    ];
    return importGoesBelowZero(c.snapshot, head!, preview!, valid);
  }

  /// Confirms every row's choice. Nothing is in the records yet.
  Future<void> confirm() async {
    final rows = cashImportRows(preview!);
    draft.putIfAbsent('decisionDate', civilToday);
    await persist();
    await submitCashImport(
      c,
      'cashImportDecision',
      {
        'name': 'Reviewed CSV row decisions',
        'date': draft['decisionDate']!,
        'preview': preview!.id,
        'rowCount': '${rows.length}',
        'acknowledge': draft['acknowledge'] ?? 'false',
        for (var i = 0; i < rows.length; i++) 'row$i': draft['choice$i']!,
      },
      draft['decision']!,
      synchronize,
    );
    await persist();
  }

  /// Picks an earlier import back up, with its original row ids.
  Future<void> resume(LocalRevision batch) async {
    if (draft['process'] != null) {
      reject(
        'An import step is still waiting for its result. Continue the import first.',
      );
    }
    final previous = c.snapshot.current
        .where(
          (r) =>
              financeType(r) == 'cashImportPreview' &&
              r.values['batch'] == batch.id,
        )
        .lastOrNull;
    if (previous == null) {
      reject(
        'This import wasn’t fully saved. Choose the file again to start over.',
      );
    }
    final frozen = c.snapshot.current
        .where(
          (r) =>
              financeType(r) == 'cashImportDecision' &&
              r.values['preview'] == previous.id,
        )
        .lastOrNull;
    final assumptions = cashImportAssumptions(batch),
        mapping = assumptions['mapping'] as Map;
    draftId = newLocalId();
    draft = {
      'batch': batch.id,
      'preview': previous.id,
      'decision': frozen?.id ?? newLocalId(),
      'headDate': batch.date,
      'fileName': batch.title,
      'header': batch.values['header']!,
      'checksum': batch.values['checksum']!,
      'rowCount': batch.values['rowCount']!,
      'account': assumptions['account'] as String,
      'dateInterpretation': assumptions['dateInterpretation'] as String,
      'cutoffStrategy': assumptions['cutoffStrategy'] as String,
      'earlierDate': assumptions['earlierDate'] as String? ?? '',
      'earlierAmount': assumptions['earlierMinor'] == null
          ? '0.00'
          : phpDecimal(parseMinor(assumptions['earlierMinor'] as String)),
      'acknowledge': frozen?.values['acknowledge'] ?? 'false',
      for (final e in mapping.entries) 'mapping:${e.key}': e.value as String,
    };
    final rows = cashImportRows(previous);
    for (var i = 0; i < rows.length; i++) {
      draft['choice$i'] = frozen?.values['row$i'] ?? _firstChoice(rows[i]);
    }
    await persist();
  }

  /// Checks the rows again after the account changed.
  Future<void> refresh() async {
    if (draft['process'] != null) {
      reject(
        'An import step is still waiting for its result. Continue the import first.',
      );
    }
    if (decision != null &&
        selectedCashImportRows(decision!).any(
          (i) => c.snapshot.revisions.any(
            (r) => r.id == cashImportRows(preview!)[i]['rowCommand'],
          ),
        )) {
      reject(
        'Some rows are already imported. Continue the import, or stop the remaining rows.',
      );
    }
    draft['preview'] = newLocalId();
    draft['decision'] = newLocalId();
    draft.remove('decisionDate');
    draft.removeWhere((k, _) => k.startsWith('choice'));
    await persist();
    await stage();
  }

  /// Rows left to send, including a step that didn't finish.
  bool get rowsLeft {
    final d = decision;
    if (d == null) return false;
    final b = batch;
    return draft['process'] != null ||
        nextCashImportRows(c.snapshot, d).isNotEmpty ||
        (b?.rebasePending ?? false);
  }

  /// Rows in the records so far.
  int get importedSoFar => batch?.importedCount ?? 0;

  /// One group of up to 50 rows. Its id and rows are saved first, so a lost
  /// response sends the same command again.
  Future<void> process() async {
    draft.putIfAbsent('process', newLocalId);
    draft.putIfAbsent('processDate', civilToday);
    draft.putIfAbsent(
      'processRows',
      () => jsonEncode(nextCashImportRows(c.snapshot, decision!)),
    );
    await persist();
    await submitCashImport(
      c,
      'cashImportProcess',
      {
        'name': 'Reviewed bounded cash-history import',
        'date': draft['processDate']!,
        'decision': decision!.id,
        'rowNumbers': draft['processRows']!,
      },
      draft['process']!,
      synchronize,
    );
    draft.remove('process');
    draft.remove('processDate');
    draft.remove('processRows');
    await persist();
  }

  /// Sends every group in turn, until none are left or Stop is asked for.
  /// When it's over, the draft goes too: the import's records say the rest.
  Future<void> importAll() async {
    stopping = false;
    while (rowsLeft && !stopping) {
      await process();
      notifyListeners();
    }
    if (stopping) {
      await stopRemaining();
    } else {
      await _finish();
    }
  }

  /// Keeps what's in, and stops the rest for good. A step still waiting for
  /// its result finishes first, so nothing is left unknown.
  Future<void> stopRemaining() async {
    if (draft['process'] != null) await process();
    draft.putIfAbsent('cancel', newLocalId);
    draft.putIfAbsent('cancelDate', civilToday);
    await persist();
    await submitCashImport(
      c,
      'cashImportCancel',
      {
        'name': 'Cancel future CSV chunks',
        'date': draft['cancelDate']!,
        'decision': decision!.id,
      },
      draft['cancel']!,
      synchronize,
    );
    stopping = false;
    await _finish();
  }

  Future<void> _finish() async {
    await writes.catchError((Object _) {});
    await c.store.discardDraft(operation);
    draft = {};
    draftId = newLocalId();
  }
}
