import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_cards.dart' show civilLabel, duePill;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../features/life/application/life_controller.dart' show AgendaItem;
import '../local/finance_domain.dart' show DebtDueStatus;
import '../prototype/scenarios.dart';
import 'life_data.dart';
import 'life_domain.dart';
import 'life_hub.dart';
import 'life_pages_detail.dart' show LifeHistoryCard;

/// Marks a task done or reopens it, with the same command the page's button
/// sends. A one-tap action has no form, so a refusal shows above the cards.
Future<void> toggleTask(LifeSource source, LifeHub hub, TaskRow r) async {
  hub.setProblem(null);
  try {
    await source.writer.change(
      r.id,
      r.record.version,
      {'status': r.done ? 'In progress' : 'Completed'},
      r.done ? 'Reopened' : 'Completed',
    );
    if (source.writer.demo) {
      hub.setProblem('This is the demo, so nothing was saved.');
    }
  } on FormatException catch (e) {
    hub.setProblem(e.message);
  } catch (_) {
    hub.setProblem('That didn’t save. Your records are unchanged.');
  }
}

/// A task's details, each whole, so a line breaks between them.
List<String> taskDetails(TaskRow r, {bool date = true}) => [
  if (date && r.due.isNotEmpty) 'Due ${civilLabel(r.due)}',
  if (date && r.due.isEmpty) 'No due date',
  if (r.priority != 'Normal') '${r.priority} priority',
  if (r.late) '${-r.days!} ${r.days == -1 ? 'day' : 'days'} overdue',
];

/// The pill a task needs, or null when nothing's off.
Widget? taskPill(TaskRow r) => r.archived
    ? const StatusPill('Archived', icon: Icons.archive_outlined)
    : r.done
    ? const StatusPill(
        'Completed',
        icon: Icons.task_alt,
        tone: PillTone.success,
      )
    : r.onHold
    ? const StatusPill('On hold', icon: Icons.pause_circle_outline)
    : r.late
    ? duePill(DebtDueStatus.overdue)
    : r.days == 0
    ? duePill(DebtDueStatus.dueToday)
    : null;

/// Done or not, one tap from the list. It's read as "Complete task ‹title›".
class TaskCheck extends StatelessWidget {
  const TaskCheck({super.key, required this.row, required this.onChanged});
  final TaskRow row;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${row.done ? 'Reopen' : 'Complete'} task ${row.title}',
    child: Checkbox(
      key: ValueKey('life-task-check-${row.id}'),
      value: row.done,
      onChanged: row.archived ? null : (_) => onChanged(),
    ),
  );
}

/// One task in a list: its checkbox, then the row that opens it.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.row,
    required this.onCheck,
    required this.onOpen,
    this.date = true,
  });
  final TaskRow row;
  final VoidCallback onCheck, onOpen;
  final bool date;
  @override
  Widget build(BuildContext context) {
    final details = taskDetails(row, date: date);
    return Row(
      children: [
        TaskCheck(row: row, onChanged: onCheck),
        Expanded(
          child: AdaptiveRow(
            key: ValueKey('life-task-${row.id}'),
            title: row.title,
            subtitle: details.isEmpty ? null : detailLine(details),
            trailing: taskPill(row),
            onTap: onOpen,
          ),
        ),
      ],
    );
  }
}

/// Tasks: what do I need to do, and what's next?
class LifeTasksTab extends StatelessWidget {
  const LifeTasksTab({
    super.key,
    required this.source,
    required this.hub,
    required this.listenable,
    required this.live,
  });
  final LifeSource source;
  final LifeHub hub;
  final Listenable listenable;
  final LifeSource Function(BuildContext context) live;

  static const _next = 5;

  void openList() => source.actions.openList(
    LifeTaskListPage(listenable: listenable, source: live),
    'Tasks',
  );

  Widget tile(
    String key,
    String label,
    IconData icon,
    String value,
    String? caption, {
    bool accent = false,
  }) => KpiTile(
    key: ValueKey(key),
    labels: const ['To do', 'Overdue', 'Today', 'This week'],
    accent: accent,
    icon: icon,
    label: label,
    value: source.lifeComplete
        ? MoneyAmount(value, size: MoneySize.tile, textAlign: TextAlign.start)
        : const MoneyAmount(
            null,
            size: MoneySize.tile,
            textAlign: TextAlign.start,
          ),
    caption: source.lifeComplete ? caption : null,
  );

  List<Widget> tiles(TaskCounts counts) {
    final high = counts.priority('High');
    final oldest = counts.oldest;
    return [
      tile(
        'life-tasks-todo',
        'To do',
        Icons.checklist,
        '${counts.toDo}',
        counts.toDo == 0
            ? 'Nothing to do'
            : high == 0
            ? 'None marked high priority'
            : '$high high priority',
        accent: true,
      ),
      tile(
        'life-tasks-overdue',
        'Overdue',
        Icons.error_outline,
        '${counts.overdue}',
        oldest == null
            ? 'Nothing overdue'
            : 'Oldest $oldest ${oldest == 1 ? 'day' : 'days'}',
      ),
      tile(
        'life-tasks-today',
        'Today',
        Icons.today_outlined,
        '${counts.dueToday}',
        counts.dueToday == 0 ? 'Nothing due today' : 'Due today',
      ),
      tile(
        'life-tasks-week',
        'This week',
        Icons.date_range_outlined,
        '${counts.thisWeek}',
        counts.thisWeek == 0 ? 'Nothing left this week' : 'Today to Sunday',
      ),
    ];
  }

  Widget nextCard(TaskCounts counts) {
    final next = counts.next;
    final left = next.length - _next;
    return OverviewCard(
      key: const ValueKey('life-tasks-next'),
      title: 'Next up',
      caption: 'Overdue first, then by date',
      child: next.isEmpty
          ? EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Nothing to do',
              message: 'Tasks you add show here.',
              action: AppButton.secondary(
                'Add task',
                onPressed: source.actions.addTask,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListGroup(
                  children: [
                    for (final r in next.take(_next))
                      TaskTile(
                        row: r,
                        onCheck: () => toggleTask(source, hub, r),
                        onOpen: () => source.actions.openTask(r.id),
                      ),
                  ],
                ),
                left > 0
                    ? ListEnd(label: '$left more', onPressed: openList)
                    : const ListEnd(),
              ],
            ),
    );
  }

  Widget priorityCard(BuildContext context, TaskCounts counts) {
    final text = Theme.of(context).textTheme;
    Widget figure(String name, int n) => Semantics(
      label: '$name, $n',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(child: Text(name, style: text.bodyMedium)),
          Text('$n', style: text.titleSmall),
        ],
      ),
    );
    Widget line(String name) {
      final n = counts.priority(name);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            figure(name, n),
            const SizedBox(height: Space.xs),
            SlimBar(fraction: counts.toDo == 0 ? 0 : n / counts.toDo),
          ],
        ),
      );
    }

    return OverviewCard(
      key: const ValueKey('life-tasks-priority'),
      title: 'By priority',
      caption: 'Your open tasks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final name in const ['High', 'Normal', 'Low']) line(name),
          const SizedBox(height: Space.sm),
          figure('On hold', counts.onHold),
          const SizedBox(height: Space.sm),
          figure('No due date', counts.undated),
          const ListEnd(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = taskRows(source.records, source.today);
    final counts = TaskCounts(rows);
    final t = tiles(counts);
    final next = nextCard(counts);
    final priority = priorityCard(context, counts);
    final list = LifeTaskList(
      key: const ValueKey('life-tasks-list'),
      source: source,
      hub: hub,
      rows: rows,
      onPage: openList,
    );
    return DashboardGrid(
      key: const ValueKey('life-tasks'),
      cards: isDesktop(context)
          ? [
              for (final tile in t) (tile, 3, 6),
              (next, 7, 12),
              (priority, 5, 12),
              (list, 12, 12),
            ]
          : null,
      stacked: [KeyedSubtree(child: t.first), ...t.skip(1), next, priority, list],
    );
  }
}

/// A task's row in a table.
AppTableRow taskTableRow(
  BuildContext context,
  TaskRow r,
  VoidCallback onCheck,
  VoidCallback onOpen,
) {
  final text = Theme.of(context).textTheme;
  final muted = text.bodySmall?.copyWith(
    color: CraftTheme.of(context).secondary,
  );
  final pill = taskPill(r);
  return AppTableRow(
    id: r.id,
    onTap: onOpen,
    spoken: [r.title, ...taskDetails(r), r.status].join(', '),
    money: const [],
    lead: TaskCheck(row: r, onChanged: onCheck),
    narrow: TaskTile(row: r, onCheck: onCheck, onOpen: onOpen),
    cells: [
      Text(r.title, style: text.bodyMedium),
      Text(r.due.isEmpty ? 'No due date' : civilLabel(r.due), style: muted),
      Text(r.priority, style: muted),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: pill ?? Text(r.status, style: muted),
      ),
    ],
  );
}

const _taskColumns = <AppTableColumn>[
  (label: 'Task', flex: 4, width: null),
  (label: 'Due', flex: 2, width: null),
  (label: 'Priority', flex: 1, width: null),
  (label: 'Status', flex: 2, width: null),
];

/// Rows under a header for each group.
List<AppTableRow> taskTable(
  BuildContext context,
  List<TaskRow> rows,
  void Function(TaskRow) onCheck,
  void Function(TaskRow) onOpen,
) {
  final out = <AppTableRow>[];
  TaskGroup? group;
  for (final r in rows) {
    if (r.group != group) {
      group = r.group;
      out.add(
        AppTableRow.header(
          'group-${group.name}',
          Text(group.label, style: Theme.of(context).textTheme.labelLarge),
        ),
      );
    }
    out.add(
      taskTableRow(context, r, () => onCheck(r), () => onOpen(r)),
    );
  }
  return out;
}

/// Every task, with a filter and search.
class LifeTaskList extends StatefulWidget {
  const LifeTaskList({
    super.key,
    required this.source,
    required this.hub,
    required this.rows,
    required this.onPage,
  });
  final LifeSource source;
  final LifeHub hub;
  final List<TaskRow> rows;
  final VoidCallback onPage;
  @override
  State<LifeTaskList> createState() => _LifeTaskListState();
}

class _LifeTaskListState extends State<LifeTaskList> {
  static const page = 25;
  int shown = page;
  late final search = TextEditingController(text: widget.hub.taskQuery);

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hub = widget.hub, source = widget.source;
    final found = filterTasks(widget.rows, hub.taskFilter, hub.taskQuery);
    return OverviewCard(
      title: 'Your tasks',
      caption: '${found.length} ${found.length == 1 ? 'task' : 'tasks'}',
      stackBelow: Space.xxxl * 8,
      trailing: MiniSegmented<TaskFilter>(
        key: const ValueKey('life-task-filter'),
        label: 'Which tasks',
        options: [for (final f in TaskFilter.values) (f, f.label)],
        selected: hub.taskFilter,
        onSelected: (f) {
          shown = page;
          hub.setTaskFilter(f);
        },
      ),
      corner: CardMenu(
        key: const ValueKey('life-tasks-menu'),
        tooltip: 'Task options',
        items: [
          MenuItemButton(
            key: const ValueKey('life-tasks-open-list'),
            leadingIcon: const Icon(Icons.open_in_full),
            onPressed: widget.onPage,
            child: const Text('Open as a page'),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.notifications_none),
            onPressed: source.actions.reminders,
            child: const Text('Reminders'),
          ),
          if (source.actions.preferences != null)
            MenuItemButton(
              leadingIcon: const Icon(Icons.settings_outlined),
              onPressed: source.actions.preferences,
              child: const Text('Preferences & help'),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('life-task-search'),
            controller: search,
            decoration: const InputDecoration(
              hintText: 'Search tasks',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) {
              shown = page;
              hub.setTaskQuery(v);
            },
          ),
          const SizedBox(height: Space.md),
          if (found.isEmpty)
            EmptyState(
              icon: Icons.check_circle_outline,
              title: hub.taskQuery.trim().isNotEmpty
                  ? 'Nothing matches that'
                  : switch (hub.taskFilter) {
                      TaskFilter.completed => 'Nothing completed yet',
                      TaskFilter.archived => 'Nothing archived',
                      _ => 'No tasks yet',
                    },
              message: hub.taskQuery.trim().isNotEmpty
                  ? 'Try other words, or another filter.'
                  : 'Tasks you add show here.',
            )
          else ...[
            AppTable(
              columns: _taskColumns,
              leadWidth: Space.target,
              dense: true,
              rows: taskTable(
                context,
                found.take(shown).toList(),
                (r) => toggleTask(source, hub, r),
                (r) => source.actions.openTask(r.id),
              ),
            ),
            if (found.length > shown)
              ShowMore(
                left: found.length - shown,
                onPressed: () => setState(() => shown += page),
              )
            else
              const ListEnd(),
          ],
        ],
      ),
    );
  }
}

/// One screenshot of what's open, by group, with no tabs or actions.
class LifeTaskListPage extends StatelessWidget {
  const LifeTaskListPage({
    super.key,
    required this.listenable,
    required this.source,
  });
  final Listenable listenable;
  final LifeSource Function(BuildContext context) source;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: listenable,
    builder: (context, _) {
      final s = source(context);
      final rows = filterTasks(taskRows(s.records, s.today), TaskFilter.active);
      final counts = TaskCounts(rows);
      return ShareableList<int>(
        title: 'Tasks',
        caption: 'Life',
        heading: 'What’s left to do',
        asOf: 'As of ${civilLabel(s.today)}',
        empty: rows.isEmpty,
        stats: [
          (label: 'To do', value: '${counts.toDo}', detail: null),
          (label: 'Overdue', value: '${counts.overdue}', detail: null),
          (label: 'This week', value: '${counts.thisWeek}', detail: null),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (group, tasks) in _grouped(rows)) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: Space.md,
                  bottom: Space.xs,
                ),
                child: Text(
                  group.label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              ListGroup(
                children: [
                  for (final r in tasks)
                    AdaptiveRow(
                      title: r.title,
                      subtitle: detailLine(taskDetails(r)),
                      trailing: taskPill(r),
                      onTap: () => s.actions.openTask(r.id),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );

  static List<(TaskGroup, List<TaskRow>)> _grouped(List<TaskRow> rows) {
    final out = <(TaskGroup, List<TaskRow>)>[];
    for (final r in rows) {
      if (out.isNotEmpty && out.last.$1 == r.group) {
        out.last.$2.add(r);
      } else {
        out.add((r.group, [r]));
      }
    }
    return out;
  }
}

/// A task's page, from anywhere.
void openLifeTask(
  BuildContext context,
  PrototypeSession session,
  String id,
) => openDemoPage<void>(
  context,
  LifeTaskPage(
    listenable: Listenable.merge([session, lifeHubOf(session)]),
    source: (context) => lifeSource(context, session),
    hub: lifeHubOf(session),
    id: id,
  ),
  'life/entry/$id',
);

/// A task: what it is, when it's due, and what's been done to it.
class LifeTaskPage extends StatefulWidget {
  const LifeTaskPage({
    super.key,
    required this.listenable,
    required this.source,
    required this.hub,
    required this.id,
  });
  final Listenable listenable;
  final LifeSource Function(BuildContext context) source;
  final LifeHub hub;
  final String id;
  @override
  State<LifeTaskPage> createState() => _LifeTaskPageState();
}

class _LifeTaskPageState extends State<LifeTaskPage> {
  String? problem;

  Future<void> change(
    LifeSource source,
    TaskRow r,
    Map<String, String> fields,
    String reason,
  ) async {
    setState(() => problem = null);
    try {
      await source.writer.change(r.id, r.record.version, fields, reason);
    } on FormatException catch (e) {
      if (mounted) setState(() => problem = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => problem = 'That didn’t save. Your records are unchanged.',
        );
      }
    }
  }

  Future<void> archive(LifeSource source, TaskRow r) async {
    final yes = await showAppDialog<bool>(
      context,
      title: 'Archive this task?',
      body: const Text(
        'It leaves your tasks and calendar, and its reminder stops. Its history stays, and you can restore it.',
      ),
      primary: const ModalAction('Archive task', value: true),
    );
    if (yes == true) await change(source, r, {'archived': 'true'}, 'Archived');
  }

  Widget more(LifeSource source, TaskRow r) => MenuAnchor(
    alignmentOffset: const Offset(0, Space.xs),
    menuChildren: [
      if (!r.archived)
        MenuItemButton(
          key: const ValueKey('life-task-edit'),
          leadingIcon: const Icon(Icons.edit_outlined),
          onPressed: () => source.actions.editTask(r.id),
          child: const Text('Edit task'),
        ),
      if (r.archived)
        MenuItemButton(
          key: const ValueKey('life-task-restore'),
          leadingIcon: const Icon(Icons.restore),
          onPressed: () =>
              change(source, r, {'archived': 'false'}, 'Restored'),
          child: const Text('Restore task'),
        )
      else
        MenuItemButton(
          key: const ValueKey('life-task-archive'),
          leadingIcon: const Icon(Icons.archive_outlined),
          onPressed: () => archive(source, r),
          child: const Text('Archive task'),
        ),
    ],
    builder: (context, controller, _) => AppIconButton(
      key: const ValueKey('life-task-more'),
      icon: Icons.more_horiz,
      tooltip: 'More actions',
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.listenable,
    builder: (context, _) {
      final source = widget.source(context);
      final record = source.records[widget.id];
      if (record is! TaskRecord) {
        return const SectionPage(
          title: 'Task',
          child: SurfaceCard(
            child: EmptyState(
              icon: Icons.history,
              title: 'This task is no longer here',
              message: 'Go back to Tasks to see what’s left.',
            ),
          ),
        );
      }
      final r = TaskRow(record, source.today);
      final detail = record.fields['detail']!;
      final about = OverviewCard(
        key: const ValueKey('life-task-about'),
        title: 'About this task',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FactRow('Status', r.status),
            FactRow(
              'Due date',
              r.due.isEmpty ? 'None' : civilLabel(r.due),
            ),
            FactRow('Priority', r.priority),
            if (detail.isNotEmpty) FactRow('Details', detail),
            // A reopened task keeps its old date in its record; it isn't true now.
            if (r.done && record.completionDate.isNotEmpty)
              FactRow('Date finished', civilLabel(record.completionDate)),
            if (record.notes.isNotEmpty) FactRow('Notes', record.notes),
          ],
        ),
      );
      final item = r.open && r.due.isNotEmpty
          ? source.actions.reminderFor(
              AgendaItem(
                r.id,
                r.id,
                'Tasks',
                r.title,
                r.due,
                'All day',
                record.version,
              ),
            )
          : null;
      final reminder = OverviewCard(
        key: const ValueKey('life-task-reminder'),
        title: 'Reminder',
        child: item ?? Text(
          r.due.isEmpty
              ? 'Add a due date to get a reminder.'
              : 'Finished and archived tasks don’t remind you.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
      final history = LifeHistoryCard(
        writer: source.writer,
        id: r.id,
        version: record.version,
      );
      final pill = taskPill(r);
      return SectionPage(
        title: r.title,
        caption: detailLine([
          'Task',
          if (r.priority != 'Normal') '${r.priority} priority',
          r.due.isEmpty ? 'No due date' : 'Due ${civilLabel(r.due)}',
        ]),
        status: pill,
        actions: [
          if (!r.archived)
            r.done
                ? AppButton.secondary(
                    'Reopen task',
                    key: const ValueKey('life-task-reopen'),
                    icon: Icons.undo,
                    onPressed: () => change(source, r, {
                      'status': 'In progress',
                    }, 'Reopened'),
                  )
                : AppButton(
                    'Complete task',
                    key: const ValueKey('life-task-complete'),
                    icon: Icons.task_alt,
                    onPressed: () => change(source, r, {
                      'status': 'Completed',
                    }, 'Completed'),
                  ),
          more(source, r),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (problem != null) ...[
              InlineNotice(problem!, tone: NoticeTone.error, live: true),
              SizedBox(height: Space.cardGapOf(context)),
            ],
            DashboardGrid(
              cards: isDesktop(context)
                  ? [(about, 7, 12), (reminder, 5, 12), (history, 12, 12)]
                  : null,
              stacked: [about, reminder, history],
            ),
          ],
        ),
      );
    },
  );
}
