import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../design_system/welcome_frame.dart';
import '../profile/profile_data.dart';
import 'onboarding_actions.dart';
import 'onboarding_data.dart';
import 'records_map.dart';

/// "How do I start, and which way is right for me?"
class WelcomePage extends StatefulWidget {
  const WelcomePage({
    super.key,
    required this.actions,
    required this.onStart,
    required this.onGoogle,
    required this.onRestore,
  });
  final OnboardingActions actions;
  final VoidCallback onStart, onGoogle, onRestore;
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  OnboardingActions get a => widget.actions;
  RecordsView view = RecordsView.local;

  /// Null until it's read. Starting stays on until then: the form says so if
  /// the rule refuses, in the moment before this arrives.
  DeviceStart? start;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final found = await a.deviceStart();
    if (mounted) setState(() => start = found);
  }

  /// Hovering or focusing a choice shows it on the map, so a person can see
  /// what each way does before picking one.
  Widget choice(RecordsView shows, Widget row) => MouseRegion(
    onEnter: (_) => setState(() => view = shows),
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (on) {
        if (on) setState(() => view = shows);
      },
      child: row,
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: a.changes,
    builder: (context, _) {
      final f = a.facts();
      final held = start ?? DeviceStart.fresh;
      final free = !f.busy && !held.unfinished;
      final kept = held.keptName;
      final choices = OverviewCard(
        key: const ValueKey('welcome-choices'),
        title: 'Choose how to start',
        child: ListGroup(
          children: [
            choice(
              RecordsView.local,
              AdaptiveRow(
                key: const ValueKey('welcome-local'),
                title: 'Start on this device',
                subtitle: held.keptFiles
                    ? '${kept ?? 'An earlier profile'}’s files '
                          'are still here, kept safe, so a new profile can’t '
                          'start on this device.'
                    : 'Best if you’re new. No account or internet needed.',
                leading: isDesktop(context)
                    ? Icons.laptop_windows_outlined
                    : Icons.smartphone_outlined,
                onTap: (held.canCreate && free) || (held.unfinished && !f.busy)
                    ? widget.onStart
                    : null,
              ),
            ),
            choice(
              RecordsView.google,
              AdaptiveRow(
                key: const ValueKey('welcome-google'),
                title: 'Continue with Google',
                subtitle: f.configured
                    ? 'Best if you use Salapiya on another device. Needs '
                          'internet.'
                    : 'This version of Salapiya can’t connect to Google.',
                leading: Icons.cloud_outlined,
                onTap: f.configured && free ? widget.onGoogle : null,
              ),
            ),
            choice(
              RecordsView.restore,
              AdaptiveRow(
                key: const ValueKey('welcome-restore'),
                title: 'Restore from backup',
                subtitle:
                    'Best if you have a backup file and its recovery secret.',
                leading: Icons.restore,
                onTap: free ? widget.onRestore : null,
              ),
            ),
          ],
        ),
      );
      final notices = _notices(f, held);
      final top = notices.isEmpty
          ? choices
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final notice in notices) ...[
                  notice,
                  SizedBox(height: Space.cardGapOf(context)),
                ],
                choices,
              ],
            );
      return WelcomeFrame(
        back: false,
        title: 'Set up Salapiya',
        caption:
            'Pick what fits you. If you start on this device, you can connect '
            'Google later.',
        aside: recordsCard(view),
        lead: RecordsMap(view: view, slim: true),
        stacked: [top, const _Privacy()],
        child: SideStack(top: top, rest: const _Privacy()),
      );
    },
  );

  List<Widget> _notices(ConnectionFacts f, DeviceStart held) => [
    if (f.busy)
      const InlineNotice(
        'Connecting to Google. This takes a moment.',
        live: true,
      )
    else if (f.signingIn || f.signedIn)
      InlineNotice(
        f.signingIn
            ? 'You started signing in with Google.'
            : 'You’re signed in with Google. Nothing has been uploaded.',
        action: CardLink(
          'Continue',
          key: const ValueKey('welcome-continue'),
          onPressed: widget.onGoogle,
        ),
      ),
    if (held.unfinished)
      const InlineNotice(
        'A profile is part-way set up here. Start on this device carries on.',
      ),
    if (held.removedLast)
      const InlineNotice(
        'The last profile on this device was removed. Backups and connected '
        'accounts aren’t affected.',
        tone: NoticeTone.neutral,
      ),
  ];
}

class _Privacy extends StatelessWidget {
  const _Privacy();
  @override
  Widget build(BuildContext context) => const OverviewCard(
    key: ValueKey('welcome-privacy'),
    title: 'Your profile and your privacy',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FactRow('On this device', 'One profile at a time'),
        FactRow('Your accounts', 'Cash, bank and cards live inside it'),
        FactRow('Google', 'Optional. Nothing uploads until you confirm'),
        FactRow('Backups', 'Keep the file and its secret apart'),
      ],
    ),
  );
}
