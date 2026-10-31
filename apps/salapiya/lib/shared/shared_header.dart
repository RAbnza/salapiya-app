import 'package:flutter/material.dart';

import '../app/overview_dashboard.dart' show overviewLongDate;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'shared_data.dart';
import 'shared_domain.dart';

/// A group's standing in a line: "You're owed ₱1,250.00", "All square".
String standingLine(SharedStanding s, String Function(BigInt) amount) =>
    switch (s.kind) {
      StandingKind.owedToYou ||
      StandingKind.youOwe => '${s.kind.label} ${amount(s.amount)}',
      _ => s.kind.label,
    };

/// One group in the switcher's words: its standing, or that the user left.
String groupRowLine(SharedGroupRow row, SharedSource source) => row.left
    ? 'You’ve left this group'
    : !source.complete
    ? MoneyAmount.unknown
    : standingLine(row.standing, source.amount);

/// Shared Expenses' header. The group is the page's title, and opens the
/// switcher: the breadcrumb and app bar already name the section. On Windows
/// the actions end the row; on Android it's one 48-tall row with a pill, and
/// the + button has the actions.
class SharedHeader extends StatelessWidget {
  const SharedHeader({
    super.key,
    required this.source,
    required this.group,
    required this.onChoose,
    required this.onCreate,
    required this.onJoin,
    required this.onAll,
    required this.onAbout,
    this.count = 0,
    this.actions = const [],
    this.toConfirm = 0,
    this.onToConfirm,
  });
  final SharedSource source;
  final SharedGroup? group;
  final ValueChanged<String> onChoose;
  final VoidCallback onCreate, onJoin, onAll, onAbout;

  /// Groups to choose from, while no group is open.
  final int count;
  final List<QuickAction> actions;
  final int toConfirm;
  final VoidCallback? onToConfirm;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final date = overviewLongDate(source.today);
    final android = !isDesktop(context);
    if (g == null) {
      if (android) {
        if (count == 0) return const SizedBox.shrink();
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Space.target),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'Choose a group',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        );
      }
      final title = PageHeader(
        count == 0 ? 'Shared Expenses' : 'Choose a group',
        caption: count == 0
            ? 'As of $date'
            : 'As of $date · $count ${count == 1 ? 'group' : 'groups'}',
      );
      return LayoutBuilder(
        builder: (context, box) => actions.isEmpty
            ? title
            : box.maxWidth >= DashboardGrid.four
            ? Row(
                children: [
                  Expanded(flex: 2, child: title),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: QuickActions(
                        key: const ValueKey('shared-quick-actions'),
                        actions: actions,
                        alignment: WrapAlignment.end,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: Space.md),
                  QuickActions(
                    key: const ValueKey('shared-quick-actions'),
                    actions: actions,
                  ),
                ],
              ),
      );
    }
    final switcher = _GroupSwitcher(
      source: source,
      group: g,
      onChoose: onChoose,
      onCreate: onCreate,
      onJoin: onJoin,
      onAll: onAll,
      onAbout: onAbout,
    );
    if (android) {
      final pill = toConfirm == 0
          ? null
          : Semantics(
              button: true,
              label: '$toConfirm to confirm. Open Payments',
              excludeSemantics: true,
              child: Pressable(
                key: const ValueKey('shared-to-confirm'),
                onTap: onToConfirm,
                child: StatusPill(
                  '$toConfirm to confirm',
                  icon: Icons.how_to_reg_outlined,
                  tone: PillTone.warning,
                ),
              ),
            );
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Space.target),
        child: LayoutBuilder(
          builder: (context, box) =>
              pill != null && narrowAt(context, box.maxWidth)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [switcher, pill],
                )
              : Row(
                  children: [
                    Expanded(child: switcher),
                    if (pill != null) ...[
                      const SizedBox(width: Space.sm),
                      pill,
                    ],
                  ],
                ),
        ),
      );
    }
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        switcher,
        const SizedBox(height: Space.captionGap),
        Text(
          'As of $date · ${groupFacts(g)}',
          style: text.bodyMedium?.copyWith(color: c.secondary),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (actions.isEmpty) return heading;
        return box.maxWidth >= DashboardGrid.four
            ? Row(
                children: [
                  Expanded(flex: 2, child: heading),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: QuickActions(
                        key: const ValueKey('shared-quick-actions'),
                        actions: actions,
                        alignment: WrapAlignment.end,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  const SizedBox(height: Space.md),
                  QuickActions(
                    key: const ValueKey('shared-quick-actions'),
                    actions: actions,
                  ),
                ],
              );
      },
    );
  }
}

/// The group's name, opening a menu on Windows and a sheet on Android.
class _GroupSwitcher extends StatelessWidget {
  const _GroupSwitcher({
    required this.source,
    required this.group,
    required this.onChoose,
    required this.onCreate,
    required this.onJoin,
    required this.onAll,
    required this.onAbout,
  });
  final SharedSource source;
  final SharedGroup group;
  final ValueChanged<String> onChoose;
  final VoidCallback onCreate, onJoin, onAll, onAbout;

  Future<void> sheet(BuildContext context) async {
    final rows = sharedGroupRows(source);
    Widget row(BuildContext context, SharedGroupRow r) => AdaptiveRow(
      key: ValueKey('switch-${r.group.id}'),
      title: r.group.name,
      subtitle: groupRowLine(r, source),
      trailing: r.toConfirm > 0
          ? StatusPill(
              '${r.toConfirm}',
              icon: Icons.how_to_reg_outlined,
              tone: PillTone.warning,
            )
          : null,
      onTap: () => Navigator.pop(context, r.group.id),
    );
    final earlier = rows.where((r) => !r.current).toList();
    final chosen = await showAppSheet<String>(
      context,
      title: 'Your groups',
      primary: null,
      body: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListGroup(
              children: [
                for (final r in rows.where((r) => r.current)) row(context, r),
              ],
            ),
            if (earlier.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Text(
                'Archived or left',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: CraftTheme.of(context).secondary),
              ),
              ListGroup(children: [for (final r in earlier) row(context, r)]),
            ],
            const SizedBox(height: Space.sm),
            ListGroup(
              leading: true,
              children: [
                ListRow(
                  title: 'About this group',
                  leading: Icons.info_outline,
                  onTap: () => Navigator.pop(context, 'about'),
                ),
                ListRow(
                  title: 'Create a group',
                  leading: Icons.add,
                  onTap: () => Navigator.pop(context, 'create'),
                ),
                ListRow(
                  title: 'Join with a code',
                  leading: Icons.vpn_key_outlined,
                  onTap: () => Navigator.pop(context, 'join'),
                ),
                ListRow(
                  title: 'See all groups',
                  leading: Icons.list_alt_outlined,
                  onTap: () => Navigator.pop(context, 'all'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    switch (chosen) {
      case null:
        return;
      case 'create':
        onCreate();
      case 'join':
        onJoin();
      case 'all':
        onAll();
      case 'about':
        onAbout();
      default:
        onChoose(chosen);
    }
  }

  List<Widget> menu(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final rows = sharedGroupRows(source);
    Widget item(SharedGroupRow r) => MenuItemButton(
      key: ValueKey('switch-${r.group.id}'),
      onPressed: () => onChoose(r.group.id),
      // Two lines, so taller than the theme's one-line menu row.
      style: MenuItemButton.styleFrom(
        minimumSize: const Size(0, Space.compactTwoLineRow),
      ),
      trailingIcon: r.toConfirm > 0
          ? StatusPill(
              '${r.toConfirm}',
              icon: Icons.how_to_reg_outlined,
              tone: PillTone.warning,
            )
          : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Space.popoverMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(r.group.name, style: text.titleSmall),
            Text(
              groupRowLine(r, source),
              style: text.bodySmall?.copyWith(color: c.secondary),
            ),
          ],
        ),
      ),
    );
    final earlier = rows.where((r) => !r.current).toList();
    return [
      for (final r in rows.where((r) => r.current)) item(r),
      if (earlier.isNotEmpty) ...[
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.sm,
            Space.md,
            Space.xs,
          ),
          child: Text(
            'Archived or left',
            style: text.labelMedium?.copyWith(color: c.secondary),
          ),
        ),
        for (final r in earlier) item(r),
      ],
      const Divider(height: 1),
      MenuItemButton(
        key: const ValueKey('switch-about'),
        leadingIcon: const Icon(Icons.info_outline),
        onPressed: onAbout,
        child: const Text('About this group'),
      ),
      MenuItemButton(
        key: const ValueKey('switch-create'),
        leadingIcon: const Icon(Icons.add),
        onPressed: onCreate,
        child: const Text('Create a group'),
      ),
      MenuItemButton(
        key: const ValueKey('switch-join'),
        leadingIcon: const Icon(Icons.vpn_key_outlined),
        onPressed: onJoin,
        child: const Text('Join with a code'),
      ),
      MenuItemButton(
        key: const ValueKey('switch-all'),
        leadingIcon: const Icon(Icons.list_alt_outlined),
        onPressed: onAll,
        child: const Text('See all groups'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final android = !isDesktop(context);
    Widget name(VoidCallback onTap) => Semantics(
      button: true,
      label: 'Group: ${group.name}. Change group',
      excludeSemantics: true,
      child: Pressable(
        key: const ValueKey('shared-switcher'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (android) ...[
                GroupInitial(group.name),
                const SizedBox(width: Space.sm),
              ],
              Flexible(
                child: Text(
                  group.name,
                  style: android ? text.titleSmall : text.headlineMedium,
                ),
              ),
              const SizedBox(width: Space.xs),
              Icon(Icons.expand_more, size: Space.lg, color: c.secondary),
            ],
          ),
        ),
      ),
    );
    if (android) return name(() => sheet(context));
    return MenuAnchor(
      alignmentOffset: const Offset(0, Space.xs),
      menuChildren: menu(context),
      builder: (context, controller, _) => name(
        () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class GroupInitial extends StatelessWidget {
  const GroupInitial(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return ExcludeSemantics(
      child: Container(
        width: Space.navAvatar,
        height: Space.navAvatar,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.selection, shape: BoxShape.circle),
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: c.onSelection),
        ),
      ),
    );
  }
}
