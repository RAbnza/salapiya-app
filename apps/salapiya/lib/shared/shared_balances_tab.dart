import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'shared_bills_tab.dart';
import 'shared_data.dart';
import 'shared_domain.dart';
import 'shared_pages.dart' show SharedPositionsCard;
import 'shared_people_data.dart';

/// "Who owes whom, and why?" Nothing here moves money: these are records of
/// what happened elsewhere, and suggestions are only proposals.
class SharedBalancesTab extends StatelessWidget {
  const SharedBalancesTab({
    super.key,
    required this.source,
    required this.group,
    required this.onPair,
    required this.onPerson,
    required this.onLog,
    required this.onPayments,
    required this.onPeople,
    required this.onPage,
  });
  final SharedSource source;
  final SharedGroup group;
  final void Function(String a, String b) onPair;
  final ValueChanged<String> onPerson;

  /// Logs a payment from one person to another. Null when this group can't
  /// take a new payment.
  final void Function(String sender, String recipient)? onLog;
  final VoidCallback onPayments, onPeople, onPage;

  @override
  Widget build(BuildContext context) {
    final android = !isDesktop(context);
    final g = group, amount = source.amount;
    final me = g.participant(source.actor ?? '');
    final loaded = source.complete;
    final whole = loaded && g.complete;
    const labels = ['Where you stand', 'You owe', 'Owed to you', 'Waiting'];
    Widget figure(String? text, {MoneyKind kind = MoneyKind.neutral}) =>
        MoneyAmount(
          text,
          kind: kind,
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        );
    String people(int n) => '$n ${n == 1 ? 'person' : 'people'}';
    final totals = pairTotals(whole ? pairsWithMe(g, me) : const []);
    final counts = whole ? balanceCounts(g) : null;
    final where = standingTile(source, g, labels);
    final owe = KpiTile(
      key: const ValueKey('balances-you-owe'),
      labels: labels,
      icon: Icons.north_east,
      label: 'You owe',
      value: figure(
        whole ? amount(totals.owe) : null,
        kind: totals.owe > BigInt.zero ? MoneyKind.owed : MoneyKind.neutral,
      ),
      caption: !whole
          ? null
          : totals.toPeople == 0
          ? 'Nothing to log'
          : 'To ${people(totals.toPeople)}',
    );
    final owed = KpiTile(
      key: const ValueKey('balances-owed-to-you'),
      labels: labels,
      icon: Icons.south_west,
      label: 'Owed to you',
      value: figure(
        whole ? amount(totals.owed) : null,
        kind: totals.owed > BigInt.zero
            ? MoneyKind.owedToYou
            : MoneyKind.neutral,
      ),
      caption: !whole
          ? null
          : totals.fromPeople == 0
          ? 'Nobody owes you here'
          : 'From ${people(totals.fromPeople)}',
    );
    final open = counts?.waitingCount ?? 0,
        disputed = counts?.disputedCount ?? 0;
    final waiting = KpiTile(
      key: const ValueKey('balances-waiting'),
      labels: labels,
      icon: Icons.schedule,
      label: 'Waiting',
      onTap: open + disputed > 0 ? onPayments : null,
      value: figure(
        counts == null
            ? null
            : open == 0
            ? 'Nothing waiting'
            : '$open ${open == 1 ? 'payment' : 'payments'}',
      ),
      caption: counts == null
          ? null
          : [
              if (open > 0) 'Not counted until confirmed',
              if (disputed > 0) '$disputed disputed',
            ].join(' · '),
    );
    final pairs = _WhoOwesCard(
      source: source,
      group: g,
      me: me,
      onPair: onPair,
      onLog: onLog,
      onPeople: onPeople,
      onPage: onPage,
    );
    final positions = SharedPositionsCard(
      source: source,
      group: g,
      onOpen: onPerson,
    );
    final suggested = _SuggestedCard(
      source: source,
      group: g,
      me: me,
      waiting: open,
      onLog: onLog,
      onPayments: onPayments,
    );
    final counted = _CountedCard(source: source, group: g, counts: counts);
    return DashboardGrid(
      key: const ValueKey('shared-balances-grid'),
      cards: android
          ? null
          : [
              (where, 3, 6),
              (owe, 3, 6),
              (owed, 3, 6),
              (waiting, 3, 6),
              (pairs, 7, 12),
              (positions, 5, 12),
              (suggested, 7, 12),
              (counted, 5, 12),
            ],
      // On phones Where you stand and Waiting take the full width.
      stacked: [
        KeyedSubtree(child: where),
        owe,
        owed,
        KeyedSubtree(child: waiting),
        pairs,
        suggested,
        positions,
        counted,
      ],
    );
  }
}

/// Why a card has no figures: the group is a partial copy, or the first
/// download isn't finished.
Widget balancesUnavailable(SharedSource source) => NotAvailable(
  source.complete
      ? 'You’ve left this group, so these figures aren’t complete.'
      : 'This shows once your records are complete.',
);

/// Every pair after netting, the user's own first. Each row opens why.
class _WhoOwesCard extends StatelessWidget {
  const _WhoOwesCard({
    required this.source,
    required this.group,
    required this.me,
    required this.onPair,
    required this.onLog,
    required this.onPeople,
    required this.onPage,
  });
  final SharedSource source;
  final SharedGroup group;
  final String? me;
  final void Function(String a, String b) onPair;
  final void Function(String sender, String recipient)? onLog;
  final VoidCallback onPeople, onPage;

  @override
  Widget build(BuildContext context) {
    final g = group, amount = source.amount;
    final whole = source.complete && g.complete;
    final rows = whole ? whoOwesRows(g, me) : const <SharedEdge>[];
    final sources = rows.isEmpty
        ? const <(String, String), (int, int)>{}
        : pairSources(g);
    (int, int) behind(SharedEdge e) =>
        sources[(e.sender, e.recipient)] ??
        sources[(e.recipient, e.sender)] ??
        (0, 0);
    return OverviewCard(
      key: const ValueKey('balances-who-owes'),
      title: 'Who owes whom',
      caption: 'Confirmed payments only · what each pair owes after netting',
      corner: rows.isEmpty
          ? null
          : CardMenu(
              key: const ValueKey('balances-who-owes-menu'),
              tooltip: 'More',
              items: [
                MenuItemButton(
                  key: const ValueKey('balances-who-owes-page'),
                  leadingIcon: const Icon(Icons.open_in_new),
                  onPressed: onPage,
                  child: const Text('Open as a page'),
                ),
              ],
            ),
      child: !whole
          ? balancesUnavailable(source)
          : g.people.length == 1
          ? EmptyState(
              icon: Icons.group_add_outlined,
              title: 'Just you so far',
              message: 'Add someone to this group to start sharing bills.',
              action: AppButton(
                'Add someone',
                key: const ValueKey('balances-add-someone'),
                icon: Icons.person_add_alt_outlined,
                onPressed: onPeople,
              ),
            )
          : rows.isEmpty
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
                    for (final e in rows)
                      AdaptiveRow(
                        key: ValueKey('who-owes-${e.sender}-${e.recipient}'),
                        leading: e.recipient == me
                            ? Icons.south_west
                            : e.sender == me
                            ? Icons.north_east
                            : Icons.swap_horiz,
                        title: owesWords(g, e.sender, e.recipient, me),
                        subtitle: sourceWords(behind(e).$1, behind(e).$2),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MoneyAmount(
                              amount(e.amount),
                              kind: e.sender == me
                                  ? MoneyKind.owed
                                  : e.recipient == me
                                  ? MoneyKind.owedToYou
                                  : MoneyKind.neutral,
                            ),
                            if (onLog != null && canLogFor(g, e.sender, me))
                              CardLink(
                                'Log payment',
                                key: ValueKey('who-owes-log-${e.recipient}'),
                                chevron: false,
                                onPressed: () => onLog!(e.sender, e.recipient),
                              ),
                          ],
                        ),
                        // The user's side comes first, so "You and Nico".
                        onTap: () => e.recipient == me
                            ? onPair(e.recipient, e.sender)
                            : onPair(e.sender, e.recipient),
                      ),
                  ],
                ),
                const ListEnd(key: ValueKey('balances-who-owes-end')),
              ],
            ),
    );
  }
}

/// One proposed way to even the group out (DOMAIN_RULES §20–22). It moves
/// nothing, doesn't claim to be the fewest payments, and pauses for a dispute.
class _SuggestedCard extends StatelessWidget {
  const _SuggestedCard({
    required this.source,
    required this.group,
    required this.me,
    required this.waiting,
    required this.onLog,
    required this.onPayments,
  });
  final SharedSource source;
  final SharedGroup group;
  final String? me;

  /// Payments still waiting, which aren't counted here.
  final int waiting;
  final void Function(String sender, String recipient)? onLog;
  final VoidCallback onPayments;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final g = group, amount = source.amount;
    final (state, rows) = source.complete
        ? sharedSuggestions(g)
        : (SuggestionState.unavailable, const <SuggestionRow>[]);
    String name(String person) => personLabel(g, person, me);
    return OverviewCard(
      key: const ValueKey('balances-suggested'),
      title: 'Suggested payments',
      caption: 'A proposal. Nothing changes until someone logs a payment.',
      child: switch (state) {
        SuggestionState.unavailable => balancesUnavailable(source),
        SuggestionState.paused => EmptyState(
          key: const ValueKey('balances-suggested-paused'),
          icon: Icons.pause_circle_outline,
          title: 'Paused while a payment is disputed',
          message: 'Suggestions come back once the dispute is answered.',
          action: AppButton.secondary(
            'See Payments',
            key: const ValueKey('balances-see-payments'),
            onPressed: onPayments,
          ),
        ),
        SuggestionState.none => const EmptyState(
          icon: Icons.check_circle_outline,
          title: 'Nothing to suggest',
          message: 'Everyone’s balance in the group is even.',
        ),
        SuggestionState.ready => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListGroup(
              children: [
                for (final s in rows)
                  AdaptiveRow(
                    key: ValueKey('suggestion-${s.sender}-${s.recipient}'),
                    title: '${name(s.sender)} → ${name(s.recipient)}',
                    subtitle: suggestionWords(s, g, me, amount),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MoneyAmount(amount(s.amount)),
                        if (s.direct &&
                            onLog != null &&
                            canLogFor(g, s.sender, me))
                          CardLink(
                            'Log payment',
                            key: ValueKey('suggestion-log-${s.recipient}'),
                            chevron: false,
                            onPressed: () => onLog!(s.sender, s.recipient),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            if (waiting > 0) ...[
              const SizedBox(height: Space.sm),
              Text(
                waiting == 1
                    ? 'A payment still waiting isn’t counted here. Confirming it changes this.'
                    : '$waiting payments still waiting aren’t counted here. Confirming them changes this.',
                style: text.bodySmall?.copyWith(color: c.secondary),
              ),
            ],
            const ListEnd(key: ValueKey('balances-suggested-end')),
          ],
        ),
      },
    );
  }
}

/// Says whether a suggestion only pays what's owed. Past that it redirects
/// someone else's obligation, so it can't be done alone (DOMAIN_RULES §22).
String suggestionWords(
  SuggestionRow s,
  SharedGroup g,
  String? me,
  String Function(BigInt) amount,
) {
  final you = s.sender == me;
  final from = you ? 'You' : g.personName(s.sender);
  final to = s.recipient == me ? 'you' : g.personName(s.recipient);
  const agree = 'Everyone involved needs to agree first.';
  if (s.direct) return '$from ${you ? 'owe' : 'owes'} $to at least this';
  if (s.owed > BigInt.zero) {
    return 'More than the ${amount(s.owed)} ${you ? 'you owe' : '$from owes'} $to directly. $agree';
  }
  return '$from ${you ? 'don’t owe' : 'doesn’t owe'} $to directly. $agree';
}

/// What these balances are made of, and what they leave out.
class _CountedCard extends StatelessWidget {
  const _CountedCard({
    required this.source,
    required this.group,
    required this.counts,
  });
  final SharedSource source;
  final SharedGroup group;
  final BalanceCounts? counts;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final amount = source.amount;
    final n = counts;
    Widget row(String label, int count, BigInt value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: LabelAmount(
        label: Text('$label · $count', style: text.bodyMedium),
        amount: MoneyAmount(amount(value)),
      ),
    );
    Widget heading(String label) => Padding(
      padding: const EdgeInsets.only(bottom: Space.xxs),
      child: Text(label, style: text.labelMedium?.copyWith(color: c.secondary)),
    );
    return OverviewCard(
      key: const ValueKey('balances-counted'),
      title: 'What these balances count',
      caption: 'Everything in the group, taken together',
      child: n == null
          ? balancesUnavailable(source)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading('Counted'),
                row('Bills', n.billCount, n.bills),
                row('Refunds', n.refundCount, n.refunds),
                row('Confirmed payments', n.confirmedCount, n.confirmed),
                const SizedBox(height: Space.sm),
                heading('Not counted'),
                row('Waiting', n.waitingCount, n.waiting),
                row('Disputed', n.disputedCount, n.disputed),
                const ListEnd(key: ValueKey('balances-counted-end')),
              ],
            ),
    );
  }
}
