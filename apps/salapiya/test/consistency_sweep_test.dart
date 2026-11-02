import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/prototype/scenarios.dart';

import 'shell_parity_test.dart' show key, shellOf;

// Chat 16's five-second question: does every screen follow the same rules?
// The source checks hold real-use code to §3 and §4 (tokens, no legacy
// colors, no older kit). The sweep opens the shell and every section's
// first tab on both platforms, at every width, both text sizes and all four
// themes, and checks nothing overflows and every button a screen reader
// reaches can be pressed. Each section's own sweep covers its other tabs.

/// The real-use code: the production paths of DESIGN_SYSTEM's scope, and
/// the section frames that still live under `lib/features`.
const realUsePaths = [
  'lib/app',
  'lib/finance',
  'lib/shared',
  'lib/life',
  'lib/local',
  'lib/connected',
  'lib/design_system',
  'lib/profile',
  'lib/onboarding',
  'lib/features/finance/presentation/money_screen.dart',
  'lib/features/finance/presentation/debts_screen.dart',
  'lib/features/finance/presentation/shared_screen.dart',
  'lib/features/finance/presentation/financial_review.dart',
  'lib/features/life/presentation/life_screen.dart',
];

/// Files in those paths that only the demo build and the gallery use.
const demoOrGallery = {
  'lib/app/demo_routes.dart',
  'lib/app/previews.dart',
  'lib/design_system/components.dart',
  'lib/design_system/craft.dart',
  'lib/design_system/editorial.dart',
  'lib/design_system/workspace.dart',
  'lib/design_system/kit/component_gallery.dart',
};

/// OS or provider-branding values, defined in one place (§4).
const branding = {
  'lib/design_system/theme.dart',
  'lib/design_system/kit/provider_sign_in.dart',
};

List<File> realUseFiles() => [
  for (final path in realUsePaths)
    if (FileSystemEntity.isDirectorySync(path))
      ...Directory(path)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
    else
      File(path),
].where((f) => !demoOrGallery.contains(_path(f))).toList();

String _path(File f) => f.path.replaceAll('\\', '/');

/// Every match of [pattern] in real-use code, as "file:line: text".
List<String> hits(RegExp pattern, {bool Function(String match)? allowed}) => [
  for (final f in realUseFiles())
    for (final (i, line) in f.readAsLinesSync().indexed)
      for (final m in pattern.allMatches(line))
        if (!(allowed?.call(m[0]!) ?? false))
          '${_path(f)}:${i + 1}: ${line.trim()}',
];

/// Rows of a screen that a screen reader reaches as a button but can't
/// press: `Semantics(excludeSemantics: true)` over a `Pressable` drops the
/// tap unless the `Semantics` has its own `onTap` (§1 principle 9).
Set<String> unpressable(WidgetTester tester) {
  final found = <String>{};
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    final flags = data.flagsCollection;
    if (flags.isButton &&
        !flags.isHidden &&
        flags.isEnabled.toBoolOrNull() != false &&
        !data.hasAction(SemanticsAction.tap)) {
      found.add(data.label.isEmpty ? '(no label)' : data.label);
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return found;
}

void main() {
  testWidgets('the tap check catches a button it can’t press', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Semantics(
              button: true,
              label: 'Dropped',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox.square(dimension: 48),
              ),
            ),
            Semantics(
              button: true,
              label: 'Kept',
              container: true,
              excludeSemantics: true,
              onTap: () {},
              child: const SizedBox.square(dimension: 48),
            ),
          ],
        ),
      ),
    );
    expect(unpressable(tester), {'Dropped'});
    semantics.dispose();
  });

  group('source', () {
    test(
      'real-use code takes sizes, spacing, radii and colors from tokens',
      () {
        // The §4 grep. A match is allowed when its only number is 0.
        final literal = RegExp(
          r'EdgeInsets\.[a-zA-Z]+\([^)]*[0-9]|SizedBox\((height|width): [0-9]|BorderRadius\.circular\([0-9]|fontSize: [0-9]|Color\(0x',
        );
        final numbers = RegExp(r'(?<![\w.])\d+(\.\d+)?');
        final found = hits(
          literal,
          allowed: (m) =>
              !m.startsWith('Color(') &&
              numbers.allMatches(m).every((n) => double.parse(n[0]!) == 0),
        ).where((h) => !branding.any(h.startsWith));
        expect(found, isEmpty);
      },
    );

    test('real-use code uses no legacy colors (§3)', () {
      final legacy = RegExp(
        r'Palette\.|(?<!Colors)\.(warm|plum|blue|focalStart|focalEnd|latticeEdge)\b',
      );
      expect(
        hits(legacy)
            .where((h) => !h.startsWith('lib/design_system/theme.dart')),
        isEmpty,
      );
    });

    test('real-use code imports none of the older kit (§5)', () {
      final older = RegExp(
        r"import '[^']*(components|workspace|editorial|form_presentation)\.dart'",
      );
      expect(hits(older), isEmpty);
    });
  });

  for (final (platform, width) in const [
    (TargetPlatform.android, 320.0),
    (TargetPlatform.android, 360.0),
    (TargetPlatform.android, 412.0),
    (TargetPlatform.windows, 720.0),
    (TargetPlatform.windows, 1200.0),
    (TargetPlatform.windows, 1440.0),
  ]) {
    testWidgets('the shell and every first tab at $width', (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final settings = GallerySettings();
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tester.pumpWidget(
        SalapiyaApp(settings: settings, session: session),
      );
      await tester.pumpAndSettle();
      final unpressed = <String, Set<String>>{};

      Future<void> look(String where) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: where);
        for (final label in unpressable(tester)) {
          unpressed.putIfAbsent(label, () => {}).add(where);
        }
      }

      for (final text in [1.0, 2.0]) {
        for (final theme in [ThemeMode.light, ThemeMode.dark]) {
          for (final contrast in [false, true]) {
            settings.change(() {
              settings.textScale = text;
              settings.themeMode = theme;
            });
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                FakeAccessibilityFeatures(highContrast: contrast);
            final state =
                '$width ${text}x ${theme.name}${contrast ? ' high contrast' : ''}';
            for (final destination in AppDestination.values) {
              shellOf(tester).select(destination);
              await look('${destination.name} $state');
            }
            // Profile and settings, the one entry that isn't a destination.
            // Where it sits follows the width class, which large text drops.
            final profile = [
              key('shell-settings'),
              find.byTooltip('Settings'),
              key('shell-profile'),
            ].firstWhere((f) => f.evaluate().isNotEmpty);
            await tester.tap(profile.first);
            await look('profile $state');
            shellOf(tester).select(AppDestination.overview);
            await tester.pumpAndSettle();
          }
        }
      }
      semantics.dispose();
      expect({
        for (final e in unpressed.entries)
          e.key: '${e.value.length} views, e.g. ${e.value.first}',
      }, isEmpty);
    }, variant: TargetPlatformVariant.only(platform));
  }
}
