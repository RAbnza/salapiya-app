import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/life/application/life_controller.dart'
    show AgendaItem;
import 'package:salapiya/features/life/presentation/life_screen.dart';
import 'package:salapiya/life/career_forms.dart';
import 'package:salapiya/life/career_pages.dart';
import 'package:salapiya/life/career_tab.dart';
import 'package:salapiya/life/life_data.dart';
import 'package:salapiya/life/life_demo.dart';
import 'package:salapiya/life/life_domain.dart';
import 'package:salapiya/life/life_hub.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/prototype/scenarios.dart';

const windows = TargetPlatform.windows, android = TargetPlatform.android;

/// §2 sweep: both platforms at every width and both text sizes.
const sizes = [
  (android, 320.0),
  (android, 360.0),
  (android, 412.0),
  (windows, 720.0),
  (windows, 1200.0),
  (windows, 1440.0),
];

void main() {
  Future<void> app(
    WidgetTester tester,
    Widget child, {
    required TargetPlatform platform,
    required double width,
    double text = 1,
    Brightness brightness = Brightness.light,
    double height = 5200,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        themeAnimationDuration: Duration.zero,
        theme: SalapiyaTheme.build(brightness, platform: platform),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(text),
          ),
          child: child,
        ),
      ),
    );
    await tester.pump();
  }

  Widget life(PrototypeSession session) => Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(Space.lg),
      child: LifeScreen(key: UniqueKey(), session: session, initial: 'Career'),
    ),
  );

  void clean(WidgetTester tester, String label) {
    final error = tester.takeException();
    expect(error, isNull, reason: '$label: $error');
  }

  LifeRecord find_(bool Function(LifeRecord) test) =>
      demoLife(civilToday()).records.values.firstWhere(test);

  String appId(String company) =>
      find_((r) => r is ApplicationRecord && r.company == company).id;

  String stepId(String company, String kind) => find_(
    (r) =>
        r is CareerEventRecord &&
        r.applicationId == appId(company) &&
        r.kind == kind,
  ).id;

  Widget application(PrototypeSession s, String company) => LifeApplicationPage(
    listenable: s,
    source: (context) => lifeSource(context, s),
    id: appId(company),
  );

  Widget stepPage(PrototypeSession s, String id) => LifeStepPage(
    listenable: s,
    source: (context) => lifeSource(context, s),
    id: id,
  );

  Future<LifeWriter> writerOf(WidgetTester tester, PrototypeSession s) async {
    late LifeWriter writer;
    await app(
      tester,
      Builder(
        builder: (c) {
          writer = lifeSource(c, s).writer;
          return const SizedBox();
        },
      ),
      platform: windows,
      width: 1200,
    );
    return writer;
  }

  group('sweep', () {
    testWidgets('Career at every size, text size and theme', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (platform, width) in sizes) {
        for (final text in [1.0, 2.0]) {
          for (final brightness in Brightness.values) {
            await app(
              tester,
              life(session),
              platform: platform,
              width: width,
              text: text,
              brightness: brightness,
            );
            expect(find.byType(KpiTile), findsNWidgets(4));
            clean(tester, '$platform $width $text $brightness');
          }
        }
      }
    });

    testWidgets('hidden and empty on both platforms', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (platform, width) in sizes) {
        session.togglePrivacy();
        await app(tester, life(session), platform: platform, width: width);
        expect(find.textContaining('₱'), findsNothing);
        expect(find.textContaining('USD'), findsNothing);
        clean(tester, 'hidden $platform $width');
        session.togglePrivacy();

        session.select(OverviewScenario.empty);
        await app(tester, life(session), platform: platform, width: width);
        expect(find.text('No applications yet'), findsWidgets);
        clean(tester, 'empty $platform $width');
        session.select(OverviewScenario.local);
      }
    });

    testWidgets('an unfinished Life download reads Not available yet', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      late BuildContext context;
      await app(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
        platform: windows,
        width: 1200,
      );
      final s = lifeSource(context, session);
      await app(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: LifeCareerTab(
              source: LifeSource(
                today: s.today,
                timezone: s.timezone,
                complete: true,
                lifeComplete: false,
                hidden: false,
                amount: s.amount,
                records: s.records,
                snapshot: s.snapshot,
                writer: s.writer,
                actions: s.actions,
                visible: s.visible,
              ),
              hub: lifeHubOf(session),
              listenable: session,
              live: (context) => lifeSource(context, session),
            ),
          ),
        ),
        platform: windows,
        width: 1200,
      );
      expect(find.text('Not available yet'), findsNWidgets(4));
      clean(tester, 'incomplete');
    });

    testWidgets('an application at every size, text size and theme', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final company in const [
        'Amihan Studio', // Everything filled in.
        'North & Co.', // Saved.
        'Bayan Digital', // A follow-up overdue.
        'Alon & Co.', // Offer, salary in another currency.
        'Liwanag Studio', // Accepted.
        'Hangin Tech', // Rejected, with a step.
        'Sampaguita Co.', // Opening cancelled.
        'Ilog Partners', // Archived.
      ]) {
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            for (final brightness in Brightness.values) {
              await app(
                tester,
                application(session, company),
                platform: platform,
                width: width,
                text: text,
                brightness: brightness,
              );
              await tester.pump();
              clean(tester, '$company $platform $width $text $brightness');
            }
          }
        }
      }
    });

    testWidgets('a step at every size and text size', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (company, kind) in const [
        ('Kapwa Health', 'Interview'), // Another timezone.
        ('Sinag Labs', 'Follow-up'), // All day.
        ('Tala Systems', 'Assessment'), // Gone by.
        ('Amihan Studio', 'Response'), // What happened.
        ('Hangin Tech', 'No response'), // On a closed application.
      ]) {
        final id = stepId(company, kind);
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            await app(
              tester,
              stepPage(session, id),
              platform: platform,
              width: width,
              text: text,
            );
            await tester.pump();
            clean(tester, '$company $kind $platform $width $text');
          }
        }
      }
    });

    testWidgets('the shareable list at every size and text size', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (platform, width) in sizes) {
        for (final text in [1.0, 2.0]) {
          await app(
            tester,
            LifeApplicationsListPage(
              listenable: session,
              source: (context) => lifeSource(context, session),
            ),
            platform: platform,
            width: width,
            text: text,
          );
          clean(tester, '$platform $width $text');
        }
      }
    });

    testWidgets('the forms at every size and text size', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final writer = await writerOf(tester, session);
      final id = appId('Amihan Studio');
      for (final form in <Widget>[
        LifeApplicationForm(writer: writer),
        LifeApplicationForm(writer: writer, id: id),
        LifeApplicationForm(writer: writer, id: id, hidden: true),
        LifeStageForm(writer: writer, id: id, change: StageChange.stage),
        LifeStageForm(writer: writer, id: id, change: StageChange.outcome),
        LifeStageForm(
          writer: writer,
          id: appId('Hangin Tech'),
          change: StageChange.reopen,
        ),
        LifeStepForm(writer: writer, application: id),
        LifeStepForm(
          writer: writer,
          application: appId('Kapwa Health'),
          id: stepId('Kapwa Health', 'Interview'),
        ),
      ]) {
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            await app(
              tester,
              KeyedSubtree(key: UniqueKey(), child: form),
              platform: platform,
              width: width,
              text: text,
            );
            await tester.pump();
            await tester.pump();
            clean(tester, '${form.runtimeType} $platform $width $text');
          }
        }
      }
    });
  });

  group('what the tab says', () {
    CareerCounts counts() {
      final today = civilToday();
      final records = demoLife(today).records;
      return CareerCounts(
        applicationRows(records, today, 'Asia/Manila'),
        nextSteps(careerRows(records, today, 'Asia/Manila')),
      );
    }

    testWidgets('the header counts what the tab counts', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final c = counts();
      await app(tester, life(session), platform: windows, width: 1200);
      expect(find.textContaining('${c.active.length} active'), findsOneWidget);
      await app(tester, life(session), platform: android, width: 412);
      expect(find.text('${c.overdue.length} overdue'), findsOneWidget);
      expect(find.text('Add an application'), findsNothing);
    });

    testWidgets('Windows has its one action', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session), platform: windows, width: 1200);
      expect(find.text('Add an application'), findsOneWidget);
    });

    testWidgets('every open stage shows, and the closed ones add up', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session), platform: windows, width: 1200);
      final card = find.byKey(const ValueKey('life-career-stands'));
      for (final stage in careerPipelineStages.where((s) => s != 'Accepted')) {
        expect(
          find.descendant(of: card, matching: find.text(stage)),
          findsOneWidget,
          reason: stage,
        );
      }
      expect(
        find.descendant(
          of: card,
          matching: find.text('${counts().closed.length} closed'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('lists start at the top and close with ListEnd', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session), platform: windows, width: 1200);
      final card = find.byKey(const ValueKey('life-career-steps'));
      expect(
        find.descendant(of: card, matching: find.byType(ListEnd)),
        findsOneWidget,
      );
      final first = find.descendant(
        of: card,
        matching: find.byType(AdaptiveRow),
      );
      expect(
        tester.getTopLeft(first.first).dy - tester.getTopLeft(card).dy,
        lessThan(Space.xxxl * 2),
      );
    });

    testWidgets('tiles line their values up', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session), platform: windows, width: 1200);
      final tops = find
          .byType(KpiTile)
          .evaluate()
          .map((e) => tester.getTopLeft(find.byWidget(e.widget)).dy);
      expect(tops.toSet(), hasLength(1));
    });

    testWidgets('table columns line up', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session), platform: windows, width: 1440);
      final list = find.byKey(const ValueKey('life-career-list'));
      // The column's heading, not a stage's pill.
      final left = find
          .descendant(of: list, matching: find.text('Applied'))
          .first;
      final dates = find.descendant(
        of: list,
        matching: find.textContaining(RegExp(r'^(Not sent|[A-Z][a-z]{2}, )')),
      );
      expect(dates, findsWidgets);
      final x = tester.getTopLeft(left).dx;
      for (final e in dates.evaluate().take(6)) {
        expect(tester.getTopLeft(find.byWidget(e.widget).first).dx, x);
      }
    });

    testWidgets('filters and a stage leave the right rows', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = lifeHubOf(session);
      hub.setCareerFilter(ApplicationFilter.closed);
      await app(tester, life(session), platform: windows, width: 1440);
      final list = find.byKey(const ValueKey('life-career-list'));
      expect(
        find.descendant(of: list, matching: find.text('Hangin Tech')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: list, matching: find.text('Bayan Digital')),
        findsNothing,
      );
      hub.setCareerQuery('nothing like this');
      await tester.pump();
      expect(find.text('Nothing matches that'), findsOneWidget);
      hub.setCareerQuery('');
      hub.setCareerFilter(ApplicationFilter.all);
      hub.setCareerStage('Offer');
      await tester.pump();
      expect(
        find.descendant(of: list, matching: find.text('Alon & Co.')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: list, matching: find.text('Bayan Digital')),
        findsNothing,
      );
    });

    testWidgets('no list shows salary, contact or notes', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session), platform: windows, width: 1440);
      for (final text in const ['Tala Reyes', '60,000', 'USD', 'case study']) {
        expect(find.textContaining(text), findsNothing, reason: text);
      }
    });

    testWidgets('a type off on the Calendar leaves the tab as it was', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = lifeHubOf(session);
      await hub.saveView({
        ...hub.view,
        'calendar': {...hub.view['calendar'] as Map, 'Career': false},
      });
      await app(tester, life(session), platform: windows, width: 1200);
      final card = find.byKey(const ValueKey('life-career-steps'));
      expect(
        find.descendant(of: card, matching: find.byType(AdaptiveRow)),
        findsWidgets,
      );
    });

    testWidgets('a follow-up overdue reads overdue', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session), platform: windows, width: 1200);
      final card = find.byKey(const ValueKey('life-career-steps'));
      expect(
        find.descendant(of: card, matching: find.text('Overdue')),
        findsWidgets,
      );
    });

    testWidgets('an interview in another timezone shows both times', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session), platform: windows, width: 1200);
      expect(find.textContaining('in Sydney'), findsWidgets);
    });
  });

  group('links', () {
    testWidgets('Calendar rows, notifications and links land on their page', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      late BuildContext context;
      await app(
        tester,
        Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
        platform: windows,
        width: 1200,
      );
      final a = appId('Amihan Studio');
      final step = stepId('Amihan Studio', 'Interview');
      openLifeSource(
        context,
        session,
        AgendaItem('life:$step', a, 'Career', 'x', '2026-12-01', '10:00', 1),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LifeStepPage), findsOneWidget);
      expect(find.byType(LifeScreen), findsNothing);
      Navigator.of(tester.element(find.byType(LifeStepPage))).pop();
      await tester.pumpAndSettle();
      openLifeSource(
        context,
        session,
        AgendaItem('followUp:$a', a, 'Career', 'x', '2026-12-01', 'All day', 1),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LifeApplicationPage), findsOneWidget);
      expect(find.byType(LifeScreen), findsNothing);
    });
  });

  group('what the pages offer', () {
    Future<void> show(WidgetTester tester, Widget page) =>
        app(tester, page, platform: windows, width: 1200);

    Future<void> menu(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('an active application offers steps and an outcome', (
      tester,
    ) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await show(tester, application(s, 'Bayan Digital'));
      expect(
        find.byKey(const ValueKey('life-application-step')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('life-application-stage')),
        findsOneWidget,
      );
      await menu(tester, 'life-application-more');
      for (final key in const ['edit', 'outcome', 'followed', 'archive']) {
        expect(
          find.byKey(ValueKey('life-application-$key')),
          findsOneWidget,
          reason: key,
        );
      }
      expect(
        find.byKey(const ValueKey('life-application-reopen')),
        findsNothing,
      );
    });

    testWidgets('a closed application reopens, and takes no steps', (
      tester,
    ) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await show(tester, application(s, 'Hangin Tech'));
      expect(find.byKey(const ValueKey('life-application-step')), findsNothing);
      expect(
        find.byKey(const ValueKey('life-application-stage')),
        findsNothing,
      );
      await menu(tester, 'life-application-more');
      expect(
        find.byKey(const ValueKey('life-application-reopen')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('life-application-outcome')),
        findsNothing,
      );
    });

    testWidgets('an archived application only restores', (tester) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await show(tester, application(s, 'Ilog Partners'));
      expect(find.byKey(const ValueKey('life-application-step')), findsNothing);
      await menu(tester, 'life-application-more');
      expect(
        find.byKey(const ValueKey('life-application-restore')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('life-application-edit')), findsNothing);
      expect(
        find.byKey(const ValueKey('life-application-archive')),
        findsNothing,
      );
    });

    testWidgets('a saved application doesn’t say Applied', (tester) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await show(tester, application(s, 'North & Co.'));
      expect(find.textContaining('Applied'), findsNothing);
      expect(find.text('Not sent'), findsOneWidget);
    });

    testWidgets('archiving says what stays', (tester) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await show(tester, application(s, 'Bayan Digital'));
      await menu(tester, 'life-application-more');
      await tester.tap(find.byKey(const ValueKey('life-application-archive')));
      await tester.pumpAndSettle();
      expect(find.text('Archive this application?'), findsOneWidget);
      expect(find.textContaining('documents and history stay'), findsOneWidget);
    });

    testWidgets('a follow-up date has its reminder card', (tester) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await show(tester, application(s, 'Bayan Digital'));
      final card = find.byKey(const ValueKey('life-application-reminder'));
      expect(
        find.descendant(
          of: card,
          matching: find.byKey(const ValueKey('life-change-reminder')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a scheduled step can be done or cancelled', (tester) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await show(tester, stepPage(s, stepId('Kapwa Health', 'Interview')));
      await menu(tester, 'life-step-more');
      expect(find.byKey(const ValueKey('life-step-done')), findsOneWidget);
      expect(find.byKey(const ValueKey('life-step-cancel')), findsOneWidget);
      expect(find.byKey(const ValueKey('life-step-reopen')), findsNothing);
    });

    testWidgets('a step recording what happened offers no reopening', (
      tester,
    ) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await show(tester, stepPage(s, stepId('Amihan Studio', 'Response')));
      expect(find.byKey(const ValueKey('life-step-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('life-step-more')), findsNothing);
    });

    testWidgets('a step on a closed application is read-only and says why', (
      tester,
    ) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await show(tester, stepPage(s, stepId('Hangin Tech', 'No response')));
      expect(find.byKey(const ValueKey('life-step-edit')), findsNothing);
      expect(find.byKey(const ValueKey('life-step-more')), findsNothing);
      expect(find.textContaining('so its steps can’t change'), findsOneWidget);
    });

    testWidgets('a cancelled step reads cancelled and can be restored', (
      tester,
    ) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      final id = find_((r) => r is CareerEventRecord && r.status == 'Cancelled')
          .id;
      await show(tester, stepPage(s, id));
      expect(find.text('Cancelled'), findsWidgets);
      expect(find.text('Done'), findsNothing);
      await menu(tester, 'life-step-more');
      expect(find.byKey(const ValueKey('life-step-restore')), findsOneWidget);
    });

    testWidgets('a removed record says so', (tester) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await show(tester, stepPage(s, 'gone'));
      expect(find.text('This step is no longer here'), findsOneWidget);
    });
  });

  group('Hide amounts', () {
    testWidgets('salary reads Amount hidden on the page', (tester) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await app(
        tester,
        application(s, 'Amihan Studio'),
        platform: windows,
        width: 1200,
      );
      expect(find.text('₱60,000.00 to ₱80,000.00 a month'), findsOneWidget);
      s.togglePrivacy();
      await tester.pump();
      expect(find.textContaining('60,000'), findsNothing);
      expect(find.text('Amount hidden'), findsOneWidget);
    });

    testWidgets('Edit locks it and keeps it in the command', (tester) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      final writer = await writerOf(tester, s);
      await app(
        tester,
        LifeApplicationForm(
          writer: writer,
          id: appId('Amihan Studio'),
          hidden: true,
        ),
        platform: windows,
        width: 1200,
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('More details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('life-field-salaryMin')), findsNothing);
      expect(find.textContaining('60000'), findsNothing);
      expect(find.textContaining('Amount hidden'), findsOneWidget);
    });

    testWidgets('a shared list has no salary, contact, notes or links', (
      tester,
    ) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await app(
        tester,
        LifeApplicationsListPage(
          listenable: s,
          source: (context) => lifeSource(context, s),
        ),
        platform: windows,
        width: 1200,
      );
      expect(find.text('Amihan Studio'), findsOneWidget);
      for (final text in const [
        '60,000',
        'USD',
        'Tala Reyes',
        'case study',
        'example.com',
        'Resume',
      ]) {
        expect(find.textContaining(text), findsNothing, reason: text);
      }
    });
  });
}
