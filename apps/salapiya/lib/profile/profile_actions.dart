import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';

import '../connected/connected_runtime.dart';
import '../finance/bounded_file_read.dart';
import '../local/finance_domain.dart';
import '../local/local_profiles.dart';
import '../local/local_runtime.dart';
import '../p0/portable_recovery.dart';
import 'profile_data.dart';

/// Everything the Connection, Devices and Backup tabs can ask for. The real
/// build goes to the runtime and the store; the demo and tests stand in.
abstract interface class ProfileActions {
  /// Read at the moment it's needed: a step can change these.
  ConnectionFacts facts();
  Future<void> connect();
  Future<void> cancelSignIn();
  Future<void> lookup();
  Future<void> confirmConnection();
  Future<void> cancelConnection();
  Future<void> keepProfile();
  Future<void> useCloudProfile();
  Future<void> syncNow();
  Future<void> setPaused(bool paused);
  Future<void> signOut();
  Future<void> send(String id);
  Future<List<Map<String, dynamic>>> devices();
  Future<void> revoke(DeviceRow device);

  /// True when the server still has to finish clearing the sign-in identity.
  Future<bool> deleteAccount();
  Future<void> removeProfile();
  Future<String> newSecret();

  /// False when the user closed the save dialog.
  Future<bool> saveBackup(String secret);

  /// Null when the user closed the file dialog.
  Future<BackupContents?> checkBackup(String secret);
  Future<BackupNote?> lastBackup();
}

/// Saves the sealed backup and hands back where it went, or null.
typedef BackupSaver = Future<Uri?> Function(String name, Uint8List bytes);

/// Asks for a backup file and reads it, or null.
typedef BackupPicker = Future<List<int>?> Function();

Future<Uri?> _save(String name, Uint8List bytes) =>
    FilePicker.saveFile(fileName: name, bytes: bytes);

Future<List<int>?> _pick() async {
  final file = await FilePicker.pickFile();
  return file == null
      ? null
      : readBoundedFinancialFile(file, LocalBackup.maxBytes + 128);
}

/// Refusals Check a backup puts on the secret's field. Anything else is about
/// the file.
const backupSecretErrors = [
  'Enter the whole recovery secret',
  'This secret doesn’t open this backup',
];

class LocalProfileActions implements ProfileActions {
  LocalProfileActions(
    this.session, {
    this.saver = _save,
    this.picker = _pick,
  });
  final LocalSession session;
  final BackupSaver saver;
  final BackupPicker picker;
  LocalRuntime get runtime => session.runtime;
  ConnectedRuntime get c => runtime.connected;

  @override
  ConnectionFacts facts() {
    final binding = c.binding;
    final store = session.localFinance.store;
    final status = store.db.currentStatus;
    final flow = c.flow;
    final cloud = c.cloud;
    return ConnectionFacts(
      configured: c.configured,
      bound: binding?['phase'] as String?,
      signingIn: flow?.pending == true,
      signedIn: flow?.client.auth.currentUser != null,
      expired:
          c.sessionExpired ||
          (flow != null && flow.client.auth.currentSession == null),
      paused: binding?['paused'] == 1,
      busy: c.busy,
      active: status.connecting || status.uploading || status.downloading,
      reachable:
          c.error == null &&
          status.connected &&
          status.uploadError == null &&
          status.downloadError == null,
      otherProfile: cloud != null && cloud['id'] != store.owner,
      deleted: session.accountDeleted,
      enrollment: binding?['enrollment_snapshot'] != null,
      email: c.connected || flow?.client.auth.currentUser != null
          ? c.identity
          : null,
      lastSync: binding?['last_sync'] as String?,
      error: c.error,
      signInOutcome: flow?.outcome,
      cloudName: cloud?['name'] as String?,
      moneyWaiting: c.pendingCount,
      moneyReview: c.reviewCount,
      sharedWaiting: c.sharedPendingCount,
      sharedReview: c.sharedReviewCount,
      lifeWaiting: c.lifePendingCount,
      lifeReview: c.lifeReviewCount,
    );
  }

  @override
  Future<void> connect() => c.signIn();
  @override
  Future<void> cancelSignIn() => c.flow!.cancel();
  @override
  Future<void> lookup() => c.lookup();
  @override
  Future<void> confirmConnection() => c.confirmConnection();
  @override
  Future<void> cancelConnection() => c.cancelConnection();

  /// Forgets the other profile and the Google account that found it.
  @override
  Future<void> keepProfile() async {
    await c.cancelConnection();
    await c.signOut();
  }

  @override
  Future<void> useCloudProfile() => c.switchAfterBackup();
  @override
  Future<void> syncNow() => c.syncNow();
  @override
  Future<void> setPaused(bool paused) => c.pause(paused);
  @override
  Future<void> signOut() => c.signOut();
  @override
  Future<void> send(String id) => c.resumeMissing(id);
  @override
  Future<List<Map<String, dynamic>>> devices() => c.authorizedDevices();
  @override
  Future<void> revoke(DeviceRow device) async {
    await c.revokeDevice(device.id);
    if (device.current) await c.signOut();
  }

  @override
  Future<bool> deleteAccount() async {
    final pending = await c.deleteConnectedAccount();
    session.accountDeleted = true;
    c.changed();
    return pending;
  }

  @override
  Future<void> removeProfile() =>
      runtime.removeLocalProfile(session.localFinance.store.owner);
  @override
  Future<String> newSecret() => PortableRecovery.newRecoverySecret();

  @override
  Future<bool> saveBackup(String secret) async {
    await runtime.flushPreferences();
    final store = session.localFinance.store;
    final bytes = await LocalBackup.seal(
      await LocalBackup.capture(store),
      secret,
    );
    final saved = await saver(
      'salapiya-${civilToday()}-${newLocalId().substring(0, 8)}.salapiya',
      bytes,
    );
    if (saved == null) return false;
    try {
      await store.recordBackup();
    } catch (_) {
      // The backup is saved. Only the date on the tab is out of step.
    }
    return true;
  }

  @override
  Future<BackupContents?> checkBackup(String secret) async {
    final bytes = await picker();
    if (bytes == null) return null;
    try {
      return BackupContents.from(
        await LocalBackup.unseal(bytes, secret),
        session.localFinance.store.owner,
      );
    } on SecretBoxAuthenticationError {
      reject('This secret doesn’t open this backup.');
    } on FormatException {
      reject('Enter the whole recovery secret.');
    }
  }

  @override
  Future<BackupNote?> lastBackup() async {
    final note = await session.localFinance.store.lastBackup();
    return note == null ? null : BackupNote(note.at, changed: note.changed);
  }
}
