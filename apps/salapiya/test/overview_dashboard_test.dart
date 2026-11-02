import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_cards.dart';
import 'package:salapiya/app/overview_controls.dart';
import 'package:salapiya/app/overview_dashboard.dart';
import 'package:salapiya/app/overview_data.dart';
import 'package:salapiya/finance/card_data.dart';
import 'package:salapiya/finance/planning_cards.dart';
import 'package:salapiya/finance/planning_data.dart';
import 'package:salapiya/app/overview_demo.dart';
import 'package:salapiya/finance/money_data.dart' show moneyActivity;
import 'package:salapiya/prototype/scenarios.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/local/finance_domain.dart';

/// Wednesday. Its ISO week runs Mon 26 Oct – Sun 1 Nov 2026.
const today = '2026-10-28';

const empty = LocalSnapshot(
  owner: 'owner',
  version: 0,
  accounts: [],
  categories: [],
  revisions: [],
);

FinancialReminderSource due(String date, {String kind = 'Debt due'}) =>
    FinancialReminderSource(
      'id-$date-$kind',
      '1',
      'source',
      'Item $date',
      date,
      BigInt.from(150000),
      kind,
    );

String amount(BigInt v) => '₱${phpDecimal(v)}';

Finder pill(String label) =>
    find.byWidgetPredicate((w) => w is StatusPill && w.label == label);

LocalRevision revision(String id, String kind, Map<String, String> values) =>
    LocalRevision(
      id: id,
      actionId: id,
      kind: kind,
      change: 'create',
      date: '2026-09-01',
      title: 'Phone loan',
      amount: BigInt.from(960000),
      values: values,
      postings: const [],
      number: 1,
    );

final debt = revision('debt', 'debtImport', const {});
final schedule = revision('schedule', 'debtSchedule', {
  'debt': 'debt',
  'schedule': debtCadenceRows(
    firstDue: '2026-09-30',
    frequency: 'monthly',
    installmentAmount: '3200.00',
    count: 3,
  ),
});
List<FinanceScheduleRow> get rows =>
    financeSchedule(schedule.values['schedule']!);

Future<void> pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: SalapiyaTheme.build(
        Brightness.light,
        platform: TargetPlatform.android,
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('periods', () {
    test('a week runs Monday to Sunday, a month is the calendar month', () {
      expect(duePeriodRange(today, DuePeriod.week), (
        '2026-10-26',
        '2026-11-01',
      ));
      expect(duePeriodRange('2026-10-26', DuePeriod.week).$1, '2026-10-26');
      expect(duePeriodRange('2026-11-01', DuePeriod.week).$2, '2026-11-01');
      expect(duePeriodRange(today, DuePeriod.month), (
        '2026-10-01',
        '2026-10-31',
      ));
      expect(monthEnd('2028-02-10'), '2028-02-29');
      expect(monthEnd('2026-12-31'), '2026-12-31');
    });
  });

  group('dues', () {
    test('empty data', () {
      final week = OverviewDues.from(const [], today, DuePeriod.week);
      expect(week.isEmpty, isTrue);
      expect(week.overdueTotal, BigInt.zero);
      expect(week.upcomingTotal, BigInt.zero);
      expect(week.days.map((d) => d.$1), [
        '2026-10-26',
        '2026-10-27',
        '2026-10-28',
        '2026-10-29',
        '2026-10-30',
        '2026-10-31',
        '2026-11-01',
      ]);
      expect(
        OverviewDues.from(const [], today, DuePeriod.month).days,
        hasLength(31),
      );
    });

    test('due today is listed, not overdue', () {
      final week = OverviewDues.from([due(today)], today, DuePeriod.week);
      expect(week.overdue, isEmpty);
      expect(week.upcoming.single.status, DebtDueStatus.dueToday);
      expect(week.upcoming.single.days, 0);
    });

    test('overdue by one day is only under Overdue', () {
      final week = OverviewDues.from(
        [due('2026-10-27', kind: 'Card statement due')],
        today,
        DuePeriod.week,
      );
      expect(week.upcoming, isEmpty);
      expect(week.overdue.single.status, DebtDueStatus.overdue);
      expect(week.overdue.single.days, -1);
      expect(week.overdueTotal, BigInt.from(150000));
    });

    test('items exactly on the week and month boundaries', () {
      final sources = [
        due('2026-10-26'), // Monday of this week, before today: overdue
        due('2026-10-01'), // first of the month, before today: overdue
        due('2026-10-31'), // last of the month
        due('2026-11-01'), // Sunday, last day of the week
        due('2026-11-02'), // the next Monday
      ];
      final week = OverviewDues.from(sources, today, DuePeriod.week);
      final month = OverviewDues.from(sources, today, DuePeriod.month);
      expect(week.overdue.map((i) => i.date), ['2026-10-01', '2026-10-26']);
      expect(week.upcoming.map((i) => i.date), ['2026-10-31', '2026-11-01']);
      expect(month.overdue.map((i) => i.date), ['2026-10-01', '2026-10-26']);
      expect(month.upcoming.map((i) => i.date), ['2026-10-31']);
      expect(week.upcomingTotal, BigInt.from(300000));
      // Overdue rows on a day of the period show on its calendar day too.
      expect(
        week.days.firstWhere((d) => d.$1 == '2026-10-26').$2.single.days,
        -2,
      );
    });
  });

  group('debt progress', () {
    test('partly paid, by the schedule', () {
      final p = DebtProgress(
        debt,
        DebtDueSummary(
          schedule,
          [(rows[1], BigInt.from(120000)), (rows[2], rows[2].amount)],
          today,
          7,
        ),
        BigInt.from(640000),
      );
      expect((p.done, p.total), (1, 3));
      expect(p.scheduledTotal, BigInt.from(960000));
      expect(p.scheduledLeft, BigInt.from(440000));
      expect(p.fraction, closeTo(520000 / 960000, 1e-9));
      expect(p.statusLabel, 'Due soon');
      expect(
        DebtProgressCard.progressLine(p, amount),
        '1 of 3 payments logged · ₱4400.00 of ₱9600.00 left',
      );
    });

    test('fully paid off', () {
      final p = DebtProgress(
        debt,
        DebtDueSummary(schedule, const [], today, 7),
        BigInt.zero,
      );
      expect(p.finished, isTrue);
      expect((p.done, p.total), (3, 3));
      expect(p.scheduledLeft, BigInt.zero);
      expect(p.fraction, 1);
      expect(p.statusLabel, 'Settled');
      expect(DebtProgressCard.progressLine(p, amount), 'All 3 payments logged');
      final closed = DebtProgress(
        debt,
        DebtDueSummary(schedule, const [], today, 7, closed: true),
        BigInt.zero,
      );
      expect(closed.statusLabel, 'Closed');
      expect(closed.fraction, 1);
      expect(
        DebtProgressCard.progressLine(closed, amount),
        'Closed with a payoff',
      );
    });

    test('no schedule has no bar', () {
      final p = DebtProgress(
        debt,
        const DebtDueSummary(null, [], today, 7),
        BigInt.from(100),
      );
      expect(p.fraction, isNull);
      expect(p.statusLabel, 'Schedule not set');
      expect(
        DebtProgressCard.progressLine(p, amount),
        'No payment schedule yet',
      );
    });
  });

  group('money derivations', () {
    test('empty data adds up to zero, never invents values', () {
      expect(overviewDebtProgress(empty, today), isEmpty);
      expect(activeBudgets(empty, today), isEmpty);
      expect(
        spendingByCategory(empty, '2026-10-01', today, (_) => ''),
        isEmpty,
      );
      expect(dailySpending(empty, '2026-10-01', today), hasLength(28));
      final owed = debtBalanceByMonth(empty, today);
      expect(owed.map((p) => p.$1), [
        '2026-05-31',
        '2026-06-30',
        '2026-07-31',
        '2026-08-31',
        '2026-09-30',
        today,
      ]);
      expect(owed.every((p) => p.$2 == BigInt.zero), isTrue);
      final comparison = SpendingComparison(empty, today);
      expect(comparison.difference, BigInt.zero);
      expect(
        overviewInsights(
          week: OverviewDues.from(const [], today, DuePeriod.week),
          comparison: comparison,
          categories: const [],
          budgets: const [],
          amount: amount,
        ),
        isEmpty,
      );
    });

    test('last month stops at its own last day', () {
      final march = SpendingComparison(empty, '2026-03-31');
      expect(
        (march.previousStart, march.previousEnd),
        ('2026-02-01', '2026-02-28'),
      );
      final october = SpendingComparison(empty, today);
      expect(october.previousEnd, '2026-09-28');
    });

    test('budgets use exact basis points; a zero limit has none', () {
      final b = BudgetProgress(
        revision('b', 'budget', const {}),
        BigInt.from(433276),
      );
      expect(b.basisPoints, 4513);
      expect(BudgetsCard.percent(b.basisPoints!), '45.13%');
      expect(BudgetsCard.percent(5), '0.05%');
      final zero = BudgetProgress(
        LocalRevision(
          id: 'z',
          actionId: 'z',
          kind: 'budget',
          change: 'create',
          date: today,
          title: 'Zero',
          amount: BigInt.zero,
          values: const {},
          postings: const [],
          number: 1,
        ),
        BigInt.from(100),
      );
      expect(zero.basisPoints, isNull);
      expect(zero.over, BigInt.from(100));
    });

    test('insights state overdue and due counts in plain words', () {
      final week = OverviewDues.from(
        [due('2026-10-27'), due(today), due('2026-10-30')],
        today,
        DuePeriod.week,
      );
      expect(
        overviewInsights(
          week: week,
          comparison: null,
          categories: [('Food', BigInt.from(100))],
          budgets: const [],
          amount: amount,
        ),
        [
          '1 payment is overdue, ₱1500.00 in total.',
          '2 payments are due by Sunday, ₱3000.00 in total.',
          'Your largest spending category this month is Food.',
        ],
      );
      // Hidden amounts leave the amounts out of the sentences.
      expect(
        overviewInsights(
          week: week,
          comparison: null,
          categories: [('Food', BigInt.from(100))],
          budgets: const [],
          amount: (_) => 'Amount hidden',
          hidden: true,
        ),
        [
          '1 payment is overdue.',
          '2 payments are due by Sunday.',
          'Your largest spending category this month is Food.',
        ],
      );
    });
  });

  group('dues card', () {
    testWidgets('empty data in both periods', (tester) async {
      final none = OverviewDues.from(const [], today, DuePeriod.week);
      await pump(
        tester,
        DuesCard(
          week: none,
          month: OverviewDues.from(const [], today, DuePeriod.month),
          amount: amount,
          onOpen: (_) {},
        ),
      );
      expect(find.text('Nothing due this week'), findsOneWidget);
      await tester.tap(find.text('This month'));
      await tester.pump();
      expect(find.text('Nothing due this month'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overdue rows sit on top; a day filters the list', (
      tester,
    ) async {
      final sources = [
        due('2026-10-27'),
        due(today),
        due('2026-10-31'),
        due('2026-11-01'),
      ];
      FinancialReminderSource? opened;
      await pump(
        tester,
        DuesCard(
          week: OverviewDues.from(sources, today, DuePeriod.week),
          month: OverviewDues.from(sources, today, DuePeriod.month),
          amount: amount,
          onOpen: (s) => opened = s,
        ),
      );
      expect(find.text('Overdue'), findsWidgets);
      expect(find.text('Due this week'), findsWidgets);
      expect(find.textContaining('1 day overdue'), findsOneWidget);
      expect(pill('Due today'), findsOneWidget);
      final overdueRow = tester.getTopLeft(find.text('Item 2026-10-27'));
      final todayRow = tester.getTopLeft(find.text('Item $today'));
      expect(overdueRow.dy, lessThan(todayRow.dy));
      expect(find.text('Item 2026-11-01'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('due-day-2026-10-31')));
      await tester.pump();
      expect(find.text('Item 2026-10-31'), findsOneWidget);
      expect(find.text('Item $today'), findsNothing);
      expect(find.text('Item 2026-10-27'), findsNothing);

      await tester.tap(find.text('This month'));
      await tester.pump();
      expect(find.text('Item 2026-11-01'), findsNothing);
      expect(find.text('Item 2026-10-31'), findsOneWidget);

      await tester.ensureVisible(find.text('Item 2026-10-31'));
      await tester.pump();
      await tester.tap(find.text('Item 2026-10-31'));
      expect(opened?.date, '2026-10-31');
      expect(tester.takeException(), isNull);
    });

    testWidgets('list view: every item in one table, with the total', (
      tester,
    ) async {
      final sources = [
        due('2026-10-27'),
        due(today),
        due('2026-10-31'),
        due('2026-11-01'),
      ];
      await pump(
        tester,
        DuesCard(
          week: OverviewDues.from(sources, today, DuePeriod.week),
          month: OverviewDues.from(sources, today, DuePeriod.month),
          amount: amount,
          onOpen: (_) {},
          shown: 1,
        ),
      );
      // The layout choice sits in the corner menu.
      await tester.tap(find.byKey(const ValueKey('dues-view')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey(DuesView.calendar)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey(DuesView.list)));
      await tester.pumpAndSettle();
      final table = find.byKey(const ValueKey('dues-list'));
      expect(table, findsOneWidget);
      // No calendar and no "Show all": every item is listed.
      expect(find.byType(DueCalendar), findsNothing);
      expect(find.textContaining('Show all'), findsNothing);
      for (final date in ['2026-10-27', today, '2026-10-31', '2026-11-01']) {
        expect(
          find.descendant(of: table, matching: find.text('Item $date')),
          findsOneWidget,
        );
      }
      expect(find.text('Due date'), findsOneWidget);
      expect(find.text('Total due'), findsOneWidget);
      expect(find.text('₱6000.00'), findsOneWidget);
      expect(find.textContaining('This week · 26 Oct – 1 Nov'), findsOneWidget);
      // Amounts end at the same x on every row.
      expect({
        for (final e
            in find
                .descendant(of: table, matching: find.byType(MoneyAmount))
                .evaluate())
          tester.getTopRight(find.byWidget(e.widget)).dx,
      }, hasLength(1));
      await tester.tap(find.text('This month'));
      await tester.pump();
      expect(find.text('Item 2026-11-01'), findsNothing);
      expect(find.textContaining('This month · 1–31 Oct'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('incomplete history shows "Not available yet"', (tester) async {
      final none = OverviewDues.from(const [], today, DuePeriod.week);
      await pump(
        tester,
        DuesCard(
          week: none,
          month: none,
          amount: amount,
          onOpen: (_) {},
          available: false,
        ),
      );
      expect(find.text('Not available yet'), findsOneWidget);
    });
  });

  group('category donut', () {
    // 60%, 30% and 10%: from 12 o'clock clockwise, Food runs to 216°, Bills
    // to 324°. 3 o'clock is in Food, 9 o'clock in Bills.
    Future<Offset> pumpCard(WidgetTester tester) async {
      await pump(
        tester,
        CategoryCard(
          categories: [
            ('Food', BigInt.from(600)),
            ('Bills', BigInt.from(300)),
            ('Fees', BigInt.from(100)),
          ],
          amount: amount,
          caption: '1–28 Oct',
          onOpen: () {},
        ),
      );
      return tester.getCenter(find.byType(OverviewDonut));
    }

    // The selection shows in the hole: name, share and amount.
    void showing(String name, String share, String value) {
      final hole = find.byKey(const ValueKey('category-selected'));
      for (final t in [name, share, value]) {
        expect(
          find.descendant(of: hole, matching: find.text(t)),
          findsOneWidget,
        );
      }
    }

    // Halfway across the ring.
    const ring = Space.xxxl + Space.lg + Space.xxs;

    testWidgets('tapping a section shows it; tapping the hole clears it', (
      tester,
    ) async {
      final center = await pumpCard(tester);
      expect(find.text('Top category'), findsOneWidget);
      await tester.tapAt(center + const Offset(ring, 0));
      await tester.pump();
      showing('Food', '60.0%', '₱6.00');
      await tester.tapAt(center + const Offset(-ring, 0));
      await tester.pump();
      showing('Bills', '30.0%', '₱3.00');
      await tester.tapAt(center);
      await tester.pump();
      expect(find.byKey(const ValueKey('category-selected')), findsNothing);
      expect(find.text('Top category'), findsOneWidget);
    });

    testWidgets('hovering a section shows it until the pointer leaves', (
      tester,
    ) async {
      final center = await pumpCard(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(center + const Offset(-ring, 0));
      await tester.pump();
      showing('Bills', '30.0%', '₱3.00');
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(find.text('Top category'), findsOneWidget);
    });

    testWidgets('legend names sit centered beside the share and amount', (
      tester,
    ) async {
      for (final (platform, width) in [
        (TargetPlatform.windows, 1440.0),
        (TargetPlatform.android, 412.0),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: SalapiyaTheme.build(Brightness.light, platform: platform),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  // The Spending tab's share of a Windows row, or a phone.
                  width: platform == TargetPlatform.windows ? 560 : width,
                  child: CategoryCard(
                    categories: [
                      ('Food', BigInt.from(831750)),
                      ('Bills', BigInt.from(2500)),
                    ],
                    amount: amount,
                    caption: '1–28 Oct',
                    onOpen: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        for (final (i, name) in ['Food', 'Bills'].indexed) {
          final row = find.byKey(ValueKey('category-$i'));
          final label = tester.getRect(
            find.descendant(of: row, matching: find.text(name)),
          );
          final share = tester.getRect(
            find.descendant(of: row, matching: find.textContaining('%')),
          );
          final money = tester.getRect(
            find.descendant(of: row, matching: find.byType(MoneyAmount)),
          );
          final right = share.expandToInclude(money);
          expect(
            label.center.dy,
            moreOrLessEquals(right.center.dy, epsilon: .5),
            reason: '$platform $name',
          );
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('a legend row selects its section too', (tester) async {
      await pumpCard(tester);
      await tester.tap(find.byKey(const ValueKey('category-2')));
      await tester.pump();
      showing('Fees', '10.0%', '₱1.00');
      expect(
        tester
            .widget<PieChart>(find.byType(PieChart))
            .data
            .sections
            .map((s) => s.radius),
        [Space.lg, Space.lg, Space.lg + Space.xs],
      );
    });
  });

  testWidgets('payoff card: a paid-off debt is Settled with a full bar', (
    tester,
  ) async {
    await pump(
      tester,
      DebtProgressCard(
        debts: [
          DebtProgress(
            debt,
            DebtDueSummary(schedule, const [], today, 7),
            BigInt.zero,
          ),
        ],
        amount: amount,
        onOpen: () {},
      ),
    );
    expect(pill('Settled'), findsOneWidget);
    expect(find.text('All 3 payments logged'), findsOneWidget);
    // The pill sits on the name’s line, not under it.
    expect(
      (tester.getCenter(pill('Settled')).dy -
              tester.getCenter(find.text(debt.title)).dy)
          .abs(),
      lessThan(Space.sm),
    );
    final bar = tester.widget<SegmentBar>(find.byType(SegmentBar));
    expect((bar.done, bar.total), (3, 3));
    await pump(
      tester,
      DebtProgressCard(debts: const [], amount: amount, onOpen: () {}),
    );
    expect(find.text('No debts yet'), findsOneWidget);
  });

  group('owner review helpers', () {
    test('changes and shares are whole basis points, rounded toward zero', () {
      expect(changeBasisPoints(BigInt.from(110), BigInt.from(100)), 1000);
      expect(changeBasisPoints(BigInt.from(90), BigInt.from(100)), -1000);
      expect(changeBasisPoints(BigInt.from(1), BigInt.from(3)), -6666);
      expect(changeBasisPoints(BigInt.one, BigInt.zero), isNull);
      // Nothing then and nothing now is no change, not "New".
      expect(changeBasisPoints(BigInt.zero, BigInt.zero), 0);
      expect(percentLabel(-6666), '66.6%');
      expect(percentLabel(42), '0.4%');
      expect(shareBasisPoints(BigInt.one, BigInt.from(3)), 3333);
      expect(shareBasisPoints(BigInt.one, BigInt.zero), isNull);
      expect(ChangeLine.spoken(1000, 'vs 1–28 Sep'), 'Up 10.0% vs 1–28 Sep');
      expect(
        ChangeLine.spoken(null, 'vs 1–28 Sep'),
        'No earlier amount vs 1–28 Sep',
      );
    });

    test('category shares keep the top five and group the rest', () {
      final many = [
        for (var i = 7; i > 0; i--) ('C$i', BigInt.from(i * 100)),
        ('Refunded', BigInt.from(-50)),
      ];
      final shares = categoryShares(many);
      expect(shares.map((s) => s.$1), ['C7', 'C6', 'C5', 'C4', 'C3', 'Other']);
      expect(shares.last.$2, BigInt.from(300));
      expect(categoryShares(many.take(6).toList()), hasLength(6));
    });

    test('budget totals skip zero limits', () {
      final totals = budgetTotals([
        BudgetProgress(revision('a', 'budget', const {}), BigInt.from(480000)),
        BudgetProgress(
          LocalRevision(
            id: 'z',
            actionId: 'z',
            kind: 'budget',
            change: 'create',
            date: today,
            title: 'Zero',
            amount: BigInt.zero,
            values: const {},
            postings: const [],
            number: 1,
          ),
          BigInt.from(100),
        ),
      ]);
      expect(totals.limit, BigInt.from(960000));
      expect(totals.spent, BigInt.from(480000));
      expect(totals.basisPoints, 5000);
      expect(budgetTotals(const []).basisPoints, isNull);
    });
  });

  group('demo sample', () {
    // Week and month edges, a year end and both kinds of February.
    final days = [
      for (
        var d = '2026-10-24';
        d.compareTo('2026-11-09') <= 0;
        d = addCivilDays(d, 1)
      )
        d,
      '2026-12-31', '2027-01-01', '2027-02-28', '2027-03-01', //
      '2028-02-28', '2028-02-29', '2028-03-01',
    ];
    test('replays through the real rules on any day', () {
      for (final day in days) {
        final s = demoOverviewSnapshot(day);
        final ids = [for (final a in s.accounts) a.id];
        expect(ids, hasLength(4), reason: day);
        for (final id in ids) {
          for (final b in balanceByDay(s, [id], addCivilDays(day, -69), day)) {
            expect(b.$2 >= BigInt.zero, isTrue, reason: '$day $id ${b.$1}');
          }
        }
        expect(
          balanceByDay(s, ids, day, day).single.$2,
          sumMinor(ids.map((id) => s.balance(id, through: day))),
        );
        // Today the accounts hold the demo balances, as Money shows them.
        expect(
          [for (final id in ids) phpDecimal(s.balance(id, through: day))],
          ['1250.00', '24850.50', '3200.25', '0.00'],
          reason: day,
        );
        final week = OverviewDues.from(
          overviewDueSources(s, day),
          day,
          DuePeriod.week,
        );
        expect(week.overdue.map((i) => i.days), contains(-3), reason: day);
        final progress = overviewDebtProgress(s, day);
        expect(progress.map((p) => p.statusLabel), contains('Settled'));
        expect(progress.map((p) => p.statusLabel), contains('Overdue'));
        expect(activeBudgets(s, day), hasLength(5));
        final cards = CardsSummary(cardRows(s, day));
        expect(cards.cards, hasLength(3));
        expect(cards.cards.any((c) => c.over > BigInt.zero), isTrue);
        expect(cards.credit, BigInt.from(30000));
        expect(cardDues(s, day).any((d) => d.statement), isTrue);
        expect(cardDues(s, day).any((d) => !d.statement), isTrue);
        final goals = goalRows(s, day).map((g) => g.funding).toSet();
        expect(goals, contains(GoalFunding.funded));
        expect(goals, contains(GoalFunding.shared));
        expect(goals, contains(GoalFunding.partly));
        expect(recurringRows(s, day), hasLength(5));
        expect(upcomingRows(s, day).any((r) => r.expected), isTrue);
        expect(spendingBetween(s, monthStart(day), day) > BigInt.zero, isTrue);
      }
      expect(demoOverviewSnapshot(today, empty: true).accounts, isEmpty);
    });
  });

  group('dashboard', () {
    Future<void> show(
      WidgetTester tester,
      PrototypeSession session, {
      required TargetPlatform platform,
      required double width,
      double text = 1,
      Brightness brightness = Brightness.light,
    }) async {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          // No theme animation: each case renders its platform at once.
          themeAnimationDuration: Duration.zero,
          theme: SalapiyaTheme.build(brightness, platform: platform),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 2400),
              textScaler: TextScaler.linear(text),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(Space.lg),
                // A fresh dashboard each time, so it starts on Summary.
                child: OverviewDashboard(
                  key: UniqueKey(),
                  session: session,
                  open: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> everyTab(WidgetTester tester, String label) async {
      for (final tab in OverviewTab.values) {
        await tester.ensureVisible(find.byKey(ValueKey(tab)));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey(tab)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '$label ${tab.label}');
      }
    }

    testWidgets('the demo sample fills every tab on both platforms', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      for (final (platform, width, text) in [
        (TargetPlatform.android, 320.0, 1.0),
        (TargetPlatform.android, 360.0, 2.0),
        (TargetPlatform.android, 412.0, 1.0),
        (TargetPlatform.windows, 720.0, 1.0),
        (TargetPlatform.windows, 1200.0, 1.0),
        (TargetPlatform.windows, 1440.0, 1.0),
        (TargetPlatform.windows, 1440.0, 2.0),
      ]) {
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
          expect(find.byType(InsightsCard), findsOneWidget);
          await everyTab(tester, '$platform $width $text $brightness');
        }
      }
      // The last tab is Accounts & Activity: three accounts and the card.
      expect(find.byType(AccountMiniCard), findsNWidgets(4));
    });

    testWidgets('spending and debts tabs show the donut, gauge and steps', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        platform: TargetPlatform.windows,
        width: 1440,
      );
      await tester.tap(find.byKey(const ValueKey(OverviewTab.spending)));
      await tester.pump();
      expect(find.text('Top category'), findsOneWidget);
      expect(find.byKey(const ValueKey('budget-gauge')), findsOneWidget);
      expect(find.text('Largest expenses this month'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey(OverviewTab.debts)));
      await tester.pump();
      expect(find.byType(SegmentBar), findsNWidgets(5));
      expect(pill('Settled'), findsOneWidget);
      expect(find.textContaining('3 days overdue'), findsWidgets);
      // Bar steps are drawn 8 tall, not collapsed to nothing.
      final steps = find.descendant(
        of: find.byType(SegmentBar),
        matching: find.byType(DecoratedBox),
      );
      expect(steps, findsWidgets);
      for (final step in steps.evaluate()) {
        expect(step.size!.height, Space.sm);
      }
      // The payoff table's middle column starts at the same x on every row,
      // whatever each row's amount.
      final lines = find.textContaining(RegExp(r'payments? logged'));
      expect({
        for (final e in lines.evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dx,
      }, hasLength(1));
      // What you owe: the figures and each debt's share.
      expect(find.byKey(const ValueKey('owed-stats')), findsOneWidget);
      expect(find.text('By debt'), findsOneWidget);

      // The Accounts tab's activity table: every Category cell lines up.
      await tester.tap(find.byKey(const ValueKey(OverviewTab.accounts)));
      await tester.pump();
      final table = find.byKey(const ValueKey('overview-activity'));
      final xs = {
        for (final name in ['Food & drink', 'Transport', 'Groceries', 'Bills'])
          for (final e
              in find
                  .descendant(of: table, matching: find.text(name))
                  .evaluate())
            tester.getTopLeft(find.byWidget(e.widget)).dx,
      };
      expect(xs, hasLength(1));
    });

    testWidgets('KPI values line up across tiles, whichever labels wrap', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      double valueTop(String key) => tester
          .getTopLeft(
            find.descendant(
              of: find.byKey(ValueKey('overview-$key')),
              matching: find.byType(MoneyAmount),
            ),
          )
          .dy;
      for (final (platform, width, rows) in [
        (
          TargetPlatform.android,
          412.0,
          [
            ['available', 'spent'],
            ['income', 'owed'],
          ],
        ),
        (
          TargetPlatform.windows,
          1440.0,
          [
            ['available', 'spent', 'income', 'owed'],
          ],
        ),
      ]) {
        await show(tester, session, platform: platform, width: width);
        for (final row in rows) {
          expect(
            {for (final key in row) valueTop(key)},
            hasLength(1),
            reason: '$platform $row',
          );
        }
      }
      // Wide tiles reserve no extra line: one-line labels stay one line.
      final label = tester.getSize(find.text('What you owe'));
      final line = tester.getSize(find.text('Available money'));
      expect(label.height, line.height);
    });

    testWidgets('Android header: the date and a dues pill on one row', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      // The test font is much wider than Geist, and would wrap a long month.
      await show(tester, session, platform: TargetPlatform.android, width: 640);
      final date = tester.getRect(find.byKey(const ValueKey('overview-date')));
      final pill = find.byKey(const ValueKey('overview-dues-pill'));
      expect(date.height, Space.target);
      // The demo always has something overdue this week.
      expect(
        find.descendant(of: pill, matching: find.text('1 overdue')),
        findsOneWidget,
      );
      expect(tester.getCenter(pill).dy, moreOrLessEquals(date.center.dy));
      final tabs = tester.getRect(find.byKey(const ValueKey('overview-tabs')));
      expect(tabs.top - date.bottom, Space.xs);
      await tester.tap(pill);
      await tester.pump();
      expect(find.text('Debt payoff'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('quick actions end at the content edge, beside the title', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: SalapiyaTheme.build(
            Brightness.light,
            platform: TargetPlatform.windows,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(Space.lg),
              child: OverviewDashboard(
                session: session,
                open: (_) {},
                actions: [
                  for (final label in ['Log expense', 'Log income'])
                    (label: label, icon: Icons.add, onSelected: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final quick = tester.getRect(
        find.byKey(const ValueKey('overview-quick-actions')),
      );
      final tabs = tester.getRect(find.byKey(const ValueKey('overview-tabs')));
      final title = tester.getRect(find.text('Overview'));
      expect(quick.right, moreOrLessEquals(tabs.right, epsilon: .5));
      expect(quick.top, lessThan(tabs.top));
      expect(quick.top, lessThan(title.bottom + Space.xl));
    });

    testWidgets('a shorter Spending card centers its content in the row', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        platform: TargetPlatform.windows,
        width: 1440,
      );
      await tester.tap(find.byKey(const ValueKey(OverviewTab.spending)));
      await tester.pump();
      // Space above and below each card's content, under its header.
      (double, double) gaps(String key, Finder content, String caption) {
        final card = find.byKey(ValueKey(key));
        final box = tester.getRect(card);
        final body = tester.getRect(
          find.ancestor(of: content, matching: find.byType(Row)).first,
        );
        final head = tester.getRect(
          find.descendant(of: card, matching: find.textContaining(caption)),
        );
        final inset =
            Space.cardPaddingOf(tester.element(card)) +
            Border.all(color: const Color(0x00000000)).dimensions.vertical / 2;
        return (
          body.top - (head.bottom + Space.md),
          box.bottom - inset - body.bottom,
        );
      }

      expect(
        tester.getSize(find.byKey(const ValueKey('overview-budgets'))).height,
        tester
            .getSize(find.byKey(const ValueKey('overview-categories')))
            .height,
      );
      final budgets = gaps(
        'overview-budgets',
        find.byKey(const ValueKey('budget-gauge')),
        'Active budgets',
      );
      final categories = gaps(
        'overview-categories',
        find.byType(OverviewDonut),
        'refunds subtracted',
      );
      for (final (above, below) in [budgets, categories]) {
        expect(above, moreOrLessEquals(below, epsilon: 1));
      }
    });

    testWidgets('a centered card beside a taller one centers its content', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: SalapiyaTheme.build(
            Brightness.light,
            platform: TargetPlatform.windows,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardGrid(
                cards: const [
                  (
                    OverviewCard(
                      key: ValueKey('short'),
                      title: 'Short',
                      centered: true,
                      child: SizedBox(key: ValueKey('body'), height: 40),
                    ),
                    6,
                    6,
                  ),
                  (SizedBox(height: 400), 6, 6),
                ],
                stacked: const [],
              ),
            ),
          ),
        ),
      );
      final card = tester.getRect(find.byKey(const ValueKey('short')));
      final body = tester.getRect(find.byKey(const ValueKey('body')));
      final title = tester.getRect(find.text('Short'));
      final inset =
          Space.cardPaddingOf(
            tester.element(find.byKey(const ValueKey('short'))),
          ) +
          Border.all(color: const Color(0x00000000)).dimensions.vertical / 2;
      expect(card.height, 400);
      final above = body.top - (title.bottom + Space.md);
      final below = card.bottom - inset - body.bottom;
      expect(above, greaterThan(Space.xxxl));
      expect(above, moreOrLessEquals(below, epsilon: 1));
    });

    testWidgets('the Summary spending card shows its figures', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        platform: TargetPlatform.windows,
        width: 1440,
      );
      final stats = find.byKey(const ValueKey('spending-stats'));
      expect(stats, findsOneWidget);
      for (final label in [
        'Highest day',
        'Days with spending',
        'Top category',
        'Last month by now',
      ]) {
        expect(
          find.descendant(of: stats, matching: find.text(label)),
          findsOneWidget,
        );
      }
    });

    testWidgets('activity lists close by saying how many more there are', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await show(
        tester,
        session,
        platform: TargetPlatform.windows,
        width: 1440,
      );
      ListEnd end(String card) => tester.widget<ListEnd>(
        find.descendant(
          of: find.byKey(ValueKey(card)),
          matching: find.byType(ListEnd),
        ),
      );
      // The same count Money's Activity gives, five of them shown here.
      final today = civilToday();
      final sample = demoSample(today);
      final logged = moneyActivity(
        sample,
        (id) =>
            sample.categories.where((c) => c.id == id).firstOrNull?.name ??
            '',
      ).where((r) => r.date.compareTo(today) <= 0).length;
      expect(
        end('overview-recent').label,
        '${logged - 5} more in Activity',
      );
      expect(end('overview-recent').onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey(OverviewTab.spending)));
      await tester.pump();
      expect(
        end('overview-largest').label,
        matches(r'^\d+ more expenses? in Activity$'),
      );
    });

    testWidgets('hidden amounts, an incomplete download and an empty profile', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      session.togglePrivacy();
      await show(
        tester,
        session,
        platform: TargetPlatform.windows,
        width: 1440,
      );
      expect(find.byType(Sparkline), findsNothing);
      expect(find.byType(ChangeLine), findsNothing);
      expect(find.text('Amounts hidden'), findsWidgets);
      await everyTab(tester, 'hidden');
      session.togglePrivacy();

      session.select(OverviewScenario.incomplete);
      await show(tester, session, platform: TargetPlatform.android, width: 360);
      expect(find.text('Your first download isn’t finished'), findsOneWidget);
      expect(find.text('Not available yet'), findsWidgets);
      await everyTab(tester, 'incomplete');

      session.select(OverviewScenario.empty);
      await show(tester, session, platform: TargetPlatform.android, width: 360);
      await everyTab(tester, 'empty');
      expect(find.text('No accounts yet'), findsOneWidget);
    });
  });
}
