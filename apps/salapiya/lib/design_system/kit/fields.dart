import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'focus_ring.dart';
import 'modals.dart';

/// The ⓘ control from §6. It says what a field or option *does*.
///
/// Windows: a tooltip on hover or keyboard focus; a click (or Enter) pins it
/// as a popover until Esc, a click outside, or a second click.
/// Android: a tap opens the popover; a tap outside or Back closes it.
class InfoControl extends StatefulWidget {
  const InfoControl({super.key, required this.label, required this.message});

  /// The field label; the control is announced as "About ‹label›".
  final String label;
  final String message;
  @override
  State<InfoControl> createState() => _InfoControlState();
}

class _InfoControlState extends State<InfoControl> {
  final portal = OverlayPortalController();
  final link = LayerLink();
  final focusNode = FocusNode(debugLabel: 'InfoControl');
  bool hovered = false, focused = false, focusHighlight = false, pinned = false;

  /// Focus came from a click or tap. It is taken only so Esc closes this
  /// popover and not a dialog behind it; it shows no ring and is released
  /// when the popover closes.
  bool byPointer = false;

  /// Set when the user closes it while the pointer or focus is still here,
  /// so hover or focus doesn't reopen it until they leave and come back.
  bool dismissed = false;

  bool showing(bool desktop) =>
      pinned || (desktop && !dismissed && (hovered || (focused && !byPointer)));

  void update(VoidCallback change) {
    if (!mounted) return;
    setState(change);
    final show = showing(isDesktop(context));
    if (show != portal.isShowing) show ? portal.show() : portal.hide();
  }

  void toggle({bool pointer = false}) {
    if (pinned) return close();
    if (pointer && !focused) byPointer = true;
    focusNode.requestFocus();
    update(() {
      dismissed = false;
      pinned = true;
    });
  }

  void close() {
    update(() {
      pinned = false;
      dismissed = true;
    });
    if (byPointer) focusNode.unfocus();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final size = hitTarget(context);
    return PopScope(
      canPop: !pinned,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: TapRegion(
        groupId: this,
        onTapOutside: (_) {
          if (pinned || portal.isShowing) close();
        },
        child: CompositedTransformTarget(
          link: link,
          child: OverlayPortal(
            controller: portal,
            overlayChildBuilder: _bubble,
            child: Semantics(
              button: true,
              label: 'About ${widget.label}',
              tooltip: widget.message,
              expanded: pinned,
              child: FocusableActionDetector(
                focusNode: focusNode,
                mouseCursor: SystemMouseCursors.click,
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                },
                actions: {
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      toggle();
                      return null;
                    },
                  ),
                  DismissIntent: CallbackAction<DismissIntent>(
                    onInvoke: (_) {
                      close();
                      return null;
                    },
                  ),
                },
                onShowHoverHighlight: (v) => update(() {
                  hovered = v;
                  if (v) dismissed = false;
                }),
                onShowFocusHighlight: (v) => setState(() => focusHighlight = v),
                onFocusChange: (v) => update(() {
                  focused = v;
                  if (!v) {
                    pinned = false;
                    byPointer = false;
                    // Still under the pointer: stay closed until it leaves.
                    if (!hovered) dismissed = false;
                  }
                }),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => toggle(pointer: true),
                  child: FocusRing(
                    // Keyboard focus only; never after a click or tap.
                    visible: focusHighlight && !byPointer,
                    radius: Radii.pill,
                    child: SizedBox.square(
                      dimension: size,
                      child: Icon(
                        Icons.info_outline,
                        size: Space.lg + Space.xs,
                        color: pinned ? c.primary : c.secondary,
                      ),
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

  Widget _bubble(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final popover = pinned || !isDesktop(context);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final target = this.context.findRenderObject() as RenderBox;
    final origin = target.localToGlobal(Offset.zero, ancestor: overlay);
    final media = MediaQuery.of(context);
    final margin = Space.lg;
    final width = (overlay.size.width - margin * 2).clamp(
      0.0,
      Space.popoverMaxWidth,
    );
    // Start under the icon, then keep the bubble inside the overlay.
    final left = (origin.dx - Space.md).clamp(
      margin,
      (overlay.size.width - margin - width).clamp(margin, double.infinity),
    );
    final usable = overlay.size.height - media.viewInsets.bottom;
    final above = origin.dy + target.size.height > usable * .6;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: popover
          ? const EdgeInsets.all(Space.md)
          : const EdgeInsets.symmetric(
              horizontal: Space.sm,
              vertical: Space.xs,
            ),
      decoration: BoxDecoration(
        color: popover ? c.raised : c.text,
        borderRadius: BorderRadius.circular(
          popover ? Radii.overlay : Radii.control,
        ),
        border: popover ? Border.all(color: c.divider) : null,
        boxShadow: popover ? c.overlayShadow : null,
      ),
      child: Text(
        widget.message,
        style: (popover ? text.bodyMedium : text.bodySmall)?.copyWith(
          color: popover ? c.text : c.surface,
        ),
      ),
    );
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: CompositedTransformFollower(
        link: link,
        showWhenUnlinked: false,
        targetAnchor: above ? Alignment.topLeft : Alignment.bottomLeft,
        followerAnchor: above ? Alignment.bottomLeft : Alignment.topLeft,
        offset: Offset(left - origin.dx, above ? -Space.xs : Space.xs),
        child: TapRegion(
          groupId: this,
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              liveRegion: pinned,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Motion.of(context, Motion.short),
                curve: Motion.enter,
                builder: (_, t, child) => Opacity(opacity: t, child: child),
                child: bubble,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Label, required marker, info control, the control itself, and one line of
/// helper or error text (§6). Validation stays with the caller: pass the
/// message in [errorText] and it replaces the helper in place.
class HelpField extends StatelessWidget {
  const HelpField({
    super.key,
    required this.label,
    required this.child,
    this.helper,
    this.info,
    this.errorText,
    this.required = false,
    this.enabled = true,
    this.disabledReason,
  });
  final String label;
  final Widget child;
  final String? helper, info, errorText, disabledReason;
  final bool required, enabled;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final labelStyle = text.labelLarge!;
    final line = MediaQuery.textScalerOf(context)
        .scale(labelStyle.fontSize! * labelStyle.height!);
    // Every label row is one hit target tall so fields with and without an
    // info control keep the same rhythm; the gap absorbs the extra height.
    final row = line > hitTarget(context) ? line : hitTarget(context);
    final gap = (Space.labelGap - (row - line) / 2).clamp(0.0, Space.labelGap);
    final (error, _) = c.tone(NoticeTone.error);
    final message =
        errorText ??
        (!enabled && disabledReason != null ? disabledReason : helper);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: row),
          child: Row(
            children: [
              Flexible(
                child: Semantics(
                  label: required ? '$label, required' : label,
                  child: ExcludeSemantics(
                    child: Text.rich(
                      TextSpan(
                        text: label,
                        children: [
                          if (required)
                            TextSpan(
                              text: ' *',
                              style: TextStyle(color: c.secondary),
                            ),
                        ],
                      ),
                      style: labelStyle.copyWith(
                        color: enabled ? c.text : c.secondary,
                      ),
                    ),
                  ),
                ),
              ),
              if (info != null) InfoControl(label: label, message: info!),
            ],
          ),
        ),
        SizedBox(height: gap),
        child,
        if (message != null) ...[
          const SizedBox(height: Space.helperGap),
          if (errorText != null)
            Semantics(
              container: true,
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: Space.lg, color: error),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      errorText!,
                      style: text.bodySmall?.copyWith(color: error),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(message, style: text.bodySmall?.copyWith(color: c.secondary)),
        ],
      ],
    );
  }
}

/// A text input inside a [HelpField]. `amount: true` adds tabular figures, a
/// ₱ prefix and the decimal keyboard; parsing stays with the caller.
class HelpTextField extends StatelessWidget {
  const HelpTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.helper,
    this.info,
    this.errorText,
    this.hintText,
    this.required = false,
    this.enabled = true,
    this.readOnly = false,
    this.disabledReason,
    this.amount = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
  });
  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? helper, info, errorText, hintText, disabledReason;
  final bool required, enabled, readOnly, amount;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final ValueChanged<String>? onChanged, onSubmitted;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final input = Theme.of(context).inputDecorationTheme;
    final style = Theme.of(context).textTheme.bodyLarge!;
    final readOnlyBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.control),
      borderSide: BorderSide(color: c.divider),
    );
    return HelpField(
      label: label,
      helper: helper,
      info: info,
      errorText: errorText,
      required: required,
      enabled: enabled,
      disabledReason: disabledReason,
      child: Semantics(
        label: label,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          readOnly: readOnly,
          maxLines: maxLines,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          keyboardType:
              keyboardType ??
              (amount
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : null),
          style: amount
              ? style.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                )
              : style,
          decoration: InputDecoration(
            hintText: hintText,
            prefixText: amount ? '₱ ' : null,
            fillColor: readOnly ? c.subtle : null,
            // The error text sits in HelpField; only the border changes here.
            enabledBorder: errorText != null
                ? input.errorBorder
                : readOnly
                ? readOnlyBorder
                : null,
            focusedBorder: errorText != null ? input.focusedErrorBorder : null,
          ),
        ),
      ),
    );
  }
}

/// A date chosen from a calendar, never typed (§6). It shows "29 Oct 2026";
/// the caller converts the [DateTime] to the format its rules store.
/// A field that isn't [required] can be cleared.
class DateField extends StatefulWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.info,
    this.errorText,
    this.hintText = 'Choose a date',
    this.required = false,
    this.disabledReason,
    this.firstDate,
    this.lastDate,
    this.focusNode,
  });
  final String label;
  final DateTime? value;

  /// Null disables the field; give a [disabledReason].
  final ValueChanged<DateTime?>? onChanged;
  final String? helper, info, errorText, disabledReason;
  final String hintText;
  final bool required;

  /// The calendar range; defaults to 2000–2100, as the existing forms use.
  final DateTime? firstDate, lastDate;
  final FocusNode? focusNode;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static String format(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  bool hovered = false, focused = false, open = false;

  Future<void> pick() async {
    final first = widget.firstDate ?? DateTime(2000);
    final last = widget.lastDate ?? DateTime(2100);
    var initial = widget.value ?? DateUtils.dateOnly(DateTime.now());
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    setState(() => open = true);
    final picked = await restoringFocus(
      () => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: last,
        initialEntryMode: DatePickerEntryMode.calendarOnly,
        helpText: widget.label,
        confirmText: 'Choose date',
        cancelText: 'Cancel',
      ),
    );
    if (!mounted) return;
    setState(() => open = false);
    if (picked != null) widget.onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final input = Theme.of(context).inputDecorationTheme;
    final enabled = widget.onChanged != null;
    final value = widget.value;
    final shown = value == null ? null : DateField.format(value);
    return HelpField(
      label: widget.label,
      helper: widget.helper,
      info: widget.info,
      errorText: widget.errorText,
      required: widget.required,
      enabled: enabled,
      disabledReason: widget.disabledReason,
      child: Semantics(
        button: true,
        label: widget.label,
        value: shown ?? widget.hintText,
        child: FocusableActionDetector(
          enabled: enabled,
          focusNode: widget.focusNode,
          mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onShowHoverHighlight: (v) => setState(() => hovered = v),
          onFocusChange: (v) => setState(() => focused = v),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                pick();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? pick : null,
            child: InputDecorator(
              isFocused: focused || open,
              isHovering: hovered,
              decoration: InputDecoration(
                enabled: enabled,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!widget.required && value != null && enabled)
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear ${widget.label}',
                        color: c.secondary,
                        onPressed: () => widget.onChanged!(null),
                      ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: Space.md),
                      child: Icon(
                        Icons.calendar_today_outlined,
                        color: enabled ? c.text : c.secondary,
                      ),
                    ),
                  ],
                ),
                enabledBorder: widget.errorText != null
                    ? input.errorBorder
                    : null,
                focusedBorder: widget.errorText != null
                    ? input.focusedErrorBorder
                    : null,
              ),
              child: Text(
                shown ?? widget.hintText,
                style: text.bodyLarge?.copyWith(
                  color: shown == null || !enabled ? c.secondary : c.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One entry in a [FormErrorSummary].
class FieldError {
  const FieldError(this.label, this.message, {this.focusNode});
  final String label, message;
  final FocusNode? focusNode;
}

/// The summary at the top of a form when two or more fields need changes.
/// Each entry moves focus to its field.
class FormErrorSummary extends StatelessWidget {
  const FormErrorSummary({super.key, required this.errors});
  final List<FieldError> errors;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final (ink, fill) = c.tone(NoticeTone.error);
    final count = errors.length;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.control),
          border: c.highContrast ? Border.all(color: ink) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: ink),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    count == 1
                        ? '1 field needs a change'
                        : '$count fields need changes',
                    style: text.titleSmall?.copyWith(color: ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            for (final e in errors)
              Pressable(
                onTap: e.focusNode == null
                    ? null
                    : () => e.focusNode!.requestFocus(),
                hoverColor: c.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.xs,
                  vertical: Space.xs,
                ),
                child: Text(
                  '${e.label}: ${e.message}',
                  style: text.bodyMedium?.copyWith(
                    color: c.text,
                    decoration: e.focusNode == null
                        ? null
                        : TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
