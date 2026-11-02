import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../finance/debt_cards.dart' show civilDay;
import '../finance/form_mechanics.dart';
import '../local/finance_domain.dart';
import 'shared_bill_form.dart';
import 'shared_cards.dart';
import 'shared_data.dart';
import 'shared_domain.dart';
import 'shared_hub.dart';

/// Log a payment between members. It starts from what's owed, and it only
/// records a payment that happened elsewhere: the recipient still has to
/// confirm it. It sends the same `report` command as before.
class SharedPaymentForm extends StatefulWidget {
  const SharedPaymentForm({
    super.key,
    required this.hub,
    required this.group,
    this.sender,
    this.recipient,
    this.draftId,
  });
  final SharedHub hub;
  final SharedGroup group;

  /// Prefilled, from a row that says who's owed. The sender is set when the
  /// owner logs for someone who isn't registered.
  final String? sender, recipient;
  final String? draftId;
  static const title = 'Log a payment between members';
  @override
  State<SharedPaymentForm> createState() => _SharedPaymentFormState();
}

class _SharedPaymentFormState extends State<SharedPaymentForm>
    with FormInputs, SharedFormSteps {
  @override
  SharedHub get hub => widget.hub;
  @override
  SharedGroup get group => widget.group;
  @override
  late String id = widget.draftId ?? newLocalId();
  @override
  bool get queued => true;
  @override
  String get op => 'report';
  late bool loading = widget.draftId != null;
  String? get me => group.participant(writer.actor ?? '');
  bool get owner => me != null && group.data['owner'] == me;

  /// The rules let you log your own payment; the owner can log one for
  /// someone who isn't registered.
  List<String> get senders => [
    ?me,
    if (owner)
      for (final p in group.people.entries)
        if (p.key != me && p.value['kind'] != 'registered') p.key,
  ];

  /// Current members, and anyone who left but is still owed.
  List<String> get recipients => [
    for (final p in group.people.entries)
      if (p.key != sender &&
          (p.value['active'] == true ||
              owedBetween(group, sender, p.key) > BigInt.zero))
        p.key,
  ];

  String get sender => values['sender'] ?? '';
  String get recipient => values['recipient'] ?? '';
  String get mode => values['mode'] ?? 'custom';
  BigInt get owed => recipient.isEmpty || recipient == sender
      ? BigInt.zero
      : owedBetween(group, sender, recipient);

  @override
  late final Map<String, String> values = startingValues();

  Map<String, String> startingValues() {
    final me = widget.sender ?? this.me ?? '';
    final to = widget.recipient ?? '';
    final due = to.isEmpty ? BigInt.zero : owedBetween(group, me, to);
    return {
      'sender': me,
      'recipient': to,
      'date': source.today,
      'mode': due > BigInt.zero ? 'full' : 'custom',
      'amount': '',
      'acknowledge': 'no',
      for (final b in group.bills.keys) 'allocation:$b': '',
    };
  }

  @override
  void initState() {
    super.initState();
    final draftId = widget.draftId;
    if (draftId != null) unawaited(restore(draftId));
  }

  Future<void> restore(String draftId) async {
    try {
      final draft = await writer.readDraft(draftId);
      if (draft != null) {
        for (final e in object(draft['fields']).entries) {
          if (values.containsKey(e.key) && e.value is String) {
            values[e.key] = e.value as String;
          }
        }
        // Whatever the group is now, the form only offers what still applies.
        if (!senders.contains(sender)) values['sender'] = me ?? '';
        if (!recipients.contains(recipient)) values['recipient'] = '';
        if (mode == 'full' && owed <= BigInt.zero) values['mode'] = 'custom';
        if (mode == 'selected' && openBills.isEmpty) values['mode'] = 'custom';
        dirty = true;
      }
    } catch (_) {
      error = 'Your saved draft could not be read. Reopen this profile.';
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
    'title': SharedPaymentForm.title,
    'op': 'report',
  };

  /// The bills this payment can go against, with what's left on each.
  Map<String, BigInt> get openBills {
    if (recipient.isEmpty) return const {};
    return {
      for (final b in group.bills.keys)
        if (group.due(sender, recipient, bill: b) > BigInt.zero)
          b: group.due(sender, recipient, bill: b),
    };
  }

  BigInt allocated(String bill) =>
      typedAmount(values['allocation:$bill']) ?? BigInt.zero;
  Map<String, dynamic> get selected => {
    for (final b in group.bills.keys)
      if (allocated(b) > BigInt.zero)
        b: {'amount': '${allocated(b)}', 'revision': group.revision(b)['id']},
  };

  /// What's being logged, once it's a valid amount.
  BigInt? get amountNow => switch (mode) {
    'full' => owed,
    'selected' =>
      group.bills.keys
          .map(allocated)
          .fold<BigInt>(BigInt.zero, (a, b) => a + b),
    _ => typedAmount(values['amount']),
  };

  /// How the rules would apply it. Null until there's something to apply.
  SharedJson? get applied {
    final amount = amountNow;
    if (amount == null || amount <= BigInt.zero || recipient.isEmpty) {
      return null;
    }
    try {
      return group.settlementAllocation(
        sender,
        recipient,
        amount,
        selected: mode == 'selected' ? selected : null,
      );
    } on LocalRuleException {
      return null;
    }
  }

  bool get needsConsent {
    final p = applied;
    return p != null && (p['advance'] != '0' || p['overNet'] == true);
  }

  @override
  void check() {
    if (recipient.isEmpty) reject('Choose who was paid.', field: 'recipient');
    if (recipient == sender) {
      reject('Choose two different people.', field: 'recipient');
    }
    if (answer('date').isEmpty) reject('Choose a date.', field: 'date');
    if (mode == 'full' && owed <= BigInt.zero) {
      reject(
        'Nothing is owed here right now. Choose Part of it to log it anyway.',
        field: 'mode',
      );
    }
    if (mode == 'custom' && answer('amount').isEmpty) {
      reject('Enter the amount.', field: 'amount');
    }
    if (mode == 'custom' && typedAmount(values['amount']) == null) {
      reject('Enter an amount like 1500.00.', field: 'amount');
    }
    if (mode == 'selected') {
      for (final b in group.bills.keys) {
        if (answer('allocation:$b').isNotEmpty &&
            typedAmount(values['allocation:$b']) == null) {
          reject('Enter an amount like 1500.00.', field: 'allocation:$b');
        }
      }
    }
    final amount = amountNow!;
    if (amount <= BigInt.zero) {
      reject(
        mode == 'selected'
            ? 'Enter an amount on at least one bill.'
            : 'Enter an amount greater than zero.',
        field: mode == 'selected' ? 'bills' : 'amount',
      );
    }
    try {
      group.settlementAllocation(
        sender,
        recipient,
        amount,
        selected: mode == 'selected' ? selected : null,
      );
    } on LocalRuleException catch (e) {
      reject(e.message, field: 'bills');
    }
    if (needsConsent && values['acknowledge'] != 'yes') {
      reject(
        'Confirm that’s right, or change the amount.',
        field: 'acknowledge',
      );
    }
  }

  @override
  SharedJson command() {
    final amount = amountNow!;
    return {
      'sender': sender,
      'recipient': recipient,
      'date': civilDate(values['date']!),
      'amount': '$amount',
      'mode': mode,
      'allocations': mode == 'selected' ? selected : <String, dynamic>{},
      'acknowledge': values['acknowledge'] == 'yes',
    };
  }

  String who(String person) => personLabel(group, person, me);

  /// A name, and what's owed when that's something to know.
  String owedLabel(String person) {
    final due = owedBetween(group, sender, person);
    if (due <= BigInt.zero || source.hidden) return who(person);
    return '${who(person)} · owed ${source.amount(due)}';
  }

  void choose() => setState(() {
    if (recipient.isNotEmpty && owed <= BigInt.zero && mode == 'full') {
      values['mode'] = 'custom';
    }
    if (mode != 'full' && owed > BigInt.zero && answer('amount').isEmpty) {
      values['mode'] = 'full';
    }
    values['acknowledge'] = 'no';
  });

  Widget consent() {
    final a = source.amount, p = applied!;
    final ahead = sharedMinor(p['advance']);
    final over = amountNow! - (owed > BigInt.zero ? owed : BigInt.zero);
    final extra = ahead > over ? ahead : over;
    return Padding(
      key: anchor('acknowledge'),
      padding: gapAbove(),
      child: OptionPicker<String>(
        key: const ValueKey('native-select-acknowledge'),
        label: extra > BigInt.zero
            ? 'That’s ${a(extra)} more than what’s owed'
            : 'This is more than what’s owed',
        style: PickerStyle.radio,
        errorText: problemFor('acknowledge'),
        value: values['acknowledge'],
        options: const [
          PickerOption(
            value: 'yes',
            label: 'That is right',
            description: 'Keep the extra as paid ahead.',
          ),
          PickerOption(
            value: 'no',
            label: 'Let me check',
            description: 'Change the amount first.',
          ),
        ],
        onChanged: (x) {
          if (errorField == 'acknowledge') errorField = errorMessage = null;
          changed('acknowledge', x);
        },
      ),
    );
  }

  Widget billFields() {
    final a = source.amount;
    final bills = openBills;
    return Column(
      key: anchor('bills'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bills.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: CompactForm.fieldGap(context)),
            child: const InlineNotice('Nothing is owed on any bill here.'),
          ),
        for (final b in bills.entries)
          amountInput(
            'allocation:${b.key}',
            group.revision(b.key)['name'] as String,
            helper: 'Up to ${a(b.value)}',
          ),
        if (bills.isNotEmpty)
          FormRunningTotal(
            label: 'This payment',
            sum: amountNow ?? BigInt.zero,
            total: null,
            amount: a,
          ),
        if (errorField == 'bills')
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
    final a = source.amount;
    return [
      if (senders.length > 1)
        pickInput(
          'sender',
          'Who paid',
          {for (final p in senders) p: who(p)},
          required: true,
          onChanged: (_) => choose(),
        ),
      pickInput(
        'recipient',
        'To',
        {for (final p in recipients) p: owedLabel(p)},
        required: true,
        onChanged: (_) => choose(),
      ),
      pickInput(
        'mode',
        'How much',
        {
          if (owed > BigInt.zero) 'full': 'All of it · ${a(owed)}',
          'custom': 'Part of it',
          if (openBills.isNotEmpty) 'selected': 'Choose bills',
        },
        style: PickerStyle.radio,
        descriptions: {
          if (owed > BigInt.zero) 'full': 'Everything owed to them right now.',
          'custom': 'Any amount. It goes against the oldest bills first.',
          if (openBills.isNotEmpty)
            'selected': 'Say how much went against each bill.',
        },
        onChanged: (_) => setState(() => values['acknowledge'] = 'no'),
      ),
      if (mode == 'custom') amountInput('amount', 'Amount', required: true),
      if (mode == 'selected') billFields(),
      if (needsConsent) consent(),
      dateInput('date', 'Date paid', required: true),
    ];
  }

  Widget review() {
    final a = source.amount, amount = amountNow!, p = applied!;
    final ahead = sharedMinor(p['advance']);
    final bills = object(p['allocations']);
    final after = owed - amount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FactRow('Payment', '${who(sender)} → ${who(recipient)}'),
        FactRow('Amount', a(amount)),
        FactRow('Date paid', civilDay(values['date']!)),
        if (bills.isNotEmpty) ...[
          SizedBox(height: CompactForm.fieldGap(context)),
          SharedMoneyTable(
            key: const ValueKey('payment-review-table'),
            label: 'Applied to',
            columns: const ['Amount'],
            rows: [
              for (final b in bills.entries)
                (
                  group.revision(b.key)['name'] as String,
                  [a(sharedMinor(b.value['amount']))],
                ),
              if (ahead > BigInt.zero) ('Paid ahead', [a(ahead)]),
            ],
          ),
        ] else if (ahead > BigInt.zero)
          FactRow('Paid ahead', a(ahead)),
        SizedBox(height: CompactForm.fieldGap(context)),
        InlineNotice(
          after > BigInt.zero
              ? 'If it’s confirmed, ${who(sender) == 'You' ? 'you’d' : '${who(sender)} would'} still owe ${who(recipient)} ${a(after)}.'
              : after < BigInt.zero
              ? 'If it’s confirmed, ${who(recipient)} would owe ${who(sender) == 'You' ? 'you' : who(sender)} ${a(-after)}.'
              : 'If it’s confirmed, nothing is left between ${who(sender) == 'You' ? 'you' : who(sender)} and ${who(recipient)}.',
          title: 'Waiting for ${who(recipient)} to confirm',
        ),
        SizedBox(height: CompactForm.fieldGap(context)),
        const InlineNotice(
          'This only records a payment made elsewhere. Your own accounts don’t change.',
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
        ? savedPanel('Payment logged')
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              errorNotices(),
              if (reviewing) review() else ...details(),
              SizedBox(height: CompactForm.groupGap(context)),
              stepActions('Save'),
            ],
          );
    return framed(SharedPaymentForm.title, body);
  }
}

/// What a person can do to a payment that's been logged.
enum PaymentAnswer {
  confirm(
    'Confirm you received it',
    'confirmed',
    'Confirm',
    needsReason: false,
  ),
  dispute('Dispute this payment', 'disputed', 'Dispute'),
  cancel('Cancel this payment', 'cancelled', 'Cancel payment'),
  undo('Undo confirmation', 'reversed', 'Undo confirmation');

  const PaymentAnswer(
    this.title,
    this.state,
    this.action, {
    this.needsReason = true,
  });
  final String title, state, action;
  final bool needsReason;
}

/// Asks, and sends the answer. A short form, so a dialog on Windows and a
/// sheet on Android. Returns true once the group has it.
Future<bool> showPaymentAnswer(
  BuildContext context,
  SharedHub hub,
  SharedGroup group,
  String payment,
  PaymentAnswer answer,
) async {
  final form = GlobalKey<_AnswerState>();
  final done = await showAdaptiveModal<bool>(
    context,
    title: answer.title,
    purpose: ModalPurpose.choice,
    body: _Answer(
      key: form,
      hub: hub,
      group: group,
      payment: payment,
      answer: answer,
    ),
    primary: ModalAction(
      answer.action,
      value: true,
      destructive:
          answer == PaymentAnswer.cancel || answer == PaymentAnswer.undo,
      onPressed: () async => await form.currentState?.save() ?? false,
    ),
  );
  return done == true;
}

class _Answer extends StatefulWidget {
  const _Answer({
    super.key,
    required this.hub,
    required this.group,
    required this.payment,
    required this.answer,
  });
  final SharedHub hub;
  final SharedGroup group;
  final String payment;
  final PaymentAnswer answer;
  @override
  State<_Answer> createState() => _AnswerState();
}

class _AnswerState extends State<_Answer> {
  var command = newLocalId();
  final reason = TextEditingController();
  String? reasonError, problem, manualError;
  bool lost = false, manual = false;

  SharedGroup get g => widget.group;
  PaymentAnswer get answer => widget.answer;

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  /// Sends, and says whether the modal can close. After a lost answer the
  /// same command goes again, and the server answers from its receipt.
  Future<bool> save() async {
    final source = widget.hub.source();
    final needsManual =
        answer == PaymentAnswer.confirm &&
        paymentChoices(
          g,
          widget.payment,
          g.participant(source.actor ?? ''),
        ).manual;
    final why = reason.text.trim();
    setState(() {
      reasonError = answer.needsReason && why.isEmpty
          ? 'Say why, so everyone can see it.'
          : null;
      manualError = needsManual && !manual
          ? 'Tick this to record it for them.'
          : null;
      problem = null;
    });
    if (reasonError != null || manualError != null) return false;
    final latest = source.group(g.id);
    if (!lost && g.complete && latest != null && latest.version != g.version) {
      setState(
        () => problem = 'The group changed while you were working. Close this and check the payment again.',
      );
      return false;
    }
    try {
      await source.writer.submit(
        g.id,
        'resolve',
        {
          'settlement': widget.payment,
          'state': answer.state,
          'reason': why,
          'acknowledge': manual,
        },
        version: g.version,
        id: command,
      );
      return true;
    } on LocalRuleException catch (e) {
      setState(() {
        problem = sharedReason(e.message);
        command = newLocalId();
        lost = false;
      });
    } catch (_) {
      setState(() => lost = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.hub.source();
    final me = g.participant(source.actor ?? '');
    final p = sharedPaymentRow(g, widget.payment, me, source.today);
    final choices = paymentChoices(g, widget.payment, me);
    final text = Theme.of(context).textTheme;
    final c = CraftTheme.of(context);
    final gap = SizedBox(height: CompactForm.fieldGap(context));
    final bills = [
      for (final b in p.applied.entries)
        if (g.bills.containsKey(b.key))
          (g.revision(b.key)['name'] as String, [source.amount(b.value)]),
      if (p.ahead > BigInt.zero) ('Paid ahead', [source.amount(p.ahead)]),
    ];
    return CompactForm(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lost) ...[
            const InlineNotice(
              lostResponseMessage,
              title: lostResponseTitle,
              tone: NoticeTone.warning,
              live: true,
            ),
            gap,
          ],
          if (problem != null) ...[
            InlineNotice(problem!, tone: NoticeTone.error, live: true),
            gap,
          ],
          Text(
            '${p.from} logged ${source.amount(p.amount)} to ${p.to == 'You' ? 'you' : p.to} on ${civilDay(p.date)}.',
          ),
          if (bills.isNotEmpty && answer == PaymentAnswer.confirm) ...[
            const SizedBox(height: Space.sm),
            SharedMoneyTable(
              label: 'Applied to',
              columns: const ['Amount'],
              rows: bills,
            ),
          ],
          if (answer == PaymentAnswer.undo) ...[
            gap,
            const Text('No money moves back. Only the group’s records change.'),
          ],
          if (answer == PaymentAnswer.confirm && choices.manual) ...[
            gap,
            PersonCheck(
              key: const ValueKey('payment-manual'),
              name:
                  'I’m recording this for ${p.to}. They didn’t sign in to confirm it.',
              value: manual,
              onChanged: lost
                  ? (_) {}
                  : (v) => setState(() {
                      manual = v;
                      manualError = null;
                    }),
            ),
            if (manualError != null)
              Text(
                manualError!,
                style: text.bodySmall?.copyWith(
                  color: c.tone(NoticeTone.error).$1,
                ),
              ),
          ],
          if (answer.needsReason) ...[
            gap,
            HelpTextField(
              key: const ValueKey('payment-reason'),
              label: 'Why',
              controller: reason,
              required: true,
              readOnly: lost,
              errorText: reasonError,
            ),
          ],
        ],
      ),
    );
  }
}
