import 'package:flutter/material.dart';

import '../theme.dart';

/// What an amount means to the user. Only owed-to-you has its own color;
/// "you owe" stays neutral, with the words beside it (§3).
enum MoneyKind {
  neutral(null),
  spent('spent'),
  owed('you owe'),
  owedToYou('owed to you');

  const MoneyKind(this.spoken);
  final String? spoken;
}

/// `tile` is the compact dashboard value (Overview KPI tiles and charts).
enum MoneySize { row, tile, card, focal }

/// Shows an amount the app has already formatted (`session.amount(value)`,
/// which also returns "Amount hidden" when amounts are hidden). It never
/// formats or calculates. A null [text] reads "Not available yet", never ₱0.00.
class MoneyAmount extends StatelessWidget {
  const MoneyAmount(
    this.text, {
    super.key,
    this.kind = MoneyKind.neutral,
    this.size = MoneySize.row,
    this.caption,
    this.textAlign = TextAlign.end,
  });
  final String? text;
  final MoneyKind kind;
  final MoneySize size;

  /// A short visible meaning, e.g. "Owed to you", so color isn't the only cue.
  final String? caption;
  final TextAlign textAlign;

  static const unknown = 'Not available yet';

  String get _spoken {
    final value = (text ?? unknown)
        .replaceAll('₱', 'Philippine pesos ')
        .replaceAll('−', 'minus ');
    return kind.spoken == null ? value : '$value, ${kind.spoken}';
  }

  /// Largest style first; focal and card amounts step down to fit the width.
  static List<TextStyle> _ladder(TextTheme t, MoneySize size) => [
    ?switch (size) {
      MoneySize.focal => t.displayMedium,
      MoneySize.card => t.displaySmall,
      MoneySize.tile => t.headlineMedium,
      MoneySize.row => t.titleSmall,
    },
    if (size == MoneySize.focal) ?t.displaySmall,
    if (size == MoneySize.focal || size == MoneySize.card) ?t.headlineMedium,
    if (size != MoneySize.row) ?t.headlineSmall,
    if (size == MoneySize.tile) ?t.titleMedium,
  ];

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final theme = Theme.of(context).textTheme;
    final known = text != null;
    final color = !known
        ? c.secondary
        : kind == MoneyKind.owedToYou
        ? c.owedToYou.$1
        : c.text;
    final ladder = [
      for (final s in _ladder(theme, size))
        s.copyWith(
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
    ];
    final align = textAlign == TextAlign.end
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final Widget value = !known
        ? Text(
            unknown,
            textAlign: textAlign,
            style:
                (size == MoneySize.row ? theme.bodyMedium : theme.titleMedium)
                    ?.copyWith(color: color),
          )
        : ladder.length == 1
        ? Text(
            text!,
            softWrap: false,
            textAlign: textAlign,
            style: ladder.first,
          )
        : LayoutBuilder(
            builder: (context, box) {
              var style = ladder.first;
              var fits = true;
              if (box.hasBoundedWidth) {
                for (final candidate in ladder) {
                  style = candidate;
                  final measure = TextPainter(
                    text: TextSpan(text: text, style: style),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                    maxLines: 1,
                  )..layout();
                  fits = measure.width <= box.maxWidth;
                  measure.dispose();
                  if (fits) break;
                }
              }
              final line = Text(
                text!,
                softWrap: false,
                textAlign: textAlign,
                style: style,
              );
              return fits
                  ? line
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: line,
                    );
            },
          );
    return Semantics(
      label: _spoken,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: align,
        mainAxisSize: MainAxisSize.min,
        children: [
          value,
          if (caption != null)
            Text(
              caption!,
              textAlign: textAlign,
              style: theme.bodySmall?.copyWith(color: c.secondary),
            ),
        ],
      ),
    );
  }
}
