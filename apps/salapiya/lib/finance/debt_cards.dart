import 'package:flutter/material.dart';

import '../app/overview_cards.dart';
import '../app/overview_data.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import '../p0/exact_money.dart';
import 'debt_data.dart';

/// Debts cards (Chat 7). Each card shows values it is given; the screens read
/// the source and `debt_data.dart` derives the rest.

String _plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : many ?? '${one}s'}';

/// "30 Oct 2026", for lists that can span years.
String civilDay(String date) => DateField.format(DateTime.parse(date));

/// "Oct".
String civilMonth(String date) =>
    DateField.monthName(DateTime.parse(date).month);

/// "in 7 days", "today" or "3 days overdue".
String dueWhen(int days) => days < 0
    ? '${_plural(-days, 'day')} overdue'
    : days == 0
    ? 'today'
    : 'in ${_plural(days, 'day')}';

String frequencyLabel(LocalRevision? schedule) {
  final v = schedule?.values ?? const <String, String>{};
  return switch (v['frequency']) {
    'weekly' => 'Weekly',
    'monthly' => 'Monthly',
    'yearly' => 'Yearly',
    'custom' =>
      'Every ${_plural(int.tryParse(v['intervalDays'] ?? '') ?? 0, 'day')}',
    _ => 'Not set',
  };
}

String debtTypeLabel(String? type) => switch (type) {
  'personal_loan' => 'Personal loan',
  'installment_loan' => 'Installment loan',
  'bnpl' => 'Buy now pay later',
  'flexible_manual' => 'Flexible credit',
  _ => 'Debt',
};

/// The next payment in a line, without an amount while amounts are hidden.
String nextLine(DebtProgress d, Amount amount, {bool hidden = false}) {
  final next = d.due.next;
  if (next == null) return '';
  final days = d.due.daysUntilNext!;
  return [
    'Next: ${civilLabel(next.$1.date)}',
    if (!hidden) amount(next.$2),
    dueWhen(days),
  ].join(' · ');
}

/// Log payment, kept small: a card link.
Widget logPaymentLink(String id, VoidCallback onPressed) => CardLink(
  'Log payment',
  key: ValueKey('debt-log-$id'),
  onPressed: onPressed,
);

const _logLabel = 'Log payment';

/// Every debt, most urgent first, with its payoff progress.
class YourDebtsCard extends StatefulWidget {
  const YourDebtsCard({
    super.key,
    required this.debts,
    required this.amount,
    required this.onOpen,
    required this.onLog,
    required this.onAdd,
    this.available = true,
    this.hidden = false,
  });
  final List<DebtProgress> debts;
  final Amount amount;
  final ValueChanged<DebtProgress> onOpen, onLog;
  final VoidCallback onAdd;
  final bool available, hidden;
  @override
  State<YourDebtsCard> createState() => _YourDebtsCardState();
}

class _YourDebtsCardState extends State<YourDebtsCard> {
  DebtFilter filter = DebtFilter.all;

  Widget bar(DebtProgress d) => d.fraction == null
      ? const SizedBox.shrink()
      : SegmentBar(
          done: d.finished ? d.total : d.done,
          total: d.total,
          fraction: d.fraction,
        );

  List<Widget> progress(DebtProgress d) {
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: CraftTheme.of(context).secondary);
    final next = nextLine(d, widget.amount, hidden: widget.hidden);
    return [
      if (d.fraction != null) ...[
        bar(d),
        const SizedBox(height: Space.xs + Space.xxs),
      ],
      Text(
        DebtProgressCard.progressLine(d, widget.amount, hidden: widget.hidden),
        style: style,
      ),
      if (next.isNotEmpty) Text(next, style: style),
    ];
  }

  String spoken(DebtProgress d) => [
    d.debt.title,
    d.statusLabel,
    DebtProgressCard.progressLine(d, widget.amount, hidden: widget.hidden),
    nextLine(d, widget.amount, hidden: widget.hidden),
    'What you owe ${widget.amount(d.outstanding)}',
  ].where((s) => s.isNotEmpty).join(', ');

  AppTableRow row(DebtProgress d) {
    final text = Theme.of(context).textTheme;
    final c = CraftTheme.of(context);
    final lender = d.debt.values['lender'] ?? '';
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DebtProgressCard.titleLine(d, text.titleSmall),
        if (lender.isNotEmpty)
          Text(lender, style: text.bodySmall?.copyWith(color: c.secondary)),
      ],
    );
    final log = d.paidOff
        ? null
        : logPaymentLink(d.debt.actionId, () => widget.onLog(d));
    final owed = MoneyAmount(
      widget.amount(d.outstanding),
      kind: MoneyKind.owed,
    );
    return AppTableRow(
      id: 'debt-${d.debt.actionId}',
      spoken: spoken(d),
      onTap: () => widget.onOpen(d),
      money: [widget.amount(d.outstanding)],
      action: log,
      cells: [
        name,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: progress(d),
        ),
      ],
      narrow: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            onTap: () => widget.onOpen(d),
            button: true,
            label: spoken(d),
            excludeSemantics: true,
            child: Pressable(
              key: ValueKey('row-debt-${d.debt.actionId}'),
              onTap: () => widget.onOpen(d),
              padding: const EdgeInsets.symmetric(
                horizontal: ListRow.horizontalPadding,
                vertical: Space.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LabelAmount(label: name, amount: owed),
                  const SizedBox(height: Space.sm),
                  ...progress(d),
                ],
              ),
            ),
          ),
          if (log != null)
            Align(alignment: AlignmentDirectional.centerEnd, child: log),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.debts.where(filter.shows).toList();
    return OverviewCard(
      title: 'Your debts',
      caption: 'Most urgent first · one bar step per payment',
      stackBelow: Space.xxxl * 15,
      trailing: widget.debts.isEmpty
          ? null
          : MiniSegmented<DebtFilter>(
              key: const ValueKey('debts-filter'),
              label: 'Filter debts',
              options: [for (final f in DebtFilter.values) (f, f.label)],
              selected: filter,
              onSelected: (f) => setState(() => filter = f),
            ),
      child: !widget.available
          ? const NotAvailable(
              'Debts show once your first download is complete.',
            )
          : widget.debts.isEmpty
          ? EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No debts yet',
              message: 'Add a debt you already have to see what you owe and what’s next.',
              action: AppButton.secondary(
                'Add a debt',
                onPressed: widget.onAdd,
              ),
            )
          : shown.isEmpty
          ? const EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'No debts match this filter',
              message: 'Choose All to see every debt.',
            )
          : AppTable(
              key: const ValueKey('debts-table'),
              columns: const [
                (label: 'Debt', flex: 4, width: null),
                (label: 'Progress', flex: 5, width: null),
              ],
              moneyColumns: const ['What you owe'],
              actionLabel: _logLabel,
              rows: [for (final d in shown) row(d)],
            ),
    );
  }
}

/// What is overdue, then what comes next, each one tap from being logged.
class DueNextCard extends StatelessWidget {
  const DueNextCard({
    super.key,
    required this.summary,
    required this.amount,
    required this.onLog,
    required this.onSchedule,
    this.available = true,
    this.shown = 5,
  });
  final DebtsSummary summary;
  final Amount amount;
  final ValueChanged<OpenPayment> onLog;
  final VoidCallback onSchedule;
  final bool available;
  final int shown;

  Widget row(OpenPayment p) => AdaptiveRow(
    key: ValueKey('due-next-${p.debt.debt.actionId}-${p.row.id}'),
    title: p.debt.debt.title,
    subtitle: '${civilLabel(p.date)} · ${dueWhen(p.days)}',
    trailing: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        MoneyAmount(amount(p.left)),
        logPaymentLink('${p.debt.debt.actionId}-${p.row.id}', () => onLog(p)),
      ],
    ),
  );

  Widget group(
    BuildContext context,
    String label,
    List<OpenPayment> rows, {
    bool overdue = false,
  }) {
    final c = CraftTheme.of(context);
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
        ListGroup(children: [for (final p in rows.take(shown)) row(p)]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final overdue = summary.overdue, upcoming = summary.upcoming;
    int beyond(List<OpenPayment> rows) =>
        rows.length > shown ? rows.length - shown : 0;
    final more = beyond(overdue) + beyond(upcoming);
    return OverviewCard(
      title: 'Due next',
      caption: 'Your debts only',
      trailing: overdue.isEmpty && upcoming.isEmpty
          ? null
          : CardLink('View schedule', onPressed: onSchedule),
      child: !available
          ? const NotAvailable(
              'Dues show once your first download is complete.',
            )
          : overdue.isEmpty && upcoming.isEmpty
          ? const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nothing due',
              message: 'Scheduled payments on your debts show here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (overdue.isNotEmpty)
                  group(context, 'Overdue', overdue, overdue: true),
                if (overdue.isNotEmpty && upcoming.isNotEmpty)
                  const SizedBox(height: Space.sm),
                if (upcoming.isNotEmpty) group(context, 'Next', upcoming),
                ListEnd(
                  key: const ValueKey('due-next-end'),
                  onPressed: more == 0 ? null : onSchedule,
                  label: more == 0
                      ? 'That’s everything'
                      : '$more more on Schedule',
                ),
              ],
            ),
    );
  }
}

/// What needs the user: a schedule, an amount to check, a breakdown.
class NeedsInputCard extends StatelessWidget {
  const NeedsInputCard({super.key, required this.tasks, required this.actions});
  final List<DebtTask> tasks;
  final DebtActions actions;
  @override
  Widget build(BuildContext context) => OverviewCard(
    title: 'Needs your input',
    caption: 'Small things that keep these figures right',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListGroup(
          children: [
            for (final t in tasks)
              AdaptiveRow(
                key: ValueKey('need-${t.need.name}-${t.debt.debt.actionId}'),
                title: t.debt.debt.title,
                subtitle: switch (t.need) {
                  DebtNeed.schedule => 'No payment schedule yet',
                  DebtNeed.confirmAmount => 'Each payment has its own amount',
                  DebtNeed.breakdown => 'A payment has no breakdown yet',
                },
                trailing: switch (t.need) {
                  DebtNeed.schedule => CardLink(
                    'Set schedule',
                    onPressed: () => actions.schedule(t.debt),
                  ),
                  DebtNeed.confirmAmount => CardLink(
                    'Check amounts',
                    onPressed: () => actions.updateAmounts(t.debt),
                  ),
                  DebtNeed.breakdown => CardLink(
                    'Break down',
                    onPressed: () => actions.breakDown(t.debt, null),
                  ),
                },
              ),
          ],
        ),
        const ListEnd(key: ValueKey('needs-end')),
      ],
    ),
  );
}

/// A bar per calendar month with its exact values, for the Schedule and
/// Payments tabs. No chart with hidden amounts (§5).
class MonthBarsCard extends StatelessWidget {
  const MonthBarsCard({
    super.key,
    required this.title,
    required this.caption,
    required this.months,
    required this.amount,
    required this.stats,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.summary,
    this.available = true,
    this.hidden = false,
  });
  final String title, caption, emptyTitle, emptyMessage;

  /// The word for the bars in the spoken summary ("Due", "Paid").
  final String summary;
  final List<(String, BigInt)> months;
  final Amount amount;
  final List<Stat> stats;
  final bool available, hidden;
  @override
  Widget build(BuildContext context) => OverviewCard(
    title: title,
    caption: caption,
    centered: true,
    child: !available
        ? const NotAvailable('Charts show once your records are complete.')
        : hidden
        ? const AmountsHidden()
        : months.every((m) => m.$2 == BigInt.zero)
        ? EmptyState(
            icon: Icons.bar_chart,
            title: emptyTitle,
            message: emptyMessage,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OverviewBarChart(
                values: [for (final m in months) m.$2],
                label: (i) =>
                    i < months.length ? civilMonth(months[i].$1) : null,
                tooltip: (i) =>
                    '${civilMonth(months[i].$1)}\n${amount(months[i].$2)}',
                semanticsLabel:
                    '$summary by month: ${[for (final m in months) '${civilMonth(m.$1)} ${amount(m.$2)}'].join(', ')}.',
              ),
              const SizedBox(height: Space.md),
              StatStrip(stats: stats),
              // Room between the figures above and the disclosure.
              const SizedBox(height: Space.lg),
              ChartValues(
                rows: [
                  for (final m in months) (civilMonth(m.$1), amount(m.$2)),
                ],
              ),
            ],
          ),
  );
}

/// Payments still without a breakdown.
class BreakdownsCard extends StatelessWidget {
  const BreakdownsCard({
    super.key,
    required this.rows,
    required this.debts,
    required this.amount,
    required this.onBreakDown,
    this.available = true,
  });
  final List<DebtPaymentRow> rows;
  final List<DebtProgress> debts;
  final Amount amount;
  final void Function(DebtProgress debt, String paymentId) onBreakDown;
  final bool available;
  @override
  Widget build(BuildContext context) => OverviewCard(
    title: 'Payments to break down',
    caption: 'Add what each one covered, once you know',
    child: !available
        ? const NotAvailable(
            'Payments show once your first download is complete.',
          )
        : rows.isEmpty
        ? const EmptyState(
            icon: Icons.task_alt,
            title: 'Nothing to break down',
            message: 'Payments you log without a breakdown show here.',
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatStrip(
                stats: [
                  (
                    label: 'Without a breakdown',
                    value: amount(sumMinor(rows.map((p) => p.left))),
                    detail: null,
                  ),
                  (label: 'Payments', value: '${rows.length}', detail: null),
                ],
              ),
              const SizedBox(height: Space.sm),
              ListGroup(
                children: [
                  for (final p in rows)
                    AdaptiveRow(
                      key: ValueKey('breakdown-${p.record.id}'),
                      title: p.debtTitle,
                      subtitle: civilDay(p.date),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MoneyAmount(amount(p.left)),
                          CardLink(
                            'Break down',
                            onPressed: () => onBreakDown(
                              debts.firstWhere(
                                (d) =>
                                    d.debt.actionId == p.record.values['debt'],
                              ),
                              p.record.id,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const ListEnd(),
            ],
          ),
  );
}

/// Logged payments, newest first; every debt's, or one debt's.
class PaymentHistoryCard extends StatefulWidget {
  const PaymentHistoryCard({
    super.key,
    required this.rows,
    required this.amount,
    required this.onOpen,
    this.showDebt = true,
    this.available = true,
    this.page = 25,
  });
  final List<DebtPaymentRow> rows;
  final Amount amount;
  final ValueChanged<String> onOpen;
  final bool showDebt, available;
  final int page;
  @override
  State<PaymentHistoryCard> createState() => _PaymentHistoryCardState();
}

class _PaymentHistoryCardState extends State<PaymentHistoryCard> {
  late int shown = widget.page;

  String applied(DebtPaymentRow p) =>
      p.appliedTo.isEmpty ? 'Not tied to a due date' : p.appliedTo.join(', ');

  AppTableRow row(DebtPaymentRow p) {
    final text = Theme.of(context).textTheme;
    final c = CraftTheme.of(context);
    final muted = text.bodySmall?.copyWith(color: c.secondary);
    final money = widget.amount(p.amount);
    return AppTableRow(
      id: 'payment-${p.record.id}',
      money: [money],
      spoken: [
        civilDay(p.date),
        if (widget.showDebt) p.debtTitle,
        'Paid from ${p.paidFrom}',
        applied(p),
        p.breakdown.label,
        money,
      ].join(', '),
      onTap: () => widget.onOpen(p.record.id),
      cells: [
        Text(civilDay(p.date), style: text.bodyMedium),
        if (widget.showDebt) Text(p.debtTitle, style: text.bodyMedium),
        Text(p.paidFrom, style: muted),
        Text(applied(p), style: muted),
        Text(p.breakdown.label, style: muted),
      ],
      narrow: AdaptiveRow(
        key: ValueKey('row-payment-${p.record.id}'),
        title: widget.showDebt ? p.debtTitle : civilDay(p.date),
        subtitle: [
          if (widget.showDebt) civilDay(p.date),
          p.paidFrom,
          applied(p),
          p.breakdown.label,
        ].join(' · '),
        trailing: MoneyAmount(money),
        onTap: () => widget.onOpen(p.record.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    return OverviewCard(
      title: 'Payment history',
      caption: 'Newest first',
      child: !widget.available
          ? const NotAvailable(
              'Payments show once your first download is complete.',
            )
          : rows.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No payments yet',
              message: 'Payments you log on a debt show here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTable(
                  key: const ValueKey('payments-table'),
                  columns: [
                    (label: 'Date', flex: 0, width: dateColumn),
                    if (widget.showDebt) (label: 'Debt', flex: 3, width: null),
                    (label: 'Paid from', flex: 2, width: null),
                    (label: 'Applied to', flex: 2, width: null),
                    (label: 'Breakdown', flex: 2, width: null),
                  ],
                  moneyColumns: const ['Amount'],
                  rows: [for (final p in rows.take(shown)) row(p)],
                ),
                if (shown < rows.length)
                  ShowMore(
                    left: rows.length - shown,
                    onPressed: () => setState(() => shown += widget.page),
                  ),
              ],
            ),
    );
  }
}

/// Records as a table: every version on History, or one debt's activity.
class RecordsCard extends StatefulWidget {
  const RecordsCard({
    super.key,
    required this.title,
    required this.caption,
    required this.records,
    required this.snapshot,
    required this.amount,
    required this.onOpen,
    this.versions = true,
    this.detail,
    this.available = true,
    this.emptyTitle = 'No history yet',
    this.emptyMessage = 'Debts, payments and their earlier versions show here.',
    this.page = 25,
  });
  final String title, caption, emptyTitle, emptyMessage;
  final List<LocalRevision> records;
  final LocalSnapshot snapshot;
  final Amount amount;
  final ValueChanged<String> onOpen;

  /// Shows the version column; a debt's own activity has no use for it.
  final bool versions;

  /// The third column's text; defaults to the record's title.
  final String Function(LocalRevision record)? detail;
  final bool available;
  final int page;
  @override
  State<RecordsCard> createState() => _RecordsCardState();
}

class _RecordsCardState extends State<RecordsCard> {
  late int shown = widget.page;

  String detailOf(LocalRevision r) => widget.detail?.call(r) ?? r.title;

  String version(LocalRevision r) => [
    'Version ${r.number}',
    if (!widget.snapshot.current.contains(r)) 'earlier',
  ].join(', ');

  AppTableRow row(LocalRevision r) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(
      color: CraftTheme.of(context).secondary,
    );
    final money = widget.amount(r.amount);
    return AppTableRow(
      id: 'record-${r.id}',
      money: [money],
      spoken: [
        civilDay(r.date),
        recordLabel(r),
        detailOf(r),
        if (widget.versions) version(r),
        money,
      ].join(', '),
      onTap: () => widget.onOpen(r.id),
      cells: [
        Text(civilDay(r.date), style: text.bodyMedium),
        Text(recordLabel(r), style: text.bodyMedium),
        Text(detailOf(r), style: muted),
        if (widget.versions) Text(version(r), style: muted),
      ],
      narrow: AdaptiveRow(
        key: ValueKey('row-record-${r.id}'),
        title: recordLabel(r),
        subtitle: [
          civilDay(r.date),
          detailOf(r),
          if (widget.versions) version(r),
        ].join(' · '),
        trailing: MoneyAmount(money),
        onTap: () => widget.onOpen(r.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.records;
    return OverviewCard(
      title: widget.title,
      caption: widget.caption,
      child: !widget.available
          ? const NotAvailable(
              'History shows once your first download is complete.',
            )
          : records.isEmpty
          ? EmptyState(
              icon: Icons.history,
              title: widget.emptyTitle,
              message: widget.emptyMessage,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTable(
                  key: const ValueKey('records-table'),
                  columns: [
                    (label: 'Date', flex: 0, width: dateColumn),
                    (label: 'What happened', flex: 3, width: null),
                    (label: 'Details', flex: 3, width: null),
                    if (widget.versions)
                      (label: 'Version', flex: 2, width: null),
                  ],
                  moneyColumns: const ['Amount'],
                  rows: [for (final r in records.take(shown)) row(r)],
                ),
                if (shown < records.length)
                  ShowMore(
                    left: records.length - shown,
                    onPressed: () => setState(() => shown += widget.page),
                  ),
              ],
            ),
    );
  }
}

/// One debt's focal card: what you owe, payoff progress and what's next.
class DebtPayoffCard extends StatelessWidget {
  const DebtPayoffCard({
    super.key,
    required this.debt,
    required this.amount,
    required this.onUpdateAmounts,
    this.hidden = false,
  });
  final DebtProgress debt;
  final Amount amount;
  final VoidCallback onUpdateAmounts;
  final bool hidden;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final d = debt, due = d.due;
    final next = due.next;
    final overdue = due.overdue.toList();
    final closeSoon = const {
      DebtDueStatus.overdue,
      DebtDueStatus.dueToday,
      DebtDueStatus.dueSoon,
    }.contains(due.status);
    return OverviewCard(
      key: const ValueKey('debt-payoff'),
      title: 'Payoff',
      caption: 'By payment schedule · one bar step per payment',
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What you owe',
            style: text.bodySmall?.copyWith(color: c.secondary),
          ),
          const SizedBox(height: Space.xxs),
          MoneyAmount(
            amount(d.outstanding),
            kind: MoneyKind.owed,
            size: MoneySize.card,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: Space.md),
          if (d.fraction != null) ...[
            SegmentBar(
              done: d.finished ? d.total : d.done,
              total: d.total,
              fraction: d.fraction,
              track: c.surface,
            ),
            const SizedBox(height: Space.xs + Space.xxs),
          ],
          Text(
            DebtProgressCard.progressLine(d, amount, hidden: hidden),
            style: text.bodySmall?.copyWith(color: c.secondary),
          ),
          if (d.scheduled) ...[
            const SizedBox(height: Space.md),
            StatStrip(
              key: const ValueKey('debt-stats'),
              stats: [
                (
                  label: 'Next payment',
                  value: next == null ? 'None left' : amount(next.$2),
                  detail: next == null
                      ? null
                      : '${civilLabel(next.$1.date)} · ${dueWhen(due.daysUntilNext!)}',
                ),
                (
                  label: 'Overdue',
                  value: amount(due.overdueAmount),
                  detail: overdue.isEmpty
                      ? 'Nothing overdue'
                      : _plural(overdue.length, 'payment'),
                ),
                (
                  label: 'Last scheduled payment',
                  value: civilDay(due.finalScheduledDue!),
                  detail: 'Not a payoff date',
                ),
              ],
            ),
          ],
          if (due.amountsVary && closeSoon && next != null) ...[
            const SizedBox(height: Space.md),
            InlineNotice(
              hidden
                  ? 'Each payment has its own amount. Check the next one, and update it if your lender changed it.'
                  : 'Each payment has its own amount. Check that ${amount(next.$2)} is right for ${civilLabel(next.$1.date)}, and update it if your lender changed it.',
              tone: NoticeTone.warning,
              action: CardLink('Update amounts', onPressed: onUpdateAmounts),
            ),
          ],
        ],
      ),
    );
  }
}

/// The debt's facts, with "Not available yet" for what isn't known.
class AboutDebtCard extends StatelessWidget {
  const AboutDebtCard({
    super.key,
    required this.debt,
    required this.principal,
    required this.amount,
  });
  final DebtProgress debt;

  /// The known principal range; null when it isn't known.
  final (BigInt, BigInt)? principal;
  final Amount amount;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final d = debt, values = d.debt.values, schedule = d.due.schedule;
    final each = schedule?.values['installmentAmount'] ?? '';
    final original = values['principal'] ?? '';
    final range = principal;
    Widget fact(String label, String? value) => Semantics(
      label: '$label: ${value ?? MoneyAmount.unknown}',
      excludeSemantics: true,
      child: LabelAmount(
        label: Text(label, style: text.bodySmall?.copyWith(color: c.secondary)),
        amount: Text(
          value ?? MoneyAmount.unknown,
          textAlign: TextAlign.end,
          style: text.bodyMedium?.copyWith(
            color: value == null ? c.secondary : c.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
    final facts = [
      fact(
        'Lender',
        (values['lender'] ?? '').isEmpty ? null : values['lender'],
      ),
      fact('Type', debtTypeLabel(values['debtType'])),
      if (d.scheduled) ...[
        fact('How often', frequencyLabel(schedule)),
        fact('Payment amounts', switch (schedule!.values['splitMode']) {
          'varied' => 'Different each time',
          'divide' => 'A total divided evenly',
          _ => 'Same each time',
        }),
        if (each.isNotEmpty) fact('Each payment', amount(parsePhp(each))),
      ],
      fact(
        'Original principal',
        original.isEmpty ? null : amount(parsePhp(original)),
      ),
      fact(
        'Principal left',
        range == null
            ? null
            : range.$1 == range.$2
            ? amount(range.$1)
            : '${amount(range.$1)} to ${amount(range.$2)}',
      ),
      if (d.clearing > BigInt.zero)
        fact('Without a breakdown', amount(d.clearing)),
    ];
    return OverviewCard(
      key: const ValueKey('debt-about'),
      title: 'About this debt',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, f) in facts.indexed) ...[
            if (i > 0) const SizedBox(height: Space.sm),
            f,
          ],
        ],
      ),
    );
  }
}

/// Every scheduled payment of one debt.
class InstallmentsCard extends StatelessWidget {
  const InstallmentsCard({
    super.key,
    required this.debt,
    required this.rows,
    required this.today,
    required this.amount,
    required this.onLog,
    required this.onSchedule,
  });
  final DebtProgress debt;
  final List<InstallmentRow> rows;
  final String today;
  final Amount amount;
  final ValueChanged<OpenPayment> onLog;
  final VoidCallback onSchedule;

  Widget pill(InstallmentRow r) => r.settled
      ? const StatusPill(
          'Paid',
          icon: Icons.check_circle_outline,
          tone: PillTone.success,
        )
      : r.cancelled
      ? const StatusPill('Cancelled by payoff', icon: Icons.block)
      : duePill(r.status);

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    AppTableRow row(InstallmentRow r) {
      final id = r.row.id;
      final late = r.open && r.days < 0;
      final log = r.open
          ? logPaymentLink(
              '${debt.debt.actionId}-$id',
              () => onLog(OpenPayment(debt, r.row, r.left, today)),
            )
          : null;
      final when = civilDay(r.row.date);
      final overdueBy = late ? dueWhen(r.days) : null;
      return AppTableRow(
        id: 'installment-$id',
        money: [amount(r.paid), amount(r.left)],
        spoken: [
          id,
          when,
          ?overdueBy,
          r.statusLabel,
          'Paid ${amount(r.paid)}',
          'Left ${amount(r.left)}',
        ].join(', '),
        action: log,
        cells: [
          Text(id, style: text.bodyMedium),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(when, style: text.bodyMedium),
              if (overdueBy != null)
                Text(
                  overdueBy,
                  style: text.bodySmall?.copyWith(color: c.overdue.$1),
                ),
            ],
          ),
          Align(alignment: AlignmentDirectional.centerStart, child: pill(r)),
        ],
        narrow: AdaptiveRow(
          key: ValueKey('row-installment-$id'),
          title: id,
          subtitle: [when, ?overdueBy, r.statusLabel].join(' · '),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [MoneyAmount(amount(r.settled ? r.paid : r.left)), ?log],
          ),
        ),
      );
    }

    return OverviewCard(
      key: const ValueKey('debt-installments'),
      title: 'Payments',
      caption: debt.scheduled
          ? 'A payment counts toward a due date only when you log it against that date'
          : null,
      child: !debt.scheduled
          ? EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'No payment schedule yet',
              message: debt.paidOff
                  ? 'This debt has nothing left to pay.'
                  : 'Set a schedule to see each due date and what’s next.',
              action: debt.paidOff
                  ? null
                  : AppButton.secondary('Set schedule', onPressed: onSchedule),
            )
          : AppTable(
              key: const ValueKey('installments-table'),
              columns: const [
                (label: 'Payment', flex: 3, width: null),
                (label: 'Due date', flex: 0, width: dateColumn),
                (label: 'Status', flex: 3, width: null),
              ],
              moneyColumns: const ['Paid', 'Left'],
              actionLabel: _logLabel,
              rows: [for (final r in rows) row(r)],
            ),
    );
  }
}
