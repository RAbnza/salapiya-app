import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../finance/debt_cards.dart' show civilDay, civilMonth;
import 'shared_bills_tab.dart' show StandingWords;
import 'shared_data.dart';
import 'shared_domain.dart';
import 'shared_header.dart' show standingLine;
import 'shared_private_data.dart';

/// "What do my own records say about this group, and does anything need me?"
/// Everything here is the user's own: it reads their records and reviews, and
/// nothing on this tab reaches the group or anyone in it.
class SharedRecordsTab extends StatelessWidget {
  const SharedRecordsTab({
    super.key,
    required this.source,
    required this.group,
    required this.onOpen,
  });
  final SharedSource source;
  final SharedGroup group;
  final ValueChanged<PrivateRow> onOpen;

  @override
  Widget build(BuildContext context) {
    final android = !isDesktop(context);
    final g = group, amount = source.amount;
    final me = g.participant(source.actor ?? '');
    final loaded = source.complete;
    final rows = loaded
        ? privateRows(g, me, source.current, source.reviews, source.today)
        : const <PrivateRow>[];
    final counts = privateCounts(rows);
    final mine = myGroupBalance(source.current, g.id);
    const labels = [
      'Needs a look',
      'In my Money',
      'Not in my Money',
      'My records say',
    ];
    Widget figure(String? text, {MoneyKind kind = MoneyKind.neutral}) =>
        MoneyAmount(
          text,
          kind: kind,
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        );
    final needs = KpiTile(
      key: const ValueKey('records-needs'),
      labels: labels,
      accent: true,
      icon: Icons.flag_outlined,
      label: 'Needs a look',
      value: figure(
        !loaded
            ? null
            : counts.needs == 0
            ? 'All clear'
            : '${counts.needs}',
      ),
      caption: loaded ? 'Only you can see this' : null,
    );
    final added = KpiTile(
      key: const ValueKey('records-added'),
      labels: labels,
      icon: Icons.check_circle_outline,
      label: 'In my Money',
      value: figure(loaded ? '${counts.added}' : null),
      caption: loaded ? 'Bills, payments and refunds' : null,
    );
    final missing = KpiTile(
      key: const ValueKey('records-not-added'),
      labels: labels,
      icon: Icons.add_circle_outline,
      label: 'Not in my Money',
      value: figure(loaded ? '${counts.notAdded}' : null),
      caption: loaded ? 'Adding them is up to you' : null,
    );
    final says = KpiTile(
      key: const ValueKey('records-says'),
      labels: labels,
      icon: Icons.account_balance_wallet_outlined,
      label: 'My records say',
      value: figure(
        !loaded
            ? null
            : mine == BigInt.zero
            ? 'All square'
            : amount(mine.abs()),
        kind: !loaded || mine == BigInt.zero
            ? MoneyKind.neutral
            : mine > BigInt.zero
            ? MoneyKind.owedToYou
            : MoneyKind.owed,
      ),
      change: loaded && mine != BigInt.zero
          ? StandingWords(
              mine > BigInt.zero ? StandingKind.owedToYou : StandingKind.youOwe,
            )
          : null,
    );
    final look = _NeedsCard(
      rows: [
        for (final r in rows)
          if (r.state.needsYou) r,
      ],
      available: loaded,
      onOpen: onOpen,
    );
    final compare = _CompareCard(source: source, group: g, me: me, mine: mine);
    final list = SharedRecordsCard(
      key: ValueKey('records-${g.id}'),
      rows: rows,
      amount: amount,
      available: loaded,
      onOpen: onOpen,
    );
    final earlier = [
      for (final r in reviewsFor(source.reviews, g.id))
        if (r['historicalOnly'] == true) r,
    ];
    final checks = !loaded || earlier.isEmpty
        ? null
        : _EarlierChecks(group: g, reviews: earlier);
    return DashboardGrid(
      key: const ValueKey('shared-records-grid'),
      cards: android
          ? null
          : [
              (needs, 3, 6),
              (added, 3, 6),
              (missing, 3, 6),
              (says, 3, 6),
              (look, 7, 12),
              (compare, 5, 12),
              (list, 12, 12),
              ?(checks == null ? null : (checks, 12, 12)),
            ],
      // On phones Needs a look and My records say take the full width.
      stacked: [
        KeyedSubtree(child: needs),
        added,
        missing,
        KeyedSubtree(child: says),
        look,
        compare,
        list,
        ?checks,
      ],
    );
  }
}

/// A state as a pill: an icon and words, never color alone.
Widget privatePill(PrivateState state) => StatusPill(
  state.label,
  icon: switch (state) {
    PrivateState.notAdded => Icons.add_circle_outline,
    PrivateState.added => Icons.check_circle_outline,
    PrivateState.needsLook => Icons.sync_problem_outlined,
    PrivateState.kept => Icons.rule_outlined,
    PrivateState.toCount => Icons.rule_outlined,
    PrivateState.counted => Icons.check_circle_outline,
    PrivateState.toTakeOut => Icons.undo,
    PrivateState.takenOut => Icons.undo,
  },
  tone: switch (state) {
    PrivateState.needsLook ||
    PrivateState.toCount ||
    PrivateState.toTakeOut => PillTone.warning,
    PrivateState.added || PrivateState.counted => PillTone.success,
    _ => PillTone.neutral,
  },
);

/// Why a row needs the user, in a few words.
String privateNote(PrivateRow r) => r.gone
    ? 'This isn’t in the group’s records here any more'
    : switch (r.state) {
        PrivateState.needsLook =>
          'This bill changed, so your own record needs a look',
        PrivateState.toCount => 'Confirmed. Count it in your group balance',
        PrivateState.toTakeOut =>
          'Its confirmation was undone. Take it out of your group balance',
        _ => r.state.label,
      };

class _NeedsCard extends StatelessWidget {
  const _NeedsCard({
    required this.rows,
    required this.available,
    required this.onOpen,
  });
  final List<PrivateRow> rows;
  final bool available;
  final ValueChanged<PrivateRow> onOpen;

  @override
  Widget build(BuildContext context) => OverviewCard(
    key: const ValueKey('records-attention'),
    title: 'Needs a look',
    caption: 'In your own records',
    child: !available
        ? const NotAvailable('This shows once your records are complete.')
        : rows.isEmpty
        ? const EmptyState(
            icon: Icons.check_circle_outline,
            title: 'Nothing needs you',
            message: 'What needs a look in your own records shows here.',
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListGroup(
                children: [
                  for (final r in rows)
                    AdaptiveRow(
                      key: ValueKey('record-needs-${r.id}'),
                      title: r.title,
                      subtitle: privateNote(r),
                      onTap: () => onOpen(r),
                    ),
                ],
              ),
              const ListEnd(key: ValueKey('records-attention-end')),
            ],
          ),
  );
}

/// The two figures side by side. There's no gap between them: no rule defines
/// one, and they differ for as long as something isn't in Money.
class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.source,
    required this.group,
    required this.me,
    required this.mine,
  });
  final SharedSource source;
  final SharedGroup group;
  final String? me;
  final BigInt mine;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final amount = source.amount;
    final standing = sharedStanding(group, me);
    return OverviewCard(
      key: const ValueKey('records-compare'),
      title: 'This group and me',
      caption: 'Only you can see this',
      child: !source.complete
          ? const NotAvailable('This shows once your records are complete.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FactRow(
                  'The group says',
                  standing.kind == StandingKind.unknown
                      ? MoneyAmount.unknown
                      : standingLine(standing, amount),
                ),
                FactRow(
                  'My records say',
                  mine == BigInt.zero
                      ? 'All square'
                      : '${mine > BigInt.zero ? 'You’re owed' : 'You owe'} ${amount(mine.abs())}',
                ),
                const SizedBox(height: Space.sm),
                Text(
                  'These can differ while something isn’t in your Money or isn’t counted yet.',
                  style: text.bodySmall?.copyWith(color: c.secondary),
                ),
                const ListEnd(key: ValueKey('records-compare-end')),
              ],
            ),
    );
  }
}

/// What the list can narrow to.
enum PrivateFilter {
  all('All'),
  needs('Needs a look'),
  notAdded('Not added'),
  added('Added');

  const PrivateFilter(this.label);
  final String label;

  bool matches(PrivateRow r) => switch (this) {
    all => true,
    needs => r.state.needsYou,
    notAdded => !r.state.inMoney,
    added => r.state.inMoney && !r.state.needsYou,
  };
}

/// Every bill, payment and refund the user is part of.
class SharedRecordsCard extends StatefulWidget {
  const SharedRecordsCard({
    super.key,
    required this.rows,
    required this.amount,
    required this.available,
    required this.onOpen,
    this.pageSize = 25,
  });
  final List<PrivateRow> rows;
  final String Function(BigInt) amount;
  final bool available;
  final ValueChanged<PrivateRow> onOpen;
  final int pageSize;
  @override
  State<SharedRecordsCard> createState() => _SharedRecordsCardState();
}

class _SharedRecordsCardState extends State<SharedRecordsCard> {
  PrivateFilter filter = PrivateFilter.all;
  late int shown = widget.pageSize;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final amount = widget.amount;
    final rows = widget.rows.where(filter.matches).toList();
    String shownAmount(BigInt? value) => value == null ? '—' : amount(value);
    return OverviewCard(
      key: const ValueKey('records-list'),
      title: 'Check against my records',
      caption: 'Only you can see this. Nothing here goes to the group.',
      child: !widget.available
          ? const NotAvailable('This shows once your records are complete.')
          : widget.rows.isEmpty
          ? const EmptyState(
              icon: Icons.lock_outline,
              title: 'Nothing to check yet',
              message: 'Bills and payments you’re part of show here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.xs,
                  children: [
                    for (final f in PrivateFilter.values)
                      ChoiceChip(
                        key: ValueKey('record-filter-${f.name}'),
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
                      'Nothing here.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: c.secondary),
                    ),
                  )
                else
                  AppTable(
                    key: const ValueKey('records-table'),
                    columns: const [
                      (label: 'Date', flex: 0, width: dateColumn),
                      (label: 'What', flex: 3, width: null),
                      (label: 'Where it stands', flex: 2, width: null),
                    ],
                    moneyColumns: const ['The group', 'My record'],
                    rows: [
                      for (final r in rows.take(shown))
                        AppTableRow(
                          id: '${r.kind.name}-${r.id}',
                          money: [shownAmount(r.group), shownAmount(r.mine)],
                          spoken: [
                            r.title,
                            r.kind.label,
                            civilDay(r.date),
                            r.state.label,
                            'The group ${shownAmount(r.group)}',
                            'My record ${shownAmount(r.mine)}',
                          ].join(', '),
                          onTap: () => widget.onOpen(r),
                          cells: [
                            Text(
                              '${civilMonth(r.date)} ${DateTime.parse(r.date).day}',
                              style: text.bodySmall?.copyWith(
                                color: c.secondary,
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(r.title, style: text.titleSmall),
                                Text(
                                  r.kind.label,
                                  style: text.bodySmall?.copyWith(
                                    color: c.secondary,
                                  ),
                                ),
                              ],
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: privatePill(r.state),
                            ),
                          ],
                          narrow: AdaptiveRow(
                            key: ValueKey('record-${r.kind.name}-${r.id}'),
                            title: r.title,
                            subtitle: detailLine([
                              civilDay(r.date),
                              r.kind.label,
                              r.state.label,
                            ]),
                            trailing: MoneyAmount(shownAmount(r.group)),
                            onTap: () => widget.onOpen(r),
                          ),
                        ),
                    ],
                  ),
                if (rows.length > shown)
                  ShowMore(
                    left: rows.length - shown,
                    onPressed: () => setState(() => shown += widget.pageSize),
                  )
                else
                  const ListEnd(key: ValueKey('records-list-end')),
              ],
            ),
    );
  }
}

/// Checks restored from a backup. They're kept, and they don't count.
class _EarlierChecks extends StatelessWidget {
  const _EarlierChecks({required this.group, required this.reviews});
  final SharedGroup group;
  final List<SharedJson> reviews;

  @override
  Widget build(BuildContext context) => OverviewCard(
    key: const ValueKey('records-earlier'),
    title: 'Earlier checks',
    caption: 'From a backup. Check these again if they still matter.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListGroup(children: [for (final r in reviews) reviewRow(group, r)]),
        const ListEnd(),
      ],
    ),
  );
}

/// One check of the user's, in plain words.
Widget reviewRow(SharedGroup g, SharedJson r) {
  final bill = r['bill_id'] as String?;
  final day = civilDayOf(r['recorded_at'] as String?);
  return AdaptiveRow(
    key: ValueKey('review-${r['id']}'),
    title: bill != null && g.bills.containsKey(bill)
        ? g.revision(bill)['name'] as String
        : 'An earlier bill',
    subtitle: detailLine([
      if (day != null) civilDay(day),
      if ((r['reason'] as String? ?? '').isNotEmpty) r['reason'] as String,
    ]),
  );
}
