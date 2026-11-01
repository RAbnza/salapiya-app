import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_demo.dart' show demoSample;
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/finance/presentation/financial_widgets.dart';
import 'package:salapiya/features/life/application/life_controller.dart'
    show LifeKind;
import 'package:salapiya/finance/money_details.dart' show SavedDraftsPage;
import 'package:salapiya/life/life_controller.dart';
import 'package:salapiya/life/life_data.dart';
import 'package:salapiya/life/life_demo.dart';
import 'package:salapiya/life/life_domain.dart';
import 'package:salapiya/life/life_forms.dart';
import 'package:salapiya/life/life_hub.dart';
import 'package:salapiya/life/life_pages_detail.dart';
import 'package:salapiya/life/life_reviews.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/local/local_finance_controller.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/local/local_runtime.dart';
import 'package:salapiya/prototype/scenarios.dart';

import 'local_money_journey.dart' show localSettle, localTap, localWait;
import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

const windows = TargetPlatform.windows, android = TargetPlatform.android;

final demoEmpty = demoSample('2026-11-01', empty: true);

/// Saves a refused edit, and can lose the answer once.
class LostReview extends LocalLifeWriter {
  LostReview(super.c);
  bool lose = false;
  @override
  Future<void> useEdit(LifeCommand command, String original) async {
    await super.useEdit(command, original);
    if (lose) {
      lose = false;
      throw StateError('The answer was lost.');
    }
  }
}

/// Saves like the real writer, and can lose an answer once.
class FlakyWriter extends LocalLifeWriter {
  FlakyWriter(super.c);
  bool lose = false;
  int saves = 0;
  @override
  Future<void> saveEvent(Map<String, String> v, {String? old}) async {
    saves++;
    await super.saveEvent(v, old: old);
    if (lose) {
      lose = false;
      throw StateError('The answer was lost.');
    }
  }
}

void main() {
  Future<(LocalFixture, DurableLifeController)> open(
    WidgetTester tester,
  ) async {
    final f = (await tester.runAsync(LocalFixture.open))!;
    // On real time: its first reload would wait for the test's fake clock.
    late DurableLifeController c;
    await tester.runAsync(() async {
      c = DurableLifeController(f.store);
      await c.initialize();
    });
    return (f, c);
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

  Widget app(
    LifeWriter writer, {
    String? id,
    TargetPlatform platform = windows,
    Brightness brightness = Brightness.light,
  }) => MaterialApp(
    themeAnimationDuration: Duration.zero,
    theme: SalapiyaTheme.build(brightness, platform: platform),
    home: FinancialEnvironment(
      production: true,
      child: LifeEventForm(writer: writer, id: id),
    ),
  );

  void sized(WidgetTester tester, [double width = 900]) {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Finder submit() => find.byKey(const ValueKey('life-submit'));

  Future<void> enter(WidgetTester tester, String key, String value) async {
    final field = find.byKey(ValueKey('life-field-$key'));
    await tester.ensureVisible(field);
    await tester.pump();
    final widget = tester.widget(field);
    if (widget is DateField) {
      widget.onChanged!(DateTime.parse(value));
    } else if (widget is TimeField) {
      final p = value.split(':');
      widget.onChanged!(
        TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])),
      );
    } else if (widget is SearchPickerField) {
      widget.onChanged!(value);
    } else {
      await tester.enterText(
        find.descendant(of: field, matching: find.byType(EditableText)),
        value,
      );
    }
    await tester.pump();
  }

  Future<void> tapReal(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump();
    await localTap(tester, target);
  }

  /// Saving reaches the store on real time, so wait for what it leads to.
  Future<void> reach(WidgetTester tester, String text) => localWait(
    tester,
    () => find.text(text).evaluate().isNotEmpty,
  );

  Future<void> more(WidgetTester tester) async {
    await tester.tap(find.text('More details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('Add event', () {
    testWidgets('saves the same keys and defaults as before', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.pumpWidget(app(LocalLifeWriter(c)));
      await localSettle(tester);
      await enter(tester, 'title', 'Dentist');
      await enter(tester, 'date', '2026-12-01');
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      await tapReal(tester, submit());
      await reach(tester, 'Event saved');
      final r = c.records.values.single as PersonalRecord;
      expect(r.title, 'Dentist');
      expect(r.date, '2026-12-01');
      expect(r.time, '09:00');
      expect(r.timezone, 'Asia/Manila');
      expect(r.status, 'Scheduled');
      expect(r.archived, isFalse);
      expect(r.fields['fold'], '');
      expect(r.utc, isNotNull);
      await close(tester, f, c);
    });

    testWidgets('All day stores no time', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.pumpWidget(app(LocalLifeWriter(c)));
      await localSettle(tester);
      await enter(tester, 'title', 'Birthday');
      await tester.tap(find.byKey(const ValueKey('life-field-allDay')));
      await tester.pump();
      expect(find.byKey(const ValueKey('life-field-time')), findsNothing);
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      await tapReal(tester, submit());
      await reach(tester, 'Event saved');
      final r = c.records.values.single as PersonalRecord;
      expect(r.allDay, isTrue);
      expect(r.utc, isNull);
      await close(tester, f, c);
    });

    testWidgets('a time that doesn’t exist errors on Time, before Review', (
      tester,
    ) async {
      sized(tester);
      final writer = DemoLifeWriter(demoLife('2026-03-01'), '2026-03-01');
      await tester.pumpWidget(app(writer));
      await tester.pump();
      await tester.pump();
      await enter(tester, 'title', 'Early start');
      await more(tester);
      await enter(tester, 'timezone', 'America/New_York');
      await enter(tester, 'date', '2026-03-08');
      await enter(tester, 'time', '02:30');
      expect(
        find.textContaining('doesn’t happen on this date'),
        findsOneWidget,
      );
      await tester.tap(submit());
      await tester.pump();
      await tester.pump();
      expect(find.text('Step 2 of 2 · Review'), findsNothing);
      expect(
        find.textContaining('doesn’t happen on this date'),
        findsOneWidget,
      );
    });

    testWidgets('a time that happens twice asks which, and only then', (
      tester,
    ) async {
      sized(tester);
      final writer = DemoLifeWriter(demoLife('2026-10-01'), '2026-10-01');
      await tester.pumpWidget(app(writer));
      await tester.pump();
      await tester.pump();
      await enter(tester, 'title', 'Night shift');
      final which = find.byKey(const ValueKey('life-field-select-fold'));
      expect(which, findsNothing);
      await more(tester);
      await enter(tester, 'timezone', 'America/New_York');
      await enter(tester, 'date', '2026-11-01');
      await enter(tester, 'time', '01:30');
      expect(which, findsOneWidget);
      expect(find.text('The earlier one'), findsOneWidget);
      // The rules insist on a choice, so nothing is chosen for the user.
      await tester.ensureVisible(submit());
      await tester.pump();
      await tester.tap(submit());
      await tester.pump();
      await tester.pump();
      expect(find.text('Step 2 of 2 · Review'), findsNothing);
      expect(find.textContaining('happens twice on this date'), findsWidgets);
      await tester.ensureVisible(find.text('The later one'));
      await tester.pump();
      await tester.tap(find.text('The later one'));
      await tester.pump();
      await tester.ensureVisible(submit());
      await tester.pump();
      await tester.tap(submit());
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('the later one'), findsOneWidget);
      await enterBack(tester);
      await enter(tester, 'time', '03:30');
      expect(which, findsNothing);
    });

    testWidgets('errors land on their field', (tester) async {
      sized(tester);
      final writer = DemoLifeWriter(demoLife('2026-11-01'), '2026-11-01');
      await tester.pumpWidget(app(writer));
      await tester.pump();
      await tester.pump();
      await tester.ensureVisible(submit());
      await tester.pump();
      await tester.tap(submit());
      await tester.pump();
      await tester.pump();
      expect(find.text('Step 2 of 2 · Review'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('life-field-title')),
          matching: find.textContaining('Enter a title'),
        ),
        findsOneWidget,
      );
      expect(find.byType(InlineNotice), findsNothing);
    });

    testWidgets('the demo checks with the rules and keeps nothing', (
      tester,
    ) async {
      sized(tester);
      final life = demoLife('2026-11-01');
      final before = life.records.length;
      await tester.pumpWidget(app(DemoLifeWriter(life, '2026-11-01')));
      await tester.pump();
      await tester.pump();
      await enter(tester, 'title', 'Not kept');
      await tester.ensureVisible(submit());
      await tester.pump();
      await tester.tap(submit());
      await tester.pump();
      await tester.pump();
      await tester.ensureVisible(submit());
      await tester.pump();
      await tester.tap(submit());
      await tester.pump();
      await tester.pump();
      expect(find.text('This is the demo, so nothing was saved.'), findsOneWidget);
      expect(life.records.length, before);
    });
  });

  group('Edit event', () {
    testWidgets('keeps every field and asks why', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.runAsync(
        () async => c.saveEvent({
          'title': 'Dentist',
          'date': '2026-12-01',
          'time': '09:00',
          'timezone': 'Asia/Tokyo',
          'location': 'Clinic',
          'notes': 'Card',
        }),
      );
      final id = c.records.keys.single;
      await tester.pumpWidget(app(LocalLifeWriter(c), id: id));
      await localSettle(tester);
      await enter(tester, 'title', 'Dentist visit');
      await tapReal(tester, submit());
      await localWait(
        tester,
        () => find.textContaining('Say why').evaluate().isNotEmpty,
      );
      expect(find.text('Step 2 of 2 · Review'), findsNothing);
      await enter(tester, 'reason', 'A better name');
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      await tapReal(tester, submit());
      await reach(tester, 'Event saved');
      final r = c.records[id]! as PersonalRecord;
      expect(r.title, 'Dentist visit');
      expect(r.version, 2);
      expect(r.timezone, 'Asia/Tokyo');
      expect(r.fields['location'], 'Clinic');
      expect(r.notes, 'Card');
      await close(tester, f, c);
    });

    testWidgets('a record that changed stops the form, and keeps the draft', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.runAsync(
        () async => c.saveEvent({
          'title': 'Dentist',
          'date': '2026-12-01',
          'time': '09:00',
          'timezone': 'Asia/Manila',
        }),
      );
      final id = c.records.keys.single;
      await tester.pumpWidget(app(LocalLifeWriter(c), id: id));
      await localSettle(tester);
      await enter(tester, 'reason', 'Mine');
      await closeWithWidgetClock(
        tester,
        () => c.change(id, 1, {'notes': 'Elsewhere'}, 'Another window'),
      );
      await tapReal(tester, submit());
      await reach(tester, 'This changed');
      expect(find.text('Step 2 of 2 · Review'), findsNothing);
      expect(c.records[id]!.version, 2);
      await close(tester, f, c);
    });
  });

  group('the event page, on a real store', () {
    testWidgets('Cancel event saves, and the event leaves the Calendar', (
      tester,
    ) async {
      sized(tester, 1200);
      final (f, c) = await open(tester);
      await tester.runAsync(
        () async => c.saveEvent({
          'title': 'Dentist',
          'date': '2030-01-01',
          'time': '09:00',
          'timezone': 'Asia/Manila',
        }),
      );
      final id = c.records.keys.single;
      LifeSource source(BuildContext context) => LifeSource(
        today: '2026-11-01',
        timezone: 'Asia/Manila',
        complete: true,
        hidden: false,
        amount: (v) => '$v',
        records: c.records,
        snapshot: demoEmpty,
        writer: LocalLifeWriter(c),
        visible: (_) => true,
        actions: LifeActions(
          addEvent: () {},
          addTask: () {},
          editEvent: (_) {},
          openEvent: (_) {},
          editTask: (_) {},
          openTask: (_) {},
          openItem: (_) {},
          openRow: (_) {},
          openList: (_, _) {},
          reminders: () {},
          reminderFor: (_) => const SizedBox.shrink(),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: SalapiyaTheme.build(Brightness.light, platform: windows),
          home: LifeEventPage(listenable: c, source: source, id: id),
        ),
      );
      await localSettle(tester);
      await localTap(tester, find.byKey(const ValueKey('life-event-more')));
      await localTap(tester, find.byKey(const ValueKey('life-event-cancel')));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('life-cancel-why')),
          matching: find.byType(EditableText),
        ),
        'The clinic closed',
      );
      await tester.pump();
      await localTap(tester, find.text('Cancel event').last);
      await localWait(tester, () => c.records[id]!.status == 'Cancelled');
      expect(c.records[id]!.version, 2);
      expect(lifeAgendaItems(c.records, '2029-01-01', '2031-01-01'), isEmpty);
      await close(tester, f, c);
    });
  });

  group('Add task', () {
    Widget taskApp(LifeWriter writer, {String? id}) => MaterialApp(
      themeAnimationDuration: Duration.zero,
      theme: SalapiyaTheme.build(Brightness.light, platform: windows),
      home: FinancialEnvironment(
        production: true,
        child: LifeTaskForm(writer: writer, id: id),
      ),
    );

    testWidgets('saves the same keys and defaults as before', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.pumpWidget(taskApp(LocalLifeWriter(c)));
      await localSettle(tester);
      await enter(tester, 'title', 'Renew license');
      await enter(tester, 'due', '2026-12-01');
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      await tapReal(tester, submit());
      await reach(tester, 'Task saved');
      final r = c.records.values.single as TaskRecord;
      expect(r.title, 'Renew license');
      expect(r.due, '2026-12-01');
      expect(r.priority, 'Normal');
      expect(r.status, 'Not started');
      expect(r.completionDate, '');
      expect(r.archived, isFalse);
      await close(tester, f, c);
    });

    testWidgets('a due date is optional, and the title isn’t', (tester) async {
      sized(tester);
      final writer = DemoLifeWriter(demoLife('2026-11-01'), '2026-11-01');
      await tester.pumpWidget(taskApp(writer));
      await tester.pump();
      await tester.pump();
      await tester.ensureVisible(submit());
      await tester.pump();
      await tester.tap(submit());
      await tester.pump();
      await tester.pump();
      expect(find.text('Step 2 of 2 · Review'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('life-field-title')),
          matching: find.textContaining('Enter a title'),
        ),
        findsOneWidget,
      );
      await enter(tester, 'title', 'No date');
      await tester.ensureVisible(submit());
      await tester.pump();
      await tester.tap(submit());
      await tester.pump();
      await tester.pump();
      expect(find.text('Step 2 of 2 · Review'), findsOneWidget);
    });

    testWidgets('Date finished shows only for a completed task', (
      tester,
    ) async {
      sized(tester);
      final writer = DemoLifeWriter(demoLife('2026-11-01'), '2026-11-01');
      await tester.pumpWidget(taskApp(writer));
      await tester.pump();
      await tester.pump();
      await more(tester);
      final finished = find.byKey(const ValueKey('life-field-completed'));
      expect(finished, findsNothing);
      final status = tester.widget<OptionPicker<String>>(
        find.byKey(const ValueKey('life-field-select-status')),
      );
      status.onChanged!('Completed');
      await tester.pump();
      expect(finished, findsOneWidget);
    });

    testWidgets('an edit keeps every field and asks why', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.runAsync(
        () async => c.saveEntry(LifeKind.task, {
          'title': 'Renew',
          'detail': 'At the office',
          'due': '2026-12-01',
          'priority': 'High',
          'status': 'In progress',
          'notes': 'Bring ID',
        }),
      );
      final id = c.records.keys.single;
      await tester.pumpWidget(taskApp(LocalLifeWriter(c), id: id));
      await localSettle(tester);
      await enter(tester, 'reason', 'Same fields');
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      await tapReal(tester, submit());
      await reach(tester, 'Task saved');
      final r = c.records[id]! as TaskRecord;
      expect(r.version, 2);
      expect(r.fields['detail'], 'At the office');
      expect(r.priority, 'High');
      expect(r.status, 'In progress');
      expect(r.notes, 'Bring ID');
      await close(tester, f, c);
    });
  });

  group('a task, one tap', () {
    testWidgets('completing and reopening send what they always did', (
      tester,
    ) async {
      final (f, c) = await open(tester);
      await tester.runAsync(() async {
        await c.saveEntry(LifeKind.task, {
          'title': 'Renew',
          'status': 'Not started',
        });
        final id = c.records.keys.single;
        final writer = LocalLifeWriter(c);
        await writer.change(id, 1, {'status': 'Completed'}, 'Completed');
        expect(c.records[id]!.status, 'Completed');
        await writer.change(id, 2, {'status': 'In progress'}, 'Reopened');
        expect(c.records[id]!.status, 'In progress');
        final reasons = (await writer.history(id)).map((h) => h.$2.reason);
        expect(reasons, ['Created', 'Completed', 'Reopened']);
      });
      await close(tester, f, c);
    });
  });

  group('drafts', () {
    Future<void> showDrafts(
      WidgetTester tester,
      LocalFixture f,
      PrototypeSession session,
    ) async {
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
    }

    testWidgets('a Life draft has a real title, and opens its form', (
      tester,
    ) async {
      sized(tester);
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final f = (await tester.runAsync(LocalFixture.open))!;
      await tester.runAsync(
        () => f.store.saveDraft('life:new-task', newLocalId(), {
          'title': 'Half typed',
          'priority': 'Normal',
        }),
      );
      await showDrafts(tester, f, session);
      expect(find.text('Add task'), findsOneWidget);
      expect(find.text('Half typed'), findsOneWidget);
      await tester.tap(find.text('Add task'));
      await localSettle(tester);
      expect(find.byType(LifeTaskForm), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await closeWithWidgetClock(tester, f.close);
    });

    testWidgets('a draft whose record went says so and can be discarded', (
      tester,
    ) async {
      sized(tester);
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final f = (await tester.runAsync(LocalFixture.open))!;
      final id = newLocalId();
      await tester.runAsync(
        () => f.store.saveDraft('life:$id', newLocalId(), {
          'title': 'Gone',
          'priority': 'High',
        }),
      );
      await showDrafts(tester, f, session);
      expect(find.text('Edit task'), findsOneWidget);
      await tester.tap(find.text('Edit task'));
      await localSettle(tester);
      expect(find.text('This draft can’t open here'), findsOneWidget);
      await localTap(tester, find.text('Discard draft').last);
      await localWait(
        tester,
        () => find.text('No saved drafts').evaluate().isNotEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await closeWithWidgetClock(tester, f.close);
    });

    testWidgets('a draft from another form never fails', (tester) async {
      sized(tester);
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final f = (await tester.runAsync(LocalFixture.open))!;
      await tester.runAsync(
        () => f.store.saveDraft('life:Log progress · x', newLocalId(), {
          'title': 'Old',
        }),
      );
      await showDrafts(tester, f, session);
      await tester.tap(find.text('Finish this draft'));
      await localSettle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('This draft can’t open here'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await closeWithWidgetClock(tester, f.close);
    });
  });

  testWidgets('Life’s waiting and refused edits reach the bell’s counts', (
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
    final connected = runtime.connected;
    expect(session.needsReview, isFalse);
    connected.lifePendingCount = 2;
    connected.pendingCount = 1;
    expect(session.pendingCount, 3);
    // Money's own figures still ask only about money.
    connected.pendingCount = 0;
    expect(session.pending, isFalse);
    connected.lifeReviewCount = 1;
    expect(session.needsReview, isTrue);
    expect(session.lifeOnlyReview, isTrue);
    connected.reviewCount = 1;
    expect(session.lifeOnlyReview, isFalse);
    connected
      ..lifePendingCount = 0
      ..lifeReviewCount = 0
      ..reviewCount = 0;
    await closeWithWidgetClock(tester, runtime.close);
    runtime.dispose();
    settings.dispose();
    await closeWithWidgetClock(tester, f.close);
  });

  group('Changes to check, on a real store', () {
    /// A connected store's refused edit, as the receipt leaves it.
    Future<(LifeCommand, String)> refused(
      WidgetTester tester,
      LocalFixture f,
      DurableLifeController c,
    ) async {
      late LifeCommand edit;
      late String id;
      await tester.runAsync(() async {
        await c.saveEntry(LifeKind.task, {
          'title': 'Renew',
          'status': 'Not started',
        });
        id = c.records.keys.single;
        edit = LifeCommand(
          owner: f.store.owner,
          recordId: id,
          type: LifeType.task,
          expectedVersion: 0,
          fields: {...c.fields(id), 'title': 'Renew my license'},
          reason: 'A clearer name',
        );
        await f.store.db.execute(
          "INSERT INTO life_intent VALUES(?,?,?,'review',?,1)",
          [
            edit.id,
            f.store.owner,
            edit.payload,
            'Life source version changed; review current record',
          ],
        );
        await c.reload();
      });
      return (edit, id);
    }

    Widget page(DurableLifeController c, LifeWriter writer) => MaterialApp(
      themeAnimationDuration: Duration.zero,
      theme: SalapiyaTheme.build(Brightness.light, platform: windows),
      home: LifeChecksPage(
        listenable: c,
        source: (context) => LifeSource(
          today: '2026-11-01',
          timezone: 'Asia/Manila',
          complete: true,
          hidden: false,
          amount: (v) => '$v',
          records: c.records,
          snapshot: demoEmpty,
          writer: writer,
          visible: (_) => true,
          reviews: lifeReviewRows(c.intents, c.records),
          actions: LifeActions(
            addEvent: () {},
            addTask: () {},
            editEvent: (_) {},
            openEvent: (_) {},
            editTask: (_) {},
            openTask: (_) {},
            openItem: (_) {},
            openRow: (_) {},
            openList: (_, _) {},
            reminders: () {},
            reminderFor: (_) => const SizedBox.shrink(),
          ),
        ),
      ),
    );

    testWidgets('it says what differs, plainly, and keeping closes it', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      final (edit, id) = await refused(tester, f, c);
      await tester.pumpWidget(page(c, LocalLifeWriter(c)));
      await localSettle(tester);
      expect(find.textContaining('This changed on another device'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Renew my license'), findsOneWidget);
      expect(find.textContaining('payload'), findsNothing);
      await localTap(tester, find.byKey(ValueKey('life-check-keep-${edit.id}')));
      expect(find.textContaining('It stays on record'), findsOneWidget);
      await localTap(tester, find.text('Keep what’s there').last);
      await localWait(tester, () => c.intents.single['resolved_at'] != null);
      expect(c.records[id]!.title, 'Renew');
      await close(tester, f, c);
    });

    testWidgets('Use my edit saves one new version, even after a lost answer', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      final (edit, id) = await refused(tester, f, c);
      final writer = LostReview(c);
      await tester.pumpWidget(page(c, writer));
      await localSettle(tester);
      await localTap(tester, find.byKey(ValueKey('life-check-use-${edit.id}')));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('life-check-why')),
          matching: find.byType(EditableText),
        ),
        'Mine is right',
      );
      await tester.pump();
      writer.lose = true;
      await localTap(tester, find.text('Use my edit').last);
      await reach(tester, lostSaveTitle);
      await localTap(tester, find.byKey(const ValueKey('life-check-retry')));
      await localWait(tester, () => c.intents.single['resolved_at'] != null);
      expect(c.records[id]!.title, 'Renew my license');
      expect(c.records[id]!.version, 2);
      await close(tester, f, c);
    });
  });

  group('a lost answer', () {
    testWidgets('freezes the form, and Check again adds nothing twice', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      final writer = FlakyWriter(c);
      await tester.pumpWidget(app(writer));
      await localSettle(tester);
      await enter(tester, 'title', 'Dentist');
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      writer.lose = true;
      await tapReal(tester, submit());
      await reach(tester, lostSaveTitle);
      expect(find.byKey(const ValueKey('life-edit')), findsNothing);
      expect(submit(), findsNothing);
      final revisions = c.records.values.single.version;
      await tapReal(tester, find.byKey(const ValueKey('life-check-again')));
      await reach(tester, 'Event saved');
      expect(writer.saves, 2);
      expect(c.records, hasLength(1));
      expect(c.records.values.single.version, revisions);
      await close(tester, f, c);
    });

    testWidgets('comes back frozen after the form is closed', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.runAsync(
        () => f.store.saveDraft('life:new-event', newLocalId(), {
          'title': 'Left behind',
          '__lost': 'true',
          '__command': newLocalId(),
          '__record': newLocalId(),
          '__version': '0',
          '__recordedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      await tester.pumpWidget(app(LocalLifeWriter(c)));
      await reach(tester, lostSaveTitle);
      expect(find.byKey(const ValueKey('life-check-again')), findsOneWidget);
      await close(tester, f, c);
    });
  });

  testWidgets('a connected profile’s form says it is waiting to sync', (
    tester,
  ) async {
    sized(tester);
    final (f, c) = await open(tester);
    final writer = LocalLifeWriter(c);
    c.intents = [
      {'id': 'one', 'state': 'pending'},
    ];
    expect(
      writer.savedLine('one'),
      'Saved on this device. It’s waiting to sync.',
    );
    expect(writer.savedLine('other'), 'Saved.');
    await close(tester, f, c);
  });

  testWidgets('every size, text size and theme, at both steps', (tester) async {
    addTearDown(tester.view.reset);
    final writer = DemoLifeWriter(demoLife('2026-11-01'), '2026-11-01');
    for (final (platform, width) in const [
      (android, 320.0),
      (android, 360.0),
      (android, 412.0),
      (windows, 720.0),
      (windows, 1200.0),
      (windows, 1440.0),
    ]) {
      for (final text in const [1.0, 2.0]) {
        for (final brightness in Brightness.values) {
          tester.view.physicalSize = Size(width, 2400);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              themeAnimationDuration: Duration.zero,
              theme: SalapiyaTheme.build(brightness, platform: platform),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 2400),
                  textScaler: TextScaler.linear(text),
                ),
                child: FinancialEnvironment(
                  production: true,
                  child: LifeEventForm(writer: writer),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          final label = '$platform $width $text $brightness';
          expect(tester.takeException(), isNull, reason: label);
          await enter(tester, 'title', 'Dentist');
          await more(tester);
          await tester.ensureVisible(submit());
          await tester.pump();
          await tester.tap(submit());
          await tester.pump();
          await tester.pump();
          expect(find.text('Step 2 of 2 · Review'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: label);
        }
      }
    }
  });

  test('every rule field names a message the rules still say', () {
    expect(lifeRuleField('Enter a title of at most 200 characters.'), 'title');
    expect(lifeRuleField('Choose a date between 1900 and 2200.'), 'date');
    expect(lifeRuleField('Choose a timezone from the list.'), 'timezone');
    expect(lifeRuleField('Enter a time, like 14:30.'), 'time');
    expect(lifeRuleField('Something else.'), isNull);
  });

  test('timezones read plainly, with Manila first', () {
    final options = timezoneOptions();
    expect(options.first.$1, 'Asia/Manila');
    expect(options.first.$2, 'Manila · Asia/Manila');
    expect(options.map((o) => o.$1), contains('America/New_York'));
    expect(options.map((o) => o.$1).toSet(), hasLength(options.length));
  });
}

Future<void> enterBack(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('life-edit')));
  await tester.pump();
  await tester.pump();
}
