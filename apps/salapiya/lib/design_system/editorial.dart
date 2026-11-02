import 'package:flutter/material.dart';

import 'theme.dart';

/// Flat editorial surfaces share spacing and color without framing every section.
class EditorialSurface extends StatelessWidget {
  const EditorialSurface({
    super.key,
    required this.child,
    this.color,
    this.padding = 20,
  });
  final Widget child;
  final Color? color;
  final double padding;
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? CraftTheme.of(context).surface,
    borderRadius: BorderRadius.circular(10),
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
      color: color ?? CraftTheme.of(context).secondary,
    ),
  );
}
