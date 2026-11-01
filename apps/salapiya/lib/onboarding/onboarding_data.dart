import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../local/local_profiles.dart';

/// What this installation holds before a profile is open. Read only: it
/// mirrors what `LocalProfiles.create` will accept, so Welcome doesn't offer
/// what would then be refused. The stored key never leaves [readDeviceStart].
class DeviceStart {
  const DeviceStart({
    this.phase,
    this.keptFiles = false,
    this.keptName,
    this.pendingName,
  });
  static const fresh = DeviceStart();

  /// The saved stage, or null on a device that has never held a profile.
  final String? phase;

  /// An earlier profile's files are still here, so a new one can't start.
  final bool keptFiles;

  /// That profile's name, when it's known.
  final String? keptName;

  /// The name of a first run or restore that didn't finish.
  final String? pendingName;

  /// The last profile here was removed, and nothing of it is left.
  bool get removedLast => phase == 'empty' && !keptFiles;

  /// A first run or restore stopped part-way. Starting anything else would be
  /// refused, so it carries on instead.
  bool get unfinished => phase == 'initializing' || phase == 'restoring';
  bool get canCreate => (phase == null || phase == 'empty') && !keptFiles;
}

Future<DeviceStart> readDeviceStart(LocalProfiles profiles) async {
  final raw = await profiles.vault.read();
  Map<String, dynamic>? saved;
  if (raw != null) {
    try {
      saved = jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return DeviceStart.fresh;
    }
  }
  final phase = saved?['phase'] as String?;
  final kept = saved?['preserved'];
  final mayStart = phase == null || phase == 'empty';
  final files =
      mayStart &&
      await profiles.directory.exists() &&
      await profiles.directory.list().any(
        (f) => p.basename(f.path).contains('.sqlite'),
      );
  return DeviceStart(
    phase: phase,
    keptFiles: files,
    keptName: kept is Map ? kept['name'] as String? : null,
    pendingName: phase == 'initializing' || phase == 'restoring'
        ? saved!['name'] as String?
        : null,
  );
}

/// Why Salapiya couldn't open. Each has its own words on the failure screen.
enum StartupProblem {
  keyUnavailable,
  unreadable,
  missingRecords,
  newerVersion,
  damaged,
  restoreUnfinished,
  removalUnfinished,
  unknown,
}

/// The rules' words, as each starts. `rule_messages_test` holds these to the
/// rule files.
const startupMessages = <String, StartupProblem>{
  'Salapiya can’t reach the key': StartupProblem.keyUnavailable,
  'Salapiya can’t read what it needs': StartupProblem.unreadable,
  'Your profile’s records aren’t on this device': StartupProblem.missingRecords,
  'This version of Salapiya can’t open your records':
      StartupProblem.newerVersion,
  'Salapiya found a problem with your records': StartupProblem.damaged,
  'Some of your records are incomplete': StartupProblem.damaged,
  'Your records don’t add up': StartupProblem.damaged,
  'These records belong to a different profile': StartupProblem.damaged,
  'A restore didn’t finish': StartupProblem.restoreUnfinished,
  'Invalid recovery staging descriptor': StartupProblem.restoreUnfinished,
  'This profile’s folder points somewhere else':
      StartupProblem.removalUnfinished,
  'Some of this profile’s files are links': StartupProblem.removalUnfinished,
  'Some of this profile’s attached files are links':
      StartupProblem.removalUnfinished,
  'Invalid profile identity': StartupProblem.removalUnfinished,
  'Local removal path is outside': StartupProblem.removalUnfinished,
};

/// Which problem this is, from the rule's words and the stage that was saved.
/// A removal or restore that stopped part-way is what matters most, whatever
/// went wrong under it.
StartupProblem startupProblemOf(String? message, {String? phase}) {
  if (phase == 'removing') return StartupProblem.removalUnfinished;
  if (phase == 'restoring') return StartupProblem.restoreUnfinished;
  if (message == null) return StartupProblem.unknown;
  for (final MapEntry(key: start, value: problem) in startupMessages.entries) {
    if (message.startsWith(start)) return problem;
  }
  return StartupProblem.unknown;
}

/// What the failure screen says.
class StartupWords {
  const StartupWords({
    required this.title,
    required this.happened,
    required this.safe,
    required this.canDo,
  });
  final String title, happened, safe, canDo;
}

const _elsewhere =
    'A backup can restore them on another device, and Google sign-in there '
    'brings back what has synced.';

StartupWords startupWords(
  StartupProblem problem, {
  String? message,
  required bool desktop,
}) {
  final account = desktop ? 'Windows account' : 'account on this phone';
  return switch (problem) {
    StartupProblem.keyUnavailable => StartupWords(
      title: 'Salapiya can’t reach your profile’s key',
      happened:
          'The key that opens your profile isn’t available right now. Your '
          'device keeps it, not Salapiya.',
      safe: 'Your files. Nothing was reset or replaced.',
      canDo: 'Make sure you’re signed in to the same $account, then try again.',
    ),
    StartupProblem.unreadable => const StartupWords(
      title: 'Salapiya can’t read what opens your profile',
      happened: 'What Salapiya keeps to open your profile can’t be read.',
      safe: 'Your files. Nothing was reset or replaced.',
      canDo: 'Try again. If this keeps happening, $_elsewhere',
    ),
    StartupProblem.missingRecords => const StartupWords(
      title: 'Your records aren’t on this device',
      happened: 'The file that holds your records has gone from this device.',
      safe: 'Nothing was replaced with an empty profile.',
      canDo: 'If you moved it, put it back and try again. $_elsewhere',
    ),
    StartupProblem.newerVersion => const StartupWords(
      title: 'This version can’t open your records',
      happened: 'Your records need a newer version of Salapiya.',
      safe: 'Your files. Nothing was changed.',
      canDo: 'Update Salapiya, then open it again.',
    ),
    StartupProblem.damaged => const StartupWords(
      title: 'Salapiya found a problem with your records',
      happened:
          'A check on your records didn’t pass, so Salapiya stopped before '
          'opening them.',
      safe: 'Your files. Salapiya didn’t change them.',
      canDo: 'Keep your files as they are. $_elsewhere',
    ),
    StartupProblem.restoreUnfinished => StartupWords(
      title: 'A restore didn’t finish',
      happened:
          message != null && message.startsWith('A restore didn’t finish')
          ? message
          : 'Salapiya was restoring a backup here and stopped part-way.',
      safe: 'Your backup file isn’t affected.',
      canDo:
          'Try again. If this keeps happening, your backup can restore on '
          'another device.',
    ),
    StartupProblem.removalUnfinished => StartupWords(
      title: 'Removing this profile didn’t finish',
      happened:
          message != null &&
              startupMessages[_startOf(message)] ==
                  StartupProblem.removalUnfinished &&
              !message.startsWith('Invalid') &&
              !message.startsWith('Local')
          ? message
          : 'Salapiya was removing this profile from this device and stopped '
                'part-way.',
      safe: 'Your backups and connected account aren’t affected.',
      canDo: 'Try again. Salapiya carries on from where it stopped.',
    ),
    StartupProblem.unknown => StartupWords(
      title: 'Salapiya couldn’t open your profile',
      happened: 'Something on this device stopped it from opening.',
      safe: 'Your files. Nothing was reset or replaced.',
      canDo:
          'Check there’s free storage and that you’re signed in to the same '
          '$account, then try again.',
    ),
  };
}

String? _startOf(String message) {
  for (final start in startupMessages.keys) {
    if (message.startsWith(start)) return start;
  }
  return null;
}

/// How a sign-in ended, on a device with no profile yet, so nothing can talk
/// about "your records". Null when there's nothing to say.
String? noProfileNote(String? outcome) => switch (outcome) {
  null ||
  'ready' ||
  'google_code_exchange_verified' ||
  'waiting_for_google' ||
  'interrupted_attempt_restored' => null,
  'wrong_account_local_data_preserved' =>
    'That Google account can’t be used here. Try another one.',
  'cancelled_local_data_preserved' ||
  'provider_cancelled' => 'Sign-in cancelled. Nothing was uploaded.',
  'late_callback_ignored' =>
    'That sign-in was cancelled, so it was ignored. Start again when you’re '
        'ready.',
  'browser_launch_failed' =>
    'Your browser didn’t open. Check that one is set up, then try again.',
  'expired_attempt_preserved_local_data' =>
    'That sign-in took too long, so it stopped. Start again when you’re ready.',
  _ => 'Sign-in didn’t finish. Nothing was uploaded. Try again.',
};

/// The connection's messages that assume a profile, as they read without one.
/// `rule_messages_test` holds the keys to the rule file.
const noProfileErrors = {
  'The connection dropped. Your records and waiting changes are safe. Try '
          'again when you’re connected.':
      'The connection dropped. Nothing changed on this device. Try again when '
      'you’re connected.',
  'The service couldn’t do that. Try again when you’re connected. Your '
          'records are safe.':
      'The service couldn’t do that. Nothing changed on this device. Try '
      'again when you’re connected.',
  'Sign in with the Google account this profile uses. Your records are still '
          'here.':
      'Sign in with Google again. Nothing changed on this device.',
  'You’ve been signed out. Sign in again to sync. Your records are still '
          'here.':
      'You’ve been signed out. Sign in again. Nothing changed on this device.',
  'Can’t connect right now. Your records are safe on this device.':
      'Can’t connect right now. Try again when you’re connected.',
};

String noProfileError(String message) => noProfileErrors[message] ?? message;

/// What the failure screen can show about the installation.
class StartupFacts {
  const StartupFacts({this.phase, this.folder});

  /// The stage that was saved, when it can be read.
  final String? phase;

  /// Where the profile's files are. Shown only under Show details.
  final String? folder;
}

/// Reads the saved stage after a failed start. Failing here changes nothing:
/// the screen just has less to say.
Future<StartupFacts> readStartupFacts(LocalProfiles profiles) async {
  final folder = profiles.directory.path;
  try {
    return StartupFacts(
      phase: (await readDeviceStart(profiles)).phase,
      folder: folder,
    );
  } on FileSystemException {
    return StartupFacts(folder: folder);
  } catch (_) {
    return StartupFacts(folder: folder);
  }
}
