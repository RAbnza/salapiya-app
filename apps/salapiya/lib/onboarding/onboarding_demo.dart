import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../gallery/settings.dart';
import '../local/finance_domain.dart';
import '../profile/profile_actions.dart' show backupSecretErrors;
import '../profile/profile_data.dart';
import 'google_page.dart';
import 'greeting_page.dart';
import 'onboarding_actions.dart';
import 'onboarding_data.dart';
import 'restore_page.dart';
import 'setup_page.dart';
import 'startup_pages.dart';
import 'welcome_page.dart';

/// The demo's first-run states. Real devices reach these only through what
/// really happens.
enum DemoFirstRun {
  greeting('Greeting'),
  welcome('Welcome: a new device'),
  removed('Welcome: after a removal'),
  kept('Welcome: an earlier profile’s files are kept'),
  noGoogle('Welcome: a build that can’t connect'),
  resumed('Welcome: a sign-in that carried over a restart'),
  partWay('Welcome: a first run or restore that stopped part-way'),
  setup('Local setup'),
  setupResume('Local setup: a first try stopped part-way'),
  opening('Opening'),
  googleReady('Google: what happens next'),
  googleWaiting('Google: waiting for the browser'),
  googleChosenNew('Google: account chosen, no profile yet'),
  googleChosenFound('Google: account chosen, a profile found'),
  googleBrowser('Google: the browser didn’t open'),
  googleCancelled('Google: sign-in cancelled'),
  googleLate('Google: a late answer'),
  googleDropped('Google: the connection dropped'),
  restoreLocal('Restore: a local backup'),
  restoreConnected('Restore: a connected backup'),
  restoreOlder('Restore: an older backup that lists no files'),
  restoreHere('Restore: this profile is already here'),
  restoreWrongSecret('Restore: a wrong secret'),
  restoreNotBackup('Restore: a file that isn’t a backup'),
  failureKey('Failure: the key can’t be reached'),
  failureRead('Failure: what opens the profile can’t be read'),
  failureMissing('Failure: the records have gone'),
  failureVersion('Failure: a newer version is needed'),
  failureDamaged('Failure: a check didn’t pass'),
  failureRestore('Failure: a restore didn’t finish'),
  failureRemoval('Failure: a removal didn’t finish'),
  failureUnknown('Failure: anything else');

  const DemoFirstRun(this.label);
  final String label;

  bool get isGoogle => name.startsWith('google');
  bool get isRestore => name.startsWith('restore');
  bool get isSetup => name.startsWith('setup');

  StartupProblem? get problem => switch (this) {
    failureKey => StartupProblem.keyUnavailable,
    failureRead => StartupProblem.unreadable,
    failureMissing => StartupProblem.missingRecords,
    failureVersion => StartupProblem.newerVersion,
    failureDamaged => StartupProblem.damaged,
    failureRestore => StartupProblem.restoreUnfinished,
    failureRemoval => StartupProblem.removalUnfinished,
    failureUnknown => StartupProblem.unknown,
    _ => null,
  };
}

/// Stands in for the runtime: every state on request, and nothing happens.
class DemoOnboarding extends ChangeNotifier implements OnboardingActions {
  DemoOnboarding(this.state, {this.settings});
  DemoFirstRun state;

  /// The demo's own settings, so a theme shows as it's picked.
  final GallerySettings? settings;
  late final ThemeMode _started = settings?.themeMode ?? ThemeMode.system;
  String? note;

  void said(String words) {
    note = 'Demo: nothing happened. $words';
    notifyListeners();
  }

  @override
  bool get demo => true;
  @override
  Listenable get changes => this;
  @override
  bool get profileOpen => false;

  @override
  ConnectionFacts facts() => switch (state) {
    DemoFirstRun.noGoogle => const ConnectionFacts(configured: false),
    DemoFirstRun.resumed ||
    DemoFirstRun.googleWaiting => const ConnectionFacts(signingIn: true),
    DemoFirstRun.googleChosenNew => const ConnectionFacts(
      signedIn: true,
      email: 'amihan@example.com',
    ),
    DemoFirstRun.googleChosenFound => const ConnectionFacts(
      signedIn: true,
      email: 'amihan@example.com',
      cloudName: 'Amihan',
    ),
    DemoFirstRun.googleBrowser => const ConnectionFacts(
      signInOutcome: 'browser_launch_failed',
    ),
    DemoFirstRun.googleCancelled => const ConnectionFacts(
      signInOutcome: 'provider_cancelled',
    ),
    DemoFirstRun.googleLate => const ConnectionFacts(
      signInOutcome: 'late_callback_ignored',
    ),
    DemoFirstRun.googleDropped => const ConnectionFacts(
      signInOutcome: 'callback_failed_local_data_preserved',
    ),
    _ => const ConnectionFacts(),
  };

  @override
  Future<DeviceStart> deviceStart() async => switch (state) {
    DemoFirstRun.removed => const DeviceStart(phase: 'empty'),
    DemoFirstRun.kept => const DeviceStart(
      phase: 'empty',
      keptFiles: true,
      keptName: 'Amihan',
    ),
    DemoFirstRun.setupResume || DemoFirstRun.partWay => const DeviceStart(
      phase: 'initializing',
      pendingName: 'Amihan',
    ),
    _ => DeviceStart.fresh,
  };

  void go(DemoFirstRun next) {
    state = next;
    note = null;
    notifyListeners();
  }

  @override
  ThemeMode get theme => settings?.themeMode ?? ThemeMode.system;
  @override
  void showTheme(ThemeMode mode) {
    _started;
    settings?.change(() => settings!.themeMode = mode);
  }

  /// Nothing the preview does stays.
  void resetTheme() {
    if (theme != _started) showTheme(_started);
  }

  @override
  Future<void> create(String name, ThemeMode theme) async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> connect() async => go(DemoFirstRun.googleWaiting);
  @override
  Future<void> cancelSignIn() async => go(DemoFirstRun.googleCancelled);
  @override
  Future<void> lookup() async {}
  @override
  Future<void> confirmConnection() async =>
      said('Connecting and the first download happen here.');
  @override
  Future<void> dontConnect() async => go(DemoFirstRun.googleReady);
  @override
  String newProfileName() => 'Amihan';
  @override
  Future<PickedBackup?> pickBackup() async =>
      const PickedBackup('salapiya-2026-10-30-a1b2c3d4.salapiya', []);

  @override
  Future<OpenedBackup> open(PickedBackup backup, String secret) async {
    if (state == DemoFirstRun.restoreWrongSecret) {
      reject('${backupSecretErrors.last}.');
    }
    if (state == DemoFirstRun.restoreNotBackup) {
      reject('This file isn’t a complete Salapiya backup.');
    }
    final connected = state == DemoFirstRun.restoreConnected;
    final older = state == DemoFirstRun.restoreOlder;
    return OpenedBackup(
      const {},
      BackupContents(
        name: 'Amihan',
        created: DateTime.now()
            .subtract(Duration(days: older ? 200 : 3))
            .toUtc()
            .toIso8601String(),
        records: 214,
        drafts: 2,
        lifeVersions: 87,
        filesListed: older ? null : 3,
        connected: connected,
        thisProfile: false,
        email: connected ? 'amihan@example.com' : null,
        toCheck: connected ? 6 : 0,
      ),
      alreadyHere: state == DemoFirstRun.restoreHere,
    );
  }

  @override
  Future<void> restore(OpenedBackup backup) async {}
  @override
  void openConnectionTab(BuildContext context) {}
}

/// First-run preview. The real pages on a stand-in, with the demo's Show a
/// state above them. It can't show real sign-in, the system's file window, a
/// real secret or restore, a real failure, or a restart.
class FirstRunPreview extends StatefulWidget {
  const FirstRunPreview({
    super.key,
    this.initial = DemoFirstRun.greeting,
    this.settings,
  });
  final DemoFirstRun initial;
  final GallerySettings? settings;
  @override
  State<FirstRunPreview> createState() => _FirstRunPreviewState();
}

class _FirstRunPreviewState extends State<FirstRunPreview> {
  late final demo = DemoOnboarding(widget.initial, settings: widget.settings);

  /// Changing state starts each page afresh.
  var round = 0;
  @override
  void dispose() {
    demo.dispose();
    super.dispose();
  }

  void show(DemoFirstRun next) {
    demo.resetTheme();
    setState(() {
      round++;
      demo.go(next);
    });
  }

  void home() => show(DemoFirstRun.welcome);

  /// Back goes one step at a time, as far as the greeting.
  void back() =>
      demo.state == DemoFirstRun.welcome ? show(DemoFirstRun.greeting) : home();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demo,
    builder: (context, _) {
      final state = demo.state;
      final problem = state.problem;
      final Widget page = switch (state) {
        _ when problem != null => StartupFailurePage(
          problem: problem,
          onRetry: () => demo.said('It would open again here.'),
          message: problem == StartupProblem.unknown
              ? null
              : 'The rule’s own words show here.',
          folder: r'C:\Users\Amihan\AppData\Roaming\Salapiya\local-v1',
        ),
        DemoFirstRun.opening => const OpeningScreen(),
        DemoFirstRun.greeting => GreetingPage(actions: demo, onStart: home),
        _ when state.isSetup => ProfileSetupPage(
          actions: demo,
          onDone: () {
            home();
            demo.said('No profile was created.');
          },
        ),
        _ when state.isGoogle => GooglePage(actions: demo, onDone: home),
        _ when state.isRestore => RestorePage(actions: demo, onDone: home),
        _ => WelcomePage(
          actions: demo,
          onStart: () => show(DemoFirstRun.setup),
          onGoogle: () => show(DemoFirstRun.googleReady),
          onRestore: () => show(DemoFirstRun.restoreLocal),
        ),
      };
      final text = Theme.of(context).textTheme;
      return PopScope(
        canPop: state == DemoFirstRun.greeting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) back();
        },
        child: Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(Space.sm),
                  child: DropdownButtonFormField<DemoFirstRun>(
                    key: ValueKey('first-run-state-$round'),
                    initialValue: state,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Show a state',
                    ),
                    items: [
                      for (final s in DemoFirstRun.values)
                        DropdownMenuItem(
                          value: s,
                          child: Text(s.label, style: text.bodyMedium),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) show(v);
                    },
                  ),
                ),
                if (demo.note != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.sm,
                      0,
                      Space.sm,
                      Space.sm,
                    ),
                    child: InlineNotice(demo.note!, live: true),
                  ),
                Expanded(
                  child: KeyedSubtree(key: ValueKey(round), child: page),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
