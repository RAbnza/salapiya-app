import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/app/shell.dart';
import 'package:salapiya/app/shell_navigation.dart';
import 'package:salapiya/app/title_bar.dart';
import 'package:salapiya/app/title_bar_tools.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/prototype/scenarios.dart';

import 'shell_journey.dart';

final windows = TargetPlatformVariant.only(TargetPlatform.windows);
final android = TargetPlatformVariant.only(TargetPlatform.android);

/// Calls the app made on the window channel.
final calls = <MethodCall>[];

/// Pumps the demo app with the runner's custom frame on (or off).
Future<void> pumpApp(
  WidgetTester tester,
  Size size, {
  bool customFrame = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  calls.clear();
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(WindowFrame.channel, (call) async {
    calls.add(call);
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(WindowFrame.channel, null);
    WindowFrame.reset();
    TitleBarClock.now = DateTime.now;
  });
  // A fixed clock: Friday 30 October 2026, 2:45 PM.
  TitleBarClock.now = () => DateTime(2026, 10, 30, 14, 45, 10);
  WindowFrame.enabled = customFrame;
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

final bar = find.byType(TitleBar);
final goTo = find.byKey(const ValueKey('shell-goto'));
final sync = find.byKey(const ValueKey('titlebar-sync'));

/// Whether [key]'s button can be pressed.
bool enabled(WidgetTester tester, String key) =>
    tester
        .widget<IconButton>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(IconButton),
          ),
        )
        .onPressed !=
    null;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

/// The sync label, from the title bar's status tooltip.
String syncLabel(WidgetTester tester) => tester
    .widget<Tooltip>(find.ancestor(of: sync, matching: find.byType(Tooltip)))
    .message!
    .replaceFirst('Sync status: ', '');

Color? fillOf(WidgetTester tester, String label) =>
    (tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.bySemanticsLabel(label),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration
            as BoxDecoration?)
        ?.color;

void main() {
  testWidgets('Windows title bar spans the window above the sidebar', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, const Size(1536, 900));
    expect(
      tester.getRect(bar),
      const Rect.fromLTWH(0, 0, 1536, Space.titleBarHeight),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('sidebar-card'))).dy,
      Space.titleBarHeight,
    );

    // Go to moved out of the app bar: centered on the window, 320 wide.
    expect(goTo, findsOneWidget);
    expect(find.descendant(of: bar, matching: goTo), findsOneWidget);
    // It gives way to the tools on the right, keeping 48 of drag space. The
    // test font is wider than Geist, so the demo's sync label ("Demo · On
    // this device only") reaches it here; with Geist it sits centered.
    final tools = tester
        .getRect(find.byKey(const ValueKey('titlebar-notifications')))
        .left;
    expect(
      tester.getCenter(goTo).dx,
      moreOrLessEquals(
        math.min(1536 / 2, tools - Space.xxxl - Space.goToWidth / 2),
        epsilon: Space.xs,
      ),
    );
    expect(tester.getSize(find.byType(GoToField)).width, Space.goToWidth);

    // The sync state moved out of the profile card.
    expect(find.descendant(of: bar, matching: sync), findsOneWidget);
    final label = syncLabel(tester);
    expect(
      find.descendant(of: sync, matching: find.byType(StatusPill)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ShellSidebar),
        matching: find.text(label),
      ),
      findsNothing,
    );

    // The runner gets the bar's height, the maximize button and the seven
    // interactive areas (clock, arrows, Go to, tools, sync, minimize,
    // close); the rest is drag space.
    final regions =
        calls.lastWhere((call) => call.method == 'regions').arguments
            as List<Object?>;
    final max = tester.getRect(find.bySemanticsLabel('Maximize'));
    expect(regions.length, 5 + 4 * 7);
    expect(regions.sublist(0, 5), [
      Space.titleBarHeight,
      max.left,
      max.top,
      max.right,
      max.bottom,
    ]);
    expect(max.right, 1536 - CaptionButtons.width);

    // The status opens the sync details (the demo has one settings page).
    await tester.tap(sync);
    await tester.pumpAndSettle();
    expect(shellOf(tester).pages.single.title, 'Profile and settings');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  }, variant: windows);

  testWidgets('Android has no title bar', (tester) async {
    await pumpApp(tester, const Size(400, 800));
    expect(bar, findsNothing);
    expect(sync, findsNothing);
    // The Android header keeps its own sync pill.
    expect(find.textContaining('Demo · '), findsWidgets);
    expect(tester.takeException(), isNull);
  }, variant: android);

  testWidgets('Without the custom frame Windows keeps the Chat 4 layout', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1536, 900), customFrame: false);
    expect(bar, findsNothing);
    expect(find.byType(GoToField), findsOneWidget);
    expect(find.text('NEEDS ATTENTION'), findsOneWidget);
    expect(find.text('QUICK CREATE'), findsNothing);
    expect(find.byKey(const ValueKey('shell-hide-amounts')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ShellSidebar),
        matching: find.textContaining('Demo · '),
      ),
      findsOneWidget,
    );
  }, variant: windows);

  testWidgets('Back and forward follow the history', (tester) async {
    await pumpApp(tester, const Size(1440, 900));
    final shell = shellOf(tester);
    expect(enabled(tester, 'titlebar-back'), isFalse);
    expect(enabled(tester, 'titlebar-forward'), isFalse);

    await tapKey(tester, 'nav-money');
    expect(enabled(tester, 'titlebar-back'), isTrue);
    expect(enabled(tester, 'titlebar-forward'), isFalse);

    await tapKey(tester, 'titlebar-back');
    expect(shell.destination, AppDestination.overview);
    expect(enabled(tester, 'titlebar-back'), isFalse);
    expect(enabled(tester, 'titlebar-forward'), isTrue);

    await tapKey(tester, 'titlebar-forward');
    expect(shell.destination, AppDestination.money);
    expect(enabled(tester, 'titlebar-forward'), isFalse);

    // An open page: Back closes it, and Forward never reopens it.
    await tapKey(tester, 'shell-new');
    await tester.tap(find.widgetWithText(MenuItemButton, 'Log expense'));
    await tester.pumpAndSettle();
    expect(shell.hasPages, isTrue);
    await tapKey(tester, 'titlebar-back');
    expect(shell.hasPages, isFalse);
    expect(shell.destination, AppDestination.money);
    expect(enabled(tester, 'titlebar-forward'), isFalse);
    expect(tester.takeException(), isNull);
  }, variant: windows);

  testWidgets('Window controls are named buttons that drive the window', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, const Size(1440, 900));
    for (final label in ['Minimize', 'Maximize', 'Close']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(label: label, isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSize(find.bySemanticsLabel(label)).width,
        CaptionButtons.width,
      );
    }
    for (final (label, method) in [
      ('Minimize', 'minimize'),
      ('Maximize', 'toggleMaximize'),
      ('Close', 'close'),
    ]) {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump();
      expect(calls.last.method, method);
    }

    // The runner reports the maximized state and the maximize hover (it
    // owns that button's pointer input for Snap Layouts).
    final c = CraftTheme.of(tester.element(bar));
    WindowFrame.state.value = const WindowFrameState(
      maximized: true,
      maxButton: CaptionState.hover,
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Maximize'), findsNothing);
    expect(fillOf(tester, 'Restore Down'), c.windowControlHover);

    // Close hovers with the system red.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(find.bySemanticsLabel('Close')),
    );
    await tester.pumpAndSettle();
    expect(fillOf(tester, 'Close'), CraftTheme.windowCloseHover);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  }, variant: windows);

  testWidgets('Tab goes through the bar in reading order, then the app', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1440, 900));
    await tapKey(tester, 'nav-money');
    await tapKey(tester, 'nav-debts');
    await tapKey(tester, 'titlebar-back');
    expect(enabled(tester, 'titlebar-back'), isTrue);
    expect(enabled(tester, 'titlebar-forward'), isTrue);

    bool focused(Finder target) {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) return false;
      final element = tester.element(target);
      var found = context == element;
      context.visitAncestorElements((e) => !(found = found || e == element));
      return found;
    }

    Focus.of(
      tester.element(
        find.descendant(
          of: find.byKey(const ValueKey('titlebar-clock')),
          matching: find.byType(Text),
        ),
      ),
    ).requestFocus();
    await tester.pump();
    expect(focused(find.byKey(const ValueKey('titlebar-clock'))), isTrue);
    for (final key in [
      'titlebar-back',
      'titlebar-forward',
      'shell-goto',
      'titlebar-notifications',
      'titlebar-calculator',
      'shell-hide-amounts',
      'titlebar-sync',
    ]) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focused(find.byKey(ValueKey(key))), isTrue, reason: key);
    }
    // The window controls aren't in the Tab order (Alt+Space reaches them).
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focused(bar), isFalse);
    expect(tester.takeException(), isNull);
  }, variant: windows);

  testWidgets('A dialog leaves the window controls working', (tester) async {
    await pumpApp(tester, const Size(1440, 900));
    await tapKey(tester, 'nav-money');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('goto-field')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('titlebar-back')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(shellOf(tester).destination, AppDestination.money);
    expect(find.byKey(const ValueKey('goto-field')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pump();
    expect(calls.last.method, 'close');
    expect(tester.takeException(), isNull);
  }, variant: windows);

  testWidgets('Medium and compact widths', (tester) async {
    await pumpApp(tester, const Size(800, 700));
    // Medium: the clock shows the time over the rail, and Go to is a search
    // button beside Forward.
    expect(find.text('2:45 PM'), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const ValueKey('titlebar-clock'))).dx,
      Space.railWidth / 2,
    );
    expect(find.byType(GoToField), findsNothing);
    expect(find.descendant(of: bar, matching: goTo), findsOneWidget);
    expect(goTo, findsOneWidget);
    expect(
      find.descendant(of: sync, matching: find.byType(StatusPill)),
      findsOneWidget,
    );

    // Compact: the header keeps its Go to menu, the status is icon-only and
    // the header's pill row is gone.
    tester.view.physicalSize = const Size(500, 700);
    await tester.pumpAndSettle();
    expect(goTo, findsNothing);
    expect(find.byKey(const ValueKey('shell-destinations')), findsOneWidget);
    expect(
      find.descendant(of: sync, matching: find.byType(StatusPill)),
      findsNothing,
    );
    expect(tester.getSize(sync).width, Space.pointerTarget);
    expect(find.text(syncLabel(tester)), findsNothing);
    // No sidebar: no clock segment; the calculator gives way to drag space,
    // and the header's Hide amounts button is in the bar.
    expect(find.byKey(const ValueKey('titlebar-clock')), findsNothing);
    expect(find.byKey(const ValueKey('titlebar-calculator')), findsNothing);
    expect(
      find.byKey(const ValueKey('titlebar-notifications')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('shell-hide-amounts')), findsOneWidget);
    expect(
      find.descendant(
        of: bar,
        matching: find.byKey(const ValueKey('shell-hide-amounts')),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  }, variant: windows);

  testWidgets('The date and clock sit over the sidebar and open a calendar', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1440, 900));
    final clock = find.byKey(const ValueKey('titlebar-clock'));
    expect(
      find.text('2:45 PM · Fri, 30 Oct', findRichText: true),
      findsOneWidget,
    );

    // The clock is centered in the sidebar's column.
    expect(tester.getCenter(clock).dx, Space.sidebarWidth / 2);

    // The bar's line stops at the sidebar's column, which runs unbroken.
    final c = CraftTheme.of(tester.element(bar));
    final line = find.descendant(
      of: bar,
      matching: find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == c.divider,
      ),
    );
    expect(tester.getRect(line).left, Space.sidebarWidth);
    expect(tester.getRect(line).height, 1);

    // Back and forward sit just past the sidebar's edge, neutral: text when
    // enabled, secondary when disabled.
    final back = find.byKey(const ValueKey('titlebar-back'));
    expect(tester.getTopLeft(back).dx, Space.sidebarWidth + Space.sm);
    Color? arrowColor() => IconTheme.of(
      tester.element(find.descendant(of: back, matching: find.byType(Icon))),
    ).color;
    expect(arrowColor(), c.secondary);
    await tapKey(tester, 'nav-money');
    expect(arrowColor(), c.text);

    // A new minute arrives.
    TitleBarClock.now = () => DateTime(2026, 10, 30, 14, 46);
    await tester.pump(const Duration(seconds: 50));
    expect(
      find.text('2:46 PM · Fri, 30 Oct', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(clock);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('clock-calendar')), findsOneWidget);
    await tapKey(tester, 'clock-open-calendar');
    expect(shellOf(tester).destination, AppDestination.life);
    expect(shellOf(tester).tab, 'Calendar');
    expect(find.byKey(const ValueKey('clock-calendar')), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: windows);

  testWidgets('The bell takes over Needs attention; Quick create replaces it', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1440, 900));
    final sidebar = find.byType(ShellSidebar);
    expect(
      find.descendant(of: sidebar, matching: find.text('NEEDS ATTENTION')),
      findsNothing,
    );
    expect(
      find.descendant(of: sidebar, matching: find.text('QUICK CREATE')),
      findsOneWidget,
    );

    // The demo has a payment to confirm.
    final bell = find.byKey(const ValueKey('titlebar-notifications'));
    expect(
      tester.widget<IconButton>(bell).tooltip,
      startsWith('Notifications, '),
    );
    await tester.tap(bell);
    await tester.pumpAndSettle();
    expect(find.text('NEEDS ATTENTION'), findsOneWidget);
    await tapKey(tester, 'notice-1 payment to confirm');
    expect(shellOf(tester).destination, AppDestination.shared);
    expect(shellOf(tester).tab, 'Payments');

    // Quick create follows the section: Debts, then Overview.
    await tapKey(tester, 'nav-debts');
    for (final label in [
      'Log a debt payment',
      'Add a debt',
      'Log a new loan',
    ]) {
      expect(find.byKey(ValueKey('quick-$label')), findsOneWidget);
    }
    await tapKey(tester, 'nav-overview');
    expect(find.byKey(const ValueKey('quick-Log a transfer')), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('quick-Log expense')));
    expect(shellOf(tester).pages.single.name, 'action/Add expense');
    expect(tester.takeException(), isNull);
  }, variant: windows);

  testWidgets('Hide amounts lives in the bar and answers Ctrl+H', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, const Size(1440, 900));
    final hide = find.byKey(const ValueKey('shell-hide-amounts'));
    expect(find.descendant(of: bar, matching: hide), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ShellSidebar),
        matching: find.text('Hide amounts'),
      ),
      findsNothing,
    );
    await tester.tap(hide);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show amounts (Ctrl+H)'), findsOneWidget);
    expect(
      tester.getSemantics(find.byTooltip('Show amounts (Ctrl+H)')),
      isSemantics(isToggled: true, hasToggledState: true),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hide amounts (Ctrl+H)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  }, variant: windows);

  test('The calculator is exact and marks rounding', () {
    String run(String keys) {
      final engine = CalculatorEngine();
      for (final key in keys.split(' ')) {
        switch (key) {
          case '=':
            engine.equals();
          case '+' || '−' || '×' || '÷':
            engine.operator(key);
          default:
            for (final d in key.split('')) {
              engine.digit(d);
            }
        }
      }
      return engine.display;
    }

    expect(run('0.1 + 0.2 ='), '0.3');
    expect(run('1250 ÷ 3 ='), '≈ 416.67');
    expect(run('100 ÷ 8 ='), '12.5');
    expect(run('1 + 2 × 3 ='), '9');
    expect(run('1234567 + 1 ='), '1,234,568');
    expect(run('5 − 7.25 ='), '-2.25');
    expect(run('2 ÷ 0 ='), "Can't divide by zero");

    final engine = CalculatorEngine();
    for (final d in '1250'.split('')) {
      engine.digit(d);
    }
    engine
      ..operator('÷')
      ..digit('3')
      ..equals();
    expect(engine.copyText, '416.67');
    expect(engine.expression, '1,250 ÷ 3 =');
  });

  testWidgets('The calculator takes typing and copies its result', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1440, 900));
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tapKey(tester, 'titlebar-calculator');
    final display = find.byKey(const ValueKey('calculator-display'));
    expect(tester.widget<Text>(display).data, '0');
    for (final key in [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.numpadMultiply,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.enter,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.pump();
    expect(tester.widget<Text>(display).data, '36');
    await tapKey(tester, 'calc-÷');
    await tapKey(tester, 'calc-7');
    await tapKey(tester, 'calc-=');
    expect(tester.widget<Text>(display).data, '≈ 5.14');
    await tapKey(tester, 'calc-Copy');
    expect(copied, '5.14');
    expect(find.text('Copied'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: windows);

  testWidgets('Disabled icon buttons look disabled, app-wide', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SalapiyaTheme.build(Brightness.light),
        home: Scaffold(
          body: Row(
            children: [
              const AppIconButton(
                key: ValueKey('off'),
                icon: Icons.add,
                tooltip: 'Off',
                onPressed: null,
              ),
              AppIconButton(
                key: const ValueKey('on'),
                icon: Icons.add,
                tooltip: 'On',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final c = CraftTheme.of(tester.element(find.byKey(const ValueKey('off'))));
    Color? colorOf(String key) => IconTheme.of(
      tester.element(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Icon),
        ),
      ),
    ).color;
    expect(colorOf('off'), c.secondary);
    expect(colorOf('on'), c.primary);
  }, variant: windows);
}
