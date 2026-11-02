import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../design_system/welcome_frame.dart';
import '../profile/connection_pages.dart';
import '../profile/profile_data.dart';
import 'onboarding_actions.dart';
import 'onboarding_data.dart';
import 'records_map.dart';

/// "What happens next, and what leaves this device?" Google with no profile
/// open. One page, by state, and the same disclosure as the Connection tab.
class GooglePage extends StatefulWidget {
  const GooglePage({super.key, required this.actions, this.onDone});
  final OnboardingActions actions;

  /// A profile opened. By default every first-run page closes.
  final VoidCallback? onDone;
  @override
  State<GooglePage> createState() => _GooglePageState();
}

class _GooglePageState extends State<GooglePage> {
  OnboardingActions get a => widget.actions;

  /// Something was tried on this page, so an error is about that. One left
  /// over from opening the app isn't.
  bool acted = false;
  bool done = false;
  @override
  void initState() {
    super.initState();
    a.changes.addListener(finish);
  }

  @override
  void dispose() {
    a.changes.removeListener(finish);
    super.dispose();
  }

  /// The profile opens under this page, part-way through connecting. The
  /// first download carries on, and the shell says how it's going.
  void finish() {
    if (done || !a.profileOpen) return;
    done = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final close = widget.onDone;
      if (close != null) {
        close();
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  Future<void> connect() async {
    setState(() => acted = true);
    await a.connect();
  }

  /// Looks the account up, then says what connecting does for it.
  Future<void> review() async {
    setState(() => acted = true);
    await a.lookup();
    if (!mounted) return;
    final f = a.facts();
    if (f.error != null) return;
    final found = f.cloudName;
    final new_ = a.newProfileName();
    final yes = await showConnectionDisclosure(
      context,
      email: f.email,
      title: found == null
          ? 'Create a connected profile?'
          : 'Use $found on this device?',
      confirm: found == null ? 'Create profile' : 'Use this profile',
      lead: found == null
          ? 'This Google account has no profile yet, so Salapiya creates one '
                'named $new_. It can’t become a local-only profile later: the '
                'ways out are pausing sync, signing out, removing it from this '
                'device, or deleting the account.'
          : 'Salapiya found $found on this Google account. It downloads to '
                'this device, and nothing here needs uploading. To undo this, '
                'remove it in Profile and settings › Devices. Your account '
                'isn’t affected.',
    );
    if (yes == true) await a.confirmConnection();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: a.changes,
    builder: (context, _) {
      final f = a.facts();
      final phase = phaseOf(f);
      final actions = offered(f);
      final text = Theme.of(context).textTheme;
      final c = CraftTheme.of(context);
      final note = noProfileNote(f.signInOutcome);
      final notices = [
        if (acted && f.error != null)
          InlineNotice(
            noProfileError(f.error!),
            tone: NoticeTone.warning,
            live: true,
          ),
        if (note != null)
          InlineNotice(note, tone: NoticeTone.warning, live: true),
      ];
      final words = TextStyle(color: c.secondary);
      final card = OverviewCard(
        key: const ValueKey('google-state'),
        title: switch (phase) {
          ConnectionPhase.signingIn => 'Waiting for Google',
          ConnectionPhase.chosen => 'Google account chosen',
          ConnectionPhase.unavailable => 'Can’t connect in this build',
          _ => 'What happens next',
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...switch (phase) {
              ConnectionPhase.signingIn => [
                Text(
                  'Finish choosing your account in your browser. If you '
                  'closed it, cancel and start again.',
                  style: text.bodyMedium?.merge(words),
                ),
              ],
              ConnectionPhase.chosen => [
                if (f.email != null) FactRow('Google account', f.email!),
                Text(
                  'Nothing has been downloaded or created yet.',
                  style: text.bodyMedium?.merge(words),
                ),
              ],
              ConnectionPhase.unavailable => [
                Text(
                  'This version of Salapiya can’t connect to Google.',
                  style: text.bodyMedium?.merge(words),
                ),
              ],
              _ => const [
                _Step(1, 'Google opens in your browser. Choose your account.'),
                _Step(
                  2,
                  'Salapiya looks for a profile on that account, and lists '
                  'this device under your sign-ins.',
                ),
                _Step(
                  3,
                  'You review what happens before anything downloads or is '
                  'created.',
                ),
              ],
            },
            for (final notice in notices) ...[
              const SizedBox(height: Space.sm),
              notice,
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [for (final action in actions) button(action, f)],
              ),
            ],
          ],
        ),
      );
      const shared = WhatIsShared(connected: false);
      final view = phase == ConnectionPhase.chosen
          ? RecordsView.chosen
          : RecordsView.google;
      return WelcomeFrame(
        title: 'Continue with Google',
        caption:
            'Bring your profile to this device, or start one that syncs. '
            'Needs internet.',
        aside: recordsCard(view),
        lead: RecordsMap(view: view, slim: true),
        stacked: [card, shared],
        child: SideStack(top: card, rest: shared),
      );
    },
  );

  Widget button(ConnectionAction action, ConnectionFacts f) => switch (action) {
    ConnectionAction.cancelSignIn => AppButton.secondary(
      'Cancel sign-in',
      key: const ValueKey('google-cancel'),
      onPressed: a.cancelSignIn,
    ),
    ConnectionAction.review => AppButton(
      'Review connection',
      key: const ValueKey('google-review'),
      busy: f.busy,
      onPressed: f.busy ? null : review,
    ),
    ConnectionAction.dontConnect => AppButton.tertiary(
      'Don’t connect',
      key: const ValueKey('google-dont-connect'),
      onPressed: f.busy ? null : a.dontConnect,
    ),
    _ => GoogleSignInButton(
      key: const ValueKey('google-sign-in'),
      busy: f.busy,
      onPressed: f.busy ? null : connect,
    ),
  };
}

/// One step of what happens next.
class _Step extends StatelessWidget {
  const _Step(this.number, this.words);
  final int number;
  final String words;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: Space.xl,
            height: Space.xl,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.selection,
            ),
            child: Text(
              '$number',
              style: text.labelMedium?.copyWith(color: c.onSelection),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(child: Text(words, style: text.bodyMedium)),
        ],
      ),
    );
  }
}
