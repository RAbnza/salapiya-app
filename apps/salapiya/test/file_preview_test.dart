import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/finance/file_access.dart';
import 'package:salapiya/finance/file_preview.dart';
import 'package:salapiya/local/finance_domain.dart';

/// One pixel.
final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  Future<void> show(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.windows,
    Size window = const Size(1600, 1000),
    double height = 400,
    ValueNotifier<String?>? problem,
  }) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        themeAnimationDuration: Duration.zero,
        theme: SalapiyaTheme.build(Brightness.light, platform: platform),
        home: Scaffold(
          body: ImagePreview(
            bytes: png,
            decodeWidth: 1,
            height: height,
            note: 'Not virus-scanned.',
            problem: problem,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  String level(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('preview-zoom-level')))
      .data!;

  Finder button(String key) => find.byKey(ValueKey(key));

  bool enabled(WidgetTester tester, String key) =>
      tester
          .widget<IconButton>(
            find.descendant(of: button(key), matching: find.byType(IconButton)),
          )
          .onPressed !=
      null;

  group('zoom', () {
    for (final platform in const [
      TargetPlatform.windows,
      TargetPlatform.android,
    ]) {
      testWidgets('works by button on $platform', (tester) async {
        await show(tester, platform: platform);
        expect(level(tester), '100%');
        await tester.tap(button('preview-zoom-in'));
        await tester.pump();
        expect(level(tester), '150%');
        await tester.tap(button('preview-zoom-in'));
        await tester.pump();
        expect(level(tester), '225%');
        await tester.tap(button('preview-zoom-out'));
        await tester.pump();
        expect(level(tester), '150%');
        await tester.tap(button('preview-zoom-fit'));
        await tester.pump();
        expect(level(tester), '100%');
      });
    }

    testWidgets('stops at its limits', (tester) async {
      await show(tester);
      expect(enabled(tester, 'preview-zoom-out'), isFalse);
      expect(enabled(tester, 'preview-zoom-fit'), isFalse);
      for (var i = 0; i < 8; i++) {
        if (!enabled(tester, 'preview-zoom-in')) break;
        await tester.tap(button('preview-zoom-in'));
        await tester.pump();
      }
      expect(level(tester), '800%');
      expect(enabled(tester, 'preview-zoom-in'), isFalse);
    });

    testWidgets('zooming back out lands exactly on the fitted image', (
      tester,
    ) async {
      await show(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(button('preview-zoom-in'));
        await tester.pump();
      }
      for (var i = 0; i < 3; i++) {
        await tester.tap(button('preview-zoom-out'));
        await tester.pump();
      }
      expect(level(tester), '100%');
      final viewer = tester.widget<InteractiveViewer>(button('preview-image'));
      expect(viewer.transformationController!.value, Matrix4.identity());
    });

    testWidgets('the mouse wheel zooms too', (tester) async {
      await show(tester);
      final viewer = tester.widget<InteractiveViewer>(button('preview-image'));
      expect(viewer.scaleEnabled, isTrue);
      expect(viewer.minScale, 1);
      expect(viewer.maxScale, 8);
    });
  });

  group('size', () {
    testWidgets('Windows gets most of the window', (tester) async {
      late ({double width, double height}) size;
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: SalapiyaTheme.build(
            Brightness.light,
            platform: TargetPlatform.windows,
          ),
          home: Builder(
            builder: (context) {
              size = previewSize(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(size.width, 1536);
      expect(size.height, 648);
    });

    testWidgets('a small window keeps the dialog’s usual width', (
      tester,
    ) async {
      late ({double width, double height}) size;
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: SalapiyaTheme.build(
            Brightness.light,
            platform: TargetPlatform.windows,
          ),
          home: Builder(
            builder: (context) {
              size = previewSize(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(size.width, Space.dialogMaxWidth);
    });

    testWidgets('it fits at every size and text scale', (tester) async {
      for (final (platform, window) in const [
        (TargetPlatform.android, Size(320, 700)),
        (TargetPlatform.android, Size(412, 900)),
        (TargetPlatform.windows, Size(720, 800)),
        (TargetPlatform.windows, Size(1440, 900)),
      ]) {
        await show(tester, platform: platform, window: window);
        expect(tester.takeException(), isNull, reason: '$platform $window');
      }
    });
  });

  testWidgets('a problem opening it shows on the preview', (tester) async {
    final problem = ValueNotifier<String?>(null);
    addTearDown(problem.dispose);
    await show(tester, problem: problem);
    expect(find.byKey(const ValueKey('preview-problem')), findsNothing);
    problem.value = 'No app on this device can open this file.';
    await tester.pump();
    expect(
      find.text('No app on this device can open this file.'),
      findsOneWidget,
    );
  });

  group('a copy’s name', () {
    test('keeps the file’s name, in safe characters', () {
      expect(openedName('5.png', 'image/png'), '5.png');
      expect(openedName('my receipt.pdf', 'application/pdf'), 'my receipt.pdf');
      expect(openedName('a&b,c;d.png', 'image/png'), 'a_b_c_d.png');
    });

    test('takes its extension from the checked type, never the name', () {
      expect(openedName('photo.exe', 'image/png'), 'photo.png');
      expect(
        openedName('invoice.pdf.bat', 'application/pdf'),
        'invoice.pdf.pdf',
      );
      expect(openedName('scan', 'image/jpeg'), 'scan.jpg');
    });

    test('a name with nothing safe in it still works', () {
      expect(openedName('', 'image/png'), 'file.png');
    });

    test('an unknown type is refused', () {
      expect(
        () => openedName('run.exe', 'application/x-msdownload'),
        throwsA(isA<LocalRuleException>()),
      );
    });
  });
}
