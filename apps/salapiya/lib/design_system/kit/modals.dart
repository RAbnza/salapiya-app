import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'buttons.dart';
import 'focus_ring.dart';

/// A modal button. The modal closes with [value] unless [onPressed] returns
/// false (e.g. a short form that fails validation).
class ModalAction<T> {
  const ModalAction(
    this.label, {
    this.value,
    this.destructive = false,
    this.onPressed,
  });
  const ModalAction.cancel({this.label = 'Cancel'})
    : value = null,
      destructive = false,
      onPressed = null;
  final String label;
  final T? value;
  final bool destructive;
  final FutureOr<bool> Function()? onPressed;
}

/// What a modal is for; [showAdaptiveModal] picks the surface from it.
enum ModalPurpose {
  /// A confirmation with at most two actions: a dialog on every platform.
  confirm,

  /// A choice or a short form (about 3 fields): a dialog on Windows, a bottom
  /// sheet on Android. Long forms are pages, not modals.
  choice,
}

enum ModalPresentation { dialog, sheet }

/// Title, a scrolling body and fixed actions. A destructive primary starts
/// with focus on Cancel, so Enter never confirms it by accident.
class ModalScaffold<T> extends StatelessWidget {
  const ModalScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.primary,
    this.secondary = const ModalAction.cancel(),
    this.presentation = ModalPresentation.dialog,
  });
  final String title;
  final Widget body;
  final ModalAction<T> primary;
  final ModalAction<T>? secondary;
  final ModalPresentation presentation;

  Future<void> _press(BuildContext context, ModalAction<T> action) async {
    final close = await action.onPressed?.call() ?? true;
    if (close && context.mounted) Navigator.of(context).pop(action.value);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sheet = presentation == ModalPresentation.sheet;
    final cancelFirst = primary.destructive;
    final primaryButton = AppButton(
      primary.label,
      variant: primary.destructive
          ? AppButtonVariant.destructive
          : AppButtonVariant.primary,
      onPressed: () => _press(context, primary),
      expand: sheet,
    );
    final secondaryButton = secondary == null
        ? null
        : AppButton(
            secondary!.label,
            variant: sheet
                ? AppButtonVariant.secondary
                : AppButtonVariant.tertiary,
            onPressed: () => _press(context, secondary!),
            autofocus: cancelFirst,
            expand: sheet,
          );
    final actions = sheet
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primaryButton,
              if (secondaryButton != null) ...[
                const SizedBox(height: Space.sm),
                secondaryButton,
              ],
            ],
          )
        : OverflowBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            overflowDirection: VerticalDirection.up,
            spacing: Space.sm,
            overflowSpacing: Space.sm,
            children: [?secondaryButton, primaryButton],
          );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.dialogPadding,
        sheet ? 0 : Space.dialogPadding,
        Space.dialogPadding,
        Space.dialogPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: text.headlineSmall),
          ),
          const SizedBox(height: Space.dialogTitleGap),
          Flexible(
            child: SingleChildScrollView(
              child: DefaultTextStyle.merge(
                style: text.bodyMedium,
                child: body,
              ),
            ),
          ),
          const SizedBox(height: Space.actionsGap),
          actions,
        ],
      ),
    );
  }
}

/// Runs [show] and then returns focus to whatever had it before.
Future<T?> restoringFocus<T>(Future<T?> Function() show) async {
  final previous = FocusManager.instance.primaryFocus;
  final result = await show();
  if (previous != null &&
      previous.context != null &&
      previous.canRequestFocus) {
    previous.requestFocus();
  }
  return result;
}

/// A centered, width-bounded dialog. Esc and the scrim close it.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  required Widget body,
  required ModalAction<T> primary,
  ModalAction<T>? secondary = const ModalAction.cancel(),
  double maxWidth = Space.dialogMaxWidth,
}) => restoringFocus(
  () => showDialog<T>(
    context: context,
    animationStyle: Motion.of(context, Motion.medium) == Duration.zero
        ? AnimationStyle.noAnimation
        : null,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(Space.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ModalScaffold<T>(
          title: title,
          body: body,
          primary: primary,
          secondary: secondary,
        ),
      ),
    ),
  ),
);

/// A modal bottom sheet with a drag handle; respects the keyboard.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  required Widget body,
  required ModalAction<T> primary,
  ModalAction<T>? secondary = const ModalAction.cancel(),
}) => restoringFocus(
  () => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: Motion.of(context, Motion.medium) == Duration.zero
        ? AnimationStyle.noAnimation
        : null,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ModalScaffold<T>(
        title: title,
        body: body,
        primary: primary,
        secondary: secondary,
        presentation: ModalPresentation.sheet,
      ),
    ),
  ),
);

/// Picks the surface from [purpose] and the platform (§5 modal rule).
Future<T?> showAdaptiveModal<T>(
  BuildContext context, {
  required String title,
  required Widget body,
  required ModalAction<T> primary,
  ModalAction<T>? secondary = const ModalAction.cancel(),
  ModalPurpose purpose = ModalPurpose.confirm,
}) {
  if (purpose == ModalPurpose.choice && !isDesktop(context)) {
    return showAppSheet<T>(
      context,
      title: title,
      body: body,
      primary: primary,
      secondary: secondary,
    );
  }
  return showAppDialog<T>(
    context,
    title: title,
    body: body,
    primary: primary,
    secondary: secondary,
    maxWidth: purpose == ModalPurpose.choice
        ? Space.formMaxWidth
        : Space.dialogMaxWidth,
  );
}
