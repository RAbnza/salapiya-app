import '../local/finance_domain.dart';
import '../p0/exact_money.dart';

/// Display-only derivations for Import (DESIGN_SYSTEM §8, Chat 9). They read
/// the records an import leaves behind and change nothing.

/// Where an import stands.
enum ImportStatus {
  saving('Saving rows'),
  ready('Ready to review'),
  confirmed('Confirmed'),
  importing('Importing'),
  done('Done'),
  stopped('Stopped');

  const ImportStatus(this.label);
  final String label;
}

/// How the rule files' stored row notes read. The words are kept in records
/// and written by the server too, so they stay as they are and only the
/// screen changes them.
const importRowNotes = {
  'Date must follow the confirmed opening cutoff.':
      'Dated on or before this account’s starting balance.',
  'Future cash history is unsupported.':
      'Dated after today. Only past activity can be imported.',
  'Mapping or row values are invalid.':
      'Something in this row can’t be read. Check its columns.',
  'Matching cash activity': 'Looks like something already logged',
  'Matching reference': 'Same reference as another record',
  'Identical file checksum': 'This file was imported before',
};

String importRowNote(Object? stored) => importRowNotes['$stored'] ?? '$stored';

/// The title imports had before they kept their file's name.
const _oldImportTitle = 'Reviewed pmp-cash-activity version-1 CSV';

/// One row of a file, as the review shows it.
class ImportRow {
  ImportRow(this.index, this.values);

  /// From 0, as the rule files count them.
  final int index;
  final Map<String, dynamic> values;

  int get number => index + 1;
  String? get date => values['date'] as String?;
  String get name => (values['name'] as String?) ?? 'A row that can’t be read';
  String get reference => (values['reference'] as String?) ?? '';
  bool get income => values['kind'] == 'income';
  List<String> get problems => [
    for (final e in values['errors'] as List) importRowNote(e),
  ];
  List<String> get warnings => [
    for (final e in values['warnings'] as List) importRowNote(e),
  ];
  bool get hasProblem => problems.isNotEmpty;
  bool get hasWarning => warnings.isNotEmpty;
  bool get needsLook => hasProblem || hasWarning;

  /// Money in is above zero, money out below it. Null when it can't be read.
  BigInt? get amount {
    final minor = values['amountMinor'] as String?;
    if (minor == null) return null;
    return income ? parseMinor(minor) : -parseMinor(minor);
  }
}

/// One import and how far it got: its file, the newest review of it, the
/// choices confirmed on that review, and what's been imported.
class ImportBatch {
  ImportBatch({
    required this.head,
    required this.preview,
    required this.decision,
    required this.imported,
    required this.stopped,
    required this.stale,
    required this.rebasePending,
  });
  final LocalRevision head;
  final LocalRevision? preview, decision;
  final Set<int> imported;
  final bool stopped;

  /// The account changed after the review, before any row went in.
  final bool stale;

  /// The starting balance still has to move, which happens with the first
  /// rows imported.
  final bool rebasePending;

  String get id => head.id;
  String get date => head.date;
  String get name =>
      head.title == _oldImportTitle ? 'Cash activity file' : head.title;
  String get checksum => head.values['checksum'] ?? '';
  String get account => cashImportAssumptions(head)['account'] as String;
  int get rowCount => int.parse(head.values['rowCount']!);
  List<ImportRow> get rows => preview == null
      ? const []
      : [
          for (final (i, r) in cashImportRows(preview!).indexed)
            ImportRow(i, r),
        ];
  int get needsLook => rows.where((r) => r.needsLook).length;

  /// Rows confirmed to go in.
  List<int> get selected =>
      decision == null ? const [] : selectedCashImportRows(decision!);
  int get leftOut => decision == null ? 0 : rowCount - selected.length;
  int get importedCount => imported.length;
  bool get finished =>
      decision != null && !rebasePending && selected.every(imported.contains);

  ImportStatus get status => stopped
      ? ImportStatus.stopped
      : preview == null
      ? ImportStatus.saving
      : decision == null
      ? ImportStatus.ready
      : finished
      ? ImportStatus.done
      : imported.isEmpty
      ? ImportStatus.confirmed
      : ImportStatus.importing;

  bool get open =>
      status != ImportStatus.done && status != ImportStatus.stopped;

  /// A row's result, as the import's page shows it.
  String result(ImportRow r) => imported.contains(r.index)
      ? 'Imported'
      : decision == null
      ? r.needsLook
            ? 'Needs a look'
            : 'Not confirmed yet'
      : !selected.contains(r.index)
      ? 'Left out'
      : stopped
      ? 'Stopped'
      : 'Waiting';
}

/// Every import, newest first.
List<ImportBatch> importBatches(LocalSnapshot s) {
  final ids = s.revisions.map((r) => r.id).toSet();
  final batches = <ImportBatch>[];
  for (final head in s.current.where((r) => financeType(r) == 'cashImport')) {
    final preview = s.current
        .where(
          (r) =>
              financeType(r) == 'cashImportPreview' &&
              r.values['batch'] == head.id,
        )
        .lastOrNull;
    final decision = preview == null
        ? null
        : s.current
              .where(
                (r) =>
                    financeType(r) == 'cashImportDecision' &&
                    r.values['preview'] == preview.id,
              )
              .lastOrNull;
    final imported = <int>{
      if (preview != null)
        for (final (i, row) in cashImportRows(preview).indexed)
          if (ids.contains(row['rowCommand'])) i,
    };
    final assumptions = cashImportAssumptions(head);
    final account = assumptions['account'] as String;
    batches.add(
      ImportBatch(
        head: head,
        preview: preview,
        decision: decision,
        imported: imported,
        stopped:
            decision != null &&
            s.current.any(
              (r) =>
                  financeType(r) == 'cashImportCancel' &&
                  r.values['decision'] == decision.id,
            ),
        stale:
            preview != null &&
            imported.isEmpty &&
            preview.values['sourceStamp'] != cashImportSourceStamp(s, account),
        rebasePending:
            assumptions['cutoffStrategy'] == 'rebase_history' &&
            !ids.contains(importStableId(s.owner, head.id, 'rebase')),
      ),
    );
  }
  return batches..sort((a, b) => b.date.compareTo(a.date));
}

/// Whether importing [chosen] rows would take the account below zero on any
/// date, at any point along the way. The rule checks each group of rows as it
/// goes in, so this does too: consent has to be given before the choices are
/// confirmed, and can't be added after.
bool importGoesBelowZero(
  LocalSnapshot s,
  LocalRevision head,
  LocalRevision preview,
  List<int> chosen,
) {
  final a = cashImportAssumptions(head), rows = cashImportRows(preview);
  final account = a['account'] as String;
  final rebase = a['cutoffStrategy'] == 'rebase_history';
  BigInt signed(int i) =>
      (rows[i]['kind'] == 'income' ? BigInt.one : -BigInt.one) *
      parseMinor(rows[i]['amountMinor'] as String);
  final cutoff = preview.values['cutoff']!;
  final earlier = [
    if (rebase)
      for (final i in chosen)
        if ((rows[i]['date'] as String).compareTo(cutoff) <= 0) i,
  ];
  final rest = [
    for (final i in chosen)
      if (!earlier.contains(i)) i,
  ];
  final groups = <List<int>>[
    if (rebase) earlier,
    for (var at = 0; at < rest.length; at += 50)
      rest.sublist(at, (at + 50).clamp(0, rest.length)),
  ];
  // What moves the balance on each date, before any row goes in.
  final moves = <String, BigInt>{};
  void move(String on, BigInt by) =>
      moves[on] = (moves[on] ?? BigInt.zero) + by;
  for (final p in s.current.expand((r) => r.postings)) {
    if (p.account == account) move(p.date, p.amount);
  }
  if (rebase) {
    move(cutoff, -parseMinor(preview.values['openingMinor']!));
    move(a['earlierDate'] as String, parseMinor(a['earlierMinor'] as String));
  }
  for (final group in groups) {
    for (final i in group) {
      move(rows[i]['date'] as String, signed(i));
    }
    var balance = BigInt.zero;
    for (final on in moves.keys.toList()..sort()) {
      balance += moves[on]!;
      if (balance < BigInt.zero) return true;
    }
  }
  return false;
}
