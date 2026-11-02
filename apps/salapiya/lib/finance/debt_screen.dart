import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_cards.dart';
import '../app/overview_dashboard.dart' show overviewLongDate;
import '../app/overview_data.dart';
import '../app/shell_navigation.dart';
import '../connected/connection_view.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import '../local/local_finance_controller.dart';
import '../local/local_runtime.dart';
import '../p0/exact_money.dart';
import '../prototype/scenarios.dart';
import 'debt_cards.dart';
import 'debt_data.dart';
import 'finance_screen.dart';
import 'form_mechanics.dart';

/// The pill for one debt, as everywhere in Debts.
class DebtStatusBadge extends StatelessWidget {
  const DebtStatusBadge(this.debt, {super.key});
  final DebtProgress debt;
  @override
  Widget build(BuildContext context) => DebtProgressCard.pill(debt);
}

/// What the Debts screens read for a real profile. Without a [session], as
/// in the editors' own tests, the records count as fully downloaded.
DebtsSource localDebtsSource(
  BuildContext context,
  LocalFinancialController c,
  PrototypeSession? session,
) {
  Future<void> editor(
    String op,
    String title, {
    Map<String, String> initial = const {},
    LocalRevision? replacing,
  }) => openNativeFinance(
    context,
    c,
    op,
    title,
    initial: initial,
    replacing: replacing,
  );
  return DebtsSource(
    today: civilToday(),
    snapshot: c.snapshot,
    complete: session?.complete ?? true,
    hidden: session?.hideAmounts ?? c.amountsHidden,
    amount:
        session?.amount ??
        (v) => c.amountsHidden ? 'Amount hidden' : c.amount(v),
    pending: session?.pending ?? false,
    pendingCount: session is LocalSession ? session.pendingCount : 0,
    needsReview: session?.needsReview ?? false,
    syncLabel: session?.syncLabel ?? '',
    onReview: session is LocalSession
        ? () => openConnection(context, session.runtime)
        : null,
    actions: DebtActions(
      logPayment: (debt, payment) => editor(
        'debtPayment',
        'Log a debt payment',
        initial: debt == null ? const {} : debtPaymentInitial(debt, payment),
      ),
      addDebt: () => editor('debtImport', 'Add a debt'),
      newLoan: () => editor('borrowing', 'Log a new loan'),
      schedule: (d) => d.due.schedule == null
          ? editor('debtSchedule', 'Set schedule', initial: {'debt': d.debt.id})
          : editor(
              'financeCorrection',
              'Edit schedule',
              replacing: d.due.schedule,
            ),
      updateAmounts: (d) => openDemoPage<void>(
        context,
        NativeScheduleAmounts(controller: c, scheduleId: d.due.schedule!.id),
        'debt/amounts/${d.due.schedule!.id}',
      ),
      breakDown: (d, payment) => editor(
        'debtClassification',
        'Break down a payment',
        initial: {'debt': d.debt.id, 'payment': ?payment},
      ),
      lenderCharge: (d) => editor(
        'debtAdjustment',
        'Log a lender charge or waiver',
        initial: {'debt': d.debt.id},
      ),
      earlyPayoff: (d) => editor(
        'debtPayoff',
        'Log an early payoff',
        initial: {
          'debt': d.debt.id,
          'amount': phpDecimal(d.outstanding),
          'reduction': phpDecimal(d.outstanding),
        },
      ),
      openDebt: (d) => openDemoPage<void>(
        context,
        NativeDebtDetail(controller: c, debtId: d.debt.id, session: session),
        'debt/${d.debt.id}',
        title: d.debt.title,
      ),
      openRecord: (id) => openFinanceDetail(context, c, id),
    ),
  );
}

/// The Debts section for a real profile.
class NativeDebtsScreen extends StatelessWidget {
  const NativeDebtsScreen({
    super.key,
    required this.controller,
    this.session,
    this.initial,
    this.actions = const [],
  });
  final LocalFinancialController controller;
  final PrototypeSession? session;
  final String? initial;
  final List<QuickAction> actions;
  @override
  Widget build(BuildContext context) => DebtsDashboard(
    listenable: session == null
        ? controller
        : Listenable.merge([controller, session]),
    source: (context) => localDebtsSource(context, controller, session),
    initial: initial,
    actions: actions,
  );
}

/// The Debts section: what you owe, what's next and what's late on Summary,
/// the detail in the other tabs (DESIGN_SYSTEM §2 Debts).
class DebtsDashboard extends StatefulWidget {
  const DebtsDashboard({
    super.key,
    required this.listenable,
    required this.source,
    this.initial,
    this.actions = const [],
  });
  final Listenable listenable;
  final DebtsSource Function(BuildContext context) source;

  /// The tab to open on, by its label.
  final String? initial;

  /// Quick actions in the header: the shell's New items. Windows only;
  /// Android has the + button above the dock for the same actions.
  final List<QuickAction> actions;
  @override
  State<DebtsDashboard> createState() => _DebtsDashboardState();
}

class _DebtsDashboardState extends State<DebtsDashboard> {
  late DebtsTab tab = DebtsTab.of(widget.initial);
  DuePeriod period = DuePeriod.week;
  DuesView view = DuesView.calendar;
  bool debtsOnly = false;

  void select(DebtsTab next) {
    ShellNavigation.reportTab(context, next.label);
    setState(() => tab = next);
  }

  void openDue(
    DebtsSource source,
    List<DebtProgress> debts,
    FinancialReminderSource due,
  ) {
    final debt = debts
        .where((d) => d.due.schedule?.id == due.source)
        .firstOrNull;
    debt == null
        ? source.actions.openRecord(due.source)
        : source.actions.openDebt(debt);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.listenable,
    builder: (context, _) => dashboard(context, widget.source(context)),
  );

  Widget dashboard(BuildContext context, DebtsSource source) {
    final android = !isDesktop(context);
    final s = source.snapshot, today = source.today;
    final complete = source.complete, hidden = source.hidden;
    final amount = source.amount, actions = source.actions;
    final trend = complete && !hidden;
    String? known(BigInt v) => complete ? amount(v) : null;

    final debts = complete
        ? overviewDebtProgress(s, today)
        : const <DebtProgress>[];
    final summary = DebtsSummary(debts, today);
    final owed = debtBalanceByMonth(s, today);
    final scoped = complete
        ? [
            for (final r in overviewDueSources(s, today))
              if (!debtsOnly || r.kind == 'Debt due') r,
          ]
        : const <FinancialReminderSource>[];
    final week = OverviewDues.from(scoped, today, DuePeriod.week);
    final month = OverviewDues.from(scoped, today, DuePeriod.month);
    final debtWeek = OverviewDues.from(
      [
        if (complete)
          for (final r in overviewDueSources(s, today))
            if (r.kind == 'Debt due') r,
      ],
      today,
      DuePeriod.week,
    );

    void openList() => openDemoPage<void>(
      context,
      DuesListPage(
        dues: period == DuePeriod.week ? week : month,
        amount: amount,
        onOpen: (due) => openDue(source, debts, due),
      ),
      'debts/list',
    );

    // Android: one compact row, the date and, at the end, a pill for what is
    // overdue or due this week, which opens Schedule.
    final dueCount = summary.overdue.isNotEmpty
        ? summary.overdue.length
        : debtWeek.upcoming.length;
    final duePill = !complete || dueCount == 0
        ? null
        : summary.overdue.isNotEmpty
        ? StatusPill(
            '$dueCount overdue',
            icon: Icons.error_outline,
            tone: PillTone.overdue,
          )
        : StatusPill(
            '$dueCount due this week',
            icon: Icons.event_outlined,
            tone: PillTone.information,
          );
    final title = PageHeader(
      'Debts',
      caption: complete
          ? 'As of ${overviewLongDate(today)} · ${debts.length} ${debts.length == 1 ? 'debt' : 'debts'}'
          : 'As of ${overviewLongDate(today)}',
    );
    final dateLine = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Space.target),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: Space.lg + Space.xxs,
            color: CraftTheme.of(context).primary,
          ),
          const SizedBox(width: Space.sm),
          Flexible(
            child: Text(
              overviewLongDate(today),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
    final pillButton = duePill == null
        ? null
        : Semantics(
            container: true,
            onTap: () => select(DebtsTab.schedule),
            button: true,
            label: '${duePill.label}. Open Schedule',
            excludeSemantics: true,
            child: TouchArea(
              onTap: () => select(DebtsTab.schedule),
              child: Pressable(
                key: const ValueKey('debts-dues-pill'),
                onTap: () => select(DebtsTab.schedule),
                radius: Radii.pill,
                child: duePill,
              ),
            ),
          );
    final header = android
        ? LayoutBuilder(
            // The pill drops under the date when large text can't hold both.
            builder: (context, box) => narrowAt(context, box.maxWidth)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [dateLine, ?pillButton],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: dateLine,
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
                              key: const ValueKey('debts-quick-actions'),
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
                        QuickActions(
                          key: const ValueKey('debts-quick-actions'),
                          actions: widget.actions,
                        ),
                      ],
                    );
            },
          );

    final notices = [
      if (!complete)
        const InlineNotice(
          'Debt totals show once all your records have downloaded.',
          title: 'Your first download isn’t finished',
          tone: NoticeTone.warning,
        ),
      if (source.pending)
        InlineNotice(
          '${source.pendingCount} ${source.pendingCount == 1 ? 'change is' : 'changes are'} waiting to sync. Debts include them, so totals here can differ from the Overview until they sync.',
          live: true,
        ),
      if (source.needsReview)
        SyncReviewNotice(onReview: source.onReview),
    ];

    // Summary's tiles: the four answers, with the trend hidden with amounts.
    const tileLabels = [
      'What you owe',
      'Overdue',
      'Next payment',
      'Due this month',
    ];
    final next = summary.next;
    final overdue = summary.overdue;
    final tiles = <Widget>[
      KpiTile(
        key: const ValueKey('debts-owed'),
        labels: tileLabels,
        accent: true,
        compactSpark: true,
        icon: Icons.account_balance_outlined,
        label: 'What you owe',
        value: MoneyAmount(
          known(summary.owed),
          kind: MoneyKind.owed,
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        change: trend
            ? ChangeLine(
                basisPoints: changeBasisPoints(
                  owed.last.$2,
                  owed[owed.length - 2].$2,
                ),
                versus: 'since ${civilLabel(owed[owed.length - 2].$1)}',
                meaning: ChangeMeaning.riseIsBad,
              )
            : null,
        spark: trend ? [for (final p in owed) p.$2] : const [],
        caption: 'Debts through today · cards are separate',
      ),
      KpiTile(
        key: const ValueKey('debts-overdue'),
        labels: tileLabels,
        icon: Icons.error_outline,
        label: 'Overdue',
        value: MoneyAmount(
          known(summary.overdueTotal),
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        caption: !complete
            ? null
            : overdue.isEmpty
            ? 'Nothing overdue'
            : '${overdue.length} ${overdue.length == 1 ? 'payment' : 'payments'} · oldest ${summary.oldestOverdueDays} ${summary.oldestOverdueDays == 1 ? 'day' : 'days'}',
        onTap: () => select(DebtsTab.schedule),
      ),
      KpiTile(
        key: const ValueKey('debts-next'),
        labels: tileLabels,
        icon: Icons.event_outlined,
        label: 'Next payment',
        // With nothing scheduled there is no next payment, not one of ₱0.00.
        value: MoneyAmount(
          complete && next.isEmpty ? 'None' : known(summary.nextTotal),
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        caption: !complete
            ? null
            : next.isEmpty
            ? 'No upcoming payments'
            : [
                next.length == 1
                    ? next.single.debt.debt.title
                    : '${next.length} payments',
                civilLabel(next.first.date),
                dueWhen(next.first.days),
              ].join(' · '),
        onTap: () => select(DebtsTab.schedule),
      ),
      KpiTile(
        key: const ValueKey('debts-month'),
        labels: tileLabels,
        icon: Icons.date_range_outlined,
        label: 'Due this month',
        value: MoneyAmount(
          known(summary.thisMonthTotal),
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        caption: !complete
            ? null
            : summary.thisMonth.isEmpty
            ? 'Nothing left this month'
            : '${summary.thisMonth.length} ${summary.thisMonth.length == 1 ? 'payment' : 'payments'} · ${overviewSpan(monthStart(today), monthEnd(today))}',
        onTap: () => select(DebtsTab.schedule),
      ),
    ];

    Widget yourDebts() => YourDebtsCard(
      key: const ValueKey('debts-yours'),
      debts: debts,
      amount: amount,
      available: complete,
      hidden: hidden,
      onOpen: actions.openDebt,
      onLog: (d) => actions.logPayment(d, null),
      onAdd: actions.addDebt,
    );
    Widget dueNext() => DueNextCard(
      key: const ValueKey('debts-due-next'),
      summary: summary,
      amount: amount,
      available: complete,
      onLog: (p) => actions.logPayment(p.debt, p),
      onSchedule: () => select(DebtsTab.schedule),
    );
    Widget owedOverTime() => OwedCard(
      key: const ValueKey('debts-owed-trend'),
      owed: owed,
      debts: debts,
      amount: amount,
      monthLabel: (date) => date == today ? 'Today' : civilMonth(date),
      available: complete,
      hidden: hidden,
    );

    (List<GridCard>, List<Widget>) summaryTab() {
      final tasks = debtTasks(debts);
      final needs = tasks.isEmpty
          ? null
          : NeedsInputCard(
              key: const ValueKey('debts-needs'),
              tasks: tasks,
              actions: actions,
            );
      return (
        [
          for (final t in tiles) (t, 3, 6),
          (yourDebts(), 8, 12),
          (dueNext(), 4, 12),
          (owedOverTime(), needs == null ? 12 : 7, 12),
          ?(needs == null ? null : (needs, 5, 12)),
        ],
        // On phones What you owe takes the full width, sparkline beside its
        // value; the other tiles pair up.
        [
          KeyedSubtree(child: tiles.first),
          ...tiles.skip(1),
          dueNext(),
          yourDebts(),
          ?needs,
          owedOverTime(),
        ],
      );
    }

    (List<GridCard>, List<Widget>) scheduleTab() {
      final months = dueByMonth(
        complete
            ? [
                for (final r in namedDueSources(
                  s,
                  financialReminderSources(
                    s,
                    today,
                    dueWindowEnd(today),
                    asOf: today,
                  ),
                ))
                  if (!debtsOnly || r.kind == 'Debt due') r,
              ]
            : const [],
        today,
      );
      final busiest = months.reduce((a, b) => b.$2 > a.$2 ? b : a);
      final total = sumMinor(months.map((m) => m.$2));
      final dues = DuesCard(
        key: const ValueKey('debts-dues'),
        week: week,
        month: month,
        amount: amount,
        available: complete,
        shown: 6,
        caption: debtsOnly
            ? 'Your debts only'
            : 'Debts, card statements and recurring bills',
        period: period,
        onPeriod: (p) => setState(() => period = p),
        view: view,
        onView: (v) => setState(() => view = v),
        onOpen: (due) => openDue(source, debts, due),
        menu: [
          const Divider(height: 1),
          for (final (only, label) in [
            (false, 'All dues'),
            (true, 'Debts only'),
          ])
            MenuItemButton(
              key: ValueKey('dues-scope-$only'),
              leadingIcon: Icon(
                only ? Icons.account_balance_outlined : Icons.list_alt,
              ),
              trailingIcon: only == debtsOnly ? const Icon(Icons.check) : null,
              onPressed: () => setState(() => debtsOnly = only),
              child: Text(label),
            ),
          const Divider(height: 1),
          MenuItemButton(
            key: const ValueKey('dues-open-page'),
            leadingIcon: const Icon(Icons.open_in_full),
            onPressed: openList,
            child: const Text('Open as a page'),
          ),
        ],
      );
      final upcoming = MonthBarsCard(
        key: const ValueKey('debts-by-month'),
        title: 'Upcoming by month',
        caption: 'This month and the next five · overdue is separate',
        summary: 'Due',
        months: months,
        amount: amount,
        available: complete,
        hidden: hidden,
        emptyTitle: 'Nothing scheduled',
        emptyMessage: 'Payments due in the next six months show here.',
        stats: [
          (label: 'Next six months', value: amount(total), detail: null),
          (
            label: 'Busiest month',
            value: amount(busiest.$2),
            detail: civilMonth(busiest.$1),
          ),
        ],
      );
      final list = view == DuesView.list;
      return (
        [(dues, list ? 12 : 7, 12), (upcoming, list ? 12 : 5, 12)],
        [dues, upcoming],
      );
    }

    (List<GridCard>, List<Widget>) paymentsTab() {
      final rows = complete ? debtPaymentRows(s) : const <DebtPaymentRow>[];
      final open = rows.where((p) => p.left > BigInt.zero).toList();
      final months = complete
          ? paidByMonth(s, today)
          : const <(String, BigInt)>[];
      final paid = months.isEmpty ? BigInt.zero : months.last.$2;
      final before = months.length < 2
          ? BigInt.zero
          : months[months.length - 2].$2;
      final over = MonthBarsCard(
        key: const ValueKey('debts-paid'),
        title: 'Paid over time',
        caption: 'Payments you logged, by month',
        summary: 'Paid',
        months: months,
        amount: amount,
        available: complete,
        hidden: hidden,
        emptyTitle: 'No payments yet',
        emptyMessage: 'What you log on your debts each month shows here.',
        stats: [
          (label: 'This month', value: amount(paid), detail: null),
          (label: 'Last month', value: amount(before), detail: null),
          (
            label: 'Paid down this month',
            value: amount(paidDownBetween(s, monthStart(today), today)),
            detail: 'Off what you owe',
          ),
        ],
      );
      final breakdowns = BreakdownsCard(
        key: const ValueKey('debts-breakdowns'),
        rows: open,
        debts: debts,
        amount: amount,
        available: complete,
        onBreakDown: (d, id) => actions.breakDown(d, id),
      );
      final history = PaymentHistoryCard(
        key: const ValueKey('debts-payments'),
        rows: rows,
        amount: amount,
        available: complete,
        onOpen: actions.openRecord,
      );
      return (
        [(over, 7, 12), (breakdowns, 5, 12), (history, 12, 12)],
        [breakdowns, over, history],
      );
    }

    (List<GridCard>, List<Widget>) historyTab() {
      final card = RecordsCard(
        key: const ValueKey('debts-history'),
        title: 'History',
        caption: 'Every record, with its earlier versions · newest first',
        records: complete ? debtHistory(s) : const [],
        snapshot: s,
        amount: amount,
        available: complete,
        onOpen: actions.openRecord,
      );
      return ([(card, 12, 12)], [card]);
    }

    final (wide, stacked) = switch (tab) {
      DebtsTab.summary => summaryTab(),
      DebtsTab.schedule => scheduleTab(),
      DebtsTab.payments => paymentsTab(),
      DebtsTab.history => historyTab(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        // Android's header row is already a 48 target; keep the tabs close.
        SizedBox(height: android ? Space.xs : Space.lg),
        AppTabs<DebtsTab>(
          key: const ValueKey('debts-tabs'),
          tabs: [for (final t in DebtsTab.values) (t, t.label)],
          selected: tab,
          onSelected: select,
        ),
        SizedBox(height: Space.cardGapOf(context) + Space.xs),
        for (final n in notices) ...[
          n,
          SizedBox(height: Space.cardGapOf(context)),
        ],
        DashboardGrid(
          key: ValueKey(('debts-grid', tab)),
          cards: android ? null : wide,
          stacked: stacked,
        ),
      ],
    );
  }
}

/// The shareable list on its own page: on Android the app bar, dock and +
/// button are gone here, so a screenshot shows only the list.
class DuesListPage extends StatelessWidget {
  const DuesListPage({
    super.key,
    required this.dues,
    required this.amount,
    required this.onOpen,
  });
  final OverviewDues dues;
  final Amount amount;
  final ValueChanged<FinancialReminderSource> onOpen;
  @override
  Widget build(BuildContext context) => SectionPage(
    title: 'Due and overdue',
    child: SurfaceCard(
      child: dues.isEmpty
          ? const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nothing due in this period',
              message: 'What you track shows here when it is due.',
            )
          : DuesList(dues: dues, amount: amount, onOpen: onOpen),
    ),
  );
}

/// One debt on its own page.
class NativeDebtDetail extends StatelessWidget {
  const NativeDebtDetail({
    super.key,
    required this.controller,
    required this.debtId,
    this.session,
  });
  final LocalFinancialController controller;
  final String debtId;
  final PrototypeSession? session;
  @override
  Widget build(BuildContext context) => DebtDetailView(
    listenable: session == null
        ? controller
        : Listenable.merge([controller, session]),
    source: (context) => localDebtsSource(context, controller, session),
    debtId: debtId,
  );
}

/// One debt: what you owe, its progress, every scheduled payment and what
/// was logged on it, with its actions at the top.
class DebtDetailView extends StatelessWidget {
  const DebtDetailView({
    super.key,
    required this.listenable,
    required this.source,
    required this.debtId,
  });
  final Listenable listenable;
  final DebtsSource Function(BuildContext context) source;
  final String debtId;

  Widget more(DebtsSource source, DebtProgress d) {
    final actions = source.actions;
    final open = !d.paidOff;
    final items = [
      if (open)
        (
          'debt-edit-schedule',
          d.scheduled ? 'Edit schedule' : 'Set schedule',
          Icons.edit_calendar_outlined,
          () => actions.schedule(d),
        ),
      if (d.scheduled && d.due.next != null)
        (
          'debt-update-amounts',
          'Update amounts',
          Icons.edit_note,
          () => actions.updateAmounts(d),
        ),
      if (d.clearing > BigInt.zero)
        (
          'debt-break-down',
          'Break down a payment',
          Icons.call_split,
          () => actions.breakDown(d, null),
        ),
      if (open) ...[
        (
          'debt-lender-charge',
          'Log a lender charge or waiver',
          Icons.request_quote_outlined,
          () => actions.lenderCharge(d),
        ),
        (
          'debt-early-payoff',
          'Log an early payoff',
          Icons.task_alt,
          () => actions.earlyPayoff(d),
        ),
      ],
      (
        'debt-view-record',
        'View record',
        Icons.description_outlined,
        () => actions.openRecord(d.debt.id),
      ),
    ];
    return MenuAnchor(
      alignmentOffset: const Offset(0, Space.xs),
      menuChildren: [
        for (final (key, label, icon, run) in items)
          MenuItemButton(
            key: ValueKey(key),
            leadingIcon: Icon(icon),
            onPressed: run,
            child: Text(label),
          ),
      ],
      builder: (context, controller, _) => AppIconButton(
        key: const ValueKey('debt-more'),
        icon: Icons.more_horiz,
        tooltip: 'More actions',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: listenable,
    builder: (context, _) {
      final source = this.source(context);
      final s = source.snapshot, today = source.today;
      final amount = source.amount, actions = source.actions;
      final action = s.revisions
          .where((r) => r.id == debtId)
          .firstOrNull
          ?.actionId;
      final d = overviewDebtProgress(
        s,
        today,
      ).where((d) => d.debt.actionId == action).firstOrNull;
      if (d == null) {
        return const SectionPage(
          title: 'Debt details',
          child: SurfaceCard(
            child: EmptyState(
              icon: Icons.history,
              title: 'This debt is no longer here',
              message: 'It was reversed. Go back to Debts to see the others.',
            ),
          ),
        );
      }
      final android = !isDesktop(context);
      final lender = d.debt.values['lender'] ?? '';
      final payments = {
        for (final p in debtPaymentRows(s, debt: d.debt.actionId))
          p.record.id: p,
      };
      String detail(LocalRevision r) {
        final p = payments[r.id];
        return p == null
            ? r.title
            : [
                'Paid from ${p.paidFrom}',
                if (p.appliedTo.isEmpty)
                  'Not tied to a due date'
                else
                  p.appliedTo.join(', '),
              ].join(' · ');
      }

      final payoff = DebtPayoffCard(
        debt: d,
        amount: amount,
        hidden: source.hidden,
        onUpdateAmounts: () => actions.updateAmounts(d),
      );
      final about = AboutDebtCard(
        debt: d,
        principal: debtPrincipalRange(s, d.debt, today),
        amount: amount,
      );
      final installments = InstallmentsCard(
        debt: d,
        rows: d.scheduled ? installmentRows(s, d, today) : const [],
        today: today,
        amount: amount,
        onLog: (p) => actions.logPayment(d, p),
        onSchedule: () => actions.schedule(d),
      );
      final activity = RecordsCard(
        key: const ValueKey('debt-activity'),
        title: 'Payment history',
        caption: 'Payments, lender charges and any payoff · newest first',
        records: debtActivity(s, d.debt.actionId),
        snapshot: s,
        amount: amount,
        versions: false,
        detail: detail,
        emptyTitle: 'No payments yet',
        emptyMessage: 'Payments you log on this debt show here.',
        onOpen: actions.openRecord,
      );
      return SectionPage(
        title: d.debt.title,
        caption: [
          if (lender.isNotEmpty) lender,
          debtTypeLabel(d.debt.values['debtType']),
        ].join(' · '),
        status: DebtStatusBadge(d),
        actions: [
          if (!d.paidOff)
            CompactForm(
              child: AppButton(
                'Log a payment',
                key: const ValueKey('debt-log-payment'),
                icon: Icons.add,
                onPressed: () => actions.logPayment(d, null),
              ),
            ),
          more(source, d),
        ],
        child: DashboardGrid(
          key: ValueKey(('debt-grid', d.debt.actionId)),
          cards: android
              ? null
              : [
                  (payoff, 8, 12),
                  (about, 4, 12),
                  (installments, 12, 12),
                  (activity, 12, 12),
                ],
          stacked: [payoff, installments, activity, about],
        ),
      );
    },
  );
}

/// Change the amount of any payment not yet paid in full. Dates, historical
/// paid amounts and recorded allocations are kept by the schedule rules.
class NativeScheduleAmounts extends StatefulWidget {
  const NativeScheduleAmounts({
    super.key,
    required this.controller,
    required this.scheduleId,
  });
  final LocalFinancialController controller;
  final String scheduleId;
  @override
  State<NativeScheduleAmounts> createState() => _NativeScheduleAmountsState();
}

class _NativeScheduleAmountsState extends State<NativeScheduleAmounts> {
  LocalFinancialController get c => widget.controller;
  late final LocalRevision schedule = c.snapshot.revision(widget.scheduleId);
  late final rows = financeSchedule(schedule.values['schedule']!);
  late final paid = [
    for (final r in rows)
      debtInstallmentPaid(c.snapshot, schedule, r, '9999-12-31'),
  ];
  late final fields = [
    for (final r in rows) TextEditingController(text: phpDecimal(r.amount)),
  ];
  int? errorRow; // a row index, or -1 for the total
  String? errorText;
  bool busy = false, saved = false, syncBlocked = false;

  /// What is still owed on this debt; the unpaid payments must add up to it.
  BigInt get owed => -financeBalance(
    c.snapshot,
    'debt_liability',
    'debt',
    schedule.values['debt']!,
    through: civilToday(),
  );

  BigInt get scheduled {
    var sum = BigInt.zero;
    for (var i = 0; i < rows.length; i++) {
      if (paid[i] >= rows[i].amount) continue;
      sum += (_amount(i) ?? BigInt.zero) - paid[i];
    }
    return sum;
  }

  BigInt? _amount(int i) {
    try {
      final v = parsePhp(fields[i].text.trim());
      return v > BigInt.zero ? v : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      errorRow = errorText = null;
    });
    String? problem;
    int? problemRow;
    var blocked = false;
    try {
      final lines = <String>[];
      var changed = false;
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        final amount = paid[i] >= r.amount ? r.amount : _amount(i);
        if (amount == null) {
          reject('Enter an amount like 2000.00 for ${r.id}.', field: '$i');
        }
        if (amount != r.amount) changed = true;
        lines.add(
          '${r.id},${r.date},${phpDecimal(amount)}${r.paid > BigInt.zero ? ',${phpDecimal(r.paid)}' : ''}',
        );
      }
      if (!changed) reject('No amounts were changed.');
      // A schedule change needs the latest records.
      if (c.connected) await c.syncLatest?.call();
      await c.reload();
      if (scheduled != owed) {
        reject(
          'The unpaid payments add up to ${c.amount(scheduled)}, but you still owe ${c.amount(owed)}. They must match exactly.',
          field: 'total',
        );
      }
      final current = c.snapshot.revision(widget.scheduleId);
      final command = LocalCommand(
        id: newLocalId(),
        owner: c.store.owner,
        expectedVersion: c.snapshot.version,
        kind: 'financeCorrection',
        values: {
          'replace': current.id,
          'replaceVersion': '${current.number}',
          'reason': 'Updated payment amounts',
          'schedule': lines.join('\n'),
          if ((current.values['frequency'] ?? '').isNotEmpty) ...{
            'splitMode': 'varied',
            'installmentAmount': '',
          },
        },
      );
      planLocal(c.snapshot, command);
      await c.store.commit(command);
      await c.reload();
      saved = true;
    } on LocalRuleException catch (e) {
      if (isSyncBlock(e)) {
        blocked = true;
      } else {
        problem = e.message;
        problemRow = e.field == 'total' ? -1 : int.tryParse(e.field ?? '');
      }
    } on FormatException catch (e) {
      problem = e.message;
    } catch (_) {
      problem = 'The amounts could not be saved. Your entries are kept.';
    }
    if (mounted) {
      setState(() {
        busy = false;
        syncBlocked = blocked;
        errorRow = problemRow;
        errorText = problem;
      });
    }
  }

  @override
  void dispose() {
    for (final f in fields) {
      f.dispose();
    }
    super.dispose();
  }

  String shown(BigInt value) =>
      c.amountsHidden ? 'Amount hidden' : c.amount(value);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ink = CraftTheme.of(context);
    final (error, _) = ink.tone(NoticeTone.error);
    final gap = SizedBox(height: CompactForm.fieldGap(context));
    final difference = scheduled - owed;
    final total = errorRow == -1;
    return CompactForm(
      child: SectionPage(
        title: 'Update payment amounts',
        caption: 'Change any payment that is not paid yet.',
        maxWidth: Space.formMaxWidth,
        child: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (saved) ...[
                const InlineNotice(
                  'The payment schedule now uses the new amounts.',
                  title: 'Amounts saved',
                  tone: NoticeTone.success,
                  live: true,
                ),
                SizedBox(height: CompactForm.groupGap(context)),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ] else ...[
                Text(
                  'Dates and payments already made stay as they are. The unpaid payments must add up to what you still owe.',
                  style: text.bodySmall?.copyWith(color: ink.secondary),
                ),
                if (errorText != null && errorRow == null) ...[
                  gap,
                  InlineNotice(errorText!, tone: NoticeTone.error, live: true),
                ],
                for (var i = 0; i < rows.length; i++) ...[
                  gap,
                  if (paid[i] >= rows[i].amount)
                    ListRow(
                      title: rows[i].id,
                      subtitle: '${civilDay(rows[i].date)} · Paid',
                      trailing: MoneyAmount(shown(rows[i].amount)),
                    )
                  else
                    AmountField(
                      key: ValueKey('amount-$i'),
                      label: '${rows[i].id} · due ${civilDay(rows[i].date)}',
                      controller: fields[i],
                      helper: paid[i] > BigInt.zero
                          ? '${shown(paid[i])} already paid toward this'
                          : null,
                      errorText: errorRow == i ? errorText : null,
                      onChanged: (_) => setState(() => errorRow = null),
                    ),
                ],
                gap,
                StatStrip(
                  key: const ValueKey('amounts-total'),
                  stats: [
                    (label: 'Still owed', value: shown(owed), detail: null),
                    (
                      label: 'Scheduled',
                      value: shown(scheduled),
                      detail: difference == BigInt.zero
                          ? 'Adds up'
                          : difference < BigInt.zero
                          ? '${shown(-difference)} still to assign'
                          : '${shown(difference)} too much',
                    ),
                  ],
                ),
                if (syncBlocked) ...[
                  gap,
                  const InlineNotice(
                    syncBlockedMessage,
                    title: syncBlockedTitle,
                    tone: NoticeTone.warning,
                    live: true,
                  ),
                ],
                if (total && errorText != null) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    errorText!,
                    style: text.bodySmall?.copyWith(color: error),
                  ),
                ],
                SizedBox(height: CompactForm.groupGap(context)),
                Align(
                  alignment: isDesktop(context)
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.center,
                  child: SizedBox(
                    width: isDesktop(context) ? null : double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : save,
                      child: Text(
                        busy
                            ? 'Saving…'
                            : syncBlocked
                            ? 'Sync and save'
                            : 'Save amounts',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
