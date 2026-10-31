import 'package:flutter/material.dart';

import '../app/overview_dashboard.dart' show overviewLongDate;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../finance/debt_cards.dart' show civilDay, civilMonth;
import 'shared_data.dart';
import 'shared_domain.dart';

/// The Shared Expenses cards (§2 Shared Expenses A).

/// "October 2026", heading a month's rows.
String monthHeading(String date) =>
    overviewLongDate(date).split(' ').sublist(2).join(' ');

/// A row with a name and measured amount columns. It keeps its columns down
/// to small cards, where an `AppTable` would turn into rows, because a person
/// beside two amounts is short. Below that, each amount takes a line.
class SharedMoneyTable extends StatelessWidget {
  const SharedMoneyTable({
    super.key,
    required this.label,
    required this.columns,
    required this.rows,
  });
  final String label;
  final List<String> columns;

  /// A name and one amount per column.
  final List<(String, List<String?>)> rows;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final widths = [
      for (final (i, column) in columns.indexed)
        moneyColumnWidth(context, [column, for (final r in rows) r.$2[i]]),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final fixed = widths.fold<double>(0, (a, b) => a + b + Space.md);
        if (box.maxWidth - fixed < Space.xxxl * 2 * scale) {
          return ListGroup(
            children: [
              for (final (name, amounts) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(name, style: text.titleSmall),
                      for (final (i, a) in amounts.indexed)
                        LabelAmount(
                          label: Text(
                            columns[i],
                            style: text.bodySmall?.copyWith(color: c.secondary),
                          ),
                          amount: MoneyAmount(a),
                        ),
                    ],
                  ),
                ),
            ],
          );
        }
        Widget line(Widget name, List<Widget> amounts) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Row(
            children: [
              Expanded(child: name),
              for (final (i, a) in amounts.indexed) ...[
                const SizedBox(width: Space.md),
                SizedBox(
                  width: widths[i],
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: a,
                  ),
                ),
              ],
            ],
          ),
        );
        final head = text.labelMedium?.copyWith(color: c.secondary);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: line(Text(label, style: head), [
                for (final column in columns) Text(column, style: head),
              ]),
            ),
            Divider(height: 1, color: c.divider),
            for (final (i, (name, amounts)) in rows.indexed) ...[
              if (i > 0) Divider(height: 1, color: c.divider),
              Semantics(
                label: [
                  name,
                  for (final (n, a) in amounts.indexed)
                    '${columns[n]} ${a ?? MoneyAmount.unknown}',
                ].join(', '),
                excludeSemantics: true,
                child: line(Text(name, style: text.bodyMedium), [
                  for (final a in amounts) MoneyAmount(a),
                ]),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A payment's state in words. "Waiting for Maria" is about the person, not
/// about syncing, which is shown apart from it.
String paymentStatusLabel(SharedPaymentRow p) => switch (p.status) {
  PaymentStatus.toConfirm => 'To confirm',
  PaymentStatus.waiting => 'Waiting for ${p.to}',
  PaymentStatus.confirmed when p.manual => 'Confirmed by the owner',
  PaymentStatus.confirmed => 'Confirmed',
  PaymentStatus.disputed => 'Disputed',
  PaymentStatus.cancelled => 'Cancelled',
  PaymentStatus.reversed => 'Reversed',
};

/// A payment's state as a pill: an icon and words, never color alone.
Widget paymentPill(SharedPaymentRow p) => StatusPill(
  paymentStatusLabel(p),
  icon: switch (p.status) {
    PaymentStatus.toConfirm => Icons.how_to_reg_outlined,
    PaymentStatus.waiting => Icons.schedule,
    PaymentStatus.confirmed => Icons.check_circle_outline,
    PaymentStatus.disputed => Icons.report_gmailerrorred_outlined,
    PaymentStatus.cancelled => Icons.block,
    PaymentStatus.reversed => Icons.undo,
  },
  tone: switch (p.status) {
    PaymentStatus.toConfirm => PillTone.warning,
    PaymentStatus.waiting => PillTone.information,
    PaymentStatus.confirmed => PillTone.success,
    PaymentStatus.disputed => PillTone.error,
    _ => PillTone.neutral,
  },
);

/// "3 days", for how long a payment has waited.
String waitedFor(int days) => days == 0
    ? 'today'
    : days == 1
    ? '1 day'
    : '$days days';

/// What a bill row says beyond its name.
String billDetails(SharedBillRow r) => detailLine([
  r.paidBy,
  if (r.waiting) 'Waiting to sync',
  if (r.corrected) 'Corrected',
  if (r.refunds > 0) 'Refunded',
]);

/// Every bill in the group, by month, newest first.
class SharedBillsCard extends StatefulWidget {
  const SharedBillsCard({
    super.key,
    required this.rows,
    required this.amount,
    required this.available,
    required this.onOpen,
    required this.empty,
    this.onPage,
    this.pageSize = 25,
  });
  final List<SharedBillRow> rows;

  /// Opens the shareable list.
  final VoidCallback? onPage;
  final String Function(BigInt) amount;
  final bool available;
  final ValueChanged<SharedBillRow> onOpen;
  final Widget empty;
  final int pageSize;
  @override
  State<SharedBillsCard> createState() => _SharedBillsCardState();
}

class _SharedBillsCardState extends State<SharedBillsCard> {
  late int shown = widget.pageSize;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final amount = widget.amount;
    final rows = widget.rows;
    final visible = rows.take(shown).toList();
    final table = <AppTableRow>[];
    String? month;
    for (final r in visible) {
      final m = monthOf(r.date);
      if (m != month) {
        month = m;
        table.add(
          AppTableRow.header(
            'month-$m',
            Text(
              monthHeading(r.date),
              style: text.labelMedium?.copyWith(color: c.text),
            ),
          ),
        );
      }
      final total = widget.available ? amount(r.total) : null;
      final part = !widget.available || r.part == null ? null : amount(r.part!);
      table.add(
        AppTableRow(
          id: r.id,
          money: [total, part],
          spoken: [
            r.name,
            civilDay(r.date),
            r.paidBy,
            if (r.waiting) 'Waiting to sync',
            'Total ${total ?? MoneyAmount.unknown}',
            'Your part ${part ?? MoneyAmount.unknown}',
          ].join(', '),
          onTap: () => widget.onOpen(r),
          cells: [
            Text(
              '${civilMonth(r.date)} ${DateTime.parse(r.date).day}',
              style: text.bodySmall?.copyWith(color: c.secondary),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.name, style: text.titleSmall),
                Text(
                  billDetails(r),
                  style: text.bodySmall?.copyWith(color: c.secondary),
                ),
              ],
            ),
          ],
          narrow: AdaptiveRow(
            key: ValueKey('bill-${r.id}'),
            title: r.name,
            subtitle: detailLine([
              civilDay(r.date),
              r.paidBy,
              'Total ${total ?? MoneyAmount.unknown}',
              if (r.waiting) 'Waiting to sync',
              if (r.corrected) 'Corrected',
              if (r.refunds > 0) 'Refunded',
            ]),
            trailing: MoneyAmount(part),
            onTap: () => widget.onOpen(r),
          ),
        ),
      );
    }
    return OverviewCard(
      key: const ValueKey('shared-bills'),
      title: 'Bills',
      caption: 'Newest first · your part after refunds',
      corner: rows.isEmpty || widget.onPage == null
          ? null
          : CardMenu(
              key: const ValueKey('shared-bills-menu'),
              tooltip: 'More',
              items: [
                MenuItemButton(
                  key: const ValueKey('shared-bills-page'),
                  leadingIcon: const Icon(Icons.open_in_new),
                  onPressed: widget.onPage,
                  child: const Text('Open as a page'),
                ),
              ],
            ),
      child: rows.isEmpty
          ? widget.empty
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTable(
                  key: const ValueKey('shared-bills-table'),
                  columns: const [
                    (label: 'Date', flex: 0, width: dateColumn),
                    (label: 'Bill', flex: 1, width: null),
                  ],
                  moneyColumns: const ['Total', 'Your part'],
                  rows: table,
                ),
                if (rows.length > shown)
                  ShowMore(
                    left: rows.length - shown,
                    onPressed: () => setState(() => shown += widget.pageSize),
                  )
                else
                  const ListEnd(key: ValueKey('shared-bills-end')),
              ],
            ),
    );
  }
}

/// What needs the user on this tab. Hidden when there's nothing.
class SharedTasksCard extends StatelessWidget {
  const SharedTasksCard({super.key, required this.tasks, required this.onOpen});
  final List<SharedTask> tasks;
  final ValueChanged<SharedTask> onOpen;

  static IconData icon(SharedTaskKind kind) => switch (kind) {
    SharedTaskKind.refused => Icons.error_outline,
    SharedTaskKind.restored => Icons.restore,
    SharedTaskKind.changed => Icons.sync_problem_outlined,
    SharedTaskKind.draft => Icons.edit_note,
    SharedTaskKind.waiting => Icons.cloud_upload_outlined,
  };

  @override
  Widget build(BuildContext context) => OverviewCard(
    key: const ValueKey('shared-attention'),
    title: 'Needs your attention',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListGroup(
          leading: true,
          children: [
            for (final t in tasks)
              AdaptiveRow(
                key: ValueKey('shared-task-${t.id}'),
                leading: icon(t.kind),
                title: t.title,
                subtitle: t.detail,
                onTap: () => onOpen(t),
              ),
          ],
        ),
        const ListEnd(),
      ],
    ),
  );
}

/// What the group shared per month, by bill date, refunds subtracted.
class SharedOverTimeCard extends StatelessWidget {
  const SharedOverTimeCard({
    super.key,
    required this.months,
    required this.amount,
    required this.available,
    required this.hidden,
  });
  final List<(String, BigInt)> months;
  final String Function(BigInt) amount;
  final bool available, hidden;
  @override
  Widget build(BuildContext context) {
    final values = [for (final m in months) m.$2];
    final any = values.any((v) => v != BigInt.zero);
    final peak = !any ? null : months.reduce((a, b) => b.$2 > a.$2 ? b : a);
    return OverviewCard(
      key: const ValueKey('shared-over-time'),
      title: 'Shared over time',
      caption: 'Each month’s bills, refunds subtracted',
      centered: true,
      child: !available
          ? const NotAvailable('This shows once your records are complete.')
          : hidden
          ? const AmountsHidden()
          : !any
          ? const EmptyState(
              icon: Icons.bar_chart,
              title: 'No bills in the last six months',
              message: 'Bills you share show here by month.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OverviewBarChart(
                  values: values,
                  label: (i) => civilMonth(months[i].$1),
                  tooltip: (i) =>
                      '${civilMonth(months[i].$1)}: ${amount(months[i].$2)}',
                  semanticsLabel:
                      'Shared per month: ${[for (final m in months) '${civilMonth(m.$1)} ${amount(m.$2)}'].join(', ')}.',
                ),
                const SizedBox(height: Space.md),
                StatStrip(
                  stats: [
                    (
                      label: 'This month',
                      value: amount(months.last.$2),
                      detail: null,
                    ),
                    (
                      label: 'Last month',
                      value: amount(months[months.length - 2].$2),
                      detail: null,
                    ),
                    (
                      label: 'Highest',
                      value: amount(peak!.$2),
                      detail: civilMonth(peak.$1),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                ChartValues(
                  rows: [
                    for (final m in months) (monthHeading(m.$1), amount(m.$2)),
                  ],
                ),
              ],
            ),
    );
  }
}

/// What each person paid and their part across the group's bills.
class WhoPaidCard extends StatelessWidget {
  const WhoPaidCard({
    super.key,
    required this.people,
    required this.amount,
    required this.available,
  });
  final List<SharedPersonRow> people;
  final String Function(BigInt) amount;
  final bool available;
  @override
  Widget build(BuildContext context) => OverviewCard(
    key: const ValueKey('shared-who-paid'),
    title: 'Who paid, whose part',
    caption: 'Across every bill, refunds applied',
    child: !available
        ? const NotAvailable('This shows once your records are complete.')
        : people.isEmpty
        ? const EmptyState(
            icon: Icons.people_outline,
            title: 'Nothing shared yet',
            message: 'What each person paid shows here.',
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SharedMoneyTable(
                key: const ValueKey('shared-who-paid-table'),
                label: 'Person',
                columns: const ['Paid', 'Part'],
                rows: [
                  for (final p in people)
                    (p.name, [amount(p.paid), amount(p.part)]),
                ],
              ),
              const ListEnd(),
            ],
          ),
  );
}

/// Payments still open. Whoever can answer one can do it from its row.
class SharedWaitingCard extends StatelessWidget {
  const SharedWaitingCard({
    super.key,
    required this.group,
    required this.me,
    required this.rows,
    required this.amount,
    required this.available,
    required this.onOpen,
    required this.onConfirm,
  });
  final SharedGroup group;
  final String? me;
  final List<SharedPaymentRow> rows;
  final String Function(BigInt) amount;
  final bool available;
  final ValueChanged<SharedPaymentRow> onOpen;

  /// Null while there's no connection, because confirming needs one.
  final ValueChanged<SharedPaymentRow>? onConfirm;

  @override
  Widget build(BuildContext context) => OverviewCard(
    key: const ValueKey('shared-waiting'),
    title: 'Waiting to be confirmed',
    caption: 'These don’t count until they’re confirmed',
    child: !available
        ? const NotAvailable('Payments show once your records are complete.')
        : rows.isEmpty
        ? const EmptyState(
            icon: Icons.check_circle_outline,
            title: 'Nothing waiting',
            message: 'Payments waiting for someone to confirm show here.',
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListGroup(
                children: [
                  for (final p in rows)
                    AdaptiveRow(
                      key: ValueKey('waiting-${p.id}'),
                      title: p.who,
                      subtitle: detailLine(
                        [
                          paymentStatusLabel(p),
                          if (p.waitingDays != null) waitedFor(p.waitingDays!),
                          appliedLine(group, p),
                        ].where((d) => d.isNotEmpty),
                      ),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MoneyAmount(amount(p.amount)),
                          if (onConfirm != null &&
                              paymentChoices(group, p.id, me).confirm)
                            CardLink(
                              'Confirm',
                              key: ValueKey('confirm-${p.id}'),
                              chevron: false,
                              onPressed: () => onConfirm!(p),
                            ),
                        ],
                      ),
                      onTap: () => onOpen(p),
                    ),
                ],
              ),
              const ListEnd(key: ValueKey('shared-waiting-end')),
            ],
          ),
  );
}

/// Who the user owes and who owes them, each with what's owed.
class SharedPairsCard extends StatelessWidget {
  const SharedPairsCard({
    super.key,
    required this.group,
    required this.me,
    required this.pairs,
    required this.amount,
    required this.available,
    required this.onLog,
    required this.onBalances,
  });
  final SharedGroup group;
  final String? me;
  final List<(String, BigInt)> pairs;
  final String Function(BigInt) amount;
  final bool available;

  /// Null when this group can't take a new payment.
  final ValueChanged<String>? onLog;
  final VoidCallback onBalances;

  @override
  Widget build(BuildContext context) => OverviewCard(
    key: const ValueKey('shared-pairs'),
    title: 'Between you and others',
    caption: 'Confirmed payments only',
    trailing: CardLink(
      'See Balances',
      key: const ValueKey('shared-see-balances'),
      onPressed: onBalances,
    ),
    child: !available
        ? const NotAvailable('This shows once your records are complete.')
        : pairs.isEmpty
        ? const EmptyState(
            icon: Icons.handshake_outlined,
            title: 'All square',
            message: 'Nobody owes anyone here right now.',
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListGroup(
                leading: true,
                children: [
                  for (final (person, signed) in pairs)
                    AdaptiveRow(
                      key: ValueKey('pair-$person'),
                      leading: signed < BigInt.zero
                          ? Icons.north_east
                          : Icons.south_west,
                      title: signed < BigInt.zero
                          ? 'You owe ${group.personName(person)}'
                          : '${group.personName(person)} owes you',
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MoneyAmount(
                            amount(signed.abs()),
                            kind: signed < BigInt.zero
                                ? MoneyKind.owed
                                : MoneyKind.owedToYou,
                          ),
                          if (signed < BigInt.zero && onLog != null)
                            CardLink(
                              'Log payment',
                              key: ValueKey('log-$person'),
                              chevron: false,
                              onPressed: () => onLog!(person),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              const ListEnd(key: ValueKey('shared-pairs-end')),
            ],
          ),
  );
}

/// Every payment, by month, newest first, with filters for each state.
class SharedPaymentsCard extends StatefulWidget {
  const SharedPaymentsCard({
    super.key,
    required this.group,
    required this.rows,
    required this.amount,
    required this.available,
    required this.onOpen,
    required this.onPage,
    this.pageSize = 25,
  });
  final SharedGroup group;
  final List<SharedPaymentRow> rows;
  final String Function(BigInt) amount;
  final bool available;
  final ValueChanged<SharedPaymentRow> onOpen;

  /// Opens the shareable list.
  final VoidCallback onPage;
  final int pageSize;
  @override
  State<SharedPaymentsCard> createState() => _SharedPaymentsCardState();
}

class _SharedPaymentsCardState extends State<SharedPaymentsCard> {
  PaymentFilter filter = PaymentFilter.all;
  late int shown = widget.pageSize;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final amount = widget.amount, g = widget.group;
    final rows = widget.rows.where(filter.matches).toList();
    final table = paymentTable(
      context,
      g,
      rows.take(shown),
      amount,
      widget.onOpen,
    );
    return OverviewCard(
      key: const ValueKey('shared-payments'),
      title: 'Payments',
      caption: 'Newest first',
      corner: widget.rows.isEmpty
          ? null
          : CardMenu(
              key: const ValueKey('shared-payments-menu'),
              tooltip: 'More',
              items: [
                MenuItemButton(
                  key: const ValueKey('shared-payments-page'),
                  leadingIcon: const Icon(Icons.open_in_new),
                  onPressed: widget.onPage,
                  child: const Text('Open as a page'),
                ),
              ],
            ),
      child: !widget.available
          ? const NotAvailable('Payments show once your records are complete.')
          : widget.rows.isEmpty
          ? const EmptyState(
              icon: Icons.payments_outlined,
              title: 'No payments yet',
              message:
                  'Payments between members show here, with who paid whom.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.xs,
                  children: [
                    for (final f in PaymentFilter.values)
                      ChoiceChip(
                        key: ValueKey('payment-filter-${f.name}'),
                        label: Text(f.label),
                        selected: filter == f,
                        showCheckmark: false,
                        onSelected: (_) => setState(() {
                          filter = f;
                          shown = widget.pageSize;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.lg),
                    child: Text(
                      'No payments here.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: c.secondary),
                    ),
                  )
                else
                  table,
                if (rows.length > shown)
                  ShowMore(
                    left: rows.length - shown,
                    onPressed: () => setState(() => shown += widget.pageSize),
                  )
                else
                  const ListEnd(key: ValueKey('shared-payments-end')),
              ],
            ),
    );
  }
}

/// Payments as a table, by month. The tab and the shareable page share it.
Widget paymentTable(
  BuildContext context,
  SharedGroup g,
  Iterable<SharedPaymentRow> rows,
  String Function(BigInt) amount,
  ValueChanged<SharedPaymentRow>? onOpen,
) {
  final c = CraftTheme.of(context);
  final text = Theme.of(context).textTheme;
  final table = <AppTableRow>[];
  String? month;
  for (final p in rows) {
    final m = monthOf(p.date);
    if (m != month) {
      month = m;
      table.add(
        AppTableRow.header(
          'month-$m',
          Text(
            monthHeading(p.date),
            style: text.labelMedium?.copyWith(color: c.text),
          ),
        ),
      );
    }
    final applied = appliedLine(g, p);
    table.add(
      AppTableRow(
        id: p.id,
        money: [amount(p.amount)],
        spoken: [
          p.who,
          civilDay(p.date),
          paymentStatusLabel(p),
          if (applied.isNotEmpty) applied,
          amount(p.amount),
        ].join(', '),
        onTap: onOpen == null ? null : () => onOpen(p),
        cells: [
          Text(
            '${civilMonth(p.date)} ${DateTime.parse(p.date).day}',
            style: text.bodySmall?.copyWith(color: c.secondary),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(p.who, style: text.titleSmall),
              if (applied.isNotEmpty)
                Text(
                  applied,
                  style: text.bodySmall?.copyWith(color: c.secondary),
                ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: paymentPill(p),
          ),
        ],
        narrow: AdaptiveRow(
          key: ValueKey('payment-${p.id}'),
          title: p.who,
          subtitle: detailLine(
            [
              civilDay(p.date),
              paymentStatusLabel(p),
              applied,
            ].where((d) => d.isNotEmpty),
          ),
          trailing: MoneyAmount(amount(p.amount)),
          onTap: onOpen == null ? null : () => onOpen(p),
        ),
      ),
    );
  }
  return AppTable(
    key: const ValueKey('shared-payments-table'),
    columns: const [
      (label: 'Date', flex: 0, width: dateColumn),
      (label: 'Who', flex: 3, width: null),
      (label: 'Status', flex: 2, width: null),
    ],
    moneyColumns: const ['Amount'],
    rows: table,
  );
}
