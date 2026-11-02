import 'package:flutter/material.dart';

import '../app/overview_cards.dart' show Amount, civilLabel, duePill;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import 'card_data.dart';
import 'debt_cards.dart' show civilMonth, dueWhen;
import 'finance_screen.dart' show formTitles;
import 'money_data.dart';

/// Cards cards (Chat 9). Each shows values it is given; the screens read the
/// source and `card_data.dart` derives the rest.

/// What a card's table row says about its credit, in words.
String creditLine(CardRow c, Amount amount, {required bool hidden}) =>
    c.limit == null
    ? 'No limit recorded'
    : c.over > BigInt.zero
    ? (hidden ? 'Over the limit' : 'Over the limit by ${amount(c.over)}')
    : c.usedBasisPoints == null
    ? 'No limit recorded'
    : '${percentLabel(c.usedBasisPoints!)} used';

/// A due row's details. How far off it is only matters when it's close, so
/// later rows stay on one line.
String dueDetail(CardDue d) => detailLine([
  d.kind,
  civilLabel(d.item.date),
  if (d.item.days <= debtDueSoonDays) dueWhen(d.item.days),
]);

/// Opens Log a card payment, with what's left when it's known.
void logCardPayment(
  MoneyActions actions,
  LocalSnapshot s,
  String card, {
  BigInt? left,
}) => actions.form(
  'cardPayment',
  formTitles['cardPayment']!,
  initial: {
    'card': cardRecord(s, card)?.id ?? card,
    if (left != null) 'amount': phpDecimal(left),
  },
);

/// Every card as a table: what's next, how much credit is used and what's
/// owed, closing with the total.
class YourCardsCard extends StatelessWidget {
  const YourCardsCard({
    super.key,
    required this.summary,
    required this.dues,
    required this.amount,
    required this.available,
    required this.hidden,
    required this.onOpen,
    required this.onAdd,
    this.corner,
  });
  final CardsSummary summary;
  final List<CardDue> dues;
  final Amount amount;
  final bool available, hidden;
  final ValueChanged<String> onOpen;
  final VoidCallback onAdd;
  final Widget? corner;

  AppTableRow row(BuildContext context, CardRow card) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: c.secondary);
    final next = dues.where((d) => d.card == card.id).firstOrNull;
    final owed = amount(card.owed);
    final open = card.available == null ? '—' : amount(card.available!);
    final credit = creditLine(card, amount, hidden: hidden);
    final over = card.over > BigInt.zero;
    final when = next == null
        ? 'Nothing due'
        : '${next.kind} · ${civilLabel(next.item.date)}';
    return AppTableRow(
      id: 'card-${card.id}',
      spoken: [
        card.name,
        card.issuer,
        when,
        if (!hidden) credit,
        if (!hidden) 'Available credit $open',
        'You owe $owed',
      ].join(', '),
      onTap: () => onOpen(card.id),
      cells: [
        Row(
          children: [
            Icon(
              Icons.credit_card_outlined,
              size: Space.lg,
              color: c.secondary,
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.name, style: text.titleSmall),
                  if (card.issuer.isNotEmpty) Text(card.issuer, style: muted),
                ],
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(when, style: text.bodySmall),
            if (next != null) ...[
              const SizedBox(height: Space.xxs),
              duePill(next.item.status),
            ],
          ],
        ),
        if (!hidden)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (card.usedBasisPoints != null) ...[
                SlimBar(
                  fraction: card.usedBasisPoints! / 10000,
                  color: over ? c.tone(NoticeTone.warning).$1 : null,
                ),
                const SizedBox(height: Space.xxs),
              ],
              Text(credit, style: muted),
              if (card.credit > BigInt.zero)
                Text(
                  'Card credit ${amount(card.credit)}',
                  key: ValueKey('card-credit-${card.id}'),
                  style: muted,
                ),
            ],
          ),
      ],
      money: [if (!hidden) open, owed],
      narrow: KeyedSubtree(
        key: ValueKey('row-card-${card.id}'),
        child: AdaptiveRow(
          leading: Icons.credit_card_outlined,
          title: card.name,
          subtitle: detailLine([
            when,
            if (!hidden) credit,
            if (!hidden && card.available != null) 'Available $open',
            if (!hidden && card.credit > BigInt.zero)
              'Card credit ${amount(card.credit)}',
          ]),
          trailing: MoneyAmount(owed),
          onTap: () => onOpen(card.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final used = summary.usedBasisPoints;
    return OverviewCard(
      title: 'Your cards',
      caption: 'What you owe today · not counted in Available money',
      stackBelow: Space.xxxl * 10,
      corner: corner,
      trailing: available
          ? CardLink(
              'Add a card',
              key: const ValueKey('cards-add'),
              icon: Icons.add,
              onPressed: onAdd,
            )
          : null,
      child: !available
          ? const NotAvailable('Cards show once your records are complete.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTable(
                  key: const ValueKey('cards-table'),
                  columns: [
                    (label: 'Card', flex: 3, width: null),
                    (label: 'Next due', flex: 2, width: null),
                    if (!hidden) (label: 'Credit used', flex: 2, width: null),
                  ],
                  moneyColumns: [
                    if (!hidden) 'Available credit',
                    'What you owe',
                  ],
                  rows: [for (final card in summary.cards) row(context, card)],
                ),
                Divider(height: 1, color: c.divider),
                Padding(
                  key: const ValueKey('cards-total'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.sm,
                    vertical: Space.xs,
                  ),
                  child: LabelAmount(
                    label: Text('Card debt', style: text.titleSmall),
                    amount: MoneyAmount(amount(summary.owed)),
                  ),
                ),
                if (!hidden) ...[
                  const SizedBox(height: Space.sm),
                  StatStrip(
                    key: const ValueKey('cards-stats'),
                    stats: [
                      (
                        label: 'Credit used',
                        value: used == null ? '—' : percentLabel(used),
                        detail: 'Of your limits',
                      ),
                      (
                        label: 'Available credit',
                        value: summary.limited.isEmpty
                            ? '—'
                            : amount(summary.available),
                        detail: 'Not money you have',
                      ),
                      (
                        label: 'Card credit',
                        value: amount(summary.credit),
                        detail: 'Not money you have',
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

/// Open statements and installments, overdue first, each with Log payment.
/// Their amounts are never added up: they can overlap.
class CardDuesCard extends StatelessWidget {
  const CardDuesCard({
    super.key,
    required this.dues,
    required this.amount,
    required this.available,
    required this.onLog,
    required this.onOpen,
    required this.onAll,
    this.shown = 5,
  });
  final List<CardDue> dues;
  final Amount amount;
  final bool available;
  final ValueChanged<CardDue> onLog, onOpen;

  /// Opens every row, when they don't all fit.
  final VoidCallback onAll;
  final int shown;

  @override
  Widget build(BuildContext context) {
    final rows = dues.take(shown).toList();
    final left = dues.length - rows.length;
    return OverviewCard(
      title: 'Due next',
      caption: 'Statements and installments can overlap',
      child: !available
          ? const NotAvailable('Dues show once your records are complete.')
          : rows.isEmpty
          ? const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nothing due on your cards',
              message: 'Statements you add show here until they’re paid.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListGroup(
                  leading: true,
                  children: [
                    for (final d in rows)
                      AdaptiveRow(
                        key: ValueKey('card-due-${d.id}'),
                        leading: d.statement
                            ? Icons.credit_card_outlined
                            : Icons.credit_score_outlined,
                        title: d.name,
                        subtitle: dueDetail(d),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MoneyAmount(amount(d.item.amount)),
                            if (d.item.days < 0) ...[
                              const SizedBox(height: Space.xxs),
                              duePill(d.item.status),
                            ],
                            CardLink(
                              'Log payment',
                              key: ValueKey('card-log-${d.id}'),
                              chevron: false,
                              onPressed: () => onLog(d),
                            ),
                          ],
                        ),
                        onTap: () => onOpen(d),
                      ),
                  ],
                ),
                ListEnd(
                  key: const ValueKey('card-dues-end'),
                  label: left > 0
                      ? '$left more on your cards'
                      : 'That’s everything',
                  onPressed: left > 0 ? onAll : null,
                ),
              ],
            ),
    );
  }
}

/// Card debt as a filled line, with where it stands and has been.
class CardDebtCard extends StatelessWidget {
  const CardDebtCard({
    super.key,
    required this.months,
    required this.amount,
    required this.available,
    required this.hidden,
  });
  final List<(String, BigInt)> months;
  final Amount amount;
  final bool available, hidden;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final values = [for (final m in months) m.$2];
    final high = values.reduce((a, b) => b > a ? b : a);
    final before = months.length > 1 ? months[months.length - 2] : months.last;
    final change = months.last.$2 - before.$2;
    String label(String date) =>
        date == months.last.$1 ? 'Today' : civilMonth(date);
    return OverviewCard(
      title: 'Card debt over time',
      caption: 'Month ends, then today',
      centered: true,
      child: !available
          ? const NotAvailable('Charts show once your records are complete.')
          : hidden
          ? const AmountsHidden()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OverviewLineChart(
                  lines: [
                    (
                      values: values,
                      color: c.chartSeries.first,
                      dashed: false,
                      fill: true,
                    ),
                  ],
                  label: (i) => i < months.length ? label(months[i].$1) : null,
                  tooltip: (_, i) =>
                      '${label(months[i].$1)}\n${amount(months[i].$2)}',
                  semanticsLabel:
                      'Card debt over ${months.length} points. From ${amount(values.first)} to ${amount(values.last)}. Highest ${amount(high)}.',
                ),
                const SizedBox(height: Space.md),
                StatStrip(
                  stats: [
                    (
                      label: 'Today',
                      value: amount(months.last.$2),
                      detail: null,
                    ),
                    (
                      label: 'Since end of ${civilMonth(before.$1)}',
                      value: change > BigInt.zero
                          ? '+${amount(change)}'
                          : amount(change),
                      detail: change > BigInt.zero
                          ? 'Added'
                          : change < BigInt.zero
                          ? 'Paid down'
                          : 'No change',
                    ),
                    (label: 'Highest', value: amount(high), detail: null),
                  ],
                ),
                const SizedBox(height: Space.lg),
                ChartValues(
                  rows: [for (final m in months) (label(m.$1), amount(m.$2))],
                ),
              ],
            ),
    );
  }
}

/// What needs the user on the cards. The screen leaves it out when empty.
class CardTasksCard extends StatelessWidget {
  const CardTasksCard({super.key, required this.tasks, required this.onOpen});
  final List<CardTask> tasks;
  final ValueChanged<CardTask> onOpen;
  @override
  Widget build(BuildContext context) => OverviewCard(
    title: 'Needs your attention',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListGroup(
          leading: true,
          children: [
            for (final t in tasks)
              AdaptiveRow(
                key: ValueKey('card-task-${t.need.name}-${t.id}'),
                leading: switch (t.need) {
                  CardNeed.difference => Icons.rule,
                  CardNeed.unmatched => Icons.link_off,
                  CardNeed.overLimit => Icons.warning_amber_rounded,
                  CardNeed.cardCredit => Icons.savings_outlined,
                  CardNeed.pending => Icons.hourglass_empty,
                },
                title: t.title,
                subtitle: t.subtitle,
                onTap: () => onOpen(t),
              ),
          ],
        ),
        const ListEnd(key: ValueKey('card-tasks-end')),
      ],
    ),
  );
}
