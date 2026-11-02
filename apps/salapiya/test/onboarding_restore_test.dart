import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/local/local_runtime.dart';
import 'package:salapiya/local/local_store.dart';
import 'package:salapiya/onboarding/onboarding_actions.dart';
import 'package:salapiya/onboarding/restore_page.dart';
import 'package:salapiya/p0/portable_recovery.dart';
import 'package:salapiya/profile/profile_actions.dart';
import 'package:salapiya/profile/profile_data.dart';

import 'local_money_journey.dart' show localSettle, localTap, localWait;
import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

const fileName = 'salapiya-2026-11-02-a1b2c3d4.salapiya';

/// A sealed backup of a real profile, as a file a person would hold.
class Backup {
  const Backup(this.bytes, this.secret, this.owner, this.bundle);
  final List<int> bytes;
  final String secret, owner;
  final Map<String, dynamic> bundle;
}

Future<Backup> makeBackup(
  WidgetTester tester, {
  bool connected = false,
  String name = 'Amihan',
}) async {
  final dir = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('salapiya-backup-'),
  ))!;
  final settings = GallerySettings();
  final runtime = LocalRuntime(
    LocalProfiles(dir, MemoryProfileVault()),
    settings,
  );
  final backup = await tester.runAsync(() async {
    await runtime.create(name, ThemeMode.system);
    final store = runtime.session!.localFinance.store;
    if (connected) {
      await store.stageConnection(newLocalId(), 'amihan@example.com', newLocalId());
    }
    final secret = await PortableRecovery.newRecoverySecret();
    final bundle = await LocalBackup.capture(store);
    return Backup(
      await LocalBackup.seal(bundle, secret),
      secret,
      store.owner,
      bundle,
    );
  });
  await closeWithWidgetClock(tester, runtime.close);
  runtime.dispose();
  settings.dispose();
  await tester.runAsync(() => dir.delete(recursive: true));
  return backup!;
}

/// A device with no profile, showing the Restore page.
Future<void> onNewDevice(
  WidgetTester tester,
  List<int> Function() file,
  Future<void> Function(LocalRuntime runtime, MemoryProfileVault vault) body, {
  Future<PickedBackup?> Function()? picker,
  void Function(MemoryProfileVault vault, Directory dir)? prepare,
  VoidCallback? onDone,
  bool reopen = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 1400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final dir = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('salapiya-new-device-'),
  ))!;
  final vault = MemoryProfileVault();
  prepare?.call(vault, dir);
  final settings = GallerySettings();
  final runtime = LocalRuntime(LocalProfiles(dir, vault), settings);
  try {
    if (reopen) await tester.runAsync(runtime.reopen);
    await tester.pumpWidget(
      MaterialApp(
        theme: SalapiyaTheme.build(Brightness.light),
        themeAnimationDuration: Duration.zero,
        home: RestorePage(
          actions: LocalOnboardingActions(
            runtime,
            picker:
                picker ?? () async => PickedBackup(fileName, file()),
          ),
          onDone: onDone ?? () {},
        ),
      ),
    );
    await localSettle(tester);
    await body(runtime, vault);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await localSettle(tester);
    await closeWithWidgetClock(tester, runtime.close);
    runtime.dispose();
    settings.dispose();
    await tester.runAsync(() => dir.delete(recursive: true));
  }
}

Finder get secretField => find.descendant(
  of: find.byKey(const ValueKey('backup-secret')),
  matching: find.byType(TextField),
);

Future<void> choose(WidgetTester tester) =>
    localTap(tester, find.byKey(const ValueKey('restore-choose')));

Future<void> enter(WidgetTester tester, String secret) async {
  await tester.enterText(secretField, secret);
  await tester.pump();
}

Future<void> open(WidgetTester tester) =>
    localTap(tester, find.byKey(const ValueKey('restore-open')));

Future<void> toReview(WidgetTester tester, Backup backup) async {
  await choose(tester);
  await enter(tester, backup.secret);
  await open(tester);
  await localWait(
    tester,
    () => find.byKey(const ValueKey('restore-review')).evaluate().isNotEmpty,
  );
}

/// A real restore builds and checks a whole encrypted database, which can
/// outlast `localWait` on a busy machine or a cold start.
Future<void> longWait(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 1500 && !ready(); i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
  }
  expect(ready(), isTrue, reason: 'The restore did not finish');
  await localSettle(tester);
}

Future<void> confirmRestore(WidgetTester tester) async {
  await localTap(tester, find.byKey(const ValueKey('restore-confirm')));
  // Not localTap: its settle can catch the button's spinner, which never stops
  // on the fake clock while the real restore waits for real time. Callers wait
  // with localWait.
  await tester.runAsync(() => tester.tap(find.text('Restore')));
  await tester.pump();
}

void main() {
  testWidgets('a backup opens, says what it holds, and comes back', (
    tester,
  ) async {
    final backup = await makeBackup(tester);
    var done = false;
    await onNewDevice(
      tester,
      () => backup.bytes,
      (runtime, _) async {
        await toReview(tester, backup);
        expect(find.textContaining('Saved'), findsWidgets);
        expect(find.text('What doesn’t come back'), findsOneWidget);
        expect(find.text('Reminders'), findsOneWidget);
        expect(find.textContaining('not a place in a group'), findsOneWidget);
        expect(runtime.session, isNull);

        await localTap(tester, find.byKey(const ValueKey('restore-confirm')));
        expect(find.text('Restore Amihan on this device?'), findsOneWidget);
        expect(find.textContaining('backup file doesn’t change'), findsOne);
        expect(find.textContaining('Devices'), findsOneWidget);
        await localTap(tester, find.text('Cancel'));
        expect(runtime.session, isNull);

        await confirmRestore(tester);
        await longWait(tester, () => runtime.session != null);
        expect(runtime.session!.profile.name, 'Amihan');
        expect(runtime.session!.localFinance.store.owner, backup.owner);
        expect(find.text('Amihan is back on this device'), findsOneWidget);
        expect(find.byType(BackButton), findsNothing);
        await localTap(tester, find.byKey(const ValueKey('restore-open-app')));
        expect(done, isTrue);
      },
      onDone: () => done = true,
    );
  });

  testWidgets('Open waits for a file and a secret', (tester) async {
    final backup = await makeBackup(tester);
    await onNewDevice(tester, () => backup.bytes, (runtime, _) async {
      bool enabled() => tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(const ValueKey('restore-open')),
              matching: find.byType(FilledButton),
            ),
          )
          .enabled;
      expect(enabled(), isFalse);
      await enter(tester, backup.secret);
      expect(enabled(), isFalse);
      await enter(tester, '');
      await choose(tester);
      expect(enabled(), isFalse);
      await enter(tester, backup.secret);
      expect(enabled(), isTrue);
    });
  });

  testWidgets('a wrong secret errors on its field and keeps the file', (
    tester,
  ) async {
    final backup = await makeBackup(tester);
    await onNewDevice(tester, () => backup.bytes, (runtime, _) async {
      await choose(tester);
      expect(find.text(fileName), findsOneWidget);
      await enter(tester, await PortableRecovery.newRecoverySecret());
      await open(tester);
      final field = find.byKey(const ValueKey('backup-secret'));
      expect(
        find.descendant(
          of: field,
          matching: find.text('This secret doesn’t open this backup.'),
        ),
        findsOneWidget,
      );
      expect(find.text(fileName), findsOneWidget);
      await enter(tester, backup.secret);
      expect(find.text('This secret doesn’t open this backup.'), findsNothing);
      await open(tester);
      await localWait(
        tester,
        () =>
            find.byKey(const ValueKey('restore-review')).evaluate().isNotEmpty,
      );
    });
  });

  testWidgets('a secret that isn\'t a whole secret says so on its field', (
    tester,
  ) async {
    final backup = await makeBackup(tester);
    await onNewDevice(tester, () => backup.bytes, (runtime, _) async {
      await choose(tester);
      await enter(tester, 'too short');
      await open(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('backup-secret')),
          matching: find.textContaining('whole recovery secret'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('a file that isn\'t a backup errors on the file', (tester) async {
    await onNewDevice(tester, () => utf8.encode('just a note'), (
      runtime,
      _,
    ) async {
      await choose(tester);
      await enter(tester, await PortableRecovery.newRecoverySecret());
      await open(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('restore-file')),
          matching: find.textContaining('isn’t a complete Salapiya backup'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('a file too big to read errors on the file', (tester) async {
    await onNewDevice(
      tester,
      () => const [],
      (runtime, _) async {
        await choose(tester);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('restore-file')),
            matching: find.textContaining('too big'),
          ),
          findsOneWidget,
        );
      },
      picker: () async =>
          reject('This file is too big, or it can’t be read. Choose another.'),
    );
  });

  testWidgets('closing the file window changes nothing', (tester) async {
    await onNewDevice(tester, () => const [], (runtime, _) async {
      await choose(tester);
      expect(find.text('Choose backup file'), findsOneWidget);
      expect(find.textContaining('.salapiya'), findsOneWidget);
    }, picker: () async => null);
  });

  testWidgets('a profile already here isn\'t offered, before any work', (
    tester,
  ) async {
    final backup = await makeBackup(tester);
    await onNewDevice(
      tester,
      () => backup.bytes,
      (runtime, _) async {
        await toReview(tester, backup);
        expect(
          find.textContaining('already on this device'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('restore-confirm')), findsNothing);
        await localTap(tester, find.byKey(const ValueKey('restore-again')));
        expect(find.byKey(const ValueKey('restore-form')), findsOneWidget);
        final staged = (await tester.runAsync(
          () => runtime.profiles.directory
              .list()
              .where((f) => f.path.endsWith('.staging'))
              .length,
        ))!;
        expect(staged, 0);
      },
      prepare: (vault, dir) {
        File('${dir.path}/${backup.owner}.sqlite').writeAsStringSync('kept');
        vault.value = jsonEncode({'version': 1, 'phase': 'empty'});
      },
    );
  });

  testWidgets('the secret goes once it\'s used, and reaches no log or draft', (
    tester,
  ) async {
    final backup = await makeBackup(tester);
    final logged = <String>[];
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) => logged.add(message ?? '');
    try {
      await onNewDevice(tester, () => backup.bytes, (runtime, vault) async {
        await choose(tester);
        await enter(tester, backup.secret);
        expect(tester.widget<TextField>(secretField).obscureText, isTrue);
        expect(
          tester.widget<TextField>(secretField).enableIMEPersonalizedLearning,
          isFalse,
        );
        await open(tester);
        await localWait(
          tester,
          () => find
              .byKey(const ValueKey('restore-review'))
              .evaluate()
              .isNotEmpty,
        );
        expect(secretField, findsNothing);
        for (final field in tester.widgetList<EditableText>(
          find.byType(EditableText),
        )) {
          expect(field.controller.text, isNot(contains(backup.secret)));
        }
        await confirmRestore(tester);
        await longWait(tester, () => runtime.session != null);
        expect(vault.value, isNot(contains(backup.secret)));
        final drafts = (await tester.runAsync(
          () => runtime.session!.localFinance.store.db.getAll(
            'SELECT values_json FROM local_draft',
          ),
        ))!;
        for (final row in drafts) {
          expect(row['values_json'], isNot(contains(backup.secret)));
        }
        expect(logged.join('\n'), isNot(contains(backup.secret)));
      });
    } finally {
      debugPrint = print;
    }
  });

  testWidgets('a restore that stops part-way carries on, with no second copy', (
    tester,
  ) async {
    final backup = await makeBackup(tester);
    await onNewDevice(tester, () => backup.bytes, (runtime, vault) async {
      vault.failAt = 2;
      await toReview(tester, backup);
      await confirmRestore(tester);
      await longWait(
        tester,
        () => find.text('Try again').evaluate().isNotEmpty,
      );
      expect(runtime.session, isNull);
      expect(find.textContaining('didn’t finish'), findsOneWidget);
      expect((jsonDecode(vault.value!) as Map)['phase'], 'restoring');

      // A second restore would be refused; carrying on needs no dialog.
      await localTap(tester, find.byKey(const ValueKey('restore-confirm')));
      await longWait(tester, () => runtime.session != null);
      expect((jsonDecode(vault.value!) as Map)['phase'], 'ready');
      expect(find.text('Amihan is back on this device'), findsOneWidget);
      final files = (await tester.runAsync(
        () => runtime.profiles.directory
            .list()
            .map((f) => f.path)
            .where((f) => f.endsWith('.sqlite') || f.endsWith('.staging'))
            .toList(),
      ))!;
      expect(files, hasLength(1));
      expect(files.single, endsWith('${backup.owner}.sqlite'));
    });
  });

  testWidgets('a restart after the checkpoint finishes the restore', (
    tester,
  ) async {
    final backup = await makeBackup(tester);
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('salapiya-restart-'),
    ))!;
    final vault = MemoryProfileVault();
    final first = LocalProfiles(dir, vault);
    await tester.runAsync(() async {
      try {
        await first.restore(backup.bundle, interruptActivation: true);
      } on StateError {
        // Stopped as if the app closed.
      }
    });
    expect((jsonDecode(vault.value!) as Map)['phase'], 'restoring');
    final settings = GallerySettings();
    final runtime = LocalRuntime(LocalProfiles(dir, vault), settings);
    await tester.runAsync(runtime.reopen);
    expect(runtime.session!.profile.name, 'Amihan');
    expect((jsonDecode(vault.value!) as Map)['phase'], 'ready');
    await closeWithWidgetClock(tester, runtime.close);
    runtime.dispose();
    settings.dispose();
    await tester.runAsync(() => dir.delete(recursive: true));
  });

  testWidgets('a restart before the checkpoint changed nothing', (
    tester,
  ) async {
    final backup = await makeBackup(tester);
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('salapiya-restart-'),
    ))!;
    final vault = MemoryProfileVault();
    final first = LocalProfiles(dir, vault);
    await tester.runAsync(() async {
      try {
        await first.restore(backup.bundle, interrupt: true);
      } on StateError {
        // Stopped as if the app closed.
      }
    });
    expect(vault.value, isNull);
    final settings = GallerySettings();
    final runtime = LocalRuntime(LocalProfiles(dir, vault), settings);
    await tester.runAsync(runtime.reopen);
    expect(runtime.session, isNull);
    await closeWithWidgetClock(tester, runtime.close);
    runtime.dispose();
    settings.dispose();
    await tester.runAsync(() => dir.delete(recursive: true));
  });

  testWidgets('a connected backup reaches Connection as a restored backup', (
    tester,
  ) async {
    final backup = await makeBackup(tester, connected: true);
    await onNewDevice(tester, () => backup.bytes, (runtime, _) async {
      await toReview(tester, backup);
      expect(find.text('amihan@example.com'), findsOneWidget);
      expect(find.text('After you sign in'), findsOneWidget);
      await confirmRestore(tester);
      await longWait(tester, () => runtime.session != null);
      expect(find.textContaining('Sign in with amihan@example.com'), findsOne);
      expect(find.byKey(const ValueKey('restore-connection')), findsOneWidget);
      // This test build can't connect, so the tab itself reads that way. The
      // stage saved is what Connection shows as a restored backup.
      final facts = LocalProfileActions(runtime.session!).facts();
      expect(facts.bound, 'restored');
      expect(
        phaseOf(ConnectionFacts(bound: facts.bound)),
        ConnectionPhase.restoring,
      );
    });
  });

  test('a backup says what it holds, old or new', () {
    final older = BackupContents.from({
      'name': 'Amihan',
      'createdUtc': '2025-01-02T03:04:05.000Z',
      'commands': [{}, {}],
      'drafts': [{}],
      'format': 1,
      'owner': 'a',
    }, null);
    expect(older.records, 2);
    expect(older.lifeVersions, 0);
    expect(older.filesListed, isNull);
    expect(older.connected, isFalse);
    expect(older.thisProfile, isFalse);
    expect(older.toCheck, 0);
    expect(filesLine(older.filesListed), 'Not available in this backup');

    final connected = BackupContents.from({
      'name': 'Amihan',
      'createdUtc': '2026-01-02T03:04:05.000Z',
      'commands': [],
      'drafts': [],
      'format': 3,
      'owner': 'a',
      'connection': {'email': 'amihan@example.com'},
      'intents': [{}, {}],
      'sharedIntents': [{}],
      'life': {
        'revisions': [{}],
        'intents': [{}],
      },
      'financialCoverage': {'supportingFileMetadata': 0},
    }, null);
    expect(connected.email, 'amihan@example.com');
    expect(connected.toCheck, 4);
    expect(filesLine(connected.filesListed), 'No files listed');
  });
}
