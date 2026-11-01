import '../design_system/kit/kit.dart' show DateField, detailLine;
import '../local/finance_domain.dart';
import '../p0/exact_money.dart';
import '../shared/shared_data.dart';

/// The tabs of Profile and settings, in order.
const profileTabs = [
  'Profile',
  'Connection',
  'Devices',
  'Backup & recovery',
  'Help',
];

/// What each tab is for, under the page's title.
String profileCaption(String tab) => switch (tab) {
  'Connection' => 'Where your data is and whether it’s syncing',
  'Devices' => 'Which devices have your profile',
  'Backup & recovery' => 'Keeping a copy, and getting it back',
  'Help' => 'Answers to common questions',
  _ => 'How this profile is set up',
};

/// Where the profile's records are kept, in a few words.
String keptLine({required bool connected}) => connected
    ? 'This device and your connected account'
    : 'On this device only';

/// The default group's choices. Null when choosing one means nothing: with
/// fewer than two active groups Shared Expenses never asks.
class DefaultGroupChoices {
  const DefaultGroupChoices(this.options, this.chosen, {this.lost = false});

  /// Null first, for Ask me each time, then each active group by name.
  final List<(String?, String)> options;
  final String? chosen;

  /// A group was saved as the default, and it's archived or the user left it.
  final bool lost;
  String get shown => options.firstWhere((o) => o.$1 == chosen).$2;
}

const askEachTime = 'Ask me each time';

DefaultGroupChoices? defaultGroupChoices(SharedSource source, String? saved) {
  final active = sharedGroupRows(source).where((r) => r.current).toList();
  if (active.length < 2) return null;
  final usable = active.any((r) => r.group.id == saved);
  return DefaultGroupChoices(
    [
      (null, askEachTime),
      for (final r in active) (r.group.id, r.group.name),
    ],
    usable ? saved : null,
    lost: saved != null && !usable,
  );
}

/// Where the connection stands. Display only, worked out from what the
/// runtime already says.
enum ConnectionPhase {
  unavailable,
  local,
  signingIn,
  chosen,
  otherProfile,
  unfinished,
  firstDownload,
  restoring,
  signedOut,
  paused,
  syncing,
  unreachable,
  waiting,
  needsReview,
  synced,
  deleted,
}

/// What the Connection tab can offer. The first one offered is the main one.
enum ConnectionAction {
  connect,
  cancelSignIn,
  review,
  dontConnect,
  saveBackup,
  useCloudProfile,
  keepProfile,
  resumeConnection,
  cancelConnection,
  reconnect,
  syncNow,
}

/// The plain values the Connection tab reads.
class ConnectionFacts {
  const ConnectionFacts({
    this.configured = true,
    this.bound,
    this.signingIn = false,
    this.signedIn = false,
    this.expired = false,
    this.paused = false,
    this.busy = false,
    this.active = false,
    this.reachable = true,
    this.otherProfile = false,
    this.deleted = false,
    this.enrollment = false,
    this.email,
    this.lastSync,
    this.error,
    this.signInOutcome,
    this.cloudName,
    this.moneyWaiting = 0,
    this.moneyReview = 0,
    this.sharedWaiting = 0,
    this.sharedReview = 0,
    this.lifeWaiting = 0,
    this.lifeReview = 0,
  });

  /// Whether this build can reach the service at all.
  final bool configured;

  /// The saved connection's stage: staged, published, connected or restored.
  /// Null with no connection.
  final String? bound;
  final bool signingIn, signedIn, expired, paused, busy;

  /// Something's moving: uploading, downloading or connecting.
  final bool active;
  final bool reachable, otherProfile, deleted;

  /// A restored connection that never reached the service still has what it
  /// needs to enroll, so it finishes through Review, not Sync.
  final bool enrollment;
  final String? email, lastSync, error, signInOutcome, cloudName;
  final int moneyWaiting, moneyReview;
  final int sharedWaiting, sharedReview, lifeWaiting, lifeReview;

  bool get connected => bound != null;
  int get waiting => moneyWaiting + sharedWaiting + lifeWaiting;

  /// What the user can act on here. Group refusals stay on Shared Expenses.
  int get toCheck => moneyReview + lifeReview;
}

ConnectionPhase phaseOf(ConnectionFacts f) {
  if (f.deleted) return ConnectionPhase.deleted;
  if (!f.configured) return ConnectionPhase.unavailable;
  if (f.signingIn) return ConnectionPhase.signingIn;
  if (f.otherProfile) return ConnectionPhase.otherProfile;
  if (f.bound == null) {
    return f.signedIn ? ConnectionPhase.chosen : ConnectionPhase.local;
  }
  if (f.bound == 'staged') return ConnectionPhase.unfinished;
  if (f.bound == 'restored') return ConnectionPhase.restoring;
  if (f.expired) return ConnectionPhase.signedOut;
  if (f.bound != 'connected') return ConnectionPhase.firstDownload;
  if (f.paused) return ConnectionPhase.paused;
  if (f.busy || f.active) return ConnectionPhase.syncing;
  if (!f.reachable) return ConnectionPhase.unreachable;
  if (f.waiting > 0) return ConnectionPhase.waiting;
  if (f.toCheck > 0) return ConnectionPhase.needsReview;
  return ConnectionPhase.synced;
}

/// Only what the rules allow now, so nothing is offered and then refused.
List<ConnectionAction> offered(ConnectionFacts f) => switch (phaseOf(f)) {
  ConnectionPhase.deleted ||
  ConnectionPhase.unavailable ||
  ConnectionPhase.syncing ||
  ConnectionPhase.paused => const [],
  ConnectionPhase.local => const [ConnectionAction.connect],
  ConnectionPhase.signingIn => const [ConnectionAction.cancelSignIn],
  ConnectionPhase.chosen => const [
    ConnectionAction.review,
    ConnectionAction.dontConnect,
  ],
  ConnectionPhase.otherProfile => const [
    ConnectionAction.saveBackup,
    ConnectionAction.useCloudProfile,
    ConnectionAction.keepProfile,
  ],
  ConnectionPhase.unfinished =>
    f.signedIn
        ? const [
            ConnectionAction.resumeConnection,
            ConnectionAction.cancelConnection,
          ]
        : const [ConnectionAction.reconnect],
  ConnectionPhase.restoring =>
    !f.signedIn
        ? const [ConnectionAction.reconnect]
        : f.enrollment
        ? const [ConnectionAction.resumeConnection]
        : const [ConnectionAction.syncNow],
  ConnectionPhase.signedOut => const [ConnectionAction.reconnect],
  ConnectionPhase.firstDownload ||
  ConnectionPhase.unreachable ||
  ConnectionPhase.waiting ||
  ConnectionPhase.needsReview ||
  ConnectionPhase.synced => const [ConnectionAction.syncNow],
};

/// Whether This device's switch and Sign out apply: a signed-in connection
/// that has finished connecting.
bool canManageSync(ConnectionFacts f) => switch (phaseOf(f)) {
  ConnectionPhase.firstDownload ||
  ConnectionPhase.paused ||
  ConnectionPhase.syncing ||
  ConnectionPhase.unreachable ||
  ConnectionPhase.waiting ||
  ConnectionPhase.needsReview ||
  ConnectionPhase.synced => true,
  _ => false,
};

/// The state in words: a headline and why it's so.
(String, String) phaseWords(ConnectionFacts f) => switch (phaseOf(f)) {
  ConnectionPhase.unavailable => (
    'Can’t connect in this build',
    'Your profile keeps working on this device.',
  ),
  ConnectionPhase.local => (
    'On this device only',
    'Nothing leaves this device. Connect a Google account to sync across '
        'your devices.',
  ),
  ConnectionPhase.signingIn => (
    'Waiting for Google',
    'Finish choosing your account in your browser.',
  ),
  ConnectionPhase.chosen => (
    'Google account chosen',
    'Nothing has been uploaded. Review what connecting does.',
  ),
  ConnectionPhase.otherProfile => (
    'This account has a different profile',
    'Salapiya never merges or overwrites a profile. Keep this one, or save '
        'a backup and switch.',
  ),
  ConnectionPhase.unfinished => (
    'Connection not finished',
    f.signedIn
        ? 'Finish connecting, or cancel and stay on this device.'
        : 'Sign in with the Google account you started with.',
  ),
  ConnectionPhase.firstDownload => (
    'First download not finished',
    'Totals aren’t complete until it finishes. Sync now carries on from '
        'where it stopped.',
  ),
  ConnectionPhase.restoring => (
    'Checking a restored backup',
    'Salapiya compares what was restored with your connected account '
        'before anything uploads.',
  ),
  ConnectionPhase.signedOut => (
    'Signed out',
    'Your records are still here. Changes wait until you sign in again.',
  ),
  ConnectionPhase.paused => (
    'Sync paused',
    'Changes wait on this device until you turn sync back on.',
  ),
  ConnectionPhase.syncing => (
    'Syncing',
    'Your records are safe while this runs.',
  ),
  ConnectionPhase.unreachable => (
    'Can’t reach the service',
    'Your records are safe here. Changes wait until the connection is back.',
  ),
  ConnectionPhase.waiting => (
    f.waiting == 1 ? '1 change waiting' : '${f.waiting} changes waiting',
    'They’re saved on this device and on their way.',
  ),
  ConnectionPhase.needsReview => (
    'Needs review',
    'Something couldn’t be saved as it was. Look at it below.',
  ),
  ConnectionPhase.synced => (
    'Synced',
    'Your changes have reached the service.',
  ),
  ConnectionPhase.deleted => (
    'Connected account deleted',
    'This profile stays on this device until you remove it.',
  ),
};

/// What a sign-in attempt ended with, when it needs saying.
String? signInNote(String? outcome) => switch (outcome) {
  null ||
  'ready' ||
  'google_code_exchange_verified' ||
  'waiting_for_google' ||
  'interrupted_attempt_restored' => null,
  'wrong_account_local_data_preserved' =>
    'That’s a different Google account. Sign in with the one this profile '
        'uses.',
  'cancelled_local_data_preserved' ||
  'provider_cancelled' => 'Sign-in cancelled. Your records haven’t changed.',
  'late_callback_ignored' =>
    'That sign-in was cancelled, so it was ignored. Start again when '
        'you’re ready.',
  _ => 'Sign-in didn’t finish. Your records are safe. Try again.',
};

/// "2 waiting · 1 to check", "Up to date".
String countsLine(int waiting, int toCheck) {
  final parts = [
    if (waiting > 0) '$waiting waiting',
    if (toCheck > 0) '$toCheck to check',
  ];
  return parts.isEmpty ? 'Up to date' : detailLine(parts);
}

const notRecorded = 'Not recorded';

/// A moment in Asia/Manila, in plain words.
String manilaWhen(String? moment, {String? today}) {
  final parsed = moment == null ? null : DateTime.tryParse(moment);
  if (parsed == null) return notRecorded;
  final m = parsed.toUtc().add(const Duration(hours: 8));
  final date = m.toIso8601String().substring(0, 10);
  final now = DateTime.parse(today ?? civilToday());
  final days = DateTime.parse(date).difference(now).inDays;
  final day = switch (days) {
    0 => 'Today',
    -1 => 'Yesterday',
    _ => DateField.format(DateTime.parse(date)),
  };
  final hour = m.hour % 12 == 0 ? 12 : m.hour % 12;
  final minute = '${m.minute}'.padLeft(2, '0');
  return '$day, $hour:$minute ${m.hour < 12 ? 'AM' : 'PM'}';
}

/// One sign-in on the server's list. Its session id never shows.
class DeviceRow {
  const DeviceRow({
    required this.id,
    required this.name,
    required this.status,
    required this.current,
    required this.active,
    required this.signedIn,
    required this.lastSeen,
    this.unknown = false,
  });
  final String id, name, status, signedIn, lastSeen;
  final bool current, active;

  /// An earlier sign-in, from before Salapiya recorded which device it was.
  final bool unknown;
}

String _deviceName(String label) => switch (label) {
  'Windows installation' => 'Windows',
  'Android installation' => 'Android',
  'Earlier sign-in; device unknown' => 'Earlier sign-in',
  _ => label,
};

/// This device first, then what's active, then what has ended.
List<DeviceRow> deviceRows(List<Map<String, dynamic>> rows, {String? today}) {
  int rank(Map<String, dynamic> d) => d['current'] == true
      ? 0
      : d['active'] == true
      ? 1
      : 2;
  final sorted = [...rows]..sort((a, b) => rank(a).compareTo(rank(b)));
  return [
    for (final d in sorted)
      DeviceRow(
        id: d['session_id'] as String,
        name: _deviceName(d['label'] as String? ?? ''),
        current: d['current'] == true,
        active: d['active'] == true,
        unknown: d['label'] == 'Earlier sign-in; device unknown',
        status: d['active'] != true
            ? d['revoked_at'] != null
                  ? 'Revoked'
                  : 'Signed out'
            : d['current'] == true
            ? 'This device'
            : 'Active',
        signedIn: manilaWhen(d['registered_at'] as String?, today: today),
        lastSeen: manilaWhen(d['last_seen_at'] as String?, today: today),
      ),
  ];
}

/// The last backup noted on this device.
class BackupNote {
  const BackupNote(this.at, {required this.changed});
  final String at;

  /// Records have changed since it was saved.
  final bool changed;
}

/// What's inside a backup, in plain terms. Only what's shown leaves the
/// opened backup: its records don't stay in memory.
class BackupContents {
  const BackupContents({
    required this.name,
    required this.created,
    required this.records,
    required this.drafts,
    required this.lifeVersions,
    required this.filesListed,
    required this.connected,
    required this.thisProfile,
  });
  final String name;

  /// The moment it was made, as recorded in it.
  final String created;
  final int records, drafts, lifeVersions;

  /// Null in an older backup that doesn't say.
  final int? filesListed;
  final bool connected, thisProfile;

  factory BackupContents.from(Map<String, dynamic> bundle, String owner) {
    final coverage = bundle['financialCoverage'] as Map?;
    final life = bundle['life'] as Map?;
    return BackupContents(
      name: bundle['name'] as String,
      created: bundle['createdUtc'] as String,
      records: (bundle['commands'] as List).length,
      drafts: (bundle['drafts'] as List).length,
      lifeVersions: (life?['revisions'] as List? ?? const []).length,
      filesListed: coverage?['supportingFileMetadata'] as int?,
      connected: const [2, 3].contains(bundle['format']),
      thisProfile: bundle['owner'] == owner,
    );
  }
}

/// How a backup's files read. Their contents are never in a backup.
String filesLine(int? listed) => switch (listed) {
  null => 'Not available in this backup',
  0 => 'No files listed',
  1 => '1 file listed, 0 files included. Keep your originals.',
  _ => '$listed files listed, 0 files included. Keep your originals.',
};

/// The server's and this app's reasons for a change that needs checking, in
/// plain words. The stored words stay as they are.
const changeReasons = {
  'source version changed or unavailable':
      'The record this was based on has changed since.',
  'sources changed; sync and review again':
      'Records it depends on have changed. Sync, then look at it again.',
  'resolve dependent evidence first':
      'Something else depends on this record. Deal with that first.',
  'refund exceeds unrefunded portion':
      'The refund is more than what’s left to refund.',
  'comparison sources changed':
      'The records it was compared with have changed.',
  'account unavailable, archived or before cutoff':
      'The account is archived or unavailable, or the date is before its '
      'starting balance.',
  'negative balance requires acknowledgement':
      'It would take an account below zero, which needs your OK first.',
  'account type or name conflict':
      'An account with that name or type already exists.',
  'category classification or name conflict':
      'A category with that name or type already exists.',
  'invalid or incompatible financial command':
      'The service couldn’t accept it.',
  'Command identity or payload requires review.':
      'The service saw a problem with this change.',
  'restored_missing':
      'This came from a backup, and the service has no record of it. You '
      'can send it now, as it was saved.',
  'restored_rejected':
      'The service refused this before. It came from a backup, with its '
      'values as they were saved.',
  'restored_mismatch':
      'The service has a different change under this one’s identity. Keep '
      'your backup, and leave this one as it is.',
  'restored_requires_current_receipt_review':
      'This came from a backup. Salapiya is still checking it with the '
      'service.',
};

/// One change to check, on Needs review.
class ReviewRow {
  const ReviewRow({
    required this.id,
    required this.title,
    required this.reason,
    required this.facts,
    required this.details,
    required this.canSend,
  });
  final String id, title, reason;

  /// What it was, in plain labels.
  final List<(String, String)> facts;

  /// The other saved values, under View details. Empty with amounts hidden.
  final List<(String, String)> details;

  /// The service has no record of it, so it can go as it was saved.
  final bool canSend;
}

const _factLabels = {
  'date': 'Date',
  'amount': 'Amount',
  'account': 'Account',
  'category': 'Category',
  'merchant': 'Merchant',
  'notes': 'Notes',
  'reference': 'Reference',
};

/// A change's saved values. An amount shows through [amount], which reads
/// "Amount hidden" with amounts hidden. Nothing unlabelled shows while they
/// are, because any stored value could hold a figure.
ReviewRow reviewRow(
  Map<String, dynamic> row, {
  required bool hidden,
  required bool connected,
  required String Function(BigInt) amount,
  required String Function(String id) accountName,
  required String Function(String id) categoryName,
}) {
  final id = row['id'] as String;
  final reason = row['reason'] as String?;
  final values = LocalCommand.decode(id, row['payload'] as String).values;
  String shown(String key, String value) => switch (key) {
    'date' => switch (DateTime.tryParse(value)) {
      final DateTime day => DateField.format(day),
      null => value,
    },
    'amount' => amount(parsePhp(value)),
    'account' => accountName(value),
    'category' => categoryName(value),
    _ => value,
  };
  bool has(String key) => (values[key] ?? '').trim().isNotEmpty;
  return ReviewRow(
    id: id,
    title:
        [
          values['description'],
          values['name'],
        ].nonNulls.where((t) => t.trim().isNotEmpty).firstOrNull ??
        'Financial change',
    reason:
        changeReasons[reason] ??
        reason ??
        'Your records changed, so this needs a look.',
    facts: [
      for (final MapEntry(key: key, value: label) in _factLabels.entries)
        if (has(key)) (label, shown(key, values[key]!)),
    ],
    details: hidden
        ? const []
        : [
            for (final e in values.entries)
              if (e.value.trim().isNotEmpty &&
                  !_factLabels.containsKey(e.key) &&
                  e.key != 'description' &&
                  e.key != 'name')
                (e.key, e.value),
          ],
    canSend: reason == 'restored_missing' && connected,
  );
}
