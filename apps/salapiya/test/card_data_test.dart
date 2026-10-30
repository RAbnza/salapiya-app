import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_demo.dart';
import 'package:salapiya/connected/financial_contract.dart';
import 'package:salapiya/finance/card_data.dart';
import 'package:salapiya/finance/money_data.dart';
import 'package:salapiya/local/finance_domain.dart';

BigInt php(int pesos) => BigInt.from(pesos * 100);

/// A small book replayed through the real rules.
class Book {
  Book() : s = demoOverviewSnapshot('2026-10-15', empty: true);
  LocalSnapshot s;
  int n = 0;
  String post(String kind, Map<String, String> values) {
    final id =
        '00000000-0000-4000-9000-${(++n).toRadixString(16).padLeft(12, '0')}';
    final command = LocalCommand(
      id: id,
      owner: s.owner,
      expectedVersion: s.version,
      kind: kind,
      values: {'acknowledge': 'false', ...values},
    );
    s = applyFinancialPlan(s, planLocal(s, command));
    return id;
  }

  String account([String name = 'Bank']) => post('account', {
    'name': name,
    'kind': 'Bank',
    'amount': '100000.00',
    'cutoff': '2026-01-01',
  });

  String card({String limit = '10000.00', String name = 'Rewards'}) =>
      post('creditCard', {
        'date': '2026-02-01',
        'name': name,
        'issuer': 'Issuer',
        'amount': '0.00',
        'limit': limit,
      });

  String buy(String card, String amount, {String date = '2026-03-10'}) =>
      post('cardPurchase', {
        'date': date,
        'name': 'Purchase $amount',
        'card': card,
        'amount': amount,
        'postingDate': date,
        'category': 'category-other',
      });

  String pay(String card, String account, String amount, {String? date}) =>
      post('cardPayment', {
        'date': date ?? '2026-03-20',
        'name': 'Payment',
        'card': card,
        'account': account,
        'amount': amount,
      });

  String statement(
    String card, {
    String amount = '1000.00',
    String issued = '2026-03-31',
    String due = '2026-04-20',
  }) => post('statement', {
    'date': issued,
    'name': 'Statement',
    'card': card,
    'start': '2026-03-01',
    'end': issued,
    'issued': issued,
    'due': due,
    'amount': amount,
    'minimum': '',
    'reference': 'Ref',
    'verified': 'true',
  });

  String match(String card, String statement, String payment, String amount) =>
      post('cardAllocation', {
        'date': '2026-04-01',
        'name': 'Matched',
        'card': card,
        'statement': statement,
        'payment': payment,
        'amount': amount,
        'verified': 'true',
      });
}

void main() {
  const today = '2026-10-15';

  group('cardRows', () {
    test('no cards', () {
      final book = Book();
      final summary = CardsSummary(cardRows(book.s, today));
      expect(summary.cards, isEmpty);
      expect(summary.owed, BigInt.zero);
      expect(summary.usedBasisPoints, isNull);
      expect(summary.limited, isEmpty);
    });

    test('what you owe, available credit and credit used', () {
      final book = Book();
      final card = book.card();
      book.buy(card, '2500.00');
      final row = cardRows(book.s, today).single;
      expect(row.owed, php(2500));
      expect(row.credit, BigInt.zero);
      expect(row.available, php(7500));
      expect(row.over, BigInt.zero);
      expect(row.usedBasisPoints, 2500);
    });

    test('a card credit is not debt and does not raise available credit', () {
      final book = Book();
      final bank = book.account();
      final card = book.card();
      book.buy(card, '500.00');
      book.pay(card, bank, '800.00');
      final row = cardRows(book.s, today).single;
      expect(row.owed, BigInt.zero);
      expect(row.credit, php(300));
      expect(row.available, php(10000), reason: 'never above the limit');
      expect(row.usedBasisPoints, 0);
    });

    test('over the limit stops at zero and says by how much', () {
      final book = Book();
      final card = book.card(limit: '1000.00');
      book.buy(card, '1250.00');
      final row = cardRows(book.s, today).single;
      expect(row.available, BigInt.zero);
      expect(row.over, php(250));
      expect(row.usedBasisPoints, 12500);
    });

    test('a missing limit has no percentage or available credit', () {
      final book = Book();
      final card = book.card(limit: '');
      book.buy(card, '100.00');
      final row = cardRows(book.s, today).single;
      expect(row.limit, isNull);
      expect(row.available, isNull);
      expect(row.usedBasisPoints, isNull);
    });

    test('a zero limit has no percentage', () {
      final book = Book();
      final card = book.card(limit: '0.00');
      book.buy(card, '100.00');
      final row = cardRows(book.s, today).single;
      expect(row.hasLimit, isFalse);
      expect(row.usedBasisPoints, isNull);
      expect(row.available, BigInt.zero);
    });

    test('records dated after today are not owed yet', () {
      final book = Book();
      final card = book.card();
      book.buy(card, '100.00', date: '2026-10-16');
      expect(cardRows(book.s, today).single.owed, BigInt.zero);
      expect(cardRows(book.s, '2026-10-16').single.owed, php(100));
    });

    test('a reversed purchase no longer counts', () {
      final book = Book();
      final card = book.card();
      final buy = book.buy(card, '100.00');
      book.post('financeReversal', {
        'replace': buy,
        'replaceVersion': '1',
        'reason': 'Logged twice',
      });
      expect(cardRows(book.s, today).single.owed, BigInt.zero);
    });

    test('a corrected purchase counts once, at its new amount', () {
      final book = Book();
      final card = book.card();
      final buy = book.buy(card, '100.00');
      book.post('financeCorrection', {
        'replace': buy,
        'replaceVersion': '1',
        'reason': 'Wrong amount',
        'amount': '150.00',
      });
      expect(cardRows(book.s, today).single.owed, php(150));
    });
  });

  group('totals across cards', () {
    test('sum over sum, never an average, and credits stay out', () {
      final book = Book();
      final bank = book.account();
      final a = book.card(limit: '1000.00', name: 'A');
      final b = book.card(limit: '9000.00', name: 'B');
      final c = book.card(limit: '', name: 'C');
      final d = book.card(limit: '5000.00', name: 'D');
      book.buy(a, '500.00');
      book.buy(b, '500.00');
      book.buy(c, '700.00');
      book.buy(d, '100.00');
      book.pay(d, bank, '400.00');
      final summary = CardsSummary(cardRows(book.s, today));
      expect(summary.owed, php(1700));
      expect(summary.credit, php(300));
      // 1,000 of 15,000, not the average of 50%, 5.5% and 0%.
      expect(summary.usedBasisPoints, 666);
      expect(summary.available, php(14000));
      expect(summary.limited, hasLength(3));
    });

    test('an older unpaid statement is not added to a newer one', () {
      final book = Book();
      final card = book.card();
      book.buy(card, '1000.00');
      book.statement(card, amount: '1000.00');
      book.statement(
        card,
        amount: '1500.00',
        issued: '2026-04-30',
        due: '2026-05-20',
      );
      final summary = CardsSummary(cardRows(book.s, today));
      expect(summary.stillDue, php(1500));
    });
  });

  group('statements', () {
    test('matched payments lower what is still due, not the balance', () {
      final book = Book();
      final bank = book.account();
      final card = book.card();
      book.buy(card, '1000.00');
      final pay = book.pay(card, bank, '400.00');
      final statement = book.statement(card);
      book.match(card, statement, pay, '400.00');
      final row = statementRows(book.s, card, today).single;
      expect(row.balance, php(1000));
      expect(row.paid, php(400));
      expect(row.stillDue, php(600));
      expect(row.settled, isFalse);
    });

    test('a statement in credit has nothing due, not a negative amount', () {
      final book = Book();
      final card = book.card();
      book.statement(card, amount: '-50.00');
      final row = statementRows(book.s, card, today).single;
      expect(row.stillDue, BigInt.zero);
      expect(row.settled, isTrue);
      expect(row.overdue, isFalse);
    });

    test('a difference from your records stays visible', () {
      final book = Book();
      final card = book.card();
      book.buy(card, '900.00');
      final statement = book.statement(card, amount: '1000.00');
      final row = statementRows(book.s, card, today).single;
      expect(row.recorded, php(900));
      expect(row.difference, php(100));
      expect(
        cardTasks(book.s, cardRows(book.s, today)).map((t) => t.need),
        contains(CardNeed.difference),
      );
      expect(statement, isNotEmpty);
    });

    test('status edges: the due date itself is not overdue', () {
      final book = Book();
      final card = book.card();
      book.buy(card, '100.00');
      book.statement(card, amount: '100.00', due: '2026-10-15');
      expect(
        statementRows(book.s, card, today).single.status,
        DebtDueStatus.dueToday,
      );
      expect(
        statementRows(book.s, card, '2026-10-16').single.overdue,
        isTrue,
      );
    });

    test('a payment dated after today is not matched yet', () {
      final book = Book();
      final bank = book.account();
      final card = book.card();
      book.buy(card, '100.00');
      final statement = book.statement(card, amount: '100.00');
      final pay = book.pay(card, bank, '100.00', date: '2026-10-20');
      book.post('cardAllocation', {
        'date': '2026-10-20',
        'name': 'Matched',
        'card': card,
        'statement': statement,
        'payment': pay,
        'amount': '100.00',
        'verified': 'true',
      });
      expect(
        statementRows(book.s, card, today).single.stillDue,
        php(100),
      );
      expect(
        statementRows(book.s, card, '2026-10-20').single.stillDue,
        BigInt.zero,
      );
    });

    test('activity posted in the period stays a suggestion until matched', () {
      final book = Book();
      final card = book.card();
      final buy = book.buy(card, '100.00');
      final statement = book.statement(card, amount: '100.00');
      final record = book.s.revision(statement);
      expect(unmatchedActivity(book.s, record).single.id, buy);
      expect(matchedActivity(book.s, record), isEmpty);
      book.post('statementLink', {
        'date': '2026-04-01',
        'name': 'Matched',
        'card': card,
        'statement': statement,
        'activity': buy,
        'verified': 'true',
      });
      expect(unmatchedActivity(book.s, record), isEmpty);
      expect(matchedActivity(book.s, record).single.id, buy);
    });
  });

  group('installments', () {
    String plan(Book book, String card, String purchase) =>
        book.post('installment', {
          'date': '2026-03-10',
          'name': 'Plan',
          'card': card,
          'purchase': purchase,
          'schedule':
              'Installment 1,2026-04-01,300.00\n'
              'Installment 2,2026-05-01,300.00,100.00\n'
              'Installment 3,2026-11-01,400.00',
          'principal': '',
          'interest': '',
          'fee': '',
          'reference': 'Ref',
          'verified': 'true',
        });

    test('what is left on each payment and the plan', () {
      final book = Book();
      final bank = book.account();
      final card = book.card();
      final buy = book.buy(card, '1000.00');
      final id = plan(book, card, buy);
      final statement = book.statement(card);
      final pay = book.pay(card, bank, '300.00');
      final matched = book.match(card, statement, pay, '300.00');
      book.post('installmentApplication', {
        'date': '2026-04-02',
        'name': 'Matched',
        'card': card,
        'plan': id,
        'row': 'Installment 1',
        'payment': matched,
        'amount': '300.00',
        'verified': 'true',
      });
      final row = planRows(book.s, card, today).single;
      expect(row.total, 3);
      expect(row.done, 1);
      expect(row.amount, php(1000));
      expect(row.left, php(600));
      expect(row.next!.row.id, 'Installment 2');
      expect(row.next!.left, php(200), reason: 'already paid counts');
      expect(row.finished, isFalse);
    });

    test('statements and installments are listed apart, never summed', () {
      final book = Book();
      final card = book.card();
      final buy = book.buy(card, '1000.00');
      plan(book, card, buy);
      book.statement(card, amount: '1000.00', due: '2026-10-20');
      final dues = cardDues(book.s, today);
      expect(dues.where((d) => d.statement), hasLength(1));
      expect(dues.where((d) => !d.statement), hasLength(3));
      expect(dues.first.item.days, lessThan(0), reason: 'overdue first');
    });
  });

  group('pending charges', () {
    test('count until a purchase uses them, and are never owed', () {
      final book = Book();
      final card = book.card();
      final hold = book.post('cardAuthorization', {
        'date': '2026-03-01',
        'name': 'Hold',
        'card': card,
        'amount': '100.00',
        'reference': 'Ref',
      });
      expect(pendingCharges(book.s, card), hasLength(1));
      expect(cardRows(book.s, today).single.owed, BigInt.zero);
      book.post('cardPurchase', {
        'date': '2026-03-02',
        'name': 'Posted',
        'card': card,
        'amount': '100.00',
        'postingDate': '2026-03-02',
        'category': 'category-other',
        'authorization': hold,
      });
      expect(pendingCharges(book.s, card), isEmpty);
      expect(cardRows(book.s, today).single.owed, php(100));
    });
  });

  group('cardDebtByMonth', () {
    test('month ends then today, and one card’s credit stays apart', () {
      final book = Book();
      final bank = book.account();
      final a = book.card(name: 'A');
      final b = book.card(name: 'B');
      book.buy(a, '100.00', date: '2026-09-10');
      book.buy(b, '50.00', date: '2026-09-10');
      book.pay(b, bank, '80.00', date: '2026-10-01');
      final months = cardDebtByMonth(book.s, today, months: 3);
      expect(months.map((m) => m.$1), [
        '2026-08-31',
        '2026-09-30',
        today,
      ]);
      expect(months.map((m) => m.$2), [BigInt.zero, php(150), php(100)]);
    });

    test('month boundaries in a short year', () {
      final book = Book();
      expect(
        cardDebtByMonth(book.s, '2026-03-01', months: 3).map((m) => m.$1),
        ['2026-01-31', '2026-02-28', '2026-03-01'],
      );
    });
  });

  group('recordActions offers only what the rules accept', () {
    test('a card with nothing on it, then with activity', () {
      final book = Book();
      final card = book.card();
      var can = recordActions(book.s, book.s.revision(card));
      expect((can.correct, can.reverse, can.blocked), (true, true, null));
      book.buy(card, '100.00');
      can = recordActions(book.s, book.s.revision(card));
      expect(can.correct, isFalse);
      expect(can.reverse, isFalse);
      expect(can.blocked, isNotNull);
    });

    test('a budget, goal or item is corrected, never reversed', () {
      final book = Book();
      final budget = book.post('budget', {
        'date': '2026-10-01',
        'name': 'Food',
        'amount': '100.00',
        'category': 'category-food',
        'start': '2026-10-01',
        'endExclusive': '2026-11-01',
        'basis': 'net',
        'status': 'active',
      });
      final can = recordActions(book.s, book.s.revision(budget));
      expect((can.correct, can.reverse), (true, false));
    });

    test('money set aside belongs to its goal', () {
      final book = Book();
      final bank = book.account();
      final goal = book.post('savingsGoal', {
        'date': '2026-02-01',
        'name': 'Trip',
        'amount': '100.00',
        'targetDate': '',
        'status': 'active',
      });
      final aside = book.post('reservation', {
        'date': '2026-03-01',
        'name': 'Set aside',
        'goal': goal,
        'account': bank,
        'amount': '100.00',
      });
      final can = recordActions(book.s, book.s.revision(aside));
      expect((can.correct, can.reverse), (false, false));
      expect(can.blocked, isNotNull);
    });

    test('what it says it can do, the rules accept', () {
      final book = Book();
      final card = book.card();
      final can = recordActions(book.s, book.s.revision(card));
      expect(can.correct, isTrue);
      book.post('financeCorrection', {
        'replace': card,
        'replaceVersion': '1',
        'reason': 'New limit',
        'limit': '20000.00',
      });
      expect(cardRows(book.s, today).single.limit, php(20000));
    });
  });

  group('cardTasks', () {
    test('nothing to do', () {
      final book = Book();
      final card = book.card();
      book.buy(card, '100.00');
      expect(cardTasks(book.s, cardRows(book.s, today)), isEmpty);
    });

    test('a payment not matched only matters while a statement is due', () {
      final book = Book();
      final bank = book.account();
      final card = book.card();
      book.buy(card, '100.00');
      book.pay(card, bank, '50.00');
      List<CardNeed> needs() => [
        for (final t in cardTasks(book.s, cardRows(book.s, today))) t.need,
      ];
      expect(needs(), isNot(contains(CardNeed.unmatched)));
      book.statement(card, amount: '100.00');
      expect(needs(), contains(CardNeed.unmatched));
    });

    test('over the limit and a card credit each say so', () {
      final book = Book();
      final bank = book.account();
      final a = book.card(limit: '10.00', name: 'A');
      final b = book.card(name: 'B');
      book.buy(a, '20.00');
      book.pay(b, bank, '5.00');
      final needs = {
        for (final t in cardTasks(book.s, cardRows(book.s, today))) t.need,
      };
      expect(needs, containsAll({CardNeed.overLimit, CardNeed.cardCredit}));
    });
  });
}
