import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_data.dart';
import 'package:salapiya/app/overview_demo.dart';
import 'package:salapiya/connected/financial_contract.dart';
import 'package:salapiya/finance/money_data.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_store.dart' show defaultLocalCategories;
import 'package:salapiya/prototype/fixtures.dart' show demoAccounts;

BigInt php(String value) => signedPhp(value);

/// A small profile replayed through the real rules.
class Book {
  LocalSnapshot s = LocalSnapshot(
    owner: 'book',
    version: 0,
    accounts: const [],
    categories: [
      for (final c in defaultLocalCategories)
        LocalCategory('category-${c.$1}', c.$2, c.$3),
    ],
    revisions: const [],
  );
  var _n = 0;
  String post(String kind, Map<String, String> values) {
    final id =
        '00000000-0000-4000-8000-${(++_n).toRadixString(16).padLeft(12, '0')}';
    s = applyFinancialPlan(
      s,
      planLocal(
        s,
        LocalCommand(
          id: id,
          owner: 'book',
          expectedVersion: s.version,
          kind: kind,
          values: {'acknowledge': 'false', ...values},
        ),
      ),
    );
    return id;
  }

  String account(String name, String amount, {String cutoff = '2026-01-01'}) =>
      post('account', {
        'name': name,
        'kind': 'Cash',
        'amount': amount,
        'cutoff': cutoff,
      });
  String expense(String date, String name, String from, String amount) =>
      post('expense', {
        'date': date,
        'name': name,
        'account': from,
        'amount': amount,
        'category': 'category-food',
      });
  String income(String date, String name, String to, String amount) =>
      post('income', {
        'date': date,
        'name': name,
        'account': to,
        'amount': amount,
        'category': 'category-income',
        'incomeClass': 'earned',
      });
  String transfer(
    String date,
    String from,
    String to,
    String amount, {
    String fee = '0.00',
  }) => post('transfer', {
    'date': date,
    'name': 'Move',
    'account': from,
    'destination': to,
    'amount': amount,
    'fee': fee,
    'feeTreatment': 'source_additional',
    'feeCategory': 'category-fees',
    'feeDate': '',
  });
}

String name(String? id) => id ?? 'No category';

void main() {
  const today = '2026-10-30';

  group('moneyActivity', () {
    test('an empty profile has no rows', () {
      final book = Book();
      expect(moneyActivity(book.s, name), isEmpty);
    });

    test('one row per record, newest first', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      book.expense('2026-10-01', 'Older', a, '10.00');
      book.expense('2026-10-02', 'Newer', a, '20.00');
      book.expense('2026-10-02', 'Newest logged', a, '30.00');
      expect(moneyActivity(book.s, name).map((r) => r.title), [
        'Newest logged',
        'Newer',
        'Older',
        'Opening balance · Wallet',
      ]);
    });

    test('a correction is one row, with its newest amount', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final id = book.expense('2026-10-01', 'Taxi', a, '320.00');
      final fixed = book.post('correction', {
        'date': '2026-10-01',
        'name': 'Taxi',
        'source': id,
        'sourceVersion': '1',
        'reason': 'Wrong fare',
        'amount': '230.00',
        'account': a,
        'category': 'category-food',
      });
      final rows = moneyActivity(book.s, name).where((r) => r.title == 'Taxi');
      expect(rows.length, 1);
      expect(rows.single.id, fixed);
      expect(rows.single.change, RecordChange.corrected);
      expect(rows.single.net, -php('230.00'));
    });

    test('a reversed record stays, moves nothing, and keeps its title', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final id = book.expense('2026-10-01', 'Beans', a, '260.00');
      book.post('reversal', {
        'source': id,
        'sourceVersion': '1',
        'reason': 'Logged twice',
      });
      final row = moneyActivity(
        book.s,
        name,
      ).firstWhere((r) => r.title == 'Beans');
      expect(row.reversed, isTrue);
      expect(row.net, BigInt.zero);
      expect(row.accounts, [a]);
      expect(row.shown((v) => '$v', hidden: false), '${php('260.00')}');
      expect(book.s.balance(a), php('1000.00'));
    });

    test('budgets and other records that move no money are not activity', () {
      final s = demoSample(today);
      final rows = moneyActivity(s, name);
      expect(rows.map((r) => r.title), isNot(contains('Transport')));
      expect(rows.any((r) => financeType(r.record) == 'budget'), isFalse);
      expect(rows.any((r) => financeType(r.record) == 'debtSchedule'), isFalse);
      expect(rows.any((r) => financeType(r.record) == 'statement'), isFalse);
    });

    test('a balance check is a row, in plain words, moving nothing', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      book.post('reconcile', {
        'date': '2026-10-02',
        'account': a,
        'amount': '950.00',
        'mode': 'compare',
      });
      final row = moneyActivity(book.s, name).firstWhere((r) => r.isCheck);
      expect(row.title, 'Balance check · Wallet');
      expect(row.net, BigInt.zero);
      expect(row.accounts, [a]);
      expect(row.type, ActivityType.adjustments);
    });

    test('amounts are signed; a transfer depends on where it is seen', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final b = book.account('Bank', '1000.00');
      book.expense('2026-10-01', 'Lunch', a, '100.00');
      book.income('2026-10-02', 'Pay', b, '500.00');
      book.transfer('2026-10-03', b, a, '200.00');
      final rows = moneyActivity(book.s, name);
      String shown(String title, {String? account}) => rows
          .firstWhere((r) => r.title == title)
          .shown((v) => phpDecimal(v), hidden: false, account: account);
      expect(shown('Lunch'), '-100.00');
      expect(shown('Pay'), '+500.00');
      expect(shown('Move'), '200.00');
      expect(shown('Move', account: a), '+200.00');
      expect(shown('Move', account: b), '-200.00');
    });

    test('a fee paid from another account shows only the fee there', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final b = book.account('Bank', '1000.00');
      final c = book.account('Spare', '1000.00');
      book.post('transfer', {
        'date': '2026-10-03',
        'name': 'Move',
        'account': a,
        'destination': b,
        'amount': '200.00',
        'fee': '15.00',
        'feeTreatment': 'separate',
        'feeAccount': c,
        'feeCategory': 'category-fees',
        'feeDate': '',
      });
      final row = moneyActivity(
        book.s,
        name,
      ).firstWhere((r) => r.title == 'Move');
      expect(row.accounts, containsAll([a, b, c]));
      expect(row.cash(c), -php('15.00'));
    });

    test('hidden amounts never get a sign or leak into search', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      book.income('2026-10-02', 'Pay', a, '500.00');
      final row = moneyActivity(
        book.s,
        name,
      ).firstWhere((r) => r.title == 'Pay');
      expect(row.shown((_) => 'Amount hidden', hidden: true), 'Amount hidden');
      expect(row.searchText(true), isNot(contains('500')));
      expect(row.searchText(false), contains('500.00'));
    });
  });

  group('cashFlow', () {
    test('nothing in an empty range', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final flow = cashFlow(book.s, [a], '2026-10-01', '2026-10-31');
      expect(flow.moneyIn, BigInt.zero);
      expect(flow.moneyOut, BigInt.zero);
    });

    test('opening balances are not money in', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00', cutoff: '2026-10-01');
      expect(
        cashFlow(book.s, [a], '2026-10-01', '2026-10-31').moneyIn,
        BigInt.zero,
      );
    });

    test('a transfer between accounts counts once, as its fee', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final b = book.account('Bank', '1000.00');
      book.transfer('2026-10-03', a, b, '200.00', fee: '15.00');
      final both = cashFlow(book.s, [a, b], '2026-10-01', '2026-10-31');
      expect(both.moneyIn, BigInt.zero);
      expect(both.moneyOut, php('15.00'));
      // Seen from one account, the move itself counts for that account.
      expect(
        cashFlow(book.s, [b], '2026-10-01', '2026-10-31').moneyIn,
        php('200.00'),
      );
    });

    test('a refund is money in, and a reversal takes its record away', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final id = book.expense('2026-10-01', 'Shoes', a, '400.00');
      book.post('refund', {
        'date': '2026-10-02',
        'name': '',
        'source': id,
        'sourceVersion': '1',
        'amount': '100.00',
        'account': a,
        'reason': 'Returned',
        'refundPosting': '$id-p2',
      });
      var flow = cashFlow(book.s, [a], '2026-10-01', '2026-10-31');
      expect(flow.moneyIn, php('100.00'));
      expect(flow.moneyOut, php('400.00'));
      final other = book.expense('2026-10-03', 'Beans', a, '50.00');
      book.post('reversal', {
        'source': other,
        'sourceVersion': '1',
        'reason': 'Twice',
      });
      flow = cashFlow(book.s, [a], '2026-10-01', '2026-10-31');
      expect(flow.moneyOut, php('400.00'));
    });

    test('a corrected record counts at its new amount, once', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final id = book.expense('2026-10-01', 'Taxi', a, '320.00');
      book.post('correction', {
        'date': '2026-10-01',
        'name': 'Taxi',
        'source': id,
        'sourceVersion': '1',
        'reason': 'Wrong fare',
        'amount': '230.00',
        'account': a,
        'category': 'category-food',
      });
      expect(
        cashFlow(book.s, [a], '2026-10-01', '2026-10-31').moneyOut,
        php('230.00'),
      );
    });

    test('month boundaries are inclusive', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      book.expense('2026-09-30', 'Before', a, '1.00');
      book.expense('2026-10-01', 'First', a, '2.00');
      book.expense('2026-10-31', 'Last', a, '4.00');
      book.expense('2026-11-01', 'After', a, '8.00');
      expect(
        cashFlow(book.s, [a], '2026-10-01', '2026-10-31').moneyOut,
        php('6.00'),
      );
    });

    test('Money in and out explain the balance change', () {
      final s = demoSample(today);
      final ids = [for (final a in s.accounts) a.id];
      final start = monthStart(today);
      final flow = cashFlow(s, ids, start, today);
      final change =
          availableMoney(s, today) - availableMoney(s, addCivilDays(start, -1));
      expect(flow.moneyIn - flow.moneyOut, change);
    });
  });

  group('accounts', () {
    test('shares are of positive balances and largest comes first', () {
      final book = Book();
      final a = book.account('Wallet', '300.00');
      final b = book.account('Bank', '900.00');
      book.post('expense', {
        'date': '2026-10-02',
        'name': 'Over',
        'account': a,
        'amount': '400.00',
        'category': 'category-food',
        'acknowledge': 'true',
      });
      final rows = accountRows(book.s, today);
      expect(rows.map((r) => r.account.id), [b, a]);
      expect(rows.first.basisPoints, 10000);
      expect(rows.last.basisPoints, isNull);
      expect(rows.last.balance, -php('100.00'));
    });

    test('this month is since the end of last month', () {
      final book = Book();
      final a = book.account('Wallet', '500.00');
      book.expense('2026-09-15', 'Earlier', a, '100.00');
      book.expense('2026-10-02', 'Now', a, '40.00');
      expect(accountRows(book.s, today).single.change, -php('40.00'));
    });

    test('archived accounts are apart but still in Available money', () {
      final book = Book();
      final a = book.account('Wallet', '500.00');
      final old = book.account('Old', '200.00');
      book.post('archive', {'account': old, 'reason': 'Closed'});
      expect(accountRows(book.s, today).map((r) => r.account.id), [a]);
      final archived = accountRows(book.s, today, archived: true);
      expect(archived.single.account.id, old);
      expect(archived.single.basisPoints, isNull);
      expect(availableMoney(book.s, today), php('700.00'));
    });

    test('later records are not in today\'s balance', () {
      final book = Book();
      final a = book.account('Wallet', '500.00');
      book.expense('2026-11-05', 'Later', a, '100.00');
      expect(accountRows(book.s, today).single.balance, php('500.00'));
      expect(availableMoney(book.s, today), php('500.00'));
    });

    test('balance by month ends on today and on month ends before', () {
      final book = Book();
      final a = book.account('Wallet', '500.00');
      book.expense('2026-09-15', 'Earlier', a, '100.00');
      final points = balanceByMonth(book.s, [a], today, months: 3);
      expect(points.map((p) => p.$1), ['2026-08-31', '2026-09-30', today]);
      expect(points.map((p) => p.$2), [
        php('500.00'),
        php('400.00'),
        php('400.00'),
      ]);
    });

    test('last month\'s span stops at its last day', () {
      expect(lastMonthSpan('2026-03-31'), ('2026-02-01', '2026-02-28'));
      expect(lastMonthSpan('2026-10-15'), ('2026-09-01', '2026-09-15'));
      expect(lastMonthSpan('2026-01-31'), ('2025-12-01', '2025-12-31'));
    });
  });

  group('balance checks', () {
    (Book, String, String) checked(String actual) {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final id = book.post('reconcile', {
        'date': '2026-10-02',
        'account': a,
        'amount': actual,
        'mode': 'compare',
      });
      return (book, a, id);
    }

    test('a match, a difference, and records that changed since', () {
      var (book, a, id) = checked('1000.00');
      expect(
        balanceCheckState(book.s, book.s.revision(id)),
        CheckState.matched,
      );
      (book, a, id) = checked('950.00');
      expect(
        balanceCheckState(book.s, book.s.revision(id)),
        CheckState.difference,
      );
      book.expense('2026-10-01', 'Backdated', a, '5.00');
      expect(
        balanceCheckState(book.s, book.s.revision(id)),
        CheckState.changed,
      );
    });

    test('an adjustment resolves it, and it leaves Needs your attention', () {
      final (book, a, id) = checked('950.00');
      expect(moneyTasks(book.s, today).single.need, MoneyNeed.balanceCheck);
      book.post('adjustment', {
        'date': '2026-10-02',
        'account': a,
        'source': id,
        'sourceVersion': '1',
        'reason': 'Counted',
      });
      expect(
        balanceCheckState(book.s, book.s.revision(id)),
        CheckState.adjusted,
      );
      expect(moneyTasks(book.s, today), isEmpty);
    });

    test('only the newest check on an account can need attention', () {
      final (book, a, _) = checked('950.00');
      book.post('reconcile', {
        'date': '2026-10-03',
        'account': a,
        'amount': '1000.00',
        'mode': 'compare',
      });
      expect(moneyTasks(book.s, today), isEmpty);
      expect(lastChecked(book.s, a), '2026-10-03');
    });
  });

  group('moneyTasks', () {
    test('nothing, then below zero and drafts', () {
      final book = Book();
      final a = book.account('Wallet', '100.00');
      expect(moneyTasks(book.s, today), isEmpty);
      book.post('expense', {
        'date': '2026-10-02',
        'name': 'Over',
        'account': a,
        'amount': '400.00',
        'category': 'category-food',
        'acknowledge': 'true',
      });
      final tasks = moneyTasks(book.s, today, drafts: 2);
      expect(tasks.map((t) => t.need), [MoneyNeed.belowZero, MoneyNeed.drafts]);
      expect(tasks.first.title, 'Wallet is below zero');
      expect(tasks.last.title, '2 saved drafts');
    });

    test('an archived account below zero is not a task', () {
      final book = Book();
      final a = book.account('Wallet', '100.00');
      book.post('expense', {
        'date': '2026-10-02',
        'name': 'Over',
        'account': a,
        'amount': '400.00',
        'category': 'category-food',
        'acknowledge': 'true',
      });
      book.post('archive', {'account': a, 'reason': 'Closed'});
      expect(moneyTasks(book.s, today), isEmpty);
    });
  });

  group('ActivityFilter', () {
    late Book book;
    late String a, b;
    late List<MoneyRow> rows;
    setUp(() {
      book = Book();
      a = book.account('Wallet', '1000.00');
      b = book.account('Bank', '1000.00');
      book.post('expense', {
        'date': '2026-10-05',
        'name': 'Lunch',
        'account': a,
        'amount': '185.50',
        'category': 'category-food',
        'merchant': 'Canteen',
        'reference': 'R-77',
      });
      book.income('2026-09-20', 'Pay', b, '1500.00');
      book.transfer('2026-10-06', b, a, '200.00');
      book.expense('2026-11-02', 'Later bill', b, '10.00');
      rows = moneyActivity(book.s, name);
    });
    List<String> titles(ActivityFilter f) => [
      for (final r in rows)
        if (f.shows(r, today)) r.title,
    ];

    test('this month starts on the 1st and keeps later records', () {
      expect(titles(const ActivityFilter()), ['Later bill', 'Move', 'Lunch']);
    });

    test('last month has both ends', () {
      expect(titles(const ActivityFilter(period: ActivityPeriod.lastMonth)), [
        'Pay',
      ]);
    });

    test('last 90 days counts today', () {
      final (start, _) = const ActivityFilter(period: ActivityPeriod.last90)
          .range(today);
      expect(civilDaysBetween(start!, today), 89);
    });

    test('search looks through every date, whatever the period', () {
      expect(titles(const ActivityFilter(query: 'pay')), ['Pay']);
      expect(
        const ActivityFilter(query: 'pay').shownPeriod,
        ActivityPeriod.all,
      );
    });

    test('search reads notes, references, merchants and exact amounts', () {
      expect(titles(const ActivityFilter(query: 'canteen')), ['Lunch']);
      expect(titles(const ActivityFilter(query: 'r-77')), ['Lunch']);
      expect(titles(const ActivityFilter(query: '185.50')), ['Lunch']);
      expect(titles(const ActivityFilter(query: '1,500')), ['Pay']);
      expect(titles(const ActivityFilter(query: 'lunch wallet')), ['Lunch']);
      expect(titles(const ActivityFilter(query: 'nothing here')), isEmpty);
    });

    test('type: money in and out follow the sign, within an account too', () {
      expect(
        titles(
          const ActivityFilter(
            type: ActivityType.moneyOut,
            period: ActivityPeriod.all,
          ),
        ),
        ['Later bill', 'Lunch'],
      );
      expect(
        titles(
          ActivityFilter(
            type: ActivityType.moneyIn,
            period: ActivityPeriod.all,
            account: a,
          ),
        ),
        ['Move'],
      );
      expect(
        titles(
          const ActivityFilter(
            type: ActivityType.transfers,
            period: ActivityPeriod.all,
          ),
        ),
        ['Move'],
      );
    });

    test('account and category narrow; each counts on the Filters button', () {
      final f = ActivityFilter(account: a, period: ActivityPeriod.all);
      expect(titles(f), ['Move', 'Lunch', 'Opening balance · Wallet']);
      expect(f.filters, 1);
    });

    test('custom dates may be open at one end', () {
      expect(
        titles(
          const ActivityFilter(
            period: ActivityPeriod.custom,
            from: '2026-10-06',
          ),
        ),
        ['Later bill', 'Move'],
      );
      expect(
        titles(
          const ActivityFilter(period: ActivityPeriod.custom, to: '2026-09-30'),
        ).first,
        'Pay',
      );
    });

    test('totals leave out later records and reversed ones', () {
      final totals = listedTotals(
        rows.where((r) => r.title != 'Opening balance · Wallet'),
        today,
      );
      expect(totals.moneyOut, php('185.50'));
    });
  });

  group('dayLabel and periodHeading', () {
    test('today, yesterday, older and later', () {
      expect(dayLabel(today, today), startsWith('Today · '));
      expect(dayLabel('2026-10-29', today), startsWith('Yesterday · '));
      expect(dayLabel('2026-10-28', today), isNot(contains('Yesterday')));
      expect(dayLabel('2026-10-31', today), contains('not in your balance'));
    });

    test('a whole month reads as its name; other spans as the span', () {
      expect(periodHeading('2026-10-01', '2026-10-31'), 'October 2026');
      expect(periodHeading('2026-02-01', '2026-02-28'), 'February 2026');
      expect(periodHeading('2026-10-01', '2026-10-30'), '1–30 Oct');
    });
  });

  group('Statement', () {
    test('its closing balance is the account\'s, row by row', () {
      final s = demoSample(today);
      final id = s.accounts.first.id;
      final from = monthStart(today);
      final rows = moneyActivity(s, name);
      final statement = Statement.of(s, rows, from, today, account: id);
      expect(
        statement.starting,
        s.balance(id, through: addCivilDays(from, -1)),
      );
      expect(statement.closing, s.balance(id, through: today));
      expect(statement.balances.length, statement.rows.length);
      expect(statement.balances.lastOrNull, statement.closing);
    });

    test('oldest first, with no reversed, later or check rows', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final id = book.expense('2026-10-01', 'Gone', a, '50.00');
      book.post('reversal', {
        'source': id,
        'sourceVersion': '1',
        'reason': 'Twice',
      });
      book.expense('2026-10-02', 'First', a, '10.00');
      book.expense('2026-10-03', 'Second', a, '20.00');
      book.expense('2026-11-01', 'Later', a, '40.00');
      book.post('reconcile', {
        'date': '2026-10-04',
        'account': a,
        'amount': '970.00',
        'mode': 'compare',
      });
      final statement = Statement.of(
        book.s,
        moneyActivity(book.s, name),
        '2026-10-01',
        today,
        account: a,
      );
      expect(statement.rows.map((r) => r.title), ['First', 'Second']);
      expect(statement.balances, [php('990.00'), php('970.00')]);
    });

    test('without an account it has no balances', () {
      final s = demoSample(today);
      final statement = Statement.of(
        s,
        moneyActivity(s, name),
        monthStart(today),
        today,
      );
      expect(statement.balances, isEmpty);
      expect(statement.starting, isNull);
    });
  });

  group('recordActions', () {
    test('an expense can be corrected, refunded and reversed', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final id = book.expense('2026-10-01', 'Shoes', a, '400.00');
      final can = recordActions(book.s, book.s.revision(id));
      expect(can.correct, isTrue);
      expect(can.reverse, isTrue);
      expect(can.refund, isTrue);
      expect(can.blocked, isNull);
    });

    test('a transfer with no fee has nothing to refund', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final b = book.account('Bank', '1000.00');
      final plain = book.transfer('2026-10-01', a, b, '100.00');
      final fee = book.transfer('2026-10-02', a, b, '100.00', fee: '5.00');
      expect(recordActions(book.s, book.s.revision(plain)).refund, isFalse);
      expect(recordActions(book.s, book.s.revision(fee)).refund, isTrue);
    });

    test('a record with a refund says why it can\'t be changed yet', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final id = book.expense('2026-10-01', 'Shoes', a, '400.00');
      book.post('refund', {
        'date': '2026-10-02',
        'name': '',
        'source': id,
        'sourceVersion': '1',
        'amount': '100.00',
        'account': a,
        'reason': 'Returned',
        'refundPosting': '$id-p2',
      });
      final can = recordActions(book.s, book.s.revision(id));
      expect(can.blocked, contains('Reverse that first'));
    });

    test('a Shared-linked record is changed in Shared Expenses', () {
      final revision = LocalRevision(
        id: 'shared',
        actionId: 'shared',
        kind: 'expense',
        change: 'create',
        date: '2026-10-01',
        title: 'Group dinner',
        amount: BigInt.one,
        values: {'sharedGroup': 'g'},
        postings: [],
        number: 1,
      );
      final s = LocalSnapshot(
        owner: 'x',
        version: 1,
        accounts: const [],
        categories: const [],
        revisions: [revision],
      );
      final can = recordActions(s, revision);
      expect(can.shared, isTrue);
      expect(can.any, isFalse);
    });

    test('an earlier version points at the current one', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final id = book.expense('2026-10-01', 'Taxi', a, '320.00');
      final fixed = book.post('correction', {
        'date': '2026-10-01',
        'name': 'Taxi',
        'source': id,
        'sourceVersion': '1',
        'reason': 'Wrong fare',
        'amount': '230.00',
        'account': a,
        'category': 'category-food',
      });
      expect(recordActions(book.s, book.s.revision(id)).superseded, fixed);
    });

    test('a balance check offers what its state allows', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final id = book.post('reconcile', {
        'date': '2026-10-02',
        'account': a,
        'amount': '950.00',
        'mode': 'compare',
      });
      expect(recordActions(book.s, book.s.revision(id)).adjust, isTrue);
      book.expense('2026-10-01', 'Backdated', a, '5.00');
      final can = recordActions(book.s, book.s.revision(id));
      expect(can.adjust, isFalse);
      expect(can.checkAgain, isTrue);
    });
  });

  group('recordEffects', () {
    test('an expense reads as money leaving and spending', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final id = book.expense('2026-10-01', 'Lunch', a, '100.00');
      final effects = recordEffects(book.s, book.s.revision(id), name);
      expect(effects.first.label, 'Wallet');
      expect(effects.first.amount, -php('100.00'));
      expect(effects.last.label, 'Spending');
      expect(effects.last.amount, php('100.00'));
    });

    test('income is positive on both lines', () {
      final book = Book();
      final a = book.account('Wallet', '1000.00');
      final id = book.income('2026-10-01', 'Pay', a, '100.00');
      final effects = recordEffects(book.s, book.s.revision(id), name);
      expect(effects.map((e) => e.amount), [php('100.00'), php('100.00')]);
    });
  });

  group('demo sample', () {
    test('it replays on week, month and year edges and ends on the demo '
        'balances', () {
      final expected = sumMinor(demoAccounts.map((a) => BigInt.parse(a.$2)));
      for (final day in const [
        '2026-01-01',
        '2026-01-31',
        '2026-02-28',
        '2028-02-29',
        '2026-03-01',
        '2026-03-31',
        '2026-06-30',
        '2026-10-05',
        '2026-10-11',
        '2026-10-12',
        '2026-10-30',
        '2026-12-31',
        '2027-01-01',
      ]) {
        final s = demoOverviewSnapshot(day);
        expect(availableMoney(s, day), expected, reason: day);
        expect(s.accounts.where((a) => a.archived).map((a) => a.name), [
          'Old savings',
        ], reason: day);
        final rows = moneyActivity(s, name);
        expect(rows.any((r) => r.reversed), isTrue, reason: day);
        expect(
          rows.any((r) => r.change == RecordChange.corrected),
          isTrue,
          reason: day,
        );
        expect(rows.any((r) => r.isCheck), isTrue, reason: day);
        expect(rows.any((r) => r.date.compareTo(day) > 0), isTrue, reason: day);
        expect(
          moneyTasks(s, day).map((t) => t.need),
          contains(MoneyNeed.balanceCheck),
          reason: day,
        );
      }
    });
  });
}
