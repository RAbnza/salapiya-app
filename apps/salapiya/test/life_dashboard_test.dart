import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_dashboard.dart';
import 'package:salapiya/app/overview_data.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/life/presentation/life_screen.dart';
import 'package:salapiya/finance/debt_screen.dart' show DebtDetailView;
import 'package:salapiya/life/agenda_page.dart';
import 'package:salapiya/life/life_data.dart';
import 'package:salapiya/life/life_demo.dart';
import 'package:salapiya/life/life_domain.dart';
import 'package:salapiya/life/life_hub.dart';
import 'package:salapiya/life/life_pages_detail.dart';
import 'package:salapiya/life/life_reviews.dart';
import 'package:salapiya/life/life_settings.dart';
import 'package:salapiya/life/native_notifications.dart';
import 'package:salapiya/life/reminder_data.dart';
import 'package:salapiya/life/reminder_page.dart';
import 'package:salapiya/life/reminders_tab.dart';
import 'package:salapiya/life/tasks_tab.dart';
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
    double height = 3600,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        // No theme animation: each case renders its platform at once.
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
      child: LifeScreen(
        key: UniqueKey(),
        session: session,
        actions: [
          for (final label in const ['Add task', 'Add event'])
            (label: label, icon: Icons.add, onSelected: () {}),
        ],
      ),
    ),
  );

  void clean(WidgetTester tester, String label) {
    final error = tester.takeException();
    expect(error, isNull, reason: '$label: $error');
  }

  group('sweep', () {
    testWidgets('Calendar at every size, text size and theme', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final agenda in [false, true]) {
        lifeHubOf(session).setAgenda(agenda);
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
              clean(tester, '$agenda $platform $width $text $brightness');
            }
          }
        }
      }
    });

    testWidgets('hidden, incomplete and empty on both platforms', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (platform, width) in sizes) {
        session.togglePrivacy();
        await app(tester, life(session), platform: platform, width: width);
        expect(find.textContaining('₱'), findsNothing);
        clean(tester, 'hidden $platform $width');
        session.togglePrivacy();

        session.select(OverviewScenario.incomplete);
        await app(tester, life(session), platform: platform, width: width);
        expect(find.text('Your first download isn’t finished'), findsOneWidget);
        expect(find.text('Not available yet'), findsWidgets);
        expect(find.textContaining('₱'), findsNothing);
        clean(tester, 'incomplete $platform $width');

        session.select(OverviewScenario.empty);
        await app(tester, life(session), platform: platform, width: width);
        expect(find.text('Nothing on this day'), findsOneWidget);
        expect(find.text('Nothing in the next seven days'), findsOneWidget);
        clean(tester, 'empty $platform $width');

        session.select(OverviewScenario.local);
      }
    });

    testWidgets('an event page at every size, text size and theme', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final records = demoLife(civilToday()).records.values;
      for (final title in const [
        'Dentist appointment', // Edited, with a location and notes.
        'Call with the Tokyo office', // Another timezone.
        'Mom’s birthday', // All day.
        'Eye check', // Gone by.
        'Car service', // Cancelled.
      ]) {
        final id = records.firstWhere((r) => r.title == title).id;
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            await app(
              tester,
              LifeEventPage(
                listenable: session,
                source: (context) => lifeSource(context, session),
                id: id,
              ),
              platform: platform,
              width: width,
              text: text,
            );
            await tester.pump();
            clean(tester, '$title $platform $width $text');
          }
        }
      }
    });

    testWidgets('the shareable lists at every size and text size', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final today = civilToday();
      for (final scope in [
        const LifeListScope.week(),
        const LifeListScope.month(),
        const LifeListScope.overdue(),
        LifeListScope.day(today),
      ]) {
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            await app(
              tester,
              LifeListPage(
                listenable: session,
                source: (context) => lifeSource(context, session),
                scope: scope,
              ),
              platform: platform,
              width: width,
              text: text,
            );
            clean(tester, '${scope.title(today)} $platform $width $text');
          }
        }
      }
    });
  });

  group('Reminders', () {
    Widget reminders(PrototypeSession session) => Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.lg),
        child: LifeScreen(
          key: UniqueKey(),
          session: session,
          initial: 'Reminders',
        ),
      ),
    );
    ReminderRow rowOf(PrototypeSession session, String title) {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      late ReminderRow row;
      row = lifeHubOf(session).demoReminders.rows
          .firstWhere((r) => r.title == title);
      return row;
    }

    Widget page(PrototypeSession session, String id) => LifeReminderPage(
      listenable: Listenable.merge([session, lifeHubOf(session)]),
      source: (context) => lifeSource(context, session),
      id: id,
    );

    testWidgets('every size, text size and theme', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (platform, width) in sizes) {
        for (final text in [1.0, 2.0]) {
          for (final brightness in Brightness.values) {
            await app(
              tester,
              reminders(session),
              platform: platform,
              width: width,
              text: text,
              brightness: brightness,
            );
            await tester.pump();
            expect(find.text('Coming reminders'), findsOneWidget);
            clean(tester, '$platform $width $text $brightness');
          }
        }
      }
    });

    testWidgets('it answers what, when and how to change it', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, reminders(session), platform: windows, width: 1440);
      expect(find.textContaining('Reminders are on,'), findsOneWidget);
      expect(find.text('Dentist appointment'), findsOneWidget);
      expect(find.textContaining('Reminds you'), findsWidgets);
      // A dismissed one stays in date order, not below everything else.
      expect(find.text('Dismissed'), findsOneWidget);
      expect(find.textContaining('more'), findsWidgets);
      // Nothing raw.
      expect(find.textContaining('Z'), findsNothing);
      expect(find.textContaining('life:'), findsNothing);
      expect(find.textContaining('Inherited'), findsNothing);
      expect(find.textContaining('OS '), findsNothing);
    });

    testWidgets('the whole list is a tap away, and nothing is lost', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, reminders(session), platform: windows, width: 1440);
      await app(
        tester,
        LifeRemindersPage(session: session),
        platform: windows,
        width: 1440,
      );
      expect(find.text('Turned off'), findsOneWidget);
      expect(find.textContaining('Show more'), findsOneWidget);
    });

    testWidgets('Android: a title sits right above its card\'s content', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, reminders(session), platform: android, width: 412);
      final gap =
          tester.getTopLeft(find.textContaining('Reminders are on')).dy -
          tester.getBottomLeft(find.text('This device')).dy;
      expect(gap, Space.md);
      await tester.tap(find.byKey(const ValueKey('life-reminders-quiet-on')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing empty sits under the side cards', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, reminders(session), platform: windows, width: 1440);
      final list = tester.getBottomLeft(
        find.byKey(const ValueKey('life-reminders-coming')),
      );
      final side = tester.getBottomLeft(
        find.byKey(const ValueKey('life-reminders-show')),
      );
      expect(side.dy, list.dy);
      final gap =
          list.dy -
          tester
              .getBottomLeft(
                find.textContaining('company names, contacts and notes'),
              )
              .dy;
      expect(gap, lessThan(Space.xxxl * 3));
    });

    testWidgets('a notification shows nothing private', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, reminders(session), platform: windows, width: 1440);
      expect(find.text(reminderTitle), findsOneWidget);
      expect(find.text(reminderBody()), findsOneWidget);
      expect(
        find.textContaining('company names, contacts and notes never show'),
        findsOneWidget,
      );
    });

    testWidgets('turning off says what changes and what stays', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, reminders(session), platform: windows, width: 1440);
      await tester.tap(find.byKey(const ValueKey('life-reminders-on')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('will be cancelled'), findsOneWidget);
      expect(find.textContaining('other devices keep theirs'), findsOneWidget);
      await tester.tap(find.text('Turn off').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Reminders are off on this device'), findsOneWidget);
      expect(find.byKey(const ValueKey('life-reminders-test')), findsNothing);
      expect(find.text('In the app only'), findsWidgets);
    });

    testWidgets('stopping a type asks first, and the Calendar keeps it', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, reminders(session), platform: windows, width: 1440);
      await tester.ensureVisible(
        find.byKey(const ValueKey('life-reminders-module-Tasks')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('life-reminders-module-Tasks')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('They stay on your calendar'), findsOneWidget);
    });

    testWidgets('quiet hours keep their rule, on their field', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, reminders(session), platform: windows, width: 1440);
      final end = tester.widget<TimeField>(
        find.byKey(const ValueKey('life-field-end')),
      );
      end.onChanged!(const TimeOfDay(hour: 22, minute: 0));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Quiet hours need a different start and end.'),
        findsOneWidget,
      );
    });

    testWidgets('a settings page at every size and text size', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, reminders(session), platform: windows, width: 1440);
      for (final title in const [
        'Dentist appointment',
        'Mom’s birthday',
        'Book club',
        'Plan the trip',
        'Send the tax papers',
      ]) {
        final id = rowOf(session, title).id;
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            await app(
              tester,
              page(session, id),
              platform: platform,
              width: width,
              text: text,
            );
            clean(tester, '$title $platform $width $text');
          }
        }
      }
    });

    testWidgets('only what applies is offered', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, reminders(session), platform: windows, width: 1440);
      Future<void> open(String title) => app(
        tester,
        page(session, rowOf(session, title).id),
        platform: windows,
        width: 1440,
      );
      Finder key(String k) => find.byKey(ValueKey(k));

      // Coming: dismiss it, but it can't be snoozed before it fires.
      await open('Dentist appointment');
      expect(key('life-reminder-dismiss'), findsOneWidget);
      expect(key('life-reminder-snooze'), findsNothing);
      expect(find.text('15 minutes before'), findsOneWidget);

      // All day: no minutes.
      await open('Mom’s birthday');
      expect(find.text('15 minutes before'), findsNothing);
      expect(find.textContaining('at 9:00 AM'), findsOneWidget);

      // Fired: now it can be snoozed.
      await open('Send the tax papers');
      expect(key('life-reminder-snooze'), findsOneWidget);
      expect(find.textContaining('can’t tell whether'), findsOneWidget);

      // Dismissed: bring it back.
      await open('Book club');
      expect(key('life-reminder-restore'), findsOneWidget);
      expect(key('life-reminder-dismiss'), findsNothing);

      // Off: turn it on.
      await open('Plan the trip');
      expect(key('life-reminder-on'), findsOneWidget);
      expect(key('life-reminder-off'), findsNothing);
    });

    testWidgets('turning one off asks first', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, reminders(session), platform: windows, width: 1440);
      await app(
        tester,
        page(session, rowOf(session, 'Dentist appointment').id),
        platform: windows,
        width: 1440,
      );
      await tester.tap(find.byKey(const ValueKey('life-reminder-off')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('stays on your calendar'), findsOneWidget);
    });

    testWidgets('an event’s page says when it reminds you', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, reminders(session), platform: windows, width: 1440);
      final id = demoLife(civilToday()).records.values
          .firstWhere((r) => r.title == 'Dentist appointment')
          .id;
      await app(
        tester,
        LifeEventPage(
          listenable: session,
          source: (context) => lifeSource(context, session),
          id: id,
        ),
        platform: windows,
        width: 1440,
      );
      await tester.pump();
      expect(find.textContaining('Reminds you'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('life-change-reminder')),
        findsOneWidget,
      );
      expect(find.text('Inherited'), findsNothing);
    });

    testWidgets('preferences at every size, and they apply', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (platform, width) in sizes) {
        for (final text in [1.0, 2.0]) {
          await app(
            tester,
            LifeSettings(key: UniqueKey(), session: session),
            platform: platform,
            width: width,
            text: text,
          );
          clean(tester, '$platform $width $text');
        }
      }
      final hub = lifeHubOf(session);
      await hub.saveView({
        ...hub.view,
        'calendar': {...hub.view['calendar'] as Map, 'Debts': false},
      });
      await app(tester, life(session), platform: windows, width: 1440);
      expect(find.text('Loan from Tita Rosa'), findsNothing);
      expect(hub.tabShown('Tasks'), isTrue);
    });

    testWidgets('Reminders can’t be hidden, and Tasks can', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = lifeHubOf(session);
      await hub.saveView({
        ...hub.view,
        'tabs': {...hub.view['tabs'] as Map, 'Tasks': false},
      });
      await app(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: LifeScreen(session: session, initial: 'Tasks'),
          ),
        ),
        platform: windows,
        width: 1440,
      );
      // The hidden tab it opened on falls back to the Calendar.
      expect(find.byKey(const ValueKey('Tasks')), findsNothing);
      expect(find.byKey(const ValueKey('Reminders')), findsOneWidget);
      expect(find.text('Coming up'), findsOneWidget);
    });
  });

  group('Tasks', () {
    Widget tasks(PrototypeSession session) => Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.lg),
        child: LifeScreen(key: UniqueKey(), session: session, initial: 'Tasks'),
      ),
    );

    testWidgets('every size, text size and theme', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (platform, width) in sizes) {
        for (final text in [1.0, 2.0]) {
          for (final brightness in Brightness.values) {
            await app(
              tester,
              tasks(session),
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

    testWidgets('hidden, incomplete and empty on both platforms', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (platform, width) in sizes) {
        session.togglePrivacy();
        await app(tester, tasks(session), platform: platform, width: width);
        clean(tester, 'hidden $platform $width');
        session.togglePrivacy();

        session.select(OverviewScenario.empty);
        await app(tester, tasks(session), platform: platform, width: width);
        expect(find.text('Nothing to do'), findsWidgets);
        clean(tester, 'empty $platform $width');
        session.select(OverviewScenario.local);
      }
    });

    testWidgets('a task page at every size and text size', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final records = demoLife(civilToday()).records.values;
      for (final title in const [
        'Send the tax papers', // Late, with details.
        'Sort the receipts', // No due date.
        'Fix the shelf', // On hold.
        'Book the car service', // Completed.
        'Old errand', // Archived.
      ]) {
        final id = records.firstWhere((r) => r.title == title).id;
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            await app(
              tester,
              LifeTaskPage(
                listenable: session,
                source: (context) => lifeSource(context, session),
                hub: lifeHubOf(session),
                id: id,
              ),
              platform: platform,
              width: width,
              text: text,
            );
            await tester.pump();
            clean(tester, '$title $platform $width $text');
          }
        }
      }
    });

    testWidgets('the task list at every size and text size', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (platform, width) in sizes) {
        for (final text in [1.0, 2.0]) {
          await app(
            tester,
            LifeTaskListPage(
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

    testWidgets('Changes to check at every size and text size', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      session.select(OverviewScenario.review);
      for (final (platform, width) in sizes) {
        for (final text in [1.0, 2.0]) {
          await app(
            tester,
            LifeChecksPage(
              listenable: session,
              source: (context) => lifeSource(context, session),
            ),
            platform: platform,
            width: width,
            text: text,
          );
          expect(find.text('Dentist check-up'), findsOneWidget);
          clean(tester, '$platform $width $text');
        }
      }
      session.select(OverviewScenario.local);
    });

    testWidgets('the tiles and lists read the sample', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, tasks(session), platform: windows, width: 1440);
      for (final label in const ['To do', 'Overdue', 'Today', 'This week']) {
        expect(find.widgetWithText(KpiTile, label), findsOneWidget);
      }
      expect(find.text('Send the tax papers'), findsNWidgets(2));
      expect(find.text('Book the car service'), findsNothing);
      expect(find.text('Old errand'), findsNothing);
      expect(find.textContaining('demo snapshot'), findsNothing);
    });

    testWidgets('the header counts what the tab counts', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, tasks(session), platform: android, width: 412);
      // Calendar also counts a debt, a learning goal and a follow-up; Tasks
      // only the task.
      expect(find.text('1 overdue'), findsOneWidget);
      expect(find.text('4 overdue'), findsNothing);
      expect(find.byKey(const ValueKey('life-pill')), findsNothing);
      await app(tester, life(session), platform: android, width: 412);
      expect(find.text('4 overdue'), findsOneWidget);
    });

    testWidgets('a finished task isn’t told to add a due date', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final today = civilToday();
      final life = demoLife(today);
      final finished = LifeRecord.read(
        '00000000-0000-4000-8000-00000000f001',
        '00000000-0000-4000-8000-00000000d000',
        1,
        LifeType.task,
        {'title': 'Done, no date', 'status': 'Completed'},
      );
      await app(
        tester,
        LifeTaskPage(
          listenable: session,
          source: (context) {
            final s = lifeSource(context, session);
            return LifeSource(
              today: s.today,
              timezone: s.timezone,
              complete: true,
              hidden: false,
              amount: s.amount,
              records: {...life.records, finished.id: finished},
              snapshot: s.snapshot,
              writer: s.writer,
              actions: s.actions,
              visible: s.visible,
            );
          },
          hub: lifeHubOf(session),
          id: finished.id,
        ),
        platform: windows,
        width: 1200,
      );
      expect(
        find.text('Finished and archived tasks don’t remind you.'),
        findsOneWidget,
      );
      expect(find.text('Add a due date to get a reminder.'), findsNothing);
    });

    testWidgets('on hold shows once, and its count lines up', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, tasks(session), platform: windows, width: 1440);
      expect(find.textContaining('6\u00A0Nov\u00A0·\u00A0On'), findsNothing);
      final card = find.byKey(const ValueKey('life-tasks-priority'));
      final high = find.descendant(of: card, matching: find.text('High'));
      final hold = find.descendant(of: card, matching: find.text('On hold'));
      expect(tester.getTopLeft(high).dx, tester.getTopLeft(hold).dx);
    });

    testWidgets('the filter shows finished and archived tasks', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, tasks(session), platform: windows, width: 1440);
      final hub = lifeHubOf(session);
      addTearDown(() => hub.setTaskFilter(TaskFilter.active));
      hub.setTaskFilter(TaskFilter.completed);
      await tester.pump();
      expect(find.text('Book the car service'), findsOneWidget);
      hub.setTaskFilter(TaskFilter.archived);
      await tester.pump();
      expect(find.text('Old errand'), findsOneWidget);
    });

    testWidgets('columns line up across groups', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, tasks(session), platform: windows, width: 1440);
      final rows = find.descendant(
        of: find.byKey(const ValueKey('life-tasks-list')),
        matching: find.text('Normal'),
      );
      expect(rows.evaluate().length, greaterThan(1));
      final starts = {
        for (final e in rows.evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dx,
      };
      expect(starts, hasLength(1));
    });

    testWidgets('Android: a pill stays beside its task, not under it', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, tasks(session), platform: android, width: 412);
      final row = find
          .ancestor(
            of: find.text('Call the insurer').first,
            matching: find.byType(AdaptiveRow),
          )
          .first;
      final title = tester.getRect(
        find.descendant(of: row, matching: find.text('Call the insurer')),
      );
      final pill = tester.getRect(
        find.descendant(of: row, matching: find.byType(StatusPill)),
      );
      expect(pill.top, lessThan(title.bottom));
      expect(pill.bottom, greaterThan(title.top));
    });

    testWidgets('the first thing can be completed in one tap', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, tasks(session), platform: android, width: 360);
      expect(
        find.bySemanticsLabel('Complete task Send the tax papers'),
        findsWidgets,
      );
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.pump();
      expect(
        find.text('This is the demo, so nothing was saved.'),
        findsOneWidget,
      );
      lifeHubOf(session).setProblem(null);
    });

    testWidgets('a task page offers only what applies', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final records = demoLife(civilToday()).records.values;
      Future<void> open(String title) => app(
        tester,
        LifeTaskPage(
          key: UniqueKey(),
          listenable: session,
          source: (context) => lifeSource(context, session),
          hub: lifeHubOf(session),
          id: records.firstWhere((r) => r.title == title).id,
        ),
        platform: windows,
        width: 1440,
      );
      await open('Send the tax papers');
      expect(find.byKey(const ValueKey('life-task-complete')), findsOneWidget);
      await open('Book the car service');
      expect(find.byKey(const ValueKey('life-task-reopen')), findsOneWidget);
      await open('Old errand');
      expect(find.byKey(const ValueKey('life-task-complete')), findsNothing);
      expect(find.byKey(const ValueKey('life-task-reopen')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('life-task-more')));
      await tester.pump();
      expect(find.text('Restore task'), findsOneWidget);
      expect(find.text('Edit task'), findsNothing);
    });

    testWidgets('Archive says what stays', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final id = demoLife(civilToday()).records.values
          .firstWhere((r) => r.title == 'Call the insurer')
          .id;
      await app(
        tester,
        LifeTaskPage(
          listenable: session,
          source: (context) => lifeSource(context, session),
          hub: lifeHubOf(session),
          id: id,
        ),
        platform: windows,
        width: 1440,
      );
      await tester.tap(find.byKey(const ValueKey('life-task-more')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('life-task-archive')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Its history stays'), findsOneWidget);
    });
  });

  group('Calendar', () {
    testWidgets('the tiles answer the five-second question', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session), platform: windows, width: 1440);
      for (final label in const ['Today', 'This week', 'Overdue', 'Next up']) {
        expect(find.widgetWithText(KpiTile, label), findsOneWidget);
      }
      // A task two days late, and money the sample has overdue.
      expect(find.text('Send the tax papers'), findsWidgets);
      // A row's details stay whole, so its spaces don't break.
      expect(find.textContaining('2\u00A0days\u00A0overdue'), findsWidgets);
    });

    testWidgets('tile values line up', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (platform, width) in sizes) {
        await app(tester, life(session), platform: platform, width: width);
        final week = tester.getTopLeft(find.byKey(const ValueKey('life-week')));
        final late = tester.getTopLeft(
          find.byKey(const ValueKey('life-overdue')),
        );
        // At 320 wide they stack, so they have no line to share.
        if (week.dy != late.dy) continue;
        final tops = {
          for (final key in const ['life-week', 'life-overdue'])
            tester
                .getTopLeft(
                  find.descendant(
                    of: find.byKey(ValueKey(key)),
                    matching: find.byType(MoneyAmount),
                  ),
                )
                .dy,
        };
        expect(tops, hasLength(1), reason: '$platform $width');
      }
    });

    testWidgets('nothing empty sits beside the month', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session), platform: windows, width: 1440);
      final month = tester.getBottomLeft(
        find.byKey(const ValueKey('life-month')),
      );
      final side = tester.getBottomLeft(
        find.byKey(const ValueKey('life-overdue-card')),
      );
      expect(side.dy, month.dy);
    });

    testWidgets('Next up closes with a link to the Calendar', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: OverviewDashboard(session: session, open: (_) {}),
          ),
        ),
        platform: windows,
        width: 1440,
      );
      final card = find.byKey(const ValueKey('overview-life'));
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining('more on the Calendar'),
        ),
        findsOneWidget,
      );
      // The same sample as the Calendar, in plain words.
      expect(
        find.descendant(of: card, matching: find.text('Call the insurer')),
        findsOneWidget,
      );
    });

    testWidgets('a debt opens the debt, not its schedule record', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session), platform: windows, width: 1440);
      await tester.tap(find.text('Loan from Tita Rosa').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DebtDetailView), findsOneWidget);
    });

    testWidgets('a debt reads as a record, never as an instruction', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session), platform: windows, width: 1440);
      expect(
        find.text('Reminders of your records. Salapiya doesn’t pay anything.'),
        findsWidgets,
      );
      for (final word in const ['Pay now', 'Pay ', 'Log payment']) {
        expect(find.textContaining(word), findsNothing);
      }
      expect(find.textContaining('payment schedule'), findsNothing);
    });

    testWidgets('a day can be chosen, and the month can move', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final today = civilToday();
      final hub = lifeHubOf(session);
      await app(tester, life(session), platform: windows, width: 1440);
      final next = addCivilDays(today, 1);
      hub.select(next);
      await tester.pump();
      expect(hub.selected(today), next);
      hub.moveMonth(today, 1);
      await tester.pump();
      expect(find.byKey(ValueKey('life-day-$next')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('life-go-today')));
      await tester.pump();
      expect(hub.selected(today), today);
      expect(find.byKey(ValueKey('life-day-$today')), findsOneWidget);
    });

    testWidgets('a filter narrows the cards, not the tiles', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      lifeHubOf(session).setShow('Personal');
      addTearDown(() => lifeHubOf(session).setShow('All'));
      await app(tester, life(session), platform: windows, width: 1440);
      expect(find.text('Events only'), findsOneWidget);
      expect(find.widgetWithText(KpiTile, 'Overdue'), findsOneWidget);
      expect(find.byKey(const ValueKey('life-overdue-card')), findsNothing);
    });

    testWidgets('Agenda searches the month', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = lifeHubOf(session)..setAgenda(true);
      await app(tester, life(session), platform: windows, width: 1440);
      await tester.enterText(
        find.byKey(const ValueKey('life-search')),
        'no such thing anywhere',
      );
      await tester.pump();
      expect(find.text('Nothing matches that'), findsOneWidget);
      hub.setQuery('');
    });

    testWidgets('lists close, and money columns share a width', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(
        tester,
        LifeListPage(
          listenable: session,
          source: (context) => lifeSource(context, session),
          scope: const LifeListScope.overdue(),
        ),
        platform: windows,
        width: 1440,
      );
      // Past their date, with no period to choose and no events to count.
      expect(find.text('Past their date'), findsOneWidget);
      expect(find.text('This month'), findsNothing);
      expect(find.text('Events'), findsNothing);
      final amounts = tester
          .widgetList<MoneyAmount>(find.byType(MoneyAmount))
          .length;
      expect(amounts, greaterThan(1));
      final ends = {
        for (final e in find.byType(MoneyAmount).evaluate())
          tester.getTopRight(find.byWidget(e.widget)).dx,
      };
      expect(ends, hasLength(1));
    });
  });

  group('event page', () {
    Future<String> open(
      WidgetTester tester,
      PrototypeSession session,
      String title,
    ) async {
      final id = demoLife(civilToday()).records.values
          .firstWhere((r) => r.title == title)
          .id;
      await app(
        tester,
        LifeEventPage(
          listenable: session,
          source: (context) => lifeSource(context, session),
          id: id,
        ),
        platform: windows,
        width: 1440,
      );
      await tester.pump();
      return id;
    }

    Future<List<String>> offered(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('life-event-more')));
      await tester.pump();
      return [
        for (final e in find.byType(MenuItemButton).evaluate())
          ((e.widget as MenuItemButton).child as Text).data!,
      ];
    }

    testWidgets('a coming event offers done, cancel and archive', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await open(tester, session, 'Dentist appointment');
      expect(await offered(tester), [
        'Mark as done',
        'Cancel event',
        'Archive event',
      ]);
    });

    testWidgets('a cancelled event offers only restore and archive', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await open(tester, session, 'Car service');
      expect(await offered(tester), ['Restore event', 'Archive event']);
      expect(find.text('Cancelled'), findsWidgets);
    });

    testWidgets('an archived event offers restore, and no edit', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await open(tester, session, 'Old reunion');
      expect(find.byKey(const ValueKey('life-event-edit')), findsNothing);
      expect(await offered(tester), ['Restore event']);
    });

    testWidgets('another timezone shows both times', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await open(tester, session, 'Call with the Tokyo office');
      expect(find.textContaining('in Tokyo'), findsOneWidget);
      expect(find.textContaining('Manila'), findsOneWidget);
    });

    testWidgets('an all-day event says so, with no timezone', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await open(tester, session, 'Mom’s birthday');
      expect(find.text('All day'), findsOneWidget);
      expect(find.textContaining('Manila'), findsNothing);
    });

    testWidgets('its history says what changed and why, in plain words', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await open(tester, session, 'Dentist appointment');
      await tester.pump();
      expect(find.text('The clinic moved it back'), findsOneWidget);
      expect(find.textContaining('Time:'), findsOneWidget);
      expect(find.textContaining('utc'), findsNothing);
    });

    testWidgets('Cancel event asks why and says what stays', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await open(tester, session, 'Dentist appointment');
      await offered(tester);
      await tester.tap(find.byKey(const ValueKey('life-event-cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Its history stays'), findsOneWidget);
      await tester.tap(find.text('Cancel event').last);
      await tester.pump();
      expect(find.text('Say why you’re cancelling.'), findsOneWidget);
    });

    testWidgets('a record that is gone says so', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(
        tester,
        LifeEventPage(
          listenable: session,
          source: (context) => lifeSource(context, session),
          id: '00000000-0000-4000-8000-00000000ffff',
        ),
        platform: android,
        width: 360,
      );
      expect(find.text('This event is no longer here'), findsOneWidget);
    });
  });

  test('every list on Calendar is a known card', () {
    expect(lifeModuleName('Personal'), 'Events');
    expect(lifeModuleName('Recurring'), 'Recurring bills');
    expect(zoneName('America/Los_Angeles'), 'Los Angeles');
  });
}
