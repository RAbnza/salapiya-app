import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/finance_domain.dart';
import '../local/local_runtime.dart';
import '../local/local_store.dart';
import '../p0/auth_runtime.dart';
import '../p0/google_auth_proof.dart';
import 'command_connector.dart';
import 'environment.dart';
import '../shared/shared_domain.dart';
import '../life/life_controller.dart';

class ConnectedRuntime extends ChangeNotifier {
  ConnectedRuntime(this.local);
  final LocalRuntime local;
  static const scope = 'salapiya.production.google.v1';
  static const vault = FlutterSecureStorage();
  static const url = String.fromEnvironment('SALAPIYA_SUPABASE_URL');
  static const publicKey = String.fromEnvironment('SALAPIYA_PUBLIC_KEY');
  static const endpoint = String.fromEnvironment('SALAPIYA_POWERSYNC_URL');
  static const environment = String.fromEnvironment(
    'SALAPIYA_ENVIRONMENT',
    defaultValue: 'development',
  );
  static const project = String.fromEnvironment(
    'SALAPIYA_EXPECTED_PROJECT',
    defaultValue: developmentProject,
  );
  static const syncInstance = String.fromEnvironment(
    'SALAPIYA_EXPECTED_SYNC_INSTANCE',
    defaultValue: developmentSyncInstance,
  );
  bool get configured =>
      publicKey.isNotEmpty &&
      allowedConnectionEnvironment(
        environment: environment,
        url: url,
        endpoint: endpoint,
        project: project,
        syncInstance: syncInstance,
      );
  GoogleAuthProof? flow;
  Future<void>? _authOpening;
  StreamSubscription<dynamic>? _downloads, _intents, _status, _lifeChanges;
  int lifePendingCount = 0, lifeReviewCount = 0;
  int sharedPendingCount = 0,
      sharedReviewCount = 0,
      needMyConfirmation = 0,
      waitingForOthers = 0,
      changedPrivateSources = 0;
  LocalStore? _attached;
  bool busy = false, refreshing = false, closed = false;
  Future<void> _refreshQueue = Future.value();
  bool sessionExpired = false;
  String? error;
  Map<String, dynamic>? binding, cloud;
  int pendingCount = 0, reviewCount = 0;
  List<Map<String, dynamic>> reviews = [];
  String get identity =>
      flow?.client.auth.currentUser?.email ??
      binding?['email'] as String? ??
      'Not connected';
  bool get connected => binding != null;
  bool get complete =>
      binding == null ||
      (binding!['phase'] == 'connected' || binding!['phase'] == 'restored');
  String get label {
    if (binding == null) {
      return flow?.pending == true
          ? 'Waiting for Google'
          : 'On this device only';
    }
    if (binding!['phase'] == 'restored') return 'Needs review';
    if (!complete) return 'First download not finished';
    if (reviewCount > 0 || sharedReviewCount > 0 || lifeReviewCount > 0) {
      return 'Needs review';
    }
    if (sessionExpired ||
        (flow != null && flow!.client.auth.currentSession == null)) {
      return 'Signed out';
    }
    if (binding!['paused'] == 1) return 'Sync paused';
    final status = _attached?.db.currentStatus;
    if (busy ||
        status?.connecting == true ||
        status?.uploading == true ||
        status?.downloading == true) {
      return 'Syncing';
    }
    if (error != null ||
        status?.connected != true ||
        status?.uploadError != null ||
        status?.downloadError != null) {
      return 'Waiting for connection';
    }
    return pendingCount + sharedPendingCount + lifePendingCount > 0
        ? 'Waiting for connection'
        : 'Synced';
  }

  void changed() {
    if (!closed) notifyListeners();
  }

  Future<void> initializeAuth() async {
    if (flow != null) return;
    try {
      await (_authOpening ??= _initializeAuth());
    } catch (_) {
      _authOpening = null;
      rethrow;
    }
  }

  Future<void> _initializeAuth() async {
    if (!configured) {
      reject(
        'This version of Salapiya can’t connect to Google. Your profile keeps working on this device.',
      );
    }
    final auth = await initializeProofAuth(
      url,
      publicKey,
      scope: scope,
      detectSessionInUri: false,
    );
    flow = GoogleAuthProof(auth, scope, vault);
    flow!.addListener(_authChanged);
    await flow!.listen();
  }

  void _authChanged() {
    if (closed) return;
    if (binding != null &&
        flow!.client.auth.currentUser?.id != binding!['remote_owner']) {
      sessionExpired = true;
      unawaited(_attached?.db.disconnect());
    } else if (binding != null &&
        flow!.outcome == 'google_code_exchange_verified') {
      sessionExpired = false;
      if (!busy && binding!['phase'] != 'staged') unawaited(syncNow());
    }
    changed();
  }

  Future<void> restore() async {
    await attach();
    if (binding != null || await vault.read(key: '$scope.attempt') != null) {
      try {
        await initializeAuth();
        if (binding != null && flow!.client.auth.currentUser != null) {
          await syncNow();
        } else if (binding != null) {
          sessionExpired = true;
          changed();
        }
      } catch (_) {
        error = 'Can’t connect right now. Your records are safe on this device.';
        changed();
      }
    }
  }

  Future<void> attach() async {
    final store = local.session?.localFinance.store;
    if (store == null) return;
    binding = await store.connection();
    if (binding == null && _attached == null) {
      changed();
      return;
    }
    if (identical(store, _attached)) {
      changed();
      return;
    }
    await _downloads?.cancel();
    await _intents?.cancel();
    await _lifeChanges?.cancel();
    await _status?.cancel();
    _attached = store;
    _downloads = store.db
        .watch('SELECT id,sequence_no FROM p2_command ORDER BY sequence_no')
        .distinct((a, b) => jsonEncode(a) == jsonEncode(b))
        .listen((_) => unawaited(refresh()));
    _intents = store.db
        .watch(
          'SELECT id,state,reason FROM connected_intent ORDER BY sequence_no',
        )
        .distinct((a, b) => jsonEncode(a) == jsonEncode(b))
        .listen((_) => unawaited(refresh()));
    _lifeChanges = store.db
        .watch('''SELECT id,state||coalesce(reason,'') AS token FROM life_intent
      UNION ALL SELECT id,payload FROM p5_command
      UNION ALL SELECT intent_id,recorded_at FROM life_review_resolution''')
        .distinct((a, b) => jsonEncode(a) == jsonEncode(b))
        .listen((_) => unawaited(refresh()));
    // Queue-stat notifications may follow our own ordinary SQLite writes.
    // React only to actual connection/download/error transitions, avoiding a
    // feedback loop while still draining an event that arrived mid-refresh.
    _status = store.db.statusStream
        .map(
          (s) => (
            s.connected,
            s.connecting,
            s.downloading,
            s.uploading,
            s.lastSyncedAt,
            s.uploadError?.toString(),
            s.downloadError?.toString(),
          ),
        )
        .distinct()
        .listen((_) => unawaited(refresh()));
    await refresh();
  }

  Future<void> refresh() {
    // Serialize actual data/status transitions. A notification arriving while
    // reconciliation is running must be processed after that transaction.
    final next = _refreshQueue.then((_) => _refreshNow());
    _refreshQueue = next;
    return next;
  }

  Future<void> _refreshNow() async {
    if (closed || _attached == null) return;
    refreshing = true;
    try {
      final store = _attached!;
      await store.reconcileDownloaded();
      await store.reconcileShared();
      await store.reconcileLife();
      await store.publishLocalLife();
      final lifeIntents = await store.lifeIntents();
      lifePendingCount = lifeIntents
          .where((r) => ['pending', 'accepted'].contains(r['state']))
          .length;
      lifeReviewCount = lifeIntents
          .where(
            (r) =>
                r['resolved_at'] == null &&
                ['review', 'restored'].contains(r['state']),
          )
          .length;
      binding = await store.connection();
      final uploadError = store.db.currentStatus.uploadError;
      if (binding != null &&
          (uploadError is AuthException ||
              (uploadError is PostgrestException &&
                  ['42501', 'PGRST301'].contains(uploadError.code)))) {
        sessionExpired = true;
      }
      final intents = await store.db.getAll(
        'SELECT * FROM connected_intent ORDER BY sequence_no',
      );
      pendingCount = intents
          .where((r) => ['pending', 'accepted'].contains(r['state']))
          .length;
      reviews = intents
          .where((r) => ['review', 'restored'].contains(r['state']))
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      reviewCount = reviews.length;
      if (!closed && identical(store, local.session?.localFinance.store)) {
        await local.session!.localFinance.reload();
        final conflicts =
            local.session!.localFinance.snapshot.projectionConflicts;
        for (final row in intents.where((r) => conflicts.contains(r['id']))) {
          if (!reviews.any((r) => r['id'] == row['id'])) {
            reviews.add({
              ...Map<String, dynamic>.from(row),
              'reason': 'Your records changed since this was saved, so it’s waiting and not in your totals until it’s sorted out.',
            });
          }
        }
        reviewCount = reviews.length;
        final shared = await store.db.getAll('SELECT state FROM shared_intent');
        sharedPendingCount = shared
            .where((r) => ['pending', 'accepted'].contains(r['state']))
            .length;
        sharedReviewCount = shared
            .where((r) => ['review', 'restored'].contains(r['state']))
            .length;
        needMyConfirmation = 0;
        waitingForOthers = 0;
        changedPrivateSources = 0;
        final privateReviews = (await store.db.getAll(
          'SELECT * FROM p3_private_review WHERE owner_id=?',
          [binding?['remote_owner']],
        )).map((r) => Map<String, dynamic>.from(r)).toList();
        for (final row in await store.db.getAll(
          'SELECT document FROM shared_snapshot_cache WHERE owner_id=?',
          [binding?['remote_owner']],
        )) {
          final group = SharedGroup(
            Map<String, dynamic>.from(
              jsonDecode(row['document'] as String) as Map,
            ),
          );
          final me = group.participant(
            binding?['remote_owner'] as String? ?? '',
          );
          for (final s in group.settlements.values) {
            if (s['state'] == 'pending') {
              if (s['recipient'] == me) {
                needMyConfirmation++;
              } else if (s['sender'] == me) {
                waitingForOthers++;
              }
            }
          }
          for (final r in local.session!.localFinance.snapshot.current.where(
            (r) =>
                r.values['sharedGroup'] == group.id &&
                r.values['sharedMode'] == 'bill',
          )) {
            if (privateBillNeedsSharedReview(
              group,
              me ?? '',
              r,
              local.session!.localFinance.snapshot.current,
              privateReviews,
            )) {
              changedPrivateSources++;
            }
          }
        }
      }
    } catch (e) {
      error = e is LocalRuleException ? e.message : 'Salapiya couldn’t check your sync. Your records and waiting changes are safe.';
    } finally {
      refreshing = false;
      changed();
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    error = null;
    changed();
    try {
      await action();
    } on AuthException {
      sessionExpired = true;
      error = 'Sign in with the Google account this profile uses. Your records are still here.';
    } on PostgrestException catch (e) {
      if (e.code == '42501' || e.code == 'PGRST301') sessionExpired = true;
      error = sessionExpired
          ? 'You’ve been signed out. Sign in again to sync. Your records are still here.'
          : 'The service couldn’t do that. Try again when you’re connected. Your records are safe.';
    } catch (e) {
      error = e is LocalRuleException ? e.message : 'The connection dropped. Your records and waiting changes are safe. Try again when you’re connected.';
    } finally {
      busy = false;
      await refresh();
      changed();
    }
  }

  Future<void> signIn() => run(() async {
    await attach();
    await initializeAuth();
    await flow!.start(expectedOwner: binding?['remote_owner'] as String?);
  });
  Future<void> lookup() => run(() async {
    await attach();
    await initializeAuth();
    final user = flow!.client.auth.currentUser;
    if (user == null) reject('Finish Google sign-in first.');
    if (binding != null && binding!['remote_owner'] != user.id) {
      reject('Select the Google identity bound to this profile.');
    }
    cloud = await boundary();
    sessionExpired = false;
  });
  Future<Map<String, dynamic>?> boundary() async {
    await flow!.client.rpc(
      'p7_register_device',
      params: {
        'device_label': Platform.isWindows
            ? 'Windows installation'
            : 'Android installation',
      },
    );
    final result = await flow!.client.rpc('p2_profile_boundary');
    return result == null ? null : Map<String, dynamic>.from(result as Map);
  }

  // Called only by an explicit product confirmation showing the selected identity
  // and service disclosure. Signing in alone never enrolls or uploads a profile.
  Future<void> confirmConnection() => run(() async {
    await attach();
    await initializeAuth();
    final user = flow!.client.auth.currentUser;
    if (user == null) reject('Finish Google sign-in first.');
    if (binding != null && binding!['remote_owner'] != user.id) {
      reject(
        'Reconnect with the Google identity already bound to this profile.',
      );
    }
    cloud = await boundary();
    final store = local.session?.localFinance.store;
    if (store == null) {
      if (cloud == null) {
        final id = newLocalId(), enrollment = newLocalId();
        final name =
            (user.userMetadata?['full_name'] as String? ?? 'My profile').trim();
        await flow!.client.rpc(
          'p2_stage_enrollment',
          params: {
            'enrollment_id': enrollment,
            'profile_id': id,
            'display_name': name,
            'snapshot': <Object>[],
          },
        );
        final published = await flow!.client.rpc(
          'p2_publish_enrollment',
          params: {'enrollment_id': enrollment},
        ) as Map;
        if (published['outcome'] != 'published') {
          cloud = await boundary();
          reject(
            'This identity already owns a profile. Review the existing cloud profile.',
          );
        }
        cloud = await boundary();
      }
      await _retrieve();
    } else {
      if (cloud != null && cloud!['id'] != store.owner) {
        reject(
          'This Google account already has a different profile. Keep this one, or save a backup before switching.',
        );
      }
      if (cloud != null) {
        // The same profile may have been published just before process loss.
        await store.stageConnection(user.id, user.email ?? '', newLocalId());
        await store.db.execute(
          "UPDATE connected_profile SET phase='published' WHERE profile_id=?",
          [store.owner],
        );
      } else {
        final previous = await store.connection();
        if (previous?['phase'] == 'restored') {
          if (previous?['enrollment_snapshot'] == null) {
            reject(
              'This backup can’t bring back history that’s missing from your connected account. Your records here are safe.',
            );
          }
          await store.db.execute(
            "UPDATE connected_profile SET phase='staged' WHERE profile_id=?",
            [store.owner],
          );
        }
        await store.stageConnection(user.id, user.email ?? '', newLocalId());
        await attach();
        final staged = (await store.connection())!;
        final result = await flow!.client.rpc(
          'p2_stage_enrollment',
          params: {
            'enrollment_id': staged['enrollment_id'],
            'profile_id': store.owner,
            'display_name': staged['enrollment_name'],
            'snapshot': jsonDecode(staged['enrollment_snapshot'] as String),
          },
        ) as Map;
        if (result['outcome'] == 'cancelled') {
          await store.cancelStaging();
          await attach();
          reject(
            'This connection was cancelled. Your profile stays on this device. Connect again when you’re ready.',
          );
        }
        if (!['staged', 'published'].contains(result['outcome'])) {
          cloud = await boundary();
          reject(
            'This Google account already has a profile. Review the switch, or cancel.',
          );
        }
        final published = await flow!.client.rpc(
          'p2_publish_enrollment',
          params: {'enrollment_id': staged['enrollment_id']},
        ) as Map;
        if (published['outcome'] == 'cancelled') {
          await store.cancelStaging();
          await attach();
          reject(
            'This connection was cancelled. Your records and drafts haven’t changed.',
          );
        }
        if (published['outcome'] != 'published') {
          cloud = await boundary();
          reject(
            'This Google account already has a profile. Review the switch, or cancel.',
          );
        }
        await store.db.execute(
          "UPDATE connected_profile SET phase='published' WHERE profile_id=?",
          [store.owner],
        );
      }
      await attach();
    }
    await _connect();
  });
  Future<void> _retrieve({bool preserveCurrent = false}) async {
    await local.flushPreferences();
    final remote = cloud!;
    final user = flow!.client.auth.currentUser!;
    final store = await local.profiles.retrieveConnected(
      remote['id'] as String,
      remote['name'] as String,
      user.id,
      user.email ?? '',
      preserveCurrent: preserveCurrent,
    );
    await local.activate(store);
    await attach();
  }

  Future<void> switchAfterBackup() => run(() async {
    await lookupBoundaryForSwitch();
    await _retrieve(preserveCurrent: true);
    await _connect();
  });
  Future<void> lookupBoundaryForSwitch() async {
    cloud = await boundary();
    if (cloud == null ||
        cloud!['id'] == local.session?.localFinance.store.owner) {
      reject('Check the profile on this Google account before switching.');
    }
    if (binding != null && binding!['phase'] != 'staged') {
      reject(
        'A connected profile can’t move to another Google account.',
      );
    }
  }

  Future<void> cancelConnection() => run(() async {
    final state = await local.session?.localFinance.store.connection();
    if (state != null && state['phase'] == 'staged') {
      await initializeAuth();
      if (flow!.client.auth.currentUser?.id != state['remote_owner']) {
        reject(
          'Sign in with the Google account that started this connection before cancelling. Your records here are safe.',
        );
      }
      // A server-side cancellation fence shares publication's actor lock. A
      // standalone boundary read cannot rule out an in-flight publication.
      final result = await flow!.client.rpc(
        'p2_cancel_enrollment',
        params: {
          'enrollment_id': state['enrollment_id'],
          'profile_id': state['profile_id'],
        },
      ) as Map;
      if (result['profile_id'] != state['profile_id']) {
        reject('Salapiya couldn’t confirm this cancellation. Your records here are safe.');
      }
      if (result['outcome'] == 'published') {
        await local.session!.localFinance.store.db.execute(
          "UPDATE connected_profile SET phase='published' WHERE profile_id=?",
          [state['profile_id']],
        );
        reject(
          'Your profile has finished connecting. Sync to carry on.',
        );
      }
      if (result['outcome'] != 'cancelled') {
        reject(
          'Salapiya couldn’t confirm the cancellation yet. Finish connecting before logging anything else.',
        );
      }
      await local.session!.localFinance.store.cancelStaging();
    }
    if (flow?.pending == true) await flow!.cancel();
    cloud = null;
    await attach();
  });
  Future<void> _connect() async {
    final store = _attached!;
    binding = await store.connection();
    final user = flow!.client.auth.currentUser;
    if (user == null || user.id != binding?['remote_owner']) {
      sessionExpired = true;
      reject('Sign in with the Google account this profile uses.');
    }
    if (binding!['paused'] == 1 || binding!['phase'] == 'staged') return;
    final remote = await boundary();
    if (remote == null || remote['id'] != store.owner) {
      reject(
        'Your connected profile can’t be reached. Your records here are safe.',
      );
    }
    sessionExpired = false;
    final groupBoundary = List<Map<String, dynamic>>.from(
      (await flow!.client.rpc('p3_group_boundary') as List).map(
        (r) => Map<String, dynamic>.from(r as Map),
      ),
    );
    final lifeBoundary = Map<String, dynamic>.from(
      await flow!.client.rpc('p5_boundary') as Map,
    );
    await store.db.execute(
      "INSERT INTO life_device VALUES('life:boundary',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
      ['${lifeBoundary['revision']}'],
    );
    final life = local.session!.life as DurableLifeController;
    life.initialComplete = false;
    if (binding!['phase'] == 'restored' ||
        (await store.db.get(
              "SELECT count(*) n FROM connected_intent WHERE state='restored'",
            ))['n'] !=
            0) {
      await _reviewRestored();
    }
    if (!store.db.currentStatus.connected ||
        store.db.currentStatus.uploadError != null ||
        store.db.currentStatus.downloadError != null) {
      await store.db.connect(
        connector: FinancialConnector.supabase(
          store,
          flow!.client,
          endpoint,
          changed: () => unawaited(refresh()),
        ),
      );
    }
    // Check actual immutable coverage rather than trusting a cached first sync.
    final target = remote['revision'] as int;
    final started = DateTime.now();
    while (!closed &&
        DateTime.now().difference(started) < const Duration(seconds: 45)) {
      if (await store.reconcileDownloaded(requiredBoundary: target) &&
          store.db.currentStatus.connected &&
          await _groupsCovered(store, groupBoundary) &&
          (await store.db.get(
                    'SELECT count(*) n FROM p5_command WHERE profile_id=? AND owner_id=?',
                    [store.owner, user.id],
                  ))['n']
                  as int >=
              (lifeBoundary['revision'] as int)) {
        await store.reconcileLife();
        for (final row in (await store.lifeIntents()).where(
          (r) => r['state'] == 'restored',
        )) {
          final receipt = await flow!.client.rpc(
            'p5_receipt',
            params: {'command_id': row['id']},
          );
          await store.reviewRestoredLife(
            row['id'] as String,
            receipt == null ? null : Map<String, dynamic>.from(receipt as Map),
            user.id,
          );
        }
        await store.publishLocalLife();
        life.initialComplete = true;
        await life.reload();
        // This timestamp follows a current authenticated boundary read plus
        // matching downloaded coverage, including an idle unchanged profile.
        await store.db.execute(
          'UPDATE connected_profile SET last_sync=? WHERE profile_id=?',
          [DateTime.now().toUtc().toIso8601String(), store.owner],
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    reject(
      binding!['phase'] == 'connected'
          ? 'Sync is waiting for the service. Your records and waiting changes are safe on this device. Try Sync now later.'
          : 'Your first download isn’t finished. Your records are still here. Sync now carries on from where it stopped.',
    );
  }

  Future<void> syncNow() => run(() async {
    await initializeAuth();
    await attach();
    if (binding == null) return;
    if (binding!['phase'] == 'staged') {
      reject('Review and confirm the connection to finish connecting.');
    }
    await _connect();
  });
  Future<bool> _groupsCovered(
    LocalStore store,
    List<Map<String, dynamic>> boundary,
  ) async {
    await store.reconcileSharedSnapshots();
    for (final expected in boundary) {
      final rows = await store.db.getAll(
        'SELECT g.version,g.document,c.version AS cached_version,c.metadata_hash FROM p3_group g LEFT JOIN shared_snapshot_cache c ON c.owner_id=g.owner_id AND c.group_id=g.group_id WHERE g.id=? AND g.owner_id=?',
        [expected['id'], binding?['remote_owner']],
      );
      if (rows.length != 1 ||
          rows.single['cached_version'] != rows.single['version'] ||
          rows.single['metadata_hash'] !=
              sha256
                  .convert(utf8.encode(rows.single['document'] as String))
                  .toString() ||
          (rows.single['version'] as int) < (expected['version'] as int)) {
        return false;
      }
      if (rows.single['version'] == expected['version'] &&
          sha256
                  .convert(utf8.encode(rows.single['document'] as String))
                  .toString() !=
              expected['digest']) {
        return false;
      }
    }
    return true;
  }

  Future<void> pause(bool paused) => run(() async {
    if (_attached == null || binding == null) return;
    await _attached!.db.execute(
      'UPDATE connected_profile SET paused=? WHERE profile_id=?',
      [paused ? 1 : 0, _attached!.owner],
    );
    if (paused) {
      await _attached!.db.disconnect();
    } else {
      await _connect();
    }
  });
  Future<void> signOut() => run(() async {
    await _attached?.db.disconnect();
    if (flow?.pending == true) await flow!.cancel();
    await flow?.client.auth.signOut(scope: SignOutScope.local);
    sessionExpired = binding != null;
  });
  Future<void> _reviewRestored() async {
    final store = _attached!;
    final rows = await store.db.getAll(
      "SELECT * FROM connected_intent WHERE state='restored'",
    );
    for (final row in rows) {
      final result = await flow!.client.rpc(
        'p2_review_command',
        params: {'command_id': row['id'], 'command_payload': row['payload']},
      ) as Map;
      if (result['id'] != row['id'] ||
          result['owner_id'] != binding!['remote_owner']) {
        reject('The service’s answer doesn’t match this profile. Nothing changed.');
      }
      final outcome = result['outcome'];
      await store.db.execute(
        'UPDATE connected_intent SET state=?,reason=? WHERE id=?',
        [
          outcome == 'accepted' ? 'accepted' : 'review',
          outcome == 'accepted' ? null : 'restored_$outcome',
          row['id'],
        ],
      );
    }
    await store.db.execute(
      "UPDATE connected_profile SET phase='published' WHERE profile_id=?",
      [store.owner],
    );
  }

  Future<void> resumeMissing(String id) => run(() async {
    if (binding == null || binding!['phase'] != 'connected') {
      reject('Finish the first download first.');
    }
    final row = await _attached!.db.get(
      "SELECT * FROM connected_intent WHERE id=? AND state='review' AND reason='restored_missing'",
      [id],
    );
    final result = await flow!.client.rpc(
      'p2_review_command',
      params: {'command_id': id, 'command_payload': row['payload']},
    ) as Map;
    if (result['id'] != id || result['owner_id'] != binding!['remote_owner']) {
      reject('The service’s answer doesn’t match this profile. Nothing changed.');
    }
    if (result['outcome'] != 'missing') {
      final accepted = result['outcome'] == 'accepted';
      await _attached!.db.execute(
        'UPDATE connected_intent SET state=?,reason=? WHERE id=?',
        [
          accepted ? 'accepted' : 'review',
          accepted ? null : 'restored_${result['outcome']}',
          id,
        ],
      );
      if (accepted) await _connect();
      return;
    }
    await _attached!.db.writeTransaction((tx) async {
      await tx.execute(
        "UPDATE connected_intent SET state='pending',reason=NULL WHERE id=?",
        [id],
      );
      await tx.execute('INSERT INTO p2_transport(id,payload) VALUES(?,?)', [
        id,
        row['envelope'],
      ]);
    });
  });
  Future<void> close() async {
    closed = true;
    await _downloads?.cancel();
    await _intents?.cancel();
    await _lifeChanges?.cancel();
    await _status?.cancel();
    await _refreshQueue;
    await _attached?.db.disconnect();
    await flow?.close();
    dispose();
  }

  Future<void> detachForLocalRemoval() async {
    if (busy) {
      reject(
        'Wait for the connection to finish, then remove this profile.',
      );
    }
    await _downloads?.cancel();
    await _intents?.cancel();
    await _lifeChanges?.cancel();
    await _status?.cancel();
    await _refreshQueue;
    await _attached?.db.disconnect();
    if (flow?.pending == true) await flow!.cancel();
    // The SDK clears its in-memory session before attempting the network logout.
    // Local removal works offline and does not promise cloud device revocation.
    try {
      await flow?.client.auth
          .signOut(scope: SignOutScope.local)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Explicit secure-storage cleanup below is still required and may fail.
    }
    if (flow != null) {
      await vault.delete(key: '$scope.session');
      await vault.delete(key: '$scope.attempt');
      await vault.delete(key: flow!.verifierSlot);
    }
    _attached = null;
    binding = cloud = null;
    pendingCount = reviewCount = lifePendingCount = lifeReviewCount = 0;
    sharedPendingCount = sharedReviewCount = 0;
    reviews = [];
    error = null;
    sessionExpired = false;
  }

  Future<List<Map<String, dynamic>>> authorizedDevices() async {
    await initializeAuth();
    if (binding == null ||
        flow!.client.auth.currentUser?.id != binding!['remote_owner']) {
      reject('Sign in with the Google account this profile uses.');
    }
    await boundary();
    return [
      for (final row in await flow!.client.rpc('p7_devices') as List)
        Map<String, dynamic>.from(row as Map),
    ];
  }

  Future<void> revokeDevice(String sessionId) async {
    await authorizedDevices();
    await flow!.client.rpc(
      'p7_revoke_device',
      params: {'target_session': sessionId},
    );
  }

  Future<bool> deleteConnectedAccount() async {
    await initializeAuth();
    if (binding == null ||
        flow!.client.auth.currentUser?.id != binding!['remote_owner']) {
      reject('Sign in with the Google account this profile uses.');
    }
    await _attached?.db.disconnect();
    final response = await flow!.client.functions.invoke(
      'delete-account',
      body: {'confirmation': 'DELETE CONNECTED ACCOUNT'},
    );
    final result = response.data;
    if (result is! Map || result['application_deleted'] != true) {
      reject(
        'Salapiya couldn’t confirm the deletion. Sign in with Google again and check. Your records here are safe.',
      );
    }
    await _attached?.db.execute('UPDATE connected_profile SET paused=1');
    sessionExpired = true;
    error = 'Your connected account was deleted. This profile stays on this device until you remove it.';
    changed();
    return result['auth_cleanup_pending'] == true;
  }
}
