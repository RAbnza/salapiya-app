import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/shell_navigation.dart';
import '../../../design_system/kit/kit.dart';
import '../../../design_system/theme.dart';
import '../../../finance/card_tab.dart';
import '../../../finance/files_tab.dart';
import '../../../finance/finance_screen.dart' show formTitles;
import '../../../finance/import_tab.dart';
import '../../../finance/money_dashboard.dart';
import '../../../finance/money_data.dart';
import '../../../finance/money_demo.dart';
import '../../../finance/money_details.dart';
import '../../../finance/planning_tab.dart';
import '../../../finance/report_data.dart';
import '../../../finance/report_tab.dart';
import '../../../local/finance_domain.dart' show financeType;
import '../../../local/local_finance_controller.dart';
import '../../../prototype/scenarios.dart';
import '../application/financial_controller.dart';

/// Money's tabs (§2 Money).
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

  /// What Activity opens on, when another tab sends the user there.
  ActivityFilter activity = const ActivityFilter();

  /// Kept here, so the header's Export CSV saves what the tab shows.
  ReportFilter report = const ReportFilter();
  FinancialController get c => widget.session.finance;

  void select(String next, {ActivityFilter filter = const ActivityFilter()}) {
    ShellNavigation.reportTab(context, next);
    setState(() {
      tab = next;
      activity = filter;
    });
  }

  /// What follows the date in the header, per tab.
  String? caption(MoneySource money) {
    if (!money.complete) return null;
    final s = money.snapshot;
    int count(String type) =>
        s.current.where((r) => financeType(r) == type).length;
    String of(int n, String one) => '$n ${n == 1 ? one : '${one}s'}';
    return switch (tab) {
      'Accounts' ||
      'Activity' => of(s.accounts.where((a) => !a.archived).length, 'account'),
      'Cards' => of(count('creditCard'), 'card'),
      'Planning' =>
        '${of(count('budget'), 'budget')} · ${of(count('savingsGoal'), 'goal')}',
      'Reports' when report.problem(money.today) == null => periodHeading(
        report.range(money.today).$1,
        report.range(money.today).$2,
      ),
      'Files' => of(count('financialFile'), 'file'),
      _ => null,
    };
  }

  /// The header's actions, per tab. Windows only: on Android they sit in
  /// the cards, and the + button has the ones it repeats.
  List<QuickAction> headerActions(MoneySource money) {
    QuickAction form(String op, IconData icon) => (
      label: formTitles[op]!,
      icon: icon,
      onSelected: () => money.actions.form(op, formTitles[op]!),
    );
    return switch (tab) {
      'Accounts' || 'Activity' => widget.actions,
      'Cards' => [
        form('cardPayment', Icons.payments_outlined),
        form('statement', Icons.receipt_long_outlined),
        form('creditCard', Icons.add_card_outlined),
      ],
      'Planning' => [
        form('budget', Icons.pie_chart_outline),
        form('savingsGoal', Icons.savings_outlined),
        form('recurrence', Icons.repeat),
      ],
      'Reports' when money.complete && report.problem(money.today) == null => [
        (
          label: 'Export CSV',
          icon: Icons.download_outlined,
          onSelected: () => exportReport(report, money),
        ),
      ],
      'Import' when money.complete => [
        (
          label: 'Import a file',
          icon: Icons.upload_file_outlined,
          onSelected: () => unawaited(
            money.actions.importFile().then((_) {
              if (mounted) setState(() {});
            }),
          ),
        ),
      ],
      'Files' when money.complete => [
        (
          label: 'Attach a file',
          icon: Icons.attach_file,
          onSelected: () => unawaited(money.actions.attachFile()),
        ),
      ],
      _ => const [],
    };
  }

  void exportReport(ReportFilter filter, MoneySource money) {
    final (from, to) = filter.range(money.today);
    money.actions.exportCsv(from, to, filter.account, filter.category);
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoneyHeader(
            today: money.today,
            caption: caption(money),
            actions: headerActions(money),
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
              filter: activity,
            )
          else if (tab == 'Cards')
            CardsTab(
              key: const ValueKey('money-cards-tab'),
              source: money,
              onActivity: () => select(
                'Activity',
                filter: const ActivityFilter(type: ActivityType.cards),
              ),
            )
          else if (tab == 'Planning')
            PlanningTab(
              key: const ValueKey('money-planning-tab'),
              source: money,
            )
          else if (tab == 'Reports')
            ReportsTab(
              key: const ValueKey('money-reports-tab'),
              source: money,
              filter: report,
              onFilter: (f) => setState(() => report = f),
              onExport: (f) => exportReport(f, money),
            )
          else if (tab == 'Import')
            ImportTab(key: const ValueKey('money-import-tab'), source: money)
          else
            FilesTab(key: const ValueKey('money-files-tab'), source: money),
        ],
      );
    },
  );
}
