import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'shell_navigation.dart';
import 'title_bar_tools.dart';

/// The maximize button's pointer state. The runner owns that button's input
/// (so Windows can show Snap Layouts) and reports it here.
enum CaptionState { none, hover, pressed }

@immutable
class WindowFrameState {
  const WindowFrameState({
    this.maximized = false,
    this.active = true,
    this.maxButton = CaptionState.none,
  });
  final bool maximized, active;
  final CaptionState maxButton;
}

/// The bridge to the Windows runner's custom frame, over the existing
/// `dev.salapiya/window_chrome` channel.
abstract final class WindowFrame {
  static const channel = MethodChannel('dev.salapiya/window_chrome');

  /// True once the runner has removed the native caption; the app then
  /// draws the title bar. Older runners and tests keep the native caption.
  static bool enabled = false;
  static final state = ValueNotifier(const WindowFrameState());
  static List<double>? _regions;

  /// Asks the runner for the custom frame. Call before `runApp`, so the
  /// first frame already has the title bar.
  static Future<bool> enable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return false;
    }
    try {
      enabled = await channel.invokeMethod<bool>('customFrame') ?? false;
    } on MissingPluginException {
      enabled = false;
    } on PlatformException {
      enabled = false;
    }
    if (enabled) channel.setMethodCallHandler(_handle);
    return enabled;
  }

  static Future<void> _handle(MethodCall call) async {
    if (call.method != 'state') return;
    final args = call.arguments as List<Object?>;
    state.value = WindowFrameState(
      maximized: args[0]! as bool,
      active: args[1]! as bool,
      maxButton: CaptionState.values[args[2]! as int],
    );
  }

  static void minimize() => unawaited(_send('minimize'));
  static void toggleMaximize() => unawaited(_send('toggleMaximize'));
  static void close() => unawaited(_send('close'));

  /// The title bar's height, the maximize button, then the interactive
  /// controls, as left, top, right, bottom in logical pixels. The runner
  /// treats the rest of the bar as drag space.
  static void regions(List<double> values) {
    if (listEquals(_regions, values)) return;
    _regions = values;
    unawaited(_send('regions', values));
  }

  static Future<void> _send(String method, [Object? args]) async {
    try {
      await channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Tests and older runners have no custom frame.
    } on PlatformException {
      // A failed window command leaves the window as it was.
    }
  }

  @visibleForTesting
  static void reset() {
    enabled = false;
    _regions = null;
    state.value = const WindowFrameState();
  }
}

/// Counts dialogs, sheets and other popups on the root navigator. While one
/// is open the title bar's app controls are inert; drag and the window
/// controls keep working.
class PopupRouteTracker extends NavigatorObserver {
  final open = ValueNotifier(false);
  int _count = 0;
  void _set(int count) {
    _count = count;
    // Navigator callbacks can arrive during a build; notify after it.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => open.value = _count > 0,
      );
    } else {
      open.value = _count > 0;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _set(_count + 1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _set(_count - 1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _set(_count - 1);
  }
}

/// What the app shell shows in the title bar.
@immutable
class TitleBarItems {
  const TitleBarItems({
    required this.navigation,
    required this.status,
    required this.notices,
    required this.hideAmounts,
    required this.sidebarWidth,
    required this.onGoTo,
    required this.onStatus,
    required this.onHideAmounts,
    required this.onCalendar,
  });
  final ShellNavigation navigation;
  final ShellStatus status;

  /// What needs the user, for the bell.
  final List<SidebarNotice> notices;
  final bool hideAmounts;

  /// The sidebar's width (0 without one): the bar's left segment, with the
  /// date and clock, lines up with it.
  final double sidebarWidth;
  final VoidCallback onGoTo, onStatus, onHideAmounts, onCalendar;

  /// Whether the bar would look the same; callbacks don't count.
  bool looksLike(TitleBarItems? other) =>
      other != null &&
      other.navigation == navigation &&
      other.status == status &&
      other.hideAmounts == hideAmounts &&
      other.sidebarWidth == sidebarWidth &&
      listEquals(
        [for (final n in other.notices) n.label],
        [for (final n in notices) n.label],
      );
}

class TitleBarController extends ChangeNotifier {
  TitleBarItems? _items;
  TitleBarItems? get items => _items;
  bool _disposed = false;

  /// Callbacks are read when used, so only a change the bar shows rebuilds
  /// it. A shell closing with the window may arrive after disposal.
  set items(TitleBarItems? value) {
    if (_disposed) return;
    final changed = value == null ? _items != null : !value.looksLike(_items);
    _items = value;
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Present only while the custom title bar is shown.
class TitleBarScope extends InheritedWidget {
  const TitleBarScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final TitleBarController controller;
  static TitleBarController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TitleBarScope>()?.controller;
  @override
  bool updateShouldNotify(TitleBarScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Shows [items] in the title bar while this widget is mounted. Does
/// nothing without a title bar.
class TitleBarSlot extends StatefulWidget {
  const TitleBarSlot({super.key, required this.items, required this.child});
  final TitleBarItems items;
  final Widget child;
  @override
  State<TitleBarSlot> createState() => _TitleBarSlotState();
}

class _TitleBarSlotState extends State<TitleBarSlot> {
  TitleBarController? bar;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    bar = TitleBarScope.maybeOf(context);
    publish();
  }

  @override
  void didUpdateWidget(TitleBarSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    publish();
  }

  // The bar sits above this widget, so it changes after the build.
  void publish() => SchedulerBinding.instance.addPostFrameCallback((_) {
    if (mounted) bar?.items = widget.items;
  });

  @override
  void dispose() {
    final bar = this.bar, navigation = widget.items.navigation;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (bar?.items?.navigation == navigation) bar!.items = null;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The Windows title bar (§2): the date and clock over the sidebar, back
/// and forward, the Go to field centered, the bell, calculator and Hide
/// amounts, the sync status and the window controls. The rest is drag
/// space, which the runner handles natively (drag, double-click, system
/// menu).
class TitleBar extends StatefulWidget {
  const TitleBar({super.key, required this.controller, required this.popups});
  final TitleBarController controller;
  final PopupRouteTracker popups;
  @override
  State<TitleBar> createState() => _TitleBarState();
}

enum _Slot { segment, lead, center, trail }

class _TitleBarState extends State<TitleBar> {
  final clock = GlobalKey(), lead = GlobalKey(), center = GlobalKey();
  final tools = GlobalKey(), status = GlobalKey();
  final minimize = GlobalKey(), maximize = GlobalKey(), close = GlobalKey();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.popups.open,
      WindowFrame.state,
    ]),
    builder: (context, _) {
      final items = widget.controller.items;
      return items == null
          ? bar(context, null)
          : ListenableBuilder(
              listenable: items.navigation,
              builder: (context, _) => bar(context, items),
            );
    },
  );

  Widget bar(BuildContext context, TitleBarItems? items) {
    final c = CraftTheme.of(context);
    final width = WidthClass.of(context);
    final frame = WindowFrame.state.value;
    final blocked = widget.popups.open.value;
    final segment = items?.sidebarWidth ?? 0;
    // Back and forward sit just past the sidebar's edge, anchored to it.
    final leadX = segment + Space.sm;
    // Neutral, as navigation chrome; the tools on the right keep the accent.
    final arrows = Theme.of(context).iconButtonTheme.style?.copyWith(
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? c.secondary : c.text,
      ),
    );
    report();
    // Dialogs leave the bar visible; its app controls wait for them.
    Widget app(Widget child) => ExcludeFocus(
      excluding: blocked,
      child: IgnorePointer(ignoring: blocked, child: child),
    );
    return Container(
      height: Space.titleBarHeight,
      color: c.titleBar,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomMultiChildLayout(
              delegate: _TitleBarLayout(segment: segment, leadX: leadX),
              children: [
                // The sidebar's column runs unbroken to the window's top; the
                // clock sits on its icon and label lines.
                if (segment > 0)
                  LayoutId(
                    id: _Slot.segment,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.surface,
                        border: Border(right: BorderSide(color: c.divider)),
                      ),
                      child: Center(
                        child: app(
                          KeyedSubtree(
                            key: clock,
                            child: ClockButton(
                              timeOnly: segment < Space.sidebarWidth,
                              onCalendar: () =>
                                  widget.controller.items?.onCalendar(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (items != null)
                  LayoutId(
                    id: _Slot.lead,
                    child: app(
                      IconButtonTheme(
                        data: IconButtonThemeData(style: arrows),
                        child: Row(
                          key: lead,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIconButton(
                              key: const ValueKey('titlebar-back'),
                              icon: Icons.arrow_back,
                              tooltip: 'Back (Alt+←)',
                              onPressed: items.navigation.canGoBack
                                  ? items.navigation.goBack
                                  : null,
                            ),
                            const SizedBox(width: Space.xs),
                            AppIconButton(
                              key: const ValueKey('titlebar-forward'),
                              icon: Icons.arrow_forward,
                              tooltip: 'Forward (Alt+→)',
                              onPressed: items.navigation.canGoForward
                                  ? items.navigation.goForward
                                  : null,
                            ),
                            if (width == WidthClass.medium) ...[
                              const SizedBox(width: Space.sm),
                              AppIconButton(
                                key: const ValueKey('shell-goto'),
                                icon: Icons.search,
                                tooltip: 'Go to (Ctrl+K)',
                                onPressed: () =>
                                    widget.controller.items?.onGoTo(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                if (items != null && width.index >= WidthClass.expanded.index)
                  LayoutId(
                    id: _Slot.center,
                    child: app(
                      KeyedSubtree(
                        key: center,
                        child: GoToField(
                          onTap: () => widget.controller.items?.onGoTo(),
                        ),
                      ),
                    ),
                  ),
                LayoutId(
                  id: _Slot.trail,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (items != null) ...[
                        app(
                          Row(
                            key: tools,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              NotificationsButton(notices: items.notices),
                              const SizedBox(width: Space.xs),
                              // Below 600 the calculator gives way to drag space.
                              if (width != WidthClass.compact) ...[
                                const CalculatorButton(),
                                const SizedBox(width: Space.xs),
                              ],
                              MergeSemantics(
                                child: Semantics(
                                  toggled: items.hideAmounts,
                                  child: AppIconButton(
                                    key: const ValueKey('shell-hide-amounts'),
                                    icon: items.hideAmounts
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    tooltip: items.hideAmounts
                                        ? 'Show amounts (Ctrl+H)'
                                        : 'Hide amounts (Ctrl+H)',
                                    onPressed: () => widget.controller.items
                                        ?.onHideAmounts(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        app(
                          KeyedSubtree(
                            key: status,
                            child: _SyncButton(
                              status: items.status,
                              compact: width == WidthClass.compact,
                              onTap: () => widget.controller.items?.onStatus(),
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                      ],
                      _CaptionButton(
                        key: minimize,
                        glyph: CaptionButtons.minimize,
                        label: 'Minimize',
                        active: frame.active,
                        onTap: WindowFrame.minimize,
                      ),
                      _CaptionButton(
                        key: maximize,
                        glyph: frame.maximized
                            ? CaptionButtons.restore
                            : CaptionButtons.maximize,
                        label: frame.maximized ? 'Restore Down' : 'Maximize',
                        active: frame.active,
                        native: frame.maxButton,
                        onTap: WindowFrame.toggleMaximize,
                      ),
                      _CaptionButton(
                        key: close,
                        glyph: CaptionButtons.close,
                        label: 'Close',
                        active: frame.active,
                        close: true,
                        onTap: WindowFrame.close,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // The bar's line stops at the sidebar's column.
          Positioned(
            left: segment,
            right: 0,
            bottom: 0,
            height: 1,
            child: ColoredBox(color: c.divider),
          ),
        ],
      ),
    );
  }

  /// Sends the runner the bar's hit-test regions after layout.
  void report() => SchedulerBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    Rect? rectOf(GlobalKey key) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return null;
      return box.localToGlobal(Offset.zero) & box.size;
    }

    final max = rectOf(maximize) ?? Rect.zero;
    WindowFrame.regions([
      Space.titleBarHeight,
      max.left,
      max.top,
      max.right,
      max.bottom,
      for (final key in [clock, lead, center, tools, status, minimize, close])
        if (rectOf(key) case final r?) ...[r.left, r.top, r.right, r.bottom],
    ]);
  });
}

/// The left segment as wide as the sidebar, back and forward at [leadX],
/// the window controls on the right, and the Go to field centered on the
/// window. The field narrows rather than overlap either side, and keeps
/// drag space beside it.
class _TitleBarLayout extends MultiChildLayoutDelegate {
  _TitleBarLayout({required this.segment, required this.leadX});
  final double segment, leadX;
  @override
  void performLayout(Size size) {
    final loose = BoxConstraints.loose(size);
    var lead = Size.zero, trail = Size.zero;
    if (hasChild(_Slot.segment)) {
      layoutChild(
        _Slot.segment,
        BoxConstraints.tightFor(width: segment, height: size.height),
      );
      positionChild(_Slot.segment, Offset.zero);
    }
    if (hasChild(_Slot.trail)) {
      trail = layoutChild(_Slot.trail, loose);
      positionChild(
        _Slot.trail,
        Offset(size.width - trail.width, (size.height - trail.height) / 2),
      );
    }
    if (hasChild(_Slot.lead)) {
      lead = layoutChild(_Slot.lead, loose);
      positionChild(_Slot.lead, Offset(leadX, (size.height - lead.height) / 2));
    }
    if (!hasChild(_Slot.center)) return;
    final left = leadX + lead.width + Space.xxxl;
    final right = size.width - trail.width - Space.xxxl;
    final width = math.max(0.0, math.min(Space.goToWidth, right - left));
    final field = layoutChild(
      _Slot.center,
      BoxConstraints(minWidth: width, maxWidth: width, maxHeight: size.height),
    );
    final x = width == 0
        ? left
        : ((size.width - width) / 2).clamp(left, right - width);
    positionChild(_Slot.center, Offset(x, (size.height - field.height) / 2));
  }

  @override
  bool shouldRelayout(_TitleBarLayout oldDelegate) =>
      oldDelegate.segment != segment || oldDelegate.leadX != leadX;
}

/// The sync status, as a pill that opens the sync details. Icon-only below
/// 600 wide, with the label in its tooltip.
class _SyncButton extends StatelessWidget {
  const _SyncButton({
    required this.status,
    required this.compact,
    required this.onTap,
  });
  final ShellStatus status;
  final bool compact;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return Tooltip(
      message: 'Sync status: ${status.label}',
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: 'Sync status, ${status.label}',
        excludeSemantics: true,
        child: SizedBox(
          height: Space.pointerTarget,
          width: compact ? Space.pointerTarget : null,
          child: Pressable(
            key: const ValueKey('titlebar-sync'),
            onTap: onTap,
            radius: Radii.pill,
            padding: compact
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: Space.xs),
            child: Center(
              widthFactor: compact ? null : 1,
              child: compact
                  ? Icon(
                      status.icon,
                      size: Space.compactControlIcon,
                      color: StatusPill.colors(c, status.tone).$1,
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: Space.popoverMaxWidth,
                      ),
                      child: StatusPill(
                        status.label,
                        icon: status.icon,
                        tone: status.tone,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A Windows 11 caption button: full bar height, 46 wide, Segoe glyphs.
/// Not in the Tab order, as with native caption buttons (Alt+Space reaches
/// them); screen readers get a named button.
class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    super.key,
    required this.glyph,
    required this.label,
    required this.active,
    required this.onTap,
    this.native = CaptionState.none,
    this.close = false,
  });
  final String glyph, label;
  final bool active, close;

  /// Pointer state reported by the runner (the maximize button only).
  final CaptionState native;
  final VoidCallback onTap;
  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool hovered = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final state = widget.native != CaptionState.none
        ? widget.native
        : pressed
        ? CaptionState.pressed
        : hovered
        ? CaptionState.hover
        : CaptionState.none;
    final down = state == CaptionState.pressed;
    Color? fill;
    var ink = widget.active ? c.text : c.secondary;
    if (state != CaptionState.none) {
      if (c.highContrast) {
        fill = c.text;
        ink = c.titleBar;
      } else if (widget.close) {
        fill = down
            ? CraftTheme.windowClosePressed
            : CraftTheme.windowCloseHover;
        ink = CraftTheme.onWindowCloseHover;
      } else {
        fill = down ? c.windowControlPressed : c.windowControlHover;
      }
    }
    return Semantics(
      container: true,
      button: true,
      enabled: true,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.label,
        excludeFromSemantics: true,
        child: MouseRegion(
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = pressed = false),
          child: GestureDetector(
            excludeFromSemantics: true,
            onTapDown: (_) => setState(() => pressed = true),
            onTapCancel: () => setState(() => pressed = false),
            onTapUp: (_) => setState(() => pressed = false),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.quick),
              curve: Motion.enter,
              width: CaptionButtons.width,
              color: fill ?? c.titleBar,
              alignment: Alignment.center,
              child: Text(
                widget.glyph,
                style: CaptionButtons.glyph.copyWith(color: ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
