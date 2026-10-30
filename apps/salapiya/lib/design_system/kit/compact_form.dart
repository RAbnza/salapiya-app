import 'package:flutter/material.dart';

import '../theme.dart';
import 'focus_ring.dart';

/// The compact form scale (§3): forms a step smaller than the app's base
/// sizes, but easy to read. Typed values are `bodyMedium`, labels 12, spacing
/// tighter. On Android a control looks 40 tall and keeps its 48 hit area: a
/// field stays 48 tall with its border drawn inside, and a button gets
/// transparent space around it. Windows controls stay 32.
///
/// A scope, not an app-wide theme change, so each form adopts it when it is
/// redesigned. Kit fields read it through [on].
class CompactForm extends StatelessWidget {
  const CompactForm({super.key, required this.child});
  final Widget child;

  static bool on(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CompactScope>() != null;

  /// Transparent space around an Android control, part of its hit area.
  static const _band = (Space.target - Space.formControl) / 2;

  /// Label to control and control to helper. On Android the control's own
  /// transparent band makes up the 4 you see.
  static double innerGap(BuildContext context) =>
      isDesktop(context) ? Space.xs : Space.xs - _band;

  /// Between fields and between groups, as you see them.
  static double fieldGap(BuildContext context) =>
      isDesktop(context) ? Space.md : Space.md - _band;
  static double groupGap(BuildContext context) =>
      isDesktop(context) ? Space.lg : Space.lg - _band;

  /// The gap above a field. A field with an ⓘ brings its own: its label row
  /// is one hit target tall.
  static double gapBefore(BuildContext context, {bool info = false}) =>
      info ? 0 : fieldGap(context);

  static ThemeData theme(ThemeData base) {
    final text = base.textTheme;
    final compact = base.copyWith(
      textTheme: text.copyWith(bodyLarge: text.bodyMedium),
    );
    if (Density.isCompact(base.platform)) return compact;
    final input = base.inputDecorationTheme;
    InputBorder? inset(InputBorder? border) =>
        border == null ? null : _InsetBorder(border);
    InputBorder? insetStates(InputBorder? border) => border == null
        ? null
        : WidgetStateInputBorder.resolveWith(
            (states) =>
                _InsetBorder(WidgetStateProperty.resolveAs(border, states)),
          );
    const size = WidgetStatePropertyAll(Size(Space.target, Space.formControl));
    const padding = WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: Space.lg),
    );
    return compact.copyWith(
      inputDecorationTheme: input.copyWith(
        // 48 tall, so the whole of it takes taps; [_InsetBorder] draws 40.
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.md + Space.xxs,
        ),
        border: inset(input.border),
        enabledBorder: insetStates(input.enabledBorder),
        disabledBorder: inset(input.disabledBorder),
        focusedBorder: inset(input.focusedBorder),
        errorBorder: inset(input.errorBorder),
        focusedErrorBorder: inset(input.focusedErrorBorder),
        suffixIconConstraints: const BoxConstraints(
          minWidth: Space.target,
          minHeight: Space.target,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(
          minimumSize: size,
          padding: padding,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: base.outlinedButtonTheme.style?.copyWith(
          minimumSize: size,
          padding: padding,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: base.textButtonTheme.style?.copyWith(
          minimumSize: size,
          padding: padding,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: theme(Theme.of(context)),
    child: _CompactScope(child: child),
  );
}

class _CompactScope extends InheritedWidget {
  const _CompactScope({required super.child});
  @override
  bool updateShouldNotify(_CompactScope oldWidget) => false;
}

/// Draws [border] inside the field's top and bottom, leaving transparent
/// space that still takes taps.
class _InsetBorder extends InputBorder {
  const _InsetBorder(this.border) : super(borderSide: BorderSide.none);
  final InputBorder border;

  Rect _inset(Rect rect) => Rect.fromLTRB(
    rect.left,
    rect.top + CompactForm._band,
    rect.right,
    rect.bottom - CompactForm._band,
  );

  @override
  BorderSide get borderSide => border.borderSide;
  @override
  bool get isOutline => border.isOutline;
  @override
  EdgeInsetsGeometry get dimensions => border.dimensions;
  @override
  InputBorder copyWith({BorderSide? borderSide}) =>
      _InsetBorder(border.copyWith(borderSide: borderSide));
  @override
  ShapeBorder scale(double t) => _InsetBorder(border.scale(t) as InputBorder);
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      border.getInnerPath(_inset(rect), textDirection: textDirection);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      border.getOuterPath(_inset(rect), textDirection: textDirection);
  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) => border.paint(
    canvas,
    _inset(rect),
    gapStart: gapStart,
    gapExtent: gapExtent,
    gapPercentage: gapPercentage,
    textDirection: textDirection,
  );
}

/// "More details": fields most people skip, closed until asked for.
class FormMoreDetails extends StatefulWidget {
  const FormMoreDetails({
    super.key,
    required this.children,
    this.label = 'More details',
    this.open = false,
  });
  final List<Widget> children;
  final String label;

  /// Starts open, e.g. when a field inside has an error.
  final bool open;
  @override
  State<FormMoreDetails> createState() => _FormMoreDetailsState();
}

class _FormMoreDetailsState extends State<FormMoreDetails> {
  late bool open = widget.open;
  @override
  void didUpdateWidget(FormMoreDetails old) {
    super.didUpdateWidget(old);
    if (widget.open && !old.open) open = true;
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          label: widget.label,
          excludeSemantics: true,
          child: Pressable(
            key: const ValueKey('form-more-details'),
            onTap: () => setState(() => open = !open),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: hitTarget(context)),
              child: Row(
                children: [
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: Space.lg,
                    color: c.primary,
                  ),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: c.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (open) ...widget.children,
      ],
    );
  }
}
