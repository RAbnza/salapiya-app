import 'package:flutter/material.dart';

import '../theme.dart';
import 'dashboard.dart';
import 'focus_ring.dart';
import 'money.dart';
import 'rows.dart';

/// One column of an [AppTable]: a fixed [width], or a [flex] share of what's
/// left.
typedef AppTableColumn = ({String label, int flex, double? width});

/// The date column's width.
const dateColumn = Space.xxxl * 2 + Space.lg;

class AppTableRow {
  const AppTableRow({
    required this.id,
    required this.cells,
    required this.money,
    required this.spoken,
    required this.narrow,
    this.onTap,
    this.action,
  }) : header = null;

  /// Starts a group of rows, e.g. one day of a dated list. It takes no part
  /// in the columns, so every day's rows share one set of widths. Space sets
  /// it apart: there's no hairline around it, and `groupGap` above it.
  const AppTableRow.header(this.id, Widget this.header)
    : cells = const [],
      money = const [],
      spoken = '',
      narrow = header,
      onTap = null,
      action = null;

  final String id;
  final Widget? header;

  /// One widget per [AppTable.columns].
  final List<Widget> cells;

  /// One amount per [AppTable.moneyColumns].
  final List<String?> money;

  /// What a screen reader hears for the row.
  final String spoken;

  /// The same row in a narrow card.
  final Widget narrow;
  final VoidCallback? onTap;

  /// Sits outside the row's own target, so it stays its own control.
  final Widget? action;
}

/// The width of a small action column: [label] and its chevron.
double _actionWidth(BuildContext context, String label) {
  final painter = TextPainter(
    text: TextSpan(text: label, style: Theme.of(context).textTheme.labelMedium),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return (width + Space.lg + Space.sm + Space.xxs).ceilToDouble();
}

/// A table (§2 Data display): columns at 528 × the text scale and wider, rows
/// below that. Each amount column has one measured width, so every column
/// starts at the same x on every row.
class AppTable extends StatelessWidget {
  const AppTable({
    super.key,
    required this.columns,
    required this.rows,
    this.moneyColumns = const [],
    this.actionLabel,
    this.dense = false,
  });
  final List<AppTableColumn> columns;
  final List<String> moneyColumns;
  final List<AppTableRow> rows;

  /// Reserves a column as wide as this label for each row's action.
  final String? actionLabel;

  /// Rows of one line, for long lists.
  final bool dense;

  /// The narrow table: rows under their group headers, with hairlines only
  /// between the rows of a group.
  Widget _groupedList(BuildContext context) {
    if (rows.every((r) => r.header == null)) {
      return ListGroup(children: [for (final r in rows) r.narrow]);
    }
    final children = <Widget>[];
    var group = <Widget>[];
    void close() {
      if (group.isEmpty) return;
      children.add(ListGroup(children: group));
      group = [];
    }

    for (final r in rows) {
      if (r.header == null) {
        group.add(r.narrow);
      } else {
        close();
        children.add(
          _GroupHeader(
            first: children.isEmpty,
            inset: ListRow.horizontalPadding,
            child: r.header!,
          ),
        );
      }
    }
    close();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final data = rows.where((r) => r.header == null);
      final widths = [
        for (final (i, label) in moneyColumns.indexed)
          moneyColumnWidth(context, [label, for (final r in data) r.money[i]]),
      ];
      final actionWidth = actionLabel == null
          ? null
          : _actionWidth(context, actionLabel!);
      // Fixed widths grow with the text; what's left must still hold the
      // flexible columns, or the table turns into rows.
      final fixed =
          [
            for (final column in columns) (column.width ?? 0) * scale,
            ...widths,
          ].fold<double>(0, (a, b) => a + b) +
          Space.md * (columns.length + moneyColumns.length - 1) +
          Space.sm * 2 +
          (actionWidth == null ? 0 : actionWidth + Space.sm);
      final shares = columns.fold(0, (n, column) => n + column.flex);
      if (narrowAt(context, box.maxWidth, tableBase) ||
          box.maxWidth - fixed < shares * Space.xxxl * scale) {
        return _groupedList(context);
      }
      final c = CraftTheme.of(context);
      final text = Theme.of(context).textTheme;
      final head = text.labelMedium?.copyWith(color: c.secondary);
      final minHeight = isDesktop(context)
          ? (dense ? Space.compactRow : Space.compactTwoLineRow)
          : (dense ? Space.target : Space.target + Space.sm);
      Widget cells(List<Widget> children, List<Widget> money) => Row(
        children: [
          for (final (i, column) in columns.indexed) ...[
            if (i > 0) const SizedBox(width: Space.md),
            if (column.width != null)
              SizedBox(width: column.width! * scale, child: children[i])
            else
              Expanded(flex: column.flex, child: children[i]),
          ],
          for (final (i, m) in money.indexed) ...[
            const SizedBox(width: Space.md),
            SizedBox(
              width: widths[i],
              child: Align(alignment: AlignmentDirectional.centerEnd, child: m),
            ),
          ],
        ],
      );
      Widget action(Widget? child) => actionWidth == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsetsDirectional.only(start: Space.sm),
              child: SizedBox(
                width: actionWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: child,
                ),
              ),
            );
      const padding = EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: padding,
                    child: cells(
                      [for (final col in columns) Text(col.label, style: head)],
                      [for (final m in moneyColumns) Text(m, style: head)],
                    ),
                  ),
                ),
                action(null),
              ],
            ),
          ),
          Divider(height: 1, color: c.divider),
          for (final (n, r) in rows.indexed) ...[
            if (n > 0 && r.header == null && rows[n - 1].header == null)
              Divider(height: 1, color: c.divider),
            if (r.header != null)
              _GroupHeader(first: n == 0, inset: Space.sm, child: r.header!)
            else
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: r.onTap != null,
                      label: r.spoken,
                      excludeSemantics: true,
                      child: Pressable(
                        key: ValueKey('row-${r.id}'),
                        onTap: r.onTap,
                        padding: padding,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: minHeight),
                          child: cells(r.cells, [
                            for (final m in r.money) MoneyAmount(m),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  action(r.action),
                ],
              ),
          ],
        ],
      );
    },
  );
}

/// Where a group starts: `groupGap` above it, or `md` under the table's own
/// header, and close to the rows it belongs to.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.first,
    required this.inset,
    required this.child,
  });
  final bool first;
  final double inset;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      inset,
      first ? Space.md : Space.groupGap,
      inset,
      Space.xs,
    ),
    child: child,
  );
}

/// "Show more": lists grow by a page rather than paging (§2 Tables).
class ShowMore extends StatelessWidget {
  const ShowMore({super.key, required this.left, required this.onPressed});
  final int left;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: CardLink(
      'Show more · $left left',
      icon: Icons.expand_more,
      onPressed: onPressed,
    ),
  );
}
