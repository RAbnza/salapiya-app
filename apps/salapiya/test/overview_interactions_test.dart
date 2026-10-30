import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/app/overview_dashboard.dart';
import 'package:salapiya/app/overview_controls.dart';
import 'package:salapiya/prototype/activity.dart';
import 'package:salapiya/prototype/fixtures.dart';
import 'package:salapiya/prototype/scenarios.dart';

import 'shell_journey.dart';

void main() {
  testWidgets('demo Overview: tabs and links open their section and return', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SalapiyaApp());
    await tester.pumpAndSettle();
    expect(find.byType(OverviewDashboard), findsOneWidget);
    expect(find.byType(KpiTile), findsNWidgets(4));
    await tapVisible(tester, find.byKey(const ValueKey(OverviewTab.accounts)));
    expect(find.byType(AccountMiniCard), findsNWidgets(4));
    expect(find.text('₱1,250.00'), findsOneWidget);
    await tapVisible(tester, find.text('Cash wallet'));
    expect(find.text('Accounts'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(OverviewDashboard), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey(OverviewTab.spending)));
    expect(find.text('Top category'), findsOneWidget);
    await tapVisible(tester, find.text('View report'));
    expect(find.text('Reports'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey(OverviewTab.debts)));
    await tapVisible(tester, find.text('View debts'));
    expect(find.byType(OverviewDashboard), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(OverviewDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('synthetic weekly activity reconciles to liquid balances exactly', () {
    expect(DemoActivity.incoming, BigInt.from(1800000));
    expect(DemoActivity.outgoing, BigInt.from(474600));
    expect(DemoActivity.opening, BigInt.from(1604675));
    expect(
      DemoActivity.opening + DemoActivity.incoming - DemoActivity.outgoing,
      DemoMoney.liquid,
    );
    expect(
      DemoActivity.categories.fold(
        BigInt.zero,
        (sum, name) => sum + DemoActivity.categoryTotal(name),
      ),
      DemoActivity.outgoing,
    );
    expect(
      [for (var d = 15; d <= 21; d++) DemoActivity.spentOn(d)]
          .reduce((a, b) => a + b),
      DemoActivity.outgoing,
    );
  });

  testWidgets('demo Overview: hidden amounts and an incomplete download', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = PrototypeSession();
    await tester.pumpWidget(SalapiyaApp(session: session));
    await tester.pumpAndSettle();
    expect(find.text('₱29,300.75'), findsOneWidget);
    session.togglePrivacy();
    await tester.pumpAndSettle();
    expect(find.text('₱29,300.75'), findsNothing);
    expect(find.text('Amounts hidden'), findsWidgets);
    session.togglePrivacy();
    session.select(OverviewScenario.incomplete);
    await tester.pumpAndSettle();
    expect(find.text('Your first download isn’t finished'), findsOneWidget);
    expect(find.text('₱29,300.75'), findsNothing);
    session.select(OverviewScenario.pending);
    await tester.pumpAndSettle();
    expect(find.textContaining('₱29,115.25'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
