import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/features/finance/presentation/financial_editor.dart';
import 'package:salapiya/app/shell.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/prototype/scenarios.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// Opens Profile and settings: directly from the header button, or through
/// the sidebar's profile menu.
Future<void> openProfile(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const ValueKey('shell-profile')));
  final item = find.byKey(const ValueKey('profile-menu-Profile and settings'));
  if (item.evaluate().isNotEmpty) await tapVisible(tester, item);
}

/// Shared native/widget acceptance journey; never captures screenshots.
Future<void> shellJourney(WidgetTester tester) async {
  final settings = GallerySettings();
  final session = PrototypeSession();
  await tester.pumpWidget(SalapiyaApp(settings: settings, session: session));
  await tester.pumpAndSettle();
  expect(find.byType(SalapiyaShell), findsOneWidget);
  expect(find.text('Money Today'), findsOneWidget);
  expect(find.text('₱29,300.75'), findsOneWidget);

  for (final destination in AppDestination.values) {
    final control = find.byKey(ValueKey('nav-${destination.name}'));
    if (control.evaluate().isEmpty) {
      await tapVisible(
        tester,
        find.byKey(const ValueKey('shell-destinations')),
      );
      await tapVisible(
        tester,
        find.byKey(ValueKey('choose-${destination.name}')),
      );
    } else {
      await tapVisible(tester, control);
    }
    expect(tester.takeException(), isNull);
  }
  await tapVisible(tester, find.byKey(const ValueKey('nav-overview')));
  if (find.byTooltip('Collapse sidebar').evaluate().isNotEmpty) {
    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Expand sidebar'), findsOneWidget);
    await tester.tap(find.byTooltip('Expand sidebar'));
    await tester.pumpAndSettle();
  }
  // Overview links switch to the section and tab; Back (Alt+← on Windows)
  // returns to Overview.
  final desktop = defaultTargetPlatform == TargetPlatform.windows;
  await tapVisible(tester, find.text('View accounts'));
  expect(find.text('Accounts'), findsWidgets);
  expect(find.text('Cash wallet'), findsWidgets);
  if (desktop) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  } else {
    await tester.binding.handlePopRoute();
  }
  await tester.pumpAndSettle();
  expect(find.text('Money Today'), findsOneWidget);

  final newAction = find.byKey(const ValueKey('shell-new'));
  await tester.tap(newAction);
  await tester.pumpAndSettle();
  expect(find.text('Log a transfer'), findsOneWidget);
  if (desktop) {
    await tester.tap(newAction);
  } else {
    await tester.binding.handlePopRoute();
  }
  await tester.pumpAndSettle();
  expect(find.text('Log a transfer'), findsNothing);
  await tester.tap(newAction);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Log expense').last);
  await tester.pumpAndSettle();
  expect(find.byType(FinancialEditor), findsOneWidget);
  // Windows keeps the shell around pages; Android pages are full screen.
  expect(newAction, desktop ? findsOneWidget : findsNothing);
  final field = find.byKey(const ValueKey('field-name'));
  if (kProfileMode) {
    final editable = find.descendant(
      of: field,
      matching: find.byType(EditableText),
    );
    tester
        .state<EditableTextState>(editable)
        .updateEditingValue(const TextEditingValue(text: 'Invented note'));
    await tester.pumpAndSettle();
  } else {
    await tester.enterText(field, 'Invented note');
    await tester.pumpAndSettle();
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(find.text('Leave this demo draft?'), findsOneWidget);
  await tester.tap(find.text('Keep editing'));
  await tester.pumpAndSettle();
  expect(tester.widget<TextField>(field).controller!.text, 'Invented note');
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Discard draft'));
  await tester.pumpAndSettle();
  expect(find.byType(FinancialEditor), findsNothing);

  for (final scenario in OverviewScenario.values) {
    session.select(scenario);
    await tester.pumpAndSettle();
    if (scenario == OverviewScenario.incomplete) {
      expect(find.text('Not yet available'), findsOneWidget);
      expect(find.text('₱29,300.75'), findsNothing);
    }
    if (scenario == OverviewScenario.empty) {
      expect(find.text('₱0.00'), findsOneWidget);
    }
    if (scenario == OverviewScenario.pending) {
      expect(find.textContaining('₱29,115.25'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  }
  session.reset();
  await tester.tap(find.byKey(const ValueKey('shell-hide-amounts')));
  await tester.pumpAndSettle();
  expect(find.text('₱29,300.75'), findsNothing);
  await tester.tap(find.byKey(const ValueKey('shell-hide-amounts')));
  await tester.pumpAndSettle();
  await openProfile(tester);
  await tapVisible(tester, find.text('Dark'));
  expect(settings.themeMode, ThemeMode.dark);
  await tapVisible(tester, find.text('Reduce motion'));
  expect(settings.reduceMotion, isTrue);
  await tapVisible(tester, find.text('Craft effects'));
  expect(settings.effects, isFalse);
  await tapVisible(tester, find.text('First-run preview'));
  expect(find.text('Create a local offline profile'), findsOneWidget);
  expect(find.text('Continue with Google'), findsOneWidget);
  expect(find.text('Restore from backup'), findsOneWidget);
  await tapVisible(tester, find.text('Continue with Google'));
  expect(find.text('Explore connection scenario'), findsOneWidget);
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('Design Gallery'));
  expect(find.text('Made with care.\nClear by design.'), findsOneWidget);
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(find.byType(SalapiyaShell), findsOneWidget);
  expect(tester.takeException(), isNull);
}
