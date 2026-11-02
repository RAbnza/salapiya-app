import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/local/local_store.dart';
import 'package:salapiya/profile/profile_data.dart';

import 'local_test_support.dart';

const signedIn = ConnectionFacts(bound: 'connected', signedIn: true);

ConnectionFacts bound(
  String phase, {
  bool signed = true,
  bool expired = false,
  bool paused = false,
  bool busy = false,
  bool active = false,
  bool reachable = true,
  int waiting = 0,
  int review = 0,
  bool enrollment = false,
}) => ConnectionFacts(
  bound: phase,
  signedIn: signed,
  expired: expired,
  paused: paused,
  busy: busy,
  active: active,
  reachable: reachable,
  moneyWaiting: waiting,
  moneyReview: review,
  enrollment: enrollment,
);

void main() {
  group('phaseOf', () {
    test('with no connection', () {
      expect(phaseOf(const ConnectionFacts()), ConnectionPhase.local);
      expect(
        phaseOf(const ConnectionFacts(configured: false)),
        ConnectionPhase.unavailable,
      );
      expect(
        phaseOf(const ConnectionFacts(signingIn: true)),
        ConnectionPhase.signingIn,
      );
      expect(
        phaseOf(const ConnectionFacts(signedIn: true)),
        ConnectionPhase.chosen,
      );
      expect(
        phaseOf(const ConnectionFacts(signedIn: true, otherProfile: true)),
        ConnectionPhase.otherProfile,
      );
    });

    test('each stage of a connection', () {
      expect(phaseOf(bound('staged')), ConnectionPhase.unfinished);
      expect(phaseOf(bound('restored')), ConnectionPhase.restoring);
      expect(phaseOf(bound('published')), ConnectionPhase.firstDownload);
      expect(phaseOf(bound('connected')), ConnectionPhase.synced);
    });

    test('a connected profile, worst first', () {
      expect(
        phaseOf(bound('connected', expired: true, paused: true, waiting: 3)),
        ConnectionPhase.signedOut,
      );
      expect(
        phaseOf(bound('connected', paused: true, active: true)),
        ConnectionPhase.paused,
      );
      expect(
        phaseOf(bound('connected', active: true, reachable: false)),
        ConnectionPhase.syncing,
      );
      expect(phaseOf(bound('connected', busy: true)), ConnectionPhase.syncing);
      expect(
        phaseOf(bound('connected', reachable: false, waiting: 2, review: 1)),
        ConnectionPhase.unreachable,
      );
      expect(
        phaseOf(bound('connected', waiting: 2, review: 1)),
        ConnectionPhase.waiting,
      );
      expect(
        phaseOf(bound('connected', review: 1)),
        ConnectionPhase.needsReview,
      );
    });

    test('an unfinished connection isn’t reported as signed out', () {
      expect(
        phaseOf(bound('staged', signed: false, expired: true)),
        ConnectionPhase.unfinished,
      );
      expect(
        phaseOf(bound('restored', signed: false, expired: true)),
        ConnectionPhase.restoring,
      );
    });

    test('a deleted account outranks everything', () {
      expect(
        phaseOf(
          const ConnectionFacts(
            deleted: true,
            bound: 'connected',
            expired: true,
            paused: true,
          ),
        ),
        ConnectionPhase.deleted,
      );
    });

    test('a group refusal alone can’t hold the state on Needs review', () {
      const f = ConnectionFacts(
        bound: 'connected',
        signedIn: true,
        sharedReview: 3,
      );
      expect(phaseOf(f), ConnectionPhase.synced);
      expect(f.toCheck, 0);
    });
  });

  group('offered', () {
    test('a local profile can only connect, and nothing to cancel', () {
      expect(offered(const ConnectionFacts()), [ConnectionAction.connect]);
    });

    test('this build can’t connect, so it offers nothing', () {
      expect(offered(const ConnectionFacts(configured: false)), isEmpty);
      expect(
        offered(const ConnectionFacts(configured: false, bound: 'connected')),
        isEmpty,
      );
    });

    test('signed out offers only signing in', () {
      final f = bound('connected', expired: true, waiting: 2);
      expect(offered(f), [ConnectionAction.reconnect]);
      expect(canManageSync(f), isFalse);
    });

    test('an unfinished connection needs the account that started it', () {
      expect(offered(bound('staged', signed: false)), [
        ConnectionAction.reconnect,
      ]);
      expect(offered(bound('staged')), [
        ConnectionAction.resumeConnection,
        ConnectionAction.cancelConnection,
      ]);
    });

    test('a restored backup finishes the way it can', () {
      expect(offered(bound('restored', signed: false)), [
        ConnectionAction.reconnect,
      ]);
      expect(offered(bound('restored')), [ConnectionAction.syncNow]);
      expect(offered(bound('restored', enrollment: true)), [
        ConnectionAction.resumeConnection,
      ]);
    });

    test('paused, syncing and deleted offer no main action', () {
      expect(offered(bound('connected', paused: true)), isEmpty);
      expect(offered(bound('connected', active: true)), isEmpty);
      expect(offered(const ConnectionFacts(deleted: true)), isEmpty);
    });

    test('every state with a sign-in can pause and sign out', () {
      for (final f in [
        bound('published'),
        bound('connected'),
        bound('connected', paused: true),
        bound('connected', active: true),
        bound('connected', reachable: false),
        bound('connected', waiting: 1),
        bound('connected', review: 1),
      ]) {
        expect(canManageSync(f), isTrue, reason: '${phaseOf(f)}');
      }
      for (final f in [
        const ConnectionFacts(),
        const ConnectionFacts(signedIn: true),
        bound('staged'),
        bound('restored'),
        const ConnectionFacts(deleted: true, bound: 'connected'),
      ]) {
        expect(canManageSync(f), isFalse, reason: '${phaseOf(f)}');
      }
    });

    test('every phase has words', () {
      for (final f in [
        const ConnectionFacts(),
        const ConnectionFacts(configured: false),
        const ConnectionFacts(signingIn: true),
        const ConnectionFacts(signedIn: true),
        const ConnectionFacts(otherProfile: true),
        bound('staged'),
        bound('published'),
        bound('restored'),
        bound('connected', expired: true),
        bound('connected', paused: true),
        bound('connected', busy: true),
        bound('connected', reachable: false),
        bound('connected', waiting: 1),
        bound('connected', review: 1),
        signedIn,
        const ConnectionFacts(deleted: true),
      ]) {
        final (headline, why) = phaseWords(f);
        expect(headline, isNotEmpty);
        expect(why, isNotEmpty);
      }
      expect(phaseWords(bound('connected', waiting: 1)).$1, '1 change waiting');
      expect(
        phaseWords(bound('connected', waiting: 3)).$1,
        '3 changes waiting',
      );
    });
  });

  group('sign-in notes', () {
    test('only what needs saying', () {
      for (final quiet in [
        null,
        'ready',
        'google_code_exchange_verified',
        'waiting_for_google',
      ]) {
        expect(signInNote(quiet), isNull);
      }
      expect(
        signInNote('wrong_account_local_data_preserved'),
        contains('different Google account'),
      );
      expect(signInNote('provider_cancelled'), contains('cancelled'));
      expect(signInNote('browser_launch_failed'), contains('didn’t finish'));
    });
  });

  test('counts read in plain words', () {
    expect(countsLine(0, 0), 'Up to date');
    expect(countsLine(2, 0), '2 waiting');
    expect(countsLine(0, 1), '1 to check');
    expect(countsLine(2, 1), '2 waiting · 1 to check');
  });

  group('manilaWhen', () {
    const today = '2026-11-02';
    test('today and yesterday, in Manila', () {
      expect(
        manilaWhen('2026-11-02T02:14:00.000Z', today: today),
        'Today, 10:14 AM',
      );
      // Before midnight in UTC is already today in Manila.
      expect(
        manilaWhen('2026-11-01T16:30:00.000Z', today: today),
        'Today, 12:30 AM',
      );
      expect(
        manilaWhen('2026-11-01T15:59:00.000Z', today: today),
        'Yesterday, 11:59 PM',
      );
    });

    test('noon, and across a month and a year', () {
      expect(
        manilaWhen('2026-11-02T04:00:00.000Z', today: today),
        'Today, 12:00 PM',
      );
      expect(
        manilaWhen('2026-10-31T16:00:00.000Z', today: '2026-11-02'),
        'Yesterday, 12:00 AM',
      );
      expect(
        manilaWhen('2025-12-31T16:00:00.000Z', today: '2026-01-02'),
        'Yesterday, 12:00 AM',
      );
      expect(
        manilaWhen('2026-10-20T04:05:00.000Z', today: today),
        contains('12:05 PM'),
      );
      expect(
        manilaWhen('2026-10-20T04:05:00.000Z', today: today),
        contains('2026'),
      );
    });

    test('nothing recorded never reads as a time', () {
      expect(manilaWhen(null), notRecorded);
      expect(manilaWhen('not a date'), notRecorded);
    });
  });

  group('deviceRows', () {
    const today = '2026-11-02';
    Map<String, dynamic> row(
      String id,
      String label, {
      bool current = false,
      bool active = true,
      String? revoked,
      String? seen,
      String? registered,
    }) => {
      'session_id': id,
      'label': label,
      'current': current,
      'active': active,
      'revoked_at': revoked,
      'last_seen_at': seen,
      'registered_at': registered,
    };

    test('this device, then active, then ended', () {
      final rows = deviceRows([
        row('a', 'Android installation', active: false),
        row('b', 'Android installation'),
        row('c', 'Windows installation', current: true),
      ], today: today);
      expect(rows.map((r) => r.id), ['c', 'b', 'a']);
      expect(rows.map((r) => r.status), [
        'This device',
        'Active',
        'Signed out',
      ]);
      expect(rows.map((r) => r.name), ['Windows', 'Android', 'Android']);
    });

    test('revoked reads differently from signed out', () {
      final rows = deviceRows([
        row('a', 'Android installation', active: false, revoked: '2026-11-01'),
      ], today: today);
      expect(rows.single.status, 'Revoked');
    });

    test('an earlier sign-in has no dates, and says so', () {
      final r = deviceRows([
        row('a', 'Earlier sign-in; device unknown'),
      ], today: today).single;
      expect(r.unknown, isTrue);
      expect(r.name, 'Earlier sign-in');
      expect(r.lastSeen, notRecorded);
      expect(r.signedIn, notRecorded);
    });

    test('an empty list is empty', () {
      expect(deviceRows(const []), isEmpty);
    });
  });

  group('backups', () {
    test('files read as listed, never as included', () {
      expect(filesLine(0), 'No files listed');
      expect(filesLine(1), contains('1 file listed, 0 files included'));
      expect(filesLine(4), contains('4 files listed, 0 files included'));
      expect(filesLine(null), 'Not available in this backup');
    });

    test('contents come from the backup itself', () {
      final bundle = <String, dynamic>{
        'name': 'Rendel',
        'createdUtc': '2026-11-01T00:00:00.000Z',
        'commands': [1, 2, 3],
        'drafts': [1],
        'format': 3,
        'owner': 'me',
        'life': {
          'revisions': [1, 2],
        },
        'financialCoverage': {'supportingFileMetadata': 2},
      };
      final found = BackupContents.from(bundle, 'me');
      expect(found.records, 3);
      expect(found.drafts, 1);
      expect(found.lifeVersions, 2);
      expect(found.filesListed, 2);
      expect(found.connected, isTrue);
      expect(found.thisProfile, isTrue);
      expect(BackupContents.from(bundle, 'other').thisProfile, isFalse);
    });

    test('an older backup that doesn’t say holds nothing false', () {
      final found = BackupContents.from({
        'name': 'Rendel',
        'createdUtc': '2024-01-01T00:00:00.000Z',
        'commands': const [],
        'drafts': const [],
        'format': 1,
        'owner': 'me',
      }, 'me');
      expect(found.filesListed, isNull);
      expect(found.lifeVersions, 0);
      expect(found.connected, isFalse);
    });

    Future<void> withStore(
      Future<void> Function(LocalStore, LocalFixture) body,
    ) async {
      final f = await LocalFixture.open();
      try {
        await body(f.store, f);
      } finally {
        await f.close();
      }
    }

    test('nothing is noted until a backup is saved', () async {
      await withStore((store, _) async {
        expect(await store.lastBackup(), isNull);
      });
    });

    test('the note says when a record changes', () async {
      await withStore((store, f) async {
        final account = await f.account('Wallet', '100.00');
        await store.recordBackup();
        final note = (await store.lastBackup())!;
        expect(DateTime.tryParse(note.at), isNotNull);
        expect(note.changed, isFalse);

        await f.post('expense', {
          'account': account,
          'name': 'After the backup',
          'date': civilToday(),
          'amount': '5.00',
          'category': 'category-food',
        });
        expect((await store.lastBackup())!.changed, isTrue);

        await store.recordBackup();
        expect((await store.lastBackup())!.changed, isFalse);
      });
    });

    test('the note stays out of what a backup holds', () async {
      await withStore((store, f) async {
        await f.account('Wallet', '100.00');
        final before = await LocalBackup.capture(store);
        await store.recordBackup();
        final after = await LocalBackup.capture(store);
        expect(after.toString(), isNot(contains('backup:last')));
        for (final key in before.keys.where((k) => k != 'createdUtc')) {
          expect('${after[key]}', '${before[key]}', reason: key);
        }
      });
    });
  });

  group('reviewRow', () {
    Map<String, dynamic> row(String? reason) => {
      'id': '11111111-1111-4111-8111-111111111111',
      'reason': reason,
      'payload': LocalCommand(
        id: '11111111-1111-4111-8111-111111111111',
        owner: '22222222-2222-4222-8222-222222222222',
        expectedVersion: 0,
        kind: 'expense',
        values: const {
          'name': 'Groceries',
          'amount': '125.50',
          'date': '2026-10-21',
          'account': 'account-1',
          'splitNote': 'kept for 125.50',
        },
      ).payload,
    };
    ReviewRow build(
      String? reason, {
      bool hidden = false,
      bool connected = true,
    }) => reviewRow(
      row(reason),
      hidden: hidden,
      connected: connected,
      amount: (v) => hidden ? 'Amount hidden' : '₱$v',
      accountName: (id) => 'Cash wallet',
      categoryName: (id) => 'Food',
    );

    test('plain labels, plain names and a plain reason', () {
      final r = build('restored_rejected');
      expect(r.title, 'Groceries');
      expect(r.facts, contains(('Account', 'Cash wallet')));
      expect(r.reason, changeReasons['restored_rejected']);
      expect(r.reason, isNot(contains('restored_')));
    });

    test('a raw code never reaches the screen', () {
      expect(
        build('restored_requires_current_receipt_review').reason,
        changeReasons['restored_requires_current_receipt_review'],
      );
      for (final words in changeReasons.values) {
        expect(words, isNot(contains('_')));
      }
    });

    test('a reason with no entry, such as this app’s own, stays readable', () {
      expect(build('Your records changed.').reason, 'Your records changed.');
      expect(build(null).reason, contains('needs a look'));
    });

    test('with amounts hidden, no figure gets through', () {
      final r = build('restored_rejected', hidden: true);
      expect(r.facts, contains(('Amount', 'Amount hidden')));
      expect(r.details, isEmpty);
      final shown = [
        r.title,
        r.reason,
        for (final (a, b) in r.facts) '$a $b',
      ].join(' ');
      expect(shown, isNot(contains('125')));
    });

    test('other saved values wait under View details', () {
      final r = build('restored_rejected');
      expect(r.details, contains(('splitNote', 'kept for 125.50')));
      expect(r.facts.map((f) => f.$1), isNot(contains('splitNote')));
    });

    test('only a change the service doesn’t have can be sent', () {
      expect(build('restored_missing').canSend, isTrue);
      expect(build('restored_rejected').canSend, isFalse);
      expect(build('restored_mismatch').canSend, isFalse);
      // The rule refuses until the first download is done.
      expect(build('restored_missing', connected: false).canSend, isFalse);
    });
  });
}
