import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../design_system/craft.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../prototype/scenarios.dart';

IconData destinationIcon(AppDestination destination) => switch (destination) {
  AppDestination.overview => Icons.grid_view_rounded,
  AppDestination.money => Icons.account_balance_wallet_outlined,
  AppDestination.debts => Icons.receipt_long_outlined,
  AppDestination.shared => Icons.people_outline,
  AppDestination.life => Icons.spa_outlined,
};

/// The dock label; screen readers still hear the full name.
String dockLabel(AppDestination destination) =>
    destination == AppDestination.shared ? 'Shared' : destination.label;

/// One page open over a destination, as the breadcrumb names it.
@immutable
class ShellPage {
  const ShellPage(this.name, this.title);

  /// The route name (`RouteSettings.name`), e.g. `debt/<id>`.
  final String name;
  final String title;
}

/// One breadcrumb segment. [onSelected] goes back to it; null for the
/// current segment.
@immutable
class ShellCrumb {
  const ShellCrumb(this.label, [this.onSelected]);
  final String label;
  final VoidCallback? onSelected;
}

typedef ShellLocation = ({AppDestination destination, String? tab});

/// Where the user is in the app shell and how they got there. UI state only;
/// routes and route names don't change.
///
/// History holds destination and tab changes plus the pages open in the
/// content area. Back closes the top page, or returns to the previous
/// destination and tab. Forward only redoes destination and tab changes; it
/// never reopens a closed page. The Windows title bar reads [breadcrumb],
/// [canGoBack] and [canGoForward].
class ShellNavigation extends ChangeNotifier {
  ShellNavigation({this.destination = AppDestination.overview});

  /// The tab each section opens on.
  static const defaultTabs = {
    AppDestination.money: 'Accounts',
    AppDestination.shared: 'Bills',
    AppDestination.life: 'Calendar',
  };
  static const _historyLimit = 50;

  /// The content-area navigator that pages open on.
  final navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'Shell content');
  late final NavigatorObserver observer = _PageObserver(this);

  AppDestination destination;
  final _tabs = Map<AppDestination, String>.of(defaultTabs);
  final _revisions = <AppDestination, int>{};
  final _routes = <Route<dynamic>>[];
  final _back = <ShellLocation>[], _forward = <ShellLocation>[];

  static ShellNavigation? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ShellNavigationScope>()
      ?.notifier;
  static ShellNavigation of(BuildContext context) => maybeOf(context)!;

  /// Sections call this from their tab control. Does nothing outside the
  /// shell, so screens still work on their own in tests.
  static void reportTab(BuildContext context, String tab) => context
      .getInheritedWidgetOfExactType<ShellNavigationScope>()
      ?.notifier
      ?._tabChanged(tab);

  /// The current tab of the current destination; null where it has none.
  String? get tab => _tabs[destination];
  String? tabOf(AppDestination destination) => _tabs[destination];

  /// Changes when the shell asks [destination]'s section to show another
  /// tab. Sections are keyed on it, so they reopen on [tabOf].
  int revisionOf(AppDestination destination) => _revisions[destination] ?? 0;

  List<ShellPage> get pages => [
    for (final route in _routes)
      ShellPage(route.settings.name ?? '', pageTitle(route.settings)),
  ];
  bool get hasPages => _routes.isNotEmpty;
  bool get canGoBack => hasPages || _back.isNotEmpty;
  bool get canGoForward => !hasPages && _forward.isNotEmpty;

  /// Section › Tab › Page › …
  List<ShellCrumb> get breadcrumb {
    final open = pages;
    final first = defaultTabs[destination];
    return [
      ShellCrumb(
        destination.label,
        open.isEmpty && (tab == null || tab == first)
            ? null
            : () => select(destination, tab: first),
      ),
      if (tab != null) ShellCrumb(tab!, open.isEmpty ? null : closePages),
      for (final (i, page) in open.indexed)
        ShellCrumb(
          page.title,
          i == open.length - 1 ? null : () => closePages(keep: i + 1),
        ),
    ];
  }

  /// The breadcrumb label of a page: its title, or a name from its route.
  static String pageTitle(RouteSettings settings) {
    if (settings.arguments case final String title) return title;
    final name = settings.name ?? '';
    for (final (prefix, label) in const [
      ('money/account/', 'Account'),
      ('money/transaction/', 'Transaction'),
      ('shared/bill/', 'Bill'),
      ('debt/', 'Debt'),
      ('profile', 'Profile and settings'),
      ('life/', 'Life'),
    ]) {
      if (name.startsWith(prefix)) return label;
    }
    return 'Details';
  }

  ShellLocation get _here => (destination: destination, tab: tab);

  void _remember() {
    _back.add(_here);
    if (_back.length > _historyLimit) _back.removeAt(0);
    _forward.clear();
  }

  /// Goes to [next], on [tab] when given. Open pages close first; a page
  /// that refuses (e.g. an unsaved draft) keeps the user where they are.
  Future<void> select(AppDestination next, {String? tab}) async {
    if (hasPages && !await closePages()) return;
    final tabChange = tab != null && tab != _tabs[next];
    if (next == destination && !tabChange) return;
    _remember();
    _go((destination: next, tab: tab ?? _tabs[next]));
  }

  void _tabChanged(String tab) {
    if (_tabs[destination] == tab) return;
    _remember();
    _tabs[destination] = tab;
    _changed();
  }

  void _go(ShellLocation to) {
    destination = to.destination;
    if (to.tab != null && to.tab != _tabs[to.destination]) {
      _tabs[to.destination] = to.tab!;
      _revisions[to.destination] = revisionOf(to.destination) + 1;
    }
    _changed();
  }

  Future<void> goBack() async {
    if (hasPages) {
      await navigatorKey.currentState?.maybePop();
      return;
    }
    if (_back.isEmpty) return;
    _forward.add(_here);
    _go(_back.removeLast());
  }

  void goForward() {
    if (!canGoForward) return;
    _back.add(_here);
    _go(_forward.removeLast());
  }

  /// Closes pages from the top until [keep] remain. Each page may refuse,
  /// as with Back; returns false when one did.
  Future<bool> closePages({int keep = 0}) async {
    while (_routes.length > keep) {
      final before = _routes.length;
      await navigatorKey.currentState?.maybePop();
      if (_routes.length >= before) return false;
    }
    return true;
  }

  void _pushed(Route<dynamic> route) {
    _routes.add(route);
    _forward.clear();
    _changed();
  }

  void _removed(Route<dynamic> route) {
    if (_routes.remove(route)) _changed();
  }

  bool _disposed = false;
  void _changed() {
    if (_disposed) return;
    // Navigator callbacks can arrive during a build; notify after it.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _changed());
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Tracks pages pushed on the content navigator. The destinations themselves
/// are its first, page-based route and are not counted.
class _PageObserver extends NavigatorObserver {
  _PageObserver(this.shell);
  final ShellNavigation shell;
  static bool _tracked(Route<dynamic>? route) =>
      route is PageRoute && route.settings is! Page;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_tracked(route)) shell._pushed(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      shell._removed(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      shell._removed(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) shell._removed(oldRoute);
    if (_tracked(newRoute)) shell._pushed(newRoute!);
  }
}

class ShellNavigationScope extends InheritedNotifier<ShellNavigation> {
  const ShellNavigationScope({
    super.key,
    required ShellNavigation navigation,
    required super.child,
  }) : super(notifier: navigation);
}

/// The sync state shown under the profile name in the sidebar.
typedef SidebarStatus = ({String label, IconData icon, PillTone tone});

/// An entry in the sidebar's profile menu.
typedef SidebarLink = ({String label, IconData icon, VoidCallback onSelected});

/// A "Needs attention" row: what needs the user and where to handle it.
@immutable
class SidebarNotice {
  const SidebarNotice(
    this.label, {
    required this.icon,
    this.tone = PillTone.neutral,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final PillTone tone;
  final VoidCallback? onTap;
}

/// Windows primary navigation, after the owner's references: a panel flush
/// with the window's left, top and bottom edges. It holds the logo and the
/// collapse toggle (in a row level with the app bar), the profile card and
/// its menu, the five destinations (the current section unfolds its tabs),
/// what needs attention, and utilities at the bottom. Collapsed, it is a
/// rail with tooltips, where sections open their tabs in a flyout.
class ShellSidebar extends StatefulWidget {
  const ShellSidebar({
    super.key,
    required this.navigation,
    required this.expanded,
    required this.profileName,
    required this.status,
    required this.profileLinks,
    required this.tabs,
    required this.badges,
    required this.notices,
    required this.hideAmounts,
    required this.onHideAmounts,
    required this.themeMode,
    required this.onThemeMode,
    required this.onSettings,
    required this.onHelp,
    this.toggle,
  });
  final ShellNavigation navigation;
  final bool expanded, hideAmounts;
  final String profileName;
  final SidebarStatus status;
  final List<SidebarLink> profileLinks;

  /// Each section's tabs, in the order the section shows them.
  final Map<AppDestination, List<String>> tabs;

  /// Counts that need the user in a section, e.g. payments to confirm.
  final Map<AppDestination, int> badges;
  final List<SidebarNotice> notices;
  final VoidCallback onHideAmounts, onSettings, onHelp;

  /// The profile's setting. The sidebar offers Light or Dark and shows
  /// whichever one System is currently giving.
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;

  /// Collapses or expands the sidebar; null where only the rail fits.
  final VoidCallback? toggle;
  @override
  State<ShellSidebar> createState() => _ShellSidebarState();
}

class _ShellSidebarState extends State<ShellSidebar> {
  /// Only the current section shows its tabs (an accordion), so the list
  /// stays short. Pressing the current section folds or unfolds them.
  bool folded = false;
  AppDestination? shown;

  ShellNavigation get navigation => widget.navigation;
  bool get wide => widget.expanded;

  void press(AppDestination destination, bool expandable) {
    if (navigation.destination == destination && expandable) {
      setState(() => folded = !folded);
      return;
    }
    navigation.select(destination);
  }

  @override
  Widget build(BuildContext context) {
    if (shown != navigation.destination) {
      shown = navigation.destination;
      folded = false;
    }
    final c = CraftTheme.of(context);
    final width = wide ? Space.sidebarWidth : Space.railWidth;
    return Container(
      key: const ValueKey('sidebar-card'),
      width: width,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          right: BorderSide(color: c.highContrast ? c.text : c.divider),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        wide ? Space.md : Space.sm,
        0,
        wide ? Space.md : Space.sm,
        Space.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The logo row stays put; the rest scrolls when the window is short.
          brand(context),
          const SizedBox(height: Space.sm),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileCard(
                    name: widget.profileName,
                    status: widget.status,
                    links: widget.profileLinks,
                    compact: !wide,
                  ),
                  const SizedBox(height: Space.lg),
                  for (final destination in AppDestination.values)
                    ...entries(context, destination),
                  if (wide) ...notices(context),
                ],
              ),
            ),
          ),
          Divider(height: Space.lg, indent: Space.xs, endIndent: Space.xs),
          ...footer(context),
        ],
      ),
    );
  }

  Widget brand(BuildContext context) {
    final c = CraftTheme.of(context);
    final toggle = widget.toggle;
    final toggleButton = toggle == null
        ? null
        : _RailButton(
            icon: Icons.view_sidebar_outlined,
            glyph: _PanelGlyph(open: wide),
            tooltip: wide ? 'Collapse sidebar' : 'Expand sidebar',
            dimension: Space.navSearch,
            onTap: toggle,
          );
    if (!wide) {
      return Column(
        children: [
          SizedBox(
            height: Space.appBarHeight,
            child: Semantics(
              label: 'Salapiya',
              image: true,
              child: const Center(child: BrandMark(size: Space.xl)),
            ),
          ),
          ?toggleButton,
        ],
      );
    }
    return SizedBox(
      height: Space.appBarHeight,
      child: Row(
        children: [
          const SizedBox(width: Space.xs),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/branding/display/salapiya_horizontal_on_${c.dark ? 'dark' : 'light'}.png',
                height: Space.xxl,
                semanticLabel: 'Salapiya',
              ),
            ),
          ),
          ?toggleButton,
        ],
      ),
    );
  }

  List<Widget> entries(BuildContext context, AppDestination destination) {
    final tabs = widget.tabs[destination] ?? const <String>[];
    final current = navigation.destination == destination;
    final badge = widget.badges[destination] ?? 0;
    if (!wide) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: Space.xs),
          child: _RailItem(
            key: ValueKey('nav-${destination.name}'),
            destination: destination,
            selected: current,
            badge: badge,
            tabs: tabs,
            tab: current ? navigation.tab : null,
            onPressed: () => navigation.select(destination),
            onTab: (tab) => navigation.select(destination, tab: tab),
          ),
        ),
        if (destination == AppDestination.overview) separator,
      ];
    }
    final showTabs = tabs.isNotEmpty && current && !folded;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: Space.xs),
        child: _NavRow(
          key: ValueKey('nav-${destination.name}'),
          destination: destination,
          selected: current,
          badge: badge,
          expandable: tabs.isNotEmpty,
          open: showTabs,
          onPressed: () => press(destination, tabs.isNotEmpty),
        ),
      ),
      if (showTabs) ...[
        for (final (i, tab) in tabs.indexed)
          _TabRow(
            key: ValueKey('nav-${destination.name}-$tab'),
            label: tab,
            last: i == tabs.length - 1,
            selected: navigation.tab == tab,
            onPressed: () => navigation.select(destination, tab: tab),
          ),
        const SizedBox(height: Space.xs),
      ],
      // Overview is the dashboard; the sections below are where work happens.
      if (destination == AppDestination.overview) separator,
    ];
  }

  static const separator = Divider(
    height: Space.xl - Space.xs,
    indent: Space.xs,
    endIndent: Space.xs,
  );

  List<Widget> notices(BuildContext context) {
    final c = CraftTheme.of(context);
    return [
      Divider(height: Space.xl, indent: Space.xs, endIndent: Space.xs),
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xs),
        child: Text(
          'NEEDS ATTENTION',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: c.secondary),
        ),
      ),
      if (widget.notices.isEmpty)
        const _UtilityRow(
          icon: Icons.check_circle_outline,
          label: 'Nothing needs attention',
          muted: true,
        )
      else
        for (final notice in widget.notices)
          _UtilityRow(
            icon: notice.icon,
            label: notice.label,
            iconColor: StatusPill.colors(c, notice.tone).$1,
            onTap: notice.onTap,
          ),
    ];
  }

  List<Widget> footer(BuildContext context) {
    final c = CraftTheme.of(context);
    final hideIcon = widget.hideAmounts
        ? Icons.visibility_off_outlined
        : Icons.visibility_outlined;
    final hideLabel = widget.hideAmounts ? 'Show amounts' : 'Hide amounts';
    // The theme in use, whether chosen or given by System.
    final dark = c.dark;
    if (!wide) {
      return [
        _RailButton(
          key: const ValueKey('shell-hide-amounts'),
          icon: hideIcon,
          tooltip: hideLabel,
          onTap: widget.onHideAmounts,
        ),
        _RailButton(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          onTap: widget.onSettings,
        ),
        _RailButton(
          icon: Icons.help_outline,
          tooltip: 'Help',
          onTap: widget.onHelp,
        ),
        _RailButton(
          key: ValueKey('theme-${dark ? 'light' : 'dark'}'),
          icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          tooltip: dark ? 'Switch to light theme' : 'Switch to dark theme',
          onTap: () =>
              widget.onThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
        ),
      ];
    }
    return [
      _UtilityRow(
        key: const ValueKey('shell-hide-amounts'),
        icon: hideIcon,
        label: 'Hide amounts',
        toggled: widget.hideAmounts,
        onTap: widget.onHideAmounts,
        trailing: ExcludeFocus(
          child: ExcludeSemantics(
            child: SizedBox(
              height: Space.xl - Space.xs,
              child: FittedBox(
                child: Switch(
                  value: widget.hideAmounts,
                  onChanged: (_) => widget.onHideAmounts(),
                ),
              ),
            ),
          ),
        ),
      ),
      _UtilityRow(
        key: const ValueKey('shell-settings'),
        icon: Icons.settings_outlined,
        label: 'Settings',
        onTap: widget.onSettings,
      ),
      _UtilityRow(
        icon: Icons.help_outline,
        label: 'Help',
        onTap: widget.onHelp,
      ),
      const SizedBox(height: Space.sm),
      _ThemeSwitch(dark: dark, onChanged: widget.onThemeMode),
    ];
  }
}

/// Selected items use a neutral fill and a darker, medium-weight label;
/// only the icon carries the brand purple. High contrast adds an outline.
BoxBorder? _selectedBorder(CraftTheme c, bool selected) =>
    selected && c.highContrast ? Border.all(color: c.text) : null;

TextStyle? _navLabel(BuildContext context, bool selected) {
  final c = CraftTheme.of(context);
  return NavType.label(context)?.copyWith(
    color: selected ? c.text : c.secondary,
    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
  );
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    super.key,
    required this.destination,
    required this.selected,
    required this.badge,
    required this.expandable,
    required this.open,
    required this.onPressed,
  });
  final AppDestination destination;
  final bool selected, expandable, open;
  final int badge;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        button: true,
        expanded: expandable ? open : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Space.navItem),
          child: Pressable(
            radius: Radii.nav,
            onTap: onPressed,
            color: selected ? c.subtle : null,
            border: _selectedBorder(c, selected),
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: Space.xs,
            ),
            child: Row(
              children: [
                Icon(
                  destinationIcon(destination),
                  size: Space.navIcon,
                  color: selected ? c.primary : c.secondary,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _navLabel(context, selected),
                  ),
                ),
                if (badge > 0) ...[
                  const SizedBox(width: Space.xs),
                  _Count(badge),
                ],
                if (expandable) ...[
                  const SizedBox(width: Space.xs),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: Space.navIcon,
                    color: c.secondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A section's tab under it, joined to the section icon by a tree line.
class _TabRow extends StatelessWidget {
  const _TabRow({
    super.key,
    required this.label,
    required this.last,
    required this.selected,
    required this.onPressed,
    this.inset = Space.lg,
  });
  final String label;
  final bool last, selected;
  final VoidCallback onPressed;

  /// How far the highlight stops short of the right edge.
  final double inset;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Space.navTab),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _TreeLine.width,
              child: CustomPaint(
                painter: _TreeLine(color: c.divider, last: last),
              ),
            ),
            Expanded(
              child: Padding(
                // The highlight stops short of the edge, as in the reference.
                padding: EdgeInsets.only(right: inset),
                child: MergeSemantics(
                  child: Semantics(
                    selected: selected,
                    button: true,
                    child: Pressable(
                      radius: Radii.nav,
                      onTap: onPressed,
                      color: selected ? c.subtle : null,
                      border: _selectedBorder(c, selected),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.sm,
                        vertical: Space.xs,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: selected ? c.text : c.secondary,
                                fontWeight: selected
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A vertical line under the section icon, curving into each tab.
class _TreeLine extends CustomPainter {
  const _TreeLine({required this.color, required this.last});
  final Color color;
  final bool last;

  /// The line sits under the section icon's center, on a half pixel so the
  /// hairline stays crisp instead of smearing across two pixels.
  static const x = Space.md + Space.navIcon / 2 + 0.5;
  static const width = Space.md * 2 + Space.navIcon / 2, radius = Space.sm;
  @override
  void paint(Canvas canvas, Size size) {
    final mid = (size.height / 2).floorToDouble() + 0.5;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(
      Path()
        ..moveTo(x, 0)
        ..lineTo(x, mid - radius)
        ..quadraticBezierTo(x, mid, x + radius, mid)
        ..lineTo(size.width - Space.xxs, mid),
      paint,
    );
    if (!last) {
      canvas.drawLine(Offset(x, mid - radius), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_TreeLine old) => old.color != color || old.last != last;
}

/// A square icon button: 40 × 40 with a 16 icon on the rail, smaller for
/// the panel toggle.
class _RailButton extends StatelessWidget {
  const _RailButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
    this.badge = 0,
    this.glyph,
    this.dimension = Space.navRailButton,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;

  /// Drawn instead of [icon] (which still names it), e.g. the panel glyph.
  final Widget? glyph;
  final int badge;
  final double dimension;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return Center(
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          selected: selected,
          label: tooltip,
          excludeSemantics: true,
          child: SizedBox.square(
            dimension: dimension,
            child: Pressable(
              radius: Radii.nav,
              onTap: onTap,
              color: selected ? c.subtle : null,
              border: _selectedBorder(c, selected),
              child: Center(
                child: Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge'),
                  backgroundColor: c.primary,
                  textColor: c.onPrimary,
                  child:
                      glyph ??
                      Icon(
                        icon,
                        size: Space.navIcon,
                        color: selected ? c.primary : c.secondary,
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

/// A destination on the rail. Sections with tabs open a flyout beside it:
/// a header with the section's icon and name, then its tabs on the same
/// tree line as the expanded sidebar, with the current tab highlighted.
class _RailItem extends StatefulWidget {
  const _RailItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.badge,
    required this.tabs,
    required this.tab,
    required this.onPressed,
    required this.onTab,
  });
  final AppDestination destination;
  final bool selected;
  final int badge;
  final List<String> tabs;
  final String? tab;
  final VoidCallback onPressed;
  final ValueChanged<String> onTab;
  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  final menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final destination = widget.destination;
    Widget item(VoidCallback onTap) => _RailButton(
      icon: destinationIcon(destination),
      tooltip: destination.label,
      selected: widget.selected,
      badge: widget.badge,
      onTap: onTap,
    );
    if (widget.tabs.isEmpty) return item(widget.onPressed);
    return MenuAnchor(
      controller: menu,
      // The flyout's header lines up with the rail item it came from.
      alignmentOffset: const Offset(
        Space.railWidth - Space.sm,
        -Space.navRailButton - Space.xs,
      ),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.all(Space.xs)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.controlOf(context)),
            side: BorderSide(color: c.highContrast ? c.text : c.divider),
          ),
        ),
      ),
      menuChildren: [
        SizedBox(
          width: Space.sidebarWidth - Space.xl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Space.navItem),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md),
                  child: Row(
                    children: [
                      Icon(
                        destinationIcon(destination),
                        size: Space.navIcon,
                        color: c.primary,
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            destination.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NavType.label(context)?.copyWith(
                              color: c.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final (i, t) in widget.tabs.indexed)
                _TabRow(
                  key: ValueKey('nav-${destination.name}-$t'),
                  label: t,
                  last: i == widget.tabs.length - 1,
                  selected: widget.selected && t == widget.tab,
                  inset: Space.xs,
                  onPressed: () {
                    menu.close();
                    widget.onTab(t);
                  },
                ),
            ],
          ),
        ),
      ],
      builder: (context, controller, _) => item(() {
        widget.onPressed();
        controller.isOpen ? controller.close() : controller.open();
      }),
    );
  }
}

/// The collapse toggle's glyph: a panel outline with its left pane, and a
/// chevron that points in to collapse ([open]) or out to expand.
class _PanelGlyph extends StatelessWidget {
  const _PanelGlyph({required this.open});
  final bool open;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(Space.navIcon + Space.xxs),
    painter: _PanelGlyphPainter(
      color: CraftTheme.of(context).secondary,
      open: open,
    ),
  );
}

class _PanelGlyphPainter extends CustomPainter {
  const _PanelGlyphPainter({required this.color, required this.open});
  final Color color;
  final bool open;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s / 12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final frame = Rect.fromLTRB(s * .1, s * .17, s * .9, s * .83);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, Radius.circular(s * .14)),
      stroke,
    );
    final pane = frame.left + frame.width * .36;
    canvas.drawLine(
      Offset(pane, frame.top),
      Offset(pane, frame.bottom),
      stroke,
    );
    // The chevron sits in the content pane.
    final cx = (pane + frame.right) / 2, cy = frame.center.dy;
    final d = s * .1, dir = open ? 1.0 : -1.0;
    canvas.drawPath(
      Path()
        ..moveTo(cx + d * dir, cy - d * 1.6)
        ..lineTo(cx - d * dir, cy)
        ..lineTo(cx + d * dir, cy + d * 1.6),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_PanelGlyphPainter old) =>
      old.color != color || old.open != open;
}

/// A count of things that need the user, e.g. payments to confirm.
class _Count extends StatelessWidget {
  const _Count(this.count);
  final int count;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm - Space.xxs,
        vertical: Space.xxs,
      ),
      decoration: BoxDecoration(
        color: c.selection,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        '$count',
        semanticsLabel: '$count need your attention',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: c.onSelection),
      ),
    );
  }
}

/// A sidebar row that isn't a destination: a notice or a utility.
class _UtilityRow extends StatelessWidget {
  const _UtilityRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
    this.trailing,
    this.toggled,
    this.muted = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Widget? trailing;
  final bool? toggled;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        toggled: toggled,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Space.navItem),
          child: Pressable(
            radius: Radii.nav,
            onTap: onTap,
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: Space.xs,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: Space.navIcon,
                  color: iconColor ?? c.secondary,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    label,
                    style: NavType.label(context)
                        ?.copyWith(color: muted ? c.secondary : c.text),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Light or Dark, as two labelled segments in one pill.
class _ThemeSwitch extends StatelessWidget {
  const _ThemeSwitch({required this.dark, required this.onChanged});

  /// The theme in use.
  final bool dark;
  final ValueChanged<ThemeMode> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return Semantics(
      label: 'Theme',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Space.xxs),
        decoration: BoxDecoration(
          color: c.subtle,
          borderRadius: BorderRadius.circular(Radii.nav),
        ),
        child: Row(
          children: [
            for (final (mode, icon, label) in const [
              (ThemeMode.light, Icons.light_mode_outlined, 'Light'),
              (ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
            ])
              Expanded(
                child: Builder(
                  builder: (context) {
                    final on = (mode == ThemeMode.dark) == dark;
                    return MergeSemantics(
                      child: Semantics(
                        button: true,
                        selected: on,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: Space.navTab - Space.xxs,
                          ),
                          child: Pressable(
                            key: ValueKey('theme-${mode.name}'),
                            onTap: () => onChanged(mode),
                            radius: Radii.nav - Space.xxs,
                            color: on ? c.surface : null,
                            hoverColor: on ? c.surface : null,
                            border: on
                                ? Border.all(
                                    color: c.highContrast ? c.text : c.divider,
                                  )
                                : null,
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.xs,
                              vertical: Space.xxs,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  icon,
                                  size: Space.md + Space.xxs,
                                  color: on ? c.text : c.secondary,
                                ),
                                const SizedBox(width: Space.xs),
                                Flexible(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _navLabel(context, on),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The profile card at the top of the sidebar: initial, name and sync state.
/// It opens the profile menu. On the rail it is the initial alone.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.status,
    required this.links,
    required this.compact,
  });
  final String name;
  final SidebarStatus status;
  final List<SidebarLink> links;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return MenuAnchor(
      alignmentOffset: compact
          ? const Offset(Space.railWidth - Space.sm, -Space.navRailButton)
          : const Offset(0, Space.xs),
      menuChildren: [
        for (final link in links)
          MenuItemButton(
            key: ValueKey('profile-menu-${link.label}'),
            leadingIcon: Icon(link.icon, size: Space.navIcon),
            onPressed: link.onSelected,
            child: Text(link.label, style: NavType.label(context)),
          ),
      ],
      builder: (context, controller, _) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        final semantics = 'Profile and settings, $name, ${status.label}';
        if (compact) {
          return Center(
            child: Tooltip(
              message: 'Profile and settings · ${status.label}',
              child: Semantics(
                button: true,
                label: semantics,
                excludeSemantics: true,
                child: SizedBox.square(
                  dimension: Space.navRailButton,
                  child: Pressable(
                    key: const ValueKey('shell-profile'),
                    onTap: toggle,
                    radius: Radii.pill,
                    child: Center(
                      child: ProfileInitial(name: name, size: Space.navAvatar),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return Semantics(
          button: true,
          label: semantics,
          excludeSemantics: true,
          child: Pressable(
            key: const ValueKey('shell-profile'),
            onTap: toggle,
            radius: Radii.nav,
            border: Border.all(color: c.divider),
            padding: const EdgeInsets.all(Space.sm),
            child: Row(
              children: [
                ProfileInitial(name: name, size: Space.navAvatar),
                const SizedBox(width: Space.sm + Space.xxs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NavType.label(
                          context,
                        )?.copyWith(color: c.text, fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          Icon(
                            status.icon,
                            size: Space.md,
                            color: StatusPill.colors(c, status.tone).$1,
                          ),
                          const SizedBox(width: Space.xs),
                          Expanded(
                            child: Text(
                              status.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color: c.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.unfold_more,
                  size: Space.navIcon,
                  color: c.secondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The app bar's Go to field (Ctrl+K): a slim search-style box with
/// keycaps. It opens Go to; it doesn't search records.
class GoToField extends StatelessWidget {
  const GoToField({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    Widget cap(String key) => Container(
      constraints: const BoxConstraints(minWidth: Space.lg + Space.xs),
      height: Space.lg + Space.xs,
      padding: const EdgeInsets.symmetric(horizontal: Space.xs),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.divider),
        borderRadius: BorderRadius.circular(Radii.nav - Space.xxs),
      ),
      child: Text(
        key,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: c.secondary, letterSpacing: 0),
      ),
    );
    return Semantics(
      button: true,
      label: 'Go to, Ctrl+K',
      excludeSemantics: true,
      child: SizedBox(
        height: Space.navSearch,
        child: Pressable(
          radius: Radii.nav,
          key: const ValueKey('shell-goto'),
          onTap: onTap,
          border: Border.all(color: c.divider),
          padding: const EdgeInsets.only(
            left: Space.sm + Space.xxs,
            right: Space.xs,
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: Space.navIcon, color: c.secondary),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  'Go to…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NavType.label(context)?.copyWith(color: c.secondary),
                ),
              ),
              cap('Ctrl'),
              const SizedBox(width: Space.xxs),
              cap('K'),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact app-bar button, sized with the Go to field beside it: 32 tall,
/// a 16 icon and a 13 label.
class AppBarButton extends StatelessWidget {
  const AppBarButton(
    this.label, {
    super.key,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        height: Space.navSearch,
        child: Pressable(
          onTap: onTap,
          radius: Radii.nav,
          border: Border.all(color: c.highContrast ? c.text : c.divider),
          padding: const EdgeInsets.symmetric(horizontal: Space.sm + Space.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: Space.navIcon, color: c.text),
              const SizedBox(width: Space.xs + Space.xxs),
              Text(
                label,
                style: NavType.label(context)
                    ?.copyWith(color: c.text, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section › Tab › Page, with chevrons. Earlier segments go back to that
/// point; the current one is plain text.
class ShellBreadcrumb extends StatelessWidget {
  const ShellBreadcrumb({super.key, required this.crumbs});
  final List<ShellCrumb> crumbs;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return Row(
      children: [
        for (final (i, crumb) in crumbs.indexed) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
              child: Icon(
                Icons.chevron_right,
                size: Space.navIcon,
                color: c.secondary,
              ),
            ),
          Flexible(
            child: crumb.onSelected == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                    child: Text(
                      crumb.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // Only the last segment reads as the current place.
                      style: _navLabel(context, i == crumbs.length - 1),
                    ),
                  )
                : Semantics(
                    button: true,
                    child: Pressable(
                      onTap: crumb.onSelected,
                      radius: Radii.nav,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.xs,
                        vertical: Space.xxs,
                      ),
                      child: Text(
                        crumb.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _navLabel(context, false),
                      ),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

/// The profile's initial in a tinted circle, [size] across.
class ProfileInitial extends StatelessWidget {
  const ProfileInitial({super.key, required this.name, this.size = Space.xxl});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: c.selection,
      foregroundColor: c.onSelection,
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        style: (size < Space.xxl ? text.labelMedium : text.labelLarge)
            ?.copyWith(color: c.onSelection),
      ),
    );
  }
}

/// One place Go to can open: a section, a tab, a create action or a
/// settings page.
@immutable
class GoToEntry {
  const GoToEntry(
    this.label, {
    required this.icon,
    required this.onSelected,
    this.where,
    this.id,
  });
  final String label;

  /// Where it sits, e.g. "Money" for the Activity tab.
  final String? where;
  final IconData icon;
  final VoidCallback onSelected;

  /// A stable key for tests, e.g. `choose-money`.
  final String? id;
}

/// Go to (Ctrl+K): type to filter, Enter opens the first match. It jumps to
/// places in the app; it doesn't search records.
Future<void> showGoTo(BuildContext context, List<GoToEntry> entries) async {
  final chosen = await restoringFocus(
    () => showDialog<GoToEntry>(
      context: context,
      animationStyle: Motion.of(context, Motion.medium) == Duration.zero
          ? AnimationStyle.noAnimation
          : null,
      builder: (context) => _GoToDialog(entries),
    ),
  );
  chosen?.onSelected();
}

class _GoToDialog extends StatefulWidget {
  const _GoToDialog(this.entries);
  final List<GoToEntry> entries;
  @override
  State<_GoToDialog> createState() => _GoToDialogState();
}

class _GoToDialogState extends State<_GoToDialog> {
  String query = '';
  List<GoToEntry> get matches {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return widget.entries;
    return [
      for (final entry in widget.entries)
        if ('${entry.label} ${entry.where ?? ''}'.toLowerCase().contains(q))
          entry,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final found = matches;
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.xxxl,
        Space.lg,
        Space.lg,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Space.dialogMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: TextField(
                key: const ValueKey('goto-field'),
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Go to a section, tab, action or setting',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => query = value),
                onSubmitted: (_) {
                  if (found.isNotEmpty) Navigator.pop(context, found.first);
                },
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: found.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Space.xl),
                      child: Text(
                        'Nothing matches "$query".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.secondary),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(Space.sm),
                      child: ListGroup(
                        leading: true,
                        children: [
                          for (final entry in found)
                            ListRow(
                              key: entry.id == null
                                  ? null
                                  : ValueKey<String>(entry.id!),
                              title: entry.label,
                              subtitle: entry.where,
                              leading: entry.icon,
                              onTap: () => Navigator.pop(context, entry),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Android primary navigation: the + button and a floating dock with the five
/// destinations. Labels hide (icons and tooltips stay) when the dock is
/// narrow or text is large.
class ShellBottomBar extends StatelessWidget {
  const ShellBottomBar({
    super.key,
    required this.selected,
    required this.select,
    required this.onNew,
  });
  final AppDestination selected;
  final ValueChanged<AppDestination> select;
  final VoidCallback onNew;

  /// The narrowest dock that still shows labels at normal text size.
  static const labelMinWidth = Space.target * 7.5;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final c = CraftTheme.of(context);
      final labels =
          box.maxWidth >= labelMinWidth &&
          MediaQuery.textScalerOf(context).scale(Space.lg) / Space.lg < 1.5;
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.sm,
          Space.md,
          Space.lg,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Space.dockMaxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppIconButton(
                  key: const ValueKey('shell-new'),
                  icon: Icons.add,
                  tooltip: 'New',
                  variant: AppIconButtonVariant.filled,
                  onPressed: onNew,
                ),
                const SizedBox(height: Space.sm),
                DecoratedBox(
                  key: const ValueKey('floating-dock-surface'),
                  decoration: BoxDecoration(
                    color: c.raised,
                    borderRadius: BorderRadius.circular(Radii.overlay),
                    border: Border.all(color: c.divider),
                    boxShadow: c.overlayShadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Space.xs),
                    child: Row(
                      children: [
                        for (final destination in AppDestination.values)
                          Expanded(
                            child: _DockItem(
                              key: ValueKey('nav-${destination.name}'),
                              destination: destination,
                              selected: selected == destination,
                              label: labels,
                              onPressed: () => select(destination),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.label,
    required this.onPressed,
  });
  final AppDestination destination;
  final bool selected, label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final color = selected ? c.onSelection : c.secondary;
    final item = MergeSemantics(
      child: Semantics(
        selected: selected,
        button: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Space.target),
          child: Pressable(
            onTap: onPressed,
            radius: Radii.card,
            color: selected ? c.selection : null,
            hoverColor: selected ? c.selection : null,
            padding: const EdgeInsets.symmetric(
              horizontal: Space.xxs,
              vertical: Space.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  destinationIcon(destination),
                  color: color,
                  semanticLabel: label ? null : destination.label,
                ),
                if (label) ...[
                  const SizedBox(height: Space.xxs),
                  Text(
                    dockLabel(destination),
                    semanticsLabel: destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: color),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return label ? item : Tooltip(message: destination.label, child: item);
  }
}
