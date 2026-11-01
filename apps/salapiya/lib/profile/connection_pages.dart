import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'profile_source.dart';

/// One change to check. Sending it goes out under its original identity, so
/// it can't count twice however often it's tried.
class ChangePage extends StatelessWidget {
  const ChangePage({super.key, required this.id, required this.current});
  final String id;
  final ProfileSource Function() current;
  @override
  Widget build(BuildContext context) {
    final start = current();
    return ListenableBuilder(
      listenable: start.listenable,
      builder: (context, _) {
        final source = current();
        final row = source.reviews.where((r) => r.id == id).firstOrNull;
        if (row == null) {
          return const SectionPage(
            title: 'Change to check',
            child: OverviewCard(
              title: 'Change to check',
              child: EmptyState(
                icon: Icons.check_circle_outline,
                title: 'This no longer needs you',
                message: 'It’s on its way, or it has been dealt with.',
              ),
            ),
          );
        }
        final f = source.connection;
        final text = Theme.of(context).textTheme;
        final c = CraftTheme.of(context);
        final why = OverviewCard(
          key: const ValueKey('change-why'),
          title: 'Why this needs a look',
          accent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(row.reason, style: text.bodyMedium),
              const SizedBox(height: Space.sm),
              Text(
                row.canSend
                    ? 'Send it as it was saved. Salapiya checks the service '
                          'first, so it can’t count twice.'
                    : 'It isn’t in your balances. Check your records, then '
                          'log it again if you still need it.',
                style: text.bodyMedium?.copyWith(color: c.secondary),
              ),
              if (f.error != null) ...[
                const SizedBox(height: Space.sm),
                InlineNotice(f.error!, tone: NoticeTone.warning, live: true),
              ],
              if (row.canSend) ...[
                const SizedBox(height: Space.md),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppButton(
                    'Send this change',
                    key: const ValueKey('change-send'),
                    busy: f.busy,
                    onPressed: f.busy
                        ? null
                        : () => source.actions.send(row.id),
                  ),
                ),
              ],
            ],
          ),
        );
        final facts = OverviewCard(
          key: const ValueKey('change-facts'),
          title: 'What it was',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (label, value) in row.facts) FactRow(label, value),
              const SizedBox(height: Space.xs),
              FormMoreDetails(
                label: 'View details',
                children: [
                  FactRow('Change ID', row.id),
                  for (final (label, value) in row.details)
                    FactRow(label, value),
                ],
              ),
            ],
          ),
        );
        return SectionPage(
          title: row.title,
          caption: 'Change to check',
          child: DashboardGrid(
            key: const ValueKey('change-grid'),
            cards: isDesktop(context) ? [(why, 7, 12), (facts, 5, 12)] : null,
            stacked: [why, facts],
          ),
        );
      },
    );
  }
}

/// What connecting does, for every path that connects. Each fact here stays:
/// [lead] adds what this path does, and [title] and [confirm] name it.
Future<bool?> showConnectionDisclosure(
  BuildContext context, {
  required String? email,
  String title = 'Turn on sync?',
  String confirm = 'Turn on sync',
  String? lead,
}) => showAdaptiveModal<bool>(
  context,
  title: title,
  body: ModalParagraphs([
    'Google account: ${email ?? 'Not chosen'}',
    ?lead,
    'This uploads your Money and Life records, proof you’ve added, Career '
        'details and the list of your files to Salapiya’s service, which '
        'runs on Supabase and PowerSync. File contents stay on this '
        'device, and so do drafts and device settings.',
    'Google only confirms who you are. People who run the service can '
        'reach synced records: this isn’t end-to-end encrypted.',
    'Anything already on the service downloads before totals show as '
        'complete.',
  ]),
  primary: ModalAction(confirm, value: true),
);

/// What leaves the device once it's connected.
class WhatIsShared extends StatelessWidget {
  const WhatIsShared({super.key, required this.connected});
  final bool connected;
  @override
  Widget build(BuildContext context) => OverviewCard(
    key: const ValueKey('connection-shared'),
    title: 'What’s shared with the service',
    caption: connected ? null : 'Only once you connect and confirm',
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FactRow(
          'Uploaded',
          'Money and Life records, proof you’ve added, Career details and '
              'the list of your files',
        ),
        FactRow(
          'Stays on this device',
          'File contents, drafts and device settings',
        ),
        FactRow('Google', 'Confirms who you are, and holds none of this'),
        FactRow(
          'Who can reach it',
          'People who run the service. It isn’t end-to-end encrypted',
        ),
      ],
    ),
  );
}
