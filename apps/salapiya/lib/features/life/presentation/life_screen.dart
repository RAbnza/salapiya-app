import 'package:flutter/material.dart';

import '../../../life/calendar_tab.dart';
import '../../../life/career_pages.dart';
import '../../../life/career_tab.dart';
import '../../../life/life_data.dart';
import '../../../life/life_domain.dart';
import '../../../life/life_forms.dart';
import '../../../life/life_header.dart';
import '../../../life/life_hub.dart';
import '../../../life/life_pages_detail.dart';
import '../../../life/progress_forms.dart';
import '../../../life/progress_pages.dart';
import '../../../life/progress_tab.dart';
import '../../../life/tasks_tab.dart';
import '../../../life/reminder_data.dart' show setReminders;
import '../../../life/reminders_tab.dart';
import '../../../local/finance_domain.dart' show civilToday;
import '../../../local/local_runtime.dart';

import '../../../app/demo_routes.dart';
import '../../../app/overview_data.dart' show monthStart;
import '../../../app/shell_navigation.dart';
import '../../../design_system/kit/kit.dart';
import '../../../design_system/theme.dart';
import '../../../prototype/scenarios.dart';
import '../../finance/presentation/financial_widgets.dart';
import '../application/life_controller.dart';

Future<void> editLifeEntry(
  BuildContext context,
  PrototypeSession s,
  LifeKind kind, {
  LifeEntry? entry,
}) => kind == LifeKind.task
    ? openTaskForm(context, s, id: entry?.id)
    : openEntryForm(
        context,
        s,
        LifeType.values.byName(kind.name),
        id: entry?.id,
      );
Future<void> editPersonalEvent(
  BuildContext context,
  PrototypeSession s, {
  PersonalEvent? event,
}) => openEventForm(context, s, id: event?.id);

/// Life's tabs, in order. Calendar and Reminders can't be hidden.
const lifeTabs = ['Calendar', 'Tasks', 'Reminders', 'Learning', 'Books', 'Career'];

class LifeScreen extends StatefulWidget {
  const LifeScreen({
    super.key,
    required this.session,
    this.initial = 'Calendar',
    this.actions = const [],
  });
  final PrototypeSession session;
  final String initial;

  /// Quick actions in the header: the shell's New items.
  final List<QuickAction> actions;
  @override
  State<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends State<LifeScreen> {
  late String tab = widget.initial;
  PrototypeSession get s => widget.session;
  LifeHub get hub => lifeHubOf(s);

  void selectTab(String t) {
    ShellNavigation.reportTab(context, t);
    setState(() => tab = t);
  }

  List<String> get visibleTabs => [
    for (final t in lifeTabs)
      if (hub.tabShown(t)) t,
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([s, hub]),
    builder: (context, _) {
      final source = lifeSource(context, s);
      final android = !isDesktop(context);
      // A tab hidden in Preferences while open goes back to the Calendar.
      final current = visibleTabs.contains(tab) ? tab : 'Calendar';
      final today = source.today;
      final calendar = LifeCalendar(
        source.rowsThrough(lifeWindowEnd(today, today)),
        today,
        monthStart(today),
        today,
        now: source.now,
      );
      // The header counts what the tab counts, so the two never disagree.
      final tasks = TaskCounts(taskRows(source.records, today));
      final onTasks = current == 'Tasks';
      final entryType = switch (current) {
        'Learning' => LifeType.learning,
        'Books' => LifeType.book,
        _ => null,
      };
      final entries = entryType == null
          ? null
          : ProgressCounts(progressRows(source.records, entryType, today));
      final onCareer = current == 'Career';
      final career = CareerCounts(
        applicationRows(source.records, today, source.timezone),
        nextSteps(careerRows(source.records, today, source.timezone)),
      );
      final late =
          entries?.overdue ??
          (onTasks
              ? tasks.overdue
              : onCareer
              ? career.overdue.length
              : calendar.late.length);
      final on =
          entries?.dueToday ??
          (onTasks
              ? tasks.dueToday
              : onCareer
              ? career.dueToday
              : calendar.onToday.length);
      final week = calendar.thisWeek.length;
      final reminding = current == 'Reminders';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LifeHeader(
            today: today,
            caption: reminding
                ? '${setReminders(source.reminders?.rows ?? const [])} set on this device'
                : onTasks
                ? '${tasks.toDo} to do'
                : entries != null
                ? entryType == LifeType.book
                      ? '${entries.inProgress.length} reading'
                      : '${entries.inProgress.length} in progress'
                : onCareer
                ? '${career.active.length} active'
                : '$week ${week == 1 ? 'thing' : 'things'} this week',
            actions: reminding
                ? const []
                : entryType != null
                ? [
                    (
                      label: ProgressWords.of(entryType).adding,
                      icon: Icons.add,
                      onSelected: () => source.actions.addEntry(entryType),
                    ),
                  ]
                : onCareer
                ? [
                    (
                      label: 'Add an application',
                      icon: Icons.add,
                      onSelected: source.actions.addApplication,
                    ),
                  ]
                : widget.actions,
            pill: reminding
                ? null
                : late > 0
                ? StatusPill(
                    '$late overdue',
                    icon: Icons.error_outline,
                    tone: PillTone.overdue,
                  )
                : on > 0
                ? StatusPill(
                    '$on today',
                    icon: Icons.today_outlined,
                    tone: PillTone.information,
                  )
                : null,
            onPill: onTasks || entries != null || onCareer
                ? null
                : () {
                    hub.select(today);
                    if (current != 'Calendar') selectTab('Calendar');
                  },
          ),
          // Android's header row is already a 48 target; keep the tabs close.
          SizedBox(height: android ? Space.xs : Space.lg),
          AppTabs<String>(
            key: const ValueKey('life-tabs'),
            tabs: [for (final t in visibleTabs) (t, t)],
            selected: current,
            onSelected: selectTab,
          ),
          SizedBox(height: Space.cardGapOf(context) + Space.xs),
          for (final n in lifeNotices(source)) ...[
            n,
            SizedBox(height: Space.cardGapOf(context)),
          ],
          if (source.reviews.isNotEmpty) ...[
            InlineNotice(
              '${source.reviews.length} ${source.reviews.length == 1 ? 'edit' : 'edits'} couldn’t be saved. You choose what happens.',
              title: 'Changes to check',
              tone: NoticeTone.warning,
              action: AppButton.secondary(
                'Check them',
                key: const ValueKey('life-open-checks'),
                onPressed: () => openLifeChecks(context, s),
              ),
            ),
            SizedBox(height: Space.cardGapOf(context)),
          ],
          if (source.restoring > 0) ...[
            InlineNotice(
              '${source.restoring} ${source.restoring == 1 ? 'edit' : 'edits'} from a backup will be checked once your connection is finished.',
            ),
            SizedBox(height: Space.cardGapOf(context)),
          ],
          if (hub.problem != null) ...[
            InlineNotice(hub.problem!, live: true),
            SizedBox(height: Space.cardGapOf(context)),
          ],
          if (reminding)
            LifeRemindersTab(source: source, hub: hub)
          else if (current == 'Tasks')
            LifeTasksTab(
              source: source,
              hub: hub,
              listenable: Listenable.merge([s, hub]),
              live: (context) => lifeSource(context, s),
            )
          else if (entryType != null)
            LifeProgressTab(
              type: entryType,
              source: source,
              hub: hub,
              listenable: Listenable.merge([s, hub]),
              live: (context) => lifeSource(context, s),
            )
          else if (onCareer)
            LifeCareerTab(
              source: source,
              hub: hub,
              listenable: Listenable.merge([s, hub]),
              live: (context) => lifeSource(context, s),
            )
          else
            LifeCalendarTab(
              source: source,
              hub: hub,
              listenable: Listenable.merge([s, hub]),
              live: (context) => lifeSource(context, s),
            ),
        ],
      );
    },
  );
}

/// An agenda item's own page.
Future<void> openLifeSource(
  BuildContext context,
  PrototypeSession session,
  AgendaItem? item,
) async {
  if (item != null && const ['Learning', 'Books'].contains(item.kind)) {
    openLifeEntry(context, session, item.sourceId);
    return;
  }
  if (item?.kind == 'Career') {
    openCareerItem(context, session, item!.id, item.sourceId);
    return;
  }
  if (item != null && session is LocalSession) {
    final today = civilToday();
    if (item.kind == 'Personal') {
      openLifeEvent(context, session, item.sourceId);
      return;
    }
    if (item.kind == 'Tasks') {
      openLifeTask(context, session, item.sourceId);
      return;
    }
    if (['Debts', 'Cards', 'Recurring'].contains(item.kind)) {
      openLifeRow(
        context,
        session,
        LifeRow(
          id: item.id,
          sourceId: item.sourceId,
          module: item.kind,
          title: item.title,
          date: item.date,
          time: item.time,
          type: LifeRowType.money,
          today: today,
          item: item,
        ),
      );
      return;
    }
  }
  await openDemoPage<void>(
    context,
    FinancePage(
      title: 'Life',
      child: LifeScreen(
        session: session,
        initial: item?.kind == 'Tasks' ? 'Tasks' : 'Calendar',
      ),
    ),
    'life/source',
  );
}
