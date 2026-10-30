import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'focus_ring.dart';

/// Escape uses the current Navigator route so dialogs keep dismissal priority.
class RouteEscape extends StatelessWidget {
  const RouteEscape({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.of(context).maybePop(),
      const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () =>
          Navigator.of(context).maybePop(),
    },
    child: Focus(autofocus: true, child: child),
  );
}

/// A page opened from a section (§2 Section screen standard). On Windows the
/// title bar and breadcrumb carry the way back, so it starts with the title.
/// On Android the app bar hides on pages, so it starts with a 48-tall back
/// row. [status] sits beside the title and [actions] end the heading.
class SectionPage extends StatelessWidget {
  const SectionPage({
    super.key,
    required this.title,
    required this.child,
    this.caption,
    this.status,
    this.actions = const [],
    this.maxWidth = Space.contentMaxWidth,
  });
  final String title;
  final String? caption;
  final Widget? status;
  final List<Widget> actions;
  final Widget child;

  /// The page's column. A form passes its own width, so its title lines up
  /// with the form instead of the far edge of the window.
  final double maxWidth;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final width = WidthClass.of(context);
    final android = !isDesktop(context);
    final gutter = Space.pageGutter(width);
    final info = [
      if (!android)
        Semantics(
          header: true,
          child: Text(title, style: text.headlineMedium),
        ),
      if (caption != null)
        Text(
          caption!,
          style: text.bodyMedium?.copyWith(color: c.secondary),
        ),
      ?status,
    ];
    final heading = Wrap(
      spacing: Space.lg,
      runSpacing: Space.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        if (info.isNotEmpty)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, line) in info.indexed) ...[
                if (i > 0) const SizedBox(height: Space.captionGap),
                line,
              ],
            ],
          ),
        if (actions.isNotEmpty)
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
      ],
    );
    return RouteEscape(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (android)
                Row(
                  children: [
                    const BackButton(),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title, style: text.titleMedium),
                      ),
                    ),
                  ],
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    android ? Space.xs : Space.pageTop(width),
                    gutter,
                    Space.pageBottom(width),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (info.isNotEmpty || actions.isNotEmpty) ...[
                            heading,
                            SizedBox(height: Space.cardGapOf(context)),
                          ],
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
