import 'package:flutter/material.dart';

import '../app/overview_cards.dart'
    show OverviewRow, civilLabel, dueKind, duePill;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart' show DebtDueStatus;
import 'life_data.dart';

/// Life's rows and lists. Money rows remind the user of their records; none
/// of them asks for anything.

String _plural(int n, String one) => '$n ${n == 1 ? one : '${one}s'}';

/// "HH:MM" as this device writes it.
String lifeClock(BuildContext context, String time) {
  final p = time.split(':');
  return TimeField.format(
    context,
    TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])),
  );
}

String lifeKindLabel(LifeRow r) => r.money
    ? dueKind(r.dueKind!).$1
    : switch (r.module) {
        'Personal' => 'Event',
        'Tasks' => 'Task',
        'Books' => 'Book',
        _ => r.module,
      };

IconData lifeIcon(LifeRow r) => r.money
    ? dueKind(r.dueKind!).$2
    : switch (r.module) {
        'Personal' => Icons.event_outlined,
        'Tasks' => Icons.check_circle_outline,
        'Learning' => Icons.school_outlined,
        'Books' => Icons.auto_stories_outlined,
        _ => Icons.work_outline,
      };

/// When a row happens, in words. An all-day event reads "All day" and a due
/// date reads "Due": neither has a time.
List<String> lifeWhen(BuildContext context, LifeRow r, {bool date = true}) => [
  if (r.event) ...[
    if (date) civilLabel(r.date),
    if (r.allDay) 'All day' else lifeClock(context, r.time),
    if (r.recordedTime != null)
      [
        lifeClock(context, r.recordedTime!),
        'in ${zoneName(r.recordedZone!)}',
        if (r.recordedDate != r.date) civilLabel(r.recordedDate!),
      ].join(' '),
  ] else if (date)
    'Due ${civilLabel(r.date)}'
  else if (r.days != 0)
    'Due',
];

List<String> lifeDetails(BuildContext context, LifeRow r, {bool date = true}) =>
    [
      lifeKindLabel(r),
      ...lifeWhen(context, r, date: date),
      if (r.late) '${_plural(-r.days, 'day')} overdue',
    ];

/// The pill a row needs: money rows always have one; others only when
/// something's off or it's today's.
Widget? lifePill(LifeRow r) => r.money
    ? duePill(r.status)
    : r.late
    ? duePill(DebtDueStatus.overdue)
    : r.past
    ? const StatusPill('Past', icon: Icons.history)
    : !r.event && r.days == 0
    ? duePill(DebtDueStatus.dueToday)
    : null;

/// One row of a list.
Widget lifeRowTile(
  BuildContext context,
  LifeRow r,
  String Function(BigInt) amount,
  ValueChanged<LifeRow> onOpen, {
  bool date = true,
}) {
  final pill = lifePill(r);
  return AdaptiveRow(
    key: ValueKey('life-row-${r.id}'),
    leading: lifeIcon(r),
    title: r.title,
    subtitle: detailLine(lifeDetails(context, r, date: date)),
    trailing: r.money
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              MoneyAmount(amount(r.amount!)),
              const SizedBox(height: Space.captionGap),
              ?pill,
            ],
          )
        : pill,
    onTap: () => onOpen(r),
  );
}

/// One row of the Overview's Next up in Life.
OverviewRow nextUpRow(BuildContext context, LifeRow r, VoidCallback onTap) => (
  icon: lifeIcon(r),
  title: r.title,
  subtitle: detailLine(lifeDetails(context, r)),
  amount: null,
  onTap: onTap,
);

/// Says once, on a list with money rows, what they are.
class LifeMoneyNote extends StatelessWidget {
  const LifeMoneyNote({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.sm),
    child: Text(
      'Reminders of your records. Salapiya doesn’t pay anything.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: CraftTheme.of(context).secondary,
      ),
    ),
  );
}

/// A list of rows in a card. It starts at the top, and closes with
/// `ListEnd`: a link to the rest when it's cut short.
class LifeRowsCard extends StatelessWidget {
  const LifeRowsCard({
    super.key,
    required this.title,
    required this.rows,
    required this.amount,
    required this.onOpen,
    required this.empty,
    this.caption,
    this.corner,
    this.limit = 6,
    this.onMore,
    this.date = true,
  });
  final String title;
  final String? caption;
  final List<LifeRow> rows;
  final String Function(BigInt) amount;
  final ValueChanged<LifeRow> onOpen;
  final Widget empty;
  final Widget? corner;
  final int limit;

  /// Opens every row.
  final VoidCallback? onMore;

  /// Off in a card that's already about one day.
  final bool date;
  @override
  Widget build(BuildContext context) {
    final left = rows.length - limit;
    final shown = rows.take(limit).toList();
    return OverviewCard(
      title: title,
      caption: caption,
      corner: corner,
      child: rows.isEmpty
          ? empty
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListGroup(
                  leading: true,
                  children: [
                    for (final r in shown)
                      lifeRowTile(context, r, amount, onOpen, date: date),
                  ],
                ),
                if (shown.any((r) => r.money)) const LifeMoneyNote(),
                left > 0 && onMore != null
                    ? ListEnd(label: '$left more', onPressed: onMore)
                    : const ListEnd(),
              ],
            ),
    );
  }
}

/// Rows as a table with a header for each day, or a list when narrow.
class LifeTable extends StatelessWidget {
  const LifeTable({
    super.key,
    required this.rows,
    required this.amount,
    required this.onOpen,
    this.today,
  });
  final List<LifeRow> rows;
  final String Function(BigInt) amount;
  final ValueChanged<LifeRow> onOpen;

  /// Names the day that is today.
  final String? today;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final body = text.bodyMedium;
    final muted = text.bodySmall?.copyWith(color: c.secondary);
    AppTableRow row(LifeRow r) {
      // Its own column, so a due today says so even without a pill beside it.
      final when = r.event ? lifeWhen(context, r, date: false).join(' · ') : 'Due';
      final pill = lifePill(r);
      return AppTableRow(
        id: r.id,
        onTap: () => onOpen(r),
        spoken: [
          r.title,
          ...lifeDetails(context, r),
          if (r.money) amount(r.amount!),
        ].join(', '),
        narrow: lifeRowTile(context, r, amount, onOpen),
        money: [r.money ? amount(r.amount!) : ''],
        cells: [
          Text(when, style: muted),
          Text(r.title, style: body),
          Text(lifeKindLabel(r), style: muted),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: pill ?? const SizedBox.shrink(),
          ),
        ],
      );
    }

    return AppTable(
      columns: const [
        (label: 'When', flex: 2, width: null),
        (label: 'Item', flex: 4, width: null),
        (label: 'Type', flex: 2, width: null),
        (label: 'Status', flex: 2, width: null),
      ],
      moneyColumns: const ['Amount'],
      dense: true,
      rows: [
        for (final (date, day) in rowsByDay(rows)) ...[
          AppTableRow.header(
            'day-$date',
            Text(
              date == today ? 'Today · ${civilLabel(date)}' : civilLabel(date),
              style: text.labelLarge,
            ),
          ),
          for (final r in day) row(r),
        ],
      ],
    );
  }
}
