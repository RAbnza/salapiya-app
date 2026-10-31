import 'package:flutter/material.dart';

import '../design_system/form_presentation.dart' show FormStatus;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../design_system/workspace.dart' show FormExitGuard;
import '../features/finance/contracts/financial_models.dart' show DemoOutcome;
import '../features/finance/presentation/financial_review.dart';
import '../finance/debt_cards.dart' show civilDay;
import '../finance/form_mechanics.dart';
import '../local/finance_domain.dart';
import '../local/local_finance_controller.dart';
import 'shared_bill_form.dart' show lostResponseMessage, lostResponseTitle;
import 'shared_data.dart';
import 'shared_domain.dart';
import 'shared_hub.dart';
import 'shared_private_data.dart';

/// Rules that name no field, and the field each is about. A test holds these
/// to the rules' own words.
const privateRuleFields = [
  ('Choose one of your accounts', 'account'),
  ('Choose an active account', 'account'),
  ('Choose a spending category', 'category'),
  ('Say why you’re changing your record', 'reason'),
  ('You’re changing what you paid', 'fundingAmount'),
  ('Keep the amount, date and account from your saved purchase', 'existing'),
  ('Keep the card, amount and date', 'existing'),
  ('That doesn’t match your card record', 'fundingAmount'),
  ('A payment needs an amount', 'fundingAmount'),
  ('To reuse that record', 'existingPayment'),
  ('Keep the amount and account from your saved refund', 'fundingAmount'),
];

/// Add to my Money, Review my record, Count it in my group balance and Take
/// it out of my group balance: one page, on the compact scale, for the user's
/// own records. Nothing here reaches the group, and only what applies shows.
/// Values start from the group's source and every key stays in the command,
/// shown or not, so what's saved is what these forms always saved.
class SharedPrivateForm extends StatefulWidget {
  const SharedPrivateForm({
    super.key,
    required this.hub,
    required this.controller,
    required this.group,
    required this.item,
    required this.mode,
  });
  final SharedHub hub;
  final LocalFinancialController controller;
  final SharedGroup group;

  /// The bill, payment or refund, by the group's id.
  final String item;

  /// `bill`, `payment`, `refund`, `clear` or `unclear`.
  final String mode;

  static String titleFor(String mode, {required bool linked}) => switch (mode) {
    'clear' => 'Count it in my group balance',
    'unclear' => 'Take it out of my group balance',
    _ => linked ? 'Review my record' : 'Add to my Money',
  };

  @override
  State<SharedPrivateForm> createState() => _SharedPrivateFormState();
}

class _SharedPrivateFormState extends State<SharedPrivateForm>
    with FormInputs, FinanceFormFields {
  @override
  LocalFinancialController get c => widget.controller;

  /// Once per form: a lost save looks up this same command.
  @override
  final String id = newLocalId();
  @override
  final Map<String, String> values = {};
  PrivateContext? private;

  /// Why this can't open now, when the rules say so.
  String? blocked;
  bool loading = true, busy = false, dirty = false, saved = false;
  bool unknown = false, needsFundingConsent = false;
  String? error;

  SharedSource get source => widget.hub.source();

  @override
  void initState() {
    super.initState();
    // After the first frame: a sync tells the whole app as it starts, and
    // nothing may change while this page is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  /// Syncs first, so the form starts from the latest records. Offline that
  /// does nothing and the form still opens: saving is what needs a connection.
  Future<void> load() async {
    try {
      await c.syncLatest?.call();
      await c.reload();
      final draft = widget.mode == 'bill'
          ? await c.store.draft('shared-purchase:${widget.item}')
          : null;
      final opened = PrivateContext.open(
        widget.group,
        source.actor,
        widget.item,
        widget.mode,
        c.snapshot,
        purchaseDraft: draft,
      );
      private = opened;
      values.addAll(opened.startingValues());
    } on LocalRuleException catch (e) {
      blocked = e.message;
    } on StateError {
      blocked = 'This is no longer in the group.';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void retain() => setState(() => dirty = true);

  /// Money leaving the account, for the warning under it.
  @override
  BigInt? get leaving {
    final p = private;
    if (p == null) return null;
    final out = p.mode == 'bill' || (p.isPayment && p.outgoing);
    return out ? typedAmount(answer('fundingAmount')) : null;
  }

  BigInt get funded => typedAmount(answer('fundingAmount')) ?? BigInt.zero;
  BigInt get part => typedAmount(answer('shareAmount')) ?? BigInt.zero;

  /// The record this form is changing or taking over.
  LocalRevision? get chosen {
    final p = private!;
    final id =
        values['existing'] ??
        values['existingPayment'] ??
        values['existingCardRefund'];
    return p.linked ??
        p.snapshot.current.where((r) => r.id == id).firstOrNull;
  }

  /// A saved purchase or refund, not a new one, fixes these fields.
  bool get locked => private!.linked == null && chosen != null;
  bool get cardFunded => sharedSourceUsesCard(chosen);
  bool get showsAccount => funded > BigInt.zero && !cardFunded && !locked;

  bool get showsCategory =>
      part > BigInt.zero &&
      (widget.mode == 'bill' ||
          (widget.mode == 'refund' && private!.refundCoverage));

  /// Checks what only the form knows, so the rules' errors stay about rules.
  void check() {
    final p = private!;
    if (p.isClear) return;
    if (typedAmount(answer('fundingAmount')) == null) {
      reject('Enter an amount like 1500.00.', field: 'fundingAmount');
    }
    if (typedAmount(answer('shareAmount')) == null) {
      reject('Enter an amount like 1500.00.', field: 'shareAmount');
    }
    if (showsAccount && answer('account').isEmpty) {
      reject('Choose an account.', field: 'account');
    }
    if (answer('date').isEmpty) reject('Choose a date.', field: 'date');
    if (chosen != null && answer('reason').isEmpty) {
      reject('Say why you’re changing your record.', field: 'reason');
    }
  }

  /// Puts a refusal on the field it's about.
  (String?, String) locateProblem(LocalRuleException e) {
    if (e.field != null) return (e.field, e.message);
    if (e.message.contains('negative')) {
      final account = c.snapshot.accounts
          .where((a) => a.id == answer('account'))
          .firstOrNull;
      if (account == null) return (null, e.message);
      return (
        'account',
        'This takes ${account.name} below zero. It has ${shownBalance(account.id)}.',
      );
    }
    for (final (text, field) in privateRuleFields) {
      if (e.message.contains(text)) return (field, e.message);
    }
    return (null, e.message);
  }

  LocalCommand makeCommand() {
    final p = private!;
    return LocalCommand(
      id: id,
      owner: c.store.owner,
      expectedVersion: c.snapshot.version,
      kind: 'shared',
      values: p.command({
        ...values,
        for (final e in values.entries) e.key: e.value.trim(),
      }),
    );
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
      errorField = errorMessage = null;
      syncBlocked = rechecked = false;
    });
    String? problem, problemField;
    try {
      if (reviewed == null) {
        check();
        await c.reload();
        reviewed = makeCommand();
        reviewSnapshot = c.snapshot;
        plan = planLocal(reviewSnapshot!, reviewed!);
      } else if (await refreshBeforeSaving()) {
        rechecked = true;
      } else {
        await c.store.commit(reviewed!);
        await c.reload();
        saved = true;
      }
    } catch (e) {
      // Stays on Review with everything kept, ready to try again.
      syncing = false;
      syncBlocked = isSyncBlock(e);
      if (reviewed != null && !syncBlocked) {
        try {
          if (await c.store.hasReceipt(id)) {
            await c.reload();
            saved = true;
          } else {
            reviewed = null;
            plan = null;
          }
        } catch (_) {
          unknown = true;
        }
      }
      if (!saved && !syncBlocked) {
        if (e is LocalRuleException) {
          (problemField, problem) = locateProblem(e);
          if (e.message.contains('negative')) needsConsent = true;
          if (e.message.contains('You’re changing what you paid')) {
            needsFundingConsent = true;
          }
        } else if (e is FormatException) {
          problem = e.message;
          problemField = 'date';
        } else {
          error = 'The save could not be verified. What you entered is kept.';
        }
      }
    }
    if (mounted) {
      setState(() {
        busy = false;
        errorField = problemField;
        errorMessage = problem;
      });
    }
    if (problem != null && mounted) await showProblem(problem, problemField);
  }

  /// The save's answer was lost. Looks up the same command, and never
  /// submits a second one.
  Future<void> checkResult() async {
    setState(() => busy = true);
    final outcome = await c.resolveReceipt(id);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (outcome == DemoOutcome.unknown) return;
      unknown = false;
      if (outcome == DemoOutcome.accepted) {
        saved = true;
        error = null;
      } else {
        error =
            'It wasn’t saved. What you entered is kept, so you can save again.';
      }
    });
  }

  /// "Dinner · 12 Oct 2026 · ₱2,400.00", with the amount left out when hidden.
  String recordLine(LocalRevision r, BigInt amount) => detailFacts([
    sharedRecordTitle(r.title),
    civilDay(r.date),
    if (!c.amountsHidden) c.amount(amount),
  ]);

  Map<String, String> get accounts => {
    for (final a in c.snapshot.accounts.where((a) => !a.archived)) a.id: a.name,
  };

  /// Taking over a record fixes what the rules won't let change.
  void take(PrivateContext p, String id) {
    final r = p.snapshot.current.where((x) => x.id == id).firstOrNull;
    setState(() {
      if (r == null) return;
      values.addAll(p.lockedTo(r));
      fields['fundingAmount']?.text = values['fundingAmount']!;
    });
  }

  /// The group's figures, so the form starts from what it's about.
  Widget groupLine(PrivateContext p) {
    final a = source.amount;
    return Padding(
      padding: EdgeInsets.only(bottom: CompactForm.fieldGap(context)),
      child: InlineNotice(switch (p.mode) {
        'bill' =>
          'The group says you paid ${a(p.paid)} and your part is ${a(p.share)}. Only your own records change.',
        'refund' =>
          'The group says ${a(p.paid)} came back to you and your part went down by ${a(p.share)}. Only your own records change.',
        'clear' =>
          'This counts ${a(typedAmount(p.fixedAmount) ?? p.paid)} in your group balance. No money moves, and your accounts stay as they are.',
        'unclear' =>
          'Its confirmation was undone, so this takes ${a(typedAmount(p.fixedAmount) ?? p.paid)} out of your group balance. No money moves.',
        _ =>
          'The group says ${p.outgoing ? 'you paid' : 'you received'} ${a(p.paid)}. Only your own records change.',
      }),
    );
  }

  List<Widget> formFields(PrivateContext p) {
    firstField = true;
    final isBill = widget.mode == 'bill', refund = widget.mode == 'refund';
    final payment = widget.mode == 'payment';
    final accountLabel = payment
        ? (p.outgoing ? 'Paid from' : 'Received in')
        : refund
        ? 'Received in'
        : 'Paid from';
    final owned = accounts;
    return [
      groupLine(p),
      if (isBill && p.linked == null && p.purchases.isNotEmpty)
        pickInput(
          'existing',
          'Is this already in Money?',
          {
            '': 'No, add it now',
            for (final r in p.purchases) r.id: recordLine(r, r.amount),
          },
          disabledReason: p.savedPurchase != null
              ? 'This bill came from your saved purchase.'
              : null,
          helper: 'Pick a saved purchase so it isn’t counted twice.',
          onChanged: (id) => take(p, id),
        ),
      if (payment && p.linked == null && p.reusablePayments.isNotEmpty)
        pickInput(
          'existingPayment',
          'Already logged?',
          {
            '': 'No, add it now',
            for (final r in p.reusablePayments)
              r.id: recordLine(
                r,
                typedAmount(r.values['fundingAmount']) ?? BigInt.zero,
              ),
          },
          helper: 'From a payment that was cancelled or reversed.',
          onChanged: (id) => take(p, id),
        ),
      if (refund && p.linked == null && p.cardRefunds.isNotEmpty)
        pickInput(
          'existingCardRefund',
          'Is this a card refund in Money?',
          {
            '': 'No, add it now',
            for (final r in p.cardRefunds) r.id: recordLine(r, r.amount),
          },
          onChanged: (id) => take(p, id),
        ),
      if (locked)
        Padding(
          padding: gapAbove(),
          child: FactRow('Amount', c.amountsHidden ? 'Amount hidden' : c.amount(funded)),
        )
      else if (p.isClear)
        Padding(
          padding: gapAbove(),
          child: FactRow('Amount', source.amount(funded)),
        )
      else ...[
        amountInput(
          'fundingAmount',
          payment
              ? (p.outgoing ? 'What you paid' : 'What you received')
              : refund
              ? 'What came back to you'
              : 'What you paid',
          required: true,
          helper: isBill ? 'Enter 0.00 if none of it was yours.' : null,
        ),
      ],
      if (needsFundingConsent && p.linked != null) fundingConsent(),
      if (showsAccount)
        pickInput(
          'account',
          accountLabel,
          owned,
          required: true,
          descriptions: balanceLines(owned, 'account'),
        ),
      if (needsConsent) consentInput(),
      if (isBill || refund)
        amountInput(
          'shareAmount',
          refund ? 'How much your part went down' : 'Your part',
          required: true,
          helper: refund ? null : 'This is what counts as your spending.',
        ),
      if (showsCategory)
        pickInput(
          'category',
          'Category',
          c.categoryChoices('expense'),
          required: true,
        ),
      if (!locked) dateInput('date', 'Date', required: true),
      if (chosen != null)
        textInput(
          'reason',
          'Why you’re changing this',
          required: true,
          helper: 'Only you can see this.',
        ),
    ];
  }

  Widget fundingConsent() => Padding(
    key: anchor('acknowledgeFunding'),
    padding: gapAbove(),
    child: OptionPicker<String>(
      key: const ValueKey('native-select-acknowledgeFunding'),
      label: 'This changes what you paid',
      style: PickerStyle.radio,
      value: answer('acknowledgeFunding'),
      options: const [
        PickerOption(
          value: 'true',
          label: 'That is right',
          description: 'Update what you paid in your record.',
        ),
        PickerOption(
          value: 'false',
          label: 'Let me check',
          description: 'Keep what your record says for now.',
        ),
      ],
      onChanged: (x) {
        if (errorField == 'fundingAmount') errorField = errorMessage = null;
        changed('acknowledgeFunding', x);
      },
    ),
  );

  Widget review() => FinancialReview(
    plan: plan!,
    snapshot: reviewSnapshot!,
    amount: c.amount,
    hidden: c.amountsHidden,
    commandId: id,
    quietNotes: true,
    title: (r) => sharedRecordTitle(r.title),
  );

  Widget body(PrivateContext p) {
    if (saved) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InlineNotice(
            'Saved on this device. Only your own records changed.',
            title: switch (widget.mode) {
              'clear' => 'Counted in your group balance',
              'unclear' => 'Taken out of your group balance',
              _ => p.linked == null ? 'Added to your Money' : 'Record updated',
            },
            tone: NoticeTone.success,
            live: true,
          ),
          SizedBox(height: CompactForm.groupGap(context)),
          actions(
            FilledButton(
              key: const ValueKey('private-done'),
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      );
    }
    final form = reviewed == null ? formFields(p) : const <Widget>[];
    final inPlace = anchors.containsKey(errorField) && reviewed == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          InlineNotice(error!, tone: NoticeTone.error, live: true),
          SizedBox(height: CompactForm.fieldGap(context)),
        ],
        if (unknown) ...[
          const InlineNotice(
            lostResponseMessage,
            title: lostResponseTitle,
            tone: NoticeTone.warning,
            live: true,
          ),
          SizedBox(height: CompactForm.fieldGap(context)),
        ],
        if (busy) ...[
          FormStatus(
            title: syncing ? 'Checking your latest records…' : 'Saving…',
            message: 'Keep this form open while it finishes.',
            busy: true,
          ),
          SizedBox(height: CompactForm.fieldGap(context)),
        ],
        if (errorMessage != null && !inPlace) ...[
          InlineNotice(errorMessage!, tone: NoticeTone.error, live: true),
          SizedBox(height: CompactForm.fieldGap(context)),
        ],
        if (reviewed == null) ...form else ...[review(), ...syncNotices()],
        SizedBox(height: CompactForm.groupGap(context)),
        actions(
          unknown
              ? FilledButton(
                  key: const ValueKey('private-check-result'),
                  onPressed: busy ? null : checkResult,
                  child: const Text('Check the result'),
                )
              : FilledButton(
                  key: const ValueKey('private-submit'),
                  onPressed: busy ? null : save,
                  child: Text(
                    busy
                        ? 'Saving…'
                        : reviewed == null
                        ? 'Review'
                        : syncBlocked
                        ? 'Sync and save'
                        : 'Save to my records',
                  ),
                ),
          reviewed == null
              ? null
              : TextButton(
                  onPressed: busy || unknown
                      ? null
                      : () => setState(() {
                          reviewed = null;
                          plan = null;
                        }),
                  child: const Text('Edit'),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = private;
    final title = SharedPrivateForm.titleFor(
      widget.mode,
      linked: p?.linked != null,
    );
    return FormExitGuard(
      dirty: dirty && !saved,
      busy: busy || unknown,
      child: CompactForm(
        child: SectionPage(
          title: title,
          caption: saved || p == null
              ? null
              : reviewed == null
              ? 'Step 1 of 2 · Details · * Required'
              : 'Step 2 of 2 · Review',
          maxWidth: Space.formMaxWidth,
          child: SurfaceCard(
            child: loading
                ? const LoadingSkeleton.lines(label: 'your records', lines: 4)
                : p == null
                ? InlineNotice(
                    blocked ?? 'This can’t open right now.',
                    tone: NoticeTone.warning,
                    live: true,
                  )
                : body(p),
          ),
        ),
      ),
    );
  }
}

/// Keep my record as it is: the bill changed, and the user's record stays. It
/// reaches the server, because reviews follow the user to their other
/// devices, so it needs a connection. The id is made when the form opens, so
/// pressing again after a lost answer repeats the same review.
Future<bool?> showKeepRecord(
  BuildContext context,
  SharedHub hub,
  SharedGroup g,
  String bill,
  LocalRevision record,
) {
  final form = GlobalKey<_KeepRecordState>();
  return showAdaptiveModal<bool>(
    context,
    title: 'Keep my record as it is',
    purpose: ModalPurpose.choice,
    body: _KeepRecord(key: form, hub: hub, group: g, bill: bill, record: record),
    primary: ModalAction(
      'Keep my record',
      onPressed: () async => await form.currentState?.save() ?? false,
    ),
  );
}

class _KeepRecord extends StatefulWidget {
  const _KeepRecord({
    super.key,
    required this.hub,
    required this.group,
    required this.bill,
    required this.record,
  });
  final SharedHub hub;
  final SharedGroup group;
  final String bill;
  final LocalRevision record;
  @override
  State<_KeepRecord> createState() => _KeepRecordState();
}

class _KeepRecordState extends State<_KeepRecord> {
  String command = newLocalId();
  final reason = TextEditingController();
  String? reasonError, problem;
  bool lost = false;

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  /// Saves, and says whether the modal can close.
  Future<bool> save() async {
    final source = widget.hub.source();
    final why = reason.text.trim();
    setState(() {
      reasonError = why.isEmpty ? 'Say why it stays as it is.' : null;
      problem = null;
    });
    if (why.isEmpty) return false;
    if (!source.online) {
      setState(() => problem = 'This needs a connection. What you entered is kept.');
      return false;
    }
    try {
      await source.writer.keepRecord(
        id: command,
        group: widget.group.id,
        bill: widget.bill,
        record: widget.record.id,
        stamp: sharedSourceStamp(object(widget.group.bills[widget.bill])),
        reason: why,
      );
      return true;
    } on LocalRuleException catch (e) {
      // Refused: the next try is a new review.
      setState(() {
        problem = sharedReason(e.message);
        command = newLocalId();
        lost = false;
      });
    } catch (_) {
      setState(() => lost = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => CompactForm(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'The group’s bill changed. Your record stays as it is, and this notes that you checked it. Nothing goes to the group.',
        ),
        SizedBox(height: CompactForm.fieldGap(context)),
        if (lost) ...[
          const InlineNotice(
            lostResponseMessage,
            title: lostResponseTitle,
            tone: NoticeTone.warning,
            live: true,
          ),
          SizedBox(height: CompactForm.fieldGap(context)),
        ],
        if (problem != null) ...[
          InlineNotice(problem!, tone: NoticeTone.error, live: true),
          SizedBox(height: CompactForm.fieldGap(context)),
        ],
        HelpTextField(
          key: const ValueKey('keep-reason'),
          label: 'Why it stays as it is',
          controller: reason,
          required: true,
          readOnly: lost,
          helper: 'Only you can see this.',
          errorText: reasonError,
        ),
      ],
    ),
  );
}
