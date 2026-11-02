import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';

// The Windows compact scale (DESIGN_SYSTEM §3, Windows density): Windows is
// one step below Android; Android keeps the full scale.

Widget harness(Widget child, TargetPlatform platform, {double width = 1200}) =>
    MaterialApp(
      theme: SalapiyaTheme.build(Brightness.light, platform: platform),
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 900)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: Space.formMaxWidth, child: child),
          ),
        ),
      ),
    );

void main() {
  const windows = TargetPlatform.windows, android = TargetPlatform.android;

  test('type is one step down on Windows only', () {
    final w = SalapiyaTheme.build(Brightness.light, platform: windows);
    final a = SalapiyaTheme.build(Brightness.light, platform: android);
    (double?, double?) metric(TextStyle? s) =>
        (s?.fontSize, s == null ? null : s.fontSize! * s.height!);
    expect(metric(w.textTheme.bodyMedium), (13, 18));
    expect(metric(a.textTheme.bodyMedium), (14, 20));
    expect(metric(w.textTheme.headlineMedium), (20, 28));
    expect(metric(a.textTheme.headlineMedium), (24, 32));
    expect(metric(w.textTheme.displayMedium), (32, 40));
    expect(metric(w.textTheme.bodySmall), (12, 16));
    expect(w.iconTheme.size, Space.compactIcon);
    expect(a.iconTheme.size, isNot(Space.compactIcon));
    BorderRadiusGeometry card(ThemeData t) =>
        (t.cardTheme.shape! as RoundedRectangleBorder).borderRadius;
    expect(card(w), BorderRadius.circular(Radii.compactCard));
    expect(card(a), BorderRadius.circular(Radii.card));
  });

  testWidgets('controls are 32 tall on Windows and 48 on Android', (
    tester,
  ) async {
    for (final (platform, height) in [
      (windows, Space.pointerTarget),
      (android, Space.target),
    ]) {
      await tester.pumpWidget(
        harness(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppButton('Save', key: const Key('button'), onPressed: () {}),
              AppIconButton(
                key: const Key('icon'),
                icon: Icons.search,
                tooltip: 'Search',
                onPressed: () {},
              ),
              const HelpTextField(label: 'Name', hintText: 'Name'),
            ],
          ),
          platform,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('button'))).height, height);
      expect(tester.getSize(find.byKey(const Key('icon'))).height, height);
      // Android fields keep their taller 16 / 24 input.
      if (platform == windows) {
        expect(tester.getSize(find.byType(TextField)).height, height);
      }
    }
  });

  testWidgets('rows are 36 / 48 on Windows and 48 / 56 on Android', (
    tester,
  ) async {
    for (final (platform, one, two) in [
      (windows, Space.compactRow, Space.compactTwoLineRow),
      (android, Space.target, Space.target + Space.sm),
    ]) {
      await tester.pumpWidget(
        harness(
          const Column(
            children: [
              ListRow(key: Key('one'), title: 'Groceries', leading: Icons.home),
              ListRow(key: Key('two'), title: 'Rent', subtitle: 'Monthly'),
            ],
          ),
          platform,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('one'))).height, one);
      expect(tester.getSize(find.byKey(const Key('two'))).height, two);
    }
  });

  testWidgets('wide cards use 16 padding and 10 corners on Windows', (
    tester,
  ) async {
    for (final (platform, padding, radius) in [
      (windows, Space.lg, Radii.compactCard),
      (android, 20.0, Radii.card),
    ]) {
      await tester.pumpWidget(
        harness(const SurfaceCard(child: SizedBox(height: Space.xl)), platform),
      );
      await tester.pumpAndSettle();
      final box = tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byType(SurfaceCard),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .first;
      expect(box.padding, EdgeInsets.all(padding));
      expect(
        (box.decoration! as BoxDecoration).borderRadius,
        BorderRadius.circular(radius),
      );
    }
  });

  testWidgets('menu items are 36 tall on Windows', (tester) async {
    final menu = MenuController();
    await tester.pumpWidget(
      harness(
        MenuAnchor(
          controller: menu,
          menuChildren: [
            MenuItemButton(
              key: const Key('item'),
              leadingIcon: const Icon(Icons.add),
              onPressed: () {},
              child: const Text('Log expense'),
            ),
          ],
          child: const SizedBox.shrink(),
        ),
        windows,
      ),
    );
    menu.open();
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('item'))).height,
      Space.compactRow,
    );
  });
}
