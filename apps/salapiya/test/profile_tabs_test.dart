import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/app/shell_navigation.dart';
import 'package:salapiya/connected/connection_view.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/local/local_runtime.dart';
import 'package:salapiya/local/local_store.dart';
import 'package:salapiya/p0/portable_recovery.dart';
import 'package:salapiya/profile/connection_pages.dart';
import 'package:salapiya/profile/connection_tab.dart';
import 'package:salapiya/profile/devices_tab.dart';
import 'package:salapiya/profile/profile_actions.dart';
import 'package:salapiya/profile/profile_data.dart';
import 'package:salapiya/profile/profile_demo.dart';
import 'package:salapiya/profile/profile_page.dart';
import 'package:salapiya/prototype/scenarios.dart';
import 'package:salapiya/shared/shared_hub.dart';

import 'local_money_journey.dart' show localWait;
import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

const windows = TargetPlatform.windows, android = TargetPlatform.android;

const sizes = [
  (android, 320.0),
  (android, 360.0),
  (android, 412.0),
  (windows, 720.0),
  (windows, 1200.0),
  (windows, 1440.0),
];

/// Stands in for the runtime, and remembers what it was asked.
class FakeActions extends DemoProfile {
  FakeActions(super.session, this.current);
  ConnectionFacts current;
  final calls = <String>[];
  List<Map<String, dynamic>> rows = const [];
  Object? devicesError, deleteError;
  bool signsInOnConnect = true;

  void update(ConnectionFacts next) {
    current = next;
    notifyListeners();
  }

  @override
  ConnectionFacts facts() => current;
  @override
  Future<void> connect() async => calls.add('connect');
  @override
  Future<void> lookup() async => calls.add('lookup');
  @override
  Future<void> confirmConnection() async => calls.add('confirm');
  @override
  Future<void> useCloudProfile() async => calls.add('use');
  @override
  Future<void> keepProfile() async => calls.add('keep');
  @override
  Future<void> signOut() async => calls.add('signOut');
  @override
  Future<void> syncNow() async => calls.add('sync');
  @override
  Future<void> setPaused(bool paused) async => calls.add('paused $paused');
  @override
  Future<void> send(String id) async => calls.add('send $id');
  @override
  Future<void> revoke(DeviceRow device) async => calls.add('revoke ${device.id}');
  @override
  Future<void> removeProfile() async => calls.add('remove');
  @override
  Future<List<Map<String, dynamic>>> devices() async {
    calls.add('devices');
    if (devicesError case final e?) throw e;
    return rows;
  }

  @override
  Future<bool> deleteAccount() async {
    calls.add('delete');
    if (deleteError case final e?) throw e;
    return false;
  }
}

const connected = ConnectionFacts(
  bound: 'connected',
  signedIn: true,
  email: 'mara@example.test',
  lastSync: '2026-11-01T02:14:00.000Z',
);

ConnectionFacts copy(
  ConnectionFacts f, {
  String? signInOutcome,
  bool? signingIn,
  bool? busy,
  bool? deleted,
  int? moneyWaiting,
}) => ConnectionFacts(
  bound: f.bound,
  signedIn: f.signedIn,
  signingIn: signingIn ?? f.signingIn,
  busy: busy ?? f.busy,
  email: f.email,
  lastSync: f.lastSync,
  deleted: deleted ?? f.deleted,
  signInOutcome: signInOutcome ?? f.signInOutcome,
  moneyWaiting: moneyWaiting ?? f.moneyWaiting,
);

Map<String, dynamic> device(
  String id, {
  bool current = false,
  bool active = true,
}) => {
  'session_id': '00000000-0000-4000-8000-00000000000$id',
  'label': current ? 'Windows installation' : 'Android installation',
  'current': current,
  'active': active,
  'revoked_at': null,
  'last_seen_at': '2026-11-01T02:14:00.000Z',
  'registered_at': '2026-10-01T02:14:00.000Z',
};

void main() {
  Future<void> app(
    WidgetTester tester,
    Widget child, {
    TargetPlatform platform = windows,
    double width = 1200,
    double text = 1,
    Brightness brightness = Brightness.light,
    double height = 3000,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
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
    GallerySettings settings,
    ProfileActions actions,
    String tab,
  ) => ProfilePage(
    key: UniqueKey(),
    session: session,
    settings: settings,
    tab: ValueNotifier(tab),
    actions: actions,
  );

  ({PrototypeSession session, GallerySettings settings}) demo() {
    final session = PrototypeSession();
    final settings = GallerySettings();
    addTearDown(() {
      session.dispose();
      settings.dispose();
    });
    return (session: session, settings: settings);
  }

  FakeActions fake(PrototypeSession session, ConnectionFacts facts) {
    final actions = FakeActions(session, facts);
    addTearDown(actions.dispose);
    return actions;
  }

  void clean(WidgetTester tester, String label) {
    final error = tester.takeException();
    expect(error, isNull, reason: '$label: $error');
  }

  Finder key(String name) => find.byKey(ValueKey(name));

  /// Types [phrase] and presses [label] in a typed confirmation.
  Future<void> confirmTyped(
    WidgetTester tester,
    String phrase,
    String label,
  ) async {
    await tester.enterText(key('typed-confirmation'), phrase);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, label));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String label) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, label)).onPressed !=
      null;

  group('sweep', () {
    testWidgets('Connection, in every state', (tester) async {
      final d = demo();
      final actions = DemoProfile(d.session);
      addTearDown(actions.dispose);
      for (final phase in ConnectionPhase.values) {
        actions.phase = phase;
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            await app(
              tester,
              page(d.session, d.settings, actions, 'Connection'),
              platform: platform,
              width: width,
              text: text,
            );
            await tester.pump();
            expect(find.text(phaseWords(actions.facts()).$1), findsWidgets);
            clean(tester, '$phase $platform $width $text');
          }
        }
      }
    });

    testWidgets('Devices, in every state', (tester) async {
      final d = demo();
      final actions = DemoProfile(d.session)..phase = ConnectionPhase.synced;
      addTearDown(actions.dispose);
      for (final state in DemoDevices.values) {
        actions.device = state;
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            await app(
              tester,
              page(d.session, d.settings, actions, 'Devices'),
              platform: platform,
              width: width,
              text: text,
            );
            await tester.pump();
            await tester.pump();
            clean(tester, '$state $platform $width $text');
          }
        }
      }
    });

    testWidgets('Backup & recovery, in every state', (tester) async {
      final d = demo();
      final actions = DemoProfile(d.session);
      addTearDown(actions.dispose);
      for (final state in DemoBackup.values) {
        actions.backup = state;
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            await app(
              tester,
              page(d.session, d.settings, actions, 'Backup & recovery'),
              platform: platform,
              width: width,
              text: text,
            );
            await tester.pump();
            await tester.pump();
            clean(tester, '$state $platform $width $text');
          }
        }
      }
    });

    testWidgets('both themes, hidden, incomplete and empty', (tester) async {
      final d = demo();
      final actions = DemoProfile(d.session)
        ..phase = ConnectionPhase.needsReview;
      addTearDown(actions.dispose);
      for (final tab in const ['Connection', 'Devices', 'Backup & recovery']) {
        for (final (platform, width) in sizes) {
          for (final brightness in Brightness.values) {
            await app(
              tester,
              page(d.session, d.settings, actions, tab),
              platform: platform,
              width: width,
              brightness: brightness,
            );
            await tester.pump();
            clean(tester, '$tab $platform $width $brightness');
          }
          d.session.togglePrivacy();
          await app(
            tester,
            page(d.session, d.settings, actions, tab),
            platform: platform,
            width: width,
          );
          await tester.pump();
          expect(find.textContaining('₱'), findsNothing);
          clean(tester, 'hidden $tab $platform $width');
          d.session.togglePrivacy();
        }
      }
      actions.phase = null;
      for (final scenario in [
        OverviewScenario.incomplete,
        OverviewScenario.empty,
      ]) {
        d.session.select(scenario);
        for (final tab in const [
          'Connection',
          'Devices',
          'Backup & recovery',
        ]) {
          await app(tester, page(d.session, d.settings, actions, tab));
          await tester.pump();
          expect(find.textContaining('₱'), findsNothing);
          clean(tester, '$scenario $tab');
        }
      }
      d.session.reset();
    });
  });

  group('Connection', () {
    Future<void> offers(
      WidgetTester tester,
      ConnectionFacts facts,
      List<String> expected,
    ) async {
      final d = demo();
      final actions = fake(d.session, facts);
      await app(tester, page(d.session, d.settings, actions, 'Connection'));
      for (final action in ConnectionAction.values) {
        expect(
          key('connection-${action.name}'),
          expected.contains(action.name) ? findsOneWidget : findsNothing,
          reason: action.name,
        );
      }
    }

    testWidgets('each state offers only what it allows', (tester) async {
      await offers(tester, const ConnectionFacts(), ['connect']);
      await offers(tester, const ConnectionFacts(configured: false), const []);
      await offers(tester, const ConnectionFacts(signingIn: true), [
        'cancelSignIn',
      ]);
      await offers(tester, const ConnectionFacts(signedIn: true), [
        'review',
        'dontConnect',
      ]);
      await offers(
        tester,
        const ConnectionFacts(signedIn: true, otherProfile: true),
        ['saveBackup', 'useCloudProfile', 'keepProfile'],
      );
      await offers(tester, const ConnectionFacts(bound: 'staged'), [
        'reconnect',
      ]);
      await offers(
        tester,
        const ConnectionFacts(bound: 'staged', signedIn: true),
        ['resumeConnection', 'cancelConnection'],
      );
      await offers(tester, const ConnectionFacts(bound: 'restored'), [
        'reconnect',
      ]);
      await offers(
        tester,
        const ConnectionFacts(bound: 'connected', expired: true),
        ['reconnect'],
      );
      await offers(tester, connected, ['syncNow']);
      await offers(
        tester,
        const ConnectionFacts(bound: 'connected', paused: true, signedIn: true),
        const [],
      );
    });

    testWidgets('signed out shows no switch and no Sign out', (tester) async {
      final d = demo();
      final actions = fake(
        d.session,
        const ConnectionFacts(bound: 'connected', expired: true),
      );
      await app(tester, page(d.session, d.settings, actions, 'Connection'));
      expect(key('connection-sync-switch'), findsNothing);
      expect(key('connection-sign-out'), findsNothing);
      expect(find.text('Signed out'), findsOneWidget);
    });

    testWidgets('Last synced reads in Manila, with no raw time', (
      tester,
    ) async {
      final d = demo();
      final actions = fake(d.session, connected);
      await app(tester, page(d.session, d.settings, actions, 'Connection'));
      expect(find.text('mara@example.test'), findsOneWidget);
      expect(find.textContaining('10:14 AM'), findsOneWidget);
      expect(find.textContaining('2026-11-01'), findsNothing);
      expect(find.textContaining('Z'), findsNothing);
    });

    testWidgets('the Google email shows on Connection and not on Profile', (
      tester,
    ) async {
      final d = demo();
      final actions = fake(d.session, connected);
      await app(tester, page(d.session, d.settings, actions, 'Profile'));
      expect(find.text('mara@example.test'), findsNothing);
    });

    testWidgets('Review connection checks the account, then discloses', (
      tester,
    ) async {
      final d = demo();
      final actions = fake(
        d.session,
        const ConnectionFacts(signedIn: true, email: 'mara@example.test'),
      );
      await app(tester, page(d.session, d.settings, actions, 'Connection'));
      await tester.tap(key('connection-review'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['lookup']);
      expect(find.text('Turn on sync?'), findsOneWidget);
      expect(find.textContaining('mara@example.test'), findsWidgets);
      expect(find.textContaining('end-to-end encrypted'), findsWidgets);
      expect(find.textContaining('Supabase and PowerSync'), findsOneWidget);
      await tester.tap(find.text('Turn on sync'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['lookup', 'confirm']);
    });

    testWidgets('a different profile stops at the tab, with no disclosure', (
      tester,
    ) async {
      final d = demo();
      final actions = _Colliding(d.session);
      addTearDown(actions.dispose);
      await app(tester, page(d.session, d.settings, actions, 'Connection'));
      await tester.tap(key('connection-review'));
      await tester.pumpAndSettle();
      expect(find.text('Turn on sync?'), findsNothing);
      expect(find.text('This account has a different profile'), findsOneWidget);
      expect(key('connection-useCloudProfile'), findsOneWidget);
    });

    testWidgets('Use that profile stays off until a backup is saved', (
      tester,
    ) async {
      final d = demo();
      final actions = fake(
        d.session,
        const ConnectionFacts(
          signedIn: true,
          otherProfile: true,
          cloudName: 'Other',
        ),
      );
      await app(tester, page(d.session, d.settings, actions, 'Connection'));
      expect(enabled(tester, 'Use that profile'), isFalse);
      await tester.tap(key('connection-keepProfile'));
      await tester.pump();
      expect(actions.calls, ['keep']);
    });

    testWidgets('a tab change doesn’t lose a saved backup', (tester) async {
      final d = demo();
      final actions = fake(
        d.session,
        const ConnectionFacts(signedIn: true, otherProfile: true),
      );
      await app(tester, page(d.session, d.settings, actions, 'Connection'));
      await tester.tap(key('connection-saveBackup'));
      await tester.pumpAndSettle();
      await tester.tap(key('backup-kept'));
      await tester.pump();
      await tester.tap(key('backup-save-file'));
      await tester.pumpAndSettle();
      await tester.tap(key('backup-done'));
      await tester.pumpAndSettle();
      await tester.tap(key('Devices'));
      await tester.pumpAndSettle();
      await tester.tap(key('Connection'));
      await tester.pumpAndSettle();
      expect(enabled(tester, 'Use that profile'), isTrue);
    });

    testWidgets('Sign out says what stays waiting', (tester) async {
      final d = demo();
      final actions = fake(d.session, copy(connected, moneyWaiting: 2));
      await app(tester, page(d.session, d.settings, actions, 'Connection'));
      await tester.tap(key('connection-sign-out'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 changes stay waiting'), findsOneWidget);
      expect(find.textContaining('records stay on this device'), findsOneWidget);
      expect(actions.calls, isEmpty);
      await tester.tap(find.widgetWithText(AppButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['signOut']);
    });

    testWidgets('the switch pauses and resumes, and needs no confirmation', (
      tester,
    ) async {
      final d = demo();
      final actions = fake(d.session, connected);
      await app(tester, page(d.session, d.settings, actions, 'Connection'));
      await tester.tap(key('connection-sync-switch'));
      await tester.pump();
      expect(actions.calls, ['paused true']);
    });

    testWidgets('group refusals say where they are, and Life’s link goes', (
      tester,
    ) async {
      final d = demo();
      final actions = fake(
        d.session,
        const ConnectionFacts(
          bound: 'connected',
          signedIn: true,
          sharedReview: 2,
        ),
      );
      await app(tester, page(d.session, d.settings, actions, 'Connection'));
      expect(find.textContaining('2 to check there'), findsOneWidget);
      // Nothing can clear them, so they don't hold the state on Needs review.
      expect(find.text('Synced'), findsOneWidget);
    });

    testWidgets('an error from a step shows on the tab', (tester) async {
      final d = demo();
      final actions = fake(
        d.session,
        const ConnectionFacts(
          bound: 'connected',
          signedIn: true,
          error: 'The connection dropped.',
        ),
      );
      await app(tester, page(d.session, d.settings, actions, 'Connection'));
      expect(find.text('The connection dropped.'), findsOneWidget);
    });
  });

  group('a change to check', () {
    testWidgets('sends under its own id, and only while nothing runs', (
      tester,
    ) async {
      final d = demo();
      final actions = DemoProfile(d.session)
        ..phase = ConnectionPhase.needsReview;
      addTearDown(actions.dispose);
      await app(tester, page(d.session, d.settings, actions, 'Connection'));
      final row = actions.reviews.last;
      await tester.tap(key('review-${row.id}'));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePage), findsOneWidget);
      await tester.tap(key('change-send'));
      await tester.pump();
      expect(actions.note, contains('nothing happened'));
    });

    testWidgets('a retry after a lost answer uses the same id', (tester) async {
      final d = demo();
      final actions = _Sending(d.session);
      addTearDown(actions.dispose);
      await app(tester, page(d.session, d.settings, actions, 'Connection'));
      final row = actions.reviews.last;
      await tester.tap(key('review-${row.id}'));
      await tester.pumpAndSettle();
      await tester.tap(key('change-send'));
      await tester.pump();
      await tester.tap(key('change-send'));
      await tester.pump();
      expect(actions.sent, [row.id, row.id]);
    });

    testWidgets('with amounts hidden, its page shows no figure', (
      tester,
    ) async {
      final d = demo();
      d.session.togglePrivacy();
      final actions = DemoProfile(d.session)
        ..phase = ConnectionPhase.needsReview;
      addTearDown(actions.dispose);
      await app(tester, page(d.session, d.settings, actions, 'Connection'));
      await tester.tap(key('review-${actions.reviews.first.id}'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('₱'), findsNothing);
      expect(find.text('Amount hidden'), findsOneWidget);
      expect(find.text('kind'), findsNothing);
    });
  });

  group('Devices', () {
    testWidgets('lists after the first frame, this device first', (
      tester,
    ) async {
      final d = demo();
      final actions = fake(d.session, connected)
        ..rows = [device('2'), device('1', current: true)];
      await app(tester, page(d.session, d.settings, actions, 'Devices'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['devices']);
      expect(find.text('This device'), findsOneWidget);
      expect(find.textContaining('2 active sign-ins'), findsOneWidget);
      final here = tester.getTopLeft(find.text('Windows')).dy;
      final other = tester.getTopLeft(find.text('Android')).dy;
      expect(here, lessThan(other));
      // No id, no raw time.
      expect(find.textContaining('00000000'), findsNothing);
      expect(find.textContaining('T02:14'), findsNothing);
    });

    testWidgets('an earlier sign-in never reads last seen null', (
      tester,
    ) async {
      final d = demo();
      final actions = fake(d.session, connected)
        ..rows = [
          {
            'session_id': '00000000-0000-4000-8000-000000000009',
            'label': 'Earlier sign-in; device unknown',
            'current': false,
            'active': true,
            'revoked_at': null,
            'last_seen_at': null,
            'registered_at': null,
          },
        ];
      await app(tester, page(d.session, d.settings, actions, 'Devices'));
      await tester.pumpAndSettle();
      expect(find.textContaining('null'), findsNothing);
      expect(find.textContaining('Not recorded'), findsWidgets);
    });

    testWidgets('offline says it needs a connection, and can try again', (
      tester,
    ) async {
      final d = demo();
      final actions = fake(d.session, connected)
        ..devicesError = StateError('offline');
      await app(tester, page(d.session, d.settings, actions, 'Devices'));
      await tester.pumpAndSettle();
      expect(find.textContaining('needs a connection'), findsOneWidget);
      actions
        ..devicesError = null
        ..rows = [device('1', current: true)];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('This device'), findsOneWidget);
    });

    testWidgets('signed out doesn’t reach for the list', (tester) async {
      final d = demo();
      final actions = fake(
        d.session,
        const ConnectionFacts(bound: 'connected', expired: true),
      );
      await app(tester, page(d.session, d.settings, actions, 'Devices'));
      await tester.pumpAndSettle();
      expect(actions.calls, isEmpty);
      expect(find.text('Sign in to see your devices'), findsOneWidget);
      expect(key('delete-account'), findsNothing);
    });

    testWidgets('a local profile has no list and only Remove', (tester) async {
      final d = demo();
      final actions = fake(d.session, const ConnectionFacts());
      await app(tester, page(d.session, d.settings, actions, 'Devices'));
      await tester.pumpAndSettle();
      expect(actions.calls, isEmpty);
      expect(key('devices-list'), findsNothing);
      expect(key('remove-profile'), findsOneWidget);
      expect(key('delete-account'), findsNothing);
    });

    testWidgets('Revoke needs its exact phrase', (tester) async {
      final d = demo();
      final actions = fake(d.session, connected)
        ..rows = [device('1', current: true), device('2')];
      await app(tester, page(d.session, d.settings, actions, 'Devices'));
      await tester.pumpAndSettle();
      await tester.tap(key('revoke-00000000-0000-4000-8000-000000000002'));
      await tester.pumpAndSettle();
      expect(find.text('Revoke this sign-in?'), findsOneWidget);
      expect(enabled(tester, 'Revoke sign-in'), isFalse);
      await tester.enterText(key('typed-confirmation'), 'revoke');
      await tester.pump();
      expect(enabled(tester, 'Revoke sign-in'), isFalse);
      await confirmTyped(tester, 'REVOKE', 'Revoke sign-in');
      expect(actions.calls, contains('revoke ${device('2')['session_id']}'));
      expect(find.textContaining('Sign-in revoked'), findsOneWidget);
    });

    testWidgets('revoking this device says it signs out too', (tester) async {
      final d = demo();
      final actions = fake(d.session, connected)
        ..rows = [device('1', current: true)];
      await app(tester, page(d.session, d.settings, actions, 'Devices'));
      await tester.pumpAndSettle();
      await tester.tap(key('revoke-00000000-0000-4000-8000-000000000001'));
      await tester.pumpAndSettle();
      expect(find.textContaining('This device signs out too'), findsOneWidget);
    });

    testWidgets('Delete takes a fresh sign-in, then its phrase', (tester) async {
      final d = demo();
      final actions = fake(d.session, connected);
      await app(tester, page(d.session, d.settings, actions, 'Devices'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Google again first'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);

      await tester.tap(key('delete-account'));
      await tester.pump();
      expect(actions.calls, contains('connect'));
      actions.update(copy(connected, signingIn: true));
      await tester.pump();
      expect(key('delete-cancel-sign-in'), findsOneWidget);
      actions.update(
        copy(connected, signInOutcome: 'google_code_exchange_verified'),
      );
      await tester.pump();
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(key('delete-account'));
      await tester.pumpAndSettle();
      expect(enabled(tester, 'Delete account'), isFalse);
      await confirmTyped(
        tester,
        'DELETE CONNECTED ACCOUNT',
        'Delete account',
      );
      expect(actions.calls, contains('delete'));
    });

    testWidgets('a sign-in that didn’t finish doesn’t open Delete', (
      tester,
    ) async {
      final d = demo();
      final actions = fake(d.session, connected);
      await app(tester, page(d.session, d.settings, actions, 'Devices'));
      await tester.pumpAndSettle();
      await tester.tap(key('delete-account'));
      await tester.pump();
      actions.update(copy(connected, signingIn: true));
      await tester.pump();
      actions.update(
        copy(connected, signInOutcome: 'cancelled_local_data_preserved'),
      );
      await tester.pump();
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Sign in again'), findsOneWidget);
    });

    testWidgets('Delete’s five minutes end by themselves', (tester) async {
      final d = demo();
      final actions = fake(d.session, connected);
      await app(tester, page(d.session, d.settings, actions, 'Devices'));
      await tester.pumpAndSettle();
      await tester.tap(key('delete-account'));
      await tester.pump();
      actions.update(copy(connected, signingIn: true));
      await tester.pump();
      actions.update(
        copy(connected, signInOutcome: 'google_code_exchange_verified'),
      );
      await tester.pump();
      expect(find.text('Delete'), findsOneWidget);
      await tester.pump(deleteWindow);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Sign in again'), findsOneWidget);
    });

    testWidgets('a lost answer asks for a fresh sign-in and no second send', (
      tester,
    ) async {
      final d = demo();
      final actions = fake(d.session, connected)
        ..deleteError = StateError('lost');
      await app(tester, page(d.session, d.settings, actions, 'Devices'));
      await tester.pumpAndSettle();
      await tester.tap(key('delete-account'));
      await tester.pump();
      actions.update(copy(connected, signingIn: true));
      await tester.pump();
      actions.update(
        copy(connected, signInOutcome: 'google_code_exchange_verified'),
      );
      await tester.pump();
      await tester.tap(key('delete-account'));
      await tester.pumpAndSettle();
      await confirmTyped(
        tester,
        'DELETE CONNECTED ACCOUNT',
        'Delete account',
      );
      expect(actions.calls.where((c) => c == 'delete'), hasLength(1));
      expect(find.textContaining('couldn’t confirm the deletion'), findsOneWidget);
      expect(find.text('Sign in again'), findsOneWidget);
    });

    testWidgets('after deletion, only Remove is left', (tester) async {
      final d = demo();
      final actions = fake(d.session, copy(connected, deleted: true));
      await app(tester, page(d.session, d.settings, actions, 'Devices'));
      await tester.pumpAndSettle();
      expect(key('devices-list'), findsNothing);
      expect(key('delete-account'), findsNothing);
      expect(key('remove-profile'), findsOneWidget);
      await tester.tap(key('Connection'));
      await tester.pumpAndSettle();
      expect(find.text('Connected account deleted'), findsOneWidget);
      for (final action in ConnectionAction.values) {
        expect(key('connection-${action.name}'), findsNothing);
      }
    });

    testWidgets('Remove counts what’s waiting, and waits for a request', (
      tester,
    ) async {
      final d = demo();
      final actions = fake(d.session, copy(connected, moneyWaiting: 3));
      await app(tester, page(d.session, d.settings, actions, 'Devices'));
      await tester.pumpAndSettle();
      await tester.tap(key('remove-profile'));
      await tester.pumpAndSettle();
      expect(find.textContaining('3 waiting changes'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      actions.update(copy(connected, busy: true));
      await tester.pumpAndSettle();
      expect(key('remove-profile'), findsNothing);
      expect(find.textContaining('current request'), findsOneWidget);
    });
  });

  group('Backup & recovery', () {
    Future<void> withProfile(
      WidgetTester tester,
      Future<void> Function(LocalRuntime, GallerySettings) body,
    ) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('salapiya-backup-ui-'),
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

    Widget real(
      LocalRuntime runtime,
      GallerySettings settings,
      LocalProfileActions actions,
    ) => ProfilePage(
      key: UniqueKey(),
      session: runtime.session!,
      settings: settings,
      tab: ValueNotifier('Backup & recovery'),
      actions: actions,
    );

    Future<void> untilSecret(WidgetTester tester) => localWait(
      tester,
      () => tester
          .widget<TextField>(
            find.descendant(
              of: key('backup-secret'),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text
          .isNotEmpty,
    );

    testWidgets('a save goes through its steps and clears the secret', (
      tester,
    ) async {
      await withProfile(tester, (runtime, settings) async {
        Uint8List? sealed;
        final actions = LocalProfileActions(
          runtime.session!,
          saver: (name, bytes) async {
            sealed = bytes;
            return Uri.file(name);
          },
        );
        await app(tester, real(runtime, settings, actions), height: 1200);
        await localWait(
          tester,
          () => find.text('No backup on this device yet').evaluate().isNotEmpty,
        );
        await tester.tap(key('backup-save'));
        await tester.pumpAndSettle();
        await untilSecret(tester);

        final field = tester.widget<TextField>(
          find.descendant(
            of: key('backup-secret'),
            matching: find.byType(TextField),
          ),
        );
        final secret = field.controller!.text;
        // Masked, and kept from the keyboard's learning.
        expect(field.obscureText, isTrue);
        expect(field.enableIMEPersonalizedLearning, isFalse);
        expect(field.autocorrect, isFalse);
        expect(field.enableSuggestions, isFalse);
        expect(enabled(tester, 'Save backup'), isFalse);

        await tester.tap(key('backup-secret-show'));
        await tester.pump();
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: key('backup-secret'),
                  matching: find.byType(TextField),
                ),
              )
              .obscureText,
          isFalse,
        );
        // Leaving the app hides it again.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: key('backup-secret'),
                  matching: find.byType(TextField),
                ),
              )
              .obscureText,
          isTrue,
        );

        await tester.tap(key('backup-kept'));
        await tester.pump();
        await tester.tap(key('backup-save-file'));
        await localWait(
          tester,
          () => key('backup-saved').evaluate().isNotEmpty,
        );
        expect(find.textContaining(secret), findsNothing);
        expect(find.byType(EditableText), findsNothing);

        // The file opens with that secret, and holds the profile.
        final opened = await tester.runAsync(
          () => LocalBackup.unseal(sealed!, secret),
        );
        expect(opened!['name'], 'Rendel');

        // The secret went nowhere durable.
        final store = runtime.session!.localFinance.store;
        final drafts = await tester.runAsync(store.drafts);
        expect('$drafts', isNot(contains(secret)));
        final preferences = await tester.runAsync(store.preferences);
        expect('$preferences', isNot(contains(secret)));

        await tester.tap(key('backup-done'));
        await localWait(
          tester,
          () => find.textContaining('Last backup').evaluate().isNotEmpty,
        );
        expect(find.text('Nothing has changed since.'), findsOneWidget);
      });
    });

    testWidgets('closing the save window records nothing', (tester) async {
      await withProfile(tester, (runtime, settings) async {
        final actions = LocalProfileActions(
          runtime.session!,
          saver: (_, _) async => null,
        );
        await app(tester, real(runtime, settings, actions), height: 1200);
        await tester.tap(key('backup-save'));
        await tester.pumpAndSettle();
        await untilSecret(tester);
        await tester.tap(key('backup-kept'));
        await tester.pump();
        await tester.tap(key('backup-save-file'));
        await localWait(
          tester,
          () => find.textContaining('Not saved').evaluate().isNotEmpty,
        );
        final store = runtime.session!.localFinance.store;
        expect(await tester.runAsync(store.lastBackup), isNull);
      });
    });

    testWidgets('a bad secret you typed errors on its field', (tester) async {
      await withProfile(tester, (runtime, settings) async {
        final actions = LocalProfileActions(
          runtime.session!,
          saver: (_, _) async => Uri.file('x'),
        );
        await app(tester, real(runtime, settings, actions), height: 1200);
        await tester.tap(key('backup-save'));
        await tester.pumpAndSettle();
        await untilSecret(tester);
        await tester.tap(find.text('One I have'));
        await tester.pump();
        await tester.enterText(
          find.descendant(
            of: key('backup-secret'),
            matching: find.byType(TextField),
          ),
          'c2hvcnQ=',
        );
        await tester.pump();
        await tester.tap(key('backup-kept'));
        await tester.pump();
        await tester.tap(key('backup-save-file'));
        await localWait(
          tester,
          () => find.text('Enter the whole recovery secret.').evaluate().isNotEmpty,
        );
        expect(key('backup-saved'), findsNothing);
      });
    });

    testWidgets('the partial warning shows until the download is done', (
      tester,
    ) async {
      final d = demo();
      d.session.select(OverviewScenario.incomplete);
      final actions = DemoProfile(d.session);
      addTearDown(actions.dispose);
      await app(
        tester,
        page(d.session, d.settings, actions, 'Backup & recovery'),
      );
      await tester.tap(key('backup-save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('only what has downloaded'), findsOneWidget);
      d.session.reset();
    });

    testWidgets('Copy reaches the clipboard, and says to clear it', (
      tester,
    ) async {
      final d = demo();
      final actions = DemoProfile(d.session);
      addTearDown(actions.dispose);
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
      await app(
        tester,
        page(d.session, d.settings, actions, 'Backup & recovery'),
      );
      await tester.tap(key('backup-save'));
      await tester.pumpAndSettle();
      await tester.tap(key('backup-secret-copy'));
      await tester.pumpAndSettle();
      expect(copied, await actions.newSecret());
      expect(find.textContaining('Clear your clipboard'), findsOneWidget);
    });

    group('Check a backup', () {
      Future<(String, Uint8List)> sealed(LocalRuntime runtime) async {
        final secret = await PortableRecovery.newRecoverySecret();
        final store = runtime.session!.localFinance.store;
        return (
          secret,
          await LocalBackup.seal(await LocalBackup.capture(store), secret),
        );
      }

      Future<void> enter(WidgetTester tester, String secret) async {
        await tester.enterText(
          find.descendant(
            of: key('backup-secret'),
            matching: find.byType(TextField),
          ),
          secret,
        );
        await tester.pump();
      }

      testWidgets('says what’s inside, and changes nothing', (tester) async {
        await withProfile(tester, (runtime, settings) async {
          final (secret, bytes) = (await tester.runAsync(
            () => sealed(runtime),
          ))!;
          final actions = LocalProfileActions(
            runtime.session!,
            picker: () async => bytes,
          );
          await app(tester, real(runtime, settings, actions), height: 1500);
          await tester.tap(key('backup-check'));
          await tester.pumpAndSettle();
          await enter(tester, secret);
          await tester.tap(key('backup-choose'));
          await localWait(
            tester,
            () => key('backup-contents').evaluate().isNotEmpty,
          );
          expect(find.text('It’s a backup of this profile'), findsOneWidget);
          expect(find.text('Rendel'), findsOneWidget);
          expect(find.text('No files listed'), findsOneWidget);
          // No raw time, format number or profile id.
          expect(find.textContaining('T0'), findsNothing);
          expect(find.textContaining('format'), findsNothing);
          expect(
            find.textContaining(runtime.session!.localFinance.store.owner),
            findsNothing,
          );
          expect(find.textContaining('never replaces'), findsOneWidget);
          final store = runtime.session!.localFinance.store;
          expect(await tester.runAsync(store.lastBackup), isNull);
        });
      });

      testWidgets('a wrong secret errors on its field', (tester) async {
        await withProfile(tester, (runtime, settings) async {
          final (_, bytes) = (await tester.runAsync(() => sealed(runtime)))!;
          final other = (await tester.runAsync(
            PortableRecovery.newRecoverySecret,
          ))!;
          final actions = LocalProfileActions(
            runtime.session!,
            picker: () async => bytes,
          );
          await app(tester, real(runtime, settings, actions), height: 1500);
          await tester.tap(key('backup-check'));
          await tester.pumpAndSettle();
          await enter(tester, other);
          await tester.tap(key('backup-choose'));
          final refused = find.text('This secret doesn’t open this backup.');
          await localWait(tester, () => refused.evaluate().isNotEmpty);
          expect(key('backup-contents'), findsNothing);
        });
      });

      testWidgets('a file that isn’t a backup says so, off the secret', (
        tester,
      ) async {
        await withProfile(tester, (runtime, settings) async {
          final secret = (await tester.runAsync(
            PortableRecovery.newRecoverySecret,
          ))!;
          final actions = LocalProfileActions(
            runtime.session!,
            picker: () async => List.filled(64, 1),
          );
          await app(tester, real(runtime, settings, actions), height: 1500);
          await tester.tap(key('backup-check'));
          await tester.pumpAndSettle();
          await enter(tester, secret);
          await tester.tap(key('backup-choose'));
          final refused = find.text('This file isn’t a complete Salapiya backup.');
          await localWait(tester, () => refused.evaluate().isNotEmpty);
        });
      });

      testWidgets('closing the file window does nothing', (tester) async {
        await withProfile(tester, (runtime, settings) async {
          final actions = LocalProfileActions(
            runtime.session!,
            picker: () async => null,
          );
          await app(tester, real(runtime, settings, actions), height: 1500);
          await tester.tap(key('backup-check'));
          await tester.pumpAndSettle();
          expect(enabled(tester, 'Choose backup file'), isFalse);
          await enter(tester, 'anything');
          await tester.tap(key('backup-choose'));
          await tester.pumpAndSettle();
          expect(key('backup-contents'), findsNothing);
          expect(tester.takeException(), isNull);
        });
      });
    });
  });

  group('the demo', () {
    testWidgets('Show a state is on the three tabs, and changes the tab', (
      tester,
    ) async {
      final d = demo();
      for (final tab in const ['Connection', 'Devices', 'Backup & recovery']) {
        await app(
          tester,
          ProfilePage(
            key: UniqueKey(),
            session: d.session,
            settings: d.settings,
            tab: ValueNotifier(tab),
          ),
        );
        expect(find.text('Show a state'), findsWidgets, reason: tab);
      }
      await app(
        tester,
        ProfilePage(
          key: UniqueKey(),
          session: d.session,
          settings: d.settings,
          tab: ValueNotifier('Help'),
        ),
      );
      expect(find.text('Show a state'), findsNothing);
    });

    testWidgets('a real profile never shows it', (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('salapiya-real-ui-'),
      ))!;
      final settings = GallerySettings();
      final runtime = LocalRuntime(
        LocalProfiles(directory, MemoryProfileVault()),
        settings,
      );
      await tester.runAsync(() => runtime.create('Rendel', ThemeMode.system));
      await app(
        tester,
        ProfilePage(
          session: runtime.session!,
          settings: settings,
          tab: ValueNotifier('Connection'),
        ),
      );
      expect(find.text('Show a state'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await closeWithWidgetClock(tester, runtime.close);
      runtime.dispose();
      settings.dispose();
      await tester.runAsync(() => directory.delete(recursive: true));
    });
  });

  group('a Review link', () {
    testWidgets('goes where the bell goes when the shell is there', (
      tester,
    ) async {
      final d = demo();
      final hub = SharedHub(d.session);
      addTearDown(hub.dispose);
      var opened = 0;
      hub.openConnection = () => opened++;
      final runtime = LocalRuntime(
        LocalProfiles(Directory.systemTemp, MemoryProfileVault()),
        d.settings,
      );
      addTearDown(runtime.dispose);
      await app(
        tester,
        SharedScope(
          hub: hub,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => openConnection(context, runtime),
              child: const Text('Review'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review'));
      await tester.pump();
      expect(opened, 1);
    });
  });

  group('the bell', () {
    Future<void> shell(
      WidgetTester tester,
      Future<void> Function(LocalRuntime) body,
    ) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('salapiya-bell-ui-'),
      ))!;
      final settings = GallerySettings();
      final runtime = LocalRuntime(
        LocalProfiles(directory, MemoryProfileVault()),
        settings,
      );
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
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

    testWidgets('waiting and review open Connection', (tester) async {
      await shell(tester, (runtime) async {
        runtime.connected
          ..pendingCount = 1
          ..reviewCount = 1
          ..changed();
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(ShellSidebar),
            matching: find.text('Sync needs review'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ConnectionTab), findsOneWidget);
      });
    });

    testWidgets('only Life’s refused edits open Changes to check', (
      tester,
    ) async {
      await shell(tester, (runtime) async {
        runtime.connected
          ..reviewCount = 0
          ..lifeReviewCount = 1
          ..changed();
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(ShellSidebar),
            matching: find.text('Sync needs review'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ConnectionTab), findsNothing);
        expect(find.text('Changes to check'), findsWidgets);
      });
    });
  });
}

/// Finds a different profile while looking the account up.
class _Colliding extends FakeActions {
  _Colliding(PrototypeSession session)
    : super(session, const ConnectionFacts(signedIn: true));
  @override
  Future<void> lookup() async => update(
    const ConnectionFacts(
      signedIn: true,
      otherProfile: true,
      cloudName: 'Other',
    ),
  );
}

/// Records every send, as a retry after a lost answer would make.
class _Sending extends DemoProfile {
  _Sending(super.session) {
    phase = ConnectionPhase.needsReview;
  }
  final sent = <String>[];
  @override
  Future<void> send(String id) async => sent.add(id);
}
