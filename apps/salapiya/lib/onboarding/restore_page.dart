import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../design_system/welcome_frame.dart';
import '../local/finance_domain.dart' show LocalRuleException;
import '../profile/profile_actions.dart' show backupSecretErrors;
import '../profile/profile_data.dart';
import 'onboarding_actions.dart';
import 'onboarding_data.dart';
import 'records_map.dart';

/// "Is this the right backup, what will I get back, and what won't I?"
///
/// The secret is masked, learns nothing, and is cleared once the backup opens.
/// The opened backup stays only until it's restored or this page goes.
class RestorePage extends StatefulWidget {
  const RestorePage({super.key, required this.actions, this.onDone});
  final OnboardingActions actions;

  /// Finished. By default every first-run page closes.
  final VoidCallback? onDone;
  @override
  State<RestorePage> createState() => _RestorePageState();
}

class _RestorePageState extends State<RestorePage> {
  OnboardingActions get a => widget.actions;
  final secret = TextEditingController();
  PickedBackup? file;
  OpenedBackup? opened;

  /// What came back, kept after the backup itself has gone.
  BackupContents? restored;
  bool busy = false;

  /// A first try got part-way, so the next one carries on from there. Doing
  /// it again would be refused by the check the first try set.
  bool resuming = false;
  String? fileError, secretError, error;
  @override
  void dispose() {
    secret.dispose();
    super.dispose();
  }

  Future<void> choose() async {
    setState(() {
      busy = true;
      fileError = null;
    });
    try {
      final picked = await a.pickBackup();
      if (!mounted) return;
      if (picked != null) setState(() => file = picked);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => fileError = e is LocalRuleException
            ? e.message
            : 'That file couldn’t be read. Nothing changed.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open() async {
    setState(() {
      busy = true;
      fileError = null;
      secretError = null;
    });
    try {
      final found = await a.open(file!, secret.text);
      if (!mounted) return;
      setState(() {
        opened = found;
        file = null;
        secret.clear();
      });
    } catch (e) {
      if (!mounted) return;
      final why = e is LocalRuleException
          ? e.message
          : 'That file couldn’t be opened. Nothing changed.';
      setState(() {
        if (backupSecretErrors.any(why.contains)) {
          secretError = why;
        } else {
          fileError = why;
        }
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void startOver() => setState(() {
    opened = null;
    error = null;
  });

  Future<void> restore() async {
    final backup = opened!;
    final name = backup.contents.name;
    if (!resuming) {
      final yes = await showAdaptiveModal<bool>(
        context,
        title: 'Restore $name on this device?',
        body: ModalParagraphs([
          '$name becomes the profile on this device. Your backup file doesn’t '
              'change.',
          'To undo this, remove it in Profile and settings › Devices.',
        ]),
        primary: const ModalAction('Restore', value: true),
      );
      if (yes != true || !mounted) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (resuming) {
        await a.resume();
      } else {
        await a.restore(backup);
      }
      if (!mounted) return;
      setState(() {
        restored = backup.contents;
        opened = null;
        busy = false;
      });
    } catch (e) {
      final why = e is LocalRuleException
          ? e.message
          : 'The restore didn’t finish. Your backup file is safe. Try again.';
      DeviceStart? start;
      try {
        start = await a.deviceStart();
      } catch (_) {
        // Without it, Try again restores from the start.
      }
      if (!mounted) return;
      setState(() {
        busy = false;
        error = why;
        resuming = start != null && !start.canCreate && !start.keptFiles;
      });
    }
  }

  void done() {
    final close = widget.onDone;
    if (close != null) {
      close();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final back = restored;
    if (back != null) {
      return WelcomeFrame(
        back: false,
        title: '${back.name} is back on this device',
        caption: 'Your records are ready.',
        child: _Finished(
          contents: back,
          demo: a.demo,
          actions: finishedActions(back),
        ),
      );
    }
    final found = opened;
    final view = found?.contents.connected == true
        ? RecordsView.restoreConnected
        : RecordsView.restore;
    final card = found == null
        ? form(context)
        : _Review(
            backup: found,
            footer: [
              if (error != null) ...[
                const SizedBox(height: Space.md),
                InlineNotice(error!, tone: NoticeTone.error, live: true),
              ],
              const SizedBox(height: Space.md),
              reviewActions(found),
            ],
          );
    return PopScope(
      canPop: !busy,
      child: WelcomeFrame(
        title: 'Restore from backup',
        step: found == null
            ? 'Step 1 of 2 · Your backup'
            : 'Step 2 of 2 · Check and restore',
        caption: found == null
            ? 'A backup opens only with its recovery secret. Salapiya can’t '
                  'recover the secret for you.'
            : 'See what comes back and what doesn’t. Nothing has changed yet.',
        aside: recordsCard(view),
        lead: RecordsMap(view: view, slim: true),
        stacked: [card, if (found == null) const _WhatComesBack()],
        child: found == null
            ? SideStack(top: card, rest: const _WhatComesBack())
            : card,
      ),
    );
  }

  Widget form(BuildContext context) {
    final chosen = file;
    return OverviewCard(
      key: const ValueKey('restore-form'),
      title: 'Your backup',
      child: CompactForm(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HelpField(
                  key: const ValueKey('restore-file'),
                  label: 'Backup file',
                  errorText: fileError,
                  helper: chosen?.name ?? 'It ends in .salapiya',
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppButton.secondary(
                      chosen == null
                          ? 'Choose backup file'
                          : 'Choose another file',
                      key: const ValueKey('restore-choose'),
                      icon: Icons.folder_open_outlined,
                      onPressed: busy ? null : choose,
                    ),
                  ),
                ),
                SizedBox(height: CompactForm.fieldGap(context)),
                SecretField(
                  controller: secret,
                  errorText: secretError,
                  helper: 'The one you kept with this backup',
                  onChanged: () => setState(() => secretError = null),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(top: CompactForm.groupGap(context)),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: AppButton(
                  'Open backup',
                  key: const ValueKey('restore-open'),
                  busy: busy,
                  onPressed: busy || chosen == null || secret.text.isEmpty
                      ? null
                      : open,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget reviewActions(OpenedBackup found) => Wrap(
    alignment: WrapAlignment.end,
    spacing: Space.sm,
    runSpacing: Space.sm,
    children: [
      AppButton.tertiary(
        'Choose another backup',
        key: const ValueKey('restore-again'),
        onPressed: busy ? null : startOver,
      ),
      if (!found.alreadyHere)
        AppButton(
          resuming ? 'Try again' : 'Restore this backup',
          key: const ValueKey('restore-confirm'),
          busy: busy,
          onPressed: busy ? null : restore,
        ),
    ],
  );

  Widget finishedActions(BackupContents back) => Wrap(
    alignment: WrapAlignment.end,
    spacing: Space.sm,
    runSpacing: Space.sm,
    children: [
      if (back.connected && !a.demo) ...[
        AppButton.tertiary(
          'Not now',
          key: const ValueKey('restore-open-app'),
          onPressed: done,
        ),
        AppButton(
          'Go to Connection',
          key: const ValueKey('restore-connection'),
          onPressed: () => a.openConnectionTab(context),
        ),
      ] else
        AppButton(
          'Open Salapiya',
          key: const ValueKey('restore-open-app'),
          onPressed: done,
        ),
    ],
  );
}

/// What any backup brings back, before one is chosen.
class _WhatComesBack extends StatelessWidget {
  const _WhatComesBack();
  @override
  Widget build(BuildContext context) => const OverviewCard(
    key: ValueKey('restore-holds'),
    title: 'What comes back',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FactRow(
          'Comes back',
          'Your records and their history, waiting changes, saved drafts and '
              'settings',
        ),
        FactRow(
          'Doesn’t',
          'File contents, sign-ins and notification choices. Reminders start '
              'off',
        ),
      ],
    ),
  );
}

/// What's in the backup, and what doesn't come back with it.
class _Review extends StatelessWidget {
  const _Review({required this.backup, required this.footer});
  final OpenedBackup backup;
  final List<Widget> footer;
  @override
  Widget build(BuildContext context) {
    final b = backup.contents;
    return OverviewCard(
      key: const ValueKey('restore-review'),
      title: 'This backup',
      caption: 'Saved ${manilaWhen(b.created)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FactRow('Profile', b.name),
          FactRow('Records', '${b.records}'),
          FactRow('Life history', '${b.lifeVersions} versions'),
          FactRow('Saved drafts', '${b.drafts}'),
          if (b.connected) ...[
            if (b.email != null) FactRow('Google account', b.email!),
            FactRow('After you sign in', switch (b.toCheck) {
              0 => 'It’s checked against your account',
              1 => '1 change is checked against your account',
              final n => '$n changes are checked against your account',
            }),
          ],
          const SizedBox(height: Space.sm),
          const Divider(height: 1),
          const SizedBox(height: Space.sm),
          Text(
            'What doesn’t come back',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: Space.xs),
          const FactRow(
            'Anything newer',
            'What you added after this was saved',
          ),
          FactRow('Your files', filesLine(b.filesListed)),
          const FactRow('Reminders', 'They start off. Turn them on in Life'),
          const FactRow('Sign-ins', 'Sign in again on this device'),
          const FactRow(
            'Groups',
            'A record of what happened, not a place in a group',
          ),
          if (backup.alreadyHere) ...[
            const SizedBox(height: Space.sm),
            const InlineNotice(
              'This profile is already on this device, so this backup can’t '
              'restore here. Your files are safe.',
              tone: NoticeTone.warning,
              live: true,
            ),
          ],
          ...footer,
        ],
      ),
    );
  }
}

/// Only what applies now it's back.
class _Finished extends StatelessWidget {
  const _Finished({
    required this.contents,
    required this.demo,
    required this.actions,
  });
  final BackupContents contents;
  final bool demo;
  final Widget actions;
  @override
  Widget build(BuildContext context) => OverviewCard(
    key: const ValueKey('restore-finished'),
    title: 'What to do next',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (demo) ...[
          const InlineNotice('Demo: nothing was restored.', live: true),
          const SizedBox(height: Space.sm),
        ],
        if (contents.connected)
          FactRow(
            'Connection',
            'Sign in with ${contents.email ?? 'your Google account'} to '
                'check it',
          ),
        const FactRow('Reminders', 'Off. Turn them on in Life'),
        if ((contents.filesListed ?? 0) > 0)
          FactRow('Your files', filesLine(contents.filesListed)),
        const SizedBox(height: Space.md),
        actions,
      ],
    ),
  );
}
