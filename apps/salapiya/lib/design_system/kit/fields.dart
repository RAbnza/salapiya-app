import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'buttons.dart';
import 'calculator.dart';
import 'compact_form.dart';
import 'focus_ring.dart';
import 'modals.dart';
import 'rows.dart';

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
    final compact = CompactForm.on(context);
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
                      child: Align(
                        alignment: compact
                            ? Alignment.bottomCenter
                            : Alignment.center,
                        child: Icon(
                          Icons.info_outline,
                          size: compact || isDesktop(context)
                              ? Space.compactControlIcon
                              : Space.lg + Space.xs,
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
          popover ? Radii.overlayOf(context) : Radii.controlOf(context),
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
    final compact = CompactForm.on(context);
    final labelStyle = compact ? text.labelMedium! : text.labelLarge!;
    final line = MediaQuery.textScalerOf(context)
        .scale(labelStyle.fontSize! * labelStyle.height!);
    // Every label row is one hit target tall so fields with and without an
    // info control keep the same rhythm; the gap absorbs the extra height.
    // A compact form only makes room for the ⓘ where there is one, and the
    // form leaves out the field gap above it (`CompactForm.gapBefore`).
    final target = compact && info == null ? line : hitTarget(context);
    final row = line > target ? line : target;
    final gap = compact
        ? CompactForm.innerGap(context)
        : (Space.labelGap - (row - line) / 2).clamp(0.0, Space.labelGap);
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
            crossAxisAlignment: compact
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.center,
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
          SizedBox(height: compact ? gap : Space.helperGap),
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

/// What a typed field accepts (§6). Anything else is refused as it's typed,
/// and [InputGuard] says why in a small note at the field.
enum FieldInput {
  amount(r'^\d*(\.\d{0,2})?$', money: true),
  signedAmount(r'^-?\d*(\.\d{0,2})?$', money: true),
  wholeNumber(r'^\d*$'),
  rating(r'^\d?(\.\d{0,4})?$'),
  numberList(r'^[\d,\s]*$'),
  date(r'^\d{0,4}(-\d{0,2}(-\d{0,2})?)?$');

  const FieldInput(this.pattern, {this.money = false});
  final String pattern;
  final bool money;

  bool accepts(String text) => RegExp(pattern).hasMatch(text);

  /// Pasted amounts often come with a ₱, commas or spaces.
  String clean(String text) =>
      money ? text.replaceAll(RegExp(r'[₱,\s]'), '') : text;

  /// Why [text] was refused, in a few plain words.
  String reason(String text) => switch (this) {
    FieldInput.wholeNumber => 'Whole numbers only.',
    FieldInput.rating => 'A number from 0 to 5, like 4.5.',
    FieldInput.numberList => 'Numbers and commas only.',
    FieldInput.date => 'Dates only, like 2026-10-30.',
    FieldInput.amount when text.contains('-') =>
      'This amount can’t be negative.',
    _ when RegExp(r'[^\d.\-]').hasMatch(text) => 'Numbers only, like 1500.00.',
    _ when '.'.allMatches(text).length > 1 => 'Only one decimal point.',
    _ when text.contains('.') => 'Up to two decimals.',
    _ => 'Numbers only, like 1500.00.',
  };
}

class _GuardFormatter extends TextInputFormatter {
  _GuardFormatter(this.input, this.onRefused, this.onAccepted);
  final FieldInput input;
  final ValueChanged<String> onRefused;
  final VoidCallback onAccepted;
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = input.clean(newValue.text);
    if (!input.accepts(text)) {
      onRefused(input.reason(text));
      return oldValue;
    }
    onAccepted();
    return text == newValue.text
        ? newValue
        : TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
  }
}

/// Keeps a field to one kind of input ([FieldInput]). [builder] gets the
/// formatter for its `TextField`. A refused keystroke shows a small note at
/// the field for a few seconds; the field never takes the keystroke, so
/// there's nothing to correct later.
class InputGuard extends StatefulWidget {
  const InputGuard({super.key, required this.input, required this.builder});
  final FieldInput input;
  final Widget Function(BuildContext context, TextInputFormatter guard) builder;
  @override
  State<InputGuard> createState() => _InputGuardState();
}

class _InputGuardState extends State<InputGuard> {
  final portal = OverlayPortalController();
  final link = LayerLink();
  late final guard = _GuardFormatter(widget.input, refused, accepted);
  String? note;
  Timer? timer;

  void refused(String reason) {
    timer?.cancel();
    timer = Timer(Motion.note, accepted);
    setState(() => note = reason);
    portal.show();
  }

  void accepted() {
    timer?.cancel();
    if (note == null || !mounted) return;
    setState(() => note = null);
    portal.hide();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Widget bubble(BuildContext context) {
    final c = CraftTheme.of(context);
    final (ink, fill) = c.tone(NoticeTone.error);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final target = this.context.findRenderObject() as RenderBox;
    final top = target.localToGlobal(Offset.zero, ancestor: overlay).dy;
    final usable =
        overlay.size.height - MediaQuery.viewInsetsOf(context).bottom;
    // Above the field in the lower part of the screen, clear of the keyboard.
    final above = top + target.size.height > usable * .6;
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: CompositedTransformFollower(
        link: link,
        showWhenUnlinked: false,
        targetAnchor: above ? Alignment.topLeft : Alignment.bottomLeft,
        followerAnchor: above ? Alignment.bottomLeft : Alignment.topLeft,
        offset: Offset(Space.md, above ? -Space.xs : Space.xs),
        child: IgnorePointer(
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Container(
              key: const ValueKey('field-note'),
              constraints: const BoxConstraints(
                maxWidth: Space.popoverMaxWidth,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: Space.sm,
                vertical: Space.xs,
              ),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(Radii.controlOf(context)),
                border: Border.all(color: ink),
                boxShadow: c.overlayShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: Space.lg, color: ink),
                  const SizedBox(width: Space.xs),
                  Flexible(
                    child: Text(
                      note ?? '',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: link,
    child: OverlayPortal(
      controller: portal,
      overlayChildBuilder: bubble,
      child: widget.builder(context, guard),
    ),
  );
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
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.input,
    this.secret = false,
    this.obscured = false,
  });
  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? helper, info, errorText, hintText, disabledReason;
  final bool required, enabled, readOnly, amount;

  /// Recovery material: no suggestions, autocorrect or keyboard learning.
  final bool secret;

  /// Masks the text. Takes one line.
  final bool obscured;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final ValueChanged<String>? onChanged, onSubmitted;

  /// A small control at the field's end, e.g. the calculator button.
  final Widget? suffix;

  /// What the field accepts; `amount: true` defaults to [FieldInput.amount].
  final FieldInput? input;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final input_ = Theme.of(context).inputDecorationTheme;
    final style = Theme.of(context).textTheme.bodyLarge!;
    final readOnlyBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.controlOf(context)),
      borderSide: BorderSide(color: c.divider),
    );
    final guarded = input ?? (amount ? FieldInput.amount : null);
    Widget field(TextInputFormatter? guard) => TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      obscureText: obscured,
      enableSuggestions: !secret,
      autocorrect: !secret,
      enableIMEPersonalizedLearning: !secret,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: guard == null ? null : [guard],
      keyboardType:
          keyboardType ??
          switch (guarded) {
            FieldInput.amount ||
            FieldInput.rating => const TextInputType.numberWithOptions(
              decimal: true,
            ),
            FieldInput.signedAmount => const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            FieldInput.wholeNumber => TextInputType.number,
            _ => null,
          },
      style: amount
          ? style.copyWith(fontFeatures: const [FontFeature.tabularFigures()])
          : style,
      decoration: InputDecoration(
        hintText: hintText,
        prefixText: amount ? '₱ ' : null,
        suffixIcon: suffix,
        fillColor: readOnly ? c.subtle : null,
        // The error text sits in HelpField; only the border changes here.
        enabledBorder: errorText != null
            ? input_.errorBorder
            : readOnly
            ? readOnlyBorder
            : null,
        focusedBorder: errorText != null ? input_.focusedErrorBorder : null,
      ),
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
        child: guarded == null
            ? field(null)
            : InputGuard(input: guarded, builder: (_, guard) => field(guard)),
      ),
    );
  }
}

/// A money field with the calculator at its end (§2 Android parity). "Use
/// result" fills the field; a result rounded to centavos says so.
class AmountField extends StatefulWidget {
  const AmountField({
    super.key,
    required this.label,
    required this.controller,
    this.helper,
    this.info,
    this.errorText,
    this.required = false,
    this.signed = false,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final String? helper, info, errorText;
  final bool required;

  /// Takes a minus sign, for the few amounts that can go below zero.
  final bool signed;
  final ValueChanged<String>? onChanged;

  static const roundedNote = 'Rounded to centavos from the calculator.';

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  final menu = MenuController();
  bool rounded = false;

  void use(String value, bool wasRounded) {
    widget.controller.text = value;
    setState(() => rounded = wasRounded);
    widget.onChanged?.call(value);
  }

  Future<void> openSheet() async {
    await showAppSheet<void>(
      context,
      title: 'Calculator',
      body: Builder(
        builder: (sheet) => CalculatorPanel(
          onUse: (value, wasRounded) {
            use(value, wasRounded);
            Navigator.of(sheet).pop();
          },
        ),
      ),
      primary: null,
      secondary: const ModalAction.cancel(label: 'Close'),
    );
  }

  @override
  Widget build(BuildContext context) => HelpTextField(
    label: widget.label,
    amount: true,
    input: widget.signed ? FieldInput.signedAmount : FieldInput.amount,
    controller: widget.controller,
    required: widget.required,
    info: widget.info,
    errorText: widget.errorText,
    helper: rounded ? AmountField.roundedNote : widget.helper,
    onChanged: (value) {
      if (rounded) setState(() => rounded = false);
      widget.onChanged?.call(value);
    },
    suffix: isDesktop(context)
        ? MenuAnchor(
            controller: menu,
            alignmentOffset: const Offset(0, Space.xs),
            menuChildren: [
              CalculatorPanel(
                onUse: (value, wasRounded) {
                  use(value, wasRounded);
                  menu.close();
                },
              ),
            ],
            builder: (context, controller, _) => AppIconButton(
              key: ValueKey('calculator-${widget.label}'),
              icon: Icons.calculate_outlined,
              tooltip: 'Calculator',
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
          )
        : AppIconButton(
            key: ValueKey('calculator-${widget.label}'),
            icon: Icons.calculate_outlined,
            tooltip: 'Calculator',
            onPressed: openSheet,
          ),
  );
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
  static String monthName(int month) => _months[month - 1];
  static String format(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  bool open = false;

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
    final value = widget.value;
    return _PickField(
      label: widget.label,
      helper: widget.helper,
      info: widget.info,
      errorText: widget.errorText,
      disabledReason: widget.disabledReason,
      required: widget.required,
      enabled: widget.onChanged != null,
      open: open,
      shown: value == null ? null : DateField.format(value),
      hintText: widget.hintText,
      icon: Icons.calendar_today_outlined,
      focusNode: widget.focusNode,
      onPick: pick,
      onClear: !widget.required && value != null
          ? () => widget.onChanged!(null)
          : null,
    );
  }
}

/// What [DateField], [TimeField] and [SearchPickerField] share: it looks like
/// a text field, and pressing it opens a picker.
class _PickField extends StatefulWidget {
  const _PickField({
    required this.label,
    required this.shown,
    required this.hintText,
    required this.icon,
    required this.onPick,
    required this.enabled,
    required this.open,
    this.helper,
    this.info,
    this.errorText,
    this.disabledReason,
    this.required = false,
    this.focusNode,
    this.onClear,
  });
  final String label, hintText;
  final String? shown, helper, info, errorText, disabledReason;
  final IconData icon;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  final bool enabled, open, required;
  final FocusNode? focusNode;
  @override
  State<_PickField> createState() => _PickFieldState();
}

class _PickFieldState extends State<_PickField> {
  bool hovered = false, focused = false;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final input = Theme.of(context).inputDecorationTheme;
    final enabled = widget.enabled;
    final shown = widget.shown;
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
                widget.onPick();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? widget.onPick : null,
            child: InputDecorator(
              isFocused: focused || widget.open,
              isHovering: hovered,
              decoration: InputDecoration(
                enabled: enabled,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onClear != null && enabled)
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear ${widget.label}',
                        color: c.secondary,
                        onPressed: widget.onClear,
                      ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: Space.md),
                      child: Icon(
                        widget.icon,
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

/// A time chosen with the system's picker, never typed. It shows the time as
/// the device writes it, and hands back a `TimeOfDay`.
class TimeField extends StatefulWidget {
  const TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.info,
    this.errorText,
    this.hintText = 'Choose a time',
    this.required = false,
    this.disabledReason,
    this.focusNode,
  });
  final String label;
  final TimeOfDay? value;

  /// Null disables the field; give a [disabledReason].
  final ValueChanged<TimeOfDay>? onChanged;
  final String? helper, info, errorText, disabledReason;
  final String hintText;
  final bool required;
  final FocusNode? focusNode;

  /// The time as this device writes it, following its 12/24-hour setting.
  static String format(BuildContext context, TimeOfDay time) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        time,
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  @override
  State<TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<TimeField> {
  bool open = false;

  Future<void> pick() async {
    setState(() => open = true);
    final picked = await restoringFocus(
      () => showTimePicker(
        context: context,
        initialTime: widget.value ?? const TimeOfDay(hour: 9, minute: 0),
        helpText: widget.label,
        confirmText: 'Choose time',
        cancelText: 'Cancel',
      ),
    );
    if (!mounted) return;
    setState(() => open = false);
    if (picked != null) widget.onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    return _PickField(
      label: widget.label,
      helper: widget.helper,
      info: widget.info,
      errorText: widget.errorText,
      disabledReason: widget.disabledReason,
      required: widget.required,
      enabled: widget.onChanged != null,
      open: open,
      shown: value == null ? null : TimeField.format(context, value),
      hintText: widget.hintText,
      icon: Icons.schedule,
      focusNode: widget.focusNode,
      onPick: pick,
    );
  }
}

/// A choice from a list too long to scroll: it opens a list with a search box,
/// a dialog on Windows and a sheet on Android. Options show plain names, never
/// ids.
class SearchPickerField extends StatefulWidget {
  const SearchPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.helper,
    this.info,
    this.errorText,
    this.hintText = 'Choose one',
    this.searchLabel = 'Search',
    this.required = false,
  });
  final String label, hintText, searchLabel;
  final String? value, helper, info, errorText;

  /// Value and name.
  final List<(String, String)> options;
  final ValueChanged<String>? onChanged;
  final bool required;
  @override
  State<SearchPickerField> createState() => _SearchPickerFieldState();
}

class _SearchPickerFieldState extends State<SearchPickerField> {
  bool open = false;

  Future<void> pick() async {
    setState(() => open = true);
    final picked = await showAdaptiveModal<String>(
      context,
      title: widget.label,
      purpose: ModalPurpose.choice,
      primary: null,
      body: _SearchList(
        options: widget.options,
        label: widget.searchLabel,
        selected: widget.value,
      ),
    );
    if (!mounted) return;
    setState(() => open = false);
    if (picked != null) widget.onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.options
        .where((o) => o.$1 == widget.value)
        .firstOrNull
        ?.$2;
    return _PickField(
      label: widget.label,
      helper: widget.helper,
      info: widget.info,
      errorText: widget.errorText,
      required: widget.required,
      enabled: widget.onChanged != null,
      open: open,
      shown: shown ?? widget.value,
      hintText: widget.hintText,
      icon: Icons.unfold_more,
      onPick: pick,
    );
  }
}

class _SearchList extends StatefulWidget {
  const _SearchList({
    required this.options,
    required this.label,
    required this.selected,
  });
  final List<(String, String)> options;
  final String label;
  final String? selected;
  @override
  State<_SearchList> createState() => _SearchListState();
}

class _SearchListState extends State<_SearchList> {
  String words = '';
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final found = [
      for (final o in widget.options)
        if (o.$2.toLowerCase().contains(words)) o,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const ValueKey('search-picker-words'),
          autofocus: isDesktop(context),
          decoration: InputDecoration(
            hintText: widget.label,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => words = v.trim().toLowerCase()),
        ),
        const SizedBox(height: Space.sm),
        SizedBox(
          height: Space.xxxl * 6,
          child: found.isEmpty
              ? Center(
                  child: Text(
                    'Nothing matches',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: c.secondary),
                  ),
                )
              : ListView.builder(
                  itemCount: found.length,
                  itemBuilder: (context, i) {
                    final (value, name) = found[i];
                    return ListRow(
                      key: ValueKey('search-picker-$value'),
                      title: name,
                      trailing: value == widget.selected
                          ? Icon(Icons.check, color: c.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(value),
                    );
                  },
                ),
        ),
      ],
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
          borderRadius: BorderRadius.circular(Radii.controlOf(context)),
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
