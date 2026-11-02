import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import 'overview_data.dart';
import 'title_bar_tools.dart';

/// Overview cards (Chat 6). Each card shows values it is given; the
/// dashboard reads the sources and `overview_data.dart` derives the rest.

typedef Amount = String Function(BigInt value);

/// "Fri, 30 Oct"; any other text is shown as given.
String civilLabel(String date) {
  final day = DateTime.tryParse(date);
  return day == null ? date : TitleBarClock.date(day);
}

String _plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : many ?? '${one}s'}';

/// The pill for a due status, matching `DebtDueStatus`.
Widget duePill(DebtDueStatus status) => switch (status) {
  DebtDueStatus.overdue => const StatusPill.overdue(),
  DebtDueStatus.dueToday => const StatusPill.dueToday(),
  DebtDueStatus.dueSoon => const StatusPill.dueSoon(),
  DebtDueStatus.upcoming => const StatusPill.upcoming(),
  DebtDueStatus.scheduleNotSet => const StatusPill.scheduleNotSet(),
};

/// Reminder kinds in everyday words, with an icon.
(String, IconData) dueKind(String kind) => switch (kind) {
  'Debt due' => ('Debt', Icons.account_balance_outlined),
  'Card statement due' => ('Card statement', Icons.credit_card_outlined),
  'Card installment due' => ('Card installment', Icons.credit_score_outlined),
  _ => ('Recurring bill', Icons.autorenew),
};

/// A small muted label over a compact amount.
class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, {this.overdue = false});
  final String label;
  final String value;
  final bool overdue;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (overdue) ...[
              Icon(
                Icons.error_outline,
                size: Space.md + Space.xxs,
                color: c.overdue.$1,
              ),
              const SizedBox(width: Space.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: text.bodySmall?.copyWith(
                  color: overdue ? c.overdue.$1 : c.secondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xxs),
        MoneyAmount(value, size: MoneySize.tile, textAlign: TextAlign.start),
      ],
    );
  }
}

/// How the dues card lays out its items.
enum DuesView {
  calendar('Calendar'),
  list('List');

  const DuesView(this.label);
  final String label;
}

/// One unpaid due item as a list row.
Widget dueRow(
  DueItem item,
  Amount amount,
  ValueChanged<FinancialReminderSource> onOpen,
) {
  final (kind, icon) = dueKind(item.source.kind);
  return AdaptiveRow(
    key: ValueKey('due-${item.source.id}'),
    leading: icon,
    title: item.source.title,
    subtitle: detailLine([
      kind,
      civilLabel(item.date),
      if (item.days < 0) '${_plural(-item.days, 'day')} overdue',
    ]),
    trailing: MoneyAmount(amount(item.amount)),
    pill: duePill(item.status),
    onTap: () => onOpen(item.source),
  );
}

/// List view: the period heading with "as of", the totals, then every item
/// of the period in one table (a list of rows when narrow), with no limit,
/// for reading at a glance or a screenshot.
class DuesList extends StatelessWidget {
  const DuesList({
    super.key,
    required this.dues,
    required this.amount,
    required this.onOpen,
  });
  final OverviewDues dues;
  final Amount amount;
  final ValueChanged<FinancialReminderSource> onOpen;

  /// A card's statement usually includes its installments.
  bool get _overlap {
    final kinds = {
      for (final i in [...dues.overdue, ...dues.upcoming]) i.source.kind,
    };
    return kinds.contains('Card statement due') &&
        kinds.contains('Card installment due');
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '${dues.period.label} · ${overviewSpan(dues.start, dues.end)} · as of ${civilLabel(dues.today)}',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: CraftTheme.of(context).secondary),
      ),
      const SizedBox(height: Space.sm),
      DueFigures(dues: dues, amount: amount, list: true),
      if (_overlap) ...[
        const SizedBox(height: Space.sm),
        Text(
          'Card statement and installment amounts can overlap.',
          key: const ValueKey('dues-overlap'),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: CraftTheme.of(context).secondary),
        ),
      ],
      const SizedBox(height: Space.md),
      _table(context),
    ],
  );

  Widget _table(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final items = [...dues.overdue, ...dues.upcoming];
    final head = text.labelMedium?.copyWith(color: c.secondary);
    final amountWidth = moneyColumnWidth(context, [
      'Amount',
      for (final i in items) amount(i.amount),
    ]);
    final rowHeight = isDesktop(context)
        ? Space.compactTwoLineRow
        : Space.target + Space.sm;
    return LayoutBuilder(
      builder: (context, box) {
        if (narrowAt(context, box.maxWidth, tableBase)) {
          return ListGroup(
            key: const ValueKey('dues-list'),
            leading: true,
            children: [for (final i in items) dueRow(i, amount, onOpen)],
          );
        }
        Widget cells(List<Widget> children) => Row(
          children: [
            SizedBox(width: Space.xxxl * 2 + Space.lg, child: children[0]),
            Expanded(flex: 3, child: children[1]),
            const SizedBox(width: Space.md),
            Expanded(flex: 2, child: children[2]),
            const SizedBox(width: Space.md),
            Expanded(flex: 2, child: children[3]),
            const SizedBox(width: Space.md),
            SizedBox(
              width: amountWidth,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: children[4],
              ),
            ),
          ],
        );
        return Column(
          key: const ValueKey('dues-list'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.sm,
                  vertical: Space.xs,
                ),
                child: cells([
                  Text('Due date', style: head),
                  Text('Item', style: head),
                  Text('Type', style: head),
                  Text('Status', style: head),
                  Text('Amount', style: head),
                ]),
              ),
            ),
            Divider(height: 1, color: c.divider),
            for (final (n, i) in items.indexed) ...[
              if (n > 0) Divider(height: 1, color: c.divider),
              Semantics(
                container: true,
                onTap: () => onOpen(i.source),
                button: true,
                label: [
                  i.source.title,
                  dueKind(i.source.kind).$1,
                  civilLabel(i.date),
                  if (i.days < 0) '${_plural(-i.days, 'day')} overdue',
                  i.status.label,
                  amount(i.amount),
                ].join(', '),
                excludeSemantics: true,
                child: Pressable(
                  key: ValueKey('due-${i.source.id}'),
                  onTap: () => onOpen(i.source),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.sm,
                    vertical: Space.xs,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: rowHeight),
                    child: cells([
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(civilLabel(i.date), style: text.bodyMedium),
                          if (i.days < 0)
                            Text(
                              '${_plural(-i.days, 'day')} overdue',
                              style: text.bodySmall?.copyWith(
                                color: c.overdue.$1,
                              ),
                            ),
                        ],
                      ),
                      Text(i.source.title, style: text.bodyMedium),
                      Text(
                        dueKind(i.source.kind).$1,
                        style: text.bodySmall?.copyWith(color: c.secondary),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: duePill(i.status),
                      ),
                      MoneyAmount(amount(i.amount)),
                    ]),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The period's totals. The list view adds the total with what is overdue.
class DueFigures extends StatelessWidget {
  const DueFigures({
    super.key,
    required this.dues,
    required this.amount,
    this.list = false,
  });
  final OverviewDues dues;
  final Amount amount;
  final bool list;
  @override
  Widget build(BuildContext context) {
    final periodLabel = dues.period == DuePeriod.week ? 'week' : 'month';
    return Wrap(
      spacing: Space.xl,
      runSpacing: Space.md,
      children: [
        _Figure('Due this $periodLabel', amount(dues.upcomingTotal)),
        if (dues.overdue.isNotEmpty)
          _Figure('Overdue', amount(dues.overdueTotal), overdue: true),
        if (list && dues.overdue.isNotEmpty)
          _Figure('Total due', amount(dues.overdueTotal + dues.upcomingTotal)),
      ],
    );
  }
}

/// R1–R3: what is due this week or month, a calendar strip, and the overdue
/// rows pinned on top; or, in list view, every item in one table.
class DuesCard extends StatefulWidget {
  const DuesCard({
    super.key,
    required this.week,
    required this.month,
    required this.amount,
    required this.onOpen,
    this.available = true,
    this.shown = 6,
    this.caption = 'Debts, card statements and recurring bills',
    this.period,
    this.onPeriod,
    this.view,
    this.onView,
    this.menu = const [],
  });
  final OverviewDues week, month;
  final Amount amount;
  final ValueChanged<FinancialReminderSource> onOpen;
  final bool available;

  /// Rows shown in each group before "Show all".
  final int shown;
  final String caption;

  /// Set these to keep the period or layout outside the card, e.g. when the
  /// card's width depends on them; otherwise the card keeps its own.
  final DuePeriod? period;
  final ValueChanged<DuePeriod>? onPeriod;
  final DuesView? view;
  final ValueChanged<DuesView>? onView;

  /// More items for the corner menu, after the layouts.
  final List<Widget> menu;
  @override
  State<DuesCard> createState() => _DuesCardState();
}

class _DuesCardState extends State<DuesCard> {
  DuePeriod _period = DuePeriod.week;
  DuesView _view = DuesView.calendar;
  DuePeriod get period => widget.period ?? _period;
  DuesView get view => widget.view ?? _view;
  String? day;
  bool all = false;

  Widget row(DueItem item) => dueRow(item, widget.amount, widget.onOpen);

  Widget group(String label, List<DueItem> items, {bool overdue = false}) {
    final c = CraftTheme.of(context);
    final shownItems = all ? items : items.take(widget.shown).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ListRow.horizontalPadding,
            vertical: Space.xs,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: overdue ? c.overdue.$1 : c.secondary),
          ),
        ),
        ListGroup(
          leading: true,
          children: [for (final i in shownItems) row(i)],
        ),
        if (shownItems.length < items.length)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: CardLink(
              'Show all ${items.length}',
              onPressed: () => setState(() => all = true),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dues = period == DuePeriod.week ? widget.week : widget.month;
    final list = view == DuesView.list;
    final overdue = day == null || list
        ? dues.overdue
        : dues.overdue.where((i) => i.date == day).toList();
    final upcoming = day == null || list
        ? dues.upcoming
        : dues.upcoming.where((i) => i.date == day).toList();
    final periodLabel = period == DuePeriod.week ? 'week' : 'month';
    return OverviewCard(
      title: 'Due and overdue',
      caption: widget.caption,
      stackBelow: periodBase + rowBase + Space.xxxl,
      trailing: MiniSegmented<DuePeriod>(
        key: const ValueKey('dues-period'),
        label: 'Period',
        options: [for (final p in DuePeriod.values) (p, p.label)],
        selected: period,
        onSelected: (p) {
          widget.onPeriod?.call(p);
          setState(() {
            _period = p;
            day = null;
            all = false;
          });
        },
      ),
      // How the card lays out its items, from a menu in the corner.
      corner: MenuAnchor(
        alignmentOffset: const Offset(0, Space.xs),
        menuChildren: [
          for (final (v, icon) in [
            (DuesView.calendar, Icons.calendar_month_outlined),
            (DuesView.list, Icons.view_list_outlined),
          ])
            MenuItemButton(
              key: ValueKey(v),
              leadingIcon: Icon(icon),
              trailingIcon: v == view ? const Icon(Icons.check) : null,
              onPressed: () {
                widget.onView?.call(v);
                setState(() {
                  _view = v;
                  day = null;
                  all = false;
                });
              },
              child: Text(v.label),
            ),
          ...widget.menu,
        ],
        builder: (context, controller, _) => AppIconButton(
          key: const ValueKey('dues-view'),
          icon: Icons.settings_outlined,
          tooltip: 'Layout: ${view.label}',
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
      child: !widget.available
          ? const NotAvailable(
              'Dues show once your first download is complete.',
            )
          : dues.isEmpty
          ? EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nothing due this $periodLabel',
              message: 'Debts, card statements and recurring bills you track show here when they are due.',
            )
          : list
          ? DuesList(dues: dues, amount: widget.amount, onOpen: widget.onOpen)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DueFigures(dues: dues, amount: widget.amount),
                const SizedBox(height: Space.md),
                DueCalendar(
                  dues: dues,
                  selected: day,
                  onSelected: (d) => setState(() {
                    day = day == d ? null : d;
                    all = false;
                  }),
                ),
                const SizedBox(height: Space.sm),
                if (day != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: CardLink(
                      'Show the whole $periodLabel',
                      icon: Icons.close,
                      onPressed: () => setState(() => day = null),
                    ),
                  ),
                if (overdue.isNotEmpty)
                  group('Overdue', overdue, overdue: true),
                if (overdue.isNotEmpty && upcoming.isNotEmpty)
                  const SizedBox(height: Space.sm),
                if (upcoming.isNotEmpty)
                  group(
                    day == null ? 'Due this $periodLabel' : civilLabel(day!),
                    upcoming,
                  ),
                if (overdue.isEmpty && upcoming.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: Text(
                      'Nothing due on ${civilLabel(day!)}.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: CraftTheme.of(context).secondary),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// The period's days as a `MonthGrid`, each with its dues. Tapping a day
/// filters the rows.
class DueCalendar extends StatelessWidget {
  const DueCalendar({
    super.key,
    required this.dues,
    required this.selected,
    required this.onSelected,
  });
  final OverviewDues dues;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => MonthGrid(
    days: [
      for (final (date, items) in dues.days)
        (
          date: date,
          count: items.length,
          late: items.any((i) => i.days < 0),
        ),
    ],
    today: dues.today,
    selected: selected,
    onSelected: onSelected,
    strip: dues.period == DuePeriod.week,
    spoken: (day) => [
      civilLabel(day.date),
      if (day.date == dues.today) 'today',
      day.count == 0
          ? 'nothing due'
          : day.late
          ? '${_plural(day.count, 'item')}, overdue'
          : '${_plural(day.count, 'item')} due',
    ].join(', '),
  );
}

/// R4: payoff progress per debt, by its payment schedule, most urgent first:
/// one bar segment per scheduled payment. Wide cards lay each debt out as a
/// table row.
class DebtProgressCard extends StatelessWidget {
  const DebtProgressCard({
    super.key,
    required this.debts,
    required this.amount,
    required this.onOpen,
    this.available = true,
    this.hidden = false,
  });
  final List<DebtProgress> debts;
  final Amount amount;
  final VoidCallback onOpen;
  final bool available, hidden;

  static const shown = 6;

  static Widget pill(DebtProgress d) => d.closed
      ? const StatusPill(
          'Closed',
          icon: Icons.check_circle_outline,
          tone: PillTone.success,
        )
      : d.settled
      ? const StatusPill.settled()
      : d.scheduleFinished
      ? const StatusPill(
          'Schedule finished',
          icon: Icons.event_available_outlined,
          tone: PillTone.warning,
        )
      : duePill(d.due.status!);

  /// The line under the bar. With amounts hidden it keeps to the count.
  static String progressLine(
    DebtProgress d,
    Amount amount, {
    bool hidden = false,
  }) => d.closed
      ? 'Closed with a payoff'
      : d.settled
      ? d.scheduled
            ? 'All ${_plural(d.total, 'payment')} logged'
            : 'Nothing left to pay'
      : d.scheduleFinished
      ? hidden
            ? 'All ${_plural(d.total, 'payment')} logged'
            : 'All ${_plural(d.total, 'payment')} logged · ${amount(d.outstanding)} still owed'
      : !d.scheduled
      ? 'No payment schedule yet'
      : hidden
      ? '${d.done} of ${_plural(d.total, 'payment')} logged'
      : '${d.done} of ${_plural(d.total, 'payment')} logged · ${amount(d.scheduledLeft)} of ${amount(d.scheduledTotal)} left';

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    Widget bar(DebtProgress d) => d.fraction == null
        ? const SizedBox.shrink()
        : SegmentBar(
            done: d.finished ? d.total : d.done,
            total: d.total,
            fraction: d.fraction,
          );
    Widget line(DebtProgress d) => Text(
      progressLine(d, amount, hidden: hidden),
      style: text.bodySmall?.copyWith(color: c.secondary),
    );
    Widget owed(DebtProgress d) =>
        MoneyAmount(amount(d.outstanding), kind: MoneyKind.owed);
    // One width for every row's amount, so the columns line up.
    final amountWidth = moneyColumnWidth(context, [
      for (final d in debts.take(shown)) amount(d.outstanding),
    ]);
    Widget item(DebtProgress d, bool table) => Semantics(
      label:
          'Payoff progress for ${d.debt.title}: ${progressLine(d, amount, hidden: hidden)}',
      child: Pressable(
        key: ValueKey('debt-progress-${d.debt.actionId}'),
        onTap: onOpen,
        padding: const EdgeInsets.symmetric(
          horizontal: ListRow.horizontalPadding,
          vertical: Space.md,
        ),
        child: table
            ? Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.debt.title, style: text.titleSmall),
                        const SizedBox(height: Space.xs),
                        pill(d),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        bar(d),
                        const SizedBox(height: Space.xs + Space.xxs),
                        line(d),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.lg),
                  SizedBox(
                    width: amountWidth,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: owed(d),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LabelAmount(
                    label: Text(d.debt.title, style: text.titleSmall),
                    amount: owed(d),
                  ),
                  const SizedBox(height: Space.xs),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: pill(d),
                  ),
                  if (d.fraction != null) ...[
                    const SizedBox(height: Space.sm),
                    bar(d),
                  ],
                  const SizedBox(height: Space.xs),
                  line(d),
                ],
              ),
      ),
    );
    return OverviewCard(
      title: 'Debt payoff',
      caption: 'Progress by payment schedule · one bar step per payment',
      trailing: debts.isEmpty
          ? null
          : CardLink('View debts', onPressed: onOpen),
      child: !available
          ? const NotAvailable(
              'Debts show once your first download is complete.',
            )
          : debts.isEmpty
          ? EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No debts yet',
              message: 'Debts you add show their payments and progress here.',
              action: AppButton.secondary('Open Debts', onPressed: onOpen),
            )
          : LayoutBuilder(
              builder: (context, box) {
                final table = !narrowAt(context, box.maxWidth, tableBase);
                return ListGroup(
                  children: [for (final d in debts.take(shown)) item(d, table)],
                );
              },
            ),
    );
  }
}

/// O12: a few plain sentences about what stands out.
class InsightsCard extends StatelessWidget {
  const InsightsCard({super.key, required this.insights});
  final List<String> insights;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return OverviewCard(
      title: 'At a glance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, line) in insights.indexed) ...[
            if (i > 0) const SizedBox(height: Space.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: Space.xxs),
                  child: Icon(
                    Icons.auto_awesome_outlined,
                    size: Space.lg,
                    color: c.primary,
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(line, style: text.bodyMedium)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// O3: this month's spending by category as a donut, with a legend of each
/// category's share and amount. Shares are of the positive spending total.
/// Hovering or tapping a section or legend row shows that category's name,
/// share and amount in the donut's hole and highlights its row.
class CategoryCard extends StatefulWidget {
  const CategoryCard({
    super.key,
    required this.categories,
    required this.amount,
    required this.caption,
    this.onOpen,
    this.available = true,
    this.hidden = false,
    this.title = 'Spending by category',
    this.emptyTitle = 'No spending this month',
    this.emptyMessage = 'Expenses you log this month show here by category.',
    this.unavailable,
  });
  final List<(String, BigInt)> categories;
  final Amount amount;
  final String caption, title, emptyTitle, emptyMessage;
  final VoidCallback? onOpen;
  final bool available, hidden;

  /// Replaces the chart, saying why it can't be drawn.
  final Widget? unavailable;

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  int? selected;

  void select(int? index) {
    if (index != selected) setState(() => selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final amount = widget.amount;
    final shares = categoryShares(widget.categories);
    final total = sumMinor(shares.map((s) => s.$2));
    final colors = [
      ...c.chartSeries.take(shares.length > 5 ? 5 : shares.length),
      if (shares.length > 5) c.chartSeries.last,
    ];
    // A selection from earlier data that no longer exists shows nothing.
    final current = selected != null && selected! < shares.length
        ? selected
        : null;
    String share(int i) {
      final bp = shareBasisPoints(shares[i].$2, total);
      return bp == null ? '' : percentLabel(bp);
    }

    // One width for every row, so the shares line up whatever each amount's
    // length.
    final moneyWidth = moneyColumnWidth(context, [
      for (final s in shares) amount(s.$2),
    ]);

    Widget legendRow(int i) {
      final (name, value) = shares[i];
      final swatch = ExcludeSemantics(
        child: Container(
          width: Space.sm + Space.xxs,
          height: Space.sm + Space.xxs,
          decoration: BoxDecoration(
            color: colors[i],
            borderRadius: BorderRadius.circular(Space.xxs),
          ),
        ),
      );
      final title = Text(
        name,
        style: i == current
            ? text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
            : text.bodyMedium,
      );
      final percent = Text(
        share(i),
        style: text.bodySmall?.copyWith(
          color: c.secondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
      final money = MoneyAmount(amount(value));
      // Wide: name, share and amount on one line. Narrower: the share over
      // the amount, with the swatch and name centered beside them. Only a
      // very narrow legend puts the amount on a line of its own.
      final row = LayoutBuilder(
        builder: (context, box) {
          if (narrowAt(context, box.maxWidth, Space.xxxl * 4)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    swatch,
                    const SizedBox(width: Space.sm),
                    Expanded(child: title),
                    percent,
                  ],
                ),
                Align(alignment: AlignmentDirectional.centerEnd, child: money),
              ],
            );
          }
          final wide = !narrowAt(context, box.maxWidth);
          return Row(
            children: [
              swatch,
              const SizedBox(width: Space.sm),
              Expanded(child: title),
              const SizedBox(width: Space.md),
              if (wide) ...[
                percent,
                const SizedBox(width: Space.md),
                SizedBox(
                  width: moneyWidth,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: money,
                  ),
                ),
              ] else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [percent, money],
                ),
            ],
          );
        },
      );
      return MouseRegion(
        onEnter: (_) => select(i),
        onExit: (_) => select(null),
        child: Semantics(
          button: true,
          selected: i == current,
          child: Pressable(
            key: ValueKey('category-$i'),
            onTap: () => select(i),
            color: i == current ? c.selection : null,
            hoverColor: c.selection,
            padding: const EdgeInsets.symmetric(
              horizontal: Space.xs,
              vertical: Space.xxs,
            ),
            child: row,
          ),
        ),
      );
    }

    final center = current == null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Top category',
                style: text.bodySmall?.copyWith(color: c.secondary),
              ),
              Text(
                shares.isEmpty ? '' : shares.first.$1,
                textAlign: TextAlign.center,
                style: text.titleSmall,
              ),
            ],
          )
        : Column(
            key: const ValueKey('category-selected'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                shares[current].$1,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: c.secondary),
              ),
              Text(
                share(current),
                style: text.headlineSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                amount(shares[current].$2),
                style: text.bodySmall?.copyWith(
                  color: c.secondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          );

    final open = widget.onOpen;
    return OverviewCard(
      title: widget.title,
      centered: true,
      caption: widget.caption,
      trailing: open == null ? null : CardLink('View report', onPressed: open),
      child: !widget.available
          ? const NotAvailable('Spending shows once your records are complete.')
          : widget.unavailable != null
          ? widget.unavailable!
          : widget.hidden
          ? const AmountsHidden()
          : shares.isEmpty
          ? EmptyState(
              icon: Icons.pie_chart_outline,
              title: widget.emptyTitle,
              message: widget.emptyMessage,
            )
          : LayoutBuilder(
              builder: (context, box) {
                final donut = OverviewDonut(
                  values: [for (final s in shares) s.$2],
                  colors: colors,
                  selected: current,
                  onSelected: select,
                  semanticsLabel:
                      'Spending by category: ${[for (final s in shares) '${s.$1} ${amount(s.$2)}'].join(', ')}.',
                  center: center,
                );
                final legend = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < shares.length; i++) ...[
                      if (i > 0) const SizedBox(height: Space.xxs),
                      legendRow(i),
                    ],
                  ],
                );
                return narrowAt(context, box.maxWidth, tableBase - Space.xxxl)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: donut),
                          const SizedBox(height: Space.lg),
                          legend,
                        ],
                      )
                    : Row(
                        children: [
                          donut,
                          const SizedBox(width: Space.xl),
                          Expanded(child: legend),
                        ],
                      );
              },
            ),
    );
  }
}

/// How the spending hero card draws the month.
enum SpendingView {
  daily('Daily'),
  running('Running');

  const SpendingView(this.label);
  final String label;
}

/// O4 + O5: this month's spending as the wide hero chart. "Daily" shows a
/// bar per day; "Running" shows the running total against the same days of
/// last month.
class SpendingCard extends StatefulWidget {
  const SpendingCard({
    super.key,
    required this.daily,
    required this.comparison,
    required this.amount,
    required this.caption,
    required this.range,
    this.top,
    this.available = true,
    this.hidden = false,
  });
  final List<(String, BigInt)> daily;
  final SpendingComparison? comparison;

  /// The largest spending category this month, when there is one.
  final (String, BigInt)? top;
  final Amount amount;
  final String caption, range;
  final bool available, hidden;
  @override
  State<SpendingCard> createState() => _SpendingCardState();
}

class _SpendingCardState extends State<SpendingCard> {
  SpendingView view = SpendingView.daily;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final amount = widget.amount, daily = widget.daily;
    final comparison = widget.comparison;
    final total = sumMinor(daily.map((d) => d.$2));
    final empty =
        daily.every((d) => d.$2 == BigInt.zero) &&
        (comparison == null || comparison.previousTotal == BigInt.zero);
    String? dayLabel(int i) => (i % 7 == 0) ? '${i + 1}' : null;
    final peak = daily.isEmpty
        ? null
        : daily.reduce((a, b) => b.$2 > a.$2 ? b : a);
    final current = c.chartSeries.first, previous = c.chartSeries.last;
    Widget chart() => switch (view) {
      SpendingView.daily => OverviewBarChart(
        height: heroChartHeight,
        values: [for (final d in daily) d.$2],
        label: dayLabel,
        tooltip: (i) => '${civilLabel(daily[i].$1)}\n${amount(daily[i].$2)}',
        semanticsLabel:
            'Daily spending, ${widget.range}. Highest on ${peak == null ? '' : civilLabel(peak.$1)}: ${peak == null ? '' : amount(peak.$2)}.',
      ),
      SpendingView.running => OverviewLineChart(
        height: heroChartHeight,
        lines: [
          (
            values: SpendingComparison.running(comparison!.current),
            color: current,
            dashed: false,
            fill: true,
          ),
          (
            values: SpendingComparison.running(comparison.previous),
            color: previous,
            dashed: true,
            fill: false,
          ),
        ],
        label: dayLabel,
        tooltip: (line, i) {
          final days = line == 0 ? comparison.current : comparison.previous;
          final running = SpendingComparison.running(days)[i];
          return '${line == 0 ? 'This month' : 'Last month'}, day ${i + 1}\n${amount(running)}';
        },
        semanticsLabel:
            'Spending so far this month ${amount(comparison.currentTotal)}; by the same day last month ${amount(comparison.previousTotal)}.',
      ),
    };
    return OverviewCard(
      title: 'Spending this month',
      caption: widget.caption,
      stackBelow: periodBase + rowBase,
      trailing: comparison == null
          ? null
          : MiniSegmented<SpendingView>(
              key: const ValueKey('spending-view'),
              label: 'Chart',
              options: [for (final v in SpendingView.values) (v, v.label)],
              selected: view,
              onSelected: (v) => setState(() => view = v),
            ),
      child: !widget.available
          ? const NotAvailable('Charts show once your records are complete.')
          : widget.hidden
          ? const AmountsHidden()
          : empty
          ? const EmptyState(
              icon: Icons.bar_chart,
              title: 'No spending this month',
              message: 'Spending shows here as you log expenses.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Space.md,
                  runSpacing: Space.xs,
                  children: [
                    MoneyAmount(
                      amount(total),
                      size: MoneySize.tile,
                      textAlign: TextAlign.start,
                    ),
                    if (comparison != null)
                      ChangeLine(
                        basisPoints: changeBasisPoints(
                          comparison.currentTotal,
                          comparison.previousTotal,
                        ),
                        versus:
                            'vs ${overviewSpan(comparison.previousStart, comparison.previousEnd)}',
                        meaning: ChangeMeaning.riseIsBad,
                      ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                chart(),
                const SizedBox(height: Space.sm),
                if (view == SpendingView.running)
                  ChartLegend(
                    entries: [
                      (label: 'This month', color: current, dashed: false),
                      (label: 'Last month', color: previous, dashed: true),
                    ],
                  ),
                const SizedBox(height: Space.md),
                StatStrip(
                  key: const ValueKey('spending-stats'),
                  stats: [
                    if (peak != null)
                      (
                        label: 'Highest day',
                        value: amount(peak.$2),
                        detail: peak.$2 == BigInt.zero
                            ? null
                            : civilLabel(peak.$1),
                      ),
                    (
                      label: 'Days with spending',
                      value:
                          '${daily.where((d) => d.$2 > BigInt.zero).length} of ${daily.length}',
                      detail: null,
                    ),
                    if (widget.top case final top?)
                      (
                        label: 'Top category',
                        value: top.$1,
                        detail: amount(top.$2),
                      ),
                    if (comparison != null)
                      (
                        label: 'Last month by now',
                        value: amount(comparison.previousTotal),
                        detail: 'By ${civilLabel(comparison.previousEnd)}',
                      ),
                  ],
                ),
                // Room between the figures above and the disclosure.
                const SizedBox(height: Space.lg),
                ChartValues(
                  rows: [
                    for (final d in daily)
                      if (d.$2 != BigInt.zero) (civilLabel(d.$1), amount(d.$2)),
                  ],
                ),
              ],
            ),
    );
  }
}

/// O6: what you owe at each month end, then today, with the figures that
/// matter most beside it and what each debt holds of the total.
class OwedCard extends StatelessWidget {
  const OwedCard({
    super.key,
    required this.owed,
    required this.debts,
    required this.amount,
    required this.monthLabel,
    this.available = true,
    this.hidden = false,
  });

  /// Month ends, then today (`debtBalanceByMonth`).
  final List<(String, BigInt)> owed;

  /// Each debt with what you owe on it today (the Debts screen's records).
  final List<DebtProgress> debts;
  final Amount amount;

  /// "Sep", or "Today" for today.
  final String Function(String date) monthLabel;
  final bool available, hidden;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final color = c.chartSeries[1];
    final now = owed.last.$2, before = owed[owed.length - 2];
    final change = now - before.$2;
    final peak = owed.reduce((a, b) => b.$2 > a.$2 ? b : a);
    final byDebt = debts.where((d) => d.outstanding > BigInt.zero).toList()
      ..sort((a, b) => b.outstanding.compareTo(a.outstanding));
    final total = sumMinor(byDebt.map((d) => d.outstanding));
    return OverviewCard(
      title: 'What you owe over time',
      caption: 'At each month end, then today',
      child: !available
          ? const NotAvailable('Charts show once your records are complete.')
          : hidden
          ? const AmountsHidden()
          : owed.every((p) => p.$2 == BigInt.zero)
          ? const EmptyState(
              icon: Icons.show_chart,
              title: 'No debts to chart',
              message: 'What you owe at each month end shows here once you add a debt.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OverviewLineChart(
                  lines: [
                    (
                      values: [for (final p in owed) p.$2],
                      color: color,
                      dashed: false,
                      fill: true,
                    ),
                  ],
                  label: (i) => i < owed.length ? monthLabel(owed[i].$1) : null,
                  tooltip: (_, i) =>
                      '${civilLabel(owed[i].$1)}\n${amount(owed[i].$2)}',
                  semanticsLabel:
                      'What you owe: ${[for (final p in owed) '${monthLabel(p.$1)} ${amount(p.$2)}'].join(', ')}.',
                ),
                const SizedBox(height: Space.md),
                StatStrip(
                  key: const ValueKey('owed-stats'),
                  stats: [
                    (label: 'Today', value: amount(now), detail: null),
                    (
                      label: 'Since end of ${monthLabel(before.$1)}',
                      value: amount(change.abs()),
                      detail: change < BigInt.zero
                          ? 'Paid down'
                          : change > BigInt.zero
                          ? 'Added'
                          : 'No change',
                    ),
                    (
                      label: 'Highest',
                      value: amount(peak.$2),
                      detail: monthLabel(peak.$1),
                    ),
                  ],
                ),
                if (byDebt.isNotEmpty) ...[
                  const SizedBox(height: Space.lg),
                  Text(
                    'By debt',
                    style: text.labelMedium?.copyWith(color: c.secondary),
                  ),
                  const SizedBox(height: Space.sm),
                  for (final (i, d) in byDebt.indexed) ...[
                    if (i > 0) const SizedBox(height: Space.md),
                    LabelAmount(
                      label: Text(d.debt.title, style: text.bodyMedium),
                      amount: MoneyAmount(
                        amount(d.outstanding),
                        kind: MoneyKind.owed,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    SlimBar(
                      fraction:
                          (shareBasisPoints(d.outstanding, total) ?? 0) / 10000,
                      color: color,
                    ),
                  ],
                ],
                // Room between the figures above and the disclosure.
                const SizedBox(height: Space.lg),
                ChartValues(
                  rows: [
                    for (final p in owed) (civilLabel(p.$1), amount(p.$2)),
                  ],
                ),
              ],
            ),
    );
  }
}

/// "1–30 Sep", or "28 Sep – 4 Oct" across months.
String overviewSpan(String from, String to) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final a = DateTime.parse(from), b = DateTime.parse(to);
  return a.month == b.month && a.year == b.year
      ? '${a.day}–${b.day} ${months[b.month - 1]}'
      : '${a.day} ${months[a.month - 1]} – ${b.day} ${months[b.month - 1]}';
}

/// One row of a plain list card: the leading icon, title, optional subtitle,
/// an optional trailing amount, and where it goes.
typedef OverviewRow = ({
  IconData icon,
  String title,
  String? subtitle,
  String? amount,
  VoidCallback onTap,
});

/// O7, O9, O10: a titled card of rows with an optional small action and an
/// empty state.
class RowsCard extends StatelessWidget {
  const RowsCard({
    super.key,
    required this.title,
    required this.rows,
    required this.empty,
    this.caption,
    this.action,
    this.footer,
  });
  final String title;
  final String? caption;
  final List<OverviewRow> rows;
  final Widget empty;
  final Widget? action, footer;
  @override
  Widget build(BuildContext context) => OverviewCard(
    title: title,
    caption: caption,
    trailing: rows.isEmpty ? null : action,
    child: rows.isEmpty
        ? empty
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListGroup(
                leading: true,
                children: [
                  for (final r in rows)
                    AdaptiveRow(
                      leading: r.icon,
                      title: r.title,
                      subtitle: r.subtitle,
                      trailing: r.amount == null ? null : MoneyAmount(r.amount),
                      onTap: r.onTap,
                    ),
                ],
              ),
              ?footer,
            ],
          ),
  );
}

/// One activity row: what, when, its category and its amount.
typedef ActivityRow = ({
  IconData icon,
  String title,
  String date,
  String category,
  String? amount,
  VoidCallback onTap,
});

/// O11 and the largest expenses: a table with Date, Description, Category
/// and Amount columns when wide, a list of rows when narrow.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.title,
    required this.rows,
    required this.empty,
    this.caption,
    this.action,
    this.footer,
  });
  final String title;
  final String? caption;
  final List<ActivityRow> rows;
  final Widget empty;
  final Widget? action, footer;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final head = text.labelMedium?.copyWith(color: c.secondary);
    final rowHeight = isDesktop(context)
        ? Space.compactTwoLineRow
        : Space.target + Space.sm;
    // One width for every row's amount, so the columns line up.
    final amountWidth = moneyColumnWidth(context, [
      'Amount',
      for (final r in rows) r.amount,
    ]);
    Widget tableRow(ActivityRow r) => Semantics(
      container: true,
      onTap: r.onTap,
      button: true,
      label:
          '${r.title}, ${civilLabel(r.date)}, ${r.category}, ${r.amount ?? MoneyAmount.unknown}',
      excludeSemantics: true,
      child: Pressable(
        onTap: r.onTap,
        padding: const EdgeInsets.symmetric(horizontal: Space.sm),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: rowHeight),
          child: Row(
            children: [
              SizedBox(
                width: Space.xxxl * 2,
                child: Text(
                  civilLabel(r.date),
                  style: text.bodySmall?.copyWith(color: c.secondary),
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Icon(r.icon, size: Space.lg, color: c.secondary),
                    const SizedBox(width: Space.sm),
                    Expanded(child: Text(r.title, style: text.bodyMedium)),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                flex: 2,
                child: Text(
                  r.category,
                  style: text.bodySmall?.copyWith(color: c.secondary),
                ),
              ),
              const SizedBox(width: Space.md),
              SizedBox(
                width: amountWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: MoneyAmount(r.amount),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return OverviewCard(
      title: title,
      caption: caption,
      trailing: rows.isEmpty ? null : action,
      child: rows.isEmpty
          ? empty
          : LayoutBuilder(
              builder: (context, box) {
                if (narrowAt(context, box.maxWidth, tableBase)) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListGroup(
                        leading: true,
                        children: [
                          for (final r in rows)
                            AdaptiveRow(
                              leading: r.icon,
                              title: r.title,
                              subtitle: '${civilLabel(r.date)} · ${r.category}',
                              trailing: MoneyAmount(r.amount),
                              onTap: r.onTap,
                            ),
                        ],
                      ),
                      ?footer,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.sm,
                          vertical: Space.xs,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: Space.xxxl * 2,
                              child: Text('Date', style: head),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('Description', style: head),
                            ),
                            const SizedBox(width: Space.md),
                            Expanded(
                              flex: 2,
                              child: Text('Category', style: head),
                            ),
                            const SizedBox(width: Space.md),
                            SizedBox(
                              width: amountWidth,
                              child: Text(
                                'Amount',
                                textAlign: TextAlign.end,
                                style: head,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: c.divider),
                    for (final (i, r) in rows.indexed) ...[
                      if (i > 0) Divider(height: 1, color: c.divider),
                      tableRow(r),
                    ],
                    ?footer,
                  ],
                );
              },
            ),
    );
  }
}
