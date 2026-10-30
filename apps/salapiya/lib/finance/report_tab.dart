import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_cards.dart';
import '../app/overview_data.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import 'money_cards.dart';
import 'money_data.dart';
import 'planning_data.dart';
import 'report_data.dart';

const _onlyAccounts = 'All accounts only',
    _onlyCategories = 'All categories only';

String _civilDate(DateTime d) => d.toIso8601String().substring(0, 10);

/// Why a card has nothing to show: the filters, not the records.
Widget _filterLimit(String title, String message) => EmptyState(
  icon: Icons.filter_alt_off_outlined,
  title: title,
  message: message,
);

final _accountsOnly = _filterLimit(
  _onlyAccounts,
  'Clear the account filter to see this.',
);
final _categoriesOnly = _filterLimit(
  _onlyCategories,
  'Clear the category filter to see this.',
);

/// "Where did my money go, and how does it compare?" Each figure answers for
/// the period and filters shown, or says it can't; what a filter can't work
/// out never reads as zero.
class ReportsTab extends StatelessWidget {
  const ReportsTab({
    super.key,
    required this.source,
    required this.filter,
    required this.onFilter,
    required this.onExport,
  });
  final MoneySource source;
  final ReportFilter filter;
  final ValueChanged<ReportFilter> onFilter;
  final ValueChanged<ReportFilter> onExport;

  Future<void> openFilters(BuildContext context) async {
    final s = source.snapshot, today = source.today;
    final (start, end) = filter.range(today);
    var account = filter.account, category = filter.category;
    var from = start, to = end;
    final apply = await showAdaptiveModal<bool>(
      context,
      title: 'Filters',
      purpose: ModalPurpose.choice,
      primary: const ModalAction('Show results', value: true),
      body: StatefulBuilder(
        builder: (context, setFilters) => CompactForm(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              OptionPicker<String>(
                key: const ValueKey('report-filter-account'),
                label: 'Account',
                style: PickerStyle.dropdown,
                value: account ?? '',
                options: [
                  const PickerOption(value: '', label: 'All accounts'),
                  for (final a in s.accounts)
                    PickerOption(value: a.id, label: a.name),
                ],
                onChanged: (v) =>
                    setFilters(() => account = v.isEmpty ? null : v),
              ),
              SizedBox(height: CompactForm.fieldGap(context)),
              OptionPicker<String>(
                key: const ValueKey('report-filter-category'),
                label: 'Category',
                style: PickerStyle.dropdown,
                value: category ?? '',
                options: [
                  const PickerOption(value: '', label: 'All categories'),
                  for (final c in s.categories)
                    PickerOption(value: c.id, label: c.name),
                ],
                onChanged: (v) =>
                    setFilters(() => category = v.isEmpty ? null : v),
              ),
              SizedBox(height: CompactForm.fieldGap(context)),
              DateField(
                key: const ValueKey('report-filter-from'),
                label: 'From',
                required: true,
                value: DateTime.parse(from),
                onChanged: (d) {
                  if (d != null) setFilters(() => from = _civilDate(d));
                },
              ),
              SizedBox(height: CompactForm.fieldGap(context)),
              DateField(
                key: const ValueKey('report-filter-to'),
                label: 'To',
                required: true,
                value: DateTime.parse(to),
                errorText: ReportFilter(
                  period: ReportPeriod.custom,
                  from: from,
                  to: to,
                ).problem(today),
                onChanged: (d) {
                  if (d != null) setFilters(() => to = _civilDate(d));
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (apply != true) return;
    final dated = from != start || to != end;
    onFilter(
      ReportFilter(
        period: dated ? ReportPeriod.custom : filter.period,
        from: dated ? from : filter.from,
        to: dated ? to : filter.to,
        account: account,
        category: category,
      ),
    );
  }

  Widget band(BuildContext context) {
    final (from, to) = filter.range(source.today);
    final periods = MenuAnchor(
      alignmentOffset: const Offset(0, Space.xs),
      menuChildren: [
        for (final p in ReportPeriod.values)
          MenuItemButton(
            key: ValueKey('report-period-${p.name}'),
            trailingIcon: filter.period == p ? const Icon(Icons.check) : null,
            onPressed: () => p == ReportPeriod.custom
                ? openFilters(context)
                : onFilter(
                    ReportFilter(
                      period: p,
                      account: filter.account,
                      category: filter.category,
                    ),
                  ),
            child: Text(p.label),
          ),
      ],
      builder: (context, controller, _) => ChipButton(
        filter.period == ReportPeriod.custom
            ? reportSpan(from, to, source.today)
            : filter.period.label,
        key: const ValueKey('report-period'),
        icon: Icons.date_range_outlined,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
    final name = filter.filters == 0
        ? 'Filters'
        : 'Filters · ${filter.filters}';
    final s = source.snapshot;
    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        periods,
        ChipButton(
          name,
          key: const ValueKey('report-filters'),
          icon: Icons.tune,
          onPressed: () => openFilters(context),
        ),
        if (!isDesktop(context) &&
            source.complete &&
            filter.problem(source.today) == null)
          ChipButton(
            'Export CSV',
            key: const ValueKey('report-export'),
            icon: Icons.download_outlined,
            onPressed: () => onExport(filter),
          ),
        if (filter.account case final id?)
          ChipButton(
            s.accounts.where((a) => a.id == id).firstOrNull?.name ?? 'Account',
            key: const ValueKey('report-remove-account'),
            icon: Icons.close,
            onPressed: () => onFilter(filter.without(account: true)),
          ),
        if (filter.category case final id?)
          ChipButton(
            source.categoryName(id),
            key: const ValueKey('report-remove-category'),
            icon: Icons.close,
            onPressed: () => onFilter(filter.without(category: true)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final problem = filter.problem(source.today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        band(context),
        SizedBox(height: Space.cardGapOf(context)),
        if (problem != null)
          InlineNotice(
            problem,
            key: const ValueKey('report-dates-problem'),
            tone: NoticeTone.warning,
          )
        else
          _ReportCards(source: source, filter: filter),
      ],
    );
  }
}

class _ReportCards extends StatelessWidget {
  const _ReportCards({required this.source, required this.filter});
  final MoneySource source;
  final ReportFilter filter;

  @override
  Widget build(BuildContext context) {
    final android = !isDesktop(context);
    final s = source.snapshot, today = source.today;
    final complete = source.complete, hidden = source.hidden;
    final amount = source.amount, actions = source.actions;
    final category = filter.category;
    final (from, to) = filter.range(today);
    final before = filter.before(today);
    final heading = reportSpan(from, to, today);
    final earlierSpan = reportSpan(before.$1, before.$2, today);
    final versus = 'vs $earlierSpan';
    final trend = complete && !hidden;
    final daily = complete
        ? dailySpending(s, from, to, category: category)
        : const <(String, BigInt)>[];
    final ids = filter.account == null
        ? [for (final a in s.accounts) a.id]
        : [filter.account!];
    final cash = cashFlow(s, ids, from, to);
    final earlier = cashFlow(s, ids, before.$1, before.$2);
    const labels = ['Spending', 'Income', 'Money in', 'Money out'];

    Widget tile({
      required String label,
      required IconData icon,
      required BigInt current,
      required BigInt previous,
      required ChangeMeaning meaning,
      required String caption,
      String? unanswered,
      bool accent = false,
      List<BigInt> spark = const [],
    }) => KpiTile(
      key: ValueKey('report-${label.toLowerCase().replaceAll(' ', '-')}'),
      labels: labels,
      accent: accent,
      compactSpark: accent,
      icon: icon,
      label: label,
      value: MoneyAmount(
        unanswered ?? (complete ? amount(current) : null),
        size: MoneySize.tile,
        textAlign: TextAlign.start,
      ),
      // Nothing in either period has nothing to compare.
      change:
          trend &&
              unanswered == null &&
              (current != BigInt.zero || previous != BigInt.zero)
          ? ChangeLine(
              basisPoints: changeBasisPoints(current, previous),
              versus: versus,
              meaning: meaning,
            )
          : null,
      spark: trend && unanswered == null ? spark : const [],
      caption: !complete || unanswered != null ? null : caption,
    );

    final tiles = <Widget>[
      tile(
        label: 'Spending',
        icon: Icons.shopping_bag_outlined,
        accent: true,
        current: spendingBetween(s, from, to, category: category),
        previous: spendingBetween(s, before.$1, before.$2, category: category),
        meaning: ChangeMeaning.riseIsBad,
        caption: 'Refunds subtracted',
        unanswered: filter.spendingKnown ? null : _onlyAccounts,
        spark: [for (final d in daily) d.$2],
      ),
      tile(
        label: 'Income',
        icon: Icons.south_west,
        current: incomeBetween(s, from, to, category: category),
        previous: incomeBetween(s, before.$1, before.$2, category: category),
        meaning: ChangeMeaning.riseIsGood,
        caption: 'What you earned or received',
        unanswered: filter.spendingKnown ? null : _onlyAccounts,
      ),
      tile(
        label: 'Money in',
        icon: Icons.login,
        current: cash.moneyIn,
        previous: earlier.moneyIn,
        meaning: ChangeMeaning.riseIsGood,
        caption: 'Transfers between your accounts aren’t counted',
        unanswered: filter.cashKnown ? null : _onlyCategories,
      ),
      tile(
        label: 'Money out',
        icon: Icons.logout,
        current: cash.moneyOut,
        previous: earlier.moneyOut,
        meaning: ChangeMeaning.riseIsBad,
        caption: 'Card purchases aren’t cash',
        unanswered: filter.cashKnown ? null : _onlyCategories,
      ),
    ];

    final categories = complete
        ? spendingByCategory(s, from, to, source.categoryName)
        : const <(String, BigInt)>[];
    final changes = complete
        ? categoryChanges(
            s,
            (from, to),
            before,
            source.categoryName,
            only: category == null ? null : source.categoryName(category),
          )
        : const <CategoryChange>[];
    final donut = CategoryCard(
      key: const ValueKey('report-where'),
      title: 'Where it went',
      caption: heading,
      categories: categories,
      amount: amount,
      available: complete,
      hidden: hidden,
      emptyTitle: 'No spending in this period',
      emptyMessage: 'Expenses you log show here by category.',
      unavailable: !filter.spendingKnown
          ? _accountsOnly
          : category != null
          ? _categoriesOnly
          : null,
    );
    final byCategory = OverviewCard(
      key: const ValueKey('report-categories'),
      title: 'By category',
      caption: versus,
      child: !complete
          ? const NotAvailable('Spending shows once your records are complete.')
          : !filter.spendingKnown
          ? _accountsOnly
          : hidden
          ? const AmountsHidden()
          : changes.isEmpty
          ? const EmptyState(
              icon: Icons.category_outlined,
              title: 'No spending to compare',
              message: 'Categories show here once either period has spending.',
            )
          : _CategoryTable(rows: changes, amount: amount, hidden: hidden),
    );
    final over = _SpendingOverTime(
      key: const ValueKey('report-over-time'),
      from: from,
      to: to,
      earlierSpan: earlierSpan,
      heading: heading,
      daily: daily,
      earlier: complete
          ? dailySpending(s, before.$1, before.$2, category: category)
          : const [],
      monthly: complete && daily.length > reportDailyDays
          ? monthlySpending(s, from, to, category: category)
          : null,
      top: changes.firstOrNull,
      amount: amount,
      available: complete,
      unavailable: filter.spendingKnown ? null : _accountsOnly,
      hidden: hidden,
    );
    final debts = _DebtsAndCards(
      key: const ValueKey('report-debts-cards'),
      summary: complete ? cardSummary(s, from, to) : null,
      amount: amount,
      filtered: filter.filtered,
      hidden: hidden,
      heading: heading,
    );
    final budgets = _BudgetsInPeriod(
      key: const ValueKey('report-budgets'),
      rows: complete
          ? reportBudgets(s, from, to, today, category: category)
          : const [],
      amount: amount,
      available: complete,
      onOpen: actions.openItem,
    );
    final all = complete
        ? reportRecords(
            moneyActivity(s, source.categoryName, waiting: source.waiting),
            filter,
            today,
            source.categoryName,
          )
        : const <MoneyRow>[];
    void openPage() => openDemoPage<void>(
      context,
      _ReportPage(
        heading: heading,
        today: today,
        spending: filter.spendingKnown
            ? spendingBetween(s, from, to, category: category)
            : null,
        income: filter.spendingKnown
            ? incomeBetween(s, from, to, category: category)
            : null,
        moneyIn: filter.cashKnown ? cash.moneyIn : null,
        moneyOut: filter.cashKnown ? cash.moneyOut : null,
        changes: filter.spendingKnown ? changes : const [],
        versus: versus,
        records: all,
        amount: amount,
        hidden: hidden,
        onOpen: actions.openRecord,
      ),
      'money/report',
      title: 'Report',
    );
    final records = RecordListCard(
      key: const ValueKey('report-records'),
      title: 'Records',
      caption: complete
          ? '${all.length} ${all.length == 1 ? 'record' : 'records'} · $heading'
          : null,
      rows: all,
      amount: amount,
      hidden: hidden,
      onOpen: actions.openRecord,
      corner: !complete
          ? null
          : CardMenu(
              key: const ValueKey('report-menu'),
              tooltip: 'More',
              items: [
                MenuItemButton(
                  key: const ValueKey('report-open-page'),
                  leadingIcon: const Icon(Icons.open_in_full),
                  onPressed: openPage,
                  child: const Text('Open as a page'),
                ),
              ],
            ),
      empty: !complete
          ? const NotAvailable('Records show once your records are complete.')
          : const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Nothing in this period',
              message: 'Try another period, or clear the filters.',
            ),
    );
    return DashboardGrid(
      key: const ValueKey('reports-grid'),
      cards: android
          ? null
          : [
              for (final t in tiles) (t, 3, 6),
              (donut, 5, 12),
              (byCategory, 7, 12),
              (over, 8, 12),
              (debts, 4, 12),
              (budgets, 12, 12),
              (records, 12, 12),
            ],
      // On phones Spending takes the full width, its sparkline beside the
      // value, as Available money does on Accounts.
      stacked: [
        KeyedSubtree(child: tiles.first),
        ...tiles.skip(1),
        donut,
        byCategory,
        over,
        debts,
        budgets,
        records,
      ],
    );
  }
}

class _CategoryTable extends StatelessWidget {
  const _CategoryTable({
    required this.rows,
    required this.amount,
    required this.hidden,
  });
  final List<CategoryChange> rows;
  final Amount amount;
  final bool hidden;

  static String _changeLine(CategoryChange c, Amount amount, bool hidden) {
    final moved = signedAmount(c.change, amount, hidden: hidden);
    final bp = c.basisPoints;
    return bp == null || bp == 0
        ? moved
        : '$moved · ${bp > 0 ? '+' : '−'}${percentLabel(bp.abs())}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppTable(
      key: const ValueKey('report-category-table'),
      columns: const [(label: 'Category', flex: 3, width: null)],
      moneyColumns: const ['This period', 'Before', 'Change'],
      rows: [
        for (final c in rows)
          () {
            final line = _changeLine(c, amount, hidden);
            return AppTableRow(
              id: 'report-category-${c.name}',
              spoken: [
                c.name,
                'this period ${amount(c.current)}',
                'before ${amount(c.previous)}',
                'change $line',
              ].join(', '),
              cells: [Text(c.name, style: text.bodyMedium)],
              money: [
                amount(c.current),
                amount(c.previous),
                signedAmount(c.change, amount, hidden: hidden),
              ],
              narrow: KeyedSubtree(
                key: ValueKey('row-report-category-${c.name}'),
                child: AdaptiveRow(
                  title: c.name,
                  subtitle: detailLine(['Before ${amount(c.previous)}', line]),
                  trailing: MoneyAmount(amount(c.current)),
                ),
              ),
            );
          }(),
      ],
    );
  }
}

/// How the chart draws the period.
enum _ChartView { bars, running }

/// Spending by day, or by month past 62 days, or as a running total against
/// the earlier period.
class _SpendingOverTime extends StatefulWidget {
  const _SpendingOverTime({
    super.key,
    required this.from,
    required this.to,
    required this.earlierSpan,
    required this.heading,
    required this.daily,
    required this.earlier,
    required this.monthly,
    required this.top,
    required this.amount,
    required this.available,
    required this.unavailable,
    required this.hidden,
  });
  final String from, to, heading, earlierSpan;
  final List<(String, BigInt)> daily, earlier;

  /// Set when the period is too long to draw by day.
  final List<(String, BigInt)>? monthly;
  final CategoryChange? top;
  final Amount amount;
  final bool available, hidden;
  final Widget? unavailable;
  @override
  State<_SpendingOverTime> createState() => _SpendingOverTimeState();
}

class _SpendingOverTimeState extends State<_SpendingOverTime> {
  _ChartView view = _ChartView.bars;

  /// "21 Oct", without the weekday.
  String short(String date) => civilLabel(date).split(', ').last;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final amount = widget.amount, daily = widget.daily;
    final earlier = widget.earlier, monthly = widget.monthly;
    final bars = monthly ?? daily;
    final empty =
        daily.every((d) => d.$2 == BigInt.zero) &&
        earlier.every((d) => d.$2 == BigInt.zero);
    final step = (daily.length / 5).ceil();
    // Phones have room for about six month names.
    final monthStep = !isDesktop(context) && bars.length > 6 ? 2 : 1;
    final peak = bars.isEmpty
        ? null
        : bars.reduce((a, b) => b.$2 > a.$2 ? b : a);
    final current = c.chartSeries.first, previous = c.chartSeries.last;
    String monthName(String month) => periodHeading(month, monthEnd(month));
    final priorTotal = sumMinor(earlier.map((d) => d.$2));
    Widget chart() => switch (view) {
      _ChartView.bars => OverviewBarChart(
        height: heroChartHeight,
        values: [for (final b in bars) b.$2],
        label: (i) => monthly != null
            ? i % monthStep == 0
                  ? short(bars[i].$1).split(' ').last
                  : null
            : i % step == 0
            ? short(bars[i].$1)
            : null,
        tooltip: (i) =>
            '${monthly != null ? monthName(bars[i].$1) : civilLabel(bars[i].$1)}\n${amount(bars[i].$2)}',
        semanticsLabel:
            'Spending ${monthly != null ? 'by month' : 'by day'}, ${widget.heading}. Highest: ${amount(peak?.$2 ?? BigInt.zero)}.',
      ),
      _ChartView.running => OverviewLineChart(
        height: heroChartHeight,
        lines: [
          (
            values: SpendingComparison.running(daily),
            color: current,
            dashed: false,
            fill: true,
          ),
          (
            values: SpendingComparison.running(earlier),
            color: previous,
            dashed: true,
            fill: false,
          ),
        ],
        label: (i) =>
            i % step == 0 && i < daily.length ? short(daily[i].$1) : null,
        tooltip: (line, i) {
          final days = line == 0 ? daily : earlier;
          return '${civilLabel(days[i].$1)}\n${amount(SpendingComparison.running(days)[i])}';
        },
        semanticsLabel:
            'Running spending, ${widget.heading}: ${amount(sumMinor(daily.map((d) => d.$2)))}. Earlier period: ${amount(priorTotal)}.',
      ),
    };
    return OverviewCard(
      title: 'Spending over time',
      caption: widget.heading,
      stackBelow: periodBase + rowBase,
      trailing: !widget.available || widget.unavailable != null
          ? null
          : MiniSegmented<_ChartView>(
              key: const ValueKey('report-chart-view'),
              label: 'Chart',
              options: [
                (_ChartView.bars, monthly == null ? 'Daily' : 'Monthly'),
                (_ChartView.running, 'Running'),
              ],
              selected: view,
              onSelected: (v) => setState(() => view = v),
            ),
      child: !widget.available
          ? const NotAvailable('Charts show once your records are complete.')
          : widget.unavailable != null
          ? widget.unavailable!
          : widget.hidden
          ? const AmountsHidden()
          : empty
          ? const EmptyState(
              icon: Icons.bar_chart,
              title: 'No spending in this period',
              message: 'Spending shows here as you log expenses.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                chart(),
                const SizedBox(height: Space.sm),
                if (view == _ChartView.running)
                  ChartLegend(
                    entries: [
                      (label: 'This period', color: current, dashed: false),
                      (label: 'Before', color: previous, dashed: true),
                    ],
                  ),
                const SizedBox(height: Space.md),
                StatStrip(
                  key: const ValueKey('report-stats'),
                  stats: [
                    if (peak != null)
                      (
                        label: monthly == null
                            ? 'Highest day'
                            : 'Highest month',
                        value: amount(peak.$2),
                        detail: peak.$2 == BigInt.zero
                            ? null
                            : monthly == null
                            ? civilLabel(peak.$1)
                            : monthName(peak.$1),
                      ),
                    (
                      label: 'Days with spending',
                      value:
                          '${daily.where((d) => d.$2 > BigInt.zero).length} of ${daily.length}',
                      detail: null,
                    ),
                    if (widget.top case final top?
                        when top.current > BigInt.zero)
                      (
                        label: 'Top category',
                        value: top.name,
                        detail: amount(top.current),
                      ),
                    (
                      label: 'Before',
                      value: amount(priorTotal),
                      detail: widget.earlierSpan,
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                ChartValues(
                  rows: [
                    for (final b in bars)
                      if (b.$2 != BigInt.zero)
                        (
                          monthly == null ? civilLabel(b.$1) : monthName(b.$1),
                          amount(b.$2),
                        ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _DebtsAndCards extends StatelessWidget {
  const _DebtsAndCards({
    super.key,
    required this.summary,
    required this.amount,
    required this.filtered,
    required this.hidden,
    required this.heading,
  });
  final CardSummary? summary;
  final Amount amount;
  final bool filtered, hidden;
  final String heading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = summary;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: LabelAmount(
          stackBelow: Space.xxxl * 5,
          label: Text(label, style: text.bodyMedium),
          amount: MoneyAmount(value),
        ),
      ),
    );
    String signed(BigInt v) => signedAmount(v, amount, hidden: hidden);
    return OverviewCard(
      title: 'Debts and cards',
      caption: heading,
      child: s == null
          ? const NotAvailable('This shows once your records are complete.')
          : filtered
          ? _filterLimit(
              'All accounts and categories only',
              'Clear the filters to see this.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                row('Card purchases', amount(s.purchases)),
                row('Card payments', amount(s.payments)),
                row('Fees and interest', amount(s.charges)),
                row('Card refunds', amount(s.refunds)),
                row('Debt paid down', amount(s.paidDown)),
                if (s.groupOwedToYou != BigInt.zero)
                  row('Owed to you in groups', signed(s.groupOwedToYou)),
                if (s.groupYouOwe != BigInt.zero)
                  row('You owe in groups', signed(s.groupYouOwe)),
                if (s.unexplained != BigInt.zero)
                  row('Payments without a breakdown', signed(s.unexplained)),
                const ListEnd(key: ValueKey('report-debts-end')),
              ],
            ),
    );
  }
}

/// Each budget's own period and spending: never cut to the report's dates,
/// and never added up.
class _BudgetsInPeriod extends StatelessWidget {
  const _BudgetsInPeriod({
    super.key,
    required this.rows,
    required this.amount,
    required this.available,
    required this.onOpen,
  });
  final List<(BudgetWhen, BudgetProgress)> rows;
  final Amount amount;
  final bool available;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(
      color: CraftTheme.of(context).secondary,
    );
    return OverviewCard(
      title: 'Budgets in this period',
      caption: 'Each budget’s whole period. Filters by account don’t apply.',
      child: !available
          ? const NotAvailable('Budgets show once your records are complete.')
          : rows.isEmpty
          ? const EmptyState(
              icon: Icons.pie_chart_outline,
              title: 'No budgets in this period',
              message: 'Budgets covering any of these dates show here.',
            )
          : AppTable(
              key: const ValueKey('report-budget-table'),
              columns: const [
                (label: 'Budget', flex: 3, width: null),
                (label: 'Period', flex: 3, width: null),
                (label: 'Status', flex: 2, width: null),
              ],
              moneyColumns: const ['Spent', 'Limit'],
              rows: [
                for (final (_, b) in rows)
                  () {
                    final period = budgetPeriodLabel(b.budget);
                    final zero = b.basisPoints == null;
                    final over = !zero && b.over > BigInt.zero;
                    final state = zero
                        ? 'Zero-limit budget'
                        : over
                        ? 'Over the limit'
                        : 'Within limit';
                    final id = b.budget.actionId;
                    return AppTableRow(
                      id: 'report-budget-$id',
                      spoken: [
                        b.budget.title,
                        period,
                        state,
                        'spent ${amount(b.spent)}',
                        'limit ${amount(b.limit)}',
                      ].join(', '),
                      onTap: () => onOpen(id),
                      cells: [
                        Text(b.budget.title, style: text.titleSmall),
                        Text(period, style: muted),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: over
                              ? StatusPill(
                                  state,
                                  icon: Icons.warning_amber_rounded,
                                  tone: PillTone.warning,
                                )
                              : StatusPill(
                                  state,
                                  icon: zero
                                      ? Icons.block
                                      : Icons.check_circle_outline,
                                  tone: zero
                                      ? PillTone.neutral
                                      : PillTone.success,
                                ),
                        ),
                      ],
                      money: [amount(b.spent), amount(b.limit)],
                      narrow: KeyedSubtree(
                        key: ValueKey('row-report-budget-$id'),
                        child: AdaptiveRow(
                          title: b.budget.title,
                          subtitle: detailLine([period, state]),
                          trailing: MoneyAmount(amount(b.spent)),
                          onTap: () => onOpen(id),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
    );
  }
}

/// The shareable report: its totals, categories and every record, with no row
/// limit, so one screenshot or print shows all of it. What the filters can't
/// answer stays out.
class _ReportPage extends StatelessWidget {
  const _ReportPage({
    required this.heading,
    required this.today,
    required this.spending,
    required this.income,
    required this.moneyIn,
    required this.moneyOut,
    required this.changes,
    required this.versus,
    required this.records,
    required this.amount,
    required this.hidden,
    required this.onOpen,
  });
  final String heading, today, versus;
  final BigInt? spending, income, moneyIn, moneyOut;
  final List<CategoryChange> changes;
  final List<MoneyRow> records;
  final Amount amount;
  final bool hidden;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => SectionPage(
    title: 'Report',
    caption: '$heading · as of ${civilLabel(today)}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatStrip(
          key: const ValueKey('report-page-totals'),
          stats: [
            if (spending case final v?)
              (label: 'Spending', value: amount(v), detail: null),
            if (income case final v?)
              (label: 'Income', value: amount(v), detail: null),
            if (moneyIn case final v?)
              (label: 'Money in', value: amount(v), detail: null),
            if (moneyOut case final v?)
              (label: 'Money out', value: amount(v), detail: null),
          ],
        ),
        SizedBox(height: Space.cardGapOf(context)),
        if (changes.isNotEmpty && !hidden) ...[
          OverviewCard(
            title: 'By category',
            caption: versus,
            child: _CategoryTable(
              rows: changes,
              amount: amount,
              hidden: hidden,
            ),
          ),
          SizedBox(height: Space.cardGapOf(context)),
        ],
        RecordListCard(
          key: const ValueKey('report-page-records'),
          title: 'Records',
          caption:
              '${records.length} ${records.length == 1 ? 'record' : 'records'}',
          rows: records,
          amount: amount,
          hidden: hidden,
          onOpen: onOpen,
          pageSize: records.isEmpty ? 1 : records.length,
          empty: const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Nothing in this period',
            message: 'Try another period, or clear the filters.',
          ),
        ),
      ],
    ),
  );
}
