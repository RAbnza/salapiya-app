import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/finance/contracts/financial_models.dart';
import 'package:salapiya/features/finance/presentation/financial_widgets.dart';
import 'package:salapiya/finance/finance_screen.dart';
import 'package:salapiya/finance/money_editor.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_finance_controller.dart';

import 'local_money_journey.dart' show localSettle, localTap;
import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

void main() {
  late LocalFixture f;
  late LocalFinancialController c;
  late String bank;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    f = (await tester.runAsync(LocalFixture.open))!;
    await tester.runAsync(() async {
      bank = await f.account('Bank', '5000.00', '2026-01-01');
      c = LocalFinancialController(f.store, await f.store.snapshot());
      await c.reload();
    });
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    await closeWithWidgetClock(tester, f.close);
  }

  /// A record already in the book, before the form opens.
  Future<String> book(
    WidgetTester tester,
    String kind,
    Map<String, String> values,
  ) async {
    late String id;
    await tester.runAsync(() async {
      id = await f.post(kind, values);
      await c.reload();
    });
    return id;
  }

  Future<void> form(
    WidgetTester tester,
    String op, {
    Map<String, String> initial = const {},
    LocalRevision? replacing,
    Map<String, String> overrides = const {},
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        themeAnimationDuration: Duration.zero,
        theme: SalapiyaTheme.build(
          Brightness.light,
          platform: TargetPlatform.windows,
        ),
        home: FinancialEnvironment(
          production: true,
          child: NativeFinanceEditor(
            controller: c,
            operation: op,
            title: formTitles[op] ?? 'Form',
            initial: initial,
            replacing: replacing,
            overrides: overrides,
          ),
        ),
      ),
    );
    await localSettle(tester);
  }

  Finder field(String key) => find.byKey(ValueKey('native-$key'));
  Finder picker(String key) => find.byKey(ValueKey('native-select-$key'));

  Future<void> enter(WidgetTester tester, String key, String value) async {
    final finder = field(key);
    await tester.ensureVisible(finder);
    await tester.pump();
    final widget = tester.widget(finder);
    if (widget is DateField) {
      widget.onChanged!(DateTime.parse(value));
      await tester.pump();
      return;
    }
    tester
        .state<EditableTextState>(
          find.descendant(of: finder, matching: find.byType(EditableText)),
        )
        .updateEditingValue(
          TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          ),
        );
    await tester.pump();
  }

  OptionPicker<String> pickerOf(WidgetTester tester, String key) =>
      tester.widget<OptionPicker<String>>(picker(key));

  Future<void> pick(WidgetTester tester, String key, String value) async {
    pickerOf(tester, key).onChanged!(value);
    await tester.pump();
  }

  Finder submit() => find.byKey(const ValueKey('native-submit'));

  Future<void> save(WidgetTester tester) async {
    await localTap(tester, submit());
    expect(find.textContaining('Step 2 of 2'), findsOneWidget);
    await localTap(tester, submit());
    expect(find.text('Saved securely on this device.'), findsOneWidget);
  }

  String? errorOn(WidgetTester tester, String key) {
    final found = picker(key).evaluate().isNotEmpty ? picker(key) : field(key);
    return switch (tester.widget(found)) {
      AmountField(:final errorText) => errorText,
      HelpTextField(:final errorText) => errorText,
      DateField(:final errorText) => errorText,
      OptionPicker<String>(:final errorText) => errorText,
      _ => null,
    };
  }

  LocalRevision saved(String type) =>
      c.snapshot.current.lastWhere((r) => financeType(r) == type);

  Future<String> card(WidgetTester tester, [String name = 'Rewards']) =>
      book(tester, 'creditCard', {
        'name': name,
        'date': '2026-02-01',
        'issuer': 'Issuer',
        'amount': '0.00',
        'limit': '10000.00',
      });

  Future<String> purchase(
    WidgetTester tester,
    String card, {
    String category = 'category-other',
    String name = 'Shoes',
  }) => book(tester, 'cardPurchase', {
    'name': name,
    'date': '2026-03-10',
    'card': card,
    'amount': '1000.00',
    'postingDate': '2026-03-10',
    'category': category,
  });

  group('Cards', () {
    testWidgets('Add a card keeps the signed balance and every value', (
      tester,
    ) async {
      await open(tester);
      try {
        await form(tester, 'creditCard');
        expect(find.textContaining('PHP'), findsNothing);
        expect(tester.widget<DateField>(field('date')).label, 'Balance as of');
        await enter(tester, 'name', 'Rewards');
        await enter(tester, 'issuer', 'Issuer');
        await enter(tester, 'limit', '10000.00');
        await enter(tester, 'amount', '-250.00');
        await enter(tester, 'date', '2026-02-01');
        await save(tester);
        final r = saved('creditCard');
        expect(r.title, 'Rewards');
        expect(r.values['limit'], '10000.00');
        expect(r.values['amount'], '-250.00');
        expect(r.amount, BigInt.from(-25000));
      } finally {
        await close(tester);
      }
    });

    testWidgets('Log a card payment names itself and keeps the command', (
      tester,
    ) async {
      await open(tester);
      try {
        final id = await card(tester);
        await form(tester, 'cardPayment', initial: {'card': id});
        await enter(tester, 'amount', '300.00');
        await pick(tester, 'account', bank);
        await enter(tester, 'date', '2026-04-01');
        await save(tester);
        final r = saved('cardPayment');
        expect(r.title, 'Payment · Rewards');
        expect(r.values['card'], id);
        expect(r.values['account'], bank);
        expect(r.values['date'], '2026-04-01');
        expect(r.amount, BigInt.from(30000));
      } finally {
        await close(tester);
      }
    });

    testWidgets('a card fee starts on Fees, not Food', (tester) async {
      await open(tester);
      try {
        final id = await card(tester);
        await form(tester, 'cardFee', initial: {'card': id});
        expect(pickerOf(tester, 'category').value, 'category-fees');
        await enter(tester, 'amount', '50.00');
        await enter(tester, 'date', '2026-04-01');
        await save(tester);
        expect(saved('cardFee').postings.any((p) {
          return p.ledger == 'expense' && p.category == 'category-fees';
        }), isTrue);
        expect(saved('cardFee').title, 'Fee · Rewards');
      } finally {
        await close(tester);
      }
    });

    testWidgets('a refund takes the purchase’s category', (tester) async {
      await open(tester);
      try {
        final id = await card(tester);
        final bought = await purchase(tester, id);
        await form(tester, 'cardRefund', initial: {'card': id});
        await pick(tester, 'purchase', bought);
        await enter(tester, 'amount', '100.00');
        await enter(tester, 'reason', 'Returned');
        await enter(tester, 'date', '2026-04-01');
        await save(tester);
        expect(saved('cardRefund').values['category'], 'category-other');
      } finally {
        await close(tester);
      }
    });

    testWidgets('pickers list only the chosen card’s records', (tester) async {
      await open(tester);
      try {
        final a = await card(tester, 'A');
        final b = await card(tester, 'B');
        final onA = await purchase(tester, a, name: 'On A');
        final onB = await purchase(tester, b, name: 'On B');
        await form(tester, 'installment', initial: {'card': a});
        final ids = pickerOf(tester, 'purchase').options.map((o) => o.value);
        expect(ids, contains(onA));
        expect(ids, isNot(contains(onB)));
        await pick(tester, 'card', b);
        final after = pickerOf(tester, 'purchase').options.map((o) => o.value);
        expect(after, contains(onB));
        expect(after, isNot(contains(onA)));
      } finally {
        await close(tester);
      }
    });

    testWidgets('a statement fills its reference and asks to confirm', (
      tester,
    ) async {
      await open(tester);
      try {
        final id = await card(tester);
        await form(tester, 'statement', initial: {'card': id});
        await enter(tester, 'amount', '1000.00');
        await enter(tester, 'start', '2026-03-01');
        await enter(tester, 'end', '2026-03-31');
        await enter(tester, 'issued', '2026-03-31');
        await enter(tester, 'due', '2026-04-20');
        await localTap(tester, submit());
        expect(errorOn(tester, 'verified'), isNotNull);
        await pick(tester, 'verified', 'true');
        await save(tester);
        final r = saved('statement');
        expect(r.values['reference'], 'Entered by me');
        expect(r.title, 'Rewards statement');
        expect(r.values['end'], '2026-03-31');
      } finally {
        await close(tester);
      }
    });

    testWidgets('statement dates out of order show on their field', (
      tester,
    ) async {
      await open(tester);
      try {
        final id = await card(tester);
        await form(tester, 'statement', initial: {'card': id});
        await enter(tester, 'amount', '1000.00');
        await enter(tester, 'start', '2026-04-01');
        await enter(tester, 'end', '2026-03-31');
        await enter(tester, 'issued', '2026-03-31');
        await enter(tester, 'due', '2026-04-20');
        await pick(tester, 'verified', 'true');
        await localTap(tester, submit());
        expect(errorOn(tester, 'end'), isNotNull);
      } finally {
        await close(tester);
      }
    });

    testWidgets('matching a payment fills the lesser amount', (tester) async {
      await open(tester);
      try {
        final id = await card(tester);
        await purchase(tester, id);
        final statement = await book(tester, 'statement', {
          'name': 'Statement',
          'date': '2026-03-31',
          'card': id,
          'start': '2026-03-01',
          'end': '2026-03-31',
          'issued': '2026-03-31',
          'due': '2026-04-20',
          'amount': '1000.00',
          'minimum': '',
          'reference': 'Ref',
          'verified': 'true',
        });
        final paid = await book(tester, 'cardPayment', {
          'name': 'Payment',
          'date': '2026-04-01',
          'card': id,
          'account': bank,
          'amount': '400.00',
        });
        await form(
          tester,
          'cardAllocation',
          initial: {'card': id, 'statement': statement},
        );
        await pick(tester, 'payment', paid);
        expect(
          tester.widget<AmountField>(field('amount')).controller.text,
          '400.00',
        );
        await pick(tester, 'verified', 'true');
        await enter(tester, 'date', '2026-04-02');
        await save(tester);
        final r = saved('cardAllocation');
        expect(r.values['statement'], statement);
        expect(r.values['payment'], paid);
      } finally {
        await close(tester);
      }
    });

    testWidgets('an installment plan is built from a few answers', (
      tester,
    ) async {
      await open(tester);
      try {
        final id = await card(tester);
        final bought = await purchase(tester, id);
        await form(tester, 'installment', initial: {'card': id});
        await pick(tester, 'purchase', bought);
        await enter(tester, 'installmentAmount', '250.00');
        await enter(tester, 'firstDue', '2026-05-01');
        await enter(tester, 'installmentCount', '4');
        await pick(tester, 'verified', 'true');
        await localTap(tester, submit());
        expect(find.textContaining('Installment plan to save'), findsOneWidget);
        await localTap(tester, submit());
        final r = saved('installment');
        expect(
          r.values['schedule'],
          'Installment 1,2026-05-01,250.00\n'
          'Installment 2,2026-06-01,250.00\n'
          'Installment 3,2026-07-01,250.00\n'
          'Installment 4,2026-08-01,250.00',
        );
        expect(r.amount, BigInt.from(100000));
        for (final key in const [
          'frequency',
          'firstDue',
          'splitMode',
          'installmentAmount',
          'installmentCount',
        ]) {
          expect(r.values.containsKey(key), isFalse, reason: key);
        }
      } finally {
        await close(tester);
      }
    });

    testWidgets('a purchase can use up a pending charge', (tester) async {
      await open(tester);
      try {
        final id = await card(tester);
        final hold = await book(tester, 'cardAuthorization', {
          'name': 'Hotel hold',
          'date': '2026-03-01',
          'card': id,
          'amount': '500.00',
          'reference': 'Ref',
        });
        await tester.pumpWidget(
          MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: SalapiyaTheme.build(
              Brightness.light,
              platform: TargetPlatform.windows,
            ),
            home: FinancialEnvironment(
              production: true,
              child: MoneyEditor(
                controller: c,
                action: FinancialAction.expense,
                initial: {'funding': 'card', 'card': id},
              ),
            ),
          ),
        );
        await localSettle(tester);
        await enter(tester, 'name', 'Hotel');
        await enter(tester, 'amount', '500.00');
        await enter(tester, 'date', '2026-03-02');
        await enter(tester, 'postingDate', '2026-03-02');
        await localTap(tester, find.text('More details').first);
        await pick(tester, 'authorization', hold);
        await save(tester);
        expect(saved('cardPurchase').values['authorization'], hold);
        expect(saved('cardPurchase').source, hold);
      } finally {
        await close(tester);
      }
    });

    testWidgets('different amounts keep the typed rows', (tester) async {
      await open(tester);
      try {
        final id = await card(tester);
        final bought = await purchase(tester, id);
        await form(tester, 'installment', initial: {'card': id});
        await pick(tester, 'purchase', bought);
        await pick(tester, 'splitMode', 'varied');
        expect(field('installmentAmount'), findsNothing);
        const rows = 'First,2026-05-01,300.00\nSecond,2026-06-01,700.00';
        await enter(tester, 'schedule', rows);
        await pick(tester, 'verified', 'true');
        await save(tester);
        expect(saved('installment').values['schedule'], rows);
      } finally {
        await close(tester);
      }
    });
  });

  group('Planning', () {
    testWidgets('a budget’s last day is stored once, as the exclusive end', (
      tester,
    ) async {
      await open(tester);
      try {
        await form(tester, 'budget');
        expect(tester.widget<DateField>(field('lastDay')).label, 'Last day');
        expect(find.textContaining('xclusive'), findsNothing);
        expect(field('status'), findsNothing);
        await enter(tester, 'name', 'Food');
        await pick(tester, 'category', 'category-food');
        await enter(tester, 'amount', '900.00');
        await enter(tester, 'start', '2026-10-01');
        await enter(tester, 'lastDay', '2026-10-31');
        await save(tester);
        final r = saved('budget');
        expect(r.values['endExclusive'], '2026-11-01');
        expect(r.values.containsKey('lastDay'), isFalse);
        expect(r.values['basis'], 'net');
      } finally {
        await close(tester);
      }
    });

    testWidgets('an overlapping budget shows on First day', (tester) async {
      await open(tester);
      try {
        await book(tester, 'budget', {
          'name': 'Food',
          'date': '2026-10-01',
          'amount': '900.00',
          'category': 'category-food',
          'start': '2026-10-01',
          'endExclusive': '2026-11-01',
          'basis': 'net',
          'status': 'active',
        });
        await form(tester, 'budget');
        await enter(tester, 'name', 'Food again');
        await pick(tester, 'category', 'category-food');
        await enter(tester, 'amount', '100.00');
        await enter(tester, 'start', '2026-10-05');
        await enter(tester, 'lastDay', '2026-10-20');
        await localTap(tester, submit());
        expect(errorOn(tester, 'start'), isNotNull);
      } finally {
        await close(tester);
      }
    });

    testWidgets('a budget’s dates in the wrong order show on Last day', (
      tester,
    ) async {
      await open(tester);
      try {
        await form(tester, 'budget');
        await enter(tester, 'name', 'Food');
        await pick(tester, 'category', 'category-food');
        await enter(tester, 'amount', '100.00');
        await enter(tester, 'start', '2026-10-05');
        await enter(tester, 'lastDay', '2026-10-01');
        await localTap(tester, submit());
        expect(errorOn(tester, 'lastDay'), isNotNull);
      } finally {
        await close(tester);
      }
    });

    testWidgets('archiving sets the status over the record’s own', (
      tester,
    ) async {
      await open(tester);
      try {
        final id = await book(tester, 'budget', {
          'name': 'Food',
          'date': '2026-10-01',
          'amount': '900.00',
          'category': 'category-food',
          'start': '2026-10-01',
          'endExclusive': '2026-11-01',
          'basis': 'net',
          'status': 'active',
        });
        await form(
          tester,
          'financeCorrection',
          replacing: c.snapshot.revision(id),
          overrides: const {'status': 'archived'},
        );
        expect(pickerOf(tester, 'status').value, 'archived');
        expect(
          tester.widget<DateField>(field('lastDay')).value,
          DateTime.parse('2026-10-31'),
        );
        await enter(tester, 'reason', 'Done with it');
        await save(tester);
        final r = saved('budget');
        expect(r.values['status'], 'archived');
        expect(r.values['endExclusive'], '2026-11-01');
        expect(r.number, 2);
      } finally {
        await close(tester);
      }
    });

    testWidgets('Set money aside says what’s free, and keeps the command', (
      tester,
    ) async {
      await open(tester);
      try {
        final goal = await book(tester, 'savingsGoal', {
          'name': 'Trip',
          'date': '2026-02-01',
          'amount': '1000.00',
          'targetDate': '',
          'status': 'active',
        });
        await form(tester, 'reservation', initial: {'goal': goal});
        await pick(tester, 'account', bank);
        expect(find.textContaining('Not set aside yet'), findsOneWidget);
        await enter(tester, 'amount', '200.00');
        await save(tester);
        final r = saved('reservation');
        expect(r.title, 'Set aside · Trip');
        expect(r.values['delta'], '20000');
      } finally {
        await close(tester);
      }
    });

    testWidgets('more than the account holds shows on the amount', (
      tester,
    ) async {
      await open(tester);
      try {
        final goal = await book(tester, 'savingsGoal', {
          'name': 'Trip',
          'date': '2026-02-01',
          'amount': '1000.00',
          'targetDate': '',
          'status': 'active',
        });
        await form(tester, 'reservation', initial: {'goal': goal});
        await pick(tester, 'account', bank);
        await enter(tester, 'amount', '9000.00');
        await localTap(tester, submit());
        expect(errorOn(tester, 'amount'), isNotNull);
      } finally {
        await close(tester);
      }
    });

    testWidgets('saving a recurring item adds its next 90 days', (
      tester,
    ) async {
      await open(tester);
      try {
        await form(tester, 'recurrence');
        await enter(tester, 'name', 'Rent');
        await enter(tester, 'amount', '8000.00');
        await enter(tester, 'monthDay', '5');
        await enter(tester, 'start', civilToday());
        await localTap(tester, submit());
        expect(find.textContaining('next 90 days'), findsOneWidget);
        await localTap(tester, submit());
        expect(find.text('Dates added'), findsOneWidget);
        final dates = saved('recurrenceGenerate');
        expect(dates.values['rule'], saved('recurrence').id);
        expect(dates.values['from'], civilToday());
        expect(dates.title, 'Rent dates');
      } finally {
        await close(tester);
      }
    });

    testWidgets('if the dates can’t be added, the item stays saved', (
      tester,
    ) async {
      await open(tester);
      try {
        await form(tester, 'recurrence');
        await enter(tester, 'name', 'Far away');
        await enter(tester, 'amount', '100.00');
        await enter(tester, 'start', '2199-12-15');
        await localTap(tester, submit());
        await localTap(tester, submit());
        expect(find.text('Dates not added'), findsOneWidget);
        expect(find.textContaining('Add to Upcoming'), findsOneWidget);
        expect(saved('recurrence').title, 'Far away');
        expect(
          c.snapshot.current.where(
            (r) => financeType(r) == 'recurrenceGenerate',
          ),
          isEmpty,
        );
      } finally {
        await close(tester);
      }
    });

    testWidgets('weekdays are chosen, not typed', (tester) async {
      await open(tester);
      try {
        await form(tester, 'recurrence');
        expect(find.text('On these days'), findsNothing);
        await pick(tester, 'frequency', 'weekly');
        expect(field('monthDay'), findsNothing);
        // Monday is already on.
        await tester.tap(find.byKey(const ValueKey('native-weekday-3')));
        await tester.pump();
        await enter(tester, 'name', 'Class');
        await enter(tester, 'amount', '100.00');
        await enter(tester, 'start', civilToday());
        await save(tester);
        expect(saved('recurrence').values['weekdays'], '1,3');
      } finally {
        await close(tester);
      }
    });

    testWidgets('no weekday shows on the days', (tester) async {
      await open(tester);
      try {
        await form(tester, 'recurrence');
        await pick(tester, 'frequency', 'weekly');
        await tester.tap(find.byKey(const ValueKey('native-weekday-1')));
        await tester.pump();
        await enter(tester, 'name', 'Class');
        await enter(tester, 'amount', '100.00');
        await localTap(tester, submit());
        expect(find.text('Choose at least one day of the week.'), findsOneWidget);
      } finally {
        await close(tester);
      }
    });

    testWidgets('changing a date offers only saved dates, and fills them', (
      tester,
    ) async {
      await open(tester);
      try {
        final rule = await book(tester, 'recurrence', {
          'name': 'Rent',
          'date': '2026-01-05',
          'recurringKind': 'bill',
          'amount': '500.00',
          'frequency': 'monthly',
          'interval': '1',
          'weekdays': '1',
          'monthDay': '20',
          'monthPolicy': 'last_valid_day',
          'start': '2026-01-05',
          'end': '',
          'count': '',
          'timezone': 'Asia/Manila',
          'account': '',
          'status': 'active',
        });
        await book(tester, 'recurrenceGenerate', {
          'name': 'Rent dates',
          'date': '2026-10-01',
          'rule': rule,
          'from': '2026-10-01',
          'through': '2026-11-30',
        });
        await form(tester, 'occurrenceOverride', initial: {'rule': rule});
        expect(pickerOf(tester, 'logicalDate').options, hasLength(2));
        await pick(tester, 'logicalDate', '2026-10-20');
        expect(
          tester.widget<AmountField>(field('amount')).controller.text,
          '500.00',
        );
        await pick(tester, 'state', 'skipped');
        expect(field('due'), findsNothing);
        await enter(tester, 'reason', 'Paused');
        await save(tester);
        final r = saved('occurrenceOverride');
        expect(r.values['state'], 'skipped');
        expect(r.values['due'], '2026-10-20');
        expect(r.values['logicalDate'], '2026-10-20');
      } finally {
        await close(tester);
      }
    });
  });
}
