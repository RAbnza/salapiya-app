import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_cards.dart';
import 'package:salapiya/app/overview_data.dart';
import 'package:salapiya/app/overview_demo.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/finance/debt_data.dart';
import 'package:salapiya/finance/debt_demo.dart';
import 'package:salapiya/finance/debt_screen.dart';
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
    double height = 3200,
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
    double height = 3200,
    DebtsTab tab = DebtsTab.summary,
  }) => app(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.lg),
        // A fresh dashboard each time, so it starts on [tab].
        child: DebtsDashboard(
          key: UniqueKey(),
          listenable: session,
          source: (context) => demoDebtsSource(context, session),
          initial: tab.label,
          actions: [
            for (final label in const [
              'Log a debt payment',
              'Add a debt',
              'Log a new loan',
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

  Future<void> detail(
    WidgetTester tester,
    PrototypeSession session,
    String title, {
    required TargetPlatform platform,
    required double width,
    double text = 1,
    Brightness brightness = Brightness.light,
  }) {
    final debt = demoOverviewSnapshot(civilToday()).current
        .firstWhere((r) => r.title == title && r.kind != 'expense');
    return app(
      tester,
      DebtDetailView(
        key: UniqueKey(),
        listenable: session,
        source: (context) => demoDebtsSource(context, session),
        debtId: debt.id,
      ),
      platform: platform,
      width: width,
      text: text,
      brightness: brightness,
    );
  }

  Future<void> everyTab(WidgetTester tester, String label) async {
    for (final tab in DebtsTab.values) {
      await tester.ensureVisible(find.byKey(ValueKey(tab)));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey(tab)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final error = tester.takeException();
      expect(error, isNull, reason: '$label ${tab.label}: $error');
    }
  }

  group('sweep', () {
    testWidgets('every tab at every size, text size and theme', (tester) async {
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

    testWidgets('debt details at every size, text size and theme', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final title in const [
        'Phone installment',
        'Appliance plan',
        'Emergency loan',
        'Scooter loan',
        'Laptop loan',
      ]) {
        for (final (platform, width) in sizes) {
          for (final text in [1.0, 2.0]) {
            for (final brightness in Brightness.values) {
              await detail(
                tester,
                session,
                title,
                platform: platform,
                width: width,
                text: text,
                brightness: brightness,
              );
              final error = tester.takeException();
              expect(
                error,
                isNull,
                reason: '$title $platform $width $text $brightness: $error',
              );
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
        await show(tester, session, platform: platform, width: width);
        expect(find.byType(Sparkline), findsNothing);
        expect(find.byType(ChangeLine), findsNothing);
        expect(find.text('Amount hidden'), findsWidgets);
        expect(find.textContaining('₱'), findsNothing);
        expect(find.textContaining('Amount hidden of'), findsNothing);
        await everyTab(tester, 'hidden $platform $width');
        session.togglePrivacy();

        session.select(OverviewScenario.incomplete);
        await show(tester, session, platform: platform, width: width);
        expect(find.text('Your first download isn’t finished'), findsOneWidget);
        expect(find.text('Not available yet'), findsWidgets);
        expect(find.textContaining('₱'), findsNothing);
        await everyTab(tester, 'incomplete $platform $width');

        session.select(OverviewScenario.empty);
        await show(tester, session, platform: platform, width: width);
        expect(find.text('No debts yet'), findsOneWidget);
        await everyTab(tester, 'empty $platform $width');
        session.select(OverviewScenario.local);
      }
    });
  });

  group('summary', () {
    testWidgets('the four answers are on the first screen', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, platform: windows, width: 1440, height: 900);
      final s = demoSample(civilToday());
      final total = sumMinor(
        overviewDebtProgress(s, civilToday()).map((d) => d.outstanding),
      );
      for (final (key, label) in const [
        ('debts-owed', 'What you owe'),
        ('debts-overdue', 'Overdue'),
        ('debts-next', 'Next payment'),
        ('debts-month', 'Due this month'),
      ]) {
        final tile = find.byKey(ValueKey(key));
        expect(tester.getBottomLeft(tile).dy, lessThan(500), reason: key);
        expect(
          find.descendant(of: tile, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('debts-owed')),
          matching: find.text(session.amount(total)),
        ),
        findsOneWidget,
      );
      expect(find.text('Your debts'), findsOneWidget);
      expect(find.text('Due next'), findsOneWidget);
      expect(find.text('Needs your input'), findsOneWidget);
    });

    testWidgets('tile values line up whichever labels wrap', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      double top(String key) => tester
          .getTopLeft(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(MoneyAmount),
            ),
          )
          .dy;
      for (final (platform, width, rows) in const [
        (
          android,
          412.0,
          [
            ['debts-overdue', 'debts-next'],
          ],
        ),
        (
          windows,
          1440.0,
          [
            ['debts-owed', 'debts-overdue', 'debts-next', 'debts-month'],
          ],
        ),
      ]) {
        await show(tester, session, platform: platform, width: width);
        for (final row in rows) {
          expect({for (final key in row) top(key)}, hasLength(1));
        }
      }
    });

    testWidgets('lists start at the top and say where they end', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, platform: windows, width: 1440);
      final needs = find.byKey(const ValueKey('debts-needs'));
      final title = find.descendant(
        of: needs,
        matching: find.text('Small things that keep these figures right'),
      );
      final rows = find.descendant(of: needs, matching: find.byType(ListRow));
      final end = find.byKey(const ValueKey('needs-end'));
      // The first row sits right under the header, however tall the card.
      expect(
        tester.getTopLeft(rows.first).dy - tester.getBottomLeft(title).dy,
        lessThanOrEqualTo(Space.md),
      );
      expect(find.text('That’s everything'), findsWidgets);
      expect(
        tester.getTopLeft(end).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(rows.last).dy),
      );
      expect(
        tester.getBottomLeft(needs).dy - tester.getBottomLeft(end).dy,
        greaterThan(Space.xxxl),
        reason: 'the marker closes the list, not the card',
      );
    });

    testWidgets('Android has no page title or action buttons', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, platform: android, width: 360);
      expect(find.byKey(const ValueKey('debts-quick-actions')), findsNothing);
      expect(find.byType(PageHeader), findsNothing);
      final pill = find.byKey(const ValueKey('debts-dues-pill'));
      expect(pill, findsOneWidget);
      await tester.tap(pill);
      await tester.pump();
      expect(find.byKey(const ValueKey('debts-dues')), findsOneWidget);
    });

    testWidgets('Windows actions end at the content edge', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, platform: windows, width: 1440);
      final actions = find.byKey(const ValueKey('debts-quick-actions'));
      final tabs = find.byKey(const ValueKey('debts-tabs'));
      expect(
        tester.getTopRight(actions).dx,
        moreOrLessEquals(tester.getTopRight(tabs).dx),
      );
    });

    testWidgets('the filter narrows Your debts, and every debt is listed', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, platform: windows, width: 1440);
      final titles = [
        'Phone installment',
        'Loan from Tita Rosa',
        'Appliance plan',
        'Emergency loan',
        'Scooter loan',
        'Laptop loan',
      ];
      final table = find.byKey(const ValueKey('debts-table'));
      bool listed(String title) => find
          .descendant(of: table, matching: find.textContaining(title))
          .evaluate()
          .isNotEmpty;
      expect(titles.where(listed), titles);
      await tester.tap(find.byKey(const ValueKey(DebtFilter.overdue)));
      await tester.pump();
      expect(titles.where(listed), ['Loan from Tita Rosa']);
      await tester.tap(find.byKey(const ValueKey(DebtFilter.noSchedule)));
      await tester.pump();
      expect(titles.where(listed), ['Emergency loan']);
      await tester.tap(find.byKey(const ValueKey(DebtFilter.paidOff)));
      await tester.pump();
      expect(titles.where(listed), ['Scooter loan', 'Laptop loan']);
    });
  });

  group('schedule', () {
    testWidgets('List view has the heading, totals and every item', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        platform: windows,
        width: 1440,
        tab: DebtsTab.schedule,
      );
      await tester.tap(find.byKey(const ValueKey('dues-view')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey(DuesView.list)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final today = civilToday();
      expect(find.textContaining('as of ${civilLabel(today)}'), findsOneWidget);
      expect(find.text('Total due'), findsOneWidget);
      final week = OverviewDues.from(
        overviewDueSources(demoSample(today), today),
        today,
        DuePeriod.week,
      );
      expect(find.byKey(const ValueKey('dues-list')), findsOneWidget);
      for (final i in [...week.overdue, ...week.upcoming]) {
        expect(find.byKey(ValueKey('due-${i.source.id}')), findsOneWidget);
      }
      // Beside nothing: the list takes the whole row.
      expect(
        tester.getSize(find.byKey(const ValueKey('debts-dues'))).width,
        moreOrLessEquals(
          tester.getSize(find.byKey(const ValueKey('debts-tabs'))).width,
        ),
      );
    });

    testWidgets('Debts only leaves card statements out', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        platform: windows,
        width: 1440,
        tab: DebtsTab.schedule,
      );
      await tester.tap(find.byKey(const ValueKey(DuePeriod.month)));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('dues-view')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('dues-scope-true')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Your debts only'), findsOneWidget);
      expect(find.textContaining('Card statement'), findsNothing);
    });
  });

  group('tables', () {
    double right(WidgetTester tester, Finder row) => tester
        .getTopRight(
          find.descendant(of: row, matching: find.byType(MoneyAmount)).last,
        )
        .dx;

    double left(WidgetTester tester, Finder row, String text) => tester
        .getTopLeft(find.descendant(of: row, matching: find.text(text)))
        .dx;

    testWidgets('payment rows keep their columns, whatever the amount', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        platform: windows,
        width: 1440,
        tab: DebtsTab.payments,
      );
      final rows = debtPaymentRows(demoSample(civilToday()));
      final found = [
        for (final p in rows)
          find.byKey(ValueKey('row-payment-${p.record.id}')),
      ];
      expect(found, isNotEmpty);
      expect({for (final row in found) right(tester, row)}, hasLength(1));
      expect({
        for (final (i, row) in found.indexed)
          left(tester, row, rows[i].paidFrom),
      }, hasLength(1));
    });

    testWidgets('installment rows keep their columns', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await detail(
        tester,
        session,
        'Phone installment',
        platform: windows,
        width: 1440,
      );
      final rows = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('row-installment-'),
      );
      expect(rows, findsNWidgets(6));
      final moneyRights = {
        for (final e in rows.evaluate())
          tester
              .getTopRight(
                find
                    .descendant(
                      of: find.byWidget(e.widget),
                      matching: find.byType(MoneyAmount),
                    )
                    .last,
              )
              .dx,
      };
      expect(moneyRights, hasLength(1));
      final paid = {
        for (final e in rows.evaluate())
          tester
              .getTopRight(
                find
                    .descendant(
                      of: find.byWidget(e.widget),
                      matching: find.byType(MoneyAmount),
                    )
                    .first,
              )
              .dx,
      };
      expect(paid, hasLength(1));
    });

    testWidgets('the debts table keeps its amount column', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(tester, session, platform: windows, width: 1440);
      final rows = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('row-debt-'),
      );
      expect(rows, findsNWidgets(6));
      expect({
        for (final e in rows.evaluate())
          tester
              .getTopRight(
                find.descendant(
                  of: find.byWidget(e.widget),
                  matching: find.byType(MoneyAmount),
                ),
              )
              .dx,
      }, hasLength(1));
    });

    testWidgets('narrow cards turn tables into rows', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        platform: android,
        width: 360,
        tab: DebtsTab.payments,
      );
      expect(find.text('Applied to'), findsNothing);
      expect(find.byType(AdaptiveRow), findsWidgets);
    });
  });

  group('details', () {
    testWidgets('a scheduled debt shows progress, payments and history', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await detail(
        tester,
        session,
        'Phone installment',
        platform: windows,
        width: 1440,
      );
      expect(find.text('Phone installment'), findsOneWidget);
      expect(find.text('Sample lender · Installment loan'), findsOneWidget);
      expect(find.text('Log a payment'), findsOneWidget);
      expect(find.byType(SegmentBar), findsOneWidget);
      expect(find.textContaining('2 of 6 payments logged'), findsOneWidget);
      expect(find.text('Last scheduled payment'), findsOneWidget);
      expect(find.text('Not a payoff date'), findsOneWidget);
      expect(find.text('Payment history'), findsOneWidget);
      expect(find.text('About this debt'), findsOneWidget);
    });

    testWidgets('the More menu keeps every action', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await detail(
        tester,
        session,
        'Appliance plan',
        platform: windows,
        width: 1440,
      );
      await tester.tap(find.byKey(const ValueKey('debt-more')));
      await tester.pump();
      for (final key in const [
        'debt-edit-schedule',
        'debt-update-amounts',
        'debt-break-down',
        'debt-lender-charge',
        'debt-early-payoff',
        'debt-view-record',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
    });

    testWidgets('a closed debt offers no new payment', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await detail(
        tester,
        session,
        'Scooter loan',
        platform: windows,
        width: 1440,
      );
      expect(find.text('Log a payment'), findsNothing);
      expect(find.text('Closed'), findsOneWidget);
      expect(find.text('Cancelled by payoff'), findsNWidgets(2));
      expect(find.text('Closed with a payoff'), findsOneWidget);
    });

    testWidgets('no schedule: no invented date, and Set schedule', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await detail(
        tester,
        session,
        'Emergency loan',
        platform: windows,
        width: 1440,
      );
      expect(find.text('Schedule not set'), findsOneWidget);
      expect(find.text('Set schedule'), findsOneWidget);
      expect(find.text('Last scheduled payment'), findsNothing);
      expect(find.text('Not available yet'), findsWidgets);
    });

    testWidgets('a varied amount asks for a check while it is close', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await detail(
        tester,
        session,
        'Appliance plan',
        platform: windows,
        width: 1440,
      );
      expect(find.text('Different each time'), findsOneWidget);
      expect(find.text('Without a breakdown'), findsOneWidget);
    });
  });

  testWidgets('Open as a page shows only the list', (tester) async {
    final session = PrototypeSession();
    addTearDown(session.dispose);
    await show(
      tester,
      session,
      platform: android,
      width: 360,
      tab: DebtsTab.schedule,
    );
    await tester.tap(find.byKey(const ValueKey('dues-view')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dues-open-page')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(DuesListPage), findsOneWidget);
    expect(find.byType(AppTabs<DebtsTab>), findsNothing);
    expect(find.textContaining('as of'), findsOneWidget);
  });
}
