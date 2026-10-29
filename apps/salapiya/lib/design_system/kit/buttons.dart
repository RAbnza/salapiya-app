import 'package:flutter/material.dart';

import '../theme.dart';

enum AppButtonVariant { primary, secondary, tertiary, destructive }

/// A labelled action. The label starts with a verb and names the result.
///
/// Busy shows a spinner in the icon slot and disables the button; give a
/// button that can be busy an [icon] so its width doesn't change.
/// [disabledReason] explains a disabled button (tooltip and screen reader).
class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.busy = false,
    this.disabledReason,
    this.expand = false,
    this.autofocus = false,
    this.focusNode,
  });
  const AppButton.secondary(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.disabledReason,
    this.expand = false,
    this.autofocus = false,
    this.focusNode,
  }) : variant = AppButtonVariant.secondary;
  const AppButton.tertiary(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.disabledReason,
    this.expand = false,
    this.autofocus = false,
    this.focusNode,
  }) : variant = AppButtonVariant.tertiary;
  const AppButton.destructive(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.disabledReason,
    this.expand = false,
    this.autofocus = false,
    this.focusNode,
  }) : variant = AppButtonVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool busy, expand, autofocus;
  final String? disabledReason;
  final FocusNode? focusNode;

  static ButtonStyle destructiveStyle(BuildContext context) {
    final c = CraftTheme.of(context);
    final (error, _) = c.tone(NoticeTone.error);
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? c.subtle : error,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? c.secondary : c.surface,
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.pressed)
            ? c.surface.withValues(alpha: .16)
            : s.contains(WidgetState.hovered)
            ? c.surface.withValues(alpha: .10)
            : null,
      ),
      side: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.focused)
            ? BorderSide(color: c.surface, width: 2)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final action = enabled ? onPressed : null;
    final iconWidget = busy
        ? SizedBox.square(
            dimension: Space.lg,
            child: CircularProgressIndicator(
              strokeWidth: Space.xxs,
              color: CraftTheme.of(context).secondary,
            ),
          )
        : icon == null
        ? null
        : Icon(icon);
    final text = Text(label);
    Widget button = switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.destructive =>
        iconWidget == null
            ? FilledButton(
                onPressed: action,
                autofocus: autofocus,
                focusNode: focusNode,
                style: variant == AppButtonVariant.destructive
                    ? destructiveStyle(context)
                    : null,
                child: text,
              )
            : FilledButton.icon(
                onPressed: action,
                autofocus: autofocus,
                focusNode: focusNode,
                style: variant == AppButtonVariant.destructive
                    ? destructiveStyle(context)
                    : null,
                icon: iconWidget,
                label: text,
              ),
      AppButtonVariant.secondary =>
        iconWidget == null
            ? OutlinedButton(
                onPressed: action,
                autofocus: autofocus,
                focusNode: focusNode,
                child: text,
              )
            : OutlinedButton.icon(
                onPressed: action,
                autofocus: autofocus,
                focusNode: focusNode,
                icon: iconWidget,
                label: text,
              ),
      AppButtonVariant.tertiary =>
        iconWidget == null
            ? TextButton(
                onPressed: action,
                autofocus: autofocus,
                focusNode: focusNode,
                child: text,
              )
            : TextButton.icon(
                onPressed: action,
                autofocus: autofocus,
                focusNode: focusNode,
                icon: iconWidget,
                label: text,
              ),
    };
    if (expand) button = SizedBox(width: double.infinity, child: button);
    final reason = busy
        ? 'Working'
        : onPressed == null
        ? disabledReason
        : null;
    if (reason == null) return button;
    return Semantics(
      hint: reason,
      child: onPressed == null && !busy
          ? Tooltip(message: reason, child: button)
          : button,
    );
  }
}

enum AppIconButtonVariant { standard, filled, outlined }

/// An icon-only action. [tooltip] is required: it is the visible hover label
/// and the screen-reader name.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = AppIconButtonVariant.standard,
    this.focusNode,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final AppIconButtonVariant variant;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) => switch (variant) {
    AppIconButtonVariant.standard => IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      focusNode: focusNode,
    ),
    // The theme's primary foreground would vanish on the primary fill.
    AppIconButtonVariant.filled => IconButton.filled(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      focusNode: focusNode,
      style: IconButton.styleFrom(
        foregroundColor: CraftTheme.of(context).onPrimary,
        backgroundColor: CraftTheme.of(context).primary,
        disabledBackgroundColor: CraftTheme.of(context).subtle,
        disabledForegroundColor: CraftTheme.of(context).secondary,
      ),
    ),
    AppIconButtonVariant.outlined => IconButton.outlined(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      focusNode: focusNode,
    ),
  };
}
