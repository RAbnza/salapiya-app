import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/finance/presentation/financial_widgets.dart';
import 'package:salapiya/features/life/application/life_controller.dart'
    show LifeKind;
import 'package:salapiya/finance/money_details.dart' show SavedDraftsPage;
import 'package:salapiya/life/life_controller.dart';
import 'package:salapiya/life/life_data.dart';
import 'package:salapiya/life/life_domain.dart';
import 'package:salapiya/life/life_forms.dart';
import 'package:salapiya/life/life_hub.dart';
import 'package:salapiya/life/progress_forms.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_finance_controller.dart';
import 'package:salapiya/prototype/scenarios.dart';

import 'local_money_journey.dart' show localSettle, localTap, localWait;
import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

const windows = TargetPlatform.windows, android = TargetPlatform.android;

/// Saves like the real writer, and can lose an answer once.
class FlakyWriter extends LocalLifeWriter {
  FlakyWriter(super.c);
  bool lose = false;
  final ids = <String>[];
  void _lost(Map<String, String> v) {
    ids.add(v['__command']!);
    if (lose) {
      lose = false;
      throw StateError('The answer was lost.');
    }
  }

  @override
  Future<void> saveEntry(
    LifeType type,
    Map<String, String> v, {
    String? old,
  }) async {
    await super.saveEntry(type, v, old: old);
    _lost(v);
  }

  @override
  Future<void> saveProgress(Map<String, String> v, String id) async {
    await super.saveProgress(v, id);
    _lost(v);
  }
}

void main() {
  Future<(LocalFixture, DurableLifeController)> open(
    WidgetTester tester,
  ) async {
    final f = (await tester.runAsync(LocalFixture.open))!;
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

  Widget app(Widget child, {TargetPlatform platform = windows}) => MaterialApp(
    themeAnimationDuration: Duration.zero,
    theme: SalapiyaTheme.build(Brightness.light, platform: platform),
    home: FinancialEnvironment(production: true, child: child),
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

  Future<void> reach(WidgetTester tester, String text) =>
      localWait(tester, () => find.text(text).evaluate().isNotEmpty);

  Future<void> more(WidgetTester tester) async {
    await tester.tap(find.text('More details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<String> addBook(
    WidgetTester tester,
    DurableLifeController c, {
    int total = 10,
    int progress = 2,
  }) async {
    await tester.runAsync(
      () => c.saveEntry(LifeKind.book, {
        'title': 'A book',
        'detail': 'An author',
        'total': '$total',
        'progress': '$progress',
        'status': 'In progress',
      }),
    );
    return c.records.values.single.id;
  }

  group('Add a learning goal and Add a book', () {
    testWidgets('a blank total sends the rules’ default, not a made-up one', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.pumpWidget(
        app(LifeEntryForm(writer: LocalLifeWriter(c), type: LifeType.learning)),
      );
      await localSettle(tester);
      await enter(tester, 'title', 'Spanish');
      await enter(tester, 'detail', 'Practice');
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      expect(find.text('No total'), findsOneWidget);
      await tapReal(tester, submit());
      await reach(tester, 'Learning goal saved');
      final r = c.records.values.single as LearningRecord;
      expect(r.title, 'Spanish');
      expect(r.resource, 'Practice');
      expect(r.total, 1);
      expect(r.progress, 0);
      expect(r.status, 'Not started');
      expect(r.due, '');
      await close(tester, f, c);
    });

    testWidgets('a total shows where they’re up to, and saves it', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.pumpWidget(
        app(LifeEntryForm(writer: LocalLifeWriter(c), type: LifeType.book)),
      );
      await localSettle(tester);
      expect(find.byKey(const ValueKey('life-field-progress')), findsNothing);
      await enter(tester, 'title', 'Piranesi');
      await enter(tester, 'total', '272');
      await enter(tester, 'progress', '40');
      await enter(tester, 'due', '2026-12-01');
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      expect(find.text('40 of 272 pages'), findsOneWidget);
      await tapReal(tester, submit());
      await reach(tester, 'Book saved');
      final r = c.records.values.single as BookRecord;
      expect(r.total, 272);
      expect(r.progress, 40);
      expect(r.due, '2026-12-01');
      await close(tester, f, c);
    });

    testWidgets('fields show only when they apply', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.pumpWidget(
        app(LifeEntryForm(writer: LocalLifeWriter(c), type: LifeType.book)),
      );
      await localSettle(tester);
      await more(tester);
      expect(find.byKey(const ValueKey('life-field-completed')), findsNothing);
      expect(find.byKey(const ValueKey('life-field-rating')), findsNothing);
      final state = tester.state<State>(find.byType(LifeEntryForm));
      expect(state.mounted, isTrue);
      final status = tester.widget<OptionPicker<String>>(
        find.byKey(const ValueKey('life-field-select-status')),
      );
      status.onChanged!('Completed');
      await tester.pump();
      expect(find.byKey(const ValueKey('life-field-completed')), findsOneWidget);
      expect(find.byKey(const ValueKey('life-field-rating')), findsOneWidget);
      await close(tester, f, c);
    });

    testWidgets('a rule’s refusal lands on its field', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.pumpWidget(
        app(LifeEntryForm(writer: LocalLifeWriter(c), type: LifeType.book)),
      );
      await localSettle(tester);
      await tapReal(tester, submit());
      await reach(tester, 'Enter a title of at most 200 characters.');
      await enter(tester, 'title', 'x');
      await enter(tester, 'total', '5');
      await enter(tester, 'progress', '6');
      await tapReal(tester, submit());
      await reach(
        tester,
        'Enter progress from 0 up to the total, and a total from 1 to 1,000,000.',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('life-field-progress')),
          matching: find.textContaining('Enter progress'),
        ),
        findsOneWidget,
      );
      expect(c.records, isEmpty);
      await close(tester, f, c);
    });

    testWidgets('a date finished before the start goes on its field', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.pumpWidget(
        app(LifeEntryForm(writer: LocalLifeWriter(c), type: LifeType.book)),
      );
      await localSettle(tester);
      await enter(tester, 'title', 'x');
      await more(tester);
      tester
          .widget<OptionPicker<String>>(
            find.byKey(const ValueKey('life-field-select-status')),
          )
          .onChanged!('Completed');
      await tester.pump();
      await enter(tester, 'started', '2026-10-02');
      await enter(tester, 'completed', '2026-10-01');
      await tapReal(tester, submit());
      await reach(tester, 'The date finished can’t be before the date started.');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('life-field-completed')),
          matching: find.textContaining('date finished'),
        ),
        findsOneWidget,
      );
      await close(tester, f, c);
    });

    testWidgets('Edit asks why, and keeps what it doesn’t show', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addBook(tester, c);
      await tester.pumpWidget(
        app(
          LifeEntryForm(writer: LocalLifeWriter(c), type: LifeType.book, id: id),
        ),
      );
      await localSettle(tester);
      await enter(tester, 'title', 'A better title');
      await tapReal(tester, submit());
      await reach(tester, 'Say why you’re changing this, in up to 2,000 characters.');
      await enter(tester, 'reason', 'Typo');
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      await tapReal(tester, submit());
      await reach(tester, 'Book saved');
      final r = c.records[id]! as BookRecord;
      expect(r.title, 'A better title');
      expect(r.author, 'An author');
      expect(r.total, 10);
      expect(r.progress, 2);
      expect(r.version, 2);
      await close(tester, f, c);
    });
  });

  group('Log progress', () {
    Widget form(LifeWriter w, String id) =>
        app(LifeProgressForm(writer: w, id: id));

    testWidgets('it saves through the form’s one command', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addBook(tester, c);
      await tester.pumpWidget(form(LocalLifeWriter(c), id));
      await localSettle(tester);
      expect(find.text('Out of 10 pages.'), findsOneWidget);
      await enter(tester, 'progress', '6');
      await enter(tester, 'note', 'Chapter 3');
      await tapReal(tester, submit());
      await reach(tester, '6 of 10 pages');
      await tapReal(tester, submit());
      await reach(tester, 'Progress saved');
      final r = c.records[id]! as BookRecord;
      expect(r.progress, 6);
      expect(r.status, 'In progress');
      final history = await tester.runAsync(() => LocalLifeWriter(c).history(id));
      expect(history!.last.$2.reason, 'Chapter 3');
      await close(tester, f, c);
    });

    testWidgets('Date finished shows only at the total, and is optional', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addBook(tester, c);
      await tester.pumpWidget(form(LocalLifeWriter(c), id));
      await localSettle(tester);
      expect(find.byKey(const ValueKey('life-field-completed')), findsNothing);
      await enter(tester, 'progress', '10');
      expect(find.byKey(const ValueKey('life-field-completed')), findsOneWidget);
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      await tapReal(tester, submit());
      await reach(tester, 'Progress saved');
      final r = c.records[id]! as BookRecord;
      expect(r.status, 'Completed');
      expect(r.fields['completed'], '');
      await close(tester, f, c);
    });

    testWidgets('a date given at the total is saved', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addBook(tester, c);
      await tester.pumpWidget(form(LocalLifeWriter(c), id));
      await localSettle(tester);
      await enter(tester, 'progress', '10');
      await enter(tester, 'completed', '2026-11-01');
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      await tapReal(tester, submit());
      await reach(tester, 'Progress saved');
      expect(c.records[id]!.fields['completed'], '2026-11-01');
      await close(tester, f, c);
    });

    testWidgets('after a lost answer it freezes and sends the same command', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addBook(tester, c);
      final writer = FlakyWriter(c)..lose = true;
      await tester.pumpWidget(form(writer, id));
      await localSettle(tester);
      await enter(tester, 'progress', '6');
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      await tapReal(tester, submit());
      await reach(tester, lostSaveTitle);
      expect(find.byKey(const ValueKey('life-edit')), findsNothing);
      await tapReal(tester, find.byKey(const ValueKey('life-check-again')));
      await reach(tester, 'Progress saved');
      expect(writer.ids, hasLength(2));
      expect(writer.ids.toSet(), hasLength(1));
      final history = await tester.runAsync(() => LocalLifeWriter(c).history(id));
      expect(history, hasLength(2));
      expect(c.records[id]!.fields['progress'], '6');
      await close(tester, f, c);
    });

    testWidgets('a lost answer on Add a book adds it once', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final writer = FlakyWriter(c)..lose = true;
      await tester.pumpWidget(
        app(LifeEntryForm(writer: writer, type: LifeType.book)),
      );
      await localSettle(tester);
      await enter(tester, 'title', 'Once');
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      await tapReal(tester, submit());
      await reach(tester, lostSaveTitle);
      await tapReal(tester, find.byKey(const ValueKey('life-check-again')));
      await reach(tester, 'Book saved');
      expect(c.records, hasLength(1));
      await close(tester, f, c);
    });

    testWidgets('a record that changed stops it and offers Discard draft', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addBook(tester, c);
      await tester.pumpWidget(form(LocalLifeWriter(c), id));
      await localSettle(tester);
      await tester.runAsync(
        () => c.change(id, 1, {'notes': 'Changed elsewhere'}, 'Elsewhere'),
      );
      await enter(tester, 'progress', '6');
      await tapReal(tester, submit());
      await reach(tester, 'This changed');
      expect(find.byKey(const ValueKey('life-discard-draft')), findsOneWidget);
      await close(tester, f, c);
    });

    testWidgets('a saved form says when it’s waiting to sync', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final writer = LocalLifeWriter(c);
      c.intents = [
        {'id': 'waiting', 'state': 'pending'},
      ];
      expect(
        writer.savedLine('waiting'),
        'Saved on this device. It’s waiting to sync.',
      );
      expect(writer.savedLine('another'), 'Saved.');
      c.intents = const [];
      await close(tester, f, c);
    });
  });

  group('Saved drafts', () {
    Future<void> show(
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
        app(SavedDraftsPage(controller: money, session: session)),
      );
      await localSettle(tester);
    }

    testWidgets('tapping a new book’s draft opens its form', (tester) async {
      sized(tester);
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final (f, c) = await open(tester);
      await tester.runAsync(
        () => f.store.saveDraft('life:new-book', newLocalId(), {
          'title': 'Half typed',
        }),
      );
      await show(tester, f, session);
      expect(find.text('Half typed'), findsOneWidget);
      await tester.tap(find.text('Add a book'));
      await localSettle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(LifeEntryForm), findsOneWidget);
      await close(tester, f, c);
    });

    testWidgets('each form’s draft has a real title and opens', (tester) async {
      for (final (operation, values, title) in [
        ('life:new-learning', {'title': 'A'}, 'Add a learning goal'),
        ('life:new-book', {'title': 'B'}, 'Add a book'),
      ]) {
        expect(lifeDraftKind(operation, values).title, title);
        expect(lifeDraftKind(operation, values).form, isNotNull);
      }
      expect(
        lifeDraftKind('life:${newLocalId()}', {'total': '2', 'rating': ''}),
        (title: 'Edit book', form: 'edit-entry'),
      );
      expect(
        lifeDraftKind('life:${newLocalId()}', {'total': '2'}),
        (title: 'Edit learning goal', form: 'edit-entry'),
      );
      expect(
        lifeDraftKind('life:progress:${newLocalId()}', const {}),
        (title: 'Log progress', form: 'progress'),
      );
      expect(
        lifeDraftKind('life:Log progress · Old', const {}),
        (title: 'Log progress', form: 'progress'),
      );
    });

    testWidgets('an old Log progress draft opens the new form', (tester) async {
      sized(tester);
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final (f, c) = await open(tester);
      final id = await addBook(tester, c);
      await tester.runAsync(
        () => f.store.saveDraft('life:Log progress · A book', newLocalId(), {
          'progress': '7',
          '__record': id,
          '__version': '1',
          '__command': newLocalId(),
          '__recordedAt': DateTime.now().toUtc().toIso8601String(),
          '__draft': 'life:Log progress · A book',
        }),
      );
      expect(
        progressDraftRecord(LocalLifeWriter(c), 'Log progress · A book', {
          '__record': id,
        }),
        id,
      );
      expect(
        progressDraftRecord(LocalLifeWriter(c), 'Log progress · A book', {
          '__record': newLocalId(),
        }),
        isNull,
      );
      await tester.pumpWidget(
        app(
          LifeProgressForm(
            writer: LocalLifeWriter(c),
            id: id,
            draft: 'life:Log progress · A book',
          ),
        ),
      );
      await localSettle(tester);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('life-field-progress')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '7',
      );
      await close(tester, f, c);
    });

    testWidgets('an edit draft’s form brings back what was typed', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addBook(tester, c);
      await tester.runAsync(
        () => f.store.saveDraft('life:$id', newLocalId(), {
          'title': 'Half typed',
          'total': '10',
          'progress': '2',
          'rating': '',
          '__version': '1',
          '__command': newLocalId(),
          '__record': id,
        }),
      );
      await tester.pumpWidget(
        app(
          LifeEntryForm(writer: LocalLifeWriter(c), type: LifeType.book, id: id),
        ),
      );
      await localSettle(tester);
      expect(find.text('Half typed'), findsOneWidget);
      await close(tester, f, c);
    });
  });
}
