import 'package:flutter/material.dart';

import '../connected/financial_contract.dart';
import '../local/finance_domain.dart';
import '../local/local_store.dart' show defaultLocalCategories;
import '../finance/money_demo.dart';
import '../prototype/fixtures.dart' show DemoMoney, demoAccounts;
import '../prototype/scenarios.dart';
import 'overview_cards.dart';
import 'overview_dashboard.dart';
import 'overview_data.dart';

/// The demo build's Overview sample (owner review, 2026-10-30): a synthetic
/// profile replayed in memory through the real rules (`planLocal`), dated
/// relative to today so dues, overdue rows and charts always have content.
/// Nothing is stored; it is rebuilt from scratch each day.

const _owner = 'demo-overview';

/// The sample profile's records as of [today]. Its accounts end today on
/// the demo accounts' balances (`demoAccounts`), so the Overview and Money
/// agree. [empty] gives the empty first-use profile (categories only).
LocalSnapshot demoOverviewSnapshot(String today, {bool empty = false}) {
  if (empty) return _replay(today, const []);
  // Replay once to measure each account's activity, then open each account
  // with what lands it on its demo balance today.
  final probe = BigInt.from(100000000);
  final measured = _replay(today, [for (final _ in demoAccounts) probe]);
  return _replay(today, [
    for (final (i, a) in measured.accounts.take(demoAccounts.length).indexed)
      BigInt.parse(demoAccounts[i].$2) -
          (measured.balance(a.id, through: today) - probe),
  ]);
}

LocalSnapshot _replay(String today, List<BigInt> openings) {
  var s = LocalSnapshot(
    owner: _owner,
    version: 0,
    accounts: const [],
    categories: [
      for (final c in defaultLocalCategories)
        LocalCategory('category-${c.$1}', c.$2, c.$3),
    ],
    revisions: const [],
  );
  if (openings.isEmpty) return s;
  var n = 0;
  String day(int offset) => addCivilDays(today, offset);
  String post(String kind, Map<String, String> values) {
    final id =
        '00000000-0000-4000-8000-${(++n).toRadixString(16).padLeft(12, '0')}';
    final command = LocalCommand(
      id: id,
      owner: _owner,
      expectedVersion: s.version,
      kind: kind,
      values: {'acknowledge': 'false', ...values},
    );
    s = applyFinancialPlan(s, planLocal(s, command));
    return id;
  }

  final cutoff = day(-70);
  String account(int i, String kind) => post('account', {
    'name': demoAccounts[i].$1,
    'kind': kind,
    'amount': phpDecimal(openings[i]),
    'cutoff': cutoff,
  });
  final cash = account(0, 'Cash');
  final bank = account(1, 'Bank');
  final wallet = account(2, 'Mobile wallet');

  void income(int offset, String name, String to, String amount) =>
      post('income', {
        'date': day(offset),
        'name': name,
        'account': to,
        'amount': amount,
        'category': 'category-income',
        'incomeClass': 'earned',
      });
  String expense(
    int offset,
    String name,
    String from,
    String category,
    String amount,
  ) => post('expense', {
    'date': day(offset),
    'name': name,
    'account': from,
    'amount': amount,
    'category': 'category-$category',
  });
  void transfer(int offset, String from, String to, String amount) =>
      post('transfer', {
        'date': day(offset),
        'name': 'Cash withdrawal',
        'account': from,
        'destination': to,
        'amount': amount,
        'fee': '0.00',
      });

  for (final offset in [-59, -44, -29, -14]) {
    income(offset, 'Salary', bank, '15000.00');
  }
  income(-45, 'Freelance design project', wallet, '4500.00');

  // Everyday spending: a deterministic mix, a little every day.
  const meals = ['Lunch', 'Coffee', 'Dinner with friends', 'Merienda'];
  const mealCost = [185, 145, 620, 95];
  for (var offset = -65; offset <= 0; offset++) {
    final i = offset + 65;
    if (i % 10 == 0) transfer(offset, bank, cash, '2000.00');
    if (i % 5 != 3) {
      expense(
        offset,
        meals[i % 4],
        cash,
        'food',
        '${mealCost[i % 4] + i * 37 % 60}.00',
      );
    }
    if (i % 3 == 1) {
      expense(
        offset,
        i % 2 == 0 ? 'Ride to work' : 'Jeepney and train',
        wallet,
        'transport',
        '${i % 2 == 0 ? 210 + i % 7 * 15 : 48}.00',
      );
    }
    if (i % 7 == 2) {
      expense(
        offset,
        'Weekly groceries',
        bank,
        'groceries',
        '${1450 + i * 23 % 400}.50',
      );
    }
  }
  for (final base in [-62, -32, -2]) {
    expense(base, 'Electricity', bank, 'bills', '${2180 + base.abs() * 3}.40');
    expense(base + 1, 'Home internet', bank, 'bills', '1699.00');
  }
  expense(-9, 'Bank transfer fee', bank, 'fees', '25.00');
  expense(-6, 'Birthday gift', cash, 'other', '850.00');

  // What Money's Activity shows besides everyday spending.
  post('expense', {
    'date': day(-11),
    'name': 'Household run',
    'account': bank,
    'amount': '1450.00',
    'category': 'category-groceries',
    'split': 'true',
    'splitCount': '2',
    'splitAmount': '600.00',
    'splitCategory': 'category-other',
  });
  final shoes = expense(-13, 'Work shoes', bank, 'other', '2200.00');
  post('refund', {
    'date': day(-3),
    'name': '',
    'source': shoes,
    'sourceVersion': '1',
    'amount': '400.00',
    'account': bank,
    'reason': 'Returned the insoles',
    'refundPosting': '$shoes-p2',
  });
  final taxi = expense(-7, 'Taxi home', wallet, 'transport', '320.00');
  post('correction', {
    'date': day(-7),
    'name': 'Taxi home',
    'source': taxi,
    'sourceVersion': '1',
    'reason': 'Typed the wrong fare',
    'amount': '230.00',
    'account': wallet,
    'category': 'category-transport',
  });
  final beans = expense(-5, 'Coffee beans', cash, 'food', '260.00');
  post('reversal', {
    'source': beans,
    'sourceVersion': '1',
    'reason': 'Logged it twice',
  });
  post('transfer', {
    'date': day(-16),
    'name': 'Move to savings',
    'account': wallet,
    'destination': bank,
    'amount': '500.00',
    'fee': '15.00',
    'feeTreatment': 'source_additional',
    'feeCategory': 'category-fees',
    'feeDate': '',
  });
  post('adjustment', {
    'date': day(-2),
    'account': cash,
    'amount': '-20.00',
    'reason': 'Counted my wallet',
    'mode': 'manual',
  });
  // Dated after today, so it isn't in any balance yet.
  expense(3, 'Insurance premium', bank, 'bills', '1200.00');
  // A closed account: nothing in it, so it doesn't change Available money.
  final closed = post('account', {
    'name': 'Old savings',
    'kind': 'Savings',
    'amount': '0.00',
    'cutoff': cutoff,
  });
  post('archive', {'account': closed, 'reason': 'Closed this account'});

  // Debts: one with a payment due soon, one overdue, one paid off.
  String debt(String name, String type, String amount) => post('debtImport', {
    'date': day(-68),
    'name': name,
    'lender': 'Sample lender',
    'debtType': type,
    'amount': amount,
    'principal': '',
  });
  String schedule(
    String debtId,
    String name,
    String firstDue,
    String frequency,
    String installment,
    int count, {
    String intervalDays = '',
  }) => post('debtSchedule', {
    'date': day(-68),
    'name': name,
    'debt': debtId,
    'schedule': debtCadenceRows(
      firstDue: firstDue,
      frequency: frequency,
      installmentAmount: installment,
      count: count,
      intervalDays: intervalDays,
    ),
    'verified': 'true',
    'reference': 'Sample agreement',
    'frequency': frequency,
    'firstDue': firstDue,
    'installmentAmount': installment,
    if (intervalDays.isNotEmpty) 'intervalDays': intervalDays,
  });
  void pay(
    String debtId,
    String scheduleId,
    int offset,
    String installment,
    String amount,
  ) => post('debtPayment', {
    'date': day(offset),
    'name': 'Payment',
    'debt': debtId,
    'account': bank,
    'amount': amount,
    'externalFee': '0.00',
    'reduction': amount,
    'interest': '0.00',
    'fee': '0.00',
    'clearing': '0.00',
    'certainty': 'confirmed_total',
    'scheduleSource': scheduleId,
    'allocations': '$installment,$amount',
    'unapplied': '0.00',
  });

  final phone = debt('Phone installment', 'installment_loan', '12000.00');
  final phonePlan = schedule(
    phone,
    'Phone installment',
    day(-54),
    'custom',
    '2000.00',
    6,
    intervalDays: '28',
  );
  pay(phone, phonePlan, -54, 'Installment 1', '2000.00');
  pay(phone, phonePlan, -26, 'Installment 2', '2000.00');

  final family = debt('Loan from Tita Rosa', 'personal_loan', '5000.00');
  final familyPlan = schedule(
    family,
    'Loan from Tita Rosa',
    day(-31),
    'custom',
    '1000.00',
    5,
    intervalDays: '14',
  );
  pay(family, familyPlan, -31, 'Installment 1', '1000.00');
  pay(family, familyPlan, -17, 'Installment 2', '1000.00');

  final laptop = debt('Laptop loan', 'installment_loan', '3000.00');
  final laptopPlan = schedule(
    laptop,
    'Laptop loan',
    day(-55),
    'custom',
    '1500.00',
    2,
    intervalDays: '30',
  );
  pay(laptop, laptopPlan, -55, 'Installment 1', '1500.00');
  pay(laptop, laptopPlan, -25, 'Installment 2', '1500.00');

  // No schedule yet.
  debt('Emergency loan', 'personal_loan', '8000.00');

  // Closed by an early payoff.
  final scooter = debt('Scooter loan', 'installment_loan', '6000.00');
  final scooterPlan = schedule(
    scooter,
    'Scooter loan',
    day(-40),
    'custom',
    '2000.00',
    3,
    intervalDays: '30',
  );
  pay(scooter, scooterPlan, -40, 'Installment 1', '2000.00');
  post('debtPayoff', {
    'date': day(-8),
    'name': 'Scooter loan payoff',
    'debt': scooter,
    'account': bank,
    'amount': '4000.00',
    'providerPayoff': '4000.00',
    'reduction': '4000.00',
    'interest': '0.00',
    'fee': '0.00',
    'waiver': '0.00',
    'avoided': '0.00',
    'verified': 'true',
    'reference': 'Payoff letter',
    'reason': 'Paid off early',
  });

  // A different amount each time, a partial payment, and a payment logged
  // before its breakdown was known.
  final appliance = debt('Appliance plan', 'bnpl', '9000.00');
  final applianceDue = day(-20);
  final appliancePlan = post('debtSchedule', {
    'date': day(-68),
    'name': 'Appliance plan',
    'debt': appliance,
    'schedule': debtScheduleRows(
      firstDue: applianceDue,
      frequency: 'custom',
      amounts: [
        for (final v in [2000, 3000, 4000]) BigInt.from(v * 100),
      ],
      intervalDays: '30',
    ),
    'verified': 'true',
    'reference': 'Sample agreement',
    'frequency': 'custom',
    'firstDue': applianceDue,
    'intervalDays': '30',
    'splitMode': 'varied',
    'installmentAmount': '',
  });
  pay(appliance, appliancePlan, -20, 'Installment 1', '2000.00');
  pay(appliance, appliancePlan, -5, 'Installment 2', '500.00');
  post('debtPayment', {
    'date': day(-4),
    'name': 'Payment',
    'debt': appliance,
    'account': bank,
    'amount': '750.00',
    'externalFee': '0.00',
    'reduction': '0.00',
    'interest': '0.00',
    'fee': '0.00',
    'clearing': '750.00',
    'certainty': 'unresolved',
    'scheduleSource': '',
    'allocations': '',
    'unapplied': '750.00',
  });

  // A card with a statement due within the week.
  final card = post('creditCard', {
    'date': day(-68),
    'name': 'Rewards card',
    'issuer': 'Sample bank',
    'amount': '0.00',
    'limit': '50000.00',
  });
  post('cardPurchase', {
    'date': day(-12),
    'name': 'New running shoes',
    'card': card,
    'amount': '4800.00',
    'postingDate': day(-12),
    'category': 'category-other',
  });
  post('statement', {
    'date': day(-10),
    'name': 'Rewards card statement',
    'card': card,
    'start': day(-40),
    'end': day(-10),
    'issued': day(-10),
    'due': day(5),
    'amount': '4800.00',
    'minimum': '500.00',
    'reference': 'Sample statement',
    'verified': 'true',
  });

  // Fifty pesos short of what was logged, with nothing done about it yet.
  // Last, so nothing logged afterwards changes what it compared.
  post('reconcile', {
    'date': day(-1),
    'account': wallet,
    'mode': 'compare',
    'amount': phpDecimal(
      s.balance(wallet, through: day(-1)) - BigInt.from(5000),
    ),
  });

  // Budgets for this month.
  final start = monthStart(today);
  final next = addCivilDays(monthEnd(today), 1);
  for (final (name, category, amount) in [
    ('Food & drink allowance', 'food', '9000.00'),
    ('Transport', 'transport', '2000.00'),
    ('Groceries', 'groceries', '7000.00'),
  ]) {
    post('budget', {
      'date': start,
      'name': name,
      'amount': amount,
      'category': 'category-$category',
      'start': start,
      'endExclusive': next,
      'basis': 'net',
      'status': 'active',
    });
  }
  return s;
}

final _cache = <String, LocalSnapshot>{};

/// The sample profile for [today], built once a day.
LocalSnapshot demoSample(String today, {bool empty = false}) =>
    _cache.putIfAbsent(
      '$today:$empty',
      () => demoOverviewSnapshot(today, empty: empty),
    );

/// The Overview's source for the demo build: the sample profile, with the
/// demo session's scenario (empty, incomplete, waiting changes, review) and
/// hidden amounts applied.
OverviewSource demoOverviewSource(
  BuildContext context,
  PrototypeSession session,
  ValueChanged<PreviewSource> open,
) {
  final today = civilToday();
  final empty = session.empty;
  final s = demoSample(today, empty: empty);
  String name(String? id) =>
      s.categories.where((c) => c.id == id).firstOrNull?.name ?? 'No category';
  final available = sumMinor(
    s.accounts.map((a) => s.balance(a.id, through: today)),
  );
  // As `LocalFinancialController.cardLiabilityAndCredit` splits them.
  var cardDebt = BigInt.zero, credit = BigInt.zero;
  final cards = s.current.where((r) => financeType(r) == 'creditCard');
  for (final card in cards) {
    final owed = -financeBalance(
      s,
      'card_liability',
      'card',
      card.actionId,
      through: today,
    );
    if (owed > BigInt.zero) {
      cardDebt += owed;
    } else {
      credit -= owed;
    }
  }
  // Newest first by date, then by when it was logged.
  final recent = [
    for (final r in s.current.reversed)
      if (['expense', 'income', 'transfer'].contains(r.kind) &&
          r.date.compareTo(today) <= 0)
        r,
  ]..sort((a, b) => b.date.compareTo(a.date));

  final life = empty
      ? const <OverviewRow>[]
      : <OverviewRow>[
          for (final (offset, title, time, kind) in [
            (1, 'Dentist appointment', '10:00', 'Events'),
            (2, 'Renew driver’s license', 'All day', 'Tasks'),
            (4, 'Book club', '19:00', 'Events'),
          ])
            (
              icon: kind == 'Tasks'
                  ? Icons.check_circle_outline
                  : Icons.event_outlined,
              title: title,
              subtitle:
                  '${civilLabel(addCivilDays(today, offset))} · $time · $kind',
              amount: null,
              onTap: () => open(PreviewSource.agenda),
            ),
        ];
  return OverviewSource(
    today: today,
    accepted: s,
    current: s,
    complete: session.complete,
    hidden: session.hideAmounts,
    available: session.complete ? available : null,
    amount: session.amount,
    categoryName: name,
    cards: cards.isEmpty ? null : (cardDebt, credit),
    pending: session.pending,
    pendingCount: session.pending ? 1 : 0,
    projected: session.pending ? available - DemoMoney.expense : null,
    needsReview: session.needsReview,
    syncLabel: session.syncLabel,
    onReview: () => open(PreviewSource.privateReview),
    openRecord: (id, _) => demoMoneySource(context, session).actions.openRecord(id),
    shared: empty
        ? const []
        : [
            (
              icon: Icons.people_outline,
              title: '1 payment to confirm',
              subtitle: 'Tala reported a payment · example',
              amount: null,
              onTap: () => open(PreviewSource.settlement),
            ),
          ],
    life: life,
    recent: [
      for (final r in recent.take(10))
        (
          icon: r.kind == 'income'
              ? Icons.south_west
              : r.kind == 'transfer'
              ? Icons.swap_horiz
              : Icons.north_east,
          title: r.title,
          date: r.date,
          category: r.kind == 'transfer'
              ? 'Transfer'
              : name(
                  r.postings
                      .where((p) => p.category != null)
                      .firstOrNull
                      ?.category,
                ),
          amount: session.amount(r.amount),
          onTap: () => demoMoneySource(context, session).actions.openRecord(r.id),
        ),
    ],
  );
}
