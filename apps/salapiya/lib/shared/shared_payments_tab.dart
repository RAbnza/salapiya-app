import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../finance/debt_cards.dart' show civilMonth;
import 'shared_cards.dart';
import 'shared_data.dart';
import 'shared_domain.dart';

/// "Who paid whom, and what's waiting to be confirmed?" Nothing here moves
/// money: these are records of payments made elsewhere.
class SharedPaymentsTab extends StatelessWidget {
  const SharedPaymentsTab({
    super.key,
    required this.source,
    required this.group,
    required this.onOpen,
    required this.onConfirm,
    required this.onLog,
    required this.onTask,
    required this.onBalances,
    required this.onPage,
    this.onPair,
  });
  final SharedSource source;
  final SharedGroup group;
  final ValueChanged<SharedPaymentRow> onOpen;

  /// Null while there's no connection.
  final ValueChanged<SharedPaymentRow>? onConfirm;

  /// Null when this group can't take a new payment.
  final ValueChanged<String>? onLog;
  final ValueChanged<SharedTask> onTask;
  final VoidCallback onBalances, onPage;

  /// Opens everything between the user and one person.
  final ValueChanged<String>? onPair;

  @override
  Widget build(BuildContext context) {
    final android = !isDesktop(context);
    final g = group, today = source.today, amount = source.amount;
    final me = g.participant(source.actor ?? '');
    final loaded = source.complete;
    final whole = loaded && g.complete;
    final rows = loaded
        ? sharedPaymentRows(g, me, today)
        : const <SharedPaymentRow>[];
    final standing = sharedStanding(g, me);
    final month = monthOf(today);
    final (inAmount, inCount) = paymentTotal(
      rows.where((p) => p.status == PaymentStatus.toConfirm),
    );
    final (outAmount, outCount) = paymentTotal(
      rows.where(
        (p) =>
            p.status == PaymentStatus.waiting && p.role == PaymentRole.sender,
      ),
    );
    final (doneAmount, doneCount) = paymentTotal(
      rows.where(
        (p) => p.status == PaymentStatus.confirmed && monthOf(p.date) == month,
      ),
    );
    const labels = [
      'To confirm',
      'Waiting for others',
      'Confirmed this month',
      'If all are confirmed',
    ];
    Widget figure(String? text, {MoneyKind kind = MoneyKind.neutral}) =>
        MoneyAmount(
          text,
          kind: kind,
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        );
    String count(int n) => '$n ${n == 1 ? 'payment' : 'payments'}';
    final confirm = KpiTile(
      key: const ValueKey('shared-to-confirm-tile'),
      labels: labels,
      accent: true,
      icon: Icons.how_to_reg_outlined,
      label: 'To confirm',
      value: figure(
        !loaded
            ? null
            : inCount == 0
            ? 'Nothing waiting'
            : amount(inAmount),
      ),
      caption: !loaded || inCount == 0 ? null : '${count(inCount)} for you',
    );
    final waiting = KpiTile(
      key: const ValueKey('shared-waiting-tile'),
      labels: labels,
      icon: Icons.schedule,
      label: 'Waiting for others',
      value: figure(
        !loaded
            ? null
            : outCount == 0
            ? 'Nothing waiting'
            : amount(outAmount),
      ),
      caption: !loaded || outCount == 0
          ? null
          : '${count(outCount)} you logged',
    );
    final confirmed = KpiTile(
      key: const ValueKey('shared-confirmed-tile'),
      labels: labels,
      icon: Icons.check_circle_outline,
      label: 'Confirmed this month',
      value: figure(whole ? amount(doneAmount) : null),
      caption: whole ? '${count(doneCount)} in ${civilMonth(today)}' : null,
    );
    final hasPosition = whole && standing.kind != StandingKind.unknown;
    final position = standing.kind == StandingKind.owedToYou
        ? standing.amount
        : -standing.amount;
    final next = standing.projected ?? position;
    final ifAll = KpiTile(
      key: const ValueKey('shared-projected-tile'),
      labels: labels,
      icon: Icons.account_balance_wallet_outlined,
      label: 'If all are confirmed',
      value: figure(
        !hasPosition
            ? null
            : next == BigInt.zero
            ? 'All square'
            : amount(next.abs()),
        kind: !hasPosition || next == BigInt.zero
            ? MoneyKind.neutral
            : next > BigInt.zero
            ? MoneyKind.owedToYou
            : MoneyKind.owed,
      ),
      caption: !hasPosition
          ? null
          : next == BigInt.zero
          ? 'Only once they’re confirmed'
          : '${next > BigInt.zero ? 'You’d be owed' : 'You’d owe'} this. Only once they’re confirmed',
    );
    final open = SharedWaitingCard(
      group: g,
      me: me,
      rows: openPayments(rows),
      amount: amount,
      available: loaded,
      onOpen: onOpen,
      onConfirm: onConfirm,
    );
    final between = SharedPairsCard(
      group: g,
      me: me,
      pairs: whole ? pairsWithMe(g, me) : const [],
      amount: amount,
      available: whole,
      onLog: onLog,
      onBalances: onBalances,
      onOpen: onPair,
    );
    final tasks = loaded
        ? sharedTasks(source, g, scope: SharedTaskScope.payments)
        : const <SharedTask>[];
    final attention = tasks.isEmpty
        ? null
        : SharedTasksCard(tasks: tasks, onOpen: onTask);
    final all = SharedPaymentsCard(
      key: ValueKey('payments-${g.id}'),
      group: g,
      rows: rows,
      amount: amount,
      available: loaded,
      onOpen: onOpen,
      onPage: onPage,
    );
    return DashboardGrid(
      key: const ValueKey('shared-payments-grid'),
      cards: android
          ? null
          : [
              (confirm, 3, 6),
              (waiting, 3, 6),
              (confirmed, 3, 6),
              (ifAll, 3, 6),
              (open, 7, 12),
              (between, 5, 12),
              ?(attention == null ? null : (attention, 12, 12)),
              (all, 12, 12),
            ],
      // On phones To confirm takes the full width; the next two pair up.
      stacked: [
        KeyedSubtree(child: confirm),
        waiting,
        confirmed,
        KeyedSubtree(child: ifAll),
        open,
        ?attention,
        between,
        all,
      ],
    );
  }
}
