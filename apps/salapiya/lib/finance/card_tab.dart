import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_cards.dart' show ActivityCard, civilLabel;
import '../app/overview_data.dart';
import '../design_system/kit/kit.dart';
import 'card_cards.dart';
import 'card_data.dart';
import 'debt_cards.dart' show dueWhen;
import 'finance_screen.dart' show formTitles;
import 'money_cards.dart';
import 'money_data.dart';

/// "What do I owe on my cards, what's due, and how much credit is left?"
/// Card debt and available credit are never shown as money you have.
class CardsTab extends StatelessWidget {
  const CardsTab({super.key, required this.source, required this.onActivity});

  /// How many records Recent card activity shows.
  static const recentRows = 10;
  final MoneySource source;

  /// Opens Activity, narrowed to cards.
  final VoidCallback onActivity;

  void add() => source.actions.form('creditCard', formTitles['creditCard']!);

  @override
  Widget build(BuildContext context) {
    final android = !isDesktop(context);
    final s = source.snapshot, today = source.today;
    final complete = source.complete, hidden = source.hidden;
    final amount = source.amount, actions = source.actions;
    final summary = CardsSummary(
      complete ? cardRows(s, today) : const <CardRow>[],
    );
    if (complete && summary.cards.isEmpty) {
      return SurfaceCard(
        key: const ValueKey('cards-empty'),
        child: EmptyState(
          icon: Icons.credit_card_outlined,
          title: 'No cards yet',
          message: 'Add a card to track what you owe, statements and payments.',
          action: AppButton(
            'Add a card',
            key: const ValueKey('cards-add'),
            icon: Icons.add,
            onPressed: add,
          ),
        ),
      );
    }
    String? known(BigInt v) => complete ? amount(v) : null;
    final trend = complete && !hidden;
    final dues = complete ? cardDues(s, today) : const <CardDue>[];
    final overdue = dues.where((d) => d.item.days < 0).length;
    final next = dues.firstOrNull;
    final months = cardDebtByMonth(s, today);
    final before = lastMonthEnd(today);
    Widget words(String text) =>
        MoneyAmount(text, size: MoneySize.tile, textAlign: TextAlign.start);
    const labels = [
      'Card debt',
      'Due next',
      'Still due on statements',
      'Available credit',
    ];
    final limited = summary.limited.length;
    final tiles = <Widget>[
      KpiTile(
        key: const ValueKey('cards-debt'),
        labels: labels,
        accent: true,
        compactSpark: true,
        icon: Icons.credit_card_outlined,
        label: 'Card debt',
        value: MoneyAmount(
          known(summary.owed),
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        change: trend
            ? ChangeLine(
                basisPoints: changeBasisPoints(
                  summary.owed,
                  months[months.length - 2].$2,
                ),
                versus: 'since ${civilLabel(before)}',
                meaning: ChangeMeaning.riseIsBad,
              )
            : null,
        spark: trend ? [for (final m in months) m.$2] : const [],
        caption: 'Not counted in Available money',
      ),
      KpiTile(
        key: const ValueKey('cards-due-next'),
        labels: labels,
        icon: Icons.event_outlined,
        label: 'Due next',
        value: !complete
            ? MoneyAmount(
                null,
                size: MoneySize.tile,
                textAlign: TextAlign.start,
              )
            : next == null
            ? words('Nothing due')
            : MoneyAmount(
                amount(next.item.amount),
                size: MoneySize.tile,
                textAlign: TextAlign.start,
              ),
        caption: next == null
            ? null
            : overdue > 0
            ? '$overdue overdue · oldest ${next.name}'
            : '${next.name} · ${civilLabel(next.item.date)} · ${dueWhen(next.item.days)}',
      ),
      KpiTile(
        key: const ValueKey('cards-still-due'),
        labels: labels,
        icon: Icons.receipt_long_outlined,
        label: 'Still due on statements',
        value: MoneyAmount(
          known(summary.stillDue),
          size: MoneySize.tile,
          textAlign: TextAlign.start,
        ),
        caption: !complete
            ? null
            : summary.statementsDue == 0
            ? 'No statements to pay'
            : 'Newest statement on each card',
      ),
      KpiTile(
        key: const ValueKey('cards-available'),
        labels: labels,
        icon: Icons.speed_outlined,
        label: 'Available credit',
        value: !complete
            ? MoneyAmount(
                null,
                size: MoneySize.tile,
                textAlign: TextAlign.start,
              )
            : limited == 0
            ? words('No limit recorded')
            : MoneyAmount(
                amount(summary.available),
                size: MoneySize.tile,
                textAlign: TextAlign.start,
              ),
        caption: !complete
            ? null
            : 'Not money you have · $limited of ${summary.cards.length} ${summary.cards.length == 1 ? 'card has' : 'cards have'} a limit',
      ),
    ];

    final cards = YourCardsCard(
      key: const ValueKey('cards-yours'),
      summary: summary,
      dues: dues,
      amount: amount,
      available: complete,
      hidden: hidden,
      onOpen: actions.openItem,
      onAdd: add,
      corner: complete
          ? CardMenu(
              key: const ValueKey('cards-menu'),
              tooltip: 'More',
              items: [
                MenuItemButton(
                  key: const ValueKey('cards-history'),
                  leadingIcon: const Icon(Icons.history),
                  onPressed: () => openDemoPage<void>(
                    context,
                    RecordHistoryPage(
                      source: source,
                      title: 'Card history',
                      empty: 'Everything on your cards shows here.',
                      types: cardRecordTypes,
                    ),
                    'money/card-history',
                    title: 'Card history',
                  ),
                  child: const Text('History'),
                ),
              ],
            )
          : null,
    );
    final due = CardDuesCard(
      key: const ValueKey('cards-dues'),
      dues: dues,
      amount: amount,
      available: complete,
      onLog: (d) => logCardPayment(actions, s, d.card, left: d.item.amount),
      onOpen: (d) => actions.openItem(d.source),
      onAll: actions.openCardDues,
    );
    final debt = CardDebtCard(
      key: const ValueKey('cards-debt-chart'),
      months: months,
      amount: amount,
      available: complete,
      hidden: hidden,
    );
    final tasks = complete ? cardTasks(s, summary.cards) : const <CardTask>[];
    final attention = tasks.isEmpty
        ? null
        : CardTasksCard(
            key: const ValueKey('cards-attention'),
            tasks: tasks,
            onOpen: (t) => actions.openItem(t.id),
          );
    final activity = complete
        ? moneyActivity(s, source.categoryName, waiting: source.waiting)
              .where(
                (r) =>
                    r.type == ActivityType.cards &&
                    r.date.compareTo(today) <= 0,
              )
              .toList()
        : const <MoneyRow>[];
    final recent = ActivityCard(
      key: const ValueKey('cards-recent'),
      title: 'Recent card activity',
      caption: 'Newest first',
      action: CardLink(
        'See all',
        key: const ValueKey('cards-see-all'),
        onPressed: onActivity,
      ),
      rows: [
        for (final r in activity.take(recentRows))
          (
            icon: moneyIcon(r),
            title: r.title,
            date: r.date,
            category: r.categoryLabel.isEmpty ? r.label : r.categoryLabel,
            amount: complete ? r.shown(amount, hidden: hidden) : null,
            onTap: () => actions.openRecord(r.id),
          ),
      ],
      footer: ListEnd(
        key: const ValueKey('cards-recent-end'),
        label: activity.length > recentRows
            ? '${activity.length - recentRows} more in Activity'
            : 'That’s everything',
        onPressed: activity.length > recentRows ? onActivity : null,
      ),
      empty: !complete
          ? const NotAvailable('Activity shows once your records are complete.')
          : const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No card activity yet',
              message: 'Purchases and payments on your cards show here.',
            ),
    );
    return DashboardGrid(
      key: const ValueKey('cards-grid'),
      cards: android
          ? null
          : [
              for (final t in tiles) (t, 3, 6),
              (cards, 8, 12),
              (due, 4, 12),
              (debt, attention == null ? 12 : 7, 12),
              ?(attention == null ? null : (attention, 5, 12)),
              (recent, 12, 12),
            ],
      // On phones Card debt takes the full width, its sparkline beside the
      // value; the next two tiles pair up.
      stacked: [
        KeyedSubtree(child: tiles.first),
        tiles[1],
        tiles[2],
        KeyedSubtree(child: tiles[3]),
        due,
        ?attention,
        cards,
        debt,
        recent,
      ],
    );
  }
}
