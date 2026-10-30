import 'source_list.dart';
import '../design_system/theme.dart';
import '../features/finance/presentation/financial_review.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../connected/financial_contract.dart' show dependencySensitive;
import '../app/overview_cards.dart' show civilLabel;
import '../app/overview_data.dart' show DebtProgress, overviewDebtProgress;
import 'debt_data.dart' show debtPaymentRows;
import '../design_system/editorial.dart';
import '../design_system/kit/kit.dart'
    show
        AmountField,
        AppIconButton,
        CardLink,
        CompactForm,
        DateField,
        FieldInput,
        FormMoreDetails,
        HelpTextField,
        InlineNotice,
        OptionPicker,
        PickerOption,
        PickerStyle,
        SectionPage,
        SurfaceCard,
        isDesktop;
import '../features/finance/presentation/financial_widgets.dart';
import '../local/finance_domain.dart';
import '../local/local_finance_controller.dart';
import '../p0/exact_money.dart';
import '../features/finance/presentation/financial_editor.dart';
import '../features/finance/contracts/financial_models.dart';

/// The sync rule's refusal: this change needs the latest records first
/// (ARCHITECTURE §8.2). It stays a rule; these are the form's words for it.
bool isSyncBlock(Object e) =>
    e is LocalRuleException &&
    e.message.startsWith('Sync now before finalizing');

const syncBlockedTitle = 'Couldn’t check your latest records';
const syncBlockedMessage =
    'Salapiya checks your latest records before saving this, and that needs a connection. Nothing was saved, and what you entered is still here.';

class FinanceInput {
  const FinanceInput(
    this.key,
    this.label, {
    this.value = '',
    this.options,
    this.lines = 1,
    this.help,
    this.info,
    this.required = false,
    this.money = false,
    this.more = false,
  });
  final String key, label, value;
  final Map<String, String>? options;
  final int lines;
  final String? help;

  /// What the field does, behind the ⓘ (§6).
  final String? info;
  final bool required;

  /// An amount field, whatever its label says.
  final bool money;

  /// Goes under "More details".
  final bool more;

  /// The same input under another label, e.g. a shared account field.
  FinanceInput as(String label, {bool required = false, bool more = false}) =>
      FinanceInput(
        key,
        label,
        value: value,
        options: options,
        lines: lines,
        help: help,
        required: required,
        more: more,
      );
}

/// Plain-language payment schedule questions. [editing] revises the dates of
/// an existing schedule; amounts are set while creating it, or later through
/// Update amounts. The payments always add up to the debt.
List<FinanceInput> debtCadenceInputs({
  required bool editing,
  required bool embedded,
}) => [
  FinanceInput(
    'frequency',
    'How often do you pay?',
    help: embedded ? 'Optional. You can add the schedule later.' : null,
    options: {
      if (embedded) '': 'Not now · I will set it later',
      if (editing) '': 'No repeating pattern · dates listed below',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
      'yearly': 'Yearly',
      'custom': 'Custom',
    },
  ),
  const FinanceInput(
    'intervalDays',
    'Pay every how many days?',
    help: 'For example, type 14 for every two weeks.',
  ),
  const FinanceInput('firstDue', 'When is your next payment due?'),
  if (!editing) ...[
    const FinanceInput(
      'installmentCount',
      'How many payments are left?',
      help: 'Count from the next payment, for example 12. Up to 120.',
    ),
    const FinanceInput(
      'splitMode',
      'How are the payments split?',
      value: 'divide',
      options: {
        'divide': 'Divide the debt evenly',
        'varied': 'Different amount each time',
      },
    ),
  ],
];

Map<String, String> financeChoices(LocalSnapshot s, Set<String> types) => {
  for (final r in s.current.where((r) => types.contains(financeType(r))))
    r.id: '${r.title} · ${r.date} · v${r.number}',
};

List<FinanceInput> financeInputs(
  LocalSnapshot s,
  String op, {
  bool editing = false,
}) {
  FinanceInput ref(String key, String label, Set<String> types) =>
      FinanceInput(key, label, options: financeChoices(s, types));
  final card = ref('card', 'Credit card', {'creditCard'});
  final debt = FinanceInput(
    'debt',
    'Debt',
    required: true,
    options: {
      for (final r in s.current.where(
        (r) => const {'debtImport', 'borrowing'}.contains(financeType(r)),
      ))
        r.id: r.title,
    },
  );
  final goal = ref('goal', 'Savings goal', {'savingsGoal'});
  final rule = FinanceInput(
    'rule',
    'Immutable recurring rule',
    options: {
      for (final r in s.revisions.where((r) => financeType(r) == 'recurrence'))
        r.id: '${r.title} · v${r.number} · ${r.values['start']}',
    },
  );
  const amount = FinanceInput('amount', 'Amount PHP');
  final category = FinanceInput(
    'category',
    'Expense category',
    value: 'category-food',
    options: {
      for (final c in s.categories.where((c) => c.kind == 'expense'))
        c.id: c.name,
    },
  );
  final account = FinanceInput(
    'account',
    'Actual cash account',
    options: {
      for (final a in s.accounts.where((a) => !a.archived)) a.id: a.name,
    },
  );
  const lenderConfirmed = FinanceInput(
    'verified',
    'Confirmed with your lender',
    value: 'false',
    options: {'false': 'Not yet', 'true': 'I confirmed this with my lender'},
  );
  const verified = FinanceInput(
    'verified',
    'Provider evidence confirmation',
    value: 'false',
    options: {
      'false': 'Not yet confirmed',
      'true': 'I confirm these provider facts',
    },
  );
  final fields = switch (op) {
    'fileDetach' => [
      ref('file', 'Private attachment link', {'financialFile'}),
      const FinanceInput('reason', 'Reason for archiving this link'),
    ],
    'budget' => [
      amount,
      category,
      const FinanceInput('start', 'Period start · YYYY-MM-DD'),
      const FinanceInput('endExclusive', 'Exclusive period end · YYYY-MM-DD'),
      const FinanceInput(
        'basis',
        'Recognized spending basis',
        value: 'net',
        options: {
          'net': 'Net spending after actual offsets',
          'gross': 'Gross recognized spending',
        },
      ),
      const FinanceInput(
        'status',
        'Budget lifecycle',
        value: 'active',
        options: {
          'active': 'Active',
          'archived': 'Archived; period remains reserved',
        },
      ),
    ],
    'savingsGoal' => [
      const FinanceInput('amount', 'Target PHP'),
      const FinanceInput('targetDate', 'Target date (optional) · YYYY-MM-DD'),
      const FinanceInput(
        'status',
        'Goal state',
        value: 'active',
        options: {
          'active': 'Active',
          'completed': 'Completed; reservations retained',
          'archived': 'Archived after explicit release',
        },
      ),
    ],
    'reservation' => [
      goal,
      account,
      const FinanceInput(
        'amount',
        'New absolute reserved amount PHP (zero releases)',
      ),
    ],
    'savingsReallocation' => [
      ref('fromGoal', 'Source savings goal', {'savingsGoal'}),
      FinanceInput(
        'fromAccount',
        'Source reserved account',
        options: {for (final a in s.accounts) a.id: a.name},
      ),
      goal,
      account,
      amount,
    ],
    'recurrence' => [
      amount,
      const FinanceInput(
        'recurringKind',
        'Expected activity',
        value: 'bill',
        options: {
          'income': 'Expected income',
          'bill': 'Bill',
          'subscription': 'Subscription',
        },
      ),
      const FinanceInput(
        'frequency',
        'Recurrence',
        value: 'monthly',
        options: {
          'daily': 'Daily',
          'weekly': 'Selected weekdays',
          'monthly': 'Monthly',
        },
      ),
      const FinanceInput('interval', 'Interval', value: '1'),
      const FinanceInput(
        'weekdays',
        'ISO weekdays (Monday=1): e.g. 1,3,5',
        value: '1',
      ),
      const FinanceInput('monthDay', 'Monthly day 1–31', value: '1'),
      const FinanceInput(
        'monthPolicy',
        'Short month policy',
        value: 'last_valid_day',
        options: {
          'last_valid_day': 'Last valid day',
          'skip': 'Skip short months',
        },
      ),
      FinanceInput(
        'start',
        'Effective start · YYYY-MM-DD',
        value: civilToday(),
      ),
      const FinanceInput('end', 'Inclusive end (optional) · YYYY-MM-DD'),
      const FinanceInput('count', 'Emitted occurrence count (optional)'),
      const FinanceInput(
        'timezone',
        'Named IANA timezone',
        value: 'Asia/Manila',
      ),
      FinanceInput(
        'account',
        'Suggested actual cash account (optional)',
        options: {'': 'Unassigned', ...?account.options},
      ),
      const FinanceInput(
        'status',
        'Definition state',
        value: 'active',
        options: {
          'active': 'Active',
          'archived': 'Archived; retained commitments remain visible',
        },
      ),
    ],
    'recurrenceGenerate' => [
      rule,
      FinanceInput(
        'from',
        'Generation start · YYYY-MM-DD',
        value: civilToday(),
      ),
      FinanceInput(
        'through',
        'Inclusive generation end · YYYY-MM-DD',
        value: DateTime.parse('${civilToday()}T00:00:00Z')
            .add(const Duration(days: 89))
            .toIso8601String()
            .substring(0, 10),
      ),
    ],
    'occurrenceOverride' || 'recurrenceLink' => [
      rule,
      const FinanceInput(
        'logicalDate',
        'Original logical occurrence date · YYYY-MM-DD',
      ),
      amount,
      if (op == 'occurrenceOverride') ...[
        const FinanceInput('due', 'Override due date · YYYY-MM-DD'),
        const FinanceInput(
          'state',
          'Occurrence decision',
          value: 'planned',
          options: {
            'planned': 'Expected / partial',
            'skipped': 'Skipped',
            'cancelled': 'Cancelled',
          },
        ),
        const FinanceInput('reason', 'Occurrence change reason'),
      ] else
        ref('actual', 'Existing actual income or purchase', {
          'income',
          'expense',
          'cardPurchase',
        }),
    ],
    'recurrenceUnlink' => [
      ref('link', 'Exact actual link to reverse', {'recurrenceLink'}),
      const FinanceInput('reason', 'Link reversal reason'),
    ],
    'debtImport' || 'borrowing' => [
      const FinanceInput('lender', 'Lender', required: true),
      const FinanceInput(
        'debtType',
        'Type',
        value: 'personal_loan',
        options: {
          'personal_loan': 'Personal loan',
          'installment_loan': 'Installment loan',
          'bnpl': 'Buy now pay later',
          'flexible_manual': 'Flexible credit',
        },
      ),
      FinanceInput(
        'amount',
        op == 'debtImport' ? 'What you owe now' : 'Amount borrowed',
        required: true,
        money: true,
      ),
      const FinanceInput(
        'principal',
        'Original principal',
        money: true,
        more: true,
        help: 'Leave this blank if you do not know it.',
      ),
      if (op == 'debtImport')
        const FinanceInput(
          'outstandingPrincipal',
          'Principal left',
          money: true,
          more: true,
          help: 'Only if your lender confirmed it. Leave this blank otherwise.',
        ),
      if (op == 'borrowing') ...[
        const FinanceInput(
          'fundingUse',
          'How you used it',
          value: 'cash',
          options: {
            'cash': 'Cash you received',
            'purchase': 'A purchase it paid for',
          },
        ),
        account.as('Paid into', required: true),
        category.as('Category', required: true),
        const FinanceInput(
          'withheld',
          'Fee taken out up front',
          value: '0.00',
          money: true,
          more: true,
        ),
        const FinanceInput(
          'financedFee',
          'Fee added to the loan',
          value: '0.00',
          money: true,
          more: true,
        ),
        FinanceInput(
          'feeCategory',
          'Fee category',
          value: 'category-fees',
          options: category.options,
          more: true,
        ),
      ],
      if (!editing) ...debtCadenceInputs(editing: false, embedded: true),
    ],
    'debtPayment' || 'debtClassification' || 'debtPayoff' => [
      debt,
      if (op != 'debtClassification') ...[
        FinanceInput(
          'amount',
          op == 'debtPayoff' ? 'Payoff amount' : 'Amount',
          required: true,
          money: true,
        ),
        account.as('Paid from', required: true),
      ],
      if (op == 'debtClassification')
        ref('payment', 'Which payment', {'debtPayment'}),
      const FinanceInput(
        'reduction',
        'Lowers what you owe',
        value: '0.00',
        money: true,
      ),
      const FinanceInput(
        'principalReduction',
        'Part of that which is principal',
        money: true,
        more: true,
        help: 'Leave this blank if your lender did not say.',
      ),
      const FinanceInput(
        'reductionSources',
        'Charges this lowers',
        lines: 4,
        more: true,
        help: 'One per line: the charge record, then the amount.',
      ),
      const FinanceInput(
        'interest',
        'New interest',
        value: '0.00',
        money: true,
      ),
      const FinanceInput('fee', 'New fee', value: '0.00', money: true),
      FinanceInput(
        'interestCategory',
        'Interest category',
        value: 'category-fees',
        options: category.options,
        more: true,
      ),
      FinanceInput(
        'feeCategory',
        'Fee category',
        value: 'category-fees',
        options: category.options,
        more: true,
      ),
      if (op == 'debtPayment') ...[
        const FinanceInput(
          'certainty',
          'What it covers',
          value: 'unresolved',
          options: {
            'unresolved': "I don't know the breakdown yet",
            'confirmed_total': 'All of it lowers what I owe',
            'known_components': 'I have the exact breakdown',
          },
        ),
        const FinanceInput(
          'externalFee',
          'Fee you paid to send it',
          value: '0.00',
          money: true,
          more: true,
        ),
        const FinanceInput(
          'clearing',
          'Still without a breakdown',
          value: '0.00',
          money: true,
        ),
        ref('scheduleSource', 'Payment schedule', {'debtSchedule'}),
        const FinanceInput(
          'allocations',
          'Applied to',
          lines: 4,
          help: 'One per line: the payment name, then the amount.',
        ),
        const FinanceInput(
          'unapplied',
          'Stays unapplied',
          value: '0.00',
          money: true,
        ),
      ],
      if (op == 'debtPayoff') ...[
        // Always the payoff amount: filled in at Review.
        const FinanceInput('providerPayoff', 'Payoff amount', money: true),
        const FinanceInput(
          'waiver',
          'Waived by your lender',
          value: '0.00',
          money: true,
        ),
        const FinanceInput(
          'avoided',
          'Charges you avoided',
          value: '0.00',
          money: true,
          more: true,
        ),
        const FinanceInput(
          'waiverBasis',
          'What the waiver is for',
          value: 'imported_unknown',
          more: true,
          options: {'imported_unknown': 'An amount in the opening balance'},
        ),
        lenderConfirmed,
      ],
      FinanceInput(
        'reason',
        op == 'debtPayoff' ? 'Why you paid it off' : 'What you found out',
      ),
    ],
    'debtSchedule' => [
      debt,
      ...debtCadenceInputs(editing: editing, embedded: false),
      const FinanceInput(
        'schedule',
        'Payment dates',
        lines: 6,
        help: 'One per line: name, date, amount and, if any, already paid.',
      ),
      lenderConfirmed,
    ],
    'debtAdjustment' => [
      debt,
      const FinanceInput('amount', 'Amount', required: true, money: true),
      const FinanceInput(
        'adjustmentKind',
        'What happened',
        value: 'recognized_charge',
        options: {
          'recognized_charge': 'A charge from your lender',
          'recognized_waiver': 'A waiver from your lender',
          'rounding_charge': 'A small rounding charge',
          'rounding_waiver': 'A small rounding waiver',
          'avoided_future': 'A future charge you avoided (no money moved)',
        },
      ),
      const FinanceInput(
        'chargeType',
        'Kind of charge',
        value: 'interest',
        options: {'interest': 'Interest', 'fee': 'Fee', 'penalty': 'Penalty'},
      ),
      category.as('Category'),
      const FinanceInput(
        'waiverBasis',
        'What the waiver is for',
        value: 'recognized_charge',
        options: {
          'recognized_charge': 'A charge you logged',
          'imported_unknown': 'An amount in the opening balance',
        },
      ),
      ref('chargeSource', 'Which charge', {'debtAdjustment', 'borrowing'}),
      const FinanceInput('reason', 'What your lender said'),
      lenderConfirmed,
    ],
    'creditCard' => [
      const FinanceInput('issuer', 'Issuer'),
      const FinanceInput('limit', 'Credit limit PHP (optional)'),
      const FinanceInput(
        'amount',
        'Signed opening posted liability PHP',
        value: '0.00',
      ),
    ],
    'cardAuthorization' => [card, amount],
    'cardPurchase' || 'cardFee' || 'cardInterest' => [
      card,
      amount,
      category,
      FinanceInput(
        'postingDate',
        'Provider posting date · YYYY-MM-DD',
        value: civilToday(),
      ),
    ],
    'cardPayment' => [card, account, amount],
    'cardRefund' => [
      card,
      ref('purchase', 'Original purchase', {'cardPurchase'}),
      amount,
      category,
      const FinanceInput('reason', 'Refund reason'),
    ],
    'statement' => [
      card,
      const FinanceInput('start', 'Cycle start · YYYY-MM-DD'),
      const FinanceInput('end', 'Cycle end · YYYY-MM-DD'),
      const FinanceInput('issued', 'Statement date · YYYY-MM-DD'),
      const FinanceInput('due', 'Due date · YYYY-MM-DD'),
      amount,
      const FinanceInput('minimum', 'Minimum due PHP (optional)'),
      verified,
    ],
    'statementLink' => [
      card,
      ref('statement', 'Statement', {'statement'}),
      ref('activity', 'Provider-confirmed activity', {
        'cardPurchase',
        'cardPayment',
        'cardRefund',
        'cardFee',
        'cardInterest',
      }),
      verified,
    ],
    'cardAllocation' => [
      card,
      ref('statement', 'Statement', {'statement'}),
      ref('payment', 'Actual payment or credit', {'cardPayment', 'cardRefund'}),
      amount,
      verified,
    ],
    'installment' => [
      card,
      ref('purchase', 'Already recognized purchase', {'cardPurchase'}),
      const FinanceInput(
        'schedule',
        'Provider schedule: label,YYYY-MM-DD,PHP amount (one per line)',
        lines: 5,
      ),
      const FinanceInput(
        'principal',
        'Confirmed total principal PHP (optional)',
      ),
      const FinanceInput('interest', 'Confirmed total interest PHP (optional)'),
      const FinanceInput('fee', 'Confirmed total fee PHP (optional)'),
      verified,
    ],
    'installmentApplication' => [
      card,
      ref('plan', 'Installment plan', {'installment'}),
      const FinanceInput('row', 'Exact installment label'),
      ref('payment', 'Actual statement allocation', {'cardAllocation'}),
      amount,
      verified,
    ],
    _ => <FinanceInput>[],
  };
  final debtOp = nativeDebtCommands.contains(op);
  final quiet = const {
    'debtImport',
    'borrowing',
    'debtClassification',
  }.contains(op);
  return [
    FinanceInput(
      'name',
      switch (op) {
        'debtImport' => 'Debt name',
        'borrowing' => 'Loan name',
        _ => 'Description',
      },
      required: const {'debtImport', 'borrowing'}.contains(op),
      more: const {'debtClassification', 'debtPayoff'}.contains(op),
    ),
    ...fields,
    FinanceInput('date', 'Date', value: civilToday()),
    FinanceInput(
      'reference',
      debtOp ? 'Lender reference' : 'Reference',
      help: debtOp
          ? null
          : 'Needed when your bank or issuer gave you a document.',
      more: quiet,
    ),
    FinanceInput('notes', 'Notes', lines: 3, more: debtOp),
    const FinanceInput(
      'acknowledge',
      'This takes the account below zero',
      value: 'false',
      options: {'false': 'Let me check', 'true': 'That is right'},
    ),
  ];
}

Future<void> openNativeFinance(
  BuildContext context,
  LocalFinancialController controller,
  String op,
  String title, {
  LocalRevision? replacing,
  Map<String, String> initial = const {},
}) => openDemoPage<void>(
  context,
  NativeFinanceEditor(
    controller: controller,
    operation: op,
    title: title,
    replacing: replacing,
    initial: initial,
  ),
  'finance/$op',
);

class NativeFinanceEditor extends StatefulWidget {
  const NativeFinanceEditor({
    super.key,
    required this.controller,
    required this.operation,
    required this.title,
    this.replacing,
    this.initial = const {},
  });
  final LocalFinancialController controller;
  final String operation, title;
  final LocalRevision? replacing;
  final Map<String, String> initial;
  @override
  State<NativeFinanceEditor> createState() => _NativeFinanceEditorState();
}

class _NativeFinanceEditorState extends State<NativeFinanceEditor> {
  late final inputs = financeInputs(
    widget.controller.snapshot,
    widget.replacing == null
        ? widget.operation
        : financeType(widget.replacing!),
    editing: widget.replacing != null,
  );
  late final values = {
    for (final f in inputs) f.key: f.value,
    ...widget.initial,
    ...?widget.replacing?.values,
    if (nativeDebtCommands.contains(
      widget.replacing == null
          ? widget.operation
          : financeType(widget.replacing!),
    ))
      'debtComponentContract': '1',
    if (widget.replacing != null &&
        [
          'budget',
          'savingsGoal',
          'recurrence',
        ].contains(financeType(widget.replacing!)))
      'date': civilToday(),
    if (widget.replacing != null) ...{
      'replace': widget.replacing!.id,
      'replaceVersion': '${widget.replacing!.number}',
      'reason': '',
    },
  };
  final fields = <String, TextEditingController>{};
  String? schedulePreview, scheduleNote, embeddedRows;
  String? errorField, errorMessage;
  final anchors = <String, GlobalKey>{};
  bool scheduleFailed = false;
  late String id = newLocalId();
  // A prefilled form keeps its own draft, so one debt's draft can't replace
  // what another debt's row proposed.
  late final draftKey = [
    'finance:${widget.operation}:${widget.replacing?.id ?? ''}',
    ?widget.initial['debt'],
    ?widget.initial['allocations'],
    ?widget.initial['payment'],
  ].join(':');
  Future<void> writes = Future.value();
  LocalCommand? reviewed;
  LocalPlan? plan;
  LocalSnapshot? reviewSnapshot;
  String? error, result;
  bool loading = true,
      busy = false,
      draftFailed = false,
      unknown = false,
      dirty = false;
  LocalFinancialController get c => widget.controller;
  Map<String, String> get reviewDetails =>
      simplePayment ? paymentDetails : standardDetails;

  /// The operation behind the form, also when correcting a record.
  String get recordType => widget.replacing == null
      ? widget.operation
      : financeType(widget.replacing!);
  Map<String, String> get standardDetails => {
    for (final input in inputs)
      if (!['name', 'amount', 'date', 'acknowledge'].contains(input.key) &&
          (values[input.key] ?? '').isNotEmpty)
        plainLabel(input):
            input.options?[values[input.key]] ?? values[input.key]!,
    if ((values['reason'] ?? '').isNotEmpty) 'Reason': values['reason']!,
  };
  @override
  void initState() {
    super.initState();
    if (simplePayment) {
      final first = (values['allocations'] ?? '').split('\n').first;
      values['paymentRow'] = first.contains(',') ? first.split(',').first : '';
      // With one account there is nothing to choose.
      final accounts = c.snapshot.accounts.where((a) => !a.archived).toList();
      if (accounts.length == 1 && (values['account'] ?? '').isEmpty) {
        values['account'] = accounts.single.id;
      }
    }
    unawaited(restore());
  }

  Future<void> restore() async {
    try {
      final draft = await c.store.draft(draftKey);
      if (draft != null) {
        values.addAll(Map<String, String>.from(draft['values'] as Map));
        id = draft['command'] as String;
        dirty = true;
      }
    } catch (_) {
      error = 'Saved input could not be read. Reopen this profile.';
      draftFailed = true;
    }
    if (mounted) setState(() => loading = false);
  }

  void retain() {
    setState(() => dirty = true);
    final frozen = Map<String, String>.from(values), command = id;
    writes = writes
        .then((_) => c.store.saveDraft(draftKey, command, frozen))
        .then((_) {
          if (mounted) setState(() => draftFailed = false);
        })
        .catchError((Object _) {
          if (mounted) {
            setState(() {
              draftFailed = true;
              error = 'Input could not be saved. Check storage before leaving.';
            });
          }
        });
  }

  /// A sync is under way before saving.
  bool syncing = false;

  /// The rule refused the change even after trying to sync.
  bool syncBlocked = false;

  /// The sync brought new records, so the review was built again.
  bool rechecked = false;

  bool get needsLatest =>
      c.connected && reviewed != null && dependencySensitive(reviewed!);

  /// Syncs before a change that needs the latest records. If that brought
  /// new records the reviewed command is out of date, so it's reviewed again
  /// on them and nothing saves: returns true.
  Future<bool> refreshBeforeSaving() async {
    if (!needsLatest) return false;
    setState(() => syncing = true);
    await c.syncLatest?.call();
    await c.reload();
    if (mounted) setState(() => syncing = false);
    if (c.snapshot.version == reviewed!.expectedVersion) return false;
    reviewed = LocalCommand(
      id: id,
      owner: c.store.owner,
      expectedVersion: c.snapshot.version,
      kind: reviewed!.kind,
      values: reviewed!.values,
    );
    reviewSnapshot = c.snapshot;
    plan = planLocal(reviewSnapshot!, reviewed!);
    return true;
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
      errorField = errorMessage = null;
      syncBlocked = rechecked = false;
    });
    String? problem, problemField;
    try {
      await writes;
      if (draftFailed) reject('Save the retained input before submitting.');
      if (reviewed == null) {
        await c.reload();
        schedulePreview = embeddedRows = null;
        final rows = simpleSchedule || embeddedSchedule ? cadenceRows() : null;
        if (rows != null) schedulePreview = previewRows(rows);
        if (embeddedSchedule) embeddedRows = rows;
        reviewed = LocalCommand(
          id: id,
          owner: c.store.owner,
          expectedVersion: c.snapshot.version,
          kind: widget.operation,
          values: Map.unmodifiable(commandValues(rows)),
        );
        reviewSnapshot = c.snapshot;
        plan = planLocal(reviewSnapshot!, reviewed!);
      } else if (await refreshBeforeSaving()) {
        rechecked = true;
      } else {
        await c.store.commit(reviewed!);
        await c.reload();
        await c.store.discardDraft(draftKey);
        await saveEmbeddedSchedule();
        result = c.connected
            ? 'Saved on this device. Server acceptance and downloaded reconciliation are still required.'
            : 'Saved locally.';
      }
    } catch (e) {
      // Stays on Review with everything kept, ready to try again.
      syncing = false;
      syncBlocked = isSyncBlock(e);
      if (reviewed != null && !syncBlocked) {
        try {
          if (await c.store.hasReceipt(id)) {
            await c.reload();
            result = 'The original command is saved. Check synchronization status for connected records.';
          } else {
            reviewed = null;
            plan = null;
          }
        } catch (_) {
          unknown = true;
        }
      }
      if (result == null && !syncBlocked) {
        if (e is LocalRuleException) {
          (problemField, problem) = locateProblem(e);
          if (e.message.contains('negative')) needsConsent = true;
        } else if (e is FormatException) {
          problem = e.message;
          problemField = 'date';
        } else {
          error = 'The save could not be verified. Input and original command identity are retained.';
        }
      }
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

  /// Rules that name no field, and the field each is about, so the problem
  /// shows there in red. The rules' own words stay (DESIGN_SYSTEM §7).
  static const ruleFields = [
    ('active cash account', 'account'),
    ('Payment exceeds remaining scheduled due', 'paymentRow'),
    ('Choose an installment in the current schedule', 'paymentRow'),
    ('Due allocations plus', 'paymentRow'),
    ('Use this debt’s current schedule', 'paymentRow'),
    ('Actual cash must equal', 'amount'),
    ('Debt activity cannot precede', 'date'),
    ('This debt is closed', 'debt'),
    ('Provider payoff must reconcile', 'reduction'),
    ('Classification exceeds', 'reduction'),
    ('Choose an actual payment on this debt', 'payment'),
    ('Confirm the exact provider payoff', 'verified'),
    ('Confirm provider dates', 'verified'),
    ('Confirm the provider adjustment', 'verified'),
    ('Known outstanding principal', 'outstandingPrincipal'),
    ('Review net proceeds', 'withheld'),
    ('Waiver exceeds', 'amount'),
    ('Waiver needs', 'chargeSource'),
    ('This waiver needs', 'waiver'),
    ('Unsupported debt', 'debt'),
  ];

  /// Where a rule's problem belongs, and what to say there. Going below zero
  /// is said in terms of the chosen account, with what it holds.
  (String?, String) locateProblem(LocalRuleException e) {
    if (e.field != null) return (e.field, e.message);
    if (e.message.contains('negative')) {
      final account = c.snapshot.accounts
          .where((a) => a.id == values['account'])
          .firstOrNull;
      return account == null
          ? (null, e.message)
          : (
              'account',
              'This takes ${account.name} below zero. It has ${shownBalance(account.id)}.',
            );
    }
    for (final (text, field) in ruleFields) {
      if (e.message.contains(text)) return (field, e.message);
    }
    return (null, e.message);
  }

  /// An account's balance today, for the eye: hidden amounts stay hidden.
  String shownBalance(String id) => c.amountsHidden
      ? 'Amount hidden'
      : c.amount(c.snapshot.balance(id, through: civilToday()));

  /// Money leaving the chosen account in this form, once it's a valid amount.
  BigInt? get leaving {
    if (!const {
      'debtPayment',
      'debtPayoff',
      'cardPayment',
    }.contains(recordType)) {
      return null;
    }
    try {
      return parsePhp(answer('amount'));
    } on FormatException {
      return null;
    }
  }

  /// Each account's balance under its name, and a warning on the chosen one
  /// if this amount takes it below zero. Saving is still the rules' call.
  Map<String, String> balanceLines(Map<String, String> accounts, String key) {
    final amount = leaving;
    return {
      for (final id in accounts.keys)
        if (id.isNotEmpty)
          id: [
            'Balance ${shownBalance(id)}',
            if (!c.amountsHidden &&
                amount != null &&
                id == values[key] &&
                amount > c.snapshot.balance(id, through: civilToday()))
              'this takes it below zero',
          ].join(' · '),
    };
  }

  /// The problem shows in place (§6); this brings it into view.
  Future<void> showProblem(String message, String? field) async {
    final target = field == null ? null : anchors[field]?.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        alignment: .15,
        duration: const Duration(milliseconds: 250),
      );
    }
  }

  String? problemFor(String key) => errorField == key ? errorMessage : null;

  GlobalKey anchor(String key) => anchors.putIfAbsent(key, () => GlobalKey());

  static const cadenceKeys = [
    'frequency',
    'intervalDays',
    'firstDue',
    'installmentCount',
    'splitMode',
    'installmentAmount',
    'totalAmount',
    'paymentAmounts',
  ];

  /// A new schedule is created from plain answers; the dates are built at
  /// Review and the Review step is the confirmation.
  bool get simpleSchedule =>
      widget.operation == 'debtSchedule' && widget.replacing == null;
  bool get embeddedSchedule =>
      widget.replacing == null &&
      ['debtImport', 'borrowing'].contains(widget.operation) &&
      (values['frequency'] ?? '').isNotEmpty;

  /// How many payments are left, once a usable number has been entered.
  int? get paymentCount {
    final n = int.tryParse(answer('installmentCount'));
    return n != null && n >= 1 && n <= 120 ? n : null;
  }

  /// Cadence inputs appear only when they apply to the answers so far.
  bool visible(FinanceInput input) {
    if (simpleSchedule &&
        const {
          'name',
          'schedule',
          'verified',
          'reference',
          'notes',
          'acknowledge',
          'date',
        }.contains(input.key)) {
      return false;
    }
    const charges = {'recognized_charge', 'rounding_charge'};
    const waivers = {'recognized_waiver', 'rounding_waiver'};
    final kind = values['adjustmentKind'];
    final type = recordType;
    return switch (input.key) {
      'intervalDays' => values['frequency'] == 'custom',
      'firstDue' ||
      'installmentCount' ||
      'splitMode' => (values['frequency'] ?? '').isNotEmpty,
      // Shown under the account it's about, once the rules ask.
      'acknowledge' => false,
      'providerPayoff' => false,
      'account' when type == 'borrowing' => values['fundingUse'] == 'cash',
      'withheld' when type == 'borrowing' => values['fundingUse'] == 'cash',
      'category' when type == 'borrowing' => values['fundingUse'] == 'purchase',
      'chargeType' ||
      'category' when type == 'debtAdjustment' => charges.contains(kind),
      'waiverBasis' when type == 'debtAdjustment' => waivers.contains(kind),
      'chargeSource' when type == 'debtAdjustment' =>
        waivers.contains(kind) && values['waiverBasis'] == 'recognized_charge',
      _ => true,
    };
  }

  /// Log a debt payment asks for the essentials; the rest of the record
  /// comes from its answers (DESIGN_SYSTEM §2 Debts). Corrections keep every
  /// field. The rules still check the whole command, and nothing saves
  /// before Review.
  bool get simplePayment =>
      widget.operation == 'debtPayment' && widget.replacing == null;
  bool needsConsent = false;

  static const coverageChoices = [
    PickerOption(
      value: 'confirmed_total',
      label: 'All of it lowers what I owe',
      description: 'Your lender confirmed the whole amount goes to your debt.',
    ),
    PickerOption(
      value: 'unresolved',
      label: "I don't know the breakdown yet",
      description: 'Logs the payment now. You can break it down later.',
    ),
    PickerOption(
      value: 'known_components',
      label: 'I have the exact breakdown',
      description: 'Enter what went to your debt, interest and fees.',
    ),
  ];

  /// Debts that can take a payment; a closed one can't.
  List<DebtProgress> get payable => [
    for (final d in overviewDebtProgress(c.snapshot, civilToday()))
      if (!d.closed) d,
  ];

  DebtProgress? get paymentDebt =>
      payable.where((d) => d.debt.id == values['debt']).firstOrNull;

  /// Extra due dates, each `id,amount`, past the one in "Which payment?".
  List<(String, String)> get extraRows => [
    for (final line in (values['extraRows'] ?? '').split('\n'))
      if (line.contains(',')) (line.split(',').first, line.split(',').last),
  ];

  void setExtraRows(List<(String, String)> rows) {
    values['extraRows'] = [for (final r in rows) '${r.$1},${r.$2}'].join('\n');
    retain();
  }

  BigInt optionalAmount(String key) {
    final text = answer(key);
    return text.isEmpty
        ? BigInt.zero
        : amountOf(text, 'Enter an amount like 1500.00.', field: key);
  }

  /// What each due date gets out of [contractual]. The row in "Which
  /// payment?" takes what's left on it; extra dates take what the user
  /// typed. Nothing else is applied: the rest stays unapplied.
  ({List<(String, BigInt)> rows, BigInt unapplied}) paymentSplit(
    BigInt contractual,
  ) {
    final open = {
      for (final (row, left)
          in paymentDebt?.due.open ?? const <(FinanceScheduleRow, BigInt)>[])
        row.id: left,
    };
    var rest = contractual;
    final extras = [
      for (final (i, (id, amount)) in extraRows.indexed)
        if (id.isNotEmpty)
          (
            id,
            amountOf(
              amount,
              'Enter an amount like 1500.00.',
              field: 'extra-$i',
            ),
          ),
    ];
    for (final (_, amount) in extras) {
      rest -= amount;
    }
    final id = values['paymentRow'] ?? '';
    final left = open[id];
    final rows = <(String, BigInt)>[];
    if (left != null && rest > BigInt.zero) {
      final take = rest < left ? rest : left;
      rows.add((id, take));
      rest -= take;
    }
    return (rows: [...rows, ...extras], unapplied: rest);
  }

  /// The record's other fields, from the answers.
  void paymentValues(Map<String, String> v) {
    final amount = amountOf(
      answer('amount'),
      'Enter the amount you paid, like 2000.00.',
      field: 'amount',
    );
    final external = optionalAmount('externalFee');
    final contractual = amount - external;
    final split = paymentSplit(contractual);
    final debt = paymentDebt;
    v['externalFee'] = phpDecimal(external);
    v['allocations'] = [
      for (final (id, value) in split.rows) '$id,${phpDecimal(value)}',
    ].join('\n');
    v['scheduleSource'] = split.rows.isEmpty ? '' : debt!.due.schedule!.id;
    v['unapplied'] = phpDecimal(split.unapplied);
    if (answer('name').isEmpty && debt != null) {
      v['name'] = 'Payment · ${debt.debt.title}';
    }
    switch (answer('certainty')) {
      case 'confirmed_total':
        v['reduction'] = phpDecimal(contractual);
        v['clearing'] = v['interest'] = v['fee'] = '0.00';
        v['principalReduction'] = v['reductionSources'] = '';
      case 'unresolved':
        v['clearing'] = phpDecimal(contractual);
        v['reduction'] = v['interest'] = v['fee'] = '0.00';
        v['principalReduction'] = v['reductionSources'] = '';
      default:
        for (final key in ['reduction', 'interest', 'fee', 'clearing']) {
          v[key] = phpDecimal(optionalAmount(key));
        }
    }
  }

  Map<String, String> get paymentDetails {
    final v = reviewed?.values ?? const <String, String>{};
    final applied = (v['allocations'] ?? '')
        .split('\n')
        .where((l) => l.isNotEmpty);
    final unapplied = v['unapplied'] ?? '0.00';
    return {
      'Applied to': applied.isEmpty
          ? 'Not tied to a due date'
          : [
              for (final line in applied)
                '${line.split(',').first}: ${c.amount(parsePhp(line.split(',').last))}',
            ].join(' · '),
      if (parsePhp(unapplied) > BigInt.zero)
        'Stays unapplied': c.amount(parsePhp(unapplied)),
      'What it covers': coverageChoices
          .firstWhere(
            (o) => o.value == v['certainty'],
            orElse: () => coverageChoices[1],
          )
          .label,
      if ((v['reference'] ?? '').isNotEmpty)
        'Lender reference': v['reference']!,
      if ((v['notes'] ?? '').isNotEmpty) 'Notes': v['notes']!,
    };
  }

  TextEditingController controllerFor(String key) => fields.putIfAbsent(
    key,
    () => TextEditingController(text: values[key] ?? ''),
  );

  void changed(String key, String value) {
    values[key] = value;
    if (errorField == key) errorField = errorMessage = null;
    retain();
  }

  Widget amountInput(
    String key,
    String label, {
    String? helper,
    String? info,
    bool required = false,
    bool signed = false,
  }) => Padding(
    key: anchor(key),
    padding: gapAbove(info: info != null),
    child: AmountField(
      key: ValueKey('native-$key'),
      label: label,
      controller: controllerFor(key),
      required: required,
      signed: signed,
      helper: helper,
      info: info,
      errorText: problemFor(key),
      onChanged: (x) => changed(key, x),
    ),
  );

  /// The space above a field; the form's first field has none.
  EdgeInsets gapAbove({bool info = false}) {
    final first = firstField;
    firstField = false;
    return EdgeInsets.only(
      top: first ? 0 : CompactForm.gapBefore(context, info: info),
    );
  }

  bool firstField = true;

  Widget textInput(
    String key,
    String label, {
    String? helper,
    String? info,
    bool required = false,
    int lines = 1,
    FieldInput? input,
  }) => Padding(
    key: anchor(key),
    padding: gapAbove(info: info != null),
    child: HelpTextField(
      key: ValueKey('native-$key'),
      label: label,
      input: input,
      controller: controllerFor(key),
      helper: helper,
      info: info,
      required: required,
      maxLines: lines,
      errorText: problemFor(key),
      onChanged: (x) => changed(key, x),
    ),
  );

  Widget pickInput(
    String key,
    String label,
    Map<String, String> options, {
    bool required = false,
    String? helper,
    String? info,
    String? disabledReason,
    ValueChanged<String>? onChanged,
    Map<String, String> descriptions = const {},
  }) => Padding(
    key: anchor(key),
    padding: gapAbove(info: info != null),
    child: OptionPicker<String>(
      key: ValueKey('native-select-$key'),
      label: label,
      style: PickerStyle.dropdown,
      required: required,
      helper: helper,
      info: info,
      disabledReason: disabledReason,
      errorText: problemFor(key),
      value: values[key],
      options: [
        for (final e in options.entries)
          PickerOption(
            value: e.key,
            label: e.value,
            description: descriptions[e.key],
          ),
      ],
      onChanged: disabledReason != null
          ? null
          : (x) {
              changed(key, x);
              onChanged?.call(x);
            },
    ),
  );

  Widget dateInput(
    String key,
    String label, {
    String? helper,
    bool required = false,
  }) => Padding(
    key: anchor(key),
    padding: gapAbove(),
    child: DateField(
      key: ValueKey('native-$key'),
      label: label,
      required: required,
      helper: helper,
      value: DateTime.tryParse(answer(key)),
      errorText: problemFor(key),
      onChanged: (d) =>
          changed(key, d == null ? '' : d.toIso8601String().substring(0, 10)),
    ),
  );

  /// Shown only once the rules ask for it.
  Widget consentInput() => Padding(
    key: anchor('acknowledge'),
    padding: gapAbove(),
    child: OptionPicker<String>(
      key: const ValueKey('native-select-acknowledge'),
      label: 'This takes the account below zero',
      style: PickerStyle.radio,
      value: answer('acknowledge'),
      options: const [
        PickerOption(
          value: 'true',
          label: 'That is right',
          description: 'Save it with a negative balance.',
        ),
        PickerOption(
          value: 'false',
          label: 'Let me check',
          description: 'Keep the balance as it is for now.',
        ),
      ],
      onChanged: (x) {
        if (errorField == 'account') errorField = errorMessage = null;
        changed('acknowledge', x);
      },
    ),
  );

  static const dateKeys = {
    'date',
    'firstDue',
    'start',
    'end',
    'endExclusive',
    'issued',
    'due',
    'postingDate',
    'targetDate',
    'logicalDate',
    'from',
    'through',
  };

  /// Fields that take one kind of value, besides dates and money.
  static const wholeNumberKeys = {
    'installmentCount',
    'intervalDays',
    'interval',
    'monthDay',
    'count',
  };

  /// Inputs that choose a money account.
  static const accountKeys = {'account', 'fromAccount'};

  bool isAmount(FinanceInput input) =>
      input.options == null &&
      (input.money || (input.lines == 1 && input.label.contains(' PHP')));

  /// A date picker needs no format, and a ₱ field no currency.
  String plainLabel(FinanceInput input) => input.label
      .replaceAll(' · YYYY-MM-DD', '')
      .replaceAll(isAmount(input) ? ' PHP' : '\u0000', '');

  void frequencyChanged(String _) {
    if (values['frequency'] == '') {
      clearCadence([
        'firstDue',
        'intervalDays',
        'installmentAmount',
        'installmentCount',
        'totalAmount',
        'paymentAmounts',
      ]);
      values['splitMode'] = widget.replacing == null ? 'divide' : '';
    } else if (values['frequency'] != 'custom') {
      clearCadence(['intervalDays']);
    }
  }

  /// Payments on the chosen debt that still have no breakdown.
  Map<String, String> breakdownChoices() {
    final debt = debtFor(values['debt']);
    return {
      for (final p in debtPaymentRows(c.snapshot, debt: debt?.actionId))
        if (p.left > BigInt.zero)
          p.record.id:
              '${p.record.title} · ${civilLabel(p.date)} · ${c.amount(p.left)} left',
    };
  }

  String? helpFor(FinanceInput input) {
    if (input.key == 'amount' && recordType == 'debtPayoff') {
      final debt = debtFor(values['debt']);
      if (debt != null) {
        final owed = -financeBalance(
          c.snapshot,
          'debt_liability',
          'debt',
          debt.actionId,
          through: civilToday(),
        );
        return 'What you owe now: ${c.amount(owed)}';
      }
    }
    return input.help;
  }

  Widget fieldFor(FinanceInput input) {
    final key = input.key, label = plainLabel(input);
    if (key == 'acknowledge') return consentInput();
    if (dateKeys.contains(key)) {
      return dateInput(
        key,
        label,
        helper: input.help,
        required: !label.contains('optional'),
      );
    }
    if (input.options != null) {
      final classifying =
          key == 'payment' && recordType == 'debtClassification';
      return pickInput(
        key,
        label,
        classifying ? breakdownChoices() : input.options!,
        required: input.required,
        helper: input.help,
        info: input.info,
        disabledReason: key == 'splitMode' && paymentCount == null
            ? 'Enter how many payments are left first.'
            : null,
        onChanged: key == 'frequency' ? frequencyChanged : null,
        descriptions: accountKeys.contains(key)
            ? balanceLines(input.options!, key)
            : const {},
      );
    }
    if (isAmount(input)) {
      return amountInput(
        key,
        label,
        helper: helpFor(input),
        info: input.info,
        required: input.required,
        signed: input.label.contains('Signed'),
      );
    }
    return textInput(
      key,
      label,
      helper: input.help,
      info: input.info,
      required: input.required,
      lines: input.lines,
      input: wholeNumberKeys.contains(key)
          ? FieldInput.wholeNumber
          : key == 'weekdays'
          ? FieldInput.numberList
          : null,
    );
  }

  /// A problem no field can show.
  List<Widget> formProblem(Iterable<String?> shown) {
    final message = errorMessage;
    return [
      if (message != null && !shown.contains(errorField)) ...[
        InlineNotice(message, tone: NoticeTone.error, live: true),
        const SizedBox(height: Space.md),
      ],
    ];
  }

  List<Widget> formFields() {
    final shown = [
      if (widget.operation != 'financeReversal') ...inputs.where(visible),
      if (widget.replacing != null && !inputs.any((i) => i.key == 'reason'))
        const FinanceInput('reason', 'Why you are changing this'),
    ];
    final more = shown.where((i) => i.more).toList();
    return [
      ...formProblem([
        for (final i in shown) i.key,
        'paymentTotal',
        if (errorField?.startsWith('payment-') ?? false) errorField,
      ]),
      for (final input in shown.where((i) => !i.more)) ...[
        fieldFor(input),
        if (input.key == 'account' && needsConsent) consentInput(),
        if (input.key == 'splitMode' &&
            answer('frequency').isNotEmpty &&
            paymentCount != null)
          answer('splitMode') == 'varied'
              ? paymentAmountFields()
              : divideSummary(),
      ],
      if (more.isNotEmpty) ...[
        SizedBox(height: CompactForm.fieldGap(context)),
        FormMoreDetails(
          open: more.any((i) => i.key == errorField),
          children: [for (final input in more) fieldFor(input)],
        ),
      ],
      if (needsConsent && !shown.any((i) => i.key == 'account')) consentInput(),
    ];
  }

  /// Where the amount goes, as the user changes it.
  Widget paymentPreview() {
    final text = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: CraftTheme.of(context).secondary);
    try {
      final amount = amountOf(answer('amount'), '', field: 'amount');
      final split = paymentSplit(amount - optionalAmount('externalFee'));
      if (split.rows.isEmpty) return const SizedBox.shrink();
      final parts = [
        for (final (id, value) in split.rows) '${c.amount(value)} goes to $id',
        if (split.unapplied > BigInt.zero)
          '${c.amount(split.unapplied)} stays unapplied',
      ];
      return Padding(
        padding: const EdgeInsets.only(top: Space.xs),
        child: Text(
          parts.join(' · '),
          key: const ValueKey('payment-preview'),
          style: text,
        ),
      );
    } on LocalRuleException {
      return const SizedBox.shrink();
    }
  }

  List<Widget> extraRowInputs(Map<String, String> rows) {
    final extras = extraRows;
    return [
      for (final (i, (id, _)) in extras.indexed) ...[
        Padding(
          padding: EdgeInsets.only(top: CompactForm.fieldGap(context)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: OptionPicker<String>(
                  label: 'Also applied to',
                  style: PickerStyle.dropdown,
                  value: id,
                  options: [
                    for (final e in rows.entries)
                      if (e.key.isNotEmpty)
                        PickerOption(value: e.key, label: e.value),
                  ],
                  onChanged: (x) => setExtraRows([
                    for (final (n, row) in extras.indexed)
                      n == i ? (x, row.$2) : row,
                  ]),
                ),
              ),
              const SizedBox(width: Space.sm),
              SizedBox(
                width: Space.xxxl * 3,
                child: AmountField(
                  key: ValueKey('native-extra-$i'),
                  label: 'Amount',
                  controller: controllerFor('extra-$i'),
                  errorText: problemFor('extra-$i'),
                  onChanged: (x) => setExtraRows([
                    for (final (n, row) in extras.indexed)
                      n == i ? (row.$1, x) : row,
                  ]),
                ),
              ),
              AppIconButton(
                icon: Icons.close,
                tooltip: 'Remove this due date',
                onPressed: () {
                  final next = [
                    for (final (n, row) in extras.indexed)
                      if (n != i) row,
                  ];
                  for (final (n, row) in next.indexed) {
                    controllerFor('extra-$n').text = row.$2;
                  }
                  setExtraRows(next);
                },
              ),
            ],
          ),
        ),
      ],
      if (rows.length > extras.length + 1)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CardLink(
            'Add another due date',
            icon: Icons.add,
            onPressed: () => setExtraRows([...extras, ('', '')]),
          ),
        ),
    ];
  }

  List<Widget> paymentFields() {
    final debts = payable;
    final debt = paymentDebt;
    final rows = <String, String>{
      '': 'Not tied to a due date',
      for (final (row, left)
          in debt?.due.open ?? const <(FinanceScheduleRow, BigInt)>[])
        row.id: '${row.id} · ${civilLabel(row.date)} · ${c.amount(left)} left',
    };
    final accounts = {
      for (final a in c.snapshot.accounts.where((a) => !a.archived))
        a.id: a.name,
    };
    final categories = c.categoryChoices('expense');
    final known = answer('certainty') == 'known_components';
    return [
      ...formProblem(paymentShownKeys),
      pickInput(
        'debt',
        'Debt',
        {for (final d in debts) d.debt.id: d.debt.title},
        required: true,
        onChanged: (_) {
          values['paymentRow'] = values['extraRows'] = '';
          setState(() {});
        },
      ),
      pickInput(
        'paymentRow',
        'Which payment?',
        rows,
        helper: 'Only a payment logged against a due date counts toward it.',
        disabledReason: debt == null ? 'Choose the debt first.' : null,
        onChanged: (id) {
          final left = debt?.due.open
              .where((o) => o.$1.id == id)
              .firstOrNull
              ?.$2;
          if (left != null && answer('amount').isEmpty) {
            values['amount'] = controllerFor('amount').text = phpDecimal(left);
          }
          setState(() {});
        },
      ),
      amountInput('amount', 'Amount', required: true),
      paymentPreview(),
      pickInput(
        'account',
        'Paid from',
        accounts,
        required: true,
        descriptions: balanceLines(accounts, 'account'),
      ),
      if (needsConsent) consentInput(),
      dateInput('date', 'Date', required: true),
      Padding(
        key: anchor('certainty'),
        padding: gapAbove(info: true),
        child: OptionPicker<String>(
          key: const ValueKey('native-select-certainty'),
          label: 'What does this payment cover?',
          style: PickerStyle.radio,
          value: answer('certainty'),
          info: 'Only choose the first if your lender confirmed it. If you are not sure, log it now and break it down later.',
          errorText: problemFor('certainty'),
          options: coverageChoices,
          onChanged: (x) => setState(() => changed('certainty', x)),
        ),
      ),
      if (known) ...[
        amountInput('reduction', 'Lowers what you owe'),
        amountInput(
          'principalReduction',
          'Part of that which is principal',
          helper: 'Leave this blank if your lender did not say.',
        ),
        amountInput('interest', 'New interest'),
        amountInput('fee', 'New fee'),
        pickInput('interestCategory', 'Interest category', categories),
        pickInput('feeCategory', 'Fee category', categories),
        amountInput('clearing', 'Still without a breakdown'),
      ],
      SizedBox(height: CompactForm.fieldGap(context)),
      FormMoreDetails(
        open: const {
          'externalFee',
          'reference',
          'notes',
          'name',
        }.contains(errorField),
        children: [
          amountInput(
            'externalFee',
            'Fee you paid to send it',
            helper: 'For example a transfer fee. It counts as spending.',
          ),
          ...extraRowInputs(rows),
          if (known)
            textInput(
              'reductionSources',
              'Charges this lowers',
              lines: 4,
              helper: 'One per line: the charge record, then the amount.',
            ),
          textInput('reference', 'Lender reference'),
          textInput('notes', 'Notes', lines: 3),
          textInput(
            'name',
            'Description',
            helper: 'Leave this blank to use "Payment · ‹debt›".',
          ),
        ],
      ),
    ];
  }

  /// The fields that can show their own error.
  Set<String?> get paymentShownKeys => {
    'debt',
    'paymentRow',
    'amount',
    'account',
    'date',
    'certainty',
    'externalFee',
    'reference',
    'notes',
    'name',
    if (answer('certainty') == 'known_components') ...[
      'reduction',
      'principalReduction',
      'interest',
      'fee',
      'clearing',
    ],
  };

  void clearCadence(Iterable<String> keys) {
    for (final key in keys) {
      values[key] = '';
      fields[key]?.text = '';
    }
    if (keys.contains('paymentAmounts')) {
      for (final entry in fields.entries) {
        if (entry.key.startsWith('payment-')) entry.value.text = '';
      }
    }
  }

  String answer(String key) => (values[key] ?? '').trim();

  List<String> get payments => (values['paymentAmounts'] ?? '').split('\n');

  BigInt amountOf(String text, String message, {String? field}) {
    try {
      return parsePhp(text.trim());
    } on FormatException {
      reject(message, field: field);
    }
  }

  LocalRevision? debtFor(String? ref) => ref == null || ref.isEmpty
      ? null
      : c.snapshot.current
            .where((r) => r.id == ref || r.actionId == ref)
            .firstOrNull;

  /// The exact amount the schedule must add up to: what is still owed on an
  /// existing debt, or the recognized liability being entered right now.
  BigInt debtTarget() {
    if (simpleSchedule) {
      final debt = debtFor(values['debt']);
      if (debt == null) {
        reject('Choose the debt this schedule belongs to.', field: 'debt');
      }
      final owed = -financeBalance(
        c.snapshot,
        'debt_liability',
        'debt',
        debt.actionId,
        through: civilToday(),
      );
      if (owed <= BigInt.zero) {
        reject(
          'This debt has nothing left to pay, so there is nothing to schedule.',
          field: 'debt',
        );
      }
      return owed;
    }
    final amount = amountOf(
      answer('amount'),
      'Enter the debt amount above first.',
      field: 'amount',
    );
    if (amount <= BigInt.zero) {
      reject('Enter the debt amount above first.', field: 'amount');
    }
    final fee = answer('financedFee').isEmpty
        ? BigInt.zero
        : amountOf(
            answer('financedFee'),
            'Enter the financed fee like 0.00.',
            field: 'financedFee',
          );
    return widget.operation == 'borrowing' ? amount + fee : amount;
  }

  /// Installment rows from the plain answers, with plain-language errors.
  String cadenceRows() {
    if (answer('frequency').isEmpty) {
      reject('Choose how often you pay.', field: 'frequency');
    }
    if (answer('frequency') == 'custom') {
      try {
        debtIntervalDays(answer('intervalDays'));
      } on LocalRuleException catch (e) {
        reject(e.message, field: 'intervalDays');
      }
    }
    if (answer('firstDue').isEmpty) {
      reject('Enter the date of your next payment.', field: 'firstDue');
    }
    try {
      civilDate(answer('firstDue'));
    } on FormatException catch (e) {
      reject(e.message, field: 'firstDue');
    }
    final count = paymentCount;
    if (count == null) {
      reject(
        'Enter how many payments are left, a whole number from 1 to 120.',
        field: 'installmentCount',
      );
    }
    final split = answer('splitMode');
    if (split.isEmpty) {
      reject('Choose how the payments are split.', field: 'splitMode');
    }
    final target = debtTarget();
    List<BigInt> amounts;
    if (split == 'varied') {
      final entered = payments;
      amounts = [
        for (var i = 0; i < count; i++)
          amountOf(
            i < entered.length ? entered[i] : '',
            'Enter the amount for payment ${i + 1}, like 2000.00.',
            field: 'payment-$i',
          ),
      ];
      for (var i = 0; i < count; i++) {
        if (amounts[i] <= BigInt.zero) {
          reject(
            'Payment ${i + 1} must be more than zero.',
            field: 'payment-$i',
          );
        }
      }
      final sum = sumMinor(amounts);
      if (sum != target) {
        reject(
          'The payments add up to ${c.amount(sum)}, but the debt is ${c.amount(target)}. The payments must add up to the debt exactly.',
          field: 'paymentTotal',
        );
      }
    } else {
      try {
        amounts = debtSplitAmounts(target, count);
      } on LocalRuleException catch (e) {
        reject(e.message, field: 'installmentCount');
      }
    }
    try {
      return debtScheduleRows(
        firstDue: answer('firstDue'),
        frequency: answer('frequency'),
        amounts: amounts,
        intervalDays: answer('intervalDays'),
      );
    } on FormatException catch (e) {
      reject(e.message, field: 'firstDue');
    }
  }

  String previewRows(String rows) {
    final list = financeSchedule(rows);
    final amounts = list.map((r) => r.amount).toList();
    final total = sumMinor(amounts);
    final same = amounts.every((a) => a == amounts.first);
    final lo = amounts.reduce((a, b) => a < b ? a : b);
    final hi = amounts.reduce((a, b) => a > b ? a : b);
    final every = switch (answer('frequency')) {
      'custom' => 'every ${answer('intervalDays')} days',
      final f => f,
    };
    final money = same
        ? '${list.length} payments of ${c.amount(amounts.first)}'
        : '${list.length} payments totaling ${c.amount(total)} (${c.amount(lo)} to ${c.amount(hi)} each)';
    return '$money · $every · first ${list.first.date} · last ${list.last.date}';
  }

  /// Only the cadence facts worth keeping on the schedule record.
  Map<String, String> cadenceStored(String rows) {
    final split = answer('splitMode');
    return {
      'frequency': answer('frequency'),
      'firstDue': answer('firstDue'),
      'splitMode': split,
      'installmentAmount': split == 'divide'
          ? phpDecimal(financeSchedule(rows).first.amount)
          : '',
      if (answer('frequency') == 'custom')
        'intervalDays': answer('intervalDays'),
    };
  }

  Map<String, String> commandValues(String? rows) {
    final v = Map<String, String>.from(values)
      ..remove('installmentCount')
      ..remove('totalAmount')
      ..remove('paymentAmounts')
      ..remove('paymentRow')
      ..remove('extraRows');
    if (simplePayment) paymentValues(v);
    if (recordType == 'debtPayoff') v['providerPayoff'] = answer('amount');
    if (widget.replacing == null && answer('name').isEmpty) {
      final debt = debtFor(values['debt']);
      if (debt != null && widget.operation == 'debtPayoff') {
        v['name'] = 'Payoff · ${debt.title}';
      } else if (debt != null && widget.operation == 'debtClassification') {
        v['name'] = 'Breakdown · ${debt.title}';
      }
    }
    if (widget.replacing == null &&
        ['debtImport', 'borrowing'].contains(widget.operation)) {
      v.removeWhere((k, _) => cadenceKeys.contains(k));
    } else if (simpleSchedule) {
      final debt = debtFor(values['debt']);
      if (debt == null) {
        reject('Choose the debt this schedule belongs to.', field: 'debt');
      }
      final today = civilToday();
      v['schedule'] = rows!;
      v['verified'] = 'true';
      v['reference'] = 'Entered by me';
      v['name'] = '${debt.title} payment schedule';
      v['date'] = debt.date.compareTo(today) > 0 ? debt.date : today;
      v['acknowledge'] = 'false';
      v.addAll(cadenceStored(rows));
    } else if (answer('frequency').isNotEmpty &&
        answer('splitMode').isNotEmpty &&
        answer('splitMode') != 'equal') {
      v['installmentAmount'] = '';
    }
    return v;
  }

  /// The schedule is its own immutable record, saved right after the debt.
  Future<void> saveEmbeddedSchedule() async {
    final rows = embeddedRows;
    if (rows == null) return;
    scheduleFailed = false;
    try {
      // The new debt is still waiting to sync, and a schedule needs the
      // latest records.
      if (c.connected) {
        await c.syncLatest?.call();
        await c.reload();
      }
      final schedule = LocalCommand(
        id: newLocalId(),
        owner: c.store.owner,
        expectedVersion: c.snapshot.version,
        kind: 'debtSchedule',
        values: {
          'name': '${values['name']} payment schedule',
          'debt': id,
          'schedule': rows,
          'verified': 'true',
          'reference': 'Entered by me',
          'date': answer('date'),
          'acknowledge': 'false',
          'debtComponentContract': '1',
          ...cadenceStored(rows),
        },
      );
      planLocal(c.snapshot, schedule);
      await c.store.commit(schedule);
      await c.reload();
      scheduleNote = 'Payment schedule saved: $schedulePreview.';
    } catch (e) {
      scheduleFailed = true;
      final why = isSyncBlock(e)
          ? 'it needs a connection to check your latest records.'
          : e is LocalRuleException
          ? e.message
          : e is FormatException
          ? e.message
          : 'it could not be verified';
      scheduleNote =
          'The debt was saved, but its payment schedule was not: $why '
          'Open the debt in Debts and choose Set schedule.';
    }
  }

  /// One amount per payment, labeled with the date it falls on.
  Widget paymentAmountFields() {
    final count = paymentCount;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(
      color: CraftTheme.of(context).secondary,
    );
    List<String>? dates;
    if (count != null) {
      try {
        dates = [
          for (var i = 0; i < count; i++)
            debtOccurrence(
              answer('firstDue'),
              answer('frequency'),
              i,
              intervalDays: answer('intervalDays'),
            ),
        ];
      } on FormatException {
        dates = null;
      } on LocalRuleException {
        dates = null;
      }
    }
    final top = EdgeInsets.only(top: CompactForm.fieldGap(context));
    if (count == null || dates == null) {
      return Padding(
        padding: top,
        child: Text(
          'Enter the next payment date and how many payments are left, and a box for each payment will appear here.',
          style: muted,
        ),
      );
    }
    BigInt? target;
    try {
      target = debtTarget();
    } on LocalRuleException {
      target = null;
    }
    final entered = payments;
    var total = BigInt.zero, filled = 0;
    for (var i = 0; i < count; i++) {
      final amount = i < entered.length ? entered[i].trim() : '';
      try {
        total += parsePhp(amount);
        filled++;
      } on FormatException {
        // Counted as not yet entered.
      }
    }
    final totalProblem = problemFor('paymentTotal');
    final error = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: top,
          child: Text(
            target == null
                ? 'Enter the amount for each payment. Together they must add up to the whole debt.'
                : 'Enter the amount for each payment. Together they must add up to the whole debt of ${c.amount(target)}.',
            style: muted,
          ),
        ),
        for (var i = 0; i < count; i++)
          Padding(
            key: anchor('payment-$i'),
            padding: top,
            child: AmountField(
              key: ValueKey('native-payment-$i'),
              label: 'Payment ${i + 1} · due ${civilLabel(dates[i])}',
              controller: fields.putIfAbsent(
                'payment-$i',
                () => TextEditingController(
                  text: i < entered.length ? entered[i] : '',
                ),
              ),
              errorText: problemFor('payment-$i'),
              onChanged: (x) {
                final list = payments.toList();
                while (list.length <= i) {
                  list.add('');
                }
                list[i] = x.trim();
                values['paymentAmounts'] = list.join('\n');
                if (errorField == 'payment-$i' ||
                    errorField == 'paymentTotal') {
                  errorField = errorMessage = null;
                }
                retain();
              },
            ),
          ),
        Padding(
          key: anchor('paymentTotal'),
          padding: top,
          child: Text(
            '$filled of $count amounts entered · total ${c.amount(total)}'
            '${target == null
                ? ''
                : total == target
                ? ' · adds up to the debt'
                : total < target
                ? ' · ${c.amount(target - total)} still to assign'
                : ' · ${c.amount(total - target)} over the debt'}',
            style: text.titleSmall?.copyWith(
              color: totalProblem != null ? error : null,
            ),
          ),
        ),
        if (totalProblem != null)
          Text(totalProblem, style: text.bodySmall?.copyWith(color: error)),
      ],
    );
  }

  /// What "divide the debt evenly" will do, from the debt's own amount.
  Widget divideSummary() {
    final count = paymentCount;
    String text;
    try {
      final target = debtTarget();
      final parts = debtSplitAmounts(target, count!);
      text = parts.first == parts.last
          ? 'Your debt of ${c.amount(target)} will be paid in ${parts.length} equal payments of ${c.amount(parts.first)}.'
          : 'Your debt of ${c.amount(target)} will be paid in ${parts.length} payments of ${c.amount(parts.first)}, with the last payment ${c.amount(parts.last)} so the total is exact.';
    } on LocalRuleException catch (e) {
      text = e.message;
    }
    return Padding(
      padding: EdgeInsets.only(top: CompactForm.fieldGap(context)),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: CraftTheme.of(context).secondary),
      ),
    );
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    firstField = true;
    return FormExitGuard(
      dirty: dirty && result == null,
      busy: busy || loading || unknown,
      keepDraft: () async {
        await writes;
        if (draftFailed) throw StateError('Draft not saved');
      },
      child: CompactForm(
        child: SectionPage(
          title: widget.title,
          caption: loading || result != null
              ? null
              : reviewed == null
              ? 'Step 1 of 2 · Details · * Required'
              : 'Step 2 of 2 · Review',
          maxWidth: Space.formMaxWidth,
          child: SurfaceCard(child: body()),
        ),
      ),
    );
  }

  /// Windows: end-aligned, the primary rightmost. Android: full width.
  Widget actions(Widget primary, [Widget? secondary]) => isDesktop(context)
      ? Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (secondary != null) ...[
              secondary,
              const SizedBox(width: Space.sm),
            ],
            primary,
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [primary, ?secondary],
        );

  Widget body() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (loading)
        const LinearProgressIndicator()
      else if (result != null) ...[
        FormStatus(
          title: '${widget.title} saved',
          message: 'Saved securely on this device.',
          tone: NoticeTone.success,
        ),
        if (scheduleNote != null)
          FormStatus(
            title: scheduleFailed ? 'Schedule not saved' : 'Schedule saved',
            message: scheduleNote!,
            tone: scheduleFailed ? NoticeTone.warning : NoticeTone.success,
          ),
        if (c.connected) FormSyncStatus(state: c.synchronizationStates[id]),
        if (plan != null)
          FinancialReview(
            plan: plan!,
            snapshot: reviewSnapshot!,
            amount: c.amount,
            hidden: c.amountsHidden,
            commandId: id,
            details: reviewDetails,
            quietNotes: nativeDebtCommands.contains(recordType),
          ),
        if (plan == null)
          FormEvidence(children: [SelectableText('Original command: $id')]),
        SizedBox(height: CompactForm.groupGap(context)),
        actions(
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ] else ...[
        if (error != null)
          FormStatus(
            title: unknown
                ? 'The result is uncertain'
                : draftFailed
                ? 'Draft needs attention'
                : 'Could not save',
            message: unknown
                ? '$error Reopen this profile to inspect the original command before submitting changed values.'
                : error!,
            tone: unknown || draftFailed
                ? NoticeTone.warning
                : NoticeTone.error,
          ),
        if (busy)
          FormStatus(
            title: syncing
                ? 'Checking your latest records\u2026'
                : 'Saving\u2026',
            message: 'Keep this form open while the operation completes.',
            busy: true,
          ),
        if (reviewed == null)
          ...(simplePayment ? paymentFields() : formFields())
        else ...[
          FinancialReview(
            plan: plan!,
            snapshot: reviewSnapshot!,
            amount: c.amount,
            hidden: c.amountsHidden,
            commandId: id,
            details: reviewDetails,
            quietNotes: nativeDebtCommands.contains(recordType),
          ),
          if (schedulePreview != null) ...[
            SizedBox(height: CompactForm.fieldGap(context)),
            InlineNotice(
              'Payment schedule to save: $schedulePreview.\nCheck these dates and amounts match your loan agreement or lender statement. A payment only counts toward a due date when you log it against that date.',
            ),
          ],
          if (c.connected) ...[
            SizedBox(height: CompactForm.fieldGap(context)),
            const InlineNotice(
              'Connected changes remain pending until server acceptance and complete downloaded reconciliation.',
            ),
          ],
          if (syncBlocked || rechecked || needsLatest)
            SizedBox(height: CompactForm.fieldGap(context)),
          if (syncBlocked)
            const InlineNotice(
              syncBlockedMessage,
              title: syncBlockedTitle,
              tone: NoticeTone.warning,
              live: true,
            )
          else if (rechecked)
            const InlineNotice(
              'Syncing brought in newer records, so this review was updated. Check it again, then save.',
              title: 'Your records changed',
              tone: NoticeTone.warning,
              live: true,
            )
          else if (needsLatest)
            const InlineNotice(
              'Saving this checks your latest records first, so it needs a connection.',
            ),
        ],
        SizedBox(height: CompactForm.groupGap(context)),
        actions(
          FilledButton(
            key: const ValueKey('native-submit'),
            onPressed: busy || draftFailed || unknown ? null : save,
            child: Text(
              busy
                  ? 'Saving…'
                  : reviewed == null
                  ? 'Review'
                  : syncBlocked
                  ? 'Sync and save'
                  : 'Save reviewed values',
            ),
          ),
          reviewed == null
              ? null
              : TextButton(
                  onPressed: busy || unknown
                      ? null
                      : () => setState(() {
                          reviewed = null;
                          plan = null;
                        }),
                  child: const Text('Edit'),
                ),
        ),
        if (unknown)
          FormEvidence(children: [SelectableText('Original command: $id')]),
      ],
    ],
  );
}

class NativeCardsScreen extends StatefulWidget {
  const NativeCardsScreen({super.key, required this.controller});
  final LocalFinancialController controller;
  @override
  State<NativeCardsScreen> createState() => _NativeCardsScreenState();
}

class _NativeCardsScreenState extends State<NativeCardsScreen> {
  LocalFinancialController get controller => widget.controller;
  int page = 0;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final s = controller.snapshot;
      final records = s.current
          .where((r) => financeType(r) == 'creditCard')
          .toList();
      final currentPage = page.clamp(
        0,
        ((records.length + 11) ~/ 12 - 1).clamp(0, 100000),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading('Credit cards'),
          const Text(
            'Keep purchases, payments and provider statements together.',
          ),
          const SizedBox(height: 20),
          NativeWorkflowGroups(
            controller: controller,
            groups: const [
              (
                'Cards & payments',
                'Manage a card and record money paid to its provider.',
                Icons.credit_card_outlined,
                {
                  'creditCard': 'Add credit card',
                  'cardPayment': 'Pay credit card',
                  'cardAuthorization': 'Pending authorization',
                  'cardRefund': 'Card refund',
                  'cardFee': 'Card fee',
                  'cardInterest': 'Card interest',
                },
              ),
              (
                'Statements',
                'Compare provider evidence with recorded activity.',
                Icons.description_outlined,
                {
                  'statement': 'Record statement',
                  'statementLink': 'Link statement activity',
                  'cardAllocation': 'Allocate payment / credit',
                },
              ),
              (
                'Installments',
                'Keep scheduled amounts separate from actual payments.',
                Icons.calendar_month_outlined,
                {
                  'installment': 'Installment plan',
                  'installmentApplication': 'Apply installment payment',
                },
              ),
            ],
          ),
          const WorkspaceHelp(
            title: 'How card balances work',
            text: 'Posted liability, provider statements and cash payments have separate meanings. Card credit and available credit are not liquid money.',
          ),
          if (!s.current.any((r) => financeType(r) == 'creditCard'))
            const WorkspaceEmpty(
              title: 'Your cards, clearly accounted for',
              message: 'Add a credit card above to track its outstanding balance, statements and payments.',
              icon: Icons.credit_card_outlined,
            ),
          for (final card in records.skip(currentPage * 12).take(12)) ...[
            SectionHeading(card.title),
            Builder(
              builder: (context) {
                final liability = -financeBalance(
                  s,
                  'card_liability',
                  'card',
                  card.actionId,
                  through: civilToday(),
                );
                final limit = card.values['limit']!.isEmpty
                    ? null
                    : signedPhp(card.values['limit']!);
                final used = liability > BigInt.zero ? liability : BigInt.zero;
                return WorkspacePanel(
                  title: card.values['issuer'],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WorkspaceGrid(
                        children: [
                          ValueBlock(
                            liability < BigInt.zero
                                ? 'CARD CREDIT'
                                : 'POSTED OUTSTANDING',
                            '${controller.decimal(liability.abs())} PHP',
                            'Through today - separate from liquid money',
                          ),
                          ValueBlock(
                            'AVAILABLE CREDIT',
                            limit == null
                                ? 'Not recorded'
                                : '${controller.decimal(limit - liability)} PHP',
                            'Estimate based on recorded limit and liability',
                          ),
                        ],
                      ),
                      WorkspaceHelp(
                        title: 'Credit utilization',
                        text: limit == null
                            ? 'No credit limit recorded.'
                            : 'Utilization: ${limit == BigInt.zero ? 'undefined for zero limit' : '${controller.amountsHidden ? 'hidden' : used * BigInt.from(10000) ~/ limit} basis points'}. Available credit is not cash.',
                      ),
                    ],
                  ),
                );
              },
            ),
            for (final statement in s.current.where(
              (r) =>
                  financeType(r) == 'statement' &&
                  r.values['card'] == card.actionId,
            ))
              FinancialLine(
                statement.title,
                'Due ${statement.values['due']} · historical balance ${controller.decimal(statement.amount)} PHP · minimum ${statement.values['minimum']?.isNotEmpty == true ? '${controller.decimal(signedPhp(statement.values['minimum']!))} PHP' : 'unknown'}\n'
                'Remaining due ${controller.decimal(statement.amount - sumMinor(s.current.where((r) => financeType(r) == 'cardAllocation' && r.date.compareTo(civilToday()) <= 0 && r.values['statement'] == statement.id).map((r) => r.amount)))} PHP. Minimum satisfaction / allocation order not inferred.\n'
                'Recorded balance by provider posting date through ${statement.values['end']}: ${controller.decimal(statementRecordedBalance(s, statement))} PHP; provider difference ${controller.decimal(statement.amount - statementRecordedBalance(s, statement))} PHP. '
                '${s.current.where((r) => financeType(r) == 'statementLink' && r.values['statement'] == statement.id).length} explicitly confirmed activity links; dates do not infer membership. Differences require reviewed source evidence.',
                icon: Icons.description_outlined,
                onTap: () =>
                    openFinanceDetail(context, controller, statement.id),
              ),
          ],
          WorkspacePager(
            count: records.length,
            page: currentPage,
            onPage: (p) => setState(() => page = p),
          ),
          const SectionHeading('Source detail & immutable history'),
          FinancialSourceList(
            controller: controller,
            records: s.revisions.reversed
                .where(
                  (r) =>
                      nativeFinanceCommands.contains(financeType(r)) &&
                      !nativeDebtCommands.contains(financeType(r)) &&
                      !nativePlanningCommands.contains(financeType(r)) &&
                      !nativeRecurrenceCommands.contains(financeType(r)),
                )
                .toList(),
          ),
        ],
      );
    },
  );
}

Future<void> openFinanceDetail(
  BuildContext context,
  LocalFinancialController c,
  String id,
) => openDemoPage<void>(
  context,
  FinancePage(
    title: 'Financial source & history',
    child: ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final r = c.snapshot.revision(id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeading(r.title),
            FinanceNotice(
              '${financeType(r)} · ${r.date} · revision ${r.number}\nOriginal action ${r.actionId}\n'
              '${c.connected ? c.synchronizationStates[r.id] ?? 'Downloaded accepted evidence' : 'Saved locally'}',
            ),
            WorkspacePanel(
              title: 'Recorded details',
              child: Column(
                children: [
                  for (final item in r.values.entries)
                    if (!['financeContract', 'financeType'].contains(item.key))
                      FinancialLine(
                        item.key
                            .replaceAllMapped(
                              RegExp(r'([a-z])([A-Z])'),
                              (m) => '${m[1]} ${m[2]}',
                            )
                            .replaceAll('_', ' '),
                        c.amountsHidden ? 'Hidden' : item.value,
                        icon: Icons.notes_outlined,
                      ),
                ],
              ),
            ),
            if (r.postings.isNotEmpty)
              WorkspacePanel(
                title: 'Ledger effects',
                child: Column(
                  children: [
                    for (final p in r.postings)
                      FinancialLine(
                        p.ledger.replaceAll('_', ' '),
                        p.date,
                        value: '${c.decimal(p.amount)} PHP',
                      ),
                  ],
                ),
              ),
            if (c.snapshot.current.contains(r) &&
                !r.values.containsKey('financeType') &&
                !r.values.containsKey('sharedGroup') &&
                [
                  'expense',
                  'income',
                  'transfer',
                  'refund',
                  'adjustment',
                  'opening',
                ].contains(r.kind))
              Wrap(
                spacing: 8,
                children: [
                  for (final action in [
                    FinancialAction.correction,
                    FinancialAction.reversal,
                  ])
                    TextButton(
                      onPressed: () => openFinancialEditor(
                        context,
                        c,
                        action,
                        sourceId: r.id,
                      ),
                      child: Text(action.label),
                    ),
                ],
              ),
            const SectionHeading('Private supporting-file evidence'),
            for (final file in c.snapshot.revisions.where(
              (f) =>
                  financeType(f) == 'financialFile' &&
                  f.values['sourceRevision'] == r.id,
            ))
              FinancialLine(
                file.title,
                '${file.values['mime']} · ${financialFileDetached(c.snapshot, file.id) ? 'Archived link' : 'Attached'} · original revision retained. Open Money / Files to verify or retrieve device-local bytes.',
                icon: Icons.attach_file,
              ),
            if (c.snapshot.current.contains(r) &&
                nativeFinanceCommands.contains(financeType(r)) &&
                !r.values.containsKey('sharedGroup'))
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => openNativeFinance(
                      context,
                      c,
                      'financeCorrection',
                      'Correct source',
                      replacing: r,
                    ),
                    child: const Text('Correct with reason'),
                  ),
                  TextButton(
                    onPressed: () => openNativeFinance(
                      context,
                      c,
                      'financeReversal',
                      'Reverse source',
                      replacing: r,
                    ),
                    child: const Text('Reverse with reason'),
                  ),
                ],
              ),
            const SectionHeading('Action history'),
            for (final h in c.snapshot.revisions.where(
              (h) => h.actionId == r.actionId,
            ))
              FinancialLine(
                h.title,
                'Revision ${h.number} · ${h.change} · ${h.values['reason'] ?? ''}',
                icon: Icons.history,
                onTap: h.id == id
                    ? null
                    : () => openFinanceDetail(context, c, h.id),
              ),
          ],
        );
      },
    ),
  ),
  'finance/source/$id',
);

class NativeWorkflowGroups extends StatelessWidget {
  const NativeWorkflowGroups({
    super.key,
    required this.controller,
    required this.groups,
  });
  final LocalFinancialController controller;
  final List<(String, String, IconData, Map<String, String>)> groups;
  @override
  Widget build(BuildContext context) => WorkspaceGrid(
    children: [
      for (final group in groups)
        WorkspaceActionGroup(
          title: group.$1,
          description: group.$2,
          icon: group.$3,
          actions: group.$4,
          onSelected: (key) =>
              openNativeFinance(context, controller, key, group.$4[key]!),
        ),
    ],
  );
}
