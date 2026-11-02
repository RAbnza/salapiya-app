import 'package:flutter/material.dart';

import '../app/overview_cards.dart' show civilLabel, overviewSpan;
import '../app/overview_data.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'calendar_tab.dart' show lifeMonthName;
import 'life_cards.dart';
import 'life_data.dart';
import 'life_hub.dart';

/// The Agenda view: every row of the month on show, by day, with search.
class LifeAgendaCard extends StatefulWidget {
  const LifeAgendaCard({
    super.key,
    required this.source,
    required this.hub,
    required this.calendar,
    required this.trailing,
    required this.corner,
    this.caption,
  });
  final LifeSource source;
  final LifeHub hub;
  final LifeCalendar calendar;
  final Widget trailing, corner;
  final String? caption;
  @override
  State<LifeAgendaCard> createState() => _LifeAgendaCardState();
}

class _LifeAgendaCardState extends State<LifeAgendaCard> {
  static const page = 25;
  int shown = page;
  late final search = TextEditingController(text: widget.hub.query);

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.hub.query.trim().toLowerCase();
    final rows = [
      for (final r in widget.calendar.inMonth)
        if (r.title.toLowerCase().contains(words)) r,
    ];
    return OverviewCard(
      title: lifeMonthName(widget.calendar.month),
      caption: widget.caption,
      trailing: widget.trailing,
      corner: widget.corner,
      stackBelow: Space.xxxl * 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('life-search'),
            controller: search,
            decoration: const InputDecoration(
              hintText: 'Search this month',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) {
              shown = page;
              widget.hub.setQuery(v);
            },
          ),
          const SizedBox(height: Space.md),
          if (rows.isEmpty)
            EmptyState(
              icon: Icons.event_available_outlined,
              title: words.isEmpty
                  ? 'Nothing this month'
                  : 'Nothing matches that',
              message: words.isEmpty
                  ? 'Events, tasks and dues you track show here.'
                  : 'Try other words, or another month.',
            )
          else ...[
            LifeTable(
              rows: rows.take(shown).toList(),
              amount: widget.source.amount,
              onOpen: widget.source.actions.openRow,
              today: widget.source.today,
            ),
            if (rows.any((r) => r.money)) const LifeMoneyNote(),
            if (rows.length > shown)
              ShowMore(
                left: rows.length - shown,
                onPressed: () => setState(() => shown += page),
              )
            else
              const ListEnd(),
          ],
        ],
      ),
    );
  }
}

/// A shareable list's period.
enum LifePeriod {
  week('This week'),
  month('This month'),
  next('Next month');

  const LifePeriod(this.label);
  final String label;
}

/// What a shareable list shows.
class LifeListScope {
  const LifeListScope.week() : period = LifePeriod.week, day = null, late = false;
  const LifeListScope.month()
    : period = LifePeriod.month,
      day = null,
      late = false;
  const LifeListScope.day(String this.day) : period = null, late = false;
  const LifeListScope.overdue() : period = null, day = null, late = true;
  final LifePeriod? period;
  final String? day;
  final bool late;

  String title(String today) => late
      ? 'Overdue'
      : day != null
      ? (day == today ? 'Today' : civilLabel(day!))
      : 'Agenda';
}

(String, String) periodSpan(LifePeriod period, String today) =>
    switch (period) {
      LifePeriod.week => duePeriodRange(today, DuePeriod.week),
      LifePeriod.month => (monthStart(today), monthEnd(today)),
      LifePeriod.next => () {
        final first = addCivilDays(monthEnd(today), 1);
        return (first, monthEnd(first));
      }(),
    };

/// One screenshot: the period, "as of", counts and every item, with no tabs
/// or actions. Counts only: no total adds up across kinds, because a card's
/// statement usually includes its installments.
class LifeListPage extends StatefulWidget {
  const LifeListPage({
    super.key,
    required this.listenable,
    required this.source,
    required this.scope,
  });
  final Listenable listenable;
  final LifeSource Function(BuildContext context) source;
  final LifeListScope scope;
  @override
  State<LifeListPage> createState() => _LifeListPageState();
}

class _LifeListPageState extends State<LifeListPage> {
  late LifePeriod? period = widget.scope.period;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.listenable,
    builder: (context, _) {
      final source = widget.source(context);
      final today = source.today, scope = widget.scope;
      final span = period == null ? null : periodSpan(period!, today);
      final rows = scope.late
          ? [
              for (final r in source.rowsThrough(today))
                if (r.late) r,
            ]
          : scope.day != null
          ? source.rows(scope.day!, scope.day!)
          : source.rows(span!.$1, span.$2);
      final counts = rowCounts(rows);
      return ShareableList<LifePeriod>(
        title: scope.title(today),
        caption: 'Life',
        heading: span != null
            ? '${period!.label} · ${overviewSpan(span.$1, span.$2)}'
            : scope.late
            ? 'Past their date'
            : civilLabel(scope.day!),
        asOf: 'As of ${civilLabel(today)}',
        periods: period == null
            ? const []
            : [for (final p in LifePeriod.values) (p, p.label)],
        period: period,
        onPeriod: (p) => setState(() => period = p),
        stats: [
          // An event that has gone by isn't overdue.
          if (!scope.late)
            (label: 'Events', value: '${counts.events}', detail: null),
          (
            label: 'Tasks and due dates',
            value: '${counts.deadlines}',
            detail: null,
          ),
          if (source.complete)
            (
              label: 'Bills, cards and debts',
              value: '${counts.dues}',
              detail: null,
            ),
        ],
        empty: rows.isEmpty,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LifeTable(
              rows: rows,
              amount: source.amount,
              onOpen: source.actions.openRow,
              today: today,
            ),
            if (rows.any((r) => r.money)) const LifeMoneyNote(),
          ],
        ),
      );
    },
  );
}

/// The live source for a list page.
LifeSource Function(BuildContext) lifeSourceOf(LifeHub hub) =>
    (context) => lifeSource(context, hub.session);
