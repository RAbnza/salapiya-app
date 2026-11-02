import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme.dart';
import 'dashboard.dart';

/// A card with its span on the 12-column grid when wide and when medium.
typedef GridCard = (Widget card, int wide, int medium);

/// The Overview grid, by content width: 12 columns from 1104 (the wide
/// spans), from 688 (the medium spans), otherwise one stacked column in
/// priority order, where [PairCard]s pair up when two fit. Android always
/// stacks ([cards] is null). Cards in a row share the tallest card's height,
/// and the grid owns the gap (§4).
class DashboardGrid extends StatelessWidget {
  const DashboardGrid({super.key, required this.cards, required this.stacked});
  final List<GridCard>? cards;
  final List<Widget> stacked;

  static const two = Space.xxxl * 14 + Space.lg, four = Space.xxxl * 23;
  static const columns = 12;

  /// The narrowest column in which two paired cards still sit side by side.
  static const pairWidth = Space.xxxl * 7;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final gap = Space.cardGapOf(context);
      final large = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
      // At 150% text and up, drop one width class (§2).
      final width = large ? box.maxWidth / 1.5 : box.maxWidth;
      final mode = cards == null
          ? 0
          : width >= four
          ? 2
          : width >= two
          ? 1
          : 0;
      // Each row: its column count and its (card, span) cells.
      final rows = <(int, List<(Widget, int)>)>[];
      if (mode == 0) {
        final pair = !large && box.maxWidth >= pairWidth;
        for (final card in stacked) {
          final last = rows.lastOrNull;
          if (pair &&
              card is PairCard &&
              last != null &&
              last.$2.length == 1 &&
              last.$1 == 2 &&
              last.$2.first.$1.runtimeType == card.runtimeType) {
            rows[rows.length - 1] = (2, [...last.$2, (card, 1)]);
          } else {
            rows.add((card is PairCard && pair ? 2 : 1, [(card, 1)]));
          }
        }
        // A paired card left alone takes the full width.
        for (final (i, row) in rows.indexed) {
          if (row.$2.length == 1) rows[i] = (1, [(row.$2.first.$1, 1)]);
        }
      } else {
        var used = columns;
        for (final (card, wideSpan, mediumSpan) in cards!) {
          final span = (mode == 2 ? wideSpan : mediumSpan).clamp(1, columns);
          if (used + span > columns) {
            rows.add((columns, []));
            used = 0;
          }
          rows.last.$2.add((card, span));
          used += span;
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (count, cells)) in rows.indexed) ...[
            if (i > 0) SizedBox(height: gap),
            _EqualHeightRow(
              gap: gap,
              columns: count,
              spans: [for (final c in cells) c.$2],
              children: [for (final c in cells) c.$1],
            ),
          ],
        ],
      );
    },
  );
}

/// A row of cards on a [columns]-wide grid, each [spans] columns wide, all as
/// tall as the tallest. Unlike `IntrinsicHeight`, it lays each child out
/// twice, so children may use `LayoutBuilder`.
class _EqualHeightRow extends MultiChildRenderObjectWidget {
  const _EqualHeightRow({
    required this.gap,
    required this.columns,
    required this.spans,
    required super.children,
  });
  final double gap;
  final int columns;
  final List<int> spans;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEqualHeightRow(gap, columns, spans);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderEqualHeightRow renderObject,
  ) => renderObject
    ..gap = gap
    ..columns = columns
    ..spans = spans;
}

class _RowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderEqualHeightRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _RowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _RowParentData> {
  _RenderEqualHeightRow(this._gap, this._columns, this._spans);
  double _gap;
  int _columns;
  List<int> _spans;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  set columns(int v) {
    if (v == _columns) return;
    _columns = v;
    markNeedsLayout();
  }

  set spans(List<int> v) {
    if (listEquals(v, _spans)) return;
    _spans = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RowParentData) {
      child.parentData = _RowParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final unit = (width - _gap * (_columns - 1)) / _columns;
    double widthOf(int span) => unit * span + _gap * (span - 1);
    var tallest = 0.0;
    var child = firstChild;
    var i = 0;
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(width: widthOf(_spans[i])),
        parentUsesSize: true,
      );
      if (child.size.height > tallest) tallest = child.size.height;
      child = childAfter(child);
      i++;
    }
    // A minimum height rather than a tight one: a tight child would become a
    // relayout boundary, and content that grows later would overflow it.
    child = firstChild;
    i = 0;
    var x = 0.0;
    while (child != null) {
      final w = widthOf(_spans[i]);
      child.layout(
        BoxConstraints(minWidth: w, maxWidth: w, minHeight: tallest),
        parentUsesSize: true,
      );
      (child.parentData! as _RowParentData).offset = Offset(x, 0);
      if (child.size.height > tallest) tallest = child.size.height;
      x += w + _gap;
      child = childAfter(child);
      i++;
    }
    size = constraints.constrain(Size(width, tallest));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
