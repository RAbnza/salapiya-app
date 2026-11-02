import 'package:flutter/widgets.dart';

import '../app/overview_data.dart';
import '../features/life/application/life_controller.dart' show AgendaItem;
import '../local/finance_domain.dart';
import 'life_controller.dart' show lifeAgendaItems, tzTime;
import 'life_domain.dart';
import 'reminder_data.dart';

/// Display-only derivations for Life (DESIGN_SYSTEM §8, Chat 12). They group
/// and count what the rules return; statuses come from `debtDueStatus`, due
/// money from `financialReminderSources`, and nothing here is stored. Dates
/// are civil `YYYY-MM-DD` strings. Today is the Asia/Manila civil day; a timed
/// event sits on its date in the display timezone.

/// What a row is, for the words and for what counts as late.
enum LifeRowType { event, deadline, money }

/// One thing on the Calendar: a Life record or a due from the user's records.
class LifeRow {
  LifeRow({
    required this.id,
    required this.sourceId,
    required this.module,
    required this.title,
    required this.date,
    required this.time,
    required this.type,
    required String today,
    this.amount,
    this.dueKind,
    this.recordedDate,
    this.recordedTime,
    this.recordedZone,
    this.item,
  }) : status = debtDueStatus(date, today),
       days = civilDaysBetween(today, date);

  /// A Life record from the agenda.
  factory LifeRow.record(
    AgendaItem item,
    Map<String, LifeRecord> records,
    String today,
    String timezone,
  ) {
    final own = item.id.startsWith('life:')
        ? records[item.id.substring('life:'.length)]
        : null;
    final other = own is ScheduledRecord && own.utc != null
        ? own.timezone
        : null;
    final recorded = other == null || other == timezone
        ? null
        : tzTime((own as ScheduledRecord).utc!, other);
    // A follow-up is something to do by a date, like a due date, so it can be
    // late. Other steps and events only go by (owner, 2026-11-01).
    final followUp = own is CareerEventRecord && own.kind == 'Follow-up';
    return LifeRow(
      id: item.id,
      sourceId: item.sourceId,
      module: item.kind,
      title: item.title,
      date: item.date,
      time: item.time,
      type: own is ScheduledRecord && !followUp
          ? LifeRowType.event
          : LifeRowType.deadline,
      today: today,
      recordedDate: recorded?.$1,
      recordedTime: recorded?.$2,
      recordedZone: recorded == null ? null : other,
      item: item,
    );
  }

  /// A due from the user's records. It reminds; it never asks for anything.
  factory LifeRow.money(FinancialReminderSource s, String today) => LifeRow(
    id: s.id,
    sourceId: s.source,
    module: lifeModuleOf(s.kind),
    title: s.title,
    date: s.date,
    time: 'All day',
    type: LifeRowType.money,
    today: today,
    amount: s.amount,
    dueKind: s.kind,
  );

  final String id, sourceId, module, title, date;

  /// `HH:MM` in the display timezone, or "All day".
  final String time;
  final LifeRowType type;
  final DebtDueStatus status;

  /// Calendar days from today; negative when it's earlier.
  final int days;
  final BigInt? amount;

  /// The rule's own kind of due, for a money row.
  final String? dueKind;

  /// Where a timed event was recorded, when that isn't the display timezone.
  final String? recordedDate, recordedTime, recordedZone;
  final AgendaItem? item;

  bool get allDay => time == 'All day';
  bool get event => type == LifeRowType.event;
  bool get money => type == LifeRowType.money;

  /// Tasks, due dates and money dues can be late. An event that has gone by
  /// isn't: few people mark one done, so it's only Past (owner, 2026-11-01).
  bool get late => !event && days < 0;
  bool get past => event && days < 0;

  /// All-day items first, as `sortedAgenda`.
  String get _order => '$date ${allDay ? '00:00' : time}';
  static int compare(LifeRow a, LifeRow b) {
    final order = a._order.compareTo(b._order);
    return order == 0 ? a.id.compareTo(b.id) : order;
  }
}

String lifeModuleOf(String dueKind) => switch (dueKind) {
  'Debt due' => 'Debts',
  'Recurring expectation' => 'Recurring',
  _ => 'Cards',
};

/// A module's plain name in filters and counts.
String lifeModuleName(String module) => switch (module) {
  'Personal' => 'Events',
  'Recurring' => 'Recurring bills',
  _ => module,
};

/// "Tokyo", from "Asia/Tokyo".
String zoneName(String timezone) =>
    timezone.split('/').last.replaceAll('_', ' ');

/// The last day the Calendar needs for [month] and the cards around it.
String lifeWindowEnd(String today, String month) {
  final ends = [monthEnd(month), monthEnd(today), addCivilDays(today, 7)]
    ..sort();
  return ends.last;
}

/// The Calendar's rows, split the ways its cards read them. Period rows start
/// today; anything earlier is only under [late], however old (W3).
class LifeCalendar {
  LifeCalendar(this.rows, this.today, this.month, this.selected, {this.now});

  final List<LifeRow> rows;
  final String today, selected;

  /// The first day of the month on show.
  final String month;

  /// `HH:MM` now, so "next" skips what has already gone by today.
  final String? now;

  List<LifeRow> get late => [
    for (final r in rows)
      if (r.late) r,
  ];
  List<LifeRow> get onToday => on(today);
  List<LifeRow> on(String date) => [
    for (final r in rows)
      if (r.date == date) r,
  ];

  /// Today to Sunday.
  List<LifeRow> get thisWeek {
    final end = duePeriodRange(today, DuePeriod.week).$2;
    return between(today, end);
  }

  /// The next seven days, after today.
  List<LifeRow> get comingUp =>
      between(addCivilDays(today, 1), addCivilDays(today, 7));

  List<LifeRow> between(String from, String to) => [
    for (final r in rows)
      if (r.date.compareTo(from) >= 0 && r.date.compareTo(to) <= 0) r,
  ];

  List<LifeRow> get inMonth => between(month, monthEnd(month));

  /// What's next: the first row today that hasn't gone by, or the first later
  /// one.
  LifeRow? get next {
    for (final r in rows) {
      if (r.days > 0) return r;
      if (r.days == 0 &&
          (r.allDay || now == null || r.time.compareTo(now!) >= 0)) {
        return r;
      }
    }
    return null;
  }

  /// The month's days with what's on each.
  List<({String date, int count, bool late})> get days => [
    for (
      var d = month;
      d.compareTo(monthEnd(month)) <= 0;
      d = addCivilDays(d, 1)
    )
      () {
        final here = on(d);
        return (date: d, count: here.length, late: here.any((r) => r.late));
      }(),
  ];
}

/// Rows by day, in order, for a dated list.
List<(String, List<LifeRow>)> rowsByDay(Iterable<LifeRow> rows) {
  final out = <(String, List<LifeRow>)>[];
  for (final r in rows) {
    if (out.isNotEmpty && out.last.$1 == r.date) {
      out.last.$2.add(r);
    } else {
      out.add((r.date, [r]));
    }
  }
  return out;
}

/// How many rows of each kind, for a list's figures. Never a money total: a
/// card's statement usually includes its installments.
({int events, int deadlines, int dues}) rowCounts(Iterable<LifeRow> rows) {
  var events = 0, deadlines = 0, dues = 0;
  for (final r in rows) {
    switch (r.type) {
      case LifeRowType.event:
        events++;
      case LifeRowType.deadline:
        deadlines++;
      case LifeRowType.money:
        dues++;
    }
  }
  return (events: events, deadlines: deadlines, dues: dues);
}

/// Where an event stands, for its pill and what its page offers.
enum EventState {
  scheduled('Scheduled'),
  past('Past'),
  completed('Completed'),
  cancelled('Cancelled'),
  archived('Archived');

  const EventState(this.label);
  final String label;
}

EventState eventState(PersonalRecord r, String today, String shownDate) =>
    r.archived
    ? EventState.archived
    : r.status == 'Cancelled'
    ? EventState.cancelled
    : r.status == 'Completed'
    ? EventState.completed
    : shownDate.compareTo(today) < 0
    ? EventState.past
    : EventState.scheduled;

/// The date and time of [r] in [timezone]: the recorded ones for an all-day
/// event, whose date doesn't move between timezones.
(String, String) eventWhen(ScheduledRecord r, String timezone) {
  final utc = r.utc;
  return utc == null ? (r.date, 'All day') : tzTime(utc, timezone);
}

/// Events that left the Calendar, newest first.
List<PersonalRecord> retiredEvents(Map<String, LifeRecord> records) =>
    records.values.whereType<PersonalRecord>().where((r) => !r.active).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

/// One saved version of a record.
class LifeChange {
  const LifeChange(this.id, this.version, this.at, this.reason, this.fields);
  final String id, at, reason;
  final int version;

  /// Each field that changed, as its key, old value and new value.
  final List<(String, String, String)> fields;
}

/// Fields a person sets; the rest are worked out or have a page action.
const _shownFields = {
  'title',
  'detail',
  'date',
  'time',
  'timezone',
  'location',
  'notes',
  'status',
  'archived',
  'due',
  'priority',
  'completed',
  'started',
  'total',
  'progress',
  'rating',
  'company',
  'eventKind',
  'stageDate',
  'arrangement',
  'postingUrl',
  'source',
  'salaryMin',
  'salaryMax',
  'currency',
  'salaryPeriod',
  'technologies',
  'description',
  'contact',
  'resume',
  'nextAction',
  'followUp',
  'outcome',
};

/// [saved] oldest first, as what each version changed, newest first.
List<LifeChange> lifeChanges(Iterable<(String, LifeCommand)> saved) {
  var before = const <String, String>{};
  final out = <LifeChange>[];
  for (final (at, c) in saved) {
    out.add(
      LifeChange(c.id, c.expectedVersion + 1, at, c.reason, [
        for (final key in c.fields.keys)
          if (_shownFields.contains(key) &&
              (before[key] ?? '') != c.fields[key])
            (key, before[key] ?? '', c.fields[key]!),
      ]),
    );
    before = c.fields;
  }
  return out.reversed.toList();
}

/// Where a task sits in the list.
enum TaskGroup {
  overdue('Overdue'),
  today('Today'),
  week('This week'),
  later('Later'),
  undated('No due date'),
  completed('Completed'),
  archived('Archived');

  const TaskGroup(this.label);
  final String label;
}

/// Which tasks the list shows.
enum TaskFilter {
  active('Active'),
  completed('Completed'),
  archived('Archived'),
  all('All');

  const TaskFilter(this.label);
  final String label;
}

/// One task, against today.
class TaskRow {
  TaskRow(this.record, String today)
    : days = record.due.isEmpty ? null : civilDaysBetween(today, record.due),
      group = _groupOf(record, today);
  final TaskRecord record;

  /// Calendar days to its due date; negative when late, null with none.
  final int? days;
  final TaskGroup group;

  String get id => record.id;
  String get title => record.title;
  String get priority => record.priority;
  String get due => record.due;
  String get status => record.status;
  bool get archived => record.archived;
  bool get done => status == 'Completed';
  bool get open => !archived && !done;
  bool get onHold => status == 'On hold';
  bool get late => group == TaskGroup.overdue;

  static TaskGroup _groupOf(TaskRecord r, String today) {
    if (r.archived) return TaskGroup.archived;
    if (r.status == 'Completed') return TaskGroup.completed;
    if (r.due.isEmpty) return TaskGroup.undated;
    if (r.due.compareTo(today) < 0) return TaskGroup.overdue;
    if (r.due == today) return TaskGroup.today;
    final sunday = duePeriodRange(today, DuePeriod.week).$2;
    return r.due.compareTo(sunday) <= 0 ? TaskGroup.week : TaskGroup.later;
  }
}

/// Earliest first within a group, then High, Normal, Low.
int _taskOrder(TaskRow a, TaskRow b) {
  int rank(String p) => const ['High', 'Normal', 'Low'].indexOf(p);
  final groups = a.group.index.compareTo(b.group.index);
  if (groups != 0) return groups;
  final dates = a.due.compareTo(b.due);
  if (dates != 0) return dates;
  final priorities = rank(a.priority).compareTo(rank(b.priority));
  if (priorities != 0) return priorities;
  final titles = a.title.compareTo(b.title);
  return titles != 0 ? titles : a.id.compareTo(b.id);
}

/// Every task, in the order the list reads.
List<TaskRow> taskRows(Map<String, LifeRecord> records, String today) =>
    [for (final r in records.values.whereType<TaskRecord>()) TaskRow(r, today)]
      ..sort(_taskOrder);

/// What [filter] and the typed [words] leave. Words look through the title
/// and details.
List<TaskRow> filterTasks(
  List<TaskRow> rows,
  TaskFilter filter, [
  String words = '',
]) {
  final query = words.trim().toLowerCase();
  return [
    for (final r in rows)
      if (switch (filter) {
            TaskFilter.active => r.open,
            TaskFilter.completed => !r.archived && r.done,
            TaskFilter.archived => r.archived,
            TaskFilter.all => true,
          } &&
          '${r.title} ${r.record.fields['detail']}'.toLowerCase().contains(
            query,
          ))
        r,
  ];
}

/// The figures on the Tasks tiles and By priority, open tasks only.
class TaskCounts {
  TaskCounts(List<TaskRow> rows)
    : open = [
        for (final r in rows)
          if (r.open) r,
      ];
  final List<TaskRow> open;

  int get toDo => open.length;
  List<TaskRow> inGroup(TaskGroup group) => [
    for (final r in open)
      if (r.group == group) r,
  ];
  int get overdue => inGroup(TaskGroup.overdue).length;
  int get dueToday => inGroup(TaskGroup.today).length;

  /// Today to Sunday, as the Calendar's This week.
  int get thisWeek => dueToday + inGroup(TaskGroup.week).length;

  /// How late the oldest is, or null with nothing late.
  int? get oldest {
    final late = inGroup(TaskGroup.overdue);
    return late.isEmpty ? null : -late.first.days!;
  }

  int priority(String name) => open.where((r) => r.priority == name).length;
  int get onHold => open.where((r) => r.onHold).length;
  int get undated => inGroup(TaskGroup.undated).length;

  /// What's next: late ones first, undated ones last, and nothing on hold.
  List<TaskRow> get next => [
    for (final r in open)
      if (!r.onHold) r,
  ];
}

/// The words Learning and Books each use.
class ProgressWords {
  const ProgressWords({
    required this.type,
    required this.tab,
    required this.module,
    required this.one,
    required this.adding,
    required this.editing,
    required this.detail,
    required this.unit,
    required this.units,
    required this.total,
    required this.done,
    required this.doing,
    required this.notDoing,
    required this.finishedOne,
  });

  static const learning = ProgressWords(
    type: LifeType.learning,
    tab: 'Learning',
    module: 'Learning',
    one: 'learning goal',
    adding: 'Add a learning goal',
    editing: 'Edit learning goal',
    detail: 'Course or resource',
    unit: 'lesson',
    units: 'lessons',
    total: 'Total lessons',
    done: 'Lessons done',
    doing: 'Learning',
    notDoing: 'Nothing in progress',
    finishedOne: 'Finished',
  );
  static const book = ProgressWords(
    type: LifeType.book,
    tab: 'Books',
    module: 'Books',
    one: 'book',
    adding: 'Add a book',
    editing: 'Edit book',
    detail: 'Author',
    unit: 'page',
    units: 'pages',
    total: 'Total pages',
    done: 'Pages read',
    doing: 'Reading',
    notDoing: 'Nothing you’re reading',
    finishedOne: 'Finished',
  );
  static ProgressWords of(LifeType type) =>
      type == LifeType.book ? book : learning;

  final LifeType type;
  final String tab, module, one, adding, editing, detail;
  final String unit, units, total, done, doing, notDoing, finishedOne;
}

/// Which items the list shows.
enum ProgressFilter {
  active('Active'),
  finished('Finished'),
  archived('Archived'),
  all('All');

  const ProgressFilter(this.label);
  final String label;
}

/// One learning item or book, against today.
class ProgressRow {
  ProgressRow(this.record, String today, this.order)
    : days = record.due.isEmpty ? null : civilDaysBetween(today, record.due);
  final ProgressRecord record;

  /// Calendar days to its due date; negative when late, null with none.
  final int? days;

  /// Its place in the order the user added things.
  final int order;

  String get id => record.id;
  String get title => record.title;
  String get detail => record.fields['detail']!;
  String get due => record.due;
  String get status => record.status;
  int get total => record.total;
  int get done => record.progress;
  bool get archived => record.archived;
  bool get finished => status == 'Completed';
  bool get open => !archived && !finished;
  bool get inProgress => open && status == 'In progress';
  bool get notStarted => open && status == 'Not started';
  bool get onHold => open && status == 'On hold';
  bool get late => open && (days ?? 0) < 0;
  bool get dueToday => open && days == 0;

  /// The rules' least total, and what the form sends for "I don't know". It
  /// has no parts to count, so it shows no bar.
  bool get hasTotal => total > 1;
  int get left => total - done;

  /// A date only the user can give: a finished item may not have one.
  String? get finishedOn {
    final date = record.fields['completed']!;
    return finished && date.isNotEmpty ? date : null;
  }

  String? get rating =>
      record is BookRecord ? (record as BookRecord).rating : null;
  String get started => record.fields['started']!;
}

/// Soonest first, then in the order they were added.
int _progressOrder(ProgressRow a, ProgressRow b) {
  if (a.due.isEmpty != b.due.isEmpty) return a.due.isEmpty ? 1 : -1;
  final dates = a.due.compareTo(b.due);
  return dates != 0 ? dates : a.order.compareTo(b.order);
}

/// Every learning item or every book, soonest first.
List<ProgressRow> progressRows(
  Map<String, LifeRecord> records,
  LifeType type,
  String today,
) {
  final out = <ProgressRow>[];
  for (final r in records.values.whereType<ProgressRecord>()) {
    if (r.type == type) out.add(ProgressRow(r, today, out.length));
  }
  return out..sort(_progressOrder);
}

/// What [filter] and the typed [words] leave. Finished ones read newest first.
List<ProgressRow> filterProgress(
  List<ProgressRow> rows,
  ProgressFilter filter, [
  String words = '',
]) {
  final query = words.trim().toLowerCase();
  final out = [
    for (final r in rows)
      if (switch (filter) {
            ProgressFilter.active => r.open,
            ProgressFilter.finished => !r.archived && r.finished,
            ProgressFilter.archived => r.archived,
            ProgressFilter.all => true,
          } &&
          '${r.title} ${r.detail}'.toLowerCase().contains(query))
        r,
  ];
  if (filter == ProgressFilter.finished) {
    out.sort((a, b) {
      final dates = (b.finishedOn ?? '').compareTo(a.finishedOn ?? '');
      return dates != 0 ? dates : _progressOrder(a, b);
    });
  }
  return out;
}

/// The figures on Learning's and Books' tiles and header. Counts only: a rate
/// or an average would need a definition the rules don't have.
class ProgressCounts {
  ProgressCounts(this.rows);
  final List<ProgressRow> rows;

  List<ProgressRow> get inProgress => [
    for (final r in rows)
      if (r.inProgress) r,
  ];
  List<ProgressRow> get notStarted => [
    for (final r in rows)
      if (r.notStarted) r,
  ];
  int get onHold => rows.where((r) => r.onHold).length;
  int get finished => rows.where((r) => !r.archived && r.finished).length;
  int get overdue => rows.where((r) => r.late).length;
  int get dueToday => rows.where((r) => r.dueToday).length;

  /// What's next: anything open with a date, then what hasn't started. Nothing
  /// on hold.
  List<ProgressRow> get next => [
    for (final r in rows)
      if (r.open && !r.onHold && (r.due.isNotEmpty || r.notStarted)) r,
  ];

  /// The nearest due date, overdue ones first.
  ProgressRow? get nextDated {
    for (final r in rows) {
      if (r.open && !r.onHold && r.due.isNotEmpty) return r;
    }
    return null;
  }

  /// How many were finished in [year], from the dates the user recorded.
  int finishedIn(String year) => rows
      .where((r) => !r.archived && (r.finishedOn ?? '').startsWith(year))
      .length;
}

/// Steps that record what happened. The rules keep them done, so there's
/// nothing to schedule or reopen.
const careerObservations = {
  'Submission',
  'Response',
  'Offer',
  'No response',
  'Note',
};

/// Stages that mean an interview or assessment is under way.
const careerInterviewing = {
  'Interview',
  'Technical assessment',
  'Final interview',
};

/// A stored outcome on screen. The stored value doesn't change.
String careerOutcomeLabel(String outcome) =>
    outcome == 'Employer-cancelled opening' ? 'Opening cancelled' : outcome;

/// A work arrangement on screen.
const careerArrangements = {
  'onsite': 'On-site',
  'hybrid': 'Hybrid',
  'remote': 'Remote',
  'unspecified': 'Not specified',
};

/// Where a step stands.
enum CareerStepState {
  scheduled('Scheduled'),
  past('Past'),
  overdue('Overdue'),
  done('Done'),
  logged('Logged'),
  cancelled('Cancelled');

  const CareerStepState(this.label);
  final String label;
}

/// A cancelled step isn't a finished one, and only a follow-up can be late.
CareerStepState stepState(
  CareerEventRecord r,
  String today,
  String shownDate,
) => r.status == 'Cancelled'
    ? CareerStepState.cancelled
    : careerObservations.contains(r.kind)
    ? CareerStepState.logged
    : r.status == 'Completed'
    ? CareerStepState.done
    : shownDate.compareTo(today) >= 0
    ? CareerStepState.scheduled
    : r.kind == 'Follow-up'
    ? CareerStepState.overdue
    : CareerStepState.past;

/// One step on an application.
class StepRow {
  StepRow(this.record, String today, String timezone)
    : date = eventWhen(record, timezone).$1,
      time = eventWhen(record, timezone).$2,
      state = stepState(record, today, eventWhen(record, timezone).$1);
  final CareerEventRecord record;

  /// In the display timezone. An all-day step keeps its recorded date.
  final String date, time;
  final CareerStepState state;

  String get id => record.id;
  String get kind => record.kind;
  bool get allDay => time == 'All day';
  bool get observed => careerObservations.contains(kind);

  /// Still ahead of the user: it can be done or cancelled.
  bool get open => const {
    CareerStepState.scheduled,
    CareerStepState.past,
    CareerStepState.overdue,
  }.contains(state);

  /// Coming up first, nearest first, then the rest, newest first.
  static int compare(StepRow a, StepRow b) {
    final soon = const {CareerStepState.scheduled, CareerStepState.overdue};
    final x = soon.contains(a.state), y = soon.contains(b.state);
    if (x != y) return x ? -1 : 1;
    final order = '${a.date} ${a.time}'.compareTo('${b.date} ${b.time}');
    return x ? order : -order;
  }
}

/// Which applications the list shows.
enum ApplicationFilter {
  active('Active'),
  closed('Closed'),
  archived('Archived'),
  all('All');

  const ApplicationFilter(this.label);
  final String label;
}

/// One application, with its steps and what's next on it.
class ApplicationRow {
  ApplicationRow(this.record, this.steps, this.next, this.order);
  final ApplicationRecord record;

  /// In [StepRow.compare]'s order.
  final List<StepRow> steps;

  /// Overdue first, then what's soonest. Null when nothing is dated.
  final LifeRow? next;
  final int order;

  String get id => record.id;
  String get company => record.company;
  String get position => record.position;
  bool get archived => record.archived;
  bool get closed => record.terminal;
  bool get active => !archived && !closed;
  bool get saved => stage == 'Saved';

  /// The stage, or null on an older closed record that never had one.
  String? get stage =>
      careerPipelineStages.contains(record.stage) ? record.stage : null;
  String? get outcome => record.outcome.isEmpty ? null : record.outcome;

  /// One word for where it stands: its outcome, or its stage.
  String get standing =>
      outcome != null ? careerOutcomeLabel(outcome!) : stage ?? 'Not recorded';
  String get applied => record.fields['date']!;
  String get stageDate => record.fields['stageDate']!;
  String get followUp => record.fields['followUp']!;
  String get nextAction => record.fields['nextAction']!;
}

/// Every interview, assessment and follow-up still in play, in order. These
/// read records directly, so a Calendar switch doesn't empty Career.
List<LifeRow> careerRows(
  Map<String, LifeRecord> records,
  String today,
  String timezone,
) => [
  for (final item in lifeAgendaItems(
    records,
    '1900-01-01',
    '2200-12-31',
    timezone: timezone,
  ))
    if (item.kind == 'Career') LifeRow.record(item, records, today, timezone),
]..sort(LifeRow.compare);

/// What's next: overdue follow-ups first, then what's coming. An interview
/// that has gone by isn't next.
List<LifeRow> nextSteps(List<LifeRow> rows) => [
  for (final r in rows)
    if (!r.past) r,
];

/// Open ones first, by what's next, then the newest move.
int _applicationOrder(ApplicationRow a, ApplicationRow b) {
  if (a.active != b.active) return a.active ? -1 : 1;
  final x = a.next, y = b.next;
  if ((x == null) != (y == null)) return x == null ? 1 : -1;
  if (x != null && y != null) {
    final dates = LifeRow.compare(x, y);
    if (dates != 0) return dates;
  }
  final moved = b.stageDate.compareTo(a.stageDate);
  return moved != 0 ? moved : a.order.compareTo(b.order);
}

/// Every application, with what's next on each.
List<ApplicationRow> applicationRows(
  Map<String, LifeRecord> records,
  String today,
  String timezone,
) {
  final steps = <String, List<StepRow>>{};
  for (final r in records.values.whereType<CareerEventRecord>()) {
    steps
        .putIfAbsent(r.applicationId, () => [])
        .add(StepRow(r, today, timezone));
  }
  final next = <String, LifeRow>{};
  for (final r in nextSteps(careerRows(records, today, timezone))) {
    next.putIfAbsent(r.sourceId, () => r);
  }
  final out = <ApplicationRow>[];
  for (final r in records.values.whereType<ApplicationRecord>()) {
    out.add(
      ApplicationRow(
        r,
        (steps[r.id] ?? [])..sort(StepRow.compare),
        next[r.id],
        out.length,
      ),
    );
  }
  return out..sort(_applicationOrder);
}

/// What [filter], a [stage] and the typed [words] leave. Words look through
/// the company and role only, because the rest is private.
List<ApplicationRow> filterApplications(
  List<ApplicationRow> rows,
  ApplicationFilter filter, {
  String? stage,
  String words = '',
}) {
  final query = words.trim().toLowerCase();
  return [
    for (final r in rows)
      if (switch (filter) {
            ApplicationFilter.active => r.active,
            ApplicationFilter.closed => !r.archived && r.closed,
            ApplicationFilter.archived => r.archived,
            ApplicationFilter.all => true,
          } &&
          (stage == null || r.stage == stage) &&
          '${r.company} ${r.position}'.toLowerCase().contains(query))
        r,
  ];
}

/// The figures on Career's tiles, header and Where they stand. Counts of
/// current records: rates, time in stage and results by source are L05's, and
/// need definitions this app doesn't have yet.
class CareerCounts {
  CareerCounts(this.rows, this.next);
  final List<ApplicationRow> rows;

  /// From [nextSteps].
  final List<LifeRow> next;

  List<ApplicationRow> get active => [
    for (final r in rows)
      if (r.active) r,
  ];
  int stage(String name) => active.where((r) => r.stage == name).length;
  int get saved => stage('Saved');
  int get interviewing =>
      active.where((r) => careerInterviewing.contains(r.stage)).length;
  List<ApplicationRow> get closed => [
    for (final r in rows)
      if (!r.archived && r.closed) r,
  ];
  int outcome(String name) => closed.where((r) => r.outcome == name).length;

  /// Follow-ups past their date. Interviews that went by aren't late.
  List<LifeRow> get overdue => [
    for (final r in next)
      if (r.late) r,
  ];
  int get dueToday => next.where((r) => r.days == 0 && !r.event).length;

  /// How late the oldest is, or null with nothing late.
  int? get oldest => overdue.isEmpty ? null : -overdue.first.days;

  /// What comes next once anything overdue is dealt with.
  LifeRow? get upcoming {
    for (final r in next) {
      if (!r.late) return r;
    }
    return null;
  }
}

/// "1500000.5" as "1,500,000.50".
String _salaryFigure(String value) {
  final parts = value.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+$)'),
    (_) => ',',
  );
  return '$whole.${(parts.length > 1 ? parts[1] : '').padRight(2, '0')}';
}

/// Expected salary in words, or null with none. It's a money figure, so Hide
/// amounts covers it. It keeps its own currency and is never added to anything.
String? salaryLine(Map<String, String> fields, {required bool hidden}) {
  final low = fields['salaryMin'] ?? '', high = fields['salaryMax'] ?? '';
  if (low.isEmpty && high.isEmpty) return null;
  if (hidden) return 'Amount hidden';
  final currency = fields['currency'] ?? 'PHP';
  String money(String v) => currency == 'PHP'
      ? '₱${_salaryFigure(v)}'
      : '$currency ${_salaryFigure(v)}';
  final range = low.isEmpty
      ? 'Up to ${money(high)}'
      : high.isEmpty
      ? 'From ${money(low)}'
      : low == high
      ? money(low)
      : '${money(low)} to ${money(high)}';
  final per = switch (fields['salaryPeriod']) {
    'hour' => 'an hour',
    'year' => 'a year',
    _ => 'a month',
  };
  return '$range $per';
}

/// Why a change came back, in plain words. The stored reason doesn't change.
const lifeReasons = {
  'Life source version changed; review current record':
      'This changed on another device first.',
  'Invalid, unavailable or incompatible private Life command; review the retained draft.':
      'Salapiya couldn’t accept this change.',
  'Source changed; review the current version and retained original intent.':
      'This changed before your edit reached it.',
  'Previously resolved review retained; original intent is not retried.':
      'You’ve already dealt with this one.',
  'Restored intent conflicts with current authority.':
      'This came back from a backup and no longer fits.',
  'Current receipt and source review required':
      'This came back from a backup. Salapiya is checking it.',
};

String lifeReason(String? reason) =>
    lifeReasons[reason] ??
    reason ??
    'This changed before your edit reached it.';

/// What a person calls a stored field.
const lifeFieldNames = {
  'title': 'Title',
  'detail': 'Details',
  'date': 'Date',
  'time': 'Time',
  'timezone': 'Timezone',
  'location': 'Location',
  'notes': 'Notes',
  'status': 'Status',
  'archived': 'Archived',
  'due': 'Due date',
  'priority': 'Priority',
  'completed': 'Date finished',
  'started': 'Date started',
  'total': 'Total',
  'progress': 'Progress',
  'rating': 'Rating',
  'company': 'Company',
  'eventKind': 'Type',
  'stageDate': 'Stage date',
  'arrangement': 'Work arrangement',
  'postingUrl': 'Posting link',
  'source': 'Found through',
  'salaryMin': 'Minimum salary',
  'salaryMax': 'Maximum salary',
  'currency': 'Currency',
  'salaryPeriod': 'Salary period',
  'technologies': 'Technologies',
  'description': 'Job description',
  'contact': 'Contact',
  'resume': 'Resume used',
  'nextAction': 'Next action',
  'followUp': 'Follow-up date',
  'outcome': 'Outcome',
};

/// A refused edit, against what's there now.
class LifeReviewRow {
  LifeReviewRow(
    this.original,
    this.reason,
    this.current, {
    this.allowed = true,
  });
  final LifeCommand original;

  /// Whether the rules would take this edit now. A step on an application
  /// that has since closed wouldn't.
  final bool allowed;

  /// As stored; [lifeReason] says it plainly.
  final String? reason;
  final LifeRecord? current;

  String get id => original.id;

  /// Whether it can still be saved: its record is there, or it's a new one.
  bool get usable =>
      allowed && (current != null || original.expectedVersion == 0);

  /// Each named field that differs, as its key, what's there and the edit.
  List<(String, String, String)> get differences => [
    for (final e in original.fields.entries)
      if (lifeFieldNames.containsKey(e.key) &&
          (current?.fields[e.key] ?? '') != e.value)
        (e.key, current?.fields[e.key] ?? '', e.value),
  ];
}

/// Edits refused and not yet dealt with. [intents] are the store's rows.
List<LifeReviewRow> lifeReviewRows(
  List<Map<String, dynamic>> intents,
  Map<String, LifeRecord> records,
) => [
  for (final row in intents)
    if (row['resolved_at'] == null && row['state'] == 'review')
      () {
        final c = LifeCommand.decode(
          row['id'] as String,
          row['payload'] as String,
        );
        return LifeReviewRow(
          c,
          row['reason'] as String?,
          records[c.recordId],
          allowed: _wouldApply(records, c),
        );
      }(),
];

/// Whether [c]'s fields would be accepted over what's there now.
bool _wouldApply(Map<String, LifeRecord> records, LifeCommand c) {
  try {
    applyLifeCommand(
      records,
      LifeCommand(
        id: c.id,
        owner: c.owner,
        recordId: c.recordId,
        type: c.type,
        expectedVersion: records[c.recordId]?.version ?? 0,
        fields: c.fields,
        reason: c.reason,
      ),
    );
    return true;
  } on FormatException {
    return false;
  }
}

/// A file picked for an application and not linked yet, kept as a draft.
class PendingDocument {
  const PendingDocument(this.operation, this.command, {this.stale = false});
  final String operation;
  final LifeCommand command;

  /// The application changed since, so it needs linking afresh.
  final bool stale;
  String get name => command.fields['title']!;
}

/// What can be done with an application's files, on both builds. A file stays
/// on the device that attached it, so these are separate from Life's records,
/// which sync. Each returns what to tell the user, if anything.
abstract interface class LifeDocuments {
  bool get demo;

  /// Whether this device holds the file.
  Future<bool> present(String id);
  Future<List<PendingDocument>> pending(String application);
  Future<String?> attach(BuildContext context, String application);
  Future<String?> finish(PendingDocument pending);
  Future<String?> letGo(PendingDocument pending);
  Future<String?> preview(BuildContext context, CareerDocumentRecord record);
  Future<String?> openElsewhere(CareerDocumentRecord record);
  Future<String?> saveCopy(CareerDocumentRecord record);
  Future<String?> restore(CareerDocumentRecord record);
  Future<String?> removeCopy(CareerDocumentRecord record);
}

/// An application's documents, oldest first.
List<CareerDocumentRecord> careerDocuments(
  Map<String, LifeRecord> records,
  String application,
) => [
  for (final r in records.values.whereType<CareerDocumentRecord>())
    if (r.applicationId == application) r,
];

/// A stored reason in plain words, for Edit history. Stored values don't change.
String lifeReasonText(String reason) => switch (reason) {
  'Attached private Career document metadata' => 'Document attached',
  'Archived private document link' => 'Document link archived',
  'Restored document link; byte presence unchanged' => 'Document link restored',
  'Completed event' => 'Marked as done',
  'Reopened event' => 'Marked as not done',
  _ => reason,
};

/// How Life's forms save. The real build commits; the demo checks with the
/// real rules and keeps nothing.
abstract interface class LifeWriter {
  bool get demo;
  String get today;

  /// The timezone the Calendar shows times in.
  String get timezone;

  /// The current record, or null if there is none.
  LifeRecord? record(String? id);

  Future<Map<String, String>?> draft(String operation);
  Future<void> saveDraft(
    String operation,
    String command,
    Map<String, String> values,
  );
  Future<void> discardDraft(String operation);

  /// The command [values] would make. Throws the rules' refusal.
  LifeCommand eventCommand(Map<String, String> values, {String? old});
  Future<void> saveEvent(Map<String, String> values, {String? old});
  LifeCommand taskCommand(Map<String, String> values, {String? old});
  Future<void> saveTask(Map<String, String> values, {String? old});

  /// A learning item or book, from its form.
  LifeCommand entryCommand(
    LifeType type,
    Map<String, String> values, {
    String? old,
  });
  Future<void> saveEntry(
    LifeType type,
    Map<String, String> values, {
    String? old,
  });

  /// An application, from its form. Throws the rules' refusal.
  LifeCommand applicationCommand(Map<String, String> values, {String? old});
  Future<void> saveApplication(Map<String, String> values, {String? old});

  /// Whether this company and role is already here.
  bool duplicateApplication(Map<String, String> values);

  /// A step on [application], from its form.
  LifeCommand stepCommand(
    Map<String, String> values,
    String application, {
    String? old,
  });
  Future<void> saveStep(
    Map<String, String> values,
    String application, {
    String? old,
  });

  /// New progress on item [id], with the form's own command id.
  LifeCommand progressCommand(Map<String, String> values, String id);
  Future<void> saveProgress(Map<String, String> values, String id);

  /// Saves a refused edit as a new one, and closes its review. [command] is
  /// made once, so asking again after a lost answer can't save it twice.
  Future<void> useEdit(LifeCommand command, String original);

  /// Closes a review and keeps the record as it is. The refused edit stays.
  Future<void> keepCurrent(String original);

  /// Changes [fields] on a record, as a page's action does.
  Future<void> change(
    String id,
    int version,
    Map<String, String> fields,
    String reason,
  );

  /// The line a saved form ends on.
  String savedLine(String command);

  /// Every saved version of a record, oldest first.
  Future<List<(String, LifeCommand)>> history(String id);
}

/// What the Life screens open.
class LifeActions {
  const LifeActions({
    required this.addEvent,
    required this.addTask,
    required this.editEvent,
    required this.editTask,
    required this.openTask,
    required this.openItem,
    required this.openRow,
    required this.openEvent,
    required this.addEntry,
    required this.openEntry,
    required this.editEntry,
    required this.logProgress,
    required this.addApplication,
    required this.openApplication,
    required this.editApplication,
    required this.changeStage,
    required this.recordOutcome,
    required this.reopenApplication,
    required this.addStep,
    required this.openStep,
    required this.editStep,
    required this.openList,
    required this.reminders,
    this.preferences,
    required this.reminderFor,
    this.openPlanning,
  });
  final VoidCallback addEvent, addTask, reminders;
  final VoidCallback? preferences, openPlanning;
  final ValueChanged<String> editEvent, openEvent, editTask, openTask;
  final ValueChanged<LifeRow> openRow;

  /// Learning and Books: add one of a type, and a page, form and progress by
  /// the item's id.
  final ValueChanged<LifeType> addEntry;
  final ValueChanged<String> openEntry, editEntry, logProgress;

  /// Career: forms and pages by the application's id, and a step's by its own.
  final VoidCallback addApplication;
  final ValueChanged<String> openApplication, editApplication, changeStage;
  final ValueChanged<String> recordOutcome, reopenApplication, addStep;
  final ValueChanged<String> openStep;
  final void Function(String application, String step) editStep;

  /// An item from Reminders: its own page.
  final ValueChanged<AgendaItem> openItem;
  final void Function(Widget page, String title) openList;

  /// The reminder controls for a dated item.
  final Widget Function(AgendaItem item) reminderFor;
}

/// What the Life screens read, on both builds.
class LifeSource {
  const LifeSource({
    required this.today,
    required this.timezone,
    required this.complete,
    required this.hidden,
    required this.amount,
    required this.records,
    required this.snapshot,
    required this.writer,
    required this.actions,
    required this.visible,
    this.now,
    this.lifeComplete = true,
    this.waiting = 0,
    this.error,
    this.reviews = const [],
    this.restoring = 0,
    this.reminders,
    this.documents,
  });
  final String today, timezone;
  final String? now, error;

  /// Every money record downloaded, and every Life record.
  final bool complete, lifeComplete, hidden;
  final String Function(BigInt) amount;
  final Map<String, LifeRecord> records;

  /// With waiting work, as Debts reads it, so the two agree.
  final LocalSnapshot snapshot;
  final LifeWriter writer;
  final LifeActions actions;

  /// Whether Preferences shows a module on the Calendar.
  final bool Function(String module) visible;

  /// Life changes waiting to sync.
  final int waiting;

  /// Refused edits to look at, and edits a backup brought back that a
  /// connection still has to check.
  final List<LifeReviewRow> reviews;
  final int restoring;

  /// This device's reminders. Null while there's no way to read them.
  final LifeReminders? reminders;

  /// This device's Career files.
  final LifeDocuments? documents;

  /// The Calendar's rows between two dates, in order.
  List<LifeRow> rows(String from, String through) => [
    for (final item in lifeAgendaItems(
      records,
      from,
      through,
      timezone: timezone,
    ))
      if (visible(item.kind)) LifeRow.record(item, records, today, timezone),
    if (complete)
      for (final s in namedDueSources(
        snapshot,
        financialReminderSources(snapshot, from, through, asOf: today),
      ))
        if (visible(lifeModuleOf(s.kind))) LifeRow.money(s, today),
  ]..sort(LifeRow.compare);

  /// Everything from the earliest late row through [through].
  List<LifeRow> rowsThrough(String through) => rows('1900-01-01', through);
}
