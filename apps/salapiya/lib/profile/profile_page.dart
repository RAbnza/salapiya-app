import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../gallery/settings.dart';
import '../local/local_runtime.dart';
import '../prototype/scenarios.dart';
import '../shared/shared_hub.dart';
import 'backup_pages.dart';
import 'backup_tab.dart';
import 'connection_tab.dart';
import 'devices_tab.dart';
import 'help_tab.dart';
import 'profile_actions.dart';
import 'profile_data.dart';
import 'profile_demo.dart';
import 'profile_source.dart';
import 'profile_tab.dart';

/// Profile and settings. Each tab answers its own question (§2).
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.session,
    required this.settings,
    this.tab,
    this.hub,
    this.goTo,
    this.actions,
  });
  final PrototypeSession session;
  final GallerySettings settings;

  /// The tab on show. The shell holds it, so a link to another tab moves this
  /// page there and doesn't open a second copy.
  final ValueNotifier<String>? tab;
  final SharedHub? hub;
  final ProfileGoTo? goTo;

  /// Stands in for the real ones, for tests.
  final ProfileActions? actions;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final tab = widget.tab ?? ValueNotifier('Profile');
  late final session = widget.session;
  late final DemoProfile? demo = session is LocalSession
      ? null
      : widget.actions is DemoProfile
      ? widget.actions as DemoProfile
      : DemoProfile(session);
  late final ProfileActions actions =
      widget.actions ??
      demo ??
      LocalProfileActions(session as LocalSession);
  late final Listenable changes = Listenable.merge([
    widget.settings,
    session,
    if (session case final LocalSession local) local.runtime,
    ?demo,
    ?widget.hub,
  ]);

  /// Lasts across tab changes, so switching profile doesn't lose it.
  bool backupSaved = false;
  BackupNote? note;
  bool noteLoaded = false;
  String? backupFailed;

  @override
  void initState() {
    super.initState();
    // After the first frame: nothing here should notify while it builds.
    WidgetsBinding.instance.addPostFrameCallback((_) => loadNote());
    demo?.addListener(loadNote);
    tab.addListener(forgetNote);
  }

  /// A demo action's note belongs to the tab it happened on.
  void forgetNote() => demo?.note = null;

  @override
  void dispose() {
    demo?.removeListener(loadNote);
    tab.removeListener(forgetNote);
    if (widget.actions == null) demo?.dispose();
    super.dispose();
  }

  Future<void> loadNote() async {
    if (!mounted) return;
    try {
      final found = await actions.lastBackup();
      if (mounted) {
        setState(() {
          note = found;
          noteLoaded = true;
          if (demo != null) {
            backupFailed = demo!.backup == DemoBackup.failed
                ? 'The backup didn’t save. Your records haven’t changed.'
                : null;
          }
        });
      }
    } catch (_) {
      // The tab still says how to make one.
      if (mounted) setState(() => noteLoaded = true);
    }
  }

  ProfileSource source() => profileSource(
    context,
    session,
    widget.settings,
    actions: actions,
    listenable: changes,
    demoReviews: demo?.reviews ?? const [],
    demoFiles: demo?.files,
    hub: widget.hub,
    goTo: widget.goTo,
  );

  void openSave() => openDemoPage<void>(
    context,
    BackupSavePage(
      source: source(),
      onSaved: () {
        setState(() {
          backupSaved = true;
          backupFailed = null;
        });
        loadNote();
      },
      onFailed: (why) => setState(() => backupFailed = why),
    ),
    'profile/backup',
    title: 'Save a backup',
  );

  void openCheck() => openDemoPage<void>(
    context,
    BackupCheckPage(source: source()),
    'profile/backup-check',
    title: 'Check a backup',
  );

  Widget body(ProfileSource source, String shown) {
    final settings = widget.settings;
    void toTab(String t) => tab.value = t;
    return switch (shown) {
      'Help' => HelpTab(source: source),
      'Connection' => ConnectionTab(
        source: source,
        backupSaved: backupSaved,
        onSaveBackup: openSave,
        current: this.source,
      ),
      'Devices' => DevicesTab(
        // A state in the demo starts its list over.
        key: ValueKey(demo?.device),
        source: source,
        onTab: toTab,
      ),
      'Backup & recovery' => BackupTab(
        source: source,
        note: note,
        loaded: noteLoaded,
        failed: backupFailed,
        onSave: openSave,
        onCheck: openCheck,
        onTab: toTab,
      ),
      _ => ProfileTab(
        source: source,
        note: note,
        noteLoaded: noteLoaded,
        onTab: toTab,
        demoTools: source.demo
            ? DemoToolsCard(session: session, settings: settings)
            : null,
      ),
    };
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([changes, tab]),
    builder: (context, _) {
      final current = source();
      final shown = tab.value;
      final problem = current.preferenceError;
      final showing = demo != null && shown != 'Profile' && shown != 'Help';
      return SectionPage(
        title: 'Profile and settings',
        caption: profileCaption(shown),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTabs<String>(
              key: const ValueKey('profile-tabs'),
              tabs: [for (final t in profileTabs) (t, t)],
              selected: shown,
              onSelected: (t) => tab.value = t,
            ),
            SizedBox(height: Space.cardGapOf(context)),
            if (problem != null) ...[
              InlineNotice(problem, tone: NoticeTone.error, live: true),
              SizedBox(height: Space.cardGapOf(context)),
            ],
            if (showing) DemoStateBar(tab: shown, demo: demo!),
            body(current, shown),
          ],
        ),
      );
    },
  );
}
