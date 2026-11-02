import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_data.dart';
import 'package:salapiya/app/overview_demo.dart';
import 'package:salapiya/features/life/application/life_controller.dart'
    show AgendaItem;
import 'package:salapiya/life/agenda_page.dart';
import 'package:salapiya/life/device_reminders.dart';
import 'package:salapiya/life/life_controller.dart';
import 'package:salapiya/life/life_data.dart';
import 'package:salapiya/life/life_demo.dart';
import 'package:salapiya/life/life_domain.dart';
import 'package:salapiya/life/native_notifications.dart';
import 'package:salapiya/life/reminder_data.dart';
import 'package:salapiya/local/finance_domain.dart';

const today = '2026-11-04'; // A Wednesday.
const owner = '00000000-0000-4000-8000-000000000001';
var _n = 100;
String id() =>
    '00000000-0000-4000-8000-${(_n++).toRadixString(16).padLeft(12, '0')}';

LifeRecord event(
  String date,
  String time, {
  String timezone = 'Asia/Manila',
  String status = 'Scheduled',
  String archived = 'false',
  String fold = '',
}) => LifeRecord.read(id(), owner, 1, LifeType.personal, {
  'title': 'An event',
  'date': date,
  'time': time,
  'timezone': timezone,
  'status': status,
  'archived': archived,
  'fold': fold,
});

LifeRecord task(String due, {String status = 'Not started'}) => LifeRecord.read(
  id(),
  owner,
  1,
  LifeType.task,
  {'title': 'A task', 'due': due, 'status': status},
);

Map<String, LifeRecord> byId(List<LifeRecord> records) => {
  for (final r in records) r.id: r,
};

LifeSource source(
  Map<String, LifeRecord> records, {
  LocalSnapshot? snapshot,
  bool complete = true,
  String timezone = 'Asia/Manila',
  bool Function(String)? visible,
  String day = today,
  String? now,
}) => LifeSource(
  today: day,
  now: now,
  timezone: timezone,
  complete: complete,
  hidden: false,
  amount: (v) => '$v',
  records: records,
  snapshot: snapshot ?? demoSample(day, empty: true),
  writer: DemoLifeWriter(DemoLife(records, const []), day),
  visible: visible ?? (_) => true,
  actions: LifeActions(
    addEvent: () {},
    addTask: () {},
    editEvent: (_) {},
    openEvent: (_) {},
    editTask: (_) {},
    openTask: (_) {},
    addEntry: (_) {},
    openEntry: (_) {},
    editEntry: (_) {},
    logProgress: (_) {},
    addApplication: () {},
    openApplication: (_) {},
    editApplication: (_) {},
    changeStage: (_) {},
    recordOutcome: (_) {},
    reopenApplication: (_) {},
    addStep: (_) {},
    openStep: (_) {},
    editStep: (_, _) {},
    openItem: (_) {},
    openRow: (_) {},
    openList: (_, _) {},
    reminders: () {},
    reminderFor: (_) => const SizedBox.shrink(),
  ),
);

void main() {
  group('rows', () {
    test('nothing recorded means no rows', () {
      expect(source(const {}).rowsThrough('2026-12-31'), isEmpty);
    });

    test('an overdue task is late; an event gone by is only past', () {
      final s = source(
        byId([task('2026-11-02'), event('2026-11-02', '10:00')]),
      );
      final rows = s.rowsThrough(today);
      final t = rows.firstWhere((r) => !r.event);
      final e = rows.firstWhere((r) => r.event);
      expect(t.late, isTrue);
      expect(t.days, -2);
      expect(e.late, isFalse);
      expect(e.past, isTrue);
    });

    test('a due today is not late', () {
      final rows = source(byId([task(today)])).rowsThrough(today);
      expect(rows.single.late, isFalse);
      expect(rows.single.status, DebtDueStatus.dueToday);
    });

    test('there is no lookback limit on what is late', () {
      final rows = source(byId([task('2001-01-01')])).rowsThrough(today);
      expect(rows.single.late, isTrue);
    });

    test('finished, cancelled and archived items leave the Calendar', () {
      final rows = source(
        byId([
          task(today, status: 'Completed'),
          event(today, '10:00', status: 'Cancelled'),
          event(today, '11:00', status: 'Completed'),
          event(today, '12:00', archived: 'true'),
        ]),
      ).rowsThrough(today);
      expect(rows, isEmpty);
    });

    test('all-day items come first, then by time', () {
      final rows = source(
        byId([event(today, '09:00'), event(today, ''), task(today)]),
      ).rowsThrough(today);
      expect(rows.first.allDay, isTrue);
      expect(rows.last.time, '09:00');
    });

    test('an all-day date never moves with the timezone', () {
      final rows = source(
        byId([event(today, '')]),
        timezone: 'America/Los_Angeles',
      ).rowsThrough(today);
      expect(rows.single.date, today);
      expect(rows.single.allDay, isTrue);
    });

    test('a timed event sits on its date in the display timezone', () {
      // 09:00 in Tokyo is 16:00 the evening before in Los Angeles.
      final rows = source(
        byId([event(today, '09:00', timezone: 'Asia/Tokyo')]),
        timezone: 'America/Los_Angeles',
      ).rowsThrough(today);
      expect(rows.single.date, '2026-11-03');
      expect(rows.single.time, '16:00');
      expect(rows.single.recordedZone, 'Asia/Tokyo');
      expect(rows.single.recordedTime, '09:00');
      expect(rows.single.recordedDate, today);
    });

    test('an event in the display timezone has no second time', () {
      final rows = source(byId([event(today, '09:00')])).rowsThrough(today);
      expect(rows.single.recordedZone, isNull);
    });

    test('a module switched off leaves the rows', () {
      final records = byId([task(today), event(today, '09:00')]);
      final rows = source(
        records,
        visible: (m) => m != 'Tasks',
      ).rowsThrough(today);
      expect(rows.map((r) => r.module), ['Personal']);
    });

    test('money rows wait for the download, and match Debts when it ends', () {
      final s = demoSample(today);
      final calendar = source(const {}, snapshot: s);
      final due = overviewDueSources(s, today);
      final through = due
          .map((r) => r.date)
          .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      final rows = calendar.rowsThrough(through);
      expect(rows.map((r) => r.id).toSet(), due.map((r) => r.id).toSet());
      expect(
        {for (final r in rows) r.id: r.title},
        {for (final r in due) r.id: r.title},
      );
      expect(
        source(const {}, snapshot: s, complete: false).rowsThrough(through),
        isEmpty,
      );
    });

    test('a recurring bill is a money row, added dates only', () {
      final s = demoSample(today);
      final rows = source(
        const {},
        snapshot: s,
      ).rowsThrough(addCivilDays(today, 60));
      final bills = rows.where((r) => r.module == 'Recurring');
      expect(bills, isNotEmpty);
      for (final r in bills) {
        expect(r.dueKind, 'Recurring expectation');
        expect(r.amount, isNotNull);
      }
    });

    test('a reversed source leaves its row, because rows are live', () {
      final s = demoSample(today);
      final before = source(const {}, snapshot: s).rowsThrough(today);
      expect(
        source(
          const {},
          snapshot: demoSample(today, empty: true),
        ).rowsThrough(today),
        isEmpty,
      );
      expect(before, isNotEmpty);
    });
  });

  group('calendar', () {
    LifeCalendar calendar(
      List<LifeRecord> records, {
      String day = today,
      String? now,
    }) => LifeCalendar(
      source(byId(records), day: day).rowsThrough('2100-01-01'),
      day,
      monthStart(day),
      day,
      now: now,
    );

    test('this week runs from today to Sunday', () {
      final c = calendar([
        task('2026-11-03'),
        task(today),
        task('2026-11-08'),
        task('2026-11-09'),
      ]);
      expect(c.thisWeek.map((r) => r.date), [today, '2026-11-08']);
    });

    test('coming up is the seven days after today', () {
      final c = calendar([
        task(today),
        task('2026-11-05'),
        task('2026-11-11'),
        task('2026-11-12'),
      ]);
      expect(c.comingUp.map((r) => r.date), ['2026-11-05', '2026-11-11']);
    });

    test('next skips what has already gone by today', () {
      final c = calendar([
        event(today, '09:00'),
        event(today, '15:00'),
      ], now: '12:00');
      expect(c.next?.time, '15:00');
      expect(calendar([event(today, '09:00')], now: '12:00').next, isNull);
    });

    test('a month grid has every day, and marks what is late', () {
      final c = calendar([task('2026-11-02'), task('2026-11-30')]);
      expect(c.days, hasLength(30));
      expect(c.days[1].late, isTrue);
      expect(c.days.last.count, 1);
      expect(c.days.last.late, isFalse);
    });

    test('February and year ends hold', () {
      expect(calendar(const [], day: '2028-02-29').days, hasLength(29));
      expect(calendar(const [], day: '2027-02-10').days, hasLength(28));
      expect(
        calendar([task('2027-01-01')], day: '2026-12-31').comingUp,
        hasLength(1),
      );
    });

    test('the window reaches the month on show and the week ahead', () {
      expect(lifeWindowEnd('2026-12-29', '2026-12-01'), '2027-01-05');
      expect(lifeWindowEnd(today, '2027-03-01'), '2027-03-31');
      expect(lifeWindowEnd(today, '2026-01-01'), '2026-11-30');
    });
  });

  group('lists', () {
    test('periods cross a year end', () {
      expect(periodSpan(LifePeriod.next, '2026-12-15'), (
        '2027-01-01',
        '2027-01-31',
      ));
      expect(periodSpan(LifePeriod.week, '2026-12-30'), (
        '2026-12-28',
        '2027-01-03',
      ));
      expect(periodSpan(LifePeriod.month, '2026-02-10'), (
        '2026-02-01',
        '2026-02-28',
      ));
    });

    test('rows group by day, in order', () {
      final rows = source(
        byId([event(today, '09:00'), task(today), task('2026-11-05')]),
      ).rowsThrough('2026-11-30');
      final days = rowsByDay(rows);
      expect(days.map((d) => d.$1), [today, '2026-11-05']);
      expect(days.first.$2, hasLength(2));
    });

    test('counts are by kind, with no money total', () {
      final s = demoSample(today);
      final rows = source(
        byId([event(today, '09:00'), task(today)]),
        snapshot: s,
      ).rowsThrough(today);
      final counts = rowCounts(rows);
      expect(counts.events, 1);
      expect(counts.deadlines, 1);
      expect(counts.dues, rows.where((r) => r.money).length);
    });
  });

  group('events', () {
    test('each event has one state', () {
      PersonalRecord r(
        String date, {
        String status = 'Scheduled',
        String a = 'false',
      }) => event(date, '', status: status, archived: a) as PersonalRecord;
      expect(
        eventState(r('2026-11-05'), today, '2026-11-05'),
        EventState.scheduled,
      );
      expect(eventState(r(today), today, today), EventState.scheduled);
      expect(eventState(r('2026-11-03'), today, '2026-11-03'), EventState.past);
      expect(
        eventState(r(today, status: 'Completed'), today, today),
        EventState.completed,
      );
      expect(
        eventState(r(today, status: 'Cancelled'), today, today),
        EventState.cancelled,
      );
      expect(
        eventState(r(today, a: 'true'), today, today),
        EventState.archived,
      );
    });

    test('retired events are the ones off the Calendar, newest first', () {
      final old = event('2026-10-01', '', status: 'Completed');
      final newer = event('2026-10-20', '', status: 'Cancelled');
      final retired = retiredEvents(byId([old, event(today, ''), newer]));
      expect(retired.map((r) => r.id), [newer.id, old.id]);
    });
  });

  group('clock changes', () {
    test('a time in a gap is refused, in plain words', () {
      expect(
        LifeTime.candidates('2026-03-08', '02:30', 'America/New_York'),
        isEmpty,
      );
      expect(
        () => LifeTime.instant('2026-03-08', '02:30', 'America/New_York'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('doesn’t happen on this date'),
          ),
        ),
      );
    });

    test('a repeated time needs a choice, and each choice is its own time', () {
      expect(
        LifeTime.candidates('2026-11-01', '01:30', 'America/New_York'),
        hasLength(2),
      );
      expect(
        () => LifeTime.instant('2026-11-01', '01:30', 'America/New_York'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('happens twice'),
          ),
        ),
      );
      final first = LifeTime.instant(
        '2026-11-01',
        '01:30',
        'America/New_York',
        'Earlier',
      );
      final last = LifeTime.instant(
        '2026-11-01',
        '01:30',
        'America/New_York',
        'Later',
      );
      expect(last.difference(first), const Duration(hours: 1));
    });

    test('an event on a repeated time keeps its choice', () {
      final rows = source(
        byId([
          event(
            '2026-11-01',
            '01:30',
            timezone: 'America/New_York',
            fold: 'Later',
          ),
        ]),
        timezone: 'America/New_York',
        day: '2026-10-30',
      ).rowsThrough('2026-11-30');
      expect(rows.single.time, '01:30');
      final r = rows.single.item!;
      expect(r.utc, isNotNull);
      expect(
        r.utc,
        LifeTime.instant('2026-11-01', '01:30', 'America/New_York', 'Later'),
      );
    });
  });

  group('tasks', () {
    List<TaskRow> rows(List<LifeRecord> records, {String day = today}) =>
        taskRows(byId(records), day);
    LifeRecord dated(String due, {String priority = 'Normal'}) =>
        LifeRecord.read(id(), owner, 1, LifeType.task, {
          'title': 'A task',
          'due': due,
          'priority': priority,
          'status': 'Not started',
        });

    test('nothing recorded means nothing to do', () {
      final counts = TaskCounts(rows(const []));
      expect(counts.toDo, 0);
      expect(counts.oldest, isNull);
      expect(counts.next, isEmpty);
    });

    test('each task sits in one group, by the Manila civil day', () {
      final r = rows([
        task('2026-11-03'),
        task(today),
        task('2026-11-08'),
        task('2026-11-09'),
        task(''),
        task('2026-11-02', status: 'Completed'),
      ]);
      expect(r.map((t) => t.group), [
        TaskGroup.overdue,
        TaskGroup.today,
        TaskGroup.week,
        TaskGroup.later,
        TaskGroup.undated,
        TaskGroup.completed,
      ]);
    });

    test('Sunday ends the week, and next Monday is later', () {
      const sunday = '2026-11-08';
      final r = rows([task('2026-11-08'), task('2026-11-09')], day: sunday);
      expect(r.map((t) => t.group), [TaskGroup.today, TaskGroup.later]);
    });

    test('a year end and a leap day hold', () {
      final r = rows([task('2027-01-03')], day: '2026-12-29');
      expect(r.single.group, TaskGroup.week);
      expect(
        rows([task('2028-02-29')], day: '2028-02-29').single.group,
        TaskGroup.today,
      );
    });

    test('earliest first, then High, Normal, Low', () {
      final r = rows([
        dated('2026-11-20', priority: 'Low'),
        dated('2026-11-20', priority: 'High'),
        dated('2026-11-20'),
      ]);
      expect(r.map((t) => t.priority), ['High', 'Normal', 'Low']);
    });

    test('an archived task is archived, whatever else it is', () {
      final r = LifeRecord.read(id(), owner, 1, LifeType.task, {
        'title': 'A task',
        'due': '2026-11-01',
        'status': 'Completed',
        'archived': 'true',
      });
      expect(rows([r]).single.group, TaskGroup.archived);
    });

    test('counts are of open tasks; This week starts today', () {
      final counts = TaskCounts(
        rows([
          task('2026-11-01'),
          task(today),
          task('2026-11-06'),
          task('2026-11-20'),
          task(''),
          task(today, status: 'Completed'),
          task(today, status: 'On hold'),
        ]),
      );
      expect(counts.toDo, 6);
      expect(counts.overdue, 1);
      expect(counts.oldest, 3);
      expect(counts.dueToday, 2);
      expect(counts.thisWeek, 3);
      expect(counts.undated, 1);
      expect(counts.onHold, 1);
      expect(counts.priority('Normal'), 6);
    });

    test('Next up leaves out what is on hold, and undated goes last', () {
      final next = TaskCounts(
        rows([task(''), task(today, status: 'On hold'), task('2026-11-20')]),
      ).next;
      expect(next.map((t) => t.group), [TaskGroup.later, TaskGroup.undated]);
    });

    test('filters and search', () {
      final r = rows([
        task(today),
        task(today, status: 'Completed'),
        LifeRecord.read(id(), owner, 1, LifeType.task, {
          'title': 'Gone',
          'detail': 'At the bank',
          'status': 'Not started',
          'archived': 'true',
        }),
      ]);
      expect(filterTasks(r, TaskFilter.active), hasLength(1));
      expect(filterTasks(r, TaskFilter.completed), hasLength(1));
      expect(filterTasks(r, TaskFilter.archived), hasLength(1));
      expect(filterTasks(r, TaskFilter.all), hasLength(3));
      expect(filterTasks(r, TaskFilter.all, 'BANK').single.title, 'Gone');
    });
  });

  group('reviews', () {
    LifeCommand edit(String title, {int version = 1, String? record}) =>
        LifeCommand(
          owner: owner,
          recordId: record ?? owner,
          type: LifeType.task,
          expectedVersion: version,
          fields: {'title': title, 'due': today, 'status': 'Not started'},
          reason: 'Mine',
        );

    test('only refused edits that nobody dealt with are listed', () {
      final c = edit('One'), done = edit('Two'), held = edit('Three');
      final rows = lifeReviewRows([
        {'id': c.id, 'payload': c.payload, 'state': 'review'},
        {
          'id': done.id,
          'payload': done.payload,
          'state': 'review',
          'resolved_at': 'now',
        },
        {'id': held.id, 'payload': held.payload, 'state': 'restored'},
      ], const {});
      expect(rows.map((r) => r.id), [c.id]);
    });

    test('it shows only what differs, by name', () {
      final current = task(today);
      final r = LifeReviewRow(
        edit('Renamed', record: current.id),
        null,
        current,
      );
      expect(r.differences, [('title', 'A task', 'Renamed')]);
      expect(r.usable, isTrue);
    });

    test('an edit to a record that is gone can only be kept', () {
      final r = LifeReviewRow(edit('Renamed'), null, null);
      expect(r.usable, isFalse);
      expect(LifeReviewRow(edit('New', version: 0), null, null).usable, isTrue);
    });
  });

  group('reminders', () {
    AgendaItem item({String time = '09:00', String date = today}) =>
        AgendaItem('life:1', '1', 'Personal', 'A thing', date, time, 1);
    ReminderRow row(
      ReminderState state, {
      String mode = 'Inherited',
      String time = '09:00',
      DateTime? at,
    }) => ReminderRow(item(time: time), ReminderView(state, at: at), mode);

    test('an all-day item offers no minutes before', () {
      final choices = reminderChoices(true, 'Inherited');
      expect(choices, ['Inherited', '1 day before', '7 days before']);
      expect(reminderChoices(false, 'Inherited'), [
        'Inherited',
        '15 minutes before',
        '1 hour before',
        '1 day before',
        '7 days before',
      ]);
    });

    test('a choice already saved stays offered', () {
      expect(reminderChoices(true, '1 hour before'), contains('1 hour before'));
      expect(reminderChoices(true, 'At due time'), contains('At due time'));
    });

    test('Off is its own action, never a choice in the list', () {
      expect(reminderChoices(false, 'Off'), isNot(contains('Off')));
    });

    test('Default says what it does; stored values stay', () {
      expect(reminderModeLabel('Inherited', true), 'Default (on the day)');
      expect(reminderModeLabel('Inherited', false), 'Default (at the time)');
      expect(reminderModeLabel('1 day before', true), '1 day before');
    });

    test('Snooze is offered only once a reminder has fired', () {
      for (final state in ReminderState.values) {
        expect(
          row(state).canSnooze,
          state == ReminderState.passed,
          reason: '$state',
        );
      }
    });

    test('only what can fire can be dismissed', () {
      expect(row(ReminderState.scheduled).canDismiss, isTrue);
      expect(row(ReminderState.passed).canDismiss, isTrue);
      expect(row(ReminderState.off).canDismiss, isFalse);
      expect(row(ReminderState.turnedOff).canDismiss, isFalse);
    });

    test('nearest first, never oldest first', () {
      final soon = row(ReminderState.scheduled, at: DateTime.utc(2026, 11, 5));
      final later = row(ReminderState.scheduled, at: DateTime.utc(2026, 12, 5));
      final gone = row(ReminderState.passed);
      final off = row(ReminderState.off);
      // Off today, so it sits before what's set for next month.
      expect(comingReminders([later, gone, off, soon], today), [
        off,
        soon,
        later,
      ]);
    });

    test('an overdue item with reminders off isn’t coming', () {
      final late = ReminderRow(
        item(date: '2026-11-01', time: 'All day'),
        const ReminderView(ReminderState.off),
        'Inherited',
      );
      expect(comingReminders([late], today), isEmpty);
    });

    test('set counts what the device really holds', () {
      expect(
        setReminders([
          row(ReminderState.scheduled),
          row(ReminderState.snoozed),
          row(ReminderState.off),
          row(ReminderState.passed),
        ]),
        2,
      );
    });

    test('past reminders read plainly, and promise nothing', () {
      expect(reminderLogLine('elapsed'), contains('can’t tell'));
      expect(reminderLogLine('obsolete'), contains('changed'));
      expect(reminderLogLine('suppressed'), contains('Skipped'));
    });

    test('a notification holds no title, amount, company or name', () {
      expect(reminderTitle, 'Salapiya reminder');
      expect(reminderBody(), isNot(contains('commitment')));
      expect(reminderBody(), isNot(contains('₱')));
      expect(
        reminderBody(showDate: true, date: '2026-11-02'),
        contains('2 Nov 2026'),
      );
    });
  });

  group('history and reasons', () {
    test('each version says only what changed', () {
      final a = LifeCommand(
        owner: owner,
        recordId: owner,
        type: LifeType.task,
        expectedVersion: 0,
        fields: {'title': 'One', 'due': today},
        reason: 'Created',
      );
      final b = LifeCommand(
        owner: owner,
        recordId: owner,
        type: LifeType.task,
        expectedVersion: 1,
        fields: {'title': 'Two', 'due': today},
        reason: 'Renamed it',
      );
      final changes = lifeChanges([('t1', a), ('t2', b)]);
      expect(changes.first.reason, 'Renamed it');
      expect(changes.first.version, 2);
      expect(changes.first.fields, [('title', 'One', 'Two')]);
    });

    test('stored reasons read plainly, and unknown ones pass through', () {
      expect(
        lifeReason('Life source version changed; review current record'),
        'This changed on another device first.',
      );
      expect(lifeReason('Something else'), 'Something else');
      expect(lifeReason(null), isNotEmpty);
    });
  });

  group('demo sample', () {
    test('it replays through the rules on 24 date edges', () {
      for (final day in const [
        '2024-02-29', '2025-03-01', '2026-01-01', '2026-01-31', //
        '2026-02-01', '2026-02-28', '2026-03-01', '2026-03-08',
        '2026-03-31', '2026-04-30', '2026-05-31', '2026-06-30',
        '2026-07-31', '2026-08-31', '2026-09-30', '2026-10-31',
        '2026-11-01', '2026-11-04', '2026-11-30', '2026-12-01',
        '2026-12-28', '2026-12-31', '2027-01-01', '2028-02-29',
      ]) {
        final life = demoLife(day);
        expect(life.records, isNotEmpty, reason: day);
        final s = source(life.records, snapshot: demoSample(day), day: day);
        final rows = s.rowsThrough(lifeWindowEnd(day, monthStart(day)));
        expect(rows.where((r) => r.late), isNotEmpty, reason: day);
        expect(rows.where((r) => r.past), isNotEmpty, reason: day);
        expect(
          rows.where((r) => r.recordedZone != null),
          isNotEmpty,
          reason: day,
        );
        expect(rows.where((r) => r.allDay && r.event), isNotEmpty, reason: day);
      }
    });

    test('it leaves the accounts on ₱29,300.75', () {
      final s = demoSample(civilToday());
      final total = sumMinor(
        s.accounts.map((a) => s.balance(a.id, through: civilToday())),
      );
      expect(total, BigInt.from(2930075));
    });

    test('an empty profile has no records', () {
      expect(demoLife(today, empty: true).records, isEmpty);
    });

    test('Next up reads the same records as the Calendar', () {
      final life = demoLife(today);
      final items = sortedAgenda(
        lifeAgendaItems(life.records, today, addCivilDays(today, 30)),
      );
      final rows = source(life.records).rows(today, addCivilDays(today, 30));
      expect(
        rows.map((r) => r.id).toList(),
        items.map((AgendaItem i) => i.id).toList(),
      );
    });
  });
}
