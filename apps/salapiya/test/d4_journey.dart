import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/prototype/scenarios.dart';
import 'package:salapiya/features/finance/presentation/financial_widgets.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/life/presentation/life_screen.dart';

Future<void> d4LifeJourney(WidgetTester tester) async {
  final s = PrototypeSession();
  await tester.pumpWidget(
    MaterialApp(
      theme: SalapiyaTheme.build(Brightness.light),
      home: FinancePage(
        title: 'Life',
        child: LifeScreen(session: s),
      ),
    ),
  );
  await tester.pumpAndSettle();
  for (final tab in ['Tasks', 'Learning', 'Books', 'Career', 'Calendar']) {
    await tester.ensureVisible(find.text(tab).first);
    await tester.tap(find.text(tab).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }
  await tester.ensureVisible(find.text('Tasks').first);
  await tester.tap(find.text('Tasks').first);
  await tester.pumpAndSettle();
  final check = find.byType(Checkbox).first;
  await tester.ensureVisible(check);
  await tester.tap(check);
  await tester.pumpAndSettle();
  // The demo's forms check with the real rules and keep nothing.
  expect(find.text('This is the demo, so nothing was saved.'), findsOneWidget);
  await tester.ensureVisible(find.text('Books').first);
  await tester.tap(find.text('Books').first);
  await tester.pumpAndSettle();
  final book = find.text('The Art of Noticing').first;
  await tester.ensureVisible(book);
  await tester.tap(book);
  await tester.pumpAndSettle();
  final log = find.byKey(const ValueKey('life-entry-log'));
  await tester.ensureVisible(log);
  await tester.tap(log);
  await tester.pumpAndSettle();
  final field = find.descendant(
    of: find.byKey(const ValueKey('life-field-progress')),
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, '120');
  await tester.pump();
  // Details to Review, then Review to saved.
  for (var step = 0; step < 2; step++) {
    final button = find.byKey(const ValueKey('life-submit'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
  expect(find.text('Progress saved'), findsOneWidget);
  expect(find.text('This is the demo, so nothing was saved.'), findsOneWidget);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  s.dispose();
}
