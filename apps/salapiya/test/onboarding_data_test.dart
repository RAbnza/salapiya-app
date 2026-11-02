import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/onboarding/onboarding_data.dart';
import 'package:salapiya/onboarding/records_map.dart';

import 'local_test_support.dart';

void main() {
  group('what the device holds', () {
    late Directory dir;
    late MemoryProfileVault vault;
    late LocalProfiles profiles;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('salapiya-start-');
      vault = MemoryProfileVault();
      profiles = LocalProfiles(dir, vault);
    });
    tearDown(() async {
      await profiles.close();
      await dir.delete(recursive: true);
    });

    /// Whether the rule takes a new profile, which leaves it open.
    Future<bool> ruleAllows() async {
      try {
        await profiles.create('Amihan', {});
        await profiles.close();
        return true;
      } on LocalRuleException {
        return false;
      }
    }

    test('a device that has never held a profile', () async {
      final start = await readDeviceStart(profiles);
      expect(start.phase, isNull);
      expect(start.canCreate, isTrue);
      expect(start.removedLast, isFalse);
      expect(start.unfinished, isFalse);
      expect(await ruleAllows(), isTrue);
    });

    test('a folder that was never created reads as fresh', () async {
      final gone = LocalProfiles(
        Directory('${dir.path}/not-here'),
        MemoryProfileVault(),
      );
      expect((await readDeviceStart(gone)).canCreate, isTrue);
    });

    test('after a removal with nothing left', () async {
      vault.value = jsonEncode({'version': 1, 'phase': 'empty'});
      final start = await readDeviceStart(profiles);
      expect(start.removedLast, isTrue);
      expect(start.canCreate, isTrue);
      expect(await ruleAllows(), isTrue);
    });

    test('a kept profile stops a new one, and the rule agrees', () async {
      final id = newLocalId();
      await File('${dir.path}/$id.sqlite').writeAsString('kept');
      vault.value = jsonEncode({
        'version': 1,
        'phase': 'empty',
        'preserved': {'id': id, 'key': 'never shown', 'name': 'Amihan'},
      });
      final start = await readDeviceStart(profiles);
      expect(start.keptFiles, isTrue);
      expect(start.keptName, 'Amihan');
      expect(start.canCreate, isFalse);
      expect(start.removedLast, isFalse);
      expect(await ruleAllows(), isFalse);
    });

    test('files with no name say so, and the rule agrees', () async {
      await File('${dir.path}/${newLocalId()}.sqlite-wal').writeAsString('');
      vault.value = jsonEncode({'version': 1, 'phase': 'empty'});
      final start = await readDeviceStart(profiles);
      expect(start.keptFiles, isTrue);
      expect(start.keptName, isNull);
      expect(await ruleAllows(), isFalse);
    });

    test('a first run that stopped part-way keeps its name', () async {
      vault.value = jsonEncode({
        'version': 1,
        'phase': 'initializing',
        'id': newLocalId(),
        'name': 'Amihan',
      });
      await File('${dir.path}/${newLocalId()}.sqlite').writeAsString('');
      final start = await readDeviceStart(profiles);
      expect(start.unfinished, isTrue);
      expect(start.pendingName, 'Amihan');
      expect(start.keptFiles, isFalse);
      expect(start.canCreate, isFalse);
      expect(await ruleAllows(), isFalse);
    });

    test('a restore that stopped part-way counts as unfinished', () async {
      vault.value = jsonEncode({
        'version': 1,
        'phase': 'restoring',
        'name': 'Amihan',
      });
      final start = await readDeviceStart(profiles);
      expect(start.unfinished, isTrue);
      expect(start.pendingName, 'Amihan');
      expect(start.canCreate, isFalse);
      expect(await ruleAllows(), isFalse);
    });

    test('an open profile can\'t be replaced, and the rule agrees', () async {
      vault.value = jsonEncode({'version': 1, 'phase': 'ready', 'id': 'x'});
      expect((await readDeviceStart(profiles)).canCreate, isFalse);
      expect(await ruleAllows(), isFalse);
    });

    test('a stored value that can\'t be read isn\'t a crash', () async {
      vault.value = 'not json';
      expect((await readDeviceStart(profiles)).phase, isNull);
    });

    test('a failed start reads its stage without writing', () async {
      vault.value = jsonEncode({'version': 1, 'phase': 'removing'});
      final writes = vault.writes;
      final facts = await readStartupFacts(profiles);
      expect(facts.phase, 'removing');
      expect(facts.folder, dir.path);
      expect(vault.writes, writes);
    });
  });

  group('why it couldn\'t open', () {
    test('each rule\'s words find their problem', () {
      for (final (message, problem) in [
        (
          'Salapiya can’t reach the key that opens your profile. Your files '
              'are safe.',
          StartupProblem.keyUnavailable,
        ),
        (
          'Your profile’s records aren’t on this device any more.',
          StartupProblem.missingRecords,
        ),
        (
          'This version of Salapiya can’t open your records. Update Salapiya.',
          StartupProblem.newerVersion,
        ),
        ('Your records don’t add up.', StartupProblem.damaged),
        ('A restore didn’t finish.', StartupProblem.restoreUnfinished),
        (
          'Some of this profile’s files are links, so nothing was removed.',
          StartupProblem.removalUnfinished,
        ),
        ('Something new.', StartupProblem.unknown),
        (null, StartupProblem.unknown),
      ]) {
        expect(startupProblemOf(message), problem, reason: '$message');
      }
    });

    test('a stage that stopped part-way comes first', () {
      expect(
        startupProblemOf(null, phase: 'removing'),
        StartupProblem.removalUnfinished,
      );
      expect(
        startupProblemOf('Your records don’t add up.', phase: 'restoring'),
        StartupProblem.restoreUnfinished,
      );
      expect(startupProblemOf(null, phase: 'ready'), StartupProblem.unknown);
    });

    test('nothing offers a restore this installation would refuse', () {
      for (final problem in StartupProblem.values) {
        for (final desktop in [true, false]) {
          final w = startupWords(problem, desktop: desktop);
          expect(w.title, isNotEmpty);
          expect(w.happened, isNotEmpty);
          expect(w.safe, isNotEmpty);
          expect(w.canDo, isNotEmpty);
          if (w.canDo.contains('backup')) {
            expect(w.canDo, contains('another device'), reason: '$problem');
          }
        }
      }
    });

    test('the account named follows the platform', () {
      expect(
        startupWords(StartupProblem.keyUnavailable, desktop: true).canDo,
        contains('Windows account'),
      );
      expect(
        startupWords(StartupProblem.keyUnavailable, desktop: false).canDo,
        contains('account on this phone'),
      );
    });

    test('a restore or removal says which way it stopped', () {
      const two = 'A restore didn’t finish, and two copies are here.';
      expect(
        startupWords(
          StartupProblem.restoreUnfinished,
          message: two,
          desktop: true,
        ).happened,
        two,
      );
      const links = 'Some of this profile’s files are links, so nothing was '
          'removed.';
      expect(
        startupWords(
          StartupProblem.removalUnfinished,
          message: links,
          desktop: true,
        ).happened,
        links,
      );
      expect(
        startupWords(
          StartupProblem.removalUnfinished,
          message: 'Invalid profile identity. Existing files are preserved.',
          desktop: true,
        ).happened,
        isNot(contains('Invalid')),
      );
    });
  });

  group('the map', () {
    test('starting here sends nothing anywhere', () {
      final places = recordsPlaces(RecordsView.local);
      expect(places[RecordsPlace.device]!.lit, isTrue);
      for (final place in [RecordsPlace.service, RecordsPlace.google]) {
        expect(places[place]!.lit, isFalse);
        expect(places[place]!.holds, 'Not used');
      }
    });

    test('signing in alone puts no records on the service', () {
      final places = recordsPlaces(RecordsView.chosen);
      expect(places[RecordsPlace.google]!.lit, isTrue);
      expect(places[RecordsPlace.service]!.lit, isFalse);
      expect(places[RecordsPlace.service]!.holds, isNot(contains('record')));
    });

    test('syncing says what goes to the service and what doesn\'t', () {
      final places = recordsPlaces(RecordsView.google);
      expect(places[RecordsPlace.service]!.lit, isTrue);
      expect(places[RecordsPlace.service]!.holds, contains('file list'));
      expect(places[RecordsPlace.google]!.holds, isNot(contains('record')));
      expect(
        recordsWords(RecordsView.google, desktop: true),
        contains('File contents stay on this device'),
      );
    });

    test('a restore goes nowhere until someone signs in', () {
      final local = recordsPlaces(RecordsView.restore);
      expect(local[RecordsPlace.backup]!.lit, isTrue);
      expect(local[RecordsPlace.service]!.lit, isFalse);
      final connected = recordsPlaces(RecordsView.restoreConnected);
      expect(connected[RecordsPlace.service]!.lit, isFalse);
      expect(connected[RecordsPlace.service]!.holds, contains('sign in'));
    });

    test('every view names every place, on one line of words', () {
      for (final view in RecordsView.values) {
        expect(recordsPlaces(view).keys, RecordsPlace.values.toSet());
        expect(recordsCaption(view), isNotEmpty);
        expect(
          recordsWords(view, desktop: true).length,
          greaterThanOrEqualTo(recordsCaption(view).length - 10),
        );
      }
      expect(
        recordsWords(RecordsView.chosen, desktop: false),
        contains('an Android device'),
      );
    });
  });
}
