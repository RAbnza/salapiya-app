import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/prototype/scenarios.dart';

/// README and portfolio screenshots from the synthetic demo, rendered on
/// the Windows host with bundled fonts. The Android layout comes from the
/// platform override at phone width. Run from apps/salapiya with
/// `--dart-define=SCREENSHOT_DIR=` set to an absolute output folder:
///
/// `flutter test integration_test/readme_screenshots_test.dart -d windows`
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('README screenshots', (tester) async {
    const dirName = String.fromEnvironment('SCREENSHOT_DIR');
    expect(dirName, isNotEmpty, reason: 'pass --dart-define=SCREENSHOT_DIR');
    final output = Directory(dirName)..createSync(recursive: true);
    final boundary = GlobalKey();

    Future<void> settle() async {
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name, double pixelRatio) async {
      await settle();
      expect(tester.takeException(), isNull, reason: name);
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${output.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }

    Future<void> open(AppDestination destination) async {
      final control = find.byKey(ValueKey('nav-${destination.name}'));
      if (control.evaluate().isEmpty) {
        await tester.tap(find.byKey(const ValueKey('shell-destinations')));
        await settle();
        await tester.tap(find.byKey(ValueKey('choose-${destination.name}')));
      } else {
        await tester.tap(control.first);
      }
      await settle();
    }

    for (final android in [false, true]) {
      debugDefaultTargetPlatformOverride = android
          ? TargetPlatform.android
          : TargetPlatform.windows;
      await binding.setSurfaceSize(
        android ? const Size(412, 915) : const Size(1440, 900),
      );
      final prefix = android ? 'android' : 'windows';
      final ratio = android ? 2.0 : 1.5;
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        final settings = GallerySettings()..themeMode = mode;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: SalapiyaApp(settings: settings, session: PrototypeSession()),
          ),
        );
        await settle();
        for (final destination in AppDestination.values) {
          await open(destination);
          await capture('$prefix-${mode.name}-${destination.name}', ratio);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await settle();
        settings.dispose();
      }
    }
    debugDefaultTargetPlatformOverride = null;
    await binding.setSurfaceSize(null);
  });
}
