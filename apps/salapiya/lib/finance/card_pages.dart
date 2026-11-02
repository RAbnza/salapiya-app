import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_cards.dart' show civilLabel, duePill, overviewSpan;
import '../app/overview_data.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import '../p0/exact_money.dart';
import 'card_cards.dart';
import 'card_data.dart';
import 'debt_cards.dart' show civilDay;
import 'finance_screen.dart' show formTitles;
import 'money_cards.dart';
import 'money_data.dart';

/// The pages a card opens (Chat 9). Each reads the source again when it
/// changes, so a record saved from a form shows as soon as it's closed.

/// A statement's state as a pill.
Widget statementPill(StatementRow r) => r.settled
    ? const StatusPill(
        'Nothing due',
        icon: Icons.check_circle_outline,
        tone: PillTone.success,
      )
    : duePill(r.status);

Widget _missing(String title) => SectionPage(
  title: title,
  child: const SurfaceCard(
    child: EmptyState(
      icon: Icons.history,
      title: 'This is no longer here',
      message: 'Go back to Cards to see the others.',
    ),
  ),
);

/// One card: what you owe, its statements, plans and activity.
class CardDetailView extends StatelessWidget {
  const CardDetailView({
    super.key,
    required this.listenable,
    required this.source,
    required this.id,
  });
  final Listenable listenable;
  final MoneySource Function(BuildContext context) source;
  final String id;

  Widget more(MoneySource source, LocalRevision card) {
    final actions = source.actions;
    void open(String op, [Map<String, String>? initial]) => actions.form(
      op,
      formTitles[op]!,
      initial: {'card': card.id, ...?initial},
    );
    final items = [
      ('card-add-statement', 'statement', Icons.receipt_long_outlined),
      ('card-log-fee', 'cardFee', Icons.request_quote_outlined),
      ('card-log-interest', 'cardInterest', Icons.percent),
      ('card-log-refund', 'cardRefund', Icons.undo),
      ('card-log-pending', 'cardAuthorization', Icons.hourglass_empty),
      ('card-add-plan', 'installment', Icons.calendar_month_outlined),
    ];
    return CardMenu(
      key: const ValueKey('card-more'),
      tooltip: 'More actions',
      items: [
        for (final (key, op, icon) in items)
          MenuItemButton(
            key: ValueKey(key),
            leadingIcon: Icon(icon),
            onPressed: () => open(op),
            child: Text(formTitles[op]!),
          ),
        const Divider(height: 1),
        MenuItemButton(
          key: const ValueKey('card-view-record'),
          leadingIcon: const Icon(Icons.description_outlined),
          onPressed: () => actions.openRecord(card.id),
          child: const Text('View record'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: listenable,
    builder: (context, _) {
      final source = this.source(context);
      final s = source.snapshot, today = source.today;
      final amount = source.amount, hidden = source.hidden;
      final actions = source.actions;
      final card = cardRows(s, today).where((c) => c.id == id).firstOrNull;
      if (card == null) return _missing('Card details');
      final android = !isDesktop(context);
      final before = lastMonthEnd(today);
      final activity = moneyActivity(
        s,
        source.categoryName,
        waiting: source.waiting,
      ).where((r) => r.record.values['card'] == id).toList();
      final overview = BalanceCard(
        key: const ValueKey('card-balance'),
        title: 'What you owe',
        caption: 'Not counted in Available money',
        accent: true,
        days: cardDebtByDay(s, id, addCivilDays(today, -29), today),
        months: cardDebtByMonth(s, today, months: 12, card: id),
        amount: amount,
        available: source.complete,
        hidden: hidden,
        empty: activity.isEmpty,
        lead: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MoneyAmount(
              source.complete ? amount(card.owed) : null,
              size: MoneySize.tile,
              textAlign: TextAlign.start,
            ),
            if (card.credit > BigInt.zero) ...[
              const SizedBox(height: Space.xs),
              Text(
                'Card credit ${amount(card.credit)}, not money you have',
                key: const ValueKey('card-credit'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (!hidden && source.complete && activity.isNotEmpty) ...[
              const SizedBox(height: Space.xs),
              ChangeLine(
                basisPoints: changeBasisPoints(
                  card.owed,
                  cardDebtByMonth(s, today, months: 2, card: id).first.$2,
                ),
                versus: 'since ${civilLabel(before)}',
                meaning: ChangeMeaning.riseIsBad,
              ),
            ],
          ],
        ),
        stats: [
          (
            label: 'Available credit',
            value: card.available == null
                ? 'No limit recorded'
                : amount(card.available!),
            detail: 'Not money you have',
          ),
          (
            label: 'Credit limit',
            value: card.limit == null ? 'Not recorded' : amount(card.limit!),
            detail: null,
          ),
          (
            label: 'Credit used',
            value: creditLine(card, amount, hidden: hidden),
            detail: null,
          ),
        ],
      );
      final about = OverviewCard(
        key: const ValueKey('card-about'),
        title: 'About this card',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (card.issuer.isNotEmpty) FactRow('Card issuer', card.issuer),
            FactRow('Balance as of', civilDay(card.card.date)),
            FactRow('Statements', '${card.statements.length}'),
            FactRow('Installment plans', '${card.plans.length}'),
            FactRow('Records', '${activity.length}'),
            if ((card.card.values['notes'] ?? '').isNotEmpty)
              FactRow('Notes', card.card.values['notes']!),
            const ListEnd(key: ValueKey('card-about-end')),
          ],
        ),
      );
      final statements = OverviewCard(
        key: const ValueKey('card-statements'),
        title: 'Statements',
        caption: 'Newest first',
        trailing: CardLink(
          'Add a statement',
          key: const ValueKey('card-statements-add'),
          icon: Icons.add,
          onPressed: () => actions.form(
            'statement',
            formTitles['statement']!,
            initial: {'card': card.card.id},
          ),
        ),
        child: card.statements.isEmpty
            ? const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No statements yet',
                message: 'Add one to see what’s due and compare your records.',
              )
            : AppTable(
                key: const ValueKey('card-statements-table'),
                columns: const [
                  (label: 'Period', flex: 3, width: null),
                  (label: 'Due', flex: 2, width: null),
                ],
                moneyColumns: [if (!hidden) 'Balance', 'Still due'],
                rows: [
                  for (final r in card.statements)
                    _statementRow(context, r, source),
                ],
              ),
      );
      final plans = card.plans.isEmpty
          ? null
          : OverviewCard(
              key: const ValueKey('card-plans'),
              title: 'Installment plans',
              caption: 'Expected payments, not new spending',
              child: ListGroup(
                children: [
                  for (final p in card.plans)
                    AdaptiveRow(
                      key: ValueKey('plan-${p.plan.actionId}'),
                      title: p.plan.title,
                      subtitle: detailLine([
                        '${p.done} of ${p.total} payments',
                        if (p.next case final n?)
                          'Next ${civilLabel(n.row.date)}',
                      ]),
                      trailing: MoneyAmount(amount(p.left), caption: 'Left'),
                      onTap: () => actions.openItem(p.plan.actionId),
                    ),
                ],
              ),
            );
      final pending = pendingCharges(s, id);
      final held = pending.isEmpty
          ? null
          : OverviewCard(
              key: const ValueKey('card-pending'),
              title: 'Pending charges',
              caption: 'Not in what you owe yet',
              child: ListGroup(
                children: [
                  for (final r in pending)
                    AdaptiveRow(
                      title: r.title,
                      subtitle: civilDay(r.date),
                      trailing: MoneyAmount(amount(r.amount)),
                      onTap: () => actions.openRecord(r.id),
                    ),
                ],
              ),
            );
      final recent = RecordListCard(
        key: const ValueKey('card-activity'),
        title: 'Activity',
        caption:
            '${activity.length} ${activity.length == 1 ? 'record' : 'records'}',
        rows: activity,
        amount: amount,
        hidden: hidden,
        onOpen: actions.openRecord,
        empty: const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No activity yet',
          message: 'Purchases and payments on this card show here.',
        ),
      );
      return SectionPage(
        title: card.name,
        caption: [
          if (card.issuer.isNotEmpty) card.issuer,
          'Since ${civilDay(card.card.date)}',
        ].join(' · '),
        status: card.over > BigInt.zero
            ? const StatusPill(
                'Over the limit',
                icon: Icons.warning_amber_rounded,
                tone: PillTone.warning,
              )
            : card.newest != null && !card.newest!.settled
            ? duePill(card.newest!.status)
            : null,
        actions: [
          CompactForm(
            child: AppButton(
              'Log a card payment',
              key: const ValueKey('card-log-payment'),
              icon: Icons.add,
              onPressed: () => logCardPayment(actions, s, id),
            ),
          ),
          more(source, card.card),
        ],
        child: DashboardGrid(
          key: ValueKey(('card-grid', id)),
          cards: android
              ? null
              : [
                  (overview, 8, 12),
                  (about, 4, 12),
                  (statements, 12, 12),
                  ?(plans == null ? null : (plans, 12, 12)),
                  ?(held == null ? null : (held, 12, 12)),
                  (recent, 12, 12),
                ],
          stacked: [overview, statements, ?plans, ?held, recent, about],
        ),
      );
    },
  );

  AppTableRow _statementRow(
    BuildContext context,
    StatementRow r,
    MoneySource source,
  ) {
    final text = Theme.of(context).textTheme;
    final amount = source.amount, hidden = source.hidden;
    final period = overviewSpan(r.start, r.end);
    return AppTableRow(
      id: 'statement-${r.id}',
      spoken: [
        period,
        'Due ${civilLabel(r.due)}',
        if (!hidden) 'Balance ${amount(r.balance)}',
        'Still due ${amount(r.stillDue)}',
      ].join(', '),
      onTap: () => source.actions.openItem(r.id),
      cells: [
        Text(period, style: text.bodyMedium),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(civilLabel(r.due), style: text.bodySmall),
            const SizedBox(height: Space.xxs),
            statementPill(r),
          ],
        ),
      ],
      money: [if (!hidden) amount(r.balance), amount(r.stillDue)],
      narrow: KeyedSubtree(
        key: ValueKey('row-statement-${r.id}'),
        child: AdaptiveRow(
          title: period,
          subtitle: 'Due ${civilLabel(r.due)}',
          trailing: MoneyAmount(amount(r.stillDue), caption: 'Still due'),
          onTap: () => source.actions.openItem(r.id),
        ),
      ),
    );
  }
}

/// One statement: what the issuer said, what's paid, and how it compares
/// with your records. A difference stays until you resolve it.
class StatementDetailView extends StatelessWidget {
  const StatementDetailView({
    super.key,
    required this.listenable,
    required this.source,
    required this.id,
  });
  final Listenable listenable;
  final MoneySource Function(BuildContext context) source;
  final String id;

  void matchActivity(MoneySource source, StatementRow r, [String? activity]) =>
      source.actions.form(
        'statementLink',
        formTitles['statementLink']!,
        initial: {
          'card': cardRecord(source.snapshot, r.card)?.id ?? r.card,
          'statement': r.id,
          'activity': ?activity,
        },
      );

  void matchPayment(MoneySource source, StatementRow r) => source.actions.form(
    'cardAllocation',
    formTitles['cardAllocation']!,
    initial: {
      'card': cardRecord(source.snapshot, r.card)?.id ?? r.card,
      'statement': r.id,
    },
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: listenable,
    builder: (context, _) {
      final source = this.source(context);
      final s = source.snapshot, today = source.today;
      final amount = source.amount;
      final actions = source.actions;
      final record = s.current
          .where((r) => r.actionId == id && financeType(r) == 'statement')
          .firstOrNull;
      if (record == null) return _missing('Statement');
      final r = statementRows(
        s,
        record.values['card']!,
        today,
      ).firstWhere((x) => x.id == record.id);
      final android = !isDesktop(context);
      final text = Theme.of(context).textTheme;
      final name = cardName(s, r.card);
      final period = overviewSpan(r.start, r.end);
      final summary = OverviewCard(
        key: const ValueKey('statement-summary'),
        title: 'This statement',
        accent: true,
        centered: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Still due', style: text.bodySmall),
            const SizedBox(height: Space.xxs),
            MoneyAmount(
              amount(r.stillDue),
              size: MoneySize.tile,
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: Space.md),
            StatStrip(
              stats: [
                (
                  label: 'Statement balance',
                  value: amount(r.balance),
                  detail: null,
                ),
                (
                  label: 'Matched payments',
                  value: amount(r.paid),
                  detail: null,
                ),
                (
                  label: 'Minimum due',
                  value: r.minimum == null
                      ? 'Not recorded'
                      : amount(r.minimum!),
                  detail: null,
                ),
                (label: 'Due date', value: civilDay(r.due), detail: null),
              ],
            ),
          ],
        ),
      );
      final same = r.difference == BigInt.zero;
      final compare = OverviewCard(
        key: const ValueKey('statement-compare'),
        title: 'Compared with your records',
        caption: 'By the date each record posted',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FactRow('Statement says', amount(r.balance)),
            FactRow('Your records say', amount(r.recorded)),
            FactRow('Difference', amount(r.difference)),
            const SizedBox(height: Space.xs),
            Text(
              same ? 'They match.' : 'Log what’s missing, or check the statement. Nothing changes until you do.',
              key: const ValueKey('statement-compare-note'),
              style: text.bodySmall,
            ),
          ],
        ),
      );
      AppTableRow activityRow(LocalRevision x, {bool match = false}) {
        final type = moneyLabel(x);
        final shown = amount(x.amount);
        return AppTableRow(
          id: 'activity-${x.id}',
          spoken: [civilDay(postedOn(x)), x.title, type, shown].join(', '),
          onTap: () => actions.openRecord(x.id),
          cells: [
            Text(civilDay(postedOn(x)), style: text.bodyMedium),
            Text(recordTitle(x), style: text.bodyMedium),
            Text(type, style: text.bodySmall),
          ],
          money: [shown],
          action: match
              ? CardLink(
                  'Match',
                  key: ValueKey('match-${x.id}'),
                  onPressed: () => matchActivity(source, r, x.id),
                )
              : null,
          narrow: KeyedSubtree(
            key: ValueKey('row-activity-${x.id}'),
            child: AdaptiveRow(
              title: recordTitle(x),
              subtitle: detailLine([civilDay(postedOn(x)), type]),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MoneyAmount(shown),
                  if (match)
                    CardLink(
                      'Match',
                      key: ValueKey('match-${x.id}'),
                      chevron: false,
                      onPressed: () => matchActivity(source, r, x.id),
                    ),
                ],
              ),
              onTap: () => actions.openRecord(x.id),
            ),
          ),
        );
      }

      final matched = matchedActivity(s, r.statement);
      final loose = unmatchedActivity(s, r.statement);
      const columns = [
        (label: 'Date it posted', flex: 0, width: dateColumn),
        (label: 'Description', flex: 3, width: null),
        (label: 'Type', flex: 2, width: null),
      ];
      final onIt = OverviewCard(
        key: const ValueKey('statement-activity'),
        title: 'On this statement',
        caption: '${matched.length} matched',
        corner: CardMenu(
          key: const ValueKey('statement-menu'),
          tooltip: 'More',
          items: [
            MenuItemButton(
              key: const ValueKey('statement-open-page'),
              leadingIcon: const Icon(Icons.open_in_full),
              onPressed: () => openDemoPage<void>(
                context,
                SectionPage(
                  title: '$name statement',
                  child: SurfaceCard(
                    child: _StatementShare(
                      row: r,
                      matched: matched,
                      name: name,
                      today: today,
                      amount: amount,
                      onOpen: actions.openRecord,
                    ),
                  ),
                ),
                'money/card-statement/${r.id}',
              ),
              child: const Text('Open as a page'),
            ),
          ],
        ),
        child: matched.isEmpty
            ? const EmptyState(
                icon: Icons.link_off,
                title: 'Nothing matched yet',
                message: 'Match activity to confirm it’s on this statement.',
              )
            : AppTable(
                key: const ValueKey('statement-matched-table'),
                dense: true,
                columns: columns,
                moneyColumns: const ['Amount'],
                rows: [for (final x in matched) activityRow(x)],
              ),
      );
      final suggested = loose.isEmpty
          ? null
          : OverviewCard(
              key: const ValueKey('statement-suggested'),
              title: 'Posted in this period, not matched yet',
              caption: 'Dates alone don’t show it’s on the statement',
              child: AppTable(
                key: const ValueKey('statement-loose-table'),
                dense: true,
                columns: columns,
                moneyColumns: const ['Amount'],
                actionLabel: 'Match',
                rows: [for (final x in loose) activityRow(x, match: true)],
              ),
            );
      return SectionPage(
        title: '$name statement',
        caption: '$period · Due ${civilDay(r.due)}',
        status: statementPill(r),
        actions: [
          CompactForm(
            child: AppButton(
              'Log a card payment',
              key: const ValueKey('statement-log-payment'),
              icon: Icons.add,
              onPressed: () =>
                  logCardPayment(actions, s, r.card, left: r.stillDue),
            ),
          ),
          CardMenu(
            key: const ValueKey('statement-more'),
            tooltip: 'More actions',
            items: [
              MenuItemButton(
                key: const ValueKey('statement-match-payment'),
                leadingIcon: const Icon(Icons.link),
                onPressed: () => matchPayment(source, r),
                child: const Text('Match a payment'),
              ),
              MenuItemButton(
                key: const ValueKey('statement-match-activity'),
                leadingIcon: const Icon(Icons.playlist_add_check),
                onPressed: () => matchActivity(source, r),
                child: const Text('Match activity'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                key: const ValueKey('statement-view-record'),
                leadingIcon: const Icon(Icons.description_outlined),
                onPressed: () => actions.openRecord(r.id),
                child: const Text('View record'),
              ),
            ],
          ),
        ],
        child: DashboardGrid(
          key: ValueKey(('statement-grid', id)),
          cards: android
              ? null
              : [
                  (summary, 8, 12),
                  (compare, 4, 12),
                  (onIt, 12, 12),
                  ?(suggested == null ? null : (suggested, 12, 12)),
                ],
          stacked: [summary, compare, onIt, ?suggested],
        ),
      );
    },
  );
}

/// The statement as one screenshot: every matched item, no row limit.
class _StatementShare extends StatelessWidget {
  const _StatementShare({
    required this.row,
    required this.matched,
    required this.name,
    required this.today,
    required this.amount,
    required this.onOpen,
  });
  final StatementRow row;
  final List<LocalRevision> matched;
  final String name, today;
  final String Function(BigInt) amount;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = CraftTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${overviewSpan(row.start, row.end)} · as of ${civilLabel(today)}',
          key: const ValueKey('statement-share-heading'),
          style: text.bodySmall?.copyWith(color: c.secondary),
        ),
        const SizedBox(height: Space.sm),
        StatStrip(
          stats: [
            (label: 'Balance', value: amount(row.balance), detail: null),
            (label: 'Paid', value: amount(row.paid), detail: null),
            (label: 'Still due', value: amount(row.stillDue), detail: null),
            (label: 'Due date', value: civilDay(row.due), detail: null),
          ],
        ),
        const SizedBox(height: Space.md),
        if (matched.isEmpty)
          const EmptyState(
            icon: Icons.link_off,
            title: 'Nothing matched yet',
            message: 'Matched activity shows here.',
          )
        else
          AppTable(
            key: const ValueKey('statement-share-table'),
            dense: true,
            columns: const [
              (label: 'Date it posted', flex: 0, width: dateColumn),
              (label: 'Description', flex: 3, width: null),
              (label: 'Type', flex: 2, width: null),
            ],
            moneyColumns: const ['Amount'],
            rows: [
              for (final x in matched)
                AppTableRow(
                  id: 'share-${x.id}',
                  spoken: [
                    civilDay(postedOn(x)),
                    x.title,
                    amount(x.amount),
                  ].join(', '),
                  onTap: () => onOpen(x.id),
                  cells: [
                    Text(civilDay(postedOn(x)), style: text.bodyMedium),
                    Text(recordTitle(x), style: text.bodyMedium),
                    Text(moneyLabel(x), style: text.bodySmall),
                  ],
                  money: [amount(x.amount)],
                  narrow: AdaptiveRow(
                    title: recordTitle(x),
                    subtitle: civilDay(postedOn(x)),
                    trailing: MoneyAmount(amount(x.amount)),
                    onTap: () => onOpen(x.id),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Everything still open on the cards, overdue first, with no row limit.
/// Statements and installments are listed apart and never added up.
class CardDuesPage extends StatelessWidget {
  const CardDuesPage({
    super.key,
    required this.listenable,
    required this.source,
  });
  final Listenable listenable;
  final MoneySource Function(BuildContext context) source;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: listenable,
    builder: (context, _) {
      final source = this.source(context);
      final s = source.snapshot, today = source.today;
      final amount = source.amount, actions = source.actions;
      final text = Theme.of(context).textTheme;
      final dues = cardDues(s, today);
      void log(CardDue d) =>
          logCardPayment(actions, s, d.card, left: d.item.amount);
      return SectionPage(
        title: 'Due on your cards',
        caption:
            'As of ${civilLabel(today)} · Statements and installments can overlap',
        child: SurfaceCard(
          child: dues.isEmpty
              ? const EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Nothing due on your cards',
                  message: 'Statements you add show here until they’re paid.',
                )
              : AppTable(
                  key: const ValueKey('card-dues-table'),
                  columns: const [
                    (label: 'Due', flex: 2, width: null),
                    (label: 'Card', flex: 2, width: null),
                    (label: 'Type', flex: 2, width: null),
                  ],
                  moneyColumns: const ['Amount'],
                  actionLabel: 'Log payment',
                  rows: [
                    for (final d in dues)
                      AppTableRow(
                        id: 'all-due-${d.id}',
                        spoken: [
                          d.name,
                          d.kind,
                          civilLabel(d.item.date),
                          d.item.status.label,
                          amount(d.item.amount),
                        ].join(', '),
                        onTap: () => actions.openItem(d.source),
                        cells: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                civilLabel(d.item.date),
                                style: text.bodyMedium,
                              ),
                              const SizedBox(height: Space.xxs),
                              duePill(d.item.status),
                            ],
                          ),
                          Text(d.name, style: text.bodyMedium),
                          Text(d.kind, style: text.bodySmall),
                        ],
                        money: [amount(d.item.amount)],
                        action: CardLink(
                          'Log payment',
                          key: ValueKey('all-due-log-${d.id}'),
                          chevron: false,
                          onPressed: () => log(d),
                        ),
                        narrow: AdaptiveRow(
                          key: ValueKey('row-all-due-${d.id}'),
                          title: d.name,
                          subtitle: dueDetail(d),
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MoneyAmount(amount(d.item.amount)),
                              CardLink(
                                'Log payment',
                                key: ValueKey('all-due-log-${d.id}'),
                                chevron: false,
                                onPressed: () => log(d),
                              ),
                            ],
                          ),
                          onTap: () => actions.openItem(d.source),
                        ),
                      ),
                  ],
                ),
        ),
      );
    },
  );
}

/// One installment plan: a step per payment, and what's left on each.
class PlanDetailView extends StatelessWidget {
  const PlanDetailView({
    super.key,
    required this.listenable,
    required this.source,
    required this.id,
  });
  final Listenable listenable;
  final MoneySource Function(BuildContext context) source;
  final String id;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: listenable,
    builder: (context, _) {
      final source = this.source(context);
      final s = source.snapshot, today = source.today;
      final amount = source.amount;
      final actions = source.actions;
      final record = s.current
          .where((r) => r.actionId == id && financeType(r) == 'installment')
          .firstOrNull;
      if (record == null) return _missing('Installment plan');
      final card = record.values['card']!;
      final plan = planRows(
        s,
        card,
        today,
      ).firstWhere((p) => p.id == record.id);
      final android = !isDesktop(context);
      final text = Theme.of(context).textTheme;
      final c = CraftTheme.of(context);
      final cardId = cardRecord(s, card)?.id ?? card;
      void match([String? row]) => actions.form(
        'installmentApplication',
        formTitles['installmentApplication']!,
        initial: {'card': cardId, 'plan': plan.id, 'row': ?row},
      );
      final summary = OverviewCard(
        key: const ValueKey('plan-summary'),
        title: 'Payments',
        accent: true,
        centered: true,
        child: Semantics(
          label:
              '${plan.done} of ${plan.total} payments. ${amount(plan.left)} left of ${amount(plan.amount)}.',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MoneyAmount(
                amount(plan.left),
                size: MoneySize.tile,
                textAlign: TextAlign.start,
                caption: 'Left of ${amount(plan.amount)}',
              ),
              const SizedBox(height: Space.md),
              SegmentBar(done: plan.done, total: plan.total, track: c.surface),
              const SizedBox(height: Space.xs),
              Text(
                '${plan.done} of ${plan.total} payments matched',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      );
      final facts = <(String, String?)>[
        ('Card', cardName(s, card)),
        (
          'Purchase',
          s.revisions
              .where((r) => r.id == record.values['purchase'])
              .lastOrNull
              ?.title,
        ),
        if ((record.values['principal'] ?? '').isNotEmpty)
          ('Principal', amount(parsePhp(record.values['principal']!))),
        if ((record.values['interest'] ?? '').isNotEmpty)
          ('Interest', amount(parsePhp(record.values['interest']!))),
        if ((record.values['fee'] ?? '').isNotEmpty)
          ('Fee', amount(parsePhp(record.values['fee']!))),
        if ((record.values['reference'] ?? '').isNotEmpty)
          ('Reference', record.values['reference']),
      ];
      final about = OverviewCard(
        key: const ValueKey('plan-about'),
        title: 'About this plan',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (label, value) in facts)
              if (value != null) FactRow(label, value),
            const ListEnd(key: ValueKey('plan-about-end')),
          ],
        ),
      );
      final rows = OverviewCard(
        key: const ValueKey('plan-payments'),
        title: 'Each payment',
        caption: 'Expected amounts, not new spending',
        child: AppTable(
          key: const ValueKey('plan-table'),
          columns: const [
            (label: 'Payment', flex: 3, width: null),
            (label: 'Due', flex: 2, width: null),
          ],
          moneyColumns: const ['Amount', 'Left'],
          actionLabel: 'Match',
          rows: [
            for (final p in plan.payments)
              AppTableRow(
                id: 'plan-row-${p.row.id}',
                spoken: [
                  p.row.id,
                  civilLabel(p.row.date),
                  amount(p.row.amount),
                  'Left ${amount(p.left)}',
                ].join(', '),
                cells: [
                  Text(p.row.id, style: text.bodyMedium),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(civilLabel(p.row.date), style: text.bodySmall),
                      const SizedBox(height: Space.xxs),
                      p.done
                          ? const StatusPill(
                              'Matched',
                              icon: Icons.check_circle_outline,
                              tone: PillTone.success,
                            )
                          : duePill(p.status),
                    ],
                  ),
                ],
                money: [amount(p.row.amount), amount(p.left)],
                action: p.done
                    ? null
                    : CardLink(
                        'Match',
                        key: ValueKey('plan-match-${p.row.id}'),
                        onPressed: () => match(p.row.id),
                      ),
                narrow: AdaptiveRow(
                  title: p.row.id,
                  subtitle: civilLabel(p.row.date),
                  trailing: MoneyAmount(
                    amount(p.left),
                    caption: p.done ? 'Matched' : 'Left',
                  ),
                  onTap: p.done ? null : () => match(p.row.id),
                ),
              ),
          ],
        ),
      );
      return SectionPage(
        title: plan.plan.title,
        caption: '${cardName(s, card)} · ${plan.total} payments',
        status: plan.finished
            ? const StatusPill(
                'All matched',
                icon: Icons.check_circle_outline,
                tone: PillTone.success,
              )
            : duePill(plan.next!.status),
        actions: [
          if (!plan.finished)
            CompactForm(
              child: AppButton(
                'Match a payment',
                key: const ValueKey('plan-match'),
                icon: Icons.link,
                onPressed: match,
              ),
            ),
          CardMenu(
            key: const ValueKey('plan-more'),
            tooltip: 'More actions',
            items: [
              MenuItemButton(
                key: const ValueKey('plan-view-record'),
                leadingIcon: const Icon(Icons.description_outlined),
                onPressed: () => actions.openRecord(plan.id),
                child: const Text('View record'),
              ),
            ],
          ),
        ],
        child: DashboardGrid(
          key: ValueKey(('plan-grid', id)),
          cards: android
              ? null
              : [(summary, 8, 12), (about, 4, 12), (rows, 12, 12)],
          stacked: [summary, rows, about],
        ),
      );
    },
  );
}
