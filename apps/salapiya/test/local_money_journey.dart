import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_dashboard.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/features/finance/presentation/financial_widgets.dart';
import 'package:salapiya/local/local_runtime.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/gallery/settings.dart';

/// Follow the approved task group's visible action or its real More menu.
/// This never invokes a controller or bypasses review/confirmation.
Future<void> localAction(WidgetTester tester, String label) async {
  final target = find.text(label);
  if (target.evaluate().isEmpty) {
    final groups = find.byWidgetPredicate(
      (widget) =>
          widget is WorkspaceActionGroup &&
          widget.actions.values.contains(label),
    );
    if (groups.evaluate().isNotEmpty) {
      await localTap(
        tester,
        find.descendant(
          of: groups.first,
          matching: find.byWidgetPredicate(
            (widget) => widget is PopupMenuButton<String>,
          ),
        ),
      );
    } else {
      await localTap(tester, find.byKey(const ValueKey('shell-new')));
    }
  }
  await localTap(tester, target.first);
}

Future<void> localSettle(WidgetTester tester) async {
  bool loading() =>
      tester
          .widgetList<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .any((w) => w.value == null) ||
      tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .any((w) => w.value == null);
  // A route's first frame is offstage, so a form still loading only shows up
  // on the next one.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  for (var i = 0; i < 300 && loading(); i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
  }
  await tester.pumpAndSettle(
    const Duration(milliseconds: 30),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 15),
  );
}

Future<void> localWait(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 200 && !ready(); i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
  }
  expect(ready(), isTrue, reason: 'Local operation did not complete');
  await localSettle(tester);
}

Future<void> localTap(WidgetTester tester, Finder finder) async {
  expect(finder, findsWidgets);
  if (tester
      .widgetList<EditableText>(find.byType(EditableText))
      .any((field) => field.focusNode.hasFocus)) {
    FocusManager.instance.primaryFocus?.unfocus();
    // The real Android IME closes asynchronously outside Flutter's frame clock.
    // Scroll/tap only after its viewport transition, rather than tapping behind it.
    if (Platform.isAndroid) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
    }
    await localSettle(tester);
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.runAsync(() => tester.tap(finder.first));
  await localSettle(tester);
}

Future<void> localEnter(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey('native-$key'));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final widget = tester.widget(finder);
  if (widget is DateField) {
    widget.onChanged!(DateTime.parse(value));
    await localSettle(tester);
    return;
  }
  final editable = find.descendant(
    of: finder,
    matching: find.byType(EditableText),
  );
  await tester.runAsync(() async {
    tester
        .state<EditableTextState>(editable)
        .updateEditingValue(
          TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          ),
        );
  });
  await localSettle(tester);
}

Future<void> localConfirm(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final submit = find.byKey(const ValueKey('native-submit'));
  await localTap(tester, submit);
  expect(
    find.text('Save reviewed values'),
    findsOneWidget,
    reason: tester
        .widgetList<InlineNotice>(find.byType(InlineNotice))
        .map((n) => n.message)
        .join('\n'),
  );
  await localTap(tester, submit);
  await localWait(
    tester,
    () => find.text('Saved securely on this device.').evaluate().isNotEmpty,
  );
  await localTap(tester, find.text('Done'));
}

/// Closes the top page: the back row on Android, Esc on Windows.
Future<void> localBack(WidgetTester tester) async {
  final back = find.byType(BackButton);
  if (back.evaluate().isNotEmpty) return localTap(tester, back);
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await localSettle(tester);
}

/// A page's More menu, then one of its items.
Future<void> localMore(WidgetTester tester, String label) async {
  await localTap(tester, find.byTooltip('More actions'));
  await localTap(tester, find.text(label));
}

// Shared real persistence/widget journey, executed on Windows and Android too.
Future<void> localMoneyJourney(
  WidgetTester tester,
  LocalProfiles profiles,
) async {
  final settings = GallerySettings();
  var runtime = LocalRuntime(profiles, settings);
  await tester.runAsync(runtime.reopen);
  await tester.pumpWidget(
    SalapiyaApp(production: true, settings: settings, localRuntime: runtime),
  );
  await localSettle(tester);
  await localTap(tester, find.byKey(const ValueKey('greeting-start')));
  expect(find.text('Continue with Google'), findsOneWidget);
  await localTap(tester, find.text('Start on this device'));
  await tester.enterText(find.byType(TextField), 'Everyday owner');
  await localTap(tester, find.text('Create profile'));
  await localWait(tester, () => runtime.session != null);
  expect(find.textContaining('Tala logged'), findsNothing);
  expect(find.textContaining('DEMO ·'), findsNothing);
  await localTap(tester, find.byKey(const ValueKey('nav-money')));
  await localTap(tester, find.text('Add account'));
  await localEnter(tester, 'name', 'Cash wallet');
  await localEnter(tester, 'amount', '1250.00');
  await localEnter(tester, 'cutoff', '2026-10-14');
  await localConfirm(tester);
  final cash = runtime.session!.finance.accounts.single.id;
  await localTap(tester, find.text('Add account'));
  await localEnter(tester, 'name', 'Bank');
  await localEnter(tester, 'amount', '1000.00');
  await localEnter(tester, 'cutoff', '2026-10-14');
  await localConfirm(tester);
  await localTap(tester, find.byTooltip('More'));
  await localTap(tester, find.byKey(const ValueKey('money-categories')));
  await localTap(tester, find.text('Add category'));
  await localEnter(tester, 'name', 'Everyday extras');
  await localConfirm(tester);
  expect(find.text('Everyday extras'), findsOneWidget);
  await localBack(tester);
  await localAction(tester, 'Log expense');
  await localEnter(tester, 'name', 'Lunch');
  // A third decimal is refused as it's typed.
  await localEnter(tester, 'amount', '185.501');
  expect(find.text('Up to two decimals.'), findsOneWidget);
  await localEnter(tester, 'amount', '185.50');
  await localEnter(tester, 'date', '2026-10-21');
  await localTap(tester, find.byKey(const ValueKey('form-more-details')));
  await localTap(tester, find.text('Split across categories'));
  await localEnter(tester, 'splitAmount', '150.00');
  // Navigation retains an encrypted unposted draft, then the same editor restores it.
  await localBack(tester);
  await localTap(tester, find.text('Keep draft & close'));
  await localAction(tester, 'Log expense');
  await localWait(
    tester,
    () => find.textContaining('Your draft is back').evaluate().isNotEmpty,
  );
  expect(
    tester
        .widget<AmountField>(find.byKey(const ValueKey('native-amount')))
        .controller
        .text,
    '185.50',
  );
  await localConfirm(tester);
  expect(runtime.session!.finance.account(cash).balance, BigInt.from(106450));
  await localAction(tester, 'Log income');
  await localEnter(tester, 'name', 'Gift');
  await localEnter(tester, 'amount', '100.01');
  await localEnter(tester, 'date', '2026-10-21');
  await localConfirm(tester);
  await localAction(tester, 'Log a transfer');
  await localEnter(tester, 'amount', '100.00');
  await localEnter(tester, 'fee', '10.00');
  await localTap(tester, find.byKey(const ValueKey('form-more-details')));
  await localTap(tester, find.text('Add transfer fee'));
  await localEnter(tester, 'fee', '9.99');
  await localEnter(tester, 'extraFee1Amount', '0.01');
  await localEnter(tester, 'date', '2026-10-21');
  await localConfirm(tester);
  expect(runtime.session!.finance.account(cash).balance, BigInt.from(105451));
  expect(runtime.session!.finance.liquid, BigInt.from(215451));
  await localTap(tester, find.text('Activity').first);
  await localTap(tester, find.byKey(const ValueKey('activity-period')));
  await localTap(tester, find.byKey(const ValueKey('period-all')));
  await localTap(tester, find.text('Lunch').first);
  await localTap(tester, find.text('Correct transaction'));
  await localEnter(tester, 'amount', '180.50');
  await localEnter(tester, 'reason', 'Correct receipt');
  await localConfirm(tester);
  // The earlier version stays, linked to the current one.
  await localTap(tester, find.text('See the current version'));
  await localMore(tester, 'Log a refund');
  await localEnter(tester, 'amount', '5.00');
  await localTap(tester, find.text('Allocate refund across original portions'));
  await localEnter(tester, 'refundFirstAmount', '3.00');
  await localEnter(tester, 'refund1Amount', '2.00');
  await localTap(
    tester,
    find.descendant(
      of: find.byKey(const ValueKey('native-select-refund1Posting')),
      matching: find.byType(InputDecorator),
    ),
  );
  await localTap(tester, find.textContaining('Transport ·').last);
  await localEnter(tester, 'date', '2026-10-21');
  await localEnter(tester, 'reason', 'Partial returned purchase');
  await localConfirm(tester);
  final refundId = runtime.session!.localFinance.snapshot.current
      .firstWhere((r) => r.kind == 'refund')
      .id;
  await localTap(tester, find.byKey(ValueKey('evidence-$refundId')));
  await localMore(tester, 'Reverse transaction');
  await localEnter(tester, 'reason', 'Refund was recorded in error');
  await localConfirm(tester);
  await localBack(tester); // current expense detail
  await localBack(tester); // earlier version
  await localBack(tester);
  expect(runtime.session!.finance.account(cash).balance, BigInt.from(105951));
  await localTap(tester, find.text('Accounts').first);
  await localTap(tester, find.text('Cash wallet').first);
  await localMore(tester, 'Check balance');
  await localEnter(tester, 'amount', '1050.00');
  await localEnter(tester, 'date', '2026-10-21');
  await localConfirm(tester);
  await localTap(tester, find.text('Balance check · Cash wallet').first);
  await localTap(tester, find.text('Adjust balance to match'));
  await localEnter(tester, 'reason', 'Counted wallet');
  await localConfirm(tester);
  await localBack(tester);
  expect(runtime.session!.finance.account(cash).balance, BigInt.from(105000));
  await localMore(tester, 'Adjust account balance');
  await localEnter(tester, 'amount', '-0.01');
  await localEnter(tester, 'date', '2026-10-21');
  await localEnter(tester, 'reason', 'One cent cash evidence');
  await localConfirm(tester);
  final manual = runtime.session!.localFinance.snapshot.current.firstWhere(
    (r) => r.kind == 'adjustment' && r.values['mode'] == 'manual',
  );
  await localTap(tester, find.byKey(ValueKey('row-${manual.id}')));
  await localMore(tester, 'Reverse transaction');
  await localEnter(tester, 'reason', 'Void adjustment evidence');
  await localConfirm(tester);
  await localBack(tester);
  expect(runtime.session!.finance.account(cash).balance, BigInt.from(105000));
  settings.change(() {
    settings.themeMode = ThemeMode.dark;
    settings.reduceMotion = true;
  });
  await tester.runAsync(runtime.flushPreferences);
  final owner = runtime.session!.profile.profileId;
  final commands = runtime.session!.finance.version;
  await tester.pumpWidget(const SizedBox.shrink());
  await localSettle(tester);
  await tester.runAsync(runtime.close);
  runtime.dispose();
  runtime = LocalRuntime(profiles, settings);
  await tester.runAsync(runtime.reopen);
  expect(runtime.session!.profile.profileId, owner);
  expect(runtime.session!.profile.name, 'Everyday owner');
  expect(runtime.session!.finance.version, commands);
  expect(runtime.session!.finance.account(cash).balance, BigInt.from(105000));
  expect(settings.themeMode, ThemeMode.dark);
  expect(settings.reduceMotion, isTrue);
  await tester.pumpWidget(
    SalapiyaApp(production: true, settings: settings, localRuntime: runtime),
  );
  await localSettle(tester);
  expect(find.byType(OverviewDashboard), findsOneWidget);
  expect(find.text('Start on this device'), findsNothing);
  await localTap(tester, find.byKey(const ValueKey('nav-debts')));
  expect(find.text('A clear view of what you owe'), findsOneWidget);
  expect(find.text('Home essentials loan'), findsNothing);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await localSettle(tester);
  await tester.runAsync(runtime.close);
  runtime.dispose();
  settings.dispose();
}
