import 'package:flutter/material.dart';

import '../theme.dart';
import 'focus_ring.dart';

/// A list row. One line is at least one hit target tall (48, or 40 on
/// Windows); two lines are at least 56. The leading icon, the text block,
/// [trailing] (usually a `MoneyAmount` or `StatusPill`) and the chevron are
/// all centered vertically on the row.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });
  final String title;
  final String? subtitle;
  final IconData? leading;
  final Widget? trailing;

  /// Adds a chevron and makes the row one target.
  final VoidCallback? onTap;

  static const horizontalPadding = Space.md;
  static const leadingSize = Space.xl, leadingGap = Space.md;

  /// Where row text starts when rows have a leading icon; dividers inset here.
  static const textInset = horizontalPadding + leadingSize + leadingGap;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final twoLine = subtitle != null;
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: twoLine ? Space.target + Space.sm : hitTarget(context),
          ),
          child: Pressable(
            onTap: onTap,
            padding: const EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: Space.sm,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  Icon(leading, size: leadingSize, color: c.secondary),
                  const SizedBox(width: leadingGap),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleSmall),
                      if (twoLine)
                        Text(
                          subtitle!,
                          style: text.bodySmall?.copyWith(color: c.secondary),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: Space.lg),
                  trailing!,
                ],
                if (onTap != null) ...[
                  const SizedBox(width: Space.sm),
                  Icon(Icons.chevron_right, color: c.secondary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rows separated by hairlines inset to the text start; none after the last.
class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.children, this.leading = false});
  final List<Widget> children;

  /// True when the rows have leading icons, so dividers start at the text.
  final bool leading;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, row) in children.indexed) ...[
        if (i > 0)
          Divider(
            height: 1,
            thickness: 1,
            indent: leading ? ListRow.textInset : ListRow.horizontalPadding,
          ),
        row,
      ],
    ],
  );
}
