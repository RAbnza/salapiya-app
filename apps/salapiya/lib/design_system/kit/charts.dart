import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'dashboard.dart';
import 'money.dart';
import 'rows.dart';

/// Charts on fl_chart, moved from the Overview unchanged. They never animate
/// (§1: no animated money values), take every color from the theme, show no
/// abbreviated money on an axis, and give screen readers a summary; exact
/// values sit beside them.

/// Chart plot heights, from the spacing scale: cards and the wide hero chart.
const overviewChartHeight = Space.xxxl * 3, heroChartHeight = Space.xxxl * 4;

/// Sparkline heights: beside a tile's value, or under it when narrow.
const sparkHeight = Space.xxl + Space.sm, sparkWidth = Space.xxxl * 2;

double _value(BigInt minor) => minor.toDouble() / 100;

/// The soft fill under a line: its color fading to nothing.
BarAreaData _area(Color color) => BarAreaData(
  show: true,
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [color.withValues(alpha: .24), color.withValues(alpha: 0)],
  ),
);

/// A decorative trend line with no axes or touch. The values it draws are
/// in its tile's text, so screen readers skip it.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.color});
  final List<BigInt> values;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final line = color ?? CraftTheme.of(context).chartSeries.first;
    final ys = values.map(_value).toList();
    if (ys.length < 2) return const SizedBox.shrink();
    var low = ys.reduce((a, b) => a < b ? a : b);
    var high = ys.reduce((a, b) => a > b ? a : b);
    if (low == high) {
      low -= 1;
      high += 1;
    }
    return ExcludeSemantics(
      child: LineChart(
        duration: Duration.zero,
        LineChartData(
          minY: low,
          maxY: high + (high - low) * .1,
          minX: 0,
          maxX: (ys.length - 1).toDouble(),
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [for (final (i, y) in ys.indexed) FlSpot(i.toDouble(), y)],
              isCurved: true,
              preventCurveOverShooting: true,
              color: line,
              barWidth: Space.xxs * .75,
              dotData: const FlDotData(show: false),
              belowBarData: _area(line),
            ),
          ],
        ),
      ),
    );
  }
}

FlTitlesData _titles(BuildContext context, String? Function(int) label) {
  final c = CraftTheme.of(context);
  final style = Theme.of(context).textTheme.bodySmall
      ?.copyWith(color: c.secondary);
  return FlTitlesData(
    topTitles: const AxisTitles(),
    leftTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: 1,
        reservedSize: Space.xl,
        getTitlesWidget: (value, meta) {
          final text = value == value.roundToDouble()
              ? label(value.toInt())
              : null;
          return text == null
              ? const SizedBox.shrink()
              : SideTitleWidget(
                  meta: meta,
                  space: Space.xs,
                  child: Text(text, style: style),
                );
        },
      ),
    ),
  );
}

FlGridData _grid(BuildContext context) => FlGridData(
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) =>
      FlLine(color: CraftTheme.of(context).divider, strokeWidth: 1),
);

TextStyle? _tooltipStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: CraftTheme.of(context).text);

/// One bar per value, e.g. one per day. [label] names the bars that get an
/// axis label; [tooltip] gives the exact text shown on hover or tap.
class OverviewBarChart extends StatelessWidget {
  const OverviewBarChart({
    super.key,
    required this.values,
    required this.label,
    required this.tooltip,
    required this.semanticsLabel,
    this.height = overviewChartHeight,
  });
  final List<BigInt> values;
  final String? Function(int index) label;
  final String Function(int index) tooltip;
  final String semanticsLabel;
  final double height;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final ys = values.map(_value).toList();
    final low = ys.fold<double>(0, (a, b) => b < a ? b : a);
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, box) {
            final slot = box.maxWidth / (values.isEmpty ? 1 : values.length);
            return BarChart(
              duration: Duration.zero,
              BarChartData(
                minY: low,
                alignment: BarChartAlignment.spaceAround,
                gridData: _grid(context),
                borderData: FlBorderData(show: false),
                titlesData: _titles(context, label),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => c.raised,
                    tooltipBorder: BorderSide(color: c.divider),
                    tooltipBorderRadius: BorderRadius.circular(
                      Radii.controlOf(context),
                    ),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, _, _, _) => BarTooltipItem(
                      tooltip(group.x),
                      _tooltipStyle(context) ?? const TextStyle(),
                    ),
                  ),
                ),
                barGroups: [
                  for (final (i, y) in ys.indexed)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: y,
                          width: slot * 0.6,
                          color: c.chartSeries.first,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(Space.xs),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A line series: its values, its color, whether it is dashed (so the
/// series differ by more than color) and whether it has a soft fill below.
typedef OverviewLine = ({
  List<BigInt> values,
  Color color,
  bool dashed,
  bool fill,
});

class OverviewLineChart extends StatelessWidget {
  const OverviewLineChart({
    super.key,
    required this.lines,
    required this.label,
    required this.tooltip,
    required this.semanticsLabel,
    this.height = overviewChartHeight,
  });
  final List<OverviewLine> lines;
  final String? Function(int index) label;
  final String Function(int line, int index) tooltip;
  final String semanticsLabel;
  final double height;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final all = [for (final l in lines) ...l.values.map(_value)];
    final low = all.fold<double>(0, (a, b) => b < a ? b : a);
    final length = lines.fold(
      0,
      (n, l) => l.values.length > n ? l.values.length : n,
    );
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: LineChart(
          duration: Duration.zero,
          LineChartData(
            minY: low,
            minX: 0,
            maxX: length < 2 ? 1 : (length - 1).toDouble(),
            gridData: _grid(context),
            borderData: FlBorderData(show: false),
            titlesData: _titles(context, label),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => c.raised,
                tooltipBorder: BorderSide(color: c.divider),
                tooltipBorderRadius: BorderRadius.circular(
                  Radii.controlOf(context),
                ),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      tooltip(s.barIndex, s.x.toInt()),
                      _tooltipStyle(context) ?? const TextStyle(),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              for (final line in lines)
                LineChartBarData(
                  spots: [
                    for (final (i, v) in line.values.indexed)
                      FlSpot(i.toDouble(), _value(v)),
                  ],
                  color: line.color,
                  barWidth: Space.xxs,
                  dashArray: line.dashed
                      ? [Space.sm.toInt(), Space.xs.toInt()]
                      : null,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  dotData: FlDotData(show: line.values.length <= 12),
                  belowBarData: line.fill ? _area(line.color) : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A legend entry: a short line sample (solid or dashed) and its label.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.entries});
  final List<({String label, Color color, bool dashed})> entries;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: c.secondary);
    return Wrap(
      spacing: Space.lg,
      runSpacing: Space.xs,
      children: [
        for (final e in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  width: Space.lg,
                  child: Row(
                    children: [
                      for (var i = 0; i < (e.dashed ? 2 : 1); i++) ...[
                        if (i > 0) const SizedBox(width: Space.xxs),
                        Expanded(
                          child: Container(height: Space.xxs, color: e.color),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Space.xs),
              Flexible(child: Text(e.label, style: style)),
            ],
          ),
      ],
    );
  }
}

/// A quiet "Show values" disclosure under a chart: the exact amounts the
/// chart draws, as rows.
class ChartValues extends StatefulWidget {
  const ChartValues({super.key, required this.rows});
  final List<(String, String)> rows;
  @override
  State<ChartValues> createState() => _ChartValuesState();
}

class _ChartValuesState extends State<ChartValues> {
  bool open = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: CardLink(
          open ? 'Hide values' : 'Show values',
          icon: open ? Icons.expand_less : Icons.expand_more,
          onPressed: () => setState(() => open = !open),
        ),
      ),
      if (open)
        ListGroup(
          children: [
            for (final (label, value) in widget.rows)
              AdaptiveRow(title: label, trailing: MoneyAmount(value)),
          ],
        ),
    ],
  );
}
