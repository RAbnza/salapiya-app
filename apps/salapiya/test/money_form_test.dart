import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/finance/contracts/financial_models.dart';
import 'package:salapiya/features/finance/presentation/financial_widgets.dart';
import 'package:salapiya/finance/money_details.dart';
import 'package:salapiya/finance/money_editor.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_finance_controller.dart';
import 'package:salapiya/local/local_store.dart';

import 'local_money_journey.dart' show localSettle, localTap;
import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

const windows = TargetPlatform.windows, android = TargetPlatform.android;

/// Lets helpers outside a test body reach the store on real time.
late Future<void> Function(Future<void> Function()) realAsync;

void main() {
  Future<(LocalFixture, LocalFinancialController, String, String)> open(
    WidgetTester tester,
  ) async {
    final f = (await tester.runAsync(LocalFixture.open))!;
    late LocalFinancialController c;
    late String wallet, bank;
    await tester.runAsync(() async {
      wallet = await f.account('Wallet', '500.00', '2026-01-01');
      bank = await f.account('Bank', '5000.00', '2026-01-01');
      c = LocalFinancialController(f.store, await f.store.snapshot());
      await c.reload();
    });
    realAsync = tester.runAsync;
    return (f, c, wallet, bank);
  }

  Widget app(
    LocalFinancialController c,
    FinancialAction action, {
    String? sourceId,
    Map<String, String>? initial,
    TargetPlatform platform = windows,
  }) => MaterialApp(
    themeAnimationDuration: Duration.zero,
    theme: SalapiyaTheme.build(Brightness.light, platform: platform),
    home: FinancialEnvironment(
      production: true,
      child: MoneyEditor(
        controller: c,
        action: action,
        sourceId: sourceId,
        initial: initial,
      ),
    ),
  );

  Future<void> close(
    WidgetTester tester,
    LocalFixture f,
    LocalFinancialController c,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    await closeWithWidgetClock(tester, f.close);
  }

  void sized(WidgetTester tester, [double width = 900]) {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Finder submit() => find.byKey(const ValueKey('native-submit'));

  Future<void> enter(WidgetTester tester, String key, String value) async {
    final field = find.byKey(ValueKey('native-$key'));
    await tester.ensureVisible(field);
    await tester.pump();
    final widget = tester.widget(field);
    if (widget is DateField) {
      widget.onChanged!(DateTime.parse(value));
      await tester.pump();
      return;
    }
    final editable = find.descendant(
      of: field,
      matching: find.byType(EditableText),
    );
    tester
        .state<EditableTextState>(editable)
        .updateEditingValue(
          TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          ),
        );
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await localTap(tester, submit());
    expect(find.textContaining('Step 2 of 2'), findsOneWidget);
    await localTap(tester, submit());
    expect(find.text('Saved securely on this device.'), findsOneWidget);
  }

  /// The saved record kept every value the form started from: nothing it
  /// doesn't show is lost or changed, and what it does show is what was typed.
  void kept(
    LocalFinancialController c,
    LocalRevision r,
    Map<String, String> before,
    Map<String, String> typed,
  ) {
    final expected = {...before, ...typed};
    for (final e in expected.entries) {
      // The rules fill in a blank description.
      if (e.key == 'name' && e.value.isEmpty) continue;
      expect(r.values[e.key], e.value, reason: e.key);
    }
  }

  String? fieldError(WidgetTester tester, String key) {
    final field = tester.widget(find.byKey(ValueKey('native-$key')));
    return switch (field) {
      AmountField(:final errorText) => errorText,
      HelpTextField(:final errorText) => errorText,
      DateField(:final errorText) => errorText,
      OptionPicker<String>(:final errorText) => errorText,
      _ => null,
    };
  }

  group('command values', () {
    testWidgets('Log expense', (tester) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        final before = c.defaults(FinancialAction.expense);
        await tester.pumpWidget(
          app(c, FinancialAction.expense, initial: {'account': wallet}),
        );
        await localSettle(tester);
        await enter(tester, 'amount', '120.50');
        await enter(tester, 'name', 'Lunch');
        await enter(tester, 'date', '2026-10-21');
        await save(tester);
        final r = c.snapshot.current.singleWhere((r) => r.kind == 'expense');
        kept(c, r, before, {
          'account': wallet,
          'amount': '120.50',
          'name': 'Lunch',
          'date': '2026-10-21',
        });
        expect(r.amount, BigInt.from(12050));
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('Log income', (tester) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        final before = c.defaults(FinancialAction.income);
        await tester.pumpWidget(
          app(c, FinancialAction.income, initial: {'account': wallet}),
        );
        await localSettle(tester);
        await enter(tester, 'amount', '100.01');
        await enter(tester, 'name', 'Gift');
        await enter(tester, 'date', '2026-10-21');
        await save(tester);
        kept(
          c,
          c.snapshot.current.singleWhere((r) => r.kind == 'income'),
          before,
          {'amount': '100.01', 'name': 'Gift', 'date': '2026-10-21'},
        );
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('Log a transfer, with a fee', (tester) async {
      sized(tester);
      final (f, c, _, _) = await open(tester);
      try {
        final before = c.defaults(FinancialAction.transfer);
        await tester.pumpWidget(app(c, FinancialAction.transfer));
        await localSettle(tester);
        await enter(tester, 'amount', '100.00');
        await enter(tester, 'fee', '10.00');
        await enter(tester, 'date', '2026-10-21');
        await save(tester);
        kept(
          c,
          c.snapshot.current.singleWhere((r) => r.kind == 'transfer'),
          before,
          {'amount': '100.00', 'fee': '10.00', 'date': '2026-10-21'},
        );
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('Add account', (tester) async {
      sized(tester);
      final (f, c, _, _) = await open(tester);
      try {
        await tester.pumpWidget(app(c, FinancialAction.account));
        await localSettle(tester);
        await enter(tester, 'name', 'Savings box');
        await enter(tester, 'amount', '75.00');
        await enter(tester, 'cutoff', '2026-10-14');
        await save(tester);
        final a = c.snapshot.accounts.singleWhere(
          (a) => a.name == 'Savings box',
        );
        expect(a.cutoff, '2026-10-14');
        expect(c.snapshot.balance(a.id), BigInt.from(7500));
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('Add category', (tester) async {
      sized(tester);
      final (f, c, _, _) = await open(tester);
      try {
        await tester.pumpWidget(app(c, FinancialAction.category));
        await localSettle(tester);
        await enter(tester, 'name', 'Everyday extras');
        await save(tester);
        expect(
          c.snapshot.categories
              .singleWhere((x) => x.name == 'Everyday extras')
              .kind,
          'expense',
        );
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('Adjust account balance is signed', (tester) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        await tester.pumpWidget(
          app(
            c,
            FinancialAction.reconcile,
            initial: {'account': wallet, 'mode': 'manual'},
          ),
        );
        await localSettle(tester);
        await enter(tester, 'amount', '-0.01');
        await enter(tester, 'date', '2026-10-21');
        await enter(tester, 'reason', 'One cent');
        await save(tester);
        final r = c.snapshot.current.singleWhere((r) => r.kind == 'adjustment');
        expect(r.values['mode'], 'manual');
        expect(c.snapshot.balance(wallet), BigInt.from(49999));
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('Correct transaction keeps the record\'s other values', (
      tester,
    ) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        late String id;
        await tester.runAsync(() async {
          id = await f.post('expense', {
            'name': 'Taxi',
            'account': wallet,
            'amount': '320.00',
            'category': 'category-transport',
            'merchant': 'Grab',
          });
          await c.reload();
        });
        final before = c.defaults(FinancialAction.correction, sourceId: id);
        await tester.pumpWidget(
          app(c, FinancialAction.correction, sourceId: id),
        );
        await localSettle(tester);
        await enter(tester, 'amount', '230.00');
        await enter(tester, 'reason', 'Wrong fare');
        await save(tester);
        final r = c.snapshot.current.singleWhere((r) => r.kind == 'expense');
        expect(r.previous, id);
        expect(r.values['merchant'], 'Grab');
        kept(c, r, before, {'amount': '230.00', 'reason': 'Wrong fare'});
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('Reverse transaction asks only why', (tester) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        late String id;
        await tester.runAsync(() async {
          id = await f.post('expense', {
            'name': 'Beans',
            'account': wallet,
            'amount': '50.00',
            'category': 'category-food',
          });
          await c.reload();
        });
        await tester.pumpWidget(app(c, FinancialAction.reversal, sourceId: id));
        await localSettle(tester);
        expect(find.byType(DateField), findsNothing);
        expect(find.byType(AmountField), findsNothing);
        await enter(tester, 'reason', 'Twice');
        await save(tester);
        expect(c.snapshot.balance(wallet), BigInt.from(50000));
        expect(c.snapshot.revisions.last.change, 'reverse');
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('an opening correction offers no date to get wrong', (
      tester,
    ) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        final opening = c.snapshot.current.firstWhere(
          (r) => r.kind == 'opening' && r.title.endsWith('Wallet'),
        );
        await tester.pumpWidget(
          app(c, FinancialAction.correction, sourceId: opening.id),
        );
        await localSettle(tester);
        expect(find.byType(DateField), findsNothing);
        await enter(tester, 'amount', '600.00');
        await enter(tester, 'reason', 'Counted again');
        await save(tester);
        expect(c.snapshot.balance(wallet), BigInt.from(60000));
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('Check balance, then Adjust balance to match', (tester) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        await tester.pumpWidget(
          app(c, FinancialAction.reconcile, initial: {'account': wallet}),
        );
        await localSettle(tester);
        await enter(tester, 'amount', '450.00');
        await enter(tester, 'date', '2026-10-21');
        await save(tester);
        expect(c.snapshot.balance(wallet), BigInt.from(50000));
        final check = c.snapshot.current.singleWhere(
          (r) => r.kind == 'reconcile',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          app(c, FinancialAction.reconcile, sourceId: check.id),
        );
        await localSettle(tester);
        expect(find.byType(DateField), findsNothing);
        await enter(tester, 'reason', 'Counted');
        await save(tester);
        expect(c.snapshot.balance(wallet), BigInt.from(45000));
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('Log a refund on an expense', (tester) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        late String id;
        await tester.runAsync(() async {
          id = await f.post('expense', {
            'name': 'Shoes',
            'account': wallet,
            'amount': '100.00',
            'category': 'category-other',
          });
          await c.reload();
        });
        await tester.pumpWidget(app(c, FinancialAction.refund, sourceId: id));
        await localSettle(tester);
        await enter(tester, 'amount', '40.00');
        await enter(tester, 'date', '2026-10-22');
        await enter(tester, 'reason', 'Returned');
        await save(tester);
        expect(c.snapshot.current.last.kind, 'refund');
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('Archive account', (tester) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        await tester.pumpWidget(
          app(c, FinancialAction.archive, initial: {'account': wallet}),
        );
        await localSettle(tester);
        await enter(tester, 'reason', 'Closed it');
        await save(tester);
        expect(c.snapshot.account(wallet).archived, isTrue);
      } finally {
        await close(tester, f, c);
      }
    });
  });

  group('errors go on their field', () {
    testWidgets('empty essentials say what to enter', (tester) async {
      sized(tester);
      final (f, c, _, _) = await open(tester);
      try {
        await tester.pumpWidget(app(c, FinancialAction.expense));
        await localSettle(tester);
        await localTap(tester, submit());
        expect(fieldError(tester, 'amount'), isNotNull);
        expect(find.textContaining('Enter amount'), findsNothing);
        await enter(tester, 'amount', '10.00');
        await localTap(tester, submit());
        expect(fieldError(tester, 'name'), 'Enter a description.');
        expect(find.textContaining('Step 1 of 2'), findsOneWidget);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('a duplicate name marks the name', (tester) async {
      sized(tester);
      final (f, c, _, _) = await open(tester);
      try {
        await tester.pumpWidget(app(c, FinancialAction.account));
        await localSettle(tester);
        await enter(tester, 'name', 'Wallet');
        await enter(tester, 'cutoff', '2026-10-14');
        await localTap(tester, submit());
        expect(
          fieldError(tester, 'name'),
          'You already have an account with this name.',
        );
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('a date before the opening balance marks the date', (
      tester,
    ) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        await tester.pumpWidget(
          app(c, FinancialAction.expense, initial: {'account': wallet}),
        );
        await localSettle(tester);
        await enter(tester, 'amount', '10.00');
        await enter(tester, 'name', 'Old');
        await enter(tester, 'date', '2025-12-01');
        await localTap(tester, submit());
        expect(
          fieldError(tester, 'date'),
          'Choose a date after 1 Jan 2026. Wallet’s balance starts from that day.',
        );
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('moving money to the same account marks To', (tester) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        await tester.pumpWidget(
          app(
            c,
            FinancialAction.transfer,
            initial: {'account': wallet, 'destination': wallet},
          ),
        );
        await localSettle(tester);
        await enter(tester, 'amount', '10.00');
        await localTap(tester, submit());
        expect(
          fieldError(tester, 'select-destination'),
          'Choose a different account.',
        );
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('not enough money marks the account and says what it holds', (
      tester,
    ) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        await tester.pumpWidget(
          app(c, FinancialAction.expense, initial: {'account': wallet}),
        );
        await localSettle(tester);
        expect(
          find.textContaining('takes the account below zero'),
          findsNothing,
        );
        await enter(tester, 'amount', '900.00');
        await enter(tester, 'name', 'Too much');
        await enter(tester, 'date', '2026-10-21');
        expect(find.textContaining('this takes it below zero'), findsOneWidget);
        await localTap(tester, submit());
        expect(
          fieldError(tester, 'select-account'),
          'This takes Wallet below zero. It has ₱500.00.',
        );
        expect(find.text('That is right'), findsOneWidget);
        await localTap(tester, find.text('That is right'));
        await save(tester);
        expect(c.snapshot.balance(wallet), -BigInt.from(40000));
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('it marks the fee account when that is the one short', (
      tester,
    ) async {
      sized(tester);
      final (f, c, wallet, bank) = await open(tester);
      try {
        late String spare;
        await tester.runAsync(() async {
          spare = await f.account('Spare', '100.00', '2026-01-01');
          await c.reload();
        });
        await tester.pumpWidget(
          app(
            c,
            FinancialAction.transfer,
            initial: {
              'account': bank,
              'destination': spare,
              'feeTreatment': 'separate',
              'feeAccount': wallet,
              'fee': '900.00',
              'date': '2026-10-21',
            },
          ),
        );
        await localSettle(tester);
        await enter(tester, 'amount', '10.00');
        await localTap(tester, submit());
        expect(
          find.byKey(const ValueKey('native-select-acknowledge')),
          findsOneWidget,
        );
        // The problem is under More details, which opens by itself.
        expect(
          fieldError(tester, 'select-feeAccount'),
          contains('takes Wallet below zero'),
        );
        expect(fieldError(tester, 'select-account'), isNull);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('a refund over what is left says how much is left', (
      tester,
    ) async {
      sized(tester);
      final (f, c, _, bank) = await open(tester);
      try {
        late String id;
        await tester.runAsync(() async {
          id = await f.post('expense', {
            'name': 'Sofa',
            'account': bank,
            'amount': '1500.00',
            'category': 'category-other',
          });
          await c.reload();
        });
        await tester.pumpWidget(app(c, FinancialAction.refund, sourceId: id));
        await localSettle(tester);
        await enter(tester, 'amount', '2000.00');
        await enter(tester, 'date', '2026-10-22');
        await enter(tester, 'reason', 'Returned');
        await localTap(tester, submit());
        expect(
          fieldError(tester, 'select-refundPosting'),
          'That’s more than is left to refund here. ₱1,500.00 is left.',
        );
        // With Hide amounts on, it says the same without the amount.
        c.privacyHidden = () => true;
        await localTap(tester, submit());
        expect(
          fieldError(tester, 'select-refundPosting'),
          'That’s more than is left to refund here.',
        );
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('splits and withheld fees say what to fix, on their field', (
      tester,
    ) async {
      sized(tester);
      final (f, c, wallet, bank) = await open(tester);
      try {
        await tester.pumpWidget(
          app(
            c,
            FinancialAction.expense,
            initial: {
              'account': wallet,
              'name': 'Groceries',
              'date': '2026-10-21',
              'split': 'true',
              'splitAmount': '100.00',
            },
          ),
        );
        await localSettle(tester);
        await enter(tester, 'amount', '100.00');
        await localTap(tester, submit());
        expect(
          fieldError(tester, 'splitAmount'),
          startsWith('Each split must be more than zero'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          app(
            c,
            FinancialAction.transfer,
            initial: {
              'account': bank,
              'destination': wallet,
              'date': '2026-10-21',
              'fee': '5.00',
              'feeTreatment': 'withheld',
              'feeDate': '2026-10-22',
            },
          ),
        );
        await localSettle(tester);
        await enter(tester, 'amount', '100.00');
        await localTap(tester, submit());
        expect(
          fieldError(tester, 'feeDate'),
          'A fee taken out of the amount has to use the transfer date.',
        );
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('a problem no field can show sits above the form', (
      tester,
    ) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        late String id;
        await tester.runAsync(() async {
          id = await f.post('expense', {
            'name': 'Shoes',
            'account': wallet,
            'amount': '100.00',
            'category': 'category-other',
          });
          await f.post('refund', {
            'name': '',
            'source': id,
            'sourceVersion': '1',
            'amount': '10.00',
            'account': wallet,
            'reason': 'Returned',
            'refundPosting': '$id-p2',
          });
          await c.reload();
        });
        await tester.pumpWidget(app(c, FinancialAction.reversal, sourceId: id));
        await localSettle(tester);
        await enter(tester, 'reason', 'Twice');
        await localTap(tester, submit());
        expect(
          find.text(
            'This record has a refund or an adjustment. Reverse that first.',
          ),
          findsOneWidget,
        );
        expect(find.byType(InlineNotice), findsWidgets);
      } finally {
        await close(tester, f, c);
      }
    });
  });

  group('input', () {
    testWidgets('only the two signed amounts take a minus', (tester) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        await tester.pumpWidget(app(c, FinancialAction.expense));
        await localSettle(tester);
        await enter(tester, 'amount', '-5.00');
        expect(
          tester
              .widget<AmountField>(find.byKey(const ValueKey('native-amount')))
              .controller
              .text,
          isNot(startsWith('-')),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          app(c, FinancialAction.reconcile, initial: {'account': wallet}),
        );
        await localSettle(tester);
        await enter(tester, 'amount', '-5.00');
        expect(
          tester
              .widget<AmountField>(find.byKey(const ValueKey('native-amount')))
              .controller
              .text,
          '-5.00',
        );
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('the balance under an account respects Hide amounts', (
      tester,
    ) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        c.privacyHidden = () => true;
        late String id;
        await tester.runAsync(() async {
          id = await f.post('expense', {
            'name': 'Shoes',
            'account': wallet,
            'amount': '100.00',
            'category': 'category-other',
          });
          await c.reload();
        });
        await tester.pumpWidget(app(c, FinancialAction.refund, sourceId: id));
        await localSettle(tester);
        expect(find.textContaining('₱100.00'), findsNothing);
        expect(find.textContaining('₱500.00'), findsNothing);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('card fields show only when a card exists', (tester) async {
      sized(tester);
      final (f, c, _, _) = await open(tester);
      try {
        await tester.pumpWidget(app(c, FinancialAction.expense));
        await localSettle(tester);
        expect(
          find.byKey(const ValueKey('native-select-funding')),
          findsNothing,
        );
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('the form fits a phone at 200% text', (tester) async {
      sized(tester, 320);
      final (f, c, _, _) = await open(tester);
      try {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 2400),
              textScaler: TextScaler.linear(2),
            ),
            child: app(c, FinancialAction.transfer, platform: android),
          ),
        );
        await localSettle(tester);
        expect(tester.takeException(), isNull);
      } finally {
        await close(tester, f, c);
      }
    });
  });

  group('changes that need the latest records', () {
    Future<void> connect(LocalFixture f, LocalFinancialController c) =>
        realAsync(() async {
          await f.store.stageConnection(
            newLocalId(),
            'synthetic@example.test',
            newLocalId(),
          );
          await f.store.db.execute(
            "UPDATE connected_profile SET phase='connected'",
          );
          await c.reload();
        });

    Future<String> purchase(
      WidgetTester tester,
      LocalFixture f,
      LocalFinancialController c,
      String wallet,
    ) async {
      late String id;
      await tester.runAsync(() async {
        id = await f.post('expense', {
          'name': 'Taxi',
          'account': wallet,
          'amount': '320.00',
          'category': 'category-transport',
        });
        await c.reload();
      });
      return id;
    }

    testWidgets('with no connection a correction stays on Review', (
      tester,
    ) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        final id = await purchase(tester, f, c, wallet);
        await connect(f, c);
        var syncs = 0;
        c.syncLatest = () async => syncs++;
        await tester.pumpWidget(
          app(c, FinancialAction.correction, sourceId: id),
        );
        await localSettle(tester);
        await enter(tester, 'amount', '230.00');
        await enter(tester, 'reason', 'Wrong fare');
        await localTap(tester, submit());
        expect(
          find.text(
            'Saving this checks your latest records first, so it needs a connection.',
          ),
          findsOneWidget,
        );
        await localTap(tester, submit());
        expect(syncs, 1);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Couldn’t check your latest records'), findsOneWidget);
        expect(find.textContaining('Sync now before'), findsNothing);
        expect(find.textContaining('Step 2 of 2'), findsOneWidget);
        expect(find.text('Sync and save'), findsOneWidget);
        expect(
          c.snapshot.current.singleWhere((r) => r.kind == 'expense').amount,
          BigInt.from(32000),
        );
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('a sync that brings new records asks for another look', (
      tester,
    ) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        final id = await purchase(tester, f, c, wallet);
        await tester.pumpWidget(app(c, FinancialAction.reversal, sourceId: id));
        await localSettle(tester);
        await enter(tester, 'reason', 'Twice');
        await localTap(tester, submit());
        c.connected = true;
        c.syncLatest = () => f.post('expense', {
          'account': wallet,
          'name': 'From another device',
          'amount': '10.00',
          'category': 'category-food',
        });
        await localTap(tester, submit());
        expect(find.text('Your records changed'), findsOneWidget);
        expect(c.snapshot.revisions.any((r) => r.change == 'reverse'), isFalse);
        await localTap(tester, submit());
        expect(c.snapshot.revisions.any((r) => r.change == 'reverse'), isTrue);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('a sync with nothing new saves straight away', (tester) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        final id = await purchase(tester, f, c, wallet);
        await tester.pumpWidget(app(c, FinancialAction.reversal, sourceId: id));
        await localSettle(tester);
        await enter(tester, 'reason', 'Twice');
        await localTap(tester, submit());
        var syncs = 0;
        c.connected = true;
        c.syncLatest = () async => syncs++;
        await localTap(tester, submit());
        expect(syncs, 1);
        expect(c.snapshot.revisions.any((r) => r.change == 'reverse'), isTrue);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('an ordinary expense never waits for a sync', (tester) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        await tester.pumpWidget(
          app(c, FinancialAction.expense, initial: {'account': wallet}),
        );
        await localSettle(tester);
        await enter(tester, 'amount', '10.00');
        await enter(tester, 'name', 'Lunch');
        await enter(tester, 'date', '2026-10-21');
        await localTap(tester, submit());
        var syncs = 0;
        c.connected = true;
        c.syncLatest = () async => syncs++;
        await localTap(tester, submit());
        expect(syncs, 0);
        expect(c.snapshot.current.any((r) => r.title == 'Lunch'), isTrue);
      } finally {
        await close(tester, f, c);
      }
    });
  });

  group('drafts', () {
    testWidgets('a draft saved by the old form still opens', (tester) async {
      sized(tester);
      final (f, c, wallet, _) = await open(tester);
      try {
        await tester.runAsync(
          () => c.retainDraft(
            'expense:',
            'a' * 8 + '-0000-4000-8000-000000000000',
            {
              ...c.defaults(FinancialAction.expense),
              'account': wallet,
              'name': 'Half typed',
              'amount': '12.00',
            },
          ),
        );
        await tester.pumpWidget(app(c, FinancialAction.expense));
        await localSettle(tester);
        expect(find.textContaining('Your draft is back'), findsOneWidget);
        expect(
          tester
              .widget<AmountField>(find.byKey(const ValueKey('native-amount')))
              .controller
              .text,
          '12.00',
        );
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('leaving offers to keep or discard it', (tester) async {
      sized(tester);
      final (f, c, _, _) = await open(tester);
      try {
        await tester.pumpWidget(
          MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: SalapiyaTheme.build(Brightness.light, platform: windows),
            home: FinancialEnvironment(
              production: true,
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MoneyEditor(
                        controller: c,
                        action: FinancialAction.expense,
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await localSettle(tester);
        await enter(tester, 'name', 'Half typed');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump();
        await tester.binding.handlePopRoute();
        await localSettle(tester);
        expect(find.text('Discard draft'), findsOneWidget);
        await tester.tap(find.text('Discard draft'));
        await localSettle(tester);
        expect(await tester.runAsync(() => c.store.drafts()), isEmpty);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('Saved drafts names each draft and opens the newer forms', (
      tester,
    ) async {
      sized(tester);
      final (f, c, _, _) = await open(tester);
      try {
        await tester.runAsync(() async {
          await c.store.saveDraft('finance:debtPayment:', newLocalId(), {
            'name': 'Half a payment',
            'amount': '5.00',
          });
          await c.store.saveDraft('expense:', newLocalId(), {'name': 'Lunch'});
        });
        await tester.pumpWidget(
          MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: SalapiyaTheme.build(Brightness.light, platform: windows),
            home: FinancialEnvironment(
              production: true,
              child: SavedDraftsPage(controller: c),
            ),
          ),
        );
        await localSettle(tester);
        expect(find.text('Unavailable draft'), findsNothing);
        expect(find.text('Log a debt payment'), findsOneWidget);
        expect(find.text('Log expense'), findsOneWidget);
        await tester.tap(find.text('Log a debt payment'));
        await localSettle(tester);
        expect(find.textContaining('Step 1 of 2'), findsOneWidget);
        expect(
          tester
              .widget<AmountField>(find.byKey(const ValueKey('native-amount')))
              .controller
              .text,
          '5.00',
        );
      } finally {
        await close(tester, f, c);
      }
    });
  });
}
