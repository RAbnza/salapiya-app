import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'profile_data.dart';
import 'profile_source.dart';

/// "Is my data safe, when was my last backup, has anything changed since, and
/// how do I get it back?"
class BackupTab extends StatelessWidget {
  const BackupTab({
    super.key,
    required this.source,
    required this.note,
    required this.loaded,
    required this.failed,
    required this.onSave,
    required this.onCheck,
    required this.onTab,
  });
  final ProfileSource source;

  /// The last backup noted on this device. Null with none.
  final BackupNote? note;
  final bool loaded;

  /// Why a backup failed since this page opened.
  final String? failed;
  final VoidCallback onSave, onCheck;
  final ValueChanged<String> onTab;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = CraftTheme.of(context);
    final f = source.connection;
    final note = this.note;
    final standing = OverviewCard(
      key: const ValueKey('backup-standing'),
      title: 'Your backups',
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(
                note == null
                    ? Icons.shield_outlined
                    : note.changed
                    ? Icons.history
                    : Icons.verified_user_outlined,
                onAccent: true,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  !loaded
                      ? 'Not available yet'
                      : note == null
                      ? 'No backup on this device yet'
                      : 'Last backup ${manilaWhen(note.at)}',
                  style: text.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            !loaded
                ? ' '
                : note == null
                ? f.connected
                      ? 'Sync isn’t a backup: it can carry a mistake to every '
                            'device. Keep a copy somewhere else.'
                      : 'This profile is on this device only. If the device '
                            'is lost, a backup is the only way back.'
                : note.changed
                ? 'Your records have changed since. A new backup would '
                      'include them.'
                : 'Nothing has changed since.',
            style: text.bodyMedium?.copyWith(color: c.secondary),
          ),
          if (failed != null) ...[
            const SizedBox(height: Space.sm),
            InlineNotice(failed!, tone: NoticeTone.error, live: true),
          ],
          if (f.bound == 'restored') ...[
            const SizedBox(height: Space.sm),
            InlineNotice(
              'This profile came from a backup and is still being checked.',
              tone: NoticeTone.warning,
              action: CardLink(
                'Open Connection',
                onPressed: () => onTab('Connection'),
              ),
            ),
          ],
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppButton(
                'Save a backup',
                key: const ValueKey('backup-save'),
                icon: Icons.shield_outlined,
                onPressed: onSave,
              ),
              AppButton.secondary(
                'Check a backup',
                key: const ValueKey('backup-check'),
                onPressed: onCheck,
              ),
            ],
          ),
        ],
      ),
    );
    final back = OverviewCard(
      key: const ValueKey('backup-back'),
      title: 'How to get it back',
      caption: 'A profile in use is never replaced',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: f.connected
            ? const [
                FactRow(
                  'New device',
                  'Sign in with Google: what has synced '
                      'downloads by itself',
                ),
                FactRow(
                  'Not synced yet',
                  'That needs a backup, or a device '
                      'that still has it',
                ),
              ]
            : const [
                FactRow('Open', 'Salapiya on a new device, or with no profile'),
                FactRow('Choose', 'Restore from backup'),
                FactRow('Have ready', 'The backup and its recovery secret'),
              ],
      ),
    );
    final inside = OverviewCard(
      key: const ValueKey('backup-inside'),
      title: 'What’s in a backup',
      caption: 'It’s encrypted with a recovery secret only you keep',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FactRow(
            'In it',
            'Money and Life records and their history, waiting changes, '
                'saved drafts and settings',
          ),
          const FactRow(
            'Not in it',
            'File contents, sign-ins and notification choices. Reminders '
                'start off after a restore',
          ),
          FactRow('Your files', filesLine(source.filesListed)),
          const FactRow(
            'Groups',
            'A record of what happened. It doesn’t bring back a place in a '
                'group',
          ),
        ],
      ),
    );
    return DashboardGrid(
      key: const ValueKey('backup-grid'),
      cards: isDesktop(context)
          ? [(standing, 8, 12), (back, 4, 12), (inside, 12, 12)]
          : null,
      stacked: [standing, inside, back],
    );
  }
}
