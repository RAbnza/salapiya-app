import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_cards.dart' show civilLabel;
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/life/application/life_controller.dart'
    show AgendaItem;
import 'package:salapiya/features/life/presentation/life_screen.dart';
import 'package:salapiya/life/life_data.dart';
import 'package:salapiya/life/life_demo.dart';
import 'package:salapiya/life/life_domain.dart';
import 'package:salapiya/life/life_hub.dart';
import 'package:salapiya/life/progress_forms.dart';
import 'package:salapiya/life/progress_pages.dart';
import 'package:salapiya/life/progress_tab.dart';
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

  Widget life(PrototypeSession session, String tab) => Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(Space.lg),
      child: LifeScreen(key: UniqueKey(), session: session, initial: tab),
    ),
  );

  void clean(WidgetTester tester, String label) {
    final error = tester.takeException();
    expect(error, isNull, reason: '$label: $error');
  }

  String idOf(String title) => demoLife(
    civilToday(),
  ).records.values.firstWhere((r) => r.title == title).id;

  group('sweep', () {
    for (final (tab, tiles) in const [('Learning', 4), ('Books', 3)]) {
      testWidgets('$tab at every size, text size and theme', (tester) async {
        final session = PrototypeSession();
        addTearDown(session.dispose);
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            for (final brightness in Brightness.values) {
              await app(
                tester,
                life(session, tab),
                platform: platform,
                width: width,
                text: text,
                brightness: brightness,
              );
              expect(find.byType(KpiTile), findsNWidgets(tiles));
              clean(tester, '$tab $platform $width $text $brightness');
            }
          }
        }
      });
    }

    testWidgets('hidden, incomplete and empty on both platforms', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final tab in const ['Learning', 'Books']) {
        for (final (platform, width) in sizes) {
          session.togglePrivacy();
          await app(tester, life(session, tab), platform: platform, width: width);
          expect(find.textContaining('₱'), findsNothing);
          clean(tester, 'hidden $tab $platform $width');
          session.togglePrivacy();

          session.select(OverviewScenario.empty);
          await app(tester, life(session, tab), platform: platform, width: width);
          expect(
            find.text(tab == 'Books' ? 'No books yet' : 'No learning goals yet'),
            findsOneWidget,
          );
          clean(tester, 'empty $tab $platform $width');
          session.select(OverviewScenario.local);
        }
      }
    });

    testWidgets('an unfinished Life download reads Not available yet', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, const SizedBox(), platform: windows, width: 1200);
      final hub = lifeHubOf(session);
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
            child: LifeProgressTab(
              type: LifeType.learning,
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
              hub: hub,
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

    testWidgets('an item’s page at every size, text size and theme', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final title in const [
        'Thoughtful interfaces with Flutter', // Edited, with a due date.
        'Everyday Spanish', // Overdue.
        'Public speaking', // No total.
        'Watercolor basics', // On hold.
        'First aid refresher', // Finished, no total.
        'Old typing course', // Archived.
        'Middlemarch', // A long book on hold.
        'Dekada ’70', // Finished, rated.
      ]) {
        final id = idOf(title);
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            for (final brightness in Brightness.values) {
              await app(
                tester,
                LifeEntryPage(
                  listenable: session,
                  source: (context) => lifeSource(context, session),
                  id: id,
                ),
                platform: platform,
                width: width,
                text: text,
                brightness: brightness,
              );
              await tester.pump();
              clean(tester, '$title $platform $width $text $brightness');
            }
          }
        }
      }
    });

    testWidgets('the shareable lists at every size and text size', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final type in const [LifeType.learning, LifeType.book]) {
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            await app(
              tester,
              LifeProgressListPage(
                listenable: session,
                source: (context) => lifeSource(context, session),
                type: type,
              ),
              platform: platform,
              width: width,
              text: text,
            );
            clean(tester, '$type $platform $width $text');
          }
        }
      }
    });

    testWidgets('the forms at every size and text size', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      late LifeWriter writer;
      await app(
        tester,
        Builder(
          builder: (c) {
            writer = lifeSource(c, session).writer;
            return const SizedBox();
          },
        ),
        platform: windows,
        width: 1200,
      );
      for (final form in <Widget>[
        LifeEntryForm(writer: writer, type: LifeType.learning),
        LifeEntryForm(writer: writer, type: LifeType.book),
        LifeEntryForm(
          writer: writer,
          type: LifeType.book,
          id: idOf('Dekada ’70'),
        ),
        LifeProgressForm(
          writer: writer,
          id: idOf('The Art of Noticing'),
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

  group('what the tabs say', () {
    testWidgets('the header counts what the tab counts', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final today = civilToday();
      final records = demoLife(today).records;
      final learning = ProgressCounts(
        progressRows(records, LifeType.learning, today),
      );
      final books = ProgressCounts(progressRows(records, LifeType.book, today));
      await app(tester, life(session, 'Learning'), platform: windows, width: 1200);
      expect(
        find.textContaining('${learning.inProgress.length} in progress'),
        findsOneWidget,
      );
      await app(tester, life(session, 'Books'), platform: windows, width: 1200);
      expect(
        find.textContaining('${books.inProgress.length} reading'),
        findsOneWidget,
      );
      await app(tester, life(session, 'Learning'), platform: android, width: 412);
      expect(find.text('${learning.overdue} overdue'), findsOneWidget);
    });

    testWidgets('Android has no action chips: the + sheet has them', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session, 'Books'), platform: android, width: 412);
      expect(find.text('Add a book'), findsNothing);
      await app(tester, life(session, 'Books'), platform: windows, width: 1200);
      expect(find.text('Add a book'), findsOneWidget);
    });

    testWidgets('the selected tab comes into view on a phone', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session, 'Books'), platform: android, width: 360);
      await tester.pump();
      final tab = tester.getRect(find.byKey(const ValueKey('Books')));
      expect(tab.left, greaterThanOrEqualTo(0));
      expect(tab.right, lessThanOrEqualTo(360));
    });

    testWidgets('a long book never draws as finished', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session, 'Books'), platform: windows, width: 1200);
      final bars = tester.widgetList<SegmentBar>(find.byType(SegmentBar));
      expect(bars, isNotEmpty);
      for (final bar in bars) {
        expect(bar.done, lessThan(bar.total));
      }
    });

    testWidgets('an item with no total shows no bar', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session, 'Learning'), platform: windows, width: 1200);
      final tile = find.ancestor(
        of: find.text('Public speaking').first,
        matching: find.byType(ProgressTile),
      );
      expect(tile, findsOneWidget);
      expect(
        find.descendant(of: tile, matching: find.byType(SegmentBar)),
        findsNothing,
      );
      expect(
        find.descendant(of: tile, matching: find.text('No total')),
        findsOneWidget,
      );
    });

    testWidgets('tiles in a set line their values up', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final tab in const ['Learning', 'Books']) {
        await app(tester, life(session, tab), platform: windows, width: 1200);
        final tops = find.byType(KpiTile).evaluate().map(
          (e) => tester.getTopLeft(find.byWidget(e.widget)).dy,
        );
        expect(tops.toSet(), hasLength(1), reason: tab);
      }
    });

    testWidgets('a list starts at the top and closes with ListEnd', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session, 'Books'), platform: windows, width: 1200);
      final card = find.byKey(const ValueKey('life-progress-now'));
      expect(
        find.descendant(of: card, matching: find.byType(ListEnd)),
        findsOneWidget,
      );
      final top = tester.getTopLeft(card).dy;
      final first = tester.getTopLeft(
        find
            .descendant(of: card, matching: find.text('The Art of Noticing'))
            .first,
      );
      expect(first.dy - top, lessThan(Space.xxxl * 2));
    });

    testWidgets('a row’s bar lines up with its text and its link', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (platform, width) in const [(windows, 1200.0), (android, 360.0)]) {
        await app(tester, life(session, 'Books'), platform: platform, width: width);
        final card = find.byKey(const ValueKey('life-progress-now'));
        final title = find
            .descendant(of: card, matching: find.text('The Art of Noticing'))
            .first;
        final bar = find
            .descendant(of: card, matching: find.byType(SegmentBar))
            .first;
        final link = find
            .descendant(of: card, matching: find.text('Log progress'))
            .first;
        expect(
          tester.getTopLeft(bar).dx,
          tester.getTopLeft(title).dx,
          reason: '$platform',
        );
        expect(
          tester.getTopRight(link).dx,
          tester.getTopRight(bar).dx,
          reason: '$platform',
        );
      }
    });

    testWidgets('one row of text holds the link on a phone', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session, 'Books'), platform: android, width: 360);
      final card = find.byKey(const ValueKey('life-progress-now'));
      final line = find
          .descendant(of: card, matching: find.textContaining('96 of 256'))
          .first;
      final link = find
          .descendant(of: card, matching: find.text('Log progress'))
          .first;
      expect(tester.getCenter(line).dy, tester.getCenter(link).dy);
    });

    testWidgets('an item with no total is one tap from finished', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(tester, life(session, 'Learning'), platform: windows, width: 1200);
      final id = idOf('Public speaking');
      await tester.tap(find.byKey(ValueKey('life-finish-$id')));
      await tester.pump();
      expect(find.text('This is the demo, so nothing was saved.'), findsOneWidget);
      clean(tester, 'finish');
    });

    testWidgets('Due stays a due date under every filter but Finished', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      lifeHubOf(session).setProgressFilter(LifeType.book, ProgressFilter.all);
      await app(tester, life(session, 'Books'), platform: windows, width: 1440);
      final list = find.byKey(const ValueKey('life-progress-list-book'));
      expect(find.descendant(of: list, matching: find.text('Due')), findsOneWidget);
      final finished = progressRows(
        demoLife(civilToday()).records,
        LifeType.book,
        civilToday(),
      ).firstWhere((r) => r.title == 'Dekada ’70').finishedOn!;
      expect(
        find.descendant(of: list, matching: find.text(civilLabel(finished))),
        findsNothing,
      );
    });

    testWidgets('Calendar rows, notifications and links open the item’s page', (
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
      final id = idOf('The Art of Noticing');
      for (final kind in const ['Learning', 'Books']) {
        openLifeSource(
          context,
          session,
          AgendaItem('life:$id', id, kind, 'Item', '2026-12-01', 'All day', 1),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LifeEntryPage), findsOneWidget, reason: kind);
        expect(find.byType(LifeScreen), findsNothing, reason: kind);
        Navigator.of(tester.element(find.byType(LifeEntryPage))).pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('filters show a tab’s own rows', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = lifeHubOf(session);
      hub.setProgressFilter(LifeType.book, ProgressFilter.finished);
      await app(tester, life(session, 'Books'), platform: windows, width: 1440);
      final list = find.byKey(const ValueKey('life-progress-list-book'));
      expect(
        find.descendant(of: list, matching: find.text('Dekada ’70')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: list, matching: find.text('Piranesi')),
        findsNothing,
      );
      expect(
        find.descendant(of: list, matching: find.text('4.5 of 5')),
        findsOneWidget,
      );
      hub.setProgressQuery(LifeType.book, 'nothing like this');
      await tester.pump();
      expect(find.text('Nothing matches that'), findsOneWidget);
    });
  });

  group('what the page offers', () {
    Future<void> page(WidgetTester tester, PrototypeSession s, String title) =>
        app(
          tester,
          LifeEntryPage(
            listenable: s,
            source: (context) => lifeSource(context, s),
            id: idOf(title),
          ),
          platform: windows,
          width: 1200,
        );

    Future<void> menu(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('life-entry-more')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('an open item logs progress', (tester) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await page(tester, s, 'The Art of Noticing');
      expect(find.byKey(const ValueKey('life-entry-log')), findsOneWidget);
      expect(find.byKey(const ValueKey('life-entry-finish')), findsNothing);
      await menu(tester);
      expect(find.byKey(const ValueKey('life-entry-hold')), findsOneWidget);
      expect(find.byKey(const ValueKey('life-entry-restore')), findsNothing);
    });

    testWidgets('an item with no total is finished or not', (tester) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await page(tester, s, 'Public speaking');
      expect(find.byKey(const ValueKey('life-entry-finish')), findsOneWidget);
      expect(find.byKey(const ValueKey('life-entry-log')), findsNothing);
      expect(find.text('This has no total. Add one to count lessons.'), findsOneWidget);
    });

    testWidgets('an archived item only restores', (tester) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await page(tester, s, 'Old typing course');
      expect(find.byKey(const ValueKey('life-entry-log')), findsNothing);
      await menu(tester);
      expect(find.byKey(const ValueKey('life-entry-restore')), findsOneWidget);
      expect(find.byKey(const ValueKey('life-entry-edit')), findsNothing);
      expect(find.byKey(const ValueKey('life-entry-archive')), findsNothing);
    });

    testWidgets('archiving says what stays', (tester) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await page(tester, s, 'The Art of Noticing');
      await menu(tester);
      await tester.tap(find.byKey(const ValueKey('life-entry-archive')));
      await tester.pumpAndSettle();
      expect(find.text('Archive this book?'), findsOneWidget);
      expect(
        find.textContaining('Its progress and history stay'),
        findsOneWidget,
      );
    });

    testWidgets('a finished item shows its date; a reopened one wouldn’t', (
      tester,
    ) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await page(tester, s, 'Dekada ’70');
      expect(find.text('Date finished'), findsOneWidget);
      expect(find.text('4.5 of 5'), findsOneWidget);
    });

    testWidgets('no due date says how to get a reminder', (tester) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await page(tester, s, 'Public speaking');
      expect(find.text('Add a due date to get a reminder.'), findsOneWidget);
    });

    testWidgets('a removed record says so', (tester) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await app(
        tester,
        LifeEntryPage(
          listenable: s,
          source: (context) => lifeSource(context, s),
          id: 'gone',
        ),
        platform: windows,
        width: 1200,
      );
      expect(find.text('This item is no longer here'), findsOneWidget);
    });

    testWidgets('a shared list leaves out notes and ratings', (tester) async {
      final s = PrototypeSession();
      addTearDown(s.dispose);
      await app(
        tester,
        LifeProgressListPage(
          listenable: s,
          source: (context) => lifeSource(context, s),
          type: LifeType.book,
        ),
        platform: windows,
        width: 1200,
      );
      expect(find.text('Reading list'), findsWidgets);
      expect(find.textContaining('As of'), findsOneWidget);
      expect(find.text('Piranesi'), findsOneWidget);
      expect(find.text('Dekada ’70'), findsNothing);
      expect(find.textContaining('of 5'), findsNothing);
    });
  });
}
