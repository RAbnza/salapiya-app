import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_data.dart';
import 'package:salapiya/app/overview_demo.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/finance/presentation/money_screen.dart';
import 'package:salapiya/finance/money_cards.dart';
import 'package:salapiya/finance/money_data.dart';
import 'package:salapiya/finance/money_demo.dart';
import 'package:salapiya/finance/money_details.dart';
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

const ownTabs = ['Accounts', 'Activity'];

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

  Future<void> show(
    WidgetTester tester,
    PrototypeSession session, {
    required TargetPlatform platform,
    required double width,
    double text = 1,
    Brightness brightness = Brightness.light,
    double height = 3600,
    String tab = 'Accounts',
  }) => app(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.lg),
        child: MoneyScreen(
          key: UniqueKey(),
          session: session,
          initial: tab,
          actions: [
            for (final label in const [
              'Log expense',
              'Log income',
              'Log a transfer',
            ])
              (label: label, icon: Icons.add, onSelected: () {}),
          ],
        ),
      ),
    ),
    platform: platform,
    width: width,
    text: text,
    brightness: brightness,
    height: height,
  );

  Future<void> everyTab(WidgetTester tester, String label) async {
    for (final tab in ownTabs) {
      await tester.ensureVisible(find.byKey(ValueKey(tab)));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey(tab)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final error = tester.takeException();
      expect(error, isNull, reason: '$label $tab: $error');
    }
  }

  LocalSnapshot sample() => demoSample(civilToday());

  LocalRevision record(String title) =>
      sample().revisions.lastWhere((r) => r.title.startsWith(title));

  group('sweep', () {
    testWidgets('Accounts and Activity at every size, text size and theme', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (platform, width) in sizes) {
        for (final text in [1.0, 2.0]) {
          for (final brightness in Brightness.values) {
            await show(
              tester,
              session,
              platform: platform,
              width: width,
              text: text,
              brightness: brightness,
            );
            expect(find.byType(KpiTile), findsNWidgets(4));
            await everyTab(tester, '$platform $width $text $brightness');
          }
        }
      }
    });

    testWidgets('the Activity list layout at every size', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (platform, width) in sizes) {
        for (final text in [1.0, 2.0]) {
          await show(
            tester,
            session,
            platform: platform,
            width: width,
            text: text,
            tab: 'Activity',
          );
          await tester.tap(find.byTooltip('Layout: By day'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.byKey(const ValueKey('activity-layout-list')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(StatementList), findsOneWidget);
          final error = tester.takeException();
          expect(error, isNull, reason: '$platform $width $text: $error');
        }
      }
    });

    testWidgets('account details at every size, text size and theme', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final s = sample();
      for (final a in s.accounts) {
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            for (final brightness in Brightness.values) {
              await app(
                tester,
                AccountDetailView(
                  key: UniqueKey(),
                  listenable: session,
                  source: (context) => demoMoneySource(context, session),
                  accountId: a.id,
                ),
                platform: platform,
                width: width,
                text: text,
                brightness: brightness,
              );
              final error = tester.takeException();
              expect(
                error,
                isNull,
                reason: '${a.name} $platform $width $text $brightness: $error',
              );
            }
          }
        }
      }
    });

    testWidgets('transaction details at every size and text size', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final title in const [
        'Work shoes',
        'Taxi home',
        'Reversal · Coffee beans',
        'Move to savings',
        'Balance adjustment',
        'Reconciliation',
        'Household run',
        'Salary',
        'Scooter loan payoff',
      ]) {
        final id = record(title).id;
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            await app(
              tester,
              RecordDetailView(
                key: UniqueKey(),
                listenable: session,
                source: (context) => demoMoneySource(context, session),
                id: id,
              ),
              platform: platform,
              width: width,
              text: text,
            );
            final error = tester.takeException();
            expect(error, isNull, reason: '$title $platform $width: $error');
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
        await show(tester, session, platform: platform, width: width);
        expect(find.byType(Sparkline), findsNothing);
        expect(find.byType(ChangeLine), findsNothing);
        expect(find.byType(SlimBar), findsNothing);
        expect(find.text('Amount hidden'), findsWidgets);
        expect(find.textContaining('₱'), findsNothing);
        expect(find.textContaining('+Amount'), findsNothing);
        await everyTab(tester, 'hidden $platform $width');
        expect(find.textContaining('₱'), findsNothing);
        session.togglePrivacy();

        session.select(OverviewScenario.incomplete);
        await show(tester, session, platform: platform, width: width);
        expect(find.text('Your first download isn’t finished'), findsOneWidget);
        expect(find.text('Not available yet'), findsWidgets);
        expect(find.textContaining('₱'), findsNothing);
        await everyTab(tester, 'incomplete $platform $width');

        session.select(OverviewScenario.empty);
        await show(tester, session, platform: platform, width: width);
        expect(find.text('No accounts yet'), findsOneWidget);
        await everyTab(tester, 'empty $platform $width');
        session.select(OverviewScenario.local);
      }
    });
  });

  group('Accounts', () {
    testWidgets('the five-second answers are on the first screen', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, platform: windows, width: 1440, height: 900);
      expect(find.text('Available money'), findsWidgets);
      expect(find.text('₱29,300.75'), findsWidgets);
      expect(find.text('Where your money is'), findsOneWidget);
      expect(find.text('Needs your attention'), findsOneWidget);
      final where = tester.getTopLeft(find.text('Where your money is'));
      expect(where.dy, lessThan(900));
    });

    testWidgets('Due this week matches the Overview’s figure', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, platform: windows, width: 1440);
      final today = civilToday();
      final week = OverviewDues.from(
        overviewDueSources(sample(), today),
        today,
        DuePeriod.week,
      );
      // The demo has something overdue, which the tile leaves to its caption.
      expect(week.overdue, isNotEmpty);
      final tile = find.byKey(const ValueKey('money-due'));
      expect(
        tester
            .widget<MoneyAmount>(
              find.descendant(of: tile, matching: find.byType(MoneyAmount)),
            )
            .text,
        session.amount(week.upcomingTotal),
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.text(
            '${week.upcoming.length} due · ${week.overdue.length} overdue',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the table adds up to the tile', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, platform: windows, width: 1440);
      final total = find.descendant(
        of: find.byKey(const ValueKey('accounts-total')),
        matching: find.text('₱29,300.75'),
      );
      expect(total, findsOneWidget);
      final rows = accountRows(sample(), civilToday());
      expect(
        sumMinor(rows.map((r) => r.balance)),
        availableMoney(sample(), civilToday()),
      );
    });

    testWidgets('archived accounts are a view of their own', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, platform: windows, width: 1440);
      expect(find.text('Old savings'), findsNothing);
      await tester.tap(find.text('Archived'));
      await tester.pump();
      expect(find.text('Old savings'), findsOneWidget);
      expect(find.byKey(const ValueKey('accounts-total')), findsNothing);
    });

    testWidgets('the attention card sits beside the table and lists first '
        'on phones', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, platform: windows, width: 1440);
      final table = tester.getRect(
        find.byKey(const ValueKey('money-accounts')),
      );
      final side = tester.getRect(
        find.byKey(const ValueKey('money-attention')),
      );
      expect(side.top, table.top);
      expect(side.bottom, table.bottom);
      await show(tester, session, platform: android, width: 360);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('money-attention'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('money-accounts'))).dy,
        ),
      );
    });

    testWidgets('a card header\'s link and menu center on each other', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      // Phones put the link under the title, where it has the room.
      for (final width in const [1440.0, 1200.0, 720.0]) {
        await show(tester, session, platform: windows, width: width);
        expect(
          tester.getCenter(find.byKey(const ValueKey('money-add-account'))).dy,
          tester
              .getCenter(find.byKey(const ValueKey('money-accounts-menu')))
              .dy,
          reason: '$width',
        );
      }
    });

    testWidgets('account icons follow the account, not its place', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, platform: windows, width: 1440);
      final bank = find.byKey(
        ValueKey('row-account-${sample().accounts[1].id}'),
      );
      expect(
        find.descendant(
          of: bank,
          matching: find.byIcon(Icons.account_balance_outlined),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tiles in a set keep their values level', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (platform, width) in sizes.skip(3)) {
        await show(tester, session, platform: platform, width: width);
        final tops = [
          for (final key in const ['money-available', 'money-in'])
            tester
                .getTopLeft(
                  find.descendant(
                    of: find.byKey(ValueKey(key)),
                    matching: find.byType(MoneyAmount),
                  ),
                )
                .dy,
        ];
        expect(tops.first, tops.last, reason: '$width');
      }
    });

    testWidgets('table columns line up on every row', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, platform: windows, width: 1440);
      final amounts = find.descendant(
        of: find.byKey(const ValueKey('accounts-table')),
        matching: find.byType(MoneyAmount),
      );
      final ends = {
        for (final element in amounts.evaluate())
          tester.getTopRight(find.byElementPredicate((e) => e == element)).dx,
      };
      expect(
        ends.length,
        2,
        reason: 'This month and Balance end at one x each',
      );
    });
  });

  group('Activity', () {
    testWidgets('records are grouped by day, with Later first', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        platform: windows,
        width: 1440,
        tab: 'Activity',
      );
      await tester.tap(find.byKey(const ValueKey('activity-period')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('period-all')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final later = find.textContaining('not in your balance yet');
      final today = find.textContaining('Today · ');
      expect(later, findsOneWidget);
      expect(
        tester.getTopLeft(later).dy,
        lessThan(tester.getTopLeft(today).dy),
      );
    });

    testWidgets('search finds an old record whatever the period', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        platform: windows,
        width: 1440,
        tab: 'Activity',
      );
      const old = 'Freelance design project';
      expect(find.text(old), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('money-search')),
        'freelance',
      );
      await tester.pump();
      expect(find.text(old), findsWidgets);
      expect(find.text('All dates'), findsOneWidget);
      expect(find.text('Search results'), findsOneWidget);
    });

    testWidgets('nothing matching offers a way back', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        platform: windows,
        width: 1440,
        tab: 'Activity',
      );
      await tester.enterText(
        find.byKey(const ValueKey('money-search')),
        'zzzz',
      );
      await tester.pump();
      expect(find.text('Nothing matches'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(find.text('Nothing matches'), findsNothing);
    });

    testWidgets('corrected and reversed records carry their pills', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        platform: windows,
        width: 1440,
        tab: 'Activity',
      );
      await tester.tap(find.byKey(const ValueKey('activity-period')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('period-all')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        find.byKey(const ValueKey('money-search')),
        'taxi',
      );
      await tester.pump();
      expect(find.text('Corrected'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('money-search')),
        'coffee beans',
      );
      await tester.pump();
      expect(find.text('Reversed'), findsOneWidget);
    });

    testWidgets('amount columns are one width across day groups', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        platform: windows,
        width: 1440,
        tab: 'Activity',
      );
      final amounts = find.descendant(
        of: find.byKey(const ValueKey('activity-table')),
        matching: find.byType(MoneyAmount),
      );
      final ends = {
        for (final element in amounts.evaluate())
          tester.getTopRight(find.byElementPredicate((e) => e == element)).dx,
      };
      expect(ends.length, 1);
    });

    testWidgets('each day has room above it and stays with its rows', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final today = civilToday();
      final last = moneyActivity(
        sample(),
        (id) => id ?? '',
      ).lastWhere((r) => r.date == today);
      for (final (platform, width) in const [
        (windows, 1440.0),
        (android, 360.0),
      ]) {
        await show(
          tester,
          session,
          platform: platform,
          width: width,
          tab: 'Activity',
        );
        // This month has no yesterday on the 1st.
        await tester.tap(find.byKey(const ValueKey('activity-period')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Last 90 days').last);
        await tester.pumpAndSettle();
        final next = find.textContaining('Yesterday · ');
        final above = tester.getBottomLeft(
          find.byKey(ValueKey('row-${last.id}')),
        );
        final day = tester.getRect(next);
        expect(day.top - above.dy, Space.groupGap, reason: '$platform');
        // The date sits close to its own rows, with no hairline around it.
        for (final divider in find.byType(Divider).evaluate()) {
          final y = tester
              .getTopLeft(find.byElementPredicate((e) => e == divider))
              .dy;
          expect(
            y >= above.dy && y <= day.bottom + Space.xs,
            isFalse,
            reason: '$platform: a hairline at the day header',
          );
        }
      }
    });

    testWidgets('long lists grow by a page', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        platform: windows,
        width: 1440,
        height: 9000,
        tab: 'Activity',
      );
      await tester.tap(find.byKey(const ValueKey('activity-period')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('period-all')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Show more ·'), findsOneWidget);
      await tester.tap(find.textContaining('Show more ·'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('details', () {
    testWidgets('an ordinary record offers Correct at the top', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final id = record('Taxi home').id;
      await app(
        tester,
        RecordDetailView(
          listenable: session,
          source: (context) => demoMoneySource(context, session),
          id: id,
        ),
        platform: windows,
        width: 1200,
      );
      expect(find.byKey(const ValueKey('record-correct')), findsOneWidget);
    });

    testWidgets('a record with a refund says what to do first', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final id = record('Work shoes').id;
      await app(
        tester,
        RecordDetailView(
          listenable: session,
          source: (context) => demoMoneySource(context, session),
          id: id,
        ),
        platform: windows,
        width: 1200,
      );
      expect(find.textContaining('Reverse that first'), findsOneWidget);
      expect(find.textContaining('Refund · Work shoes'), findsOneWidget);
    });

    testWidgets('a balance check offers to adjust the difference', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final id = record('Reconciliation').id;
      await app(
        tester,
        RecordDetailView(
          listenable: session,
          source: (context) => demoMoneySource(context, session),
          id: id,
        ),
        platform: windows,
        width: 1200,
      );
      expect(find.textContaining('Balance check · '), findsWidgets);
      expect(find.text('No money moved'), findsOneWidget);
      expect(find.text('Adjust balance to match'), findsOneWidget);
      expect(find.text('Actual balance'), findsOneWidget);
      expect(find.text('Balance in Salapiya'), findsOneWidget);
    });

    testWidgets('an account shows its own statement, closing on its balance', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final s = sample();
      final a = s.accounts.first;
      await app(
        tester,
        AccountDetailView(
          listenable: session,
          source: (context) => demoMoneySource(context, session),
          accountId: a.id,
        ),
        platform: windows,
        width: 1200,
        height: 9000,
      );
      await tester.tap(find.byTooltip('Layout: By day'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('account-layout-list')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Closing balance'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('statement-totals')),
          matching: find.text(
            session.amount(s.balance(a.id, through: civilToday())),
          ),
        ),
        findsOneWidget,
      );
    });
  });
}
