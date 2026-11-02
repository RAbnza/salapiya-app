import 'package:flutter/material.dart';

import '../app/overview_cards.dart' show civilLabel;
import '../app/overview_data.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import 'debt_cards.dart' show civilDay;
import 'finance_screen.dart' show formTitles;
import 'money_cards.dart';
import 'money_data.dart';
import 'planning_cards.dart';
import 'planning_data.dart';

/// The pages Planning opens (Chat 9). Budgets, goals and recurring items are
/// edited through corrections, because the rules keep every earlier version.

Widget _missing(String title) => SectionPage(
  title: title,
  child: const SurfaceCard(
    child: EmptyState(
      icon: Icons.history,
      title: 'This is no longer here',
      message: 'Go back to Planning to see the others.',
    ),
  ),
);

/// One budget: its whole period against its limit, and what counted.
class BudgetDetailView extends StatelessWidget {
  const BudgetDetailView({
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
      final amount = source.amount, hidden = source.hidden;
      final actions = source.actions;
      final record = s.current
          .where((r) => r.actionId == id && financeType(r) == 'budget')
          .firstOrNull;
      if (record == null) return _missing('Budget');
      final android = !isDesktop(context);
      final c = CraftTheme.of(context);
      final text = Theme.of(context).textTheme;
      final b = BudgetProgress(record, budgetSpending(s, record));
      final when = budgetWhen(record, today);
      final start = record.values['start']!;
      final last = lastDay(record.values['endExclusive']!);
      final net = record.values['basis'] != 'gross';
      final category = source.categoryName(record.values['category']);
      final over = b.overLimit;
      final days = dailySpending(s, start, last);
      final rows =
          moneyActivity(s, source.categoryName, waiting: source.waiting)
              .where(
                (r) =>
                    !r.reversed &&
                    r.effect.postings.any(
                      (p) =>
                          p.ledger == 'expense' &&
                          p.category == record.values['category'] &&
                          p.date.compareTo(start) >= 0 &&
                          p.date.compareTo(last) <= 0 &&
                          (net || p.amount > BigInt.zero),
                    ),
              )
              .toList();
      final period = OverviewCard(
        key: const ValueKey('budget-summary'),
        title: 'This period',
        caption: budgetPeriodLabel(record),
        accent: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MoneyAmount(
              amount(b.spent),
              size: MoneySize.tile,
              textAlign: TextAlign.start,
              caption: 'Spent of ${amount(b.limit)}',
            ),
            if (!hidden) ...[
              const SizedBox(height: Space.sm),
              if (b.basisPoints != null)
                SlimBar(
                  fraction: b.basisPoints! / 10000,
                  track: c.surface,
                  color: over ? c.tone(NoticeTone.warning).$1 : null,
                ),
              const SizedBox(height: Space.xs),
              Text(BudgetsCard.line(b, amount), style: text.bodySmall),
              const SizedBox(height: Space.md),
              OverviewBarChart(
                values: [for (final d in days) d.$2],
                label: (i) => i % 7 == 0 && i < days.length
                    ? civilLabel(days[i].$1).split(', ').last
                    : null,
                tooltip: (i) =>
                    '${civilLabel(days[i].$1)}\n${amount(days[i].$2)}',
                semanticsLabel:
                    'Spending each day in ${budgetPeriodLabel(record)}, ${amount(b.spent)} in all.',
              ),
              const SizedBox(height: Space.md),
              StatStrip(
                stats: [
                  (label: 'Limit', value: amount(b.limit), detail: null),
                  (label: 'Spent', value: amount(b.spent), detail: null),
                  (
                    label: 'Left',
                    value: amount(b.remaining),
                    detail: over ? 'Over the limit' : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      );
      final about = OverviewCard(
        key: const ValueKey('budget-about'),
        title: 'About this budget',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FactRow('Category', category),
            FactRow('Period', budgetPeriodLabel(record)),
            FactRow(
              'What counts',
              net ? 'Spending after refunds' : 'Spending before refunds',
            ),
            FactRow('Status', when.label),
            if ((record.values['notes'] ?? '').isNotEmpty)
              FactRow('Notes', record.values['notes']!),
            const ListEnd(key: ValueKey('budget-about-end')),
          ],
        ),
      );
      final spending = RecordListCard(
        key: const ValueKey('budget-records'),
        title: 'Spending in this budget',
        caption: '${rows.length} ${rows.length == 1 ? 'record' : 'records'}',
        rows: rows,
        amount: amount,
        hidden: hidden,
        onOpen: actions.openRecord,
        empty: const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No spending yet',
          message: 'Expenses in this category show here.',
        ),
      );
      final archived = record.values['status'] == 'archived';
      return SectionPage(
        title: record.title,
        caption: '$category · ${budgetPeriodLabel(record)}',
        status: archived
            ? const StatusPill('Archived', icon: Icons.archive_outlined)
            : over
            ? const StatusPill(
                'Over the limit',
                icon: Icons.warning_amber_rounded,
                tone: PillTone.warning,
              )
            : b.basisPoints == null
            ? const StatusPill('Zero-limit budget', icon: Icons.block)
            : const StatusPill(
                'Within limit',
                icon: Icons.check_circle_outline,
                tone: PillTone.success,
              ),
        actions: [
          CompactForm(
            child: AppButton(
              'Edit budget',
              key: const ValueKey('budget-edit'),
              icon: Icons.edit_outlined,
              onPressed: () => actions.form(
                'financeCorrection',
                'Edit budget',
                replacing: record,
              ),
            ),
          ),
          CardMenu(
            key: const ValueKey('budget-more'),
            tooltip: 'More actions',
            items: [
              MenuItemButton(
                key: const ValueKey('budget-archive'),
                leadingIcon: const Icon(Icons.archive_outlined),
                onPressed: () => actions.form(
                  'financeCorrection',
                  archived ? 'Restore budget' : 'Archive budget',
                  replacing: record,
                  overrides: {'status': archived ? 'active' : 'archived'},
                ),
                child: Text(archived ? 'Restore budget' : 'Archive budget'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                key: const ValueKey('budget-view-record'),
                leadingIcon: const Icon(Icons.description_outlined),
                onPressed: () => actions.openRecord(record.id),
                child: const Text('View record'),
              ),
            ],
          ),
        ],
        child: DashboardGrid(
          key: ValueKey(('budget-grid', id)),
          cards: android
              ? null
              : [(period, 8, 12), (about, 4, 12), (spending, 12, 12)],
          stacked: [period, spending, about],
        ),
      );
    },
  );
}

/// One goal: what's set aside, whether your accounts cover it, and where.
class GoalDetailView extends StatelessWidget {
  const GoalDetailView({
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
      final amount = source.amount, hidden = source.hidden;
      final actions = source.actions;
      final record = s.current
          .where((r) => r.actionId == id && financeType(r) == 'savingsGoal')
          .firstOrNull;
      if (record == null) return _missing('Goal');
      final android = !isDesktop(context);
      final c = CraftTheme.of(context);
      final text = Theme.of(context).textTheme;
      final g = goalRow(s, record, today);
      final accounts = goalAccounts(s, id, today);
      final active = g.status == 'active';
      void aside([Map<String, String> more = const {}]) => actions.form(
        'reservation',
        formTitles['reservation']!,
        initial: {'goal': record.id, ...more},
      );
      void status(String title, String value) => actions.form(
        'financeCorrection',
        title,
        replacing: record,
        overrides: {'status': value},
      );
      final progress = OverviewCard(
        key: const ValueKey('goal-summary'),
        title: 'Progress',
        caption: 'Money set aside stays in your accounts',
        accent: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MoneyAmount(
              amount(g.reserved),
              size: MoneySize.tile,
              textAlign: TextAlign.start,
              caption: 'Set aside of ${amount(g.target)}',
            ),
            if (!hidden) ...[
              const SizedBox(height: Space.sm),
              SlimBar(fraction: (g.basisPoints ?? 0) / 10000, track: c.surface),
              const SizedBox(height: Space.xs),
              Text(goalLine(g, amount), style: text.bodySmall),
              const SizedBox(height: Space.md),
              StatStrip(
                key: const ValueKey('goal-funding'),
                stats: [
                  (
                    label: 'Your accounts cover',
                    value: g.low == g.high
                        ? amount(g.low)
                        : '${amount(g.low)} to ${amount(g.high)}',
                    detail: g.low == g.high ? null : 'Shared with other goals',
                  ),
                  (
                    label: 'Target',
                    value: amount(g.target),
                    detail: g.targetDate == null
                        ? null
                        : 'By ${civilLabel(g.targetDate!)}',
                  ),
                ],
              ),
            ],
          ],
        ),
      );
      final about = OverviewCard(
        key: const ValueKey('goal-about'),
        title: 'About this goal',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FactRow(
              'Status',
              active
                  ? g.funding.label
                  : g.status == 'completed'
                  ? 'Completed'
                  : 'Archived',
            ),
            FactRow('Started', civilDay(record.date)),
            if (g.targetDate != null)
              FactRow('Target date', civilDay(g.targetDate!)),
            if ((record.values['notes'] ?? '').isNotEmpty)
              FactRow('Notes', record.values['notes']!),
            const ListEnd(key: ValueKey('goal-about-end')),
          ],
        ),
      );
      final where = OverviewCard(
        key: const ValueKey('goal-accounts'),
        title: 'Where it’s set aside',
        caption: 'If an account runs short, no goal is chosen for you',
        child: accounts.isEmpty
            ? const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Nothing set aside yet',
                message: 'Set money aside from an account you already have.',
              )
            : ListGroup(
                children: [
                  for (final a in accounts)
                    AdaptiveRow(
                      key: ValueKey('goal-account-${a.account.id}'),
                      leading: accountIcon(a.account.kind),
                      title: a.account.name,
                      subtitle: hidden || a.shortfall == BigInt.zero
                          ? 'Set aside here'
                          : 'Short by ${amount(a.shortfall)}',
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MoneyAmount(amount(a.reserved)),
                          CardLink(
                            'Release',
                            key: ValueKey('goal-release-${a.account.id}'),
                            onPressed: () => aside({
                              'account': a.account.id,
                              'amount': '0.00',
                            }),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      );
      final history = s.current
          .where(
            (r) =>
                const {
                  'reservation',
                  'savingsReallocation',
                }.contains(financeType(r)) &&
                (r.values['goal'] == id || r.values['fromGoal'] == id),
          )
          .toList()
          .reversed
          .toList();
      final past = OverviewCard(
        key: const ValueKey('goal-history'),
        title: 'History',
        caption: 'Newest first',
        child: history.isEmpty
            ? const EmptyState(
                icon: Icons.history,
                title: 'No changes yet',
                message: 'Money set aside or moved shows here.',
              )
            : ListGroup(
                children: [
                  for (final r in history)
                    AdaptiveRow(
                      title: moneyLabel(r),
                      subtitle: civilDay(r.date),
                      trailing: MoneyAmount(amount(r.amount)),
                      onTap: () => actions.openRecord(r.id),
                    ),
                ],
              ),
      );
      final total = g.reserved != BigInt.zero;
      return SectionPage(
        title: record.title,
        caption: g.targetDate == null
            ? 'Savings goal'
            : 'Target ${civilDay(g.targetDate!)}',
        status: goalPill(g),
        actions: [
          if (active)
            CompactForm(
              child: AppButton(
                'Set money aside',
                key: const ValueKey('goal-aside'),
                icon: Icons.add,
                onPressed: aside,
              ),
            ),
          CardMenu(
            key: const ValueKey('goal-more'),
            tooltip: 'More actions',
            items: [
              if (active && total)
                MenuItemButton(
                  key: const ValueKey('goal-move'),
                  leadingIcon: const Icon(Icons.swap_horiz),
                  onPressed: () => actions.form(
                    'savingsReallocation',
                    formTitles['savingsReallocation']!,
                    initial: {'fromGoal': record.id},
                  ),
                  child: const Text('Move to another goal'),
                ),
              MenuItemButton(
                key: const ValueKey('goal-edit'),
                leadingIcon: const Icon(Icons.edit_outlined),
                onPressed: () => actions.form(
                  'financeCorrection',
                  'Edit goal',
                  replacing: record,
                ),
                child: const Text('Edit goal'),
              ),
              if (active)
                MenuItemButton(
                  key: const ValueKey('goal-complete'),
                  leadingIcon: const Icon(Icons.check_circle_outline),
                  onPressed: () => status('Mark goal complete', 'completed'),
                  child: const Text('Mark complete'),
                )
              else
                MenuItemButton(
                  key: const ValueKey('goal-reopen'),
                  leadingIcon: const Icon(Icons.replay),
                  onPressed: () => status('Reopen goal', 'active'),
                  child: const Text('Reopen goal'),
                ),
              if (g.status != 'archived')
                MenuItemButton(
                  key: const ValueKey('goal-archive'),
                  leadingIcon: const Icon(Icons.archive_outlined),
                  onPressed: () => status('Archive goal', 'archived'),
                  child: const Text('Archive goal'),
                ),
              const Divider(height: 1),
              MenuItemButton(
                key: const ValueKey('goal-view-record'),
                leadingIcon: const Icon(Icons.description_outlined),
                onPressed: () => actions.openRecord(record.id),
                child: const Text('View record'),
              ),
            ],
          ),
        ],
        child: DashboardGrid(
          key: ValueKey(('goal-grid', id)),
          cards: android
              ? null
              : [
                  (progress, 8, 12),
                  (about, 4, 12),
                  (where, 6, 12),
                  (past, 6, 12),
                ],
          stacked: [progress, where, past, about],
        ),
      );
    },
  );
}

/// One recurring item: its dates, and what happened on each. Reaching a date
/// never logs anything.
class RecurringDetailView extends StatelessWidget {
  const RecurringDetailView({
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
          .where((r) => r.actionId == id && financeType(r) == 'recurrence')
          .firstOrNull;
      if (record == null) return _missing('Recurring item');
      final android = !isDesktop(context);
      final text = Theme.of(context).textTheme;
      final dates = recurringDatesFor(s, record, today);
      final row = recurringRows(
        s,
        today,
      ).firstWhere((r) => r.rule.actionId == id);
      final type = recurringKindLabel(record.values['recurringKind']);
      final active = row.active;
      final open = dates
          .where(
            (d) =>
                const {'planned', 'linked'}.contains(d.state) &&
                d.due.compareTo(today) >= 0,
          )
          .take(3)
          .toList();
      void addDates() => actions.form(
        'recurrenceGenerate',
        formTitles['recurrenceGenerate']!,
        initial: {'rule': record.id},
      );
      final saved = dates
          .where(
            (d) => d.persisted && const {'planned', 'linked'}.contains(d.state),
          )
          .firstOrNull;
      void link() => actions.form(
        'recurrenceLink',
        formTitles['recurrenceLink']!,
        initial: {'rule': saved!.rule.id, 'logicalDate': saved.logicalDate},
      );
      final next = OverviewCard(
        key: const ValueKey('recurring-next'),
        title: 'Next dates',
        caption: 'What you expect, not what’s logged',
        accent: true,
        centered: true,
        child: open.isEmpty
            ? Text('No dates ahead.', style: text.bodyMedium)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final d in open)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.xs),
                      child: LabelAmount(
                        label: Text(
                          [
                            civilLabel(d.due),
                            if (!d.persisted) 'Not added yet',
                          ].join(' · '),
                          style: text.bodyMedium,
                        ),
                        amount: MoneyAmount(amount(d.remaining)),
                      ),
                    ),
                ],
              ),
      );
      final facts = <(String, String?)>[
        ('Type', type),
        ('How often', recurringLabel(record)),
        ('Starts', civilDay(record.values['start']!)),
        if ((record.values['end'] ?? '').isNotEmpty)
          ('Ends', civilDay(record.values['end']!)),
        if ((record.values['count'] ?? '').isNotEmpty)
          ('How many times', record.values['count']),
        ('Time zone', record.values['timezone']),
        if ((record.values['account'] ?? '').isNotEmpty)
          (
            'Usual account',
            s.accounts
                .where((a) => a.id == record.values['account'])
                .firstOrNull
                ?.name,
          ),
      ];
      final about = OverviewCard(
        key: const ValueKey('recurring-about'),
        title: 'About this item',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (label, value) in facts)
              if (value != null) FactRow(label, value),
            const ListEnd(key: ValueKey('recurring-about-end')),
          ],
        ),
      );
      AppTableRow dateRow(RecurringOccurrence d) {
        final state = d.persisted ? dateStateLabel(d.state) : 'Not added yet';
        final open =
            d.persisted && const {'planned', 'linked'}.contains(d.state);
        final links = effectiveRecurringLinks(s, d.id);
        return AppTableRow(
          id: 'date-${d.id}',
          spoken: [
            civilLabel(d.due),
            state,
            'Expected ${amount(d.expected)}',
            'Linked ${amount(d.linked)}',
          ].join(', '),
          cells: [
            Text(civilDay(d.due), style: text.bodyMedium),
            Text(state, style: text.bodySmall),
          ],
          money: [amount(d.expected), amount(d.linked), amount(d.remaining)],
          action: open || links.isNotEmpty
              ? CardMenu(
                  key: ValueKey('date-menu-${d.id}'),
                  tooltip: 'Actions for this date',
                  items: [
                    if (open) ...[
                      MenuItemButton(
                        key: ValueKey('date-link-${d.id}'),
                        onPressed: () => actions.form(
                          'recurrenceLink',
                          formTitles['recurrenceLink']!,
                          initial: {
                            'rule': d.rule.id,
                            'logicalDate': d.logicalDate,
                          },
                        ),
                        child: const Text('Link a record'),
                      ),
                      MenuItemButton(
                        key: ValueKey('date-change-${d.id}'),
                        onPressed: () => actions.form(
                          'occurrenceOverride',
                          formTitles['occurrenceOverride']!,
                          initial: {
                            'rule': d.rule.id,
                            'logicalDate': d.logicalDate,
                          },
                        ),
                        child: const Text('Change or skip'),
                      ),
                    ],
                    for (final l in links)
                      MenuItemButton(
                        key: ValueKey('date-unlink-${l.id}'),
                        onPressed: () => actions.form(
                          'recurrenceUnlink',
                          formTitles['recurrenceUnlink']!,
                          initial: {'link': l.id},
                        ),
                        child: Text('Remove link: ${l.title}'),
                      ),
                  ],
                )
              : null,
          narrow: AdaptiveRow(
            title: civilDay(d.due),
            subtitle: state,
            trailing: MoneyAmount(amount(d.remaining), caption: 'Left'),
          ),
        );
      }

      final table = OverviewCard(
        key: const ValueKey('recurring-dates'),
        title: 'Dates',
        caption: 'Link a record to mark a date as done',
        child: dates.isEmpty
            ? const EmptyState(
                icon: Icons.event_busy,
                title: 'No dates yet',
                message: 'Add dates to see them in Upcoming.',
              )
            : AppTable(
                key: const ValueKey('recurring-dates-table'),
                dense: true,
                columns: const [
                  (label: 'Date', flex: 0, width: dateColumn),
                  (label: 'State', flex: 2, width: null),
                ],
                moneyColumns: const ['Expected', 'Linked', 'Left'],
                actionLabel: 'Actions',
                rows: [for (final d in dates) dateRow(d)],
              ),
      );
      return SectionPage(
        title: record.title,
        caption: '$type · ${recurringLabel(record)}',
        status: active
            ? null
            : const StatusPill('Archived', icon: Icons.archive_outlined),
        actions: [
          if (active && row.added && saved != null)
            CompactForm(
              child: AppButton(
                'Link a record',
                key: const ValueKey('recurring-link'),
                icon: Icons.link,
                onPressed: link,
              ),
            )
          else if (active)
            CompactForm(
              child: AppButton(
                'Add to Upcoming',
                key: const ValueKey('recurring-add-dates'),
                icon: Icons.event_outlined,
                onPressed: addDates,
              ),
            ),
          CardMenu(
            key: const ValueKey('recurring-more'),
            tooltip: 'More actions',
            items: [
              if (active && row.added && saved != null)
                MenuItemButton(
                  key: const ValueKey('recurring-add-more'),
                  leadingIcon: const Icon(Icons.event_outlined),
                  onPressed: addDates,
                  child: const Text('Add to Upcoming'),
                ),
              MenuItemButton(
                key: const ValueKey('recurring-edit'),
                leadingIcon: const Icon(Icons.edit_outlined),
                onPressed: () => actions.form(
                  'financeCorrection',
                  'Edit recurring item',
                  replacing: record,
                ),
                child: const Text('Edit item'),
              ),
              if (active)
                MenuItemButton(
                  key: const ValueKey('recurring-archive'),
                  leadingIcon: const Icon(Icons.archive_outlined),
                  onPressed: () => actions.form(
                    'financeCorrection',
                    'Archive recurring item',
                    replacing: record,
                    overrides: const {'status': 'archived'},
                  ),
                  child: const Text('Archive item'),
                ),
              const Divider(height: 1),
              MenuItemButton(
                key: const ValueKey('recurring-view-record'),
                leadingIcon: const Icon(Icons.description_outlined),
                onPressed: () => actions.openRecord(record.id),
                child: const Text('View record'),
              ),
            ],
          ),
        ],
        child: DashboardGrid(
          key: ValueKey(('recurring-grid', id)),
          cards: android
              ? null
              : [(next, 8, 12), (about, 4, 12), (table, 12, 12)],
          stacked: [next, table, about],
        ),
      );
    },
  );
}
