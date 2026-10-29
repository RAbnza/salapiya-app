import 'package:flutter/material.dart';

import '../theme.dart';

/// True where input is pointer and keyboard first (Windows, macOS, Linux).
/// Reads the theme's platform so tests and the gallery can switch it.
bool isDesktop(BuildContext context) => switch (Theme.of(context).platform) {
  TargetPlatform.android ||
  TargetPlatform.iOS ||
  TargetPlatform.fuchsia => false,
  _ => true,
};

/// Smallest hit area for this platform: 48 for touch, 40 for pointer-only.
double hitTarget(BuildContext context) =>
    isDesktop(context) ? Space.pointerTarget : Space.target;

/// Keyboard focus outline: 2 px of `focus`, drawn 2 px outside the child.
class FocusRing extends StatelessWidget {
  const FocusRing({
    super.key,
    required this.visible,
    required this.child,
    this.radius = Radii.control,
  });
  final bool visible;
  final double radius;
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: visible
        ? _RingPainter(CraftTheme.of(context).focus, radius)
        : null,
    child: child,
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.color, this.radius);
  final Color color;
  final double radius;
  static const _width = 2.0, _gap = Space.xxs;
  @override
  void paint(Canvas canvas, Size size) {
    const outset = _gap + _width / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).inflate(outset),
        Radius.circular(radius + outset),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _width,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color || old.radius != radius;
}

/// The shared interactive surface for kit components: hover fill on desktop,
/// pressed fill everywhere, a [FocusRing] for keyboard focus, and Enter/Space
/// activation. No ripple.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.radius = Radii.control,
    this.color,
    this.hoverColor,
    this.border,
    this.focusNode,
    this.autofocus = false,
    this.padding = EdgeInsets.zero,
    this.overlay = false,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double radius;

  /// Rest fill; hover and pressed use [hoverColor] (default `subtle`).
  final Color? color, hoverColor;
  final BoxBorder? border;
  final FocusNode? focusNode;
  final bool autofocus;
  final EdgeInsetsGeometry padding;

  /// Paint the hover and pressed fill over the child (for opaque artwork)
  /// instead of behind it.
  final bool overlay;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool hovered = false, focused = false, pressed = false;
  void set(VoidCallback change) => setState(change);
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final enabled = widget.onTap != null;
    final active = enabled && (pressed || (hovered && isDesktop(context)));
    return FocusableActionDetector(
      enabled: enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (v) => set(() => focused = v),
      onShowHoverHighlight: (v) => set(() => hovered = v),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => set(() => pressed = true) : null,
        onTapUp: enabled ? (_) => set(() => pressed = false) : null,
        onTapCancel: enabled ? () => set(() => pressed = false) : null,
        child: FocusRing(
          visible: focused,
          radius: widget.radius,
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.quick),
            curve: Motion.enter,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: active && !widget.overlay
                  ? (widget.hoverColor ?? c.subtle)
                  : widget.color,
              borderRadius: BorderRadius.circular(widget.radius),
              border: widget.border,
            ),
            foregroundDecoration: widget.overlay
                ? BoxDecoration(
                    color: active ? widget.hoverColor ?? c.subtle : null,
                    borderRadius: BorderRadius.circular(widget.radius),
                  )
                : null,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
