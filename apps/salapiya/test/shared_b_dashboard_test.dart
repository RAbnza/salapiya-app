import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/finance/presentation/shared_screen.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/prototype/scenarios.dart';
import 'package:salapiya/shared/shared_demo.dart';
import 'package:salapiya/shared/shared_domain.dart';
import 'package:salapiya/shared/shared_hub.dart';
import 'package:salapiya/shared/shared_people_data.dart';
import 'package:salapiya/shared/shared_person_pages.dart';
import 'package:salapiya/shared/shared_private_data.dart';
import 'package:salapiya/shared/shared_record_page.dart';

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
    double height = 4200,
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

  SharedHub hubFor(PrototypeSession session, {String? group}) {
    final hub = SharedHub(session)..selected = group ?? demoHouseholdId;
    addTearDown(hub.dispose);
    return hub;
  }

  /// The section's frame on [tab], for the group at [index] in the sample.
  Future<void> tab(
    WidgetTester tester,
    PrototypeSession session,
    String name, {
    required TargetPlatform platform,
    required double width,
    double text = 1,
    Brightness brightness = Brightness.light,
    int index = 0,
  }) {
    final hub = hubFor(
      session,
      group: session.empty ? null : demoSharedGroups(civilToday())[index].id,
    );
    return app(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: SharedScreen(session: session, hub: hub, initial: name),
          ),
        ),
      ),
      platform: platform,
      width: width,
      text: text,
      brightness: brightness,
    );
  }

  SharedGroup sample(int index) => demoSharedGroups(civilToday())[index];

  /// A page with the whole height in view.
  Future<void> page(
    WidgetTester tester,
    PrototypeSession session,
    Widget Function(SharedHub hub) build, {
    required TargetPlatform platform,
    required double width,
    double text = 1,
    Brightness brightness = Brightness.light,
  }) => app(
    tester,
    build(hubFor(session)),
    platform: platform,
    width: width,
    text: text,
    brightness: brightness,
  );

  group('sweep', () {
    for (final (platform, width) in sizes) {
      for (final text in [1.0, 2.0]) {
        for (final brightness in Brightness.values) {
          testWidgets(
            'Balances at ${platform.name} $width, ${text * 100}% text, ${brightness.name}',
            (tester) async {
              final session = PrototypeSession();
              addTearDown(session.dispose);
              await tab(
                tester,
                session,
                'Balances',
                platform: platform,
                width: width,
                text: text,
                brightness: brightness,
              );
              expect(tester.takeException(), isNull);
              expect(find.text('Who owes whom'), findsOneWidget);
              expect(find.text('Where everyone stands'), findsOneWidget);
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
            'pages at ${platform.name} $width, ${text * 100}% text, ${brightness.name}',
            (tester) async {
              final session = PrototypeSession();
              addTearDown(session.dispose);
              final g = sample(0);
              final me = g.participant(demoActor)!;
              final other = sharedMembers(g, me)[1].person;
              for (final build in <Widget Function(SharedHub)>[
                (hub) => SharedPairPage(hub: hub, group: g.id, a: me, b: other),
                (hub) => SharedPairPage(
                  hub: hub,
                  group: g.id,
                  a: me,
                  b: other,
                  list: true,
                ),
                (hub) =>
                    SharedPersonPage(hub: hub, group: g.id, person: other),
                (hub) => SharedPersonPage(
                  hub: hub,
                  group: g.id,
                  person: other,
                  list: true,
                ),
                (hub) => SharedWhoOwesPage(hub: hub, group: g.id),
              ]) {
                await page(
                  tester,
                  session,
                  build,
                  platform: platform,
                  width: width,
                  text: text,
                  brightness: brightness,
                );
                expect(tester.takeException(), isNull);
              }
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
            await tab(
              tester,
              session,
              'Balances',
              platform: platform,
              width: width,
              text: text,
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
        await tab(
          tester,
          session,
          'Balances',
          platform: platform,
          width: width,
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('₱'), findsNothing);
        final g = sample(0);
        final me = g.participant(demoActor)!;
        final other = sharedMembers(g, me)[1].person;
        for (final build in <Widget Function(SharedHub)>[
          (hub) => SharedPairPage(hub: hub, group: g.id, a: me, b: other),
          (hub) => SharedPersonPage(hub: hub, group: g.id, person: other),
          (hub) => SharedWhoOwesPage(hub: hub, group: g.id),
        ]) {
          await page(tester, session, build, platform: platform, width: width);
          expect(tester.takeException(), isNull);
          expect(find.textContaining('₱'), findsNothing);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });

  group('My Records', () {
    for (final (platform, width) in sizes) {
      for (final text in [1.0, 2.0]) {
        for (final brightness in Brightness.values) {
          testWidgets(
            'at ${platform.name} $width, ${text * 100}% text, ${brightness.name}',
            (tester) async {
              final session = PrototypeSession();
              addTearDown(session.dispose);
              await tab(
                tester,
                session,
                'My Records',
                platform: platform,
                width: width,
                text: text,
                brightness: brightness,
              );
              expect(tester.takeException(), isNull);
              expect(find.text('Check against my records'), findsOneWidget);
              expect(find.text('This group and me'), findsOneWidget);
              final hub = SharedHub(session)..selected = demoHouseholdId;
              addTearDown(hub.dispose);
              final source = hub.source();
              final g = source.groups.first;
              for (final kind in PrivateKind.values) {
                final row = privateRows(
                  g,
                  g.participant(demoActor),
                  source.current,
                  source.reviews,
                  source.today,
                ).firstWhere((r) => r.kind == kind);
                await page(
                  tester,
                  session,
                  (hub) => SharedRecordPage(
                    hub: hub,
                    group: g.id,
                    kind: kind,
                    id: row.id,
                  ),
                  platform: platform,
                  width: width,
                  text: text,
                  brightness: brightness,
                );
                expect(tester.takeException(), isNull);
              }
              await tester.pumpWidget(const SizedBox.shrink());
            },
          );
        }
      }
    }

    for (final scenario in [
      OverviewScenario.empty,
      OverviewScenario.incomplete,
      OverviewScenario.review,
    ]) {
      for (final (platform, width) in const [
        (android, 320.0),
        (windows, 1200.0),
      ]) {
        testWidgets('${scenario.name} at ${platform.name}', (tester) async {
          final session = PrototypeSession()..select(scenario);
          addTearDown(session.dispose);
          await tab(
            tester,
            session,
            'My Records',
            platform: platform,
            width: width,
          );
          expect(tester.takeException(), isNull);
          if (scenario == OverviewScenario.incomplete) {
            expect(find.textContaining('₱'), findsNothing);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }

    for (final (platform, width) in sizes) {
      testWidgets('hidden amounts at ${platform.name} $width', (tester) async {
        final session = PrototypeSession()..togglePrivacy();
        addTearDown(session.dispose);
        await tab(
          tester,
          session,
          'My Records',
          platform: platform,
          width: width,
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('₱'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('a group you left lists only your own records', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(
        tester,
        session,
        'My Records',
        platform: windows,
        width: 1200,
        index: 3,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Nothing to check yet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the two figures sit side by side, with no difference', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session, 'My Records', platform: windows, width: 1440);
      expect(find.text('The group says'), findsOneWidget);
      expect(find.text('My records say'), findsWidgets);
      expect(find.textContaining('Difference'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the tiles’ values line up', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session, 'My Records', platform: windows, width: 1440);
      final tops = [
        for (final key in const [
          'records-needs',
          'records-added',
          'records-not-added',
          'records-says',
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
      ];
      expect(tops.toSet().length, 1, reason: '$tops');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the demo opens a placeholder, not a private form', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final hub = SharedHub(session)..selected = demoHouseholdId;
      addTearDown(hub.dispose);
      expect(hub.private, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('states', () {
    testWidgets('an incomplete download never shows ₱', (tester) async {
      final session = PrototypeSession()..select(OverviewScenario.incomplete);
      addTearDown(session.dispose);
      await tab(tester, session, 'Balances', platform: windows, width: 1200);
      expect(find.textContaining('₱'), findsNothing);
      expect(
        find.text('This shows once your records are complete.'),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a group you left reads Not available yet, with no ₱', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(
        tester,
        session,
        'Balances',
        platform: windows,
        width: 1200,
        index: 3,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.text('You’ve left this group, so these figures aren’t complete.'),
        findsWidgets,
      );
      expect(find.textContaining('₱'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('an archived group shows balances with nothing to log', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(
        tester,
        session,
        'Balances',
        platform: windows,
        width: 1200,
        index: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Log payment'), findsNothing);
      expect(find.text('All square'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a group of one offers Add someone', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(
        tester,
        session,
        'Balances',
        platform: android,
        width: 360,
        index: 4,
      );
      expect(find.text('Just you so far'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('balances-add-someone')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('someone who left keeps their balance on their page', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final g = sample(0);
      final rosa = sharedMembers(
        g,
        g.participant(demoActor),
      ).firstWhere((m) => !m.active);
      await page(
        tester,
        session,
        (hub) => SharedPersonPage(hub: hub, group: g.id, person: rosa.person),
        platform: windows,
        width: 1200,
      );
      expect(find.text('Left'), findsWidgets);
      expect(find.text('They owe the group'), findsOneWidget);
      expect(find.textContaining(RegExp('Moved.out.in.September')), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a deleted account reads plainly and keeps its balance', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(
        tester,
        session,
        'Balances',
        platform: windows,
        width: 1200,
        index: 1,
      );
      expect(find.text('Deleted account'), findsWidgets);
      expect(find.text('Deleted participant'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('suggestions', () {
    testWidgets('a dispute pauses them and says why', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session, 'Balances', platform: windows, width: 1200);
      expect(
        find.text('Paused while a payment is disputed'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('they read as a proposal, and never as the fewest payments', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(
        tester,
        session,
        'Balances',
        platform: windows,
        width: 1200,
        index: 1,
      );
      expect(
        find.text('A proposal. Nothing changes until someone logs a payment.'),
        findsOneWidget,
      );
      expect(find.textContaining('fewest'), findsNothing);
      expect(find.textContaining('Minimum'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('only a direct row the user can log has a link', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final g = sample(1);
      final me = g.participant(demoActor)!;
      await tab(
        tester,
        session,
        'Balances',
        platform: windows,
        width: 1200,
        index: 1,
      );
      final (_, rows) = sharedSuggestions(g);
      expect(rows, isNotEmpty);
      for (final s in rows) {
        expect(
          find.byKey(ValueKey('suggestion-log-${s.recipient}')).evaluate().isNotEmpty,
          s.direct && canLogFor(g, s.sender, me),
          reason: '${s.sender} → ${s.recipient}',
        );
        if (!s.direct) {
          expect(
            find.textContaining('Everyone involved needs to agree first.'),
            findsWidgets,
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('alignment', () {
    testWidgets('the tiles’ values line up', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session, 'Balances', platform: windows, width: 1440);
      final tops = [
        for (final key in const [
          'shared-standing',
          'balances-you-owe',
          'balances-owed-to-you',
          'balances-waiting',
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
      ];
      expect(tops.toSet().length, 1, reason: '$tops');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a pair’s amounts share their columns', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final g = sample(0);
      final me = g.participant(demoActor)!;
      final other = sharedMembers(g, me)[1].person;
      await page(
        tester,
        session,
        (hub) => SharedPairPage(hub: hub, group: g.id, a: me, b: other),
        platform: windows,
        width: 1200,
      );
      final rights = [
        for (final e in find
            .descendant(
              of: find.byKey(const ValueKey('pair-table')),
              matching: find.byType(MoneyAmount),
            )
            .evaluate())
          tester.getTopRight(find.byWidget(e.widget)).dx,
      ]..sort();
      expect(rights, isNotEmpty);
      // Two columns: every amount ends on one of two edges.
      expect(rights.toSet().length, 2, reason: '$rights');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('exact figures', () {
    testWidgets('the page’s total is the rules’ figure for the pair', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final g = sample(0);
      final me = g.participant(demoActor)!;
      final other = sharedMembers(g, me)[1].person;
      await page(
        tester,
        session,
        (hub) =>
            SharedPairPage(hub: hub, group: g.id, a: me, b: other, list: true),
        platform: windows,
        width: 1200,
      );
      final due = g.due(me, other);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pair-total')),
          matching: find.text(session.amount(due.abs())),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
