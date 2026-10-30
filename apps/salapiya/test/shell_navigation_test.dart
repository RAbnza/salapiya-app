import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/app/shell.dart';
import 'package:salapiya/app/shell_navigation.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/features/finance/presentation/financial_editor.dart';
import 'package:salapiya/features/finance/presentation/financial_widgets.dart';
import 'package:salapiya/prototype/scenarios.dart';

import 'shell_journey.dart';

final windows = TargetPlatformVariant.only(TargetPlatform.windows);
final android = TargetPlatformVariant.only(TargetPlatform.android);

Future<void> pumpShell(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const SalapiyaApp());
  await tester.pumpAndSettle();
}

ShellNavigation shellOf(WidgetTester tester) => ShellNavigation.of(
  tester.element(
    find
        .descendant(
          of: find.byType(SalapiyaShell),
          matching: find.byType(Scaffold),
        )
        .first,
  ),
);

List<String> crumbs(WidgetTester tester) => [
  for (final crumb in shellOf(tester).breadcrumb) crumb.label,
];

Future<void> altArrow(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Windows sidebar follows the width classes', (tester) async {
    await pumpShell(tester, const Size(1440, 900));
    final card = find.byKey(const ValueKey('sidebar-card'));
    expect(tester.getSize(card).width, Space.sidebarWidth);
    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();
    expect(tester.getSize(card).width, Space.railWidth);
    await tester.tap(find.byTooltip('Expand sidebar'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(800, 700);
    await tester.pumpAndSettle();
    expect(tester.getSize(card).width, Space.railWidth);
    expect(find.byTooltip('Expand sidebar'), findsNothing);

    tester.view.physicalSize = const Size(500, 700);
    await tester.pumpAndSettle();
    expect(find.byType(ShellSidebar), findsNothing);
    await tester.tap(find.byKey(const ValueKey('shell-destinations')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('choose-money')));
    await tester.pumpAndSettle();
    expect(crumbs(tester), ['Money', 'Accounts']);
    expect(find.text('Money › Accounts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: windows);

  testWidgets('Windows back and forward over destinations and tabs', (
    tester,
  ) async {
    await pumpShell(tester, const Size(1440, 900));
    final shell = shellOf(tester);
    expect(shell.canGoBack, isFalse);
    await tester.tap(find.byKey(const ValueKey('nav-money')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Activity'));
    expect(crumbs(tester), ['Money', 'Activity']);

    await altArrow(tester, LogicalKeyboardKey.arrowLeft);
    expect(crumbs(tester), ['Money', 'Accounts']);
    await altArrow(tester, LogicalKeyboardKey.arrowLeft);
    expect(shell.destination, AppDestination.overview);
    expect(shell.canGoBack, isFalse);
    expect(shell.canGoForward, isTrue);

    await altArrow(tester, LogicalKeyboardKey.arrowRight);
    expect(crumbs(tester), ['Money', 'Accounts']);
    await altArrow(tester, LogicalKeyboardKey.arrowRight);
    expect(crumbs(tester), ['Money', 'Activity']);
    expect(shell.canGoForward, isFalse);

    // The mouse back button goes back too.
    final mouse = await tester.startGesture(
      tester.getCenter(find.byType(Navigator).last),
      kind: PointerDeviceKind.mouse,
      buttons: kBackMouseButton,
    );
    await mouse.up();
    await tester.pumpAndSettle();
    expect(crumbs(tester), ['Money', 'Accounts']);
    expect(tester.takeException(), isNull);
  }, variant: windows);

  testWidgets('Windows pages open beside the sidebar and never come forward', (
    tester,
  ) async {
    await pumpShell(tester, const Size(1440, 900));
    final shell = shellOf(tester);
    await tester.tap(find.byKey(const ValueKey('shell-new')));
    await tester.pumpAndSettle();
    await tester.tap(newItem('Log expense'));
    await tester.pumpAndSettle();
    expect(find.byType(FinancialEditor), findsOneWidget);
    expect(find.byType(ShellSidebar), findsOneWidget);
    expect(crumbs(tester), ['Overview', 'Log expense']);
    expect(shell.pages.single.name, 'action/Add expense');
    expect(shell.canGoBack, isTrue);

    await altArrow(tester, LogicalKeyboardKey.arrowLeft);
    expect(find.byType(FinancialEditor), findsNothing);
    expect(shell.hasPages, isFalse);
    expect(shell.canGoForward, isFalse);

    // Choosing a destination closes the open page first.
    await tester.tap(find.byKey(const ValueKey('shell-new')));
    await tester.pumpAndSettle();
    await tester.tap(newItem('Log income'));
    await tester.pumpAndSettle();
    expect(shell.hasPages, isTrue);

    // Esc closes the New menu, not the page under it.
    await tester.tap(find.byKey(const ValueKey('shell-new')));
    await tester.pumpAndSettle();
    expect(find.text('Log a transfer'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Log a transfer'), findsNothing);
    expect(shell.hasPages, isTrue);

    await tester.tap(find.byKey(const ValueKey('nav-debts')));
    await tester.pumpAndSettle();
    expect(shell.hasPages, isFalse);
    expect(crumbs(tester), ['Debts', 'Summary']);
    expect(tester.takeException(), isNull);
  }, variant: windows);

  testWidgets('Android Overview links switch section and tab; Back returns', (
    tester,
  ) async {
    await pumpShell(tester, const Size(412, 900));
    final shell = shellOf(tester);
    await tapVisible(tester, find.byKey(const ValueKey('overview-available')));
    expect(shell.destination, AppDestination.money);
    expect(crumbs(tester), ['Money', 'Accounts']);
    expect(find.byType(FinancePage), findsNothing);
    expect(find.byKey(const ValueKey('floating-dock-surface')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(shell.destination, AppDestination.overview);
    expect(find.text('Available money'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: android);

  testWidgets('Android pages hide the app bar and dock', (tester) async {
    await pumpShell(tester, const Size(412, 900));
    await tester.tap(find.byKey(const ValueKey('shell-profile')));
    await tester.pumpAndSettle();
    expect(crumbs(tester), ['Overview', 'Profile and settings']);
    expect(find.byKey(const ValueKey('floating-dock-surface')), findsNothing);
    expect(find.byKey(const ValueKey('shell-profile')), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('floating-dock-surface')), findsOneWidget);
    expect(shellOf(tester).hasPages, isFalse);

    await tester.tap(find.byKey(const ValueKey('shell-new')));
    await tester.pumpAndSettle();
    expect(newItem('Log a transfer'), findsOneWidget);
    expect(find.text('Transfer money'), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: android);

  testWidgets('Windows sidebar: tabs, Go to, attention and utilities', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = GallerySettings();
    final session = PrototypeSession();
    await tester.pumpWidget(SalapiyaApp(settings: settings, session: session));
    await tester.pumpAndSettle();

    // A section opens its tabs; a tab row goes straight to that tab.
    await tester.tap(find.byKey(const ValueKey('nav-money')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-money-Reports')));
    await tester.pumpAndSettle();
    expect(crumbs(tester), ['Money', 'Reports']);
    // Pressing the current section again folds its tabs away.
    await tester.tap(find.byKey(const ValueKey('nav-money')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nav-money-Reports')), findsNothing);

    // Go to (Ctrl+K) filters, and Enter opens the first match.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('goto-field')), 'books');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(crumbs(tester), ['Life', 'Books']);

    // The demo has a payment waiting for confirmation.
    expect(find.text('1 payment to confirm'), findsOneWidget);
    await tester.tap(find.text('1 payment to confirm'));
    await tester.pumpAndSettle();
    expect(crumbs(tester), ['Shared Expenses', 'Payments']);

    await tester.tap(find.byKey(const ValueKey('shell-hide-amounts')));
    await tester.pumpAndSettle();
    expect(session.hideAmounts, isTrue);
    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);

    // The profile card opens its menu.
    await tester.tap(find.byKey(const ValueKey('shell-profile')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('profile-menu-Profile and settings')),
    );
    await tester.pumpAndSettle();
    expect(crumbs(tester), [
      'Shared Expenses',
      'Payments',
      'Profile and settings',
    ]);
    expect(tester.takeException(), isNull);
  }, variant: windows);

  test('page titles come from the page, then the route name', () {
    expect(
      ShellNavigation.pageTitle(
        const RouteSettings(name: 'debt/1', arguments: 'Home loan'),
      ),
      'Home loan',
    );
    expect(
      ShellNavigation.pageTitle(const RouteSettings(name: 'debt/1')),
      'Debt',
    );
    expect(
      ShellNavigation.pageTitle(const RouteSettings(name: 'report/source')),
      'Details',
    );
  });
}
