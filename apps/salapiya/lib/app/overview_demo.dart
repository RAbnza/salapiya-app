import 'package:flutter/material.dart';

import '../connected/financial_contract.dart';
import '../local/finance_domain.dart';
import '../local/local_store.dart' show defaultLocalCategories;
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
    for (final (i, a) in measured.accounts.indexed)
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
  void expense(
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
  final s = _cache.putIfAbsent(
    '$today:$empty',
    () => demoOverviewSnapshot(today, empty: empty),
  );
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
  void openRecord(String id, String title) => open(PreviewSource.activity);
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
    openRecord: openRecord,
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
          onTap: () => openRecord(r.id, r.title),
        ),
    ],
  );
}
