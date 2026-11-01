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
