import 'package:flutter/material.dart';

import '../theme.dart';
import 'buttons.dart';

/// Nothing to show yet: what this place holds and the one next step.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Space.xxl, color: c.secondary),
          const SizedBox(height: Space.md),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: Space.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: c.secondary),
          ),
          if (action != null) ...[const SizedBox(height: Space.lg), action!],
        ],
      ),
    );
  }
}

enum _SkeletonShape { lines, row, card }

/// Static placeholder blocks while content loads. No shimmer or animation
/// (§1.10); screen readers hear "Loading ‹what›".
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton.lines({super.key, required this.label, this.lines = 3})
    : _shape = _SkeletonShape.lines;
  const LoadingSkeleton.row({super.key, required this.label})
    : _shape = _SkeletonShape.row,
      lines = 2;
  const LoadingSkeleton.card({super.key, required this.label})
    : _shape = _SkeletonShape.card,
      lines = 0;

  /// What is loading, e.g. "accounts".
  final String label;
  final int lines;
  final _SkeletonShape _shape;

  static Widget _bar(BuildContext context, double height, double fraction) =>
      FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: fraction,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: CraftTheme.of(context).subtle,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final body = switch (_shape) {
      _SkeletonShape.lines => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < lines; i++) ...[
            if (i > 0) const SizedBox(height: Space.sm),
            _bar(context, Space.md, i == lines - 1 && lines > 1 ? .6 : 1),
          ],
        ],
      ),
      _SkeletonShape.row => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        child: Row(
          children: [
            Container(
              width: Space.xl,
              height: Space.xl,
              decoration: BoxDecoration(
                color: c.subtle,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _bar(context, Space.md, .7),
                  const SizedBox(height: Space.sm),
                  _bar(context, Space.sm + Space.xxs, .4),
                ],
              ),
            ),
            const SizedBox(width: Space.lg),
            SizedBox(
              width: Space.xxxl + Space.xl,
              child: _bar(context, Space.md, 1),
            ),
          ],
        ),
      ),
      _SkeletonShape.card => Container(
        padding: EdgeInsets.all(Space.cardPaddingOf(context)),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.cardOf(context)),
          border: Border.all(color: c.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bar(context, Space.md, .4),
            const SizedBox(height: Space.md),
            _bar(context, Space.xxl, .7),
            const SizedBox(height: Space.md),
            _bar(context, Space.md, .5),
          ],
        ),
      ),
    };
    return Semantics(
      label: 'Loading $label',
      liveRegion: true,
      child: ExcludeSemantics(child: body),
    );
  }
}

/// Something failed to load. States the fact calmly, offers "Try again", and
/// keeps technical detail behind a disclosure.
class ErrorState extends StatefulWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.details,
  });
  final String title, message, retryLabel;
  final VoidCallback? onRetry;
  final String? details;
  @override
  State<ErrorState> createState() => _ErrorStateState();
}

class _ErrorStateState extends State<ErrorState> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final (ink, _) = c.tone(NoticeTone.error);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: Space.xxl, color: ink),
            const SizedBox(height: Space.md),
            Text(
              widget.title,
              style: text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.xs),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: c.secondary),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: Space.lg),
              AppButton.secondary(
                widget.retryLabel,
                icon: Icons.refresh,
                onPressed: widget.onRetry,
              ),
            ],
            if (widget.details != null) ...[
              const SizedBox(height: Space.sm),
              AppButton.tertiary(
                open ? 'Hide details' : 'Show details',
                icon: open ? Icons.expand_less : Icons.expand_more,
                onPressed: () => setState(() => open = !open),
              ),
              if (open)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Space.md),
                  decoration: BoxDecoration(
                    color: c.subtle,
                    borderRadius: BorderRadius.circular(
                      Radii.controlOf(context),
                    ),
                  ),
                  child: SelectableText(
                    widget.details!,
                    style: text.bodySmall?.copyWith(color: c.text),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
