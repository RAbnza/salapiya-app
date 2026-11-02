import 'package:flutter/material.dart';

import '../connected/financial_contract.dart' show dependencySensitive;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import '../local/local_finance_controller.dart';

/// The sync rule's refusal: this change needs the latest records first
/// (ARCHITECTURE §8.2). It stays a rule; these are the form's words for it.
bool isSyncBlock(Object e) =>
    e is LocalRuleException && e.message.startsWith('Sync now before saving');

const syncBlockedTitle = 'Couldn’t check your latest records';
const syncBlockedMessage =
    'Salapiya checks your latest records before saving this, and that needs a connection. Nothing was saved, and what you entered is still here.';

/// The fields of a compact form (§3, §5), errors on the field they're about
/// included. They need no store, so Shared Expenses' forms use them too.
mixin FormInputs<T extends StatefulWidget> on State<T> {
  Map<String, String> get values;
  void retain();

  /// Starts each field's key, which device tests find it by.
  String get fieldPrefix => 'native-';

  final fields = <String, TextEditingController>{};
  final anchors = <String, GlobalKey>{};
  String? errorField, errorMessage;

  /// The problem shows in place (§6); this brings it into view.
  Future<void> showProblem(String message, String? field) async {
    final target = field == null ? null : anchors[field]?.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        alignment: .15,
        duration: const Duration(milliseconds: 250),
      );
    }
  }

  String? problemFor(String key) => errorField == key ? errorMessage : null;

  GlobalKey anchor(String key) => anchors.putIfAbsent(key, () => GlobalKey());

  TextEditingController controllerFor(String key) => fields.putIfAbsent(
    key,
    () => TextEditingController(text: values[key] ?? ''),
  );

  void changed(String key, String value) {
    values[key] = value;
    if (errorField == key) errorField = errorMessage = null;
    retain();
  }

  String answer(String key) => (values[key] ?? '').trim();

  /// The space above a field; the form's first field has none.
  EdgeInsets gapAbove({bool info = false}) {
    final first = firstField;
    firstField = false;
    return EdgeInsets.only(
      top: first ? 0 : CompactForm.gapBefore(context, info: info),
    );
  }

  bool firstField = true;

  Widget amountInput(
    String key,
    String label, {
    String? helper,
    String? info,
    bool required = false,
    bool signed = false,
  }) => Padding(
    key: anchor(key),
    padding: gapAbove(info: info != null),
    child: AmountField(
      key: ValueKey('$fieldPrefix$key'),
      label: label,
      controller: controllerFor(key),
      required: required,
      signed: signed,
      helper: helper,
      info: info,
      errorText: problemFor(key),
      onChanged: (x) => changed(key, x),
    ),
  );

  Widget textInput(
    String key,
    String label, {
    String? helper,
    String? info,
    bool required = false,
    int lines = 1,
    FieldInput? input,
  }) => Padding(
    key: anchor(key),
    padding: gapAbove(info: info != null),
    child: HelpTextField(
      key: ValueKey('$fieldPrefix$key'),
      label: label,
      input: input,
      controller: controllerFor(key),
      helper: helper,
      info: info,
      required: required,
      maxLines: lines,
      errorText: problemFor(key),
      onChanged: (x) => changed(key, x),
    ),
  );

  Widget pickInput(
    String key,
    String label,
    Map<String, String> options, {
    bool required = false,
    String? helper,
    String? info,
    String? disabledReason,
    ValueChanged<String>? onChanged,
    Map<String, String> descriptions = const {},
    PickerStyle style = PickerStyle.dropdown,
  }) => Padding(
    key: anchor(key),
    padding: gapAbove(info: info != null),
    child: OptionPicker<String>(
      key: ValueKey('${fieldPrefix}select-$key'),
      label: label,
      style: style,
      required: required,
      helper: helper,
      info: info,
      disabledReason: disabledReason,
      errorText: problemFor(key),
      value: values[key],
      options: [
        for (final e in options.entries)
          PickerOption(
            value: e.key,
            label: e.value,
            description: descriptions[e.key],
          ),
      ],
      onChanged: disabledReason != null
          ? null
          : (x) {
              changed(key, x);
              onChanged?.call(x);
            },
    ),
  );

  Widget dateInput(
    String key,
    String label, {
    String? helper,
    bool required = false,
  }) => Padding(
    key: anchor(key),
    padding: gapAbove(),
    child: DateField(
      key: ValueKey('$fieldPrefix$key'),
      label: label,
      required: required,
      helper: helper,
      value: DateTime.tryParse(answer(key)),
      errorText: problemFor(key),
      onChanged: (d) =>
          changed(key, d == null ? '' : d.toIso8601String().substring(0, 10)),
    ),
  );

  /// Windows: end-aligned, the primary rightmost. Android: full width.
  Widget actions(Widget primary, [Widget? secondary]) => isDesktop(context)
      ? Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (secondary != null) ...[
              secondary,
              const SizedBox(width: Space.sm),
            ],
            primary,
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [primary, ?secondary],
        );
}

/// What the compact finance forms add to [FormInputs]: account balances, the
/// below-zero choice and syncing before a change that needs the latest
/// records. `NativeFinanceEditor` and `MoneyEditor` each decide which fields
/// to show and what to save.
mixin FinanceFormFields<T extends StatefulWidget> on FormInputs<T> {
  LocalFinancialController get c;
  String get id;

  /// Money leaving the chosen account in this form, once it's a valid amount.
  BigInt? get leaving;

  /// The command, its plan and the records it was planned on, once at Review.
  LocalCommand? reviewed;
  LocalPlan? plan;
  LocalSnapshot? reviewSnapshot;

  /// The rules asked whether going below zero is right.
  bool needsConsent = false;

  /// The account field the below-zero choice is about.
  String consentField = 'account';

  /// A sync is under way before saving.
  bool syncing = false;

  /// The rule refused the change even after trying to sync.
  bool syncBlocked = false;

  /// The sync brought new records, so the review was built again.
  bool rechecked = false;

  bool get needsLatest =>
      c.connected && reviewed != null && dependencySensitive(reviewed!);

  /// Syncs before a change that needs the latest records. If that brought
  /// new records the reviewed command is out of date, so it's reviewed again
  /// on them and nothing saves: returns true.
  Future<bool> refreshBeforeSaving() async {
    if (!needsLatest) return false;
    setState(() => syncing = true);
    await c.syncLatest?.call();
    await c.reload();
    if (mounted) setState(() => syncing = false);
    if (c.snapshot.version == reviewed!.expectedVersion) return false;
    reviewed = LocalCommand(
      id: id,
      owner: c.store.owner,
      expectedVersion: c.snapshot.version,
      kind: reviewed!.kind,
      values: reviewed!.values,
    );
    reviewSnapshot = c.snapshot;
    plan = planLocal(reviewSnapshot!, reviewed!);
    return true;
  }

  /// What Review says about syncing, under the review itself.
  List<Widget> syncNotices() => [
    if (c.connected) ...[
      SizedBox(height: CompactForm.fieldGap(context)),
      const InlineNotice(
        'On a connected profile, this waits to sync after you save.',
      ),
    ],
    if (syncBlocked || rechecked || needsLatest)
      SizedBox(height: CompactForm.fieldGap(context)),
    if (syncBlocked)
      const InlineNotice(
        syncBlockedMessage,
        title: syncBlockedTitle,
        tone: NoticeTone.warning,
        live: true,
      )
    else if (rechecked)
      const InlineNotice(
        'Syncing brought in newer records, so this review was updated. Check it again, then save.',
        title: 'Your records changed',
        tone: NoticeTone.warning,
        live: true,
      )
    else if (needsLatest)
      const InlineNotice(
        'Saving this checks your latest records first, so it needs a connection.',
      ),
  ];

  /// An account's balance today, for the eye: hidden amounts stay hidden.
  String shownBalance(String id) => c.amountsHidden
      ? 'Amount hidden'
      : c.amount(c.snapshot.balance(id, through: civilToday()));

  /// Each account's balance under its name, and a warning on the chosen one
  /// if this amount takes it below zero. Saving is still the rules' call.
  Map<String, String> balanceLines(Map<String, String> accounts, String key) {
    final amount = leaving;
    return {
      for (final id in accounts.keys)
        if (id.isNotEmpty)
          id: [
            'Balance ${shownBalance(id)}',
            if (!c.amountsHidden &&
                amount != null &&
                id == values[key] &&
                amount > c.snapshot.balance(id, through: civilToday()))
              'this takes it below zero',
          ].join(' · '),
    };
  }

  /// Shown only once the rules ask for it.
  Widget consentInput() => Padding(
    key: anchor('acknowledge'),
    padding: gapAbove(),
    child: OptionPicker<String>(
      key: const ValueKey('native-select-acknowledge'),
      label: 'This takes the account below zero',
      style: PickerStyle.radio,
      value: answer('acknowledge'),
      options: const [
        PickerOption(
          value: 'true',
          label: 'That is right',
          description: 'Save it with a negative balance.',
        ),
        PickerOption(
          value: 'false',
          label: 'Let me check',
          description: 'Keep the balance as it is for now.',
        ),
      ],
      onChanged: (x) {
        if (errorField == consentField) errorField = errorMessage = null;
        changed('acknowledge', x);
      },
    ),
  );
}
