import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_cards.dart';
import 'package:salapiya/app/overview_data.dart';
import 'package:salapiya/app/overview_demo.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/finance/presentation/money_screen.dart';
import 'package:salapiya/finance/card_cards.dart';
import 'package:salapiya/finance/card_data.dart';
import 'package:salapiya/finance/card_pages.dart';
import 'package:salapiya/finance/file_pages.dart';
import 'package:salapiya/finance/files_data.dart';
import 'package:salapiya/finance/import_data.dart';
import 'package:salapiya/finance/import_review.dart';
import 'package:salapiya/finance/forecast_page.dart';
import 'package:salapiya/finance/money_demo.dart';
import 'package:salapiya/finance/planning_cards.dart';
import 'package:salapiya/finance/planning_data.dart';
import 'package:salapiya/finance/planning_pages.dart';
import 'package:salapiya/finance/report_data.dart';
import 'package:salapiya/finance/report_tab.dart';
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

  Future<void> show(
    WidgetTester tester,
    PrototypeSession session, {
    required TargetPlatform platform,
    required double width,
    required String tab,
    double text = 1,
    Brightness brightness = Brightness.light,
    double height = 3600,
  }) => app(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.lg),
        child: MoneyScreen(key: UniqueKey(), session: session, initial: tab),
      ),
    ),
    platform: platform,
    width: width,
    text: text,
    brightness: brightness,
    height: height,
  );

  void clean(WidgetTester tester, String label) {
    final error = tester.takeException();
    expect(error, isNull, reason: '$label: $error');
  }

  LocalSnapshot sample() => demoSample(civilToday());

  group('sweep', () {
    for (final tab in const ['Cards', 'Planning', 'Reports']) {
      testWidgets('$tab at every size, text size and theme', (tester) async {
        final session = PrototypeSession();
        addTearDown(session.dispose);
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            for (final brightness in Brightness.values) {
              await show(
                tester,
                session,
                tab: tab,
                platform: platform,
                width: width,
                text: text,
                brightness: brightness,
              );
              expect(find.byType(KpiTile), findsNWidgets(4));
              clean(tester, '$tab $platform $width $text $brightness');
            }
          }
        }
      });

      testWidgets('$tab hidden, incomplete and empty', (tester) async {
        final session = PrototypeSession();
        addTearDown(session.dispose);
        void only(OverviewScenario s) => session.select(s);
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            session.hideAmounts = true;
            only(OverviewScenario.local);
            await show(
              tester,
              session,
              tab: tab,
              platform: platform,
              width: width,
              text: text,
            );
            expect(find.textContaining('₱'), findsNothing);
            expect(find.textContaining('••••'), findsNothing);
            clean(tester, '$tab hidden $platform $width $text');
            session.hideAmounts = false;
            only(OverviewScenario.incomplete);
            await show(
              tester,
              session,
              tab: tab,
              platform: platform,
              width: width,
              text: text,
            );
            expect(find.textContaining('₱'), findsNothing);
            clean(tester, '$tab incomplete $platform $width $text');
            only(OverviewScenario.empty);
            await show(
              tester,
              session,
              tab: tab,
              platform: platform,
              width: width,
              text: text,
            );
            clean(tester, '$tab empty $platform $width $text');
            only(OverviewScenario.local);
          }
        }
      });
    }

    for (final tab in const ['Import', 'Files']) {
      testWidgets('$tab at every size, state and theme', (tester) async {
        final session = PrototypeSession();
        addTearDown(session.dispose);
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            for (final brightness in Brightness.values) {
              await show(
                tester,
                session,
                tab: tab,
                platform: platform,
                width: width,
                text: text,
                brightness: brightness,
              );
              await tester.pump();
              clean(tester, '$tab $platform $width $text $brightness');
            }
            session.hideAmounts = true;
            await show(
              tester,
              session,
              tab: tab,
              platform: platform,
              width: width,
              text: text,
            );
            expect(find.textContaining('₱'), findsNothing);
            expect(find.textContaining('••••'), findsNothing);
            session.hideAmounts = false;
            session.select(OverviewScenario.incomplete);
            await show(
              tester,
              session,
              tab: tab,
              platform: platform,
              width: width,
              text: text,
            );
            clean(tester, '$tab incomplete $platform $width $text');
            session.select(OverviewScenario.empty);
            await show(
              tester,
              session,
              tab: tab,
              platform: platform,
              width: width,
              text: text,
            );
            clean(tester, '$tab empty $platform $width $text');
            session.select(OverviewScenario.local);
          }
        }
      });
    }

    testWidgets('import and file pages at every size', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final s = sample();
      final pages = <Widget Function()>[
        for (final b in importBatches(s))
          () => ImportDetailView(
            key: UniqueKey(),
            listenable: session,
            source: (c) => demoMoneySource(c, session),
            id: b.id,
          ),
        for (final r in fileRows(s))
          () => FileDetailView(
            key: UniqueKey(),
            listenable: session,
            source: (c) => demoMoneySource(c, session),
            id: r.id,
          ),
        () => AttachFilePage(
          key: UniqueKey(),
          listenable: session,
          source: (c) => demoMoneySource(c, session),
        ),
      ];
      expect(pages.length, 6);
      for (final (platform, width) in sizes) {
        for (final text in [1.0, 2.0]) {
          for (final page in pages) {
            await app(
              tester,
              page(),
              platform: platform,
              width: width,
              text: text,
            );
            await tester.pump();
            clean(tester, 'page $platform $width $text');
          }
        }
      }
    });

    testWidgets('the forecast page at every size and state', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      Widget page() => ForecastPage(
        key: UniqueKey(),
        listenable: session,
        source: (c) => demoMoneySource(c, session),
      );
      for (final (platform, width) in sizes) {
        for (final text in [1.0, 2.0]) {
          for (final brightness in Brightness.values) {
            await app(
              tester,
              page(),
              platform: platform,
              width: width,
              text: text,
              brightness: brightness,
            );
            clean(tester, 'forecast $platform $width $text $brightness');
          }
          session.hideAmounts = true;
          await app(
            tester,
            page(),
            platform: platform,
            width: width,
            text: text,
          );
          expect(find.textContaining('₱'), findsNothing);
          expect(find.textContaining('••••'), findsNothing);
          clean(tester, 'forecast hidden $platform $width $text');
          session.hideAmounts = false;
          session.select(OverviewScenario.incomplete);
          await app(
            tester,
            page(),
            platform: platform,
            width: width,
            text: text,
          );
          expect(find.textContaining('₱'), findsNothing);
          clean(tester, 'forecast incomplete $platform $width $text');
          session.select(OverviewScenario.empty);
          await app(
            tester,
            page(),
            platform: platform,
            width: width,
            text: text,
          );
          clean(tester, 'forecast empty $platform $width $text');
          session.select(OverviewScenario.local);
        }
      }
    });

    testWidgets('detail pages at every size', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final s = sample();
      final ids = <(String, Widget Function(String))>[
        for (final r in s.current)
          ...switch (financeType(r)) {
            'creditCard' => [
              (
                r.title,
                (String id) => CardDetailView(
                  listenable: session,
                  source: (c) => demoMoneySource(c, session),
                  id: id,
                ),
              ),
            ],
            'statement' => [
              (
                r.title,
                (String id) => StatementDetailView(
                  listenable: session,
                  source: (c) => demoMoneySource(c, session),
                  id: id,
                ),
              ),
            ],
            'installment' => [
              (
                r.title,
                (String id) => PlanDetailView(
                  listenable: session,
                  source: (c) => demoMoneySource(c, session),
                  id: id,
                ),
              ),
            ],
            'budget' => [
              (
                r.title,
                (String id) => BudgetDetailView(
                  listenable: session,
                  source: (c) => demoMoneySource(c, session),
                  id: id,
                ),
              ),
            ],
            'savingsGoal' => [
              (
                r.title,
                (String id) => GoalDetailView(
                  listenable: session,
                  source: (c) => demoMoneySource(c, session),
                  id: id,
                ),
              ),
            ],
            'recurrence' => [
              (
                r.title,
                (String id) => RecurringDetailView(
                  listenable: session,
                  source: (c) => demoMoneySource(c, session),
                  id: id,
                ),
              ),
            ],
            _ => const <(String, Widget Function(String))>[],
          },
      ];
      expect(ids.length, greaterThan(12));
      for (final (platform, width) in sizes) {
        for (final text in [1.0, 2.0]) {
          for (final (title, build) in ids) {
            final id = s.current
                .firstWhere(
                  (r) =>
                      r.title == title &&
                      const {
                        'creditCard',
                        'statement',
                        'installment',
                        'budget',
                        'savingsGoal',
                        'recurrence',
                      }.contains(financeType(r)),
                )
                .actionId;
            await app(
              tester,
              build(id),
              platform: platform,
              width: width,
              text: text,
              height: 3000,
            );
            clean(tester, '$title $platform $width $text');
          }
        }
      }
    });
  });

  group('Cards', () {
    testWidgets('card debt and available credit never read as yours', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, tab: 'Cards', platform: windows, width: 1440);
      expect(find.text('Not counted in Available money'), findsOneWidget);
      expect(find.textContaining('Not money you have'), findsWidgets);
      expect(find.textContaining('liquid'), findsNothing);
      expect(find.textContaining('PHP'), findsNothing);
    });

    testWidgets('a card over its limit and one with no limit say so', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, tab: 'Cards', platform: windows, width: 1440);
      expect(find.textContaining('Over the limit by'), findsOneWidget);
      expect(find.text('No limit recorded'), findsOneWidget);
    });

    testWidgets('the Your cards table columns line up', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, tab: 'Cards', platform: windows, width: 1440);
      final rows = cardRows(sample(), civilToday());
      final table = find.byKey(const ValueKey('cards-table'));
      final right = [
        for (final c in rows)
          tester
              .getTopRight(
                find
                    .descendant(
                      of: table,
                      matching: find.text(session.amount(c.owed)),
                    )
                    .last,
              )
              .dx,
      ];
      expect(right.toSet().length, 1, reason: '$right');
    });

    testWidgets('tiles keep their values on one line across a row', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, tab: 'Cards', platform: windows, width: 1440);
      final tiles = find.byType(KpiTile);
      final tops = {
        for (final e in tiles.evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dy,
      };
      expect(tops.length, 1);
    });
  });

  group('Reports', () {
    Future<void> tab(
      WidgetTester tester,
      PrototypeSession session,
      ReportFilter filter, {
      TargetPlatform platform = windows,
      double width = 1440,
      void Function(ReportFilter)? onExport,
    }) => app(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.lg),
          child: Builder(
            builder: (context) => ReportsTab(
              source: demoMoneySource(context, session),
              filter: filter,
              onFilter: (_) {},
              onExport: onExport ?? (_) {},
            ),
          ),
        ),
      ),
      platform: platform,
      width: width,
    );

    Finder inTile(String key, String text) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.text(text),
    );

    testWidgets('an account filter never shows spending as zero', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(
        tester,
        session,
        ReportFilter(account: sample().accounts.first.id),
      );
      expect(inTile('report-spending', 'All accounts only'), findsOneWidget);
      expect(inTile('report-income', 'All accounts only'), findsOneWidget);
      final money = find.descendant(
        of: find.byKey(const ValueKey('report-spending')),
        matching: find.textContaining('₱'),
      );
      expect(money, findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report-money-in')),
          matching: find.textContaining('₱'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a category filter never shows cash as zero', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(
        tester,
        session,
        const ReportFilter(category: 'category-other'),
      );
      expect(inTile('report-money-in', 'All categories only'), findsOneWidget);
      expect(inTile('report-money-out', 'All categories only'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report-spending')),
          matching: find.textContaining('₱'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a card that can’t answer says so', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(
        tester,
        session,
        ReportFilter(account: sample().accounts.first.id),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report-debts-cards')),
          matching: find.text('Clear the filters to see this.'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Clear the account filter to see this.'),
        findsNWidgets(3),
      );
      expect(find.text('Not available yet'), findsNothing);
    });

    testWidgets('dates a report can’t cover show why, and no figures', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(
        tester,
        session,
        const ReportFilter(
          period: ReportPeriod.custom,
          from: '2024-01-01',
          to: '2026-01-01',
        ),
      );
      expect(
        find.byKey(const ValueKey('report-dates-problem')),
        findsOneWidget,
      );
      expect(find.byType(KpiTile), findsNothing);
    });

    testWidgets('a long period draws months, a short one days', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session, const ReportFilter());
      expect(find.text('Daily'), findsOneWidget);
      await tab(
        tester,
        session,
        const ReportFilter(period: ReportPeriod.thisYear),
      );
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Highest month'), findsOneWidget);
    });

    testWidgets('Export CSV is in the band on Android, the header on Windows', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session, const ReportFilter());
      expect(find.byKey(const ValueKey('report-export')), findsNothing);
      await show(
        tester,
        session,
        tab: 'Reports',
        platform: windows,
        width: 1440,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('money-quick-actions')),
          matching: find.text('Export CSV'),
        ),
        findsOneWidget,
      );
      ReportFilter? saved;
      const filter = ReportFilter(period: ReportPeriod.lastMonth);
      await tab(
        tester,
        session,
        filter,
        platform: android,
        width: 360,
        onExport: (f) => saved = f,
      );
      await tester.tap(find.byKey(const ValueKey('report-export')));
      expect(saved, filter);
    });

    testWidgets('the shared page lists every record, with no limit', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(
        tester,
        session,
        const ReportFilter(period: ReportPeriod.thisYear),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('report-menu')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('report-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-open-page')));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('report-page-totals')), findsOneWidget);
      expect(find.byKey(const ValueKey('record-list-end')), findsWidgets);
      expect(find.text('Show more'), findsNothing);
    });

    testWidgets('Where it went keeps its shares in one column', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      // Three months always hold six categories; this month may not yet.
      await tab(
        tester,
        session,
        const ReportFilter(period: ReportPeriod.last90),
      );
      final edges = <double>{};
      for (var i = 0; i < 6; i++) {
        final share = find.descendant(
          of: find.byKey(ValueKey('category-$i')),
          matching: find.textContaining('%'),
        );
        edges.add(tester.getTopRight(share).dx);
      }
      expect(edges.length, 1);
    });

    testWidgets('Debts and cards starts at the top and closes its list', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session, const ReportFilter());
      final card = find.byKey(const ValueKey('report-debts-cards'));
      // The caption names the period, so it reads differently through a month.
      final caption = tester.getBottomLeft(
        find.descendant(of: card, matching: find.byType(Text)).at(1),
      );
      final first = tester.getTopLeft(
        find.descendant(of: card, matching: find.text('Card purchases')),
      );
      expect(first.dy - caption.dy, lessThan(Space.xl));
      expect(find.byKey(const ValueKey('report-debts-end')), findsOneWidget);
    });

    testWidgets('two empty periods have nothing to compare', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(
        tester,
        session,
        const ReportFilter(
          period: ReportPeriod.custom,
          from: '2020-01-01',
          to: '2020-01-31',
        ),
      );
      expect(find.byType(ChangeLine), findsNothing);
      expect(find.textContaining('₱0.00'), findsWidgets);
    });

    testWidgets('a zero-limit budget doesn’t read as over its limit', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session, const ReportFilter());
      final zero = find.descendant(
        of: find.byKey(const ValueKey('report-budget-table')),
        matching: find.text('Zero-limit budget'),
      );
      expect(zero, findsOneWidget);
      final pill = tester.widget<StatusPill>(
        find.ancestor(of: zero, matching: find.byType(StatusPill)),
      );
      expect(pill.tone, PillTone.neutral);
    });

    testWidgets('tile values line up across a row', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session, const ReportFilter());
      final tops = {
        for (final key in const [
          'report-spending',
          'report-income',
          'report-money-in',
          'report-money-out',
        ])
          tester.getTopLeft(find.byKey(ValueKey(key))).dy,
      };
      expect(tops.length, 1);
    });
  });

  group('Import', () {
    Future<void> tab(WidgetTester tester, PrototypeSession session) =>
        show(tester, session, tab: 'Import', platform: windows, width: 1440);

    testWidgets('it answers what’s waiting and how the last one went', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session);
      await tester.pump();
      expect(find.text('bank-export-october.csv'), findsWidgets);
      expect(find.text('Ready to review'), findsWidgets);
      expect(find.text('3 of 4 imported'), findsOneWidget);
      expect(find.text('Done'), findsWidgets);
      expect(
        find.byKey(const ValueKey('import-history-table')),
        findsOneWidget,
      );
    });

    testWidgets('a zero-limit budget reads the same everywhere', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        tab: 'Planning',
        platform: windows,
        width: 1440,
      );
      final row = find.ancestor(
        of: find.text('Bills held at zero'),
        matching: find.byType(Wrap),
      );
      expect(
        find.descendant(of: row, matching: find.text('Zero-limit budget')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Over the limit')),
        findsNothing,
      );
      // Spending builds through the month, so how many are over moves. What
      // holds is that the zero-limit budget is in neither figure.
      final budgets = [
        for (final (period, b) in budgetRows(sample(), civilToday()))
          if (period == BudgetWhen.current) b,
      ];
      final summary = PlanningSummary(budgets, const [], const []);
      expect(summary.limited.length, budgets.length - 1);
      expect(
        find.text('${summary.withinLimit} of ${summary.limited.length}'),
        findsOneWidget,
      );
      expect(
        find.text(
          summary.overLimit == 0
              ? 'Within limit'
              : 'Within limit · ${summary.overLimit} over',
        ),
        findsOneWidget,
      );
      final id = sample().current
          .firstWhere((r) => r.title == 'Bills held at zero')
          .actionId;
      await app(
        tester,
        BudgetDetailView(
          listenable: session,
          source: (c) => demoMoneySource(c, session),
          id: id,
        ),
        platform: windows,
        width: 1440,
      );
      expect(find.text('Zero-limit budget'), findsOneWidget);
      expect(find.text('Over the limit'), findsNothing);
    });

    testWidgets('old words are gone', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session);
      for (final word in const ['pmp-cash', 'SHA256', 'staged', 'batch']) {
        expect(find.textContaining(word), findsNothing, reason: word);
      }
    });

    testWidgets('a row of the history opens its import', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session);
      final done = importBatches(sample()).firstWhere((b) => !b.open);
      await tester.tap(find.text(done.name).first);
      await tester.pumpAndSettle();
      expect(find.byType(ImportDetailView), findsOneWidget);
      expect(find.text('Left out'), findsOneWidget);
      expect(find.text('Imported'), findsNWidgets(3));
      expect(find.text('Continue review'), findsNothing);
    });

    testWidgets('a waiting import’s page offers to continue', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final waiting = importBatches(sample()).firstWhere((b) => b.open);
      await app(
        tester,
        ImportDetailView(
          listenable: session,
          source: (c) => demoMoneySource(c, session),
          id: waiting.id,
        ),
        platform: windows,
        width: 1440,
      );
      expect(find.text('Continue review'), findsOneWidget);
      expect(find.text('Needs a look'), findsWidgets);
    });
  });

  group('Files', () {
    Future<void> tab(WidgetTester tester, PrototypeSession session) async {
      await show(tester, session, tab: 'Files', platform: windows, width: 1440);
      await tester.pump();
    }

    testWidgets('it answers what’s attached and what’s missing', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('Not checked yet'), findsOneWidget);
      expect(find.text('flight-itinerary.pdf'), findsWidgets);
      expect(find.byKey(const ValueKey('files-attention')), findsOneWidget);
      expect(
        find.text('3 files listed, 0 files included. Keep your originals.'),
        findsOneWidget,
      );
    });

    testWidgets('Check files reads each file and says what it found', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session);
      await tester.tap(find.byKey(const ValueKey('files-checked')));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('1 verified'), findsOneWidget);
    });

    testWidgets('the filter narrows to what it names', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session);
      await tester.tap(find.text('Archived links'));
      await tester.pump();
      expect(find.text('order-photo.png'), findsOneWidget);
      expect(find.text('running-shoes-receipt.pdf'), findsNothing);
    });

    testWidgets('a missing file’s page offers no preview or copy', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final s = sample();
      final id = fileRows(s)
          .firstWhere((r) => r.name == 'flight-itinerary.pdf')
          .id;
      await app(
        tester,
        FileDetailView(
          listenable: session,
          source: (c) => demoMoneySource(c, session),
          id: id,
        ),
        platform: windows,
        width: 1440,
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('file-save')), findsNothing);
      expect(find.byKey(const ValueKey('file-preview')), findsNothing);
      expect(find.textContaining('isn’t on this device'), findsOneWidget);
    });

    testWidgets('a file that’s here says it isn’t virus-scanned', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final id = fileRows(sample())
          .firstWhere((r) => r.name == 'running-shoes-receipt.pdf')
          .id;
      await app(
        tester,
        FileDetailView(
          listenable: session,
          source: (c) => demoMoneySource(c, session),
          id: id,
        ),
        platform: windows,
        width: 1440,
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Not virus-scanned'), findsOneWidget);
      expect(find.byKey(const ValueKey('file-save')), findsOneWidget);
      // A PDF doesn't open here.
      expect(find.byKey(const ValueKey('file-preview')), findsNothing);
    });

    testWidgets('a PDF opens in another app, and an image previews', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final id = fileRows(sample())
          .firstWhere((r) => r.name == 'running-shoes-receipt.pdf')
          .id;
      await app(
        tester,
        FileDetailView(
          listenable: session,
          source: (c) => demoMoneySource(c, session),
          id: id,
        ),
        platform: android,
        width: 360,
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('file-open')), findsOneWidget);
      expect(find.byKey(const ValueKey('file-preview')), findsNothing);
    });

    testWidgets('a missing file can’t be opened in another app', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final id = fileRows(sample())
          .firstWhere((r) => r.name == 'flight-itinerary.pdf')
          .id;
      await app(
        tester,
        FileDetailView(
          listenable: session,
          source: (c) => demoMoneySource(c, session),
          id: id,
        ),
        platform: windows,
        width: 1440,
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('file-open')), findsNothing);
    });

    testWidgets('searching narrows the records to attach to', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await app(
        tester,
        AttachFilePage(
          listenable: session,
          source: (c) => demoMoneySource(c, session),
        ),
        platform: windows,
        width: 1440,
      );
      await tester.enterText(
        find.byKey(const ValueKey('attach-search')),
        'running shoes',
      );
      await tester.pump();
      expect(find.text('New running shoes'), findsOneWidget);
      expect(find.text('Coffee'), findsNothing);
    });
  });

  group('Forecast', () {
    Future<void> page(WidgetTester tester, PrototypeSession session) => app(
      tester,
      ForecastPage(
        listenable: session,
        source: (c) => demoMoneySource(c, session),
      ),
      platform: windows,
      width: 1440,
    );

    testWidgets('it is labelled an estimate', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await page(tester, session);
      expect(find.textContaining('An estimate'), findsOneWidget);
      expect(find.text('Lowest day'), findsOneWidget);
    });

    testWidgets('what you expect can be left out and put back', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await page(tester, session);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      final links = find.text('Leave out');
      expect(links, findsWidgets);
      final before = links.evaluate().length;
      await tester.tap(links.first);
      await tester.pump();
      expect(find.text('Leave out').evaluate().length, lessThan(before));
      expect(find.text('Put back'), findsOneWidget);
      await tester.tap(find.text('Put back'));
      await tester.pump();
      expect(find.text('Put back'), findsNothing);
      expect(find.text('Leave out').evaluate().length, before);
    });

    testWidgets('logged records offer no Leave out', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await page(tester, session);
      expect(find.text('Expected'), findsWidgets);
      expect(
        find.text('Leave out').evaluate().length,
        find.text('Expected').evaluate().length,
      );
      expect(find.textContaining('can’t be left out'), findsOneWidget);
    });

    testWidgets('a what-if counts once it’s complete', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await page(tester, session);
      await tester.tap(find.byKey(const ValueKey('what-if-add')));
      await tester.pump();
      expect(find.text('What-if'), findsNothing);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('what-if-amount-0')),
          matching: find.byType(TextField),
        ),
        '0',
      );
      await tester.pump();
      expect(
        find.text('Enter an amount above zero, like 1500.00.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('what-if-amount-0')),
          matching: find.byType(TextField),
        ),
        '1000.00',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('what-if-name-0')),
          matching: find.byType(TextField),
        ),
        'New laptop',
      );
      await tester.pump();
      expect(find.text('What-if'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('what-if-date-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose date'));
      await tester.pumpAndSettle();
      expect(find.text('What-if'), findsOneWidget);
      expect(find.text('New laptop'), findsWidgets);
    });
  });

  group('lists cut short', () {
    testWidgets('Due next links to every open row, on one page', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, tab: 'Cards', platform: windows, width: 1440);
      final all = cardDues(sample(), civilToday());
      expect(all.length, greaterThan(5));
      expect(find.text('${all.length - 5} more on your cards'), findsOneWidget);
      await tester.tap(find.text('${all.length - 5} more on your cards'));
      await tester.pumpAndSettle();
      expect(find.byType(CardDuesPage), findsOneWidget);
      expect(find.byKey(const ValueKey('card-dues-table')), findsOneWidget);
      for (final d in all) {
        expect(
          find.byKey(ValueKey('all-due-log-${d.id}')),
          findsOneWidget,
          reason: 'No row limit: ${d.id}',
        );
      }
    });

    testWidgets('Coming up links to its whole list', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        tab: 'Planning',
        platform: windows,
        width: 1440,
      );
      final all = upcomingRows(sample(), civilToday());
      expect(all.length, greaterThan(6));
      await tester.tap(find.text('${all.length - 6} more'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('upcoming-share-table')),
        findsOneWidget,
      );
    });

    testWidgets('a list that shows everything says so, and isn’t a link', (
      tester,
    ) async {
      await app(
        tester,
        const Scaffold(body: ListEnd()),
        platform: windows,
        width: 600,
      );
      expect(find.text('That’s everything'), findsOneWidget);
      expect(find.byType(CardLink), findsNothing);
    });

    testWidgets('a link in a row with its own chevron has none', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, tab: 'Cards', platform: windows, width: 1440);
      final due = cardDues(sample(), civilToday()).first;
      final link = find.byKey(ValueKey('card-log-${due.id}'));
      expect(
        find.descendant(of: link, matching: find.byIcon(Icons.chevron_right)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey('card-due-${due.id}')),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Log payment ends level with the amount above it', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final due = cardDues(sample(), civilToday()).first;
      for (final (platform, width) in const [
        (windows, 1440.0),
        (android, 412.0),
        (android, 320.0),
      ]) {
        await show(
          tester,
          session,
          tab: 'Cards',
          platform: platform,
          width: width,
        );
        final row = find.byKey(ValueKey('card-due-${due.id}'));
        final link = find.descendant(
          of: row,
          matching: find.text('Log payment'),
        );
        final money = find.descendant(
          of: row,
          matching: find.text(session.amount(due.item.amount)),
        );
        expect(
          tester.getTopRight(link).dx,
          tester.getTopRight(money).dx,
          reason: '$platform $width',
        );
      }
    });

    test('details break between themselves, never inside one', () {
      final line = detailLine(['Installment', 'Mon, 11 Jan', 'in 72 days']);
      expect(line.split(' '), [
        'Installment\u00A0·',
        'Mon,\u00A011\u00A0Jan\u00A0·',
        'in\u00A072\u00A0days',
      ]);
    });

    test('how far off a due date is shows only when it’s close', () {
      final dues = cardDues(sample(), civilToday());
      expect(dueDetail(dues.first), contains('days'));
      final far = dues.where((d) => d.item.days > 7).first;
      expect(dueDetail(far), isNot(contains('in\u00A0')));
    });
  });

  group('Overview dues', () {
    testWidgets('statement and installment amounts can overlap, and it says', (
      tester,
    ) async {
      FinancialReminderSource due(String kind) => FinancialReminderSource(
        kind,
        '1',
        'x',
        'Rewards',
        // Tomorrow isn't this week on a Sunday.
        civilToday(),
        BigInt.from(100),
        kind,
      );
      Widget list(List<FinancialReminderSource> rows) => Scaffold(
        body: SingleChildScrollView(
          child: DuesList(
            dues: OverviewDues.from(rows, civilToday(), DuePeriod.week),
            amount: (v) => '₱$v',
            onOpen: (_) {},
          ),
        ),
      );
      await app(
        tester,
        list([due('Card statement due'), due('Card installment due')]),
        platform: windows,
        width: 1000,
      );
      expect(find.byKey(const ValueKey('dues-overlap')), findsOneWidget);
      await app(
        tester,
        list([due('Card statement due')]),
        platform: windows,
        width: 1000,
      );
      expect(find.byKey(const ValueKey('dues-overlap')), findsNothing);
    });
  });

  group('Planning', () {
    testWidgets('no total across budgets with different terms', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        tab: 'Planning',
        platform: windows,
        width: 1440,
      );
      final current = [
        for (final (period, b) in budgetRows(sample(), civilToday()))
          if (period == BudgetWhen.current) b,
      ];
      expect(sameBudgetTerms(current), isTrue);
      expect(find.byKey(const ValueKey('budget-gauge')), findsOneWidget);
    });

    testWidgets('the gauge shows only for budgets that can be added up', (
      tester,
    ) async {
      final current = activeBudgets(sample(), civilToday());
      final first = current.first.budget;
      final gross = BudgetProgress(
        LocalRevision(
          id: first.id,
          actionId: first.actionId,
          kind: first.kind,
          change: first.change,
          date: first.date,
          title: first.title,
          amount: first.amount,
          values: {...first.values, 'basis': 'gross'},
          postings: const [],
          number: 1,
        ),
        current.first.spent,
      );
      Widget card(List<BudgetProgress> budgets) => Scaffold(
        body: SingleChildScrollView(
          child: BudgetsCard(
            budgets: budgets,
            amount: (v) => '₱$v',
            onOpen: () {},
          ),
        ),
      );
      await app(tester, card(current), platform: windows, width: 1000);
      expect(find.byKey(const ValueKey('budget-gauge')), findsOneWidget);
      await app(
        tester,
        card([gross, ...current.skip(1)]),
        platform: windows,
        width: 1000,
      );
      expect(find.byKey(const ValueKey('budget-gauge')), findsNothing);
    });

    testWidgets('in a tall card the gauge centers and the list stays up', (
      tester,
    ) async {
      final current = activeBudgets(sample(), civilToday());
      const height = 900.0;
      await app(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: height),
              child: BudgetsCard(
                budgets: current,
                amount: (v) => '₱$v',
                onOpen: () {},
                onBudget: (_) {},
              ),
            ),
          ),
        ),
        platform: windows,
        width: 1000,
      );
      final card = tester.getRect(find.byType(BudgetsCard));
      expect(card.height, height);
      final caption = tester.getBottomLeft(
        find.text('Active budgets covering today'),
      );
      final gauge = tester.getRect(find.byKey(const ValueKey('budget-gauge')));
      final padding = Space.cardPaddingOf(
        tester.element(find.byType(BudgetsCard)),
      );
      final rest = (caption.dy + Space.md + card.bottom - padding) / 2;
      expect(gauge.center.dy, moreOrLessEquals(rest, epsilon: 2));
      final first = tester.getTopLeft(
        find.byKey(ValueKey('budget-${current.first.budget.actionId}')),
      );
      expect(first.dy - caption.dy, lessThan(Space.xl));
    });

    testWidgets('old words are gone', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        tab: 'Planning',
        platform: windows,
        width: 1440,
      );
      for (final word in const [
        'Reservation',
        'Occurrence',
        'Recognized',
        'PHP',
        'exclusive',
      ]) {
        expect(find.textContaining(word), findsNothing, reason: word);
      }
    });
  });
}
