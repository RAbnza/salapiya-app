import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/local/local_runtime.dart';
import 'package:salapiya/onboarding/onboarding_actions.dart';
import 'package:salapiya/onboarding/onboarding_data.dart';
import 'package:salapiya/onboarding/setup_page.dart';
import 'package:salapiya/onboarding/welcome_page.dart';

import 'local_money_journey.dart' show localSettle, localTap, localWait;
import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

/// The real app, on a real encrypted store, from a device with no profile.
Future<void> onDevice(
  WidgetTester tester,
  Future<void> Function(LocalRuntime runtime, MemoryProfileVault vault) body, {
  void Function(MemoryProfileVault vault, Directory dir)? prepare,
  void Function(MemoryProfileVault vault)? after,
  ThemeMode theme = ThemeMode.system,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final dir = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('salapiya-setup-'),
  ))!;
  final vault = MemoryProfileVault();
  prepare?.call(vault, dir);
  final settings = GallerySettings()..themeMode = theme;
  final runtime = LocalRuntime(LocalProfiles(dir, vault), settings);
  try {
    await tester.runAsync(() async {
      await runtime.reopen();
      // Its queue is a Future, which deadlocks if it's made on the fake clock.
      runtime.connected.closed;
    });
    after?.call(vault);
    await tester.pumpWidget(
      SalapiyaApp(production: true, settings: settings, localRuntime: runtime),
    );
    await localSettle(tester);
    final greeting = find.byKey(const ValueKey('greeting-start'));
    if (greeting.evaluate().isNotEmpty) await localTap(tester, greeting);
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

Future<void> openSetup(WidgetTester tester) async {
  await localTap(tester, find.byKey(const ValueKey('welcome-local')));
  expect(find.byType(ProfileSetupPage), findsOneWidget);
}

Future<void> enterName(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextField), name);
  await tester.pump();
}

void main() {
  testWidgets('a profile is created and the page goes', (tester) async {
    await onDevice(tester, (runtime, _) async {
      await openSetup(tester);
      await enterName(tester, 'Amihan');
      await localTap(tester, find.byKey(const ValueKey('setup-create')));
      await localWait(tester, () => runtime.session != null);
      expect(find.byType(ProfileSetupPage), findsNothing);
      expect(runtime.session!.profile.name, 'Amihan');
    });
  });

  testWidgets('the theme chosen is the profile\'s', (tester) async {
    await onDevice(tester, (runtime, _) async {
      await openSetup(tester);
      await enterName(tester, 'Amihan');
      await localTap(tester, find.text('Dark'));
      await localTap(tester, find.byKey(const ValueKey('setup-create')));
      await localWait(tester, () => runtime.session != null);
      expect(runtime.settings.themeMode, ThemeMode.dark);
    });
  });

  testWidgets('picking a theme shows it straight away', (tester) async {
    await onDevice(tester, (runtime, _) async {
      await openSetup(tester);
      Brightness shown() =>
          Theme.of(tester.element(find.byType(ProfileSetupPage))).brightness;
      expect(shown(), Brightness.light);
      await localTap(tester, find.text('Dark'));
      expect(runtime.settings.themeMode, ThemeMode.dark);
      expect(shown(), Brightness.dark);
      await localTap(tester, find.text('Light'));
      expect(shown(), Brightness.light);
    });
  });

  testWidgets('leaving puts the theme back, because nothing keeps it', (
    tester,
  ) async {
    await onDevice(tester, (runtime, _) async {
      await openSetup(tester);
      await localTap(tester, find.text('Dark'));
      await localTap(tester, find.byKey(const ValueKey('setup-cancel')));
      expect(find.text('Discard your changes?'), findsOneWidget);
      await localTap(tester, find.text('Keep editing'));
      expect(runtime.settings.themeMode, ThemeMode.dark);
      await localTap(tester, find.byKey(const ValueKey('setup-cancel')));
      await localTap(tester, find.text('Discard changes'));
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(runtime.settings.themeMode, ThemeMode.system);
    });
  });

  testWidgets('Back puts the theme back too', (tester) async {
    await onDevice(tester, (runtime, _) async {
      await openSetup(tester);
      await localTap(tester, find.text('Light'));
      await tester.binding.handlePopRoute();
      await localSettle(tester);
      await localTap(tester, find.text('Discard changes'));
      expect(runtime.settings.themeMode, ThemeMode.system);
    });
  });

  testWidgets('the switch starts on the theme that\'s showing', (tester) async {
    await onDevice(
      tester,
      (runtime, _) async {
        await openSetup(tester);
        // Nothing has changed, so leaving doesn't ask.
        await localTap(tester, find.byKey(const ValueKey('setup-cancel')));
        expect(find.text('Discard your changes?'), findsNothing);
        expect(runtime.settings.themeMode, ThemeMode.dark);
      },
      after: (_) {},
      theme: ThemeMode.dark,
    );
  });

  testWidgets('a missing name errors on its field, not above it', (
    tester,
  ) async {
    await onDevice(tester, (runtime, _) async {
      await openSetup(tester);
      await localTap(tester, find.byKey(const ValueKey('setup-create')));
      final field = find.byKey(const ValueKey('setup-name'));
      expect(
        find.descendant(
          of: field,
          matching: find.textContaining('Enter a display name'),
        ),
        findsOneWidget,
      );
      expect(runtime.session, isNull);
      await enterName(tester, 'A');
      expect(find.textContaining('Enter a display name'), findsNothing);
    });
  });

  testWidgets('a refusal that isn\'t about the name stays off its field', (
    tester,
  ) async {
    await onDevice(tester, (runtime, _) async {
      await openSetup(tester);
      await tester.runAsync(
        () => File(
          '${runtime.profiles.directory.path}/${newLocalId()}.sqlite',
        ).writeAsString('kept'),
      );
      await enterName(tester, 'Amihan');
      await localTap(tester, find.byKey(const ValueKey('setup-create')));
      final message = find.textContaining('earlier profile’s files');
      expect(message, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('setup-name')),
          matching: message,
        ),
        findsNothing,
      );
    });
  });

  testWidgets('a failed Create carries on, with no second profile', (
    tester,
  ) async {
    await onDevice(tester, (runtime, vault) async {
      vault.failAt = 2;
      await openSetup(tester);
      await enterName(tester, 'Amihan');
      await localTap(tester, find.byKey(const ValueKey('setup-create')));
      await localWait(
        tester,
        () => find.text('Try again').evaluate().isNotEmpty,
      );
      expect(runtime.session, isNull);
      final id = (jsonDecode(vault.value!) as Map)['id'];
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('setup-name')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.readOnly, isTrue);

      await localTap(tester, find.byKey(const ValueKey('setup-create')));
      await localWait(tester, () => runtime.session != null);
      final saved = jsonDecode(vault.value!) as Map;
      expect(saved['id'], id);
      expect(saved['phase'], 'ready');
      expect(runtime.session!.profile.name, 'Amihan');
      final files = (await tester.runAsync(
        () => runtime.profiles.directory
            .list()
            .where((f) => f.path.endsWith('.sqlite'))
            .length,
      ))!;
      expect(files, 1);
    });
  });

  testWidgets('leaving part-way and coming back carries on too', (
    tester,
  ) async {
    await onDevice(tester, (runtime, vault) async {
      vault.failAt = 2;
      await openSetup(tester);
      await enterName(tester, 'Amihan');
      await localTap(tester, find.byKey(const ValueKey('setup-create')));
      await localWait(
        tester,
        () => find.text('Try again').evaluate().isNotEmpty,
      );
      expect(find.byKey(const ValueKey('setup-theme')), findsNothing);
      // Nothing is discarded by leaving now, so it doesn't ask.
      await localTap(tester, find.byKey(const ValueKey('setup-cancel')));
      expect(find.text('Discard your changes?'), findsNothing);
      await localSettle(tester);
      expect(find.byType(ProfileSetupPage), findsNothing);
      // The first run is still saved, so Start opens it again.
      await tester.pumpWidget(
        SalapiyaApp(
          production: true,
          settings: runtime.settings,
          localRuntime: runtime,
        ),
      );
      await localSettle(tester);
      await localTap(tester, find.byKey(const ValueKey('welcome-local')));
      await localWait(
        tester,
        () => find.text('Try again').evaluate().isNotEmpty,
      );
      await localTap(tester, find.byKey(const ValueKey('setup-create')));
      await localWait(tester, () => runtime.session != null);
      expect(runtime.session!.profile.name, 'Amihan');
    });
  });

  testWidgets('a restart part-way through a first run resumes it', (
    tester,
  ) async {
    await onDevice(
      tester,
      (runtime, vault) async {
        expect(runtime.session!.profile.name, 'Amihan');
        expect(find.byType(WelcomePage), findsNothing);
      },
      prepare: (vault, dir) {
        vault.value = jsonEncode({
          'version': 1,
          'phase': 'initializing',
          'id': newLocalId(),
          'key': base64Url.encode(List.filled(32, 7)),
          'name': 'Amihan',
          'preferences': <String, String>{},
        });
      },
    );
  });

  testWidgets('a removal cut short finishes, then Welcome says so', (
    tester,
  ) async {
    await onDevice(
      tester,
      (runtime, vault) async {
        expect((jsonDecode(vault.value!) as Map)['phase'], 'empty');
        expect(find.byType(WelcomePage), findsOneWidget);
        // Welcome reads the device after its first frame.
        await localWait(
          tester,
          () => find
              .textContaining('last profile on this device')
              .evaluate()
              .isNotEmpty,
        );
        expect(find.textContaining('Amihan'), findsNothing);
      },
      prepare: (vault, dir) {
        final id = newLocalId();
        File('${dir.path}/$id.sqlite').writeAsStringSync('left over');
        vault.value = jsonEncode({
          'version': 1,
          'phase': 'removing',
          'id': id,
          'key': base64Url.encode(List.filled(32, 7)),
          'name': 'Amihan',
        });
      },
    );
  });

  testWidgets('kept files turn Start off on a real device', (tester) async {
    await onDevice(
      tester,
      (runtime, vault) async {
        await localWait(
          tester,
          () => find.textContaining('Amihan’s files').evaluate().isNotEmpty,
        );
        await localTap(tester, find.byKey(const ValueKey('welcome-local')));
        expect(find.byType(ProfileSetupPage), findsNothing);
        final refused = await tester.runAsync(() async {
          try {
            await runtime.create('New', ThemeMode.system);
            return false;
          } on LocalRuleException {
            return true;
          }
        });
        expect(refused, isTrue);
      },
      prepare: (vault, dir) {
        final id = newLocalId();
        File('${dir.path}/$id.sqlite').writeAsStringSync('kept');
        vault.value = jsonEncode({
          'version': 1,
          'phase': 'empty',
          'preserved': {'id': id, 'name': 'Amihan'},
        });
      },
    );
  });

  testWidgets('leaving with a name typed asks first, and can stay', (
    tester,
  ) async {
    await onDevice(tester, (runtime, _) async {
      await openSetup(tester);
      await enterName(tester, 'Amihan');
      await localTap(tester, find.byKey(const ValueKey('setup-cancel')));
      expect(find.text('Discard your changes?'), findsOneWidget);
      await localTap(tester, find.text('Keep editing'));
      expect(find.byType(ProfileSetupPage), findsOneWidget);
      await localTap(tester, find.byKey(const ValueKey('setup-cancel')));
      await localTap(tester, find.text('Discard changes'));
      expect(find.byType(ProfileSetupPage), findsNothing);
      expect(find.byType(WelcomePage), findsOneWidget);
    });
  });

  testWidgets('leaving with nothing typed doesn\'t ask', (tester) async {
    await onDevice(tester, (runtime, _) async {
      await openSetup(tester);
      await localTap(tester, find.byKey(const ValueKey('setup-cancel')));
      expect(find.text('Discard your changes?'), findsNothing);
      expect(find.byType(WelcomePage), findsOneWidget);
    });
  });

  testWidgets('Don\'t connect is safe with nothing signed in', (tester) async {
    await onDevice(tester, (runtime, _) async {
      await tester.runAsync(LocalOnboardingActions(runtime).dontConnect);
      expect(runtime.connected.error, isNull);
      expect(runtime.session, isNull);
    });
  });

  testWidgets('a restore that stopped part-way picks up from Start', (
    tester,
  ) async {
    await onDevice(
      tester,
      (runtime, vault) async {
        expect(runtime.session, isNull);
        await localWait(
          tester,
          () => find.textContaining('part-way set up').evaluate().isNotEmpty,
        );
      },
      prepare: (vault, dir) {
        // A real start would finish this; here the page reads it before then.
        vault.value = jsonEncode({'version': 1, 'phase': 'empty'});
      },
      after: (vault) {
        vault.value = jsonEncode({
          'version': 1,
          'phase': 'restoring',
          'name': 'Amihan',
        });
      },
    );
  });

  test('every name refusal the form moves is still a rule', () {
    final rules = [
      'lib/local/local_profiles.dart',
      'lib/local/local_store.dart',
    ].map((f) => File(f).readAsStringSync()).join();
    for (final words in setupNameErrors) {
      expect(rules, contains(words));
    }
  });

  test('the device start the form reads is the real one', () async {
    final dir = await Directory.systemTemp.createTemp('salapiya-setup-');
    final vault = MemoryProfileVault()..failAt = 2;
    final profiles = LocalProfiles(dir, vault);
    await expectLater(profiles.create('Amihan', {}), throwsA(anything));
    final start = await readDeviceStart(profiles);
    expect(start.unfinished, isTrue);
    expect(start.pendingName, 'Amihan');
    await profiles.close();
    await dir.delete(recursive: true);
  });
}
