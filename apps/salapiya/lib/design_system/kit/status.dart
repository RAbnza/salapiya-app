import 'package:flutter/material.dart';

import '../theme.dart';

enum PillTone { neutral, information, success, warning, error, overdue }

/// A small, non-interactive status label: always an icon and words, never
/// color alone. Debt states use the same labels as `DebtDueStatus`.
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    required this.icon,
    this.tone = PillTone.neutral,
  });
  const StatusPill.overdue({super.key})
    : label = 'Overdue',
      icon = Icons.error_outline,
      tone = PillTone.overdue;
  const StatusPill.dueToday({super.key})
    : label = 'Due today',
      icon = Icons.today_outlined,
      tone = PillTone.warning;
  const StatusPill.dueSoon({super.key})
    : label = 'Due soon',
      icon = Icons.schedule,
      tone = PillTone.warning;
  const StatusPill.upcoming({super.key})
    : label = 'Upcoming',
      icon = Icons.event_outlined,
      tone = PillTone.neutral;
  const StatusPill.scheduleNotSet({super.key})
    : label = 'Schedule not set',
      icon = Icons.event_busy_outlined,
      tone = PillTone.neutral;
  const StatusPill.paidOff({super.key})
    : label = 'Paid off',
      icon = Icons.check_circle_outline,
      tone = PillTone.success;
  const StatusPill.settled({super.key})
    : label = 'Settled',
      icon = Icons.done_all,
      tone = PillTone.success;

  final String label;
  final IconData icon;
  final PillTone tone;

  static (Color, Color) colors(CraftTheme c, PillTone tone) => switch (tone) {
    PillTone.overdue => c.overdue,
    PillTone.neutral => c.tone(NoticeTone.neutral),
    PillTone.information => c.tone(NoticeTone.information),
    PillTone.success => c.tone(NoticeTone.success),
    PillTone.warning => c.tone(NoticeTone.warning),
    PillTone.error => c.tone(NoticeTone.error),
  };

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final (ink, fill) = colors(c, tone);
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: Space.pillPadding,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.pill),
          // Tinted fills become `surface` in high contrast; keep a boundary.
          border: c.highContrast ? Border.all(color: ink) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: Space.lg, color: ink),
            const SizedBox(width: Space.xs),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tinted message inside a page or form: information, success, warning or
/// error. It states facts calmly; an optional [action] sits below.
class InlineNotice extends StatelessWidget {
  const InlineNotice(
    this.message, {
    super.key,
    this.title,
    this.tone = NoticeTone.information,
    this.action,
    this.live = false,
  });
  final String message;
  final String? title;
  final NoticeTone tone;
  final Widget? action;

  /// Announce changes to screen readers.
  final bool live;

  static IconData iconFor(NoticeTone tone) => switch (tone) {
    NoticeTone.success => Icons.check_circle_outline,
    NoticeTone.warning => Icons.warning_amber_rounded,
    NoticeTone.error => Icons.error_outline,
    NoticeTone.information => Icons.info_outline,
    NoticeTone.neutral => Icons.notes_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final (ink, fill) = c.tone(tone);
    return Semantics(
      container: true,
      liveRegion: live,
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.control),
          border: c.highContrast ? Border.all(color: ink) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(iconFor(tone), color: ink),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(title!, style: text.titleSmall?.copyWith(color: ink)),
                    const SizedBox(height: Space.captionGap),
                  ],
                  Text(
                    message,
                    style: text.bodyMedium?.copyWith(color: c.text),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: Space.sm),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
