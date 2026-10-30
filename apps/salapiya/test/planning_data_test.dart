import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_data.dart';
import 'package:salapiya/app/overview_demo.dart';
import 'package:salapiya/connected/financial_contract.dart';
import 'package:salapiya/finance/planning_data.dart';
import 'package:salapiya/local/finance_domain.dart';

BigInt php(int pesos) => BigInt.from(pesos * 100);

class Book {
  Book() : s = demoOverviewSnapshot('2026-10-15', empty: true);
  LocalSnapshot s;
  int n = 0;
  String post(String kind, Map<String, String> values) {
    final id =
        '00000000-0000-4000-9000-${(++n).toRadixString(16).padLeft(12, '0')}';
    s = applyFinancialPlan(
      s,
      planLocal(
        s,
        LocalCommand(
          id: id,
          owner: s.owner,
          expectedVersion: s.version,
          kind: kind,
          values: {'acknowledge': 'false', ...values},
        ),
      ),
    );
    return id;
  }

  String account(String name, String amount) => post('account', {
    'name': name,
    'kind': 'Bank',
    'amount': amount,
    'cutoff': '2026-01-01',
  });

  String expense(String account, String amount, String date) =>
      post('expense', {
        'date': date,
        'name': 'Spent $amount',
        'account': account,
        'amount': amount,
        'category': 'category-food',
      });

  String budget({
    String amount = '1000.00',
    String start = '2026-10-01',
    String end = '2026-11-01',
    String basis = 'net',
    String status = 'active',
    String category = 'food',
  }) => post('budget', {
    'date': '2026-10-01',
    'name': 'Budget',
    'amount': amount,
    'category': 'category-$category',
    'start': start,
    'endExclusive': end,
    'basis': basis,
    'status': status,
  });

  String goal(
    String name,
    String amount, {
    String status = 'active',
    String targetDate = '',
  }) => post('savingsGoal', {
    'date': '2026-02-01',
    'name': name,
    'amount': amount,
    'targetDate': targetDate,
    'status': status,
  });

  void aside(String goal, String account, String amount) =>
      post('reservation', {
        'date': '2026-03-01',
        'name': 'Set aside',
        'goal': goal,
        'account': account,
        'amount': amount,
      });

  String rule(
    String name, {
    String kind = 'bill',
    String monthDay = '20',
    String amount = '500.00',
    String status = 'active',
    String account = '',
  }) => post('recurrence', {
    'date': '2026-01-05',
    'name': name,
    'recurringKind': kind,
    'amount': amount,
    'frequency': 'monthly',
    'interval': '1',
    'weekdays': '1',
    'monthDay': monthDay,
    'monthPolicy': 'last_valid_day',
    'start': '2026-01-05',
    'end': '',
    'count': '',
    'timezone': 'Asia/Manila',
    'account': account,
    'status': status,
  });

  void addDates(String rule, String from, String through) =>
      post('recurrenceGenerate', {
        'date': '2026-10-15',
        'name': 'Dates',
        'rule': rule,
        'from': from,
        'through': through,
      });
}

void main() {
  const today = '2026-10-15';

  group('budget periods', () {
    test('the last day is the day before the stored end', () {
      expect(lastDay('2026-11-01'), '2026-10-31');
      expect(lastDay('2024-03-01'), '2024-02-29');
      expect(lastDay('2027-01-01'), '2026-12-31');
    });

    test('a whole month reads as its name, anything else as a span', () {
      final book = Book();
      book.budget();
      book.budget(
        start: '2026-11-03',
        end: '2026-11-11',
        category: 'transport',
      );
      final labels = book.s.current
          .where((r) => financeType(r) == 'budget')
          .map(budgetPeriodLabel);
      expect(labels, ['October 2026', '3–10 Nov']);
    });

    test('when a budget applies, edges included', () {
      final book = Book();
      final r = book.s.revisions;
      expect(r, isEmpty);
      book.budget();
      final b = book.s.current.single;
      expect(budgetWhen(b, '2026-09-30'), BudgetWhen.later);
      expect(budgetWhen(b, '2026-10-01'), BudgetWhen.current);
      expect(budgetWhen(b, '2026-10-31'), BudgetWhen.current);
      expect(budgetWhen(b, '2026-11-01'), BudgetWhen.past);
    });

    test('archived budgets leave current, whatever their dates', () {
      final book = Book();
      book.budget(status: 'archived');
      final rows = budgetRows(book.s, today);
      expect(rows.single.$1, BudgetWhen.archived);
      expect(activeBudgets(book.s, today), isEmpty);
    });

    test('current first, then later, past and archived', () {
      final book = Book();
      book.budget(start: '2026-09-01', end: '2026-10-01');
      book.budget(start: '2026-11-01', end: '2026-12-01');
      book.budget();
      book.budget(category: 'transport', status: 'archived');
      expect(budgetRows(book.s, today).map((r) => r.$1), [
        BudgetWhen.current,
        BudgetWhen.later,
        BudgetWhen.past,
        BudgetWhen.archived,
      ]);
    });
  });

  group('budget amounts', () {
    BudgetProgress single(Book book) => budgetRows(book.s, today).single.$2;

    test('over the limit', () {
      final book = Book();
      final bank = book.account('Bank', '5000.00');
      book.budget(amount: '100.00');
      book.expense(bank, '150.00', '2026-10-05');
      final b = single(book);
      expect(b.spent, php(150));
      expect(b.remaining, -php(50));
      expect(b.over, php(50));
      expect(b.basisPoints, 15000);
    });

    test('a zero limit has no percentage', () {
      final book = Book();
      final bank = book.account('Bank', '5000.00');
      book.budget(amount: '0.00');
      book.expense(bank, '10.00', '2026-10-05');
      final b = single(book);
      expect(b.basisPoints, isNull);
      expect(b.over, php(10));
    });

    test('net subtracts refunds; gross does not', () {
      final book = Book();
      final bank = book.account('Bank', '5000.00');
      book.budget(amount: '500.00');
      final bought = book.expense(bank, '300.00', '2026-10-05');
      book.post('refund', {
        'date': '2026-10-06',
        'name': '',
        'source': bought,
        'sourceVersion': '1',
        'amount': '100.00',
        'account': bank,
        'reason': 'Returned',
        'refundPosting': '$bought-p2',
      });
      expect(single(book).spent, php(200));
      final gross = Book();
      final other = gross.account('Bank', '5000.00');
      gross.budget(amount: '500.00', basis: 'gross');
      final spent = gross.expense(other, '300.00', '2026-10-05');
      gross.post('refund', {
        'date': '2026-10-06',
        'name': '',
        'source': spent,
        'sourceVersion': '1',
        'amount': '100.00',
        'account': other,
        'reason': 'Returned',
        'refundPosting': '$spent-p2',
      });
      expect(single(gross).spent, php(300));
    });

    test('a refund larger than spending goes below zero', () {
      final book = Book();
      final bank = book.account('Bank', '5000.00');
      final bought = book.expense(bank, '300.00', '2026-09-20');
      book.budget(amount: '500.00');
      book.post('refund', {
        'date': '2026-10-06',
        'name': '',
        'source': bought,
        'sourceVersion': '1',
        'amount': '100.00',
        'account': bank,
        'reason': 'Returned',
        'refundPosting': '$bought-p2',
      });
      final b = single(book);
      expect(b.spent, -php(100));
      expect(b.remaining, php(600));
      expect(b.over, BigInt.zero);
    });

    test('reversed spending stops counting', () {
      final book = Book();
      final bank = book.account('Bank', '5000.00');
      book.budget(amount: '500.00');
      final bought = book.expense(bank, '300.00', '2026-10-05');
      book.post('reversal', {
        'source': bought,
        'sourceVersion': '1',
        'reason': 'Logged twice',
      });
      expect(single(book).spent, BigInt.zero);
    });

    test('corrected spending counts its new amount once', () {
      final book = Book();
      final bank = book.account('Bank', '5000.00');
      book.budget(amount: '500.00');
      final bought = book.expense(bank, '300.00', '2026-10-05');
      book.post('correction', {
        'date': '2026-10-05',
        'name': 'Spent',
        'source': bought,
        'sourceVersion': '1',
        'reason': 'Wrong amount',
        'amount': '250.00',
        'account': bank,
        'category': 'category-food',
      });
      expect(single(book).spent, php(250));
    });
  });

  group('sameBudgetTerms', () {
    test('only budgets sharing a period and basis can be added up', () {
      final book = Book();
      book.budget();
      book.budget(category: 'transport');
      final same = activeBudgets(book.s, today);
      expect(sameBudgetTerms(same), isTrue);
      book.budget(category: 'bills', basis: 'gross');
      expect(sameBudgetTerms(activeBudgets(book.s, today)), isFalse);
      final other = Book();
      other.budget();
      other.budget(
        category: 'transport',
        start: '2026-10-10',
        end: '2026-10-20',
      );
      expect(sameBudgetTerms(activeBudgets(other.s, today)), isFalse);
    });

    test('nothing to add up is fine', () {
      expect(sameBudgetTerms(const []), isTrue);
    });
  });

  group('goals', () {
    test('fully funded needs the low bound to meet the target', () {
      final book = Book();
      final bank = book.account('Bank', '5000.00');
      final goal = book.goal('Trip', '1000.00');
      book.aside(goal, bank, '1000.00');
      final row = goalRows(book.s, today).single;
      expect(row.funding, GoalFunding.funded);
      expect(row.basisPoints, 10000);
      expect(row.excess, BigInt.zero);
    });

    test('nothing set aside is not funded', () {
      final book = Book();
      book.account('Bank', '5000.00');
      book.goal('Trip', '1000.00');
      expect(goalRows(book.s, today).single.funding, GoalFunding.none);
    });

    test('partly funded when set aside is below the target and covered', () {
      final book = Book();
      final bank = book.account('Bank', '5000.00');
      final goal = book.goal('Trip', '1000.00');
      book.aside(goal, bank, '250.00');
      final row = goalRows(book.s, today).single;
      expect(row.funding, GoalFunding.partly);
      expect(row.basisPoints, 2500);
    });

    test('two goals sharing a short account: no goal wins', () {
      final book = Book();
      final bank = book.account('Bank', '1000.00');
      final a = book.goal('A', '600.00');
      final b = book.goal('B', '400.00');
      book.aside(a, bank, '600.00');
      book.aside(b, bank, '400.00');
      book.expense(bank, '300.00', '2026-10-01');
      final rows = goalRows(book.s, today);
      final first = rows.firstWhere((r) => r.goal.title == 'A');
      final second = rows.firstWhere((r) => r.goal.title == 'B');
      expect((first.low, first.high), (php(300), php(600)));
      expect((second.low, second.high), (php(100), php(400)));
      expect(first.funding, GoalFunding.shared);
      expect(second.funding, GoalFunding.shared);
      final accounts = goalAccounts(book.s, a, today);
      expect(accounts.single.shortfall, php(300));
    });

    test('spending everything leaves a goal not funded', () {
      final book = Book();
      final bank = book.account('Bank', '1000.00');
      final goal = book.goal('Trip', '1000.00');
      book.aside(goal, bank, '1000.00');
      book.expense(bank, '1000.00', '2026-10-01');
      final row = goalRows(book.s, today).single;
      expect(row.reserved, php(1000));
      expect(row.funding, GoalFunding.none);
    });

    test('a target lowered below what is set aside shows the excess', () {
      final book = Book();
      final bank = book.account('Bank', '5000.00');
      final goal = book.goal('Trip', '1000.00');
      book.aside(goal, bank, '1000.00');
      book.post('financeCorrection', {
        'replace': goal,
        'replaceVersion': '1',
        'reason': 'Cheaper now',
        'amount': '800.00',
        'date': today,
      });
      final row = goalRows(book.s, today).single;
      expect(row.excess, php(200));
      expect(row.basisPoints, 12500);
    });

    test('active first, then completed, then archived', () {
      final book = Book();
      book.goal('Old', '100.00', status: 'archived');
      book.goal('Done', '100.00', status: 'completed');
      book.goal('Now', '100.00');
      expect(goalRows(book.s, today).map((g) => g.goal.title), [
        'Now',
        'Done',
        'Old',
      ]);
    });
  });

  group('recurring', () {
    test('how often, in words', () {
      LocalRevision rule(Map<String, String> values) => LocalRevision(
        id: 'x',
        actionId: 'x',
        kind: 'adjustment',
        change: 'create',
        date: today,
        title: 'x',
        amount: BigInt.zero,
        values: values,
        postings: const [],
        number: 1,
      );
      expect(
        recurringLabel(rule({'frequency': 'monthly', 'monthDay': '1'})),
        'Monthly on the 1st',
      );
      expect(
        recurringLabel(rule({'frequency': 'monthly', 'monthDay': '22'})),
        'Monthly on the 22nd',
      );
      expect(
        recurringLabel(rule({'frequency': 'monthly', 'monthDay': '13'})),
        'Monthly on the 13th',
      );
      expect(
        recurringLabel(
          rule({'frequency': 'weekly', 'interval': '2', 'weekdays': '1,3'}),
        ),
        'Every 2 weeks on Mon, Wed',
      );
      expect(
        recurringLabel(rule({'frequency': 'daily', 'interval': '3'})),
        'Every 3 days',
      );
    });

    test('a new item shows as expected before its dates are added', () {
      final book = Book();
      book.rule('Rent');
      final rows = upcomingRows(book.s, today);
      expect(rows.single.expected, isTrue);
      expect(rows.single.date, '2026-10-20');
      expect(rows.single.title, 'Rent');
      final item = recurringRows(book.s, today).single;
      expect(item.added, isFalse);
      expect(item.next!.due, '2026-10-20');
    });

    test('added dates aren’t listed twice', () {
      final book = Book();
      final rule = book.rule('Rent');
      book.addDates(rule, today, '2027-01-12');
      final rows = upcomingRows(book.s, today);
      expect(rows.single.expected, isFalse);
      expect(recurringRows(book.s, today).single.added, isTrue);
    });

    test('expected income is marked as income', () {
      final book = Book();
      book.rule('Salary', kind: 'income');
      expect(upcomingRows(book.s, today).single.income, isTrue);
    });

    test('an archived item adds nothing and sorts last', () {
      final book = Book();
      book.rule('Gym', status: 'archived');
      book.rule('Rent');
      expect(upcomingRows(book.s, today).map((r) => r.title), ['Rent']);
      expect(recurringRows(book.s, today).map((r) => r.rule.title), [
        'Rent',
        'Gym',
      ]);
    });

    test('a skipped date leaves Upcoming and stays in its dates', () {
      final book = Book();
      final rule = book.rule('Rent');
      book.addDates(rule, today, '2026-10-31');
      book.post('occurrenceOverride', {
        'date': today,
        'name': 'Rent date changed',
        'rule': rule,
        'logicalDate': '2026-10-20',
        'amount': '500.00',
        'due': '2026-10-20',
        'state': 'skipped',
        'reason': 'Paused',
      });
      expect(upcomingRows(book.s, today), isEmpty);
      final record = book.s.revision(rule);
      final dates = recurringDatesFor(book.s, record, today);
      expect(dates.first.state, 'skipped');
    });

    test('a date moved past the window leaves it', () {
      final book = Book();
      final rule = book.rule('Rent');
      book.addDates(rule, today, '2026-10-31');
      book.post('occurrenceOverride', {
        'date': today,
        'name': 'Rent date changed',
        'rule': rule,
        'logicalDate': '2026-10-20',
        'amount': '500.00',
        'due': '2026-12-20',
        'state': 'planned',
        'reason': 'Moved',
      });
      expect(upcomingRows(book.s, today).any((r) => !r.expected), isFalse);
    });

    test('a partly linked date shows what is left', () {
      final book = Book();
      final bank = book.account('Bank', '5000.00');
      final rule = book.rule('Rent');
      book.addDates(rule, today, '2026-10-31');
      final paid = book.expense(bank, '200.00', '2026-10-15');
      book.post('recurrenceLink', {
        'date': today,
        'name': 'Rent linked',
        'rule': rule,
        'logicalDate': '2026-10-20',
        'actual': paid,
        'amount': '200.00',
      });
      expect(upcomingRows(book.s, today).first.amount, php(300));
      final dates = recurringDatesFor(book.s, book.s.revision(rule), today);
      expect(dateStateLabel(dates.first.state), 'Part linked');
    });

    test('the window is today and the next 29 days', () {
      final book = Book();
      book.rule('Soon', monthDay: '15');
      book.rule('Edge', monthDay: '13');
      final rows = upcomingRows(book.s, today, days: 30);
      expect(rows.map((r) => r.date), ['2026-10-15', '2026-11-13']);
      expect(rows.first.days, 0);
    });
  });

  group('forecast', () {
    test('the default runs tomorrow through 30 days and finds the low', () {
      final book = Book();
      book.account('Bank', '1000.00');
      final f = defaultForecast(book.s, today)!;
      expect(f.daily.keys.first, '2026-10-16');
      expect(f.daily.keys.last, '2026-11-14');
      expect(f.opening, php(1000));
      expect(lowestDay(f)!.$2, php(1000));
    });

    test('a bill with a usual account lowers the estimate only', () {
      final book = Book();
      final bank = book.account('Bank', '1000.00');
      book.rule('Rent', account: bank);
      final f = defaultForecast(book.s, today)!;
      expect(f.daily.values.last, php(500));
      expect(lowestDay(f)!.$2, php(500));
      expect(book.s.balance(bank, through: today), php(1000));
    });
  });
}
