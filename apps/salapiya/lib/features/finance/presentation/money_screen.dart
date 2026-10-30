import 'package:flutter/material.dart';

import '../../../app/demo_routes.dart';
import '../../../app/shell_navigation.dart';
import '../../../design_system/editorial.dart';
import '../../../design_system/kit/kit.dart';
import '../../../design_system/theme.dart';
import '../../../finance/files_screen.dart';
import '../../../finance/finance_screen.dart';
import '../../../finance/import_screen.dart';
import '../../../finance/money_dashboard.dart';
import '../../../finance/money_data.dart';
import '../../../finance/money_demo.dart';
import '../../../finance/money_details.dart';
import '../../../finance/planning_screen.dart';
import '../../../finance/reports_screen.dart';
import '../../../local/local_finance_controller.dart';
import '../../../local/local_profile_view.dart';
import '../../../local/local_runtime.dart';
import '../../../prototype/scenarios.dart';
import '../../planning/presentation/planning_screen.dart';
import '../../planning/presentation/reports_screen.dart';
import '../../supporting/presentation/files_screen.dart';
import '../application/financial_controller.dart';
import '../contracts/financial_models.dart';
import 'credit_screen.dart';
import 'financial_editor.dart';
import 'financial_widgets.dart';
import 'import_screen.dart';

/// Money's tabs. Accounts and Activity are this section's own (§2 Money);
/// the others keep their content until Chat 9.
const moneyTabs = [
  'Accounts',
  'Activity',
  'Cards',
  'Planning',
  'Reports',
  'Import',
  'Files',
];

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({
    super.key,
    required this.session,
    this.initial = 'Accounts',
    this.actions = const [],
  });
  final PrototypeSession session;
  final String initial;

  /// Quick actions in the header: the shell's New items. Windows only;
  /// Android has the + button above the dock for the same actions.
  final List<QuickAction> actions;
  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  late String tab = widget.initial;
  int drafts = 0;
  FinancialController get c => widget.session.finance;

  void select(String next) {
    ShellNavigation.reportTab(context, next);
    setState(() => tab = next);
  }

  MoneySource source(BuildContext context) => switch (c) {
    final LocalFinancialController local => localMoneySource(
      context,
      local,
      widget.session,
    ),
    _ => demoMoneySource(context, widget.session),
  };

  /// Pages closing change the shell's navigation, which brings this back to
  /// read the count again: that's when a draft may have come or gone.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ShellNavigation.maybeOf(context);
    readDrafts();
  }

  Future<void> readDrafts() async {
    final read = source(context).draftCount;
    if (read == null) return;
    final count = await read();
    if (mounted && count != drafts) setState(() => drafts = count);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, widget.session]),
    builder: (context, _) {
      final money = source(context);
      final own = tab == 'Accounts' || tab == 'Activity';
      final count = money.snapshot.accounts.where((a) => !a.archived).length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoneyHeader(
            today: money.today,
            caption: own && money.complete
                ? '$count ${count == 1 ? 'account' : 'accounts'}'
                : null,
            actions: own ? widget.actions : const [],
          ),
          // Android's header row is already a 48 target; keep the tabs close.
          SizedBox(height: isDesktop(context) ? Space.lg : Space.xs),
          AppTabs<String>(
            key: const ValueKey('money-tabs'),
            tabs: [for (final t in moneyTabs) (t, t)],
            selected: tab,
            onSelected: select,
          ),
          SizedBox(height: Space.cardGapOf(context) + Space.xs),
          if (own || !money.complete)
            for (final n in moneyNotices(money)) ...[
              n,
              SizedBox(height: Space.cardGapOf(context)),
            ],
          if (tab == 'Accounts')
            AccountsTab(
              key: const ValueKey('money-accounts-tab'),
              source: money,
              drafts: drafts,
              onTab: select,
              onDues: () => openDues(context),
            )
          else if (tab == 'Activity')
            ActivityTab(
              key: const ValueKey('money-activity-tab'),
              source: money,
            )
          else if (money.complete)
            other(),
        ],
      );
    },
  );

  /// Chat 9's tabs, as they were.
  Widget other() {
    final session = widget.session;
    final local = c is LocalFinancialController
        ? c as LocalFinancialController
        : null;
    return switch (tab) {
      'Cards' when local != null => NativeCardsScreen(controller: local),
      'Planning' when local != null => NativePlanningScreen(controller: local),
      'Reports' when local != null => NativeReportsScreen(controller: local),
      'Import' when local != null => NativeImportScreen(
        controller: local,
        synchronize: session is LocalSession
            ? session.runtime.connected.syncNow
            : null,
      ),
      'Files' when session is LocalSession => NativeFilesScreen(
        session: session,
      ),
      'Files' => FilesScreen(session: session),
      'Planning' => PlanningScreen(session: session),
      'Reports' => ReportsScreen(session: session),
      'Cards' => CreditScreen(session: session),
      'Import' => ImportScreen(controller: c),
      _ => UpcomingView(tab),
    };
  }
}

/// The demo's record page, for the demo's Cards, Planning and Reports.
class TransactionDetail extends StatelessWidget {
  const TransactionDetail({super.key, required this.session, required this.id});
  final PrototypeSession session;
  final String id;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session.finance,
    builder: (context, _) {
      final c = session.finance, r = c.records.firstWhere((r) => r.id == id);
      return FinancePage(
        title: 'Transaction detail',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinanceHeading(
              'ACTIVITY / ${r.kind.toUpperCase()}',
              r.title,
              '${r.date} · ${r.category} · ${r.status}',
            ),
            FinanceColumns(
              main: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueBlock(
                    'ORIGINAL AMOUNT',
                    session.amount(r.amount),
                    'Evidence $id · immutable record',
                    color: Palette.lilac,
                  ),
                  const SizedBox(height: 24),
                  const SectionHeading('Financial meaning'),
                  for (final e in r.cash.entries)
                    FinancialLine(
                      c.account(e.key).name,
                      'Actual cash movement',
                      value: session.amount(e.value),
                    ),
                  FinancialLine(
                    'Card liability',
                    'Separate from liquid funds',
                    value: session.amount(r.card),
                  ),
                  FinancialLine(
                    'Recognized spending',
                    'Transfer principal and card repayments excluded',
                    value: session.amount(r.spending),
                  ),
                  if (r.note.trim().isNotEmpty)
                    FinanceNotice(
                      session.hideAmounts ? 'Evidence amounts hidden.' : r.note,
                    ),
                ],
              ),
              aside: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeading('Contextual actions'),
                  if ([
                    'expense',
                    'income',
                    'cardPurchase',
                  ].contains(r.kind)) ...[
                    for (final a in [
                      FinancialAction.correction,
                      if (r.kind != 'income') FinancialAction.refund,
                      FinancialAction.reversal,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OutlinedButton(
                          onPressed: () => openFinancialEditor(
                            context,
                            c,
                            a,
                            sourceId: r.id,
                          ),
                          child: Text(a.label),
                        ),
                      ),
                    if (r.kind != 'income')
                      OutlinedButton(
                        onPressed: () => openFinancialEditor(
                          context,
                          c,
                          FinancialAction.adoption,
                          initial: {
                            'funding': 'Existing purchase',
                            'existing': r.id,
                          },
                        ),
                        child: const Text('Share this purchase'),
                      ),
                  ] else
                    const FinanceNotice(
                      'This action belongs to its source workflow. Linked financial evidence cannot be changed through an ordinary expense form.',
                    ),
                  const SizedBox(height: 24),
                  const SectionHeading('Evidence trail'),
                  SupportingFilesLink(
                    session: session,
                    source: 'action:${r.id}',
                  ),
                  if (r.sourceId != null)
                    FinancialLine(
                      'Original source',
                      r.sourceId!,
                      onTap: c.records.any((x) => x.id == r.sourceId)
                          ? () => openDemoPage<void>(
                              context,
                              TransactionDetail(
                                session: session,
                                id: r.sourceId!,
                              ),
                              'money/source',
                            )
                          : null,
                    ),
                  for (final child in c.records.where(
                    (x) => x.sourceId == r.id,
                  ))
                    FinancialLine(
                      child.kind,
                      '${child.date} · ${session.amount(child.amount)}',
                      key: ValueKey('evidence-${child.id}'),
                      onTap: () => openDemoPage<void>(
                        context,
                        TransactionDetail(session: session, id: child.id),
                        'money/evidence',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
