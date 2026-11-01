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
                child: _Reveal(
                  selected: value == selected,
                  child: Pressable(
                    key: ValueKey(value),
                    onTap: () => onSelected(value),
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: hitTarget(context),
                      ),
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Brings the selected tab into view when the row doesn't fit. It moves only
/// the row, never the page around it.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.selected, required this.child});
  final bool selected;
  final Widget child;
  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  void reveal() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !widget.selected) return;
    final tab = context.findRenderObject();
    final row = Scrollable.maybeOf(context)?.position;
    if (tab != null && row != null && row.hasContentDimensions) {
      row.ensureVisible(tab, alignment: .5);
    }
  });

  @override
  void initState() {
    super.initState();
    if (widget.selected) reveal();
  }

  @override
  void didUpdateWidget(_Reveal old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) reveal();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
