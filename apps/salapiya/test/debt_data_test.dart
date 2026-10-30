import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_data.dart';
import 'package:salapiya/finance/debt_data.dart';
import 'package:salapiya/connected/financial_contract.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_store.dart' show defaultLocalCategories;

/// Friday. Its week runs Monday 26 Oct to Sunday 1 Nov.
const today = '2026-10-30';

/// A profile built by replaying commands through the real rules.
class Book {
  Book() {
    account = post('account', {
      'name': 'Bank',
      'kind': 'Bank',
      'amount': '100000.00',
      'cutoff': '2026-01-01',
    });
  }
  LocalSnapshot s = LocalSnapshot(
    owner: 'debt-data',
    version: 0,
    accounts: const [],
    categories: [
      for (final c in defaultLocalCategories)
        LocalCategory('category-${c.$1}', c.$2, c.$3),
    ],
    revisions: const [],
  );
  var n = 0;
  late final String account;

  String post(String kind, Map<String, String> values) {
    final id =
        '00000000-0000-4000-8000-${(++n).toRadixString(16).padLeft(12, '0')}';
    s = applyFinancialPlan(
      s,
      planLocal(
        s,
        LocalCommand(
          id: id,
          owner: 'debt-data',
          expectedVersion: s.version,
          kind: kind,
          values: {'acknowledge': 'false', ...values},
        ),
      ),
    );
    return id;
  }

  String debt(String name, String amount) => post('debtImport', {
    'date': '2026-02-01',
    'name': name,
    'lender': 'Sample lender',
    'debtType': 'personal_loan',
    'amount': amount,
    'principal': '',
  });

  String schedule(String debt, String rows) => post('debtSchedule', {
    'date': '2026-02-01',
    'name': 'Schedule record',
    'debt': debt,
    'schedule': rows,
    'verified': 'true',
    'reference': 'Agreement',
  });

  String pay(
    String debt,
    String amount, {
    String date = '2026-10-10',
    String? schedule,
    String allocations = '',
    bool known = true,
  }) => post('debtPayment', {
    'date': date,
    'name': 'Payment',
    'debt': debt,
    'account': account,
    'amount': amount,
    'externalFee': '0.00',
    'reduction': known ? amount : '0.00',
    'interest': '0.00',
    'fee': '0.00',
    'clearing': known ? '0.00' : amount,
    'certainty': known ? 'confirmed_total' : 'unresolved',
    'scheduleSource': schedule ?? '',
    'allocations': allocations,
    'unapplied': allocations.isEmpty ? amount : '0.00',
  });

  void payoff(String debt, String amount) => post('debtPayoff', {
    'date': '2026-10-20',
    'name': 'Payoff',
    'debt': debt,
    'account': account,
    'amount': amount,
    'providerPayoff': amount,
    'reduction': amount,
    'interest': '0.00',
    'fee': '0.00',
    'waiver': '0.00',
    'avoided': '0.00',
    'verified': 'true',
    'reference': 'Letter',
    'reason': 'Paid early',
  });

  void charge(String debt, String amount) => post('debtAdjustment', {
    'date': '2026-10-21',
    'name': 'Late fee',
    'debt': debt,
    'amount': amount,
    'adjustmentKind': 'recognized_charge',
    'chargeType': 'fee',
    'category': 'category-fees',
    'reason': 'Late fee',
    'reference': 'Statement',
    'verified': 'true',
  });

  List<DebtProgress> get progress => overviewDebtProgress(s, today);
  DebtsSummary get summary => DebtsSummary(progress, today);
  DebtProgress of(String id) =>
      progress.firstWhere((d) => d.debt.actionId == id);
}

void main() {
  group('summary', () {
    test('empty data has nothing to show and no invented zero rows', () {
      final book = Book();
      final summary = book.summary;
      expect(summary.owed, BigInt.zero);
      expect(summary.overdue, isEmpty);
      expect(summary.next, isEmpty);
      expect(summary.thisMonth, isEmpty);
      expect(summary.oldestOverdueDays, 0);
      expect(debtPaymentRows(book.s), isEmpty);
      expect(debtHistory(book.s), isEmpty);
      expect(debtTasks(book.progress), isEmpty);
    });

    test('a payment due today is next and in the month, not overdue', () {
      final book = Book();
      book.schedule(book.debt('Loan', '1000.00'), 'one,$today,1000.00');
      final summary = book.summary;
      expect(summary.next.single.status, DebtDueStatus.dueToday);
      expect(summary.next.single.days, 0);
      expect(summary.overdue, isEmpty);
      expect(summary.thisMonthTotal, BigInt.from(100000));
    });

    test('overdue by one day is overdue and never next', () {
      final book = Book();
      book.schedule(
        book.debt('Loan', '1000.00'),
        'one,2026-10-29,400.00\ntwo,2026-11-29,600.00',
      );
      final summary = book.summary;
      expect(summary.overdue.single.days, -1);
      expect(summary.oldestOverdueDays, 1);
      expect(summary.overdueTotal, BigInt.from(40000));
      expect(summary.next.single.date, '2026-11-29');
      expect(summary.thisMonth, isEmpty);
    });

    test('rows sharing the next date are summed', () {
      final book = Book();
      book.schedule(book.debt('A', '100.00'), 'one,2026-11-02,100.00');
      book.schedule(book.debt('B', '250.00'), 'one,2026-11-02,250.00');
      book.schedule(book.debt('C', '500.00'), 'one,2026-11-03,500.00');
      expect(book.summary.next, hasLength(2));
      expect(book.summary.nextTotal, BigInt.from(35000));
    });

    test('week and month boundaries are inclusive and exact', () {
      final book = Book();
      book.schedule(
        book.debt('Loan', '60.00'),
        [
          'before,2026-10-25,10.00',
          'monday,2026-10-26,10.00',
          'monthEnd,2026-10-31,10.00',
          'sunday,2026-11-01,10.00',
          'nextMonday,2026-11-02,10.00',
          'monthAfter,2026-12-01,10.00',
        ].join('\n'),
      );
      final sources = overviewDueSources(book.s, today);
      final week = OverviewDues.from(sources, today, DuePeriod.week);
      final month = OverviewDues.from(sources, today, DuePeriod.month);
      expect((week.start, week.end), ('2026-10-26', '2026-11-01'));
      expect(week.overdue.map((i) => i.date), ['2026-10-25', '2026-10-26']);
      expect(week.upcoming.map((i) => i.date), ['2026-10-31', '2026-11-01']);
      expect((month.start, month.end), ('2026-10-01', '2026-10-31'));
      expect(month.upcoming.map((i) => i.date), ['2026-10-31']);
      expect(book.summary.thisMonth.map((p) => p.date), ['2026-10-31']);
    });

    test('the total owed is what `debtTotal` adds up', () {
      final book = Book();
      final a = book.debt('A', '1000.00');
      book.debt('B', '250.50');
      book.pay(a, '300.00');
      final total = -sumMinor(
        book.s.current
            .expand((r) => r.postings)
            .where(
              (p) =>
                  p.ledger == 'debt_liability' && p.date.compareTo(today) <= 0,
            )
            .map((p) => p.amount),
      );
      expect(book.summary.owed, total);
      expect(total, BigInt.from(95050));
    });
  });

  group('display state', () {
    test('a fully paid-off debt is settled and sorts last', () {
      final book = Book();
      final paid = book.debt('Paid', '100.00');
      final plan = book.schedule(paid, 'one,2026-09-01,100.00');
      book.pay(paid, '100.00', schedule: plan, allocations: 'one,100.00');
      book.schedule(book.debt('Open', '100.00'), 'one,2026-12-01,100.00');
      expect(book.of(paid).statusLabel, 'Settled');
      expect(book.of(paid).fraction, 1);
      expect(book.progress.last.debt.actionId, paid);
    });

    test('a debt without a schedule stays "Schedule not set"', () {
      final book = Book();
      final id = book.debt('Loan', '100.00');
      expect(book.of(id).statusLabel, 'Schedule not set');
      expect(book.of(id).fraction, isNull);
      expect(DebtFilter.noSchedule.shows(book.of(id)), isTrue);
      expect(debtTasks(book.progress).single.need, DebtNeed.schedule);
    });

    test('an unscheduled debt with nothing owed is settled', () {
      final book = Book();
      final id = book.debt('Loan', '100.00');
      book.pay(id, '100.00');
      expect(book.of(id).statusLabel, 'Settled');
      expect(DebtFilter.paidOff.shows(book.of(id)), isTrue);
      expect(debtTasks(book.progress), isEmpty);
    });

    test('a payoff closes a debt with or without a schedule', () {
      final book = Book();
      final scheduled = book.debt('Scheduled', '100.00');
      book.schedule(scheduled, 'one,2026-12-01,100.00');
      book.payoff(scheduled, '100.00');
      final plain = book.debt('Plain', '200.00');
      book.payoff(plain, '200.00');
      expect(book.of(scheduled).statusLabel, 'Closed');
      expect(book.of(scheduled).due.open, isEmpty);
      expect(book.of(plain).statusLabel, 'Closed');
      expect(book.of(plain).closed, isTrue);
      expect(book.summary.payments, isEmpty);
      expect(debtTasks(book.progress), isEmpty);
    });

    test('a finished schedule with money still owed is not settled', () {
      final book = Book();
      final id = book.debt('Loan', '100.00');
      final plan = book.schedule(id, 'one,2026-09-01,100.00');
      book.pay(id, '100.00', schedule: plan, allocations: 'one,100.00');
      book.charge(id, '25.00');
      expect(book.of(id).outstanding, BigInt.from(2500));
      expect(book.of(id).statusLabel, 'Schedule finished');
      expect(DebtFilter.paidOff.shows(book.of(id)), isFalse);
      expect(DebtFilter.noSchedule.shows(book.of(id)), isTrue);
    });

    test('each debt falls under exactly one filter besides All', () {
      final book = Book();
      book.schedule(book.debt('Late', '100.00'), 'one,2026-10-01,100.00');
      book.schedule(book.debt('Soon', '100.00'), 'one,$today,100.00');
      book.debt('None', '100.00');
      final paid = book.debt('Paid', '100.00');
      book.pay(paid, '100.00');
      for (final d in book.progress) {
        final filters = DebtFilter.values
            .where((f) => f != DebtFilter.all && f.shows(d))
            .toList();
        expect(filters, hasLength(1), reason: d.debt.title);
      }
    });
  });

  group('rows', () {
    test('due rows carry the debt name, not the schedule record', () {
      final book = Book();
      book.schedule(book.debt('Phone', '100.00'), 'one,2026-11-01,100.00');
      expect(overviewDueSources(book.s, today).single.title, 'Phone');
    });

    test('installment rows show paid, left and a display status', () {
      final book = Book();
      final id = book.debt('Loan', '300.00');
      final plan = book.schedule(
        id,
        'one,2026-09-01,100.00\ntwo,2026-10-01,100.00\nthree,2026-12-01,100.00',
      );
      book.pay(id, '100.00', schedule: plan, allocations: 'one,100.00');
      book.pay(id, '40.00', schedule: plan, allocations: 'two,40.00');
      final rows = installmentRows(book.s, book.of(id), today);
      expect(rows.map((r) => r.statusLabel), ['Paid', 'Overdue', 'Upcoming']);
      expect(rows[1].left, BigInt.from(6000));
      expect(rows[1].paid, BigInt.from(4000));
      expect(rows[1].days, -29);
    });

    test('a payoff cancels what was left, not what was paid', () {
      final book = Book();
      final id = book.debt('Loan', '200.00');
      final plan = book.schedule(
        id,
        'one,2026-09-01,100.00\ntwo,2026-12-01,100.00',
      );
      book.pay(id, '100.00', schedule: plan, allocations: 'one,100.00');
      book.payoff(id, '100.00');
      final rows = installmentRows(book.s, book.of(id), today);
      expect(rows.map((r) => r.statusLabel), ['Paid', 'Cancelled by payoff']);
      expect(rows.every((r) => !r.open), isTrue);
    });

    test('payments read their account, due date and breakdown', () {
      final book = Book();
      final id = book.debt('Loan', '300.00');
      final plan = book.schedule(id, 'one,2026-11-01,300.00');
      book.pay(id, '100.00', schedule: plan, allocations: 'one,100.00');
      final unknown = book.pay(id, '50.00', date: '2026-10-15', known: false);
      final rows = debtPaymentRows(book.s);
      expect(rows.map((r) => r.date), ['2026-10-15', '2026-10-10']);
      expect(rows.first.breakdown, PaymentBreakdown.unknown);
      expect(rows.first.left, BigInt.from(5000));
      expect(rows.first.appliedTo, isEmpty);
      expect(rows.last.breakdown, PaymentBreakdown.reducesDebt);
      expect(rows.last.appliedTo, ['one']);
      expect(rows.last.paidFrom, 'Bank');
      expect(rows.last.debtTitle, 'Loan');

      book.post('debtClassification', {
        'date': '2026-10-16',
        'name': 'Breakdown',
        'debt': id,
        'payment': unknown,
        'reduction': '30.00',
        'interest': '0.00',
        'fee': '0.00',
        'reason': 'From the statement',
      });
      final after = debtPaymentRows(book.s).first;
      expect(after.left, BigInt.from(2000));
      expect(after.breakdown, PaymentBreakdown.unknown);
      expect(book.of(id).clearing, BigInt.from(2000));
      expect(debtTasks(book.progress).single.need, DebtNeed.breakdown);
    });

    test('a varied amount needs confirming only once it is close', () {
      final book = Book();
      final soon = book.debt('Soon', '100.00');
      book.post('debtSchedule', {
        'date': '2026-02-01',
        'name': 'Plan',
        'debt': soon,
        'schedule': 'one,2026-11-01,100.00',
        'verified': 'true',
        'reference': 'Agreement',
        'frequency': 'monthly',
        'firstDue': '2026-11-01',
        'splitMode': 'varied',
        'installmentAmount': '',
      });
      final later = book.debt('Later', '100.00');
      book.post('debtSchedule', {
        'date': '2026-02-01',
        'name': 'Plan',
        'debt': later,
        'schedule': 'one,2027-01-01,100.00',
        'verified': 'true',
        'reference': 'Agreement',
        'frequency': 'monthly',
        'firstDue': '2027-01-01',
        'splitMode': 'varied',
        'installmentAmount': '',
      });
      final tasks = debtTasks(book.progress);
      expect(tasks.single.need, DebtNeed.confirmAmount);
      expect(tasks.single.debt.debt.actionId, soon);
    });

    test('monthly totals cover six calendar months and skip overdue', () {
      final book = Book();
      book.schedule(
        book.debt('Loan', '60.00'),
        [
          'late,2026-10-01,10.00',
          'now,2026-10-31,10.00',
          'next,2026-11-30,10.00',
          'year,2027-01-01,10.00',
          'last,2027-03-31,10.00',
          'out,2027-04-01,10.00',
        ].join('\n'),
      );
      final sources = namedDueSources(
        book.s,
        financialReminderSources(
          book.s,
          today,
          dueWindowEnd(today),
          asOf: today,
        ),
      );
      final months = dueByMonth(sources, today);
      expect(months.map((m) => m.$1), [
        '2026-10-01',
        '2026-11-01',
        '2026-12-01',
        '2027-01-01',
        '2027-02-01',
        '2027-03-01',
      ]);
      expect(months.map((m) => m.$2.toInt()), [1000, 1000, 0, 1000, 0, 1000]);
    });

    test('paid per month ends this month; paid down skips charges', () {
      final book = Book();
      final id = book.debt('Loan', '1000.00');
      book.pay(id, '100.00', date: '2026-05-31');
      book.pay(id, '200.00', date: '2026-10-01');
      book.pay(id, '50.00', date: '2026-10-15', known: false);
      book.charge(id, '25.00');
      final months = paidByMonth(book.s, today);
      expect(months, hasLength(6));
      expect(months.first, ('2026-05-01', BigInt.from(10000)));
      expect(months.last, ('2026-10-01', BigInt.from(25000)));
      expect(paidDownBetween(book.s, '2026-10-01', today), BigInt.from(20000));
    });

    test('history names each record, including corrections', () {
      final book = Book();
      final id = book.debt('Loan', '100.00');
      book.schedule(id, 'one,2026-12-01,100.00');
      book.pay(id, '10.00');
      final labels = debtHistory(book.s).map(recordLabel).toList();
      expect(labels, ['Payment logged', 'Payment schedule set', 'Debt added']);
      expect(debtActivity(book.s, id), hasLength(1));
    });

    test('what Log payment proposes passes the real rules', () {
      final book = Book();
      final id = book.debt('Loan', '300.00');
      book.schedule(id, 'one,2026-10-01,100.00\ntwo,2026-12-01,200.00');
      final d = book.of(id);
      final initial = debtPaymentInitial(d);
      expect(initial['allocations'], 'one,100.00');
      expect(initial['amount'], '100.00');
      final later = debtPaymentInitial(d, book.summary.next.single);
      expect(later['allocations'], 'two,200.00');
      book.post('debtPayment', {
        ...initial,
        'date': today,
        'account': book.account,
        'externalFee': '0.00',
        'interest': '0.00',
        'fee': '0.00',
        'clearing': '0.00',
        'unapplied': '0.00',
      });
      expect(book.of(id).due.open, hasLength(1));
      expect(book.of(id).outstanding, BigInt.from(20000));
    });

    test('an open debt with no due date proposes no allocation', () {
      final book = Book();
      final initial = debtPaymentInitial(book.of(book.debt('Loan', '10.00')));
      expect(initial.keys, unorderedEquals(['debt', 'name']));
    });
  });
}
