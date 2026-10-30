import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../design_system/theme.dart';

/// Overview charts on fl_chart. They never animate (§1: no animated money
/// values), take every color from the theme, show no abbreviated money on an
/// axis, and give screen readers a summary; exact values sit beside them.

double _value(BigInt minor) => minor.toDouble() / 100;

/// Spending shares as a donut, with [center] in the hole. Colors follow the
/// chart series; the legend beside it carries the names and values.
/// Hovering or tapping a section selects it ([onSelected]); it grows
/// outward. Leaving the chart, or tapping its hole, clears the selection.
class OverviewDonut extends StatelessWidget {
  const OverviewDonut({
    super.key,
    required this.values,
    required this.colors,
    required this.center,
    required this.semanticsLabel,
    this.selected,
    this.onSelected,
    this.size = Space.xxxl * 3 + Space.lg,
  });
  final List<BigInt> values;
  final List<Color> colors;
  final Widget center;
  final String semanticsLabel;
  final int? selected;
  final ValueChanged<int?>? onSelected;
  final double size;

  /// The section index under the pointer, or null.
  static int? _hit(PieTouchResponse? response) {
    final index = response?.touchedSection?.touchedSectionIndex ?? -1;
    return index >= 0 ? index : null;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            duration: Duration.zero,
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: Space.xxs,
              // Room for a selected section to grow by 4.
              centerSpaceRadius: size / 2 - Space.lg - Space.xs - Space.xxs,
              pieTouchData: PieTouchData(
                enabled: onSelected != null,
                mouseCursorResolver: (_, response) => _hit(response) == null
                    ? MouseCursor.defer
                    : SystemMouseCursors.click,
                touchCallback: (event, response) {
                  final hit = _hit(response);
                  final next = switch (event) {
                    FlPointerHoverEvent() || FlTapUpEvent() => hit,
                    FlPointerExitEvent() => null,
                    _ => selected,
                  };
                  if (next != selected) onSelected?.call(next);
                },
              ),
              sections: [
                for (final (i, v) in values.indexed)
                  PieChartSectionData(
                    value: _value(v),
                    color: colors[i % colors.length],
                    radius: i == selected ? Space.lg + Space.xs : Space.lg,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          // Taps in the hole reach the chart, which clears the selection.
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.all(Space.xl + Space.xs),
              child: FittedBox(fit: BoxFit.scaleDown, child: center),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A half-circle gauge: [fraction] of the arc filled (clamped to the arc),
/// with [child] under its middle. [over] paints the arc in the warning tone.
class BudgetGauge extends StatelessWidget {
  const BudgetGauge({
    super.key,
    required this.fraction,
    required this.over,
    required this.child,
    this.width = Space.xxxl * 4,
  });
  final double fraction;
  final bool over;
  final Widget child;
  final double width;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return SizedBox(
      width: width,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ExcludeSemantics(
            child: CustomPaint(
              size: Size(width, width / 2 + Space.sm),
              painter: _GaugePainter(
                fraction: fraction.clamp(0, 1).toDouble(),
                track: c.subtle,
                fill: over ? c.tone(NoticeTone.warning).$1 : c.primary,
                stroke: Space.md,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.fraction,
    required this.track,
    required this.fill,
    required this.stroke,
  });
  final double fraction, stroke;
  final Color track, fill;
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2 - stroke / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.width / 2),
      radius: radius,
    );
    Paint paint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, paint(track));
    if (fraction > 0) {
      canvas.drawArc(rect, math.pi, math.pi * fraction, false, paint(fill));
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.track != track || old.fill != fill;
}

