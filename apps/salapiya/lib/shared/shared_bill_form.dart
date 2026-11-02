import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../design_system/kit/review.dart' show FormExitGuard;
import '../finance/debt_cards.dart' show civilDay;
import '../finance/form_mechanics.dart';
import '../local/finance_domain.dart';
import 'shared_cards.dart';
import 'shared_data.dart';
import 'shared_domain.dart';
import 'shared_hub.dart';

/// What a group form does when its answer doesn't come back.
const lostResponseTitle = 'We couldn’t tell if this reached the group';
const lostResponseMessage =
    'What you entered is kept. Check again: it won’t be sent twice.';

/// How the group's forms end up. A queued form never says the group has it.
String savedLine(SharedSource source, {required bool queued}) => source.demo
    ? 'This is the demo, so nothing was saved.'
    : queued
    ? 'Saved. Waiting for the group.'
    : 'Saved. The group has it.';

/// The steps every group form shares: details, review, send. Values freeze
/// once a send's answer is lost, and "Check again" sends the same id, which
/// the server answers from its receipt. It is never a second command.
mixin SharedFormSteps<T extends StatefulWidget> on State<T>, FormInputs<T> {
  SharedHub get hub;
  SharedGroup get group;

  /// `bill` and `report` queue offline; everything else needs a connection.
  bool get queued;
  String get id;
  set id(String next);
  String get op;

  /// The command's values. Throws a rule's refusal, on its field.
  SharedJson command();

  /// Checks the answers. Throws a rule's refusal, on its field.
  void check();
  Map<String, dynamic> get draftData;

  SharedSource get source => hub.source();
  SharedWriter get writer => source.writer;

  Future<void> writes = Future.value();
  bool busy = false, dirty = false, reviewing = false;
  bool saved = false, unknown = false, draftFailed = false, stale = false;
  String? error;

  @override
  void retain() {
    setState(() => dirty = true);
    final frozen = Map<String, String>.from(values), command = id;
    final payload = {...draftData, 'fields': frozen};
    final group = this.group.id;
    writes = writes
        .then((_) => writer.draft(command, group, payload))
        .then((_) {
          if (mounted) setState(() => draftFailed = false);
        })
        .catchError((Object _) {
          if (mounted) {
            setState(() {
              draftFailed = true;
              error = 'Your draft could not be saved. Check storage before leaving.';
            });
          }
        });
  }

  /// Moves on from details, or sends what was reviewed.
  Future<void> advance() async {
    String? problem, problemField;
    setState(() {
      busy = true;
      error = null;
      errorField = errorMessage = null;
      stale = false;
    });
    try {
      await writes;
      if (draftFailed) reject('Your draft needs saving before you continue.');
      if (!reviewing) {
        check();
        command();
        reviewing = true;
      } else {
        await send();
      }
    } on LocalRuleException catch (e) {
      problem = sharedReason(e.message);
      problemField = e.field;
      // A refused id can't be used again: the server would repeat its answer.
      if (reviewing && !queued) id = newLocalId();
      if (reviewing && problemField != null) reviewing = false;
    } on FormatException {
      problem = 'Enter an amount like 1500.00.';
      problemField = 'total';
    } catch (_) {
      unknown = reviewing;
      if (!unknown) error = 'That didn’t work. What you entered is kept.';
    }
    if (mounted) {
      setState(() {
        busy = false;
        errorField = problemField;
        errorMessage = problem;
      });
    }
    if (problem != null && mounted) await showProblem(problem, problemField);
  }

  Future<void> send() async {
    final latest = source.group(group.id);
    // The server refuses a stale version outright, and a refused command
    // stays on record, so stop here and let the user look again.
    if (!queued && latest != null && latest.version != group.version) {
      stale = true;
      return;
    }
    await writer.submit(
      group.id,
      op,
      command(),
      version: group.version,
      id: id,
    );
    saved = true;
  }

  /// Asks about the same command. It stays frozen until there's an answer.
  Future<void> checkAgain() async {
    setState(() {
      busy = true;
      errorMessage = null;
    });
    try {
      await writer.retry(id);
      saved = true;
      unknown = false;
    } on LocalRuleException catch (e) {
      errorMessage = sharedReason(e.message);
      // The rule that needs a connection isn't an answer about the command.
      if (writer.online) {
        unknown = false;
        reviewing = false;
        id = newLocalId();
      }
    } catch (_) {
      // Still no answer: keep waiting.
    }
    if (mounted) setState(() => busy = false);
  }

  /// The form's last lines: what happened, what's wrong, and the buttons.
  Widget stepActions(String reviewLabel) => actions(
    unknown
        ? FilledButton(
            key: const ValueKey('shared-check-again'),
            onPressed: busy ? null : checkAgain,
            child: const Text('Check again'),
          )
        : FilledButton(
            key: const ValueKey('shared-submit'),
            onPressed: busy || draftFailed || !offlineReady ? null : advance,
            child: Text(
              busy
                  ? 'Saving…'
                  : !reviewing
                  ? 'Review'
                  : reviewLabel,
            ),
          ),
    !reviewing || unknown
        ? null
        : TextButton(
            onPressed: busy ? null : () => setState(() => reviewing = false),
            child: const Text('Edit'),
          ),
  );

  /// Queued forms work offline; the others say so before Save.
  bool get offlineReady => !reviewing || queued || source.online;

  List<Widget> reviewNotices() {
    final gap = SizedBox(height: CompactForm.fieldGap(context));
    return [
      if (stale) ...[
        gap,
        const InlineNotice(
          'The group changed while you were working. Close this and check it, then try again.',
          title: 'This group changed',
          tone: NoticeTone.warning,
          live: true,
        ),
      ],
      if (reviewing && !queued && !source.online) ...[
        gap,
        const InlineNotice(
          'This needs a connection. What you entered is kept.',
          tone: NoticeTone.warning,
        ),
      ] else if (reviewing && queued && !source.online) ...[
        gap,
        const InlineNotice(
          'You’re offline. This waits here and reaches the group when you reconnect.',
        ),
      ],
      if (unknown) ...[
        gap,
        const InlineNotice(
          lostResponseMessage,
          title: lostResponseTitle,
          tone: NoticeTone.warning,
          live: true,
        ),
      ],
    ];
  }

  Widget errorNotices() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (error != null) ...[
        InlineNotice(error!, tone: NoticeTone.error, live: true),
        SizedBox(height: CompactForm.fieldGap(context)),
      ],
      if (errorMessage != null && !anchors.containsKey(errorField)) ...[
        InlineNotice(errorMessage!, tone: NoticeTone.error, live: true),
        SizedBox(height: CompactForm.fieldGap(context)),
      ],
    ],
  );

  Widget savedPanel(String title) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InlineNotice(
        savedLine(source, queued: queued),
        title: title,
        tone: NoticeTone.success,
        live: true,
      ),
      SizedBox(height: CompactForm.groupGap(context)),
      actions(
        FilledButton(
          key: const ValueKey('shared-done'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ),
    ],
  );

  /// The page around a form.
  Widget framed(String title, Widget body, {bool keepDraft = true}) =>
      FormExitGuard(
        dirty: dirty && !saved,
        busy: busy || unknown,
        keepDraft: !keepDraft
            ? null
            : () async {
                await writes;
                if (draftFailed) throw StateError('Draft not saved');
              },
        child: CompactForm(
          child: SectionPage(
            title: title,
            caption: saved
                ? null
                : !reviewing
                ? 'Step 1 of 2 · Details · * Required'
                : 'Step 2 of 2 · Review',
            maxWidth: Space.formMaxWidth,
            child: SurfaceCard(child: body),
          ),
        ),
      );
}

/// A label that heads a group of fields.
class FormGroupLabel extends StatelessWidget {
  const FormGroupLabel(this.label, {super.key, this.action});
  final String label;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: CompactForm.groupGap(context)),
    // Wraps, so large text moves the link down rather than overflowing.
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.md,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        ?action,
      ],
    ),
  );
}

/// A running total under amount fields: exact, and what's left to enter.
class FormRunningTotal extends StatelessWidget {
  const FormRunningTotal({
    super.key,
    required this.label,
    required this.sum,
    required this.total,
    required this.amount,
  });
  final String label;
  final BigInt sum;
  final BigInt? total;
  final String Function(BigInt) amount;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final left = total == null ? null : total! - sum;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Semantics(
        liveRegion: true,
        child: Text(
          left == null
              ? '$label ${amount(sum)}'
              : left == BigInt.zero
              ? '$label ${amount(sum)} · matches the total'
              : left > BigInt.zero
              ? '$label ${amount(sum)} · ${amount(left)} left to assign'
              : '$label ${amount(sum)} · ${amount(-left)} over the total',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: left == null || left == BigInt.zero
                ? c.secondary
                : c.tone(NoticeTone.warning).$1,
          ),
        ),
      ),
    );
  }
}

/// A person who can be ticked in or out, with what follows at the end.
class PersonCheck extends StatelessWidget {
  const PersonCheck({
    super.key,
    required this.name,
    required this.value,
    required this.onChanged,
    this.trailing,
  });
  final String name;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: hitTarget(context)),
        child: Padding(
          // Two-line results need their own space between rows.
          padding: EdgeInsets.symmetric(
            vertical: trailing == null ? 0 : Space.xs,
          ),
          child: Row(
            children: [
              Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
              const SizedBox(width: Space.xs),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(!value),
                  child: Text(name, style: text.bodyMedium),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Space.md),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: trailing,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What a bill leaves one person with: paid minus their part, the same sum
/// `billPositions` does. [paid] is null until Who paid adds up, and then only
/// the part shows, because a figure from half-entered amounts would be wrong.
class BillResult extends StatelessWidget {
  const BillResult({
    super.key,
    required this.part,
    required this.paid,
    required this.amount,
  });
  final BigInt part;
  final BigInt? paid;
  final String Function(BigInt) amount;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final figures = text.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final paid = this.paid;
    if (paid == null) {
      return Text(
        'Part ${amount(part)}',
        textAlign: TextAlign.end,
        style: figures,
      );
    }
    final left = paid - part;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          left > BigInt.zero
              ? 'Gets back ${amount(left)}'
              : left < BigInt.zero
              ? 'Owes ${amount(-left)}'
              : 'Nothing owed',
          textAlign: TextAlign.end,
          style: figures?.copyWith(
            color: left > BigInt.zero ? c.owedToYou.$1 : c.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          detailLine(['Part ${amount(part)}', 'paid ${amount(paid)}']),
          textAlign: TextAlign.end,
          style: text.bodySmall?.copyWith(color: c.secondary),
        ),
      ],
    );
  }
}

/// A purchase already in Money, being shared. Its amount, date and payer are
/// settled, so only what the group needs is asked.
class SharedPurchase {
  const SharedPurchase({
    required this.id,
    required this.name,
    required this.date,
    required this.total,
  });
  final String id, name, date;
  final BigInt total;
}

/// Add shared expense and Correct shared expense. One person pays by default,
/// and the form asks who's in; a person's exact share shows as it's worked
/// out. It sends the same command the old form did: `paid` lists everyone,
/// zeros included.
class SharedBillForm extends StatefulWidget {
  const SharedBillForm({
    super.key,
    required this.hub,
    this.group,
    this.bill,
    this.draftId,
    this.purchase,
  });
  final SharedHub hub;

  /// Null when the form should ask which group.
  final SharedGroup? group;
  final SharedPurchase? purchase;

  /// The bill being corrected.
  final String? bill;
  final String? draftId;

  String get title => purchase != null
      ? 'Share your saved purchase'
      : bill == null
      ? 'Add shared expense'
      : 'Correct shared expense';
  @override
  State<SharedBillForm> createState() => _SharedBillFormState();
}

class _SharedBillFormState extends State<SharedBillForm>
    with FormInputs, SharedFormSteps {
  @override
  SharedHub get hub => widget.hub;
  @override
  late SharedGroup group = widget.group ?? currentGroups.first;
  @override
  late String id = widget.draftId ?? newLocalId();
  String? get bill => widget.bill;
  @override
  bool get queued => bill == null;
  @override
  String get op => bill == null ? 'bill' : 'correct';
  late bool loading = widget.draftId != null;

  /// Groups that can take a new bill, for the form opened from New.
  List<SharedGroup> get currentGroups => [
    for (final r in sharedGroupRows(hub.source()))
      if (r.current) r.group,
  ];

  SharedJson? get revision => bill == null ? null : group.revision(bill!);
  String? get me => group.participant(writer.actor ?? '');

  /// A correction may keep people who've since left; a new bill can't.
  List<MapEntry<String, dynamic>> get people => [
    for (final p in group.people.entries)
      if (bill != null || p.value['active'] == true) p,
  ];

  @override
  late final Map<String, String> values = startingValues();

  /// One person paid unless the bill or draft says otherwise.
  bool many = false;

  Map<String, String> startingValues() {
    final r = revision, shared = widget.purchase;
    final out = <String, String>{
      'name': shared?.name ?? r?['name'] as String? ?? '',
      'date': shared?.date ?? r?['date'] as String? ?? source.today,
      'total': shared != null
          ? phpDecimal(shared.total)
          : r == null
          ? ''
          : phpDecimal(sharedMinor(r['total'])),
      // A correction keeps the bill's own split; it used to turn into Exact.
      'method': r?['method'] as String? ?? 'equal',
      'reason': '',
      if (widget.group == null) 'group': group.id,
    };
    final payers = <String>[];
    for (final p in people) {
      final paid = r == null
          ? BigInt.zero
          : sharedMinor(r['paid'][p.key] ?? '0');
      if (paid > BigInt.zero) payers.add(p.key);
      out['paid:${p.key}'] = r == null ? '' : phpDecimal(paid);
      out['include:${p.key}'] = r == null || r['shares'].containsKey(p.key)
          ? 'yes'
          : 'no';
      out['share:${p.key}'] = r == null
          ? ''
          : phpDecimal(sharedMinor(r['shares'][p.key] ?? '0'));
    }
    many = payers.length > 1;
    out['payer'] = payers.length == 1 ? payers.single : me ?? '';
    return out;
  }

  @override
  void initState() {
    super.initState();
    unawaited(restore());
  }

  Future<void> restore() async {
    final draftId = widget.draftId;
    if (draftId != null) {
      try {
        final draft = await writer.readDraft(draftId);
        final fields = draft == null ? null : object(draft['fields']);
        if (fields != null) {
          for (final e in fields.entries) {
            if (values.containsKey(e.key) && e.value is String) {
              values[e.key] = e.value as String;
            }
          }
          final payers = [
            for (final p in people)
              if ((typedAmount(values['paid:${p.key}']) ?? BigInt.zero) >
                  BigInt.zero)
                p.key,
          ];
          many = fields['payers'] == 'many' || payers.length > 1;
          if (fields['payer'] == null && payers.length == 1) {
            values['payer'] = payers.single;
          }
          // A payer who has since left can't be chosen for a new bill.
          if (!people.any((p) => p.key == values['payer'])) {
            values['payer'] = me ?? '';
          }
          dirty = true;
        }
      } catch (_) {
        error = 'Your saved draft could not be read. Reopen this profile.';
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Map<String, dynamic> get draftData => {
    'title': widget.title,
    'op': 'bill',
    'source': bill,
    'refund': false,
  };

  BigInt? get total => typedAmount(values['total']);
  Iterable<String> get included => [
    for (final p in people)
      if (values['include:${p.key}'] == 'yes') p.key,
  ];

  /// Who paid what: everyone, zeros included, as the command always carried.
  /// A shared purchase names only its payer, as it always did.
  Map<String, String> paidAxis(BigInt total) => widget.purchase != null
      ? {me!: '$total'}
      : many
      ? {
          for (final p in people)
            p.key: '${typedOrZero(values['paid:${p.key}'])}',
        }
      : {
          for (final p in people)
            p.key: p.key == values['payer'] ? '$total' : '0',
        };

  Map<String, String> shareAxis(BigInt total) => values['method'] == 'equal'
      ? equalShares(total, included)
      : {for (final p in included) p: '${typedOrZero(values['share:$p'])}'};

  /// Each person's part as it stands, for the eye.
  Map<String, String>? get liveShares {
    final t = total;
    if (t == null || t <= BigInt.zero || included.isEmpty) return null;
    if (values['method'] != 'equal') return null;
    return equalShares(t, included);
  }

  /// Each person's part as it stands: null until the parts add up.
  Map<String, BigInt>? get liveParts {
    final t = total;
    if (t == null || t <= BigInt.zero || included.isEmpty) return null;
    final shares = liveShares;
    if (shares != null) {
      return {for (final e in shares.entries) e.key: sharedMinor(e.value)};
    }
    final parts = {
      for (final p in included)
        p: typedAmount(values['share:$p']) ?? BigInt.zero,
    };
    return parts.values.fold(BigInt.zero, (a, b) => a + b) == t ? parts : null;
  }

  /// What each person paid as it stands: null until it adds up to the total.
  Map<String, BigInt>? get livePaid {
    final t = total;
    if (t == null || t <= BigInt.zero) return null;
    if (widget.purchase != null) return {me!: t};
    if (!many) {
      final payer = values['payer'] ?? '';
      return payer.isEmpty ? null : {payer: t};
    }
    final paid = {
      for (final p in people)
        p.key: typedAmount(values['paid:${p.key}']) ?? BigInt.zero,
    };
    return paid.values.fold(BigInt.zero, (a, b) => a + b) == t ? paid : null;
  }

  @override
  void check() {
    if (answer('name').isEmpty) {
      reject('Say what this was for.', field: 'name');
    }
    final t = total;
    if (t == null) {
      reject(
        answer('total').isEmpty
            ? 'Enter the total.'
            : 'Enter an amount like 1500.00.',
        field: 'total',
      );
    }
    if (t <= BigInt.zero) {
      reject('Enter a total greater than zero.', field: 'total');
    }
    if (answer('date').isEmpty) reject('Choose a date.', field: 'date');
    if (!many && (values['payer'] ?? '').isEmpty) {
      reject('Choose who paid.', field: 'payer');
    }
    if (bill != null && answer('reason').isEmpty) {
      reject('Say why you’re changing this.', field: 'reason');
    }
    for (final key in values.keys.where(
      (k) => k.startsWith('paid:') || k.startsWith('share:'),
    )) {
      if (answer(key).isNotEmpty && typedAmount(values[key]) == null) {
        reject('Enter an amount like 1500.00.', field: key);
      }
    }
    final Map<String, String> paid = paidAxis(t);
    try {
      validateSharedAxis(paid, group.people, t);
    } on LocalRuleException catch (e) {
      reject(e.message, field: many ? 'paid' : 'payer');
    }
    try {
      validateSharedAxis(shareAxis(t), group.people, t);
    } on LocalRuleException catch (e) {
      reject(e.message, field: 'shares');
    }
    // What the server checks, so a refusal doesn't stay on the record.
    if (bill != null) checkRefunds(paid, shareAxis(t));
  }

  void checkRefunds(Map<String, String> paid, Map<String, String> shares) {
    for (final f in group.bills[bill]['refunds'] as List) {
      for (final p in people) {
        if (sharedMinor(f['received'][p.key] ?? '0') >
                sharedMinor(paid[p.key] ?? '0') ||
            sharedMinor(f['credits'][p.key] ?? '0') >
                sharedMinor(shares[p.key] ?? '0')) {
          reject(
            'A refund on this bill is more than this change leaves.',
            field: 'total',
          );
        }
      }
    }
  }

  @override
  void retain() {
    // A shared purchase keeps no draft: it's already saved in Money.
    if (widget.purchase == null) {
      super.retain();
    } else {
      setState(() => dirty = true);
    }
  }

  @override
  Future<void> send() async {
    final shared = widget.purchase;
    if (shared != null) await hub.repo?.linkPurchase(id, group.id, shared.id);
    await super.send();
  }

  @override
  SharedJson command() {
    final t = total!;
    final paid = paidAxis(t), shares = shareAxis(t);
    return {
      'date': civilDate(values['date']!),
      'total': '$t',
      'name': answer('name'),
      'paid': paid,
      'shares': shares,
      'method': values['method'],
      if (bill != null) ...{
        'bill': bill,
        'revision': revision!['id'],
        'reason': answer('reason'),
      },
    };
  }

  void setPayers(bool next) {
    setState(() {
      many = next;
      if (errorField == 'paid' || errorField == 'payer') {
        errorField = errorMessage = null;
      }
    });
    values['payers'] = next ? 'many' : 'one';
    retain();
  }

  void include(String person, bool yes) {
    setState(() {
      values['include:$person'] = yes ? 'yes' : 'no';
      if (errorField == 'shares') errorField = errorMessage = null;
    });
    retain();
  }

  Widget whoPaid() {
    final a = source.amount;
    if (!many) {
      return pickInput('payer', 'Paid by', {
        for (final p in people) p.key: personLabel(group, p.key, me),
      }, required: true);
    }
    final sum = [
      for (final p in people)
        typedAmount(values['paid:${p.key}']) ?? BigInt.zero,
    ].fold(BigInt.zero, (a, b) => a + b);
    return Column(
      key: anchor('paid'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in people)
          amountInput('paid:${p.key}', personLabel(group, p.key, me)),
        FormRunningTotal(label: 'Paid', sum: sum, total: total, amount: a),
        if (errorField == 'paid') fieldError(errorMessage!),
      ],
    );
  }

  Widget fieldError(String message) => Padding(
    padding: const EdgeInsets.only(top: Space.xs),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: CraftTheme.of(context).tone(NoticeTone.error).$1),
    ),
  );

  Widget whosIn() {
    final a = source.amount, c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final live = liveShares;
    final parts = liveParts, paid = livePaid;
    final exact = values['method'] != 'equal';
    final sum = [
      for (final p in included) typedAmount(values['share:$p']) ?? BigInt.zero,
    ].fold(BigInt.zero, (a, b) => a + b);
    final extra = live == null
        ? const <String>[]
        : extraCentavo({'method': 'equal', 'shares': live});
    return Column(
      key: anchor('shares'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in people)
          PersonCheck(
            key: ValueKey('include-${p.key}'),
            name: personLabel(group, p.key, me),
            value: values['include:${p.key}'] == 'yes',
            onChanged: (yes) => include(p.key, yes),
            trailing:
                parts == null ||
                    ((parts[p.key] ?? BigInt.zero) == BigInt.zero &&
                        (paid?[p.key] ?? BigInt.zero) == BigInt.zero)
                ? null
                : BillResult(
                    key: ValueKey('result-${p.key}'),
                    part: parts[p.key] ?? BigInt.zero,
                    paid: paid == null ? null : paid[p.key] ?? BigInt.zero,
                    amount: a,
                  ),
          ),
        if (exact)
          for (final p in included)
            amountInput('share:$p', '${personLabel(group, p, me)}’s part'),
        if (exact)
          FormRunningTotal(label: 'Parts', sum: sum, total: total, amount: a),
        if (extra.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              'The extra centavo goes to ${extra.map((p) => personLabel(group, p, me)).join(' and ')}.',
              style: text.bodySmall?.copyWith(color: c.secondary),
            ),
          ),
        if (parts != null && paid == null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              'What each person owes shows once Who paid adds up to the total.',
              style: text.bodySmall?.copyWith(color: c.secondary),
            ),
          ),
        if (errorField == 'shares') fieldError(errorMessage!),
      ],
    );
  }

  List<Widget> details() {
    firstField = true;
    final groups = currentGroups;
    return [
      if (widget.group == null && groups.length > 1)
        pickInput(
          'group',
          'Group',
          {for (final g in groups) g.id: g.name},
          required: true,
          onChanged: (next) {
            final chosen = groups.firstWhere((g) => g.id == next);
            setState(() {
              group = chosen;
              final kept = {
                for (final key in ['name', 'date', 'total', 'method'])
                  key: values[key]!,
              };
              values
                ..clear()
                ..addAll(startingValues())
                ..addAll(kept)
                ..['group'] = next;
            });
          },
        ),
      textInput('name', 'Description', required: true),
      if (widget.purchase == null) ...[
        amountInput('total', 'Total', required: true),
        dateInput('date', 'Date', required: true),
        FormGroupLabel(
          'Who paid',
          action: CardLink(
            many ? 'One person paid' : 'Split between payers',
            key: const ValueKey('shared-payers'),
            chevron: false,
            onPressed: () => setPayers(!many),
          ),
        ),
        whoPaid(),
      ] else ...[
        FactRow('Amount', source.amount(widget.purchase!.total)),
        FactRow('Date', civilDay(widget.purchase!.date)),
        const FactRow('Who paid', 'You'),
      ],
      const FormGroupLabel('Who’s in'),
      pickInput(
        'method',
        'How to split',
        const {'equal': 'Equal', 'exact': 'Exact amounts'},
        style: PickerStyle.radio,
        descriptions: const {
          'equal': 'Everyone who’s in pays the same, to the centavo.',
          'exact': 'Enter each person’s part yourself.',
        },
        onChanged: (_) => setState(() {}),
      ),
      whosIn(),
      if (bill != null)
        textInput(
          'reason',
          'Why you’re changing this',
          required: true,
          helper: 'The earlier version stays in Edit history.',
        ),
    ];
  }

  Widget review() {
    final t = total!;
    final paid = paidAxis(t), shares = shareAxis(t), a = source.amount;
    final rows = [
      for (final p in people)
        if (sharedMinor(paid[p.key] ?? '0') > BigInt.zero ||
            shares.containsKey(p.key))
          (
            personLabel(group, p.key, me),
            [
              a(sharedMinor(paid[p.key] ?? '0')),
              a(sharedMinor(shares[p.key] ?? '0')),
            ],
          ),
    ];
    final extra = extraCentavo({'method': values['method'], 'shares': shares});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FactRow('Description', answer('name')),
        FactRow('Group', group.name),
        FactRow('Date', civilDay(values['date']!)),
        FactRow('Total', a(t)),
        if (bill != null) FactRow('Why', answer('reason')),
        SizedBox(height: CompactForm.fieldGap(context)),
        SharedMoneyTable(
          key: const ValueKey('shared-review-table'),
          label: 'Person',
          columns: const ['Paid', 'Part'],
          rows: rows,
        ),
        if (extra.isNotEmpty) ...[
          const SizedBox(height: Space.xs),
          Text(
            'The extra centavo goes to ${extra.map((p) => personLabel(group, p, me)).join(' and ')}.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: CraftTheme.of(context).secondary),
          ),
        ],
        SizedBox(height: CompactForm.fieldGap(context)),
        const InlineNotice(
          'This goes to the group. Your own accounts don’t change.',
        ),
        ...reviewNotices(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = loading
        ? const LoadingSkeleton.lines(label: 'your draft', lines: 4)
        : saved
        ? savedPanel(bill == null ? 'Shared expense added' : 'Bill corrected')
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              errorNotices(),
              if (reviewing) review() else ...details(),
              SizedBox(height: CompactForm.groupGap(context)),
              stepActions('Save'),
            ],
          );
    return framed(widget.title, body, keepDraft: widget.purchase == null);
  }
}

/// Log a refund. What came back goes to whoever received it, and whose part
/// goes down is entered separately; the two are the rule's own axes. Each
/// person's room is beside their field, as the server caps them.
class SharedRefundForm extends StatefulWidget {
  const SharedRefundForm({
    super.key,
    required this.hub,
    required this.group,
    required this.bill,
    this.draftId,
  });
  final SharedHub hub;
  final SharedGroup group;
  final String bill;
  final String? draftId;
  @override
  State<SharedRefundForm> createState() => _SharedRefundFormState();
}

class _SharedRefundFormState extends State<SharedRefundForm>
    with FormInputs, SharedFormSteps {
  @override
  SharedHub get hub => widget.hub;
  @override
  SharedGroup get group => widget.group;
  @override
  late String id = widget.draftId ?? newLocalId();
  @override
  bool get queued => false;
  @override
  String get op => 'refund';
  SharedJson get revision => group.revision(widget.bill);
  String? get me => group.participant(writer.actor ?? '');

  BigInt refunded(String key, String person) => sumMinor(
    (group.bills[widget.bill]['refunds'] as List).map(
      (f) => sharedMinor(f[key][person] ?? '0'),
    ),
  );

  /// What each person can still get back, and how much their part can drop.
  late final Map<String, BigInt> roomBack = {
    for (final p in group.people.keys)
      p: sharedMinor(revision['paid'][p] ?? '0') - refunded('received', p),
  };
  late final Map<String, BigInt> roomPart = {
    for (final p in group.people.keys)
      p: sharedMinor(revision['shares'][p] ?? '0') - refunded('credits', p),
  };

  @override
  late final Map<String, String> values = {
    'total': '',
    'date': source.today,
    'reason': '',
    for (final p in group.people.keys) ...{'paid:$p': '', 'share:$p': ''},
  };

  @override
  void initState() {
    super.initState();
    final draftId = widget.draftId;
    if (draftId != null) unawaited(restore(draftId));
  }

  Future<void> restore(String draftId) async {
    try {
      final draft = await writer.readDraft(draftId);
      if (draft == null) return;
      for (final e in object(draft['fields']).entries) {
        if (values.containsKey(e.key) && e.value is String) {
          values[e.key] = e.value as String;
          fields[e.key]?.text = e.value as String;
        }
      }
      dirty = true;
    } catch (_) {
      error = 'Your saved draft could not be read. Reopen this profile.';
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Map<String, dynamic> get draftData => {
    'title': 'Log a refund',
    'op': 'bill',
    'source': widget.bill,
    'refund': true,
  };

  BigInt? get total => typedAmount(values['total']);

  /// The people on each axis. Credits only go to people with a part, as the
  /// old form's include list did.
  List<String> get receivers => [
    for (final e in roomBack.entries)
      if (e.value > BigInt.zero) e.key,
  ];
  List<String> get sharers => [
    for (final p in object(revision['shares']).keys)
      if (group.people.containsKey(p)) p,
  ];

  Map<String, String> get received => {
    for (final p in group.people.keys) p: '${typedOrZero(values['paid:$p'])}',
  };
  Map<String, String> get credits => {
    for (final p in sharers) p: '${typedOrZero(values['share:$p'])}',
  };

  @override
  void check() {
    final t = total;
    if (t == null) {
      reject(
        answer('total').isEmpty
            ? 'Enter the refund.'
            : 'Enter an amount like 1500.00.',
        field: 'total',
      );
    }
    if (t <= BigInt.zero) {
      reject('Enter a refund greater than zero.', field: 'total');
    }
    if ((values['date'] ?? '').compareTo(revision['date'] as String) < 0) {
      reject('A refund can’t be dated before its bill.', field: 'date');
    }
    if (answer('reason').isEmpty) {
      reject('Say what this refund was for.', field: 'reason');
    }
    for (final key in values.keys.where(
      (k) => k.startsWith('paid:') || k.startsWith('share:'),
    )) {
      if (answer(key).isNotEmpty && typedAmount(values[key]) == null) {
        reject('Enter an amount like 1500.00.', field: key);
      }
    }
    for (final p in receivers) {
      if (typedOrZero(values['paid:$p']) > roomBack[p]!) {
        reject(
          'That’s more than what’s left to refund for someone on this bill.',
          field: 'paid:$p',
        );
      }
    }
    for (final p in sharers) {
      if (typedOrZero(values['share:$p']) > roomPart[p]!) {
        reject(
          'That’s more than what’s left to refund for someone on this bill.',
          field: 'share:$p',
        );
      }
    }
    try {
      validateSharedAxis(received, group.people, t);
    } on LocalRuleException catch (e) {
      reject(e.message, field: 'received');
    }
    try {
      validateSharedAxis(credits, group.people, t);
    } on LocalRuleException catch (e) {
      reject(e.message, field: 'credits');
    }
  }

  @override
  SharedJson command() => {
    'date': civilDate(values['date']!),
    'total': '${total!}',
    'received': received,
    'credits': credits,
    'bill': widget.bill,
    'revision': revision['id'],
    'reason': answer('reason'),
  };

  /// Fills the parts with the rule's own equal split of the refund.
  void splitEqually() {
    final t = total;
    if (t == null || t <= BigInt.zero || sharers.isEmpty) return;
    final even = equalShares(t, sharers);
    setState(() {
      for (final p in sharers) {
        final text = phpDecimal(sharedMinor(even[p]));
        values['share:$p'] = text;
        controllerFor('share:$p').text = text;
      }
      if (errorField == 'credits') errorField = errorMessage = null;
    });
    retain();
  }

  Widget axis(
    String anchorKey,
    String key,
    List<String> people,
    Map<String, BigInt> room,
    String label,
  ) {
    final a = source.amount;
    final sum = [
      for (final p in people) typedAmount(values['$key:$p']) ?? BigInt.zero,
    ].fold(BigInt.zero, (a, b) => a + b);
    return Column(
      key: anchor(anchorKey),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in people)
          amountInput(
            '$key:$p',
            personLabel(group, p, me),
            helper: 'Up to ${a(room[p] ?? BigInt.zero)}',
          ),
        FormRunningTotal(label: label, sum: sum, total: total, amount: a),
        if (errorField == anchorKey)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CraftTheme.of(context).tone(NoticeTone.error).$1,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> details() {
    firstField = true;
    return [
      amountInput('total', 'Refund', required: true),
      dateInput(
        'date',
        'Date',
        required: true,
        helper: 'On or after ${civilDay(revision['date'] as String)}.',
      ),
      textInput('reason', 'What this refund was for', required: true),
      const FormGroupLabel('Who got the money back'),
      axis('received', 'paid', receivers, roomBack, 'Back'),
      FormGroupLabel(
        'Whose part goes down',
        action: CardLink(
          'Split equally',
          key: const ValueKey('shared-refund-equal'),
          chevron: false,
          onPressed: splitEqually,
        ),
      ),
      axis('credits', 'share', sharers, roomPart, 'Parts'),
    ];
  }

  Widget review() {
    final a = source.amount, t = total!;
    final rows = [
      for (final p in {...receivers, ...sharers})
        (
          personLabel(group, p, me),
          [
            a(typedOrZero(values['paid:$p'])),
            a(typedOrZero(values['share:$p'])),
          ],
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FactRow('Bill', revision['name'] as String),
        FactRow('Date', civilDay(values['date']!)),
        FactRow('Refund', a(t)),
        FactRow('For', answer('reason')),
        SizedBox(height: CompactForm.fieldGap(context)),
        SharedMoneyTable(
          label: 'Person',
          columns: const ['Back', 'Part down'],
          rows: rows,
        ),
        SizedBox(height: CompactForm.fieldGap(context)),
        const InlineNotice(
          'The bill and any payments stay as they are. Your own accounts don’t change.',
        ),
        ...reviewNotices(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => framed(
    'Log a refund',
    saved
        ? savedPanel('Refund logged')
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              errorNotices(),
              if (reviewing) review() else ...details(),
              SizedBox(height: CompactForm.groupGap(context)),
              stepActions('Save'),
            ],
          ),
  );
}
