import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/app/profile_utilities.dart';
import 'package:salapiya/app/shell.dart';
import 'package:salapiya/app/shell_navigation.dart';
import 'package:salapiya/app/title_bar.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/local/local_runtime.dart';
import 'package:salapiya/local/local_store.dart';
import 'package:salapiya/profile/connection_tab.dart';
import 'package:salapiya/prototype/scenarios.dart';

import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

// Android parity with the Windows title bar (§2): the app bar, its status
// row, Go to, the bell and the calculator in the + sheet, from the same
// sources as Windows.

Finder key(String value) => find.byKey(ValueKey(value));

void androidTest(String name, WidgetTesterCallback body) => testWidgets(
  name,
  body,
  variant: TargetPlatformVariant.only(TargetPlatform.android),
);

void windowsTest(String name, WidgetTesterCallback body) => testWidgets(
  name,
  body,
  variant: TargetPlatformVariant.only(TargetPlatform.windows),
);

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

/// The demo app on Android at [size].
Future<PrototypeSession> pumpDemo(
  WidgetTester tester, {
  Size size = const Size(360, 780),
  OverviewScenario scenario = OverviewScenario.local,
  double scale = 1,
  ThemeMode theme = ThemeMode.light,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final settings = GallerySettings()
    ..textScale = scale
    ..themeMode = theme;
  final session = PrototypeSession()..select(scenario);
  addTearDown(session.dispose);
  await tester.pumpWidget(SalapiyaApp(settings: settings, session: session));
  await tester.pumpAndSettle();
  return session;
}

Future<void> tapKey(WidgetTester tester, String value) async {
  await tester.tap(key(value));
  await tester.pumpAndSettle();
}

void main() {
  group('Android app bar and status row', () {
    androidTest('three actions, then the pill and the eye', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpDemo(tester);
      final row = tester.getCenter(key('shell-profile')).dy;
      for (final action in ['shell-goto', 'shell-notifications']) {
        expect(tester.getCenter(key(action)).dy, closeTo(row, 1));
        expect(tester.getSize(key(action)).height, greaterThanOrEqualTo(48));
      }
      expect(tester.getSize(key('shell-profile')), const Size(48, 48));
      expect(find.text('Overview'), findsWidgets);
      final status = tester.getCenter(key('shell-hide-amounts')).dy;
      expect(status, greaterThan(row));
      expect(tester.getCenter(key('shell-sync')).dy, closeTo(status, 1));
      // Every target is 48 tall, the pill's too.
      expect(
        tester
            .getSize(
              find.ancestor(
                of: key('shell-sync'),
                matching: find.byType(TouchArea),
              ),
            )
            .height,
        48,
      );

      // Screen readers can press the profile and the pill, and hear the eye
      // as a toggle.
      final profile = tester.getSemantics(key('shell-profile'));
      expect(profile.label, 'Profile and settings');
      expect(profile.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      final pill = tester.getSemantics(key('shell-sync'));
      expect(pill.label, 'Sync status, Demo · On this device only');
      expect(pill.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(
        tester
            .getSemantics(key('shell-hide-amounts'))
            .getSemanticsData()
            .flagsCollection
            .isToggled
            .toBoolOrNull(),
        isFalse,
      );
      semantics.dispose();
    });

    androidTest('Hide amounts works from the status row', (tester) async {
      final session = await pumpDemo(tester);
      expect(session.hideAmounts, isFalse);
      await tapKey(tester, 'shell-hide-amounts');
      expect(session.hideAmounts, isTrue);
      expect(find.byTooltip('Show amounts'), findsOneWidget);
      await tapKey(tester, 'shell-hide-amounts');
      expect(session.hideAmounts, isFalse);
      expect(find.byTooltip('Hide amounts'), findsOneWidget);
    });

    androidTest('phones use the dock names; wider screens the full name', (
      tester,
    ) async {
      await pumpDemo(tester);
      await tapKey(tester, 'nav-shared');
      final heading = find.descendant(
        of: find.byType(SalapiyaShell),
        matching: find.text('Shared'),
      );
      expect(heading, findsWidgets);
      tester.view.physicalSize = const Size(720, 900);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SalapiyaShell),
          matching: find.text('Shared Expenses'),
        ),
        findsWidgets,
      );
    });

    androidTest('at large text the title drops under the actions', (
      tester,
    ) async {
      await pumpDemo(tester, size: const Size(320, 780), scale: 2);
      final title = find.descendant(
        of: find.byType(SalapiyaShell),
        matching: find.text('Overview'),
      );
      final heading = title.first;
      expect(
        tester.getTopLeft(heading).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(key('shell-profile')).dy),
      );
      final paragraph = tester.renderObject<RenderParagraph>(heading);
      expect(paragraph.didExceedMaxLines, isFalse);
      // At normal text it shares the row. (The test font is wider than
      // Geist, so this checks 412; the real-font render covers 320.)
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpDemo(tester, size: const Size(412, 780));
      expect(
        tester.getCenter(title.first).dy,
        closeTo(tester.getCenter(key('shell-profile')).dy, 1),
      );
    });

    androidTest('the demo pill names its state in plain words', (tester) async {
      final session = await pumpDemo(tester);
      for (final (scenario, label) in [
        (OverviewScenario.local, 'Demo · On this device only'),
        (OverviewScenario.current, 'Demo · Synced'),
        (OverviewScenario.waiting, 'Demo · Waiting for connection'),
        (OverviewScenario.pending, 'Demo · Waiting for connection'),
        (OverviewScenario.incomplete, 'Demo · First download not finished'),
        (OverviewScenario.review, 'Demo · Needs review'),
      ]) {
        session.select(scenario);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: key('shell-sync'), matching: find.text(label)),
          findsOneWidget,
          reason: '$scenario',
        );
      }
    });

    androidTest('the pill opens Profile and settings in the demo', (
      tester,
    ) async {
      await pumpDemo(tester);
      await tapKey(tester, 'shell-sync');
      await tester.pump();
      expect(find.byType(ProfileUtilities), findsOneWidget);
      // The app bar and its status row hide while a page is open.
      expect(key('shell-sync'), findsNothing);
      expect(key('shell-hide-amounts'), findsNothing);
    });
  });

  group('Go to', () {
    androidTest('a full-screen page that filters and opens', (tester) async {
      await pumpDemo(tester);
      await tapKey(tester, 'shell-goto');
      await tester.pump();
      expect(key('goto-field'), findsOneWidget);
      for (final group in ['Sections', 'Tabs', 'New', 'Profile and settings']) {
        expect(key('goto-group-$group'), findsOneWidget, reason: group);
      }
      expect(find.byType(ListEnd), findsOneWidget);

      await tester.enterText(key('goto-field'), 'activ');
      await tester.pumpAndSettle();
      expect(key('goto-group-Sections'), findsNothing);
      expect(key('goto-group-Tabs'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);

      await tester.enterText(key('goto-field'), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches "zzz"'), findsOneWidget);

      // Enter opens the first match.
      await tester.enterText(key('goto-field'), 'activity');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(key('goto-field'), findsNothing);
      final shell = shellOf(tester);
      expect(shell.destination, AppDestination.money);
      expect(shell.tab, 'Activity');

      // A row opens its place.
      await tapKey(tester, 'shell-goto');
      await tester.pump();
      await tester.tap(key('choose-debts'));
      await tester.pumpAndSettle();
      expect(shellOf(tester).destination, AppDestination.debts);
    });

    androidTest('Back closes it and leaves the place as it was', (
      tester,
    ) async {
      await pumpDemo(tester);
      await tapKey(tester, 'shell-goto');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(key('goto-field'), findsNothing);
      expect(shellOf(tester).destination, AppDestination.overview);
    });
  });

  group('the bell', () {
    androidTest('a sheet whose rows go where each is handled', (tester) async {
      await pumpDemo(tester);
      expect(find.byTooltip('Notifications, 1 need attention'), findsOneWidget);
      await tapKey(tester, 'shell-notifications');
      expect(find.text('Needs attention'), findsOneWidget);
      await tapKey(tester, 'notice-1 payment to confirm');
      expect(find.text('Needs attention'), findsNothing);
      final shell = shellOf(tester);
      expect(shell.destination, AppDestination.shared);
      expect(shell.tab, 'Payments');
    });

    androidTest('many rows, then Close', (tester) async {
      await pumpDemo(tester, scenario: OverviewScenario.review);
      expect(find.byTooltip('Notifications, 2 need attention'), findsOneWidget);
      await tapKey(tester, 'shell-notifications');
      expect(key('notice-1 payment to confirm'), findsOneWidget);
      expect(key('notice-Sync needs review'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Needs attention'), findsNothing);
      expect(shellOf(tester).destination, AppDestination.overview);
    });
  });

  group('the + sheet', () {
    androidTest('its last row opens the calculator, with Copy', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
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
      await pumpDemo(tester);
      await tapKey(tester, 'shell-new');
      final rows = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(ListRow),
      );
      expect(tester.widget<ListRow>(rows.last).title, 'Calculator');
      await tapKey(tester, 'new-calculator');
      expect(key('new-calculator'), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      for (final k in ['1', '0', '0', '÷', '3', '=']) {
        await tester.tap(key('calc-$k'));
        await tester.pump();
      }
      expect(find.text('≈ 33.33'), findsOneWidget);
      await tester.tap(key('calc-Copy'));
      await tester.pump();
      expect(copied, '33.33');
      expect(key('calculator-use'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(key('calculator-display'), findsNothing);
    });

    androidTest('an unfinished download offers only what works', (
      tester,
    ) async {
      final session = await pumpDemo(tester);
      const refused = [
        'Log expense',
        'Log income',
        'Log a transfer',
        'Add shared expense',
      ];
      Future<List<String>> offered() async {
        await tapKey(tester, 'shell-new');
        final titles = [
          for (final row in tester.widgetList<ListRow>(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(ListRow),
            ),
          ))
            row.title,
        ];
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        return titles;
      }

      expect(await offered(), containsAll(refused));
      session.select(OverviewScenario.incomplete);
      await tester.pumpAndSettle();
      final now = await offered();
      for (final label in refused) {
        expect(now, isNot(contains(label)));
      }
      expect(
        now,
        containsAll(['Log a debt payment', 'Add task', 'Calculator']),
      );

      // Go to doesn't offer them either.
      await tapKey(tester, 'shell-goto');
      await tester.pump();
      expect(key('goto-group-New'), findsOneWidget);
      expect(find.text('Log expense'), findsNothing);
      expect(find.text('Log a payment between members'), findsNothing);
      // Once, though Money and Debts both offer it.
      expect(find.text('Log a debt payment'), findsOneWidget);
    });
  });

  group('real build', () {
    Future<void> shell(
      WidgetTester tester,
      Future<void> Function(LocalRuntime) body,
    ) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('salapiya-parity-'),
      ))!;
      final settings = GallerySettings();
      final runtime = LocalRuntime(
        LocalProfiles(directory, MemoryProfileVault()),
        settings,
      );
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.runAsync(() async {
          await runtime.create('Rendel', ThemeMode.system);
          await runtime.session!.localFinance.store.stageConnection(
            '11111111-1111-4111-8111-111111111111',
            'synthetic@example.test',
            newLocalId(),
          );
          await runtime.session!.localFinance.store.db.execute(
            "UPDATE connected_profile SET phase='connected'",
          );
          await runtime.connected.attach();
        });
        await tester.pumpWidget(
          SalapiyaApp(
            production: true,
            settings: settings,
            localRuntime: runtime,
          ),
        );
        await tester.pumpAndSettle();
        await body(runtime);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await closeWithWidgetClock(tester, runtime.close);
        runtime.dispose();
        settings.dispose();
      }
    }

    Finder pill(String label) =>
        find.descendant(of: key('shell-sync'), matching: find.text(label));

    testWidgets('the pill opens Connection; an empty bell says so', (
      tester,
    ) async {
      await shell(tester, (runtime) async {
        expect(find.byTooltip('Notifications'), findsOneWidget);
        await tapKey(tester, 'shell-notifications');
        expect(find.text('Nothing needs attention'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(pill(runtime.connected.label), findsOneWidget);
        await tapKey(tester, 'shell-sync');
        await tester.pump();
        expect(find.byType(ConnectionTab), findsOneWidget);
      });
    });

    testWidgets('signed out: the pill says so and the bell has a row', (
      tester,
    ) async {
      await shell(tester, (runtime) async {
        runtime.connected
          ..sessionExpired = true
          ..changed();
        await tester.pumpAndSettle();
        expect(pill('Signed out'), findsOneWidget);
        expect(
          find.descendant(
            of: key('shell-sync'),
            matching: find.byIcon(Icons.no_accounts_outlined),
          ),
          findsOneWidget,
        );
        await tapKey(tester, 'shell-notifications');
        await tapKey(tester, 'notice-Sync needs you to sign in');
        await tester.pump();
        expect(find.byType(ConnectionTab), findsOneWidget);
      });
    });

    testWidgets('an unfinished first download warns and offers what works', (
      tester,
    ) async {
      await shell(tester, (runtime) async {
        runtime.connected
          ..binding = {...runtime.connected.binding!, 'phase': 'downloading'}
          ..changed();
        await tester.pumpAndSettle();
        expect(pill('First download not finished'), findsOneWidget);
        expect(
          find.descendant(
            of: key('shell-sync'),
            matching: find.byIcon(Icons.cloud_download_outlined),
          ),
          findsOneWidget,
        );
        await tapKey(tester, 'shell-new');
        expect(find.text('Log expense'), findsNothing);
        expect(find.text('Log a debt payment'), findsOneWidget);
        expect(find.text('Calculator'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      });
    });
  });

  group('sweep', () {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 2.0]) {
        for (final theme in [ThemeMode.light, ThemeMode.dark]) {
          androidTest('Android $width, ${scale}x, ${theme.name}', (
            tester,
          ) async {
            await pumpDemo(
              tester,
              size: Size(width, 780),
              scale: scale,
              theme: theme,
              // The longest pill label at large text.
              scenario: scale == 2
                  ? OverviewScenario.incomplete
                  : OverviewScenario.review,
            );
            expect(tester.takeException(), isNull);
            for (final action in [
              'shell-goto',
              'shell-notifications',
              'shell-profile',
              'shell-sync',
              'shell-hide-amounts',
            ]) {
              final rect = tester.getRect(key(action));
              expect(rect.left, greaterThanOrEqualTo(0), reason: action);
              expect(rect.right, lessThanOrEqualTo(width), reason: action);
            }
            for (final destination in ['nav-shared', 'nav-overview']) {
              await tapKey(tester, destination);
              expect(tester.takeException(), isNull);
            }
            await tapKey(tester, 'shell-goto');
            await tester.pump();
            expect(tester.takeException(), isNull);
            await tester.pageBack();
            await tester.pumpAndSettle();
            await tapKey(tester, 'shell-notifications');
            expect(tester.takeException(), isNull);
            await tester.tap(find.text('Close'));
            await tester.pumpAndSettle();
            await tapKey(tester, 'shell-new');
            // At large text the + sheet scrolls to its last row.
            await tester.ensureVisible(key('new-calculator'));
            await tester.pumpAndSettle();
            await tapKey(tester, 'new-calculator');
            expect(key('calculator-display'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.tap(find.text('Close'));
            await tester.pumpAndSettle();
          });
        }
      }
    }

    for (final frame in [true, false]) {
      for (final scale in [1.0, 2.0]) {
        windowsTest(
          'Windows below 600, ${frame ? 'with' : 'without'} the title bar, '
          '${scale}x: nothing doubled or lost',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = const Size(560, 800);
            addTearDown(tester.view.resetPhysicalSize);
            final messenger = tester.binding.defaultBinaryMessenger;
            messenger.setMockMethodCallHandler(
              WindowFrame.channel,
              (_) async => null,
            );
            addTearDown(() {
              messenger.setMockMethodCallHandler(WindowFrame.channel, null);
              WindowFrame.reset();
            });
            WindowFrame.enabled = frame;
            final settings = GallerySettings()..textScale = scale;
            await tester.pumpWidget(SalapiyaApp(settings: settings));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            // One bell, one eye and one sync status, wherever they are.
            expect(key('titlebar-notifications'), findsOneWidget);
            expect(key('shell-hide-amounts'), findsOneWidget);
            expect(key('titlebar-sync'), findsOneWidget);
            expect(key('shell-notifications'), findsNothing);
            expect(key('shell-sync'), findsNothing);
            // The menu button stays the way to Go to; Android's search
            // button isn't added.
            expect(key('shell-destinations'), findsOneWidget);
            expect(key('shell-goto'), findsNothing);
            expect(key('shell-new'), findsOneWidget);
            expect(key('shell-profile'), findsOneWidget);
            final inBar = find.descendant(
              of: find.byType(TitleBar),
              matching: key('titlebar-notifications'),
            );
            expect(inBar, frame ? findsOneWidget : findsNothing);
          },
        );
      }
    }
  });
}
