import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart' show LocalRuleException;
import 'profile_actions.dart';
import 'profile_data.dart';
import 'profile_source.dart';

const backupFormWidth = Space.formMaxWidth;

/// The recovery secret's field and its controls. It's masked until asked, and
/// masks again when the app leaves the foreground. Nothing here stores it.
class _SecretField extends StatefulWidget {
  const _SecretField({
    required this.controller,
    required this.onChanged,
    this.errorText,
    this.readOnly = false,
    this.helper,
  });
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? errorText, helper;
  final bool readOnly;
  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField>
    with WidgetsBindingObserver {
  bool masked = true, copied = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !masked) {
      setState(() => masked = true);
    }
  }

  Future<void> copy() async {
    await Clipboard.setData(ClipboardData(text: widget.controller.text));
    if (mounted) setState(() => copied = true);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HelpTextField(
        key: const ValueKey('backup-secret'),
        label: 'Recovery secret',
        controller: widget.controller,
        secret: true,
        obscured: masked,
        readOnly: widget.readOnly,
        keyboardType: TextInputType.visiblePassword,
        errorText: widget.errorText,
        helper: copied
            ? 'Copied. Clear your clipboard once it’s saved somewhere.'
            : widget.helper,
        onChanged: (_) => widget.onChanged(),
      ),
      const SizedBox(height: Space.xs),
      Wrap(
        spacing: Space.md,
        children: [
          CardLink(
            masked ? 'Show' : 'Hide',
            key: const ValueKey('backup-secret-show'),
            icon: masked
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            chevron: false,
            onPressed: () => setState(() => masked = !masked),
          ),
          if (widget.readOnly)
            CardLink(
              'Copy',
              key: const ValueKey('backup-secret-copy'),
              icon: Icons.copy_outlined,
              chevron: false,
              onPressed: copy,
            ),
        ],
      ),
    ],
  );
}

/// Save a backup. The secret lives in this page's field and goes when the
/// page does; there's no draft to bring it back.
class BackupSavePage extends StatefulWidget {
  const BackupSavePage({
    super.key,
    required this.source,
    required this.onSaved,
    required this.onFailed,
  });
  final ProfileSource source;
  final VoidCallback onSaved;
  final ValueChanged<String?> onFailed;
  @override
  State<BackupSavePage> createState() => _BackupSavePageState();
}

class _BackupSavePageState extends State<BackupSavePage> {
  final secret = TextEditingController();
  bool ownSecret = false, kept = false, saving = false, saved = false;
  String? error, secretError;
  ProfileSource get source => widget.source;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => generate());
  }

  @override
  void dispose() {
    secret.dispose();
    super.dispose();
  }

  Future<void> generate() async {
    final fresh = await source.actions.newSecret();
    if (!mounted || ownSecret) return;
    setState(() {
      secret.text = fresh;
      kept = false;
    });
  }

  void chooseOwn(bool own) {
    setState(() {
      ownSecret = own;
      kept = false;
      secretError = null;
      secret.clear();
    });
    if (!own) generate();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
      secretError = null;
    });
    try {
      final done = await source.actions.saveBackup(secret.text);
      if (!mounted) return;
      if (done) {
        widget.onSaved();
        setState(() {
          saved = true;
          secret.clear();
        });
      } else {
        setState(() => error = 'Not saved. You closed the save window.');
      }
    } catch (e) {
      if (!mounted) return;
      final why = e is LocalRuleException
          ? e.message
          : 'The backup didn’t save. Your records haven’t changed.';
      widget.onFailed(why);
      setState(() {
        if (backupSecretErrors.any(why.contains)) {
          secretError = why;
        } else {
          error = why;
        }
      });
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = CraftTheme.of(context);
    final f = source.connection;
    if (saved) {
      return SectionPage(
        title: 'Save a backup',
        maxWidth: backupFormWidth,
        child: OverviewCard(
          key: const ValueKey('backup-saved'),
          title: 'Backup saved',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                source.demo
                    ? 'Demo: no file was saved.'
                    : 'Keep the backup and its recovery secret in separate '
                          'places. Salapiya can’t recover the secret for you.',
                style: text.bodyMedium?.copyWith(color: c.secondary),
              ),
              const SizedBox(height: Space.md),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton(
                  'Done',
                  key: const ValueKey('backup-done'),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SectionPage(
      title: 'Save a backup',
      caption: 'An encrypted copy, to keep somewhere else',
      maxWidth: backupFormWidth,
      child: CompactForm(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!source.complete) ...[
              const InlineNotice(
                'Your first download isn’t finished, so this backup holds '
                'only what has downloaded so far.',
                tone: NoticeTone.warning,
              ),
              SizedBox(height: CompactForm.groupGap(context)),
            ],
            if (f.waiting > 0) ...[
              InlineNotice(
                f.waiting == 1
                    ? 'The 1 change waiting to sync is included.'
                    : 'The ${f.waiting} changes waiting to sync are included.',
              ),
              SizedBox(height: CompactForm.groupGap(context)),
            ],
            Text(
              'It holds your records and their history, waiting changes, '
              'saved drafts and settings. It lists your files but doesn’t '
              'hold them.',
              style: text.bodyMedium?.copyWith(color: c.secondary),
            ),
            SizedBox(height: CompactForm.groupGap(context)),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: MiniSegmented<bool>(
                key: const ValueKey('backup-secret-kind'),
                label: 'Recovery secret',
                options: const [(false, 'New secret'), (true, 'One I have')],
                selected: ownSecret,
                onSelected: chooseOwn,
              ),
            ),
            SizedBox(height: CompactForm.fieldGap(context)),
            _SecretField(
              controller: secret,
              readOnly: !ownSecret,
              errorText: secretError,
              helper:
                  'The backup opens only with this. Keep it apart from the '
                  'backup. Salapiya can’t recover it for you.',
              onChanged: () => setState(() {
                kept = false;
                secretError = null;
              }),
            ),
            SizedBox(height: CompactForm.fieldGap(context)),
            CheckboxListTile(
              key: const ValueKey('backup-kept'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                'I’ve saved this secret somewhere separate',
                style: text.bodyMedium,
              ),
              value: kept,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: saving || secret.text.isEmpty
                  ? null
                  : (v) => setState(() => kept = v ?? false),
            ),
            if (error != null) ...[
              SizedBox(height: CompactForm.fieldGap(context)),
              InlineNotice(error!, tone: NoticeTone.error, live: true),
            ],
            SizedBox(height: CompactForm.groupGap(context)),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppButton(
                'Save backup',
                key: const ValueKey('backup-save-file'),
                busy: saving,
                onPressed: !kept || saving ? null : save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Check a backup: opens one with its secret and says what's inside. Nothing
/// on this device changes.
class BackupCheckPage extends StatefulWidget {
  const BackupCheckPage({super.key, required this.source});
  final ProfileSource source;
  @override
  State<BackupCheckPage> createState() => _BackupCheckPageState();
}

class _BackupCheckPageState extends State<BackupCheckPage> {
  final secret = TextEditingController();
  bool checking = false;
  String? error, secretError;
  BackupContents? contents;
  @override
  void dispose() {
    secret.dispose();
    super.dispose();
  }

  Future<void> check() async {
    setState(() {
      checking = true;
      error = null;
      secretError = null;
      contents = null;
    });
    try {
      final found = await widget.source.actions.checkBackup(secret.text);
      if (mounted) setState(() => contents = found);
    } catch (e) {
      if (!mounted) return;
      final why = e is LocalRuleException
          ? e.message
          : 'That file couldn’t be opened. Nothing changed.';
      setState(() {
        if (backupSecretErrors.any(why.contains)) {
          secretError = why;
        } else {
          error = why;
        }
      });
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final found = contents;
    return SectionPage(
      title: 'Check a backup',
      caption: 'See what’s inside. Nothing on this device changes',
      maxWidth: backupFormWidth,
      child: CompactForm(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SecretField(
              controller: secret,
              errorText: secretError,
              helper: 'The one you kept with this backup',
              onChanged: () => setState(() {
                secretError = null;
                contents = null;
              }),
            ),
            if (error != null) ...[
              SizedBox(height: CompactForm.fieldGap(context)),
              InlineNotice(error!, tone: NoticeTone.error, live: true),
            ],
            SizedBox(height: CompactForm.groupGap(context)),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppButton(
                'Choose backup file',
                key: const ValueKey('backup-choose'),
                icon: Icons.folder_open_outlined,
                busy: checking,
                onPressed: checking || secret.text.isEmpty ? null : check,
              ),
            ),
            if (found != null) ...[
              SizedBox(height: Space.cardGapOf(context)),
              OverviewCard(
                key: const ValueKey('backup-contents'),
                title: 'This backup opens',
                caption: found.thisProfile
                    ? 'It’s a backup of this profile'
                    : 'It’s a backup of a different profile',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FactRow('Profile', found.name),
                    FactRow('Saved', manilaWhen(found.created)),
                    FactRow('Records', '${found.records}'),
                    FactRow('Life history', '${found.lifeVersions} versions'),
                    FactRow('Saved drafts', '${found.drafts}'),
                    FactRow('Files', filesLine(found.filesListed)),
                    if (found.connected)
                      const FactRow(
                        'After restoring',
                        'It needs a Google sign-in, and it’s checked against '
                            'your connected account',
                      ),
                    const SizedBox(height: Space.sm),
                    const InlineNotice(
                      'A backup restores on a new device, or once no profile '
                      'is open. It never replaces a profile in use.',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
