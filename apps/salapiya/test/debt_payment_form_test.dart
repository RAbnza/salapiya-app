import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_data.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/finance/presentation/financial_widgets.dart';
import 'package:salapiya/finance/debt_data.dart';
import 'package:salapiya/finance/finance_screen.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_finance_controller.dart';
import 'package:salapiya/local/local_store.dart';

import 'local_money_journey.dart' show localSettle, localTap;
import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

String _offset(int days) =>
    DateTime.parse('${civilToday()}T00:00:00Z')
        .add(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);

/// Lets helpers outside a test body reach the store on real time.
late Future<void> Function(Future<void> Function()) realAsync;

void main() {
  /// A profile with an account and one debt of two payments.
  Future<(LocalFixture, LocalFinancialController, String)> open(
    WidgetTester tester, {
    String opening = '5000.00',
  }) async {
    final f = (await tester.runAsync(LocalFixture.open))!;
    late LocalFinancialController controller;
    late String debt;
    await tester.runAsync(() async {
      await f.account('Wallet', opening);
      debt = await f.post('debtImport', {
        'name': 'Phone loan',
        'lender': 'Lender',
        'debtType': 'installment_loan',
        'amount': '1000.00',
        'principal': '',
      });
      await f.post('debtSchedule', {
        'name': 'Phone schedule',
        'debt': debt,
        'schedule': 'one,${_offset(2)},400.00\ntwo,${_offset(32)},600.00',
        'verified': 'true',
        'reference': 'Letter',
      });
      controller = LocalFinancialController(f.store, await f.store.snapshot());
    });
    return (f, controller, debt);
  }

  Widget app(
    LocalFinancialController c,
    Map<String, String> initial, {
    TargetPlatform platform = TargetPlatform.windows,
  }) => MaterialApp(
    themeAnimationDuration: Duration.zero,
    theme: SalapiyaTheme.build(Brightness.light, platform: platform),
    home: FinancialEnvironment(
      production: true,
      child: NativeFinanceEditor(
        controller: c,
        operation: 'debtPayment',
        title: 'Log a debt payment',
        initial: initial,
      ),
    ),
  );

  Map<String, String> prefill(LocalFinancialController c) {
    final d = overviewDebtProgress(c.snapshot, civilToday()).single;
    return debtPaymentInitial(d);
  }

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

  Finder amountField() => find.descendant(
    of: find.byKey(const ValueKey('native-amount')),
    matching: find.byType(TextField),
  );

  LocalRevision payment(LocalFinancialController c) =>
      c.snapshot.current.where((r) => financeType(r) == 'debtPayment').single;

  testWidgets('a row proposes its payment; saving logs exactly that', (
    tester,
  ) async {
    sized(tester);
    final (f, c, _) = await open(tester);
    try {
      await tester.pumpWidget(app(c, prefill(c)));
      await localSettle(tester);
      expect(find.textContaining('Step 1 of 2'), findsOneWidget);
      expect(find.textContaining('goes to one'), findsOneWidget);
      await localTap(tester, submit());
      expect(find.textContaining('Step 2 of 2'), findsOneWidget);
      await localTap(tester, submit());
      final v = payment(c).values;
      expect(v['amount'], '400.00');
      expect(v['allocations'], 'one,400.00');
      expect(v['certainty'], 'confirmed_total');
      expect(v['reduction'], '400.00');
      expect(v['clearing'], '0.00');
      expect(v['unapplied'], '0.00');
      expect(v['name'], 'Payment · Phone loan');
      expect(v.containsKey('paymentRow'), isFalse);
      expect(v.containsKey('extraRows'), isFalse);
      final d = overviewDebtProgress(c.snapshot, civilToday()).single;
      expect(d.due.open.single.$1.id, 'two');
      expect(d.outstanding, BigInt.from(60000));
    } finally {
      await close(tester, f, c);
    }
  });

  testWidgets('more than what is left stays unapplied, and says so', (
    tester,
  ) async {
    sized(tester);
    final (f, c, _) = await open(tester);
    try {
      await tester.pumpWidget(app(c, prefill(c)));
      await localSettle(tester);
      await tester.enterText(amountField(), '500.00');
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('payment-preview'))).data,
        allOf(contains('goes to one'), contains('stays unapplied')),
      );
      await localTap(tester, submit());
      await localTap(tester, submit());
      final v = payment(c).values;
      expect(v['allocations'], 'one,400.00');
      expect(v['unapplied'], '100.00');
      expect(v['reduction'], '500.00');
    } finally {
      await close(tester, f, c);
    }
  });

  testWidgets('an unknown breakdown goes to clearing, tied to no due date', (
    tester,
  ) async {
    sized(tester);
    final (f, c, debt) = await open(tester);
    try {
      final record = c.snapshot.current.firstWhere((r) => r.actionId == debt);
      await tester.pumpWidget(app(c, {'debt': record.id}));
      await localSettle(tester);
      expect(
        tester
            .widget<OptionPicker<String>>(
              find.byKey(const ValueKey('native-select-certainty')),
            )
            .value,
        'unresolved',
      );
      await tester.enterText(amountField(), '250.00');
      await tester.pump();
      await localTap(tester, submit());
      await localTap(tester, submit());
      final v = payment(c).values;
      expect(v['clearing'], '250.00');
      expect(v['reduction'], '0.00');
      expect(v['allocations'], '');
      expect(v['unapplied'], '250.00');
      final d = overviewDebtProgress(c.snapshot, civilToday()).single;
      expect(d.clearing, BigInt.from(25000));
      expect(d.due.open, hasLength(2));
    } finally {
      await close(tester, f, c);
    }
  });

  testWidgets('a problem shows in place, with no popup', (tester) async {
    sized(tester);
    final (f, c, _) = await open(tester);
    try {
      await tester.pumpWidget(app(c, prefill(c)));
      await localSettle(tester);
      await tester.enterText(amountField(), '');
      await tester.pump();
      await localTap(tester, submit());
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Enter the amount you paid, like 2000.00.'),
        findsOneWidget,
      );
      expect(find.textContaining('Step 1 of 2'), findsOneWidget);
      expect(
        c.snapshot.current.where((r) => financeType(r) == 'debtPayment'),
        isEmpty,
      );
    } finally {
      await close(tester, f, c);
    }
  });

  testWidgets('fields look 40 on Android and keep a 48 hit area', (
    tester,
  ) async {
    sized(tester, 400);
    final (f, c, _) = await open(tester);
    try {
      await tester.pumpWidget(
        app(c, prefill(c), platform: TargetPlatform.android),
      );
      await localSettle(tester);
      expect(tester.getSize(amountField()).height, Space.target);
      final style = tester
          .widget<EditableText>(
            find.descendant(
              of: amountField(),
              matching: find.byType(EditableText),
            ),
          )
          .style;
      expect(style.fontSize, 14);
      expect(tester.getSize(submit()).height, Space.target);
      expect(
        tester
            .getSize(
              find
                  .descendant(of: submit(), matching: find.byType(Material))
                  .first,
            )
            .height,
        Space.formControl,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await close(tester, f, c);
    }
  });

  testWidgets('Windows controls stay 32 and values are 13', (tester) async {
    sized(tester);
    final (f, c, _) = await open(tester);
    try {
      await tester.pumpWidget(app(c, prefill(c)));
      await localSettle(tester);
      expect(tester.getSize(amountField()).height, Space.pointerTarget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: amountField(),
                matching: find.byType(EditableText),
              ),
            )
            .style
            .fontSize,
        13,
      );
      expect(tester.getSize(submit()).height, Space.pointerTarget);
    } finally {
      await close(tester, f, c);
    }
  });

  testWidgets('Use result fills the amount, and says when it rounded', (
    tester,
  ) async {
    sized(tester);
    final (f, c, _) = await open(tester);
    try {
      await tester.pumpWidget(app(c, prefill(c)));
      await localSettle(tester);
      await localTap(tester, find.byKey(const ValueKey('calculator-Amount')));
      await localTap(tester, find.byKey(const ValueKey('calc-C')));
      for (final key in ['1', '0', '0', '÷', '3', '=']) {
        await localTap(tester, find.byKey(ValueKey('calc-$key')));
      }
      await localTap(tester, find.byKey(const ValueKey('calculator-use')));
      expect(tester.widget<TextField>(amountField()).controller!.text, '33.33');
      expect(find.text(AmountField.roundedNote), findsOneWidget);
      await tester.enterText(amountField(), '40.00');
      await tester.pump();
      expect(find.text(AmountField.roundedNote), findsNothing);
    } finally {
      await close(tester, f, c);
    }
  });

  testWidgets('the title starts where the form starts', (tester) async {
    sized(tester, 1400);
    final (f, c, _) = await open(tester);
    try {
      await tester.pumpWidget(app(c, prefill(c)));
      await localSettle(tester);
      final title = tester.getTopLeft(find.text('Log a debt payment')).dx;
      final step = tester.getTopLeft(find.textContaining('Step 1 of 2')).dx;
      final card = tester.getTopLeft(find.byType(SurfaceCard)).dx;
      expect(title, card);
      expect(step, card);
      expect(
        tester.getSize(find.byType(SurfaceCard)).width,
        Space.formMaxWidth,
      );
    } finally {
      await close(tester, f, c);
    }
  });

  group('the other editors', () {
    Widget editor(
      LocalFinancialController c,
      String operation, {
      Map<String, String> initial = const {},
      TargetPlatform platform = TargetPlatform.windows,
    }) => MaterialApp(
      themeAnimationDuration: Duration.zero,
      theme: SalapiyaTheme.build(Brightness.light, platform: platform),
      home: FinancialEnvironment(
        production: true,
        child: NativeFinanceEditor(
          controller: c,
          operation: operation,
          title: 'Form',
          initial: initial,
        ),
      ),
    );

    testWidgets('a new loan asks only for what its use needs', (tester) async {
      sized(tester);
      final (f, c, _) = await open(tester);
      try {
        await tester.pumpWidget(editor(c, 'borrowing'));
        await localSettle(tester);
        expect(find.byKey(const ValueKey('native-select-account')), findsOne);
        expect(
          find.byKey(const ValueKey('native-select-category')),
          findsNothing,
        );
        await localTap(
          tester,
          find.byKey(const ValueKey('native-select-fundingUse')),
        );
        await localTap(tester, find.text('A purchase it paid for').last);
        expect(
          find.byKey(const ValueKey('native-select-account')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('native-select-category')), findsOne);
        expect(find.byKey(const ValueKey('native-withheld')), findsNothing);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('optional fields wait under More details', (tester) async {
      sized(tester);
      final (f, c, _) = await open(tester);
      try {
        await tester.pumpWidget(editor(c, 'debtImport'));
        await localSettle(tester);
        expect(find.byKey(const ValueKey('native-principal')), findsNothing);
        await localTap(tester, find.byKey(const ValueKey('form-more-details')));
        expect(find.byKey(const ValueKey('native-principal')), findsOneWidget);
        expect(find.byKey(const ValueKey('native-reference')), findsOneWidget);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('an early payoff fills the lender amount from the payoff', (
      tester,
    ) async {
      sized(tester);
      final (f, c, debt) = await open(tester);
      try {
        final record = c.snapshot.current.firstWhere((r) => r.actionId == debt);
        await tester.pumpWidget(
          editor(
            c,
            'debtPayoff',
            initial: {
              'debt': record.id,
              'amount': '1000.00',
              'reduction': '1000.00',
              'reference': 'Payoff letter',
              'reason': 'Paid early',
              'verified': 'true',
            },
          ),
        );
        await localSettle(tester);
        expect(find.text('What you owe now: ₱1,000.00'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('native-providerPayoff')),
          findsNothing,
        );
        await localTap(
          tester,
          find.byKey(const ValueKey('native-select-account')),
        );
        await localTap(tester, find.text('Wallet').last);
        await localTap(tester, find.byKey(const ValueKey('native-submit')));
        await localTap(tester, find.byKey(const ValueKey('native-submit')));
        final payoff = c.snapshot.current.singleWhere(
          (r) => financeType(r) == 'debtPayoff',
        );
        expect(payoff.values['providerPayoff'], '1000.00');
        expect(payoff.title, 'Payoff · Phone loan');
        expect(
          overviewDebtProgress(c.snapshot, civilToday()).single.closed,
          isTrue,
        );
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('not enough money marks the account, then asks to go on', (
      tester,
    ) async {
      sized(tester);
      final (f, c, _) = await open(tester, opening: '100.00');
      try {
        await tester.pumpWidget(app(c, prefill(c)));
        await localSettle(tester);
        final consent = find.byKey(const ValueKey('native-select-acknowledge'));
        expect(consent, findsNothing);
        // Warned before saving: the amount is more than the account holds.
        expect(find.textContaining('this takes it below zero'), findsOneWidget);

        await localTap(tester, submit());
        expect(find.byType(AlertDialog), findsNothing);
        const problem = 'This takes Wallet below zero. It has ₱100.00.';
        expect(find.text(problem), findsOneWidget);
        expect(
          tester
              .widget<OptionPicker<String>>(
                find.byKey(const ValueKey('native-select-account')),
              )
              .errorText,
          problem,
        );
        expect(find.textContaining('Step 1 of 2'), findsOneWidget);

        expect(consent, findsOneWidget);
        await localTap(tester, find.text('That is right'));
        expect(find.text(problem), findsNothing);
        await localTap(tester, submit());
        expect(find.textContaining('Step 2 of 2'), findsOneWidget);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('a Money form gets the same fields, with typed dates gone', (
      tester,
    ) async {
      sized(tester);
      final (f, c, _) = await open(tester);
      try {
        await tester.pumpWidget(editor(c, 'budget'));
        await localSettle(tester);
        expect(find.byKey(const ValueKey('native-start')), findsOneWidget);
        expect(
          tester.widget(find.byKey(const ValueKey('native-start'))),
          isA<DateField>(),
        );
        expect(
          tester.widget(find.byKey(const ValueKey('native-amount'))),
          isA<AmountField>(),
        );
        expect(find.textContaining('YYYY-MM-DD'), findsNothing);
        expect(find.textContaining('PHP'), findsNothing);
        expect(find.text('LOCAL ONLY · PRIVATE ON THIS DEVICE'), findsNothing);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('every debt form fits both platforms and 200% text', (
      tester,
    ) async {
      final (f, c, debt) = await open(tester);
      addTearDown(tester.view.reset);
      try {
        final record = c.snapshot.current.firstWhere((r) => r.actionId == debt);
        for (final (platform, width, text) in const [
          (TargetPlatform.android, 320.0, 1.0),
          (TargetPlatform.android, 320.0, 2.0),
          (TargetPlatform.android, 412.0, 1.0),
          (TargetPlatform.windows, 720.0, 2.0),
          (TargetPlatform.windows, 1440.0, 1.0),
        ]) {
          tester.view.physicalSize = Size(width, 3200);
          tester.view.devicePixelRatio = 1;
          for (final op in const [
            'debtImport',
            'borrowing',
            'debtPayment',
            'debtClassification',
            'debtSchedule',
            'debtPayoff',
            'debtAdjustment',
          ]) {
            await tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 3200),
                  textScaler: TextScaler.linear(text),
                ),
                child: editor(
                  c,
                  op,
                  initial: {'debt': record.id},
                  platform: platform,
                ),
              ),
            );
            await localSettle(tester);
            final error = tester.takeException();
            expect(error, isNull, reason: '$op $platform $width $text: $error');
          }
        }
      } finally {
        await close(tester, f, c);
      }
    });
  });

  group('changes that need the latest records', () {
    Widget charge(LocalFinancialController c, String debtId) => MaterialApp(
      themeAnimationDuration: Duration.zero,
      theme: SalapiyaTheme.build(
        Brightness.light,
        platform: TargetPlatform.windows,
      ),
      home: FinancialEnvironment(
        production: true,
        child: NativeFinanceEditor(
          controller: c,
          operation: 'debtAdjustment',
          title: 'Log a lender charge or waiver',
          initial: {
            'debt': debtId,
            'name': 'Late fee',
            'amount': '25.00',
            'reason': 'Late',
            'reference': 'Statement',
            'verified': 'true',
            'category': 'category-fees',
          },
        ),
      ),
    );

    LocalRevision? saved(LocalFinancialController c) => c.snapshot.current
        .where((r) => financeType(r) == 'debtAdjustment')
        .firstOrNull;

    Future<void> connect(LocalFixture f, LocalFinancialController c) async {
      await realAsync(() async {
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
    }

    testWidgets('with no connection it stays on Review and keeps everything', (
      tester,
    ) async {
      sized(tester);
      final (f, c, debt) = await open(tester);
      realAsync = tester.runAsync;
      try {
        final record = c.snapshot.current.firstWhere((r) => r.actionId == debt);
        await connect(f, c);
        var syncs = 0;
        c.syncLatest = () async => syncs++;
        await tester.pumpWidget(charge(c, record.id));
        await localSettle(tester);
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
        expect(saved(c), isNull);
        await localTap(tester, submit());
        expect(syncs, 2);
        expect(find.text('Couldn’t check your latest records'), findsOneWidget);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('a sync that brings new records asks for another look', (
      tester,
    ) async {
      sized(tester);
      final (f, c, debt) = await open(tester);
      try {
        final record = c.snapshot.current.firstWhere((r) => r.actionId == debt);
        await tester.pumpWidget(charge(c, record.id));
        await localSettle(tester);
        await localTap(tester, submit());
        c.connected = true;
        c.syncLatest = () => f.post('expense', {
          'account': c.snapshot.accounts.first.id,
          'name': 'From another device',
          'amount': '10.00',
          'category': 'category-food',
        });
        await localTap(tester, submit());
        expect(find.text('Your records changed'), findsOneWidget);
        expect(saved(c), isNull);
        await localTap(tester, submit());
        expect(saved(c), isNotNull);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('a sync with nothing new saves straight away', (tester) async {
      sized(tester);
      final (f, c, debt) = await open(tester);
      try {
        final record = c.snapshot.current.firstWhere((r) => r.actionId == debt);
        await tester.pumpWidget(charge(c, record.id));
        await localSettle(tester);
        await localTap(tester, submit());
        var syncs = 0;
        c.connected = true;
        c.syncLatest = () async => syncs++;
        await localTap(tester, submit());
        expect(syncs, 1);
        expect(saved(c), isNotNull);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('an ordinary payment never waits for a sync', (tester) async {
      sized(tester);
      final (f, c, _) = await open(tester);
      try {
        await tester.pumpWidget(app(c, prefill(c)));
        await localSettle(tester);
        await localTap(tester, submit());
        var syncs = 0;
        c.connected = true;
        c.syncLatest = () async => syncs++;
        await localTap(tester, submit());
        expect(syncs, 0);
        expect(payment(c).values['amount'], '400.00');
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('a new debt saves offline and says why its schedule did not', (
      tester,
    ) async {
      sized(tester);
      final (f, c, _) = await open(tester);
      realAsync = tester.runAsync;
      try {
        await connect(f, c);
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
                operation: 'debtImport',
                title: 'Add a debt',
                initial: {
                  'name': 'New loan',
                  'lender': 'Lender',
                  'amount': '600.00',
                  'frequency': 'monthly',
                  'firstDue': _offset(10),
                  'installmentCount': '3',
                  'splitMode': 'divide',
                },
              ),
            ),
          ),
        );
        await localSettle(tester);
        await localTap(tester, submit());
        await localTap(tester, submit());
        expect(find.text('Debt added'), findsOneWidget);
        expect(find.text('Schedule not saved'), findsOneWidget);
        expect(
          find.textContaining('it needs a connection to check your latest'),
          findsOneWidget,
        );
        expect(find.textContaining('Sync now before'), findsNothing);
      } finally {
        await close(tester, f, c);
      }
    });
  });

  group('what a field accepts', () {
    Finder note() => find.byKey(const ValueKey('field-note'));

    testWidgets('an amount refuses letters and says why, right there', (
      tester,
    ) async {
      sized(tester);
      final (f, c, _) = await open(tester);
      try {
        await tester.pumpWidget(app(c, prefill(c)));
        await localSettle(tester);
        await tester.enterText(amountField(), '12a');
        await tester.pump();
        expect(
          tester.widget<TextField>(amountField()).controller!.text,
          '400.00',
        );
        expect(find.text('Numbers only, like 1500.00.'), findsOneWidget);
        // The note sits at the field.
        expect(
          tester.getTopLeft(note()).dy,
          moreOrLessEquals(tester.getBottomLeft(amountField()).dy + Space.xs),
        );
        // A valid keystroke clears it.
        await tester.enterText(amountField(), '12');
        await tester.pump();
        expect(note(), findsNothing);
        expect(tester.widget<TextField>(amountField()).controller!.text, '12');
        // Otherwise it goes by itself.
        await tester.enterText(amountField(), '12x');
        await tester.pump();
        expect(note(), findsOneWidget);
        await tester.pump(Motion.note);
        expect(note(), findsNothing);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('amounts stop at two decimals and one point', (tester) async {
      sized(tester);
      final (f, c, _) = await open(tester);
      try {
        await tester.pumpWidget(app(c, prefill(c)));
        await localSettle(tester);
        await tester.enterText(amountField(), '10.123');
        await tester.pump();
        expect(find.text('Up to two decimals.'), findsOneWidget);
        await tester.enterText(amountField(), '1.2.3');
        await tester.pump();
        expect(find.text('Only one decimal point.'), findsOneWidget);
        await tester.enterText(amountField(), '-5');
        await tester.pump();
        expect(find.text('This amount can’t be negative.'), findsOneWidget);
        await tester.pump(Motion.note);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('a pasted amount loses its ₱ and commas', (tester) async {
      sized(tester);
      final (f, c, _) = await open(tester);
      try {
        await tester.pumpWidget(app(c, prefill(c)));
        await localSettle(tester);
        await tester.enterText(amountField(), '₱1,250.50');
        await tester.pump();
        expect(
          tester.widget<TextField>(amountField()).controller!.text,
          '1250.50',
        );
        expect(note(), findsNothing);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('a count takes whole numbers only', (tester) async {
      sized(tester);
      final (f, c, debt) = await open(tester);
      try {
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
                operation: 'debtImport',
                title: 'Form',
                initial: {'frequency': 'monthly', 'debt': debt},
              ),
            ),
          ),
        );
        await localSettle(tester);
        final count = find.byKey(const ValueKey('native-installmentCount'));
        await tester.enterText(count, '1.5');
        await tester.pump();
        expect(find.text('Whole numbers only.'), findsOneWidget);
        await tester.pump(Motion.note);
      } finally {
        await close(tester, f, c);
      }
    });

    testWidgets('account menus show each balance, and it can be hidden', (
      tester,
    ) async {
      sized(tester);
      final (f, c, _) = await open(tester);
      try {
        await tester.pumpWidget(app(c, prefill(c)));
        await localSettle(tester);
        // The chosen account's balance sits under the field.
        expect(find.text('Balance ₱5,000.00'), findsOneWidget);
        await localTap(
          tester,
          find.byKey(const ValueKey('native-select-account')),
        );
        expect(find.text('Balance ₱5,000.00'), findsNWidgets(2));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        c.privacyHidden = () => true;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(app(c, prefill(c)));
        await localSettle(tester);
        expect(find.text('Balance Amount hidden'), findsOneWidget);
        expect(find.textContaining('₱5,000.00'), findsNothing);
      } finally {
        await close(tester, f, c);
      }
    });

    test('each kind accepts only its own data', () {
      expect(FieldInput.amount.accepts('1250.50'), isTrue);
      expect(FieldInput.amount.accepts('1250.'), isTrue);
      expect(FieldInput.amount.accepts(''), isTrue);
      expect(FieldInput.amount.accepts('12a'), isFalse);
      expect(FieldInput.amount.accepts('-1'), isFalse);
      expect(FieldInput.signedAmount.accepts('-1.50'), isTrue);
      expect(FieldInput.wholeNumber.accepts('12'), isTrue);
      expect(FieldInput.wholeNumber.accepts('1.2'), isFalse);
      expect(FieldInput.numberList.accepts('1,3, 5'), isTrue);
      expect(FieldInput.numberList.accepts('1;3'), isFalse);
      expect(FieldInput.date.accepts('2026-10-30'), isTrue);
      expect(FieldInput.date.accepts('2026-1'), isTrue);
      expect(FieldInput.date.accepts('Oct 30'), isFalse);
    });
  });

  test('money results keep centavos and flag rounding', () {
    final engine = CalculatorEngine();
    for (final key in ['1', '2', '5', '0']) {
      engine.digit(key);
    }
    expect(engine.moneyText, '1250.00');
    expect(engine.moneyRounded, isFalse);
    engine
      ..operator('÷')
      ..digit('3')
      ..equals();
    expect(engine.moneyText, '416.67');
    expect(engine.moneyRounded, isTrue);
  });

  testWidgets('a draft for one payment never replaces another row', (
    tester,
  ) async {
    sized(tester);
    final (f, c, _) = await open(tester);
    try {
      final initial = prefill(c);
      await tester.pumpWidget(app(c, initial));
      await localSettle(tester);
      await tester.enterText(amountField(), '123.00');
      await tester.pump();
      await localSettle(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        app(c, {...initial, 'allocations': 'two,600.00', 'amount': '600.00'}),
      );
      await localSettle(tester);
      expect(
        tester.widget<TextField>(amountField()).controller!.text,
        '600.00',
      );
    } finally {
      await close(tester, f, c);
    }
  });
}
