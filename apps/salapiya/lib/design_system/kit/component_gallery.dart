import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../prototype/fixtures.dart';
import '../theme.dart';
import 'kit.dart';

// Debug-only component gallery. main.dart starts it only when kDebugMode is
// true and SALAPIYA_COMPONENTS is defined, so release builds tree-shake it.
// Amounts are synthetic, formatted by the app's own DemoMoney.format.

enum _ThemeView { both, light, dark, highContrast }

class ComponentGalleryApp extends StatefulWidget {
  const ComponentGalleryApp({super.key});
  @override
  State<ComponentGalleryApp> createState() => _ComponentGalleryAppState();
}

class _ComponentGalleryAppState extends State<ComponentGalleryApp> {
  TargetPlatform platform = defaultTargetPlatform;
  _ThemeView view = _ThemeView.both;
  double textScale = 1;
  bool reduceMotion = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Salapiya components',
    debugShowCheckedModeBanner: false,
    theme: SalapiyaTheme.build(Brightness.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations:
            reduceMotion || MediaQuery.disableAnimationsOf(context),
      ),
      child: child!,
    ),
    home: Builder(builder: _page),
  );

  Widget _page(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final shown = !wide && view == _ThemeView.both ? _ThemeView.light : view;
    Widget pane(Brightness b, {bool hc = false}) => _Pane(
      key: ValueKey('$b-$hc'),
      theme: SalapiyaTheme.build(
        b,
        highContrast: hc,
      ).copyWith(platform: platform),
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Toolbar(
              wide: wide,
              platform: platform,
              view: shown,
              textScale: textScale,
              reduceMotion: reduceMotion,
              onPlatform: (v) => setState(() => platform = v),
              onView: (v) => setState(() => view = v),
              onTextScale: (v) => setState(() => textScale = v),
              onReduceMotion: (v) => setState(() => reduceMotion = v),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: switch (shown) {
                _ThemeView.both => Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: pane(Brightness.light)),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: pane(Brightness.dark)),
                  ],
                ),
                _ThemeView.light => pane(Brightness.light),
                _ThemeView.dark => pane(Brightness.dark),
                _ThemeView.highContrast => pane(Brightness.light, hc: true),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.wide,
    required this.platform,
    required this.view,
    required this.textScale,
    required this.reduceMotion,
    required this.onPlatform,
    required this.onView,
    required this.onTextScale,
    required this.onReduceMotion,
  });
  final bool wide, reduceMotion;
  final TargetPlatform platform;
  final _ThemeView view;
  final double textScale;
  final ValueChanged<TargetPlatform> onPlatform;
  final ValueChanged<_ThemeView> onView;
  final ValueChanged<double> onTextScale;
  final ValueChanged<bool> onReduceMotion;
  @override
  Widget build(BuildContext context) {
    final w = WidthClass.of(context);
    return ColoredBox(
      color: CraftTheme.of(context).surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: Space.pageGutter(w),
          vertical: Space.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, picker) in <Widget>[
              OptionPicker<TargetPlatform>(
                label: 'Platform behavior',
                value: platform == TargetPlatform.android
                    ? TargetPlatform.android
                    : TargetPlatform.windows,
                onChanged: onPlatform,
                options: const [
                  PickerOption(value: TargetPlatform.windows, label: 'Windows'),
                  PickerOption(value: TargetPlatform.android, label: 'Android'),
                ],
              ),
              OptionPicker<_ThemeView>(
                label: 'Theme',
                value: view,
                onChanged: onView,
                options: [
                  if (wide)
                    const PickerOption(value: _ThemeView.both, label: 'Both'),
                  const PickerOption(value: _ThemeView.light, label: 'Light'),
                  const PickerOption(value: _ThemeView.dark, label: 'Dark'),
                  const PickerOption(
                    value: _ThemeView.highContrast,
                    label: 'Contrast',
                  ),
                ],
              ),
              OptionPicker<double>(
                label: 'Text size',
                value: textScale,
                onChanged: onTextScale,
                options: const [
                  PickerOption(value: 1, label: '100%'),
                  PickerOption(value: 2, label: '200%'),
                ],
              ),
              OptionPicker<bool>(
                label: 'Motion',
                value: reduceMotion,
                onChanged: onReduceMotion,
                options: const [
                  PickerOption(value: false, label: 'Normal'),
                  PickerOption(value: true, label: 'Reduced'),
                ],
              ),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: Space.xl),
              IntrinsicWidth(child: picker),
            ],
          ],
        ),
      ),
    );
  }
}

/// One theme's copy of every section.
class _Pane extends StatelessWidget {
  const _Pane({super.key, required this.theme});
  final ThemeData theme;
  @override
  Widget build(BuildContext context) => Theme(
    data: theme,
    child: Builder(
      builder: (context) {
        final w = WidthClass.of(context);
        final sections = <(String, String, Widget)>[
          (
            'Buttons',
            'Hover, Tab and press to see each state.',
            const _Buttons(),
          ),
          (
            'Form fields',
            'Label above, helper below, ⓘ for what it does.',
            const _Fields(),
          ),
          (
            'Option picker',
            'Each option says what it does before you choose.',
            const _Pickers(),
          ),
          (
            'Dialogs and sheets',
            'Confirmations are dialogs; choices are sheets on Android.',
            const _Modals(),
          ),
          (
            'Cards and section headers',
            'One focal value per card.',
            const _Cards(),
          ),
          ('List rows', 'Right side centered on the row.', const _Rows()),
          ('Status', 'Icon and words, never color alone.', const _Status()),
          ('Amounts', 'Formatted by the app; display only.', const _Amounts()),
          (
            'Google sign-in',
            "Follows Google's branding, not the Salapiya theme.",
            const _Google(),
          ),
          (
            'Empty, loading and error',
            'Static skeletons; calm error text.',
            const _States(),
          ),
        ];
        return ColoredBox(
          color: CraftTheme.of(context).canvas,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: CraftTheme.of(context).text),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                Space.pageGutter(w),
                Space.pageTop(w),
                Space.pageGutter(w),
                Space.pageBottom(w),
              ),
              itemCount: sections.length,
              separatorBuilder: (_, _) => SizedBox(height: Space.sectionGap(w)),
              itemBuilder: (context, i) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(sections[i].$1, caption: sections[i].$2),
                  SizedBox(height: Space.headerGap(w)),
                  sections[i].$3,
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

String _php(int centavos) => DemoMoney.format(BigInt.from(centavos));

/// Equal-width cards with the grid-owned gap (§4).
Widget _grid(BuildContext context, List<Widget> children) => LayoutBuilder(
  builder: (context, box) {
    final gap = Space.cardGap(WidthClass.of(context));
    final columns = (box.maxWidth / (Space.formMaxWidth / 2)).floor().clamp(
      1,
      children.length,
    );
    final width = (box.maxWidth - gap * (columns - 1)) / columns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [for (final c in children) SizedBox(width: width, child: c)],
    );
  },
);

Widget _labelled(BuildContext context, String label, Widget child) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      label,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: CraftTheme.of(context).secondary),
    ),
    const SizedBox(height: Space.sm),
    child,
  ],
);

class _Buttons extends StatefulWidget {
  const _Buttons();
  @override
  State<_Buttons> createState() => _ButtonsState();
}

class _ButtonsState extends State<_Buttons> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    void noop() {}
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _labelled(
            context,
            'VARIANTS',
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                AppButton('Log expense', icon: Icons.add, onPressed: noop),
                AppButton.secondary('Edit debt', onPressed: noop),
                AppButton.tertiary('Show details', onPressed: noop),
                AppButton.destructive(
                  'Delete debt',
                  icon: Icons.delete_outline,
                  onPressed: noop,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.groupGap),
          _labelled(
            context,
            'DISABLED WITH REASON AND BUSY',
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                const AppButton(
                  'Log debt payment',
                  onPressed: null,
                  disabledReason: 'Add a debt first.',
                ),
                const AppButton.secondary(
                  'Export',
                  onPressed: null,
                  disabledReason: 'Nothing to export yet.',
                ),
                AppButton(
                  'Save changes',
                  icon: Icons.check,
                  busy: busy,
                  onPressed: () => setState(() => busy = true),
                ),
                AppButton.tertiary(
                  'Reset busy',
                  onPressed: () => setState(() => busy = false),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.groupGap),
          _labelled(
            context,
            'ICON BUTTONS',
            Wrap(
              spacing: Space.sm,
              children: [
                AppIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  onPressed: noop,
                ),
                AppIconButton(
                  icon: Icons.add,
                  tooltip: 'Add',
                  variant: AppIconButtonVariant.filled,
                  onPressed: noop,
                ),
                AppIconButton(
                  icon: Icons.more_horiz,
                  tooltip: 'More actions',
                  variant: AppIconButtonVariant.outlined,
                  onPressed: noop,
                ),
                const AppIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete (unavailable)',
                  onPressed: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fields extends StatefulWidget {
  const _Fields();
  @override
  State<_Fields> createState() => _FieldsState();
}

class _FieldsState extends State<_Fields> {
  final countFocus = FocusNode(), dateFocus = FocusNode();
  final currency = TextEditingController(text: 'PHP');
  bool hide = false, remind = true;
  DateTime? firstDue, statement = DateTime(2026, 10, 15);
  @override
  void dispose() {
    countFocus.dispose();
    dateFocus.dispose();
    currency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Space.formMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormErrorSummary(
            errors: [
              FieldError(
                'Installments',
                'Enter a whole number from 1 to 360.',
                focusNode: countFocus,
              ),
              FieldError(
                'First due date',
                'Choose the first due date.',
                focusNode: dateFocus,
              ),
            ],
          ),
          const SizedBox(height: Space.groupGap),
          Text(
            '* Required',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: CraftTheme.of(context).secondary),
          ),
          const SizedBox(height: Space.fieldGap),
          const HelpTextField(
            label: 'Debt name',
            hintText: 'e.g. Car loan',
            required: true,
          ),
          const SizedBox(height: Space.fieldGap),
          const HelpTextField(
            label: 'Current balance',
            amount: true,
            required: true,
            helper: "The amount on your lender's latest statement.",
            info: 'This becomes the starting balance. Payments you log later reduce it.',
          ),
          const SizedBox(height: Space.fieldGap),
          HelpTextField(
            label: 'Installments',
            focusNode: countFocus,
            required: true,
            helper: 'How many payments are left.',
            info: 'Each payment you log is matched to the earliest unpaid due date.',
            errorText: 'Enter a whole number from 1 to 360.',
          ),
          const SizedBox(height: Space.fieldGap),
          DateField(
            label: 'First due date',
            focusNode: dateFocus,
            required: true,
            value: firstDue,
            onChanged: (v) => setState(() => firstDue = v),
            helper: 'The next date a payment is due.',
            errorText: firstDue == null ? 'Choose the first due date.' : null,
          ),
          const SizedBox(height: Space.fieldGap),
          DateField(
            label: 'Statement date',
            value: statement,
            onChanged: (v) => setState(() => statement = v),
            helper: "The date on your lender's statement.",
            info: 'Due dates in your reminders count from this date.',
          ),
          const SizedBox(height: Space.fieldGap),
          const DateField(
            label: 'Closed on',
            value: null,
            onChanged: null,
            disabledReason: 'Only a fully paid debt can be closed.',
          ),
          const SizedBox(height: Space.fieldGap),
          const HelpTextField(
            label: 'Paid from',
            enabled: false,
            disabledReason: 'Add an account first.',
          ),
          const SizedBox(height: Space.fieldGap),
          HelpTextField(
            label: 'Currency',
            controller: currency,
            readOnly: true,
            helper: 'Salapiya records amounts in Philippine pesos.',
          ),
          const SizedBox(height: Space.groupGap),
          HelpField(
            label: 'Hide amounts',
            info: 'Replaces amounts on screen with "Amount hidden". Your records do not change.',
            helper: 'Useful when others can see your screen.',
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Switch(
                value: hide,
                onChanged: (v) => setState(() => hide = v),
              ),
            ),
          ),
          const SizedBox(height: Space.fieldGap),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: remind,
            onChanged: (v) => setState(() => remind = v ?? false),
            title: const Text('Remind me before each due date'),
          ),
        ],
      ),
    ),
  );
}

class _Pickers extends StatefulWidget {
  const _Pickers();
  @override
  State<_Pickers> createState() => _PickersState();
}

class _PickersState extends State<_Pickers> {
  String period = 'month', amounts = 'same', repeats = 'monthly';
  String? required;
  static const repeatOptions = [
    PickerOption(
      value: 'once',
      label: 'Once',
      description: 'Records a single due date with no repeat.',
    ),
    PickerOption(
      value: 'weekly',
      label: 'Every week',
      description: 'Repeats on the same weekday.',
    ),
    PickerOption(
      value: 'biweekly',
      label: 'Every two weeks',
      description: 'Use when you are paid every other week.',
    ),
    PickerOption(
      value: 'monthly',
      label: 'Every month',
      description: 'Repeats on the same day each month.',
    ),
    PickerOption(
      value: 'quarterly',
      label: 'Every three months',
      description: 'Repeats four times a year.',
    ),
    PickerOption(
      value: 'custom',
      label: 'Custom interval',
      description: 'Use when your lender set a different number of days.',
    ),
  ];
  static const amountOptions = [
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
  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Space.formMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OptionPicker<String>(
            label: 'Period',
            value: period,
            onChanged: (v) => setState(() => period = v),
            options: const [
              PickerOption(value: 'week', label: 'Week'),
              PickerOption(value: 'month', label: 'Month'),
              PickerOption(value: 'year', label: 'Year'),
            ],
          ),
          const SizedBox(height: Space.fieldGap),
          OptionPicker<String>(
            label: 'Payment amounts',
            info: 'Decides how the balance is spread across the schedule.',
            value: amounts,
            onChanged: (v) => setState(() => amounts = v),
            options: amountOptions,
          ),
          const SizedBox(height: Space.fieldGap),
          OptionPicker<String>(
            label: 'Repeats',
            info: 'Sets how often a due date comes up in your reminders.',
            value: repeats,
            onChanged: (v) => setState(() => repeats = v),
            options: repeatOptions,
          ),
          const SizedBox(height: Space.fieldGap),
          OptionPicker<String>(
            label: 'Reminder schedule',
            required: true,
            value: required,
            errorText: required == null ? 'Choose how often it repeats.' : null,
            onChanged: (v) => setState(() => required = v),
            style: PickerStyle.dropdown,
            options: repeatOptions,
          ),
          const SizedBox(height: Space.fieldGap),
          const OptionPicker<String>(
            label: 'Split method',
            value: 'same',
            onChanged: null,
            disabledReason:
                'Only the person who added the bill can change this.',
            options: amountOptions,
          ),
        ],
      ),
    ),
  );
}

class _Modals extends StatefulWidget {
  const _Modals();
  @override
  State<_Modals> createState() => _ModalsState();
}

class _ModalsState extends State<_Modals> {
  String result = 'None yet';
  void show(Object? value) =>
      setState(() => result = value?.toString() ?? 'Closed without choosing');
  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            AppButton.secondary(
              'Confirmation',
              onPressed: () async => show(
                await showAdaptiveModal<String>(
                  context,
                  title: 'Archive this account?',
                  body: const Text(
                    'It stays in your history but leaves your account lists.',
                  ),
                  primary: const ModalAction(
                    'Archive account',
                    value: 'Archived',
                  ),
                ),
              ),
            ),
            AppButton.secondary(
              'Destructive confirmation',
              onPressed: () async => show(
                await showAdaptiveModal<String>(
                  context,
                  title: 'Delete this debt?',
                  body: const Text(
                    'Its schedule and logged payments are removed from this device.',
                  ),
                  primary: const ModalAction(
                    'Delete debt',
                    value: 'Deleted',
                    destructive: true,
                  ),
                ),
              ),
            ),
            AppButton.secondary(
              'Choice (adaptive)',
              onPressed: () async {
                var choice = 'same';
                show(
                  await showAdaptiveModal<String>(
                    context,
                    purpose: ModalPurpose.choice,
                    title: 'Payment amounts',
                    body: StatefulBuilder(
                      builder: (context, set) => OptionPicker<String>(
                        label: 'Amounts',
                        value: choice,
                        onChanged: (v) => set(() => choice = v),
                        options: _PickersState.amountOptions,
                      ),
                    ),
                    primary: ModalAction(
                      'Use this',
                      onPressed: () {
                        Navigator.of(context).pop(choice);
                        return false;
                      },
                    ),
                  ),
                );
              },
            ),
            AppButton.secondary(
              'Bottom sheet',
              onPressed: () async => show(
                await showAppSheet<String>(
                  context,
                  title: 'Log a transfer',
                  body: const HelpTextField(
                    label: 'Amount',
                    amount: true,
                    helper: 'Between your own accounts.',
                  ),
                  primary: const ModalAction('Log transfer', value: 'Logged'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        Text(
          'Last result: $result',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: CraftTheme.of(context).secondary),
        ),
      ],
    ),
  );
}

class _Cards extends StatelessWidget {
  const _Cards();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _grid(context, [
        MetricTile(
          label: 'Spent this month',
          value: MoneyAmount(
            _php(1845075),
            kind: MoneyKind.spent,
            size: MoneySize.card,
            textAlign: TextAlign.start,
          ),
          context: '1–29 Oct · refunds subtracted',
        ),
        MetricTile(
          label: 'What you owe',
          value: MoneyAmount(
            _php(12500000),
            kind: MoneyKind.owed,
            size: MoneySize.card,
            textAlign: TextAlign.start,
          ),
          context: '3 debts · next due 5 Nov',
          trend: const StatusPill.dueSoon(),
        ),
        MetricTile(
          label: 'Owed to you',
          value: MoneyAmount(
            _php(80000),
            kind: MoneyKind.owedToYou,
            size: MoneySize.card,
            textAlign: TextAlign.start,
          ),
          context: 'Across 2 groups',
          onTap: () {},
        ),
      ]),
      SizedBox(height: Space.cardGap(WidthClass.of(context))),
      _grid(context, [
        SurfaceCard(
          title: 'Accounts',
          caption: 'Cash and bank',
          trailing: AppButton.tertiary('View all', onPressed: () {}),
          child: const Text('A card has one job and a title that names it.'),
        ),
        SurfaceCard(
          onTap: () {},
          title: 'Tappable card',
          child: const Text(
            'The whole card is one target, with hover and focus.',
          ),
        ),
      ]),
    ],
  );
}

class _Rows extends StatelessWidget {
  const _Rows();
  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: ListGroup(
      leading: true,
      children: [
        ListRow(
          leading: Icons.account_balance_wallet_outlined,
          title: 'Cash wallet',
          trailing: MoneyAmount(_php(125000)),
        ),
        ListRow(
          leading: Icons.shopping_basket_outlined,
          title: 'Groceries',
          subtitle: 'Today · Everyday bank',
          trailing: MoneyAmount(_php(-245050), kind: MoneyKind.spent),
        ),
        ListRow(
          leading: Icons.directions_car_outlined,
          title: 'Car loan',
          subtitle: 'Next due 5 Nov',
          trailing: const StatusPill.dueSoon(),
          onTap: () {},
        ),
        ListRow(
          leading: Icons.group_outlined,
          title: 'Dinner with Tala',
          subtitle: 'Shared expenses',
          trailing: MoneyAmount(_php(40000), kind: MoneyKind.owedToYou),
          onTap: () {},
        ),
      ],
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status();
  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            StatusPill.overdue(),
            StatusPill.dueToday(),
            StatusPill.dueSoon(),
            StatusPill.upcoming(),
            StatusPill.scheduleNotSet(),
            StatusPill.paidOff(),
            StatusPill.settled(),
            StatusPill(
              'Synced',
              icon: Icons.cloud_done_outlined,
              tone: PillTone.information,
            ),
          ],
        ),
        const SizedBox(height: Space.groupGap),
        for (final (tone, title, text) in const [
          (NoticeTone.information, null, 'Card credit is not money you have.'),
          (
            NoticeTone.success,
            'Saved on this device',
            'It syncs when you are online.',
          ),
          (
            NoticeTone.warning,
            'Needs review',
            'Two records changed on another device.',
          ),
          (
            NoticeTone.error,
            null,
            "Couldn't save. Your earlier records are unchanged.",
          ),
          (NoticeTone.neutral, null, 'Borrowed money is not income.'),
        ]) ...[
          InlineNotice(text, title: title, tone: tone),
          const SizedBox(height: Space.sm),
        ],
      ],
    ),
  );
}

class _Amounts extends StatelessWidget {
  const _Amounts();
  @override
  Widget build(BuildContext context) {
    final rows = <(String, Widget)>[
      ('Neutral', MoneyAmount(_php(2485050))),
      ('Spent', MoneyAmount(_php(-245050), kind: MoneyKind.spent)),
      ('You owe', MoneyAmount(_php(12500000), kind: MoneyKind.owed)),
      (
        'Owed to you',
        MoneyAmount(
          _php(80000),
          kind: MoneyKind.owedToYou,
          caption: 'Owed to you',
        ),
      ),
      ('Hidden', const MoneyAmount('Amount hidden')),
      ('Unknown', const MoneyAmount(null)),
    ];
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListGroup(
            children: [
              for (final (label, amount) in rows)
                ListRow(title: label, trailing: amount),
            ],
          ),
          const SizedBox(height: Space.groupGap),
          _labelled(
            context,
            'FOCAL (STEPS DOWN TO FIT)',
            MoneyAmount(
              _php(123456789012),
              size: MoneySize.focal,
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }
}

class _Google extends StatelessWidget {
  const _Google();

  /// Whether the official artwork is bundled; checked once for both panes.
  static final Future<bool> _bundled =
      AssetManifest.loadFromAssetBundle(rootBundle).then(
        (m) => m.listAssets().contains(
          ProviderBrands.google.asset(
            ProviderButtonTheme.light,
            ProviderButtonShape.rectangular,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _bundled,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const LoadingSkeleton.lines(label: 'Google button', lines: 1);
      }
      if (!snapshot.data!) {
        return const InlineNotice(
          "Google's official button artwork is not bundled. "
          'No approximation is drawn.',
          title: 'Blocked: official asset missing',
          tone: NoticeTone.warning,
        );
      }
      Widget labelled(String label, Widget button) =>
          _labelled(context, label, button);
      return SurfaceCard(
        child: Wrap(
          spacing: Space.xl,
          runSpacing: Space.lg,
          children: [
            labelled('FOLLOWS APP THEME', GoogleSignInButton(onPressed: () {})),
            for (final theme in ProviderButtonTheme.values)
              for (final shape in ProviderButtonShape.values)
                labelled(
                  '${theme.name} · ${shape.name}'.toUpperCase(),
                  GoogleSignInButton(
                    theme: theme,
                    shape: shape,
                    onPressed: () {},
                  ),
                ),
            labelled('BUSY', GoogleSignInButton(busy: true, onPressed: () {})),
            labelled('DISABLED', const GoogleSignInButton(onPressed: null)),
          ],
        ),
      );
    },
  );
}

class _States extends StatelessWidget {
  const _States();
  @override
  Widget build(BuildContext context) => _grid(context, [
    SurfaceCard(
      child: EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No debts yet',
        message: 'Add a debt you already have to track its schedule.',
        action: AppButton('Add a debt', icon: Icons.add, onPressed: () {}),
      ),
    ),
    const SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LoadingSkeleton.lines(label: 'activity'),
          SizedBox(height: Space.lg),
          LoadingSkeleton.row(label: 'accounts'),
        ],
      ),
    ),
    const LoadingSkeleton.card(label: 'this month'),
    SurfaceCard(
      child: ErrorState(
        title: "Couldn't load your accounts",
        message: 'Your records on this device are unchanged.',
        onRetry: () {},
        details: 'SqliteException(5): database is locked',
      ),
    ),
  ]);
}
