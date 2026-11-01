import 'package:flutter/material.dart';

import '../app/overview_dashboard.dart' show overviewLongDate;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'life_data.dart';

/// Life's header. Windows: the title, the date and quick actions. Android: one
/// 48-tall row with a pill for what's overdue or on today, because the app bar
/// has the title and the + button has the actions.
class LifeHeader extends StatelessWidget {
  const LifeHeader({
    super.key,
    required this.today,
    this.caption,
    this.actions = const [],
    this.pill,
    this.onPill,
    this.alwaysActions = false,
  });
  final String today;

  /// What follows the date in the caption.
  final String? caption;
  final List<QuickAction> actions;
  final StatusPill? pill;
  final VoidCallback? onPill;

  /// Shows [actions] on Android too, for what the + button doesn't have.
  final bool alwaysActions;
  @override
  Widget build(BuildContext context) {
    final date = overviewLongDate(today);
    final chips = QuickActions(
      key: const ValueKey('life-quick-actions'),
      actions: actions,
    );
    if (!isDesktop(context)) {
      final line = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Space.target),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: Space.lg + Space.xxs,
              color: CraftTheme.of(context).primary,
            ),
            const SizedBox(width: Space.sm),
            Flexible(
              child: Text(date, style: Theme.of(context).textTheme.titleSmall),
            ),
          ],
        ),
      );
      final Widget? badge = pill == null || onPill == null
          ? pill
          : Semantics(
              button: true,
              label: pill!.label,
              excludeSemantics: true,
              child: TouchArea(
                onTap: onPill,
                child: Pressable(
                  key: const ValueKey('life-pill'),
                  onTap: onPill!,
                  radius: Radii.pill,
                  child: pill!,
                ),
              ),
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            // The pill drops under the date when large text can't hold both.
            builder: (context, box) => narrowAt(context, box.maxWidth)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [line, ?badge],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: line,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: Space.sm),
                        badge,
                      ],
                    ],
                  ),
          ),
          if (alwaysActions && actions.isNotEmpty) chips,
        ],
      );
    }
    final title = PageHeader(
      'Life',
      caption: caption == null ? 'As of $date' : 'As of $date · $caption',
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (actions.isEmpty) return title;
        // Beside the title when wide, ending at the content's right edge.
        return box.maxWidth >= DashboardGrid.four
            ? Row(
                children: [
                  Expanded(flex: 2, child: title),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: QuickActions(
                        key: const ValueKey('life-quick-actions'),
                        actions: actions,
                        alignment: WrapAlignment.end,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [title, const SizedBox(height: Space.md), chips],
              );
      },
    );
  }
}

/// Under the tabs, only when they apply.
List<Widget> lifeNotices(LifeSource source) => [
  if (!source.lifeComplete)
    const InlineNotice(
      'Some of your events and tasks may not show until it finishes.',
      title: 'Your first download isn’t finished',
      tone: NoticeTone.warning,
    ),
  if (!source.complete)
    const InlineNotice(
      'Debts, cards and bills show here once all your records have downloaded.',
      title: 'Your first download isn’t finished',
      tone: NoticeTone.warning,
    ),
  if (source.waiting > 0)
    InlineNotice(
      '${source.waiting} ${source.waiting == 1 ? 'change is' : 'changes are'} waiting to sync. This includes them, but a reminder can still go off for something you’ve already logged until they sync.',
      live: true,
    ),
  if (source.error != null)
    InlineNotice(source.error!, tone: NoticeTone.warning, live: true),
];
