import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/kit/review.dart';

import 'shell_journey.dart' show newItem;

void main() {
  testWidgets(
    'desktop commands replace the floating dock and remain keyboard accessible',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const SalapiyaApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('floating-dock-surface')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('shell-new')));
      await tester.pumpAndSettle();
      expect(newItem('Log a transfer'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(newItem('Log a transfer'), findsNothing);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'failed protected draft save prevents exit; successful retry closes without posting',
    (tester) async {
      var fail = true, writes = 0;
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: SalapiyaTheme.build(Brightness.light),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => FormExitGuard(
            dirty: true,
            busy: false,
            keepDraft: () async {
              writes++;
              if (fail) throw StateError('Synthetic storage failure');
            },
            child: const Scaffold(body: Text('Unposted form')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await nav.currentState!.maybePop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      await nav.currentState!.maybePop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep draft & close'));
      await tester.pumpAndSettle();
      expect(find.text('Unposted form'), findsOneWidget);
      expect(writes, 1);
      fail = false;
      await nav.currentState!.maybePop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep draft & close'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(writes, 2);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('leaving a form with no draft is a destructive confirmation', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        theme: SalapiyaTheme.build(Brightness.light),
        home: const Scaffold(body: Text('Home')),
      ),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const FormExitGuard(
          dirty: true,
          busy: false,
          child: Scaffold(body: Text('Unposted form')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await nav.currentState!.maybePop();
    await tester.pumpAndSettle();
    // §5: the kit's dialog, a red main action, focus on the safe choice.
    expect(find.text('Discard your changes?'), findsOneWidget);
    final discard = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Discard changes'),
    );
    expect(discard.variant, AppButtonVariant.destructive);
    final keep = find.widgetWithText(AppButton, 'Keep editing');
    expect(tester.widget<AppButton>(keep).autofocus, isTrue);
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
