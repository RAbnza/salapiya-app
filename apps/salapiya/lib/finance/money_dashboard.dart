import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_cards.dart';
import '../app/overview_dashboard.dart' show overviewLongDate;
import '../app/overview_data.dart';
import '../app/shell_navigation.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../prototype/scenarios.dart' show AppDestination;
import 'money_cards.dart';
import 'money_data.dart';

/// Money's header: on Windows the title, the date and quick actions; on
/// Android one compact row, because the app bar has the title and the +
/// button has the actions.
class MoneyHeader extends StatelessWidget {
  const MoneyHeader({
    super.key,
    required this.today,
    this.caption,
    this.actions = const [],
  });
  final String today;

  /// What follows the date in the caption, e.g. "3 accounts".
  final String? caption;
  final List<QuickAction> actions;
  @override
  Widget build(BuildContext context) {
    final date = overviewLongDate(today);
    if (!isDesktop(context)) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Space.target),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: Space.lg + Space.xxs,
              color: CraftTheme.of(context).primary,
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(date, style: Theme.of(context).textTheme.titleSmall),
            ),
          ],
        ),
      );
    }
    final title = PageHeader(
      'Money',
      caption: caption == null ? 'As of $date' : 'As of $date · $caption',
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (actions.isEmpty) return title;
        // Beside the title when wide, ending at the content's right edge.
        return box.maxWidth >= DashboardGrid.four
            ? Row(
                children: [
                  Expanded(flex: 2, child: title),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: QuickActions(
                        key: const ValueKey('money-quick-actions'),
                        actions: actions,
                        alignment: WrapAlignment.end,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: Space.md),
                  QuickActions(
                    key: const ValueKey('money-quick-actions'),
                    actions: actions,
                  ),
                ],
              );
      },
    );
  }
}

/// Under the tabs, only when they apply.
List<Widget> moneyNotices(MoneySource source) => [
  if (!source.complete)
    const InlineNotice(
      'Balances and activity show once all your records have downloaded.',
      title: 'Your first download isn’t finished',
      tone: NoticeTone.warning,
    ),
  if (source.pending)
    InlineNotice(
      '${source.pendingCount} ${source.pendingCount == 1 ? 'change is' : 'changes are'} waiting to sync. Balances here include them, so they can differ from the Overview until they sync.',
      live: true,
    ),
  if (source.needsReview)
    SyncReviewNotice(onReview: source.onReview),
];

/// "How much do I have, where is it, what changed, and does anything need
/// me?" (§2 Money).
class AccountsTab extends StatelessWidget {
  const AccountsTab({
    super.key,
    required this.source,
    required this.drafts,
    required this.onTab,
    required this.onDues,
  });
  final MoneySource source;
  final int drafts;
  final ValueChanged<String> onTab;
  final VoidCallback onDues;

  @override
  Widget build(BuildContext context) {
    final android = !isDesktop(context);
    final s = source.snapshot, today = source.today;
    final complete = source.complete, hidden = source.hidden;
    final amount = source.amount, actions = source.actions;
    if (complete && s.accounts.isEmpty) {
      return SurfaceCard(
        key: const ValueKey('money-empty'),
        child: EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'No accounts yet',
          message: 'Add a cash wallet or bank account and what it holds today.',
          action: AppButton(
            'Add account',
            key: const ValueKey('money-add-account'),
            icon: Icons.add,
            onPressed: actions.addAccount,
          ),
        ),
      );
    }
    String? known(BigInt v) => complete ? amount(v) : null;
    final trend = complete && !hidden;
    final ids = [for (final a in s.accounts) a.id];
    final total = availableMoney(s, today);
    final before = lastMonthEnd(today);
    final month = cashFlow(s, ids, monthStart(today), today);
    final (lastStart, lastEnd) = lastMonthSpan(today);
    final last = cashFlow(s, ids, lastStart, lastEnd);
    final days = complete
        ? balanceByDay(s, ids, addCivilDays(today, -29), today)
        : const <(String, BigInt)>[];
    final week = OverviewDues.from(
      complete ? overviewDueSources(s, today) : const [],
      today,
      DuePeriod.week,
    );
    final versus = 'vs ${overviewSpan(lastStart, lastEnd)}';
    const labels = [
      'Available money',
      'Money in',
      'Money out',
      'Due this week',
    ];
    final tiles = <Widget>[
      KpiTile(
        key: const ValueKey('money-available'),
        labels: labels,
        accent: true,
        compactSpark: true,
        icon: Icons.account_balance_wallet_outlined,
        label: 'Available money',
        value: MoneyAmount(
          known(total),
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        change: trend
            ? ChangeLine(
                basisPoints: changeBasisPoints(
                  total,
                  availableMoney(s, before),
                ),
                versus: 'since ${civilLabel(before)}',
                meaning: ChangeMeaning.riseIsGood,
              )
            : null,
        spark: trend ? [for (final d in days) d.$2] : const [],
        caption: 'Cash and bank · card credit excluded',
      ),
      KpiTile(
        key: const ValueKey('money-in'),
        labels: labels,
        icon: Icons.south_west,
        label: 'Money in',
        value: MoneyAmount(
          known(month.moneyIn),
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        change: trend
            ? ChangeLine(
                basisPoints: changeBasisPoints(month.moneyIn, last.moneyIn),
                versus: versus,
                meaning: ChangeMeaning.riseIsGood,
              )
            : null,
        caption: !complete
            ? null
            : month.moneyIn == BigInt.zero
            ? 'Nothing yet this month'
            : 'This month · transfers between your accounts aren’t counted',
      ),
      KpiTile(
        key: const ValueKey('money-out'),
        labels: labels,
        icon: Icons.north_east,
        label: 'Money out',
        value: MoneyAmount(
          known(month.moneyOut),
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        change: trend
            ? ChangeLine(
                basisPoints: changeBasisPoints(month.moneyOut, last.moneyOut),
                versus: versus,
                meaning: ChangeMeaning.riseIsBad,
              )
            : null,
        caption: !complete
            ? null
            : month.moneyOut == BigInt.zero
            ? 'Nothing yet this month'
            : 'This month · card purchases aren’t cash',
      ),
      KpiTile(
        key: const ValueKey('money-due'),
        labels: labels,
        icon: Icons.event_outlined,
        label: 'Due this week',
        value: MoneyAmount(
          known(week.upcomingTotal + week.overdueTotal),
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        caption: !complete
            ? null
            : week.isEmpty
            ? 'Nothing due this week'
            : [
                '${week.upcoming.length} due',
                if (week.overdue.isNotEmpty) '${week.overdue.length} overdue',
              ].join(' · '),
        onTap: onDues,
      ),
    ];

    final accounts = AccountsCard(
      key: const ValueKey('money-accounts'),
      rows: complete ? accountRows(s, today) : const [],
      archived: complete ? accountRows(s, today, archived: true) : const [],
      total: total,
      amount: amount,
      available: complete,
      hidden: hidden,
      cards: source.cards,
      onCards: () => onTab('Cards'),
      onOpen: actions.openAccount,
      onAdd: actions.addAccount,
      corner: CardMenu(
        key: const ValueKey('money-accounts-menu'),
        tooltip: 'More',
        items: [
          MenuItemButton(
            key: const ValueKey('money-categories'),
            leadingIcon: const Icon(Icons.category_outlined),
            onPressed: actions.openCategories,
            child: const Text('Categories'),
          ),
          MenuItemButton(
            key: const ValueKey('money-drafts'),
            leadingIcon: const Icon(Icons.drafts_outlined),
            onPressed: actions.openDrafts,
            child: const Text('Saved drafts'),
          ),
          MenuItemButton(
            key: const ValueKey('money-imported'),
            leadingIcon: const Icon(Icons.upload_file_outlined),
            onPressed: () => onTab('Import'),
            child: const Text('Imported history'),
          ),
        ],
      ),
    );
    final tasks = complete
        ? moneyTasks(s, today, drafts: drafts)
        : const <MoneyTask>[];
    final attention = tasks.isEmpty
        ? null
        : AttentionCard(
            key: const ValueKey('money-attention'),
            tasks: tasks,
            onOpen: (t) => switch (t.need) {
              MoneyNeed.belowZero => actions.openAccount(t.id),
              MoneyNeed.balanceCheck => actions.openRecord(t.id),
              MoneyNeed.drafts => actions.openDrafts(),
            },
          );
    final rows = complete
        ? moneyActivity(s, source.categoryName, waiting: source.waiting)
        : const <MoneyRow>[];
    final balance = BalanceCard(
      key: const ValueKey('money-balance'),
      title: 'Balance over time',
      caption: 'All your accounts · closing balance',
      days: days,
      months: complete ? balanceByMonth(s, ids, today) : const [],
      amount: amount,
      available: complete,
      hidden: hidden,
      empty: rows.isEmpty,
    );
    final logged = rows.where((r) => r.date.compareTo(today) <= 0).toList();
    final recent = ActivityCard(
      key: const ValueKey('money-recent'),
      title: 'Recent activity',
      caption: 'Newest first',
      action: CardLink(
        'See all',
        key: const ValueKey('money-see-all'),
        onPressed: () => onTab('Activity'),
      ),
      rows: [
        for (final r in logged.take(6))
          (
            icon: moneyIcon(r),
            title: r.title,
            date: r.date,
            category: r.categoryLabel.isEmpty ? r.label : r.categoryLabel,
            amount: complete ? r.shown(amount, hidden: hidden) : null,
            onTap: () => actions.openRecord(r.id),
          ),
      ],
      footer: ListEnd(
        key: const ValueKey('money-recent-end'),
        label: logged.length > 6
            ? '${logged.length - 6} more in Activity'
            : 'That’s everything',
        onPressed: logged.length > 6 ? () => onTab('Activity') : null,
      ),
      empty: !complete
          ? const NotAvailable('Activity shows once your records are complete.')
          : const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No activity yet',
              message: 'What you log shows here.',
            ),
    );
    return DashboardGrid(
      key: const ValueKey('money-accounts-grid'),
      cards: android
          ? null
          : [
              for (final t in tiles) (t, 3, 6),
              (accounts, attention == null ? 12 : 8, 12),
              ?(attention == null ? null : (attention, 4, 12)),
              (balance, 7, 12),
              (recent, 5, 12),
            ],
      // On phones Available money takes the full width, its sparkline beside
      // the value; Money in and out pair up.
      stacked: [
        KeyedSubtree(child: tiles.first),
        ...tiles.skip(1),
        ?attention,
        accounts,
        recent,
        balance,
      ],
    );
  }
}

enum ActivityLayout {
  timeline('By day'),
  list('List');

  const ActivityLayout(this.label);
  final String label;
}

/// Find a record, and see what changed. Search looks through every date;
/// everything else narrows the period's records.
class ActivityTab extends StatefulWidget {
  const ActivityTab({
    super.key,
    required this.source,
    this.filter = const ActivityFilter(),
  });
  final MoneySource source;

  /// What it opens on.
  final ActivityFilter filter;
  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  late ActivityFilter filter = widget.filter;
  ActivityLayout layout = ActivityLayout.timeline;
  final search = TextEditingController();

  MoneySource get source => widget.source;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void clear() {
    search.clear();
    setState(() => filter = const ActivityFilter());
  }

  /// The list's dates: from the period's start, or the oldest record listed,
  /// through the period's end or today.
  (String, String, String) span(List<MoneyRow> rows) {
    final today = source.today;
    final (start, end) = filter.range(today);
    final from = start ?? (rows.isEmpty ? today : rows.last.date);
    final through = end ?? today;
    final last = through.compareTo(today) > 0 ? today : through;
    return (
      from,
      last,
      filter.shownPeriod == ActivityPeriod.thisMonth
          ? monthEnd(today)
          : through,
    );
  }

  Future<void> openFilters() async {
    final s = source.snapshot;
    var account = filter.account, category = filter.category;
    var from = filter.from, to = filter.to;
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
                key: const ValueKey('filter-account'),
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
                key: const ValueKey('filter-category'),
                label: 'Category',
                style: PickerStyle.dropdown,
                value: category ?? '',
                options: [
                  const PickerOption(value: '', label: 'All categories'),
                  for (final c in s.categories)
                    PickerOption(value: c.name, label: c.name),
                ],
                onChanged: (v) =>
                    setFilters(() => category = v.isEmpty ? null : v),
              ),
              SizedBox(height: CompactForm.fieldGap(context)),
              DateField(
                key: const ValueKey('filter-from'),
                label: 'From',
                value: from == null ? null : DateTime.parse(from!),
                onChanged: (d) => setFilters(
                  () => from = d?.toIso8601String().substring(0, 10),
                ),
              ),
              SizedBox(height: CompactForm.fieldGap(context)),
              DateField(
                key: const ValueKey('filter-to'),
                label: 'To',
                value: to == null ? null : DateTime.parse(to!),
                onChanged: (d) => setFilters(
                  () => to = d?.toIso8601String().substring(0, 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (apply != true || !mounted) return;
    final dated = from != null || to != null;
    setState(
      () => filter = ActivityFilter(
        query: filter.query,
        type: filter.type,
        account: account,
        category: category,
        period: dated
            ? ActivityPeriod.custom
            : filter.period == ActivityPeriod.custom
            ? ActivityPeriod.thisMonth
            : filter.period,
        from: from,
        to: to,
      ),
    );
  }

  void removeFilter({
    bool account = false,
    bool category = false,
    bool dates = false,
  }) => setState(
    () => filter = ActivityFilter(
      query: filter.query,
      type: filter.type,
      account: account ? null : filter.account,
      category: category ? null : filter.category,
      period: dates ? ActivityPeriod.thisMonth : filter.period,
      from: dates ? null : filter.from,
      to: dates ? null : filter.to,
    ),
  );

  Widget band() {
    final periods = MenuAnchor(
      alignmentOffset: const Offset(0, Space.xs),
      menuChildren: [
        for (final p in ActivityPeriod.values)
          if (p != ActivityPeriod.custom || filter.period == p)
            MenuItemButton(
              key: ValueKey('period-${p.name}'),
              trailingIcon: filter.period == p ? const Icon(Icons.check) : null,
              onPressed: () => setState(
                () => filter = p == ActivityPeriod.custom
                    ? filter
                    : ActivityFilter(
                        query: filter.query,
                        type: filter.type,
                        account: filter.account,
                        category: filter.category,
                        period: p,
                      ),
              ),
              child: Text(p.label),
            ),
      ],
      builder: (context, controller, _) => ChipButton(
        filter.shownPeriod.label,
        key: const ValueKey('activity-period'),
        icon: Icons.date_range_outlined,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
    final field = CompactForm(
      child: Semantics(
        label: 'Search activity',
        textField: true,
        child: TextField(
          key: const ValueKey('money-search'),
          controller: search,
          decoration: InputDecoration(
            hintText: 'Search every date',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: search.text.isEmpty
                ? null
                : AppIconButton(
                    icon: Icons.close,
                    tooltip: 'Clear search',
                    onPressed: () {
                      search.clear();
                      setState(() => filter = filter.copyWith(query: ''));
                    },
                  ),
          ),
          onChanged: (x) => setState(() => filter = filter.copyWith(query: x)),
        ),
      ),
    );
    final name = filter.filters == 0
        ? 'Filters'
        : 'Filters · ${filter.filters}';
    final controls = Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        periods,
        ChipButton(
          name,
          key: const ValueKey('activity-filters'),
          icon: Icons.tune,
          onPressed: openFilters,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) => narrowAt(context, box.maxWidth, tableBase)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: Space.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: controls,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: field),
                const SizedBox(width: Space.md),
                controls,
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = source.today, amount = source.amount;
    final hidden = source.hidden, s = source.snapshot;
    final actions = source.actions;
    if (!source.complete) {
      return const SurfaceCard(
        key: ValueKey('money-activity'),
        child: NotAvailable('Activity shows once your records are complete.'),
      );
    }
    final all = moneyActivity(s, source.categoryName, waiting: source.waiting);
    final rows = [
      for (final r in all)
        if (filter.shows(r, today, hidden: hidden)) r,
    ];
    final account = filter.account;
    final totals = listedTotals(rows, today, account: account);
    final change = totals.moneyIn - totals.moneyOut;
    final accountName = account == null
        ? null
        : s.accounts.where((a) => a.id == account).firstOrNull?.name;
    final (from, through, spanEnd) = span(rows);
    final heading = periodHeading(from, spanEnd);
    final statement = Statement.of(s, rows, from, through, account: account);
    final list = StatementList(
      key: const ValueKey('activity-statement'),
      statement: statement,
      heading: heading,
      today: today,
      amount: amount,
      hidden: hidden,
      onOpen: actions.openRecord,
    );
    final menu = CardMenu(
      key: const ValueKey('activity-menu'),
      tooltip: 'Layout: ${layout.label}',
      icon: Icons.settings_outlined,
      items: [
        for (final l in ActivityLayout.values)
          MenuItemButton(
            key: ValueKey('activity-layout-${l.name}'),
            leadingIcon: Icon(
              l == ActivityLayout.timeline
                  ? Icons.view_day_outlined
                  : Icons.table_rows_outlined,
            ),
            trailingIcon: l == layout ? const Icon(Icons.check) : null,
            onPressed: () => setState(() => layout = l),
            child: Text(l.label),
          ),
        const Divider(height: 1),
        MenuItemButton(
          key: const ValueKey('activity-open-page'),
          leadingIcon: const Icon(Icons.open_in_full),
          onPressed: () => openDemoPage<void>(
            context,
            StatementPage(title: accountName ?? 'Activity', list: list),
            'money/statement',
          ),
          child: const Text('Open as a page'),
        ),
      ],
    );
    final title = filter.searching ? 'Search results' : heading;
    final caption = [
      '${rows.length} ${rows.length == 1 ? 'record' : 'records'}',
      ?accountName,
      ?filter.category,
    ].join(' · ');
    final card = layout == ActivityLayout.list
        ? OverviewCard(
            key: const ValueKey('activity-list-card'),
            title: title,
            caption: caption,
            corner: menu,
            child: list,
          )
        : ActivityListCard(
            key: const ValueKey('money-activity'),
            title: title,
            caption: caption,
            corner: menu,
            rows: rows,
            today: today,
            amount: amount,
            hidden: hidden,
            onOpen: actions.openRecord,
            empty: all.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No activity yet',
                    message: 'What you log shows here.',
                    action: AppButton(
                      'Log expense',
                      icon: Icons.add,
                      onPressed: () => actions.logExpense(null),
                    ),
                  )
                : EmptyState(
                    icon: Icons.search_off,
                    title: 'Nothing matches',
                    message: 'Try other words, or clear what’s narrowing this.',
                    action: AppButton.secondary(
                      'Clear filters',
                      onPressed: clear,
                    ),
                  ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        band(),
        const SizedBox(height: Space.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MiniSegmented<ActivityType>(
            key: const ValueKey('activity-type'),
            label: 'Type',
            options: [for (final t in ActivityType.values) (t, t.label)],
            selected: filter.type,
            onSelected: (t) =>
                setState(() => filter = filter.copyWith(type: t)),
          ),
        ),
        if (filter.filters > 0) ...[
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              if (accountName != null)
                ChipButton(
                  accountName,
                  key: const ValueKey('remove-account'),
                  icon: Icons.close,
                  onPressed: () => removeFilter(account: true),
                ),
              if (filter.category != null)
                ChipButton(
                  filter.category!,
                  key: const ValueKey('remove-category'),
                  icon: Icons.close,
                  onPressed: () => removeFilter(category: true),
                ),
              if (filter.period == ActivityPeriod.custom)
                ChipButton(
                  heading,
                  key: const ValueKey('remove-dates'),
                  icon: Icons.close,
                  onPressed: () => removeFilter(dates: true),
                ),
            ],
          ),
        ],
        SizedBox(height: Space.cardGapOf(context)),
        StatStrip(
          key: const ValueKey('activity-totals'),
          stats: [
            (label: 'Records', value: '${rows.length}', detail: null),
            (label: 'Money in', value: amount(totals.moneyIn), detail: null),
            (label: 'Money out', value: amount(totals.moneyOut), detail: null),
            (
              label: 'Change',
              value: signedAmount(change, amount, hidden: hidden),
              detail: null,
            ),
          ],
        ),
        SizedBox(height: Space.cardGapOf(context)),
        card,
      ],
    );
  }
}

/// Sends the shell to where dues are handled.
void openDues(BuildContext context) =>
    ShellNavigation.maybeOf(context)
        ?.select(AppDestination.debts, tab: 'Schedule');
