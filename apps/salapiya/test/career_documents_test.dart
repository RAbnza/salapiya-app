import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_demo.dart' show demoSample;
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/finance/presentation/financial_widgets.dart';
import 'package:salapiya/finance/file_store.dart';
import 'package:salapiya/finance/money_details.dart' show SavedDraftsPage;
import 'package:salapiya/life/career_documents.dart';
import 'package:salapiya/life/career_pages.dart';
import 'package:salapiya/life/life_controller.dart';
import 'package:salapiya/life/life_data.dart';
import 'package:salapiya/life/life_demo.dart';
import 'package:salapiya/life/life_domain.dart';
import 'package:salapiya/life/life_hub.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_finance_controller.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/local/local_runtime.dart';
import 'package:salapiya/local/local_store.dart';
import 'package:salapiya/prototype/scenarios.dart';

import 'local_money_journey.dart' show localSettle, localTap, localWait;
import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

const windows = TargetPlatform.windows, android = TargetPlatform.android;

/// The real store, with a file chosen by the test instead of a system picker.
class TestDocuments extends LocalLifeDocuments {
  TestDocuments(super.c, super.files);
  (String, Uint8List)? chosen;
  @override
  Future<(String, Uint8List)?> pick() async => chosen;
}

void main() {
  final bytes = File('test/fixtures/p4_receipt.png').readAsBytesSync();
  final today = civilToday();

  Future<(LocalFixture, DurableLifeController, TestDocuments)> open(
    WidgetTester tester,
  ) async {
    final f = (await tester.runAsync(LocalFixture.open))!;
    late DurableLifeController c;
    await tester.runAsync(() async {
      c = DurableLifeController(f.store);
      await c.initialize();
    });
    final files = FinancialFileStore(
      f.store,
      Directory('${f.directory.path}/career'),
      () async => 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
    );
    return (f, c, TestDocuments(c, files));
  }

  Future<void> close(
    WidgetTester tester,
    LocalFixture f,
    DurableLifeController c,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await closeWithWidgetClock(tester, c.close);
    c.dispose();
    await closeWithWidgetClock(tester, f.close);
  }

  Future<String> addApplication(
    WidgetTester tester,
    DurableLifeController c,
  ) async {
    await tester.runAsync(
      () => c.saveApplication({
        'company': 'Acme',
        'position': 'Designer',
        'stage': 'Applied',
        'stageDate': today,
        'date': today,
      }),
    );
    return c.records.values.whereType<ApplicationRecord>().single.id;
  }

  LifeSource sourceFor(DurableLifeController c, LifeDocuments documents) {
    final writer = LocalLifeWriter(c);
    return LifeSource(
      today: today,
      timezone: 'Asia/Manila',
      complete: true,
      hidden: false,
      amount: (v) => '$v',
      records: c.records,
      snapshot: demoSample(today, empty: true),
      writer: writer,
      visible: (_) => true,
      documents: documents,
      actions: LifeActions(
        addEvent: () {},
        addTask: () {},
        editEvent: (_) {},
        openEvent: (_) {},
        editTask: (_) {},
        openTask: (_) {},
        addEntry: (_) {},
        openEntry: (_) {},
        editEntry: (_) {},
        logProgress: (_) {},
        addApplication: () {},
        openApplication: (_) {},
        editApplication: (_) {},
        changeStage: (_) {},
        recordOutcome: (_) {},
        reopenApplication: (_) {},
        addStep: (_) {},
        openStep: (_) {},
        editStep: (_, _) {},
        openItem: (_) {},
        openRow: (_) {},
        openList: (_, _) {},
        reminders: () {},
        reminderFor: (_) => const SizedBox.shrink(),
      ),
    );
  }

  Widget card(
    DurableLifeController c,
    LifeDocuments documents,
    String id, {
    TargetPlatform platform = windows,
  }) => MaterialApp(
    themeAnimationDuration: Duration.zero,
    theme: SalapiyaTheme.build(Brightness.light, platform: platform),
    home: FinancialEnvironment(
      production: true,
      child: Scaffold(
        body: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) => LifeDocumentsCard(
              source: sourceFor(c, documents),
              documents: documents,
              application: id,
              archived: false,
            ),
          ),
        ),
      ),
    ),
  );

  void sized(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> reach(WidgetTester tester, String text) =>
      localWait(tester, () => find.textContaining(text).evaluate().isNotEmpty);

  Future<void> attach(WidgetTester tester, TestDocuments d) async {
    d.chosen = ('resume.png', bytes);
    await localTap(tester, find.byKey(const ValueKey('life-document-attach')));
    await reach(tester, 'Attach this file?');
    await localTap(tester, find.text('Attach file'));
    await reach(tester, 'Attached.');
  }

  /// Waits for what a card reads from storage after its first frame.
  Future<void> settleCard(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
    }
    await tester.pump();
  }

  testWidgets('attaching asks first, then links, with the same fields', (
    tester,
  ) async {
    sized(tester);
    final (f, c, d) = await open(tester);
    final id = await addApplication(tester, c);
    await tester.pumpWidget(card(c, d, id));
    await settleCard(tester);
    await attach(tester, d);
    final r = c.records.values.whereType<CareerDocumentRecord>().single;
    expect(r.title, 'resume.png');
    expect(r.applicationId, id);
    expect(r.fields['mime'], 'image/png');
    expect(r.fields['size'], '${bytes.length}');
    expect(r.fields['sourceVersion'], '1');
    final kept = await tester.runAsync(
      () => d.files.readMetadata(r.id, r.fileMetadata),
    );
    expect(kept, bytes);
    final drafts = await tester.runAsync(() => f.store.drafts());
    expect(drafts, isEmpty);
    final saved = await tester.runAsync(() => LocalLifeWriter(c).history(r.id));
    expect(
      saved!.single.$2.reason,
      'Attached private Career document metadata',
    );
    await close(tester, f, c);
  });

  testWidgets('saying no keeps nothing', (tester) async {
    sized(tester);
    final (f, c, d) = await open(tester);
    final id = await addApplication(tester, c);
    await tester.pumpWidget(card(c, d, id));
    await settleCard(tester);
    d.chosen = ('resume.png', bytes);
    await localTap(tester, find.byKey(const ValueKey('life-document-attach')));
    await reach(tester, 'Attach this file?');
    expect(find.textContaining('Not virus-scanned'), findsWidgets);
    await localTap(tester, find.text('Cancel'));
    await settleCard(tester);
    expect(c.records.values.whereType<CareerDocumentRecord>(), isEmpty);
    final drafts = await tester.runAsync(() => f.store.drafts());
    expect(drafts, isEmpty);
    await close(tester, f, c);
  });

  testWidgets('a wrong kind of file says so in plain words', (tester) async {
    sized(tester);
    final (f, c, d) = await open(tester);
    final id = await addApplication(tester, c);
    await tester.pumpWidget(card(c, d, id));
    await settleCard(tester);
    d.chosen = ('notes.txt', Uint8List.fromList([1, 2, 3]));
    await localTap(tester, find.byKey(const ValueKey('life-document-attach')));
    await localSettle(tester);
    expect(find.byType(InlineNotice), findsWidgets);
    expect(c.records.values.whereType<CareerDocumentRecord>(), isEmpty);
    await close(tester, f, c);
  });

  group('a half-attached file', () {
    /// Leaves a file written and a draft saved, as if the app stopped there.
    Future<LifeCommand> interrupted(
      WidgetTester tester,
      DurableLifeController c,
      TestDocuments d,
      String id,
    ) async {
      final command = LifeCommand(
        owner: c.store.owner,
        recordId: newLocalId(),
        type: LifeType.document,
        expectedVersion: 0,
        fields: {
          'title': 'resume.png',
          'application': id,
          'sourceVersion': '${c.records[id]!.version}',
          'mime': 'image/png',
          'size': '${bytes.length}',
          'checksum': sha256.convert(bytes).toString(),
        },
        reason: 'Attached private Career document metadata',
      );
      final record = LifeRecord.read(
        command.recordId,
        command.owner,
        1,
        LifeType.document,
        command.fields,
      ) as CareerDocumentRecord;
      await tester.runAsync(() async {
        await c.store.saveDraft(
          'life-document:${command.recordId}',
          command.id,
          {'payload': command.payload},
        );
        await d.files.write(record.id, record.fileMetadata, bytes);
      });
      return command;
    }

    testWidgets('it finishes with the same command', (tester) async {
      sized(tester);
      final (f, c, d) = await open(tester);
      final id = await addApplication(tester, c);
      final command = await interrupted(tester, c, d, id);
      await tester.pumpWidget(card(c, d, id));
      await settleCard(tester);
      expect(find.text('Not attached yet'), findsOneWidget);
      await localTap(
        tester,
        find.byKey(ValueKey('life-document-finish-${command.recordId}')),
      );
      await reach(tester, 'Attached.');
      expect(c.records.containsKey(command.recordId), isTrue);
      final drafts = await tester.runAsync(() => f.store.drafts());
      expect(drafts, isEmpty);
      await close(tester, f, c);
    });

    testWidgets('it finishes even after the application changed', (
      tester,
    ) async {
      sized(tester);
      final (f, c, d) = await open(tester);
      final id = await addApplication(tester, c);
      final command = await interrupted(tester, c, d, id);
      await tester.runAsync(() => c.change(id, 1, {'notes': 'New'}, 'Edited'));
      await tester.pumpWidget(card(c, d, id));
      await settleCard(tester);
      await localTap(
        tester,
        find.byKey(ValueKey('life-document-finish-${command.recordId}')),
      );
      await reach(tester, 'Attached.');
      final r = c.records.values.whereType<CareerDocumentRecord>().single;
      expect(r.fields['sourceVersion'], '2');
      expect(r.id, isNot(command.recordId));
      final kept = await tester.runAsync(
        () => d.files.readMetadata(r.id, r.fileMetadata),
      );
      expect(kept, bytes);
      final old = await tester.runAsync(() => d.present(command.recordId));
      expect(old, isFalse);
      final drafts = await tester.runAsync(() => f.store.drafts());
      expect(drafts, isEmpty);
      await close(tester, f, c);
    });

    testWidgets('letting go takes its encrypted copy too', (tester) async {
      sized(tester);
      final (f, c, d) = await open(tester);
      final id = await addApplication(tester, c);
      final command = await interrupted(tester, c, d, id);
      await tester.pumpWidget(card(c, d, id));
      await settleCard(tester);
      await localTap(
        tester,
        find.byKey(ValueKey('life-document-letgo-${command.recordId}')),
      );
      await reach(tester, 'Let go of this file?');
      await localTap(tester, find.text('Let go').last);
      await reach(tester, 'Nothing was attached.');
      final still = await tester.runAsync(() => d.present(command.recordId));
      expect(still, isFalse);
      final drafts = await tester.runAsync(() => f.store.drafts());
      expect(drafts, isEmpty);
      await close(tester, f, c);
    });

    testWidgets('Saved drafts names it, and a tap never fails', (tester) async {
      sized(tester);
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final (f, c, d) = await open(tester);
      final id = await addApplication(tester, c);
      await interrupted(tester, c, d, id);
      late LocalFinancialController money;
      await tester.runAsync(() async {
        money = LocalFinancialController(f.store, await f.store.snapshot());
        await money.reload();
      });
      await tester.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: SalapiyaTheme.build(Brightness.light, platform: windows),
          home: FinancialEnvironment(
            production: true,
            child: SavedDraftsPage(controller: money, session: session),
          ),
        ),
      );
      await localSettle(tester);
      expect(find.text('Attach a document'), findsOneWidget);
      expect(find.text('resume.png'), findsOneWidget);
      // The demo session doesn't have this application, so it says so.
      await tester.tap(find.text('Attach a document'));
      await localSettle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('This draft can’t open here'), findsOneWidget);
      await close(tester, f, c);
    });

    testWidgets('its draft has a real title in Saved drafts', (tester) async {
      expect(
        documentDraftName({
          'payload':
              '{"fields":{"title":"resume.png","application":"x"},"owner":"y"}',
        }),
        'resume.png',
      );
      expect(documentDraftName(const {'payload': 'not json'}), isNull);
      expect(documentDraftName(const {}), isNull);
    });
  });

  group('a linked file', () {
    Future<CareerDocumentRecord> linked(
      WidgetTester tester,
      DurableLifeController c,
      TestDocuments d,
      String id,
    ) async {
      await tester.pumpWidget(card(c, d, id));
      await settleCard(tester);
      await attach(tester, d);
      await reach(tester, 'On this device');
      return c.records.values.whereType<CareerDocumentRecord>().single;
    }

    Future<void> menu(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(ValueKey('life-document-menu-$id')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('it offers what works on a file that’s here', (tester) async {
      sized(tester);
      final (f, c, d) = await open(tester);
      final id = await addApplication(tester, c);
      final r = await linked(tester, c, d, id);
      expect(find.textContaining('On this device'), findsOneWidget);
      await menu(tester, r.id);
      for (final key in const [
        'preview',
        'open',
        'save',
        'remove',
        'archive',
      ]) {
        expect(
          find.byKey(ValueKey('life-document-$key-${r.id}')),
          findsOneWidget,
          reason: key,
        );
      }
      expect(
        find.byKey(ValueKey('life-document-restore-${r.id}')),
        findsNothing,
      );
      await close(tester, f, c);
    });

    testWidgets('removing the copy keeps the record, and it can come back', (
      tester,
    ) async {
      sized(tester);
      final (f, c, d) = await open(tester);
      final id = await addApplication(tester, c);
      final r = await linked(tester, c, d, id);
      await menu(tester, r.id);
      await localTap(
        tester,
        find.byKey(ValueKey('life-document-remove-${r.id}')),
      );
      await reach(tester, 'Remove this file from your device?');
      expect(find.textContaining('keep your original first'), findsOneWidget);
      await localTap(tester, find.text('Remove from this device').last);
      await reach(tester, 'Removed from this device.');
      await settleCard(tester);
      expect(c.records.containsKey(r.id), isTrue);
      expect(find.textContaining('Not on this device'), findsOneWidget);
      await menu(tester, r.id);
      expect(find.byKey(ValueKey('life-document-open-${r.id}')), findsNothing);
      expect(find.byKey(ValueKey('life-document-save-${r.id}')), findsNothing);
      d.chosen = ('resume.png', bytes);
      await localTap(
        tester,
        find.byKey(ValueKey('life-document-restore-${r.id}')),
      );
      await reach(tester, 'Restored from your original.');
      final back = await tester.runAsync(() => d.present(r.id));
      expect(back, isTrue);
      await close(tester, f, c);
    });

    testWidgets('a different file can’t restore it', (tester) async {
      sized(tester);
      final (f, c, d) = await open(tester);
      final id = await addApplication(tester, c);
      final r = await linked(tester, c, d, id);
      await tester.runAsync(() => d.remove(r.id));
      d.chosen = ('other.png', Uint8List.fromList([...bytes, 0]));
      final refused = await tester.runAsync(() async {
        try {
          await d.restore(r);
          return null;
        } on LocalRuleException catch (e) {
          return e.message;
        }
      });
      expect(refused, 'This isn’t the same file. Choose the original.');
      await close(tester, f, c);
    });

    testWidgets('archiving says what stays, and the link comes back', (
      tester,
    ) async {
      sized(tester);
      final (f, c, d) = await open(tester);
      final id = await addApplication(tester, c);
      final r = await linked(tester, c, d, id);
      await menu(tester, r.id);
      await localTap(
        tester,
        find.byKey(ValueKey('life-document-archive-${r.id}')),
      );
      await reach(tester, 'Archive this link?');
      expect(find.textContaining('you can restore the link'), findsOneWidget);
      await localTap(tester, find.text('Archive link').last);
      await reach(tester, 'Show archived');
      expect(c.records[r.id]!.archived, isTrue);
      await localTap(
        tester,
        find.byKey(const ValueKey('life-document-archived')),
      );
      await menu(tester, r.id);
      await localTap(
        tester,
        find.byKey(ValueKey('life-document-unarchive-${r.id}')),
      );
      await localWait(tester, () => c.records[r.id]!.archived == false);
      final kept = await tester.runAsync(() => d.present(r.id));
      expect(kept, isTrue);
      await close(tester, f, c);
    });

    testWidgets('its file stays out of the backup', (tester) async {
      sized(tester);
      final (f, c, d) = await open(tester);
      final id = await addApplication(tester, c);
      await linked(tester, c, d, id);
      final archive = await tester.runAsync(
        () => f.store.db.readTransaction(f.store.captureLifeArchive),
      );
      expect(archive!['attachmentByteObjects'], 0);
      await close(tester, f, c);
    });
  });

  group('the rules', () {
    testWidgets('a refused edit to a document can only be kept', (
      tester,
    ) async {
      final (f, c, d) = await open(tester);
      final id = await addApplication(tester, c);
      await tester.pumpWidget(card(c, d, id));
      await settleCard(tester);
      await attach(tester, d);
      final r = c.records.values.whereType<CareerDocumentRecord>().single;
      final edit = LifeCommand(
        owner: c.store.owner,
        recordId: newLocalId(),
        type: LifeType.document,
        expectedVersion: 0,
        fields: {...r.fields, 'sourceVersion': '99'},
        reason: 'x',
        recordedAt: DateTime.utc(2026),
      );
      final row = lifeReviewRows([
        {
          'id': edit.id,
          'payload': edit.payload,
          'state': 'review',
          'reason': 'x',
          'resolved_at': null,
        },
      ], c.records).single;
      expect(row.usable, isFalse);
      await close(tester, f, c);
    });

    test('a file’s name that can’t be stored says so', () {
      expect(
        () =>
            LifeRecord.read(newLocalId(), newLocalId(), 1, LifeType.document, {
              'title': 'a/b.png',
              'application': newLocalId(),
              'sourceVersion': '1',
              'mime': 'image/png',
              'size': '1',
              'checksum': 'a' * 64,
              'status': 'Linked',
            }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'This file’s name can’t be used. Rename it and try again.',
          ),
        ),
      );
    });
  });

  group('the demo', () {
    Widget page(PrototypeSession s, TargetPlatform platform, double width) =>
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: SalapiyaTheme.build(Brightness.light, platform: platform),
          home: LifeApplicationPage(
            listenable: s,
            source: (context) => lifeSource(context, s),
            id: demoLife(today).records.values
                .firstWhere(
                  (r) => r is ApplicationRecord && r.company == 'Amihan Studio',
                )
                .id,
          ),
        );

    testWidgets('it shows each state and says what it can’t do', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await tester.pumpWidget(page(s, windows, 1200));
      await tester.pumpAndSettle();
      expect(find.text('Resume v4.pdf'), findsOneWidget);
      expect(find.textContaining('Not on this device'), findsOneWidget);
      expect(find.text('Old resume.pdf'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('life-document-archived')));
      await tester.pump();
      expect(find.text('Old resume.pdf'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('life-document-attach')));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('the demo can’t open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no shared list or row names a file', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: SalapiyaTheme.build(Brightness.light, platform: windows),
          home: LifeApplicationsListPage(
            listenable: s,
            source: (context) => lifeSource(context, s),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Resume'), findsNothing);
    });
  });

  testWidgets('discarding a draft takes its encrypted file on a real profile', (
    tester,
  ) async {
    final f = (await tester.runAsync(LocalFixture.open))!;
    final settings = GallerySettings();
    final runtime = LocalRuntime(
      LocalProfiles(f.directory, MemoryProfileVault()),
      settings,
    );
    await tester.runAsync(() => runtime.activate(f.store));
    final session = runtime.session!;
    final id = newLocalId();
    final file = LocalLifeDocuments.of(session).files.object(id);
    await tester.runAsync(() async {
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3]);
      expect(await file.exists(), isTrue);
      await forgetDocumentDraft(session, 'life-document:$id');
      expect(await file.exists(), isFalse);
    });
    await closeWithWidgetClock(tester, runtime.close);
    runtime.dispose();
    settings.dispose();
    await closeWithWidgetClock(tester, f.close);
  });

  test('stored reasons read plainly, and stay as they are', () {
    expect(
      lifeReasonText('Attached private Career document metadata'),
      'Document attached',
    );
    expect(lifeReasonText('Completed event'), 'Marked as done');
    expect(lifeReasonText('Moved it back'), 'Moved it back');
  });
}
