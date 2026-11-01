import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/previews.dart' show DemoActionPage;
import '../app/shell_navigation.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../finance/debt_cards.dart' show civilDay;
import '../finance/money_data.dart' show lastMonthEnd;
import '../local/finance_domain.dart';
import '../prototype/scenarios.dart' show AppDestination;
import 'shared_balances_tab.dart' show balancesUnavailable;
import 'shared_bill_form.dart';
import 'shared_cards.dart';
import 'shared_change_forms.dart';
import 'shared_data.dart';
import 'shared_domain.dart';
import 'shared_group_forms.dart';
import 'shared_history_tab.dart' show SharedHistoryPage;
import 'shared_header.dart';
import 'shared_hub.dart';
import 'shared_payment_form.dart';
import 'shared_people_data.dart';
import 'shared_person_pages.dart';
import 'shared_private_data.dart';
import 'shared_record_page.dart';

/// The pages and forms Shared Expenses opens. Each page reads the hub again
/// when it changes, so what's saved in a form shows as soon as it closes.

/// What only a real profile can do, because these forms need the encrypted
/// store. The demo opens a placeholder instead.
abstract class SharedPrivateActions {
  Future<void> privateBill(BuildContext context, SharedGroup g, String bill);
  Future<void> retainEvidence(BuildContext context, SharedGroup g, String bill);
  Future<void> privateEffect(
    BuildContext context,
    SharedGroup g,
    String key,
    String mode,
  );
}

/// Why a create action is off, or null when it's on.
String? cantAdd(SharedSource source, SharedGroup g) {
  final me = g.participant(source.actor ?? '');
  if (!g.active(me)) return 'You’ve left this group.';
  if (g.archived) return 'This group is archived.';
  return null;
}

class SharedFlows {
  const SharedFlows(this.hub);
  final SharedHub hub;
  SharedSource get source => hub.source();

  void _placeholder(BuildContext context, String label) => openDemoPage<void>(
    context,
    DemoActionPage(label: label),
    'shared/demo',
    title: label,
  );

  Future<void> createGroup(BuildContext context) async {
    if (await _online(context) && context.mounted) {
      await showCreateGroup(context, hub);
    }
  }

  Future<void> joinGroup(BuildContext context) async {
    if (await _online(context) && context.mounted) {
      await showJoinGroup(context, hub);
    }
  }

  /// Opens a group change, or says it needs a connection.
  Future<void> change(
    BuildContext context,
    Future<void> Function() open,
  ) async {
    if (await _online(context) && context.mounted) await open();
  }

  void addPerson(BuildContext context, SharedGroup g) =>
      change(context, () => showAddPerson(context, hub, g));
  void invite(BuildContext context, SharedGroup g, {String? person}) =>
      change(context, () => showInvite(context, hub, g, person: person));
  void revoke(BuildContext context, SharedGroup g, OpenInvitation i) =>
      change(context, () => showRevoke(context, hub, g, i));
  void transfer(BuildContext context, SharedGroup g, {String? person}) =>
      change(context, () => showTransfer(context, hub, g, person: person));
  void remove(BuildContext context, SharedGroup g, {String? person}) =>
      change(context, () => showRemove(context, hub, g, person: person));
  void archive(BuildContext context, SharedGroup g) =>
      change(context, () => showArchive(context, hub, g));
  void leave(BuildContext context, SharedGroup g, String me) =>
      change(context, () => showLeave(context, hub, g, me));

  /// Says so before a form opens that couldn't finish.
  Future<bool> _online(BuildContext context) async {
    if (source.online) return true;
    await showAdaptiveModal<void>(
      context,
      title: 'This needs a connection',
      body: const Text('Connect, then try again. Your records stay here.'),
      primary: null,
      secondary: const ModalAction.cancel(label: 'Close'),
    );
    return false;
  }

  /// Add shared expense from anywhere: with no connection it says so, and
  /// with no group it starts one (DOMAIN_RULES §4).
  Future<void> addBill(BuildContext context, {SharedGroup? group}) async {
    final s = source;
    if (!s.connected) {
      await _needsConnection(context);
      return;
    }
    final open = sharedGroupRows(s).where((r) => r.current).toList();
    if (group == null && open.isEmpty) {
      await createGroup(context);
      return;
    }
    if (!context.mounted) return;
    await openDemoPage<void>(
      context,
      SharedBillForm(
        hub: hub,
        group:
            group ??
            (open.length == 1
                ? open.single.group
                : open
                      .where((r) => r.group.id == hub.group(s)?.id)
                      .firstOrNull
                      ?.group),
      ),
      'shared/editor',
      title: 'Add shared expense',
    );
  }

  /// Asks which group, for an action that needs one before its form opens.
  Future<SharedGroup?> pickGroup(BuildContext context) async {
    final rows = sharedGroupRows(source).where((r) => r.current).toList();
    if (rows.length == 1) return rows.single.group;
    final id = await showAdaptiveModal<String>(
      context,
      title: 'Which group?',
      purpose: ModalPurpose.choice,
      primary: null,
      body: Builder(
        builder: (context) => ListGroup(
          children: [
            for (final r in rows)
              AdaptiveRow(
                key: ValueKey('pick-${r.group.id}'),
                title: r.group.name,
                subtitle: groupRowLine(r, source),
                onTap: () => Navigator.pop(context, r.group.id),
              ),
          ],
        ),
      ),
    );
    return rows.where((r) => r.group.id == id).firstOrNull?.group;
  }

  Future<void> _needsConnection(BuildContext context) async {
    final connect = await showAdaptiveModal<bool>(
      context,
      title: 'Connect this profile first',
      body: const Text(
        'Shared groups need a connected profile, because other people are in them. Your own records stay as they are.',
      ),
      primary: hub.openConnection == null
          ? null
          : const ModalAction('Connect', value: true),
    );
    if (connect == true) hub.openConnection?.call();
  }

  /// Log a payment between members from anywhere. Whatever stands in the
  /// way says so, rather than opening a form that can't be finished.
  Future<void> startPayment(BuildContext context, {SharedGroup? group}) async {
    final s = source;
    if (!s.connected) {
      await _needsConnection(context);
      return;
    }
    if (group == null && !sharedGroupRows(s).any((r) => r.current)) {
      await createGroup(context);
      return;
    }
    final shown = group ?? hub.group(s);
    final g = shown != null && cantAdd(s, shown) == null
        ? shown
        : await pickGroup(context);
    if (g == null || !context.mounted) return;
    if (g.people.length < 2) {
      await showAdaptiveModal<void>(
        context,
        title: 'Add someone first',
        body: const Text('A payment needs two people in the group.'),
        primary: null,
        secondary: const ModalAction.cancel(label: 'Close'),
      );
      return;
    }
    if (!context.mounted) return;
    await logPayment(context, g);
  }

  Future<void> logPayment(
    BuildContext context,
    SharedGroup g, {
    String? sender,
    String? recipient,
    String? draftId,
  }) => openDemoPage<void>(
    context,
    SharedPaymentForm(
      hub: hub,
      group: g,
      sender: sender,
      recipient: recipient,
      draftId: draftId,
    ),
    'shared/editor',
    title: SharedPaymentForm.title,
  );

  Future<bool> answer(
    BuildContext context,
    SharedGroup g,
    String payment,
    PaymentAnswer answer,
  ) => showPaymentAnswer(context, hub, g, payment, answer);

  Future<void> correct(BuildContext context, SharedGroup g, String bill) =>
      openDemoPage<void>(
        context,
        SharedBillForm(hub: hub, group: g, bill: bill),
        'shared/editor',
        title: 'Correct shared expense',
      );
  Future<void> refund(BuildContext context, SharedGroup g, String bill) =>
      openDemoPage<void>(
        context,
        SharedRefundForm(hub: hub, group: g, bill: bill),
        'shared/editor',
        title: 'Log a refund',
      );

  void openBill(BuildContext context, SharedGroup g, String bill) =>
      openDemoPage<void>(
        context,
        SharedBillPage(hub: hub, group: g.id, bill: bill),
        'shared/bill/$bill',
        title: g.revision(bill)['name'] as String,
      );
  void openPayment(BuildContext context, SharedGroup g, String payment) =>
      openDemoPage<void>(
        context,
        SharedPaymentPage(hub: hub, group: g.id, payment: payment),
        'shared/payment/$payment',
        title: 'Payment',
      );
  void openBillsList(BuildContext context, SharedGroup g) => openDemoPage<void>(
    context,
    SharedBillsPage(hub: hub, group: g.id),
    'shared/bills',
    title: 'Bills',
  );
  void openPaymentsList(BuildContext context, SharedGroup g) =>
      openDemoPage<void>(
        context,
        SharedPaymentsPage(hub: hub, group: g.id),
        'shared/payments',
        title: 'Payments',
      );
  void openPerson(
    BuildContext context,
    SharedGroup g,
    String person, {
    bool list = false,
  }) => openDemoPage<void>(
    context,
    SharedPersonPage(hub: hub, group: g.id, person: person, list: list),
    'shared/person/$person',
    title: g.personName(person),
  );

  /// Between two people. [a] is the side the figures read from.
  void openPair(
    BuildContext context,
    SharedGroup g,
    String a,
    String b, {
    bool list = false,
  }) => openDemoPage<void>(
    context,
    SharedPairPage(hub: hub, group: g.id, a: a, b: b, list: list),
    'shared/pair/$a/$b',
    title: 'Between two people',
  );
  void openHistoryList(BuildContext context, SharedGroup g) =>
      openDemoPage<void>(
        context,
        SharedHistoryPage(hub: hub, group: g.id),
        'shared/history',
        title: 'History',
      );
  void openWhoOwes(BuildContext context, SharedGroup g) => openDemoPage<void>(
    context,
    SharedWhoOwesPage(hub: hub, group: g.id),
    'shared/who-owes',
    title: 'Who owes whom',
  );
  void openRecord(BuildContext context, SharedGroup g, PrivateRow r) =>
      openDemoPage<void>(
        context,
        SharedRecordPage(hub: hub, group: g.id, kind: r.kind, id: r.id),
        'shared/record/${r.id}',
        title: r.title,
      );
  void openSplit(BuildContext context, SharedGroup g, String bill) =>
      openDemoPage<void>(
        context,
        SharedSplitPage(hub: hub, group: g.id, bill: bill),
        'shared/split/$bill',
        title: g.revision(bill)['name'] as String,
      );

  /// From a record in Money: the group it's linked to, on the right tab, with
  /// the bill or payment open. Says so if that group isn't on this device.
  Future<void> openLinked(
    BuildContext context,
    Map<String, String> values,
  ) async {
    final shell = ShellNavigation.maybeOf(context);
    final key = values['sharedKey'], mode = values['sharedMode'];
    final g = source.groups
        .where((x) => x.id == values['sharedGroup'])
        .firstOrNull;
    if (shell == null || key == null) return;
    if (g == null) {
      await showAdaptiveModal<void>(
        context,
        title: 'This group isn’t here',
        body: const Text(
          'It may not have reached this device yet. Connect and try again.',
        ),
        primary: null,
        secondary: const ModalAction.cancel(label: 'Close'),
      );
      return;
    }
    final bill = switch (mode) {
      'bill' => g.bills.containsKey(key) ? key : null,
      'refund' =>
        g.bills.entries
            .where(
              (b) => (b.value['refunds'] as List).any((f) => f['id'] == key),
            )
            .firstOrNull
            ?.key,
      _ => null,
    };
    final payment = g.settlements.containsKey(key) ? key : null;
    hub.choose(g.id);
    await shell.select(
      AppDestination.shared,
      tab: bill != null ? 'Bills' : 'Payments',
    );
    final content = shell.navigatorKey.currentContext;
    if (content == null || !content.mounted || shell.hasPages) return;
    if (bill != null) {
      openBill(content, g, bill);
    } else if (payment != null) {
      openPayment(content, g, payment);
    }
  }

  void openGroup(BuildContext context, SharedGroup g) => openDemoPage<void>(
    context,
    SharedGroupPage(hub: hub, group: g.id),
    'shared/group/${g.id}',
    title: g.name,
  );
  Future<void> private(
    BuildContext context,
    Future<void> Function(SharedPrivateActions) run,
  ) async {
    final forms = hub.private;
    if (forms == null) {
      _placeholder(context, 'Add to my Money');
    } else {
      await run(forms);
    }
  }

  /// A task on a card: a draft opens its form, a change linked to Money opens
  /// its bill, and saved work says where it stands.
  Future<void> openTask(
    BuildContext context,
    SharedGroup g,
    SharedTask task,
  ) async {
    switch (task.kind) {
      case SharedTaskKind.draft:
        await openDraft(context, task.id);
      case SharedTaskKind.changed:
        if (g.bills.containsKey(task.id)) openBill(context, g, task.id);
      case _:
        await openWork(context, task.id);
    }
  }

  /// Opens a saved draft. Whatever has changed since, it opens or says why
  /// it can't, with a way to discard it: tapping a draft never fails.
  Future<void> openDraft(BuildContext context, String id) async {
    final s = source;
    final row = s.drafts.where((d) => d['id'] == id).firstOrNull;
    if (row == null) return;
    final payload = object(jsonDecode(row['payload'] as String));
    final g = s.groups.where((x) => x.id == row['group_id']).firstOrNull;
    final bill = payload['source'] as String?;
    final why = g == null
        ? 'Its group isn’t on this device yet. Connect and it comes back.'
        : g.archived || !g.active(g.participant(s.actor ?? ''))
        ? 'This group can’t take changes now.'
        : bill != null && !g.bills.containsKey(bill)
        ? 'The bill it was changing isn’t here any more.'
        : null;
    if (why != null) {
      final discard = await showAdaptiveModal<bool>(
        context,
        title: draftTitle(payload, g),
        body: Text(why),
        primary: const ModalAction(
          'Discard draft',
          value: true,
          destructive: true,
        ),
        secondary: const ModalAction.cancel(label: 'Keep it'),
      );
      if (discard == true) await s.writer.discardDraft(id);
      return;
    }
    if (!context.mounted) return;
    if (payload['op'] == 'report') {
      await logPayment(context, g!, draftId: id);
    } else {
      await openDemoPage<void>(
        context,
        payload['refund'] == true
            ? SharedRefundForm(hub: hub, group: g!, bill: bill!, draftId: id)
            : SharedBillForm(hub: hub, group: g!, bill: bill, draftId: id),
        'shared/editor',
        title: payload['refund'] == true
            ? 'Log a refund'
            : bill == null
            ? 'Add shared expense'
            : 'Correct shared expense',
      );
    }
  }

  /// Where a saved command stands, and what can be done about it.
  Future<void> openWork(BuildContext context, String id) async {
    final s = source;
    final intent = s.intents.where((i) => i['id'] == id).firstOrNull;
    if (intent == null) return;
    final command = object(jsonDecode(intent['payload'] as String));
    final g = s.groups.where((x) => x.id == intent['group_id']).firstOrNull;
    final refused = intent['state'] == 'review';
    final op = command['op'] as String;
    final canDraft =
        refused &&
        g != null &&
        !g.archived &&
        g.active(g.participant(s.actor ?? '')) &&
        const ['bill', 'report'].contains(op);
    String? problem;
    final fix = await showAdaptiveModal<bool>(
      context,
      title: refused ? 'The group didn’t accept this' : intentTitle(command, g),
      body: StatefulBuilder(
        builder: (context, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (problem != null) ...[
              InlineNotice(problem!, tone: NoticeTone.error, live: true),
              const SizedBox(height: Space.md),
            ],
            _IntentFacts(
              command: command,
              group: g,
              state: intentState(intent),
              amount: s.amount,
            ),
            const SizedBox(height: Space.md),
            Text(
              refused
                  ? canDraft
                        ? 'Fix it starts a new draft from today’s group. This one stays on record.'
                        : 'This stays on record. Check the group and start again if you need to.'
                  : op == 'invite'
                  ? 'It’s kept on this device and won’t be sent twice. Its code can’t be shown again, so send a new invitation too.'
                  : 'It’s kept on this device and won’t be sent twice.',
            ),
          ],
        ),
      ),
      primary: canDraft
          ? const ModalAction('Fix it', value: true)
          : !refused && s.online
          ? ModalAction(
              'Send now',
              onPressed: () async {
                try {
                  await s.writer.retry(id);
                  return true;
                } on LocalRuleException catch (e) {
                  problem = sharedReason(e.message);
                } catch (_) {
                  problem = lostResponseMessage;
                }
                return false;
              },
            )
          : null,
      secondary: const ModalAction.cancel(label: 'Close'),
    );
    // Once the modal has closed, so the form opens on the page beneath it.
    if (fix == true && context.mounted) {
      await _correctedDraft(context, intent, command, g!);
    }
  }

  /// A new draft from a refused command, on the group as it is now. The
  /// original stays on record and keeps its link to the user's purchase.
  Future<void> _correctedDraft(
    BuildContext context,
    SharedJson intent,
    SharedJson command,
    SharedGroup group,
  ) async {
    final op = command['op'] as String, values = object(command['values']);
    final id = newLocalId();
    final fields = <String, String>{'date': values['date'] as String};
    if (op == 'bill') {
      fields.addAll({
        'name': values['name'] as String,
        'total': phpDecimal(sharedMinor(values['total'])),
        'method': values['method'] as String,
      });
      for (final person in group.people.keys) {
        fields['paid:$person'] = phpDecimal(
          sharedMinor(values['paid'][person] ?? '0'),
        );
        fields['include:$person'] =
            (values['shares'] as Map).containsKey(person) ? 'yes' : 'no';
        fields['share:$person'] = phpDecimal(
          sharedMinor(values['shares'][person] ?? '0'),
        );
      }
    } else {
      fields.addAll({
        'sender': values['sender'] as String,
        'recipient': values['recipient'] as String,
        'mode': values['mode'] as String,
        'amount': phpDecimal(sharedMinor(values['amount'])),
        'acknowledge': 'no',
      });
      for (final source in group.bills.keys) {
        fields['allocation:$source'] = phpDecimal(
          sharedMinor(values['allocations']?[source]?['amount'] ?? '0'),
        );
      }
    }
    await source.writer.draft(id, group.id, {
      'title': op == 'bill'
          ? 'Corrected shared expense draft'
          : 'Corrected payment draft',
      'op': op,
      'fields': fields,
    });
    if (op == 'bill') {
      await hub.repo?.carryPurchaseLink(intent['id'] as String, id, group.id);
    }
    if (!context.mounted) return;
    if (op == 'bill') {
      await openDemoPage<void>(
        context,
        SharedBillForm(hub: hub, group: group, draftId: id),
        'shared/editor',
        title: 'Add shared expense',
      );
    } else {
      await logPayment(context, group, draftId: id);
    }
  }
}

class _IntentFacts extends StatelessWidget {
  const _IntentFacts({
    required this.command,
    required this.group,
    required this.state,
    required this.amount,
  });
  final SharedJson command;
  final SharedGroup? group;
  final String state;
  final String Function(BigInt) amount;
  @override
  Widget build(BuildContext context) {
    final v = object(command['values'] ?? const <String, dynamic>{});
    String who(String? id) =>
        id == null ? 'Someone' : group?.personName(id) ?? 'Earlier member';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FactRow('What', intentTitle(command, group)),
        FactRow('Where it stands', state),
        if (v['date'] != null) FactRow('Date', civilDay(v['date'] as String)),
        if (v['total'] != null)
          FactRow('Total', amount(sharedMinor(v['total']))),
        if (command['op'] == 'report') ...[
          FactRow(
            'Between',
            '${who(v['sender'] as String?)} → ${who(v['recipient'] as String?)}',
          ),
          FactRow('Amount', amount(sharedMinor(v['amount']))),
        ],
        if (command['op'] == 'bill') ...[
          for (final p in object(v['paid']).entries)
            if (sharedMinor(p.value) > BigInt.zero)
              FactRow('${who(p.key)} paid', amount(sharedMinor(p.value))),
          for (final p in object(v['shares']).entries)
            FactRow('${who(p.key)}’s part', amount(sharedMinor(p.value))),
        ],
      ],
    );
  }
}

Widget sharedGonePage(String title, String where) => SectionPage(
  title: title,
  child: SurfaceCard(
    child: EmptyState(
      icon: Icons.history,
      title: 'This is no longer here',
      message: 'Go back to $where to see the others.',
    ),
  ),
);

/// The action that opens [label], off with a reason when it can't work now.
Widget billAction(
  String label, {
  required VoidCallback onPressed,
  required bool online,
  Key? key,
  bool primary = false,
  IconData? icon,
}) {
  const reason = 'This needs a connection.';
  return primary
      ? AppButton(
          label,
          key: key,
          icon: icon,
          onPressed: online ? onPressed : null,
          disabledReason: online ? null : reason,
        )
      : AppButton.secondary(
          label,
          key: key,
          icon: icon,
          onPressed: online ? onPressed : null,
          disabledReason: online ? null : reason,
        );
}

/// One bill: how it was split, what's been applied to it and its history.
class SharedBillPage extends StatelessWidget {
  const SharedBillPage({
    super.key,
    required this.hub,
    required this.group,
    required this.bill,
  });
  final SharedHub hub;
  final String group, bill;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([hub, hub.session]),
    builder: (context, _) {
      final source = hub.source();
      final g = source.groups.where((x) => x.id == group).firstOrNull;
      if (g == null || !g.bills.containsKey(bill)) {
        return sharedGonePage('Bill', 'Bills');
      }
      return _BillPage(hub: hub, source: source, g: g, bill: bill);
    },
  );
}

class _BillPage extends StatelessWidget {
  const _BillPage({
    required this.hub,
    required this.source,
    required this.g,
    required this.bill,
  });
  final SharedHub hub;
  final SharedSource source;
  final SharedGroup g;
  final String bill;

  @override
  Widget build(BuildContext context) {
    final flows = SharedFlows(hub);
    final a = source.amount, me = g.participant(source.actor ?? '');
    final b = object(g.bills[bill]), r = g.revision(bill);
    final refunds = b['refunds'] as List, revisions = b['revisions'] as List;
    final row = sharedBillRows(g, me).firstWhere((x) => x.id == bill);
    final split = billSplit(g, bill, me);
    final extra = extraCentavo(r);
    final creator = personLabel(g, b['creator'] as String, me);
    final linked = source.current
        .where(
          (x) =>
              x.values['sharedGroup'] == g.id &&
              x.values['sharedKey'] == bill &&
              x.values['sharedMode'] == 'bill',
        )
        .firstOrNull;
    final left = row.left;
    final standing = left == null || left == BigInt.zero
        ? 'Nothing left between you'
        : left > BigInt.zero
        ? 'You still owe ${a(left)} on this bill'
        : 'You’re still owed ${a(-left)} on this bill';
    final how = OverviewCard(
      key: const ValueKey('bill-split'),
      title: 'How it was split',
      caption: r['method'] == 'equal' ? 'Equally' : 'Exact amounts',
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoneyAmount(
            a(row.total),
            size: MoneySize.tile,
            textAlign: TextAlign.start,
          ),
          if (refunds.isNotEmpty)
            Text(
              '${a(sharedMinor(r['total']))} before refunds',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: Space.md),
          SharedMoneyTable(
            key: const ValueKey('bill-split-table'),
            label: 'Person',
            columns: const ['Paid', 'Part', 'Difference'],
            rows: [
              for (final p in split)
                (p.name, [a(p.paid), a(p.part), a(p.position)]),
            ],
          ),
          if (extra.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text(
              'Split to the centavo: the extra goes to ${extra.map((p) => personLabel(g, p, me)).join(' and ')}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
    final about = OverviewCard(
      key: const ValueKey('bill-about'),
      title: 'About this bill',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FactRow('Date', civilDay(r['date'] as String)),
          FactRow('Added by', creator),
          FactRow('Who paid', row.paidBy),
          if (row.part != null) FactRow('Your part', a(row.part!)),
          if (source.complete && g.complete) FactRow('Between you', standing),
          if (revisions.length > 1)
            FactRow('Edited', '${revisions.length - 1} times'),
        ],
      ),
    );
    final applied = billPayments(g, bill, me, source.today);
    final payments = OverviewCard(
      key: const ValueKey('bill-payments'),
      title: 'Payments on this bill',
      caption: 'Waiting ones don’t count until they’re confirmed',
      child: applied.isEmpty
          ? const EmptyState(
              icon: Icons.payments_outlined,
              title: 'No payments on this bill',
              message: 'Payments between members show here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListGroup(
                  children: [
                    for (final (p, amount) in applied)
                      AdaptiveRow(
                        key: ValueKey('bill-payment-${p.id}'),
                        title: p.who,
                        subtitle: detailLine([
                          civilDay(p.date),
                          paymentStatusLabel(p),
                        ]),
                        trailing: MoneyAmount(a(amount)),
                        onTap: () => flows.openPayment(context, g, p.id),
                      ),
                  ],
                ),
                const ListEnd(),
              ],
            ),
    );
    final refundCard = OverviewCard(
      key: const ValueKey('bill-refunds'),
      title: 'Refunds',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListGroup(
            children: [
              for (final f in refunds.reversed)
                AdaptiveRow(
                  key: ValueKey('bill-refund-${f['id']}'),
                  title: f['reason'] as String? ?? 'Refund',
                  subtitle: f['date'] == null
                      ? null
                      : civilDay(f['date'] as String),
                  trailing: MoneyAmount(a(sharedMinor(f['total']))),
                ),
            ],
          ),
          const ListEnd(),
        ],
      ),
    );
    final history = OverviewCard(
      key: const ValueKey('bill-history'),
      title: 'Edit history',
      caption: 'Earlier versions stay here',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListGroup(
            children: [
              for (final (i, v) in revisions.reversed.indexed)
                AdaptiveRow(
                  key: ValueKey('bill-version-${v['id']}'),
                  title: i == 0 ? 'Current version' : 'Earlier version',
                  subtitle: detailLine([
                    civilDay(v['date'] as String),
                    paidBy(g, object(v['paid']), me),
                    if ((v['reason'] as String? ?? '').isNotEmpty)
                      v['reason'] as String,
                  ]),
                  trailing: MoneyAmount(a(sharedMinor(v['total']))),
                ),
            ],
          ),
          const ListEnd(),
        ],
      ),
    );
    final mine = canChangeBill(g, bill, me);
    final canAdopt = g.active(me) || linked != null;
    final menu = [
      MenuItemButton(
        key: const ValueKey('bill-share'),
        leadingIcon: const Icon(Icons.open_in_new),
        onPressed: () => flows.openSplit(context, g, bill),
        child: const Text('Open the split as a page'),
      ),
      if (canAdopt)
        MenuItemButton(
          key: ValueKey('private-bill-$bill'),
          leadingIcon: const Icon(Icons.account_balance_wallet_outlined),
          onPressed: () => flows.private(
            context,
            (forms) => forms.privateBill(context, g, bill),
          ),
          child: Text(linked == null ? 'Add to my Money' : 'Review my record'),
        ),
      if (linked != null)
        MenuItemButton(
          key: ValueKey('private-retain-$bill'),
          leadingIcon: const Icon(Icons.rule_outlined),
          onPressed: () => flows.private(
            context,
            (forms) => forms.retainEvidence(context, g, bill),
          ),
          child: const Text('Keep my record as it is'),
        ),
      for (final f in refunds)
        MenuItemButton(
          key: ValueKey('private-refund-${f['id']}'),
          leadingIcon: const Icon(Icons.undo),
          onPressed: () => flows.private(
            context,
            (forms) =>
                forms.privateEffect(context, g, f['id'] as String, 'refund'),
          ),
          child: Text('Add ${a(sharedMinor(f['total']))} refund to my Money'),
        ),
    ];
    return SectionPage(
      title: r['name'] as String,
      caption:
          'Shared expense · ${civilDay(r['date'] as String)} · Added by $creator',
      status: revisions.length > 1 || refunds.isNotEmpty
          ? StatusPill(
              revisions.length > 1 ? 'Corrected' : 'Refunded',
              icon: revisions.length > 1 ? Icons.edit_outlined : Icons.undo,
            )
          : null,
      actions: [
        if (mine)
          billAction(
            'Correct',
            key: ValueKey('correct-bill-$bill'),
            icon: Icons.edit_outlined,
            primary: true,
            online: source.online,
            onPressed: () => flows.correct(context, g, bill),
          ),
        if (mine)
          billAction(
            'Log a refund',
            key: ValueKey('refund-bill-$bill'),
            icon: Icons.undo,
            online: source.online,
            onPressed: () => flows.refund(context, g, bill),
          ),
        CardMenu(
          key: const ValueKey('bill-menu'),
          tooltip: 'More',
          items: menu,
        ),
      ],
      child: DashboardGrid(
        cards: isDesktop(context)
            ? [
                (how, 8, 12),
                (about, 4, 12),
                (payments, 12, 12),
                ?(refunds.isEmpty ? null : (refundCard, 12, 12)),
                (history, 12, 12),
              ]
            : null,
        stacked: [
          how,
          about,
          payments,
          if (refunds.isNotEmpty) refundCard,
          history,
        ],
      ),
    );
  }
}

/// Where everyone stands, confirmed or if waiting payments are confirmed.
/// Used on the Group page and at the top of Balances.
class SharedPositionsCard extends StatefulWidget {
  const SharedPositionsCard({
    super.key,
    required this.source,
    required this.group,
    this.accent = false,
    this.onOpen,
  });
  final SharedSource source;
  final SharedGroup group;
  final bool accent;

  /// Opens a person's page from their row.
  final ValueChanged<String>? onOpen;
  @override
  State<SharedPositionsCard> createState() => _SharedPositionsCardState();
}

class _SharedPositionsCardState extends State<SharedPositionsCard> {
  bool projected = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group, a = widget.source.amount;
    final me = g.participant(widget.source.actor ?? '');
    Map<String, BigInt>? positions;
    if (g.complete && widget.source.complete) {
      try {
        positions = g.positions(projected: projected);
      } catch (_) {
        positions = null;
      }
    }
    return OverviewCard(
      key: const ValueKey('shared-positions'),
      title: 'Where everyone stands',
      caption: projected
          ? 'If waiting payments are confirmed'
          : 'Confirmed payments only',
      accent: widget.accent,
      stackBelow: periodBase + rowBase,
      trailing: MiniSegmented<bool>(
        label: 'Which payments count',
        options: const [(false, 'Confirmed'), (true, 'If confirmed')],
        selected: projected,
        onSelected: (v) => setState(() => projected = v),
      ),
      child: positions == null
          ? balancesUnavailable(widget.source)
          : ListGroup(
              children: [
                for (final p in positions.entries)
                  AdaptiveRow(
                    key: ValueKey('position-${p.key}'),
                    title: personLabel(g, p.key, me),
                    subtitle: detailLine([
                      if (!g.active(p.key)) 'Left',
                      p.value == BigInt.zero
                          ? 'All square'
                          : p.key == me
                          ? (p.value > BigInt.zero
                                ? 'Owed to you'
                                : 'You owe the group')
                          : p.value > BigInt.zero
                          ? 'Owed to them'
                          : 'Owes the group',
                    ]),
                    trailing: MoneyAmount(
                      a(p.value.abs()),
                      kind: p.value > BigInt.zero
                          ? MoneyKind.owedToYou
                          : p.value < BigInt.zero
                          ? MoneyKind.owed
                          : MoneyKind.neutral,
                    ),
                    onTap: widget.onOpen == null
                        ? null
                        : () => widget.onOpen!(p.key),
                  ),
              ],
            ),
    );
  }
}

/// A group's history entry in plain words.
String activityLabel(String? op) => switch (op) {
  'create' => 'Group created',
  'bill' => 'Bill added',
  'correct' => 'Bill corrected',
  'refund' => 'Refund logged',
  'report' => 'Payment logged',
  'resolve' => 'Payment answered',
  'manual' => 'Person added',
  'invite' => 'Invitation sent',
  'revoke' => 'Invitation revoked',
  'accept' => 'Someone joined',
  'leave' => 'Someone left',
  'remove' => 'Someone removed',
  'transfer' => 'Owner changed',
  'archive' => 'Group archived or restored',
  _ => 'Group changed',
};

/// One group: where everyone stands, what it is and what happened lately.
class SharedGroupPage extends StatelessWidget {
  const SharedGroupPage({super.key, required this.hub, required this.group});
  final SharedHub hub;
  final String group;

  /// How many history rows the page shows.
  static const recentRows = 5;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([hub, hub.session]),
    builder: (context, _) {
      final source = hub.source();
      final g = source.groups.where((x) => x.id == group).firstOrNull;
      if (g == null) return sharedGonePage('Group', 'Bills');
      final me = g.participant(source.actor ?? '');
      final flows = SharedFlows(hub);
      final left = !g.active(me);
      final shell = ShellNavigation.maybeOf(context);
      void tab(String name) => shell?.select(AppDestination.shared, tab: name);
      final activity = (g.data['activity'] as List).reversed
          .take(recentRows)
          .toList();
      final total = (g.data['activity'] as List).length;
      final about = OverviewCard(
        key: const ValueKey('group-about'),
        title: 'About this group',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FactRow('People', '${g.people.length}'),
            FactRow('Bills', '${g.bills.length}'),
            FactRow(
              'Owner',
              g.data['owner'] == null
                  ? 'Nobody'
                  : personLabel(g, g.data['owner'] as String, me),
            ),
            if (g.complete)
              FactRow('Group spending', source.amount(g.spending)),
            FactRow(
              'Where you stand',
              left
                  ? 'You’ve left this group'
                  : standingLine(sharedStanding(g, me), source.amount),
            ),
          ],
        ),
      );
      final recent = OverviewCard(
        key: const ValueKey('group-recent'),
        title: 'Recent activity',
        child: activity.isEmpty
            ? const EmptyState(
                icon: Icons.history,
                title: 'Nothing here yet',
                message: 'What happens in this group shows here.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListGroup(
                    children: [
                      for (final e in activity)
                        AdaptiveRow(
                          title: activityLabel(e['op'] as String?),
                          subtitle: [
                            ?civilDayOf(e['at'] as String?)?.let(civilDay),
                            if ((e['reason'] as String? ?? '').isNotEmpty)
                              e['reason'] as String,
                          ].join(' · '),
                        ),
                    ],
                  ),
                  ListEnd(
                    label: total > recentRows
                        ? '${total - recentRows} more in History'
                        : 'That’s everything',
                    onPressed: total > recentRows && shell != null
                        ? () => tab('History')
                        : null,
                  ),
                ],
              ),
      );
      final positions = SharedPositionsCard(
        source: source,
        group: g,
        accent: true,
        onOpen: (person) => flows.openPerson(context, g, person),
      );
      return SectionPage(
        title: g.name,
        caption: [
          '${g.people.length} ${g.people.length == 1 ? 'person' : 'people'}',
          if (g.data['owner'] == me && me != null) 'You’re the owner',
        ].join(' · '),
        status: left
            ? const StatusPill('You’ve left', icon: Icons.logout)
            : g.archived
            ? const StatusPill('Archived', icon: Icons.inventory_2_outlined)
            : null,
        actions: [
          if (cantAdd(source, g) == null)
            ChipButton(
              'Add shared expense',
              key: const ValueKey('group-add-bill'),
              icon: Icons.add,
              onPressed: () => flows.addBill(context, group: g),
            ),
          if (shell != null)
            CardMenu(
              key: const ValueKey('group-menu'),
              tooltip: 'More',
              items: [
                if (!left && !g.archived)
                  MenuItemButton(
                    key: const ValueKey('group-default'),
                    leadingIcon: Icon(
                      hub.defaultGroup == g.id
                          ? Icons.star
                          : Icons.star_outline,
                    ),
                    onPressed: () =>
                        hub.setDefault(hub.defaultGroup == g.id ? null : g.id),
                    child: Text(
                      hub.defaultGroup == g.id
                          ? 'Stop opening this first'
                          : 'Make this my default',
                    ),
                  ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.people_outline),
                  onPressed: () => tab('People'),
                  child: const Text('People'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.history),
                  onPressed: () => tab('History'),
                  child: const Text('History'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.inventory_2_outlined),
                  onPressed: () => tab('Manage Group'),
                  child: const Text('Archive or leave'),
                ),
              ],
            ),
        ],
        child: DashboardGrid(
          cards: isDesktop(context)
              ? [(positions, 8, 12), (about, 4, 12), (recent, 12, 12)]
              : null,
          stacked: [positions, about, recent],
        ),
      );
    },
  );
}

/// A payment event in plain words.
String paymentEventLabel(String? state) => switch (state) {
  'pending' => 'Logged',
  'confirmed' => 'Confirmed',
  'disputed' => 'Disputed',
  'cancelled' => 'Cancelled',
  'reversed' => 'Confirmation undone',
  _ => 'Changed',
};

/// One payment: what it does, what it's applied to and what's happened to it.
class SharedPaymentPage extends StatelessWidget {
  const SharedPaymentPage({
    super.key,
    required this.hub,
    required this.group,
    required this.payment,
  });
  final SharedHub hub;
  final String group, payment;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([hub, hub.session]),
    builder: (context, _) {
      final source = hub.source();
      final g = source.groups.where((x) => x.id == group).firstOrNull;
      if (g == null || !g.settlements.containsKey(payment)) {
        return sharedGonePage('Payment', 'Payments');
      }
      return _PaymentPage(hub: hub, source: source, g: g, id: payment);
    },
  );
}

class _PaymentPage extends StatelessWidget {
  const _PaymentPage({
    required this.hub,
    required this.source,
    required this.g,
    required this.id,
  });
  final SharedHub hub;
  final SharedSource source;
  final SharedGroup g;
  final String id;

  @override
  Widget build(BuildContext context) {
    final flows = SharedFlows(hub);
    final a = source.amount, me = g.participant(source.actor ?? '');
    final p = sharedPaymentRow(g, id, me, source.today);
    final choices = paymentChoices(g, id, me);
    final s = object(g.settlements[id]);
    final open =
        p.status == PaymentStatus.toConfirm ||
        p.status == PaymentStatus.waiting;
    final projection = open ? paymentProjection(g, p) : null;
    String owes(BigInt signed) => signed > BigInt.zero
        ? '${p.from} ${p.from == 'You' ? 'owe' : 'owes'} ${p.to == 'You' ? 'you' : p.to} ${a(signed)}'
        : signed < BigInt.zero
        ? '${p.to} ${p.to == 'You' ? 'owe' : 'owes'} ${p.from == 'You' ? 'you' : p.from} ${a(-signed)}'
        : 'Nothing is owed between them';
    final effect = OverviewCard(
      key: const ValueKey('payment-effect'),
      title: 'What this does',
      caption: switch (p.status) {
        PaymentStatus.toConfirm => 'It counts once you confirm it',
        PaymentStatus.waiting => 'It counts once it’s confirmed',
        PaymentStatus.confirmed => 'It counts in everyone’s balances',
        PaymentStatus.disputed => 'It doesn’t count while it’s disputed',
        PaymentStatus.cancelled => 'It doesn’t count: it was cancelled',
        PaymentStatus.reversed =>
          'It doesn’t count: its confirmation was undone',
      },
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoneyAmount(
            a(p.amount),
            size: MoneySize.tile,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: Space.sm),
          if (projection != null) ...[
            FactRow('Confirmed so far', owes(projection.$1)),
            FactRow('If it’s confirmed', owes(projection.$2)),
          ],
          const FactRow(
            'Your accounts',
            'Unchanged. This records a payment made elsewhere.',
          ),
        ],
      ),
    );
    final about = OverviewCard(
      key: const ValueKey('payment-about'),
      title: 'About this payment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FactRow('From', p.from),
          FactRow('To', p.to),
          FactRow('Date paid', civilDay(p.date)),
          FactRow('Status', paymentStatusLabel(p)),
          if (p.waitingDays != null)
            FactRow('Waiting', waitedFor(p.waitingDays!)),
          if (p.manual)
            FactRow('Confirmed by', 'The owner. ${p.to} didn’t sign in.'),
        ],
      ),
    );
    final applied = OverviewCard(
      key: const ValueKey('payment-applied'),
      title: 'Applied to',
      child: p.applied.isEmpty && p.ahead == BigInt.zero
          ? const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Not on any bill',
              message: 'Bills it’s applied to show here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListGroup(
                  children: [
                    for (final b in p.applied.entries)
                      AdaptiveRow(
                        key: ValueKey('applied-${b.key}'),
                        title: g.bills.containsKey(b.key)
                            ? g.revision(b.key)['name'] as String
                            : 'Earlier bill',
                        trailing: MoneyAmount(a(b.value)),
                        onTap: g.bills.containsKey(b.key)
                            ? () => flows.openBill(context, g, b.key)
                            : null,
                      ),
                    if (p.ahead > BigInt.zero)
                      AdaptiveRow(
                        title: 'Paid ahead',
                        subtitle: 'More than was owed, on no bill',
                        trailing: MoneyAmount(a(p.ahead)),
                      ),
                  ],
                ),
                const ListEnd(),
              ],
            ),
    );
    final history = OverviewCard(
      key: const ValueKey('payment-history'),
      title: 'History',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListGroup(
            children: [
              for (final e in ((s['events'] as List?) ?? const []).reversed)
                AdaptiveRow(
                  title: paymentEventLabel(e['state'] as String?),
                  subtitle: [
                    ?civilDayOf(e['at'] as String?)?.let(civilDay),
                    if ((e['reason'] as String? ?? '').isNotEmpty)
                      e['reason'] as String,
                  ].join(' · '),
                ),
            ],
          ),
          const ListEnd(),
        ],
      ),
    );
    final party = p.role != PaymentRole.other;
    final links = paymentLinks(source.current, g.id, id);
    void private(String mode) => flows.private(
      context,
      (forms) => forms.privateEffect(context, g, id, mode),
    );
    final menu = [
      if (party && links.canAdd(p.status))
        MenuItemButton(
          key: ValueKey('private-payment-$id'),
          leadingIcon: const Icon(Icons.account_balance_wallet_outlined),
          onPressed: () => private('payment'),
          child: Text(links.added ? 'Review my record' : 'Add to my Money'),
        ),
      if (party && links.canCount(p.status))
        MenuItemButton(
          key: ValueKey('private-clear-$id'),
          leadingIcon: const Icon(Icons.rule_outlined),
          onPressed: () => private('clear'),
          child: const Text('Count it in my group balance'),
        ),
      if (party && links.canTakeOut(p.status))
        MenuItemButton(
          key: ValueKey('private-unclear-$id'),
          leadingIcon: const Icon(Icons.undo),
          onPressed: () => private('unclear'),
          child: const Text('Take it out of my group balance'),
        ),
    ];
    Widget answer(PaymentAnswer answer, {bool primary = false}) => billAction(
      answer.title,
      key: ValueKey('payment-${answer.name}'),
      primary: primary,
      online: source.online,
      onPressed: () => flows.answer(context, g, id, answer),
    );
    return SectionPage(
      title: p.who,
      caption: 'Payment between members · ${civilDay(p.date)}',
      status: paymentPill(p),
      actions: [
        if (choices.confirm) answer(PaymentAnswer.confirm, primary: true),
        if (choices.dispute) answer(PaymentAnswer.dispute),
        if (choices.undo) answer(PaymentAnswer.undo),
        if (choices.cancel) answer(PaymentAnswer.cancel),
        if (menu.isNotEmpty)
          CardMenu(
            key: const ValueKey('payment-menu'),
            tooltip: 'More',
            items: menu,
          ),
      ],
      child: DashboardGrid(
        cards: isDesktop(context)
            ? [
                (effect, 8, 12),
                (about, 4, 12),
                (applied, 6, 12),
                (history, 6, 12),
              ]
            : null,
        stacked: [effect, about, applied, history],
      ),
    );
  }
}

/// What a shareable list covers.
enum SharedPeriod {
  thisMonth('This month'),
  lastMonth('Last month'),
  all('All dates');

  const SharedPeriod(this.label);
  final String label;

  /// Whether [date] falls in the period.
  bool holds(String date, String today) => switch (this) {
    thisMonth => monthOf(date) == monthOf(today),
    lastMonth => monthOf(date) == monthOf(lastMonthEnd(today)),
    all => true,
  };

  String heading(String today) => switch (this) {
    thisMonth => monthHeading(today),
    lastMonth => monthHeading(lastMonthEnd(today)),
    all => 'All dates',
  };
}

/// A list to show other people: one heading, the totals and every item, so
/// one screenshot says it all (§2 Shareable views).
class ShareablePage extends StatelessWidget {
  const ShareablePage({
    super.key,
    required this.title,
    required this.group,
    required this.period,
    required this.onPeriod,
    required this.as,
    required this.stats,
    required this.child,
    required this.empty,
  });
  final String title, group, as;
  final SharedPeriod period;
  final ValueChanged<SharedPeriod> onPeriod;
  final List<Stat> stats;
  final Widget child;
  final bool empty;
  @override
  Widget build(BuildContext context) => ShareableList<SharedPeriod>(
    title: title,
    caption: group,
    heading: period.heading(as),
    asOf: 'As of ${civilDay(as)}',
    periods: [for (final p in SharedPeriod.values) (p, p.label)],
    period: period,
    onPeriod: onPeriod,
    periodKey: const ValueKey('shared-period'),
    listKey: const ValueKey('shared-list'),
    stats: stats,
    empty: empty,
    child: child,
  );
}

/// A group's bills for a period, with no row limit.
class SharedBillsPage extends StatefulWidget {
  const SharedBillsPage({super.key, required this.hub, required this.group});
  final SharedHub hub;
  final String group;
  @override
  State<SharedBillsPage> createState() => _SharedBillsPageState();
}

class _SharedBillsPageState extends State<SharedBillsPage> {
  var period = SharedPeriod.thisMonth;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.hub, widget.hub.session]),
    builder: (context, _) {
      final source = widget.hub.source();
      final g = source.groups.where((x) => x.id == widget.group).firstOrNull;
      if (g == null) return sharedGonePage('Bills', 'Bills');
      final a = source.amount, me = g.participant(source.actor ?? '');
      final text = Theme.of(context).textTheme;
      final rows = [
        for (final r in sharedBillRows(g, me))
          if (period.holds(r.date, source.today)) r,
      ].reversed.toList();
      return ShareablePage(
        title: 'Bills',
        group: g.name,
        period: period,
        onPeriod: (p) => setState(() => period = p),
        as: source.today,
        empty: rows.isEmpty,
        stats: [
          (
            label: 'Total shared',
            value: a(sumMinor(rows.map((r) => r.total))),
            detail: null,
          ),
          (
            label: 'Your part',
            value: a(sumMinor(rows.map((r) => r.part ?? BigInt.zero))),
            detail: null,
          ),
          (label: 'Bills', value: '${rows.length}', detail: null),
        ],
        child: AppTable(
          key: const ValueKey('shared-list-table'),
          dense: true,
          columns: const [
            (label: 'Date', flex: 0, width: dateColumn),
            (label: 'Bill', flex: 2, width: null),
            (label: 'Paid by', flex: 2, width: null),
          ],
          moneyColumns: const ['Total', 'Your part'],
          rows: [
            for (final r in rows)
              AppTableRow(
                id: r.id,
                money: [a(r.total), r.part == null ? null : a(r.part!)],
                spoken: '${r.name}, ${civilDay(r.date)}, ${r.paidBy}',
                cells: [
                  Text(civilDay(r.date), style: text.bodySmall),
                  Text(r.name, style: text.bodyMedium),
                  Text(r.paidBy, style: text.bodySmall),
                ],
                narrow: AdaptiveRow(
                  title: r.name,
                  subtitle: detailLine([
                    civilDay(r.date),
                    r.paidBy,
                    'Total ${a(r.total)}',
                  ]),
                  trailing: MoneyAmount(r.part == null ? null : a(r.part!)),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// A group's payments for a period, with no row limit.
class SharedPaymentsPage extends StatefulWidget {
  const SharedPaymentsPage({super.key, required this.hub, required this.group});
  final SharedHub hub;
  final String group;
  @override
  State<SharedPaymentsPage> createState() => _SharedPaymentsPageState();
}

class _SharedPaymentsPageState extends State<SharedPaymentsPage> {
  var period = SharedPeriod.thisMonth;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.hub, widget.hub.session]),
    builder: (context, _) {
      final source = widget.hub.source();
      final g = source.groups.where((x) => x.id == widget.group).firstOrNull;
      if (g == null) return sharedGonePage('Payments', 'Payments');
      final a = source.amount, me = g.participant(source.actor ?? '');
      final rows = [
        for (final p in sharedPaymentRows(g, me, source.today))
          if (period.holds(p.date, source.today)) p,
      ].reversed.toList();
      final (confirmed, _) = paymentTotal(
        rows.where((p) => p.status == PaymentStatus.confirmed),
      );
      final (waiting, _) = paymentTotal(
        rows.where(
          (p) =>
              p.status == PaymentStatus.toConfirm ||
              p.status == PaymentStatus.waiting,
        ),
      );
      return ShareablePage(
        title: 'Payments',
        group: g.name,
        period: period,
        onPeriod: (p) => setState(() => period = p),
        as: source.today,
        empty: rows.isEmpty,
        stats: [
          (label: 'Confirmed', value: a(confirmed), detail: null),
          (label: 'Waiting', value: a(waiting), detail: null),
          (label: 'Payments', value: '${rows.length}', detail: null),
        ],
        child: paymentTable(context, g, rows, a, null),
      );
    },
  );
}

/// One bill's split, to show someone how it was divided.
class SharedSplitPage extends StatelessWidget {
  const SharedSplitPage({
    super.key,
    required this.hub,
    required this.group,
    required this.bill,
  });
  final SharedHub hub;
  final String group, bill;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([hub, hub.session]),
    builder: (context, _) {
      final source = hub.source();
      final g = source.groups.where((x) => x.id == group).firstOrNull;
      if (g == null || !g.bills.containsKey(bill)) {
        return sharedGonePage('Bill', 'Bills');
      }
      final a = source.amount, me = g.participant(source.actor ?? '');
      final r = g.revision(bill), refunds = g.bills[bill]['refunds'] as List;
      final row = sharedBillRows(g, me).firstWhere((x) => x.id == bill);
      final extra = extraCentavo(r);
      return SectionPage(
        title: r['name'] as String,
        caption: g.name,
        child: OverviewCard(
          key: const ValueKey('shared-split'),
          title: civilDay(r['date'] as String),
          caption: 'As of ${civilDay(source.today)}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatStrip(
                stats: [
                  (label: 'Total', value: a(row.total), detail: null),
                  (label: 'Paid by', value: row.paidBy, detail: null),
                  if (refunds.isNotEmpty)
                    (
                      label: 'Before refunds',
                      value: a(sharedMinor(r['total'])),
                      detail: null,
                    ),
                ],
              ),
              const SizedBox(height: Space.md),
              SharedMoneyTable(
                label: 'Person',
                columns: const ['Paid', 'Part'],
                rows: [
                  for (final p in billSplit(g, bill, me))
                    (p.name, [a(p.paid), a(p.part)]),
                ],
              ),
              if (extra.isNotEmpty) ...[
                const SizedBox(height: Space.sm),
                Text(
                  'Split to the centavo: the extra goes to ${extra.map((p) => personLabel(g, p, me)).join(' and ')}.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const ListEnd(),
            ],
          ),
        ),
      );
    },
  );
}

extension _Let<T> on T {
  R let<R>(R Function(T) next) => next(this);
}
