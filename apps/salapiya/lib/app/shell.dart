import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/craft.dart';
import '../design_system/kit/kit.dart';
import '../design_system/measured_layout.dart';
import '../design_system/theme.dart';
import '../gallery/settings.dart';
import '../prototype/fixtures.dart';
import '../prototype/scenarios.dart';
import 'demo_routes.dart';
import 'overview.dart';
import 'previews.dart';
import 'profile_utilities.dart';
import 'shell_navigation.dart';
import 'title_bar.dart';
import '../features/finance/contracts/financial_models.dart';
import '../features/finance/presentation/financial_editor.dart';
import '../features/finance/presentation/financial_widgets.dart';
import '../features/finance/presentation/money_screen.dart';
import '../features/finance/presentation/debts_screen.dart';
import '../features/finance/presentation/shared_screen.dart';
import '../features/life/presentation/life_screen.dart';
import '../features/life/application/life_controller.dart';
import '../local/local_profile_view.dart';
import '../local/local_runtime.dart';
import '../local/local_finance_controller.dart';
import '../finance/finance_screen.dart';
import '../life/life_controller.dart';

/// A create action: a fixed key (it also names the route, `action/<key>`),
/// the glossary label, and an icon.
typedef NewItem = (String key, String label, IconData icon);

class SalapiyaShell extends StatefulWidget {
  const SalapiyaShell({super.key, required this.settings, this.session});
  final GallerySettings settings;
  final PrototypeSession? session;
  @override
  State<SalapiyaShell> createState() => _SalapiyaShellState();
}

class _SalapiyaShellState extends State<SalapiyaShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final life = session.life;
      if (life is DurableLifeController && life.device != null) {
        life.device!.navigate = (item) {
          if (!mounted) return;
          if (item == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This reminder source changed or is no longer available. Open Life to review current commitments.',
                ),
              ),
            );
            return;
          }
          openLifeSource(
            navigation.navigatorKey.currentContext ?? context,
            session,
            item,
          );
        };
        life.device!.openPendingTap();
      }
    });
  }

  late final PrototypeSession session = widget.session ?? PrototypeSession();
  final navigation = ShellNavigation();
  final scrolls = [for (final _ in AppDestination.values) ScrollController()];
  final newMenu = MenuController();
  final newFirstItem = FocusNode(debugLabel: 'New menu first item');
  bool? expanded;
  bool opening = false;
  double dockHeight = 0;
  @override
  void dispose() {
    final life = session.life;
    if (life is DurableLifeController) life.device?.navigate = null;
    for (final controller in scrolls) {
      controller.dispose();
    }
    navigation.dispose();
    newFirstItem.dispose();
    if (widget.session == null) session.dispose();
    super.dispose();
  }

  void select(AppDestination destination) => navigation.select(destination);

  /// Opens [page] in the content area, so the Windows sidebar stays.
  Future<void> open(Widget page, String name, {String? title}) async {
    final content = navigation.navigatorKey.currentContext;
    if (opening || content == null) return;
    opening = true;
    try {
      await openDemoPage<void>(content, page, name, title: title);
    } finally {
      opening = false;
    }
  }

  /// Overview links go to the section and tab that hold the source.
  void source(PreviewSource source) {
    if (session.production &&
        ![
          PreviewSource.accounts,
          PreviewSource.activity,
          PreviewSource.cards,
          PreviewSource.planning,
          PreviewSource.reports,
          PreviewSource.electricity,
          PreviewSource.debt,
          PreviewSource.debtHistory,
          PreviewSource.group,
          PreviewSource.settlement,
          PreviewSource.privateReview,
          PreviewSource.agenda,
          PreviewSource.task,
          PreviewSource.learning,
          PreviewSource.books,
          PreviewSource.career,
        ].contains(source)) {
      open(
        FinancePage(title: source.label, child: UpcomingView(source.label)),
        'upcoming/${source.name}',
      );
      return;
    }
    navigation.select(
      source.destination,
      tab: switch (source) {
        PreviewSource.accounts => 'Accounts',
        PreviewSource.activity => 'Activity',
        PreviewSource.cards => 'Cards',
        PreviewSource.planning || PreviewSource.electricity => 'Planning',
        PreviewSource.reports => 'Reports',
        PreviewSource.debt || PreviewSource.debtHistory => null,
        PreviewSource.group => 'Bills',
        PreviewSource.settlement => 'Payments',
        PreviewSource.privateReview => 'Private review',
        PreviewSource.task => 'Tasks',
        PreviewSource.learning => 'Learning',
        PreviewSource.books => 'Books',
        PreviewSource.career => 'Career',
        PreviewSource.agenda => 'Calendar',
      },
    );
  }

  /// Opens Profile and settings, on [section] for a local profile.
  void utilities([String section = 'Profile']) => open(
    ProfileUtilities(
      settings: widget.settings,
      session: session,
      initialSection: section,
    ),
    'profile',
    title: section == 'Profile' ? 'Profile and settings' : section,
  );

  LocalSession? get local =>
      session is LocalSession ? session as LocalSession : null;

  /// The sidebar's profile menu. The demo profile has no tabs.
  List<SidebarLink> get profileLinks => [
    (
      label: 'Profile and settings',
      icon: Icons.person_outline,
      onSelected: utilities,
    ),
    if (local != null)
      for (final (label, icon) in const [
        ('Connection', Icons.cloud_outlined),
        ('Devices', Icons.devices_outlined),
        ('Backup & recovery', Icons.restore),
      ])
        (label: label, icon: icon, onSelected: () => utilities(label)),
  ];

  /// Each section's tabs, mirroring the tab lists in the section screens.
  Map<AppDestination, List<String>> get sectionTabs {
    final life = session.life;
    return {
      AppDestination.money: const [
        'Accounts',
        'Activity',
        'Cards',
        'Planning',
        'Reports',
        'Import',
        'Files',
      ],
      AppDestination.debts: const [
        'Summary',
        'Schedule',
        'Payments',
        'History',
      ],
      AppDestination.shared: const [
        'Bills',
        'Payments',
        'Balances',
        'People',
        'Private review',
        'History',
        'Lifecycle',
      ],
      AppDestination.life: [
        for (final tab in const [
          'Calendar',
          'Tasks',
          'Learning',
          'Books',
          'Career',
        ])
          if (life is! DurableLifeController ||
              tab == 'Calendar' ||
              life.tabVisible(tab))
            tab,
      ],
    };
  }

  /// Payments between members waiting for your confirmation.
  int get toConfirm =>
      local?.runtime.connected.needMyConfirmation ??
      (session.receipt == DemoReceipt.awaiting ? 1 : 0);

  /// What needs the user, from existing counts only.
  List<SidebarNotice> get notices {
    final waiting = local?.pendingCount ?? (session.pending ? 1 : 0);
    return [
      if (toConfirm > 0)
        SidebarNotice(
          toConfirm == 1
              ? '1 payment to confirm'
              : '$toConfirm payments to confirm',
          icon: Icons.how_to_reg_outlined,
          tone: PillTone.warning,
          onTap: () =>
              navigation.select(AppDestination.shared, tab: 'Payments'),
        ),
      if (waiting > 0)
        SidebarNotice(
          '$waiting waiting to sync',
          icon: Icons.cloud_upload_outlined,
          onTap: () => utilities('Connection'),
        ),
      if (session.needsReview)
        SidebarNotice(
          'Sync needs review',
          icon: Icons.error_outline,
          tone: PillTone.warning,
          onTap: () => utilities('Connection'),
        ),
    ];
  }

  /// Go to: sections, their tabs, create actions and settings pages.
  List<GoToEntry> get goToEntries {
    final created = <String>{};
    return [
      for (final destination in AppDestination.values)
        GoToEntry(
          destination.label,
          icon: destinationIcon(destination),
          id: 'choose-${destination.name}',
          onSelected: () => select(destination),
        ),
      for (final MapEntry(key: destination, value: tabs) in sectionTabs.entries)
        for (final tab in tabs)
          GoToEntry(
            tab,
            where: destination.label,
            icon: destinationIcon(destination),
            onSelected: () => navigation.select(destination, tab: tab),
          ),
      for (final destination in AppDestination.values)
        for (final item in newItemsFor(destination))
          if (created.add(item.$1))
            GoToEntry(
              item.$2,
              where: 'New',
              icon: item.$3,
              onSelected: () => runNew(item),
            ),
      for (final link in profileLinks)
        GoToEntry(
          link.label,
          where: link.label == 'Profile and settings'
              ? null
              : 'Profile and settings',
          icon: link.icon,
          onSelected: link.onSelected,
        ),
      if (local != null)
        GoToEntry(
          'Help',
          where: 'Profile and settings',
          icon: Icons.help_outline,
          onSelected: () => utilities('Help'),
        ),
    ];
  }

  void goTo() => showGoTo(context, goToEntries);

  List<NewItem> get newItems => newItemsFor(navigation.destination);

  List<NewItem> newItemsFor(AppDestination destination) {
    final List<NewItem> items = switch (destination) {
      AppDestination.overview || AppDestination.money => [
        ('Add expense', 'Log expense', Icons.remove_circle_outline),
        ('Record income', 'Log income', Icons.add_circle_outline),
        ('Transfer money', 'Log a transfer', Icons.swap_horiz),
        (
          'Record debt payment',
          'Log a debt payment',
          Icons.event_note_outlined,
        ),
        ('Add shared expense', 'Add shared expense', Icons.people_outline),
        ('Add task', 'Add task', Icons.check_circle_outline),
      ],
      AppDestination.debts => [
        ('Record payment', 'Log a debt payment', Icons.event_note_outlined),
        ('Add existing debt', 'Add a debt', Icons.add),
        ('Record borrowing', 'Log a new loan', Icons.account_balance_outlined),
      ],
      AppDestination.shared => [
        ('Add shared expense', 'Add shared expense', Icons.people_outline),
        (
          'Report payment',
          'Log a payment between members',
          Icons.payments_outlined,
        ),
      ],
      AppDestination.life => [
        ('Add task', 'Add task', Icons.check_circle_outline),
        ('Add event', 'Add event', Icons.event_outlined),
      ],
    };
    return [
      for (final item in items)
        if (!session.production ||
            [
              'Add expense',
              'Record income',
              'Transfer money',
              'Record payment',
              'Record debt payment',
              'Add existing debt',
              'Record borrowing',
              'Add task',
              'Add event',
            ].contains(item.$1))
          item,
    ];
  }

  void runNew(NewItem item) {
    final (key, label, _) = item;
    final content = navigation.navigatorKey.currentContext ?? context;
    if (key == 'Add task') {
      editLifeEntry(content, session, LifeKind.task);
    } else if (key == 'Add event') {
      editPersonalEvent(content, session);
    } else {
      open(actionPage(key, label), 'action/$key', title: label);
    }
  }

  /// Android: the + button's bottom sheet.
  Future<void> showNewSheet() async {
    final items = newItems;
    final chosen = await showAppSheet<int>(
      context,
      title: 'New',
      primary: null,
      body: Builder(
        builder: (context) => ListGroup(
          leading: true,
          children: [
            for (final (i, (_, label, icon)) in items.indexed)
              ListRow(
                title: label,
                leading: icon,
                onTap: () => Navigator.pop(context, i),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) runNew(items[chosen]);
  }

  Widget actionPage(String key, String label) {
    if (session.production &&
        [
          'Record payment',
          'Record debt payment',
          'Add existing debt',
          'Record borrowing',
        ].contains(key)) {
      return NativeFinanceEditor(
        controller: session.finance as LocalFinancialController,
        operation: switch (key) {
          'Add existing debt' => 'debtImport',
          'Record borrowing' => 'borrowing',
          _ => 'debtPayment',
        },
        title: label,
      );
    }
    final action = switch (key) {
      'Add expense' => FinancialAction.expense,
      'Record income' => FinancialAction.income,
      'Transfer money' => FinancialAction.transfer,
      'Record payment' || 'Record debt payment' => FinancialAction.debtPayment,
      'Add existing debt' => FinancialAction.debtImport,
      'Record borrowing' => FinancialAction.borrowing,
      'Add shared expense' => FinancialAction.sharedBill,
      'Report payment' => FinancialAction.settlement,
      _ => null,
    };
    if (action == null) return DemoActionPage(label: label);
    if (!session.complete) {
      return const DemoPage(
        title: 'History unavailable',
        child: Text(
          'Complete the demo snapshot before recording financial actions. Your balances are not known yet.',
        ),
      );
    }
    return FinancialEditor(controller: session.finance, action: action);
  }

  /// System Back and Esc: close the top page; on Android, return to Overview
  /// before leaving the app.
  void back(bool desktop) {
    if (navigation.hasPages) {
      navigation.navigatorKey.currentState?.maybePop();
    } else if (!desktop) {
      select(AppDestination.overview);
    }
  }

  void pointer(PointerDownEvent event) {
    if (event.buttons & kBackMouseButton != 0) {
      navigation.goBack();
    } else if (event.buttons & kForwardMouseButton != 0) {
      navigation.goForward();
    }
  }

  ShellStatus get status => !session.production
      ? (
          label: 'Demo · ${session.syncLabel}',
          icon: Icons.science_outlined,
          tone: PillTone.neutral,
        )
      : session.local
      ? (
          label: 'On this device only',
          icon: Icons.lock_outline,
          tone: PillTone.neutral,
        )
      : (
          label: session.syncLabel,
          icon: session.needsReview
              ? Icons.error_outline
              : Icons.cloud_outlined,
          tone: session.needsReview ? PillTone.warning : PillTone.neutral,
        );

  Widget syncStatus() =>
      StatusPill(status.label, icon: status.icon, tone: status.tone);

  /// The title bar's sync status opens the sync details.
  void syncDetails() => local == null ? utilities() : utilities('Connection');

  /// Opens the New menu with its first item focused, so Esc and the arrow
  /// keys reach the menu before an open page. Focus returns when it closes.
  FocusNode? beforeNewMenu;
  void openNewMenu() {
    beforeNewMenu = FocusManager.instance.primaryFocus;
    newMenu.open();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (newMenu.isOpen) newFirstItem.requestFocus();
    });
  }

  /// Windows: the New menu (Ctrl+N).
  Widget newButton(bool compact) => MenuAnchor(
    controller: newMenu,
    onClose: () {
      final previous = beforeNewMenu;
      beforeNewMenu = null;
      if (previous?.context != null && previous!.canRequestFocus) {
        previous.requestFocus();
      }
    },
    menuChildren: [
      for (final (i, item) in newItems.indexed)
        MenuItemButton(
          focusNode: i == 0 ? newFirstItem : null,
          leadingIcon: Icon(item.$3),
          onPressed: () => runNew(item),
          child: Text(item.$2),
        ),
    ],
    builder: (context, controller, _) {
      void toggle() => controller.isOpen ? controller.close() : openNewMenu();
      return compact
          ? AppIconButton(
              key: const ValueKey('shell-new'),
              icon: Icons.add,
              tooltip: 'New',
              onPressed: toggle,
            )
          : AppBarButton(
              'New',
              key: const ValueKey('shell-new'),
              icon: Icons.add,
              onTap: toggle,
            );
    },
  );

  /// Windows: the location and New above the content; Go to and the sync
  /// state are in the title bar when it is shown ([titleBar]). Android: the
  /// top app bar.
  Widget header(
    BuildContext context, {
    required bool desktop,
    required bool rail,
    required bool titleBar,
  }) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final width = WidthClass.of(context);
    final crumbs = navigation.breadcrumb;
    final title = desktop
        ? Text.rich(
            TextSpan(
              children: [
                for (final (i, crumb) in crumbs.indexed)
                  TextSpan(
                    text: '${i == 0 ? '' : ' › '}${crumb.label}',
                    style: TextStyle(
                      color: i == crumbs.length - 1 ? c.text : c.secondary,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium,
          )
        : Row(
            children: [
              if (navigation.destination == AppDestination.overview) ...[
                const BrandMark(size: Space.xl),
                const SizedBox(width: Space.sm),
              ],
              Expanded(
                child: Text(
                  navigation.destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleLarge,
                ),
              ),
            ],
          );
    final heading = Semantics(header: true, child: title);
    // With the sidebar, Hide amounts, the profile and the sync state live in
    // it; the header keeps the location and New.
    final actions = [
      const SizedBox(width: Space.sm),
      if (desktop) newButton(width == WidthClass.compact),
      if (!rail) ...[
        if (desktop) const SizedBox(width: Space.sm),
        // On Windows the title bar has Hide amounts when it is shown.
        if (!(desktop && titleBar))
          AppIconButton(
            key: const ValueKey('shell-hide-amounts'),
            tooltip: session.hideAmounts ? 'Show amounts' : 'Hide amounts',
            onPressed: session.togglePrivacy,
            icon: session.hideAmounts
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        Tooltip(
          message: 'Profile and settings',
          child: Semantics(
            button: true,
            label: 'Profile and settings',
            excludeSemantics: true,
            child: SizedBox.square(
              dimension: hitTarget(context),
              child: Pressable(
                key: const ValueKey('shell-profile'),
                onTap: utilities,
                radius: Radii.pill,
                child: Center(
                  child: ProfileInitial(name: session.profile.name),
                ),
              ),
            ),
          ),
        ),
      ],
    ];
    if (rail) {
      // Windows with the sidebar: an app bar level with the sidebar's logo
      // row, with its own divider, below the title bar.
      return Container(
        height: Space.appBarHeight,
        padding: EdgeInsets.symmetric(horizontal: Space.pageGutter(width)),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(bottom: BorderSide(color: c.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: ShellBreadcrumb(crumbs: crumbs),
              ),
            ),
            const SizedBox(width: Space.md),
            if (!titleBar) ...[
              if (width == WidthClass.medium)
                AppIconButton(
                  key: const ValueKey('shell-goto'),
                  icon: Icons.search,
                  tooltip: 'Go to (Ctrl+K)',
                  onPressed: goTo,
                )
              else
                SizedBox(
                  width: Space.sidebarWidth,
                  child: GoToField(onTap: goTo),
                ),
              const SizedBox(width: Space.sm),
            ],
            newButton(false),
          ],
        ),
      );
    }
    // The bottom gap keeps the header clear of content scrolling under it.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.pageGutter(width),
        Space.sm,
        Space.pageGutter(width),
        Space.md,
      ),
      // Without the sidebar, the sync pill gets its own full-width row,
      // unless the Windows title bar shows it.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (desktop && !rail) ...[
                AppIconButton(
                  key: const ValueKey('shell-destinations'),
                  icon: Icons.menu,
                  tooltip: 'Go to (Ctrl+K)',
                  onPressed: goTo,
                ),
                const SizedBox(width: Space.sm),
              ],
              Expanded(child: heading),
              ...actions,
            ],
          ),
          if (!(desktop && titleBar)) ...[
            const SizedBox(height: Space.xs),
            syncStatus(),
          ],
        ],
      ),
    );
  }

  Widget section(AppDestination destination) => switch (destination) {
    AppDestination.overview => Overview(
      session: session,
      open: source,
      actions: [
        for (final item in newItemsFor(AppDestination.overview).take(4))
          (label: item.$2, icon: item.$3, onSelected: () => runNew(item)),
      ],
    ),
    AppDestination.money => MoneyScreen(
      key: ValueKey((session.finance, navigation.revisionOf(destination))),
      session: session,
      initial: navigation.tabOf(destination)!,
    ),
    AppDestination.debts => DebtsScreen(
      key: ValueKey((session.finance, navigation.revisionOf(destination))),
      session: session,
      initial: navigation.tabOf(destination),
      actions: [
        for (final item in newItemsFor(AppDestination.debts))
          (label: item.$2, icon: item.$3, onSelected: () => runNew(item)),
      ],
    ),
    AppDestination.shared => SharedScreen(
      key: ValueKey(navigation.revisionOf(destination)),
      session: session,
      initial: navigation.tabOf(destination)!,
    ),
    AppDestination.life => LifeScreen(
      key: ValueKey(navigation.revisionOf(destination)),
      session: session,
      initial: navigation.tabOf(destination)!,
    ),
  };

  /// The five destinations, each keeping its own scroll position. Content is
  /// capped at `Space.contentMaxWidth` and centered.
  Widget destinations(bool showDock) => LayoutBuilder(
    builder: (context, box) {
      final width = WidthClass.of(context);
      final gutter = Space.pageGutter(width);
      final side = (box.maxWidth - Space.contentMaxWidth) / 2;
      final inset = side > gutter ? side : gutter;
      return IndexedStack(
        index: navigation.destination.index,
        sizing: StackFit.expand,
        children: [
          for (final destination in AppDestination.values)
            Scrollbar(
              controller: scrolls[destination.index],
              child: SingleChildScrollView(
                key: PageStorageKey('destination-${destination.name}'),
                controller: scrolls[destination.index],
                padding: EdgeInsets.fromLTRB(
                  inset,
                  Space.pageTop(width),
                  inset,
                  Space.pageBottom(width) + (showDock ? dockHeight : 0),
                ),
                child: section(destination),
              ),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => ShellNavigationScope(
    navigation: navigation,
    child: ListenableBuilder(
      listenable: Listenable.merge([
        session,
        navigation,
        widget.settings,
        ?local?.runtime.connected,
      ]),
      builder: (context, _) {
        final desktop = isDesktop(context);
        final width = WidthClass.of(context);
        final titleBar = TitleBarScope.maybeOf(context) != null;
        final rail = desktop && width != WidthClass.compact;
        final canExpand = width.index >= WidthClass.expanded.index;
        final isExpanded = canExpand && (expanded ?? !widget.settings.compact);
        final paged = navigation.hasPages;
        final showDock =
            !desktop && !paged && MediaQuery.viewInsetsOf(context).bottom == 0;
        return TitleBarSlot(
          items: TitleBarItems(
            navigation: navigation,
            status: status,
            notices: notices,
            hideAmounts: session.hideAmounts,
            sidebarWidth: rail
                ? (isExpanded ? Space.sidebarWidth : Space.railWidth)
                : 0,
            onGoTo: goTo,
            onStatus: syncDetails,
            onHideAmounts: session.togglePrivacy,
            onCalendar: () =>
                navigation.select(AppDestination.life, tab: 'Calendar'),
          ),
          child: PopScope(
            canPop:
                !paged &&
                (desktop || navigation.destination == AppDestination.overview),
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) back(desktop);
            },
            child: CallbackShortcuts(
              bindings: {
                if (desktop) ...{
                  const SingleActivator(
                    LogicalKeyboardKey.arrowLeft,
                    alt: true,
                  ): navigation.goBack,
                  const SingleActivator(
                    LogicalKeyboardKey.arrowRight,
                    alt: true,
                  ): navigation.goForward,
                  const SingleActivator(LogicalKeyboardKey.keyN, control: true):
                      openNewMenu,
                  const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                      goTo,
                  const SingleActivator(LogicalKeyboardKey.keyH, control: true):
                      session.togglePrivacy,
                },
              },
              child: Shortcuts(
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                },
                child: Actions(
                  actions: {DismissIntent: _CloseMenu(newMenu)},
                  child: Listener(
                    onPointerDown: desktop ? pointer : null,
                    child: Focus(
                      autofocus: true,
                      child: Scaffold(
                        body: SafeArea(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Stable Row/Expanded ancestry preserves destination controllers on resize.
                              if (rail)
                                ShellSidebar(
                                  navigation: navigation,
                                  expanded: isExpanded,
                                  profileName: session.profile.name,
                                  status: titleBar ? null : status,
                                  titleBar: titleBar,
                                  quickCreate: [
                                    for (final item in newItems.take(3))
                                      (
                                        label: item.$2,
                                        icon: item.$3,
                                        onSelected: () => runNew(item),
                                      ),
                                  ],
                                  profileLinks: profileLinks,
                                  tabs: sectionTabs,
                                  badges: {AppDestination.shared: toConfirm},
                                  notices: notices,
                                  hideAmounts: session.hideAmounts,
                                  onHideAmounts: session.togglePrivacy,
                                  themeMode: widget.settings.themeMode,
                                  onThemeMode: (mode) => widget.settings.change(
                                    () => widget.settings.themeMode = mode,
                                  ),
                                  onSettings: utilities,
                                  onHelp: () => utilities(
                                    local == null ? 'Profile' : 'Help',
                                  ),
                                  toggle: canExpand
                                      ? () => setState(
                                          () => expanded = !isExpanded,
                                        )
                                      : null,
                                )
                              else
                                const SizedBox.shrink(),
                              Expanded(
                                child: Column(
                                  children: [
                                    if (desktop || !paged)
                                      header(
                                        context,
                                        desktop: desktop,
                                        rail: rail,
                                        titleBar: titleBar,
                                      ),
                                    Expanded(
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // A route's modal barrier hides what is painted
                                          // before it from screen readers, up to the nearest
                                          // container; this keeps the sidebar and header.
                                          Semantics(
                                            container: true,
                                            child: Navigator(
                                              key: navigation.navigatorKey,
                                              observers: [navigation.observer],
                                              pages: [
                                                MaterialPage<void>(
                                                  key: const ValueKey(
                                                    'shell-destinations',
                                                  ),
                                                  child: destinations(showDock),
                                                ),
                                              ],
                                              onDidRemovePage: (_) {},
                                            ),
                                          ),
                                          // The scroll viewport extends behind the dock. Only its
                                          // trailing content padding reserves final-item clearance.
                                          if (showDock)
                                            Positioned(
                                              left: 0,
                                              right: 0,
                                              bottom: 0,
                                              child: MeasureSize(
                                                onChanged: (size) {
                                                  if (mounted &&
                                                      dockHeight !=
                                                          size.height) {
                                                    setState(
                                                      () => dockHeight =
                                                          size.height,
                                                    );
                                                  }
                                                },
                                                child: ShellBottomBar(
                                                  selected:
                                                      navigation.destination,
                                                  select: select,
                                                  onNew: showNewSheet,
                                                ),
                                              ),
                                            ),
                                        ],
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
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Esc closes the New menu while it is open; otherwise the key passes on to
/// the page or the app.
class _CloseMenu extends DismissAction {
  _CloseMenu(this.menu);
  final MenuController menu;
  @override
  bool isEnabled(DismissIntent intent) => menu.isOpen;
  @override
  void invoke(DismissIntent intent) => menu.close();
}
