import 'package:flutter/material.dart';

import '../theme.dart';
import 'focus_ring.dart';

/// A list row. One line is at least 48 tall (36 on Windows); two lines are
/// at least 56 (48 on Windows). The leading icon, the text block,
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
    this.stackTrailing = false,
    this.titleEnd,
  });
  final String title;
  final String? subtitle;
  final IconData? leading;
  final Widget? trailing;

  /// Puts [trailing] under the text, end-aligned, for rows too narrow to
  /// hold both side by side (e.g. at 200% text). Amounts are never cut.
  final bool stackTrailing;

  /// At the end of the title's first line, so the subtitle keeps the row's
  /// width. For a status pill in a narrow row.
  final Widget? titleEnd;

  /// Adds a chevron and makes the row one target.
  final VoidCallback? onTap;

  static const horizontalPadding = Space.md, leadingGap = Space.md;

  /// The leading icon and chevron: 24, or 16 on Windows.
  static double leadingSize(BuildContext context) =>
      isDesktop(context) ? Space.compactControlIcon : Space.xl;

  /// Where row text starts when rows have a leading icon; dividers inset here.
  static double textInset(BuildContext context) =>
      horizontalPadding + leadingSize(context) + leadingGap;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final twoLine = subtitle != null;
    final compact = isDesktop(context);
    final iconSize = leadingSize(context);
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: switch ((twoLine, compact)) {
              (true, true) => Space.compactTwoLineRow,
              (true, false) => Space.target + Space.sm,
              (false, true) => Space.compactRow,
              (false, false) => Space.target,
            },
          ),
          child: Pressable(
            onTap: onTap,
            // Windows' two-line rows fit 48 with a tighter inset.
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: compact ? Space.xs + Space.xxs : Space.sm,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  Icon(leading, size: iconSize, color: c.secondary),
                  const SizedBox(width: leadingGap),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (titleEnd != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(title, style: text.titleSmall),
                            ),
                            const SizedBox(width: Space.sm),
                            titleEnd!,
                          ],
                        )
                      else
                        Text(title, style: text.titleSmall),
                      if (twoLine)
                        Text(
                          subtitle!,
                          style: text.bodySmall?.copyWith(color: c.secondary),
                        ),
                      if (stackTrailing && trailing != null) ...[
                        const SizedBox(height: Space.xs),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: trailing,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null && !stackTrailing) ...[
                  const SizedBox(width: Space.lg),
                  trailing!,
                ],
                if (onTap != null) ...[
                  const SizedBox(width: Space.sm),
                  Icon(Icons.chevron_right, size: iconSize, color: c.secondary),
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
            indent: leading
                ? ListRow.textInset(context)
                : ListRow.horizontalPadding,
          ),
        row,
      ],
    ],
  );
}
