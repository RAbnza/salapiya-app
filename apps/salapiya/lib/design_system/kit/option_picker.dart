import 'package:flutter/material.dart';

import '../theme.dart';
import 'fields.dart';
import 'focus_ring.dart';

/// One choice. [label] is a short noun phrase; [description] says what the
/// choice does, in one line starting with a verb or "Use when…".
class PickerOption<T> {
  const PickerOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
  });
  final T value;
  final String label;
  final String? description;
  final IconData? icon;
}

enum PickerStyle { auto, segmented, radio, dropdown }

/// Picks one option, with each option's effect visible before choosing.
///
/// Which control (what [PickerStyle.auto] applies):
/// - segmented: 2–4 short options with no descriptions, that only change the
///   view (period filter, list or chart);
/// - radio: up to 5 options that differ in effect; descriptions always show;
/// - dropdown: 6 or more options, or a long list; descriptions show in the
///   open menu and the selected one becomes the helper text.
class OptionPicker<T> extends StatelessWidget {
  const OptionPicker({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.style = PickerStyle.auto,
    this.helper,
    this.info,
    this.errorText,
    this.hintText = 'Choose one',
    this.required = false,
    this.disabledReason,
  });
  final String label;
  final List<PickerOption<T>> options;
  final T? value;

  /// Null disables the picker; give a [disabledReason].
  final ValueChanged<T>? onChanged;
  final PickerStyle style;
  final String? helper, info, errorText, disabledReason;
  final String hintText;
  final bool required;

  static const segmentedMaxOptions = 4, radioMaxOptions = 5;
  static const segmentedMaxLabel = 12;

  static PickerStyle resolve<T>(List<PickerOption<T>> options) {
    final described = options.any((o) => o.description != null);
    if (!described &&
        options.length <= segmentedMaxOptions &&
        options.every((o) => o.label.length <= segmentedMaxLabel)) {
      return PickerStyle.segmented;
    }
    if (described && options.length <= radioMaxOptions) {
      return PickerStyle.radio;
    }
    return PickerStyle.dropdown;
  }

  PickerOption<T>? get selected {
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final effective = style == PickerStyle.auto ? resolve(options) : style;
    assert(
      effective != PickerStyle.segmented ||
          options.every((o) => o.description == null),
      'Options that differ in effect use a radio list or a dropdown.',
    );
    final enabled = onChanged != null;
    final control = switch (effective) {
      PickerStyle.radio => _RadioList<T>(picker: this),
      PickerStyle.dropdown => _Dropdown<T>(picker: this),
      _ => _Segmented<T>(picker: this),
    };
    return HelpField(
      label: label,
      info: info,
      required: required,
      enabled: enabled,
      disabledReason: disabledReason,
      errorText: errorText,
      helper: effective == PickerStyle.dropdown
          ? selected?.description ?? helper
          : helper,
      child: control,
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({required this.picker});
  final OptionPicker<T> picker;
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Semantics(
      label: picker.label,
      child: SegmentedButton<T>(
        segments: [
          for (final o in picker.options)
            ButtonSegment(
              value: o.value,
              label: Text(o.label),
              icon: o.icon == null ? null : Icon(o.icon),
            ),
        ],
        selected: {?picker.value},
        emptySelectionAllowed: picker.value == null,
        showSelectedIcon: false,
        onSelectionChanged: picker.onChanged == null
            ? null
            : (s) {
                if (s.isNotEmpty) picker.onChanged!(s.first);
              },
      ),
    ),
  );
}

class _RadioList<T> extends StatelessWidget {
  const _RadioList({required this.picker});
  final OptionPicker<T> picker;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final enabled = picker.onChanged != null;
    return RadioGroup<T>(
      groupValue: picker.value,
      onChanged: (v) {
        if (v != null) picker.onChanged?.call(v);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final o in picker.options)
            MergeSemantics(
              child: Semantics(
                inMutuallyExclusiveGroup: true,
                checked: o.value == picker.value,
                enabled: enabled,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: hitTarget(context)),
                  child: Pressable(
                    onTap: enabled ? () => picker.onChanged!(o.value) : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.xs,
                      vertical: Space.sm,
                    ),
                    child: Row(
                      // A label alone sits level with its radio.
                      crossAxisAlignment: o.description == null
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        // The row is the target; the radio only shows state.
                        ExcludeFocus(
                          child: ExcludeSemantics(
                            child: IgnorePointer(
                              child: Radio<T>(
                                value: o.value,
                                enabled: enabled,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.label,
                                style: text.titleSmall?.copyWith(
                                  color: enabled ? c.text : c.secondary,
                                ),
                              ),
                              if (o.description != null)
                                Text(
                                  o.description!,
                                  style: text.bodySmall?.copyWith(
                                    color: c.secondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Dropdown<T> extends StatefulWidget {
  const _Dropdown({required this.picker});
  final OptionPicker<T> picker;
  @override
  State<_Dropdown<T>> createState() => _DropdownState<T>();
}

class _DropdownState<T> extends State<_Dropdown<T>> {
  final menu = MenuController();
  bool hovered = false, focused = false;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final picker = widget.picker;
    final enabled = picker.onChanged != null;
    final input = Theme.of(context).inputDecorationTheme;
    return LayoutBuilder(
      builder: (context, box) => MenuAnchor(
        controller: menu,
        alignmentOffset: const Offset(0, Space.xs),
        style: MenuStyle(
          minimumSize: WidgetStatePropertyAll(Size(box.maxWidth, 0)),
          maximumSize: WidgetStatePropertyAll(
            Size(box.maxWidth, double.infinity),
          ),
        ),
        menuChildren: [
          for (final o in picker.options)
            MenuItemButton(
              onPressed: () => picker.onChanged?.call(o.value),
              leadingIcon: Icon(
                o.value == picker.value ? Icons.check : null,
                color: c.primary,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: box.maxWidth - Space.xxxl - Space.xl,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(o.label, style: text.titleSmall),
                      if (o.description != null)
                        Text(
                          o.description!,
                          style: text.bodySmall?.copyWith(color: c.secondary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        builder: (context, controller, _) => Semantics(
          button: true,
          label: picker.label,
          value: picker.selected?.label,
          expanded: controller.isOpen,
          child: FocusableActionDetector(
            enabled: enabled,
            mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
            onShowHoverHighlight: (v) => setState(() => hovered = v),
            onFocusChange: (v) => setState(() => focused = v),
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  controller.isOpen ? controller.close() : controller.open();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled
                  ? () => controller.isOpen
                        ? controller.close()
                        : controller.open()
                  : null,
              child: InputDecorator(
                isFocused: focused || controller.isOpen,
                isHovering: hovered,
                decoration: InputDecoration(
                  enabled: enabled,
                  suffixIcon: Icon(
                    controller.isOpen ? Icons.expand_less : Icons.expand_more,
                    color: enabled ? c.text : c.secondary,
                  ),
                  enabledBorder: picker.errorText != null
                      ? input.errorBorder
                      : null,
                  focusedBorder: picker.errorText != null
                      ? input.focusedErrorBorder
                      : null,
                ),
                child: Text(
                  picker.selected?.label ?? picker.hintText,
                  style: text.bodyLarge?.copyWith(
                    color: picker.selected == null || !enabled
                        ? c.secondary
                        : c.text,
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
