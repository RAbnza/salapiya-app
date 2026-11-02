import 'package:flutter/material.dart';

import '../theme.dart';
import 'focus_ring.dart';

/// One day of a [MonthGrid]: its `YYYY-MM-DD` date, how many things are on it
/// and whether one of them is late.
typedef GridDay = ({String date, int count, bool late});

/// A period's days: a week strip, or a month's grid. A dot marks a day with
/// something on it and an icon marks one with something late, so the two
/// differ by shape as well as color. Moved from the Overview's dues card.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.days,
    required this.today,
    required this.selected,
    required this.onSelected,
    required this.spoken,
    this.strip = false,
    this.keyPrefix = 'due-day-',
  });
  final List<GridDay> days;
  final String today;
  final String? selected;
  final ValueChanged<String> onSelected;

  /// What a screen reader hears for a day.
  final String Function(GridDay day) spoken;

  /// One row with a letter over each day, for a week.
  final bool strip;
  final String keyPrefix;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final height = isDesktop(context)
        ? Space.compactTwoLineRow
        : Space.target + Space.sm;
    Widget cell(GridDay day) {
      final date = day.date;
      final isToday = date == today, isSelected = date == selected;
      final late = day.late, count = day.count;
      return Semantics(
        container: true,
        onTap: () => onSelected(date),
        button: true,
        selected: isSelected,
        label: spoken(day),
        excludeSemantics: true,
        child: Pressable(
          key: ValueKey('$keyPrefix$date'),
          radius: Radii.controlOf(context),
          color: isSelected
              ? c.selection
              : late
              ? c.overdue.$2
              : null,
          border: isToday ? Border.all(color: c.primary) : null,
          onTap: () => onSelected(date),
          // A minimum, not a fixed height, so the cell grows with the text.
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (strip)
                  Text(
                    _letters[DateTime.parse(date).weekday - 1],
                    style: text.labelSmall?.copyWith(color: c.secondary),
                  ),
                Text(
                  '${DateTime.parse(date).day}',
                  style: text.labelLarge?.copyWith(
                    color: isSelected ? c.onSelection : c.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(
                  height: Space.md,
                  child: late
                      ? Icon(
                          Icons.error_outline,
                          size: Space.md,
                          color: c.overdue.$1,
                        )
                      : count > 0
                      ? Center(
                          child: Container(
                            width: Space.xs + Space.xxs,
                            height: Space.xs + Space.xxs,
                            decoration: BoxDecoration(
                              color: c.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget line(List<Widget> cells) => Row(
      children: [
        for (final (i, w) in cells.indexed) ...[
          if (i > 0) const SizedBox(width: Space.xxs),
          Expanded(child: w),
        ],
      ],
    );

    if (strip) return line([for (final d in days) cell(d)]);
    final lead = DateTime.parse(days.first.date).weekday - 1;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (final d in days) cell(d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }
    return Column(
      children: [
        line([
          for (final l in _letters)
            ExcludeSemantics(
              child: Center(
                child: Text(
                  l,
                  style: text.labelSmall?.copyWith(color: c.secondary),
                ),
              ),
            ),
        ]),
        const SizedBox(height: Space.xs),
        for (var r = 0; r < cells.length; r += 7) ...[
          if (r > 0) const SizedBox(height: Space.xxs),
          line(cells.sublist(r, r + 7)),
        ],
      ],
    );
  }
}
