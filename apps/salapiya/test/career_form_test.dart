import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/finance/presentation/financial_widgets.dart';
import 'package:salapiya/life/career_forms.dart';
import 'package:salapiya/life/life_controller.dart';
import 'package:salapiya/life/life_data.dart';
import 'package:salapiya/life/life_domain.dart';
import 'package:salapiya/life/life_forms.dart';
import 'package:salapiya/life/life_hub.dart';
import 'package:salapiya/local/finance_domain.dart';

import 'local_money_journey.dart' show localSettle, localTap, localWait;
import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

const windows = TargetPlatform.windows;

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
  Future<void> saveApplication(Map<String, String> v, {String? old}) async {
    await super.saveApplication(v, old: old);
    _lost(v);
  }

  @override
  Future<void> saveStep(
    Map<String, String> v,
    String application, {
    String? old,
  }) async {
    await super.saveStep(v, application, old: old);
    _lost(v);
  }
}

void main() {
  final today = civilToday();

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

  Widget app(Widget child) => MaterialApp(
    themeAnimationDuration: Duration.zero,
    theme: SalapiyaTheme.build(Brightness.light, platform: windows),
    home: FinancialEnvironment(production: true, child: child),
  );

  void sized(WidgetTester tester, [double width = 900]) {
    tester.view.physicalSize = Size(width, 3000);
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

  void pick(WidgetTester tester, String key, String value) => tester
      .widget<OptionPicker<String>>(
        find.byKey(ValueKey('life-field-select-$key')),
      )
      .onChanged!(value);

  Future<void> tapReal(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump();
    await localTap(tester, target);
  }

  Future<void> reach(WidgetTester tester, String text) =>
      localWait(tester, () => find.text(text).evaluate().isNotEmpty);

  Future<void> more(WidgetTester tester) async {
    await tester.ensureVisible(find.text('More details'));
    await tester.tap(find.text('More details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> save(WidgetTester tester, String saved) async {
    await tapReal(tester, submit());
    await reach(tester, 'Step 2 of 2 · Review');
    await tapReal(tester, submit());
    await reach(tester, saved);
  }

  Future<String> addApplication(
    WidgetTester tester,
    DurableLifeController c, {
    String stage = 'Applied',
    String? date,
    Map<String, String> more = const {},
  }) async {
    await tester.runAsync(
      () => c.saveApplication({
        'company': 'Acme',
        'position': 'Designer',
        'stage': stage,
        'stageDate': today,
        'date': stage == 'Saved' ? '' : date ?? today,
        ...more,
      }),
    );
    return c.records.values.whereType<ApplicationRecord>().last.id;
  }

  group('Add an application', () {
    testWidgets('a saved one sends the same keys, with no date applied', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.pumpWidget(
        app(LifeApplicationForm(writer: LocalLifeWriter(c))),
      );
      await localSettle(tester);
      expect(find.byKey(const ValueKey('life-field-date')), findsNothing);
      await enter(tester, 'company', 'Acme');
      await enter(tester, 'position', 'Designer');
      await save(tester, 'Application saved');
      final r = c.records.values.single as ApplicationRecord;
      expect(r.company, 'Acme');
      expect(r.position, 'Designer');
      expect(r.stage, 'Saved');
      expect(r.status, 'Saved');
      expect(r.outcome, '');
      expect(r.fields['date'], '');
      expect(r.fields['stageDate'], today);
      expect(r.fields['currency'], 'PHP');
      expect(r.fields['salaryPeriod'], 'month');
      expect(r.fields['arrangement'], 'unspecified');
      await close(tester, f, c);
    });

    testWidgets('Applied asks when, and its stage dates from it', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.pumpWidget(
        app(LifeApplicationForm(writer: LocalLifeWriter(c))),
      );
      await localSettle(tester);
      await enter(tester, 'company', 'Acme');
      await enter(tester, 'position', 'Designer');
      pick(tester, 'stage', 'Applied');
      await tester.pump();
      await tapReal(tester, submit());
      await reach(tester, 'Choose a date between 1900 and 2200.');
      await enter(tester, 'date', '2026-10-01');
      await save(tester, 'Application saved');
      final r = c.records.values.single as ApplicationRecord;
      expect(r.fields['date'], '2026-10-01');
      expect(r.fields['stageDate'], '2026-10-01');
      await close(tester, f, c);
    });

    testWidgets('a later stage asks since when, and the rule holds', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.pumpWidget(
        app(LifeApplicationForm(writer: LocalLifeWriter(c))),
      );
      await localSettle(tester);
      await enter(tester, 'company', 'Acme');
      await enter(tester, 'position', 'Designer');
      pick(tester, 'stage', 'Interview');
      await tester.pump();
      await enter(tester, 'date', '2026-10-10');
      await enter(tester, 'stageDate', '2026-10-01');
      await tapReal(tester, submit());
      await reach(tester, 'The stage date can’t be before the date applied.');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('life-field-stageDate')),
          matching: find.textContaining('stage date can’t be'),
        ),
        findsOneWidget,
      );
      await close(tester, f, c);
    });

    testWidgets('errors land on company and position', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.pumpWidget(
        app(LifeApplicationForm(writer: LocalLifeWriter(c))),
      );
      await localSettle(tester);
      await tapReal(tester, submit());
      await reach(tester, 'Enter the company, in up to 200 characters.');
      await enter(tester, 'company', 'Acme');
      await tapReal(tester, submit());
      await reach(tester, 'Enter a title of at most 200 characters.');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('life-field-position')),
          matching: find.textContaining('Enter a title'),
        ),
        findsOneWidget,
      );
      await close(tester, f, c);
    });

    testWidgets('salary fields show as they apply, and errors find them', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      await tester.pumpWidget(
        app(LifeApplicationForm(writer: LocalLifeWriter(c))),
      );
      await localSettle(tester);
      await enter(tester, 'company', 'Acme');
      await enter(tester, 'position', 'Designer');
      await more(tester);
      expect(find.byKey(const ValueKey('life-field-currency')), findsNothing);
      await enter(tester, 'salaryMin', '900');
      expect(find.byKey(const ValueKey('life-field-currency')), findsOneWidget);
      await enter(tester, 'salaryMax', '100');
      await tapReal(tester, submit());
      await reach(tester, 'The lowest salary can’t be more than the highest.');
      await enter(tester, 'salaryMax', '1000');
      await enter(tester, 'currency', 'usd');
      await enter(tester, 'postingUrl', 'ftp://example.com');
      await tapReal(tester, submit());
      await reach(
        tester,
        'Enter the posting’s web address, starting with https:// or http://, with no sign-in details in it.',
      );
      await enter(tester, 'postingUrl', 'https://example.com/job');
      await save(tester, 'Application saved');
      final r = c.records.values.single as ApplicationRecord;
      expect(r.fields['salaryMin'], '900');
      expect(r.fields['currency'], 'USD');
      expect(r.fields['postingUrl'], 'https://example.com/job');
      await close(tester, f, c);
    });

    testWidgets('a duplicate asks, and a separate attempt is fine', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      await addApplication(tester, c);
      await tester.pumpWidget(
        app(LifeApplicationForm(writer: LocalLifeWriter(c))),
      );
      await localSettle(tester);
      await enter(tester, 'company', 'acme');
      expect(
        find.byKey(const ValueKey('life-field-duplicateConsent')),
        findsNothing,
      );
      await enter(tester, 'position', 'DESIGNER');
      expect(
        find.byKey(const ValueKey('life-field-duplicateConsent')),
        findsOneWidget,
      );
      await tapReal(tester, submit());
      await localSettle(tester);
      expect(c.records, hasLength(1));
      await tapReal(
        tester,
        find.byKey(const ValueKey('life-field-duplicateConsent')),
      );
      await save(tester, 'Application saved');
      expect(c.records, hasLength(2));
      expect(
        c.records.values.whereType<ApplicationRecord>().last.fields,
        isNot(contains('duplicateConsent')),
      );
      await close(tester, f, c);
    });

    testWidgets('a lost answer freezes it and adds it once', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final writer = FlakyWriter(c)..lose = true;
      await tester.pumpWidget(app(LifeApplicationForm(writer: writer)));
      await localSettle(tester);
      await enter(tester, 'company', 'Acme');
      await enter(tester, 'position', 'Designer');
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      await tapReal(tester, submit());
      await reach(tester, lostSaveTitle);
      expect(find.byKey(const ValueKey('life-edit')), findsNothing);
      await tapReal(tester, find.byKey(const ValueKey('life-check-again')));
      await reach(tester, 'Application saved');
      expect(writer.ids.toSet(), hasLength(1));
      expect(c.records, hasLength(1));
      await close(tester, f, c);
    });
  });

  group('Edit application', () {
    testWidgets('it asks why and keeps what it doesn’t show', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(
        tester,
        c,
        stage: 'Interview',
        more: {'salaryMin': '100', 'contact': 'Tala', 'outcome': ''},
      );
      await tester.pumpWidget(
        app(LifeApplicationForm(writer: LocalLifeWriter(c), id: id)),
      );
      await localSettle(tester);
      await enter(tester, 'position', 'Lead designer');
      await tapReal(tester, submit());
      await reach(tester, 'Say why you’re changing this, in up to 2,000 characters.');
      await enter(tester, 'reason', 'Retitled');
      await save(tester, 'Application saved');
      final r = c.records[id]! as ApplicationRecord;
      expect(r.position, 'Lead designer');
      expect(r.stage, 'Interview');
      expect(r.fields['salaryMin'], '100');
      expect(r.fields['contact'], 'Tala');
      await close(tester, f, c);
    });

    testWidgets('with Hide amounts on, a salary stays, unseen, through a save', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(
        tester,
        c,
        more: {'salaryMin': '12345.67', 'salaryMax': '20000'},
      );
      await tester.pumpWidget(
        app(
          LifeApplicationForm(
            writer: LocalLifeWriter(c),
            id: id,
            hidden: true,
          ),
        ),
      );
      await localSettle(tester);
      await more(tester);
      expect(find.byKey(const ValueKey('life-field-salaryMin')), findsNothing);
      expect(find.textContaining('12345'), findsNothing);
      await enter(tester, 'reason', 'Tidying');
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      expect(find.textContaining('12,345'), findsNothing);
      expect(find.text('Amount hidden'), findsOneWidget);
      await tapReal(tester, submit());
      await reach(tester, 'Application saved');
      expect(find.textContaining('12,345'), findsNothing);
      expect(c.records[id]!.fields['salaryMin'], '12345.67');
      await close(tester, f, c);
    });
  });

  group('Change stage', () {
    Widget form(LifeWriter w, String id, StageChange change) =>
        app(LifeStageForm(writer: w, id: id, change: change));

    testWidgets('it moves the stage and keeps the rest', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c, more: {'contact': 'Tala'});
      await tester.pumpWidget(form(LocalLifeWriter(c), id, StageChange.stage));
      await localSettle(tester);
      pick(tester, 'stage', 'Screening');
      await tester.pump();
      await enter(tester, 'reason', 'They called');
      await save(tester, 'Stage saved');
      final r = c.records[id]! as ApplicationRecord;
      expect(r.stage, 'Screening');
      expect(r.status, 'Screening');
      expect(r.fields['contact'], 'Tala');
      await close(tester, f, c);
    });

    testWidgets('choosing the same stage says so', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c);
      await tester.pumpWidget(form(LocalLifeWriter(c), id, StageChange.stage));
      await localSettle(tester);
      await enter(tester, 'reason', 'x');
      await tapReal(tester, submit());
      await reach(tester, 'Choose a stage from the list.');
      await close(tester, f, c);
    });

    testWidgets('leaving Saved asks for the date applied', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c, stage: 'Saved');
      await tester.pumpWidget(form(LocalLifeWriter(c), id, StageChange.stage));
      await localSettle(tester);
      expect(find.byKey(const ValueKey('life-field-date')), findsNothing);
      pick(tester, 'stage', 'Applied');
      await tester.pump();
      expect(find.byKey(const ValueKey('life-field-date')), findsOneWidget);
      await enter(tester, 'date', today);
      await enter(tester, 'reason', 'Sent it');
      await save(tester, 'Stage saved');
      expect(c.records[id]!.fields['date'], today);
      await close(tester, f, c);
    });

    testWidgets('going back to Saved clears the date, as the rules insist', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c);
      await tester.pumpWidget(form(LocalLifeWriter(c), id, StageChange.stage));
      await localSettle(tester);
      pick(tester, 'stage', 'Saved');
      await tester.pump();
      expect(find.textContaining('that date is cleared'), findsOneWidget);
      await enter(tester, 'reason', 'Not sent after all');
      await save(tester, 'Stage saved');
      expect(c.records[id]!.fields['date'], '');
      await close(tester, f, c);
    });

    testWidgets('Accepted pairs itself, so the rules never refuse it', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c, stage: 'Offer');
      await tester.pumpWidget(
        form(LocalLifeWriter(c), id, StageChange.outcome),
      );
      await localSettle(tester);
      pick(tester, 'outcome', 'Accepted');
      await tester.pump();
      await enter(tester, 'reason', 'Said yes');
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      expect(find.textContaining('This closes the application'), findsOneWidget);
      await tapReal(tester, submit());
      await reach(tester, 'Outcome saved');
      final r = c.records[id]! as ApplicationRecord;
      expect(r.stage, 'Accepted');
      expect(r.outcome, 'Accepted');
      expect(r.status, 'Accepted');
      await close(tester, f, c);
    });

    testWidgets('any other outcome keeps the last stage', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c, stage: 'Interview');
      await tester.pumpWidget(
        form(LocalLifeWriter(c), id, StageChange.outcome),
      );
      await localSettle(tester);
      pick(tester, 'outcome', 'Withdrawn');
      await tester.pump();
      await enter(tester, 'reason', 'Took another job');
      await save(tester, 'Outcome saved');
      final r = c.records[id]! as ApplicationRecord;
      expect(r.stage, 'Interview');
      expect(r.outcome, 'Withdrawn');
      expect(r.terminal, isTrue);
      await close(tester, f, c);
    });

    testWidgets('reopening asks for a stage after Accepted', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c, stage: 'Offer');
      await tester.runAsync(
        () => c.saveApplication({
          'company': 'Acme',
          'position': 'Designer',
          'stage': 'Accepted',
          'outcome': 'Accepted',
          'date': today,
          'stageDate': today,
          'reason': 'Yes',
        }, old: c.applications.single),
      );
      await tester.pumpWidget(
        form(LocalLifeWriter(c), id, StageChange.reopen),
      );
      await localSettle(tester);
      await enter(tester, 'reason', 'Fell through');
      await tapReal(tester, submit());
      await reach(tester, 'Choose a stage from the list.');
      pick(tester, 'stage', 'Offer');
      await tester.pump();
      await save(tester, 'Application reopened');
      final r = c.records[id]! as ApplicationRecord;
      expect(r.stage, 'Offer');
      expect(r.outcome, '');
      expect(r.terminal, isFalse);
      await close(tester, f, c);
    });
  });

  group('Steps', () {
    Widget form(LifeWriter w, String app_, {String? id}) =>
        app(LifeStepForm(writer: w, application: app_, id: id));

    testWidgets('an interview saves the same keys and defaults', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c);
      await tester.pumpWidget(form(LocalLifeWriter(c), id));
      await localSettle(tester);
      expect(find.byKey(const ValueKey('life-field-allDay')), findsNothing);
      await enter(tester, 'date', '2026-12-01');
      await save(tester, 'Step saved');
      final r = c.records.values.whereType<CareerEventRecord>().single;
      expect(r.kind, 'Interview');
      expect(r.applicationId, id);
      expect(r.date, '2026-12-01');
      expect(r.time, '10:00');
      expect(r.timezone, 'Asia/Manila');
      expect(r.status, 'Scheduled');
      expect(r.utc, isNotNull);
      await close(tester, f, c);
    });

    testWidgets('a follow-up can be all day', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c);
      await tester.pumpWidget(form(LocalLifeWriter(c), id));
      await localSettle(tester);
      pick(tester, 'kind', 'Follow-up');
      await tester.pump();
      await tapReal(tester, find.byKey(const ValueKey('life-field-allDay')));
      expect(find.byKey(const ValueKey('life-field-time')), findsNothing);
      await save(tester, 'Step saved');
      final r = c.records.values.whereType<CareerEventRecord>().single;
      expect(r.time, '');
      expect(r.utc, isNull);
      await close(tester, f, c);
    });

    testWidgets('what happened saves as done, so the rules never refuse it', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c);
      for (final kind in careerObservations) {
        await tester.pumpWidget(
          KeyedSubtree(key: UniqueKey(), child: form(LocalLifeWriter(c), id)),
        );
        await localSettle(tester);
        pick(tester, 'kind', kind);
        await tester.pump();
        expect(find.byKey(const ValueKey('life-field-time')), findsNothing);
        await save(tester, 'Step saved');
      }
      final steps = c.records.values.whereType<CareerEventRecord>();
      expect(steps, hasLength(careerObservations.length));
      expect(steps.every((r) => r.status == 'Completed'), isTrue);
      await close(tester, f, c);
    });

    testWidgets('a time that doesn’t exist errors on Time as it’s picked', (
      tester,
    ) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c);
      await tester.pumpWidget(form(LocalLifeWriter(c), id));
      await localSettle(tester);
      await enter(tester, 'date', '2026-10-04');
      await enter(tester, 'time', '02:30');
      await more(tester);
      await enter(tester, 'timezone', 'Australia/Sydney');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('life-field-time')),
          matching: find.textContaining('doesn’t happen on this date'),
        ),
        findsOneWidget,
      );
      await close(tester, f, c);
    });

    testWidgets('a time that happens twice asks which', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c);
      await tester.pumpWidget(form(LocalLifeWriter(c), id));
      await localSettle(tester);
      await enter(tester, 'date', '2026-04-05');
      await enter(tester, 'time', '02:30');
      await more(tester);
      await enter(tester, 'timezone', 'Australia/Sydney');
      expect(
        find.byKey(const ValueKey('life-field-select-fold')),
        findsOneWidget,
      );
      await close(tester, f, c);
    });

    testWidgets('a lost answer sends the same command', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c);
      final writer = FlakyWriter(c)..lose = true;
      await tester.pumpWidget(form(writer, id));
      await localSettle(tester);
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      await tapReal(tester, submit());
      await reach(tester, lostSaveTitle);
      await tapReal(tester, find.byKey(const ValueKey('life-check-again')));
      await reach(tester, 'Step saved');
      expect(writer.ids.toSet(), hasLength(1));
      expect(c.records.values.whereType<CareerEventRecord>(), hasLength(1));
      await close(tester, f, c);
    });

    testWidgets('a closed application refuses in plain words', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c, stage: 'Interview');
      await tester.pumpWidget(form(LocalLifeWriter(c), id));
      await localSettle(tester);
      await tester.runAsync(
        () => c.saveApplication({
          'company': 'Acme',
          'position': 'Designer',
          'stage': 'Interview',
          'outcome': 'Rejected',
          'date': today,
          'stageDate': today,
          'reason': 'No',
        }, old: c.applications.single),
      );
      await tapReal(tester, submit());
      await reach(tester, 'Step 2 of 2 · Review');
      await tapReal(tester, submit());
      await reach(
        tester,
        'This application is closed or archived, so it can’t take steps. Reopen or restore it first.',
      );
      expect(c.records.values.whereType<CareerEventRecord>(), isEmpty);
      await close(tester, f, c);
    });

    testWidgets('Edit keeps the step on its application', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c);
      await tester.pumpWidget(form(LocalLifeWriter(c), id));
      await localSettle(tester);
      await save(tester, 'Step saved');
      final step = c.records.values.whereType<CareerEventRecord>().single;
      await tester.pumpWidget(
        KeyedSubtree(
          key: UniqueKey(),
          child: form(LocalLifeWriter(c), id, id: step.id),
        ),
      );
      await localSettle(tester);
      await enter(tester, 'reason', 'Moved');
      await enter(tester, 'date', '2026-12-05');
      await save(tester, 'Step saved');
      final r = c.records[step.id]! as CareerEventRecord;
      expect(r.date, '2026-12-05');
      expect(r.applicationId, id);
      expect(r.version, 2);
      await close(tester, f, c);
    });
  });

  group('Drafts', () {
    test('each form’s draft has a real title', () {
      final id = newLocalId();
      for (final (key, values, title, form) in [
        ('new-career', const <String, String>{}, 'Add an application', 'application'),
        ('new-career-event-$id', const <String, String>{}, 'Add a step', 'step'),
        ('stage:$id', const <String, String>{}, 'Change stage', 'stage'),
        ('outcome:$id', const <String, String>{}, 'Record outcome', 'outcome'),
        ('reopen:$id', const <String, String>{}, 'Reopen application', 'reopen'),
        (id, const {'company': 'x', 'position': 'y'}, 'Edit application', 'edit-application'),
        (id, const {'kind': 'Interview', 'timezone': 'x'}, 'Edit step', 'edit-step'),
      ]) {
        expect(
          lifeDraftKind('life:$key', values),
          (title: title, form: form),
          reason: key,
        );
      }
    });

    testWidgets('an old edit draft comes back in the new form', (tester) async {
      sized(tester);
      final (f, c) = await open(tester);
      final id = await addApplication(tester, c);
      await tester.runAsync(
        () => f.store.saveDraft('life:$id', newLocalId(), {
          ...applicationValues(c.records[id]! as ApplicationRecord, today),
          'position': 'Half typed',
          'reason': '',
          '__version': '1',
          '__command': newLocalId(),
          '__record': id,
        }),
      );
      await tester.pumpWidget(
        app(LifeApplicationForm(writer: LocalLifeWriter(c), id: id)),
      );
      await localSettle(tester);
      expect(find.text('Half typed'), findsOneWidget);
      await close(tester, f, c);
    });
  });
}
