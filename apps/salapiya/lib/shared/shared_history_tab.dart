import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../finance/debt_cards.dart' show civilDay, civilMonth;
import 'shared_cards.dart';
import 'shared_data.dart';
import 'shared_domain.dart';
import 'shared_hub.dart';
import 'shared_pages.dart';
import 'shared_people_data.dart';

/// "What happened in this group, and when?" Who did what, newest first, on
/// the day it happened. It's the group's own record, so it's read-only.
class SharedHistoryTab extends StatefulWidget {
  const SharedHistoryTab({
    super.key,
    required this.source,
    required this.group,
    required this.onRow,
    required this.onPage,
    this.pageSize = 25,
  });
  final SharedSource source;
  final SharedGroup group;
  final ValueChanged<HistoryRow> onRow;

  /// Opens the shareable list.
  final VoidCallback onPage;
  final int pageSize;
  @override
  State<SharedHistoryTab> createState() => _SharedHistoryTabState();
}

class _SharedHistoryTabState extends State<SharedHistoryTab> {
  HistoryFilter filter = HistoryFilter.all;
  late int shown = widget.pageSize;

  /// The authorized copy of the group, as it has always been. It isn't a
  /// backup, and it holds amounts, so it's off while they're hidden.
  Future<void> copy() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(
        text: jsonEncode({
          'format': 'salapiya-group-history-1',
          'restorable': false,
          'document': widget.group.data,
        }),
      ),
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Copied. It isn’t a backup and can’t be restored.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final source = widget.source, g = widget.group;
    final me = g.participant(source.actor ?? '');
    final loaded = source.complete;
    final all = loaded
        ? historyRows(g, me, source.today)
        : const <HistoryRow>[];
    final rows = all.where(filter.matches).toList();
    return OverviewCard(
      key: const ValueKey('history-card'),
      title: 'What happened',
      caption: 'Newest first, on the day it happened',
      corner: CardMenu(
        key: const ValueKey('history-menu'),
        tooltip: 'More',
        items: [
          MenuItemButton(
            key: const ValueKey('history-page'),
            leadingIcon: const Icon(Icons.open_in_new),
            onPressed: all.isEmpty ? null : widget.onPage,
            child: const Text('Open as a page'),
          ),
          MenuItemButton(
            key: const ValueKey('history-copy'),
            leadingIcon: const Icon(Icons.copy_outlined),
            onPressed: source.hidden ? null : copy,
            child: Text(
              source.hidden
                  ? 'Copy group history (amounts are hidden)'
                  : 'Copy group history',
            ),
          ),
        ],
      ),
      child: !loaded
          ? const NotAvailable('This shows once your records are complete.')
          : all.isEmpty
          ? EmptyState(
              icon: Icons.history,
              title: g.complete ? 'Nothing here yet' : 'No history here',
              message: g.complete
                  ? 'What happens in this group shows here.'
                  : 'You’ve left this group. Your earlier bills and payments are on Bills and Payments.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.xs,
                  children: [
                    for (final f in HistoryFilter.values)
                      ChoiceChip(
                        key: ValueKey('history-filter-${f.name}'),
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
                  historyTable(
                    context,
                    rows.take(shown),
                    source.amount,
                    widget.onRow,
                  ),
                if (rows.length > shown)
                  ShowMore(
                    left: rows.length - shown,
                    onPressed: () => setState(() => shown += widget.pageSize),
                  )
                else
                  const ListEnd(key: ValueKey('history-end')),
              ],
            ),
    );
  }
}

/// History as a table, by month. The tab and the shareable page share it.
Widget historyTable(
  BuildContext context,
  Iterable<HistoryRow> rows,
  String Function(BigInt) amount,
  ValueChanged<HistoryRow>? onRow,
) {
  final c = CraftTheme.of(context);
  final text = Theme.of(context).textTheme;
  final table = <AppTableRow>[];
  String? month;
  for (final r in rows) {
    final date = r.date;
    final m = date == null ? '' : monthOf(date);
    if (m != month) {
      month = m;
      table.add(
        AppTableRow.header(
          'month-$m',
          Text(
            date == null ? 'Date not recorded' : monthHeading(date),
            style: text.labelMedium?.copyWith(color: c.text),
          ),
        ),
      );
    }
    final opens = r.bill != null || r.payment != null;
    final figure = r.amount == null ? '' : amount(r.amount!);
    final reason = r.reason ?? '';
    void tap() => onRow?.call(r);
    table.add(
      AppTableRow(
        id: r.id,
        money: [figure],
        spoken: [
          r.title,
          if (date != null) civilDay(date),
          if (reason.isNotEmpty) reason,
          if (figure.isNotEmpty) figure,
        ].join(', '),
        onTap: opens && onRow != null ? tap : null,
        cells: [
          Text(
            date == null
                ? ''
                : '${civilMonth(date)} ${DateTime.parse(date).day}',
            style: text.bodySmall?.copyWith(color: c.secondary),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(r.title, style: text.titleSmall),
              if (reason.isNotEmpty)
                Text(
                  reason,
                  style: text.bodySmall?.copyWith(color: c.secondary),
                ),
            ],
          ),
        ],
        narrow: AdaptiveRow(
          key: ValueKey('history-${r.id}'),
          title: r.title,
          subtitle: detailLine([
            if (date != null) civilDay(date),
            if (reason.isNotEmpty) reason,
          ]),
          trailing: figure.isEmpty ? null : MoneyAmount(figure),
          onTap: opens && onRow != null ? tap : null,
        ),
      ),
    );
  }
  return AppTable(
    key: const ValueKey('history-table'),
    columns: const [
      (label: 'Date', flex: 0, width: dateColumn),
      (label: 'What happened', flex: 1, width: null),
    ],
    moneyColumns: const ['Amount'],
    rows: table,
  );
}

/// A period of the group's history, with no row limit.
class SharedHistoryPage extends StatefulWidget {
  const SharedHistoryPage({super.key, required this.hub, required this.group});
  final SharedHub hub;
  final String group;
  @override
  State<SharedHistoryPage> createState() => _SharedHistoryPageState();
}

class _SharedHistoryPageState extends State<SharedHistoryPage> {
  var period = SharedPeriod.thisMonth;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.hub, widget.hub.session]),
    builder: (context, _) {
      final source = widget.hub.source();
      final g = source.groups.where((x) => x.id == widget.group).firstOrNull;
      if (g == null) return sharedGonePage('History', 'History');
      final rows = [
        for (final r in historyRows(
          g,
          g.participant(source.actor ?? ''),
          source.today,
        ))
          if (r.date != null && period.holds(r.date!, source.today)) r,
      ];
      int count(HistoryKind kind) => rows.where((r) => r.kind == kind).length;
      return ShareablePage(
        title: 'History',
        group: g.name,
        period: period,
        onPeriod: (p) => setState(() => period = p),
        as: source.today,
        empty: rows.isEmpty,
        stats: [
          (label: 'Bills', value: '${count(HistoryKind.bill)}', detail: null),
          (
            label: 'Payments',
            value: '${count(HistoryKind.payment)}',
            detail: null,
          ),
          (label: 'Changes', value: '${rows.length}', detail: null),
        ],
        child: historyTable(context, rows, source.amount, null),
      );
    },
  );
}
