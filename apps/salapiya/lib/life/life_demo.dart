import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_data.dart';
import '../finance/debt_demo.dart';
import '../finance/money_demo.dart';
import '../app/overview_demo.dart' show demoSample;
import '../features/life/application/life_controller.dart' show AgendaItem;
import '../local/finance_domain.dart';
import '../prototype/scenarios.dart';
import 'life_controller.dart'
    show
        lifeAgendaItems,
        lifeCommandFor,
        lifeEntryData,
        lifeEventData,
        sortedAgenda;
import 'life_data.dart';
import 'life_domain.dart';
import 'device_reminders.dart';
import 'life_forms.dart';
import 'life_hub.dart';
import 'life_pages_detail.dart';
import 'life_settings.dart';
import 'reminder_data.dart';
import 'tasks_tab.dart' show openLifeTask;

/// The demo's Life records: a sample replayed through the real rules, dated
/// relative to today, so Calendar agrees with Debts, Cards, Planning and the
/// Overview's Next up in Life. Nothing is stored.
class DemoLife {
  DemoLife(this.records, this.log);
  final Map<String, LifeRecord> records;

  /// Every command, with when it was recorded, in order.
  final List<(String, LifeCommand)> log;
}

const _owner = '00000000-0000-4000-8000-00000000d000';
String _id(int n) =>
    '00000000-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}';

final _cache = <String, DemoLife>{};

/// The sample for [today], built once a day.
DemoLife demoLife(String today, {bool empty = false}) =>
    _cache.putIfAbsent('$today:$empty', () => _build(today, empty));

DemoLife _build(String today, bool empty) {
  final records = <String, LifeRecord>{};
  final log = <(String, LifeCommand)>[];
  if (empty) return DemoLife(records, log);
  var serial = 0;
  void save(
    int record,
    LifeType type,
    Map<String, String> fields, {
    String reason = 'Created',
    int daysAgo = 7,
  }) {
    final id = _id(record);
    final at = DateTime.parse(
      '${addCivilDays(today, -daysAgo)}T01:00:00Z',
    ).add(Duration(minutes: serial));
    final c = LifeCommand(
      id: _id(1000 + serial++),
      owner: _owner,
      recordId: id,
      type: type,
      expectedVersion: records[id]?.version ?? 0,
      fields: {...?records[id]?.fields, ...fields},
      reason: reason,
      recordedAt: at,
    );
    records[id] = applyLifeCommand(records, c);
    log.add((c.recordedAt.toIso8601String(), c));
  }

  String day(int offset) => addCivilDays(today, offset);
  void event(
    int record,
    String title,
    int offset,
    String time, {
    String timezone = 'Asia/Manila',
    String status = 'Scheduled',
    String archived = 'false',
    String location = '',
    String notes = '',
  }) => save(record, LifeType.personal, {
    'title': title,
    'date': day(offset),
    'time': time,
    'timezone': timezone,
    'status': status,
    'archived': archived,
    'location': location,
    'notes': notes,
  });
  void task(
    int record,
    String title,
    int? offset, {
    String priority = 'Normal',
    String status = 'Not started',
    String detail = '',
    String archived = 'false',
  }) => save(record, LifeType.task, {
    'title': title,
    'detail': detail,
    'due': offset == null ? '' : day(offset),
    'priority': priority,
    'status': status,
    'archived': archived,
  });

  // Events: all-day, timed, another timezone, gone by, cancelled, finished.
  event(
    1,
    'Dentist appointment',
    1,
    '10:00',
    location: 'Quezon City',
    notes: 'Bring the appointment card.',
  );
  save(
    1,
    LifeType.personal,
    {'time': '10:30', 'utc': ''},
    reason: 'The clinic moved it back',
    daysAgo: 2,
  );
  event(2, 'Team lunch', 0, '12:30', location: 'Makati');
  event(
    3,
    'Call with the Tokyo office',
    2,
    '09:00',
    timezone: 'Asia/Tokyo',
    location: 'Online',
  );
  event(4, 'Book club', 4, '19:00', location: 'Maginhawa');
  event(5, 'Mom’s birthday', 6, '');
  event(6, 'Eye check', -3, '15:00', location: 'Ortigas');
  event(7, 'Car service', 8, '08:30', status: 'Cancelled');
  event(8, 'Haircut', -5, '11:00', status: 'Completed');
  event(9, 'Old reunion', -40, '', archived: 'true');

  // Tasks: late, today, soon, later, undated, finished, archived.
  task(
    20,
    'Send the tax papers',
    -2,
    priority: 'High',
    detail: 'To the accountant',
  );
  task(21, 'Call the insurer', 0);
  task(
    22,
    'Renew driver’s license',
    2,
    priority: 'High',
    status: 'In progress',
  );
  task(23, 'Plan the trip', 12, priority: 'Low');
  task(24, 'Sort the receipts', null, priority: 'Low');
  task(25, 'Fix the shelf', 5, status: 'On hold');
  task(26, 'Book the car service', -6, status: 'Completed');
  task(27, 'Old errand', -30, archived: 'true');

  // Due dates and a career step, so every module shows.
  save(30, LifeType.learning, {
    'title': 'Thoughtful interfaces with Flutter',
    'detail': 'Self-paced course',
    'due': day(14),
    'total': '12',
    'progress': '5',
  });
  save(31, LifeType.book, {
    'title': 'The Art of Noticing',
    'detail': 'Rob Walker',
    'due': day(20),
    'total': '256',
    'progress': '96',
  });
  save(40, LifeType.application, {
    'title': 'Product designer',
    'company': 'Amihan Studio',
    'status': 'Interview',
    'pipelineStage': 'Interview',
    'outcome': '',
    'date': day(-14),
    'stageDate': day(-7),
    'location': 'Metro Manila',
  });
  save(41, LifeType.careerEvent, {
    'title': 'Interview',
    'eventKind': 'Interview',
    'application': _id(40),
    'date': day(3),
    'time': '10:00',
    'timezone': 'Asia/Manila',
  });
  return DemoLife(records, log);
}

/// One edit to look at, for the demo's review scenario: another device moved
/// the dentist while this one renamed it.
List<LifeReviewRow> demoReviews(DemoLife life) {
  final r = life.records[_id(1)]!;
  return [
    LifeReviewRow(
      LifeCommand(
        id: _id(900),
        owner: _owner,
        recordId: r.id,
        type: r.type,
        expectedVersion: 1,
        fields: {
          ...r.fields,
          'title': 'Dentist check-up',
          'time': '09:30',
          'utc': '',
        },
        reason: 'A clearer name',
        recordedAt: DateTime.parse('2026-01-01T01:00:00Z'),
      ),
      'Life source version changed; review current record',
      r,
    ),
  ];
}

/// Checks with the real rules, and keeps nothing.
class DemoLifeWriter implements LifeWriter {
  DemoLifeWriter(this.life, this.today);
  final DemoLife life;
  @override
  final String today;
  @override
  String timezone = 'Asia/Manila';
  final drafts = <String, Map<String, String>>{};

  @override
  bool get demo => true;
  @override
  LifeRecord? record(String? id) => life.records[id];
  @override
  Future<Map<String, String>?> draft(String operation) async =>
      drafts[operation];
  @override
  Future<void> saveDraft(
    String operation,
    String command,
    Map<String, String> values,
  ) async => drafts[operation] = values;
  @override
  Future<void> discardDraft(String operation) async =>
      drafts.remove(operation);
  @override
  LifeCommand eventCommand(Map<String, String> v, {String? old}) =>
      lifeCommandFor(
        _owner,
        LifeType.personal,
        v,
        lifeEventData(v),
        current: record(old)?.fields ?? const {},
        oldId: old,
        oldVersion: record(old)?.version,
      );
  @override
  Future<void> saveEvent(Map<String, String> v, {String? old}) async =>
      applyLifeCommand(life.records, eventCommand(v, old: old));
  @override
  Future<void> change(
    String id,
    int version,
    Map<String, String> fields,
    String reason,
  ) async {
    final r = life.records[id];
    if (r == null) lifeReject('This record isn’t available any more.');
    applyLifeCommand(
      life.records,
      LifeCommand(
        owner: _owner,
        recordId: id,
        type: r.type,
        expectedVersion: version,
        fields: {...r.fields, ...fields},
        reason: reason,
      ),
    );
  }

  @override
  LifeCommand taskCommand(Map<String, String> v, {String? old}) =>
      lifeCommandFor(
        _owner,
        LifeType.task,
        v,
        lifeEntryData(LifeType.task, v),
        current: record(old)?.fields ?? const {},
        oldId: old,
        oldVersion: record(old)?.version,
      );
  @override
  Future<void> saveTask(Map<String, String> v, {String? old}) async =>
      applyLifeCommand(life.records, taskCommand(v, old: old));
  @override
  Future<void> useEdit(LifeCommand command, String original) async =>
      applyLifeCommand(life.records, command);
  @override
  Future<void> keepCurrent(String original) async {}
  @override
  String savedLine(String command) =>
      'This is the demo, so nothing was saved.';
  @override
  Future<List<(String, LifeCommand)>> history(String id) async => [
    for (final (at, c) in life.log)
      if (c.recordId == id) (at, c),
  ];
}

/// What could remind the user, from the sample, 90 days either way.
List<AgendaItem> demoReminderItems(
  DemoLife life,
  LocalSnapshot s,
  String today,
) {
  final from = addCivilDays(today, -90), to = addCivilDays(today, 90);
  return sortedAgenda([
    ...lifeAgendaItems(life.records, from, to),
    for (final r in namedDueSources(
      s,
      financialReminderSources(s, from, to, asOf: today),
    ))
      AgendaItem(
        r.id,
        r.source,
        lifeModuleOf(r.kind),
        r.title,
        r.date,
        'All day',
        0,
        amount: r.amount,
      ),
  ]);
}

/// Reminders in the demo: a few states from the sample, kept in memory.
/// Nothing is delivered.
class DemoReminders implements LifeReminders {
  DemoReminders(this.hub);
  final LifeHub hub;
  List<AgendaItem> items = const [];
  final choices = <String, (String, String)>{};
  bool _preset = false;

  @override
  Map<String, dynamic> preferences = {
    'enabled': true,
    'quiet': true,
    'start': '22:00',
    'end': '07:00',
    'timezone': 'Device',
    'showDate': false,
    'modules': {for (final m in reminderModules) m: true},
  };

  @override
  bool get available => true;
  @override
  bool get on => preferences['enabled'] == true;
  @override
  bool get blocked => false;
  @override
  bool get unknown => false;
  @override
  bool get failed => false;
  @override
  String get capability => 'In the demo, reminders never show.';
  @override
  String get timezone => 'Asia/Manila';

  ReminderView _view(AgendaItem item, String mode, String action) {
    if (!on) return const ReminderView(ReminderState.off);
    if ((preferences['modules'] as Map)[item.kind] != true) {
      return const ReminderView(ReminderState.moduleOff);
    }
    if (mode == 'Off') return const ReminderView(ReminderState.turnedOff);
    if (action == 'Dismissed') {
      return const ReminderView(ReminderState.dismissed);
    }
    final now = DateTime.now().toUtc();
    if (action == 'Snoozed 1 hour') {
      return ReminderView(
        ReminderState.snoozed,
        at: now.add(const Duration(hours: 1)),
      );
    }
    final lead = switch (mode) {
      '15 minutes before' => const Duration(minutes: 15),
      '1 hour before' => const Duration(hours: 1),
      '1 day before' => const Duration(days: 1),
      '7 days before' => const Duration(days: 7),
      _ => Duration.zero,
    };
    final at = (item.utc ?? LifeTime.instant(item.date, '09:00', timezone))
        .subtract(lead);
    if (at.isBefore(now)) return const ReminderView(ReminderState.passed);
    return ReminderView(ReminderState.scheduled, at: at);
  }

  @override
  List<ReminderRow> get rows {
    if (!_preset) {
      _preset = true;
      for (final item in items) {
        if (item.title == 'Book club') {
          choices[item.id] = ('Inherited', 'Dismissed');
        } else if (item.title == 'Plan the trip') {
          choices[item.id] = ('Off', 'Planned');
        } else if (item.title == 'Mom’s birthday') {
          choices[item.id] = ('1 day before', 'Planned');
        }
      }
    }
    return [
      for (final item in items)
        () {
          final (mode, action) = choices[item.id] ?? ('Inherited', '');
          return ReminderRow(item, _view(item, mode, action), mode);
        }(),
    ];
  }

  @override
  Future<void> configure(
    Map<String, dynamic> changes, {
    bool request = false,
  }) async {
    final next = {...preferences, ...changes};
    if (next['start'] == next['end']) {
      lifeReject('Quiet hours need a different start and end.');
    }
    preferences = next;
    hub.touch();
  }

  @override
  Future<void> choose(ReminderRow row, String mode, String action) async {
    choices[row.id] = (mode, action);
    hub.touch();
  }

  @override
  Future<void> recheck() async {}
  @override
  Future<bool> sendTest() async => false;
  @override
  Future<List<ReminderLog>> log() async => [
    for (final r in rows)
      if (r.view.state == ReminderState.passed)
        ReminderLog(
          r.title,
          'elapsed',
          r.item.utc ?? LifeTime.instant(r.item.date, '09:00', timezone),
          row: r,
        ),
    ReminderLog(
      'Car service',
      'obsolete',
      DateTime.now().toUtc().subtract(const Duration(days: 2)),
    ),
  ];
}

/// Life on the demo build: the sample above and the Overview's money sample,
/// with the demo session's scenario and hidden amounts applied.
LifeSource demoLifeSource(BuildContext context, PrototypeSession session) {
  final hub = lifeHubOf(session);
  final today = civilToday();
  final life = demoLife(today, empty: session.empty);
  final s = demoSample(today, empty: session.empty);
  final writer = hub.demoWriter(life, today);
  final timezone = hub.view['timezone'] as String;
  writer.timezone = timezone;
  void open(String module, String id) => switch (module) {
    'Personal' => openLifeEvent(context, session, id),
    'Tasks' => openLifeTask(context, session, id),
    'Debts' => openDebtDue(demoDebtsSource(context, session), id),
    'Cards' || 'Recurring' => demoMoneySource(
      context,
      session,
    ).actions.openItem(id),
    _ => hub.openTab?.call(module),
  };
  return LifeSource(
    today: today,
    timezone: timezone,
    complete: session.complete,
    hidden: session.hideAmounts,
    amount: session.amount,
    records: life.records,
    snapshot: s,
    writer: writer,
    visible: hub.calendarShown,
    waiting: session.pending ? 1 : 0,
    reviews: session.needsReview ? demoReviews(life) : const [],
    reminders: hub.demoReminders..items = demoReminderItems(life, s, today),
    actions: LifeActions(
      addEvent: () => openEventForm(context, session),
      addTask: () => openTaskForm(context, session),
      editEvent: (id) => openEventForm(context, session, id: id),
      openEvent: (id) => openLifeEvent(context, session, id),
      editTask: (id) => openTaskForm(context, session, id: id),
      openTask: (id) => openLifeTask(context, session, id),
      openRow: (row) => open(row.module, row.sourceId),
      openItem: (item) => open(item.kind, item.sourceId),
      openList: (page, title) =>
          openDemoPage<void>(context, page, 'life/list', title: title),
      reminders: () => openLifeReminders(context, session),
      preferences: () => openDemoPage<void>(
        context,
        LifeSettings(session: session),
        'life/settings',
      ),
      reminderFor: (item) => lifeReminderControls(session, item),
    ),
  );
}
