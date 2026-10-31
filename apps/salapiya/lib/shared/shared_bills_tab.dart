import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../finance/debt_cards.dart' show civilMonth;
import 'shared_cards.dart';
import 'shared_data.dart';
import 'shared_domain.dart';

/// "What's been shared, what's my part, and does anything need me?"
class SharedBillsTab extends StatelessWidget {
  const SharedBillsTab({
    super.key,
    required this.source,
    required this.group,
    required this.onOpenBill,
    required this.onTask,
    required this.onAdd,
    required this.onPeople,
    required this.onPayments,
    this.onPage,
  });
  final SharedSource source;
  final SharedGroup group;
  final ValueChanged<SharedBillRow> onOpenBill;
  final ValueChanged<SharedTask> onTask;

  /// Null when this group can't take new bills.
  final VoidCallback? onAdd;
  final VoidCallback onPeople, onPayments;

  /// Opens the shareable list.
  final VoidCallback? onPage;

  @override
  Widget build(BuildContext context) {
    final android = !isDesktop(context);
    final g = group, today = source.today, amount = source.amount;
    final me = g.participant(source.actor ?? '');
    final loaded = source.complete;
    // Totals need the whole group; a group the user left is a partial copy.
    final whole = loaded && g.complete;
    final rows = loaded
        ? sharedBillRows(g, me, intents: source.intents)
        : const <SharedBillRow>[];
    final standing = sharedStanding(g, me);
    final month = monthOf(today);
    final tasks = loaded
        ? sharedTasks(source, g, payments: false)
        : const <SharedTask>[];
    final toConfirm = !loaded
        ? 0
        : g.settlements.values
              .where((s) => s['state'] == 'pending' && s['recipient'] == me)
              .length;
    const labels = [
      'Where you stand',
      'Your part this month',
      'Group spending',
      'Needs you',
    ];
    Widget figure(String? text, {MoneyKind kind = MoneyKind.neutral}) =>
        MoneyAmount(
          text,
          kind: kind,
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        );
    final hasAmount =
        standing.kind == StandingKind.owedToYou ||
        standing.kind == StandingKind.youOwe;
    final where = KpiTile(
      key: const ValueKey('shared-standing'),
      labels: labels,
      accent: true,
      icon: Icons.account_balance_wallet_outlined,
      label: 'Where you stand',
      value: !whole || standing.kind == StandingKind.unknown
          ? figure(null)
          : hasAmount
          ? figure(
              amount(standing.amount),
              kind: standing.kind == StandingKind.owedToYou
                  ? MoneyKind.owedToYou
                  : MoneyKind.owed,
            )
          : figure(standing.kind.label),
      change: hasAmount && whole ? StandingWords(standing.kind) : null,
      caption: !loaded
          ? null
          : !g.complete
          ? 'You’ve left this group, so this is only your earlier records.'
          : standing.projected == null
          ? 'Confirmed payments only'
          : '${positionWords(standing.projected!, amount)} if waiting payments are confirmed',
    );
    final part = KpiTile(
      key: const ValueKey('shared-part'),
      labels: labels,
      icon: Icons.pie_chart_outline,
      label: 'Your part this month',
      value: figure(whole ? amount(monthPart(rows, month)) : null),
      caption: whole
          ? 'Of ${amount(monthTotal(rows, month))} shared in ${civilMonth(today)}'
          : null,
    );
    final spending = KpiTile(
      key: const ValueKey('shared-spending'),
      labels: labels,
      icon: Icons.receipt_long_outlined,
      label: 'Group spending',
      value: figure(whole ? amount(g.spending) : null),
      caption: whole
          ? '${g.bills.length} ${g.bills.length == 1 ? 'bill' : 'bills'} · refunds subtracted'
          : null,
    );
    final needs = tasks.length + toConfirm;
    final needing = KpiTile(
      key: const ValueKey('shared-needs'),
      labels: labels,
      icon: Icons.notifications_none,
      label: 'Needs you',
      onTap: toConfirm > 0 ? onPayments : null,
      value: figure(
        !loaded
            ? null
            : needs == 0
            ? 'All clear'
            : '$needs',
      ),
      caption: !loaded || needs == 0
          ? null
          : [
              if (toConfirm > 0) '$toConfirm to confirm',
              if (tasks.isNotEmpty) '${tasks.length} on this tab',
            ].join(' · '),
    );
    final empty = !loaded
        ? const NotAvailable('Bills show once your records are complete.')
        : g.people.length == 1
        ? EmptyState(
            icon: Icons.group_add_outlined,
            title: 'Just you so far',
            message: 'Add someone to this group to start sharing bills.',
            action: AppButton(
              'Add someone',
              key: const ValueKey('shared-add-someone'),
              icon: Icons.person_add_alt_outlined,
              onPressed: onPeople,
            ),
          )
        : EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No bills yet',
            message: 'Add a bill and everyone’s part is worked out exactly.',
            action: onAdd == null
                ? null
                : AppButton(
                    'Add shared expense',
                    key: const ValueKey('shared-add-first'),
                    icon: Icons.add,
                    onPressed: onAdd!,
                  ),
          );
    final bills = SharedBillsCard(
      key: ValueKey('bills-${g.id}'),
      rows: rows,
      amount: amount,
      available: loaded,
      onOpen: onOpenBill,
      onPage: onPage,
      empty: empty,
    );
    final attention = tasks.isEmpty
        ? null
        : SharedTasksCard(tasks: tasks, onOpen: onTask);
    final chart = SharedOverTimeCard(
      months: sharedByMonth(rows, today),
      amount: amount,
      available: whole,
      hidden: source.hidden,
    );
    final who = WhoPaidCard(
      people: whole ? peopleTotals(g, me) : const [],
      amount: amount,
      available: whole,
    );
    // With something to attend to, Who paid fills the column under it, so a
    // long Bills list has no empty space beside it (§2 lessons).
    final side = attention == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              attention,
              SizedBox(height: Space.cardGapOf(context)),
              who,
            ],
          );
    return DashboardGrid(
      key: const ValueKey('shared-bills-grid'),
      cards: android
          ? null
          : [
              (where, 3, 6),
              (part, 3, 6),
              (spending, 3, 6),
              (needing, 3, 6),
              (bills, side == null ? 12 : 8, 12),
              ?(side == null ? null : (side, 4, 12)),
              (chart, side == null ? 7 : 12, 12),
              ?(side == null ? (who, 5, 12) : null),
            ],
      // On phones Where you stand takes the full width; the next two pair up.
      stacked: [
        KeyedSubtree(child: where),
        part,
        spending,
        ?attention,
        bills,
        who,
        chart,
      ],
    );
  }
}

/// The direction, in words and an arrow, so color is never the only cue.
class StandingWords extends StatelessWidget {
  const StandingWords(this.kind, {super.key});
  final StandingKind kind;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final owed = kind == StandingKind.owedToYou;
    final ink = owed ? c.owedToYou.$1 : c.text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          owed ? Icons.south_west : Icons.north_east,
          size: Space.md,
          color: ink,
        ),
        const SizedBox(width: Space.xxs),
        Flexible(
          child: Text(
            kind.label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: ink),
          ),
        ),
      ],
    );
  }
}
