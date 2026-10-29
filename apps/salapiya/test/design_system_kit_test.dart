import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/kit/component_gallery.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';

const info = 'Each payment you log is matched to the earliest unpaid due date.';

Widget harness(
  Widget child, {
  TargetPlatform platform = TargetPlatform.windows,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: SalapiyaTheme.build(brightness).copyWith(platform: platform),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: SizedBox(width: Space.formMaxWidth / 2, child: child),
      ),
    ),
  ),
);

const field = HelpTextField(
  label: 'Statement date',
  helper: "The date on your lender's statement.",
  info: info,
);

Finder get infoControl => find.byType(InfoControl);

bool ringShown(WidgetTester tester) => tester
    .widget<FocusRing>(
      find.descendant(of: infoControl, matching: find.byType(FocusRing)),
    )
    .visible;

bool infoFocused() =>
    FocusManager.instance.primaryFocus?.debugLabel == 'InfoControl';

void main() {
  group('Info control', () {
    // Windows starts in traditional (pointer and keyboard) highlight mode;
    // the test binding starts in touch mode.
    void desktopHighlights() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
    }

    testWidgets('Windows: hover shows the help and leaving hides it', (
      tester,
    ) async {
      desktopHighlights();
      await tester.pumpWidget(harness(field));
      expect(find.text(info), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(infoControl));
      await tester.pumpAndSettle();
      expect(find.text(info), findsOneWidget);
      await mouse.moveTo(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(find.text(info), findsNothing);
    });

    testWidgets('Windows: keyboard focus shows the help', (tester) async {
      desktopHighlights();
      await tester.pumpWidget(harness(field));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text(info), findsOneWidget);
      expect(ringShown(tester), isTrue, reason: 'keyboard focus shows a ring');
    });

    testWidgets('Windows: a click pins it; Esc and a click outside close it', (
      tester,
    ) async {
      desktopHighlights();
      await tester.pumpWidget(harness(field));
      Future<void> click(Finder f) async {
        await tester.tap(f, kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
      }

      await click(infoControl);
      expect(find.text(info), findsOneWidget);
      expect(ringShown(tester), isFalse, reason: 'no ring after a click');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(info), findsNothing);
      expect(infoFocused(), isFalse);
      // A second click closes it and leaves no ring or focus behind.
      await click(infoControl);
      expect(find.text(info), findsOneWidget);
      await click(infoControl);
      expect(find.text(info), findsNothing);
      expect(ringShown(tester), isFalse);
      expect(infoFocused(), isFalse);
      await click(infoControl);
      await tester.tapAt(const Offset(780, 580), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.text(info), findsNothing);
      expect(ringShown(tester), isFalse);
      expect(infoFocused(), isFalse);
    });

    testWidgets('Android: a tap opens the popover; outside and Back close it', (
      tester,
    ) async {
      await tester.pumpWidget(harness(field, platform: TargetPlatform.android));
      await tester.tap(infoControl);
      await tester.pumpAndSettle();
      expect(find.text(info), findsOneWidget);
      expect(ringShown(tester), isFalse, reason: 'no ring after a tap');
      await tester.tapAt(const Offset(780, 580));
      await tester.pumpAndSettle();
      expect(find.text(info), findsNothing);
      expect(ringShown(tester), isFalse);
      expect(infoFocused(), isFalse);
      await tester.tap(infoControl);
      await tester.pumpAndSettle();
      expect(find.text(info), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(info), findsNothing);
      expect(find.text('Statement date'), findsOneWidget);
    });

    testWidgets('Android: a 48×48 target named "About ‹label›"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(harness(field, platform: TargetPlatform.android));
      final size = tester.getSize(infoControl);
      expect(size.width, greaterThanOrEqualTo(Space.target));
      expect(size.height, greaterThanOrEqualTo(Space.target));
      expect(find.bySemanticsLabel('About Statement date'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('Option picker', () {
    const options = [
      PickerOption(
        value: 'same',
        label: 'Same each time',
        description: 'Splits the total evenly across all payments.',
      ),
      PickerOption(
        value: 'different',
        label: 'Different each time',
        description:
            'Use when your lender gave you a payment-by-payment schedule.',
      ),
    ];
    final many = [
      for (var i = 1; i <= 6; i++)
        PickerOption(
          value: i,
          label: 'Option $i',
          description: 'Does thing $i.',
        ),
    ];

    test('auto picks segmented, radio or dropdown by the §5 rule', () {
      expect(
        OptionPicker.resolve(const [
          PickerOption(value: 'w', label: 'Week'),
          PickerOption(value: 'm', label: 'Month'),
          PickerOption(value: 'y', label: 'Year'),
        ]),
        PickerStyle.segmented,
      );
      expect(OptionPicker.resolve(options), PickerStyle.radio);
      expect(OptionPicker.resolve(many), PickerStyle.dropdown);
      expect(
        OptionPicker.resolve(const [
          PickerOption(value: 1, label: 'A label that is too long'),
          PickerOption(value: 2, label: 'Short'),
        ]),
        PickerStyle.dropdown,
      );
    });

    testWidgets('radio shows every description before a choice', (
      tester,
    ) async {
      String? chosen;
      await tester.pumpWidget(
        harness(
          StatefulBuilder(
            builder: (context, set) => OptionPicker<String>(
              label: 'Payment amounts',
              value: chosen,
              onChanged: (v) => set(() => chosen = v),
              options: options,
            ),
          ),
        ),
      );
      for (final o in options) {
        expect(find.text(o.description!), findsOneWidget);
      }
      await tester.tap(find.text('Different each time'));
      await tester.pump();
      expect(chosen, 'different');
    });

    testWidgets('dropdown shows descriptions in the open menu', (tester) async {
      int? chosen = 2;
      await tester.pumpWidget(
        harness(
          StatefulBuilder(
            builder: (context, set) => OptionPicker<int>(
              label: 'Repeats',
              value: chosen,
              onChanged: (v) => set(() => chosen = v),
              options: many,
            ),
          ),
        ),
      );
      // Closed: only the selected option's description, as the helper.
      expect(find.text('Does thing 2.'), findsOneWidget);
      expect(find.text('Does thing 5.'), findsNothing);
      await tester.tap(find.text('Option 2'));
      await tester.pumpAndSettle();
      for (final o in many) {
        expect(find.text(o.description!), findsWidgets);
      }
      await tester.tap(find.text('Option 5').last);
      await tester.pumpAndSettle();
      expect(chosen, 5);
      expect(find.text('Does thing 5.'), findsOneWidget);
      expect(find.text('Does thing 2.'), findsNothing);
    });
  });

  group('Validation states', () {
    testWidgets('an error replaces the helper and is announced', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(harness(field));
      expect(find.text("The date on your lender's statement."), findsOneWidget);
      await tester.pumpWidget(
        harness(
          const HelpTextField(
            label: 'Statement date',
            helper: "The date on your lender's statement.",
            errorText: 'Enter a date as YYYY-MM-DD.',
          ),
        ),
      );
      expect(find.text("The date on your lender's statement."), findsNothing);
      expect(find.text('Enter a date as YYYY-MM-DD.'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Enter a date as YYYY-MM-DD.')),
        isSemantics(isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('required fields are announced as required', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(const HelpTextField(label: 'Debt name', required: true)),
      );
      expect(find.text('Debt name *', findRichText: true), findsOneWidget);
      expect(find.bySemanticsLabel('Debt name, required'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a disabled field shows why', (tester) async {
      await tester.pumpWidget(
        harness(
          const HelpTextField(
            label: 'Paid from',
            helper: 'The account the money left.',
            enabled: false,
            disabledReason: 'Add an account first.',
          ),
        ),
      );
      expect(find.text('Add an account first.'), findsOneWidget);
      expect(find.text('The account the money left.'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('a summary entry moves focus to its field', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              FormErrorSummary(
                errors: [
                  FieldError(
                    'Installments',
                    'Enter a whole number.',
                    focusNode: node,
                  ),
                  const FieldError('Name', 'Enter a name.'),
                ],
              ),
              HelpTextField(
                label: 'Installments',
                focusNode: node,
                errorText: 'Enter a whole number.',
              ),
            ],
          ),
        ),
      );
      expect(find.text('2 fields need changes'), findsOneWidget);
      await tester.tap(find.text('Installments: Enter a whole number.'));
      await tester.pump();
      expect(node.hasFocus, isTrue);
    });
  });

  group('Date field', () {
    testWidgets('opens a calendar, not a typed input, and shows the choice', (
      tester,
    ) async {
      DateTime? chosen;
      await tester.pumpWidget(
        harness(
          StatefulBuilder(
            builder: (context, set) => DateField(
              label: 'Statement date',
              value: chosen,
              firstDate: DateTime(2026, 10),
              lastDate: DateTime(2026, 10, 31),
              onChanged: (v) => set(() => chosen = v),
            ),
          ),
        ),
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Choose a date'), findsOneWidget);
      await tester.tap(find.byType(DateField));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      // Calendar only: no switch to a typed entry and no text input.
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('15'));
      await tester.tap(find.text('Choose date'));
      await tester.pumpAndSettle();
      expect(chosen, DateTime(2026, 10, 15));
      expect(find.text('15 Oct 2026'), findsOneWidget);
    });

    testWidgets('an optional date can be cleared; a required one cannot', (
      tester,
    ) async {
      DateTime? chosen = DateTime(2026, 10, 15);
      Widget build({required bool required}) => harness(
        StatefulBuilder(
          builder: (context, set) => DateField(
            label: 'Statement date',
            required: required,
            value: chosen,
            onChanged: (v) => set(() => chosen = v),
          ),
        ),
      );
      await tester.pumpWidget(build(required: true));
      expect(find.byTooltip('Clear Statement date'), findsNothing);
      await tester.pumpWidget(build(required: false));
      await tester.tap(find.byTooltip('Clear Statement date'));
      await tester.pump();
      expect(chosen, isNull);
      expect(find.text('Choose a date'), findsOneWidget);
    });
  });

  group('List row', () {
    testWidgets('trailing content is centered on a two-line row', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          ListRow(
            leading: Icons.directions_car_outlined,
            title: 'Car loan',
            subtitle: 'Next due 5 Nov',
            trailing: const StatusPill.dueSoon(),
            onTap: () {},
          ),
        ),
      );
      final row = tester.getCenter(find.byType(ListRow)).dy;
      expect(tester.getCenter(find.byType(StatusPill)).dy, closeTo(row, 1));
      expect(
        tester.getCenter(find.byIcon(Icons.chevron_right)).dy,
        closeTo(row, 1),
      );
    });
  });

  group('Google sign-in', () {
    testWidgets('shows the official artwork for the theme and shape', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        harness(
          GoogleSignInButton(
            shape: ProviderButtonShape.pill,
            onPressed: () => taps++,
          ),
          brightness: Brightness.dark,
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/branding/providers/google/buttons/dark_pill.png',
      );
      expect(image.width, 180);
      expect(image.height, 40);
      expect(find.bySemanticsLabel('Sign in with Google'), findsOneWidget);
      await tester.tap(find.byType(GoogleSignInButton));
      expect(taps, 1);
      semantics.dispose();
    });
  });

  group('Modals', () {
    testWidgets('destructive: Cancel has focus; Esc closes and focus returns', (
      tester,
    ) async {
      final trigger = FocusNode();
      addTearDown(trigger.dispose);
      String? result = 'unset';
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => AppButton(
              'Delete',
              focusNode: trigger,
              onPressed: () async => result = await showAdaptiveModal<String>(
                context,
                title: 'Delete this debt?',
                body: const Text('Its schedule is removed from this device.'),
                primary: const ModalAction(
                  'Delete debt',
                  value: 'deleted',
                  destructive: true,
                ),
              ),
            ),
          ),
        ),
      );
      trigger.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Delete this debt?'), findsOneWidget);
      final cancel = find.ancestor(
        of: find.text('Cancel'),
        matching: find.byType(TextButton),
      );
      expect(
        Focus.of(tester.element(find.text('Cancel'))).hasFocus,
        isTrue,
        reason: 'a destructive modal starts on Cancel',
      );
      expect(cancel, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Delete this debt?'), findsNothing);
      expect(result, isNull);
      expect(trigger.hasFocus, isTrue);
    });
  });

  group('Component gallery', () {
    for (final size in const [Size(1400, 900), Size(400, 800)]) {
      testWidgets('builds every section at ${size.width.toInt()} wide', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const ComponentGalleryApp());
        await tester.pumpAndSettle();
        // The first (light) pane's section list.
        final pane = find.byType(ListView).first;
        final list = find
            .descendant(of: pane, matching: find.byType(Scrollable))
            .first;
        for (final title in const [
          'Buttons',
          'Form fields',
          'Option picker',
          'Dialogs and sheets',
          'Cards and section headers',
          'List rows',
          'Status',
          'Amounts',
          'Google sign-in',
          'Empty, loading and error',
        ]) {
          await tester.scrollUntilVisible(
            find.descendant(
              of: pane,
              matching: find.widgetWithText(SectionHeader, title),
            ),
            300,
            scrollable: list,
          );
          // Busy spinners never settle; give images and fades time instead.
          await tester.pump(Motion.medium);
          expect(tester.takeException(), isNull, reason: title);
        }
      });
    }
  });
}
