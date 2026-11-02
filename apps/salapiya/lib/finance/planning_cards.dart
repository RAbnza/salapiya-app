import 'package:flutter/material.dart';

import '../app/overview_cards.dart' show Amount, civilLabel;
import '../app/overview_data.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import 'money_cards.dart' show signedAmount;
import 'planning_data.dart';

/// Planning cards (Chat 9). Each card shows values it is given; the screens
/// read the source and `planning_data.dart` derives the rest.

/// O8: active budgets against their limits, in exact basis points, with a
/// gauge of the total used across the budgets that have a limit.
class BudgetsCard extends StatelessWidget {
  const BudgetsCard({
    super.key,
    required this.budgets,
    required this.amount,
    required this.onOpen,
    this.onBudget,
    this.action,
    this.corner,
    this.emptyAction,
    this.available = true,
    this.hidden = false,
  });
  final List<BudgetProgress> budgets;
  final Amount amount;
  final VoidCallback onOpen;

  /// Rows open their budget.
  final ValueChanged<LocalRevision>? onBudget;

  /// Replaces the "View budgets" link.
  final Widget? action, corner, emptyAction;
  final bool available, hidden;

  static String percent(int basisPoints) =>
      '${basisPoints ~/ 100}.${(basisPoints % 100).toString().padLeft(2, '0')}%';

  static String line(BudgetProgress b, Amount amount) => b.basisPoints == null
      ? '${amount(b.spent)} spent · zero-limit budget'
      : b.over > BigInt.zero
      ? '${amount(b.spent)} of ${amount(b.limit)} · ${amount(b.over)} over'
      : '${amount(b.spent)} of ${amount(b.limit)} · ${percent(b.basisPoints!)} used';

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final totals = budgetTotals(budgets);
    final bp = totals.basisPoints;
    final over = totals.spent > totals.limit;
    // No total across different periods or bases (DOMAIN_RULES V2-C).
    final gauge = bp == null || hidden || !sameBudgetTerms(budgets)
        ? null
        : Semantics(
            label:
                'All budgets with a limit: ${percent(bp)} used, ${amount(totals.spent)} of ${amount(totals.limit)}',
            excludeSemantics: true,
            child: BudgetGauge(
              key: const ValueKey('budget-gauge'),
              fraction: bp / 10000,
              over: over,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    percent(bp),
                    style: text.headlineSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    over ? 'over the limit' : 'used',
                    style: text.bodySmall?.copyWith(color: c.secondary),
                  ),
                ],
              ),
            ),
          );
    Widget row(BudgetProgress b, int i) {
      final tap = onBudget;
      final body = Semantics(
        button: tap != null,
        label: hidden
            ? b.budget.title
            : '${b.budget.title}: ${line(b, amount)}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(b.budget.title, style: text.titleSmall),
                if (b.overLimit)
                  const StatusPill(
                    'Over the limit',
                    icon: Icons.warning_amber_rounded,
                    tone: PillTone.warning,
                  ),
                if (b.basisPoints == null)
                  const StatusPill('Zero-limit budget', icon: Icons.block),
              ],
            ),
            if (!hidden) ...[
              const SizedBox(height: Space.xs),
              if (b.basisPoints != null)
                SlimBar(
                  fraction: b.basisPoints! / 10000,
                  color: b.overLimit ? c.tone(NoticeTone.warning).$1 : null,
                ),
              const SizedBox(height: Space.xs),
              // Its pill already says what kind of budget it is.
              Text(
                b.basisPoints == null
                    ? '${amount(b.spent)} spent'
                    : line(b, amount),
                style: text.bodySmall?.copyWith(color: c.secondary),
              ),
            ],
          ],
        ),
      );
      return tap == null
          ? body
          : Pressable(
              key: ValueKey('budget-${b.budget.actionId}'),
              onTap: () => tap(b.budget),
              child: body,
            );
    }

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, b) in budgets.indexed) ...[
          if (i > 0) const SizedBox(height: Space.md),
          row(b, i),
        ],
        if (onBudget != null) const ListEnd(key: ValueKey('budgets-end')),
      ],
    );
    return OverviewCard(
      title: 'Budgets',
      centered: onBudget == null,
      fill: onBudget != null,
      caption: 'Active budgets covering today',
      trailing: action ?? CardLink('View budgets', onPressed: onOpen),
      corner: corner,
      child: !available
          ? const NotAvailable('Budgets show once your records are complete.')
          : budgets.isEmpty
          ? EmptyState(
              icon: Icons.savings_outlined,
              title: 'No active budgets',
              message: 'Budgets you set in Money show their progress here.',
              action:
                  emptyAction ??
                  AppButton.secondary('Open budgets', onPressed: onOpen),
            )
          : LayoutBuilder(
              builder: (context, box) => gauge == null
                  ? list
                  : narrowAt(context, box.maxWidth, tableBase)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: gauge),
                        const SizedBox(height: Space.lg),
                        list,
                      ],
                    )
                  // The gauge centers in the height the card has; the list
                  // keeps to the top, as lists do.
                  : Row(
                      children: [
                        gauge,
                        const SizedBox(width: Space.xl),
                        Expanded(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: box.minHeight,
                            ),
                            child: Align(
                              alignment: AlignmentDirectional.topStart,
                              heightFactor: 1,
                              child: list,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}

/// What's coming up in the next 30 days. There's no total: a statement and
/// its installments can overlap.
class UpcomingCard extends StatelessWidget {
  const UpcomingCard({
    super.key,
    required this.rows,
    required this.amount,
    required this.available,
    required this.onOpen,
    required this.onAll,
    this.hidden = false,
    this.corner,
    this.shown = 6,
  });
  final List<UpcomingRow> rows;
  final Amount amount;
  final bool available, hidden;
  final ValueChanged<UpcomingRow> onOpen;

  /// Opens every row, when they don't all fit.
  final VoidCallback onAll;
  final Widget? corner;
  final int shown;

  @override
  Widget build(BuildContext context) {
    final visible = rows.take(shown).toList();
    final left = rows.length - visible.length;
    return OverviewCard(
      title: 'Coming up',
      caption: 'The next 30 days',
      corner: corner,
      child: !available
          ? const NotAvailable('Dates show once your records are complete.')
          : visible.isEmpty
          ? const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nothing coming up',
              message: 'Bills, income, statements and debts due show here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListGroup(
                  leading: true,
                  children: [
                    for (final r in visible)
                      upcomingRow(r, amount, hidden, onOpen),
                  ],
                ),
                ListEnd(
                  key: const ValueKey('upcoming-end'),
                  label: left > 0 ? '$left more' : 'That’s everything',
                  onPressed: left > 0 ? onAll : null,
                ),
              ],
            ),
    );
  }
}

/// What a row is, and whether it's only expected so far.
String upcomingKind(UpcomingRow r) =>
    r.expected && !r.income ? '${r.kind} · Expected' : r.kind;

/// Income reads as money coming in.
String upcomingAmount(UpcomingRow r, Amount amount, bool hidden) => r.income
    ? signedAmount(r.amount, amount, hidden: hidden)
    : amount(r.amount);

/// One thing coming up.
Widget upcomingRow(
  UpcomingRow r,
  Amount amount,
  bool hidden,
  ValueChanged<UpcomingRow> onOpen,
) => AdaptiveRow(
  key: ValueKey('upcoming-${r.id}'),
  leading: r.income ? Icons.south_west : Icons.event_outlined,
  title: r.title,
  subtitle: detailLine([civilLabel(r.date), upcomingKind(r)]),
  trailing: MoneyAmount(upcomingAmount(r, amount, hidden)),
  onTap: () => onOpen(r),
);

/// Active savings goals: how much is set aside and whether your accounts
/// cover it. A shared shortfall stays shared: no goal wins it.
class GoalsCard extends StatelessWidget {
  const GoalsCard({
    super.key,
    required this.goals,
    required this.amount,
    required this.available,
    required this.hidden,
    required this.onOpen,
    required this.onSetAside,
    required this.onAdd,
    this.corner,
  });
  final List<GoalRow> goals;
  final Amount amount;
  final bool available, hidden;
  final ValueChanged<GoalRow> onOpen, onSetAside;
  final VoidCallback onAdd;

  /// Completed and archived goals.
  final Widget? corner;

  @override
  Widget build(BuildContext context) => OverviewCard(
    title: 'Savings goals',
    caption: 'Money set aside stays in your accounts',
    corner: corner,
    trailing: available
        ? CardLink(
            'Add a goal',
            key: const ValueKey('goals-add'),
            icon: Icons.add,
            onPressed: onAdd,
          )
        : null,
    child: !available
        ? const NotAvailable('Goals show once your records are complete.')
        : goals.isEmpty
        ? EmptyState(
            icon: Icons.savings_outlined,
            title: 'No goals yet',
            message: 'A goal sets aside money you already have.',
            action: AppButton.secondary('Add a goal', onPressed: onAdd),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, g) in goals.indexed) ...[
                if (i > 0) const SizedBox(height: Space.md),
                _GoalRow(
                  goal: g,
                  amount: amount,
                  hidden: hidden,
                  onOpen: () => onOpen(g),
                  onSetAside: () => onSetAside(g),
                ),
              ],
              const ListEnd(key: ValueKey('goals-end')),
            ],
          ),
  );
}

/// A goal's funding as a pill, in words as well as color.
Widget goalPill(GoalRow g) => switch (g.status) {
  'completed' => const StatusPill(
    'Completed',
    icon: Icons.check_circle_outline,
    tone: PillTone.success,
  ),
  'archived' => const StatusPill('Archived', icon: Icons.archive_outlined),
  _ => switch (g.funding) {
    GoalFunding.funded => StatusPill(
      g.funding.label,
      icon: Icons.check_circle_outline,
      tone: PillTone.success,
    ),
    GoalFunding.none => StatusPill(
      g.funding.label,
      icon: Icons.remove_circle_outline,
    ),
    GoalFunding.shared => StatusPill(
      g.funding.label,
      icon: Icons.warning_amber_rounded,
      tone: PillTone.warning,
    ),
    GoalFunding.partly => StatusPill(g.funding.label, icon: Icons.timelapse),
  },
};

/// "₱3,000.00 of ₱12,000.00 · 25.0%".
String goalLine(GoalRow g, Amount amount) => [
  '${amount(g.reserved)} of ${amount(g.target)}',
  if (g.basisPoints != null) percentLabel(g.basisPoints!),
  if (g.excess > BigInt.zero) '${amount(g.excess)} above the target',
].join(' · ');

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goal,
    required this.amount,
    required this.hidden,
    required this.onOpen,
    required this.onSetAside,
  });
  final GoalRow goal;
  final Amount amount;
  final bool hidden;
  final VoidCallback onOpen, onSetAside;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final g = goal;
    final line = hidden ? null : goalLine(g, amount);
    final body = Semantics(
      container: true,
      onTap: onOpen,
      button: true,
      label: [
        g.goal.title,
        if (g.status == 'active') g.funding.label else g.status,
        ?line,
      ].join(', '),
      excludeSemantics: true,
      child: Pressable(
        key: ValueKey('goal-${g.id}'),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(g.goal.title, style: text.titleSmall),
                goalPill(g),
              ],
            ),
            if (line != null) ...[
              const SizedBox(height: Space.xs),
              SlimBar(fraction: (g.basisPoints ?? 0) / 10000),
              const SizedBox(height: Space.xs),
              Text(
                [
                  line,
                  if (g.targetDate != null) 'By ${civilLabel(g.targetDate!)}',
                ].join(' · '),
                style: text.bodySmall?.copyWith(color: c.secondary),
              ),
            ],
          ],
        ),
      ),
    );
    return Row(
      children: [
        Expanded(child: body),
        const SizedBox(width: Space.sm),
        CardLink(
          'Set aside',
          key: ValueKey('goal-aside-${g.id}'),
          onPressed: onSetAside,
        ),
      ],
    );
  }
}

/// The default forecast as a dashed line: an estimate, never money you have.
class ForecastFigures extends StatelessWidget {
  const ForecastFigures({
    super.key,
    required this.forecast,
    required this.amount,
    this.height = overviewChartHeight,
  });
  final FinanceForecast forecast;
  final Amount amount;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = forecast, low = lowestDay(f)!;
    final days = f.daily.entries.toList();
    final step = (days.length / 3).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OverviewLineChart(
          height: height,
          lines: [
            (
              values: [for (final d in days) d.value],
              color: CraftTheme.of(context).chartSeries.first,
              dashed: true,
              fill: false,
            ),
          ],
          label: (i) => i % step == 0 && i < days.length
              ? civilLabel(days[i].key).split(', ').last
              : null,
          tooltip: (_, i) =>
              '${civilLabel(days[i].key)}\n${amount(days[i].value)}',
          semanticsLabel:
              'Cash forecast for ${days.length} days, an estimate. From ${amount(f.opening)} today to ${amount(days.last.value)}. Lowest ${amount(low.$2)} on ${civilLabel(low.$1)}.',
        ),
        const SizedBox(height: Space.md),
        StatStrip(
          stats: [
            (label: 'Today', value: amount(f.opening), detail: null),
            (
              label: 'Lowest day',
              value: amount(low.$2),
              detail: civilLabel(low.$1),
            ),
            (
              label: 'Last day',
              value: amount(days.last.value),
              detail: civilLabel(days.last.key),
            ),
          ],
        ),
      ],
    );
  }
}

class ForecastCard extends StatelessWidget {
  const ForecastCard({
    super.key,
    required this.forecast,
    required this.today,
    required this.amount,
    required this.available,
    required this.hidden,
    required this.onOpen,
  });
  final FinanceForecast? forecast;
  final String today;
  final Amount amount;
  final bool available, hidden;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final f = forecast;
    final days = f?.daily.entries.toList() ?? const [];
    return OverviewCard(
      title: 'Cash forecast',
      caption: 'Estimate, not money you have',
      centered: true,
      trailing: CardLink(
        'Open forecast',
        key: const ValueKey('forecast-open'),
        onPressed: onOpen,
      ),
      child: !available
          ? const NotAvailable('The forecast shows once records are complete.')
          : hidden
          ? const AmountsHidden()
          : f == null || days.isEmpty
          ? const EmptyState(
              icon: Icons.insights_outlined,
              title: 'No forecast yet',
              message: 'Open the forecast to see what’s included.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ForecastFigures(forecast: f, amount: amount),
                // The first note is always there: what a forecast never has.
                if (f.exclusions.length > 1) ...[
                  const SizedBox(height: Space.sm),
                  Text(
                    '${f.exclusions.length - 1} expected ${f.exclusions.length == 2 ? 'item is' : 'items are'} left out. Open the forecast to see why.',
                    key: const ValueKey('forecast-left-out'),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: c.secondary),
                  ),
                ],
              ],
            ),
    );
  }
}
