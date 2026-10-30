import 'package:flutter/material.dart';

import '../theme.dart';
import 'focus_ring.dart';

/// A level-1 card: `surface`, a divider hairline, card radius, equal padding.
/// It has no outer margin (the grid owns gaps) and never holds another card.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.title,
    this.caption,
    this.trailing,
    this.onTap,
    this.accent = false,
  });
  final Widget child;
  final String? title, caption;
  final Widget? trailing;

  /// Makes the whole card one target, with hover, pressed and focus states.
  final VoidCallback? onTap;

  /// The one tinted focal card on a screen (`selection`); at most one.
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title!, style: text.titleMedium),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: Space.captionGap),
                      Text(
                        caption!,
                        style: text.bodySmall?.copyWith(color: c.secondary),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: Space.cardHeaderGap),
        ],
        child,
      ],
    );
    // Material sits inside the fill so stock list tiles in a card still paint.
    return Pressable(
      onTap: onTap,
      radius: Radii.cardOf(context),
      color: accent ? c.selection : c.surface,
      border: Border.all(color: c.divider),
      padding: EdgeInsets.all(Space.cardPaddingOf(context)),
      child: Material(type: MaterialType.transparency, child: content),
    );
  }
}

/// A card with one focal value: small muted label, the value, then a context
/// line (period, what's included) and an optional trend.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.context,
    this.trend,
    this.onTap,
    this.accent = false,
  });
  final String label;
  final Widget value;
  final String? context;
  final Widget? trend;
  final VoidCallback? onTap;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      onTap: onTap,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelLarge?.copyWith(color: c.secondary)),
          const SizedBox(height: Space.sm),
          value,
          if (this.context != null) ...[
            const SizedBox(height: Space.captionGap),
            Text(
              this.context!,
              style: text.bodySmall?.copyWith(color: c.secondary),
            ),
          ],
          if (trend != null) ...[const SizedBox(height: Space.sm), trend!],
        ],
      ),
    );
  }
}

/// A section title with an optional caption and a trailing action centered on
/// the title. The parent owns the gap below it.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.caption, this.trailing});
  final String title;
  final String? caption;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: text.titleLarge),
              ),
              if (caption != null) ...[
                const SizedBox(height: Space.captionGap),
                Text(
                  caption!,
                  style: text.bodyMedium?.copyWith(
                    color: CraftTheme.of(context).secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: Space.md), trailing!],
      ],
    );
  }
}

/// The top of a page: a `headlineMedium` title, an optional caption below it
/// and actions centered on the title. The parent owns the gap after it
/// (`headerGap`).
class PageHeader extends StatelessWidget {
  const PageHeader(
    this.title, {
    super.key,
    this.caption,
    this.actions = const [],
  });
  final String title;
  final String? caption;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: text.headlineMedium),
              ),
              if (caption != null) ...[
                const SizedBox(height: Space.captionGap),
                Text(
                  caption!,
                  style: text.bodyMedium?.copyWith(
                    color: CraftTheme.of(context).secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        for (final action in actions) ...[
          const SizedBox(width: Space.sm),
          action,
        ],
      ],
    );
  }
}
