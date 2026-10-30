import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import 'overview_charts.dart';
import 'overview_controls.dart';
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

/// True when [width] can't hold text and a trailing item side by side at
/// the current text size; [base] is the width needed at 100%.
bool narrowAt(BuildContext context, double width, [double base = rowBase]) =>
    width < base * MediaQuery.textScalerOf(context).scale(1);

/// Widths, at 100% text, below which trailing items move under the text,
/// a card's header control moves above its content, and a table or a
/// side-by-side card layout turns into a list.
const rowBase = Space.xxxl * 7,
    periodBase = Space.xxxl * 6 + Space.lg,
    tableBase = Space.xxxl * 11;

/// A `ListRow` whose trailing item moves under the text when the row is
/// narrow, so amounts are never cut (§4).
class AdaptiveRow extends StatelessWidget {
  const AdaptiveRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });
  final String title;
  final String? subtitle;
  final IconData? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => ListRow(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      stackTrailing: narrowAt(context, box.maxWidth),
    ),
  );
}

/// A dashboard card: a compact `titleSmall` header with an optional caption
/// and a small trailing control, which moves above the content when the card
/// is narrower than [stackBelow] at the current text size. [corner] (an icon
/// button) always stays at the header's end.
class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.title,
    required this.child,
    this.caption,
    this.trailing,
    this.corner,
    this.stackBelow = rowBase,
    this.accent = false,
    this.centered = false,
  });
  final String title;
  final String? caption;
  final Widget? trailing, corner;
  final Widget child;
  final double stackBelow;
  final bool accent;

  /// When the grid row makes the card taller than its content, center the
  /// content in the space under the header instead of leaving a gap below.
  final bool centered;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: text.titleSmall)),
        if (caption != null) ...[
          const SizedBox(height: Space.xxs),
          Text(caption!, style: text.bodySmall?.copyWith(color: c.secondary)),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        final stack =
            trailing != null && narrowAt(context, box.maxWidth, stackBelow);
        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: heading),
                if (trailing != null && !stack) ...[
                  const SizedBox(width: Space.sm),
                  trailing!,
                ],
                if (corner != null) ...[
                  const SizedBox(width: Space.xs),
                  corner!,
                ],
              ],
            ),
            if (stack) ...[
              const SizedBox(height: Space.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: trailing,
              ),
            ],
            const SizedBox(height: Space.md),
          ],
        );
        // The row's height reaches the card as a minimum; pass it on, less
        // the card's padding and hairline, so the column can use the space.
        final inset =
            EdgeInsets.all(Space.cardPaddingOf(context)).vertical +
            Border.all(color: c.divider).dimensions.vertical;
        final minimum = centered && box.minHeight > inset
            ? box.minHeight - inset
            : 0.0;
        return SurfaceCard(
          accent: accent,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minimum),
            // Header at the top, content centered in the rest: spaceBetween
            // with an empty last child puts equal space above and below it.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: centered
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.start,
              children: [header, child, if (centered) const SizedBox.shrink()],
            ),
          ),
        );
      },
    );
  }
}

/// A label with its amount at the end, or the amount under it when narrow.
class LabelAmount extends StatelessWidget {
  const LabelAmount({super.key, required this.label, required this.amount});
  final Widget label, amount;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => narrowAt(context, box.maxWidth)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label,
              Align(alignment: AlignmentDirectional.centerEnd, child: amount),
            ],
          )
        : Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: Space.md),
              amount,
            ],
          ),
  );
}

/// What a card shows when its source isn't complete yet.
class NotAvailable extends StatelessWidget {
  const NotAvailable(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.hourglass_empty,
    title: MoneyAmount.unknown,
    message: message,
  );
}

/// Shown instead of a chart while amounts are hidden.
class AmountsHidden extends StatelessWidget {
  const AmountsHidden({super.key});
  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.visibility_off_outlined,
    title: 'Amounts hidden',
    message: 'Show amounts to see this chart.',
  );
}

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
  });
  final OverviewDues week, month;
  final Amount amount;
  final ValueChanged<FinancialReminderSource> onOpen;
  final bool available;

  /// Rows shown in each group before "Show all".
  final int shown;
  @override
  State<DuesCard> createState() => _DuesCardState();
}

class _DuesCardState extends State<DuesCard> {
  DuePeriod period = DuePeriod.week;
  DuesView view = DuesView.calendar;
  String? day;
  bool all = false;

  Widget row(DueItem item) {
    final (kind, icon) = dueKind(item.source.kind);
    return AdaptiveRow(
      key: ValueKey('due-${item.source.id}'),
      leading: icon,
      title: item.source.title,
      subtitle: [
        kind,
        civilLabel(item.date),
        if (item.days < 0) '${_plural(-item.days, 'day')} overdue',
      ].join(' · '),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyAmount(widget.amount(item.amount)),
          const SizedBox(height: Space.captionGap),
          duePill(item.status),
        ],
      ),
      onTap: () => widget.onOpen(item.source),
    );
  }

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

  /// List view: every item of the period in one table (a list of rows when
  /// narrow), with no limit, for reading at a glance or a screenshot.
  Widget table(OverviewDues dues) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final items = [...dues.overdue, ...dues.upcoming];
    final head = text.labelMedium?.copyWith(color: c.secondary);
    final amountWidth = moneyColumnWidth(context, [
      'Amount',
      for (final i in items) widget.amount(i.amount),
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
            children: [for (final i in items) row(i)],
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
                button: true,
                label: [
                  i.source.title,
                  dueKind(i.source.kind).$1,
                  civilLabel(i.date),
                  if (i.days < 0) '${_plural(-i.days, 'day')} overdue',
                  i.status.label,
                  widget.amount(i.amount),
                ].join(', '),
                excludeSemantics: true,
                child: Pressable(
                  key: ValueKey('due-${i.source.id}'),
                  onTap: () => widget.onOpen(i.source),
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
                      MoneyAmount(widget.amount(i.amount)),
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
    final secondary = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: CraftTheme.of(context).secondary);
    return OverviewCard(
      title: 'Due and overdue',
      caption: 'Debts, card statements and recurring bills',
      stackBelow: periodBase + rowBase + Space.xxxl,
      trailing: MiniSegmented<DuePeriod>(
        key: const ValueKey('dues-period'),
        label: 'Period',
        options: [for (final p in DuePeriod.values) (p, p.label)],
        selected: period,
        onSelected: (p) => setState(() {
          period = p;
          day = null;
          all = false;
        }),
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
              onPressed: () => setState(() {
                view = v;
                day = null;
                all = false;
              }),
              child: Text(v.label),
            ),
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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (list) ...[
                  Text(
                    '${period.label} · ${overviewSpan(dues.start, dues.end)} · as of ${civilLabel(dues.today)}',
                    style: secondary,
                  ),
                  const SizedBox(height: Space.sm),
                ],
                Wrap(
                  spacing: Space.xl,
                  runSpacing: Space.md,
                  children: [
                    _Figure(
                      'Due this $periodLabel',
                      widget.amount(dues.upcomingTotal),
                    ),
                    if (dues.overdue.isNotEmpty)
                      _Figure(
                        'Overdue',
                        widget.amount(dues.overdueTotal),
                        overdue: true,
                      ),
                    if (list && dues.overdue.isNotEmpty)
                      _Figure(
                        'Total due',
                        widget.amount(dues.overdueTotal + dues.upcomingTotal),
                      ),
                  ],
                ),
                const SizedBox(height: Space.md),
                if (list)
                  table(dues)
                else ...[
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
              ],
            ),
    );
  }
}

/// The period's days: a week strip, or a month grid. A dot marks a day with
/// something due and an icon marks one with something overdue, so the two
/// differ by shape as well as color. Tapping a day filters the rows.
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

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final days = dues.days;
    final week = dues.period == DuePeriod.week;
    final height = isDesktop(context)
        ? Space.compactTwoLineRow
        : Space.target + Space.sm;
    Widget cell(String date, List<DueItem> items) {
      final isToday = date == dues.today, isSelected = date == selected;
      final late = items.any((i) => i.days < 0);
      final count = items.length;
      return Semantics(
        button: true,
        selected: isSelected,
        label: [
          civilLabel(date),
          if (isToday) 'today',
          count == 0
              ? 'nothing due'
              : late
              ? '${_plural(count, 'item')}, overdue'
              : '${_plural(count, 'item')} due',
        ].join(', '),
        excludeSemantics: true,
        child: Pressable(
          key: ValueKey('due-day-$date'),
          radius: Radii.controlOf(context),
          color: isSelected
              ? c.selection
              : late
              ? c.overdue.$2
              : null,
          border: isToday ? Border.all(color: c.primary) : null,
          onTap: () => onSelected(date),
          // A minimum, not a fixed height, so the cell grows with the text.
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (week)
                  Text(
                    _letters[DateTime.parse(date).weekday - 1],
                    style: text.labelSmall?.copyWith(color: c.secondary),
                  ),
                Text(
                  '${DateTime.parse(date).day}',
                  style: text.labelLarge?.copyWith(
                    color: isSelected ? c.onSelection : c.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(
                  height: Space.md,
                  child: late
                      ? Icon(
                          Icons.error_outline,
                          size: Space.md,
                          color: c.overdue.$1,
                        )
                      : count > 0
                      ? Center(
                          child: Container(
                            width: Space.xs + Space.xxs,
                            height: Space.xs + Space.xxs,
                            decoration: BoxDecoration(
                              color: c.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget line(List<Widget> cells) => Row(
      children: [
        for (final (i, w) in cells.indexed) ...[
          if (i > 0) const SizedBox(width: Space.xxs),
          Expanded(child: w),
        ],
      ],
    );

    if (week) return line([for (final (d, items) in days) cell(d, items)]);
    final lead = DateTime.parse(days.first.$1).weekday - 1;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (final (d, items) in days) cell(d, items),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }
    return Column(
      children: [
        line([
          for (final l in _letters)
            ExcludeSemantics(
              child: Center(
                child: Text(
                  l,
                  style: text.labelSmall?.copyWith(color: c.secondary),
                ),
              ),
            ),
        ]),
        const SizedBox(height: Space.xs),
        for (var r = 0; r < cells.length; r += 7) ...[
          if (r > 0) const SizedBox(height: Space.xxs),
          line(cells.sublist(r, r + 7)),
        ],
      ],
    );
  }
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
  });
  final List<DebtProgress> debts;
  final Amount amount;
  final VoidCallback onOpen;
  final bool available;

  static const shown = 6;

  static Widget pill(DebtProgress d) => switch (d.due.status) {
    final DebtDueStatus status => duePill(status),
    null =>
      d.closed
          ? const StatusPill(
              'Closed',
              icon: Icons.check_circle_outline,
              tone: PillTone.success,
            )
          : const StatusPill.settled(),
  };

  /// The line under the bar.
  static String progressLine(DebtProgress d, Amount amount) => !d.scheduled
      ? 'No payment schedule yet'
      : d.closed
      ? 'Closed with a payoff'
      : d.finished
      ? 'All ${_plural(d.total, 'payment')} logged'
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
      progressLine(d, amount),
      style: text.bodySmall?.copyWith(color: c.secondary),
    );
    Widget owed(DebtProgress d) =>
        MoneyAmount(amount(d.outstanding), kind: MoneyKind.owed);
    // One width for every row's amount, so the columns line up.
    final amountWidth = moneyColumnWidth(context, [
      for (final d in debts.take(shown)) amount(d.outstanding),
    ]);
    Widget item(DebtProgress d, bool table) => Semantics(
      label: 'Payoff progress for ${d.debt.title}: ${progressLine(d, amount)}',
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
    required this.onOpen,
    this.available = true,
    this.hidden = false,
  });
  final List<(String, BigInt)> categories;
  final Amount amount;
  final String caption;
  final VoidCallback onOpen;
  final bool available, hidden;

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
                money,
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

    return OverviewCard(
      title: 'Spending by category',
      centered: true,
      caption: widget.caption,
      trailing: CardLink('View report', onPressed: widget.onOpen),
      child: !widget.available
          ? const NotAvailable('Spending shows once your records are complete.')
          : widget.hidden
          ? const AmountsHidden()
          : shares.isEmpty
          ? const EmptyState(
              icon: Icons.pie_chart_outline,
              title: 'No spending this month',
              message: 'Expenses you log this month show here by category.',
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

/// O8: active budgets against their limits, in exact basis points, with a
/// gauge of the total used across the budgets that have a limit.
class BudgetsCard extends StatelessWidget {
  const BudgetsCard({
    super.key,
    required this.budgets,
    required this.amount,
    required this.onOpen,
  });
  final List<BudgetProgress> budgets;
  final Amount amount;
  final VoidCallback onOpen;

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
    final gauge = bp == null
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
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, b) in budgets.indexed) ...[
          if (i > 0) const SizedBox(height: Space.md),
          Semantics(
            label: '${b.budget.title}: ${line(b, amount)}',
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
                    if (b.over > BigInt.zero)
                      const StatusPill(
                        'Over the limit',
                        icon: Icons.warning_amber_rounded,
                        tone: PillTone.warning,
                      ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                if (b.basisPoints != null)
                  SlimBar(
                    fraction: b.basisPoints! / 10000,
                    color: b.over > BigInt.zero
                        ? c.tone(NoticeTone.warning).$1
                        : null,
                  ),
                const SizedBox(height: Space.xs),
                Text(
                  line(b, amount),
                  style: text.bodySmall?.copyWith(color: c.secondary),
                ),
              ],
            ),
          ),
        ],
      ],
    );
    return OverviewCard(
      title: 'Budgets',
      centered: true,
      caption: 'Active budgets covering today',
      trailing: CardLink('View budgets', onPressed: onOpen),
      child: budgets.isEmpty
          ? EmptyState(
              icon: Icons.savings_outlined,
              title: 'No active budgets',
              message: 'Budgets you set in Money show their progress here.',
              action: AppButton.secondary('Open budgets', onPressed: onOpen),
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
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        gauge,
                        const SizedBox(width: Space.xl),
                        Expanded(child: list),
                      ],
                    ),
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
  });
  final String title;
  final String? caption;
  final List<ActivityRow> rows;
  final Widget empty;
  final Widget? action;

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
                  return ListGroup(
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
                  ],
                );
              },
            ),
    );
  }
}
