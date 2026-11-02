import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart' show LocalRuleException;
import 'profile_data.dart';
import 'profile_source.dart';

/// How long the server accepts a Google sign-in for deleting an account.
const deleteWindow = Duration(minutes: 5);

/// "Which sign-ins have my profile, and is anything wrong with one?"
class DevicesTab extends StatefulWidget {
  const DevicesTab({super.key, required this.source, required this.onTab});
  final ProfileSource source;
  final ValueChanged<String> onTab;
  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> {
  ProfileSource get source => widget.source;
  List<DeviceRow>? devices;
  bool loading = false, working = false;
  String? problem, message;

  /// Delete's first step: the user asked to sign in again, and when it came
  /// back. The server's own check on the time is what counts.
  bool signingInAgain = false;
  DateTime? signedInAt;
  Timer? window;

  bool canList(ConnectionFacts f) =>
      f.connected && f.configured && !f.deleted && phaseOf(f) != ConnectionPhase.signedOut;

  @override
  void initState() {
    super.initState();
    // After the first frame: this reaches the service.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && canList(source.actions.facts())) load();
    });
  }

  @override
  void didUpdateWidget(DevicesTab old) {
    super.didUpdateWidget(old);
    final f = source.connection;
    if (!signingInAgain || f.signingIn) return;
    signingInAgain = false;
    if (f.signInOutcome == 'google_code_exchange_verified') {
      signedInAt = DateTime.now();
      window?.cancel();
      window = Timer(deleteWindow, () {
        if (mounted) setState(() => signedInAt = null);
      });
    }
  }

  @override
  void dispose() {
    window?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      problem = null;
    });
    try {
      final rows = await source.actions.devices();
      if (mounted) setState(() => devices = deviceRows(rows));
    } catch (e) {
      if (mounted) {
        setState(
          () => problem = e is LocalRuleException
              ? e.message
              : 'This needs a connection. Try again when you’re online.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> run(Future<void> Function() work, String failure) async {
    setState(() {
      working = true;
      message = null;
      problem = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) {
        setState(
          () => problem = e is LocalRuleException ? e.message : failure,
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> revoke(DeviceRow device) async {
    final yes = await showTypedConfirmation(
      context,
      title: 'Revoke this sign-in?',
      body: device.current
          ? 'This device signs out too. Your records stay on it, and any '
                'waiting changes stay here. Your other devices stay connected.'
          : 'That device loses access to your connected account. What’s '
                'already on it stays there, and can’t be erased from here. '
                'Your other devices stay connected. Signing in with Google '
                'again is a new sign-in.',
      phrase: 'REVOKE',
      action: 'Revoke sign-in',
    );
    if (!yes || !mounted) return;
    await run(() async {
      await source.actions.revoke(device);
      if (device.current) {
        devices = [];
      } else {
        devices = deviceRows(await source.actions.devices());
      }
      message = 'Sign-in revoked. Copies already on that device stay there.';
    }, 'That didn’t finish. Nothing changed. Try again when you’re online.');
  }

  Future<void> signInAgain() async {
    setState(() {
      signingInAgain = true;
      signedInAt = null;
    });
    await source.actions.connect();
  }

  Future<void> deleteAccount() async {
    final waiting = source.connection.waiting;
    final yes = await showTypedConfirmation(
      context,
      title: 'Delete your connected account?',
      body: [
        'This erases your private records from the service and ends every '
            'sign-in. It can’t be undone.',
        if (waiting > 0)
          waiting == 1
              ? '1 waiting change will never upload. Save a backup first if '
                    'you want to keep it.'
              : '$waiting waiting changes will never upload. Save a backup '
                    'first if you want to keep them.',
        'Group bills and payments stay with the other members. A group only '
            'you own is archived, so make someone else the owner first if it '
            'should carry on.',
        'This profile stays on this device until you remove it. Your other '
            'devices and your backups aren’t erased, and your Google account '
            'isn’t deleted.',
      ].join('\n\n'),
      phrase: 'DELETE CONNECTED ACCOUNT',
      action: 'Delete account',
    );
    if (!yes || !mounted) return;
    await run(
      () async {
        final pending = await source.actions.deleteAccount();
        devices = [];
        signedInAt = null;
        message = pending
            ? 'Your records were erased from the service, and every sign-in '
                  'is blocked. One cleanup step is still running on the '
                  'service. This profile stays here.'
            : 'Your connected account was deleted. This profile stays on '
                  'this device until you remove it.';
      },
      'Salapiya couldn’t confirm the deletion. Sign in with Google again and '
      'check. Your records here are safe.',
    );
    // Whatever came back, a retry starts from a fresh sign-in.
    if (mounted) setState(() => signedInAt = null);
  }

  Future<void> remove() async {
    final f = source.connection;
    final yes = await showTypedConfirmation(
      context,
      title: 'Remove this profile from this device?',
      body: [
        f.connected
            ? 'Your connected account, your groups and your other devices '
                  'aren’t affected.'
            : 'This profile is on this device only, so there’s no other '
                  'copy to get back from Salapiya.',
        if (f.waiting > 0)
          f.waiting == 1
              ? '1 waiting change will be lost.'
              : '${f.waiting} waiting changes will be lost.',
        'All records, drafts and encrypted file copies on this device go. '
            'Save a backup and check it first. Backups don’t hold file '
            'contents, so keep your originals.',
        'Backups you’ve saved stay. This works offline, and it doesn’t sign '
            'this device out of the service.',
      ].join('\n\n'),
      phrase: 'REMOVE LOCAL',
      action: 'Remove profile',
    );
    if (!yes || !mounted) return;
    await run(
      source.actions.removeProfile,
      'Removal didn’t finish. Open Salapiya again to carry on. Nothing else '
      'is touched.',
    );
  }

  Widget list(ConnectionFacts f) {
    final rows = devices;
    Widget body;
    if (!canList(f)) {
      body = EmptyState(
        icon: Icons.login,
        title: f.configured
            ? 'Sign in to see your devices'
            : 'This build can’t list devices',
        message: 'Your records are still on this device.',
        action: f.configured
            ? CardLink(
                'Open Connection',
                onPressed: () => widget.onTab('Connection'),
              )
            : null,
      );
    } else if (rows == null && problem != null) {
      body = EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Can’t list your devices',
        message: problem!,
        action: CardLink('Try again', onPressed: load),
      );
    } else if (rows == null) {
      body = const Padding(
        padding: EdgeInsets.all(Space.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListGroup(
            children: [
              for (final d in rows)
                _DeviceRow(
                  key: ValueKey('device-${d.id}'),
                  device: d,
                  onRevoke: d.active && !working ? () => revoke(d) : null,
                ),
            ],
          ),
          const ListEnd(),
        ],
      );
    }
    final active = rows?.where((d) => d.active).length ?? 0;
    return OverviewCard(
      key: const ValueKey('devices-list'),
      title: 'Signed-in devices',
      caption: rows == null
          ? 'One device can show twice after signing in again'
          : '${active == 1 ? '1 active sign-in' : '$active active sign-ins'}. '
                'One device can show twice after signing in again',
      corner: canList(f) && rows != null
          ? AppIconButton(
              key: const ValueKey('devices-refresh'),
              icon: Icons.refresh,
              tooltip: 'Refresh',
              onPressed: load,
            )
          : null,
      child: body,
    );
  }

  Widget removeOrDelete(ConnectionFacts f) {
    final open = signedInAt != null;
    final text = Theme.of(context).textTheme;
    final c = CraftTheme.of(context);
    final busy = working || f.busy;
    return OverviewCard(
      key: const ValueKey('devices-remove'),
      title: 'Remove or delete',
      caption: 'Each one asks you to type what you’re doing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListGroup(
            children: [
              AdaptiveRow(
                key: const ValueKey('remove-profile-row'),
                narrowBelow: Space.xxxl * 5,
                title: 'Remove this profile from this device',
                subtitle: f.connected && !f.deleted
                    ? 'Your connected account stays'
                    : 'There’s no other copy, so save a backup first',
                trailing: busy
                    ? null
                    : CardLink(
                        'Remove',
                        key: const ValueKey('remove-profile'),
                        chevron: false,
                        onPressed: remove,
                      ),
              ),
              if (f.connected && !f.deleted && canList(f))
                AdaptiveRow(
                  key: const ValueKey('delete-account-row'),
                  narrowBelow: Space.xxxl * 5,
                  title: 'Delete your connected account',
                  subtitle: f.signingIn
                      ? 'Finish signing in with Google in your browser'
                      : open
                      ? 'You can delete it for the next five minutes'
                      : 'Sign in with Google again first',
                  trailing: f.signingIn
                      ? CardLink(
                          'Cancel sign-in',
                          key: const ValueKey('delete-cancel-sign-in'),
                          chevron: false,
                          onPressed: source.actions.cancelSignIn,
                        )
                      : busy
                      ? null
                      : CardLink(
                          open ? 'Delete' : 'Sign in again',
                          key: const ValueKey('delete-account'),
                          chevron: false,
                          onPressed: open ? deleteAccount : signInAgain,
                        ),
                ),
            ],
          ),
          if (busy)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(
                'Wait for the current request to finish.',
                style: text.bodySmall?.copyWith(color: c.secondary),
              ),
            ),
          const ListEnd(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = source.connection;
    final remove = removeOrDelete(f);
    final notices = [
      if (message != null)
        InlineNotice(message!, live: true),
      if (problem != null && devices != null)
        InlineNotice(problem!, tone: NoticeTone.warning, live: true),
    ];
    Widget grid;
    if (!f.connected || f.deleted) {
      final here = OverviewCard(
        key: const ValueKey('devices-this'),
        title: 'This device',
        accent: true,
        child: Text(
          f.deleted
              ? 'Your connected account was deleted, so nothing else is '
                    'signed in. This profile stays here until you remove it.'
              : 'This profile is on this device only. Connecting a Google '
                    'account is what puts it on others.',
        ),
      );
      grid = DashboardGrid(
        key: const ValueKey('devices-grid'),
        cards: isDesktop(context) ? [(here, 12, 12), (remove, 12, 12)] : null,
        stacked: [here, remove],
      );
    } else {
      final signedIn = list(f);
      const lost = OverviewCard(
        key: ValueKey('devices-lost'),
        title: 'Lost a device?',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FactRow('First', 'Revoke its sign-in here'),
            FactRow('Then', 'Secure your Google account'),
            FactRow(
              'What it can’t do',
              'Records already on that device can’t be erased from here',
            ),
          ],
        ),
      );
      grid = DashboardGrid(
        key: const ValueKey('devices-grid'),
        cards: isDesktop(context)
            ? [(signedIn, 8, 12), (lost, 4, 12), (remove, 12, 12)]
            : null,
        stacked: [signedIn, lost, remove],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final notice in notices) ...[
          notice,
          SizedBox(height: Space.cardGapOf(context)),
        ],
        grid,
      ],
    );
  }
}

/// One sign-in. The pill stays with the name, so Revoke has the row's end.
class _DeviceRow extends StatelessWidget {
  const _DeviceRow({super.key, required this.device, required this.onRevoke});
  final DeviceRow device;
  final VoidCallback? onRevoke;
  @override
  Widget build(BuildContext context) {
    final d = device;
    final revoke = onRevoke;
    final icon = d.unknown
        ? Icons.help_outline
        : d.name == 'Android'
        ? Icons.phone_android_outlined
        : Icons.laptop_windows_outlined;
    final details = detailLine([
      if (d.unknown) 'Device unknown',
      'Signed in ${d.signedIn}',
      'Last seen ${d.lastSeen}',
    ]);
    final pill = StatusPill(
      d.status,
      icon: d.active ? Icons.check_circle_outline : Icons.block_outlined,
    );
    final link = revoke == null
        ? null
        : CardLink(
            'Revoke',
            key: ValueKey('revoke-${d.id}'),
            chevron: false,
            onPressed: revoke,
          );
    return LayoutBuilder(
      builder: (context, box) => narrowAt(context, box.maxWidth)
          // It knows when the pill no longer fits beside the name.
          ? AdaptiveRow(
              leading: icon,
              title: d.name,
              subtitle: details,
              pill: pill,
              trailing: link,
            )
          : ListRow(
              leading: icon,
              title: d.name,
              subtitle: details,
              titleEnd: pill,
              trailing: link,
            ),
    );
  }
}
