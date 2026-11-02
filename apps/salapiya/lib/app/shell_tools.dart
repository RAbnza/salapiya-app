import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'shell_navigation.dart';

// The tools both platforms share, from one source (§2 Android parity): the
// bell, the sync status and Hide amounts. The Windows title bar shows them as
// compact pointer controls; Android's app bar and status row at touch size.

/// The bell: what needs the user (payments to confirm, waiting to sync, sync
/// needs review, signed out), each row going where it's handled. A menu on
/// Windows, a bottom sheet on Android.
class NotificationsButton extends StatelessWidget {
  const NotificationsButton({super.key, required this.notices});
  final List<SidebarNotice> notices;

  Widget bell(BuildContext context, VoidCallback onPressed) {
    final c = CraftTheme.of(context);
    final count = notices.length;
    return IconButton(
      key: ValueKey(
        isDesktop(context) ? 'titlebar-notifications' : 'shell-notifications',
      ),
      tooltip: count == 0
          ? 'Notifications'
          : 'Notifications, $count need attention',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        // At large text the count stays inside the badge; the tooltip and
        // screen readers say it.
        label: MediaQuery.withNoTextScaling(child: Text('$count')),
        backgroundColor: c.primary,
        textColor: c.onPrimary,
        child: Icon(
          count == 0
              ? Icons.notifications_none_outlined
              : Icons.notifications_outlined,
        ),
      ),
    );
  }

  Future<void> sheet(BuildContext context) async {
    final c = CraftTheme.of(context);
    final chosen = await showAppSheet<SidebarNotice>(
      context,
      title: 'Needs attention',
      body: notices.isEmpty
          ? const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Nothing needs attention',
              message: 'Payments to confirm and sync problems show here.',
            )
          : Builder(
              builder: (sheet) => ListGroup(
                leading: true,
                children: [
                  for (final notice in notices)
                    ListRow(
                      key: ValueKey('notice-${notice.label}'),
                      title: notice.label,
                      leading: notice.icon,
                      leadingColor: StatusPill.colors(c, notice.tone).$1,
                      onTap: () => Navigator.pop(sheet, notice),
                    ),
                ],
              ),
            ),
      primary: null,
      secondary: const ModalAction.cancel(label: 'Close'),
    );
    chosen?.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop(context)) return bell(context, () => sheet(context));
    final c = CraftTheme.of(context);
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
      builder: (context, controller, _) => bell(
        context,
        () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// The sync status, as a pill that opens the sync details. In the Windows
/// title bar it's icon-only below 600 wide ([compact]), with the label in its
/// tooltip. On Android it sits at the start of the status row, with a 48 hit
/// area, and wraps at large text.
class SyncStatusButton extends StatelessWidget {
  const SyncStatusButton({
    super.key,
    required this.status,
    required this.onTap,
    this.compact = false,
  });
  final ShellStatus status;
  final bool compact;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final pill = StatusPill(status.label, icon: status.icon, tone: status.tone);
    Widget named(Widget child) => Semantics(
      container: true,
      button: true,
      label: 'Sync status, ${status.label}',
      onTap: onTap,
      excludeSemantics: true,
      child: child,
    );
    if (!isDesktop(context)) {
      return named(
        TouchArea(
          onTap: onTap,
          alignment: AlignmentDirectional.centerStart,
          child: Pressable(
            key: const ValueKey('shell-sync'),
            onTap: onTap,
            radius: Radii.pill,
            child: pill,
          ),
        ),
      );
    }
    return Tooltip(
      message: 'Sync status: ${status.label}',
      excludeFromSemantics: true,
      child: named(
        SizedBox(
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
                      child: pill,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hide amounts, an eye reported as a toggle. On Windows its tooltip names
/// the shortcut (Ctrl+H).
class HideAmountsButton extends StatelessWidget {
  const HideAmountsButton({
    super.key,
    required this.hidden,
    required this.onPressed,
  });
  final bool hidden;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final shortcut = isDesktop(context) ? ' (Ctrl+H)' : '';
    return MergeSemantics(
      child: Semantics(
        toggled: hidden,
        child: AppIconButton(
          key: const ValueKey('shell-hide-amounts'),
          icon: hidden
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          tooltip: hidden ? 'Show amounts$shortcut' : 'Hide amounts$shortcut',
          onPressed: onPressed,
        ),
      ),
    );
  }
}
