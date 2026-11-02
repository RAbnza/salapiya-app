import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../prototype/scenarios.dart' show AppDestination;
import 'connection_pages.dart';
import 'profile_data.dart';
import 'profile_source.dart';

/// "Is my data on this device only or syncing, is it healthy, and does
/// anything need me?"
class ConnectionTab extends StatefulWidget {
  const ConnectionTab({
    super.key,
    required this.source,
    required this.backupSaved,
    required this.onSaveBackup,
    required this.current,
  });
  final ProfileSource source;

  /// A backup was saved since this page opened, so switching profile is safe.
  final bool backupSaved;
  final VoidCallback onSaveBackup;

  /// The page's source as it is now, for the pages this opens.
  final ProfileSource Function() current;
  @override
  State<ConnectionTab> createState() => _ConnectionTabState();
}

class _ConnectionTabState extends State<ConnectionTab> {
  ProfileSource get source => widget.source;
  var shownReviews = 50;

  /// What connecting does. It stays this complete on every path here.
  Future<void> disclose() async {
    final a = source.actions;
    final yes = await showConnectionDisclosure(context, email: a.facts().email);
    if (yes == true) await a.confirmConnection();
  }

  Future<void> review() async {
    final a = source.actions;
    await a.lookup();
    if (!mounted) return;
    final f = a.facts();
    // A different profile, or a refusal, has its own words on the tab.
    if (f.error == null && !f.otherProfile) await disclose();
  }

  Future<void> useCloud() async {
    final a = source.actions;
    final yes = await showAdaptiveModal<bool>(
      context,
      title: 'Use ${a.facts().cloudName ?? 'that profile'} on this device?',
      body: const ModalParagraphs([
        'Keep the backup you saved and its recovery secret apart from each '
            'other.',
        'This profile stays on this device, in its own protected files. '
            'Nothing is merged, and you can’t switch back and forth from here.',
      ]),
      primary: const ModalAction('Use that profile', value: true),
    );
    if (yes != true) return;
    await a.useCloudProfile();
    if (mounted && a.facts().error == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> signOut() async {
    final a = source.actions;
    final waiting = a.facts().waiting;
    final yes = await showAdaptiveModal<bool>(
      context,
      title: 'Sign out on this device?',
      body: ModalParagraphs([
        if (waiting > 0)
          waiting == 1
              ? '1 change stays waiting. It uploads after you sign in again.'
              : '$waiting changes stay waiting. They upload after you sign in '
                    'again.',
        'Your records stay on this device, and your account isn’t affected.',
      ]),
      primary: const ModalAction('Sign out', value: true),
    );
    if (yes == true) await a.signOut();
  }

  VoidCallback? run(ConnectionAction action, ConnectionFacts f) {
    final a = source.actions;
    if (f.busy && action != ConnectionAction.cancelSignIn) return null;
    return switch (action) {
      ConnectionAction.connect || ConnectionAction.reconnect => a.connect,
      ConnectionAction.cancelSignIn => a.cancelSignIn,
      ConnectionAction.review => review,
      ConnectionAction.dontConnect => a.signOut,
      ConnectionAction.saveBackup => widget.onSaveBackup,
      ConnectionAction.useCloudProfile => widget.backupSaved ? useCloud : null,
      ConnectionAction.keepProfile => a.keepProfile,
      ConnectionAction.resumeConnection => disclose,
      ConnectionAction.cancelConnection => a.cancelConnection,
      ConnectionAction.syncNow => a.syncNow,
    };
  }

  Widget button(
    ConnectionAction action,
    ConnectionFacts f, {
    required bool main,
  }) {
    final key = ValueKey('connection-${action.name}');
    final press = run(action, f);
    if (action == ConnectionAction.connect ||
        action == ConnectionAction.reconnect) {
      return GoogleSignInButton(key: key, onPressed: press, busy: f.busy);
    }
    final label = switch (action) {
      ConnectionAction.cancelSignIn => 'Cancel sign-in',
      ConnectionAction.review => 'Review connection',
      ConnectionAction.dontConnect => 'Don’t connect',
      ConnectionAction.saveBackup => 'Save a backup',
      ConnectionAction.useCloudProfile => 'Use that profile',
      ConnectionAction.keepProfile => 'Keep this profile',
      ConnectionAction.resumeConnection => 'Finish connecting',
      ConnectionAction.cancelConnection => 'Cancel connection',
      _ => 'Sync now',
    };
    return main
        ? AppButton(label, key: key, onPressed: press, busy: f.busy)
        : AppButton.secondary(label, key: key, onPressed: press);
  }

  @override
  Widget build(BuildContext context) {
    final f = source.connection;
    final phase = phaseOf(f);
    final (headline, why) = phaseWords(f);
    final actions = offered(f);
    final note = signInNote(f.signInOutcome);
    final text = Theme.of(context).textTheme;
    final c = CraftTheme.of(context);
    final sync = OverviewCard(
      key: const ValueKey('connection-sync'),
      title: 'Sync',
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(phaseIcon(phase), onAccent: true),
              const SizedBox(width: Space.md),
              Expanded(child: Text(headline, style: text.titleLarge)),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(why, style: text.bodyMedium?.copyWith(color: c.secondary)),
          if (phase != ConnectionPhase.deleted &&
              (f.connected || f.email != null)) ...[
            const SizedBox(height: Space.sm),
            if (f.connected) FactRow('Last synced', manilaWhen(f.lastSync)),
            if (f.email != null) FactRow('Google account', f.email!),
          ],
          if (f.error != null && !f.deleted) ...[
            const SizedBox(height: Space.sm),
            InlineNotice(f.error!, tone: NoticeTone.warning, live: true),
          ],
          if (note != null) ...[
            const SizedBox(height: Space.sm),
            InlineNotice(note, tone: NoticeTone.warning, live: true),
          ],
          if (phase == ConnectionPhase.otherProfile && !widget.backupSaved) ...[
            const SizedBox(height: Space.sm),
            Text(
              'Save a backup first. Then you can switch to '
              '${f.cloudName ?? 'that profile'}.',
              style: text.bodySmall?.copyWith(color: c.secondary),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (i, action) in actions.indexed)
                  button(action, f, main: i == 0),
              ],
            ),
          ],
        ],
      ),
    );
    final shared = WhatIsShared(connected: f.connected);
    final waiting = _Waiting(source: source);
    final toCheck = source.reviews.isEmpty
        ? null
        : _Reviews(
            rows: source.reviews,
            shown: shownReviews,
            onMore: () => setState(() => shownReviews += 50),
            onOpen: (row) => openDemoPage<void>(
              context,
              ChangePage(id: row.id, current: widget.current),
              'profile/change',
              title: row.title,
            ),
          );
    final device = canManageSync(f)
        ? _ThisDevice(source: source, onSignOut: signOut)
        : null;
    if (!f.connected) {
      return DashboardGrid(
        key: const ValueKey('connection-grid'),
        cards: isDesktop(context) ? [(sync, 8, 12), (shared, 4, 12)] : null,
        stacked: [sync, shared],
      );
    }
    return DashboardGrid(
      key: const ValueKey('connection-grid'),
      cards: isDesktop(context)
          ? [
              (sync, 8, 12),
              (waiting, 4, 12),
              ?(toCheck == null ? null : (toCheck, 12, 12)),
              ?(device == null ? null : (device, 6, 12)),
              (shared, device == null ? 12 : 6, 12),
            ]
          : null,
      stacked: [sync, ?toCheck, waiting, ?device, shared],
    );
  }
}

IconData phaseIcon(ConnectionPhase phase) => switch (phase) {
  ConnectionPhase.local ||
  ConnectionPhase.unavailable ||
  ConnectionPhase.deleted => Icons.lock_outline,
  ConnectionPhase.signingIn || ConnectionPhase.chosen => Icons.login,
  ConnectionPhase.signedOut => Icons.logout,
  ConnectionPhase.paused => Icons.pause_circle_outline,
  ConnectionPhase.syncing ||
  ConnectionPhase.firstDownload ||
  ConnectionPhase.restoring => Icons.sync,
  ConnectionPhase.unreachable => Icons.cloud_off_outlined,
  ConnectionPhase.synced => Icons.cloud_done_outlined,
  ConnectionPhase.waiting => Icons.cloud_upload_outlined,
  _ => Icons.error_outline,
};

class _Waiting extends StatelessWidget {
  const _Waiting({required this.source});
  final ProfileSource source;
  @override
  Widget build(BuildContext context) {
    final f = source.connection;
    final go = source.goTo;
    return OverviewCard(
      key: const ValueKey('connection-waiting'),
      title: 'Waiting and to check',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListGroup(
            children: [
              AdaptiveRow(
                key: const ValueKey('waiting-money'),
                leading: Icons.account_balance_wallet_outlined,
                title: 'Money',
                subtitle: countsLine(f.moneyWaiting, f.moneyReview),
                onTap: go == null
                    ? null
                    : () => go(AppDestination.money, 'Activity'),
              ),
              AdaptiveRow(
                key: const ValueKey('waiting-shared'),
                leading: Icons.group_outlined,
                title: 'Shared Expenses',
                // Nothing can clear these yet, so the row says where they
                // are and the bell stays quiet.
                subtitle: f.sharedReview == 0
                    ? countsLine(f.sharedWaiting, 0)
                    : detailLine([
                        if (f.sharedWaiting > 0) '${f.sharedWaiting} waiting',
                        '${f.sharedReview} to check there',
                      ]),
                onTap: go == null
                    ? null
                    : () => go(AppDestination.shared, null),
              ),
              AdaptiveRow(
                key: const ValueKey('waiting-life'),
                leading: Icons.event_note_outlined,
                title: 'Life',
                subtitle: countsLine(f.lifeWaiting, f.lifeReview),
                onTap: f.lifeReview > 0
                    ? source.openLifeChecks
                    : go == null
                    ? null
                    : () => go(AppDestination.life, null),
              ),
            ],
          ),
          const ListEnd(),
        ],
      ),
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({
    required this.rows,
    required this.shown,
    required this.onMore,
    required this.onOpen,
  });
  final List<ReviewRow> rows;
  final int shown;
  final VoidCallback onMore;
  final ValueChanged<ReviewRow> onOpen;
  @override
  Widget build(BuildContext context) {
    final left = rows.length - shown;
    return OverviewCard(
      key: const ValueKey('connection-reviews'),
      title: 'Needs review',
      caption:
          'These aren’t in your balances. Their values stay on this '
          'device.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListGroup(
            children: [
              for (final row in rows.take(shown))
                AdaptiveRow(
                  key: ValueKey('review-${row.id}'),
                  title: row.title,
                  subtitle: row.reason,
                  onTap: () => onOpen(row),
                ),
            ],
          ),
          if (left > 0)
            ShowMore(left: left, onPressed: onMore)
          else
            const ListEnd(),
        ],
      ),
    );
  }
}

class _ThisDevice extends StatelessWidget {
  const _ThisDevice({required this.source, required this.onSignOut});
  final ProfileSource source;
  final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) {
    final f = source.connection;
    final a = source.actions;
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return OverviewCard(
      key: const ValueKey('connection-device'),
      title: 'Sync on this device',
      caption: 'Turn it off to pause',
      toggle: AppSwitch(
        key: const ValueKey('connection-sync-switch'),
        label: 'Sync on this device',
        value: !f.paused,
        onChanged: f.busy ? null : (on) => a.setPaused(!on),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FactRow('Pausing', 'Changes wait here until you turn it on'),
          const FactRow('Signing out', 'Ends this device’s sign-in'),
          const FactRow('Neither', 'Deletes your account or your records'),
          const SizedBox(height: Space.xs),
          if (f.busy)
            Text(
              'Sign out is available once this finishes.',
              style: text.bodySmall?.copyWith(color: c.secondary),
            )
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CardLink(
                'Sign out',
                key: const ValueKey('connection-sign-out'),
                onPressed: onSignOut,
              ),
            ),
        ],
      ),
    );
  }
}
