import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/features/life/presentation/life_screen.dart'
    show lifeTabs;
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/local/local_runtime.dart';
import 'package:salapiya/local/local_store.dart';
import 'package:salapiya/profile/help_data.dart';
import 'package:salapiya/profile/help_tab.dart';
import 'package:salapiya/profile/profile_data.dart';
import 'package:salapiya/profile/profile_page.dart';
import 'package:salapiya/prototype/scenarios.dart';
import 'package:salapiya/shared/shared_demo.dart';
import 'package:salapiya/shared/shared_hub.dart';

import 'local_money_journey.dart' show localWait;
import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

const windows = TargetPlatform.windows, android = TargetPlatform.android;

/// §2 sweep: both platforms at every width and both text sizes.
const sizes = [
  (android, 320.0),
  (android, 360.0),
  (android, 412.0),
  (windows, 720.0),
  (windows, 1200.0),
  (windows, 1440.0),
];

void main() {
  Future<void> app(
    WidgetTester tester,
    Widget child, {
    required TargetPlatform platform,
    required double width,
    double text = 1,
    Brightness brightness = Brightness.light,
    double height = 3600,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        // No theme animation: each case renders its platform at once.
        themeAnimationDuration: Duration.zero,
        theme: SalapiyaTheme.build(brightness, platform: platform),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(text),
          ),
          child: child,
        ),
      ),
    );
    await tester.pump();
  }

  Widget page(
    PrototypeSession session,
    GallerySettings settings, {
    String tab = 'Profile',
    SharedHub? hub,
    ProfileGoToLog? log,
  }) => ProfilePage(
    key: UniqueKey(),
    session: session,
    settings: settings,
    tab: ValueNotifier(tab),
    hub: hub,
    goTo: log?.add,
  );

  void clean(WidgetTester tester, String label) {
    final error = tester.takeException();
    expect(error, isNull, reason: '$label: $error');
  }

  group('Help', () {
    test('search needs every word, in any order, in either part', () {
      const entry = HelpEntry('Is a loan income?', 'Borrowed money isn’t.');
      expect(entry.matches(''), isTrue);
      expect(entry.matches('   '), isTrue);
      expect(entry.matches('LOAN'), isTrue);
      expect(entry.matches('borrowed income'), isTrue);
      expect(entry.matches('income borrowed'), isTrue);
      expect(entry.matches('loan card'), isFalse);
    });

    test('questions are unique, and every link goes to a real tab', () {
      final entries = [for (final t in helpTopics) ...t.entries];
      expect(entries.map((e) => e.question).toSet(), hasLength(entries.length));
      const tabs = {
        AppDestination.money: [
          'Accounts',
          'Activity',
          'Cards',
          'Planning',
          'Reports',
          'Import',
          'Files',
        ],
        AppDestination.debts: ['Summary', 'Schedule', 'Payments', 'History'],
      };
      for (final link in entries.map((e) => e.link).nonNulls) {
        final tab = link.tab;
        if (tab == null) continue;
        final known = link.destination == AppDestination.life
            ? lifeTabs
            : tabs[link.destination];
        expect(known, contains(tab), reason: link.label);
      }
    });

    test('the release note stays out, and nothing uses old jargon', () {
      const jargon = [
        'certification',
        'chunk',
        'contract',
        'cutoff',
        'evidence',
        'liability',
        'ledger',
        'synchroniz',
        'unscanned',
      ];
      for (final topic in helpTopics) {
        for (final entry in topic.entries) {
          final text = '${entry.question} ${entry.answer}'.toLowerCase();
          for (final word in jargon) {
            expect(text, isNot(contains(word)), reason: entry.question);
          }
        }
      }
    });
  });

  group('default group', () {
    test('offers Ask me each time, then each active group', () {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final source = demoSharedSource(session);
      final choices = defaultGroupChoices(source, null)!;
      expect(choices.options.first, (null, askEachTime));
      expect(choices.options.length, greaterThan(2));
      expect(choices.chosen, isNull);
      expect(choices.shown, askEachTime);
      expect(choices.lost, isFalse);

      final (id, name) = choices.options[1];
      final saved = defaultGroupChoices(source, id)!;
      expect(saved.chosen, id);
      expect(saved.shown, name);
      expect(saved.lost, isFalse);
    });

    test('a default that can no longer be used reads as asking', () {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final choices = defaultGroupChoices(demoSharedSource(session), 'gone')!;
      expect(choices.chosen, isNull);
      expect(choices.shown, askEachTime);
      expect(choices.lost, isTrue);
    });

    test('with no groups there is nothing to choose', () {
      final session = PrototypeSession()..select(OverviewScenario.empty);
      addTearDown(session.dispose);
      expect(defaultGroupChoices(demoSharedSource(session), null), isNull);
    });
  });

  group('sweep', () {
    testWidgets('Profile and Help at every size, text size and theme', (
      tester,
    ) async {
      final session = PrototypeSession();
      final settings = GallerySettings();
      final hub = SharedHub(session);
      addTearDown(() {
        hub.dispose();
        session.dispose();
        settings.dispose();
      });
      for (final tab in const ['Profile', 'Help']) {
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            for (final brightness in Brightness.values) {
              await app(
                tester,
                page(session, settings, tab: tab, hub: hub),
                platform: platform,
                width: width,
                text: text,
                brightness: brightness,
              );
              expect(find.byType(AppTabs<String>), findsOneWidget);
              clean(tester, '$tab $platform $width $text $brightness');
            }
          }
        }
      }
    });

    testWidgets('hidden, incomplete and empty on both platforms', (
      tester,
    ) async {
      final session = PrototypeSession();
      final settings = GallerySettings();
      addTearDown(() {
        session.dispose();
        settings.dispose();
      });
      for (final (platform, width) in sizes) {
        session.togglePrivacy();
        await app(
          tester,
          page(session, settings),
          platform: platform,
          width: width,
        );
        expect(find.textContaining('₱'), findsNothing);
        clean(tester, 'hidden $platform $width');
        session.togglePrivacy();

        for (final scenario in [
          OverviewScenario.incomplete,
          OverviewScenario.empty,
        ]) {
          session.select(scenario);
          await app(
            tester,
            page(session, settings),
            platform: platform,
            width: width,
          );
          // This tab holds no money, so none of these can change a figure.
          expect(find.textContaining('₱'), findsNothing);
          clean(tester, '$scenario $platform $width');
        }
        session.reset();
      }
    });
  });

  group('Profile tab', () {
    testWidgets('the demo has its tools; the id waits under View details', (
      tester,
    ) async {
      final session = PrototypeSession();
      final settings = GallerySettings();
      addTearDown(() {
        session.dispose();
        settings.dispose();
      });
      await app(
        tester,
        page(session, settings),
        platform: windows,
        width: 1200,
      );
      expect(find.byKey(const ValueKey('demo-tools')), findsOneWidget);
      expect(find.text(session.profile.profileId), findsNothing);
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text(session.profile.profileId), findsOneWidget);
    });

    testWidgets('settings reach the saved values', (tester) async {
      final session = PrototypeSession();
      final settings = GallerySettings();
      addTearDown(() {
        session.dispose();
        settings.dispose();
      });
      await app(
        tester,
        page(session, settings),
        platform: windows,
        width: 1200,
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('profile-theme')),
          matching: find.text('Dark'),
        ),
      );
      await tester.pump();
      expect(settings.themeMode, ThemeMode.dark);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('profile-text-size')),
          matching: find.text('150%'),
        ),
      );
      await tester.pump();
      expect(settings.textScale, 1.5);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('profile-text-size')),
          matching: find.text('System'),
        ),
      );
      await tester.pump();
      expect(settings.textScale, isNull);

      await tester.tap(find.byKey(const ValueKey('profile-reduce-motion')));
      await tester.pump();
      expect(settings.reduceMotion, isTrue);

      expect(session.hideAmounts, isFalse);
      await tester.tap(find.byKey(const ValueKey('profile-hide-amounts')));
      await tester.pump();
      expect(session.hideAmounts, isTrue);
    });

    testWidgets('a real profile has no effects switch or demo tools', (
      tester,
    ) async {
      await withProfile(tester, (runtime, settings) async {
        await app(
          tester,
          page(runtime.session!, settings),
          platform: windows,
          width: 1200,
        );
        expect(find.byKey(const ValueKey('demo-tools')), findsNothing);
        expect(find.textContaining('effects'), findsNothing);
        expect(find.text('Reduce motion'), findsOneWidget);
        expect(find.text('Philippine peso (PHP)'), findsOneWidget);
        expect(find.text('On this device only'), findsWidgets);
      });
    });

    testWidgets('At a glance moves to the tab it names', (tester) async {
      final session = PrototypeSession();
      final settings = GallerySettings();
      addTearDown(() {
        session.dispose();
        settings.dispose();
      });
      await app(
        tester,
        page(session, settings),
        platform: windows,
        width: 1200,
      );
      await tester.tap(find.byKey(const ValueKey('glance-devices')));
      await tester.pumpAndSettle();
      expect(find.text(profileCaption('Devices')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-glance')), findsNothing);
    });

    testWidgets('choosing a default group saves it, and Ask clears it', (
      tester,
    ) async {
      final session = PrototypeSession();
      final settings = GallerySettings();
      final hub = SharedHub(session);
      addTearDown(() {
        hub.dispose();
        session.dispose();
        settings.dispose();
      });
      await app(
        tester,
        page(session, settings, hub: hub),
        platform: windows,
        width: 1200,
      );
      final group = demoSharedGroupName(session);
      await tester.tap(find.byKey(const ValueKey('profile-default-group')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(group));
      await tester.pumpAndSettle();
      expect(session.sharedDefaultGroup, isNotNull);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-default-group')),
          matching: find.text(group),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('profile-default-group')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('default-group-none')));
      await tester.pumpAndSettle();
      expect(session.sharedDefaultGroup, isNull);
    });

    testWidgets('Reminders goes to Life’s tab', (tester) async {
      final session = PrototypeSession();
      final settings = GallerySettings();
      final log = ProfileGoToLog();
      addTearDown(() {
        session.dispose();
        settings.dispose();
      });
      await app(
        tester,
        page(session, settings, log: log),
        platform: windows,
        width: 1200,
      );
      await tester.tap(find.byKey(const ValueKey('profile-reminders')));
      await tester.pump();
      expect(log.calls, [(AppDestination.life, 'Reminders')]);
    });

    testWidgets('a failed preference save shows on every tab', (tester) async {
      await withProfile(tester, (runtime, settings) async {
        runtime.preferenceError = 'Preferences could not be saved.';
        for (final tab in profileTabs) {
          await app(
            tester,
            page(runtime.session!, settings, tab: tab),
            platform: windows,
            width: 1200,
          );
          expect(
            find.text('Preferences could not be saved.'),
            findsOneWidget,
            reason: tab,
          );
        }
        runtime.preferenceError = null;
      });
    });
  });

  group('Edit name', () {
    testWidgets('an empty name errors on the field, and a name saves', (
      tester,
    ) async {
      await withProfile(tester, (runtime, settings) async {
        final session = runtime.session!;
        await app(
          tester,
          page(session, settings),
          platform: windows,
          width: 1200,
        );
        await tester.tap(find.byKey(const ValueKey('profile-edit-name')));
        await tester.pumpAndSettle();
        expect(find.textContaining('other devices'), findsNothing);

        await tester.enterText(find.byType(TextField), '   ');
        await tester.tap(find.text('Save name'));
        final refused = find.text('Enter a display name (1–200 characters).');
        await localWait(tester, () => refused.evaluate().isNotEmpty);
        expect(find.text('Save name'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '  Mara Reyes ');
        await tester.tap(find.text('Save name'));
        await localWait(
          tester,
          () => find.text('Save name').evaluate().isEmpty,
        );
        expect(session.profile.name, 'Mara Reyes');
        expect(
          await tester.runAsync(session.localFinance.store.displayName),
          'Mara Reyes',
        );
        expect(find.text('Mara Reyes'), findsOneWidget);
      });
    });

    testWidgets('a connected profile says it stays on this device', (
      tester,
    ) async {
      await withProfile(tester, (runtime, settings) async {
        final session = runtime.session!;
        await tester.runAsync(() async {
          await session.localFinance.store.stageConnection(
            '11111111-1111-4111-8111-111111111111',
            'synthetic@example.test',
            newLocalIdForTest(),
          );
          await runtime.connected.attach();
        });
        await app(
          tester,
          page(session, settings),
          platform: android,
          width: 360,
          height: 1400,
        );
        await tester.tap(find.byKey(const ValueKey('profile-edit-name')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'This changes the name on this device. Your other devices keep '
            'theirs.',
          ),
          findsOneWidget,
        );
      });
    });
  });

  group('Help tab', () {
    testWidgets('a question opens in place and its link goes there', (
      tester,
    ) async {
      final session = PrototypeSession();
      final settings = GallerySettings();
      final log = ProfileGoToLog();
      addTearDown(() {
        session.dispose();
        settings.dispose();
      });
      await app(
        tester,
        page(session, settings, tab: 'Help', log: log),
        platform: windows,
        width: 1200,
      );
      expect(find.textContaining('Borrowed money isn’t income'), findsNothing);
      await tester.tap(find.text('Is a loan income?'));
      await tester.pump();
      expect(
        find.textContaining('Borrowed money isn’t income'),
        findsOneWidget,
      );
      await tester.tap(find.text('Open Debts'));
      await tester.pump();
      expect(log.calls, [(AppDestination.debts, 'Summary')]);
    });

    testWidgets('search narrows the cards, and says when nothing matches', (
      tester,
    ) async {
      final session = PrototypeSession();
      final settings = GallerySettings();
      addTearDown(() {
        session.dispose();
        settings.dispose();
      });
      await app(
        tester,
        page(session, settings, tab: 'Help'),
        platform: windows,
        width: 1200,
      );
      expect(find.byType(HelpTab), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'virus');
      await tester.pump();
      expect(find.text('Are my files safe?'), findsOneWidget);
      expect(find.text('Is a loan income?'), findsNothing);
      expect(find.byKey(const ValueKey('help-Money')), findsNothing);

      await tester.enterText(find.byType(TextField), 'zebra');
      await tester.pump();
      expect(find.text('Nothing matches that'), findsOneWidget);
      // About stays, so the version is always one screen away.
      expect(find.byKey(const ValueKey('help-about')), findsOneWidget);
    });
  });
}

/// A chosen group's name in the demo.
String demoSharedGroupName(PrototypeSession session) =>
    defaultGroupChoices(demoSharedSource(session), null)!.options[1].$2;

/// Records where a link went.
class ProfileGoToLog {
  final calls = <(AppDestination, String?)>[];
  void add(AppDestination destination, String? tab) =>
      calls.add((destination, tab));
}

String newLocalIdForTest() => '22222222-2222-4222-8222-222222222222';

/// Runs [body] against a real encrypted profile.
Future<void> withProfile(
  WidgetTester tester,
  Future<void> Function(LocalRuntime, GallerySettings) body,
) async {
  final directory = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('salapiya-profile-ui-'),
  ))!;
  final settings = GallerySettings();
  final runtime = LocalRuntime(
    LocalProfiles(directory, MemoryProfileVault()),
    settings,
  );
  await tester.runAsync(() => runtime.create('Rendel', ThemeMode.system));
  try {
    await body(runtime, settings);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await closeWithWidgetClock(tester, runtime.close);
    runtime.dispose();
    settings.dispose();
    await tester.runAsync(() => directory.delete(recursive: true));
  }
}
