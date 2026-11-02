import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';

// The Windows title bar's clock and its month calendar (§2). The bell, the
// sync status and Hide amounts are in shell_tools.dart, which Android shares;
// the calculator is in the kit.

/// The clock's time source; tests replace it.
abstract final class TitleBarClock {
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "Thu, 30 Oct", in the app's day-month order.
  static String date(DateTime d) =>
      '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
}

/// The date and time in the title bar's left segment, updated each minute.
/// The time follows the system's 12/24-hour setting. It opens a month
/// calendar. [timeOnly] fits the 64-wide rail.
class ClockButton extends StatefulWidget {
  const ClockButton({
    super.key,
    required this.timeOnly,
    required this.onCalendar,
  });
  final bool timeOnly;
  final VoidCallback onCalendar;
  @override
  State<ClockButton> createState() => _ClockButtonState();
}

class _ClockButtonState extends State<ClockButton> {
  Timer? timer;
  late DateTime now = TitleBarClock.now();

  @override
  void initState() {
    super.initState();
    schedule();
  }

  /// Wakes at the start of the next minute.
  void schedule() {
    timer = Timer(Duration(seconds: 60 - TitleBarClock.now().second), () {
      if (!mounted) return;
      setState(() => now = TitleBarClock.now());
      schedule();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(now),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final date = TitleBarClock.date(now);
    final text = Theme.of(context).textTheme;
    return MenuAnchor(
      alignmentOffset: const Offset(0, Space.xs),
      menuChildren: [
        _CalendarPanel(today: now),
        MenuItemButton(
          key: const ValueKey('clock-open-calendar'),
          leadingIcon: const Icon(Icons.calendar_month_outlined),
          onPressed: widget.onCalendar,
          child: const Text('Open Life › Calendar'),
        ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: '$date · $time',
        excludeFromSemantics: true,
        child: Semantics(
          container: true,
          button: true,
          label: '$date, $time. Open the calendar',
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          excludeSemantics: true,
          child: SizedBox(
            height: Space.pointerTarget,
            child: Pressable(
              key: const ValueKey('titlebar-clock'),
              radius: Radii.nav,
              onTap: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              padding: EdgeInsets.symmetric(
                horizontal: widget.timeOnly ? Space.xs : Space.md,
              ),
              child: widget.timeOnly
                  ? Center(
                      widthFactor: 1,
                      child: Text(
                        time,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: text.bodySmall?.copyWith(
                          color: c.text,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: Space.navIcon,
                          color: c.secondary,
                        ),
                        const SizedBox(width: Space.md),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: time,
                                  style: TextStyle(
                                    color: c.text,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextSpan(text: ' · $date'),
                              ],
                            ),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: NavType.label(context)?.copyWith(
                              color: c.secondary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A month calendar with today marked. It only shows dates; Life holds the
/// agenda.
class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({required this.today});
  final DateTime today;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: Space.popoverMaxWidth,
    child: CalendarDatePicker(
      key: const ValueKey('clock-calendar'),
      initialDate: today,
      currentDate: today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      onDateChanged: (_) {},
    ),
  );
}
