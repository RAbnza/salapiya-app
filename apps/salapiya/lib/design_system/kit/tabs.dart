import 'package:flutter/material.dart';

import '../theme.dart';
import 'focus_ring.dart';

/// Underline tabs that switch between views of one page. The selected tab
/// is `primary` with a 2 px underline on the row's divider hairline; the row
/// scrolls sideways when it doesn't fit. Each tab is `hitTarget` tall (32 on
/// Windows, 48 on Android). Each tab's key is `ValueKey(value)`.
class AppTabs<T> extends StatelessWidget {
  const AppTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });
  final List<(T, String)> tabs;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final style = Theme.of(context).textTheme.labelLarge;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, (value, label)) in tabs.indexed) ...[
              if (i > 0) const SizedBox(width: Space.md),
              Semantics(
                button: true,
                selected: value == selected,
                inMutuallyExclusiveGroup: true,
                label: label,
                excludeSemantics: true,
                child: Pressable(
                  key: ValueKey(value),
                  onTap: () => onSelected(value),
                  child: Container(
                    constraints: BoxConstraints(minHeight: hitTarget(context)),
                    padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          width: Space.xxs,
                          color: value == selected
                              ? c.primary
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Text(
                      label,
                      style: style?.copyWith(
                        color: value == selected ? c.primary : c.secondary,
                        fontWeight: value == selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
