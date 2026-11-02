import 'package:flutter/material.dart';

import '../app/shell_navigation.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart' show LocalRuleException;
import '../prototype/scenarios.dart' show AppDestination;
import 'profile_data.dart';
import 'profile_source.dart';

/// "Who is this profile, and how is it set up?"
class ProfileTab extends StatelessWidget {
  const ProfileTab({
    super.key,
    required this.source,
    required this.onTab,
    this.note,
    this.noteLoaded = false,
    this.demoTools,
  });
  final ProfileSource source;
  final ValueChanged<String> onTab;

  /// The last backup noted on this device.
  final BackupNote? note;
  final bool noteLoaded;

  /// The demo's scenario controls. They're no part of a real profile.
  final Widget? demoTools;

  Future<void> chooseGroup(
    BuildContext context,
    DefaultGroupChoices choices,
  ) async {
    final hub = source.hub!;
    final picked = await showAdaptiveModal<(String?,)>(
      context,
      title: 'Default group',
      purpose: ModalPurpose.choice,
      primary: null,
      body: ListGroup(
        children: [
          for (final (id, name) in choices.options)
            ListRow(
              key: ValueKey('default-group-${id ?? 'none'}'),
              title: name,
              trailing: id == choices.chosen
                  ? Icon(Icons.check, color: CraftTheme.of(context).primary)
                  : null,
              onTap: () =>
                  Navigator.of(context, rootNavigator: true).pop((id,)),
            ),
        ],
      ),
    );
    if (picked != null) hub.setDefault(picked.$1);
  }

  @override
  Widget build(BuildContext context) {
    final hub = source.hub;
    final groups = hub == null
        ? null
        : defaultGroupChoices(hub.source(), hub.defaultGroup);
    final profile = _ThisProfile(source: source);
    final glance = _AtAGlance(
      source: source,
      onTab: onTab,
      backup: !noteLoaded
          ? 'Not available yet'
          : note == null
          ? 'No backup on this device yet'
          : 'Last backup ${manilaWhen(note!.at)}',
    );
    final appearance = _Appearance(source: source);
    final privacy = _Privacy(source: source);
    final defaults = OverviewCard(
      key: const ValueKey('profile-defaults'),
      title: 'Defaults and more settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListGroup(
            children: [
              if (groups != null)
                AdaptiveRow(
                  key: const ValueKey('profile-default-group'),
                  title: 'Default group',
                  subtitle: groups.lost
                      ? '${groups.shown}. Your default was archived or you '
                            'left it.'
                      : groups.shown,
                  onTap: () => chooseGroup(context, groups),
                ),
              AdaptiveRow(
                key: const ValueKey('profile-life-settings'),
                title: 'Life preferences',
                subtitle: 'What shows in Life and on the Calendar',
                onTap: source.openLifeSettings,
              ),
              if (source.goTo case final go?)
                AdaptiveRow(
                  key: const ValueKey('profile-reminders'),
                  title: 'Reminders',
                  subtitle: 'What reminds you on this device',
                  onTap: () => go(AppDestination.life, 'Reminders'),
                ),
            ],
          ),
          const ListEnd(),
        ],
      ),
    );
    return DashboardGrid(
      key: const ValueKey('profile-grid'),
      cards: isDesktop(context)
          ? [
              (profile, 8, 12),
              (glance, 4, 12),
              (appearance, 6, 12),
              (privacy, 6, 12),
              (defaults, 12, 12),
              ?(demoTools == null ? null : (demoTools!, 12, 12)),
            ]
          : null,
      stacked: [profile, glance, appearance, privacy, defaults, ?demoTools],
    );
  }
}

class _ThisProfile extends StatelessWidget {
  const _ThisProfile({required this.source});
  final ProfileSource source;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return OverviewCard(
      key: const ValueKey('profile-this'),
      title: 'This profile',
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final edit = CardLink(
                'Edit name',
                key: const ValueKey('profile-edit-name'),
                onPressed: () => showEditName(context, source),
              );
              final narrow = narrowAt(context, box.maxWidth, Space.xxxl * 5);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProfileInitial(
                        name: source.name,
                        size: Space.target,
                        onAccent: true,
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Text(source.name, style: text.titleLarge),
                      ),
                      if (!narrow) ...[const SizedBox(width: Space.sm), edit],
                    ],
                  ),
                  if (narrow) edit,
                ],
              );
            },
          ),
          const SizedBox(height: Space.sm),
          const FactRow('Currency', 'Philippine peso (PHP)'),
          const FactRow('Timezone', 'Asia/Manila'),
          FactRow('Where it’s kept', keptLine(connected: source.connected)),
          const FactRow('Protection', 'Encrypted on this device'),
          const SizedBox(height: Space.xs),
          FormMoreDetails(
            label: 'View details',
            children: [FactRow('Profile ID', source.profileId)],
          ),
        ],
      ),
    );
  }
}

class _AtAGlance extends StatelessWidget {
  const _AtAGlance({
    required this.source,
    required this.onTab,
    required this.backup,
  });
  final ProfileSource source;
  final ValueChanged<String> onTab;
  final String backup;
  @override
  Widget build(BuildContext context) => OverviewCard(
    key: const ValueKey('profile-glance'),
    title: 'At a glance',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListGroup(
          children: [
            AdaptiveRow(
              key: const ValueKey('glance-connection'),
              leading: Icons.cloud_outlined,
              title: 'Connection',
              subtitle: source.syncLine,
              pill: source.needsReview
                  ? const StatusPill(
                      'Needs review',
                      icon: Icons.error_outline,
                      tone: PillTone.warning,
                    )
                  : null,
              onTap: () => onTab('Connection'),
            ),
            AdaptiveRow(
              key: const ValueKey('glance-devices'),
              leading: Icons.devices_outlined,
              title: 'Devices',
              subtitle: source.connected
                  ? 'See what’s signed in'
                  : 'This device only',
              onTap: () => onTab('Devices'),
            ),
            AdaptiveRow(
              key: const ValueKey('glance-backup'),
              leading: Icons.restore,
              title: 'Backup & recovery',
              subtitle: backup,
              onTap: () => onTab('Backup & recovery'),
            ),
          ],
        ),
        const ListEnd(),
      ],
    ),
  );
}

/// A label with its control, which moves under it when the card is narrow.
class _Setting extends StatelessWidget {
  const _Setting(this.label, this.control);
  final String label;
  final Widget control;
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: hitTarget(context)),
      child: LayoutBuilder(
        builder: (context, box) => narrowAt(context, box.maxWidth)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: style),
                  const SizedBox(height: Space.xs),
                  control,
                ],
              )
            : Row(
                children: [
                  Expanded(child: Text(label, style: style)),
                  const SizedBox(width: Space.md),
                  control,
                ],
              ),
      ),
    );
  }
}

class _Appearance extends StatelessWidget {
  const _Appearance({required this.source});
  final ProfileSource source;
  @override
  Widget build(BuildContext context) {
    final settings = source.settings;
    return OverviewCard(
      key: const ValueKey('profile-appearance'),
      title: 'Appearance',
      caption: 'Saved with this profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Setting(
            'Theme',
            MiniSegmented<ThemeMode>(
              key: const ValueKey('profile-theme'),
              label: 'Theme',
              options: const [
                (ThemeMode.system, 'System'),
                (ThemeMode.light, 'Light'),
                (ThemeMode.dark, 'Dark'),
              ],
              selected: settings.themeMode,
              onSelected: (mode) =>
                  settings.change(() => settings.themeMode = mode),
            ),
          ),
          const SizedBox(height: Space.xs),
          _Setting(
            'Text size',
            MiniSegmented<double>(
              key: const ValueKey('profile-text-size'),
              label: 'Text size',
              options: const [
                (0, 'System'),
                (1, '100%'),
                (1.5, '150%'),
                (2, '200%'),
              ],
              selected: settings.textScale ?? 0,
              onSelected: (size) => settings.change(
                () => settings.textScale = size == 0 ? null : size,
              ),
            ),
          ),
          SwitchRow(
            label: 'Reduce motion',
            switchKey: const ValueKey('profile-reduce-motion'),
            value: settings.reduceMotion,
            onChanged: (v) => settings.change(() => settings.reduceMotion = v),
          ),
        ],
      ),
    );
  }
}

class _Privacy extends StatelessWidget {
  const _Privacy({required this.source});
  final ProfileSource source;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return OverviewCard(
      key: const ValueKey('profile-privacy'),
      title: 'Hide amounts',
      caption: 'Stays on until you turn it off',
      toggle: AppSwitch(
        key: const ValueKey('profile-hide-amounts'),
        label: 'Hide amounts',
        value: source.hidden,
        onChanged: (_) => source.togglePrivacy(),
      ),
      child: Text(
        'Amounts read “Amount hidden” on every screen, and charts are hidden '
        'too, so you can use Salapiya with people around.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: c.secondary),
      ),
    );
  }
}

/// Edit name. It's a short form with one field, so it stays a modal.
Future<void> showEditName(BuildContext context, ProfileSource source) async {
  final form = GlobalKey<_EditNameState>();
  await showAdaptiveModal<bool>(
    context,
    title: 'Edit name',
    purpose: ModalPurpose.choice,
    body: _EditName(key: form, source: source),
    primary: ModalAction(
      'Save name',
      value: true,
      onPressed: () async => await form.currentState?.save() ?? false,
    ),
  );
}

class _EditName extends StatefulWidget {
  const _EditName({super.key, required this.source});
  final ProfileSource source;
  @override
  State<_EditName> createState() => _EditNameState();
}

class _EditNameState extends State<_EditName> {
  late final name = TextEditingController(text: widget.source.name);
  String? error;
  bool saving = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  /// False keeps the form open, with the reason on the field.
  Future<bool> save() async {
    if (saving) return false;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.source.rename(name.text);
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is LocalRuleException
              ? e.message
              : 'That didn’t save. Nothing changed.';
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => CompactForm(
    child: HelpTextField(
      key: const ValueKey('profile-name-field'),
      label: 'Display name',
      controller: name,
      enabled: !saving,
      errorText: error,
      helper: widget.source.connected
          ? 'This changes the name on this device. Your other devices keep '
                'theirs.'
          : null,
    ),
  );
}
