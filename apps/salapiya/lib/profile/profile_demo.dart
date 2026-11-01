import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/profile_utilities.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../features/profile/presentation/profile_experience.dart';
import '../gallery/settings.dart';
import '../prototype/scenarios.dart';
import 'profile_actions.dart';
import 'profile_data.dart';

/// The demo's own controls. A real profile never shows these.
class DemoToolsCard extends StatelessWidget {
  const DemoToolsCard({
    super.key,
    required this.session,
    required this.settings,
  });
  final PrototypeSession session;
  final GallerySettings settings;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return OverviewCard(
      key: const ValueKey('demo-tools'),
      title: 'Demo tools',
      caption:
          'Fictional profile. Everything here resets when the app closes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<OverviewScenario>(
            key: ValueKey(session.scenario),
            initialValue: session.scenario,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Overview scenario'),
            items: [
              for (final scenario in OverviewScenario.values)
                DropdownMenuItem(value: scenario, child: Text(scenario.label)),
            ],
            onChanged: (value) {
              if (value != null) session.select(value);
            },
          ),
          const SizedBox(height: Space.sm),
          SwitchRow(
            label: 'Craft effects',
            switchKey: const ValueKey('demo-craft-effects'),
            value: settings.effects,
            onChanged: (v) => settings.change(() => settings.effects = v),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              AppButton.secondary(
                'First-run preview',
                icon: Icons.waving_hand_outlined,
                onPressed: () => openDemoPage<void>(
                  context,
                  ProfileExperience(
                    session: session,
                    settings: settings,
                    initial: 'Welcome',
                  ),
                  'first-run',
                ),
              ),
              AppButton.secondary(
                'Design Gallery',
                icon: Icons.palette_outlined,
                onPressed: () => openDemoPage<void>(
                  context,
                  GalleryUtility(settings: settings),
                  'design-gallery',
                ),
              ),
              AppButton.tertiary('Reset demo scenario', onPressed: session.reset),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Gallery specimens use their own sample amounts, so Hide amounts '
            'doesn’t cover them.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: c.secondary),
          ),
        ],
      ),
    );
  }
}

/// The demo's device states.
enum DemoDevices {
  one('One device'),
  several('Several devices'),
  lost('A revoked and a signed-out device'),
  earlier('An earlier sign-in'),
  offline('No connection');

  const DemoDevices(this.label);
  final String label;
}

/// The demo's backup states.
enum DemoBackup {
  none('No backup yet'),
  current('Nothing changed since'),
  changed('Records changed since'),
  failed('A backup that failed'),
  noFiles('No files listed');

  const DemoBackup(this.label);
  final String label;
}

const _phaseNames = {
  ConnectionPhase.local: 'On this device only',
  ConnectionPhase.unavailable: 'Can’t connect in this build',
  ConnectionPhase.signingIn: 'Waiting for Google',
  ConnectionPhase.chosen: 'Google account chosen',
  ConnectionPhase.otherProfile: 'A different profile on this account',
  ConnectionPhase.unfinished: 'Connection not finished',
  ConnectionPhase.firstDownload: 'First download not finished',
  ConnectionPhase.restoring: 'Checking a restored backup',
  ConnectionPhase.signedOut: 'Signed out',
  ConnectionPhase.paused: 'Sync paused',
  ConnectionPhase.syncing: 'Syncing',
  ConnectionPhase.unreachable: 'Can’t reach the service',
  ConnectionPhase.waiting: 'Changes waiting',
  ConnectionPhase.needsReview: 'Needs review',
  ConnectionPhase.synced: 'Synced',
  ConnectionPhase.deleted: 'Account deleted',
};

/// Stands in for the runtime: every state on request, and nothing happens.
class DemoProfile extends ChangeNotifier implements ProfileActions {
  DemoProfile(this.session);
  final PrototypeSession session;

  /// Null follows the demo's scenario.
  ConnectionPhase? phase;
  DemoDevices device = DemoDevices.several;
  DemoBackup backup = DemoBackup.changed;

  /// What the last action would have done.
  String? note;

  void set(void Function() change) {
    change();
    note = null;
    notifyListeners();
  }

  void said(String words) {
    note = 'Demo: nothing happened. $words';
    notifyListeners();
  }

  static final _synced = DateTime.now()
      .subtract(const Duration(minutes: 12))
      .toUtc()
      .toIso8601String();

  ConnectionPhase get shown =>
      phase ??
      switch (session.scenario) {
        OverviewScenario.local || OverviewScenario.empty => ConnectionPhase.local,
        OverviewScenario.current => ConnectionPhase.synced,
        OverviewScenario.waiting => ConnectionPhase.unreachable,
        OverviewScenario.pending => ConnectionPhase.waiting,
        OverviewScenario.incomplete => ConnectionPhase.firstDownload,
        OverviewScenario.review => ConnectionPhase.needsReview,
      };

  @override
  ConnectionFacts facts() {
    const email = 'amihan@example.test';
    final last = _synced;
    return switch (shown) {
      ConnectionPhase.unavailable => const ConnectionFacts(configured: false),
      ConnectionPhase.local => const ConnectionFacts(),
      ConnectionPhase.signingIn => const ConnectionFacts(signingIn: true),
      ConnectionPhase.chosen => const ConnectionFacts(
        signedIn: true,
        email: email,
      ),
      ConnectionPhase.otherProfile => const ConnectionFacts(
        signedIn: true,
        email: email,
        otherProfile: true,
        cloudName: 'Amihan’s other profile',
      ),
      ConnectionPhase.unfinished => const ConnectionFacts(
        bound: 'staged',
        signedIn: true,
        email: email,
      ),
      ConnectionPhase.firstDownload => ConnectionFacts(
        bound: 'published',
        signedIn: true,
        email: email,
        lastSync: last,
      ),
      ConnectionPhase.restoring => const ConnectionFacts(
        bound: 'restored',
        signedIn: true,
        email: email,
      ),
      ConnectionPhase.signedOut => ConnectionFacts(
        bound: 'connected',
        expired: true,
        email: email,
        lastSync: last,
        moneyWaiting: 2,
      ),
      ConnectionPhase.paused => ConnectionFacts(
        bound: 'connected',
        signedIn: true,
        paused: true,
        email: email,
        lastSync: last,
        moneyWaiting: 1,
      ),
      ConnectionPhase.syncing => ConnectionFacts(
        bound: 'connected',
        signedIn: true,
        active: true,
        email: email,
        lastSync: last,
      ),
      ConnectionPhase.unreachable => ConnectionFacts(
        bound: 'connected',
        signedIn: true,
        reachable: false,
        email: email,
        lastSync: last,
        moneyWaiting: 2,
        lifeWaiting: 1,
      ),
      ConnectionPhase.waiting => ConnectionFacts(
        bound: 'connected',
        signedIn: true,
        email: email,
        lastSync: last,
        moneyWaiting: 2,
        sharedWaiting: 1,
      ),
      ConnectionPhase.needsReview => ConnectionFacts(
        bound: 'connected',
        signedIn: true,
        email: email,
        lastSync: last,
        moneyReview: 2,
        sharedReview: 1,
        lifeReview: 1,
      ),
      ConnectionPhase.synced => ConnectionFacts(
        bound: 'connected',
        signedIn: true,
        email: email,
        lastSync: last,
      ),
      ConnectionPhase.deleted => const ConnectionFacts(
        bound: 'connected',
        deleted: true,
      ),
    };
  }

  /// Sample changes to check, on Needs review only.
  List<ReviewRow> get reviews => shown != ConnectionPhase.needsReview
      ? const []
      : [
          ReviewRow(
            id: '00000000-0000-4000-8000-000000000001',
            title: 'Market groceries',
            reason: changeReasons['account unavailable, archived or before cutoff']!,
            facts: [
              ('Date', '21 Oct 2026'),
              ('Amount', session.amount(BigInt.from(125000))),
              ('Account', 'Cash wallet'),
            ],
            details: session.hideAmounts
                ? const []
                : const [('kind', 'expense')],
            canSend: false,
          ),
          ReviewRow(
            id: '00000000-0000-4000-8000-000000000002',
            title: 'Electric bill',
            reason: changeReasons['restored_missing']!,
            facts: [
              ('Date', '18 Oct 2026'),
              ('Amount', session.amount(BigInt.from(248000))),
              ('Account', 'BPI savings'),
            ],
            details: const [],
            canSend: true,
          ),
        ];

  int get files => backup == DemoBackup.noFiles ? 0 : 3;

  @override
  Future<void> connect() async => said('Google opens here.');
  @override
  Future<void> cancelSignIn() async => said('The sign-in stops here.');
  @override
  Future<void> lookup() async => said('Salapiya checks the account here.');
  @override
  Future<void> confirmConnection() async => said('Sync starts here.');
  @override
  Future<void> cancelConnection() async => said('The connection stops here.');
  @override
  Future<void> keepProfile() async => said('This profile stays as it is.');
  @override
  Future<void> useCloudProfile() async => said('The profile switches here.');
  @override
  Future<void> syncNow() async => said('A sync starts here.');
  @override
  Future<void> setPaused(bool paused) async =>
      set(() => phase = paused ? ConnectionPhase.paused : ConnectionPhase.synced);
  @override
  Future<void> signOut() async => said('This device signs out here.');
  @override
  Future<void> send(String id) async => said('The change goes out here.');

  @override
  Future<List<Map<String, dynamic>>> devices() async {
    if (device == DemoDevices.offline) {
      throw StateError('No connection in this demo state');
    }
    final now = DateTime.now().toUtc();
    String ago(int hours) =>
        now.subtract(Duration(hours: hours)).toIso8601String();
    Map<String, dynamic> row(
      String id,
      String label, {
      bool current = false,
      bool active = true,
      String? seen,
      String? revoked,
      String? registered,
    }) => {
      'session_id': '00000000-0000-4000-8000-00000000000$id',
      'label': label,
      'current': current,
      'active': active,
      'last_seen_at': seen,
      'registered_at': registered,
      'revoked_at': revoked,
    };
    final here = row(
      '1',
      'Windows installation',
      current: true,
      seen: ago(0),
      registered: ago(900),
    );
    final phone = row(
      '2',
      'Android installation',
      seen: ago(6),
      registered: ago(400),
    );
    return switch (device) {
      DemoDevices.one => [here],
      DemoDevices.several => [here, phone],
      DemoDevices.earlier => [
        here,
        row('3', 'Earlier sign-in; device unknown'),
      ],
      _ => [
        here,
        row(
          '4',
          'Android installation',
          active: false,
          seen: ago(200),
          registered: ago(1200),
          revoked: ago(100),
        ),
        row(
          '5',
          'Windows installation',
          active: false,
          seen: ago(700),
          registered: ago(1500),
        ),
      ],
    };
  }

  @override
  Future<void> revoke(DeviceRow device) async =>
      said('That sign-in ends here.');
  @override
  Future<bool> deleteAccount() async {
    set(() => phase = ConnectionPhase.deleted);
    return false;
  }

  @override
  Future<void> removeProfile() async => said('The profile goes here.');
  @override
  Future<String> newSecret() async =>
      'demo-only-this-opens-nothing-so-it-can-show';
  @override
  Future<bool> saveBackup(String secret) async => true;
  @override
  Future<BackupContents?> checkBackup(String secret) async => BackupContents(
    name: session.profile.name,
    created: DateTime.now()
        .subtract(const Duration(days: 3))
        .toUtc()
        .toIso8601String(),
    records: 214,
    drafts: 2,
    lifeVersions: 87,
    filesListed: files,
    connected: true,
    thisProfile: true,
  );
  @override
  Future<BackupNote?> lastBackup() async => switch (backup) {
    DemoBackup.none || DemoBackup.failed => null,
    final kept => BackupNote(
      DateTime.now()
          .subtract(const Duration(days: 3))
          .toUtc()
          .toIso8601String(),
      changed: kept == DemoBackup.changed,
    ),
  };
}

/// Show a state: every state a tab can be in, for reviewing the demo. Real
/// profiles reach these only through what really happens.
class DemoStateBar extends StatelessWidget {
  const DemoStateBar({super.key, required this.tab, required this.demo});
  final String tab;
  final DemoProfile demo;

  Widget picker<T>(T value, List<(T, String)> options, ValueChanged<T> onPick) =>
      DropdownButtonFormField<T>(
        key: ValueKey('demo-state-$tab'),
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Show a state'),
        items: [
          for (final (v, label) in options)
            DropdownMenuItem(value: v, child: Text(label)),
        ],
        onChanged: (v) {
          if (v != null) onPick(v);
        },
      );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      switch (tab) {
        'Connection' => picker<ConnectionPhase>(
          demo.shown,
          [for (final e in _phaseNames.entries) (e.key, e.value)],
          (v) => demo.set(() => demo.phase = v),
        ),
        'Devices' => picker<DemoDevices>(
          demo.device,
          [for (final d in DemoDevices.values) (d, d.label)],
          (v) => demo.set(() => demo.device = v),
        ),
        _ => picker<DemoBackup>(
          demo.backup,
          [for (final b in DemoBackup.values) (b, b.label)],
          (v) => demo.set(() => demo.backup = v),
        ),
      },
      if (demo.note != null) ...[
        const SizedBox(height: Space.sm),
        InlineNotice(demo.note!, live: true),
      ],
      SizedBox(height: Space.cardGapOf(context)),
    ],
  );
}
