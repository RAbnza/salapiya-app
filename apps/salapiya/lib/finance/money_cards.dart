import 'package:flutter/material.dart';

import '../app/overview_cards.dart';
import '../app/overview_data.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import 'debt_cards.dart' show civilDay, civilMonth;
import 'money_data.dart';

/// Money cards (Chat 8). Each card shows values it is given; the screens read
/// the source and `money_data.dart` derives the rest.

String _account(AccountRow a) => [
  a.account.kind,
  if (a.account.archived) 'Archived',
  if (a.checked != null) 'Checked ${civilLabel(a.checked!)}',
].join(' · ');

/// A change in money: "+₱500.00", or "−₱185.50" as the formatter gives it.
String signedAmount(BigInt value, Amount amount, {required bool hidden}) =>
    !hidden && value > BigInt.zero ? '+${amount(value)}' : amount(value);

/// What the small "This month" figures read when nothing changed.
String _change(BigInt value, Amount amount, bool hidden) =>
    signedAmount(value, amount, hidden: hidden);

/// Accounts as a table: where the money is, how much of it each holds and
/// what changed this month. Active and archived accounts are separate views;
/// the total always adds up to what the rows and lines above it show.
class AccountsCard extends StatefulWidget {
  const AccountsCard({
    super.key,
    required this.rows,
    required this.archived,
    required this.total,
    required this.amount,
    required this.available,
    required this.hidden,
    required this.onOpen,
    required this.onAdd,
    this.cards,
    this.onCards,
    this.corner,
  });
  final List<AccountRow> rows, archived;
  final BigInt total;
  final Amount amount;
  final bool available, hidden;
  final ValueChanged<String> onOpen;
  final VoidCallback onAdd;

  /// Card debt and available credit, when the profile has a card.
  final (BigInt, BigInt)? cards;
  final VoidCallback? onCards;
  final Widget? corner;
  @override
  State<AccountsCard> createState() => _AccountsCardState();
}

class _AccountsCardState extends State<AccountsCard> {
  bool archived = false;

  AppTableRow row(AccountRow a) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: c.secondary);
    final hidden = widget.hidden, amount = widget.amount;
    final balance = amount(a.balance);
    final share = a.basisPoints;
    final change = _change(a.change, amount, hidden);
    return AppTableRow(
      id: 'account-${a.account.id}',
      spoken: [
        a.account.name,
        _account(a),
        if (!hidden && share != null) '${percentLabel(share)} of your money',
        if (!hidden) 'This month $change',
        balance,
      ].join(', '),
      onTap: () => widget.onOpen(a.account.id),
      cells: [
        Row(
          children: [
            Icon(
              accountIcon(a.account.kind),
              size: Space.lg,
              color: c.secondary,
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.account.name, style: text.titleSmall),
                  Text(_account(a), style: muted),
                ],
              ),
            ),
          ],
        ),
        if (!hidden)
          share == null
              ? Text(a.balance.isNegative ? 'Below zero' : '—', style: muted)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SlimBar(fraction: share / 10000),
                    const SizedBox(height: Space.xxs),
                    Text(percentLabel(share), style: muted),
                  ],
                ),
      ],
      money: [if (!hidden) change, balance],
      narrow: KeyedSubtree(
        key: ValueKey('row-account-${a.account.id}'),
        child: AdaptiveRow(
          leading: accountIcon(a.account.kind),
          title: a.account.name,
          subtitle: [
            _account(a),
            if (!hidden && share != null) percentLabel(share),
            if (!hidden) 'This month $change',
          ].join(' · '),
          trailing: MoneyAmount(balance),
          onTap: () => widget.onOpen(a.account.id),
        ),
      ),
    );
  }

  Widget line(String label, String value, {String? caption, Key? key}) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      child: LabelAmount(
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.titleSmall),
            if (caption != null)
              Text(
                caption,
                style: text.bodySmall?.copyWith(color: c.secondary),
              ),
          ],
        ),
        amount: MoneyAmount(value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final amount = widget.amount, hidden = widget.hidden;
    final showing = archived && widget.archived.isNotEmpty;
    final rows = showing ? widget.archived : widget.rows;
    final held = sumMinor(widget.archived.map((a) => a.balance));
    return OverviewCard(
      title: 'Where your money is',
      caption: showing
          ? 'Archived accounts keep their history'
          : 'Balances today · largest first',
      stackBelow: Space.xxxl * 10,
      corner: widget.corner,
      trailing: widget.available
          ? Wrap(
              spacing: Space.sm,
              runSpacing: Space.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.archived.isNotEmpty)
                  MiniSegmented<bool>(
                    key: const ValueKey('accounts-view'),
                    label: 'Accounts',
                    options: const [(false, 'Active'), (true, 'Archived')],
                    selected: showing,
                    onSelected: (v) => setState(() => archived = v),
                  ),
                CardLink(
                  'Add account',
                  key: const ValueKey('money-add-account'),
                  icon: Icons.add,
                  onPressed: widget.onAdd,
                ),
              ],
            )
          : null,
      child: !widget.available
          ? const NotAvailable('Balances show once your records are complete.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTable(
                  key: const ValueKey('accounts-table'),
                  columns: [
                    (label: 'Account', flex: 3, width: null),
                    if (!hidden) (label: 'Share', flex: 2, width: null),
                  ],
                  moneyColumns: [if (!hidden) 'This month', 'Balance'],
                  rows: [for (final a in rows) row(a)],
                ),
                Divider(height: 1, color: c.divider),
                if (!showing) ...[
                  if (held != BigInt.zero)
                    line(
                      'Archived accounts',
                      amount(held),
                      caption: 'Counted in Available money',
                      key: const ValueKey('accounts-archived-line'),
                    ),
                  line(
                    'Available money',
                    amount(widget.total),
                    key: const ValueKey('accounts-total'),
                  ),
                  if (widget.cards case (final debt, final credit)?)
                    Semantics(
                      button: true,
                      child: Pressable(
                        key: const ValueKey('accounts-card-debt'),
                        onTap: widget.onCards,
                        child: line(
                          'Card debt',
                          amount(debt),
                          caption: credit > BigInt.zero
                              ? 'Not counted · ${amount(credit)} of card credit isn’t money you have'
                              : 'Not counted in Available money',
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

/// What needs the user, each row going where it's handled. The screen leaves
/// this card out when there's nothing to show.
class AttentionCard extends StatelessWidget {
  const AttentionCard({super.key, required this.tasks, required this.onOpen});
  final List<MoneyTask> tasks;
  final ValueChanged<MoneyTask> onOpen;
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
                key: ValueKey('attention-${t.need.name}-${t.id}'),
                leading: switch (t.need) {
                  MoneyNeed.belowZero => Icons.error_outline,
                  MoneyNeed.balanceCheck => Icons.fact_check_outlined,
                  MoneyNeed.drafts => Icons.drafts_outlined,
                },
                title: t.title,
                subtitle: t.subtitle,
                onTap: () => onOpen(t),
              ),
          ],
        ),
        const ListEnd(key: ValueKey('attention-end')),
      ],
    ),
  );
}

enum BalanceView {
  days('30 days'),
  months('12 months');

  const BalanceView(this.label);
  final String label;
}

/// A balance as a line over 30 days or 12 months, with its high, low and
/// change, and the exact values under "Show values".
class BalanceCard extends StatefulWidget {
  const BalanceCard({
    super.key,
    required this.title,
    required this.caption,
    required this.days,
    required this.months,
    required this.amount,
    required this.available,
    required this.hidden,
    required this.empty,
    this.lead,
    this.stats = const [],
    this.accent = false,
  });
  final String title, caption;
  final List<(String, BigInt)> days, months;
  final Amount amount;
  final bool available, hidden;

  /// No activity to draw yet.
  final bool empty;

  /// Above the chart, e.g. the balance on an account's page.
  final Widget? lead;

  /// The figures under the chart, in place of its high, low and change.
  final List<Stat> stats;
  final bool accent;
  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  BalanceView view = BalanceView.days;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final amount = widget.amount;
    final points = view == BalanceView.days ? widget.days : widget.months;
    final values = [for (final p in points) p.$2];
    final high = values.isEmpty
        ? BigInt.zero
        : values.reduce((a, b) => b > a ? b : a);
    final low = values.isEmpty
        ? BigInt.zero
        : values.reduce((a, b) => b < a ? b : a);
    final change = values.isEmpty ? BigInt.zero : values.last - values.first;
    final daily = view == BalanceView.days;
    String label(String date) => daily
        ? civilLabel(date).split(', ').last
        : date.endsWith(monthEnd(date).substring(8))
        ? civilMonth(date)
        : 'Today';
    return OverviewCard(
      title: widget.title,
      caption: widget.caption,
      accent: widget.accent,
      centered: true,
      stackBelow: periodBase,
      trailing: widget.available && !widget.hidden && !widget.empty
          ? MiniSegmented<BalanceView>(
              key: ValueKey('${widget.title}-view'),
              label: 'Period',
              options: [for (final v in BalanceView.values) (v, v.label)],
              selected: view,
              onSelected: (v) => setState(() => view = v),
            )
          : null,
      child: !widget.available
          ? const NotAvailable('Charts show once your records are complete.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.lead != null) ...[
                  widget.lead!,
                  const SizedBox(height: Space.md),
                ],
                if (widget.hidden)
                  const AmountsHidden()
                else if (widget.empty)
                  const EmptyState(
                    icon: Icons.show_chart,
                    title: 'Nothing to chart yet',
                    message: 'Shows after your first activity.',
                  )
                else ...[
                  OverviewLineChart(
                    lines: [
                      (
                        values: values,
                        color: c.chartSeries.first,
                        dashed: false,
                        fill: true,
                      ),
                    ],
                    label: (i) => i % (daily ? 7 : 3) == 0 && i < points.length
                        ? label(points[i].$1)
                        : null,
                    tooltip: (_, i) =>
                        '${label(points[i].$1)}\n${amount(points[i].$2)}',
                    semanticsLabel:
                        '${widget.title}, ${view.label}. From ${amount(values.first)} to ${amount(values.last)}. Highest ${amount(high)}, lowest ${amount(low)}.',
                  ),
                  const SizedBox(height: Space.md),
                  StatStrip(
                    stats: widget.stats.isNotEmpty
                        ? widget.stats
                        : [
                            (
                              label: 'Highest',
                              value: amount(high),
                              detail: null,
                            ),
                            (label: 'Lowest', value: amount(low), detail: null),
                            (
                              label: 'Change',
                              value: signedAmount(
                                change,
                                amount,
                                hidden: false,
                              ),
                              detail: view.label,
                            ),
                          ],
                  ),
                  const SizedBox(height: Space.lg),
                  ChartValues(
                    rows: [
                      for (final p in points) (civilLabel(p.$1), amount(p.$2)),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

Widget _pill(MoneyRow r) => Wrap(
  spacing: Space.xs,
  runSpacing: Space.xxs,
  children: [
    if (r.change == RecordChange.corrected)
      const StatusPill('Corrected', icon: Icons.edit_outlined),
    if (r.reversed) const StatusPill('Reversed', icon: Icons.undo),
    if (r.waiting)
      const StatusPill(
        'Waiting to sync',
        icon: Icons.cloud_upload_outlined,
        tone: PillTone.information,
      ),
  ],
);

String _states(MoneyRow r) => [
  if (r.change == RecordChange.corrected) 'Corrected',
  if (r.reversed) 'Reversed',
  if (r.waiting) 'Waiting to sync',
].join(' · ');

/// One row of a dated list.
AppTableRow activityRow(
  BuildContext context,
  MoneyRow r, {
  required Amount amount,
  required bool hidden,
  required ValueChanged<String> onOpen,
  String? account,
}) {
  final c = CraftTheme.of(context);
  final text = Theme.of(context).textTheme;
  final muted = text.bodySmall?.copyWith(color: c.secondary);
  final shown = r.shown(amount, hidden: hidden, account: account);
  final states = _states(r);
  final where = account == null ? r.accountLabel : '';
  final kind = r.categoryLabel.isEmpty ? r.label : r.categoryLabel;
  return AppTableRow(
    id: r.id,
    spoken: [
      r.title,
      civilLabel(r.date),
      r.label,
      if (where.isNotEmpty) where,
      if (r.categoryLabel.isNotEmpty) r.categoryLabel,
      shown,
      if (states.isNotEmpty) states,
    ].join(', '),
    onTap: () => onOpen(r.id),
    cells: [
      Row(
        children: [
          Icon(moneyIcon(r), size: Space.lg, color: c.secondary),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.title, style: text.bodyMedium),
                if (states.isNotEmpty) ...[
                  const SizedBox(height: Space.xxs),
                  _pill(r),
                ],
              ],
            ),
          ),
        ],
      ),
      if (account == null) Text(where, style: muted),
      Text(kind, style: muted),
    ],
    money: [shown],
    narrow: KeyedSubtree(
      key: ValueKey('row-${r.id}'),
      child: AdaptiveRow(
        leading: moneyIcon(r),
        title: r.title,
        subtitle: [
          if (where.isNotEmpty) where,
          kind,
          if (states.isNotEmpty) states,
        ].join(' · '),
        trailing: MoneyAmount(shown),
        onTap: () => onOpen(r.id),
      ),
    ),
  );
}

/// Records grouped by day, newest first, under a card header.
class ActivityListCard extends StatefulWidget {
  const ActivityListCard({
    super.key,
    required this.title,
    required this.rows,
    required this.today,
    required this.amount,
    required this.hidden,
    required this.onOpen,
    required this.empty,
    this.caption,
    this.corner,
    this.account,
    this.pageSize = 50,
  });
  final String title;
  final String? caption;
  final List<MoneyRow> rows;
  final String today;
  final Amount amount;
  final bool hidden;
  final ValueChanged<String> onOpen;
  final Widget empty;
  final Widget? corner;

  /// Shows this account's own effect, and drops the Account column.
  final String? account;
  final int pageSize;
  @override
  State<ActivityListCard> createState() => _ActivityListCardState();
}

class _ActivityListCardState extends State<ActivityListCard> {
  late int shown = widget.pageSize;

  @override
  void didUpdateWidget(ActivityListCard old) {
    super.didUpdateWidget(old);
    if (old.rows.length != widget.rows.length) shown = widget.pageSize;
  }

  /// The day a row is filed under; everything after today shares one band.
  String group(MoneyRow r) =>
      r.date.compareTo(widget.today) > 0 ? 'later' : r.date;

  Widget header(String date, BigInt change) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final later = date == 'later';
    final title = Text(
      dayLabel(later ? addCivilDays(widget.today, 1) : date, widget.today),
      style: text.labelMedium?.copyWith(color: c.text),
    );
    return Semantics(
      header: true,
      // Wraps rather than cut an amount at 200% text.
      child: later || widget.hidden || change == BigInt.zero
          ? title
          : Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: Space.sm,
              children: [
                title,
                Text(
                  signedAmount(change, widget.amount, hidden: false),
                  style: text.labelMedium?.copyWith(
                    color: c.secondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final account = widget.account;
    final totals = <String, BigInt>{};
    for (final r in rows) {
      final day = group(r);
      totals[day] = (totals[day] ?? BigInt.zero) + r.cash(account);
    }
    final visible = rows.take(shown).toList();
    final entries = <AppTableRow>[];
    String? day;
    for (final r in visible) {
      final next = group(r);
      if (next != day) {
        day = next;
        entries.add(
          AppTableRow.header('day-$next', header(next, totals[next]!)),
        );
      }
      entries.add(
        activityRow(
          context,
          r,
          amount: widget.amount,
          hidden: widget.hidden,
          onOpen: widget.onOpen,
          account: account,
        ),
      );
    }
    return OverviewCard(
      title: widget.title,
      caption: widget.caption,
      corner: widget.corner,
      child: rows.isEmpty
          ? widget.empty
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTable(
                  key: const ValueKey('activity-table'),
                  dense: true,
                  columns: [
                    (label: 'Description', flex: 3, width: null),
                    if (account == null)
                      (label: 'Account', flex: 2, width: null),
                    (label: 'Category', flex: 2, width: null),
                  ],
                  moneyColumns: const ['Amount'],
                  rows: entries,
                ),
                if (rows.length > shown) ...[
                  const SizedBox(height: Space.sm),
                  ShowMore(
                    left: rows.length - shown,
                    onPressed: () => setState(() => shown += widget.pageSize),
                  ),
                ] else
                  const ListEnd(key: ValueKey('activity-end')),
              ],
            ),
    );
  }
}

/// Records in date order, one line each, for a page about one thing: a card
/// or a budget, where day headers and an account column would add nothing.
class RecordListCard extends StatefulWidget {
  const RecordListCard({
    super.key,
    required this.title,
    required this.rows,
    required this.amount,
    required this.hidden,
    required this.onOpen,
    required this.empty,
    this.caption,
    this.corner,
    this.pageSize = 25,
  });
  final String title;
  final String? caption;
  final List<MoneyRow> rows;
  final Amount amount;
  final bool hidden;
  final ValueChanged<String> onOpen;
  final Widget empty;
  final Widget? corner;
  final int pageSize;
  @override
  State<RecordListCard> createState() => _RecordListCardState();
}

class _RecordListCardState extends State<RecordListCard> {
  late int shown = widget.pageSize;

  @override
  void didUpdateWidget(RecordListCard old) {
    super.didUpdateWidget(old);
    if (old.rows.length != widget.rows.length) shown = widget.pageSize;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = CraftTheme.of(context);
    final muted = text.bodySmall?.copyWith(color: c.secondary);
    final rows = widget.rows, amount = widget.amount;
    return OverviewCard(
      title: widget.title,
      caption: widget.caption,
      corner: widget.corner,
      child: rows.isEmpty
          ? widget.empty
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTable(
                  key: const ValueKey('record-list-table'),
                  dense: true,
                  columns: const [
                    (label: 'Date', flex: 0, width: dateColumn),
                    (label: 'Description', flex: 3, width: null),
                    (label: 'Category', flex: 2, width: null),
                  ],
                  moneyColumns: const ['Amount'],
                  rows: [
                    for (final r in rows.take(shown))
                      () {
                        final money = r.shown(amount, hidden: widget.hidden);
                        final kind = r.categoryLabel.isEmpty
                            ? r.label
                            : r.categoryLabel;
                        return AppTableRow(
                          id: 'record-${r.id}',
                          spoken: [
                            civilLabel(r.date),
                            r.title,
                            kind,
                            money,
                          ].join(', '),
                          onTap: () => widget.onOpen(r.id),
                          cells: [
                            Text(civilDay(r.date), style: text.bodyMedium),
                            Text(r.title, style: text.bodyMedium),
                            Text(kind, style: muted),
                          ],
                          money: [money],
                          narrow: KeyedSubtree(
                            key: ValueKey('row-record-${r.id}'),
                            child: AdaptiveRow(
                              title: r.title,
                              subtitle: [civilDay(r.date), kind].join(' · '),
                              trailing: MoneyAmount(money),
                              onTap: () => widget.onOpen(r.id),
                            ),
                          ),
                        );
                      }(),
                  ],
                ),
                if (rows.length > shown) ...[
                  const SizedBox(height: Space.sm),
                  ShowMore(
                    left: rows.length - shown,
                    onPressed: () => setState(() => shown += widget.pageSize),
                  ),
                ] else
                  const ListEnd(key: ValueKey('record-list-end')),
              ],
            ),
    );
  }
}

/// Every record of some kinds and its earlier versions, newest first. Keeps
/// records no list shows, such as a match, within reach.
class RecordHistoryPage extends StatefulWidget {
  const RecordHistoryPage({
    super.key,
    required this.source,
    required this.title,
    required this.empty,
    required this.types,
  });
  final MoneySource source;
  final String title, empty;
  final Set<String> types;
  @override
  State<RecordHistoryPage> createState() => _RecordHistoryPageState();
}

class _RecordHistoryPageState extends State<RecordHistoryPage> {
  int shown = 25;

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final s = source.snapshot;
    final text = Theme.of(context).textTheme;
    final records = s.revisions.reversed
        .where((r) => widget.types.contains(financeType(r)))
        .toList();
    final current = s.current.map((r) => r.id).toSet();
    return SectionPage(
      title: widget.title,
      caption: 'Earlier versions stay here',
      child: SurfaceCard(
        child: records.isEmpty
            ? EmptyState(
                icon: Icons.history,
                title: 'No history yet',
                message: widget.empty,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTable(
                    key: const ValueKey('history-table'),
                    dense: true,
                    columns: const [
                      (label: 'Date', flex: 0, width: dateColumn),
                      (label: 'Record', flex: 3, width: null),
                      (label: 'Type', flex: 2, width: null),
                    ],
                    moneyColumns: const ['Amount'],
                    rows: [
                      for (final r in records.take(shown))
                        AppTableRow(
                          id: 'history-${r.id}',
                          spoken: [
                            civilDay(r.date),
                            recordTitle(r),
                            moneyLabel(r),
                          ].join(', '),
                          onTap: () => source.actions.openRecord(r.id),
                          cells: [
                            Text(civilDay(r.date), style: text.bodyMedium),
                            Text(recordTitle(r), style: text.bodyMedium),
                            Text(
                              current.contains(r.id)
                                  ? moneyLabel(r)
                                  : '${moneyLabel(r)} · Earlier version',
                              style: text.bodySmall,
                            ),
                          ],
                          money: [source.amount(r.amount)],
                          narrow: AdaptiveRow(
                            title: recordTitle(r),
                            subtitle: [
                              civilDay(r.date),
                              moneyLabel(r),
                            ].join(' · '),
                            trailing: MoneyAmount(source.amount(r.amount)),
                            onTap: () => source.actions.openRecord(r.id),
                          ),
                        ),
                    ],
                  ),
                  if (records.length > shown) ...[
                    const SizedBox(height: Space.sm),
                    ShowMore(
                      left: records.length - shown,
                      onPressed: () => setState(() => shown += 25),
                    ),
                  ] else
                    const ListEnd(key: ValueKey('history-end')),
                ],
              ),
      ),
    );
  }
}

/// The shareable list: the period, its totals and every item, with no row
/// limit, so one screenshot says it all (§2 Shareable views).
class StatementList extends StatelessWidget {
  const StatementList({
    super.key,
    required this.statement,
    required this.heading,
    required this.today,
    required this.amount,
    required this.hidden,
    required this.onOpen,
  });
  final Statement statement;
  final String heading, today;
  final Amount amount;
  final bool hidden;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: c.secondary);
    final rows = statement.rows;
    final account = statement.account;
    final totals = listedTotals(rows, today, account: account);
    final running = account != null;
    final lines = <AppTableRow>[
      for (final (i, r) in rows.indexed)
        () {
          final shown = r.shown(amount, hidden: hidden, account: account);
          final balance = running ? amount(statement.balances[i]) : null;
          return AppTableRow(
            id: r.id,
            spoken: [
              civilLabel(r.date),
              r.title,
              r.categoryLabel,
              shown,
              if (balance != null) 'Balance $balance',
            ].join(', '),
            onTap: () => onOpen(r.id),
            cells: [
              Text(civilDay(r.date), style: text.bodyMedium),
              Text(r.title, style: text.bodyMedium),
              Text(
                r.categoryLabel.isEmpty ? r.label : r.categoryLabel,
                style: muted,
              ),
            ],
            money: [shown, ?balance],
            narrow: KeyedSubtree(
              key: ValueKey('row-${r.id}'),
              child: AdaptiveRow(
                title: r.title,
                subtitle: [
                  civilDay(r.date),
                  if (r.categoryLabel.isNotEmpty) r.categoryLabel,
                ].join(' · '),
                trailing: MoneyAmount(
                  shown,
                  caption: balance == null ? null : 'Balance $balance',
                ),
                onTap: () => onOpen(r.id),
              ),
            ),
          );
        }(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$heading · as of ${civilLabel(today)}',
          key: const ValueKey('statement-heading'),
          style: text.bodySmall?.copyWith(color: c.secondary),
        ),
        const SizedBox(height: Space.sm),
        StatStrip(
          key: const ValueKey('statement-totals'),
          stats: [
            if (running)
              (
                label: 'Starting balance',
                value: amount(statement.starting!),
                detail: null,
              ),
            (label: 'Money in', value: amount(totals.moneyIn), detail: null),
            (label: 'Money out', value: amount(totals.moneyOut), detail: null),
            if (running)
              (
                label: 'Closing balance',
                value: amount(statement.closing!),
                detail: null,
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        if (rows.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Nothing in this period',
            message: 'Records in this period show here.',
          )
        else
          AppTable(
            key: const ValueKey('statement-table'),
            dense: true,
            columns: const [
              (label: 'Date', flex: 0, width: dateColumn),
              (label: 'Description', flex: 3, width: null),
              (label: 'Category', flex: 2, width: null),
            ],
            moneyColumns: ['Amount', if (running) 'Balance'],
            rows: lines,
          ),
      ],
    );
  }
}

/// The shareable list on its own page: on Android the app bar, dock and +
/// button are gone here, so a screenshot shows only the list.
class StatementPage extends StatelessWidget {
  const StatementPage({super.key, required this.title, required this.list});
  final String title;
  final StatementList list;
  @override
  Widget build(BuildContext context) => SectionPage(
    title: title,
    child: SurfaceCard(child: list),
  );
}
