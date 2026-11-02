import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../connected/connection_view.dart';
import '../finance/bounded_file_read.dart';
import '../local/local_profiles.dart';
import '../local/local_runtime.dart';
import '../profile/profile_actions.dart';
import '../profile/profile_data.dart';
import 'onboarding_data.dart';

/// A backup file someone chose. It stays in memory, so a wrong secret doesn't
/// mean choosing it again, and it goes with the page.
class PickedBackup {
  const PickedBackup(this.name, this.bytes);
  final String name;
  final List<int> bytes;
}

/// A backup its secret has opened.
class OpenedBackup {
  const OpenedBackup(this.bundle, this.contents, {required this.alreadyHere});
  final Map<String, dynamic> bundle;
  final BackupContents contents;

  /// This profile's files are on this device, so the rules would refuse it.
  final bool alreadyHere;
}

/// Everything the first-run screens can ask for, before a profile is open.
/// The real build goes to the runtime; tests and the demo stand in.
abstract interface class OnboardingActions {
  /// Tells the screens when [facts] may have changed.
  Listenable get changes;

  /// The demo says what would have happened, and nothing does.
  bool get demo;

  /// Read at the moment it's needed: a step can change these.
  ConnectionFacts facts();

  /// A profile has opened, so the first-run pages have done their job.
  bool get profileOpen;
  Future<DeviceStart> deviceStart();

  /// The theme showing now.
  ThemeMode get theme;

  /// Shows [mode] straight away. Only a new profile keeps it.
  void showTheme(ThemeMode mode);
  Future<void> create(String name, ThemeMode theme);

  /// Carries on a first run or restore that stopped part-way. Doing it again
  /// would be refused by the check the first try set.
  Future<void> resume();
  Future<void> connect();
  Future<void> cancelSignIn();
  Future<void> lookup();
  Future<void> confirmConnection();

  /// Forgets the account chosen, with nothing uploaded.
  Future<void> dontConnect();

  /// What a new profile on this account would be called.
  String newProfileName();

  /// Null when the user closed the file window.
  Future<PickedBackup?> pickBackup();
  Future<OpenedBackup> open(PickedBackup backup, String secret);
  Future<void> restore(OpenedBackup backup);

  /// Goes to the Connection tab, leaving the first-run pages behind.
  void openConnectionTab(BuildContext context);
}

Future<PickedBackup?> _pick() async {
  final file = await FilePicker.pickFile();
  if (file == null) return null;
  return PickedBackup(
    file.name,
    await readBoundedFinancialFile(file, LocalBackup.maxBytes + 128),
  );
}

class LocalOnboardingActions implements OnboardingActions {
  LocalOnboardingActions(this.runtime, {this.picker = _pick});
  final LocalRuntime runtime;
  final Future<PickedBackup?> Function() picker;

  @override
  bool get demo => false;
  @override
  Listenable get changes => Listenable.merge([runtime, runtime.connected]);

  @override
  ConnectionFacts facts() {
    final c = runtime.connected;
    final flow = c.flow;
    final user = flow?.client.auth.currentUser;
    return ConnectionFacts(
      configured: c.configured,
      signingIn: flow?.pending == true,
      signedIn: user != null,
      busy: c.busy,
      email: user?.email,
      error: c.error,
      signInOutcome: flow?.outcome,
      cloudName: c.cloud?['name'] as String?,
    );
  }

  @override
  bool get profileOpen => runtime.session != null;
  @override
  Future<DeviceStart> deviceStart() => readDeviceStart(runtime.profiles);
  @override
  ThemeMode get theme => runtime.settings.themeMode;
  @override
  void showTheme(ThemeMode mode) =>
      runtime.settings.change(() => runtime.settings.themeMode = mode);
  @override
  Future<void> create(String name, ThemeMode theme) =>
      runtime.create(name, theme);
  @override
  Future<void> resume() => runtime.reopen();
  @override
  Future<void> connect() => runtime.connected.signIn();

  @override
  Future<void> cancelSignIn() async {
    try {
      await runtime.connected.flow?.cancel();
    } on StateError {
      // The answer is being read, so it's too late to cancel: it lands next.
    }
  }

  @override
  Future<void> lookup() => runtime.connected.lookup();
  @override
  Future<void> confirmConnection() => runtime.connected.confirmConnection();

  @override
  Future<void> dontConnect() async {
    await runtime.connected.cancelConnection();
    await runtime.connected.signOut();
  }

  @override
  String newProfileName() =>
      (runtime
                      .connected
                      .flow
                      ?.client
                      .auth
                      .currentUser
                      ?.userMetadata?['full_name']
                  as String? ??
              'My profile')
          .trim();

  @override
  Future<PickedBackup?> pickBackup() => picker();

  @override
  Future<OpenedBackup> open(PickedBackup backup, String secret) async {
    final bundle = await openBackup(backup.bytes, secret);
    final owner = bundle['owner'] as String;
    return OpenedBackup(
      bundle,
      BackupContents.from(bundle, null),
      alreadyHere: await File(
        p.join(runtime.profiles.directory.path, '$owner.sqlite'),
      ).exists(),
    );
  }

  @override
  Future<void> restore(OpenedBackup backup) async {
    final store = await runtime.profiles.restore(backup.bundle);
    await runtime.activate(store);
  }

  @override
  void openConnectionTab(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => ConnectionPage(runtime: runtime)),
      (route) => route.isFirst,
    );
  }
}
