import '../design_system/theme.dart';
import '../features/finance/presentation/financial_review.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_cards.dart' show civilLabel;
import '../app/overview_data.dart'
    show DebtProgress, addCivilDays, monthEnd, monthStart, overviewDebtProgress;
import 'card_data.dart';
import 'debt_data.dart' show debtPaymentRows;
import 'form_mechanics.dart';
import 'money_details.dart' show openMoneyRecord;
import '../design_system/kit/kit.dart'
    show
        AmountField,
        AppIconButton,
        CardLink,
        CompactForm,
        DateField,
        FieldInput,
        FormMoreDetails,
        InlineNotice,
        OptionPicker,
        PickerOption,
        PickerStyle,
        SectionPage,
        SurfaceCard;
import 'planning_data.dart' show lastDay;
import '../features/finance/presentation/financial_widgets.dart';
import '../local/finance_domain.dart';
import '../local/local_finance_controller.dart';
import '../p0/exact_money.dart';

/// Rules that name no field, and the field each is about, so the problem
/// shows there in red. A test holds these to the rules' own words.
const nativeRuleFields = [
  ('Choose an active account', 'account'),
  ('on this payment or still due', 'amount'),
  ('more than is left on this payment', 'paymentRow'),
  ('Choose a payment in the current schedule', 'paymentRow'),
  ('applied to due dates', 'paymentRow'),
  ('Choose a payment from this debt’s current schedule', 'paymentRow'),
  ('The amount must equal what lowers your debt', 'amount'),
  ('on or after the day this debt started', 'date'),
  ('This debt is closed', 'debt'),
  ('The payoff amount must equal', 'reduction'),
  ('more than is left to break down', 'reduction'),
  ('Choose a payment logged on this debt', 'payment'),
  ('Confirm the payoff amount', 'verified'),
  ('Confirm these dates and amounts', 'verified'),
  ('Confirm this charge or waiver', 'verified'),
  ('Principal left can’t be more', 'outstandingPrincipal'),
  ('fee taken out up front must be less', 'withheld'),
  ('A waiver can’t be more', 'amount'),
  ('Choose an unpaid charge on this debt', 'chargeSource'),
  ('This waiver needs', 'waiver'),
  ('isn’t supported here', 'debt'),
  ('You already have a card with this name', 'name'),
  ('the day this card starts in Salapiya', 'date'),
  ('The date it posted can’t be before', 'postingDate'),
  ('more than is left to refund in this category', 'amount'),
  ('the period ends by the statement date', 'end'),
  ('The minimum due can’t be more', 'minimum'),
  ('Confirm this matches your statement', 'verified'),
  ('isn’t already matched to a statement', 'activity'),
  ('Confirm this is on the statement', 'verified'),
  ('Choose a statement and a payment on this card', 'date'),
  ('Confirm your card issuer applied it', 'verified'),
  ('Choose a purchase on this card', 'purchase'),
  ('Enter principal, interest and fee together', 'principal'),
  ('must add up to the plan’s total', 'principal'),
  ('This purchase already has an installment plan', 'purchase'),
  ('Choose a plan and a matched payment', 'plan'),
  ('Choose a payment in this plan', 'row'),
  ('on this installment or on the matched payment', 'amount'),
  ('Enter 1 to 120 payments', 'schedule'),
  ('Put each payment on its own line', 'schedule'),
  ('List the payments in date order', 'schedule'),
  ('What’s already paid can’t be more', 'schedule'),
  ('A budget covers 1 to 366 days', 'lastDay'),
  ('Choose what counts as spending', 'basis'),
  ('already has a budget for some of these dates', 'start'),
  ('Choose this goal’s status', 'status'),
  ('Release the money set aside', 'status'),
  ('Enter an amount to move', 'amount'),
  ('Choose two different places', 'amount'),
  ('You can set aside more only', 'amount'),
  ('Choose a time zone from the list', 'timezone'),
  ('Choose dates up to 366 days apart', 'through'),
  ('Enter how often it repeats', 'interval'),
  ('Choose at least one day of the week', 'weekdays'),
  ('Choose a day of the month', 'monthDay'),
  ('The end date can’t be before', 'end'),
  ('Enter 1 to 10,000 times', 'count'),
  ('This start date is too far back', 'start'),
  ('That’s more than 500 dates', 'through'),
  ('Choose a recurring item', 'rule'),
  ('Choose the type of item', 'recurringKind'),
  ('A change starts on a future date', 'start'),
  ('This link was already removed', 'link'),
  ('Only an active recurring item can add dates', 'rule'),
  ('Add this date to Upcoming first', 'logicalDate'),
  ('so it can’t change', 'logicalDate'),
  ('Remove the records linked to this date first', 'amount'),
  ('so it can’t take a record', 'logicalDate'),
  ('Choose income for an income item', 'actual'),
  ('more than this date expects', 'amount'),
];

/// Where a rule's field shows on a form that asks for it differently.
const _shownFields = {'endExclusive': 'lastDay'};

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
    this.signed = false,
    this.optional = false,
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

  /// An amount that may have a minus sign.
  final bool signed;

  /// A date that can stay empty.
  final bool optional;

  /// Goes under "More details".
  final bool more;

  /// The same input under another label, e.g. a shared account field.
  FinanceInput as(
    String label, {
    bool required = false,
    bool more = false,
    String? value,
  }) => FinanceInput(
    key,
    label,
    value: value ?? this.value,
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

/// A record in a picker: its name and date.
String recordChoice(LocalRevision r) =>
    '${r.title} · ${DateField.format(DateTime.parse(r.date))}';

Map<String, String> financeChoices(LocalSnapshot s, Set<String> types) => {
  for (final r in s.current.where((r) => types.contains(financeType(r))))
    r.id: recordChoice(r),
};

/// Each form's title, where Money, Saved drafts and the pages open it.
const formTitles = {
  'creditCard': 'Add a card',
  'cardPayment': 'Log a card payment',
  'cardFee': 'Log a card fee',
  'cardInterest': 'Log card interest',
  'cardRefund': 'Log a card refund',
  'cardAuthorization': 'Log a pending charge',
  'statement': 'Add a statement',
  'statementLink': 'Match activity to a statement',
  'cardAllocation': 'Match a payment to a statement',
  'installment': 'Add an installment plan',
  'installmentApplication': 'Match a payment to an installment',
  'budget': 'Add a budget',
  'savingsGoal': 'Add a goal',
  'reservation': 'Set money aside',
  'savingsReallocation': 'Move to another goal',
  'recurrence': 'Add a recurring item',
  'recurrenceGenerate': 'Add to Upcoming',
  'occurrenceOverride': 'Change or skip a date',
  'recurrenceLink': 'Link a record',
  'recurrenceUnlink': 'Remove a link',
  'fileDetach': 'Archive file link',
};

/// Time zones a recurring item can use.
const recurringTimeZones = [
  'Asia/Manila',
  'Asia/Singapore',
  'Asia/Hong_Kong',
  'Asia/Tokyo',
  'Asia/Dubai',
  'Australia/Sydney',
  'Europe/London',
  'America/New_York',
  'America/Los_Angeles',
  'UTC',
];

List<FinanceInput> financeInputs(
  LocalSnapshot s,
  String op, {
  bool editing = false,
}) {
  FinanceInput ref(
    String key,
    String label,
    Set<String> types, {
    bool required = false,
  }) => FinanceInput(
    key,
    label,
    required: required,
    options: financeChoices(s, types),
  );
  final card = FinanceInput(
    'card',
    'Card',
    required: true,
    options: {
      for (final r in s.current.where((r) => financeType(r) == 'creditCard'))
        r.id: r.title,
    },
  );
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
  final goal = ref('goal', 'Goal', {'savingsGoal'}, required: true);
  final rule = FinanceInput(
    'rule',
    'Recurring item',
    required: true,
    options: {
      for (final r in s.revisions.where((r) => financeType(r) == 'recurrence'))
        r.id: r.title,
    },
  );
  const amount = FinanceInput('amount', 'Amount', required: true, money: true);
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
  FinanceInput confirmed(String label) => FinanceInput(
    'verified',
    label,
    value: 'false',
    options: const {'false': 'Not yet', 'true': 'Yes'},
  );
  final fields = switch (op) {
    'fileDetach' => [
      ref('file', 'File', {'financialFile'}, required: true),
      const FinanceInput('reason', 'Why you’re archiving this link'),
    ],
    'budget' => [
      category.as('Category', required: true, value: ''),
      const FinanceInput('amount', 'Limit', required: true, money: true),
      FinanceInput(
        'start',
        'First day',
        value: monthStart(civilToday()),
        required: true,
      ),
      FinanceInput(
        'lastDay',
        'Last day',
        value: monthEnd(civilToday()),
        required: true,
      ),
      const FinanceInput(
        'basis',
        'What counts',
        value: 'net',
        more: true,
        info:
            'Refunds lower your spending in the first choice, not the second.',
        options: {
          'net': 'Spending after refunds',
          'gross': 'Spending before refunds',
        },
      ),
      const FinanceInput(
        'status',
        'Status',
        value: 'active',
        options: {'active': 'Active', 'archived': 'Archived'},
      ),
    ],
    'savingsGoal' => [
      const FinanceInput(
        'amount',
        'Target amount',
        required: true,
        money: true,
      ),
      const FinanceInput('targetDate', 'Target date', optional: true),
      const FinanceInput(
        'status',
        'Status',
        value: 'active',
        options: {
          'active': 'Active',
          'completed': 'Completed',
          'archived': 'Archived',
        },
      ),
    ],
    'reservation' => [
      goal,
      account.as('Account', required: true),
      const FinanceInput(
        'amount',
        'Total set aside from this account',
        required: true,
        money: true,
        info:
            'The money stays in the account. Enter 0.00 to release all of it.',
      ),
    ],
    'savingsReallocation' => [
      ref('fromGoal', 'From goal', {'savingsGoal'}, required: true),
      FinanceInput(
        'fromAccount',
        'From account',
        required: true,
        options: {for (final a in s.accounts) a.id: a.name},
      ),
      goal.as('To goal', required: true),
      account.as('To account', required: true),
      amount,
    ],
    'recurrence' => [
      const FinanceInput(
        'recurringKind',
        'Type',
        value: 'bill',
        options: {
          'bill': 'Bill',
          'subscription': 'Subscription',
          'income': 'Expected income',
        },
      ),
      const FinanceInput(
        'amount',
        'Expected amount',
        required: true,
        money: true,
      ),
      const FinanceInput(
        'frequency',
        'How often',
        value: 'monthly',
        options: {
          'daily': 'Every day',
          'weekly': 'Every week',
          'monthly': 'Every month',
        },
      ),
      const FinanceInput('weekdays', 'On these days', value: '1'),
      const FinanceInput('monthDay', 'Day of the month', value: '1'),
      const FinanceInput(
        'monthPolicy',
        'In shorter months',
        value: 'last_valid_day',
        options: {
          'last_valid_day': 'Use the last day',
          'skip': 'Skip that month',
        },
      ),
      FinanceInput('start', 'Starts', value: civilToday(), required: true),
      const FinanceInput(
        'interval',
        'Repeat every',
        value: '1',
        more: true,
        help: 'For example, 2 means every second day, week or month.',
      ),
      const FinanceInput('end', 'Ends on', optional: true, more: true),
      const FinanceInput(
        'count',
        'How many times',
        more: true,
        help: 'Leave this blank if it keeps going.',
      ),
      FinanceInput(
        'account',
        'Usual account',
        more: true,
        help: 'Forecasts use it. You still choose an account when you log it.',
        options: {'': 'Not set', ...?account.options},
      ),
      FinanceInput(
        'timezone',
        'Time zone',
        value: 'Asia/Manila',
        more: true,
        options: {for (final z in recurringTimeZones) z: z},
      ),
      const FinanceInput(
        'status',
        'Status',
        value: 'active',
        options: {'active': 'Active', 'archived': 'Archived'},
      ),
    ],
    'recurrenceGenerate' => [
      rule,
      FinanceInput('from', 'From', value: civilToday(), required: true),
      FinanceInput(
        'through',
        'Through',
        value: addCivilDays(civilToday(), 89),
        required: true,
      ),
    ],
    'occurrenceOverride' || 'recurrenceLink' => [
      rule,
      const FinanceInput(
        'logicalDate',
        'Which date',
        required: true,
        options: {},
      ),
      if (op == 'occurrenceOverride')
        const FinanceInput(
          'state',
          'What happened',
          value: 'planned',
          options: {
            'planned': 'It’s still expected',
            'skipped': 'Skip this date',
            'cancelled': 'Cancel this date',
          },
        ),
      amount,
      if (op == 'occurrenceOverride') ...[
        const FinanceInput('due', 'New due date'),
        const FinanceInput('reason', 'Why'),
      ] else
        ref('actual', 'Record', {
          'income',
          'expense',
          'cardPurchase',
        }, required: true),
    ],
    'recurrenceUnlink' => [
      ref('link', 'Link', {'recurrenceLink'}, required: true),
      const FinanceInput('reason', 'Why'),
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
      const FinanceInput('issuer', 'Card issuer', required: true),
      const FinanceInput(
        'limit',
        'Credit limit',
        money: true,
        help: 'Leave this blank if you don’t know it.',
      ),
      const FinanceInput(
        'amount',
        'What you owe on it now',
        value: '0.00',
        required: true,
        money: true,
        signed: true,
        help: 'Use a minus sign if you have a card credit.',
      ),
    ],
    'cardAuthorization' => [card, amount],
    'cardPurchase' || 'cardFee' || 'cardInterest' => [
      card,
      amount,
      category.as(
        'Category',
        required: true,
        value: op == 'cardPurchase' ? null : 'category-fees',
      ),
      FinanceInput(
        'postingDate',
        'Date it posted',
        value: civilToday(),
        more: true,
      ),
    ],
    'cardPayment' => [card, amount, account.as('Paid from', required: true)],
    'cardRefund' => [
      card,
      ref('purchase', 'Purchase', {'cardPurchase'}, required: true),
      amount,
      const FinanceInput('reason', 'Why'),
      category.as('Category', more: true),
    ],
    'statement' => [
      card,
      const FinanceInput(
        'amount',
        'Statement balance',
        required: true,
        money: true,
        signed: true,
      ),
      const FinanceInput(
        'minimum',
        'Minimum due',
        money: true,
        help: 'Leave this blank if your statement doesn’t say.',
      ),
      const FinanceInput('start', 'Period from', required: true),
      const FinanceInput('end', 'Period to', required: true),
      const FinanceInput('issued', 'Statement date', required: true),
      const FinanceInput('due', 'Due date', required: true),
      confirmed('Does this match your statement?'),
    ],
    'statementLink' => [
      card,
      ref('statement', 'Statement', {'statement'}, required: true),
      ref('activity', 'Activity', {
        'cardPurchase',
        'cardPayment',
        'cardRefund',
        'cardFee',
        'cardInterest',
      }, required: true),
      confirmed('Is this on the statement?'),
    ],
    'cardAllocation' => [
      card,
      ref('statement', 'Statement', {'statement'}, required: true),
      ref('payment', 'Payment', {'cardPayment', 'cardRefund'}, required: true),
      amount,
      confirmed('Did your card issuer apply it this way?'),
    ],
    'installment' => [
      card,
      ref('purchase', 'Purchase', {'cardPurchase'}, required: true),
      if (!editing) ...[
        const FinanceInput(
          'splitMode',
          'How much is each payment?',
          value: 'same',
          options: {
            'same': 'The same each time',
            'varied': 'Different amounts',
          },
        ),
        const FinanceInput(
          'installmentAmount',
          'Each payment',
          required: true,
          money: true,
        ),
        const FinanceInput(
          'frequency',
          'How often',
          value: 'monthly',
          options: {
            'weekly': 'Weekly',
            'monthly': 'Monthly',
            'yearly': 'Yearly',
            'custom': 'Custom',
          },
        ),
        const FinanceInput(
          'intervalDays',
          'Every how many days?',
          help: 'For example, type 14 for every two weeks.',
        ),
        const FinanceInput('firstDue', 'First payment', required: true),
        const FinanceInput(
          'installmentCount',
          'How many payments?',
          required: true,
          help: 'Up to 120.',
        ),
      ],
      const FinanceInput(
        'schedule',
        'Payment dates',
        lines: 5,
        help: 'One per line: name, date, amount and, if any, already paid.',
      ),
      confirmed('Do these match your card issuer’s plan?'),
      const FinanceInput('principal', 'Principal', money: true, more: true),
      const FinanceInput('interest', 'Interest', money: true, more: true),
      const FinanceInput('fee', 'Fee', money: true, more: true),
    ],
    'installmentApplication' => [
      card,
      ref('plan', 'Installment plan', {'installment'}, required: true),
      const FinanceInput('row', 'Which payment', required: true, options: {}),
      ref('payment', 'Matched payment', {'cardAllocation'}, required: true),
      amount,
      confirmed('Did your card issuer apply it this way?'),
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
        'creditCard' => 'Card name',
        'budget' => 'Budget name',
        'savingsGoal' => 'Goal name',
        'recurrence' => 'Name',
        _ => 'Description',
      },
      required: namedForms.contains(op),
      more:
          const {'debtClassification', 'debtPayoff'}.contains(op) ||
          (!debtOp && !namedForms.contains(op)),
      help: !debtOp && !namedForms.contains(op)
          ? 'Leave this blank to name it for you.'
          : null,
    ),
    ...fields,
    FinanceInput(
      'date',
      op == 'creditCard' ? 'Balance as of' : 'Date',
      value: civilToday(),
    ),
    FinanceInput(
      'reference',
      debtOp ? 'Lender reference' : 'Reference',
      help: debtOp
          ? null
          : const {'statement', 'installment', 'cardAuthorization'}.contains(op)
          ? 'Leave this blank to use "Entered by me".'
          : 'Needed when your bank or issuer gave you a document.',
      more: quiet || !debtOp,
    ),
    FinanceInput('notes', 'Notes', lines: 3, more: true),
    const FinanceInput(
      'acknowledge',
      'This takes the account below zero',
      value: 'false',
      options: {'false': 'Let me check', 'true': 'That is right'},
    ),
  ];
}

/// Forms where the user names the thing; the others are named for them.
const namedForms = {
  'debtImport',
  'borrowing',
  'creditCard',
  'budget',
  'savingsGoal',
  'recurrence',
};

Future<void> openNativeFinance(
  BuildContext context,
  LocalFinancialController controller,
  String op,
  String title, {
  LocalRevision? replacing,
  Map<String, String> initial = const {},
  Map<String, String> overrides = const {},
  String? draft,
}) => openDemoPage<void>(
  context,
  NativeFinanceEditor(
    controller: controller,
    operation: op,
    title: title,
    replacing: replacing,
    initial: initial,
    overrides: overrides,
    draft: draft,
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
    this.overrides = const {},
    this.draft,
  });
  final LocalFinancialController controller;
  final String operation, title;
  final LocalRevision? replacing;
  final Map<String, String> initial;

  /// Beats the replaced record's own values, e.g. archiving sets the status.
  final Map<String, String> overrides;

  /// The saved draft to reopen, when Saved drafts opens this form.
  final String? draft;
  @override
  State<NativeFinanceEditor> createState() => _NativeFinanceEditorState();
}

class _NativeFinanceEditorState extends State<NativeFinanceEditor>
    with FinanceFormFields {
  late final inputs = financeInputs(
    widget.controller.snapshot,
    widget.replacing == null
        ? widget.operation
        : financeType(widget.replacing!),
    editing: widget.replacing != null,
  );
  @override
  late final values = {
    for (final f in inputs) f.key: f.value,
    ...widget.initial,
    ...?widget.replacing?.values,
    if (widget.replacing?.values['endExclusive'] case final end?)
      'lastDay': lastDay(end),
    ...widget.overrides,
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
  String? schedulePreview, scheduleNote, embeddedRows;
  bool scheduleFailed = false;
  @override
  late String id = newLocalId();
  // A prefilled form keeps its own draft, so one debt's draft can't replace
  // what another debt's row proposed.
  late final draftKey =
      widget.draft ??
      [
        'finance:${widget.operation}:${widget.replacing?.id ?? ''}',
        ?widget.initial['debt'],
        ?widget.initial['allocations'],
        ?widget.initial['payment'],
      ].join(':');
  Future<void> writes = Future.value();
  String? error, result;
  bool loading = true,
      busy = false,
      draftFailed = false,
      unknown = false,
      dirty = false;
  @override
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
          (nativeDebtCommands.contains(recordType) || visible(input)) &&
          (values[input.key] ?? '').isNotEmpty)
        input.label:
            optionsFor(input)?[values[input.key]] ?? values[input.key]!,
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

  @override
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
        final rows = simpleSchedule || embeddedSchedule
            ? cadenceRows()
            : builtPlan
            ? installmentRows()
            : null;
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
        await saveRecurringDates();
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

  /// Where a rule's problem belongs, and what to say there. Going below zero
  /// is said in terms of the chosen account, with what it holds.
  (String?, String) locateProblem(LocalRuleException e) {
    if (e.field != null) {
      return (_shownFields[e.field] ?? e.field, e.message);
    }
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
    for (final (text, field) in nativeRuleFields) {
      if (e.message.contains(text)) return (field, e.message);
    }
    return (null, e.message);
  }

  @override
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
    if (input.key == 'date' && _noDate.contains(type)) return false;
    if (input.key == 'reference' && _noReference.contains(type)) return false;
    final varied = values['splitMode'] == 'varied';
    return switch (input.key) {
      'status' => widget.replacing != null,
      'weekdays' => values['frequency'] == 'weekly',
      'monthDay' || 'monthPolicy' => values['frequency'] == 'monthly',
      'due' || 'amount' when type == 'occurrenceOverride' =>
        values['state'] == 'planned',
      'schedule' when type == 'installment' =>
        widget.replacing != null || varied,
      'installmentAmount' ||
      'frequency' ||
      'firstDue' ||
      'installmentCount' when type == 'installment' => !varied,
      'intervalDays' when type == 'installment' =>
        !varied && values['frequency'] == 'custom',
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

  /// Forms whose date stays today: their own dates say what matters.
  static const _noDate = {
    'budget',
    'savingsGoal',
    'reservation',
    'savingsReallocation',
    'recurrence',
    'recurrenceGenerate',
    'occurrenceOverride',
    'recurrenceLink',
    'recurrenceUnlink',
    'statement',
    'statementLink',
    'installment',
    'installmentApplication',
    'fileDetach',
  };

  static const _noReference = {
    'budget',
    'savingsGoal',
    'reservation',
    'savingsReallocation',
    'recurrence',
    'recurrenceGenerate',
    'occurrenceOverride',
    'recurrenceLink',
    'recurrenceUnlink',
    'statementLink',
    'cardAllocation',
    'installmentApplication',
    'fileDetach',
  };

  /// An installment plan built from a few answers, as a debt's schedule is.
  bool get builtPlan =>
      widget.operation == 'installment' &&
      widget.replacing == null &&
      values['splitMode'] != 'varied';

  /// Log a debt payment asks for the essentials; the rest of the record
  /// comes from its answers (DESIGN_SYSTEM §2 Debts). Corrections keep every
  /// field. The rules still check the whole command, and nothing saves
  /// before Review.
  bool get simplePayment =>
      widget.operation == 'debtPayment' && widget.replacing == null;

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
    'lastDay',
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
    if (input.key == 'amount' && recordType == 'reservation') {
      final goal = c.snapshot.current
          .where((r) => r.id == values['goal'])
          .firstOrNull;
      final account = values['account'] ?? '';
      if (goal != null && account.isNotEmpty) {
        final held = savingsReserved(
          c.snapshot,
          goal: goal.actionId,
          account: account,
        );
        final all = savingsReserved(c.snapshot, account: account);
        final free = eligibleSavings(c.snapshot, account, civilToday()) - all;
        return c.amountsHidden
            ? null
            : 'Set aside here now: ${c.amount(held)}. Not set aside yet: ${c.amount(free < BigInt.zero ? BigInt.zero : free)}.';
      }
    }
    return input.help;
  }

  /// The chosen card's action id: every record on a card stores that.
  String? get chosenCard => debtFor(values['card'])?.actionId;

  /// What a picker offers, given the answers so far (DESIGN_SYSTEM §2): only
  /// records the rules would accept on this card or item, in plain names. A
  /// value already chosen stays listed, so a correction keeps showing it.
  Map<String, String>? optionsFor(FinanceInput input) {
    final all = input.options;
    if (all == null) return null;
    final s = c.snapshot, today = civilToday();
    final card = chosenCard;
    bool onCard(LocalRevision r) => card != null && r.values['card'] == card;
    final limited = switch ((recordType, input.key)) {
      ('statementLink' || 'cardAllocation', 'statement') => {
        for (final r in s.current)
          if (financeType(r) == 'statement' && onCard(r)) r.id: r.title,
      },
      ('statementLink', 'activity') => {
        for (final r in s.current)
          if (const {
                'cardPurchase',
                'cardPayment',
                'cardRefund',
                'cardFee',
                'cardInterest',
              }.contains(financeType(r)) &&
              onCard(r) &&
              !s.current.any(
                (l) =>
                    financeType(l) == 'statementLink' &&
                    l.values['activity'] == r.id,
              ))
            r.id: recordChoice(r),
      },
      ('cardAllocation', 'payment') => {
        for (final r in s.current)
          if (const {'cardPayment', 'cardRefund'}.contains(financeType(r)) &&
              onCard(r) &&
              unmatchedCredit(s, r) > BigInt.zero)
            r.id: c.amountsHidden
                ? recordChoice(r)
                : '${recordChoice(r)} · ${c.amount(unmatchedCredit(s, r))} left',
      },
      ('cardRefund', 'purchase') => {
        for (final r in s.current)
          if (financeType(r) == 'cardPurchase' && onCard(r))
            r.id: recordChoice(r),
      },
      ('installment', 'purchase') => {
        for (final r in s.current)
          if (financeType(r) == 'cardPurchase' &&
              onCard(r) &&
              !s.current.any(
                (p) =>
                    financeType(p) == 'installment' &&
                    p.values['purchase'] == r.id,
              ))
            r.id: recordChoice(r),
      },
      ('installmentApplication', 'plan') => {
        for (final r in s.current)
          if (financeType(r) == 'installment' && onCard(r)) r.id: r.title,
      },
      ('installmentApplication', 'row') => {
        if (card != null)
          for (final plan in planRows(s, card, today))
            if (plan.id == values['plan'])
              for (final p in plan.payments)
                if (!p.done)
                  p.row.id: c.amountsHidden
                      ? '${p.row.id} · ${civilLabel(p.row.date)}'
                      : '${p.row.id} · ${civilLabel(p.row.date)} · ${c.amount(p.left)} left',
      },
      ('installmentApplication', 'payment') => {
        for (final r in s.current)
          if (financeType(r) == 'cardAllocation' && onCard(r))
            r.id: recordChoice(r),
      },
      ('recurrenceGenerate', 'rule') => {
        for (final r in s.current)
          if (financeType(r) == 'recurrence' && r.values['status'] == 'active')
            r.id: r.title,
      },
      ('occurrenceOverride' || 'recurrenceLink', 'rule') => {
        for (final o in recurringOccurrences(s, '1900-01-01', '2199-12-31'))
          if (const {'planned', 'linked'}.contains(o.state))
            o.rule.id: o.rule.title,
      },
      ('occurrenceOverride' || 'recurrenceLink', 'logicalDate') => {
        for (final o in recurringOccurrences(s, '1900-01-01', '2199-12-31'))
          if (o.rule.id == values['rule'] &&
              const {'planned', 'linked'}.contains(o.state))
            o.logicalDate: civilLabel(o.due),
      },
      ('recurrenceLink', 'actual') => () {
        final rule = s.revisions
            .where((r) => r.id == values['rule'])
            .firstOrNull;
        final income = rule?.values['recurringKind'] == 'income';
        return {
          for (final r in s.current)
            if (income
                ? r.kind == 'income'
                : const {'expense', 'cardPurchase'}.contains(financeType(r)))
              r.id: recordChoice(r),
        };
      }(),
      ('recurrenceUnlink', 'link') => {
        for (final r in s.current)
          if (financeType(r) == 'recurrenceLink' &&
              !s.current.any(
                (u) =>
                    financeType(u) == 'recurrenceUnlink' &&
                    u.values['link'] == r.id,
              ))
            r.id: r.title,
      },
      ('fileDetach', 'file') => {
        for (final r in s.current)
          if (financeType(r) == 'financialFile' &&
              !financialFileDetached(s, r.id))
            r.id: r.title,
      },
      ('budget', 'category') => all,
      _ => null,
    };
    if (limited == null) return all;
    final kept = values[input.key];
    return {
      ...limited,
      if (kept != null && kept.isNotEmpty && !limited.containsKey(kept))
        kept: all[kept] ?? kept,
    };
  }

  /// The picker to fill first, when one depends on another.
  String? waitingOn(FinanceInput input) => switch ((recordType, input.key)) {
    (
      'statementLink' || 'cardAllocation',
      'statement' || 'activity' || 'payment',
    ) ||
    ('cardRefund' || 'installment', 'purchase') ||
    (
      'installmentApplication',
      'plan' || 'payment',
    ) when (values['card'] ?? '').isEmpty => 'Choose the card first.',
    ('installmentApplication', 'row') when (values['plan'] ?? '').isEmpty =>
      'Choose the plan first.',
    ('occurrenceOverride' || 'recurrenceLink', 'logicalDate')
        when (values['rule'] ?? '').isEmpty =>
      'Choose the item first.',
    _ => null,
  };

  void fill(String key, String value) {
    values[key] = value;
    fields[key]?.text = value;
  }

  /// A choice can fill what follows from it, and clears what no longer fits.
  void picked(String key) {
    final s = c.snapshot, today = civilToday();
    final type = recordType;
    if (key == 'card') {
      for (final k in const [
        'statement',
        'activity',
        'purchase',
        'plan',
        'payment',
        'row',
      ]) {
        if (values.containsKey(k)) values[k] = '';
      }
    }
    if (key == 'plan') values['row'] = '';
    if (key == 'rule') values['logicalDate'] = '';
    if (type == 'cardRefund' && key == 'purchase') {
      final bought = s.current
          .where((r) => r.id == values['purchase'])
          .firstOrNull
          ?.postings
          .where((p) => p.ledger == 'expense')
          .firstOrNull;
      if (bought?.category != null) values['category'] = bought!.category!;
    }
    if (type == 'cardAllocation' &&
        answer('amount').isEmpty &&
        const {'statement', 'payment'}.contains(key)) {
      final credit = s.current
          .where((r) => r.id == values['payment'])
          .firstOrNull;
      final rows = chosenCard == null
          ? const <StatementRow>[]
          : statementRows(s, chosenCard!, today);
      final statement = rows
          .where((r) => r.id == values['statement'])
          .firstOrNull;
      if (credit != null && statement != null) {
        fill('amount', phpDecimal(matchableAmount(s, credit, statement)));
      }
    }
    if (type == 'installmentApplication' && key == 'row') {
      final plan = chosenCard == null
          ? null
          : planRows(
              s,
              chosenCard!,
              today,
            ).where((p) => p.id == values['plan']).firstOrNull;
      final row = plan?.payments
          .where((p) => p.row.id == values['row'])
          .firstOrNull;
      if (row != null) fill('amount', phpDecimal(row.left));
    }
    if (const {'occurrenceOverride', 'recurrenceLink'}.contains(type) &&
        key == 'logicalDate') {
      final date = recurringOccurrences(s, '1900-01-01', '2199-12-31')
          .where(
            (o) =>
                o.rule.id == values['rule'] &&
                o.logicalDate == values['logicalDate'],
          )
          .firstOrNull;
      if (date != null) {
        fill(
          'amount',
          phpDecimal(type == 'recurrenceLink' ? date.remaining : date.expected),
        );
        if (type == 'occurrenceOverride') values['due'] = date.due;
      }
    }
    setState(() {});
  }

  /// One toggle per weekday, stored as ISO numbers, Monday first.
  Widget weekdayInput() {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final text = Theme.of(context).textTheme;
    final chosen = answer('weekdays').split(',').toSet();
    final problem = problemFor('weekdays');
    return Padding(
      key: anchor('weekdays'),
      padding: gapAbove(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('On these days', style: text.labelMedium),
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final (i, name) in names.indexed)
                FilterChip(
                  key: ValueKey('native-weekday-${i + 1}'),
                  label: Text(name),
                  selected: chosen.contains('${i + 1}'),
                  onSelected: (on) {
                    final next = {...chosen}..remove('');
                    on ? next.add('${i + 1}') : next.remove('${i + 1}');
                    setState(
                      () => changed(
                        'weekdays',
                        (next.toList()..sort()).join(','),
                      ),
                    );
                  },
                ),
            ],
          ),
          if (problem != null) ...[
            const SizedBox(height: Space.xs),
            Text(
              problem,
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget fieldFor(FinanceInput input) {
    final key = input.key, label = input.label;
    if (key == 'acknowledge') return consentInput();
    if (key == 'weekdays') return weekdayInput();
    if (dateKeys.contains(key)) {
      return dateInput(
        key,
        label,
        helper: input.help,
        required: !input.optional,
      );
    }
    if (input.options != null) {
      final classifying =
          key == 'payment' && recordType == 'debtClassification';
      final options = classifying ? breakdownChoices() : optionsFor(input)!;
      return pickInput(
        key,
        label,
        options,
        required: input.required,
        helper: input.help,
        info: input.info,
        disabledReason:
            key == 'splitMode' &&
                recordType != 'installment' &&
                paymentCount == null
            ? 'Enter how many payments are left first.'
            : waitingOn(input),
        onChanged: key == 'frequency' && recordType != 'recurrence'
            ? frequencyChanged
            : (_) => picked(key),
        descriptions: accountKeys.contains(key)
            ? balanceLines(options, key)
            : const {},
      );
    }
    if (input.money) {
      return amountInput(
        key,
        label,
        helper: helpFor(input),
        info: input.info,
        required: input.required,
        signed: input.signed,
      );
    }
    return textInput(
      key,
      label,
      helper: input.help,
      info: input.info,
      required: input.required,
      lines: input.lines,
      input: wholeNumberKeys.contains(key) ? FieldInput.wholeNumber : null,
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
            recordType != 'installment' &&
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

  /// An installment plan's rows from the plain answers.
  String installmentRows() {
    if (answer('installmentAmount').isEmpty) {
      reject('Enter the amount of each payment.', field: 'installmentAmount');
    }
    if (answer('firstDue').isEmpty) {
      reject('Enter the date of the first payment.', field: 'firstDue');
    }
    final count = int.tryParse(answer('installmentCount'));
    if (count == null || count < 1 || count > 120) {
      reject(
        'Enter how many payments, a whole number from 1 to 120.',
        field: 'installmentCount',
      );
    }
    try {
      return debtCadenceRows(
        firstDue: answer('firstDue'),
        frequency: answer('frequency'),
        installmentAmount: answer('installmentAmount'),
        count: count,
        intervalDays: answer('intervalDays'),
      );
    } on FormatException catch (e) {
      reject(e.message, field: 'firstDue');
    } on LocalRuleException catch (e) {
      reject(e.message, field: e.field ?? 'installmentAmount');
    }
  }

  String _record(String key) =>
      c.snapshot.revisions
          .where((r) => r.id == values[key])
          .lastOrNull
          ?.title ??
      '';

  /// What a form names its record when the user leaves Description blank.
  String? get automaticName {
    final card = _record('card');
    return switch (recordType) {
      'cardPayment' => 'Payment · $card',
      'cardFee' => 'Fee · $card',
      'cardInterest' => 'Interest · $card',
      'cardRefund' => 'Refund · ${_record('purchase')}',
      'cardAuthorization' => 'Pending charge · $card',
      'statement' => '$card statement',
      'statementLink' => 'Matched · ${_record('activity')}',
      'cardAllocation' => 'Matched payment · ${_record('statement')}',
      'installment' => '${_record('purchase')} installment plan',
      'installmentApplication' => 'Matched payment · ${_record('plan')}',
      'reservation' => 'Set aside · ${_record('goal')}',
      'savingsReallocation' => 'Moved to ${_record('goal')}',
      'recurrenceGenerate' => '${_record('rule')} dates',
      'occurrenceOverride' => '${_record('rule')} date changed',
      'recurrenceLink' => '${_record('rule')} linked',
      'recurrenceUnlink' => 'Link removed · ${_record('link')}',
      'fileDetach' => 'Archived link · ${_record('file')}',
      _ => null,
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
    if (widget.replacing == null && answer('name').isEmpty) {
      final name = automaticName;
      if (name != null) v['name'] = name;
    }
    if (widget.replacing == null &&
        answer('reference').isEmpty &&
        const {
          'statement',
          'installment',
          'cardAuthorization',
        }.contains(widget.operation)) {
      v['reference'] = 'Entered by me';
    }
    if (recordType == 'budget') {
      final last = answer('lastDay');
      v['endExclusive'] = last.isEmpty ? '' : addCivilDays(last, 1);
      v.remove('lastDay');
    }
    if (recordType == 'installment') {
      if (builtPlan) v['schedule'] = rows!;
      v.removeWhere(
        (k, _) => const {
          'frequency',
          'intervalDays',
          'firstDue',
          'splitMode',
          'installmentAmount',
        }.contains(k),
      );
    }
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
    } else if (recordType != 'installment' &&
        answer('frequency').isNotEmpty &&
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

  /// A new recurring item adds its next 90 days, so it shows in Upcoming and
  /// dues at once. It's its own record, saved right after the item.
  bool get addsDates =>
      widget.operation == 'recurrence' &&
      widget.replacing == null &&
      answer('status') != 'archived';

  Future<void> saveRecurringDates() async {
    if (!addsDates) return;
    scheduleFailed = false;
    try {
      if (c.connected) {
        await c.syncLatest?.call();
        await c.reload();
      }
      final today = civilToday();
      final from = answer('start').compareTo(today) > 0
          ? answer('start')
          : today;
      final dates = LocalCommand(
        id: newLocalId(),
        owner: c.store.owner,
        expectedVersion: c.snapshot.version,
        kind: 'recurrenceGenerate',
        values: {
          'name': '${values['name']} dates',
          'rule': id,
          'from': from,
          'through': addCivilDays(from, 89),
          'date': today,
          'reference': '',
          'notes': '',
          'acknowledge': 'false',
        },
      );
      planLocal(c.snapshot, dates);
      await c.store.commit(dates);
      await c.reload();
      scheduleNote = 'The next 90 days are in Upcoming.';
    } catch (e) {
      scheduleFailed = true;
      final why = isSyncBlock(e)
          ? 'it needs a connection to check your latest records.'
          : e is LocalRuleException
          ? e.message
          : 'it could not be verified.';
      scheduleNote =
          'The item was saved, but its dates were not: $why '
          'Open it in Planning and choose Add to Upcoming.';
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
            title: addsDates
                ? (scheduleFailed ? 'Dates not added' : 'Dates added')
                : (scheduleFailed ? 'Schedule not saved' : 'Schedule saved'),
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
            quietNotes: true,
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
            quietNotes: true,
          ),
          if (schedulePreview != null) ...[
            SizedBox(height: CompactForm.fieldGap(context)),
            InlineNotice(
              recordType == 'installment'
                  ? 'Installment plan to save: $schedulePreview.\nCheck these dates and amounts match your card issuer’s plan.'
                  : 'Payment schedule to save: $schedulePreview.\nCheck these dates and amounts match your loan agreement or lender statement. A payment only counts toward a due date when you log it against that date.',
            ),
          ],
          if (addsDates) ...[
            SizedBox(height: CompactForm.fieldGap(context)),
            const InlineNotice(
              'Saving also adds the next 90 days to Upcoming. Nothing is logged when a date arrives.',
            ),
          ],
          ...syncNotices(),
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

/// One record's page: the same page for Money, Debts, Cards, Planning and
/// Reports (§2 Money).
Future<void> openFinanceDetail(
  BuildContext context,
  LocalFinancialController c,
  String id,
) => openMoneyRecord(context, c, id);
