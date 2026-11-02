import 'package:flutter/material.dart';

import '../app/overview_cards.dart' show civilLabel;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'career_pages.dart';
import 'life_cards.dart';
import 'life_data.dart';
import 'life_domain.dart';
import 'life_hub.dart';

/// Career: where do my applications stand, and what's my next step? Figures
/// are counts of current records. Rates and time in stage are deferred (L05).
class LifeCareerTab extends StatelessWidget {
  const LifeCareerTab({
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

  static const _shown = 5;

  void openList() => source.actions.openList(
    LifeApplicationsListPage(listenable: listenable, source: live),
    'Applications',
  );

  Widget tile(
    String key,
    String label,
    IconData icon,
    Widget value,
    String? caption, {
    bool accent = false,
    VoidCallback? onTap,
  }) => KpiTile(
    key: ValueKey(key),
    labels: const ['Active', 'Interviewing', 'Next step', 'Follow-ups due'],
    accent: accent,
    icon: icon,
    label: label,
    value: source.lifeComplete
        ? value
        : const MoneyAmount(
            null,
            size: MoneySize.tile,
            textAlign: TextAlign.start,
          ),
    caption: source.lifeComplete ? caption : null,
    onTap: source.lifeComplete ? onTap : null,
  );

  Widget number(int n) =>
      MoneyAmount('$n', size: MoneySize.tile, textAlign: TextAlign.start);

  List<Widget> tiles(BuildContext context, CareerCounts counts) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final active = counts.active.length;
    final next = counts.upcoming;
    final late = counts.overdue.length;
    final oldest = counts.oldest;
    return [
      tile(
        'life-career-active',
        'Active',
        Icons.work_outline,
        number(active),
        active == 0
            ? 'Nothing open'
            : counts.saved == 0
            ? 'All sent'
            : '${counts.saved} saved, not sent',
        accent: true,
      ),
      tile(
        'life-career-interviewing',
        'Interviewing',
        Icons.forum_outlined,
        number(counts.interviewing),
        counts.interviewing == 0 ? 'None right now' : 'Interview or assessment',
      ),
      tile(
        'life-career-next',
        'Next step',
        Icons.upcoming_outlined,
        Text(
          next?.title ?? 'Nothing planned',
          style: text.titleSmall?.copyWith(
            color: next == null ? c.secondary : c.text,
          ),
        ),
        next == null ? null : detailLine(lifeWhen(context, next).take(2)),
        onTap: next == null ? null : () => source.actions.openRow(next),
      ),
      tile(
        'life-career-followups',
        'Follow-ups due',
        Icons.error_outline,
        number(late),
        oldest == null
            ? 'Nothing overdue'
            : 'Oldest $oldest ${oldest == 1 ? 'day' : 'days'}',
      ),
    ];
  }

  Widget standsCard(BuildContext context, CareerCounts counts) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(
      color: CraftTheme.of(context).secondary,
    );
    final active = counts.active.length;
    Widget line(String stage) {
      final n = counts.stage(stage);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: '$stage, $n',
              excludeSemantics: true,
              child: Row(
                children: [
                  Expanded(child: Text(stage, style: text.bodyMedium)),
                  Text('$n', style: text.titleSmall),
                ],
              ),
            ),
            const SizedBox(height: Space.xs),
            SlimBar(fraction: active == 0 ? 0 : n / active),
          ],
        ),
      );
    }

    final closed = counts.closed.length;
    final outcomes = [
      for (final o in careerOutcomes)
        if (counts.outcome(o) > 0)
          '${counts.outcome(o)} ${careerOutcomeLabel(o).toLowerCase()}',
    ];
    return OverviewCard(
      key: const ValueKey('life-career-stands'),
      title: 'Where they stand',
      caption: 'Your active applications, by stage',
      child: active == 0 && closed == 0
          ? EmptyState(
              icon: Icons.work_outline,
              title: 'No applications yet',
              message: 'Add one when you find a role you want to follow.',
              action: AppButton.secondary(
                'Add an application',
                onPressed: source.actions.addApplication,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final stage in careerPipelineStages)
                  if (stage != 'Accepted') line(stage),
                if (closed > 0) ...[
                  const SizedBox(height: Space.sm),
                  Text('$closed closed', style: text.titleSmall),
                  const SizedBox(height: Space.xxs),
                  Text(detailLine(outcomes), style: muted),
                ],
                const ListEnd(),
              ],
            ),
    );
  }

  Widget stepRow(BuildContext context, LifeRow r) => AdaptiveRow(
    key: ValueKey('life-next-${r.id}'),
    leading: lifeIcon(r),
    title: r.title,
    subtitle: detailLine([
      ...lifeWhen(context, r),
      if (r.late) '${-r.days} ${r.days == -1 ? 'day' : 'days'} overdue',
    ]),
    pill: lifePill(r),
    onTap: () => source.actions.openRow(r),
  );

  Widget nextCard(BuildContext context, CareerCounts counts) {
    final rows = counts.next;
    final left = rows.length - _shown;
    return OverviewCard(
      key: const ValueKey('life-career-steps'),
      title: 'Next steps',
      caption: 'Overdue first, then by date',
      child: rows.isEmpty
          ? const EmptyState(
              icon: Icons.upcoming_outlined,
              title: 'Nothing planned',
              message: 'Interviews, assessments and follow-ups show here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListGroup(
                  leading: true,
                  children: [
                    for (final r in rows.take(_shown)) stepRow(context, r),
                  ],
                ),
                left > 0
                    ? ListEnd(label: '$left more', onPressed: openList)
                    : const ListEnd(),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = source.today, zone = source.timezone;
    final rows = applicationRows(source.records, today, zone);
    final counts = CareerCounts(
      rows,
      nextSteps(careerRows(source.records, today, zone)),
    );
    final t = tiles(context, counts);
    final stands = standsCard(context, counts);
    final next = nextCard(context, counts);
    final list = LifeApplicationList(
      key: const ValueKey('life-career-list'),
      source: source,
      hub: hub,
      rows: rows,
      onPage: openList,
    );
    return DashboardGrid(
      key: const ValueKey('life-career'),
      cards: isDesktop(context)
          ? [
              for (final tile in t) (tile, 3, 6),
              (stands, 8, 12),
              (next, 4, 12),
              (list, 12, 12),
            ]
          : null,
      stacked: [
        KeyedSubtree(child: t.first),
        ...t.skip(1),
        next,
        stands,
        list,
      ],
    );
  }
}

/// Every application, with a filter, a stage and search.
class LifeApplicationList extends StatefulWidget {
  const LifeApplicationList({
    super.key,
    required this.source,
    required this.hub,
    required this.rows,
    required this.onPage,
  });
  final LifeSource source;
  final LifeHub hub;
  final List<ApplicationRow> rows;
  final VoidCallback onPage;
  @override
  State<LifeApplicationList> createState() => _LifeApplicationListState();
}

class _LifeApplicationListState extends State<LifeApplicationList> {
  static const page = 25;
  int shown = page;
  late final search = TextEditingController(text: widget.hub.careerQuery);

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  AppTableRow row(BuildContext context, ApplicationRow r) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(
      color: CraftTheme.of(context).secondary,
    );
    final open = widget.source.actions.openApplication;
    final next = r.next == null ? null : nextLine(r.next!);
    final applied = r.applied.isEmpty ? 'Not sent' : civilLabel(r.applied);
    return AppTableRow(
      id: r.id,
      onTap: () => open(r.id),
      spoken: [r.company, r.position, r.standing, applied, ?next].join(', '),
      money: const [],
      narrow: AdaptiveRow(
        key: ValueKey('life-application-${r.id}'),
        title: r.company,
        subtitle: detailLine(applicationDetails(r)),
        pill: applicationPill(r, short: true),
        narrowBelow: applicationRowBase,
        onTap: () => open(r.id),
      ),
      cells: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(r.company, style: text.bodyMedium),
            Text(r.position, style: muted),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: applicationPill(r),
        ),
        Text(applied, style: muted),
        Text(next ?? '—', style: muted),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hub = widget.hub, source = widget.source;
    final found = filterApplications(
      widget.rows,
      hub.careerFilter,
      stage: hub.careerStage,
      words: hub.careerQuery,
    );
    final narrowed =
        hub.careerQuery.trim().isNotEmpty || hub.careerStage != null;
    return OverviewCard(
      title: 'Your applications',
      caption:
          '${found.length} ${found.length == 1 ? 'application' : 'applications'}',
      stackBelow: Space.xxxl * 8,
      trailing: MiniSegmented<ApplicationFilter>(
        key: const ValueKey('life-career-filter'),
        label: 'Which applications',
        options: [for (final f in ApplicationFilter.values) (f, f.label)],
        selected: hub.careerFilter,
        onSelected: (f) {
          shown = page;
          hub.setCareerFilter(f);
        },
      ),
      corner: CardMenu(
        key: const ValueKey('life-career-menu'),
        tooltip: 'Application options',
        items: [
          SubmenuButton(
            key: const ValueKey('life-career-stage'),
            leadingIcon: const Icon(Icons.filter_list),
            menuChildren: [
              for (final stage in [null, ...careerPipelineStages])
                MenuItemButton(
                  key: ValueKey('life-career-stage-$stage'),
                  trailingIcon: stage == hub.careerStage
                      ? const Icon(Icons.check)
                      : null,
                  onPressed: () {
                    shown = page;
                    hub.setCareerStage(stage);
                  },
                  child: Text(stage ?? 'Every stage'),
                ),
            ],
            child: const Text('Stage'),
          ),
          const Divider(height: 1),
          MenuItemButton(
            key: const ValueKey('life-career-open-list'),
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
            key: const ValueKey('life-career-search'),
            controller: search,
            decoration: const InputDecoration(
              hintText: 'Search company or role',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) {
              shown = page;
              hub.setCareerQuery(v);
            },
          ),
          const SizedBox(height: Space.md),
          if (found.isEmpty)
            EmptyState(
              icon: Icons.work_outline,
              title: narrowed
                  ? 'Nothing matches that'
                  : switch (hub.careerFilter) {
                      ApplicationFilter.closed => 'Nothing closed yet',
                      ApplicationFilter.archived => 'Nothing archived',
                      _ => 'No applications yet',
                    },
              message: narrowed
                  ? 'Try other words, or another filter.'
                  : 'Applications you add show here.',
            )
          else ...[
            AppTable(
              columns: const [
                (label: 'Company and role', flex: 4, width: null),
                (label: 'Stage', flex: 3, width: null),
                (label: 'Applied', flex: 2, width: null),
                (label: 'Next step', flex: 3, width: null),
              ],
              rows: [for (final r in found.take(shown)) row(context, r)],
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
