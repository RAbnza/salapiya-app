import 'dart:convert';

import 'package:flutter/material.dart';

import '../connected/financial_contract.dart';
import '../local/finance_domain.dart';
import '../local/local_store.dart' show defaultLocalCategories;
import '../finance/money_data.dart' show moneyActivity;
import '../finance/money_demo.dart';
import '../life/life_cards.dart' show nextUpRow;
import '../life/life_controller.dart' show lifeAgendaItems, sortedAgenda;
import '../life/life_data.dart' show LifeRow;
import '../life/life_demo.dart' show demoLife;
import '../life/life_hub.dart' show lifeHubOf;
import '../shared/shared_demo.dart'
    show demoLinkedBill, demoPrivateBill, demoPrivatePayment, demoToConfirmLine;
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
  String post(String kind, Map<String, String> values, {String? stableId}) {
    final id =
        stableId ??
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
  var internet = '';
  for (final base in [-62, -32, -2]) {
    expense(base, 'Electricity', bank, 'bills', '${2180 + base.abs() * 3}.40');
    internet = expense(base + 1, 'Home internet', bank, 'bills', '1699.00');
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
  // A bill the user paid for the group, linked to their own record.
  final linked = demoLinkedBill(today);
  post('shared', {
    'name': 'Shared bill · ${linked.name}',
    'date': linked.date,
    'sharedMode': 'bill',
    'sharedAccounting': '2',
    'sharedGroup': linked.group,
    'sharedKey': linked.bill,
    'sharedRevision': linked.revision,
    'fundingAmount': linked.paid,
    'shareAmount': linked.part,
    'account': bank,
    'category': 'category-bills',
    'reason': '',
    'funding': 'cash',
    'acknowledgeFunding': 'false',
  });
  // The rest of My Records: two bills added before they were corrected, a
  // payment still to count and one already counted.
  post('shared', demoPrivateBill(today, 'Weekly market'));
  post('shared', demoPrivateBill(today, 'Car repair'));
  post('shared', {...demoPrivatePayment(today, '400.00'), 'account': bank});
  final counted = demoPrivatePayment(today, '775.00');
  final payment = post('shared', {...counted, 'account': bank});
  post('shared', {
    ...counted,
    'name': 'Shared clear · Household',
    'sharedMode': 'clear',
    'account': '',
    'paymentSource': payment,
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
  final runningShoes = post('cardPurchase', {
    'date': day(-12),
    'name': 'New running shoes',
    'card': card,
    'amount': '4800.00',
    'postingDate': day(-12),
    'category': 'category-other',
  });
  final onlineOrder = post('cardPurchase', {
    'date': day(-6),
    'name': 'Online order',
    'card': card,
    'amount': '1350.00',
    'postingDate': day(-5),
    'category': 'category-other',
  });
  post('cardRefund', {
    'date': day(-2),
    'name': 'Online order refund',
    'card': card,
    'purchase': onlineOrder,
    'amount': '200.00',
    'category': 'category-other',
    'reason': 'Returned one item',
  });
  post('cardFee', {
    'date': day(-9),
    'name': 'Annual fee',
    'card': card,
    'amount': '250.00',
    'postingDate': day(-9),
    'category': 'category-fees',
  });
  post('cardAuthorization', {
    'date': day(-1),
    'name': 'Hotel hold',
    'card': card,
    'amount': '650.00',
    'reference': 'Entered by me',
  });
  final rewards = post('statement', {
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
  post('statementLink', {
    'date': day(-10),
    'name': 'Matched · New running shoes',
    'card': card,
    'statement': rewards,
    'activity': runningShoes,
    'verified': 'true',
  });
  final rewardsPaid = post('cardPayment', {
    'date': day(-3),
    'name': 'Payment · Rewards card',
    'card': card,
    'account': bank,
    'amount': '1000.00',
  });
  post('cardAllocation', {
    'date': day(-3),
    'name': 'Matched payment · Rewards card statement',
    'card': card,
    'statement': rewards,
    'payment': rewardsPaid,
    'amount': '1000.00',
    'verified': 'true',
  });

  // A card over its limit, with an installment plan on a statement that
  // differs from the records.
  final travel = post('creditCard', {
    'date': day(-68),
    'name': 'Travel card',
    'issuer': 'Sample bank',
    'amount': '0.00',
    'limit': '5000.00',
  });
  final flight = post('cardPurchase', {
    'date': day(-50),
    'name': 'Flight to Cebu',
    'card': travel,
    'amount': '6000.00',
    'postingDate': day(-49),
    'category': 'category-other',
  });
  post('cardInterest', {
    'date': day(-12),
    'name': 'Card interest',
    'card': travel,
    'amount': '60.00',
    'postingDate': day(-12),
    'category': 'category-fees',
  });
  final plan = post('installment', {
    'date': day(-49),
    'name': 'Flight to Cebu installment plan',
    'card': travel,
    'purchase': flight,
    'schedule': debtCadenceRows(
      firstDue: day(-20),
      frequency: 'monthly',
      installmentAmount: '1000.00',
      count: 6,
    ),
    'principal': '',
    'interest': '',
    'fee': '',
    'reference': 'Entered by me',
    'verified': 'true',
  });
  final travelBill = post('statement', {
    'date': day(-11),
    'name': 'Travel card statement',
    'card': travel,
    'start': day(-41),
    'end': day(-12),
    'issued': day(-11),
    'due': day(8),
    'amount': '6180.00',
    'minimum': '600.00',
    'reference': 'Sample statement',
    'verified': 'true',
  });
  final travelPaid = post('cardPayment', {
    'date': day(-9),
    'name': 'Payment · Travel card',
    'card': travel,
    'account': bank,
    'amount': '1000.00',
  });
  final travelMatch = post('cardAllocation', {
    'date': day(-9),
    'name': 'Matched payment · Travel card statement',
    'card': travel,
    'statement': travelBill,
    'payment': travelPaid,
    'amount': '1000.00',
    'verified': 'true',
  });
  post('installmentApplication', {
    'date': day(-9),
    'name': 'Matched payment · Flight to Cebu installment plan',
    'card': travel,
    'plan': plan,
    'row': 'Installment 1',
    'payment': travelMatch,
    'amount': '1000.00',
    'verified': 'true',
  });

  // Paid more than was owed: a card credit, which isn't money you have.
  final store = post('creditCard', {
    'date': day(-68),
    'name': 'Store card',
    'issuer': 'Sample store',
    'amount': '0.00',
    'limit': '',
  });
  post('cardPurchase', {
    'date': day(-15),
    'name': 'Kitchen shelf',
    'card': store,
    'amount': '500.00',
    'postingDate': day(-15),
    'category': 'category-other',
  });
  post('cardPayment', {
    'date': day(-8),
    'name': 'Payment · Store card',
    'card': store,
    'account': bank,
    'amount': '800.00',
  });

  // Recurring items: added dates, a skipped one, a linked one, one not added
  // yet and an archived one.
  String recurring(
    String name,
    String kind,
    String amount,
    Map<String, String> when, {
    String account = '',
    String status = 'active',
  }) => post('recurrence', {
    'date': day(-60),
    'name': name,
    'recurringKind': kind,
    'amount': amount,
    'interval': '1',
    'weekdays': '1',
    'monthDay': '1',
    'monthPolicy': 'last_valid_day',
    'start': day(-60),
    'end': '',
    'count': '',
    'timezone': 'Asia/Manila',
    'account': account,
    'status': status,
    ...when,
  });
  void addDates(String rule, String name, int from) =>
      post('recurrenceGenerate', {
        'date': today,
        'name': '$name dates',
        'rule': rule,
        'from': day(from),
        'through': day(from + 89),
      });
  String monthly(int offset) => '${DateTime.parse(day(offset)).day}';
  final rent = recurring('Rent', 'bill', '8000.00', {
    'frequency': 'monthly',
    'monthDay': monthly(2),
  }, account: bank);
  addDates(rent, 'Rent', 0);
  final net = recurring('Home internet', 'bill', '1699.00', {
    'frequency': 'monthly',
    'monthDay': monthly(-1),
  }, account: bank);
  addDates(net, 'Home internet', -1);
  post('recurrenceLink', {
    'date': today,
    'name': 'Home internet linked',
    'rule': net,
    'logicalDate': day(-1),
    'actual': internet,
    'amount': '1699.00',
  });
  final streaming = recurring('Streaming plan', 'subscription', '350.00', {
    'frequency': 'monthly',
    'monthDay': monthly(12),
  }, account: bank);
  addDates(streaming, 'Streaming plan', 0);
  post('occurrenceOverride', {
    'date': today,
    'name': 'Streaming plan date changed',
    'rule': streaming,
    'logicalDate': day(12),
    'amount': '350.00',
    'due': day(12),
    'state': 'skipped',
    'reason': 'Paused for a month',
  });
  recurring('Salary', 'income', '15000.00', {
    'frequency': 'weekly',
    'interval': '2',
    'weekdays': '${DateTime.parse(day(1)).weekday}',
    'start': day(1),
  }, account: bank);
  recurring('Gym membership', 'bill', '1200.00', {
    'frequency': 'monthly',
  }, status: 'archived');

  // Takes the wallet below what's set aside in it, for a shared shortfall.
  expense(0, 'Service charge', wallet, 'fees', '300.00');

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

  // Budgets for this month, one over its limit and one at zero, then one
  // for last month, one for next month and an archived one.
  final start = monthStart(today);
  final next = addCivilDays(monthEnd(today), 1);
  final previous = monthStart(addCivilDays(start, -1));
  final after = addCivilDays(monthEnd(next), 1);
  void budget(
    String name,
    String category,
    String amount, {
    String? from,
    String? to,
    String status = 'active',
  }) => post('budget', {
    'date': today,
    'name': name,
    'amount': amount,
    'category': 'category-$category',
    'start': from ?? start,
    'endExclusive': to ?? next,
    'basis': 'net',
    'status': status,
  });
  budget('Food & drink allowance', 'food', '9000.00');
  budget('Transport', 'transport', '2000.00');
  budget('Groceries', 'groceries', '7000.00');
  budget('Fees', 'fees', '100.00');
  budget('Bills held at zero', 'bills', '0.00');
  budget('Food last month', 'food', '9500.00', from: previous, to: start);
  budget('Food next month', 'food', '9000.00', from: next, to: after);
  budget(
    'Transport last month',
    'transport',
    '2500.00',
    from: previous,
    to: start,
    status: 'archived',
  );

  // Goals: funded, partly funded, two sharing a short account, a completed
  // one and an archived one.
  String goal(
    String name,
    String amount, {
    String targetDate = '',
    String status = 'active',
  }) => post('savingsGoal', {
    'date': day(-30),
    'name': name,
    'amount': amount,
    'targetDate': targetDate,
    'status': status,
  });
  void setAside(String goalId, String account, BigInt amount) =>
      post('reservation', {
        'date': day(-1),
        'name': 'Set aside',
        'goal': goalId,
        'account': account,
        'amount': phpDecimal(amount),
      });
  final fund = goal('Emergency fund', '10000.00');
  setAside(fund, bank, BigInt.from(1000000));
  final computer = goal('New laptop', '40000.00', targetDate: day(120));
  setAside(computer, cash, BigInt.from(50000));
  final inWallet = s.balance(wallet, through: day(-1));
  final half = inWallet ~/ BigInt.two;
  final trip = goal('Holiday trip', '5000.00', targetDate: day(60));
  setAside(trip, wallet, half);
  final gift = goal('Family gift', '2000.00');
  setAside(gift, wallet, inWallet - half);
  goal('Phone repair', '1500.00', status: 'completed');
  goal('Old bike fund', '3000.00', status: 'archived');

  void attach(String name, String mime, String source, int size) =>
      post('financialFile', {
        'name': name,
        'date': day(-8),
        'sourceRevision': source,
        'mime': mime,
        'size': '$size',
        'checksum': '0123456789abcdef' * 4,
      });
  attach('running-shoes-receipt.pdf', 'application/pdf', runningShoes, 184320);
  attach(demoMissingFile, 'application/pdf', flight, 2202009);
  final oldPhoto = post('financialFile', {
    'name': 'order-photo.png',
    'date': day(-20),
    'sourceRevision': onlineOrder,
    'mime': 'image/png',
    'size': '640000',
    'checksum': 'fedcba9876543210' * 4,
  });
  post('fileDetach', {
    'name': 'Archived link',
    'date': day(-6),
    'file': oldPhoto,
    'reason': 'Attached to the wrong order',
  });

  (String, String) stage(
    String name,
    String checksum,
    List<List<String>> rows,
  ) {
    final batch = post('cashImport', {
      'name': name,
      'date': today,
      'header': jsonEncode(_importHeader),
      'rowCount': '${rows.length}',
      'checksum': checksum * 8,
      'assumptions': jsonEncode({
        'sourceFormat': 'pmp-cash-activity',
        'formatVersion': 1,
        'currency': 'PHP',
        'account': bank,
        'mapping': {
          'date': 'date',
          'kind': 'kind',
          'amountMinor': 'amount_minor',
          'classification': 'classification',
          'description': 'description',
          'reference': 'reference',
        },
        'dateInterpretation': 'YYYY-MM-DD',
        'cutoffStrategy': 'after_opening',
        'earlierDate': null,
        'earlierMinor': null,
      }),
    });
    post('cashImportChunk', {
      'name': 'Original CSV staging rows',
      'date': today,
      'batch': batch,
      'offset': '0',
      'rowCount': '${rows.length}',
      for (final (i, row) in rows.indexed) 'row$i': jsonEncode(row),
    }, stableId: importStableId(_owner, batch, 'stage/0'));
    return (
      batch,
      post('cashImportPreview', {
        'name': 'Immutable cash CSV preview',
        'date': today,
        'batch': batch,
      }),
    );
  }

  // A finished import, one row left out. Its money nets to zero and its dates
  // are older than last month, so the sample's totals don't move.
  final (done, reviewed) = stage('bank-export-august.csv', 'a1b2c3d4', [
    [day(-69), 'income', '150000', 'earned', 'Freelance payment', 'BX-1001'],
    [day(-68), 'expense', '100000', 'expense', 'Office supplies', 'BX-1002'],
    [day(-68), 'expense', '50000', 'expense', 'Courier fees', 'BX-1003'],
    [day(-68), 'expense', '25000', 'expense', 'Duplicate courier', 'BX-1004'],
  ]);
  final decided = post('cashImportDecision', {
    'name': 'Reviewed CSV row decisions',
    'date': today,
    'preview': reviewed,
    'rowCount': '4',
    for (final (i, category) in const [
      'category-income',
      'category-other',
      'category-other',
      'category-other',
    ].indexed)
      'row$i': jsonEncode({
        'include': i < 3,
        'acknowledgeDuplicates': false,
        'category': category,
      }),
  });
  final process = LocalCommand(
    id: post('cashImportProcess', {
      'name': 'Reviewed bounded cash-history import',
      'date': today,
      'decision': decided,
      'rowNumbers': '[0,1,2]',
    }),
    owner: _owner,
    expectedVersion: s.version,
    kind: 'cashImportProcess',
    values: s.revisions.last.values,
  );
  for (final child in cashImportChildren(s, process)) {
    s = applyFinancialPlan(s, planLocal(s, child));
  }
  // One waiting for review, with a row to fix and a possible duplicate.
  stage('bank-export-october.csv', 'e5f60718', [
    [day(-12), 'income', '82000', 'gift', 'Birthday money', 'BX-2001'],
    [day(-11), 'expense', '45050', 'expense', 'Hardware store', 'BX-2002'],
    [day(-10), 'expense', '50000', 'expense', 'Courier fees', 'BX-1003'],
    [day(-90), 'expense', '12000', 'expense', 'Old parking fee', 'BX-2003'],
    [day(-9), 'expense', '18000', 'expense', 'Pharmacy', 'BX-2004'],
  ]);
  return s;
}

/// The file the demo shows as Missing.
const demoMissingFile = 'flight-itinerary.pdf';

const _importHeader = [
  'date',
  'kind',
  'amount_minor',
  'classification',
  'description',
  'reference',
];

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

  // The Calendar's own sample, so the two agree.
  final records = demoLife(today, empty: empty).records;
  final agenda = sortedAgenda([
    for (final item in lifeAgendaItems(records, today, addCivilDays(today, 30)))
      if (lifeHubOf(session).calendarShown(item.kind)) item,
  ]);
  final life = <OverviewRow>[
    for (final item in agenda.take(3))
      nextUpRow(
        context,
        LifeRow.record(item, records, today, 'Asia/Manila'),
        () => open(PreviewSource.agenda),
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
    openRecord: (id, _) =>
        demoMoneySource(context, session).actions.openRecord(id),
    openItem: (id) => demoMoneySource(context, session).actions.openItem(id),
    shared: empty
        ? const []
        : [
            (
              icon: Icons.people_outline,
              title: '1 payment to confirm',
              subtitle: demoToConfirmLine(today, session.amount),
              amount: null,
              onTap: () => open(PreviewSource.settlement),
            ),
          ],
    life: life,
    lifeMore: agenda.length > 3 ? agenda.length - 3 : 0,
    // Every row Money's Activity holds through today, so both say the same.
    activityCount: moneyActivity(
      s,
      name,
    ).where((r) => r.date.compareTo(today) <= 0).length,
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
          onTap: () =>
              demoMoneySource(context, session).actions.openRecord(r.id),
        ),
    ],
  );
}
