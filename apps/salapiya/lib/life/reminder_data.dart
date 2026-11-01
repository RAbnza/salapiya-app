import '../features/life/application/life_controller.dart' show AgendaItem;
import '../app/overview_data.dart' show debtRecord;
import '../features/finance/application/financial_controller.dart';
import '../local/local_finance_controller.dart';
import 'device_reminders.dart';
import 'life_controller.dart';
import 'native_notifications.dart';

/// Display-only reminder data (DESIGN_SYSTEM §8, Chat 12). Scheduling stays in
/// `DeviceReminders`; this says what it decided, in words a person can read.

/// One item with a possible reminder.
class ReminderRow {
  const ReminderRow(this.item, this.view, this.mode, {this.name});
  final AgendaItem item;
  final ReminderView view;

  /// The stored mode: 'Inherited', 'At due time', '1 day before' and so on.
  final String mode;

  /// A better name than the item's own, where there is one.
  final String? name;

  String get id => item.id;
  String get title => name ?? item.title;
  bool get allDay => item.time == 'All day';

  /// Snoozing only makes sense once a reminder has fired: before that it would
  /// fire early, and the real one would be lost.
  bool get canSnooze => view.state == ReminderState.passed;
  bool get canDismiss => const {
    ReminderState.scheduled,
    ReminderState.snoozed,
    ReminderState.passed,
  }.contains(view.state);
  bool get dismissed => view.state == ReminderState.dismissed;
  bool get turnedOff => mode == 'Off';

  /// Coming, not gone by. With no time to go on, its date decides, so an
  /// overdue item with reminders off isn't "coming".
  bool upcoming(String today) =>
      view.state != ReminderState.passed &&
      (view.at != null || item.date.compareTo(today) >= 0);
}

/// What a past reminder became.
class ReminderLog {
  const ReminderLog(this.title, this.state, this.due, {this.row});
  final String title, state;
  final DateTime due;

  /// The item, while it's still around.
  final ReminderRow? row;
}

/// The stored modes to offer: all-day items have no time to count minutes
/// from, so those go, unless one is already chosen.
List<String> reminderChoices(bool allDay, String current) => [
  for (final mode in reminderModes)
    if (mode != 'Off' &&
        (mode == current ||
            mode == 'Inherited' ||
            !const {'At due time'}.contains(mode) &&
                (!allDay ||
                    !const {
                      '15 minutes before',
                      '1 hour before',
                    }.contains(mode))))
      mode,
];

/// A stored mode in plain words. The stored value doesn't change.
String reminderModeLabel(String mode, bool allDay) => switch (mode) {
  'Inherited' => allDay ? 'Default (on the day)' : 'Default (at the time)',
  'At due time' => allDay ? 'On the day' : 'At the time',
  _ => mode,
};

/// What became of a past reminder, for a stored state.
String reminderLogLine(String state) => switch (state) {
  'elapsed' => 'Its time passed. Salapiya can’t tell whether it showed.',
  'suppressed' => 'Skipped: its time had passed when it was set',
  'obsolete' => 'Cancelled: what it was for changed',
  'dismissed' => 'Dismissed',
  _ => 'Set on this device',
};

/// What Reminders reads and changes, on both builds. Everything here stays on
/// this device.
abstract interface class LifeReminders {
  /// Whether this device can schedule anything at all.
  bool get available;

  /// The user turned reminders on here.
  bool get on;

  /// On, but the device refuses them.
  bool get blocked;

  /// The device won't say whether they can show.
  bool get unknown;
  bool get failed;
  String get capability;
  Map<String, dynamic> get preferences;
  String get timezone;

  /// Every item that could remind the user, nearest first.
  List<ReminderRow> get rows;
  Future<void> configure(Map<String, dynamic> changes, {bool request = false});
  Future<void> choose(ReminderRow row, String mode, String action);
  Future<void> recheck();

  /// Whether a test was really sent.
  Future<bool> sendTest();
  Future<List<ReminderLog>> log();
}

/// Reminders nearest first. One with no time, because it's dismissed or off,
/// stays in date order, so it can't sink below reminders weeks later.
List<ReminderRow> sortedReminders(Iterable<ReminderRow> rows) {
  DateTime when(ReminderRow r) =>
      r.view.at ?? DateTime.parse('${r.item.date}T00:00:00Z');
  return rows.toList()..sort((a, b) => when(a).compareTo(when(b)));
}

/// What's coming, and how many are really set.
List<ReminderRow> comingReminders(List<ReminderRow> rows, String today) => [
  for (final r in sortedReminders(rows))
    if (r.upcoming(today)) r,
];

int setReminders(List<ReminderRow> rows) => rows
    .where(
      (r) => const {
        ReminderState.scheduled,
        ReminderState.snoozed,
      }.contains(r.view.state),
    )
    .length;

/// The real device.
class LocalReminders implements LifeReminders {
  LocalReminders(this.c, this.finance);
  final DurableLifeController c;
  final FinancialController finance;
  DeviceReminders? get d => c.device;

  @override
  bool get available => d?.ready == true;
  @override
  bool get on => d?.preferences['enabled'] == true;
  @override
  bool get blocked => on && d?.allowed == false;
  @override
  bool get unknown => d?.permissionKnown == false;
  @override
  bool get failed => d?.reconcileFailed == true;
  @override
  String get capability => d?.device.capability ?? '';
  @override
  Map<String, dynamic> get preferences => d?.preferences ?? const {};
  @override
  String get timezone => d?.timezone ?? 'Asia/Manila';

  @override
  List<ReminderRow> get rows {
    final device = d;
    if (device == null) return const [];
    return [
      for (final item in device.sources())
        ReminderRow(
          item,
          device.views[item.id] ?? const ReminderView(ReminderState.checking),
          (device.choices[item.id] as Map?)?['mode'] as String? ?? 'Inherited',
          name: _debtName(item),
        ),
    ];
  }

  /// A debt's row carries its schedule's title; people know it by its name.
  String? _debtName(AgendaItem item) {
    final f = finance;
    if (item.kind != 'Debts' || f is! LocalFinancialController) return null;
    final s = f.acceptedSnapshot;
    return debtRecord(s, s.revision(item.sourceId).values['debt'])?.title;
  }

  @override
  Future<void> configure(Map<String, dynamic> changes, {bool request = false}) =>
      d!.configure(changes, request: request);
  @override
  Future<void> choose(ReminderRow row, String mode, String action) =>
      c.reminder(row.item, mode, action);
  @override
  Future<void> recheck() async => d?.reconcile();
  @override
  Future<bool> sendTest() async {
    final device = d?.device;
    if (device is! NativeNotificationDevice) return false;
    await device.showTest();
    await d!.reconcile();
    return true;
  }

  @override
  Future<List<ReminderLog>> log() async {
    final device = d;
    if (device == null) return const [];
    final current = {for (final r in rows) r.id: r};
    final now = DateTime.now().toUtc();
    return [
      for (final row in await device.history())
        if (row['state'] != 'scheduled' && row['state'] != 'prepared' ||
            DateTime.parse(row['due_utc'] as String).isBefore(now))
          ReminderLog(
            current[row['source_id']]?.title ?? 'Something no longer here',
            row['state'] as String,
            DateTime.parse(row['due_utc'] as String),
            row: current[row['source_id']],
          ),
    ];
  }
}
