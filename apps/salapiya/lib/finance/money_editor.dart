import 'dart:async';

import 'package:flutter/material.dart';

import '../connected/financial_contract.dart' show applyFinancialPlan;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../design_system/kit/review.dart';
import '../features/finance/contracts/financial_models.dart';
import '../features/finance/presentation/financial_review.dart';
import '../local/finance_domain.dart';
import '../local/local_finance_controller.dart';
import '../p0/exact_money.dart';
import '../shared/shared_screen.dart' show sharePrivatePurchase;
import 'card_data.dart' show pendingCharges;
import 'form_mechanics.dart';
import 'money_data.dart';

/// The Money forms a real profile opens (§2 Money). Everything else
/// `FinancialEditor` holds is the demo build's.
const moneyFormActions = {
  FinancialAction.account,
  FinancialAction.expense,
  FinancialAction.income,
  FinancialAction.transfer,
  FinancialAction.correction,
  FinancialAction.refund,
  FinancialAction.reversal,
  FinancialAction.reconcile,
  FinancialAction.category,
  FinancialAction.archive,
};

/// Rules that name no field, and the field each is about. A test holds these
/// to the rules' own words.
const moneyRuleFields = [
  ('You already have an account with this name', 'name'),
  ('You already have a category with this name', 'name'),
  ('Choose an account type', 'kind'),
  ('Choose whether this is for spending or income', 'classification'),
  ('Choose the type of income', 'incomeClass'),
  ('Choose a spending category', 'category'),
  ('Choose an income category', 'category'),
  ('Choose one of your accounts', 'account'),
  ('Choose an active account', 'account'),
  ('balance starts from that day', 'date'),
  ('the day this account’s balance starts', 'date'),
  ('A refund can’t be dated before', 'date'),
  ('Choose two different accounts', 'destination'),
  ('A fee taken out of the amount', 'feeDate'),
  ('Each split must be more than zero', 'splitAmount'),
  ('more than is left to refund', 'refundPosting'),
  ('Choose a part of this purchase', 'refundPosting'),
  ('Apply the refund to each part', 'refundPosting'),
  ('The parts must add up', 'amount'),
  ('The amount plus fees', 'amount'),
];

/// Log expense, income and a transfer, the account and category forms, and
/// corrections, reversals, refunds and balance checks, on the compact scale.
/// Values start from the controller's defaults and every key stays in the
/// command, shown or not, so what's saved is what these forms always saved.
class MoneyEditor extends StatefulWidget {
  const MoneyEditor({
    super.key,
    required this.controller,
    required this.action,
    this.sourceId,
    this.initial,
  });
  final LocalFinancialController controller;
  final FinancialAction action;
  final String? sourceId;
  final Map<String, String>? initial;

  /// The form's title, for the page's route too.
  String get title => titleFor(action, initial?['mode']);

  static String titleFor(FinancialAction action, String? mode) =>
      switch (action) {
        FinancialAction.account => 'Add account',
        FinancialAction.expense => 'Log expense',
        FinancialAction.income => 'Log income',
        FinancialAction.transfer => 'Log a transfer',
        FinancialAction.refund => 'Log a refund',
        FinancialAction.category => 'Add category',
        FinancialAction.reconcile when mode == 'manual' =>
          'Adjust account balance',
        FinancialAction.reconcile when mode == 'adjustment' =>
          'Adjust balance to match',
        FinancialAction.reconcile => 'Check a balance',
        _ => action.label,
      };

  @override
  State<MoneyEditor> createState() => _MoneyEditorState();
}

class _MoneyEditorState extends State<MoneyEditor>
    with FormInputs, FinanceFormFields {
  @override
  LocalFinancialController get c => widget.controller;
  FinancialAction get action => widget.action;
  @override
  late final values = {
    ...c.defaults(action, sourceId: widget.sourceId),
    ...?widget.initial,
  };
  @override
  late String id = c.nextCommand();

  /// The same draft keys as before, so saved drafts still open.
  late final operation =
      '${action.name}:${widget.sourceId ?? ''}${action == FinancialAction.reconcile ? ':${values['mode'] ?? 'compare'}' : ''}';
  late final mode = values['mode'];
  String get title => MoneyEditor.titleFor(action, mode);
  Future<void> writes = Future.value();
  bool loading = true,
      busy = false,
      dirty = false,
      restored = false,
      draftFailed = false,
      unknown = false,
      saved = false;
  String? error, shareProblem;

  LocalRevision? get source =>
      c.snapshot.revisions.where((r) => r.id == values['source']).firstOrNull;

  /// The kind of form: a correction shows its record's own fields.
  String? get kind =>
      action == FinancialAction.correction ? source?.kind : action.name;

  /// A balance change that belongs to a comparison keeps its account and
  /// date; the rules won't accept others.
  bool get linkedAdjustment =>
      mode == 'adjustment' || (kind == 'adjustment' && source?.source != null);

  @override
  void initState() {
    super.initState();
    unawaited(restore());
  }

  Future<void> restore() async {
    try {
      final draft = await c.restoreDraft(operation);
      if (draft != null) {
        values.addAll(Map<String, String>.from(draft['values'] as Map));
        id = draft['command'] as String;
        dirty = restored = true;
        needsConsent = values['acknowledge'] == 'true';
      }
    } catch (_) {
      error = 'Your saved draft could not be read. Reopen this profile.';
      draftFailed = true;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void retain() {
    setState(() => dirty = true);
    final frozen = Map<String, String>.from(values), command = id;
    writes = writes
        .then((_) => c.retainDraft(operation, command, frozen))
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

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  /// Money leaving the chosen account, once it's a valid amount.
  @override
  BigInt? get leaving {
    if (!const {'expense', 'transfer'}.contains(kind) ||
        answer('funding') == 'card' && kind == 'expense') {
      return null;
    }
    try {
      final amount = parsePhp(answer('amount'));
      if (kind != 'transfer' || answer('feeTreatment') == 'separate') {
        return amount;
      }
      final fee = answer('fee');
      return amount + (fee.isEmpty ? BigInt.zero : parsePhp(fee));
    } on FormatException {
      return null;
    }
  }

  /// Masked with Hide amounts, unlike `c.amount`.
  String shown(BigInt value) =>
      c.amountsHidden ? 'Amount hidden' : c.amount(value);

  Map<String, String> get activeAccounts => {
    for (final a in c.snapshot.accounts.where((a) => !a.archived)) a.id: a.name,
  };

  /// A correction may keep an archived account it was logged on.
  Map<String, String> accountsFor(String key) => {
    ...activeAccounts,
    if (action == FinancialAction.correction ||
        action == FinancialAction.reversal)
      for (final a in c.snapshot.accounts.where(
        (a) => a.archived && a.id == values[key],
      ))
        a.id: '${a.name} · archived',
  };

  Widget accountInput(
    String label, {
    String key = 'account',
    bool required = true,
  }) {
    final accounts = accountsFor(key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pickInput(
          key,
          label,
          accounts,
          required: required,
          descriptions: balanceLines(accounts, key),
          onChanged: (_) => setState(() {}),
        ),
        if (needsConsent && consentField == key) consentInput(),
      ],
    );
  }

  Widget categoryInput(String key, String label, String classification) =>
      pickInput(key, label, c.categoryChoices(classification), required: true);

  /// The fields of an expense or income, which a correction shows too.
  /// The chosen card's pending charges no purchase has used yet.
  Map<String, String> pendingChoices() => {
    for (final r in pendingCharges(c.snapshot, answer('card')))
      r.id: c.amountsHidden ? r.title : '${r.title} · ${c.amount(r.amount)}',
  };

  List<Widget> entry(String kind, List<Widget> extra) {
    final local = c.snapshot;
    final cards = {
      for (final r in local.current.where(
        (r) => financeType(r) == 'creditCard',
      ))
        r.actionId: r.title,
    };
    final card = answer('funding') == 'card';
    return [
      amountInput('amount', 'Amount', required: true),
      textInput('name', 'Description', required: true),
      if (kind == 'expense') ...[
        if (cards.isNotEmpty)
          pickInput('funding', 'Paid with', const {
            'cash': 'Cash, bank or wallet',
            'card': 'Credit card',
          }, onChanged: (_) => setState(() {})),
        if (card) ...[
          pickInput(
            'card',
            'Credit card',
            cards,
            required: true,
            onChanged: (_) => setState(() => values['authorization'] = ''),
          ),
          dateInput(
            'postingDate',
            'Date it posted',
            required: true,
            helper: 'When it appeared on your card.',
          ),
          if (pendingChoices().isNotEmpty)
            more(
              [
                pickInput('authorization', 'Pending charge this came from', {
                  '': 'None',
                  ...pendingChoices(),
                }),
              ],
              const {'authorization'},
            ),
        ] else
          accountInput('Paid from'),
      ] else
        accountInput('Paid into'),
      dateInput('date', 'Date', required: true),
      categoryInput('category', 'Category', kind),
      if (kind == 'income')
        pickInput('incomeClass', 'Type of income', const {
          'earned': 'Earned',
          'gift': 'Gift',
          'reward': 'Reward',
          'other': 'Other',
        }),
      ...extra,
    ];
  }

  Widget toggle(String key, String label) => Padding(
    padding: EdgeInsets.only(top: CompactForm.fieldGap(context)),
    child: CheckboxListTile(
      key: ValueKey('native-$key'),
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      value: values[key] == 'true',
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (x) => setState(() => changed(key, '$x')),
    ),
  );

  Widget formLink(String label, IconData icon, VoidCallback? onPressed) =>
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: onPressed == null
            ? const SizedBox.shrink()
            : CardLink(label, icon: icon, onPressed: onPressed),
      );

  void setCount(String key, int value) => setState(() {
    values[key] = '$value';
    retain();
  });

  List<Widget> splitFields() {
    final count = int.tryParse(values['splitCount'] ?? '') ?? 2;
    return [
      toggle('split', 'Split across categories'),
      if (values['split'] == 'true') ...[
        amountInput('splitAmount', 'First category amount', required: true),
        for (var i = 2; i < count; i++) ...[
          amountInput('split${i}Amount', 'Category ${i + 1} amount'),
          categoryInput('split${i}Category', 'Category ${i + 1}', 'expense'),
        ],
        categoryInput('splitCategory', 'Category for the rest', 'expense'),
        formLink(
          'Add another split',
          Icons.add,
          count < 100 ? () => setCount('splitCount', count + 1) : null,
        ),
        formLink(
          'Remove the last split',
          Icons.remove,
          count > 2 ? () => setCount('splitCount', count - 1) : null,
        ),
      ],
    ];
  }

  static const feeTreatments = {
    'source_additional': 'On top, from the same account',
    'withheld': 'Taken out of the amount',
    'separate': 'From another account',
  };

  List<Widget> feeFields() {
    final count = int.tryParse(values['feeCount'] ?? '') ?? 1;
    return [
      pickInput(
        'feeTreatment',
        'How the fee was paid',
        feeTreatments,
        onChanged: (_) => setState(() {}),
      ),
      if (values['feeTreatment'] == 'separate')
        accountInput('Fee paid from', key: 'feeAccount'),
      categoryInput('feeCategory', 'Fee category', 'expense'),
      dateInput(
        'feeDate',
        'Fee date',
        helper: 'Leave this empty to use the transfer date.',
      ),
      for (var i = 1; i < count; i++) ...[
        textInput('extraFee${i}Label', 'Fee ${i + 1} name'),
        amountInput('extraFee${i}Amount', 'Fee ${i + 1} amount'),
        pickInput(
          'extraFee${i}Treatment',
          'How fee ${i + 1} was paid',
          feeTreatments,
          onChanged: (_) => setState(() {}),
        ),
        if (values['extraFee${i}Treatment'] == 'separate')
          accountInput('Fee ${i + 1} paid from', key: 'extraFee${i}Account'),
        categoryInput(
          'extraFee${i}Category',
          'Fee ${i + 1} category',
          'expense',
        ),
        dateInput('extraFee${i}Date', 'Fee ${i + 1} date'),
      ],
      formLink(
        'Add transfer fee',
        Icons.add,
        count < 20
            ? () => setState(() {
                values.addAll({
                  'feeCount': '${count + 1}',
                  'extraFee${count}Amount': '',
                  'extraFee${count}Treatment': 'source_additional',
                  'extraFee${count}Category': 'category-fees',
                  'extraFee${count}Account': values['account'] ?? '',
                  'extraFee${count}Date': '',
                  'extraFee${count}Label': '',
                });
                retain();
              })
            : null,
      ),
      formLink(
        'Remove the last fee',
        Icons.remove,
        count > 1 ? () => setCount('feeCount', count - 1) : null,
      ),
    ];
  }

  Widget portionInput([String key = 'refundPosting']) {
    final purchase = source?.kind == 'refund' && source?.source != null
        ? c.snapshot.revision(source!.source!)
        : source;
    return pickInput(key, 'What was refunded', {
      for (final e
          in (purchase?.postings ?? <LocalPosting>[]).asMap().entries.where(
            (e) => e.value.ledger == 'expense',
          ))
        '${purchase!.id}-p${e.key + 1}':
            '${c.categoryName(e.value.category)} · ${shown(e.value.amount)}',
    }, required: true);
  }

  List<Widget> refundFields(String label) {
    final purchase = source?.kind == 'refund' && source?.source != null
        ? c.snapshot.revision(source!.source!)
        : source;
    final many =
        (purchase?.postings.where((p) => p.ledger == 'expense').length ?? 0) >
        1;
    final count = int.tryParse(values['refundCount'] ?? '') ?? 2;
    return [
      amountInput('amount', label, required: true),
      accountInput('Paid into'),
      dateInput('date', 'Date', required: true),
      portionInput(),
      if (many) ...[
        toggle('refundMultiple', 'Allocate refund across original portions'),
        if (values['refundMultiple'] == 'true') ...[
          amountInput('refundFirstAmount', 'First portion refund'),
          for (var i = 1; i < count; i++) ...[
            portionInput('refund${i}Posting'),
            amountInput('refund${i}Amount', 'Portion ${i + 1} refund'),
          ],
          formLink(
            'Add refund portion',
            Icons.add,
            count < 100 ? () => setCount('refundCount', count + 1) : null,
          ),
          formLink(
            'Remove the last portion',
            Icons.remove,
            count > 2 ? () => setCount('refundCount', count - 1) : null,
          ),
        ],
      ],
    ];
  }

  Widget reasonInput([String label = 'Why you’re changing this']) =>
      textInput('reason', label, required: true, lines: 2);

  List<Widget> get details => [
    textInput('reference', 'Reference'),
    textInput('notes', 'Notes', lines: 3),
  ];

  Widget more(List<Widget> children, Set<String> keys) => Padding(
    padding: EdgeInsets.only(top: CompactForm.fieldGap(context)),
    child: FormMoreDetails(open: keys.contains(errorField), children: children),
  );

  Widget note(String message) => Padding(
    padding: EdgeInsets.only(top: CompactForm.groupGap(context)),
    child: InlineNotice(message),
  );

  /// A fact a form can't change, in place of its field.
  Widget locked(String label, String value) => Padding(
    padding: gapAbove(),
    child: HelpTextField(
      key: ValueKey('native-locked-$label'),
      label: label,
      controller: TextEditingController(text: value),
      readOnly: true,
    ),
  );

  /// Keys under "More details" in this form, so an error opens it.
  Set<String> get moreKeys => {
    'merchant',
    'sender',
    'sourceLabel',
    'reference',
    'notes',
    'institution',
    'splitAmount',
    'splitCategory',
    'feeTreatment',
    'feeAccount',
    'feeCategory',
    'feeDate',
    if (kind == 'transfer') 'name',
  };

  List<Widget> formFields() {
    final correcting = action == FinancialAction.correction;
    final reason = correcting ? [reasonInput()] : const <Widget>[];
    if (action == FinancialAction.reversal) {
      return [
        reasonInput('Why you’re reversing this'),
        note(
          'Its effect is removed from the dates it happened, and the record stays in its edit history.',
        ),
      ];
    }
    if (action == FinancialAction.refund) {
      return [
        ...refundFields('Refund amount'),
        reasonInput('Why it was refunded'),
        more(details, moreKeys),
        note('A refund lowers the spending it came from. It isn’t income.'),
      ];
    }
    if (action == FinancialAction.reconcile) {
      if (mode == 'manual') {
        return [
          accountInput('Account'),
          amountInput(
            'amount',
            'Change to balance',
            required: true,
            signed: true,
            helper: 'Use a minus sign to lower the balance.',
          ),
          dateInput('date', 'Date', required: true),
          reasonInput('Why you’re adjusting it'),
          more(details, moreKeys),
          note(
            'This isn’t income or spending. To compare with a statement or a count, use Check balance first.',
          ),
        ];
      }
      if (mode == 'adjustment') {
        return [
          locked('Account', c.snapshot.account(values['account']!).name),
          locked('Change to balance', shown(source?.amount ?? BigInt.zero)),
          reasonInput('Why you’re adjusting it'),
          note(
            'This makes the balance match what you counted. It isn’t income or spending.',
          ),
        ];
      }
      return [
        accountInput('Account'),
        amountInput(
          'amount',
          'Actual balance',
          required: true,
          signed: true,
          helper: 'What the account really holds, from a statement or a count.',
        ),
        dateInput('date', 'Date', required: true),
        more(details, moreKeys),
        note(
          'This saves a comparison and changes no money. If there’s a difference, you can adjust the balance next.',
        ),
      ];
    }
    switch (kind) {
      case 'account':
        return [
          textInput('name', 'Account name', required: true),
          pickInput('kind', 'Account type', const {
            'Cash': 'Cash',
            'Bank': 'Bank',
            'Mobile wallet': 'Mobile wallet',
            'Checking': 'Checking',
            'Savings': 'Savings',
          }, required: true),
          amountInput('amount', 'Opening balance'),
          dateInput(
            'cutoff',
            'Balance as of',
            required: true,
            helper:
                'The day this balance was true. Log newer activity after it.',
          ),
          more([
            textInput('institution', 'Institution'),
            textInput('notes', 'Notes', lines: 3),
          ], moreKeys),
        ];
      case 'category':
        return [
          textInput('name', 'Category name', required: true),
          pickInput('classification', 'Type', const {
            'expense': 'Expense',
            'income': 'Income',
          }, style: PickerStyle.segmented),
        ];
      case 'archive':
        return [
          accountInput('Account'),
          reasonInput('Why you’re archiving it'),
          note(
            'Its history and balance stay. You can’t log anything new on it.',
          ),
        ];
      case 'expense':
        return [
          ...entry('expense', const []),
          more([
            textInput('merchant', 'Merchant'),
            ...splitFields(),
            ...details,
          ], moreKeys),
          ...reason,
        ];
      case 'income':
        return [
          ...entry('income', const []),
          more([
            textInput('sender', 'Received from'),
            textInput('sourceLabel', 'Income source'),
            ...details,
          ], moreKeys),
          ...reason,
        ];
      case 'transfer':
        return [
          amountInput('amount', 'Amount received', required: true),
          accountInput('From'),
          accountInput('To', key: 'destination'),
          dateInput('date', 'Date', required: true),
          amountInput('fee', 'Transfer fee'),
          more([
            textInput('name', 'Description'),
            ...feeFields(),
            ...details,
          ], moreKeys),
          ...reason,
          note(
            'Moving money between your accounts isn’t income or spending. Only a fee counts as spending.',
          ),
        ];
      case 'refund':
        return [
          ...refundFields('Corrected refund'),
          ...reason,
          more(details, moreKeys),
        ];
      case 'opening':
        return [
          amountInput('amount', 'Opening balance', required: true),
          ...reason,
          note('The account and its date stay as they are.'),
        ];
      case 'adjustment':
        if (linkedAdjustment) {
          return [
            locked('Account', c.snapshot.account(values['account']!).name),
            ...reason,
            note(
              'This adjustment belongs to a balance check, so its account, date and amount stay as they are.',
            ),
          ];
        }
        return [
          accountInput('Account'),
          amountInput(
            'amount',
            'Change to balance',
            required: true,
            signed: true,
            helper: 'Use a minus sign to lower the balance.',
          ),
          dateInput('date', 'Date', required: true),
          ...reason,
          more(details, moreKeys),
        ];
      default:
        return [
          const InlineNotice('This record is changed where it was logged.'),
        ];
    }
  }

  /// The form's own checks, in plain words on the field. The rules still
  /// check everything; these only say what to fix first.
  void check() {
    void need(String key, String message) {
      if (answer(key).isEmpty) reject(message, field: key);
    }

    void amount(String key, String message, {bool zero = false}) {
      final text = answer(key);
      try {
        final value = signedPhp(text);
        if (!zero && value == BigInt.zero) {
          reject('Enter an amount greater than zero.', field: key);
        }
      } on FormatException {
        reject(message, field: key);
      }
    }

    const money = 'Enter an amount in pesos, like 1500.00.';
    switch (action == FinancialAction.reconcile ? mode : kind) {
      case 'account':
        need('name', 'Enter a name for this account.');
        amount('amount', money, zero: true);
        need('cutoff', 'Choose the day this balance was true.');
      case 'category':
        need('name', 'Enter a name for this category.');
      case 'archive':
        need('account', 'Choose an account.');
        need('reason', 'Say why you’re archiving it.');
      case 'expense' || 'income':
        amount('amount', money);
        need('name', 'Enter a description.');
        if (answer('funding') == 'card' && kind == 'expense') {
          need('card', 'Choose a credit card.');
          need('postingDate', 'Choose the date it posted.');
        } else {
          need('account', 'Choose an account.');
        }
        need('date', 'Choose a date.');
        need('category', 'Choose a category.');
        if (kind == 'expense' && values['split'] == 'true') {
          amount('splitAmount', money);
          need('splitCategory', 'Choose a category for the rest.');
        }
      case 'transfer':
        amount('amount', money);
        need('account', 'Choose where it came from.');
        need('destination', 'Choose where it went.');
        if (answer('account') == answer('destination')) {
          reject('Choose a different account.', field: 'destination');
        }
        need('date', 'Choose a date.');
        amount('fee', 'Enter the fee, or 0.00.', zero: true);
      case 'refund':
        amount('amount', money);
        need('account', 'Choose an account.');
        need('date', 'Choose a date.');
        need('refundPosting', 'Choose what was refunded.');
      case 'compare':
        need('account', 'Choose an account.');
        amount('amount', 'Enter what the account holds.', zero: true);
        need('date', 'Choose a date.');
      case 'manual':
        need('account', 'Choose an account.');
        amount('amount', 'Enter how much it changes, like -20.00.');
        need('date', 'Choose a date.');
      case 'opening':
        amount('amount', money);
    }
    if (action == FinancialAction.reversal ||
        action == FinancialAction.correction ||
        action == FinancialAction.refund ||
        kind == 'adjustment' ||
        mode == 'manual' ||
        mode == 'adjustment') {
      need('reason', 'Say why.');
    }
  }

  /// Which account field goes below zero: the rule says that one does, not
  /// which. Plans the same command with consent, in memory, and looks.
  String? belowZeroField() {
    final s = c.snapshot;
    final LocalPlan consented;
    try {
      consented = planLocal(
        s,
        c.command(action, {...values, 'acknowledge': 'true'}, id, s.version),
      );
    } catch (_) {
      return null;
    }
    final after = applyFinancialPlan(s, consented);
    final revision = consented.revision;
    final replaced = revision?.previous == null
        ? null
        : s.revisions.where((r) => r.id == revision!.previous).firstOrNull;
    bool goesBelow(String account) {
      final changed = [
        ...?revision?.postings,
        ...?replaced?.postings,
      ].where((p) => p.account == account).map((p) => p.date).toList()..sort();
      if (changed.isEmpty) return false;
      final byDay = <String, BigInt>{};
      for (final p in after.current.expand((r) => r.postings)) {
        if (p.account == account) {
          byDay[p.date] = (byDay[p.date] ?? BigInt.zero) + p.amount;
        }
      }
      var running = BigInt.zero;
      for (final day in byDay.keys.toList()..sort()) {
        running += byDay[day]!;
        if (day.compareTo(changed.first) >= 0 && running.isNegative) {
          return true;
        }
      }
      return false;
    }

    final count = int.tryParse(values['feeCount'] ?? '') ?? 1;
    for (final key in [
      'account',
      'destination',
      'feeAccount',
      for (var i = 1; i < count; i++) 'extraFee${i}Account',
    ]) {
      final account = values[key];
      if (account != null && account.isNotEmpty && goesBelow(account)) {
        return key;
      }
    }
    return null;
  }

  (String?, String) locateProblem(LocalRuleException e) {
    if (e.field != null) return (e.field, e.message);
    if (e.message.contains('negative')) {
      final key = belowZeroField();
      final account = c.snapshot.accounts
          .where((a) => a.id == values[key])
          .firstOrNull;
      if (key == null || account == null) return (null, e.message);
      consentField = key;
      return (
        key,
        'This takes ${account.name} below zero. It has ${shownBalance(account.id)}.',
      );
    }
    // The refund message says what's left, which Hide amounts keeps hidden.
    final message = c.amountsHidden
        ? e.message.replaceAll(RegExp(r' ₱[\d,.]+ is left\.'), '')
        : e.message;
    for (final (text, field) in moneyRuleFields) {
      if (message.contains(text)) return (field, message);
    }
    return (null, message);
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
      if (draftFailed) reject('Your draft needs saving before you continue.');
      if (reviewed == null) {
        check();
        await c.reload();
        reviewed = c.command(action, Map.of(values), id, c.snapshot.version);
        reviewSnapshot = c.snapshot;
        plan = planLocal(reviewSnapshot!, reviewed!);
      } else if (await refreshBeforeSaving()) {
        rechecked = true;
      } else {
        await c.store.commit(reviewed!);
        await c.reload();
        await c.discardDraft(operation);
        saved = true;
      }
    } catch (e) {
      // Stays on Review with everything kept, ready to try again.
      syncing = false;
      syncBlocked = isSyncBlock(e);
      if (reviewed != null && !syncBlocked) {
        try {
          if (await c.store.hasReceipt(id)) {
            await c.reload();
            saved = true;
          } else {
            reviewed = null;
            plan = null;
          }
        } catch (_) {
          unknown = true;
        }
      }
      if (!saved && !syncBlocked) {
        if (e is LocalRuleException) {
          (problemField, problem) = locateProblem(e);
          if (e.message.contains('negative')) needsConsent = true;
        } else if (e is FormatException) {
          problem = e.message;
          problemField = 'date';
        } else {
          error = 'The save could not be verified. What you entered is kept.';
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

  /// The save's answer was lost. Looks up the same command, and never
  /// submits a second one.
  Future<void> checkResult() async {
    setState(() => busy = true);
    final outcome = await c.resolveReceipt(id);
    if (outcome == DemoOutcome.accepted) await c.discardDraft(operation);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (outcome == DemoOutcome.unknown) return;
      unknown = false;
      if (outcome == DemoOutcome.accepted) {
        saved = true;
        error = null;
      } else {
        error =
            'It wasn’t saved. What you entered is kept, so you can save again.';
      }
    });
  }

  Map<String, String> get reviewDetails => {
    if (kind == 'category') ...{
      'Category': answer('name'),
      'Type': answer('classification') == 'income' ? 'Income' : 'Expense',
    },
    if (kind == 'archive' && activeAccounts[values['account']] != null)
      'Account': activeAccounts[values['account']]!,
    for (final (key, label) in const [
      ('merchant', 'Merchant'),
      ('sender', 'Received from'),
      ('sourceLabel', 'Income source'),
      ('institution', 'Institution'),
      ('reference', 'Reference'),
      ('notes', 'Notes'),
      ('reason', 'Reason'),
    ])
      if (answer(key).isNotEmpty) label: answer(key),
  };

  String get savedTitle => switch (action) {
    FinancialAction.account => 'Account added',
    FinancialAction.expense => 'Expense logged',
    FinancialAction.income => 'Income logged',
    FinancialAction.transfer => 'Transfer logged',
    FinancialAction.refund => 'Refund logged',
    FinancialAction.category => 'Category added',
    FinancialAction.archive => 'Account archived',
    FinancialAction.correction => 'Transaction corrected',
    FinancialAction.reversal => 'Transaction reversed',
    _ => mode == 'compare' ? 'Balance check saved' : 'Balance adjusted',
  };

  Future<void> share() async {
    setState(() => shareProblem = null);
    try {
      await sharePrivatePurchase(context, c, id);
    } catch (e) {
      if (mounted) {
        setState(
          () => shareProblem = e is LocalRuleException
              ? e.message
              : 'That didn’t work. Your purchase stays saved.',
        );
      }
    }
  }

  Widget review() => FinancialReview(
    plan: plan!,
    snapshot: reviewSnapshot!,
    amount: c.amount,
    hidden: c.amountsHidden,
    commandId: id,
    details: reviewDetails,
    quietNotes: true,
    title: recordTitle,
  );

  Widget body() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (loading)
        const LinearProgressIndicator()
      else if (saved) ...[
        FormStatus(
          title: savedTitle,
          message: 'Saved securely on this device.',
          tone: NoticeTone.success,
        ),
        if (c.connected) FormSyncStatus(state: c.synchronizationStates[id]),
        if (plan != null) review(),
        if (shareProblem != null) ...[
          SizedBox(height: CompactForm.fieldGap(context)),
          InlineNotice(shareProblem!, tone: NoticeTone.error, live: true),
        ],
        SizedBox(height: CompactForm.groupGap(context)),
        actions(
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
          action == FinancialAction.expense
              ? OutlinedButton(
                  onPressed: share,
                  child: const Text('Share this purchase'),
                )
              : null,
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
                ? '$error Check the result before saving anything else.'
                : error!,
            tone: unknown || draftFailed
                ? NoticeTone.warning
                : NoticeTone.error,
          ),
        if (busy)
          FormStatus(
            title: syncing ? 'Checking your latest records…' : 'Saving…',
            message: 'Keep this form open while it finishes.',
            busy: true,
          ),
        if (reviewed == null) ...[
          if (restored) ...[
            const InlineNotice(
              'Your draft is back. Check it, then continue.',
              live: true,
            ),
            SizedBox(height: CompactForm.fieldGap(context)),
          ],
          ...() {
            final form = formFields();
            final inPlace =
                anchors.containsKey(errorField) ||
                moreKeys.contains(errorField);
            return [
              if (errorMessage != null && !inPlace) ...[
                InlineNotice(errorMessage!, tone: NoticeTone.error, live: true),
                SizedBox(height: CompactForm.fieldGap(context)),
              ],
              ...form,
            ];
          }(),
        ] else ...[
          review(),
          ...syncNotices(),
        ],
        SizedBox(height: CompactForm.groupGap(context)),
        actions(
          unknown
              ? FilledButton(
                  key: const ValueKey('money-check-result'),
                  onPressed: busy ? null : checkResult,
                  child: const Text('Check the result'),
                )
              : FilledButton(
                  key: const ValueKey('native-submit'),
                  onPressed: busy || draftFailed ? null : save,
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
        if (unknown) FormEvidence(children: [SelectableText('Change: $id')]),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    firstField = true;
    return FormExitGuard(
      dirty: dirty && !saved,
      busy: busy || loading || unknown,
      keepDraft: () async {
        await writes;
        if (draftFailed) throw StateError('Draft not saved');
      },
      child: CompactForm(
        child: SectionPage(
          title: title,
          caption: loading || saved
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
}
