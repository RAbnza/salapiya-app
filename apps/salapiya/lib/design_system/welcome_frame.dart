import 'package:flutter/material.dart';

import 'kit/kit.dart';
import 'theme.dart';

/// The frame around the first-run steps. Returning profiles bypass it, with
/// no timers or intro routes.
///
/// [aside] sits beside [child] when there's room, at the same height. Where
/// there isn't, and always on Android, [lead] comes first and [stacked] (or
/// [child]) follows in one column.
class WelcomeFrame extends StatelessWidget {
  const WelcomeFrame({
    super.key,
    required this.child,
    this.title,
    this.caption,
    this.step,
    this.back = true,
    this.aside,
    this.lead,
    this.stacked,
  });
  final Widget child;
  final String? title, caption, step;
  final bool back;
  final Widget? aside, lead;
  final List<Widget>? stacked;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final width = WidthClass.of(context);
    final gutter = Space.pageGutter(width);
    final desktop = isDesktop(context);
    final aside = this.aside;
    final heading = [
      Row(
        children: [
          if (back) ...[const BackButton(), const SizedBox(width: Space.xs)],
          Flexible(
            child: Image.asset(
              'assets/branding/display/salapiya_horizontal_on_${c.dark ? 'dark' : 'light'}.png',
              height: Space.xxl,
              alignment: Alignment.centerLeft,
              semanticLabel: 'Salapiya',
            ),
          ),
        ],
      ),
      const SizedBox(height: Space.xl),
      if (step != null) ...[
        Text(step!, style: text.bodySmall?.copyWith(color: c.secondary)),
        const SizedBox(height: Space.captionGap),
      ],
      if (title != null)
        Semantics(
          header: true,
          child: Text(title!, style: text.headlineMedium),
        ),
      if (caption != null) ...[
        const SizedBox(height: Space.captionGap),
        Text(caption!, style: text.bodyMedium?.copyWith(color: c.secondary)),
      ],
      const SizedBox(height: Space.xl),
    ];
    return RouteEscape(
      child: Scaffold(
        backgroundColor: c.canvas,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: gutter,
                vertical: Space.pageTop(width),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: desktop
                      ? box.maxHeight - Space.pageTop(width) * 2
                      : 0,
                ),
                child: Align(
                  alignment: desktop ? Alignment.center : Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: aside == null
                          ? Space.formMaxWidth
                          : DashboardGrid.four,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...heading,
                        DashboardGrid(
                          cards: desktop && aside != null
                              ? [(child, 7, 7), (aside, 5, 5)]
                              : null,
                          stacked: [
                            ?lead,
                            ...stacked ?? [child],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
