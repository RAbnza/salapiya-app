import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme.dart';
import 'buttons.dart';
import 'charts.dart';
import 'focus_ring.dart';
import 'money.dart';
import 'rows.dart';
import 'states.dart';
import 'status.dart';
import 'surfaces.dart';

/// The compact dashboard kit, moved from the Overview unchanged (§2 Section
/// screen standard). Controls look 32 tall on both platforms; on touch,
/// [TouchArea] grows each hit area to 48 with transparent space (§1 targets).

/// On touch, extends [child]'s hit area to 48 × 48 around it. Taps on the
/// child itself go to the child; taps on the extra space call [onTap].
class TouchArea extends StatelessWidget {
  const TouchArea({
    super.key,
    required this.onTap,
    required this.child,
    this.alignment = Alignment.center,
  });
  final VoidCallback? onTap;
  final Widget child;
  final AlignmentGeometry alignment;
  @override
  Widget build(BuildContext context) => isDesktop(context)
      ? child
      : GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Space.target,
              minWidth: Space.target,
            ),
            child: Align(
              alignment: alignment,
              widthFactor: 1,
              heightFactor: 1,
              child: child,
            ),
          ),
        );
}

/// A switch at the compact scale: 20 tall on Windows and 24 on Android, in
/// step with the fields and buttons around it. On Android it keeps a 48 hit
/// area. Give it a [label] when no text beside it says what it does.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });
  final bool value;

  /// Null disables it.
  final ValueChanged<bool>? onChanged;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return Semantics(
      label: label,
      child: TouchArea(
        onTap: change == null ? null : () => change(!value),
        // Flush with the content above and below it, not inset by the area.
        alignment: AlignmentDirectional.centerEnd,
        child: SizedBox(
          height: isDesktop(context) ? Space.xl - Space.xs : Space.xl,
          child: FittedBox(
            child: Switch(
              value: value,
              onChanged: change,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ),
    );
  }
}

/// A label and its switch, read as one control. It keeps a row's height, so a
/// list of them doesn't crowd.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.switchKey,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Key? switchKey;
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: isDesktop(context) ? Space.pointerTarget : Space.target,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: Space.md),
          AppSwitch(key: switchKey, value: value, onChanged: onChanged),
        ],
      ),
    ),
  );
}

/// A small text action in a card header, e.g. "View all ›".
class CardLink extends StatelessWidget {
  const CardLink(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.chevron = true,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  /// Off inside a row that already ends in its own chevron. The link then
  /// ends flush with its text, so it lines up with an amount above it.
  final bool chevron;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return TouchArea(
      onTap: onPressed,
      alignment: chevron ? Alignment.center : AlignmentDirectional.centerEnd,
      child: Semantics(
        container: true,
        onTap: onPressed,
        button: true,
        label: label,
        excludeSemantics: true,
        child: Pressable(
          onTap: onPressed,
          padding: EdgeInsetsDirectional.only(
            start: Space.xs,
            top: Space.xs,
            end: chevron ? Space.xs : 0,
            bottom: Space.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: Space.lg, color: c.primary),
                const SizedBox(width: Space.xxs),
              ],
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: c.primary),
                ),
              ),
              if (icon == null && chevron)
                Icon(Icons.chevron_right, size: Space.lg, color: c.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact segmented control for 2–3 view options (§5 option picker):
/// a `subtle` track with the selected segment raised on it.
class MiniSegmented<T> extends StatelessWidget {
  const MiniSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.label,
  });
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  /// What the options choose, for screen readers ("Period").
  final String label;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme.labelMedium;
    final radius = Radii.controlOf(context);
    // Scrolls sideways rather than shrink its text when it can't fit.
    return Semantics(
      label: label,
      container: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Center(
                child: Container(
                  height: Space.pointerTarget,
                  decoration: BoxDecoration(
                    color: c.subtle,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (value, name) in options)
                  TouchArea(
                    onTap: () => onSelected(value),
                    child: Padding(
                      padding: const EdgeInsets.all(Space.xxs),
                      child: Semantics(
                        container: true,
                        onTap: () => onSelected(value),
                        button: true,
                        selected: value == selected,
                        inMutuallyExclusiveGroup: true,
                        label: name,
                        excludeSemantics: true,
                        child: Pressable(
                          key: ValueKey(value),
                          onTap: () => onSelected(value),
                          radius: radius - Space.xxs,
                          color: value == selected ? c.surface : null,
                          border: value == selected
                              ? Border.all(color: c.divider)
                              : null,
                          child: Container(
                            height: Space.pointerTarget - Space.xs,
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.md,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              name,
                              style: text?.copyWith(
                                color: value == selected ? c.text : c.secondary,
                                fontWeight: value == selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A quick action: a small outlined button with an icon.
class ChipButton extends StatelessWidget {
  const ChipButton(
    this.label, {
    super.key,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return TouchArea(
      onTap: onPressed,
      child: Semantics(
        container: true,
        onTap: onPressed,
        button: true,
        label: label,
        excludeSemantics: true,
        child: Pressable(
          onTap: onPressed,
          color: c.surface,
          border: Border.all(color: c.divider),
          // A minimum height, so large text wraps instead of overflowing.
          child: Container(
            constraints: const BoxConstraints(minHeight: Space.pointerTarget),
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: Space.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: Space.lg, color: c.primary),
                const SizedBox(width: Space.xs + Space.xxs),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One quick action: its label, icon and what it opens.
typedef QuickAction = ({String label, IconData icon, VoidCallback onSelected});

/// The Overview header's quick actions (Windows only; Android uses the +
/// button above the dock). They wrap when the space runs out.
class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
    required this.actions,
    this.alignment = WrapAlignment.start,
  });
  final List<QuickAction> actions;
  final WrapAlignment alignment;
  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final a in actions)
        ChipButton(a.label, icon: a.icon, onPressed: a.onSelected),
    ];
    return Wrap(
      alignment: alignment,
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: chips,
    );
  }
}

/// A small icon on a tinted square, leading a tile's label.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.onAccent = false});
  final IconData icon;

  /// On the tinted focal card, the badge uses `surface` instead.
  final bool onAccent;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return Container(
      width: Space.xxl - Space.xs,
      height: Space.xxl - Space.xs,
      decoration: BoxDecoration(
        color: onAccent ? c.surface : c.selection,
        borderRadius: BorderRadius.circular(Radii.controlOf(context)),
      ),
      child: Icon(icon, size: Space.lg, color: c.primary),
    );
  }
}

/// Whether a rise is good news for this value.
enum ChangeMeaning { riseIsGood, riseIsBad }

/// The change from last month: an arrow and a percentage on a tinted pill,
/// then what it compares with. The arrow and words carry the direction, so
/// color is never the only cue.
class ChangeLine extends StatelessWidget {
  const ChangeLine({
    super.key,
    required this.basisPoints,
    required this.versus,
    required this.meaning,
  });

  /// Null when the earlier value was zero.
  final int? basisPoints;
  final String versus;
  final ChangeMeaning meaning;

  /// The words a screen reader hears.
  static String spoken(int? basisPoints, String versus) {
    final bp = basisPoints;
    return bp == null
        ? 'No earlier amount $versus'
        : bp == 0
        ? 'No change $versus'
        : '${bp > 0 ? 'Up' : 'Down'} ${percentLabel(bp)} $versus';
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final bp = basisPoints;
    final good =
        bp != null &&
        bp != 0 &&
        (bp > 0) == (meaning == ChangeMeaning.riseIsGood);
    final (fg, bg) = bp == null || bp == 0
        ? c.tone(NoticeTone.neutral)
        : c.tone(good ? NoticeTone.success : NoticeTone.warning);
    return Semantics(
      label: spoken(bp, versus),
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.xs + Space.xxs,
        runSpacing: Space.xxs,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.xs + Space.xxs,
              vertical: Space.xxs,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  bp == null || bp == 0
                      ? Icons.remove
                      : bp > 0
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: Space.md,
                  color: fg,
                ),
                const SizedBox(width: Space.xxs),
                Text(
                  bp == null ? 'New' : percentLabel(bp),
                  style: text.labelMedium?.copyWith(
                    color: fg,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Text(versus, style: text.bodySmall?.copyWith(color: c.secondary)),
        ],
      ),
    );
  }
}

/// Marks a card that pairs with the next one of its kind in a stacked
/// column (phones), like the KPI tiles and account cards.
mixin PairCard on Widget {}

/// A KPI tile: an icon and label, the value, the change from last month and
/// a sparkline beside the value (under it when narrow).
class KpiTile extends StatelessWidget with PairCard {
  const KpiTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.change,
    this.spark = const [],
    this.caption,
    this.onTap,
    this.accent = false,
    this.labels = const [],
    this.compactSpark = false,
  });
  final IconData icon;
  final String label;

  /// Keeps the sparkline beside the value down to a narrower tile, so a tile
  /// with one isn't much taller than its neighbours without.
  final bool compactSpark;

  /// Every label in the tile's set. Each tile reserves the height of the
  /// tallest of them at its width, so values line up across a row even when
  /// one label wraps and another doesn't.
  final List<String> labels;
  final Widget value;
  final Widget? change;
  final List<BigInt> spark;
  final String? caption;
  final VoidCallback? onTap;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return SurfaceCard(
      onTap: onTap,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final style = text.labelLarge?.copyWith(color: c.secondary);
              // Measured as if every tile had the chevron, so all tiles in
              // the set reserve the same height.
              final width =
                  box.maxWidth - (Space.xxl - Space.xs) - Space.sm - Space.lg;
              var reserve = 0.0;
              for (final l in labels) {
                final painter = TextPainter(
                  text: TextSpan(text: l, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: width > 0 ? width : 0);
                if (painter.height > reserve) reserve = painter.height;
                painter.dispose();
              }
              return Row(
                children: [
                  IconBadge(icon, onAccent: accent),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: reserve),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(label, style: style),
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: Space.lg,
                      color: c.secondary,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: Space.md),
          LayoutBuilder(
            builder: (context, box) {
              final beside =
                  spark.length > 1 &&
                  box.maxWidth >=
                      ((compactSpark
                                  ? Space.xxxl * 2 + Space.xl
                                  : Space.xxxl * 4) +
                              sparkWidth) *
                          scale;
              final figures = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  value,
                  if (change != null) ...[
                    const SizedBox(height: Space.xs),
                    change!,
                  ],
                ],
              );
              return beside
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: figures),
                        const SizedBox(width: Space.md),
                        SizedBox(
                          width: sparkWidth,
                          height: sparkHeight,
                          child: Sparkline(values: spark),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        figures,
                        if (spark.length > 1) ...[
                          const SizedBox(height: Space.sm),
                          SizedBox(
                            height: sparkHeight,
                            child: Sparkline(values: spark),
                          ),
                        ],
                      ],
                    );
            },
          ),
          if (caption != null) ...[
            const SizedBox(height: Space.sm),
            Text(caption!, style: text.bodySmall?.copyWith(color: c.secondary)),
          ],
        ],
      ),
    );
  }
}

/// A slim bar: [fraction] filled in [color] (default `primary`) on a
/// `subtle` track. Decorative; its row says the same in words.
class SlimBar extends StatelessWidget {
  const SlimBar({super.key, required this.fraction, this.color, this.track});
  final double fraction;
  final Color? color;

  /// Defaults to `subtle`; use `surface` on the tinted focal card.
  final Color? track;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.pill),
        child: SizedBox(
          height: Space.xs + Space.xxs,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: track ?? c.subtle),
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: fraction.clamp(0, 1).toDouble(),
                child: ColoredBox(color: color ?? c.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The width of a table's amount column: its widest amount as `MoneyAmount`
/// draws it (row size) at the current text size, so every row's columns
/// line up whatever each amount's length.
double moneyColumnWidth(BuildContext context, Iterable<String?> amounts) {
  final theme = Theme.of(context).textTheme;
  var widest = 0.0;
  for (final text in amounts) {
    final painter = TextPainter(
      text: TextSpan(
        text: text ?? MoneyAmount.unknown,
        style: text == null
            ? theme.bodyMedium
            : theme.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    if (painter.width > widest) widest = painter.width;
    painter.dispose();
  }
  return widest.ceilToDouble() + Space.xxs;
}

/// Closes a list that may sit in a taller card, so the space below reads as
/// the end of the list rather than as rows that didn't load (§2).
class ListEnd extends StatelessWidget {
  const ListEnd({super.key, this.label = 'That’s everything', this.onPressed});
  final String label;

  /// For a list cut short: the words become a link to the whole list.
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    final open = onPressed;
    // The hairline runs the card's width, with the words set on it.
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Center(child: Divider(height: 1, color: c.divider)),
          ),
          ColoredBox(
            color: c.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
              child: open == null
                  ? Text(
                      label,
                      textAlign: TextAlign.center,
                      style: style?.copyWith(color: c.secondary),
                    )
                  : CardLink(label, onPressed: open),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row's details, joined with dots. Each detail stays whole, so a long line
/// breaks between details and never inside one, as in "in 72 days". A word
/// joiner keeps a sign on its amount ("−₱3,444.50"), where the text engine
/// would otherwise break.
String detailLine(Iterable<String> details) => details
    .map(
      (d) => d
          .replaceAll(' ', '\u00A0')
          .replaceAllMapped(RegExp('[−+](?=₱)'), (m) => '${m[0]}\u2060'),
    )
    .join('\u00A0· ');

/// One figure in a [StatStrip]: a label, its value and an optional detail.
typedef Stat = ({String label, String value, String? detail});

/// A row of small figures on a `subtle` panel, under a card's chart. Four
/// across when they fit, otherwise two.
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.stats});
  final List<Stat> stats;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    Widget stat(Stat s) => Semantics(
      label: [s.label, s.value, ?s.detail].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.label, style: text.bodySmall?.copyWith(color: c.secondary)),
          const SizedBox(height: Space.xxs),
          Text(
            s.value,
            style: text.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (s.detail != null)
            Text(
              s.detail!,
              style: text.bodySmall?.copyWith(color: c.secondary),
            ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.subtle,
        borderRadius: BorderRadius.circular(Radii.controlOf(context)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final across = box.maxWidth >= stats.length * Space.xxxl * 3 * scale
              ? stats.length
              : 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var r = 0; r < stats.length; r += across) ...[
                if (r > 0) const SizedBox(height: Space.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = r; i < r + across; i++) ...[
                      if (i > r) const SizedBox(width: Space.md),
                      Expanded(
                        child: i < stats.length
                            ? stat(stats[i])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A bar of [total] segments with the first [done] filled, one per
/// scheduled payment. Above [maxSegments] it is one continuous bar.
class SegmentBar extends StatelessWidget {
  const SegmentBar({
    super.key,
    required this.done,
    required this.total,
    this.fraction,
    this.track,
  });
  final int done, total;

  /// Used for the continuous bar; defaults to [done] of [total].
  final double? fraction;

  /// Defaults to `subtle`; use `surface` on the tinted focal card.
  final Color? track;

  static const maxSegments = 24;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    if (total <= 0 || total > maxSegments) {
      return SlimBar(
        fraction: fraction ?? (total <= 0 ? 0 : done / total),
        track: track,
      );
    }
    return ExcludeSemantics(
      child: SizedBox(
        height: Space.sm,
        // Stretch: a childless box would otherwise lay out 0 tall.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: Space.xxs),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: i < done ? c.primary : track ?? c.subtle,
                    borderRadius: BorderRadius.circular(Space.xxs),
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

/// "4.2%": basis points with one decimal, rounded toward zero, no sign.
String percentLabel(int basisPoints) {
  final bp = basisPoints.abs();
  return '${bp ~/ 100}.${bp % 100 ~/ 10}%';
}

/// True when [width] can't hold text and a trailing item side by side at
/// the current text size; [base] is the width needed at 100%.
bool narrowAt(BuildContext context, double width, [double base = rowBase]) =>
    width < base * MediaQuery.textScalerOf(context).scale(1);

/// Widths, at 100% text, below which trailing items move under the text,
/// a card's header control moves above its content, and a table or a
/// side-by-side card layout turns into a list.
const rowBase = Space.xxxl * 7,
    titleBase = Space.xxxl + Space.xxl,
    periodBase = Space.xxxl * 6 + Space.lg,
    tableBase = Space.xxxl * 11;

/// A `ListRow` whose trailing item moves under the text when the row is
/// narrow, so amounts are never cut (§4).
class AdaptiveRow extends StatelessWidget {
  const AdaptiveRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.pill,
    this.onTap,
    this.narrowBelow = rowBase,
  });
  final String title;
  final String? subtitle;
  final IconData? leading;
  final Widget? trailing;

  /// The width, at 100% text, below which [trailing] moves under the text. A
  /// short link can stay beside it in a narrower row than an amount can.
  final double narrowBelow;

  /// A status pill. It sits under [trailing], or on the title's line in a
  /// narrow row, so only an amount ever moves under the text. A [trailing]
  /// that is itself a pill is treated the same way.
  final Widget? pill;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final status = pill ?? (trailing is StatusPill ? trailing : null);
      final rest = identical(status, trailing) ? null : trailing;
      final narrow = narrowAt(context, box.maxWidth, narrowBelow);
      final onTitle = narrow && _fits(context, box.maxWidth, status);
      return ListRow(
        title: title,
        subtitle: subtitle,
        leading: leading,
        titleEnd: onTitle ? status : null,
        trailing: onTitle || status == null
            ? rest
            : rest == null
            ? status
            : Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  rest,
                  const SizedBox(height: Space.captionGap),
                  status,
                ],
              ),
        onTap: onTap,
        stackTrailing: narrow,
      );
    },
  );

  /// Whether the title keeps a readable width with a pill on its line.
  bool _fits(BuildContext context, double width, Widget? status) {
    if (status is! StatusPill) return false;
    final icons = ListRow.leadingSize(context);
    final room =
        width -
        ListRow.horizontalPadding * 2 -
        (leading == null ? 0 : icons + ListRow.leadingGap) -
        (onTap == null ? 0 : icons + Space.sm) -
        Space.sm -
        status.widthIn(context);
    return !narrowAt(context, room, titleBase);
  }
}

/// A dashboard card: a compact `titleSmall` header with an optional caption
/// and a small trailing control, which moves above the content when the card
/// is narrower than [stackBelow] at the current text size. [corner] (an icon
/// button) always stays at the header's end. Use [toggle] for an [AppSwitch]
/// that belongs to the whole card, instead of [corner].
class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.title,
    required this.child,
    this.caption,
    this.trailing,
    this.corner,
    this.toggle,
    this.stackBelow = rowBase,
    this.accent = false,
    this.centered = false,
    this.fill = false,
  });
  final String title;
  final String? caption;
  final Widget? trailing, corner;

  /// Level with the title. On Android its touch target lies over the card's
  /// padding, so the target doesn't push the content down.
  final Widget? toggle;
  final Widget child;
  final double stackBelow;
  final bool accent;

  /// Gives [child] the height left under the header as its minimum, so it can
  /// place things in a card the grid row made taller.
  final bool fill;

  /// When the grid row makes the card taller than its content, center the
  /// content in the space under the header instead of leaving a gap below.
  final bool centered;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final toggle = this.toggle;
    final floating = toggle != null && !isDesktop(context);
    final corner = floating ? this.corner : this.corner ?? toggle;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: text.titleSmall)),
        if (caption != null) ...[
          const SizedBox(height: Space.xxs),
          Text(caption!, style: text.bodySmall?.copyWith(color: c.secondary)),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        final stack =
            trailing != null && narrowAt(context, box.maxWidth, stackBelow);
        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: heading),
                if (floating) const SizedBox(width: Space.target),
                // Centered on each other: a link is shorter than an icon
                // button.
                if ((trailing != null && !stack) || corner != null) ...[
                  const SizedBox(width: Space.sm),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (trailing != null && !stack) trailing!,
                      if (trailing != null && !stack && corner != null)
                        const SizedBox(width: Space.xs),
                      ?corner,
                    ],
                  ),
                ],
              ],
            ),
            if (stack) ...[
              const SizedBox(height: Space.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: trailing,
              ),
            ],
            const SizedBox(height: Space.md),
          ],
        );
        // The row's height reaches the card as a minimum; pass it on, less
        // the card's padding and hairline, so the column can use the space.
        final inset =
            EdgeInsets.all(Space.cardPaddingOf(context)).vertical +
            Border.all(color: c.divider).dimensions.vertical;
        final minimum = (centered || fill) && box.minHeight > inset
            ? box.minHeight - inset
            : 0.0;
        final card = SurfaceCard(
          accent: accent,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minimum),
            // Header at the top, content centered in the rest: spaceBetween
            // with an empty last child puts equal space above and below it.
            child: fill
                ? _HeaderOverRest(children: [header, child])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: centered
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.start,
                    children: [
                      header,
                      child,
                      if (centered) const SizedBox.shrink(),
                    ],
                  ),
          ),
        );
        if (!floating) return card;
        final style = text.titleSmall!;
        final line = MediaQuery.textScalerOf(context)
            .scale(style.fontSize! * (style.height ?? 1));
        return Stack(
          fit: StackFit.passthrough,
          children: [
            card,
            PositionedDirectional(
              top: math.max(0, (inset + line - Space.target) / 2),
              end: inset / 2,
              child: toggle,
            ),
          ],
        );
      },
    );
  }
}

/// Two cards in one grid cell, beside a taller card: the second takes the
/// height left, so nothing empty sits under them.
class SideStack extends StatelessWidget {
  const SideStack({super.key, required this.top, required this.rest});
  final Widget top, rest;
  @override
  Widget build(BuildContext context) => _HeaderOverRest(
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          top,
          SizedBox(height: Space.cardGapOf(context)),
        ],
      ),
      rest,
    ],
  );
}

/// A header over one child, which takes the height left as its minimum. A
/// Column can't: a card's height reaches it only as a minimum, so it has
/// nothing to share out.
class _HeaderOverRest extends MultiChildRenderObjectWidget {
  const _HeaderOverRest({required super.children});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeaderOverRest();
}

class _RestParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderHeaderOverRest extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _RestParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _RestParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RestParentData) {
      child.parentData = _RestParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final header = firstChild!, rest = childAfter(header)!;
    header.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    final top = header.size.height;
    final left = constraints.minHeight - top;
    rest.layout(
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        minHeight: left > 0 ? left : 0,
      ),
      parentUsesSize: true,
    );
    (rest.parentData! as _RestParentData).offset = Offset(0, top);
    size = constraints.constrain(Size(width, top + rest.size.height));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// A label with its amount at the end, or the amount under it when narrow.
class LabelAmount extends StatelessWidget {
  const LabelAmount({
    super.key,
    required this.label,
    required this.amount,
    this.stackBelow = rowBase,
  });
  final Widget label, amount;

  /// The width, at 100% text, below which the amount moves under the label.
  final double stackBelow;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => narrowAt(context, box.maxWidth, stackBelow)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label,
              Align(alignment: AlignmentDirectional.centerEnd, child: amount),
            ],
          )
        : Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: Space.md),
              amount,
            ],
          ),
  );
}

/// What a card shows when its source isn't complete yet.
class NotAvailable extends StatelessWidget {
  const NotAvailable(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.hourglass_empty,
    title: MoneyAmount.unknown,
    message: message,
  );
}

/// Shown instead of a chart while amounts are hidden.
class AmountsHidden extends StatelessWidget {
  const AmountsHidden({super.key});
  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.visibility_off_outlined,
    title: 'Amounts hidden',
    message: 'Show amounts to see this chart.',
  );
}

/// A small menu in a card's corner.
class CardMenu extends StatelessWidget {
  const CardMenu({
    super.key,
    required this.tooltip,
    required this.items,
    this.icon = Icons.more_horiz,
  });
  final String tooltip;
  final IconData icon;
  final List<Widget> items;
  @override
  Widget build(BuildContext context) => MenuAnchor(
    alignmentOffset: const Offset(0, Space.xs),
    menuChildren: items,
    builder: (context, controller, _) => AppIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}

/// One fact on a details card: its label, then its value on the same line,
/// or under it when the card is narrow.
class FactRow extends StatelessWidget {
  const FactRow(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: LayoutBuilder(
          builder: (context, box) {
            final name = Text(
              label,
              style: text.bodySmall?.copyWith(color: c.secondary),
            );
            final shown = Text(value, style: text.bodyMedium);
            return narrowAt(context, box.maxWidth, Space.xxxl * 5)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [name, shown],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: name),
                      const SizedBox(width: Space.md),
                      Expanded(flex: 3, child: shown),
                    ],
                  );
          },
        ),
      ),
    );
  }
}
