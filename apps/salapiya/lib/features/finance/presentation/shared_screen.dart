import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../shared/shared_balances_tab.dart';
import '../../../shared/shared_bills_tab.dart';
import '../../../shared/shared_chooser.dart';
import '../../../shared/shared_data.dart';
import '../../../shared/shared_domain.dart';
import '../../../shared/shared_header.dart';
import '../../../shared/shared_history_tab.dart';
import '../../../shared/shared_hub.dart';
import '../../../shared/shared_lifecycle_tab.dart';
import '../../../shared/shared_pages.dart';
import '../../../shared/shared_payment_form.dart';
import '../../../shared/shared_payments_tab.dart';
import '../../../shared/shared_people_tab.dart';
import '../../../shared/shared_records_tab.dart';

import '../../../app/shell_navigation.dart';
import '../../../design_system/kit/kit.dart';
import '../../../design_system/theme.dart';
import '../../../prototype/scenarios.dart';
import '../application/financial_controller.dart';

/// Shared Expenses' tabs, as the shell lists them.
const sharedTabs = [
  'Bills',
  'Payments',
  'Balances',
  'People',
  'My Records',
  'History',
  'Manage Group',
];

/// The section's frame, on both builds: the header, the tabs and the notices.
/// Every tab is the same on both; only the private forms need a real profile.
class SharedScreen extends StatefulWidget {
  const SharedScreen({
    super.key,
    required this.session,
    this.initial = 'Bills',
    this.hub,
  });
  final PrototypeSession session;
  final String initial;

  /// The shell's, so what the section shows survives a change of tab.
  final SharedHub? hub;
  @override
  State<SharedScreen> createState() => _SharedScreenState();
}

class _SharedScreenState extends State<SharedScreen> {
  late String tab = widget.initial;
  SharedHub? own;
  SharedHub get hub => widget.hub ?? (own ??= SharedHub(widget.session));
  SharedFlows get flows => SharedFlows(hub);
  FinancialController get c => widget.session.finance;
  String money(BigInt v) => widget.session.amount(v);

  @override
  void dispose() {
    own?.dispose();
    super.dispose();
  }

  void select(String next) {
    ShellNavigation.reportTab(context, next);
    setState(() => tab = next);
  }

  List<QuickAction> headerActions(SharedSource source, SharedGroup? g) {
    if (g == null) {
      return source.groups.isEmpty
          ? const []
          : [
              (
                label: 'Create a group',
                icon: Icons.add,
                onSelected: () => flows.createGroup(context),
              ),
              (
                label: 'Join with a code',
                icon: Icons.vpn_key_outlined,
                onSelected: () => flows.joinGroup(context),
              ),
            ];
    }
    if (cantAdd(source, g) != null) return const [];
    return [
      (
        label: 'Add shared expense',
        icon: Icons.add,
        onSelected: () => flows.addBill(context, group: g),
      ),
      if (g.people.length > 1)
        (
          label: 'Log a payment between members',
          icon: Icons.payments_outlined,
          onSelected: () => flows.startPayment(context, group: g),
        ),
    ];
  }

  /// Under the tabs, only when they apply.
  List<Widget> notices(SharedSource source, SharedGroup? g) {
    final me = g?.participant(source.actor ?? '');
    return [
      if (source.error != null)
        InlineNotice(source.error!, tone: NoticeTone.error, live: true),
      if (!source.complete)
        const InlineNotice(
          'Amounts show once all your records have downloaded.',
          title: 'Your first download isn’t finished',
          tone: NoticeTone.warning,
        ),
      if (source.connected && !source.online)
        const InlineNotice(
          'New bills and payments wait here. Other changes need a connection.',
          title: 'You’re offline',
        ),
      if (source.pendingCount > 0)
        InlineNotice(
          '${source.pendingCount} ${source.pendingCount == 1 ? 'change is' : 'changes are'} waiting for the group.',
          live: true,
        ),
      if (source.needsReview)
        InlineNotice(
          source.syncLabel,
          title: 'Sync needs review',
          tone: NoticeTone.warning,
          action: source.onReview == null
              ? null
              : AppButton.secondary('Review', onPressed: source.onReview!),
        ),
      if (g != null && !g.active(me))
        const InlineNotice(
          'You’ve left this group, so these are only your earlier records.',
        )
      else if (g != null && g.archived)
        const InlineNotice(
          'This group is archived. Its records stay here, and it can’t change.',
        ),
    ];
  }

  /// What shows when there's no group to look at.
  Widget noGroup(SharedSource source) {
    if (!source.loaded) {
      return const SurfaceCard(
        key: ValueKey('shared-loading'),
        child: LoadingSkeleton.lines(label: 'your groups', lines: 4),
      );
    }
    if (!source.connected) {
      return SurfaceCard(
        key: const ValueKey('shared-connect'),
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Shared groups need a connected profile',
          message: 'Other people are in them, so they need a connection. Your own records stay available offline.',
          action: source.onConnect == null
              ? null
              : AppButton(
                  'Connect',
                  key: const ValueKey('shared-connect-action'),
                  icon: Icons.cloud_outlined,
                  onPressed: source.onConnect!,
                ),
        ),
      );
    }
    final offline = !source.online;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          key: const ValueKey('shared-empty'),
          child: EmptyState(
            icon: Icons.people_outline,
            title: offline ? 'Connect to see your groups' : 'No groups yet',
            message: offline ? 'Your groups come down when you’re online.' : 'Create a group to start sharing bills, or join one with a code.',
            action: offline
                ? null
                : AppButton(
                    'Create a group',
                    key: const ValueKey('shared-create'),
                    icon: Icons.add,
                    onPressed: () => flows.createGroup(context),
                  ),
          ),
        ),
        if (!offline) ...[
          const SizedBox(height: Space.xs),
          Center(
            child: CardLink(
              'Join with a code',
              key: const ValueKey('shared-join'),
              onPressed: () => flows.joinGroup(context),
            ),
          ),
        ],
        if (source.drafts.isNotEmpty) ...[
          SizedBox(height: Space.cardGapOf(context)),
          OverviewCard(
            key: const ValueKey('shared-drafts'),
            title: 'Saved drafts',
            child: ListGroup(
              leading: true,
              children: [
                for (final d in source.drafts)
                  AdaptiveRow(
                    key: ValueKey('shared-draft-${d['id']}'),
                    leading: Icons.edit_note,
                    title: draftTitle(
                      object(jsonDecode(d['payload'] as String)),
                      null,
                    ),
                    subtitle: 'Draft · its group isn’t here yet',
                    onTap: () => flows.openDraft(context, d['id'] as String),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget body(SharedSource source, SharedGroup g) {
    if (tab == 'Bills') {
      return SharedBillsTab(
        key: ValueKey('shared-bills-tab-${g.id}'),
        source: source,
        group: g,
        onOpenBill: (r) => r.waiting
            ? flows.openWork(context, r.id)
            : flows.openBill(context, g, r.id),
        onTask: (t) => flows.openTask(context, g, t),
        onAdd: cantAdd(source, g) == null
            ? () => flows.addBill(context, group: g)
            : null,
        onPeople: () => select('People'),
        onPayments: () => select('Payments'),
        onPage: () => flows.openBillsList(context, g),
      );
    }
    if (tab == 'Payments') {
      final open = cantAdd(source, g) == null && g.people.length > 1;
      return SharedPaymentsTab(
        key: ValueKey('shared-payments-tab-${g.id}'),
        source: source,
        group: g,
        onOpen: (p) => flows.openPayment(context, g, p.id),
        onConfirm: source.online
            ? (p) => flows.answer(context, g, p.id, PaymentAnswer.confirm)
            : null,
        onLog: open
            ? (person) => flows.logPayment(context, g, recipient: person)
            : null,
        onTask: (t) => flows.openTask(context, g, t),
        onBalances: () => select('Balances'),
        onPage: () => flows.openPaymentsList(context, g),
        onPair: (person) {
          final me = g.participant(source.actor ?? '');
          if (me != null) flows.openPair(context, g, me, person);
        },
      );
    }
    if (tab == 'Balances') {
      final open = cantAdd(source, g) == null && g.people.length > 1;
      return SharedBalancesTab(
        key: ValueKey('shared-balances-tab-${g.id}'),
        source: source,
        group: g,
        onPair: (a, b) => flows.openPair(context, g, a, b),
        onPerson: (person) => flows.openPerson(context, g, person),
        onLog: open
            ? (sender, recipient) => flows.logPayment(
                context,
                g,
                sender: sender,
                recipient: recipient,
              )
            : null,
        onPayments: () => select('Payments'),
        onPeople: () => select('People'),
        onPage: () => flows.openWhoOwes(context, g),
      );
    }
    if (tab == 'My Records') {
      return SharedRecordsTab(
        key: ValueKey('shared-records-tab-${g.id}'),
        source: source,
        group: g,
        onOpen: (r) => flows.openRecord(context, g, r),
      );
    }
    if (tab == 'People') {
      return SharedPeopleTab(
        key: ValueKey('shared-people-tab-${g.id}'),
        source: source,
        group: g,
        onPerson: (person) => flows.openPerson(context, g, person),
        onAdd: () => flows.addPerson(context, g),
        onInvite: () => flows.invite(context, g),
        onRevoke: (i) => flows.revoke(context, g, i),
        onTask: (t) => flows.openTask(context, g, t),
      );
    }
    if (tab == 'History') {
      return SharedHistoryTab(
        key: ValueKey('shared-history-tab-${g.id}'),
        source: source,
        group: g,
        onRow: (r) {
          if (r.bill != null) {
            flows.openBill(context, g, r.bill!);
          } else if (r.payment != null) {
            flows.openPayment(context, g, r.payment!);
          }
        },
        onPage: () => flows.openHistoryList(context, g),
      );
    }
    return SharedLifecycleTab(
      key: ValueKey('shared-lifecycle-tab-${g.id}'),
      source: source,
      group: g,
      onTransfer: () => flows.transfer(context, g),
      onRemove: () => flows.remove(context, g),
      onArchive: () => flows.archive(context, g),
      onLeave: () {
        final me = g.participant(source.actor ?? '');
        if (me != null) flows.leave(context, g, me);
      },
      onTask: (t) => flows.openTask(context, g, t),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, widget.session, hub]),
    builder: (context, _) {
      final source = hub.source();
      final g = hub.group(source);
      // Asked to choose, or several groups and none to open by itself.
      final chooser = g == null && source.loaded && source.groups.isNotEmpty;
      final me = g?.participant(source.actor ?? '');
      final toConfirm = g == null
          ? 0
          : g.settlements.values
                .where((s) => s['state'] == 'pending' && s['recipient'] == me)
                .length;
      final gap = SizedBox(height: Space.cardGapOf(context));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SharedHeader(
            key: const ValueKey('shared-header'),
            source: source,
            group: g,
            actions: headerActions(source, g),
            toConfirm: toConfirm,
            onToConfirm: () => select('Payments'),
            onChoose: hub.choose,
            onCreate: () => flows.createGroup(context),
            onJoin: () => flows.joinGroup(context),
            onAll: hub.showChooser,
            onAbout: () {
              if (g != null) flows.openGroup(context, g);
            },
            count: chooser ? source.groups.length : 0,
          ),
          if (g != null) ...[
            // Android's header row is already a 48 target; keep the tabs close.
            SizedBox(height: isDesktop(context) ? Space.lg : Space.xs),
            AppTabs<String>(
              key: const ValueKey('shared-tabs'),
              tabs: [for (final t in sharedTabs) (t, t)],
              selected: tab,
              onSelected: select,
            ),
            SizedBox(height: Space.cardGapOf(context) + Space.xs),
          ] else if (isDesktop(context))
            SizedBox(height: Space.cardGapOf(context) + Space.xs),
          for (final n in notices(source, g)) ...[n, gap],
          if (chooser)
            SharedGroupChooser(
              key: const ValueKey('shared-group-chooser'),
              source: source,
              defaultGroup: hub.defaultGroup,
              onOpen: hub.choose,
              onAbout: (r) => flows.openGroup(context, r.group),
              onDefault: hub.setDefault,
              onCreate: () => flows.createGroup(context),
              onJoin: () => flows.joinGroup(context),
            )
          else if (g == null)
            noGroup(source)
          else
            body(source, g),
        ],
      );
    },
  );
}
