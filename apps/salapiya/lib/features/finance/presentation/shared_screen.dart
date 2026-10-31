import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../local/local_runtime.dart';
import '../../../shared/shared_bills_tab.dart';
import '../../../shared/shared_chooser.dart';
import '../../../shared/shared_data.dart';
import '../../../shared/shared_domain.dart';
import '../../../shared/shared_header.dart';
import '../../../shared/shared_hub.dart';
import '../../../shared/shared_pages.dart';
import '../../../shared/shared_payment_form.dart';
import '../../../shared/shared_payments_tab.dart';
import '../../../shared/shared_screen.dart';

import '../../../app/shell_navigation.dart';
import '../../../design_system/editorial.dart';
import '../../../design_system/kit/kit.dart';
import '../../../design_system/theme.dart';
import '../../../prototype/scenarios.dart';
import '../application/financial_controller.dart';
import '../contracts/financial_models.dart';
import 'financial_editor.dart';
import 'financial_widgets.dart';
import 'group_lifecycle.dart';

/// Shared Expenses' tabs, as the shell lists them.
const sharedTabs = [
  'Bills',
  'Payments',
  'Balances',
  'People',
  'Private review',
  'History',
  'Lifecycle',
];

/// The section's frame, on both builds: the header, the tabs and the notices.
/// Bills is the same on both. The tabs that wait for later stages keep their
/// old content, from the real group or the demo's own fixture.
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
  void edit(FinancialAction a, {String? source}) =>
      openFinancialEditor(context, c, a, sourceId: source);

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
    final session = widget.session;
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
      );
    }
    if (session is LocalSession) {
      return NativeSharedScreen(
        key: ValueKey('shared-tab-$tab'),
        session: session,
        hub: hub,
        group: g,
        tab: tab,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (tab) {
        'Balances' => [
          SharedPositionsCard(source: source, group: g),
          const SizedBox(height: Space.lg),
          ...balances(),
        ],
        'People' => people(),
        'Private review' => privateReview(),
        'Lifecycle' => [GroupLifecycle(session: session)],
        _ => [
          const SectionHeading('Group history'),
          for (final h in c.visibleGroupHistory)
            FinancialLine('Immutable demo event', h, icon: Icons.history),
          if (c.groupHistory.isEmpty)
            const FinanceNotice(
              'Opening dinner and pending payment are independent synthetic fixtures. New actions appear here.',
            ),
        ],
      },
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

  List<Widget> balances() {
    final names = c.members.keys.toList()..sort();
    final disputed = c.groupSettlements.any(
      (s) => s.status == SettlementStatus.disputed,
    );
    return [
      const SectionHeading('Where each position comes from'),
      const FinanceNotice(
        'Pairwise sources offset reciprocal obligations. Suggestions are explanations requiring agreement; they never post money or redirect original bills.',
      ),
      for (var i = 0; i < names.length; i++)
        for (var j = i + 1; j < names.length; j++)
          Builder(
            builder: (context) {
              final left = names[i], right = names[j];
              final forward = ExactFinance.sum(
                c.groupBills.map((b) => c.billObligation(b, left, right)),
              );
              final backward = ExactFinance.sum(
                c.groupBills.map((b) => c.billObligation(b, right, left)),
              );
              final net = forward - backward;
              return ExpansionTile(
                key: PageStorageKey(
                  'shared-pair-${c.activeGroup}-$left-$right',
                ),
                title: Text('$left ↔ $right'),
                subtitle: Text(
                  'Reciprocal net ${money(net.abs())} · ${net >= BigInt.zero ? '$left owes $right' : '$right owes $left'}',
                ),
                children: [
                  for (final b in c.groupBills)
                    FinancialLine(
                      b.title,
                      'v${b.revision} · source attribution retained',
                      value:
                          '${money(c.billObligation(b, left, right))} / ${money(c.billObligation(b, right, left))}',
                    ),
                ],
              );
            },
          ),
      const SizedBox(height: 24),
      SectionHeading(disputed ? 'Suggestions paused' : 'A suggested next step'),
      if (disputed)
        const FinanceNotice(
          'Resolve the disputed payment before using group settlement suggestions.',
          warning: true,
        )
      else ...[
        for (final p in c.groupPositions().entries.where(
          (p) => p.value < BigInt.zero,
        ))
          FinancialLine(
            '${p.key} can review a payment',
            'Net payable ${money(-p.value)}. Inspect the original bills and recipient before reporting.',
            icon: Icons.lightbulb_outline,
            color: Palette.mint,
            onTap: () => openFinancialEditor(
              context,
              c,
              FinancialAction.settlement,
              initial: {'sender': p.key},
            ),
          ),
      ],
    ];
  }

  List<Widget> people() => [
    const SectionHeading('People & membership'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: () => edit(FinancialAction.member),
          child: const Text('Add participant'),
        ),
        OutlinedButton(
          onPressed: () => edit(FinancialAction.invitation),
          child: const Text('Review invitation / claim'),
        ),
      ],
    ),
    const SizedBox(height: 16),
    for (final m in c.members.entries)
      FinancialLine(
        m.key,
        m.value,
        icon: Icons.person_outline,
        color: Palette.peach,
      ),
    const FinanceNotice(
      'Group owners administer membership; they cannot inspect private funding. Former-member access retains entitled history only. Open Lifecycle for ownership, removal, recovery and export.',
    ),
  ];

  List<Widget> privateReview() => c.actor != 'Amihan'
      ? [
          const FinanceNotice(
            'This identity cannot view Amihan’s private funding or review decisions. Switch back to Amihan to inspect your own private records.',
            warning: true,
          ),
        ]
      : [
          const SectionHeading('Only your private records'),
          const FinanceNotice(
            'Amihan’s private accounts and classifications are visible only in this local private view. They are not part of the group record.',
          ),
          for (final s in c.groupSettlements.where(
            (s) => c.privateSettlements.contains(s.id),
          ))
            FinancialLine(
              'Private payment / receipt',
              '${s.sender} → ${s.recipient} · actual movement already recorded\nGroup state: ${s.status.name} · ${c.privateSettlementReviews[s.id] ?? 'Clearing coverage needs review'}',
              icon: Icons.lock_outline,
              onTap: () => openFinancialEditor(
                context,
                c,
                FinancialAction.settlementPrivate,
                sourceId: s.id,
                initial: {'decision': 'Review clearing coverage'},
              ),
            ),
          for (final b in c.groupBills)
            Builder(
              builder: (context) {
                final a = c.adoptions[b.id];
                return FinancialLine(
                  b.title,
                  a == null
                      ? 'Not adopted · no private effect'
                      : 'Accepted v${a.revision} / group v${b.revision} · funding ${money(a.funding)} · own share ${money(a.share)}${c.retainedReviews[b.id] == null ? '' : '\nRetained evidence review: ${c.retainedReviews[b.id]}'}',
                  icon: Icons.lock_outline,
                  color: Palette.mint,
                  onTap: () => edit(
                    a == null
                        ? FinancialAction.adoption
                        : FinancialAction.privateReview,
                    source: b.id,
                  ),
                );
              },
            ),
        ];
}
