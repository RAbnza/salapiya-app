import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

import '../p0/portable_recovery.dart';
import '../connected/financial_contract.dart';
import 'finance_domain.dart';
import 'local_store.dart';
import '../life/life_domain.dart';

abstract interface class ProfileVault {
  Future<String?> read();
  Future<void> write(String value);
}

class OsProfileVault implements ProfileVault {
  const OsProfileVault({this.slot = 'salapiya.local.production.v1'});
  static const storage = FlutterSecureStorage();
  final String slot;
  @override
  Future<String?> read() => storage.read(key: slot);
  @override
  Future<void> write(String value) => storage.write(key: slot, value: value);
}

// One protected activation descriptor. It is written before creating a database,
// so an interrupted first-run is resumable without generating a replacement key.
class LocalProfiles {
  LocalProfiles(this.directory, this.vault);
  final Directory directory;
  final ProfileVault vault;
  LocalStore? active;
  bool _opening = false;
  Future<LocalStore?> reopen() async {
    if (active != null) return active;
    if (_opening) reject('Profile startup is already running.');
    _opening = true;
    try {
      await directory.create(recursive: true);
      final encoded = await vault.read();
      if (encoded == null) {
        if (await directory.list().any(
          (f) =>
              p.basename(f.path).endsWith('.sqlite') ||
              p.basename(f.path).contains('.sqlite-'),
        )) {
          reject(
            'Salapiya can’t reach the key that opens your profile. Your files are safe and nothing was reset. Make sure you’re signed in to the same device account, then try again.',
          );
        }
        return null;
      }
      final descriptor = jsonDecode(encoded) as Map<String, dynamic>;
      if (descriptor['version'] == 1 && descriptor['phase'] == 'empty') {
        return null;
      }
      if (descriptor['version'] == 1 && descriptor['phase'] == 'removing') {
        await _finishRemoval(descriptor);
        return null;
      }
      return await _open(descriptor);
    } finally {
      _opening = false;
    }
  }

  Future<LocalStore> _open(Map<String, dynamic> d) async {
    final id = d['id'] as String, key = d['key'] as String;
    if (d['version'] != 1 ||
        !RegExp(r'^[0-9a-f-]{36}$').hasMatch(id) ||
        base64Url.decode(key).length != 32 ||
        !['initializing', 'ready', 'restoring'].contains(d['phase'])) {
      reject(
        'Salapiya can’t read what it needs to open your profile. Your files are safe and nothing was reset.',
      );
    }
    final file = File(p.join(directory.path, '$id.sqlite'));
    if (d['phase'] == 'ready' && !await file.exists()) {
      reject(
        'Your profile’s records aren’t on this device any more. Nothing was replaced with an empty profile. A backup can restore them on another device.',
      );
    }
    if (d['phase'] == 'restoring') {
      final name = d['staging'] as String;
      if (!RegExp(r'^[0-9a-f-]{36}\.staging$').hasMatch(name)) {
        reject('Invalid recovery staging descriptor.');
      }
      final staging = File(p.join(directory.path, name));
      if (await staging.exists()) {
        if (await file.exists()) {
          reject(
            'A restore didn’t finish, and two copies of this profile are on this device. Both are safe.',
          );
        }
        final check = openLocalDatabase(staging.path, key);
        try {
          await check.initialize();
          await LocalStore(check, id).integrity();
        } finally {
          await check.close();
        }
        await staging.rename(file.path);
      } else if (!await file.exists()) {
        reject(
          'A restore didn’t finish and its files have gone. Your backup file is safe, and it can restore on another device.',
        );
      }
      final check = openLocalDatabase(file.path, key);
      try {
        await check.initialize();
        await LocalStore(check, id).integrity();
      } finally {
        await check.close();
      }
      final ready = {...d, 'phase': 'ready'};
      await vault.write(jsonEncode(ready));
      return _open(ready);
    }
    final db = openLocalDatabase(file.path, key);
    try {
      await db.initialize();
      final store = LocalStore(db, id);
      await store.migrate();
      if (d['phase'] == 'initializing') {
        await store.initializeProfile(
          d['name'] as String,
          Map<String, String>.from(d['preferences'] as Map),
        );
      }
      if (d['connected'] case final Map remote) {
        if (await store.connection() == null) {
          await store.db.execute(
            '''INSERT INTO connected_profile(profile_id,remote_owner,email,phase,enrollment_id)
            VALUES(?,?,?,'published',?)''',
            [id, remote['owner'], remote['email'], newLocalId()],
          );
        }
      }
      await store.integrity();
      if (d['phase'] != 'ready') {
        await vault.write(jsonEncode({...d, 'phase': 'ready'}));
      }
      active = store;
      return store;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  Future<LocalStore> create(
    String name,
    Map<String, String> preferences,
  ) async {
    if (name.trim().isEmpty || name.trim().length > 200) {
      reject('Enter a display name (1–200 characters).');
    }
    final previous = await vault.read();
    final old = previous == null ? null : jsonDecode(previous) as Map;
    if (active != null || (old != null && old['phase'] != 'empty')) {
      reject('A profile is already set up on this device. Try again to open it.');
    }
    await directory.create(recursive: true);
    if (await directory.list().any(
      (f) => p.basename(f.path).contains('.sqlite'),
    )) {
      reject(
        'An earlier profile’s files are still on this device, so a new one can’t start here.',
      );
    }
    final d = {
      'version': 1,
      'phase': 'initializing',
      'id': newLocalId(),
      'key': await PortableRecovery.newRecoverySecret(),
      'name': name.trim(),
      'preferences': preferences,
      if (old?['preserved'] != null) 'preserved': old!['preserved'],
    };
    await vault.write(jsonEncode(d));
    return _open(d);
  }

  // Preserve the prior descriptor/key in OS secure storage before activating a
  // different cloud profile. Original database files remain at their own paths.
  Future<LocalStore> retrieveConnected(
    String id,
    String name,
    String actor,
    String email, {
    bool preserveCurrent = false,
  }) async {
    final previous = await vault.read();
    final prior = previous == null ? null : jsonDecode(previous) as Map;
    final hasCurrent = prior != null && prior['phase'] != 'empty';
    if (hasCurrent && !preserveCurrent) {
      reject('A profile is already open on this device. Review the switch first.');
    }
    if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(id) ||
        name.trim().isEmpty ||
        name.length > 200) {
      reject('Invalid cloud profile descriptor.');
    }
    final target = File(p.join(directory.path, '$id.sqlite'));
    if (await target.exists()) {
      reject(
        'The profile on this Google account already has files on this device. They’re safe. Nothing changed.',
      );
    }
    await directory.create(recursive: true);
    final descriptor = {
      'version': 1,
      'phase': 'initializing',
      'id': id,
      'key': await PortableRecovery.newRecoverySecret(),
      'name': name,
      'preferences': <String, String>{},
      'connected': {'owner': actor, 'email': email},
      if (hasCurrent) 'preserved': prior,
      if (!hasCurrent && prior?['preserved'] != null)
        'preserved': prior!['preserved'],
    };
    // Save first: failure keeps the old profile active. Successful save is a
    // resumable activation checkpoint, never deletion of the old key or ledger.
    await vault.write(jsonEncode(descriptor));
    await close();
    return _open(descriptor);
  }

  // Recovery never merges or overwrites an existing profile. Its protected
  // staging descriptor makes final activation resumable across process loss.
  Future<LocalStore> restore(
    Map<String, dynamic> bundle, {
    bool interrupt = false,
    bool interruptActivation = false,
  }) async {
    LocalBackup.validate(bundle);
    final previous = await vault.read();
    final old = previous == null ? null : jsonDecode(previous) as Map;
    if (active != null || (old != null && old['phase'] != 'empty')) {
      reject(
        'A backup restores only when no profile is open on this device. Your profile hasn’t changed.',
      );
    }
    final id = bundle['owner'] as String;
    final key = await PortableRecovery.newRecoverySecret();
    final staging = File(p.join(directory.path, '${newLocalId()}.staging'));
    await directory.create(recursive: true);
    final db = openLocalDatabase(staging.path, key);
    final store = LocalStore(db, id);
    try {
      await db.initialize();
      await store.migrate();
      await store.initializeProfile(
        bundle['name'] as String,
        Map<String, String>.from(bundle['preferences'] as Map),
      );
      // Replay accepted local commands to validate every financial recipe, version,
      // source dependency and original ID; never import an arbitrary posting dump.
      await store.replayFinancialArchive([
        for (final row in bundle['commands'] as List)
          Map<String, dynamic>.from(row as Map),
      ], fromServer: [2, 3].contains(bundle['format']));
      for (final row in bundle['drafts'] as List) {
        final r = row as Map;
        await store.saveDraft(
          r['operation'] as String,
          r['command_id'] as String,
          Map<String, String>.from(
            jsonDecode(r['values_json'] as String) as Map,
          ),
        );
      }
      if ([2, 3].contains(bundle['format'])) {
        final remote = bundle['connection'] as Map;
        final unpublished = remote['origin'] == 'staged';
        await store.db.execute(
          "INSERT INTO connected_profile(profile_id,remote_owner,email,phase,enrollment_id,enrollment_snapshot,enrollment_name) VALUES(?,?,?,'restored',?,?,?)",
          [
            id,
            remote['remote_owner'],
            remote['email'],
            unpublished ? remote['enrollment_id'] : newLocalId(),
            unpublished ? remote['enrollment_snapshot'] : null,
            unpublished ? remote['enrollment_name'] : null,
          ],
        );
        for (final raw in bundle['intents'] as List) {
          final r = raw as Map;
          await store.db.execute(
            "INSERT INTO connected_intent VALUES(?,?,?,?,?,'restored',?,?)",
            [
              r['id'],
              id,
              r['payload'],
              r['envelope'],
              r['recorded_at'],
              'restored_requires_current_receipt_review',
              r['sequence_no'],
            ],
          );
        }
      }
      if (bundle['format'] == 3) {
        for (final raw in bundle['sharedReviews'] as List? ?? []) {
          final r = Map<String, dynamic>.from(raw as Map);
          await store.db.execute(
            'INSERT INTO shared_review_history VALUES(?,?)',
            [r['id'], jsonEncode(r)],
          );
        }
        final remote = bundle['connection'] as Map;
        for (final raw in bundle['sharedIntents'] as List) {
          final r = raw as Map;
          await store.db.execute(
            "INSERT INTO shared_intent VALUES(?,?,?,?, 'restored',?,NULL,?,0)",
            [
              r['id'],
              remote['remote_owner'],
              r['group_id'],
              r['payload'],
              'Restored history is not current membership authority; review original receipt online.',
              r['recorded_at'],
            ],
          );
        }
        for (final raw in bundle['sharedDrafts'] as List) {
          final r = raw as Map;
          await store.db.execute('INSERT INTO shared_draft VALUES(?,?,?,?)', [
            r['id'],
            r['group_id'],
            r['payload'],
            r['updated_at'],
          ]);
        }
      }
      if (bundle['life'] case final Map life) {
        await store.restoreLifeArchive(
          Map<String, dynamic>.from(life),
          connected: [2, 3].contains(bundle['format']),
        );
      }
      await store.integrity();
      if (interrupt) throw StateError('Injected restore interruption');
    } finally {
      await db.close();
    }
    // Staging is closed/checkpointed. Store its key before final rename.
    final target = File(p.join(directory.path, '$id.sqlite'));
    if (await target.exists()) {
      // Existing profiles are deliberately never replaced from an old archive.
      reject(
        'This profile is already on this device, so this backup can’t restore here. Your files are safe.',
      );
    }
    final descriptor = {
      'version': 1,
      'phase': 'restoring',
      'staging': p.basename(staging.path),
      'id': id,
      'key': key,
      'name': bundle['name'],
      'preferences': bundle['preferences'],
      if (old?['preserved'] != null) 'preserved': old!['preserved'],
    };
    await vault.write(jsonEncode(descriptor));
    if (interruptActivation) {
      throw StateError('Injected recovery activation interruption');
    }
    return _open(descriptor);
  }

  Future<void> close() async {
    final store = active;
    active = null;
    await store?.close();
  }

  /// Removes exactly one reviewed local profile. A protected checkpoint retains
  /// its key until all owned files have gone, so restart resumes a partial erase.
  /// Remote records, external archives and preserved profiles are never touched.
  Future<void> removeLocal(String expectedOwner) async {
    final raw = await vault.read();
    if (raw == null) reject('No profile is open on this device.');
    final d = jsonDecode(raw) as Map<String, dynamic>;
    if (d['id'] != expectedOwner || d['phase'] != 'ready') {
      reject('This profile changed. Open Remove again and check it.');
    }
    _validateRemovalPaths(d);
    await vault.write(jsonEncode({...d, 'phase': 'removing'}));
    await close();
    await _finishRemoval(d);
  }

  List<String> _validateRemovalPaths(Map<String, dynamic> d) {
    final id = d['id'];
    if (id is! String ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(id)) {
      reject('Invalid profile identity. Existing files are preserved.');
    }
    final root = p.normalize(p.absolute(directory.path));
    final paths = [
      for (final suffix in [
        '.sqlite',
        '.sqlite-wal',
        '.sqlite-shm',
        '.attachments',
        '.career-attachments',
      ])
        p.normalize(p.join(root, '$id$suffix')),
    ];
    if (paths.any((path) => !p.isWithin(root, path))) {
      reject('Local removal path is outside this profile.');
    }
    return paths;
  }

  Future<void> _finishRemoval(Map<String, dynamic> d) async {
    final paths = _validateRemovalPaths(d);
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
            FileSystemEntityType.directory ||
        !p.equals(
          await directory.resolveSymbolicLinks(),
          p.join(
            await directory.parent.resolveSymbolicLinks(),
            p.basename(directory.path),
          ),
        )) {
      reject('This profile’s folder points somewhere else, so nothing was removed.');
    }
    // Validate every target before deleting any; never traverse a link/junction.
    for (final path in paths) {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        reject('Some of this profile’s files are links, so nothing was removed.');
      }
      if (type == FileSystemEntityType.directory) {
        await for (final entity in Directory(
          path,
        ).list(recursive: true, followLinks: false)) {
          if (await FileSystemEntity.type(entity.path, followLinks: false) ==
              FileSystemEntityType.link) {
            reject('Some of this profile’s attached files are links, so nothing was removed.');
          }
        }
      }
    }
    for (final path in paths) {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else if (type == FileSystemEntityType.file) {
        await File(path).delete();
      }
    }
    await vault.write(
      jsonEncode({
        'version': 1,
        'phase': 'empty',
        if (d['preserved'] != null) 'preserved': d['preserved'],
      }),
    );
  }
}

// Reuses the P0 library AES-256-GCM envelope and independently generated recovery
// secret, with a distinct authenticated P1 header and bounded versioned manifest.
class LocalBackup {
  static final _cipher = AesGcm.with256bits();
  static final _header = utf8.encode('SALAPIYA-LOCAL-ARCHIVE-1\n');
  static const maxBytes = 32 * 1024 * 1024;
  static SecretKey _key(String value) {
    final bytes = base64Url.decode(value.trim());
    if (bytes.length != 32) {
      reject('Enter the whole recovery secret.');
    }
    return SecretKey(bytes);
  }

  static Future<Map<String, dynamic>> capture(LocalStore store) =>
      store.db.readTransaction((tx) async {
        final profile = await tx.get(
          'SELECT name,preferences,revision FROM local_profile WHERE id=?',
          [store.owner],
        );
        final commands = await tx.getAll(
          'SELECT id,payload,recorded_at FROM local_command WHERE owner_id=? ORDER BY sequence_no',
          [store.owner],
        );
        final drafts = await tx.getAll(
          'SELECT operation,command_id,values_json FROM local_draft WHERE owner_id=? ORDER BY operation',
          [store.owner],
        );
        final connection = await store.connectionIn(tx);
        final connected = connection != null;
        final result = <String, dynamic>{
          'format': connected ? 3 : 1,
          'localSchema': localSchemaVersion,
          'commandContract': 1,
          'calculationVersion': 1,
          'authority': connected ? 'connected-review-required' : 'local',
          if (connected)
            'connection': {
              'remote_owner': connection['remote_owner'],
              'email': connection['email'],
              'origin': connection['phase'],
              if (connection['phase'] == 'staged' ||
                  (connection['phase'] == 'restored' &&
                      connection['enrollment_snapshot'] != null)) ...{
                'origin': 'staged',
                'enrollment_id': connection['enrollment_id'],
                'enrollment_snapshot': connection['enrollment_snapshot'],
                'enrollment_name': connection['enrollment_name'],
              },
            },
          if (connected)
            'intents': [
              for (final r in await tx.getAll(
                'SELECT id,payload,envelope,recorded_at,sequence_no FROM connected_intent ORDER BY sequence_no',
              ))
                Map<String, dynamic>.from(r),
            ],
          if (connected)
            'sharedIntents': [
              for (final r in await tx.getAll(
                'SELECT id,group_id,payload,recorded_at FROM shared_intent ORDER BY recorded_at',
              ))
                if ([
                  'bill',
                  'report',
                ].contains((jsonDecode(r['payload'] as String) as Map)['op']))
                  Map<String, dynamic>.from(r),
            ],
          if (connected)
            'sharedDrafts': [
              for (final r in await tx.getAll('SELECT * FROM shared_draft'))
                Map<String, dynamic>.from(r),
            ],
          if (connected)
            'sharedReviews': {
              for (final row in await tx.getAll(
                'SELECT payload FROM shared_review_history',
              ))
                (jsonDecode(row['payload'] as String) as Map)['id']: jsonDecode(
                  row['payload'] as String,
                ),
              for (final row in await tx.getAll(
                'SELECT * FROM p3_private_review WHERE profile_id=?',
                [store.owner],
              ))
                row['id']: Map<String, dynamic>.from(row),
            }.values.toList(),
          'currency': 'PHP',
          'timezone': 'Asia/Manila',
          'owner': store.owner,
          'name': profile['name'],
          'preferences': jsonDecode(profile['preferences'] as String),
          'createdUtc': DateTime.now().toUtc().toIso8601String(),
          'revision': '${profile['revision']}',
          'commands': commands
              .map((r) => Map<String, dynamic>.from(r))
              .toList(),
          'drafts': drafts.map((r) => Map<String, dynamic>.from(r)).toList(),
          'coverage': 'local-profile-preferences-all-commands-and-drafts-no-attachments-no-cloud-authority',
          'financialCoverage': {
            'contract': 1,
            'financialRecipe': 1,
            'supportingFileMetadata': commands
                .where(
                  (r) =>
                      LocalCommand.decode(
                        r['id'] as String,
                        r['payload'] as String,
                      ).kind ==
                      'financialFile',
                )
                .length,
            'attachmentByteObjects': 0,
          },
          'life': await store.captureLifeArchive(tx),
        };
        validate(result);
        return result;
      });
  static void validate(Map<String, dynamic> b) {
    final connected = [2, 3].contains(b['format']);
    if (![1, 2, 3].contains(b['format']) ||
        ![1, 2, 3, 4, 5, 6, localSchemaVersion].contains(b['localSchema']) ||
        b['commandContract'] != 1 ||
        b['calculationVersion'] != 1 ||
        b['authority'] != (connected ? 'connected-review-required' : 'local') ||
        b['currency'] != 'PHP' ||
        b['timezone'] != 'Asia/Manila' ||
        b['coverage'] !=
            'local-profile-preferences-all-commands-and-drafts-no-attachments-no-cloud-authority' ||
        !RegExp(r'^[0-9a-f-]{36}$').hasMatch(b['owner'] as String) ||
        (b['name'] as String).trim().isEmpty ||
        (b['name'] as String).length > 200 ||
        DateTime.tryParse(b['createdUtc'] as String) == null ||
        !(b['createdUtc'] as String).endsWith('Z')) {
      reject('This version of Salapiya can’t open this backup.');
    }
    final commands = b['commands'] as List, drafts = b['drafts'] as List;
    if (b['life'] case final Map life) {
      validateLifeArchive(
        Map<String, dynamic>.from(life),
        b['owner'] as String,
        connected: connected,
      );
    }
    if (b['financialCoverage'] case final Map coverage) {
      if (coverage['contract'] != 1 ||
          coverage['financialRecipe'] != 1 ||
          coverage['attachmentByteObjects'] != 0 ||
          coverage['supportingFileMetadata'] !=
              commands.where((raw) {
                final r = raw as Map;
                return LocalCommand.decode(
                      r['id'] as String,
                      r['payload'] as String,
                    ).kind ==
                    'financialFile';
              }).length) {
        reject(
          'This backup’s file list doesn’t add up. Nothing changed.',
        );
      }
    }
    Map<String, String>.from(b['preferences'] as Map);
    if (commands.length > 20000 ||
        drafts.length > 100 ||
        b['revision'] != '${commands.length}') {
      reject('This version of Salapiya can’t open this backup.');
    }
    final ids = <String>{};
    for (var i = 0; i < commands.length; i++) {
      final r = commands[i] as Map;
      final c = LocalCommand.decode(r['id'] as String, r['payload'] as String);
      if (!ids.add(c.id) ||
          c.owner != b['owner'] ||
          (connected ? c.expectedVersion < 0 : c.expectedVersion != i) ||
          c.payload != r['payload'] ||
          DateTime.tryParse(r['recorded_at'] as String) == null) {
        reject('This backup’s history is damaged. Nothing changed.');
      }
    }
    if (connected) {
      final remote = b['connection'] as Map;
      if (remote['origin'] == 'staged') {
        if (!RegExp(r'^[0-9a-f-]{36}$')
                .hasMatch(remote['enrollment_id'] as String) ||
            (remote['enrollment_name'] as String).trim().isEmpty ||
            canonicalJson(
                  jsonDecode(remote['enrollment_snapshot'] as String),
                ) !=
                canonicalJson(commands)) {
          reject('This backup is damaged. Nothing changed.');
        }
      }
      if (!RegExp(r'^[0-9a-f-]{36}$')
              .hasMatch(remote['remote_owner'] as String) ||
          remote['email'] is! String) {
        reject('This backup is damaged. Nothing changed.');
      }
      final intents = b['intents'] as List;
      if (intents.length > 20000) reject('This backup is damaged. Nothing changed.');
      final intentIds = <String>{};
      var last = 0;
      for (final raw in intents) {
        final r = raw as Map;
        final c = LocalCommand.decode(
          r['id'] as String,
          r['payload'] as String,
        );
        final envelope = jsonDecode(r['envelope'] as String) as Map;
        if (!intentIds.add(c.id) ||
            c.owner != b['owner'] ||
            c.payload != r['payload'] ||
            envelope['contract'] != 2 ||
            envelope['profile_id'] != b['owner'] ||
            envelope['payload'] != c.payload ||
            r['sequence_no'] is! int ||
            (r['sequence_no'] as int) <= last ||
            DateTime.tryParse(r['recorded_at'] as String) == null) {
          reject('This backup is damaged. Nothing changed.');
        }
        last = r['sequence_no'] as int;
      }
    }
    if (b['format'] == 3) {
      if ((b['sharedReviews'] as List? ?? []).length > 20000) {
        reject('This backup is damaged. Nothing changed.');
      }
      for (final raw in b['sharedReviews'] as List? ?? []) {
        final r = raw as Map;
        if (r['profile_id'] != b['owner'] ||
            r['owner_id'] != (b['connection'] as Map)['remote_owner'] ||
            r['id'] is! String ||
            r['reason'] is! String) {
          reject('This backup is damaged. Nothing changed.');
        }
      }
      if ((b['sharedIntents'] as List).length > 20000 ||
          (b['sharedDrafts'] as List).length > 100) {
        reject('This backup is damaged. Nothing changed.');
      }
      final sharedIds = <String>{};
      for (final raw in b['sharedIntents'] as List) {
        final r = raw as Map;
        final payload = jsonDecode(r['payload'] as String) as Map;
        if (!sharedIds.add(r['id'] as String) ||
            !['bill', 'report'].contains(payload['op']) ||
            payload['contract'] != 3 ||
            payload['group'] != r['group_id'] ||
            DateTime.tryParse(r['recorded_at'] as String) == null) {
          reject('This backup is damaged. Nothing changed.');
        }
      }
      for (final raw in b['sharedDrafts'] as List) {
        final r = raw as Map;
        if ((r['payload'] as String).length > 131072 ||
            DateTime.tryParse(r['updated_at'] as String) == null) {
          reject('This backup is damaged. Nothing changed.');
        }
        jsonDecode(r['payload'] as String);
      }
    }
    for (final raw in drafts) {
      final r = raw as Map;
      if (ids.contains(r['command_id']) ||
          (r['operation'] as String).length > 200) {
        reject('This backup is damaged. Nothing changed.');
      }
      Map<String, String>.from(jsonDecode(r['values_json'] as String) as Map);
    }
  }

  static Future<Uint8List> seal(
    Map<String, dynamic> bundle,
    String secret,
  ) async {
    validate(bundle);
    final bytes = utf8.encode(jsonEncode(bundle));
    if (bytes.length > maxBytes) {
      reject('This backup is over the 32 MB limit. Nothing was saved.');
    }
    final box = await _cipher.encrypt(
      bytes,
      secretKey: _key(secret),
      aad: _header,
    );
    return Uint8List.fromList([..._header, ...box.concatenation()]);
  }

  static Future<Map<String, dynamic>> unseal(
    List<int> bytes,
    String secret,
  ) async {
    if (bytes.length < _header.length + 28 ||
        bytes.length > maxBytes + _header.length + 28 ||
        !List.generate(
          _header.length,
          (i) => bytes[i] == _header[i],
        ).every((x) => x)) {
      reject('This file isn’t a complete Salapiya backup.');
    }
    final plain = await _cipher.decrypt(
      SecretBox.fromConcatenation(
        bytes.sublist(_header.length),
        nonceLength: 12,
        macLength: 16,
      ),
      secretKey: _key(secret),
      aad: _header,
    );
    final bundle = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    validate(bundle);
    return bundle;
  }
}
