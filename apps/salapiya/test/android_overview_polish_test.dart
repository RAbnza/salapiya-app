import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/app/overview_dashboard.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/features/finance/presentation/financial_editor.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/local/local_runtime.dart';

import 'local_money_journey.dart' show localSettle, localTap, localWait;
import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Geist',
    )..addFont(rootBundle.load('assets/fonts/geist/regular.ttf'))).load();
  });
  for (final android in [true, false]) {
    testWidgets(
      '${android ? 'Android' : 'Windows'} Overview presentation and expense access',
      (tester) async {
        debugDefaultTargetPlatformOverride = android
            ? TargetPlatform.android
            : TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        try {
          await overviewPolishJourney(
            tester,
            android: android,
            sweepLayouts: true,
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}

/// The same focused production checks run on the native emulator and Windows.
/// No screenshot or golden-image APIs are used.
Future<void> overviewPolishJourney(
  WidgetTester tester, {
  required bool android,
  bool sweepLayouts = false,
}) async {
  final f = (await tester.runAsync(LocalFixture.open))!;
  final settings = GallerySettings();
  final runtime = LocalRuntime(
    LocalProfiles(f.directory, MemoryProfileVault()),
    settings,
  );
  final semantics = tester.ensureSemantics();
  try {
    await tester.runAsync(() async {
      final today = civilToday();
      final cutoff = DateTime.parse(today)
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      final account = await f.account('Polish wallet', '987654321.00', cutoff);
      await f.post('expense', {
        'name': 'Polish receipt',
        'account': account,
        'date': today,
        'amount': '1234567.89',
        'category': 'category-food',
      });
      await runtime.activate(f.store);
    });
    final session = runtime.session!;
    final overview = find.byType(OverviewDashboard);
    Finder tile(String name) => find.descendant(
      of: overview,
      matching: find.byKey(ValueKey('overview-$name')),
    );
    final tiles = [
      tile('available'),
      tile('spent'),
      tile('income'),
      tile('owed'),
    ];
    String? value(Finder tile) => tester
        .widget<MoneyAmount>(
          find.descendant(of: tile, matching: find.byType(MoneyAmount)),
        )
        .text;
    Future<void> checkLayout() async {
      await tester.pumpWidget(
        SalapiyaApp(session: session, settings: settings),
      );
      await localSettle(tester);
      expect(overview, findsOneWidget);
      expect(value(tiles[0]), session.amount(session.accepted!));
      expect(value(tiles[1]), session.amount(BigInt.from(123456789)));
      expect(value(tiles[2]), session.amount(BigInt.zero));
      expect(value(tiles[3]), session.amount(BigInt.zero));
      expect(
        [for (final t in tiles) tester.widget<KpiTile>(t).caption],
        [
          'Cash and bank · card credit excluded',
          'Refunds subtracted',
          'Borrowed money isn’t income',
          'Debts through today · cards are separate',
        ],
      );
      expect(tester.widget<KpiTile>(tiles[0]).accent, isTrue);
      expect(find.byKey(const ValueKey('shell-new')), findsOneWidget);
      if (android) {
        expect(find.byKey(const ValueKey('overview-date')), findsOneWidget);
        expect(find.byType(PageHeader), findsNothing);
        // The + button above the dock replaces the header's quick actions.
        expect(
          find.byKey(const ValueKey('overview-quick-actions')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('floating-dock-surface')),
          findsOneWidget,
        );
      } else {
        expect(find.byType(PageHeader), findsOneWidget);
        expect(find.byKey(const ValueKey('overview-date')), findsNothing);
        expect(
          find.byKey(const ValueKey('overview-quick-actions')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('floating-dock-surface')),
          findsNothing,
        );
      }
      // Tiles in one row share a height, and no text leaves its tile.
      final rects = tiles.map(tester.getRect).toList();
      for (var i = 1; i < rects.length; i++) {
        if ((rects[i].top - rects[i - 1].top).abs() < .1) {
          expect(rects[i].height, closeTo(rects[i - 1].height, .1));
        }
      }
      for (final metric in tiles) {
        final bounds = tester.getRect(metric);
        for (final text
            in find
                .descendant(of: metric, matching: find.byType(Text))
                .evaluate()) {
          final finder = find.byWidget(text.widget);
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(bounds.left));
          expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + .1));
          expect(
            tester
                .renderObject<RenderParagraph>(
                  find.descendant(of: finder, matching: find.byType(RichText)),
                )
                .didExceedMaxLines,
            isFalse,
          );
        }
      }
      expect(tester.takeException(), isNull);
    }

    if (sweepLayouts) {
      for (final width in android ? [320.0, 360.0, 412.0] : [412.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 1000);
        for (final scale in android ? [1.0, 2.0] : [1.0]) {
          for (final mode in [ThemeMode.light, ThemeMode.dark]) {
            settings.change(() {
              settings.textScale = scale;
              settings.themeMode = mode;
            });
            await checkLayout();
          }
        }
      }
    } else {
      await checkLayout();
    }
    settings.change(() => settings.textScale = 1);
    await localSettle(tester);
    // The sweep queued a preference save per change. They finish on the test
    // clock, so wait for them while pumping, not inside runAsync at teardown.
    var saved = false;
    runtime.flushPreferences().then((_) => saved = true);
    await localWait(tester, () => saved);
    await localTap(tester, find.byKey(const ValueKey('shell-new')));
    final addExpense = find.text('Log expense').last;
    await tester.ensureVisible(addExpense);
    await tester.pumpAndSettle();
    // Build the native draft reader with a real I/O clock in host widget tests.
    await tester.runAsync(() async {
      await tester.tap(addExpense);
      await tester.pump();
    });
    await localSettle(tester);
    await localWait(
      tester,
      () => find.byType(FinancialEditor).evaluate().isNotEmpty,
    );
    expect(
      find.byType(FinancialEditor),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data)
          .join(' | '),
    );
    expect(find.text('Amount'), findsWidgets);
    expect(tester.takeException(), isNull);
    // Opening the editor must not post or change any financial record.
    expect(session.finance.liquid, session.accepted);
  } finally {
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await localSettle(tester);
    await tester.runAsync(runtime.flushPreferences);
    await closeWithWidgetClock(tester, runtime.close);
    runtime.dispose();
    settings.dispose();
    await closeWithWidgetClock(tester, f.close);
  }
}
