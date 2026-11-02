import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_profile_view.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/local/local_runtime.dart';
import 'package:salapiya/onboarding/onboarding_actions.dart';
import 'package:salapiya/onboarding/google_page.dart';
import 'package:salapiya/onboarding/greeting_page.dart';
import 'package:salapiya/onboarding/onboarding_data.dart';
import 'package:salapiya/onboarding/onboarding_demo.dart';
import 'package:salapiya/onboarding/records_map.dart';
import 'package:salapiya/onboarding/restore_page.dart';
import 'package:salapiya/onboarding/setup_page.dart';
import 'package:salapiya/onboarding/startup_pages.dart';
import 'package:salapiya/onboarding/welcome_page.dart';
import 'package:salapiya/profile/profile_data.dart';

import 'local_test_support.dart';

/// Stands in for the runtime, so these tests touch no store.
class FakeActions extends ChangeNotifier implements OnboardingActions {
  FakeActions({
    this.start = DeviceStart.fresh,
    this.f = const ConnectionFacts(),
    this.open_,
    this.pick,
  });
  final DeviceStart start;
  ConnectionFacts f;
  final Future<OpenedBackup> Function(PickedBackup, String)? open_;
  final Future<PickedBackup?> Function()? pick;
  final calls = <String>[];
  bool opened = false;

  /// Holds a restore open until it's completed.
  Completer<void>? gate;

  /// What's true once the account has been looked up.
  ConnectionFacts? lookupFacts;
  void note(String call, [ConnectionFacts? next]) {
    calls.add(call);
    if (next != null) f = next;
    notifyListeners();
  }

  @override
  bool get demo => false;
  @override
  Listenable get changes => this;
  @override
  ConnectionFacts facts() => f;
  @override
  bool get profileOpen => opened;
  @override
  Future<DeviceStart> deviceStart() async => start;
  @override
  ThemeMode theme = ThemeMode.system;
  @override
  void showTheme(ThemeMode mode) => theme = mode;
  @override
  Future<void> create(String name, ThemeMode theme) async {}
  @override
  Future<void> resume() async => note('resume');
  @override
  Future<void> connect() async => note('connect');
  @override
  Future<void> cancelSignIn() async => note('cancel');
  @override
  Future<void> lookup() async => note('lookup', lookupFacts);
  @override
  Future<void> confirmConnection() async => note('confirm');
  @override
  Future<void> dontConnect() async => note('dontConnect');
  @override
  String newProfileName() => 'Amihan Reyes';
  @override
  Future<PickedBackup?> pickBackup() async =>
      pick == null ? const PickedBackup('a.salapiya', [1]) : pick!();
  @override
  Future<OpenedBackup> open(PickedBackup backup, String secret) =>
      open_!(backup, secret);
  @override
  Future<void> restore(OpenedBackup backup) async {
    note('restore');
    await gate?.future;
  }

  @override
  void openConnectionTab(BuildContext context) => note('connection');
}

Future<void> show(
  WidgetTester tester,
  Widget page, {
  TargetPlatform platform = TargetPlatform.windows,
  Brightness brightness = Brightness.light,
  Size size = const Size(1200, 800),
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      themeAnimationDuration: Duration.zero,
      theme: SalapiyaTheme.build(brightness, platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pump();
  await tester.pump();
}

WelcomePage welcome({
  DeviceStart start = DeviceStart.fresh,
  ConnectionFacts f = const ConnectionFacts(),
  VoidCallback? onStart,
  VoidCallback? onGoogle,
  VoidCallback? onRestore,
}) => WelcomePage(
  actions: FakeActions(start: start, f: f),
  onStart: onStart ?? () {},
  onGoogle: onGoogle ?? () {},
  onRestore: onRestore ?? () {},
);

/// Every fact the connection disclosure has always carried.
const disclosureFacts = [
  'Google account: ',
  'This uploads your Money and Life records',
  'Career details and the list of your files',
  'runs on Supabase and PowerSync',
  'File contents stay on this device',
  'drafts and device settings',
  'Google only confirms who you are',
  'People who run the service can reach synced records',
  'end-to-end encrypted',
  'downloads before totals show as complete',
];

/// Takes the demo's Restore page to its review.
Future<void> throughRestore(WidgetTester tester) async {
  final choose = find.byKey(const ValueKey('restore-choose'));
  await tester.ensureVisible(choose);
  await tester.pump();
  await tester.tap(choose);
  await tester.pump();
  await tester.pump();
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey('backup-secret')),
      matching: find.byType(TextField),
    ),
    'anything',
  );
  await tester.pump();
  final open = find.byKey(const ValueKey('restore-open'));
  await tester.ensureVisible(open);
  await tester.pump();
  await tester.tap(open);
  await tester.pump();
  await tester.pump();
}

/// Whether the row with [key] does anything when pressed.
bool tappable(WidgetTester tester, String key) => find
    .descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byIcon(Icons.chevron_right),
    )
    .evaluate()
    .isNotEmpty;

void main() {
  group('every screen fits', () {
    final pages = <String, Widget Function()>{
      'welcome': welcome,
      'kept files': () => welcome(
        start: const DeviceStart(
          phase: 'empty',
          keptFiles: true,
          keptName:
              'A name long enough to wrap across the row in a narrow '
              'window',
        ),
      ),
      'removed, signing in, no connection': () => welcome(
        start: const DeviceStart(phase: 'empty'),
        f: const ConnectionFacts(configured: false, signingIn: true),
      ),
      'connecting': () => welcome(f: const ConnectionFacts(busy: true)),
      'part-way': () => welcome(
        start: const DeviceStart(phase: 'restoring', pendingName: 'Amihan'),
      ),
      'setup': () => ProfileSetupPage(actions: FakeActions()),
      'setup, part-way': () => ProfileSetupPage(
        actions: FakeActions(
          start: const DeviceStart(
            phase: 'initializing',
            pendingName: 'Amihan',
          ),
        ),
      ),
      'opening': () => const OpeningScreen(),
      'greeting': () => GreetingPage(actions: FakeActions(), onStart: () {}),
      for (final state in DemoFirstRun.values)
        if (state.isGoogle)
          state.label: () => GooglePage(actions: DemoOnboarding(state)),
      'restore': () =>
          RestorePage(actions: DemoOnboarding(DemoFirstRun.restoreLocal)),
      for (final problem in StartupProblem.values)
        'failure ${problem.name}': () => StartupFailurePage(
          problem: problem,
          onRetry: () {},
          message: 'Words from a rule.',
          folder: r'C:\Users\Amihan\AppData\Roaming\Salapiya\local-v1',
        ),
    };
    for (final (platform, widths) in [
      (TargetPlatform.android, [320.0, 360.0, 412.0]),
      (TargetPlatform.windows, [720.0, 1200.0, 1440.0]),
    ]) {
      testWidgets('on ${platform.name}', (tester) async {
        for (final width in widths) {
          for (final scale in [1.0, 2.0]) {
            for (final brightness in Brightness.values) {
              for (final MapEntry(key: name, value: page) in pages.entries) {
                await show(
                  tester,
                  page(),
                  platform: platform,
                  brightness: brightness,
                  size: Size(width, 780),
                  scale: scale,
                );
                expect(
                  tester.takeException(),
                  isNull,
                  reason: '$name at $width, $scale, $brightness',
                );
              }
              for (final state in [
                DemoFirstRun.restoreConnected,
                DemoFirstRun.restoreOlder,
                DemoFirstRun.restoreHere,
              ]) {
                await show(
                  tester,
                  RestorePage(actions: DemoOnboarding(state)),
                  platform: platform,
                  brightness: brightness,
                  size: Size(width, 780),
                  scale: scale,
                );
                await throughRestore(tester);
                expect(
                  find.byKey(const ValueKey('restore-review')),
                  findsOneWidget,
                );
                expect(
                  tester.takeException(),
                  isNull,
                  reason: '$state at $width, $scale, $brightness',
                );
              }
            }
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });

  group('Google', () {
    FakeActions on(ConnectionFacts f) => FakeActions(f: f);

    testWidgets('starts with what happens next and Google\'s own button', (
      tester,
    ) async {
      final a = on(const ConnectionFacts());
      await show(tester, GooglePage(actions: a));
      expect(find.text('What happens next'), findsOneWidget);
      expect(find.textContaining('opens in your browser'), findsOneWidget);
      expect(find.textContaining('lists this device'), findsOneWidget);
      expect(find.text('What’s shared with the service'), findsOneWidget);
      expect(find.text(recordsCaption(RecordsView.google)), findsOneWidget);
      expect(find.byKey(const ValueKey('google-review')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('google-sign-in')));
      await tester.pump();
      expect(a.calls, ['connect']);
    });

    testWidgets('waiting offers only Cancel sign-in', (tester) async {
      final a = on(const ConnectionFacts(signingIn: true));
      await show(tester, GooglePage(actions: a));
      expect(find.text('Waiting for Google'), findsOneWidget);
      expect(find.byKey(const ValueKey('google-sign-in')), findsNothing);
      expect(find.byKey(const ValueKey('google-review')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('google-cancel')));
      await tester.pump();
      expect(a.calls, ['cancel']);
    });

    testWidgets('one review step, and Don\'t connect really leaves', (
      tester,
    ) async {
      final a = on(
        const ConnectionFacts(signedIn: true, email: 'amihan@example.com'),
      );
      await show(tester, GooglePage(actions: a));
      expect(find.text('Google account chosen'), findsOneWidget);
      expect(find.text('amihan@example.com'), findsOneWidget);
      expect(find.byKey(const ValueKey('google-review')), findsOneWidget);
      expect(find.text(recordsCaption(RecordsView.chosen)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('google-dont-connect')));
      await tester.pump();
      expect(a.calls, ['dontConnect']);
    });

    testWidgets('a new account names the profile, and keeps every fact', (
      tester,
    ) async {
      final a = on(
        const ConnectionFacts(signedIn: true, email: 'amihan@example.com'),
      );
      await show(tester, GooglePage(actions: a));
      await tester.tap(find.byKey(const ValueKey('google-review')));
      await tester.pumpAndSettle();
      expect(a.calls, ['lookup']);
      expect(find.text('Create a connected profile?'), findsOneWidget);
      expect(find.textContaining('named Amihan Reyes'), findsOneWidget);
      expect(find.textContaining('can’t become a local-only'), findsOneWidget);
      for (final fact in disclosureFacts) {
        expect(find.textContaining(fact), findsWidgets, reason: fact);
      }
      await tester.tap(find.text('Create profile'));
      await tester.pumpAndSettle();
      expect(a.calls, ['lookup', 'confirm']);
    });

    testWidgets('a profile found says so, and keeps every fact', (
      tester,
    ) async {
      final a = on(
        const ConnectionFacts(
          signedIn: true,
          email: 'amihan@example.com',
          cloudName: 'Household',
        ),
      );
      await show(tester, GooglePage(actions: a));
      await tester.tap(find.byKey(const ValueKey('google-review')));
      await tester.pumpAndSettle();
      expect(find.text('Use Household on this device?'), findsOneWidget);
      expect(find.textContaining('downloads to this device'), findsOneWidget);
      expect(find.textContaining('Devices'), findsOneWidget);
      for (final fact in disclosureFacts) {
        expect(find.textContaining(fact), findsWidgets, reason: fact);
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(a.calls, ['lookup']);
    });

    testWidgets('a refused lookup stops before the disclosure', (tester) async {
      final a = on(const ConnectionFacts(signedIn: true));
      a.lookupFacts = const ConnectionFacts(
        signedIn: true,
        error:
            'The connection dropped. Your records and waiting changes are '
            'safe. Try again when you’re connected.',
      );
      await show(tester, GooglePage(actions: a));
      await tester.tap(find.byKey(const ValueKey('google-review')));
      await tester.pumpAndSettle();
      expect(find.text('Create a connected profile?'), findsNothing);
      expect(find.textContaining('Nothing changed on this device'), findsOne);
      expect(find.textContaining('waiting changes'), findsNothing);
    });

    testWidgets('an error left from opening the app waits', (tester) async {
      final a = on(
        const ConnectionFacts(
          error:
              'Can’t connect right now. Your records are safe on this device.',
        ),
      );
      await show(tester, GooglePage(actions: a));
      expect(find.textContaining('connect right now'), findsNothing);
    });

    testWidgets('each way a sign-in ends reads without a profile', (
      tester,
    ) async {
      for (final (outcome, words) in [
        ('browser_launch_failed', 'Your browser didn’t open'),
        ('provider_cancelled', 'Nothing was uploaded'),
        ('late_callback_ignored', 'it was ignored'),
        ('expired_attempt_preserved_local_data', 'took too long'),
        ('callback_failed_local_data_preserved', 'didn’t finish'),
      ]) {
        await show(
          tester,
          GooglePage(actions: on(ConnectionFacts(signInOutcome: outcome))),
        );
        expect(find.textContaining(words), findsOneWidget, reason: outcome);
        expect(find.textContaining('haven’t changed'), findsNothing);
        expect(find.textContaining('are safe'), findsNothing);
      }
    });

    testWidgets('the page goes when the profile opens under it', (
      tester,
    ) async {
      final a = on(const ConnectionFacts(signedIn: true));
      var done = 0;
      await show(tester, GooglePage(actions: a, onDone: () => done++));
      a.opened = true;
      a.notifyListeners();
      await tester.pump();
      await tester.pump();
      a.notifyListeners();
      await tester.pump();
      expect(done, 1);
    });

    testWidgets('with nothing given, every first-run page closes', (
      tester,
    ) async {
      final a = on(const ConnectionFacts(signedIn: true));
      await show(tester, const SizedBox());
      Navigator.of(
        tester.element(find.byType(SizedBox).first),
      ).push(MaterialPageRoute<void>(builder: (_) => GooglePage(actions: a)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(GooglePage), findsOneWidget);
      a.opened = true;
      a.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(GooglePage), findsNothing);
    });

    testWidgets('a build that can\'t connect offers nothing', (tester) async {
      await show(
        tester,
        GooglePage(actions: on(const ConnectionFacts(configured: false))),
      );
      expect(find.byKey(const ValueKey('google-sign-in')), findsNothing);
      expect(find.textContaining('can’t connect to Google'), findsOneWidget);
    });
  });

  group('Restore', () {
    testWidgets('Back waits while a restore runs', (tester) async {
      final gate = Completer<void>();
      final a = FakeActions(
        open_: (_, _) async => OpenedBackup(
          const {},
          BackupContents(
            name: 'Amihan',
            created: '2026-10-30T01:02:03.000Z',
            records: 1,
            drafts: 0,
            lifeVersions: 0,
            filesListed: 0,
            connected: false,
            thisProfile: false,
          ),
          alreadyHere: false,
        ),
      )..gate = gate;
      await show(tester, const SizedBox(), size: const Size(1200, 900));
      Navigator.of(
        tester.element(find.byType(SizedBox).first),
      ).push(MaterialPageRoute<void>(builder: (_) => RestorePage(actions: a)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await throughRestore(tester);
      await tester.tap(find.byKey(const ValueKey('restore-confirm')));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Restore'));
      await tester.pump(const Duration(seconds: 1));
      expect(a.calls, ['restore']);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RestorePage), findsOneWidget);
      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Amihan is back on this device'), findsOneWidget);
      expect(find.textContaining('No files'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('First-run preview', () {
    testWidgets('moves between the real pages, and Back comes home', (
      tester,
    ) async {
      await show(tester, const FirstRunPreview());
      expect(find.byType(GreetingPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('greeting-start')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(WelcomePage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('welcome-google')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(GooglePage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump();
      expect(find.byType(WelcomePage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump();
      expect(find.byType(GreetingPage), findsOneWidget);
    });

    testWidgets('finishing a form comes home and says nothing happened', (
      tester,
    ) async {
      await show(tester, const FirstRunPreview(initial: DemoFirstRun.setup));
      await tester.enterText(find.byType(TextField).last, 'Amihan');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('setup-create')));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.textContaining('Demo: nothing happened'), findsOneWidget);
    });

    testWidgets('a theme shows as it\'s picked, and nothing keeps it', (
      tester,
    ) async {
      final settings = GallerySettings();
      addTearDown(settings.dispose);
      await show(
        tester,
        ListenableBuilder(
          listenable: settings,
          builder: (context, _) =>
              FirstRunPreview(initial: DemoFirstRun.setup, settings: settings),
        ),
      );
      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(settings.themeMode, ThemeMode.dark);
      await tester.tap(find.byKey(const ValueKey('setup-cancel')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Discard changes'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(settings.themeMode, ThemeMode.system);
    });

    testWidgets('shows every state', (tester) async {
      for (final state in DemoFirstRun.values) {
        await show(
          tester,
          FirstRunPreview(initial: state),
          size: const Size(1200, 900),
        );
        expect(tester.takeException(), isNull, reason: state.label);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a wrong secret shows on its field, in the demo too', (
      tester,
    ) async {
      await show(
        tester,
        RestorePage(actions: DemoOnboarding(DemoFirstRun.restoreWrongSecret)),
        size: const Size(1200, 900),
      );
      await tester.tap(find.byKey(const ValueKey('restore-choose')));
      await tester.pump();
      await tester.pump();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('backup-secret')),
          matching: find.byType(TextField),
        ),
        'anything',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('restore-open')));
      await tester.pump();
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('backup-secret')),
          matching: find.textContaining('doesn’t open this backup'),
        ),
        findsOneWidget,
      );
    });
  });

  group('Greeting', () {
    testWidgets('says what this is, and goes on to Welcome', (tester) async {
      var started = 0;
      await show(
        tester,
        GreetingPage(actions: FakeActions(), onStart: () => started++),
      );
      expect(find.bySemanticsLabel('Salapiya'), findsOneWidget);
      expect(find.textContaining('in one place'), findsOneWidget);
      expect(find.textContaining('never moves money'), findsOneWidget);
      // The sample has a Shared Expenses card too.
      for (final section in ['Money', 'Debts', 'Shared Expenses', 'Life']) {
        expect(find.text(section), findsWidgets, reason: section);
      }
      await tester.tap(find.byKey(const ValueKey('greeting-start')));
      await tester.pump();
      await tester.pump();
      expect(started, 1);
    });

    testWidgets('Windows shows the sample beside the words, level', (
      tester,
    ) async {
      await show(tester, GreetingPage(actions: FakeActions(), onStart: () {}));
      final preview = tester.getRect(
        find.byKey(const ValueKey('greeting-preview')),
      );
      final start = tester.getRect(
        find.byKey(const ValueKey('greeting-start')),
      );
      expect(preview.left, greaterThan(start.right));
      expect(preview.width, greaterThan(500));
      expect(find.text('Sample'), findsOneWidget);
    });

    testWidgets('the sample can\'t be pressed or read as real money', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await show(tester, GreetingPage(actions: FakeActions(), onStart: () {}));
      expect(
        find.bySemanticsLabel('A sample of Salapiya, with made-up figures.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('29,300')), findsNothing);
      expect(
        tester
            .widgetList<IgnorePointer>(
              find.ancestor(
                of: find.byKey(const ValueKey('greeting-preview')),
                matching: find.byType(IgnorePointer),
              ),
            )
            .any((w) => w.ignoring),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('a phone fits one screen, with nothing to scroll', (
      tester,
    ) async {
      // 640 tall fits too, in Geist. The test font is wider, and overflows it.
      for (final (width, height) in const [(360.0, 780.0), (412.0, 915.0)]) {
        await show(
          tester,
          GreetingPage(actions: FakeActions(), onStart: () {}),
          platform: TargetPlatform.android,
          size: Size(width, height),
        );
        for (final scroll in tester.stateList<ScrollableState>(
          find.byType(Scrollable),
        )) {
          // A wide amount may scroll sideways in the test's wider font.
          if (scroll.position.axis == Axis.horizontal) continue;
          expect(scroll.position.maxScrollExtent, 0, reason: '$height');
        }
        final start = tester.getRect(
          find.byKey(const ValueKey('greeting-start')),
        );
        expect(start.bottom, lessThanOrEqualTo(height));
      }
    });

    testWidgets('a phone keeps it simple, with no sample', (tester) async {
      await show(
        tester,
        GreetingPage(actions: FakeActions(), onStart: () {}),
        platform: TargetPlatform.android,
        size: const Size(360, 780),
      );
      expect(find.byKey(const ValueKey('greeting-preview')), findsNothing);
      expect(find.text('Shared Expenses'), findsOneWidget);
    });

    testWidgets('a screen too short still reaches everything', (tester) async {
      await show(
        tester,
        GreetingPage(actions: FakeActions(), onStart: () {}),
        platform: TargetPlatform.android,
        size: const Size(320, 480),
      );
      expect(tester.takeException(), isNull);
      final start = tester.getRect(
        find.byKey(const ValueKey('greeting-start')),
      );
      expect(start.bottom, lessThanOrEqualTo(480));
    });

    testWidgets('the amounts start level with their sparklines', (
      tester,
    ) async {
      await show(tester, GreetingPage(actions: FakeActions(), onStart: () {}));
      for (final amount in ['₱29,300.75', '₱18,214.50']) {
        final figure = tester.getRect(find.text(amount));
        final tile = find.ancestor(
          of: find.text(amount),
          matching: find.byType(KpiTile),
        );
        final line = tester.getRect(
          find.descendant(of: tile, matching: find.byType(Sparkline)),
        );
        expect(figure.top, lessThanOrEqualTo(line.top), reason: amount);
      }
    });

    testWidgets('large text says it in words instead', (tester) async {
      await show(
        tester,
        GreetingPage(actions: FakeActions(), onStart: () {}),
        platform: TargetPlatform.android,
        size: const Size(360, 780),
        scale: 2,
      );
      expect(find.byKey(const ValueKey('greeting-preview')), findsNothing);
      expect(find.text('Shared Expenses'), findsOneWidget);
    });

    testWidgets('a second press does nothing more', (tester) async {
      var started = 0;
      await show(
        tester,
        GreetingPage(actions: FakeActions(), onStart: () => started++),
      );
      final button = find.byKey(const ValueKey('greeting-start'));
      await tester.tap(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump();
      expect(started, 1);
    });

    testWidgets('a sign-in in progress skips it', (tester) async {
      for (final f in const [
        ConnectionFacts(signingIn: true),
        ConnectionFacts(signedIn: true),
        ConnectionFacts(busy: true),
      ]) {
        var started = 0;
        await show(
          tester,
          GreetingPage(
            actions: FakeActions(f: f),
            onStart: () => started++,
          ),
        );
        await tester.pump();
        expect(started, 1);
      }
    });

    testWidgets('one that starts while it\'s showing skips it too', (
      tester,
    ) async {
      final a = FakeActions();
      var started = 0;
      await show(tester, GreetingPage(actions: a, onStart: () => started++));
      expect(started, 0);
      a.note('late', const ConnectionFacts(signedIn: true));
      await tester.pump();
      await tester.pump();
      expect(started, 1);
    });

    testWidgets('a start that stopped part-way skips it', (tester) async {
      var started = 0;
      await show(
        tester,
        GreetingPage(
          actions: FakeActions(start: const DeviceStart(phase: 'initializing')),
          onStart: () => started++,
        ),
      );
      await tester.pump();
      expect(started, 1);
    });

    testWidgets('kept files and a removal still greet', (tester) async {
      var started = 0;
      await show(
        tester,
        GreetingPage(
          actions: FakeActions(
            start: const DeviceStart(phase: 'empty', keptFiles: true),
          ),
          onStart: () => started++,
        ),
      );
      await tester.pump();
      expect(started, 0);
    });

    testWidgets('Android\'s button takes the column\'s width', (tester) async {
      await show(
        tester,
        GreetingPage(actions: FakeActions(), onStart: () {}),
        platform: TargetPlatform.android,
        size: const Size(360, 780),
      );
      final button = tester.getRect(
        find.byKey(const ValueKey('greeting-start')),
      );
      expect(button.width, greaterThan(280));
    });
  });

  group('Welcome', () {
    testWidgets('offers all three ways on a new device', (tester) async {
      await show(tester, welcome());
      for (final key in [
        'welcome-local',
        'welcome-google',
        'welcome-restore',
      ]) {
        expect(tappable(tester, key), isTrue, reason: key);
      }
      expect(find.text('Your profile and your privacy'), findsOneWidget);
      expect(find.text('Where your records live'), findsOneWidget);
    });

    testWidgets('kept files turn Start off, name them and leave the rest', (
      tester,
    ) async {
      await show(
        tester,
        welcome(
          start: const DeviceStart(
            phase: 'empty',
            keptFiles: true,
            keptName: 'Amihan',
          ),
        ),
      );
      expect(tappable(tester, 'welcome-local'), isFalse);
      expect(tappable(tester, 'welcome-google'), isTrue);
      expect(tappable(tester, 'welcome-restore'), isTrue);
      expect(find.textContaining('Amihan’s files'), findsOneWidget);
    });

    testWidgets('a part-way start leaves only the way that carries on', (
      tester,
    ) async {
      var started = false;
      await show(
        tester,
        welcome(
          start: const DeviceStart(phase: 'restoring', pendingName: 'Amihan'),
          onStart: () => started = true,
        ),
      );
      expect(tappable(tester, 'welcome-google'), isFalse);
      expect(tappable(tester, 'welcome-restore'), isFalse);
      expect(find.textContaining('part-way set up'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('welcome-local')));
      await tester.pump();
      expect(started, isTrue);
    });

    testWidgets('a removal says what it left alone', (tester) async {
      await show(tester, welcome(start: const DeviceStart(phase: 'empty')));
      expect(find.textContaining('last profile on this device'), findsOne);
      await show(tester, welcome());
      expect(find.textContaining('last profile on this device'), findsNothing);
    });

    testWidgets('a build that can\'t connect doesn\'t offer Google', (
      tester,
    ) async {
      var opened = false;
      await show(
        tester,
        welcome(
          f: const ConnectionFacts(configured: false),
          onGoogle: () => opened = true,
        ),
      );
      expect(tappable(tester, 'welcome-google'), isFalse);
      expect(find.textContaining('can’t connect to Google'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('welcome-google')));
      await tester.pump();
      expect(opened, isFalse);
      expect(tappable(tester, 'welcome-restore'), isTrue);
    });

    testWidgets('a sign-in that carried over a restart shows, with a way on', (
      tester,
    ) async {
      var opened = false;
      await show(
        tester,
        welcome(
          f: const ConnectionFacts(signingIn: true),
          onGoogle: () => opened = true,
        ),
      );
      expect(find.text('You started signing in with Google.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('welcome-continue')));
      await tester.pump();
      expect(opened, isTrue);
    });

    testWidgets('being signed in says nothing has been uploaded', (
      tester,
    ) async {
      await show(tester, welcome(f: const ConnectionFacts(signedIn: true)));
      expect(find.textContaining('Nothing has been uploaded'), findsOneWidget);
    });

    testWidgets('nothing starts while Google is connecting', (tester) async {
      await show(tester, welcome(f: const ConnectionFacts(busy: true)));
      for (final key in [
        'welcome-local',
        'welcome-google',
        'welcome-restore',
      ]) {
        expect(tappable(tester, key), isFalse, reason: key);
      }
      expect(find.textContaining('Connecting to Google'), findsOneWidget);
    });

    testWidgets('hovering a choice shows it on the map, and nothing moves', (
      tester,
    ) async {
      await show(tester, welcome());
      expect(find.byKey(const ValueKey(RecordsView.local)), findsOneWidget);
      final map = find.byKey(const ValueKey('records-map'));
      final before = tester.getRect(map);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      for (final (key, view) in [
        ('welcome-google', RecordsView.google),
        ('welcome-restore', RecordsView.restore),
        ('welcome-local', RecordsView.local),
      ]) {
        await mouse.moveTo(tester.getCenter(find.byKey(ValueKey(key))));
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(ValueKey(view)), findsOneWidget, reason: key);
        expect(tester.getRect(map), before, reason: key);
      }
    });

    testWidgets('a keyboard shows it on the map too', (tester) async {
      await show(tester, welcome());
      final google = find.byKey(const ValueKey(RecordsView.google));
      for (var i = 0; i < 8 && google.evaluate().isEmpty; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump(const Duration(seconds: 1));
      }
      expect(google, findsOneWidget);
    });

    testWidgets('screen readers hear the whole sentence', (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester, welcome());
      expect(
        find.bySemanticsLabel(recordsWords(RecordsView.local, desktop: true)),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('Windows shows the map beside the choices, level with them', (
      tester,
    ) async {
      await show(tester, welcome());
      final map = tester.getRect(find.byKey(const ValueKey('records-map')));
      final choices = tester.getRect(
        find.byKey(const ValueKey('welcome-choices')),
      );
      final privacy = tester.getRect(
        find.byKey(const ValueKey('welcome-privacy')),
      );
      expect(map.left, greaterThan(choices.right));
      expect(map.top, choices.top);
      expect(map.bottom, privacy.bottom);
    });

    testWidgets('Android leads with the slim map and goes down the page', (
      tester,
    ) async {
      await show(
        tester,
        welcome(),
        platform: TargetPlatform.android,
        size: const Size(360, 1100),
      );
      expect(find.byKey(const ValueKey('records-map')), findsNothing);
      final map = tester.getRect(find.byType(RecordsMap));
      final choices = tester.getRect(
        find.byKey(const ValueKey('welcome-choices')),
      );
      final privacy = tester.getRect(
        find.byKey(const ValueKey('welcome-privacy')),
      );
      expect(map.bottom, lessThanOrEqualTo(choices.top));
      expect(choices.bottom, lessThanOrEqualTo(privacy.top));
    });

    testWidgets('holds no slogans, ids or emails', (tester) async {
      await show(tester, welcome());
      expect(find.textContaining('on your terms'), findsNothing);
      expect(find.textContaining('@'), findsNothing);
    });
  });

  group('Startup failure', () {
    StartupFailurePage failure({
      StartupProblem problem = StartupProblem.keyUnavailable,
      String? message,
      String? folder,
    }) => StartupFailurePage(
      problem: problem,
      onRetry: () {},
      message: message,
      folder: folder,
    );

    testWidgets('says what happened, what\'s safe and what to do', (
      tester,
    ) async {
      await show(tester, failure());
      expect(find.text('What happened'), findsOneWidget);
      expect(find.text('What’s safe'), findsOneWidget);
      expect(find.text('What you can do'), findsOneWidget);
      expect(find.byKey(const ValueKey('startup-retry')), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('offers nothing but Try again', (tester) async {
      await show(tester, failure());
      expect(find.text('Restore from backup'), findsNothing);
      expect(find.text('Start on this device'), findsNothing);
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('details stay hidden until asked, and show the folder', (
      tester,
    ) async {
      await show(
        tester,
        failure(message: 'Words from a rule.', folder: r'C:\Salapiya'),
      );
      expect(find.textContaining('Words from a rule.'), findsNothing);
      await tester.tap(find.text('Show details'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Words from a rule.'), findsOneWidget);
      expect(find.textContaining(r'C:\Salapiya'), findsOneWidget);
    });

    testWidgets('Android has no folder to show', (tester) async {
      await show(
        tester,
        failure(folder: '/data/user/0/dev.salapiya/files'),
        platform: TargetPlatform.android,
        size: const Size(360, 780),
      );
      expect(find.text('Show details'), findsNothing);
    });
  });

  group('Opening', () {
    testWidgets('says what it\'s doing, then that closing is safe', (
      tester,
    ) async {
      await show(tester, const OpeningScreen());
      expect(find.text('Opening Salapiya'), findsOneWidget);
      expect(find.textContaining('Nothing is lost'), findsNothing);
      await tester.pump(
        OpeningScreen.slowAfter - const Duration(milliseconds: 100),
      );
      expect(find.textContaining('Nothing is lost'), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Nothing is lost'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('LocalBootstrap', () {
    Future<void> boot(
      WidgetTester tester,
      GallerySettings settings,
      RuntimeOpener opener, {
      StartupReader? reader,
    }) => show(
      tester,
      LocalBootstrap(
        settings: settings,
        opener: opener,
        reader: reader ?? () async => const StartupFacts(),
      ),
    );

    testWidgets('a rule\'s refusal reaches the failure screen', (tester) async {
      final settings = GallerySettings();
      addTearDown(settings.dispose);
      await boot(
        tester,
        settings,
        (_) async => reject(
          'Your profile’s records aren’t on this device any more. Nothing '
          'was replaced with an empty profile.',
        ),
      );
      expect(find.text('Your records aren’t on this device'), findsOneWidget);
    });

    testWidgets('an exception\'s own text never shows', (tester) async {
      final settings = GallerySettings();
      addTearDown(settings.dispose);
      await boot(
        tester,
        settings,
        (_) async => throw Exception('PRAGMA key = "secret"'),
        reader: () async => const StartupFacts(folder: r'C:\Salapiya'),
      );
      expect(find.text('Salapiya couldn’t open your profile'), findsOneWidget);
      await tester.tap(find.text('Show details'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('PRAGMA'), findsNothing);
      expect(find.textContaining('secret'), findsNothing);
    });

    testWidgets('the saved stage decides the words', (tester) async {
      final settings = GallerySettings();
      addTearDown(settings.dispose);
      await boot(
        tester,
        settings,
        (_) async => throw const FileSystemExceptionLike(),
        reader: () async => const StartupFacts(phase: 'removing'),
      );
      expect(find.text('Removing this profile didn’t finish'), findsOneWidget);
    });

    testWidgets('a reader that fails still leaves the screen', (tester) async {
      final settings = GallerySettings();
      addTearDown(settings.dispose);
      await boot(
        tester,
        settings,
        (_) async => throw const FileSystemExceptionLike(),
        reader: () async => throw StateError('no folder'),
      );
      expect(find.text('Salapiya couldn’t open your profile'), findsOneWidget);
    });

    testWidgets('Try again opens again, and a good second try goes on', (
      tester,
    ) async {
      final settings = GallerySettings();
      addTearDown(settings.dispose);
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('salapiya-boot-'),
      ))!;
      addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
      final runtime = LocalRuntime(
        LocalProfiles(dir, MemoryProfileVault()),
        settings,
      );
      var tries = 0;
      await boot(tester, settings, (_) async {
        tries++;
        if (tries == 1) throw const FileSystemExceptionLike();
        return runtime;
      });
      expect(find.byKey(const ValueKey('startup-failure')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('startup-retry')));
      await tester.pump();
      await tester.pump();
      expect(tries, 2);
      expect(find.byType(GreetingPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('greeting-start')));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.byType(WelcomePage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Opening shows while it\'s opening', (tester) async {
      final settings = GallerySettings();
      addTearDown(settings.dispose);
      final never = Future<LocalRuntime>.delayed(
        const Duration(days: 1),
        () => throw StateError('unused'),
      );
      await boot(tester, settings, (_) => never);
      expect(find.byType(OpeningScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(days: 2));
    });
  });
}

class FileSystemExceptionLike implements Exception {
  const FileSystemExceptionLike();
}
