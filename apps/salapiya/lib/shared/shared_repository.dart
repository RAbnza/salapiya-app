import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../local/finance_domain.dart';
import '../local/local_runtime.dart';
import '../local/local_store.dart';
import 'shared_data.dart';
import 'shared_domain.dart';

class SharedRepository extends ChangeNotifier implements SharedWriter {
  SharedRepository(this.runtime, this.store);
  final LocalRuntime runtime;
  final LocalStore store;
  StreamSubscription<dynamic>? _records, _intents;
  bool _closed = false;
  List<SharedGroup> groups = [];
  List<SharedJson> intents = [];
  List<SharedJson> drafts = [];
  StreamSubscription<dynamic>? _drafts;
  StreamSubscription<dynamic>? _resources;
  StreamSubscription<dynamic>? _reviews;
  List<SharedJson> reviews = [];
  String? error;

  /// The first read has finished, so an empty list means there are no groups.
  bool loaded = false;
  @override
  String? get actor => runtime.connected.binding?['remote_owner'] as String?;
  @override
  bool get online =>
      runtime.connected.flow?.client.auth.currentUser?.id == actor &&
      store.db.currentStatus.connected &&
      runtime.connected.binding?['paused'] == 0 &&
      runtime.connected.binding?['phase'] == 'connected';
  Future<void> open() async {
    _reviews = store.db
        .watch('SELECT id FROM p3_private_review')
        .distinct((a, b) => jsonEncode(a) == jsonEncode(b))
        .listen((_) => unawaited(reload()));
    _resources = store.db
        .watch('SELECT id,version FROM p3_resource')
        .distinct((a, b) => jsonEncode(a) == jsonEncode(b))
        .listen((_) => unawaited(reload()));
    _drafts = store.db
        .watch('SELECT id,updated_at FROM shared_draft')
        .distinct((a, b) => jsonEncode(a) == jsonEncode(b))
        .listen((_) => unawaited(reload()));
    _records = store.db
        .watch('SELECT id,version FROM p3_group')
        .distinct((a, b) => jsonEncode(a) == jsonEncode(b))
        .listen((_) => unawaited(reload()));
    _intents = store.db
        .watch('SELECT id,state FROM shared_intent')
        .distinct((a, b) => jsonEncode(a) == jsonEncode(b))
        .listen((_) => unawaited(reload()));
    await reload();
  }

  Future<void> reload() async {
    try {
      await store.reconcileShared();
      final user = actor;
      final rows = await store.db.getAll(
        'SELECT document FROM shared_snapshot_cache WHERE owner_id=? ORDER BY group_id',
        [user],
      );
      groups = rows
          .map((r) => SharedGroup(object(jsonDecode(r['document'] as String))))
          .toList();
      intents = (await store.db.getAll(
        'SELECT * FROM shared_intent WHERE actor=? ORDER BY recorded_at DESC',
        [user],
      )).map(object).toList();
      error = null;
      drafts = (await store.db.getAll(
        'SELECT * FROM shared_draft ORDER BY updated_at DESC',
      )).map(object).toList();
      reviews = [
        ...(await store.db.getAll(
          'SELECT * FROM p3_private_review WHERE owner_id=? ORDER BY recorded_at DESC',
          [user],
        )).map(object),
        ...(await store.db.getAll('SELECT payload FROM shared_review_history'))
            .map(
              (r) => {
                ...object(jsonDecode(r['payload'] as String)),
                'historicalOnly': true,
              },
            )
            .where((r) => r['owner_id'] == user),
      ];
    } catch (_) {
      error = 'Couldn’t read your shared records. Nothing was lost. Try again.';
    }
    loaded = true;
    if (!_closed) notifyListeners();
  }

  SharedJson command(
    String group,
    String op,
    SharedJson values, {
    int version = 0,
  }) => {
    'contract': 3,
    'group': group,
    'op': op,
    'version': version,
    'values': values,
  };
  @override
  Future<String> submit(
    String group,
    String op,
    SharedJson values, {
    int version = 0,
    String? id,
  }) async {
    final user = actor;
    if (user == null) {
      reject('Connect this profile with Google to use shared groups.');
    }
    final queued = ['bill', 'report'].contains(op);
    if (!queued && !online) {
      reject('This needs a connection. Connect, then try again.');
    }
    final cid = id ?? newLocalId();
    final payload = jsonEncode(command(group, op, values, version: version));
    // Accept tokens are ephemeral online requests. Store their digest rather than
    // invitation secrets; lost responses resolve by original authenticated ID.
    if (op == 'accept') {
      final prior = await runtime.connected.flow!.client.rpc(
        'p3_submit_command',
        params: {'command_id': cid, 'command_payload': payload},
      );
      if (prior['outcome'] != 'accepted') {
        reject(
          prior['reason'] as String? ??
              'This invitation didn’t go through. Check it and try again.',
        );
      }
      return cid;
    }
    await store.saveSharedIntent(cid, user, group, payload, queued: queued);
    if (!queued) await retry(cid);
    await reload();
    return cid;
  }

  @override
  Future<void> retry(String id) async {
    if (!online) reject('You need to be online and signed in to do this.');
    final row = await store.db.get('SELECT * FROM shared_intent WHERE id=?', [
      id,
    ]);
    if (row['actor'] != actor || row['state'] == 'review') {
      reject('Check what was refused before trying again.');
    }
    if (row['state'] == 'restored') {
      final original = object(
        await runtime.connected.flow!.client.rpc(
          'p3_review_command',
          params: {'command_id': id},
        ),
      );
      if (original['outcome'] != 'missing') {
        await store.recordSharedReceipt(id, actor!, original);
        await reload();
        return;
      }
      // Explicit same-ID resume after current identity validation. The server
      // independently rechecks membership; no archived authority is restored.
    }
    final receipt = object(
      await runtime.connected.flow!.client.rpc(
        'p3_submit_command',
        params: {'command_id': id, 'command_payload': row['payload']},
      ),
    );
    await store.recordSharedReceipt(id, actor!, receipt);
    await reload();
    if (receipt['outcome'] != 'accepted') {
      reject(
        receipt['reason'] as String? ??
            'The group didn’t accept this. Check it and try again.',
      );
    }
  }

  @override
  Future<SharedJson> reviewInvitation(String code) async {
    if (!online) {
      reject('Sign in with the Google account this invitation was sent to.');
    }
    final parts = code.trim().split('.');
    if (parts.length != 2) reject('Paste the whole invitation code.');
    return object(
      await runtime.connected.flow!.client.rpc(
        'p3_review_invitation',
        params: {'group_id': parts[0], 'token': parts[1]},
      ),
    );
  }

  static String invitationToken() => List.generate(
    32,
    (_) => Random.secure().nextInt(256),
  ).map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  static String tokenHash(String token) =>
      sha256.convert(utf8.encode(token)).toString();
  @override
  Future<void> draft(String id, String group, SharedJson values) =>
      store.db.execute(
        'INSERT INTO shared_draft VALUES(?,?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,updated_at=excluded.updated_at',
        [
          id,
          group,
          jsonEncode(values),
          DateTime.now().toUtc().toIso8601String(),
        ],
      );

  /// Keeps the link to the user's own purchase before the bill is sent. A
  /// refusal can never undo that spending, so the intent is saved first.
  Future<void> linkPurchase(String bill, String group, String purchase) =>
      store.saveDraft('shared-purchase:$bill', bill, {
        'privateSource': purchase,
        'group': group,
        'bill': bill,
      });

  /// A corrected draft keeps its purchase's link to the user's own record.
  Future<void> carryPurchaseLink(String from, String to, String group) async {
    final purchase = await store.draft('shared-purchase:$from');
    if (purchase == null) return;
    await store.saveDraft('shared-purchase:$to', to, {
      ...Map<String, String>.from(purchase['values'] as Map),
      'group': group,
      'bill': to,
    });
  }

  /// The fields a saved draft holds, or null when it's gone.
  @override
  Future<SharedJson?> readDraft(String id) async {
    final row = (await store.db.getAll(
      'SELECT payload FROM shared_draft WHERE id=?',
      [id],
    )).firstOrNull;
    return row == null ? null : object(jsonDecode(row['payload'] as String));
  }

  /// Removes the user's own unsent draft. Nothing else refers to it.
  @override
  Future<void> discardDraft(String id) async {
    await store.db.execute('DELETE FROM shared_draft WHERE id=?', [id]);
    await reload();
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(_records?.cancel());
    unawaited(_intents?.cancel());
    unawaited(_drafts?.cancel());
    unawaited(_resources?.cancel());
    unawaited(_reviews?.cancel());
    super.dispose();
  }
}
