import 'package:flutter/material.dart';

import '../app/overview_cards.dart' show civilLabel;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'agenda_page.dart';
import 'device_reminders.dart' show reminderModules;
import 'life_cards.dart';
import 'life_data.dart';
import 'life_hub.dart';
import 'life_pages_detail.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "November 2026".
String lifeMonthName(String date) {
  final d = DateTime.parse(date);
  return '${_monthNames[d.month - 1]} ${d.year}';
}

/// The Calendar: what's coming up, what's today, and is anything late?
class LifeCalendarTab extends StatelessWidget {
  const LifeCalendarTab({
    super.key,
    required this.source,
    required this.hub,
    required this.listenable,
    required this.live,
  });
  final LifeSource source;
  final LifeHub hub;

  /// Rebuilds the pages opened from here.
  final Listenable listenable;
  final LifeSource Function(BuildContext context) live;

  @override
  Widget build(BuildContext context) {
    final android = !isDesktop(context);
    final today = source.today, month = hub.month(today);
    final selected = hub.selected(today);
    final rows = source.rowsThrough(lifeWindowEnd(today, month));
    final all = LifeCalendar(rows, today, month, selected, now: source.now);
    final calendar = hub.show == 'All'
        ? all
        : LifeCalendar(
            [
              for (final r in rows)
                if (r.module == hub.show) r,
            ],
            today,
            month,
            selected,
            now: source.now,
          );
    final actions = source.actions;

    void openList(LifeListScope scope) => actions.openList(
      LifeListPage(listenable: listenable, source: live, scope: scope),
      scope.title(today),
    );

    final grid = android ? null : wideCards(context, calendar, all, openList);
    return DashboardGrid(
      key: ValueKey(('life-calendar', hub.agenda)),
      cards: grid,
      stacked: stackedCards(context, calendar, all, openList),
    );
  }

  List<Widget> tiles(
    BuildContext context,
    LifeCalendar all,
    ValueChanged<LifeListScope> openList,
  ) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final today = source.today;
    final done = source.complete;
    Widget words(String value) =>
        MoneyAmount(value, size: MoneySize.tile, textAlign: TextAlign.start);
    final unknown = const MoneyAmount(
      null,
      size: MoneySize.tile,
      textAlign: TextAlign.start,
    );
    const labels = ['Today', 'This week', 'Overdue', 'Next up'];
    final on = all.onToday, week = all.thisWeek, late = all.late;
    final next = all.next;
    final oldest = late.isEmpty ? 0 : -late.first.days;
    return [
      KpiTile(
        key: const ValueKey('life-today'),
        labels: labels,
        accent: true,
        icon: Icons.today_outlined,
        label: 'Today',
        value: done ? words('${on.length}') : unknown,
        caption: !done
            ? null
            : on.isEmpty
            ? 'Nothing today'
            : todayLine(on),
        onTap: () => hub.select(today),
      ),
      KpiTile(
        key: const ValueKey('life-week'),
        labels: labels,
        icon: Icons.date_range_outlined,
        label: 'This week',
        value: done ? words('${week.length}') : unknown,
        caption: !done
            ? null
            : week.isEmpty
            ? 'Nothing left this week'
            : 'Today to Sunday',
        onTap: () => openList(const LifeListScope.week()),
      ),
      KpiTile(
        key: const ValueKey('life-overdue'),
        labels: labels,
        icon: Icons.error_outline,
        label: 'Overdue',
        value: done ? words('${late.length}') : unknown,
        caption: !done
            ? null
            : late.isEmpty
            ? 'Nothing overdue'
            : 'Oldest $oldest ${oldest == 1 ? 'day' : 'days'}',
        onTap: late.isEmpty
            ? null
            : () => openList(const LifeListScope.overdue()),
      ),
      KpiTile(
        key: const ValueKey('life-next'),
        labels: labels,
        icon: Icons.upcoming_outlined,
        label: 'Next up',
        value: Text(
          next?.title ?? 'Nothing planned',
          style: text.titleSmall?.copyWith(
            color: next == null ? c.secondary : c.text,
          ),
        ),
        caption: next == null
            ? null
            : detailLine(lifeWhen(context, next).take(2)),
        onTap: next == null ? null : () => source.actions.openRow(next),
      ),
    ];
  }

  /// "1 event · 2 due".
  String todayLine(List<LifeRow> rows) {
    final counts = rowCounts(rows);
    final due = counts.deadlines + counts.dues;
    return [
      if (counts.events > 0)
        '${counts.events} ${counts.events == 1 ? 'event' : 'events'}',
      if (due > 0) '$due due',
    ].join(' · ');
  }

  Widget monthControls(BuildContext context) {
    final today = source.today;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIconButton(
          key: const ValueKey('life-month-back'),
          icon: Icons.chevron_left,
          tooltip: 'Previous month',
          onPressed: () => hub.moveMonth(today, -1),
        ),
        AppIconButton(
          key: const ValueKey('life-month-next'),
          icon: Icons.chevron_right,
          tooltip: 'Next month',
          onPressed: () => hub.moveMonth(today, 1),
        ),
        const SizedBox(width: Space.xs),
        CardLink(
          'Today',
          key: const ValueKey('life-go-today'),
          chevron: false,
          onPressed: () => hub.select(today),
        ),
      ],
    );
  }

  Widget corner(ValueChanged<LifeListScope> openList) {
    final actions = source.actions;
    final modules = [
      for (final m in reminderModules)
        if (source.visible(m)) m,
    ];
    return CardMenu(
      key: const ValueKey('life-calendar-menu'),
      icon: Icons.tune,
      tooltip: 'Calendar options',
      items: [
        for (final (agenda, label, icon) in const [
          (false, 'Calendar', Icons.calendar_month_outlined),
          (true, 'Agenda', Icons.view_agenda_outlined),
        ])
          MenuItemButton(
            key: ValueKey('life-view-$agenda'),
            leadingIcon: Icon(icon),
            trailingIcon: agenda == hub.agenda ? const Icon(Icons.check) : null,
            onPressed: () => hub.setAgenda(agenda),
            child: Text(label),
          ),
        const Divider(height: 1),
        SubmenuButton(
          key: const ValueKey('life-show'),
          leadingIcon: const Icon(Icons.filter_list),
          menuChildren: [
            for (final m in ['All', ...modules])
              MenuItemButton(
                key: ValueKey('life-show-$m'),
                trailingIcon: m == hub.show ? const Icon(Icons.check) : null,
                onPressed: () => hub.setShow(m),
                child: Text(m == 'All' ? 'Everything' : lifeModuleName(m)),
              ),
          ],
          child: const Text('Show'),
        ),
        const Divider(height: 1),
        MenuItemButton(
          key: const ValueKey('life-open-list'),
          leadingIcon: const Icon(Icons.open_in_full),
          onPressed: () => openList(const LifeListScope.month()),
          child: const Text('Open as a page'),
        ),
        MenuItemButton(
          key: const ValueKey('life-open-retired'),
          leadingIcon: const Icon(Icons.history),
          onPressed: () => actions.openList(
            LifeRetiredPage(listenable: listenable, source: live),
            'Past and cancelled',
          ),
          child: const Text('Past and cancelled'),
        ),
        const Divider(height: 1),
        MenuItemButton(
          key: const ValueKey('life-open-reminders'),
          leadingIcon: const Icon(Icons.notifications_none),
          onPressed: actions.reminders,
          child: const Text('Reminders'),
        ),
        if (actions.preferences != null)
          MenuItemButton(
            key: const ValueKey('life-open-preferences'),
            leadingIcon: const Icon(Icons.settings_outlined),
            onPressed: actions.preferences,
            child: const Text('Preferences & help'),
          ),
      ],
    );
  }

  String? get showing =>
      hub.show == 'All' ? null : '${lifeModuleName(hub.show)} only';

  Widget monthCard(
    BuildContext context,
    LifeCalendar calendar,
    ValueChanged<LifeListScope> openList,
  ) {
    final today = source.today, month = calendar.month;
    final counts = rowCounts(calendar.inMonth);
    return OverviewCard(
      key: const ValueKey('life-month'),
      title: lifeMonthName(month),
      caption: showing,
      trailing: monthControls(context),
      corner: corner(openList),
      stackBelow: Space.xxxl * 8,
      centered: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonthGrid(
            keyPrefix: 'life-day-',
            days: calendar.days,
            today: today,
            selected: calendar.selected,
            onSelected: hub.select,
            spoken: (day) => [
              civilLabel(day.date),
              if (day.date == today) 'today',
              day.count == 0
                  ? 'nothing on'
                  : day.late
                  ? '${day.count} on, something overdue'
                  : '${day.count} on',
            ].join(', '),
          ),
          const SizedBox(height: Space.md),
          StatStrip(
            stats: [
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
          ),
        ],
      ),
    );
  }

  Widget dayCard(
    BuildContext context,
    LifeCalendar calendar,
    ValueChanged<LifeListScope> openList,
  ) {
    final today = source.today, selected = calendar.selected;
    final rows = calendar.on(selected);
    return LifeRowsCard(
      key: const ValueKey('life-day'),
      title: selected == today
          ? 'Today · ${civilLabel(selected)}'
          : civilLabel(selected),
      caption: rows.isEmpty
          ? null
          : '${rows.length} ${rows.length == 1 ? 'thing' : 'things'} on this day',
      rows: rows,
      amount: source.amount,
      onOpen: source.actions.openRow,
      date: false,
      onMore: () => openList(LifeListScope.day(selected)),
      corner: rows.isEmpty
          ? null
          : CardMenu(
              key: const ValueKey('life-day-menu'),
              tooltip: 'Day options',
              items: [
                MenuItemButton(
                  key: const ValueKey('life-day-open'),
                  leadingIcon: const Icon(Icons.open_in_full),
                  onPressed: () => openList(LifeListScope.day(selected)),
                  child: const Text('Open as a page'),
                ),
              ],
            ),
      empty: EmptyState(
        icon: Icons.event_available_outlined,
        title: 'Nothing on this day',
        message: 'Events, tasks and dues you track show here.',
        action: AppButton.secondary(
          'Add event',
          onPressed: source.actions.addEvent,
        ),
      ),
    );
  }

  Widget overdueCard(
    LifeCalendar calendar,
    ValueChanged<LifeListScope> openList,
  ) => LifeRowsCard(
    key: const ValueKey('life-overdue-card'),
    title: 'Overdue',
    caption: 'Tasks, due dates and dues past their date',
    rows: calendar.late,
    amount: source.amount,
    onOpen: source.actions.openRow,
    onMore: () => openList(const LifeListScope.overdue()),
    empty: const SizedBox.shrink(),
  );

  Widget comingCard(
    LifeCalendar calendar,
    ValueChanged<LifeListScope> openList,
  ) => LifeRowsCard(
    key: const ValueKey('life-coming'),
    title: 'Coming up',
    caption: 'The next seven days',
    rows: calendar.comingUp,
    amount: source.amount,
    onOpen: source.actions.openRow,
    onMore: () => openList(const LifeListScope.month()),
    empty: const EmptyState(
      icon: Icons.event_available_outlined,
      title: 'Nothing in the next seven days',
      message: 'What’s coming up shows here.',
    ),
  );

  Widget agendaCard(
    BuildContext context,
    LifeCalendar calendar,
    ValueChanged<LifeListScope> openList,
  ) => LifeAgendaCard(
    key: const ValueKey('life-agenda'),
    source: source,
    hub: hub,
    calendar: calendar,
    trailing: monthControls(context),
    corner: corner(openList),
    caption: showing,
  );

  List<GridCard> wideCards(
    BuildContext context,
    LifeCalendar calendar,
    LifeCalendar all,
    ValueChanged<LifeListScope> openList,
  ) {
    final late = calendar.late.isNotEmpty;
    return [
      for (final t in tiles(context, all, openList)) (t, 3, 6),
      if (hub.agenda) ...[
        if (late) (overdueCard(calendar, openList), 12, 12),
        (agendaCard(context, calendar, openList), 12, 12),
      ] else ...[
        (monthCard(context, calendar, openList), 7, 12),
        // Stacked beside the month, so nothing empty sits under them.
        (
          SideStack(
            top: dayCard(context, calendar, openList),
            rest: late
                ? overdueCard(calendar, openList)
                : comingCard(calendar, openList),
          ),
          5,
          12,
        ),
        if (late) (comingCard(calendar, openList), 12, 12),
      ],
    ];
  }

  List<Widget> stackedCards(
    BuildContext context,
    LifeCalendar calendar,
    LifeCalendar all,
    ValueChanged<LifeListScope> openList,
  ) {
    final t = tiles(context, all, openList);
    return [
      KeyedSubtree(child: t.first),
      t[1],
      t[2],
      KeyedSubtree(child: t[3]),
      if (calendar.late.isNotEmpty) overdueCard(calendar, openList),
      if (hub.agenda)
        agendaCard(context, calendar, openList)
      else ...[
        monthCard(context, calendar, openList),
        dayCard(context, calendar, openList),
        comingCard(calendar, openList),
      ],
    ];
  }
}
