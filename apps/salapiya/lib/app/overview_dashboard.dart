import 'package:flutter/material.dart';

import '../connected/connection_view.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../features/finance/contracts/financial_models.dart';
import '../features/finance/presentation/financial_editor.dart';
import '../finance/money_data.dart';
import '../finance/money_details.dart' show localMoneySource, openMoneyRecord;
import '../finance/planning_cards.dart';
import '../features/life/application/life_controller.dart' show AgendaItem;
import '../features/life/presentation/life_screen.dart';
import '../life/life_cards.dart' show nextUpRow;
import '../life/life_controller.dart';
import '../life/life_data.dart' show LifeRow;
import '../life/life_hub.dart' show lifeHubOf;
import '../local/finance_domain.dart';
import '../local/local_runtime.dart';
import '../prototype/scenarios.dart';
import 'overview_cards.dart';
import 'overview_controls.dart';
import 'overview_data.dart';
import 'overview_demo.dart';

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
  'Sunday',
];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

/// "Friday, 30 October 2026".
String overviewLongDate(String date) {
  final d = DateTime.parse(date);
  return '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "30 Sep".
String _dayMonth(String date) {
  final d = DateTime.parse(date);
  return '${d.day} ${_months[d.month - 1].substring(0, 3)}';
}

/// Everything the Overview reads. A real profile fills it from its session
/// ([localOverviewSource]); the demo build from its sample profile
/// (`demoOverviewSource`).
class OverviewSource {
  const OverviewSource({
    required this.today,
    required this.accepted,
    required this.current,
    required this.complete,
    required this.hidden,
    required this.available,
    required this.amount,
    required this.categoryName,
    required this.shared,
    required this.life,
    required this.recent,
    required this.openRecord,
    required this.openItem,
    this.cards,
    this.pending = false,
    this.pendingCount = 0,
    this.projected,
    this.needsReview = false,
    this.lifeMore = 0,
    this.activityCount = 0,
    this.syncLabel = '',
    this.onReview,
    this.onAddAccount,
  });
  final String today;

  /// Money metrics use [accepted] history; dues and debt progress use
  /// [current] records, as the Debts screen does.
  final LocalSnapshot accepted, current;
  final bool complete, hidden, pending, needsReview;

  /// How many more of Life's next items there are than [life] shows.
  final int lifeMore;

  /// How many rows Activity holds through today, so a list of [recent]
  /// can say how many more there are.
  final int activityCount;
  final int pendingCount;
  final BigInt? available, projected;
  final String syncLabel;
  final Amount amount;
  final String Function(String?) categoryName;

  /// Card debt and available credit, when the profile has a card.
  final (BigInt, BigInt)? cards;
  final List<OverviewRow> shared, life;

  /// The newest activity, newest first (up to 10).
  final List<ActivityRow> recent;

  /// Opens one record by its revision id.
  final void Function(String id, String title) openRecord;

  /// A card statement, plan or recurring item on its own page.
  final void Function(String id) openItem;
  final VoidCallback? onReview, onAddAccount;
}

/// The Overview's source for a real profile.
OverviewSource localOverviewSource(
  BuildContext context,
  LocalSession session,
  ValueChanged<PreviewSource> open,
) {
  final c = session.localFinance;
  final today = civilToday();
  final hasCards = c.snapshot.current.any(
    (r) => financeType(r) == 'creditCard',
  );
  final connected = session.runtime.connected;
  final life = session.life;
  final agenda = life is DurableLifeController
      ? [
          for (final item in life.agendaWindow(
            session.finance,
            today,
            addCivilDays(today, 30),
            financial: false,
            timezone: life.displayTimezone,
          ))
            if (life.calendarVisible(item.kind)) item,
        ]
      : const <AgendaItem>[];
  // Activity's rows through today, newest first, as Money lists them.
  final logged = moneyActivity(
    c.snapshot,
    c.categoryName,
  ).where((r) => r.date.compareTo(today) <= 0).toList();
  void openRecord(String id, String title) =>
      openMoneyRecord(context, c, id, session: session);
  return OverviewSource(
    today: today,
    accepted: c.acceptedSnapshot,
    current: c.snapshot,
    complete: session.complete,
    hidden: session.hideAmounts,
    available: session.accepted,
    amount: session.amount,
    categoryName: c.categoryName,
    cards: hasCards ? c.cardLiabilityAndCredit : null,
    pending: session.pending,
    pendingCount: session.pendingCount,
    projected: session.projected,
    needsReview: session.needsReview,
    syncLabel: session.syncLabel,
    onReview: () => openConnection(context, session.runtime),
    onAddAccount: () =>
        openFinancialEditor(context, c, FinancialAction.account),
    openRecord: openRecord,
    openItem: (id) =>
        localMoneySource(context, c, session).actions.openItem(id),
    shared: [
      for (final (count, one, many, source) in [
        (
          connected.needMyConfirmation,
          'payment to confirm',
          'payments to confirm',
          PreviewSource.settlement,
        ),
        (
          connected.waitingForOthers,
          'payment waiting for others',
          'payments waiting for others',
          PreviewSource.settlement,
        ),
        (
          connected.sharedPendingCount,
          'change waiting for the group',
          'changes waiting for the group',
          PreviewSource.group,
        ),
        (
          connected.sharedReviewCount,
          'change was rejected or restored',
          'changes were rejected or restored',
          PreviewSource.group,
        ),
        (
          connected.changedPrivateSources,
          'linked record changed',
          'linked records changed',
          PreviewSource.privateReview,
        ),
      ])
        if (count > 0)
          (
            icon: Icons.people_outline,
            title: '$count ${count == 1 ? one : many}',
            subtitle: null,
            amount: null,
            onTap: () => open(source),
          ),
    ],
    life: [
      for (final item in agenda.take(3))
        nextUpRow(
          context,
          LifeRow.record(
            item,
            (life as DurableLifeController).records,
            today,
            life.displayTimezone,
          ),
          () => openLifeSource(context, session, item),
        ),
    ],
    lifeMore: agenda.length > 3 ? agenda.length - 3 : 0,
    activityCount: logged.length,
    recent: [
      for (final r in logged.take(10))
        (
          icon: moneyIcon(r),
          title: r.title,
          date: r.date,
          category: r.categoryLabel.isEmpty ? r.label : r.categoryLabel,
          amount: r.shown(session.amount, hidden: session.hideAmounts),
          onTap: () => openRecord(r.id, r.title),
        ),
    ],
  );
}

/// The Overview's tabs (owner review, 2026-10-30).
enum OverviewTab {
  summary('Summary'),
  spending('Spending'),
  debts('Debts & Dues'),
  accounts('Accounts & Activity');

  const OverviewTab(this.label);
  final String label;
}

/// The Overview (Chat 6): where your money stands, what is due and what
/// changed, in four tabs. Real profiles and the demo build share it.
class OverviewDashboard extends StatefulWidget {
  const OverviewDashboard({
    super.key,
    required this.session,
    required this.open,
    this.actions = const [],
  });
  final PrototypeSession session;
  final ValueChanged<PreviewSource> open;

  /// Quick actions in the header: the shell's first New items. Windows
  /// only; Android has the + button above the dock for the same actions.
  final List<QuickAction> actions;
  @override
  State<OverviewDashboard> createState() => _OverviewDashboardState();
}

class _OverviewDashboardState extends State<OverviewDashboard> {
  OverviewTab tab = OverviewTab.summary;

  ValueChanged<PreviewSource> get open => widget.open;

  void _openDue(OverviewSource source, FinancialReminderSource s) =>
      s.kind == 'Debt due'
      ? open(PreviewSource.debt)
      : source.openItem(s.source);

  Future<void> _calendar(BuildContext context, String today) async {
    var picked = today;
    final go = await showAppSheet<bool>(
      context,
      title: 'Calendar',
      body: CalendarDatePicker(
        key: const ValueKey('overview-calendar'),
        initialDate: DateTime.parse(today),
        currentDate: DateTime.parse(today),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        onDateChanged: (d) => picked = DateTime.utc(
          d.year,
          d.month,
          d.day,
        ).toIso8601String().substring(0, 10),
      ),
      primary: const ModalAction('Open Life › Calendar', value: true),
      secondary: const ModalAction.cancel(label: 'Close'),
    );
    if (go == true) {
      lifeHubOf(widget.session).select(picked);
      open(PreviewSource.agenda);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final source = session is LocalSession
        ? localOverviewSource(context, session, open)
        : demoOverviewSource(context, session, open);
    final android = !isDesktop(context);
    final theme = CraftTheme.of(context);
    final accepted = source.accepted, current = source.current;
    final complete = source.complete, hidden = source.hidden;
    final today = source.today, start = monthStart(today);
    final amount = source.amount;
    String? known(BigInt v) => complete ? amount(v) : null;
    final showTrend = complete && !hidden;

    final sources = complete
        ? overviewDueSources(current, today)
        : const <FinancialReminderSource>[];
    final week = OverviewDues.from(sources, today, DuePeriod.week);
    final month = OverviewDues.from(sources, today, DuePeriod.month);
    final debts = complete
        ? overviewDebtProgress(current, today)
        : const <DebtProgress>[];
    final categories = complete
        ? spendingByCategory(accepted, start, today, source.categoryName)
        : const <(String, BigInt)>[];
    final daily = dailySpending(accepted, start, today);
    final comparison = complete ? SpendingComparison(accepted, today) : null;
    final owed = debtBalanceByMonth(accepted, today);
    final budgets = complete
        ? activeBudgets(accepted, today)
        : const <BudgetProgress>[];
    final insights = complete
        ? overviewInsights(
            week: week,
            comparison: comparison,
            categories: categories,
            budgets: budgets,
            amount: amount,
            hidden: hidden,
          )
        : const <String>[];
    final range = overviewSpan(start, today);
    final period = '$range · refunds subtracted';
    final lastMonthEnd = addCivilDays(start, -1);
    final accountIds = [for (final a in accepted.accounts) a.id];
    final balances = balanceByDay(
      accepted,
      accountIds,
      addCivilDays(today, -29),
      today,
    );

    // Android: one compact row, the date (it opens the calendar) and, at
    // the end, a pill for what is overdue or due this week, which opens the
    // Debts & Dues tab.
    final duesCount = week.overdue.isNotEmpty
        ? week.overdue.length
        : week.upcoming.length;
    final duesPill = !complete || duesCount == 0
        ? null
        : week.overdue.isNotEmpty
        ? StatusPill(
            '$duesCount overdue',
            icon: Icons.error_outline,
            tone: PillTone.overdue,
          )
        : StatusPill(
            '$duesCount due this week',
            icon: Icons.event_outlined,
            tone: PillTone.information,
          );
    final dateButton = Semantics(
      container: true,
      button: true,
      label: '${overviewLongDate(today)}. Open the calendar',
      onTap: () => _calendar(context, today),
      excludeSemantics: true,
      child: Pressable(
        key: const ValueKey('overview-date'),
        onTap: () => _calendar(context, today),
        padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Space.target),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: Space.lg + Space.xxs,
                color: theme.primary,
              ),
              const SizedBox(width: Space.sm),
              Flexible(
                child: Text(
                  overviewLongDate(today),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: Space.xxs),
              Icon(
                Icons.chevron_right,
                size: Space.lg + Space.xxs,
                color: theme.secondary,
              ),
            ],
          ),
        ),
      ),
    );
    final pillButton = duesPill == null
        ? null
        : Semantics(
            container: true,
            button: true,
            label: '${duesPill.label}. Open Debts & Dues',
            onTap: () => setState(() => tab = OverviewTab.debts),
            excludeSemantics: true,
            child: TouchArea(
              onTap: () => setState(() => tab = OverviewTab.debts),
              child: Pressable(
                key: const ValueKey('overview-dues-pill'),
                onTap: () => setState(() => tab = OverviewTab.debts),
                radius: Radii.pill,
                child: duesPill,
              ),
            ),
          );
    final header = android
        ? LayoutBuilder(
            // The pill drops under the date when large text can't hold both.
            builder: (context, box) => narrowAt(context, box.maxWidth)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [dateButton, ?pillButton],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: dateButton,
                        ),
                      ),
                      if (pillButton != null) ...[
                        const SizedBox(width: Space.sm),
                        pillButton,
                      ],
                    ],
                  ),
          )
        : LayoutBuilder(
            builder: (context, box) {
              final title = PageHeader(
                'Overview',
                caption: overviewLongDate(today),
              );
              final quick = QuickActions(
                key: const ValueKey('overview-quick-actions'),
                actions: widget.actions,
              );
              if (widget.actions.isEmpty) return title;
              // Beside the title when wide, ending at the content's right
              // edge (the cards' edge), wrapping from the end if needed.
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
                              key: const ValueKey('overview-quick-actions'),
                              actions: widget.actions,
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
                        quick,
                      ],
                    );
            },
          );

    final notices = [
      if (!complete)
        const InlineNotice(
          'Money totals show once all your records have downloaded.',
          title: 'Your first download isn’t finished',
          tone: NoticeTone.warning,
        ),
      if (source.pending)
        InlineNotice(
          '${source.pendingCount} ${source.pendingCount == 1 ? 'change is' : 'changes are'} waiting to sync. Totals use synced records. '
          'With waiting changes, available money is ${source.projected == null ? MoneyAmount.unknown.toLowerCase() : amount(source.projected!)}.',
          live: true,
        ),
      if (source.needsReview) SyncReviewNotice(onReview: source.onReview),
    ];

    // KPI tiles: value, change and sparkline (hidden with amounts).
    final spent = spendingBetween(accepted, start, today);
    const kpiLabels = [
      'Available money',
      'Spent this month',
      'Income this month',
      'What you owe',
    ];
    final income = incomeBetween(accepted, start, today);
    final tiles = [
      KpiTile(
        labels: kpiLabels,
        key: const ValueKey('overview-available'),
        accent: true,
        icon: Icons.account_balance_wallet_outlined,
        label: 'Available money',
        value: MoneyAmount(
          source.available == null ? null : amount(source.available!),
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        change: showTrend && source.available != null
            ? ChangeLine(
                basisPoints: changeBasisPoints(
                  balances.last.$2,
                  sumMinor(
                    balanceByDay(
                      accepted,
                      accountIds,
                      lastMonthEnd,
                      lastMonthEnd,
                    ).map((d) => d.$2),
                  ),
                ),
                versus: 'since ${_dayMonth(lastMonthEnd)}',
                meaning: ChangeMeaning.riseIsGood,
              )
            : null,
        spark: showTrend ? [for (final b in balances) b.$2] : const [],
        caption: 'Cash and bank · card credit excluded',
        onTap: () => open(PreviewSource.accounts),
      ),
      KpiTile(
        labels: kpiLabels,
        key: const ValueKey('overview-spent'),
        icon: Icons.north_east,
        label: 'Spent this month',
        value: MoneyAmount(
          known(spent),
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        change: showTrend && comparison != null
            ? ChangeLine(
                basisPoints: changeBasisPoints(
                  comparison.currentTotal,
                  comparison.previousTotal,
                ),
                versus:
                    'vs ${overviewSpan(comparison.previousStart, comparison.previousEnd)}',
                meaning: ChangeMeaning.riseIsBad,
              )
            : null,
        spark: showTrend && comparison != null
            ? SpendingComparison.running(comparison.current)
            : const [],
        caption: 'Refunds subtracted',
      ),
      KpiTile(
        labels: kpiLabels,
        key: const ValueKey('overview-income'),
        icon: Icons.south_west,
        label: 'Income this month',
        value: MoneyAmount(
          known(income),
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        change: showTrend && comparison != null
            ? ChangeLine(
                basisPoints: changeBasisPoints(
                  income,
                  incomeBetween(
                    accepted,
                    comparison.previousStart,
                    comparison.previousEnd,
                  ),
                ),
                versus:
                    'vs ${overviewSpan(comparison.previousStart, comparison.previousEnd)}',
                meaning: ChangeMeaning.riseIsGood,
              )
            : null,
        spark: showTrend
            ? SpendingComparison.running(dailyIncome(accepted, start, today))
            : const [],
        caption: 'Borrowed money isn’t income',
      ),
      KpiTile(
        labels: kpiLabels,
        key: const ValueKey('overview-owed'),
        icon: Icons.account_balance_outlined,
        label: 'What you owe',
        value: MoneyAmount(
          known(owed.last.$2),
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        change: showTrend
            ? ChangeLine(
                basisPoints: changeBasisPoints(
                  owed.last.$2,
                  owed[owed.length - 2].$2,
                ),
                versus: 'since ${_dayMonth(owed[owed.length - 2].$1)}',
                meaning: ChangeMeaning.riseIsBad,
              )
            : null,
        spark: showTrend ? [for (final p in owed) p.$2] : const [],
        caption: 'Debts through today · cards are separate',
        onTap: () => open(PreviewSource.debt),
      ),
    ];

    final spendingCard = SpendingCard(
      key: const ValueKey('overview-spending'),
      top: categories.where((c) => c.$2 > BigInt.zero).firstOrNull,
      daily: daily,
      comparison: comparison,
      amount: amount,
      caption: period,
      range: range,
      available: complete,
      hidden: hidden,
    );

    String monthLabel(String date) => date == today
        ? 'Today'
        : _months[DateTime.parse(date).month - 1].substring(0, 3);
    final owedCard = OwedCard(
      key: const ValueKey('overview-owed-trend'),
      owed: owed,
      debts: debts,
      amount: amount,
      monthLabel: monthLabel,
      available: complete,
      hidden: hidden,
    );

    final sharedCard = source.shared.isEmpty
        ? null
        : RowsCard(
            key: const ValueKey('overview-shared'),
            title: 'Shared Expenses',
            caption: 'What needs you in your groups',
            rows: source.shared,
            action: CardLink(
              'Open',
              onPressed: () => open(PreviewSource.group),
            ),
            empty: const SizedBox.shrink(),
          );

    final lifeCard = RowsCard(
      key: const ValueKey('overview-life'),
      title: 'Next up in Life',
      caption: 'What’s coming up in the next 30 days',
      rows: source.life,
      action: CardLink(
        'Open Life',
        onPressed: () => open(PreviewSource.agenda),
      ),
      footer: source.lifeMore > 0
          ? ListEnd(
              label: '${source.lifeMore} more on the Calendar',
              onPressed: () => open(PreviewSource.agenda),
            )
          : const ListEnd(),
      empty: EmptyState(
        icon: Icons.event_outlined,
        title: 'Nothing planned',
        message: 'Tasks and events for the next 30 days show here.',
        action: AppButton.secondary(
          'Open Life',
          onPressed: () => open(PreviewSource.agenda),
        ),
      ),
    );

    ActivityCard activity(Key key, int count) => ActivityCard(
      key: key,
      title: 'Recent activity',
      rows: complete ? source.recent.take(count).toList() : const [],
      action: CardLink(
        'View all',
        onPressed: () => open(PreviewSource.activity),
      ),
      footer: source.activityCount > count
          ? ListEnd(
              label: '${source.activityCount - count} more in Activity',
              onPressed: () => open(PreviewSource.activity),
            )
          : const ListEnd(),
      empty: !complete
          ? const NotAvailable('Activity shows once your records are complete.')
          : const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No activity yet',
              message: 'Expenses, income and transfers you log show here.',
            ),
    );

    // Every expense this month, largest first; the card shows five.
    final spending = complete
        ? largestExpenses(
            accepted,
            start,
            today,
            count: accepted.current.length,
          )
        : const <(LocalRevision, BigInt)>[];
    final largest = spending.take(5).toList();
    final largestCard = ActivityCard(
      key: const ValueKey('overview-largest'),
      title: 'Largest expenses this month',
      caption: range,
      rows: [
        for (final (r, value) in largest)
          (
            icon: Icons.north_east,
            title: r.title,
            date: r.date,
            category: source.categoryName(
              r.postings.firstWhere((p) => p.ledger == 'expense').category,
            ),
            amount: amount(value),
            onTap: () => source.openRecord(r.id, r.title),
          ),
      ],
      action: CardLink(
        'View all',
        onPressed: () => open(PreviewSource.activity),
      ),
      footer: spending.length > largest.length
          ? ListEnd(
              label:
                  '${spending.length - largest.length} more ${spending.length - largest.length == 1 ? 'expense' : 'expenses'} in Activity',
              onPressed: () => open(PreviewSource.activity),
            )
          : const ListEnd(),
      empty: !complete
          ? const NotAvailable('Spending shows once your records are complete.')
          : const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No spending this month',
              message: 'Your largest expenses this month show here.',
            ),
    );

    final dues = DuesCard(
      key: const ValueKey('overview-dues'),
      week: week,
      month: month,
      amount: amount,
      onOpen: (due) => _openDue(source, due),
      available: complete,
      shown: tab == OverviewTab.summary ? 4 : 6,
    );
    final progress = DebtProgressCard(
      key: const ValueKey('overview-debts'),
      debts: debts,
      amount: amount,
      onOpen: () => open(PreviewSource.debt),
      available: complete,
      hidden: hidden,
    );
    final category = CategoryCard(
      key: const ValueKey('overview-categories'),
      categories: categories,
      amount: amount,
      caption: period,
      onOpen: () => open(PreviewSource.reports),
      available: complete,
      hidden: hidden,
    );
    final budgetsCard = BudgetsCard(
      key: const ValueKey('overview-budgets'),
      budgets: budgets,
      amount: amount,
      onOpen: () => open(PreviewSource.planning),
    );
    final insightsCard = insights.isEmpty
        ? null
        : InsightsCard(
            key: const ValueKey('overview-insights'),
            insights: insights,
          );

    final accountCards = <Widget>[
      if (complete)
        for (final a in accepted.accounts.where((a) => !a.archived))
          AccountMiniCard(
            key: ValueKey('overview-account-${a.id}'),
            icon: switch (a.kind) {
              'Cash' => Icons.payments_outlined,
              'Mobile wallet' => Icons.phone_iphone,
              _ => Icons.account_balance_outlined,
            },
            name: a.name,
            kind: a.kind,
            balance: amount(accepted.balance(a.id, through: today)),
            spark: hidden
                ? const []
                : [
                    for (final b in balanceByDay(
                      accepted,
                      [a.id],
                      addCivilDays(today, -29),
                      today,
                    ))
                      b.$2,
                  ],
            caption: hidden ? null : 'Last 30 days',
            onTap: () => open(PreviewSource.accounts),
          ),
      if (complete && source.cards != null)
        AccountMiniCard(
          key: const ValueKey('overview-card-debt'),
          icon: Icons.credit_card_outlined,
          name: 'Card debt',
          kind: 'Credit cards',
          balance: amount(source.cards!.$1),
          caption:
              'Available credit ${amount(source.cards!.$2)}, not money you have',
          onTap: () => open(PreviewSource.cards),
        ),
    ];
    final noAccounts = SurfaceCard(
      key: const ValueKey('overview-accounts'),
      child: !complete
          ? const NotAvailable('Balances show once your records are complete.')
          : EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No accounts yet',
              message:
                  'Add a cash wallet or bank account to see its balance here.',
              action: source.onAddAccount == null
                  ? null
                  : AppButton.secondary(
                      'Add account',
                      onPressed: source.onAddAccount!,
                    ),
            ),
    );

    // Each card with its span on the 12-column grid when wide and when
    // medium, in reading order. Phones and narrow windows stack [stacked]
    // in priority order instead (§2).
    final (List<GridCard> wide, List<Widget> stacked) = switch (tab) {
      OverviewTab.summary => (
        [
          for (final t in tiles) (t, 3, 6),
          (spendingCard, 8, 12),
          (dues, 4, 12),
          (
            activity(const ValueKey('overview-recent'), 5),
            insightsCard == null ? 12 : 8,
            12,
          ),
          ?(insightsCard == null ? null : (insightsCard, 4, 12)),
          (lifeCard, sharedCard == null ? 12 : 6, sharedCard == null ? 12 : 6),
          ?(sharedCard == null ? null : (sharedCard, 6, 6)),
        ],
        [
          ...tiles,
          ?insightsCard,
          dues,
          spendingCard,
          activity(const ValueKey('overview-recent'), 5),
          lifeCard,
          ?sharedCard,
        ],
      ),
      OverviewTab.spending => (
        [(category, 5, 12), (budgetsCard, 7, 12), (largestCard, 12, 12)],
        [category, budgetsCard, largestCard],
      ),
      OverviewTab.debts => (
        [(dues, 6, 12), (owedCard, 6, 12), (progress, 12, 12)],
        [dues, progress, owedCard],
      ),
      OverviewTab.accounts => (
        [
          if (accountCards.isEmpty)
            (noAccounts, 12, 12)
          else
            for (final a in accountCards) (a, 3, 6),
          (activity(const ValueKey('overview-activity'), 10), 12, 12),
        ],
        [
          if (accountCards.isEmpty) noAccounts else ...accountCards,
          activity(const ValueKey('overview-activity'), 10),
        ],
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        // Android's header row is already a 48 target; keep the tabs close.
        SizedBox(height: android ? Space.xs : Space.lg),
        AppTabs<OverviewTab>(
          key: const ValueKey('overview-tabs'),
          tabs: [for (final t in OverviewTab.values) (t, t.label)],
          selected: tab,
          onSelected: (t) => setState(() => tab = t),
        ),
        SizedBox(height: Space.cardGapOf(context) + Space.xs),
        for (final n in notices) ...[
          n,
          SizedBox(height: Space.cardGapOf(context)),
        ],
        DashboardGrid(
          key: ValueKey(('overview-grid', tab)),
          cards: android ? null : wide,
          stacked: stacked,
        ),
      ],
    );
  }
}
