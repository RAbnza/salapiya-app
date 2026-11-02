import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_cards.dart' show civilLabel;
import '../app/overview_data.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import 'finance_screen.dart' show formTitles;
import 'money_cards.dart';
import 'money_data.dart';
import 'planning_cards.dart';
import 'planning_data.dart';

/// "Am I within my budgets and on track with my goals, and what's coming up?"
/// One page, with no third tab layer: budgets, goals and recurring items are
/// cards, and each opens its own page.
class PlanningTab extends StatelessWidget {
  const PlanningTab({super.key, required this.source});
  final MoneySource source;

  void open(String op) => source.actions.form(op, formTitles[op]!);

  @override
  Widget build(BuildContext context) {
    final android = !isDesktop(context);
    final s = source.snapshot, today = source.today;
    final complete = source.complete, hidden = source.hidden;
    final amount = source.amount, actions = source.actions;
    final all = complete
        ? budgetRows(s, today)
        : const <(BudgetWhen, BudgetProgress)>[];
    final current = [
      for (final (period, b) in all)
        if (period == BudgetWhen.current) b,
    ];
    final goals = complete ? goalRows(s, today) : const <GoalRow>[];
    final upcoming = complete ? upcomingRows(s, today) : const <UpcomingRow>[];
    final summary = PlanningSummary(current, goals, upcoming);
    final forecast = complete ? defaultForecast(s, today) : null;
    final low = forecast == null ? null : lowestDay(forecast);
    final recurring = complete
        ? recurringRows(s, today)
        : const <RecurringRow>[];
    String? known(BigInt v) => complete ? amount(v) : null;
    Widget words(String text) =>
        MoneyAmount(text, size: MoneySize.tile, textAlign: TextAlign.start);
    const labels = ['Budgets', 'Set aside', 'Coming up', 'Cash forecast'];
    final next = upcoming.firstOrNull;
    final tiles = <Widget>[
      KpiTile(
        key: const ValueKey('planning-budgets'),
        labels: labels,
        accent: true,
        icon: Icons.pie_chart_outline,
        label: 'Budgets',
        value: !complete
            ? MoneyAmount(
                null,
                size: MoneySize.tile,
                textAlign: TextAlign.start,
              )
            : words(
                current.isEmpty
                    ? 'None yet'
                    : summary.limited.isEmpty
                    ? '${current.length}'
                    : '${summary.withinLimit} of ${summary.limited.length}',
              ),
        caption: !complete
            ? null
            : current.isEmpty
            ? 'No budgets covering today'
            : summary.limited.isEmpty
            ? 'Zero-limit budgets'
            : summary.overLimit == 0
            ? 'Within limit'
            : 'Within limit · ${summary.overLimit} over',
      ),
      KpiTile(
        key: const ValueKey('planning-aside'),
        labels: labels,
        icon: Icons.savings_outlined,
        label: 'Set aside',
        value: MoneyAmount(
          known(savingsReserved(s)),
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        caption: !complete
            ? null
            : 'Still part of your balance · ${summary.activeGoals.length} ${summary.activeGoals.length == 1 ? 'goal' : 'goals'}',
      ),
      KpiTile(
        key: const ValueKey('planning-upcoming'),
        labels: labels,
        icon: Icons.event_outlined,
        label: 'Coming up',
        value: !complete
            ? MoneyAmount(
                null,
                size: MoneySize.tile,
                textAlign: TextAlign.start,
              )
            : words('${upcoming.length}'),
        caption: !complete
            ? null
            : next == null
            ? 'Nothing in the next 30 days'
            : 'In 30 days · next ${next.title}, ${civilLabel(next.date)}',
      ),
      KpiTile(
        key: const ValueKey('planning-forecast'),
        labels: labels,
        icon: Icons.insights_outlined,
        label: 'Cash forecast',
        value: MoneyAmount(
          complete && forecast != null && forecast.daily.isNotEmpty
              ? amount(forecast.daily.values.last)
              : null,
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        caption: !complete
            ? null
            : low == null || hidden
            ? 'Estimate, not money you have'
            : 'In 30 days · an estimate · lowest ${amount(low.$2)}',
        onTap: actions.openForecast,
      ),
    ];

    final budgets = BudgetsCard(
      key: const ValueKey('planning-budgets-card'),
      budgets: current,
      amount: amount,
      available: complete,
      hidden: hidden,
      onOpen: () {},
      onBudget: (b) => actions.openItem(b.actionId),
      emptyAction: AppButton.secondary(
        'Add a budget',
        onPressed: () => open('budget'),
      ),
      action: complete
          ? CardLink(
              'Add a budget',
              key: const ValueKey('budgets-add'),
              icon: Icons.add,
              onPressed: () => open('budget'),
            )
          : null,
      corner: all.length > current.length
          ? CardMenu(
              key: const ValueKey('budgets-menu'),
              tooltip: 'Other budgets',
              items: [
                for (final (period, b) in all)
                  if (period != BudgetWhen.current)
                    MenuItemButton(
                      key: ValueKey('budget-other-${b.budget.actionId}'),
                      onPressed: () => actions.openItem(b.budget.actionId),
                      child: Text(
                        '${b.budget.title} · ${period.label} · ${budgetPeriodLabel(b.budget)}',
                      ),
                    ),
              ],
            )
          : null,
    );
    void allUpcoming() => openDemoPage<void>(
      context,
      _UpcomingPage(
        rows: upcoming,
        today: today,
        amount: amount,
        hidden: hidden,
        onOpen: (r) => actions.openItem(r.source),
      ),
      'money/upcoming',
      title: 'Coming up',
    );
    final coming = UpcomingCard(
      key: const ValueKey('planning-upcoming-card'),
      rows: upcoming,
      amount: amount,
      available: complete,
      hidden: hidden,
      onOpen: (r) => actions.openItem(r.source),
      onAll: allUpcoming,
      corner: upcoming.isEmpty
          ? null
          : CardMenu(
              key: const ValueKey('upcoming-menu'),
              tooltip: 'More',
              items: [
                MenuItemButton(
                  key: const ValueKey('upcoming-open-page'),
                  leadingIcon: const Icon(Icons.open_in_full),
                  onPressed: allUpcoming,
                  child: const Text('Open as a page'),
                ),
              ],
            ),
    );
    final savings = GoalsCard(
      key: const ValueKey('planning-goals-card'),
      goals: summary.activeGoals,
      amount: amount,
      available: complete,
      hidden: hidden,
      corner: goals.length > summary.activeGoals.length
          ? CardMenu(
              key: const ValueKey('goals-menu'),
              tooltip: 'Other goals',
              items: [
                for (final g in goals)
                  if (g.status != 'active')
                    MenuItemButton(
                      key: ValueKey('goal-other-${g.id}'),
                      onPressed: () => actions.openItem(g.id),
                      child: Text(
                        '${g.goal.title} · ${g.status == 'completed' ? 'Completed' : 'Archived'}',
                      ),
                    ),
              ],
            )
          : null,
      onOpen: (g) => actions.openItem(g.id),
      onSetAside: (g) => actions.form(
        'reservation',
        formTitles['reservation']!,
        initial: {'goal': g.goal.id},
      ),
      onAdd: () => open('savingsGoal'),
    );
    final chart = ForecastCard(
      key: const ValueKey('planning-forecast-card'),
      forecast: forecast,
      today: today,
      amount: amount,
      available: complete,
      hidden: hidden,
      onOpen: actions.openForecast,
    );
    final items = _RecurringCard(
      key: const ValueKey('planning-recurring-card'),
      rows: recurring,
      amount: amount,
      available: complete,
      hidden: hidden,
      onOpen: (r) => actions.openItem(r.rule.actionId),
      onAdd: () => open('recurrence'),
      corner: CardMenu(
        key: const ValueKey('planning-menu'),
        tooltip: 'More',
        items: [
          MenuItemButton(
            key: const ValueKey('planning-history'),
            leadingIcon: const Icon(Icons.history),
            onPressed: () => openDemoPage<void>(
              context,
              RecordHistoryPage(
                source: source,
                title: 'Planning history',
                empty: 'Budgets, goals and recurring items show here.',
                types: {...nativePlanningCommands, ...nativeRecurrenceCommands},
              ),
              'money/planning-history',
              title: 'Planning history',
            ),
            child: const Text('History'),
          ),
        ],
      ),
    );
    return DashboardGrid(
      key: const ValueKey('planning-grid'),
      cards: android
          ? null
          : [
              for (final t in tiles) (t, 3, 6),
              (budgets, 7, 12),
              (coming, 5, 12),
              (savings, 7, 12),
              (chart, 5, 12),
              (items, 12, 12),
            ],
      stacked: [...tiles, coming, budgets, savings, chart, items],
    );
  }
}

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({
    super.key,
    required this.rows,
    required this.amount,
    required this.available,
    required this.hidden,
    required this.onOpen,
    required this.onAdd,
    required this.corner,
  });
  final List<RecurringRow> rows;
  final String Function(BigInt) amount;
  final bool available, hidden;
  final ValueChanged<RecurringRow> onOpen;
  final VoidCallback onAdd;
  final Widget corner;

  AppTableRow row(BuildContext context, RecurringRow r) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: c.secondary);
    final type = recurringKindLabel(r.rule.values['recurringKind']);
    final how = recurringLabel(r.rule);
    final next = r.next == null ? 'None' : civilLabel(r.next!.due);
    final shown = amount(r.rule.amount);
    return AppTableRow(
      id: 'recurring-${r.rule.actionId}',
      spoken: [
        r.rule.title,
        type,
        how,
        'Next $next',
        shown,
        if (!r.active) 'Archived',
      ].join(', '),
      onTap: () => onOpen(r),
      cells: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(r.rule.title, style: text.titleSmall),
            Text(type, style: muted),
          ],
        ),
        Text(how, style: text.bodySmall),
        Text(next, style: text.bodySmall),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: !r.active
              ? const StatusPill('Archived', icon: Icons.archive_outlined)
              : !r.added
              ? const StatusPill('Not in Upcoming', icon: Icons.event_busy)
              : const StatusPill(
                  'In Upcoming',
                  icon: Icons.check_circle_outline,
                  tone: PillTone.success,
                ),
        ),
      ],
      money: [shown],
      narrow: KeyedSubtree(
        key: ValueKey('row-recurring-${r.rule.actionId}'),
        child: AdaptiveRow(
          leading: r.income ? Icons.south_west : Icons.repeat,
          title: r.rule.title,
          subtitle: detailLine([how, 'Next $next']),
          trailing: MoneyAmount(shown),
          onTap: () => onOpen(r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => OverviewCard(
    title: 'Recurring items',
    caption: 'Bills, subscriptions and expected income',
    stackBelow: Space.xxxl * 10,
    corner: corner,
    trailing: available
        ? CardLink(
            'Add a recurring item',
            key: const ValueKey('recurring-add'),
            icon: Icons.add,
            onPressed: onAdd,
          )
        : null,
    child: !available
        ? const NotAvailable('Items show once your records are complete.')
        : rows.isEmpty
        ? EmptyState(
            icon: Icons.repeat,
            title: 'No recurring items yet',
            message: 'Add a bill or expected income to see it coming up.',
            action: AppButton.secondary(
              'Add a recurring item',
              onPressed: onAdd,
            ),
          )
        : AppTable(
            key: const ValueKey('recurring-table'),
            columns: const [
              (label: 'Item', flex: 3, width: null),
              (label: 'How often', flex: 3, width: null),
              (label: 'Next date', flex: 2, width: null),
              (label: 'Status', flex: 2, width: null),
            ],
            moneyColumns: const ['Expected'],
            rows: [for (final r in rows) row(context, r)],
          ),
  );
}

/// The shareable list: everything in the next 30 days, one screenshot.
class _UpcomingPage extends StatelessWidget {
  const _UpcomingPage({
    required this.rows,
    required this.today,
    required this.amount,
    required this.hidden,
    required this.onOpen,
  });
  final List<UpcomingRow> rows;
  final String today;
  final String Function(BigInt) amount;
  final bool hidden;
  final ValueChanged<UpcomingRow> onOpen;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SectionPage(
      title: 'Coming up',
      caption: 'The next 30 days · as of ${civilLabel(today)}',
      child: SurfaceCard(
        child: AppTable(
          key: const ValueKey('upcoming-share-table'),
          dense: true,
          columns: const [
            (label: 'Date', flex: 0, width: dateColumn),
            (label: 'Item', flex: 3, width: null),
            (label: 'Type', flex: 2, width: null),
          ],
          moneyColumns: const ['Amount'],
          rows: [
            for (final r in rows)
              AppTableRow(
                id: 'upcoming-share-${r.id}',
                spoken: [
                  civilLabel(r.date),
                  r.title,
                  r.kind,
                  amount(r.amount),
                ].join(', '),
                onTap: () => onOpen(r),
                cells: [
                  Text(civilLabel(r.date), style: text.bodyMedium),
                  Text(r.title, style: text.bodyMedium),
                  Text(upcomingKind(r), style: text.bodySmall),
                ],
                money: [upcomingAmount(r, amount, hidden)],
                narrow: upcomingRow(r, amount, hidden, onOpen),
              ),
          ],
        ),
      ),
    );
  }
}
