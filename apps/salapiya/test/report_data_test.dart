import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_data.dart';
import 'package:salapiya/app/overview_demo.dart';
import 'package:salapiya/connected/financial_contract.dart';
import 'package:salapiya/finance/money_data.dart';
import 'package:salapiya/finance/planning_data.dart';
import 'package:salapiya/finance/report_data.dart';
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

  String account([String name = 'Bank']) => post('account', {
    'name': name,
    'kind': 'Bank',
    'amount': '100000.00',
    'cutoff': '2026-01-01',
  });

  String expense(
    String account,
    String amount,
    String date, {
    String category = 'food',
  }) => post('expense', {
    'date': date,
    'name': 'Spent $amount',
    'account': account,
    'amount': amount,
    'category': 'category-$category',
  });

  String income(String account, String amount, String date) => post('income', {
    'date': date,
    'name': 'Pay',
    'account': account,
    'amount': amount,
    'category': 'category-income',
    'incomeClass': 'earned',
  });

  String card() => post('creditCard', {
    'date': '2026-02-01',
    'name': 'Rewards',
    'issuer': 'Issuer',
    'amount': '500.00',
    'limit': '10000.00',
  });

  String buy(String card, String amount, String date) => post('cardPurchase', {
    'date': date,
    'name': 'Purchase',
    'card': card,
    'amount': amount,
    'postingDate': date,
    'category': 'category-other',
  });

  String fee(String kind, String card, String amount, String date) =>
      post(kind, {
        'date': date,
        'name': kind,
        'card': card,
        'amount': amount,
        'postingDate': date,
        'category': 'category-fees',
      });

  String budget({
    String start = '2026-10-01',
    String end = '2026-11-01',
    String status = 'active',
    String category = 'food',
  }) => post('budget', {
    'date': '2026-10-01',
    'name': 'Budget',
    'amount': '1000.00',
    'category': 'category-$category',
    'start': start,
    'endExclusive': end,
    'basis': 'net',
    'status': status,
  });

  String name(String? id) => s.categories
      .firstWhere(
        (c) => c.id == id,
        orElse: () => const LocalCategory('', 'Uncategorized', 'expense'),
      )
      .name;
}

void main() {
  group('periods', () {
    const today = '2026-10-15';
    test('this month runs to today, against the same days of last month', () {
      const f = ReportFilter();
      expect(f.range(today), ('2026-10-01', '2026-10-15'));
      expect(f.before(today), ('2026-09-01', '2026-09-15'));
    });

    test('this month stops at the end of a shorter month', () {
      const f = ReportFilter();
      expect(f.before('2026-03-31'), ('2026-02-01', '2026-02-28'));
      expect(f.before('2024-03-31'), ('2024-02-01', '2024-02-29'));
    });

    test('this month on the 1st is one day', () {
      const f = ReportFilter();
      expect(f.range('2026-11-01'), ('2026-11-01', '2026-11-01'));
      expect(f.before('2026-11-01'), ('2026-10-01', '2026-10-01'));
    });

    test('this month in January compares with December', () {
      const f = ReportFilter();
      expect(f.before('2027-01-10'), ('2026-12-01', '2026-12-10'));
    });

    test('other periods compare with the same days just before', () {
      const last = ReportFilter(period: ReportPeriod.lastMonth);
      expect(last.range(today), ('2026-09-01', '2026-09-30'));
      expect(last.before(today), ('2026-08-02', '2026-08-31'));
      const ninety = ReportFilter(period: ReportPeriod.last90);
      expect(ninety.range(today), ('2026-07-18', today));
      expect(ninety.before(today), ('2026-04-19', '2026-07-17'));
      const year = ReportFilter(period: ReportPeriod.thisYear);
      expect(year.range(today), ('2026-01-01', today));
    });

    test('a custom period is 1 to 366 days', () {
      ReportFilter custom(String from, String to) =>
          ReportFilter(period: ReportPeriod.custom, from: from, to: to);
      expect(custom('2026-01-01', '2026-01-01').problem(today), isNull);
      expect(custom('2024-01-01', '2024-12-31').problem(today), isNull);
      expect(custom('2024-01-01', '2025-01-01').problem(today), isNotNull);
      expect(custom('2026-02-02', '2026-02-01').problem(today), isNotNull);
    });

    test('a whole year never reads as too long', () {
      const year = ReportFilter(period: ReportPeriod.thisYear);
      expect(year.problem('2024-12-31'), isNull);
    });
  });

  group('period labels', () {
    const today = '2026-10-15';
    test('a span in another year says which', () {
      expect(
        reportSpan('2025-03-03', '2025-12-31', today),
        '3 Mar – 31 Dec 2025',
      );
    });

    test('a span this year needs no year', () {
      expect(reportSpan('2026-03-03', '2026-05-31', today), '3 Mar – 31 May');
    });

    test('a whole month already has one', () {
      expect(reportSpan('2025-09-01', '2025-09-30', today), 'September 2025');
    });
  });

  group('what filters can answer', () {
    test('an account filter has no spending or income to show', () {
      const f = ReportFilter(account: 'a');
      expect(f.spendingKnown, isFalse);
      expect(f.cashKnown, isTrue);
    });

    test('a category filter has no cash movement to show', () {
      const f = ReportFilter(category: 'c');
      expect(f.spendingKnown, isTrue);
      expect(f.cashKnown, isFalse);
    });

    test('filters come off one at a time and keep the period', () {
      const f = ReportFilter(
        period: ReportPeriod.last90,
        account: 'a',
        category: 'c',
      );
      final left = f.without(account: true);
      expect(left.account, isNull);
      expect(left.category, 'c');
      expect(left.period, ReportPeriod.last90);
      expect(f.filters, 2);
    });
  });

  group('spending', () {
    test('a category narrows spending, income and days', () {
      final b = Book();
      final a = b.account();
      b.expense(a, '100.00', '2026-10-02');
      b.expense(a, '40.00', '2026-10-02', category: 'other');
      b.income(a, '900.00', '2026-10-03');
      const from = '2026-10-01', to = '2026-10-15';
      expect(spendingBetween(b.s, from, to), php(140));
      expect(
        spendingBetween(b.s, from, to, category: 'category-food'),
        php(100),
      );
      expect(
        incomeBetween(b.s, from, to, category: 'category-food'),
        BigInt.zero,
      );
      expect(
        incomeBetween(b.s, from, to, category: 'category-income'),
        php(900),
      );
      final day = dailySpending(b.s, from, to, category: 'category-other');
      expect(day.length, 15);
      expect(day[1].$2, php(40));
    });

    test('monthly spending keeps every month and cuts the ends', () {
      final b = Book();
      final a = b.account();
      b.expense(a, '10.00', '2026-08-30');
      b.expense(a, '20.00', '2026-09-30');
      b.expense(a, '40.00', '2026-10-01');
      b.expense(a, '80.00', '2026-10-02');
      final months = monthlySpending(b.s, '2026-08-31', '2026-10-01');
      expect(months, [
        ('2026-08-01', BigInt.zero),
        ('2026-09-01', php(20)),
        ('2026-10-01', php(40)),
      ]);
    });

    test('months add up to the days across a year end', () {
      final b = Book();
      final a = b.account();
      b.expense(a, '10.00', '2026-02-15');
      final months = monthlySpending(b.s, '2026-01-01', '2026-03-31');
      expect(months.map((m) => m.$1), [
        '2026-01-01',
        '2026-02-01',
        '2026-03-01',
      ]);
      expect(sumMinor(months.map((m) => m.$2)), php(10));
    });

    test('categories compare, and one with only earlier spending stays', () {
      final b = Book();
      final a = b.account();
      b.expense(a, '100.00', '2026-10-02');
      b.expense(a, '50.00', '2026-09-02');
      b.expense(a, '30.00', '2026-09-03', category: 'other');
      final rows = categoryChanges(
        b.s,
        ('2026-10-01', '2026-10-15'),
        ('2026-09-01', '2026-09-15'),
        b.name,
      );
      expect(rows.map((r) => r.name), [b.name('category-food'), 'Other']);
      expect(rows.first.change, php(50));
      expect(rows.first.basisPoints, 10000);
      expect(rows.last.current, BigInt.zero);
      expect(rows.last.basisPoints, -10000);
    });

    test('a new category has no percentage', () {
      final b = Book();
      final a = b.account();
      b.expense(a, '100.00', '2026-10-02');
      final row = categoryChanges(
        b.s,
        ('2026-10-01', '2026-10-15'),
        ('2026-09-01', '2026-09-15'),
        b.name,
      ).single;
      expect(row.basisPoints, isNull);
      expect(row.change, php(100));
    });

    test('a category filter leaves one row', () {
      final b = Book();
      final a = b.account();
      b.expense(a, '100.00', '2026-10-02');
      b.expense(a, '30.00', '2026-10-03', category: 'other');
      final rows = categoryChanges(
        b.s,
        ('2026-10-01', '2026-10-15'),
        ('2026-09-01', '2026-09-15'),
        b.name,
        only: 'Other',
      );
      expect(rows.single.current, php(30));
    });
  });

  group('debts and cards', () {
    test('each line comes from its own records', () {
      final b = Book();
      final a = b.account();
      final card = b.card();
      b.buy(card, '700.00', '2026-10-02');
      b.fee('cardFee', card, '50.00', '2026-10-03');
      b.fee('cardInterest', card, '25.00', '2026-10-04');
      b.post('cardPayment', {
        'date': '2026-10-05',
        'name': 'Payment',
        'card': card,
        'account': a,
        'amount': '300.00',
      });
      final purchase = b.buy(card, '200.00', '2026-10-06');
      b.post('cardRefund', {
        'date': '2026-10-07',
        'name': 'Refund',
        'card': card,
        'purchase': purchase,
        'amount': '80.00',
        'category': 'category-other',
        'reason': 'Returned',
      });
      final sum = cardSummary(b.s, '2026-10-01', '2026-10-15');
      expect(sum.purchases, php(900));
      expect(sum.payments, php(300));
      expect(sum.charges, php(75));
      expect(sum.refunds, php(80));
    });

    test('a card’s starting balance isn’t activity', () {
      final b = Book();
      b.card();
      final sum = cardSummary(b.s, '2026-01-01', '2026-12-31');
      expect(sum.purchases, BigInt.zero);
      expect(sum.refunds, BigInt.zero);
    });

    test('dates outside the period don’t count', () {
      final b = Book();
      final card = b.card();
      b.buy(card, '700.00', '2026-09-30');
      expect(
        cardSummary(b.s, '2026-10-01', '2026-10-15').purchases,
        BigInt.zero,
      );
    });

    test('a reversed purchase leaves the report', () {
      final b = Book();
      final card = b.card();
      final id = b.buy(card, '700.00', '2026-10-02');
      b.post('financeReversal', {
        'replace': id,
        'replaceVersion': '1',
        'reason': 'Mistake',
      });
      expect(
        cardSummary(b.s, '2026-10-01', '2026-10-15').purchases,
        BigInt.zero,
      );
    });
  });

  group('budgets in a period', () {
    test('one that overlaps counts its whole period, uncut', () {
      final b = Book();
      final a = b.account();
      final id = b.budget(start: '2026-09-15', end: '2026-10-15');
      b.expense(a, '200.00', '2026-09-20');
      b.expense(a, '300.00', '2026-10-10');
      final row = reportBudgets(
        b.s,
        '2026-10-01',
        '2026-10-15',
        '2026-10-15',
      ).single;
      expect(row.$2.budget.actionId, id);
      expect(row.$2.spent, php(500));
    });

    test('the day after its last day is outside it', () {
      final b = Book();
      b.budget(start: '2026-09-01', end: '2026-10-01');
      expect(
        reportBudgets(b.s, '2026-10-01', '2026-10-15', '2026-10-15'),
        isEmpty,
      );
      expect(
        reportBudgets(b.s, '2026-09-30', '2026-10-15', '2026-10-15').length,
        1,
      );
    });

    test('archived budgets stay out', () {
      final b = Book();
      b.budget(status: 'archived');
      expect(
        reportBudgets(b.s, '2026-10-01', '2026-10-15', '2026-10-15'),
        isEmpty,
      );
    });

    test('a category filter keeps only its budget', () {
      final b = Book();
      b.budget();
      b.budget(category: 'other');
      final rows = reportBudgets(
        b.s,
        '2026-10-01',
        '2026-10-15',
        '2026-10-15',
        category: 'category-other',
      );
      expect(rows.single.$1, BudgetWhen.current);
    });
  });

  group('records', () {
    test('the period, account and category all narrow them', () {
      final b = Book();
      final bank = b.account();
      final wallet = b.account('Wallet');
      b.expense(bank, '100.00', '2026-10-02');
      b.expense(wallet, '40.00', '2026-10-03', category: 'other');
      b.expense(bank, '10.00', '2026-09-02');
      final rows = moneyActivity(b.s, b.name);
      expect(
        reportRecords(rows, const ReportFilter(), '2026-10-15', b.name).length,
        2,
      );
      expect(
        reportRecords(
          rows,
          ReportFilter(account: wallet),
          '2026-10-15',
          b.name,
        ).single.title,
        'Spent 40.00',
      );
      expect(
        reportRecords(
          rows,
          const ReportFilter(category: 'category-food'),
          '2026-10-15',
          b.name,
        ).single.title,
        'Spent 100.00',
      );
    });

    test('a reversed record isn’t listed', () {
      final b = Book();
      final bank = b.account();
      final id = b.expense(bank, '100.00', '2026-10-02');
      final record = b.s.current.firstWhere((r) => r.actionId == id);
      b.post('reversal', {
        'date': '2026-10-02',
        'source': record.id,
        'sourceVersion': '${record.number}',
        'reason': 'Mistake',
      });
      expect(
        reportRecords(
          moneyActivity(b.s, b.name),
          const ReportFilter(),
          '2026-10-15',
          b.name,
        ),
        isEmpty,
      );
    });
  });

  group('the demo sample', () {
    test('its totals agree with the tiles on the month’s edges', () {
      for (final today in const [
        '2026-10-01',
        '2026-10-31',
        '2026-11-30',
        '2026-12-31',
        '2027-01-01',
        '2027-03-01',
      ]) {
        final s = demoSample(today);
        final (from, to) = const ReportFilter().range(today);
        final days = dailySpending(s, from, to);
        expect(
          sumMinor(days.map((d) => d.$2)),
          spendingBetween(s, from, to),
          reason: today,
        );
        final categories = spendingByCategory(s, from, to, (id) => '$id');
        expect(
          sumMinor(categories.map((c) => c.$2)),
          spendingBetween(s, from, to),
          reason: today,
        );
      }
    });
  });
}
