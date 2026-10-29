import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'shell_navigation.dart';

// The Windows title bar's tools (§2): the date and clock with a month
// calendar, the notifications bell, and the quick calculator.

/// The clock's time source; tests replace it.
abstract final class TitleBarClock {
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "Thu, 30 Oct", in the app's day-month order.
  static String date(DateTime d) =>
      '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
}

/// The date and time in the title bar's left segment, updated each minute.
/// The time follows the system's 12/24-hour setting. It opens a month
/// calendar. [timeOnly] fits the 64-wide rail.
class ClockButton extends StatefulWidget {
  const ClockButton({
    super.key,
    required this.timeOnly,
    required this.onCalendar,
  });
  final bool timeOnly;
  final VoidCallback onCalendar;
  @override
  State<ClockButton> createState() => _ClockButtonState();
}

class _ClockButtonState extends State<ClockButton> {
  Timer? timer;
  late DateTime now = TitleBarClock.now();

  @override
  void initState() {
    super.initState();
    schedule();
  }

  /// Wakes at the start of the next minute.
  void schedule() {
    timer = Timer(Duration(seconds: 60 - TitleBarClock.now().second), () {
      if (!mounted) return;
      setState(() => now = TitleBarClock.now());
      schedule();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(now),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final date = TitleBarClock.date(now);
    final text = Theme.of(context).textTheme;
    return MenuAnchor(
      alignmentOffset: const Offset(0, Space.xs),
      menuChildren: [
        _CalendarPanel(today: now),
        MenuItemButton(
          key: const ValueKey('clock-open-calendar'),
          leadingIcon: const Icon(Icons.calendar_month_outlined),
          onPressed: widget.onCalendar,
          child: const Text('Open Life › Calendar'),
        ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: '$date · $time',
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: '$date, $time. Open the calendar',
          excludeSemantics: true,
          child: SizedBox(
            height: Space.pointerTarget,
            child: Pressable(
              key: const ValueKey('titlebar-clock'),
              radius: Radii.nav,
              onTap: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              padding: EdgeInsets.symmetric(
                horizontal: widget.timeOnly ? Space.xs : Space.md,
              ),
              child: widget.timeOnly
                  ? Center(
                      widthFactor: 1,
                      child: Text(
                        time,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: text.bodySmall?.copyWith(
                          color: c.text,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: Space.navIcon,
                          color: c.secondary,
                        ),
                        const SizedBox(width: Space.md),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: time,
                                  style: TextStyle(
                                    color: c.text,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextSpan(text: ' · $date'),
                              ],
                            ),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: NavType.label(context)?.copyWith(
                              color: c.secondary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
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
}

/// A month calendar with today marked. It only shows dates; Life holds the
/// agenda.
class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({required this.today});
  final DateTime today;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: Space.popoverMaxWidth,
    child: CalendarDatePicker(
      key: const ValueKey('clock-calendar'),
      initialDate: today,
      currentDate: today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      onDateChanged: (_) {},
    ),
  );
}

/// The bell: what needs the user (payments to confirm, waiting to sync,
/// sync needs review), each row going where it's handled. It replaces the
/// sidebar's Needs attention group while the title bar is shown.
class NotificationsButton extends StatelessWidget {
  const NotificationsButton({super.key, required this.notices});
  final List<SidebarNotice> notices;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final count = notices.length;
    return MenuAnchor(
      alignmentOffset: const Offset(0, Space.xs),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.sm,
            Space.md,
            Space.xs,
          ),
          child: Text(
            'NEEDS ATTENTION',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: c.secondary),
          ),
        ),
        if (notices.isEmpty)
          const MenuItemButton(
            leadingIcon: Icon(Icons.check_circle_outline),
            child: Text('Nothing needs attention'),
          )
        else
          for (final notice in notices)
            MenuItemButton(
              key: ValueKey('notice-${notice.label}'),
              leadingIcon: Icon(
                notice.icon,
                color: StatusPill.colors(c, notice.tone).$1,
              ),
              onPressed: notice.onTap,
              child: Text(notice.label),
            ),
      ],
      builder: (context, controller, _) => IconButton(
        key: const ValueKey('titlebar-notifications'),
        tooltip: count == 0
            ? 'Notifications'
            : 'Notifications, $count need attention',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          backgroundColor: c.primary,
          textColor: c.onPrimary,
          child: Icon(
            count == 0
                ? Icons.notifications_none_outlined
                : Icons.notifications_outlined,
          ),
        ),
      ),
    );
  }
}

/// An exact fraction of two BigInts.
@immutable
class _Fraction {
  const _Fraction._(this.n, this.d);
  factory _Fraction(BigInt n, BigInt d) {
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    final g = n.gcd(d);
    return g <= BigInt.one ? _Fraction._(n, d) : _Fraction._(n ~/ g, d ~/ g);
  }

  /// A typed decimal such as "1250" or "0.1".
  factory _Fraction.parse(String text) {
    final dot = text.indexOf('.');
    final places = dot < 0 ? 0 : text.length - dot - 1;
    final digits = text.replaceFirst('.', '');
    return _Fraction(
      BigInt.parse(digits.isEmpty ? '0' : digits),
      BigInt.from(10).pow(places),
    );
  }
  final BigInt n, d;
  bool get isZero => n == BigInt.zero;

  _Fraction operator +(_Fraction o) => _Fraction(n * o.d + o.n * d, d * o.d);
  _Fraction operator -(_Fraction o) => _Fraction(n * o.d - o.n * d, d * o.d);
  _Fraction operator *(_Fraction o) => _Fraction(n * o.n, d * o.d);
  _Fraction operator /(_Fraction o) => _Fraction(n * o.d, d * o.n);

  /// Decimal places when the value ends; null when it repeats.
  int? get places {
    var rest = d, twos = 0, fives = 0;
    final two = BigInt.two, five = BigInt.from(5);
    while (rest % two == BigInt.zero) {
      rest ~/= two;
      twos++;
    }
    while (rest % five == BigInt.zero) {
      rest ~/= five;
      fives++;
    }
    return rest == BigInt.one ? (twos > fives ? twos : fives) : null;
  }

  /// The value with [scale] decimals, rounded half away from zero.
  String fixed(int scale) {
    final scaled = n.abs() * BigInt.from(10).pow(scale);
    var q = scaled ~/ d;
    if ((scaled.remainder(d)) * BigInt.two >= d) q += BigInt.one;
    var digits = q.toString().padLeft(scale + 1, '0');
    final whole = digits.substring(0, digits.length - scale);
    final part = digits.substring(digits.length - scale);
    digits = scale == 0 ? whole : '$whole.$part';
    return n.isNegative && q != BigInt.zero ? '-$digits' : digits;
  }
}

/// The quick calculator's arithmetic. It works on exact fractions, so
/// 0.1 + 0.2 is 0.3 and nothing drifts. Operations run left to right, as in
/// the Windows calculator's standard mode. A result that doesn't end within
/// [maxPlaces] decimals is shown rounded to centavos and marked "≈", so
/// rounding is never silent (DOMAIN_RULES §49). It saves nothing.
class CalculatorEngine {
  static const maxPlaces = 10, maxDigits = 15;
  static const operators = ['+', '−', '×', '÷'];

  String _entry = '0';
  _Fraction? _total;
  String? _op;
  bool _fresh = true;
  String expression = '';
  String? error;

  /// What the display shows: the typed entry or the running result.
  String get display {
    if (error != null) return error!;
    if (!_fresh || _total == null) return _group(_entry);
    return _show(_total!);
  }

  /// The value Copy puts on the clipboard: plain digits, rounded to
  /// centavos when the exact value doesn't end.
  String get copyText {
    final value = !_fresh || _total == null ? _Fraction.parse(_entry) : _total!;
    final places = value.places;
    return value.fixed(places == null || places > maxPlaces ? 2 : places);
  }

  static String _show(_Fraction value) {
    final places = value.places;
    return places == null || places > maxPlaces
        ? '≈ ${_group(value.fixed(2))}'
        : _group(value.fixed(places));
  }

  /// Thousands separators on the whole part.
  static String _group(String number) {
    final negative = number.startsWith('-');
    final body = negative ? number.substring(1) : number;
    final dot = body.indexOf('.');
    final whole = dot < 0 ? body : body.substring(0, dot);
    final out = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
      out.write(whole[i]);
    }
    return '${negative ? '-' : ''}$out${dot < 0 ? '' : body.substring(dot)}';
  }

  void digit(String key) {
    if (error != null) clear();
    if (_fresh) {
      _entry = key == '.' ? '0.' : key;
      _fresh = false;
      if (_op == null) _total = null;
      return;
    }
    if (key == '.' && _entry.contains('.')) return;
    if (_entry.replaceAll('.', '').length >= maxDigits) return;
    _entry = _entry == '0' && key != '.' ? key : '$_entry$key';
  }

  void backspace() {
    if (error != null || _fresh) return;
    _entry = _entry.length > 1 ? _entry.substring(0, _entry.length - 1) : '0';
  }

  void operator(String op) {
    if (error != null) return;
    if (_total == null) {
      _total = _Fraction.parse(_entry);
    } else if (!_fresh && _op != null) {
      if (!_apply(_Fraction.parse(_entry))) return;
    }
    _op = op;
    _fresh = true;
    expression = '${_show(_total!)} $op';
  }

  void equals() {
    if (error != null || _op == null) return;
    final right = _fresh ? _total! : _Fraction.parse(_entry);
    final left = _total!;
    if (!_apply(right)) return;
    expression = '${_show(left)} $_op ${_show(right)} =';
    _op = null;
    _fresh = true;
  }

  bool _apply(_Fraction right) {
    final left = _total!;
    if (_op == '÷' && right.isZero) {
      clear();
      error = "Can't divide by zero";
      return false;
    }
    _total = switch (_op) {
      '+' => left + right,
      '−' => left - right,
      '×' => left * right,
      _ => left / right,
    };
    return true;
  }

  void clear() {
    _entry = '0';
    _total = null;
    _op = null;
    _fresh = true;
    expression = '';
    error = null;
  }
}

/// The calculator button and its popover.
class CalculatorButton extends StatelessWidget {
  const CalculatorButton({super.key});
  @override
  Widget build(BuildContext context) => MenuAnchor(
    alignmentOffset: const Offset(0, Space.xs),
    menuChildren: const [_CalculatorPanel()],
    builder: (context, controller, _) => AppIconButton(
      key: const ValueKey('titlebar-calculator'),
      icon: Icons.calculate_outlined,
      tooltip: 'Calculator',
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}

class _CalculatorPanel extends StatefulWidget {
  const _CalculatorPanel();
  @override
  State<_CalculatorPanel> createState() => _CalculatorPanelState();
}

class _CalculatorPanelState extends State<_CalculatorPanel> {
  final engine = CalculatorEngine();
  bool copied = false;

  void run(void Function() action) => setState(() {
    copied = false;
    action();
  });

  Future<void> copy() async {
    await Clipboard.setData(ClipboardData(text: engine.copyText));
    if (mounted) setState(() => copied = true);
  }

  /// Typing works while the calculator is open; Esc closes it.
  KeyEventResult key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed && key == LogicalKeyboardKey.keyC) {
      unawaited(copy());
      return KeyEventResult.handled;
    }
    final character = event.character;
    void Function()? action = switch (key) {
      LogicalKeyboardKey.enter ||
      LogicalKeyboardKey.numpadEnter => engine.equals,
      LogicalKeyboardKey.backspace => engine.backspace,
      LogicalKeyboardKey.delete => engine.clear,
      // Numpad operators, whether or not they report a character.
      LogicalKeyboardKey.numpadAdd => () => engine.operator('+'),
      LogicalKeyboardKey.numpadSubtract => () => engine.operator('−'),
      LogicalKeyboardKey.numpadMultiply => () => engine.operator('×'),
      LogicalKeyboardKey.numpadDivide => () => engine.operator('÷'),
      _ => null,
    };
    if (action == null && character != null) {
      if (RegExp(r'^[0-9.]$').hasMatch(character)) {
        action = () => engine.digit(character);
      } else {
        final op = switch (character) {
          '+' => '+',
          '-' => '−',
          '*' || 'x' || 'X' => '×',
          '/' => '÷',
          _ => null,
        };
        if (op != null) action = () => engine.operator(op);
        if (character == '=') action = engine.equals;
        if (character == 'c' || character == 'C') action = engine.clear;
      }
    }
    if (action == null) return KeyEventResult.ignored;
    run(action);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    Widget row(List<Widget> keys) => Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Row(
        children: [
          for (final (i, key) in keys.indexed) ...[
            if (i > 0) const SizedBox(width: Space.xs),
            key,
          ],
        ],
      ),
    );
    _Key digit(String d, {int flex = 1}) =>
        _Key(d, flex: flex, onTap: () => run(() => engine.digit(d)));
    _Key op(String o) => _Key(
      o,
      kind: _KeyKind.operator,
      onTap: () => run(() => engine.operator(o)),
    );
    return Focus(
      autofocus: true,
      onKeyEvent: key,
      child: SizedBox(
        width: Space.sidebarWidth + Space.xxl,
        child: Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: true,
                label: 'Calculator result',
                value: engine.display,
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      copied ? 'Copied' : engine.expression,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: c.secondary),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        engine.display,
                        key: const ValueKey('calculator-display'),
                        maxLines: 1,
                        style: text.headlineSmall?.copyWith(
                          color: engine.error == null
                              ? c.text
                              : c.tone(NoticeTone.error).$1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xs),
              row([
                _Key(
                  'C',
                  kind: _KeyKind.operator,
                  onTap: () => run(engine.clear),
                ),
                _Key(
                  '⌫',
                  semantics: 'Backspace',
                  kind: _KeyKind.operator,
                  onTap: () => run(engine.backspace),
                ),
                _Key(
                  'Copy',
                  icon: Icons.copy_outlined,
                  semantics: 'Copy result',
                  kind: _KeyKind.operator,
                  onTap: copy,
                ),
                op('÷'),
              ]),
              row([digit('7'), digit('8'), digit('9'), op('×')]),
              row([digit('4'), digit('5'), digit('6'), op('−')]),
              row([digit('1'), digit('2'), digit('3'), op('+')]),
              row([
                digit('0', flex: 2),
                digit('.'),
                _Key(
                  '=',
                  kind: _KeyKind.equals,
                  onTap: () => run(engine.equals),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

enum _KeyKind { digit, operator, equals }

class _Key extends StatelessWidget {
  const _Key(
    this.label, {
    required this.onTap,
    this.kind = _KeyKind.digit,
    this.flex = 1,
    this.icon,
    this.semantics,
  });
  final String label;
  final VoidCallback onTap;
  final _KeyKind kind;
  final int flex;
  final IconData? icon;
  final String? semantics;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final ink = kind == _KeyKind.equals ? c.onPrimary : c.text;
    return Expanded(
      flex: flex,
      child: Semantics(
        button: true,
        label: semantics ?? label,
        excludeSemantics: true,
        child: SizedBox(
          height: Space.navItem,
          child: Pressable(
            key: ValueKey('calc-$label'),
            onTap: onTap,
            radius: Radii.nav,
            color: switch (kind) {
              _KeyKind.digit => c.surface,
              _KeyKind.operator => c.subtle,
              _KeyKind.equals => c.primary,
            },
            hoverColor: switch (kind) {
              _KeyKind.equals => c.hover,
              _ => c.windowControlHover,
            },
            border: kind == _KeyKind.digit
                ? Border.all(color: c.divider)
                : null,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: Space.compactControlIcon, color: ink)
                  : Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: ink),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
