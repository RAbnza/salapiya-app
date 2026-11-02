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
        lifeApplicationData,
        lifeCheckDuplicate,
        lifeCommandFor,
        lifeEntryData,
        lifeEventData,
        lifeIsDuplicate,
        lifeProgressCommand,
        lifeStepData,
        sortedAgenda;
import 'life_data.dart';
import 'life_domain.dart';
import 'device_reminders.dart';
import 'life_forms.dart';
import 'life_hub.dart';
import 'life_pages_detail.dart';
import 'life_settings.dart';
import 'career_forms.dart';
import 'career_pages.dart';
import 'progress_forms.dart';
import 'progress_pages.dart';
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
    final at = DateTime.parse('${addCivilDays(today, -daysAgo)}T01:00:00Z')
        .add(Duration(minutes: serial));
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
  event(4, 'Book club', 1, '19:00', location: 'Maginhawa');
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

  void learning(
    int record,
    String title,
    String detail, {
    int? due,
    int total = 1,
    int progress = 0,
    String status = 'In progress',
    int? finished,
    String archived = 'false',
  }) => save(record, LifeType.learning, {
    'title': title,
    'detail': detail,
    'due': due == null ? '' : day(due),
    'total': '$total',
    'progress': '$progress',
    'status': status,
    'completed': finished == null ? '' : day(finished),
    'archived': archived,
  });
  void book(
    int record,
    String title,
    String author, {
    int? due,
    int total = 1,
    int progress = 0,
    String status = 'In progress',
    int? finished,
    String rating = '',
    String archived = 'false',
  }) => save(record, LifeType.book, {
    'title': title,
    'detail': author,
    'due': due == null ? '' : day(due),
    'total': '$total',
    'progress': '$progress',
    'status': status,
    'completed': finished == null ? '' : day(finished),
    'rating': rating,
    'archived': archived,
  });

  // Learning: in progress, late, no total, not started, on hold, finished.
  learning(
    30,
    'Thoughtful interfaces with Flutter',
    'Self-paced course',
    due: 14,
    total: 12,
    progress: 4,
  );
  save(
    30,
    LifeType.learning,
    {'progress': '5', 'status': 'In progress'},
    reason: 'Finished the layout lesson',
    daysAgo: 2,
  );
  learning(
    32,
    'Everyday Spanish',
    'Practice sessions',
    due: -2,
    total: 30,
    progress: 8,
  );
  learning(33, 'Public speaking', 'Toastmasters club');
  learning(
    34,
    'Data storytelling',
    'Online workshop',
    status: 'Not started',
    due: 40,
    total: 6,
  );
  learning(35, 'Basic accounting', 'Library course', status: 'Not started');
  learning(
    36,
    'Watercolor basics',
    'Weekend class',
    total: 8,
    progress: 3,
    status: 'On hold',
  );
  learning(
    37,
    'Intro to Dart',
    'Official tour',
    total: 10,
    progress: 10,
    status: 'Completed',
    finished: -21,
  );
  learning(
    38,
    'First aid refresher',
    'Red Cross',
    status: 'Completed',
    progress: 1,
  );
  learning(
    39,
    'Old typing course',
    '',
    total: 20,
    progress: 2,
    archived: 'true',
  );

  // Books: reading, on the list, on hold, finished, abandoned.
  book(
    31,
    'The Art of Noticing',
    'Rob Walker',
    due: 20,
    total: 256,
    progress: 96,
  );
  book(
    42,
    'A Field Guide to Getting Lost',
    'Rebecca Solnit',
    total: 224,
    progress: 32,
  );
  book(43, 'Piranesi', 'Susanna Clarke', status: 'Not started', due: 45);
  book(44, 'Noli Me Tangere', 'José Rizal', status: 'Not started', total: 480);
  book(45, 'The Overstory', 'Richard Powers', status: 'Not started');
  book(
    46,
    'Middlemarch',
    'George Eliot',
    total: 880,
    progress: 120,
    status: 'On hold',
  );
  book(
    47,
    'Dekada ’70',
    'Lualhati Bautista',
    total: 216,
    progress: 216,
    status: 'Completed',
    finished: -12,
    rating: '4.5',
  );
  book(
    48,
    'Four Thousand Weeks',
    'Oliver Burkeman',
    total: 272,
    progress: 272,
    status: 'Completed',
  );
  book(
    49,
    'A Very Long Saga',
    'Anonymous',
    total: 900,
    progress: 40,
    archived: 'true',
  );

  void application(
    int record,
    String company,
    String position,
    String stage, {
    int? applied,
    int? moved,
    Map<String, String> more = const {},
  }) => save(record, LifeType.application, {
    'title': position,
    'company': company,
    'status': stage,
    'pipelineStage': stage,
    'outcome': '',
    'date': applied == null ? '' : day(applied),
    'stageDate': day(moved ?? applied ?? -10),
    ...more,
  });
  void step(
    int record,
    int on,
    String kind,
    int offset, {
    String time = '',
    String timezone = 'Asia/Manila',
    String status = 'Scheduled',
    String location = '',
    String notes = '',
    String outcome = '',
  }) => save(record, LifeType.careerEvent, {
    'title': kind,
    'eventKind': kind,
    'application': _id(on),
    'date': day(offset),
    'time': time,
    'timezone': timezone,
    'status': status,
    'location': location,
    'notes': notes,
    'outcome': outcome,
  });

  /// Closes an application the way the Record outcome form does.
  void close(int record, String outcome, int offset, {String? stage}) => save(
    record,
    LifeType.application,
    {
      'status': outcome,
      'pipelineStage': stage ?? records[_id(record)]!.fields['pipelineStage']!,
      'outcome': outcome,
      'stageDate': day(offset),
    },
    reason: 'Heard back',
    daysAgo: 1,
  );

  // Career: every stage and outcome, a step in another timezone, an overdue
  // follow-up, a salary in another currency, and a step that was cancelled.
  application(
    40,
    'Amihan Studio',
    'Product designer',
    'Interview',
    applied: -14,
    moved: -7,
    more: {
      'location': 'Metro Manila',
      'arrangement': 'hybrid',
      'source': 'A friend at the studio',
      'postingUrl': 'https://example.com/careers/product-designer',
      'technologies': 'Figma, Flutter',
      'description': 'Design and ship the mobile product with a small team. Portfolio review, then two interviews.',
      'contact': 'Tala Reyes, recruiter · tala@example.com',
      'resume': 'Resume v4',
      'salaryMin': '60000',
      'salaryMax': '80000',
      'nextAction': 'Prepare the portfolio walkthrough',
      'notes': 'They liked the case study.',
    },
  );
  step(
    41,
    40,
    'Interview',
    3,
    time: '10:00',
    location: 'Online',
    notes: 'Portfolio conversation.',
  );
  step(
    70,
    40,
    'Interview',
    -6,
    time: '14:00',
    status: 'Completed',
    outcome: 'Went well',
    notes: 'First conversation.',
  );
  step(
    71,
    40,
    'Response',
    -9,
    status: 'Completed',
    notes: 'They asked for an interview.',
  );
  application(
    50,
    'North & Co.',
    'UX engineer',
    'Saved',
    more: {'nextAction': 'Ask Tala about the team'},
  );
  application(
    51,
    'Bayan Digital',
    'Flutter developer',
    'Applied',
    applied: -12,
    more: {
      'followUp': day(-3),
      'nextAction': 'Check how the application is going',
      'location': 'Taguig',
      'arrangement': 'remote',
      'source': 'Job board',
    },
  );
  application(
    52,
    'Sinag Labs',
    'Mobile engineer',
    'Screening',
    applied: -20,
    moved: -6,
  );
  step(72, 52, 'Follow-up', 1, notes: 'Ask about the next round.');
  application(
    53,
    'Tala Systems',
    'Senior designer',
    'Technical assessment',
    applied: -25,
    moved: -4,
  );
  step(73, 53, 'Assessment', -2, time: '09:00', notes: 'Take-home task.');
  step(
    74,
    53,
    'Interview',
    9,
    time: '11:00',
    status: 'Cancelled',
    notes: 'They moved to a written round.',
  );
  application(
    54,
    'Kapwa Health',
    'Product lead',
    'Final interview',
    applied: -30,
    moved: -3,
  );
  step(
    75,
    54,
    'Interview',
    2,
    time: '09:00',
    timezone: 'Australia/Sydney',
    location: 'Video call',
  );
  application(
    55,
    'Alon & Co.',
    'Design manager',
    'Offer',
    applied: -40,
    moved: -1,
    more: {
      'salaryMin': '3000',
      'salaryMax': '3500',
      'currency': 'USD',
      'nextAction': 'Reply by Friday',
    },
  );
  step(76, 55, 'Offer', -1, status: 'Completed', notes: 'Offer by email.');
  application(
    56,
    'Liwanag Studio',
    'Designer',
    'Offer',
    applied: -90,
    moved: -60,
  );
  close(56, 'Accepted', -50, stage: 'Accepted');
  application(57, 'Hangin Tech', 'Frontend developer', 'Applied', applied: -34);
  step(
    77,
    57,
    'No response',
    -13,
    status: 'Completed',
    notes: 'Three weeks, nothing yet.',
  );
  close(57, 'Rejected', -8);
  application(
    58,
    'Bukid Foods',
    'Product designer',
    'Screening',
    applied: -50,
    moved: -44,
  );
  close(58, 'Withdrawn', -30);
  application(59, 'Daloy Works', 'UX lead', 'Offer', applied: -70, moved: -55);
  close(59, 'Declined offer', -52);
  application(60, 'Palay Inc.', 'Designer', 'Offer', applied: -80, moved: -66);
  close(60, 'Expired offer', -56);
  application(
    61,
    'Sampaguita Co.',
    'Researcher',
    'Interview',
    applied: -100,
    moved: -80,
  );
  close(61, 'Employer-cancelled opening', -70);
  application(
    62,
    'Ilog Partners',
    'Designer',
    'Applied',
    applied: -200,
    more: {'archived': 'true'},
  );

  // Documents: here, on another device, and an archived link.
  void document(
    int record,
    String name,
    String mime,
    int size, {
    String archived = 'false',
  }) => save(record, LifeType.document, {
    'title': name,
    'application': _id(40),
    'sourceVersion': '1',
    'status': 'Linked',
    'mime': mime,
    'size': '$size',
    'checksum': 'a' * 64,
    'archived': archived,
  }, reason: 'Attached private Career document metadata');
  document(80, 'Resume v4.pdf', 'application/pdf', 182400);
  document(81, 'Portfolio cover.png', 'image/png', 920000);
  document(82, 'Old resume.pdf', 'application/pdf', 164000, archived: 'true');
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
  Future<void> discardDraft(String operation) async => drafts.remove(operation);
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
  LifeCommand entryCommand(
    LifeType type,
    Map<String, String> v, {
    String? old,
  }) => lifeCommandFor(
    _owner,
    type,
    v,
    lifeEntryData(type, v),
    current: record(old)?.fields ?? const {},
    oldId: old,
    oldVersion: record(old)?.version,
  );
  @override
  Future<void> saveEntry(
    LifeType type,
    Map<String, String> v, {
    String? old,
  }) async => applyLifeCommand(life.records, entryCommand(type, v, old: old));
  @override
  LifeCommand applicationCommand(Map<String, String> v, {String? old}) {
    if (old == null) lifeCheckDuplicate(life.records, v);
    return lifeCommandFor(
      _owner,
      LifeType.application,
      v,
      lifeApplicationData(v),
      current: record(old)?.fields ?? const {},
      oldId: old,
      oldVersion: record(old)?.version,
    );
  }

  @override
  Future<void> saveApplication(Map<String, String> v, {String? old}) async =>
      applyLifeCommand(life.records, applicationCommand(v, old: old));
  @override
  bool duplicateApplication(Map<String, String> v) =>
      lifeIsDuplicate(life.records, v);
  @override
  LifeCommand stepCommand(
    Map<String, String> v,
    String application, {
    String? old,
  }) => lifeCommandFor(
    _owner,
    LifeType.careerEvent,
    v,
    lifeStepData(v, application),
    current: record(old)?.fields ?? const {},
    oldId: old,
    oldVersion: record(old)?.version,
  );
  @override
  Future<void> saveStep(
    Map<String, String> v,
    String application, {
    String? old,
  }) async =>
      applyLifeCommand(life.records, stepCommand(v, application, old: old));
  @override
  LifeCommand progressCommand(Map<String, String> v, String id) {
    final r = record(id);
    if (r is! ProgressRecord) {
      lifeReject('This record isn’t available any more.');
    }
    return lifeProgressCommand(_owner, r, v);
  }

  @override
  Future<void> saveProgress(Map<String, String> v, String id) async =>
      applyLifeCommand(life.records, progressCommand(v, id));
  @override
  Future<void> useEdit(LifeCommand command, String original) async =>
      applyLifeCommand(life.records, command);
  @override
  Future<void> keepCurrent(String original) async {}
  @override
  String savedLine(String command) => 'This is the demo, so nothing was saved.';
  @override
  Future<List<(String, LifeCommand)>> history(String id) async => [
    for (final (at, c) in life.log)
      if (c.recordId == id) (at, c),
  ];
}

/// The demo has no encrypted store, so its files are only their details.
class DemoDocuments implements LifeDocuments {
  const DemoDocuments();
  static const _nothing =
      'Files need the encrypted store, so the demo can’t open or save them.';

  @override
  bool get demo => true;

  /// One sample file is on another device, so that state shows.
  @override
  Future<bool> present(String id) async => id != _id(81);
  @override
  Future<List<PendingDocument>> pending(String application) async => const [];
  @override
  Future<String?> attach(BuildContext context, String application) async =>
      _nothing;
  @override
  Future<String?> finish(PendingDocument pending) async => _nothing;
  @override
  Future<String?> letGo(PendingDocument pending) async => _nothing;
  @override
  Future<String?> preview(
    BuildContext context,
    CareerDocumentRecord record,
  ) async => _nothing;
  @override
  Future<String?> openElsewhere(CareerDocumentRecord record) async => _nothing;
  @override
  Future<String?> saveCopy(CareerDocumentRecord record) async => _nothing;
  @override
  Future<String?> restore(CareerDocumentRecord record) async => _nothing;
  @override
  Future<String?> removeCopy(CareerDocumentRecord record) async => _nothing;
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
    'Learning' || 'Books' => openLifeEntry(context, session, id),
    'Career' => openLifeApplication(context, session, id),
    'Debts' => openDebtDue(demoDebtsSource(context, session), id),
    'Cards' ||
    'Recurring' => demoMoneySource(context, session).actions.openItem(id),
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
    documents: const DemoDocuments(),
    actions: LifeActions(
      addEvent: () => openEventForm(context, session),
      addTask: () => openTaskForm(context, session),
      editEvent: (id) => openEventForm(context, session, id: id),
      openEvent: (id) => openLifeEvent(context, session, id),
      editTask: (id) => openTaskForm(context, session, id: id),
      openTask: (id) => openLifeTask(context, session, id),
      addEntry: (type) => openEntryForm(context, session, type),
      openEntry: (id) => openLifeEntry(context, session, id),
      editEntry: (id) =>
          openEntryForm(context, session, life.records[id]!.type, id: id),
      logProgress: (id) => openProgressForm(context, session, id),
      addApplication: () => openApplicationForm(context, session),
      openApplication: (id) => openLifeApplication(context, session, id),
      editApplication: (id) => openApplicationForm(context, session, id: id),
      changeStage: (id) =>
          openStageForm(context, session, id, StageChange.stage),
      recordOutcome: (id) =>
          openStageForm(context, session, id, StageChange.outcome),
      reopenApplication: (id) =>
          openStageForm(context, session, id, StageChange.reopen),
      addStep: (id) => openStepForm(context, session, id),
      openStep: (id) => openCareerStep(context, session, id),
      editStep: (application, id) =>
          openStepForm(context, session, application, id: id),
      openRow: (row) => row.module == 'Career'
          ? openCareerItem(context, session, row.id, row.sourceId)
          : open(row.module, row.sourceId),
      openItem: (item) => item.kind == 'Career'
          ? openCareerItem(context, session, item.id, item.sourceId)
          : open(item.kind, item.sourceId),
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
