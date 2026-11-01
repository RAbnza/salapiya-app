import 'package:flutter/material.dart';

import '../../../life/calendar_tab.dart';
import '../../../life/life_controller.dart';
import '../../../life/life_data.dart';
import '../../../life/life_domain.dart';
import '../../../life/life_form.dart';
import '../../../life/life_forms.dart';
import '../../../life/life_header.dart';
import '../../../life/life_history.dart';
import '../../../life/life_hub.dart';
import '../../../life/life_pages.dart';
import '../../../life/life_pages_detail.dart';
import '../../../life/tasks_tab.dart';
import '../../../life/reminder_data.dart' show setReminders;
import '../../../life/reminders_tab.dart';
import '../../../life/career_documents.dart';
import '../../../local/finance_domain.dart' show civilToday;
import '../../../local/local_runtime.dart';

import '../../../app/demo_routes.dart';
import '../../../app/overview_data.dart' show monthStart;
import '../../../app/shell_navigation.dart';
import '../../../design_system/editorial.dart';
import '../../../design_system/kit/kit.dart';
import '../../../design_system/theme.dart';
import '../../../prototype/scenarios.dart';
import '../../common/prototype_form.dart';
import '../../finance/presentation/financial_widgets.dart';
import '../../planning/presentation/planning_screen.dart' show options;
import '../application/life_controller.dart';
import '../../supporting/presentation/files_screen.dart';

Widget _lifeView({required bool production, required Widget child}) =>
    production ? child : DemoViewState(child: child);

Future<void> editLifeEntry(
  BuildContext context,
  PrototypeSession s,
  LifeKind kind, {
  LifeEntry? entry,
}) => kind == LifeKind.task
    ? openTaskForm(context, s, id: entry?.id)
    : lifeReviewForm(
  context,
  s,
  title: entry == null ? 'New ${kind.name}' : 'Edit ${entry.title}',
  draftKey: entry?.id ?? 'new-${kind.name}',
  revision: () => s.life.revision,
  explanation:
      'A private ${kind.name} preset. Deadlines and reminders follow this source; no custom template is created.',
  fields: [
    DemoField('title', 'Title', value: entry?.title ?? ''),
    DemoField(
      'detail',
      kind == LifeKind.book
          ? 'Author'
          : kind == LifeKind.learning
          ? 'Course or learning resource'
          : 'Context',
      value: entry?.detail ?? '',
      required: false,
    ),
    DemoField(
      'due',
      'Deadline (optional YYYY-MM-DD)',
      value: entry?.due ?? (s.production ? '' : '2026-10-24'),
      required: false,
    ),
    if (kind != LifeKind.task) ...[
      DemoField(
        'total',
        kind == LifeKind.book ? 'Total pages' : 'Goal units / lessons',
        value: '${entry?.total ?? (kind == LifeKind.book ? 240 : 12)}',
      ),
      DemoField(
        'progress',
        kind == LifeKind.book ? 'Pages read' : 'Units completed',
        value: '${entry?.progress ?? 0}',
      ),
    ],
    if (s.production) ...[
      DemoField(
        'status',
        'Status',
        value: entry?.status ?? 'Not started',
        options: options(lifeStatuses),
      ),
      if (kind != LifeKind.task)
        DemoField(
          'started',
          'Started date (optional YYYY-MM-DD)',
          value:
              (s.life as DurableLifeController).fields(entry?.id)['started'] ??
              '',
          required: false,
        ),
      DemoField(
        'completed',
        'Manual completion date (optional YYYY-MM-DD)',
        value:
            (s.life as DurableLifeController).fields(entry?.id)['completed'] ??
            '',
        required: false,
      ),
      if (kind == LifeKind.book)
        DemoField(
          'rating',
          'Rating (optional 0–5, up to 4 decimal places)',
          value:
              (s.life as DurableLifeController).fields(entry?.id)['rating'] ??
              '',
          required: false,
        ),
    ],
    DemoField(
      'notes',
      'Notes',
      value: entry?.notes ?? '',
      required: false,
      lines: 3,
    ),
    if (entry != null) const DemoField('reason', 'Reason for change'),
  ],
  save: (v) => s.life.saveEntry(kind, v, old: entry),
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
    this.initialRecord,
    this.actions = const [],
  });
  final PrototypeSession session;
  final String initial;
  final String? initialRecord;

  /// Quick actions in the header: the shell's New items.
  final List<QuickAction> actions;
  @override
  State<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends State<LifeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.initialRecord == null) return;
      final id = widget.initialRecord;
      final entry = c.entries.where((r) => r.id == id).firstOrNull;
      final event = c.events.where((r) => r.id == id).firstOrNull;
      final application = c.applications.where((r) => r.id == id).firstOrNull;
      if (entry != null) {
        entry.kind == LifeKind.task
            ? openLifeTask(context, s, entry.id)
            : entryDetail(entry);
      } else if (event != null) {
        openLifeEvent(context, s, event.id);
      } else if (application != null) {
        applicationDetail(application);
      }
    });
  }

  late String tab = widget.initial;
  String query = '', filter = 'Active', stage = 'All';
  int page = 0;
  PrototypeSession get s => widget.session;
  LifeController get c => s.life;
  LifeHub get hub => lifeHubOf(s);

  void selectTab(String t) {
    ShellNavigation.reportTab(context, t);
    setState(() {
      tab = t;
      page = 0;
      query = '';
      filter = 'Active';
    });
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
      final late = onTasks ? tasks.overdue : calendar.late.length;
      final on = onTasks ? tasks.dueToday : calendar.onToday.length;
      final week = calendar.thisWeek.length;
      final reminding = current == 'Reminders';
      final redesigned = const ['Calendar', 'Tasks'].contains(current);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LifeHeader(
            today: today,
            caption: reminding
                ? '${setReminders(source.reminders?.rows ?? const [])} set on this device'
                : onTasks
                ? '${tasks.toDo} to do'
                : '$week ${week == 1 ? 'thing' : 'things'} this week',
            actions: reminding
                ? const []
                : redesigned
                ? widget.actions
                : tabActions(current, source),
            alwaysActions: !redesigned && !reminding,
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
            onPill: onTasks
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
          else if (current == 'Calendar')
            LifeCalendarTab(
              source: source,
              hub: hub,
              listenable: Listenable.merge([s, hub]),
              live: (context) => lifeSource(context, s),
            )
          else
            _lifeView(
              production: s.production,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: ValueKey('search-$current'),
                    decoration: InputDecoration(
                      labelText: 'Search ${current.toLowerCase()}',
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() {
                      query = v.toLowerCase();
                      page = 0;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in [
                        'Active',
                        'Completed',
                        'Archived',
                        'All',
                      ])
                        ChoiceChip(
                          label: Text(f),
                          selected: filter == f,
                          onSelected: (_) => setState(() {
                            filter = f;
                            page = 0;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (current == 'Career')
                    career()
                  else
                    entries(
                      current == 'Books' ? LifeKind.book : LifeKind.learning,
                    ),
                  if (filteredCount > 25)
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: page == 0
                              ? null
                              : () => setState(() => page--),
                          child: const Text('Previous page'),
                        ),
                        Text(
                          'Page ${page + 1} / ${((filteredCount + 24) ~/ 25).clamp(1, 100000)}',
                        ),
                        TextButton(
                          onPressed: (page + 1) * 25 >= filteredCount
                              ? null
                              : () => setState(() => page++),
                          child: const Text('Next page'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );

  /// Chat 13's tabs keep their own buttons until their chat.
  List<QuickAction> tabActions(String t, LifeSource source) => [
    (
      label: switch (t) {
        'Career' => 'New application',
        'Books' => 'Add book',
        _ => 'New learning goal',
      },
      icon: Icons.add,
      onSelected: () => t == 'Career'
          ? applicationForm()
          : editLifeEntry(
              context,
              s,
              t == 'Books' ? LifeKind.book : LifeKind.learning,
            ),
    ),
    if (source.actions.preferences != null)
      (
        label: 'Preferences & help',
        icon: Icons.tune,
        onSelected: source.actions.preferences!,
      ),
    (
      label: 'Reminders',
      icon: Icons.notifications_none,
      onSelected: source.actions.reminders,
    ),
  ];

  int get filteredCount {
    if (tab == 'Career') {
      return c.applications
          .where(
            (a) =>
                '${a.company} ${a.position}'.toLowerCase().contains(query) &&
                (stage == 'All' || a.stage == stage) &&
                (filter == 'All' ||
                    filter == 'Archived' && a.archived ||
                    filter == 'Completed' &&
                        !a.archived &&
                        careerOutcomes.contains(a.stage) ||
                    filter == 'Active' &&
                        !a.archived &&
                        !careerOutcomes.contains(a.stage)),
          )
          .length;
    }
    final kind = tab == 'Books' ? LifeKind.book : LifeKind.learning;
    return c.entries
        .where(
          (e) =>
              e.kind == kind &&
              '${e.title} ${e.detail}'.toLowerCase().contains(query) &&
              (filter == 'All' ||
                  filter == 'Archived' && e.archived ||
                  filter == 'Completed' &&
                      !e.archived &&
                      e.status == 'Completed' ||
                  filter == 'Active' && !e.archived && e.status != 'Completed'),
        )
        .length;
  }

  Widget entries(LifeKind kind) {
    final all = c.entries.where((e) => e.kind == kind).toList();
    final matches = all
        .where(
          (e) =>
              '${e.title} ${e.detail}'.toLowerCase().contains(query) &&
              (filter == 'All' ||
                  filter == 'Archived' && e.archived ||
                  filter == 'Completed' &&
                      !e.archived &&
                      e.status == 'Completed' ||
                  filter == 'Active' && !e.archived && e.status != 'Completed'),
        )
        .toList();
    final boundedPage = page.clamp(
      0,
      ((matches.length - 1) ~/ 25).clamp(0, 100000),
    );
    final visible = matches.skip(boundedPage * 25).take(25).toList();
    if (visible.isEmpty) {
      return const WorkspaceEmpty(
        icon: Icons.auto_awesome_outlined,
        title: 'A little room for what matters',
        message: 'Nothing here yet. Try another filter or add something you want to make time for.',
      );
    }
    if (kind == LifeKind.book) {
      return LayoutBuilder(
        builder: (context, b) => Wrap(
          spacing: 20,
          runSpacing: 28,
          children: [
            for (var i = 0; i < visible.length; i++)
              SizedBox(
                width: b.maxWidth >= 900
                    ? (b.maxWidth - 40) / 3
                    : b.maxWidth >= 580
                    ? (b.maxWidth - 20) / 2
                    : b.maxWidth,
                child: bookTile(visible[i], i),
              ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: FinanceColumns(
              main: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    e.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(e.detail),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var n = 1; n <= e.total.clamp(1, 60); n++)
                        Tooltip(
                          message: 'Unit $n',
                          child: Container(
                            width: 26,
                            height: 12,
                            decoration: BoxDecoration(
                              color: n <= e.progress
                                  ? Palette.violet
                                  : CraftTheme.of(context).subtle,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('${e.progress} of ${e.total} units · ${e.status}'),
                  TextButton(
                    onPressed: () => entryDetail(e),
                    child: const Text('Open learning journal →'),
                  ),
                ],
              ),
              aside: ValueBlock(
                'NEXT MILESTONE',
                e.due.isEmpty ? 'At your pace' : e.due,
                '${e.total - e.progress} units to go. Record your progress and what you learned.',
                color: Palette.lilac,
              ),
            ),
          ),
      ],
    );
  }

  Widget bookTile(LifeEntry e, int index) => InkWell(
    onTap: () => entryDetail(e),
    borderRadius: BorderRadius.circular(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 220),
          padding: const EdgeInsets.fromLTRB(28, 28, 24, 24),
          decoration: BoxDecoration(
            color: [Palette.lilac, Palette.peach, Palette.mint][index % 3],
            borderRadius: BorderRadius.circular(12),
            border: const Border(
              left: BorderSide(color: Palette.ink, width: 7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THE READING ROOM',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: Palette.ink,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                e.title,
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.1,
                  color: Palette.ink,
                ),
              ),
              const SizedBox(height: 20),
              Text(e.detail, style: const TextStyle(color: Palette.ink)),
              const SizedBox(height: 22),
              const Icon(Icons.auto_stories_outlined, color: Palette.ink),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ExactBar(
          label: '${e.progress} / ${e.total} pages',
          value: '${e.progress * 100 ~/ e.total}%',
          amount: BigInt.from(e.progress),
          total: BigInt.from(e.total),
          color: Palette.violet,
        ),
        Text('${e.status} · ${e.due}'),
      ],
    ),
  );
  void entryDetail(LifeEntry e) => openDemoPage<void>(
    context,
    FinancePage(
      title: e.title,
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinanceHeading(
              'LIFE / ${e.kind.name.toUpperCase()} PRESET',
              e.title,
              '${e.detail}\n${e.status}${e.archived ? ' · archived' : ''} · ${e.due.isEmpty ? 'No deadline' : e.due}',
              actions: [
                OutlinedButton(
                  onPressed: () => editLifeEntry(context, s, e.kind, entry: e),
                  child: const Text('Edit details'),
                ),
                TextButton(
                  onPressed: () => lifeAction(context, () => c.archive(e)),
                  child: Text(e.archived ? 'Restore' : 'Archive'),
                ),
              ],
            ),
            if (e.kind != LifeKind.task)
              ExactBar(
                label: 'Progress',
                value: '${e.progress} / ${e.total}',
                amount: BigInt.from(e.progress),
                total: BigInt.from(e.total),
                color: Palette.violet,
              ),
            Text(e.notes),
            const SizedBox(height: 16),
            if (!e.archived)
              FilledButton(
                onPressed: () => e.kind == LifeKind.task
                    ? lifeAction(
                        context,
                        () => c.progress(
                          e,
                          e.status == 'Completed' ? 0 : 1,
                          e.status == 'Completed' ? 'Reopened' : 'Completed',
                        ),
                      )
                    : lifeReviewForm(
                        context,
                        s,
                        title: 'Log progress · ${e.title}',
                        fields: [
                          DemoField(
                            'progress',
                            e.kind == LifeKind.book
                                ? 'Pages read'
                                : 'Completed units',
                            value: '${e.progress}',
                          ),
                          const DemoField(
                            'note',
                            'Progress note',
                            required: false,
                            lines: 3,
                          ),
                        ],
                        sourceId: e.id,
                        save: (v) => c.progress(
                          e,
                          int.tryParse(v['progress']!) ?? -1,
                          v['note']!,
                        ),
                      ),
                child: Text(
                  e.kind == LifeKind.task
                      ? (e.status == 'Completed'
                            ? 'Reopen task'
                            : 'Complete task')
                      : 'Log progress',
                ),
              ),
            if (!e.archived && e.status != 'Completed' && e.due.isNotEmpty)
              lifeReminderControls(
                s,
                AgendaItem(
                  e.id,
                  e.id,
                  e.kind.name,
                  e.title,
                  e.due,
                  'All day',
                  e.version,
                ),
              ),
            const SizedBox(height: 24),
            const SectionHeading('Your progress history'),
            if (c is DurableLifeController)
              LifeHistory(controller: c as DurableLifeController, record: e.id)
            else
              for (final h in e.history.reversed)
                FinancialLine('Retained revision', h, icon: Icons.history),
          ],
        ),
      ),
    ),
    'life/entry/${e.id}',
  );
  void applicationForm([CareerApplication? a]) => lifeReviewForm(
    context,
    s,
    title: a == null ? 'New application' : 'Edit application',
    draftKey: a?.id ?? 'new-career',
    revision: () => c.revision,
    fields: [
      DemoField('company', 'Company', value: a?.company ?? ''),
      DemoField('position', 'Position', value: a?.position ?? ''),
      DemoField(
        'date',
        'Submission date (empty while saved)',
        value: a?.date ?? (s.production ? '' : '2026-10-21'),
        required: false,
      ),
      DemoField(
        'stage',
        'Stage',
        value: s.production
            ? ((c as DurableLifeController).records[a?.id] is ApplicationRecord
                  ? ((c as DurableLifeController).records[a?.id]
                            as ApplicationRecord)
                        .stage
                  : 'Saved')
            : a?.stage ?? 'Saved',
        options: options(
          s.production
              ? careerPipelineStages
              : [
                  'Saved',
                  'Applied',
                  'Screening',
                  'Assessment',
                  'Interview',
                  'Offer',
                  'Accepted',
                  'Rejected',
                  'Withdrawn',
                ],
        ),
      ),
      if (s.production) ...[
        DemoField(
          'outcome',
          'Distinct outcome',
          value:
              ((c as DurableLifeController).records[a?.id]
                      as ApplicationRecord?)
                  ?.outcome ??
              '',
          required: false,
          options: options(['', ...careerOutcomes]),
        ),
        DemoField(
          'stageDate',
          'Actual stage date',
          value:
              (c as DurableLifeController).fields(a?.id)['stageDate'] ??
              LifeTime.today(),
        ),
        DemoField(
          'postingUrl',
          'Posting URL',
          value: (c as DurableLifeController).fields(a?.id)['postingUrl'] ?? '',
          required: false,
        ),
        DemoField(
          'source',
          'Application source',
          value: (c as DurableLifeController).fields(a?.id)['source'] ?? '',
          required: false,
        ),
        DemoField(
          'arrangement',
          'Work arrangement',
          value:
              (c as DurableLifeController).fields(a?.id)['arrangement'] ??
              'unspecified',
          options: options(['onsite', 'hybrid', 'remote', 'unspecified']),
        ),
        for (final key in [
          'salaryMin',
          'salaryMax',
          'technologies',
          'description',
          'contact',
          'resume',
          'nextAction',
          'followUp',
        ])
          DemoField(
            key,
            switch (key) {
              'salaryMin' => 'Expected salary minimum',
              'salaryMax' => 'Expected salary maximum',
              'description' => 'Job description snapshot',
              'contact' => 'Recruiter / contact details',
              'resume' => 'Resume version used',
              'nextAction' => 'Next action',
              'followUp' => 'Follow-up civil date (YYYY-MM-DD)',
              _ => 'Technologies',
            },
            value: (c as DurableLifeController).fields(a?.id)[key] ?? '',
            required: false,
            lines: ['description', 'contact'].contains(key) ? 3 : 1,
          ),
        DemoField(
          'currency',
          'Salary currency',
          value:
              (c as DurableLifeController).fields(a?.id)['currency'] ?? 'PHP',
        ),
        DemoField(
          'salaryPeriod',
          'Salary period',
          value:
              (c as DurableLifeController).fields(a?.id)['salaryPeriod'] ??
              'month',
          options: options(['hour', 'month', 'year']),
        ),
        if (a == null)
          const DemoField(
            'duplicateConsent',
            'Separate attempt if company/role already exists',
            value: 'false',
            options: {
              'false': 'Warn me about duplicates',
              'true': 'Create an independent attempt',
            },
          ),
      ],
      DemoField(
        'location',
        'Location / work arrangement',
        value: a?.location ?? '',
        required: false,
      ),
      DemoField(
        'notes',
        'Notes',
        value: a?.notes ?? '',
        required: false,
        lines: 3,
      ),
      if (a != null) const DemoField('reason', 'Reason'),
    ],
    save: (v) => c.saveApplication(v, old: a),
  );
  Widget career() {
    final all = c.applications
        .where(
          (a) =>
              '${a.company} ${a.position}'.toLowerCase().contains(query) &&
              (filter == 'All' ||
                  filter == 'Archived' && a.archived ||
                  filter == 'Completed' &&
                      !a.archived &&
                      careerOutcomes.contains(a.stage) ||
                  filter == 'Active' &&
                      !a.archived &&
                      !careerOutcomes.contains(a.stage)),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: DropdownButtonFormField<String>(
              initialValue: stage,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Application stage'),
              items: [
                for (final t
                    in s.production
                        ? ['All', ...careerStages]
                        : [
                            'All',
                            'Saved',
                            'Applied',
                            'Screening',
                            'Assessment',
                            'Interview',
                            'Offer',
                            'Accepted',
                            'Rejected',
                            'Withdrawn',
                          ])
                  DropdownMenuItem(
                    value: t,
                    child: Text(t == 'All' ? 'All stages' : t),
                  ),
              ],
              onChanged: (t) {
                if (t != null) {
                  setState(() {
                    stage = t;
                    page = 0;
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        FinanceColumns(
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final a
                  in all
                      .where((a) => stage == 'All' || a.stage == stage)
                      .skip(page * 25)
                      .take(25))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: InkWell(
                    onTap: () => applicationDetail(a),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 8, 8, 16),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            width: 4,
                            color: a.stage == 'Interview'
                                ? Palette.violet
                                : Palette.mint,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            a.company,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(a.position),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text(a.stage)),
                              Text('${a.date} · ${a.location}'),
                            ],
                          ),
                          TextButton(
                            onPressed: () => applicationDetail(a),
                            child: const Text('Application story →'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (!all.any((a) => stage == 'All' || a.stage == stage))
                const WorkspaceEmpty(
                  icon: Icons.work_outline,
                  title: 'Room for your next opportunity',
                  message: 'No applications match. Add an application when you find a role you want to follow.',
                ),
            ],
          ),
          aside: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValueBlock(
                'IN MOTION',
                '${all.length}',
                'Applications in this view. Stages are your records, never inferred employer decisions.',
              ),
              const SizedBox(height: 20),
              const SectionHeading('Next conversations'),
              for (final a in all.take(25))
                for (final e in a.events.where((e) => !e.complete).take(5))
                  FinancialLine(
                    a.company,
                    '${e.kind} · ${e.date} ${e.time}',
                    icon: Icons.work_outline,
                    onTap: () => applicationDetail(a),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  void careerEventForm(CareerApplication a, [CareerEvent? e]) => lifeReviewForm(
    context,
    s,
    title: e == null ? 'Add career event' : 'Edit career event',
    draftKey: e?.id ?? 'new-career-event-${a.id}',
    revision: () => c.revision,
    fields: [
      DemoField(
        'kind',
        'Type',
        value: e?.kind ?? 'Interview',
        options: options(
          s.production
              ? careerEventKinds
              : ['Interview', 'Assessment', 'Follow-up'],
        ),
      ),
      DemoField(
        'date',
        'Date',
        value: e?.date ?? (s.production ? LifeTime.today() : '2026-10-23'),
      ),
      DemoField(
        'time',
        'Time (optional except interview / assessment)',
        value: e?.time == 'All day' ? '' : e?.time ?? '10:00',
        required: false,
      ),
      if (s.production) ...[
        DemoField(
          'timezone',
          'Original IANA timezone',
          value:
              (c as DurableLifeController).fields(e?.id)['timezone'] ??
              'Asia/Manila',
        ),
        DemoField(
          'fold',
          'Ambiguous time occurrence',
          value: (c as DurableLifeController).fields(e?.id)['fold'] ?? '',
          required: false,
          options: options(['', 'Earlier', 'Later']),
        ),
        DemoField(
          'status',
          'Event status (observations must be Completed)',
          value:
              (c as DurableLifeController).fields(e?.id)['status'] ??
              'Scheduled',
          options: options(['Scheduled', 'Completed', 'Cancelled']),
        ),
        DemoField(
          'location',
          'Location or meeting link',
          value: (c as DurableLifeController).fields(e?.id)['location'] ?? '',
          required: false,
        ),
        DemoField(
          'outcome',
          'Recorded event outcome',
          value: (c as DurableLifeController).fields(e?.id)['outcome'] ?? '',
          required: false,
        ),
        if (e != null) const DemoField('reason', 'Reason for revision'),
      ],
      DemoField(
        'notes',
        'Location, preparation and notes',
        value: e?.notes ?? '',
        required: false,
        lines: 3,
      ),
    ],
    save: (v) => c.saveCareerEvent(a, v, old: e),
  );
  void applicationDetail(CareerApplication a) => openDemoPage<void>(
    context,
    FinancePage(
      title: a.company,
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinanceHeading(
              'CAREER / ${a.stage.toUpperCase()}',
              a.position,
              '${a.company} · ${a.location}\nApplied ${a.date}${a.archived ? ' · archived' : ''}',
              actions: [
                OutlinedButton(
                  onPressed: () => applicationForm(a),
                  child: const Text('Edit / change stage'),
                ),
                FilledButton(
                  onPressed: a.archived || careerOutcomes.contains(a.stage)
                      ? null
                      : () => careerEventForm(a),
                  child: const Text('Add interview / follow-up'),
                ),
                TextButton(
                  onPressed: () =>
                      lifeAction(context, () => c.archiveApplication(a)),
                  child: Text(a.archived ? 'Restore' : 'Archive'),
                ),
              ],
            ),
            Text(a.notes),
            if (c is DurableLifeController &&
                (c as DurableLifeController).records[a.id]
                    is ApplicationRecord) ...[
              FinancialLine(
                'Current stage',
                ((c as DurableLifeController).records[a.id]
                        as ApplicationRecord)
                    .stage,
              ),
              FinancialLine(
                'Distinct outcome',
                ((c as DurableLifeController).records[a.id]
                        as ApplicationRecord)
                    .outcome,
              ),
            ],
            if (c is DurableLifeController) ...[
              for (final value
                  in (c as DurableLifeController)
                      .fields(a.id)
                      .entries
                      .where(
                        (v) =>
                            [
                              'postingUrl',
                              'source',
                              'date',
                              'stageDate',
                              'arrangement',
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
                            ].contains(v.key) &&
                            v.value.isNotEmpty,
                      ))
                FinancialLine(
                  const {
                        'postingUrl': 'Posting URL',
                        'source': 'Found through',
                        'date': 'Submitted on',
                        'stageDate': 'Stage recorded for',
                        'arrangement': 'Work arrangement',
                        'salaryMin': 'Minimum expected salary',
                        'salaryMax': 'Maximum expected salary',
                        'currency': 'Currency',
                        'salaryPeriod': 'Salary period',
                        'technologies': 'Technologies',
                        'description': 'Job description snapshot',
                        'contact': 'Recruiter or contact',
                        'resume': 'Resume version used',
                        'nextAction': 'Next action',
                        'followUp': 'Follow-up date',
                      }[value.key] ??
                      value.key,
                  s.hideAmounts &&
                          ['salaryMin', 'salaryMax'].contains(value.key)
                      ? 'Hidden'
                      : value.value,
                ),
            ],
            const SizedBox(height: 24),
            const SectionHeading('Conversations & milestones'),
            LifePages(
              count: a.events.length,
              itemBuilder: (context, index) {
                final e = a.events[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FinancialLine(
                      e.kind,
                      '${e.date} · ${e.time} · ${e.complete ? 'Completed' : 'Planned'}\n${e.notes}',
                      icon: Icons.event_note,
                      onTap: a.archived || careerOutcomes.contains(a.stage)
                          ? null
                          : () => careerEventForm(a, e),
                    ),
                    TextButton(
                      onPressed:
                          a.archived ||
                              careerOutcomes.contains(a.stage) ||
                              [
                                'Response',
                                'Offer',
                                'No response',
                                'Note',
                              ].contains(e.kind)
                          ? null
                          : () => lifeAction(
                              context,
                              () => c.completeCareerEvent(a, e),
                            ),
                      child: Text(
                        e.complete ? 'Reopen event' : 'Mark event complete',
                      ),
                    ),
                    if (s.production)
                      ExpansionTile(
                        title: const Text('Career event history'),
                        children: [
                          LifeHistory(
                            controller: c as DurableLifeController,
                            record: e.id,
                          ),
                        ],
                      ),
                    if (!e.complete && !a.archived)
                      lifeReminderControls(
                        s,
                        AgendaItem(
                          e.id,
                          a.id,
                          'Career',
                          '${e.kind} · ${a.company}',
                          e.date,
                          e.time,
                          e.version + a.version,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SectionHeading('Documents'),
            if (s.production)
              CareerDocuments(session: s as LocalSession, application: a.id)
            else
              SupportingFilesLink(session: s, source: 'career:${a.id}'),
            for (final file in s.finance.files.files.where(
              (f) => f.source == 'career:${a.id}',
            ))
              FinancialLine(
                file.name,
                file.state,
                icon: Icons.description_outlined,
              ),
            const SectionHeading('Application history'),
            if (c is DurableLifeController)
              LifeHistory(
                controller: c as DurableLifeController,
                record: a.id,
                hideAmounts: s.hideAmounts,
              )
            else
              for (final h in a.history.reversed)
                FinancialLine('History', h, icon: Icons.history),
          ],
        ),
      ),
    ),
    'life/career/${a.id}',
  );
}

/// An agenda item's own page. Learning, Books and Career open their tab until
/// Chat 13 gives them pages.
Future<void> openLifeSource(
  BuildContext context,
  PrototypeSession session,
  AgendaItem? item,
) async {
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
        initialRecord: item?.sourceId,
        initial: switch (item?.kind) {
          'Tasks' => 'Tasks',
          'Learning' => 'Learning',
          'Books' => 'Books',
          'Career' => 'Career',
          _ => 'Calendar',
        },
      ),
    ),
    'life/source',
  );
}
