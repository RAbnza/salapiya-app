import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/app/shell.dart';
import 'package:salapiya/app/shell_navigation.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/finance/presentation/shared_screen.dart';
import 'package:salapiya/finance/money_details.dart' show isFormDraft;
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/local/local_runtime.dart';
import 'package:salapiya/local/local_store.dart';
import 'package:salapiya/prototype/scenarios.dart';
import 'package:salapiya/shared/shared_cards.dart';
import 'package:salapiya/shared/shared_data.dart';
import 'package:salapiya/shared/shared_demo.dart';
import 'package:salapiya/shared/shared_hub.dart';
import 'package:salapiya/shared/shared_pages.dart';

import 'local_money_journey.dart';
import 'local_test_support.dart';

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

  /// The section with a group open. [choose] leaves it to the section.
  Future<void> section(
    WidgetTester tester,
    PrototypeSession session, {
    required TargetPlatform platform,
    required double width,
    double text = 1,
    Brightness brightness = Brightness.light,
    SharedHub? hub,
    String tab = 'Bills',
    bool choose = false,
  }) {
    var used = hub;
    if (used == null) {
      used = SharedHub(session);
      if (!choose) used.selected = demoHouseholdId;
      addTearDown(used.dispose);
    }
    return app(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: SharedScreen(session: session, hub: used, initial: tab),
          ),
        ),
      ),
      platform: platform,
      width: width,
      text: text,
      brightness: brightness,
    );
  }

  group('sweep', () {
    for (final (platform, width) in sizes) {
      for (final text in [1.0, 2.0]) {
        for (final brightness in Brightness.values) {
          testWidgets(
            'Bills at ${platform.name} $width, ${text * 100}% text, ${brightness.name}',
            (tester) async {
              final session = PrototypeSession();
              addTearDown(session.dispose);
              await section(
                tester,
                session,
                platform: platform,
                width: width,
                text: text,
                brightness: brightness,
              );
              expect(tester.takeException(), isNull);
              expect(find.text('Where you stand'), findsOneWidget);
              expect(find.text('Household'), findsWidgets);
              await tester.pumpWidget(const SizedBox.shrink());
            },
          );
        }
      }
    }

    for (final (platform, width) in sizes) {
      for (final text in [1.0, 2.0]) {
        for (final brightness in Brightness.values) {
          testWidgets(
            'Payments at ${platform.name} $width, ${text * 100}% text, ${brightness.name}',
            (tester) async {
              final session = PrototypeSession();
              addTearDown(session.dispose);
              await section(
                tester,
                session,
                platform: platform,
                width: width,
                text: text,
                brightness: brightness,
                tab: 'Payments',
              );
              expect(tester.takeException(), isNull);
              expect(find.text('Waiting to be confirmed'), findsOneWidget);
              expect(find.text('Between you and others'), findsOneWidget);
              await tester.pumpWidget(const SizedBox.shrink());
            },
          );
        }
      }
    }

    for (final (platform, width) in sizes) {
      for (final text in [1.0, 2.0]) {
        for (final brightness in Brightness.values) {
          testWidgets(
            'chooser at ${platform.name} $width, ${text * 100}% text, ${brightness.name}',
            (tester) async {
              final session = PrototypeSession();
              addTearDown(session.dispose);
              await section(
                tester,
                session,
                platform: platform,
                width: width,
                text: text,
                brightness: brightness,
                choose: true,
              );
              expect(tester.takeException(), isNull);
              expect(find.text('Boracay trip'), findsOneWidget);
              await tester.pumpWidget(const SizedBox.shrink());
            },
          );
        }
      }
    }

    for (final scenario in [
      OverviewScenario.empty,
      OverviewScenario.incomplete,
      OverviewScenario.pending,
      OverviewScenario.review,
      OverviewScenario.waiting,
    ]) {
      for (final (platform, width) in const [
        (android, 320.0),
        (windows, 1200.0),
      ]) {
        for (final text in [1.0, 2.0]) {
          testWidgets('${scenario.name} at ${platform.name} $width, $text', (
            tester,
          ) async {
            final session = PrototypeSession()..select(scenario);
            addTearDown(session.dispose);
            await section(
              tester,
              session,
              platform: platform,
              width: width,
              text: text,
            );
            expect(tester.takeException(), isNull);
            await section(
              tester,
              session,
              platform: platform,
              width: width,
              text: text,
              tab: 'Payments',
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          });
        }
      }
    }

    for (final (platform, width) in sizes) {
      testWidgets('hidden amounts at ${platform.name} $width', (tester) async {
        final session = PrototypeSession()..togglePrivacy();
        addTearDown(session.dispose);
        await section(tester, session, platform: platform, width: width);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('₱'), findsNothing);
        expect(find.text('Amounts hidden'), findsOneWidget);
        await section(
          tester,
          session,
          platform: platform,
          width: width,
          tab: 'Payments',
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('₱'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });

  group('states', () {
    testWidgets('an incomplete download never shows ₱', (tester) async {
      final session = PrototypeSession()..select(OverviewScenario.incomplete);
      addTearDown(session.dispose);
      await section(tester, session, platform: windows, width: 1200);
      expect(find.textContaining('₱'), findsNothing);
      expect(find.text('Your first download isn’t finished'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('no groups offers Create and Join', (tester) async {
      final session = PrototypeSession()..select(OverviewScenario.empty);
      addTearDown(session.dispose);
      await section(tester, session, platform: windows, width: 1200);
      expect(find.byKey(const ValueKey('shared-empty')), findsOneWidget);
      expect(find.text('Create a group'), findsOneWidget);
      expect(find.text('Join with a code'), findsOneWidget);
      expect(find.byKey(const ValueKey('shared-tabs')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a waiting bill and a refused one show where they apply', (
      tester,
    ) async {
      final pending = PrototypeSession()..select(OverviewScenario.pending);
      addTearDown(pending.dispose);
      await section(tester, pending, platform: windows, width: 1440);
      expect(find.text('1 change is waiting for the group.'), findsOneWidget);
      expect(find.text('Birthday cake'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());

      final review = PrototypeSession()..select(OverviewScenario.review);
      addTearDown(review.dispose);
      await section(tester, review, platform: windows, width: 1440);
      expect(
        find.text(
          'The group changed while you were working. Check it and try again.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('offline says what still works', (tester) async {
      final session = PrototypeSession()..select(OverviewScenario.waiting);
      addTearDown(session.dispose);
      await section(tester, session, platform: android, width: 360);
      expect(find.text('You’re offline'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a one-member group asks for someone', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = SharedHub(session)..selected = demoNewGroupId;
      addTearDown(hub.dispose);
      await section(tester, session, platform: windows, width: 1200, hub: hub);
      expect(find.text('Just you so far'), findsOneWidget);
      expect(find.text('Log a payment between members'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a group the user left shows earlier records and no totals', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = SharedHub(session)
        ..selected = demoSharedGroups(civilToday())[3].id;
      addTearDown(hub.dispose);
      await section(tester, session, platform: windows, width: 1200, hub: hub);
      expect(tester.takeException(), isNull);
      expect(find.text('Move-out cleaning'), findsOneWidget);
      expect(find.text('Not available yet'), findsWidgets);
      expect(find.text('Add shared expense'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the Windows switcher shows each group’s standing', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await section(tester, session, platform: windows, width: 1200);
      await tester.tap(find.byKey(const ValueKey('shared-switcher')));
      await tester.pump();
      expect(find.text('Boracay trip'), findsOneWidget);
      expect(find.textContaining('You owe ₱'), findsOneWidget);
      expect(find.text('You’ve left this group'), findsOneWidget);
      expect(find.text('Join with a code'), findsOneWidget);
      await tester.tap(find.text('Boracay trip'));
      await tester.pumpAndSettle();
      expect(find.text('Hotel, two nights'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the Android switcher is a sheet', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await section(tester, session, platform: android, width: 360);
      expect(find.text('1 to confirm'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shared-switcher')));
      await tester.pumpAndSettle();
      expect(find.text('Your groups'), findsOneWidget);
      await tester.tap(find.text('Boracay trip'));
      await tester.pumpAndSettle();
      expect(find.text('Hotel, two nights'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('payments', () {
    Future<PrototypeSession> open(WidgetTester tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await section(
        tester,
        session,
        platform: windows,
        width: 1440,
        tab: 'Payments',
      );
      return session;
    }

    testWidgets('the tab answers who paid whom and what’s waiting', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('To confirm'), findsWidgets);
      expect(find.text('Waiting for others'), findsOneWidget);
      expect(find.text('Confirmed this month'), findsOneWidget);
      expect(find.text('If all are confirmed'), findsOneWidget);
      final waiting = find.byKey(const ValueKey('shared-waiting'));
      expect(
        find.descendant(of: waiting, matching: find.text('Tala → You')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: waiting, matching: find.text('Confirm')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: waiting, matching: find.byType(ListEnd)),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('filters narrow the list, and each state has a name', (
      tester,
    ) async {
      await open(tester);
      final table = find.byKey(const ValueKey('shared-payments-table'));
      await tester.tap(find.byKey(const ValueKey('payment-filter-disputed')));
      await tester.pump();
      expect(
        find.descendant(of: table, matching: find.text('Disputed')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: table, matching: find.text('Confirmed')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('payment-filter-closed')));
      await tester.pump();
      expect(
        find.descendant(of: table, matching: find.text('Cancelled')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: table, matching: find.text('Reversed')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('payment amounts share one measured column', (tester) async {
      await open(tester);
      final amounts = find.descendant(
        of: find.byKey(const ValueKey('shared-payments-table')),
        matching: find.byType(MoneyAmount),
      );
      expect(amounts, findsWidgets);
      expect(
        {
          for (final e in amounts.evaluate())
            tester.getTopRight(find.byWidget(e.widget)).dx,
        }.length,
        1,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a link in a row ends flush with the amount above it', (
      tester,
    ) async {
      await open(tester);
      final waiting = find.byKey(const ValueKey('shared-waiting'));
      final amount = tester.getTopRight(
        find.descendant(of: waiting, matching: find.byType(MoneyAmount)).first,
      );
      final link = tester.getTopRight(
        find.descendant(of: waiting, matching: find.text('Confirm')),
      );
      expect(link.dx, closeTo(amount.dx, 1));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('someone who owes gets Log payment, someone owed doesn’t', (
      tester,
    ) async {
      await open(tester);
      final pairs = find.byKey(const ValueKey('shared-pairs'));
      expect(
        find.descendant(of: pairs, matching: find.text('Log payment')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pairs, matching: find.textContaining('owes you')),
        findsWidgets,
      );
      expect(
        find.descendant(of: pairs, matching: find.text('See Balances')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a group with no payments says so on every card', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = SharedHub(session)..selected = demoNewGroupId;
      addTearDown(hub.dispose);
      await section(
        tester,
        session,
        platform: windows,
        width: 1200,
        hub: hub,
        tab: 'Payments',
      );
      expect(find.text('Nothing waiting'), findsNWidgets(3));
      expect(find.text('All square'), findsWidgets);
      expect(find.text('No payments yet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('offline, a row offers no Confirm that would fail', (
      tester,
    ) async {
      final session = PrototypeSession()..select(OverviewScenario.waiting);
      addTearDown(session.dispose);
      await section(
        tester,
        session,
        platform: windows,
        width: 1200,
        tab: 'Payments',
      );
      expect(find.text('Confirm'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Confirm in a row asks first, with what’s applied', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm you received it'), findsOneWidget);
      expect(find.textContaining('Tala logged'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('alignment', () {
    testWidgets('bill amounts share one measured column', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await section(tester, session, platform: windows, width: 1440);
      final table = find.byKey(const ValueKey('shared-bills-table'));
      final amounts = find.descendant(
        of: table,
        matching: find.byType(MoneyAmount),
      );
      expect(amounts, findsWidgets);
      final rights = <double>{
        for (final e in amounts.evaluate().take(2))
          tester.getTopRight(find.byWidget(e.widget)).dx,
      };
      final all = <double>{
        for (final e in amounts.evaluate())
          tester.getTopRight(find.byWidget(e.widget)).dx,
      };
      expect(all.length, rights.length);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the attention list starts at the top and closes', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await section(tester, session, platform: windows, width: 1440);
      final card = find.byKey(const ValueKey('shared-attention'));
      final title = find.descendant(
        of: card,
        matching: find.text('Needs your attention'),
      );
      final row = find.descendant(of: card, matching: find.text('Gas refill'));
      expect(
        tester.getTopLeft(row).dy - tester.getBottomLeft(title).dy,
        lessThan(Space.xxxl),
      );
      expect(
        find.descendant(of: card, matching: find.byType(ListEnd)),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('tiles in the set keep their values on one line', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await section(tester, session, platform: windows, width: 1200);
      final tops = {
        for (final key in const [
          'shared-standing',
          'shared-part',
          'shared-spending',
          'shared-needs',
        ])
          tester
              .getTopLeft(
                find
                    .descendant(
                      of: find.byKey(ValueKey(key)),
                      matching: find.byType(MoneyAmount),
                    )
                    .first,
              )
              .dy,
      };
      expect(tops.length, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('who paid columns line up, whatever each amount’s length', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await section(tester, session, platform: windows, width: 1440);
      final table = find.byKey(const ValueKey('shared-who-paid-table'));
      final amounts = find.descendant(
        of: table,
        matching: find.byType(MoneyAmount),
      );
      final rights = {
        for (final e in amounts.evaluate())
          tester.getTopRight(find.byWidget(e.widget)).dx,
      };
      expect(rights.length, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('pages', () {
    Future<void> page(
      WidgetTester tester,
      Widget child, {
      TargetPlatform platform = windows,
      double width = 1200,
      double text = 1,
    }) async {
      await app(tester, child, platform: platform, width: width, text: text);
      await tester.pump();
    }

    for (final (platform, width) in sizes) {
      testWidgets('bill and group pages at ${platform.name} $width', (
        tester,
      ) async {
        final session = PrototypeSession();
        addTearDown(session.dispose);
        final hub = SharedHub(session);
        addTearDown(hub.dispose);
        final g = hub.source().groups.first;
        final me = g.participant(demoActor);
        final corrected = sharedBillRows(g, me).firstWhere((r) => r.corrected);
        for (final text in [1.0, 2.0]) {
          await page(
            tester,
            SharedBillPage(hub: hub, group: g.id, bill: corrected.id),
            platform: platform,
            width: width,
            text: text,
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Corrected'), findsOneWidget);
          expect(find.text('Earlier version'), findsOneWidget);
          await page(
            tester,
            SharedGroupPage(hub: hub, group: g.id),
            platform: platform,
            width: width,
            text: text,
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Where everyone stands'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    for (final (platform, width) in sizes) {
      testWidgets('payment and shareable pages at ${platform.name} $width', (
        tester,
      ) async {
        final session = PrototypeSession();
        addTearDown(session.dispose);
        final hub = SharedHub(session);
        addTearDown(hub.dispose);
        final g = hub.source().groups.first;
        final me = g.participant(demoActor);
        final rows = sharedPaymentRows(g, me, civilToday());
        final bill = sharedBillRows(g, me).firstWhere((r) => r.refunds > 0);
        for (final text in [1.0, 2.0]) {
          for (final p in rows) {
            await page(
              tester,
              SharedPaymentPage(hub: hub, group: g.id, payment: p.id),
              platform: platform,
              width: width,
              text: text,
            );
            expect(tester.takeException(), isNull);
          }
          for (final child in <Widget>[
            SharedBillsPage(hub: hub, group: g.id),
            SharedPaymentsPage(hub: hub, group: g.id),
            SharedSplitPage(hub: hub, group: g.id, bill: bill.id),
          ]) {
            await page(
              tester,
              child,
              platform: platform,
              width: width,
              text: text,
            );
            expect(tester.takeException(), isNull);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('a payment offers only what the rules allow you', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = SharedHub(session);
      addTearDown(hub.dispose);
      final g = hub.source().groups.first;
      final me = g.participant(demoActor);
      final rows = sharedPaymentRows(g, me, civilToday());
      SharedPaymentRow row(PaymentStatus status) =>
          rows.firstWhere((p) => p.status == status);
      Future<void> open(PaymentStatus status) => page(
        tester,
        SharedPaymentPage(hub: hub, group: g.id, payment: row(status).id),
      );
      await open(PaymentStatus.toConfirm);
      expect(find.text('Confirm you received it'), findsOneWidget);
      expect(find.text('Dispute this payment'), findsOneWidget);
      expect(find.text('Cancel this payment'), findsNothing);
      expect(find.text('If it’s confirmed'), findsOneWidget);
      await open(PaymentStatus.waiting);
      expect(find.text('Cancel this payment'), findsOneWidget);
      expect(find.text('Confirm you received it'), findsNothing);
      await open(PaymentStatus.confirmed);
      expect(find.text('Undo confirmation'), findsOneWidget);
      await open(PaymentStatus.cancelled);
      expect(find.text('Undo confirmation'), findsNothing);
      expect(find.text('Cancel this payment'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a confirmed-by-owner payment says who didn’t sign in', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = SharedHub(session);
      addTearDown(hub.dispose);
      final g = hub.source().groups.first;
      final manual = sharedPaymentRows(
        g,
        g.participant(demoActor),
        civilToday(),
      ).firstWhere((p) => p.manual);
      await page(
        tester,
        SharedPaymentPage(hub: hub, group: g.id, payment: manual.id),
      );
      expect(find.textContaining('didn’t sign in'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a shareable list has its period, the totals and every row', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = SharedHub(session);
      addTearDown(hub.dispose);
      final g = hub.source().groups.first;
      await page(tester, SharedBillsPage(hub: hub, group: g.id));
      expect(find.text('Total shared'), findsOneWidget);
      expect(find.textContaining('As of '), findsOneWidget);
      await tester.tap(find.text('All dates'));
      await tester.pump();
      for (final r in sharedBillRows(g, g.participant(demoActor))) {
        expect(find.text(r.name), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a bill page lists what the old dialog printed raw', (
      tester,
    ) async {
      final session = PrototypeSession()..togglePrivacy();
      addTearDown(session.dispose);
      final hub = SharedHub(session);
      addTearDown(hub.dispose);
      final g = hub.source().groups.first;
      final me = g.participant(demoActor);
      final refunded = sharedBillRows(g, me).firstWhere((r) => r.refunds > 0);
      await page(
        tester,
        SharedBillPage(hub: hub, group: g.id, bill: refunded.id),
      );
      expect(find.text('Returned the balloons'), findsOneWidget);
      expect(find.textContaining('₱'), findsNothing);
      expect(find.textContaining('10000000-'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('only the creator can change a bill', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = SharedHub(session);
      addTearDown(hub.dispose);
      final g = hub.source().groups.first;
      final me = g.participant(demoActor);
      final rows = sharedBillRows(g, me);
      await page(
        tester,
        SharedBillPage(
          hub: hub,
          group: g.id,
          bill: rows.firstWhere((r) => r.name == 'Water bill').id,
        ),
      );
      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Log a refund'), findsOneWidget);
      await page(
        tester,
        SharedBillPage(
          hub: hub,
          group: g.id,
          bill: rows.firstWhere((r) => r.name == 'Groceries').id,
        ),
      );
      expect(find.text('Correct'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('an equal split with a remainder names who gets it', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = SharedHub(session);
      addTearDown(hub.dispose);
      final g = hub.source().groups.first;
      final me = g.participant(demoActor);
      final market = sharedBillRows(
        g,
        me,
      ).firstWhere((r) => r.name == 'Weekly market');
      await page(
        tester,
        SharedBillPage(hub: hub, group: g.id, bill: market.id),
      );
      expect(find.textContaining('the extra goes to You'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('sidebar', () {
    testWidgets(
      'a sidebar tab keeps the group and never shows the empty state',
      (tester) async {
        debugDefaultTargetPlatformOverride = windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = (await tester.runAsync(LocalFixture.open))!;
        final settings = GallerySettings();
        final runtime = LocalRuntime(
          LocalProfiles(f.directory, MemoryProfileVault()),
          settings,
        );
        final actor = newLocalId();
        final first = '00000000-0000-4000-8000-00000000000a';
        final second = '00000000-0000-4000-8000-00000000000b';
        final me = newLocalId();
        String document(String id, String name) => jsonEncode({
          'id': id,
          'name': name,
          'owner': me,
          'version': 1,
          'complete': true,
          'archived': false,
          'people': {
            me: {
              'name': 'Owner',
              'user': actor,
              'active': true,
              'kind': 'registered',
            },
          },
          'bills': <String, dynamic>{},
          'settlements': <String, dynamic>{},
          'activity': const <dynamic>[],
        });
        try {
          await tester.runAsync(() async {
            await f.store.stageConnection(
              actor,
              'synthetic@example.test',
              newLocalId(),
            );
            await f.store.db.execute(
              "UPDATE connected_profile SET phase='connected'",
            );
            for (final (id, name) in [
              (first, 'Alpha group'),
              (second, 'Beta group'),
            ]) {
              await f.store.db.execute(
                'INSERT INTO p3_group(id,owner_id,group_id,version,document) VALUES(?,?,?,?,?)',
                ['$id:$actor', actor, id, 1, document(id, name)],
              );
            }
            await runtime.activate(f.store);
          });
          await tester.pumpWidget(
            SalapiyaApp(
              production: true,
              settings: settings,
              localRuntime: runtime,
            ),
          );
          await localSettle(tester);
          await localTap(tester, find.byKey(const ValueKey('nav-shared')));
          final switcher = find.byKey(const ValueKey('shared-switcher'));
          final betaCard = find.text('Beta group');
          await localWait(tester, () => betaCard.evaluate().isNotEmpty);
          // New offers both actions on the real build; they used to be empty.
          await localTap(tester, find.byKey(const ValueKey('shell-new')));
          expect(find.text('Add shared expense'), findsWidgets);
          expect(find.text('Log a payment between members'), findsWidgets);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await localSettle(tester);
          await localTap(tester, betaCard);
          await localWait(tester, () => switcher.evaluate().isNotEmpty);
          expect(
            find.descendant(of: switcher, matching: find.text('Beta group')),
            findsOneWidget,
          );
          // The sidebar's tab, not the page's: the shell rebuilds the section.
          final sidebarTab = find.byKey(const ValueKey('nav-shared-Balances'));
          await tester.tap(sidebarTab);
          // Every frame after the tap: the empty state used to flash here.
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(find.byKey(const ValueKey('shared-empty')), findsNothing);
            expect(find.byKey(const ValueKey('shared-loading')), findsNothing);
          }
          expect(
            find.descendant(of: switcher, matching: find.text('Beta group')),
            findsOneWidget,
            reason: 'The chosen group stays chosen.',
          );
          expect(tester.takeException(), isNull);

          // The breadcrumb names the group and goes back to choosing.
          final crumb = find.descendant(
            of: find.byType(ShellBreadcrumb),
            matching: find.text('Beta group'),
          );
          expect(crumb, findsOneWidget);
          await localTap(
            tester,
            find.descendant(
              of: find.byType(ShellBreadcrumb),
              matching: find.text('Shared Expenses'),
            ),
          );
          expect(
            find.byKey(const ValueKey('shared-group-chooser')),
            findsOneWidget,
          );

          // The default is saved with the profile, and another setting
          // saving afterwards doesn't lose it.
          final session = runtime.session!;
          session.sharedDefaultGroup = first;
          settings.change(() {});
          settings.change(() => settings.compact = !settings.compact);
          Map<String, String>? saved;
          final reading = runtime
              .flushPreferences()
              .then((_) => f.store.preferences())
              .then((values) => saved = values);
          for (var i = 0; i < 300 && saved == null; i++) {
            await tester.pump(const Duration(milliseconds: 20));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
          }
          await reading;
          expect(saved!['sharedDefaultGroup'], first);
        } finally {
          debugDefaultTargetPlatformOverride = null;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          var closed = false;
          final closing = (() async {
            await runtime.close();
            runtime.dispose();
            settings.dispose();
            await f.close();
          })().whenComplete(() => closed = true);
          for (var i = 0; i < 300 && !closed; i++) {
            await tester.pump(const Duration(milliseconds: 20));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
          }
          expect(closed, isTrue);
          await closing;
        }
      },
    );
  });

  group('choosing a group', () {
    Future<(PrototypeSession, SharedHub)> open(
      WidgetTester tester, {
      void Function(SharedHub)? before,
      TargetPlatform platform = windows,
      String tab = 'Bills',
    }) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = SharedHub(session);
      addTearDown(hub.dispose);
      before?.call(hub);
      await section(
        tester,
        session,
        platform: platform,
        width: platform == windows ? 1200 : 360,
        hub: hub,
        tab: tab,
      );
      return (session, hub);
    }

    final chooser = find.byKey(const ValueKey('shared-group-chooser'));
    final tabs = find.byKey(const ValueKey('shared-tabs'));

    testWidgets('several groups ask first, each with where you stand', (
      tester,
    ) async {
      await open(tester);
      expect(chooser, findsOneWidget);
      expect(tabs, findsNothing);
      expect(find.text('Choose a group'), findsOneWidget);
      expect(find.text('Create a group'), findsOneWidget);
      expect(find.text('Join with a code'), findsOneWidget);
      expect(find.text('1 to confirm'), findsOneWidget);
      expect(find.text('Archived or left'), findsOneWidget);
      expect(find.text('You’re owed'), findsOneWidget);
      expect(find.text('You owe'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('choosing one opens it, on the tab that was asked for', (
      tester,
    ) async {
      await open(tester, tab: 'Payments');
      await tester.tap(find.text('Household'));
      await tester.pumpAndSettle();
      expect(chooser, findsNothing);
      expect(tabs, findsOneWidget);
      expect(find.text('Waiting to be confirmed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a chosen group stays until the user asks to see them all', (
      tester,
    ) async {
      final (_, hub) = await open(
        tester,
        before: (hub) => hub.choose(demoHouseholdId),
      );
      expect(chooser, findsNothing);
      await tester.tap(find.byKey(const ValueKey('shared-switcher')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See all groups'));
      await tester.pumpAndSettle();
      expect(chooser, findsOneWidget);
      expect(hub.selected, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the default opens by itself, and See all groups still asks', (
      tester,
    ) async {
      final (_, hub) = await open(
        tester,
        before: (hub) => hub.setDefault(demoHouseholdId),
      );
      expect(chooser, findsNothing);
      expect(find.text('Where you stand'), findsOneWidget);
      hub.showChooser();
      await tester.pumpAndSettle();
      expect(chooser, findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a default that can’t be used falls back to asking', (
      tester,
    ) async {
      for (final id in ['gone', demoSharedGroups(civilToday())[2].id]) {
        await open(tester, before: (hub) => hub.setDefault(id));
        expect(chooser, findsOneWidget, reason: id);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('the menu sets and clears the default without opening it', (
      tester,
    ) async {
      final (session, hub) = await open(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('group-menu-$demoHouseholdId')),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make this my default'));
      await tester.pumpAndSettle();
      expect(session.sharedDefaultGroup, demoHouseholdId);
      expect(hub.selected, isNull);
      hub.showChooser();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('group-menu-$demoHouseholdId')),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop opening this first'));
      await tester.pumpAndSettle();
      expect(session.sharedDefaultGroup, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('an only active group opens by itself, whatever else is listed', () {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = SharedHub(session);
      addTearDown(hub.dispose);
      final all = hub.source().groups;
      SharedSource only(Iterable<int> keep) => SharedSource(
        today: civilToday(),
        groups: [for (final i in keep) all[i]],
        loaded: true,
        connected: true,
        online: true,
        complete: true,
        hidden: false,
        amount: (v) => '$v',
        writer: const DemoSharedWriter(),
        profileName: 'Amihan',
        actor: demoActor,
      );
      // Household, plus an archived group and one the user left.
      expect(hub.group(only([0, 2, 3]))?.id, all[0].id);
      expect(hub.group(only([0])), isNotNull);
      // Nothing active but one old group: that one still opens.
      expect(hub.group(only([3]))?.id, all[3].id);
      expect(hub.group(only([0, 1])), isNull);
      expect(hub.group(only([2, 3])), isNull);
      expect(hub.group(only(const [])), isNull);
    });

    testWidgets('Android asks too, with Create and Join below the groups', (
      tester,
    ) async {
      await open(tester, platform: android);
      expect(chooser, findsOneWidget);
      expect(find.byKey(const ValueKey('chooser-create')), findsOneWidget);
      expect(find.byKey(const ValueKey('chooser-join')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a payment from New asks which group when none is open', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = SharedHub(session);
      addTearDown(hub.dispose);
      await app(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => SharedFlows(hub).startPayment(context),
              child: const Text('Open'),
            ),
          ),
        ),
        platform: windows,
        width: 1200,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Which group?'), findsOneWidget);
      expect(find.text('Reunion 2025'), findsNothing);
      await tester.tap(find.text('Household'));
      await tester.pumpAndSettle();
      expect(find.text('Log a payment between members'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('landing', () {
    Widget demoApp(PrototypeSession session) => MaterialApp(
      themeAnimationDuration: Duration.zero,
      theme: SalapiyaTheme.build(Brightness.light, platform: windows),
      home: SalapiyaShell(settings: GallerySettings(), session: session),
    );

    testWidgets('a confirm count lands on the group that has one', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = SharedHub(session);
      addTearDown(hub.dispose);
      final other = hub.source().groups[1].id;
      hub.choose(other);
      hub.focusWaiting();
      expect(hub.selected, demoHouseholdId);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a linked record opens its bill, in its group', (tester) async {
      debugDefaultTargetPlatformOverride = windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tester.pumpWidget(demoApp(session));
      await tester.pumpAndSettle();
      final shell = tester.state<State>(find.byType(SalapiyaShell));
      final linked = demoLinkedBill(civilToday());
      await SharedFlows(
        SharedScope.maybeOf(
          tester.element(find.byType(SharedScreen, skipOffstage: false)),
        )!,
      ).openLinked(
        tester.element(find.byType(SharedScreen, skipOffstage: false)),
        {
          'sharedGroup': linked.group,
          'sharedKey': linked.bill,
          'sharedMode': 'bill',
        },
      );
      await tester.pumpAndSettle();
      expect(shell.mounted, isTrue);
      expect(find.text('How it was split'), findsOneWidget);
      expect(find.text('Water bill'), findsWidgets);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  test('a shared purchase’s link row isn’t a draft to finish', () {
    expect(isFormDraft({'operation': 'shared-purchase:abc'}), isFalse);
    expect(isFormDraft({'operation': 'expense:'}), isTrue);
  });

  test('card helpers read plainly', () {
    expect(monthHeading('2026-10-31'), 'October 2026');
    final row = SharedPaymentRow(
      id: 'p',
      sender: 'a',
      recipient: 'b',
      from: 'You',
      to: 'Maria',
      date: '2026-10-30',
      amount: BigInt.one,
      status: PaymentStatus.waiting,
      role: PaymentRole.sender,
      applied: const {},
      ahead: BigInt.zero,
    );
    expect(paymentStatusLabel(row), 'Waiting for Maria');
  });
}
