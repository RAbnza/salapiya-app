import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_cards.dart' show civilLabel;
import '../app/overview_data.dart';
import '../app/shell_navigation.dart';
import '../connected/connection_view.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../features/finance/contracts/financial_models.dart';
import '../features/finance/presentation/financial_editor.dart';
import '../local/finance_domain.dart';
import '../local/local_finance_controller.dart';
import '../local/local_runtime.dart';
import '../prototype/scenarios.dart';
import 'debt_cards.dart' show civilDay;
import 'finance_screen.dart';
import 'money_cards.dart';
import 'money_dashboard.dart';
import 'money_data.dart';
import 'money_editor.dart';

/// What the Money screens read for a real profile. Without a [session], as on
/// a record page opened from another section's list, the records count as
/// fully downloaded.
MoneySource localMoneySource(
  BuildContext context,
  LocalFinancialController c,
  PrototypeSession? session,
) {
  void edit(
    FinancialAction action, {
    String? sourceId,
    Map<String, String>? initial,
  }) => openFinancialEditor(
    context,
    c,
    action,
    sourceId: sourceId,
    initial: initial,
  );
  bool native(LocalRevision r) =>
      nativeFinanceCommands.contains(financeType(r));
  final hasCards = c.snapshot.current.any(
    (r) => financeType(r) == 'creditCard',
  );
  return MoneySource(
    today: civilToday(),
    snapshot: c.snapshot,
    complete: session?.complete ?? true,
    hidden: session?.hideAmounts ?? c.amountsHidden,
    amount:
        session?.amount ??
        (v) => c.amountsHidden ? 'Amount hidden' : c.amount(v),
    categoryName: c.categoryName,
    cards: hasCards ? c.cardLiabilityAndCredit : null,
    waiting: c.connected
        ? (id) => const {
            'pending',
            'accepted',
          }.contains(c.synchronizationStates[id])
        : null,
    pending: session?.pending ?? false,
    pendingCount: session is LocalSession ? session.pendingCount : 0,
    needsReview: session?.needsReview ?? false,
    syncLabel: session?.syncLabel ?? '',
    onReview: session is LocalSession
        ? () => openDemoPage<void>(
            context,
            ConnectionPage(runtime: session.runtime),
            'profile/connection',
          )
        : null,
    draftCount: () async => (await c.store.drafts()).length,
    actions: MoneyActions(
      logExpense: (a) => edit(
        FinancialAction.expense,
        initial: a == null ? null : {'account': a},
      ),
      logIncome: (a) => edit(
        FinancialAction.income,
        initial: a == null ? null : {'account': a},
      ),
      logTransfer: (a) => edit(
        FinancialAction.transfer,
        initial: a == null ? null : {'account': a},
      ),
      addAccount: () => edit(FinancialAction.account),
      addCategory: () => edit(FinancialAction.category),
      checkBalance: (a) =>
          edit(FinancialAction.reconcile, initial: {'account': a}),
      adjustBalance: (a) => edit(
        FinancialAction.reconcile,
        initial: {'account': a, 'mode': 'manual'},
      ),
      archive: (a) => edit(FinancialAction.archive, initial: {'account': a}),
      openAccount: (id) => openDemoPage<void>(
        context,
        AccountDetailView(
          listenable: _listening(c, session),
          source: (context) => localMoneySource(context, c, session),
          accountId: id,
        ),
        'money/account/$id',
        title: c.snapshot.account(id).name,
      ),
      openRecord: (id) => openMoneyRecord(context, c, id, session: session),
      openCategories: () => openDemoPage<void>(
        context,
        CategoriesView(
          listenable: _listening(c, session),
          source: (context) => localMoneySource(context, c, session),
        ),
        'money/categories',
      ),
      openDrafts: () => openDemoPage<void>(
        context,
        SavedDraftsPage(
          controller: c,
          onImport: () => ShellNavigation.maybeOf(
            context,
          )?.select(AppDestination.money, tab: 'Import'),
        ),
        'money/drafts',
      ),
      correct: (r) => native(r)
          ? openNativeFinance(
              context,
              c,
              'financeCorrection',
              'Correct this record',
              replacing: r,
            )
          : edit(FinancialAction.correction, sourceId: r.id),
      reverse: (r) => native(r)
          ? openNativeFinance(
              context,
              c,
              'financeReversal',
              'Reverse this record',
              replacing: r,
            )
          : edit(FinancialAction.reversal, sourceId: r.id),
      refund: (r) => edit(FinancialAction.refund, sourceId: r.id),
      adjustToMatch: (r) => edit(FinancialAction.reconcile, sourceId: r.id),
    ),
  );
}

Listenable _listening(LocalFinancialController c, PrototypeSession? session) =>
    session == null ? c : Listenable.merge([c, session]);

/// One record's page, for Money and for every other section's lists.
Future<void> openMoneyRecord(
  BuildContext context,
  LocalFinancialController c,
  String id, {
  PrototypeSession? session,
}) => openDemoPage<void>(
  context,
  RecordDetailView(
    listenable: _listening(c, session),
    source: (context) => localMoneySource(context, c, session),
    id: id,
  ),
  'money/transaction/$id',
  title: recordTitle(c.snapshot.revision(id)),
);

/// One account: what it holds, how that changed and everything on it.
class AccountDetailView extends StatefulWidget {
  const AccountDetailView({
    super.key,
    required this.listenable,
    required this.source,
    required this.accountId,
  });
  final Listenable listenable;
  final MoneySource Function(BuildContext context) source;
  final String accountId;
  @override
  State<AccountDetailView> createState() => _AccountDetailViewState();
}

class _AccountDetailViewState extends State<AccountDetailView> {
  ActivityLayout layout = ActivityLayout.timeline;

  Widget more(MoneySource source) {
    final actions = source.actions, id = widget.accountId;
    final items = [
      (
        'account-log-income',
        'Log income',
        Icons.add_circle_outline,
        () {
          actions.logIncome(id);
        },
      ),
      (
        'account-log-transfer',
        'Log a transfer',
        Icons.swap_horiz,
        () {
          actions.logTransfer(id);
        },
      ),
      (
        'account-check',
        'Check balance',
        Icons.fact_check_outlined,
        () {
          actions.checkBalance(id);
        },
      ),
      (
        'account-adjust',
        'Adjust account balance',
        Icons.tune,
        () {
          actions.adjustBalance(id);
        },
      ),
      (
        'account-archive',
        'Archive account',
        Icons.archive_outlined,
        () {
          actions.archive(id);
        },
      ),
    ];
    return CardMenu(
      key: const ValueKey('account-more'),
      tooltip: 'More actions',
      items: [
        for (final (key, label, icon, run) in items)
          MenuItemButton(
            key: ValueKey(key),
            leadingIcon: Icon(icon),
            onPressed: run,
            child: Text(label),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.listenable,
    builder: (context, _) {
      final source = widget.source(context);
      final s = source.snapshot, today = source.today, id = widget.accountId;
      final amount = source.amount, hidden = source.hidden;
      final actions = source.actions;
      final a = s.accounts.where((a) => a.id == id).firstOrNull;
      if (a == null) {
        return const SectionPage(
          title: 'Account details',
          child: SurfaceCard(
            child: EmptyState(
              icon: Icons.history,
              title: 'This account is no longer here',
              message: 'Go back to Money to see your accounts.',
            ),
          ),
        );
      }
      final android = !isDesktop(context);
      final balance = s.balance(id, through: today);
      final before = lastMonthEnd(today);
      final month = cashFlow(s, [id], monthStart(today), today);
      final checked = lastChecked(s, id);
      final opening = sumMinor(
        s.current
            .where((r) => r.kind == 'opening')
            .expand((r) => r.postings)
            .where((p) => p.account == id)
            .map((p) => p.amount),
      );
      final all = moneyActivity(
        s,
        source.categoryName,
        waiting: source.waiting,
      ).where((r) => r.accounts.contains(id)).toList();
      final trend = !hidden;
      final overview = BalanceCard(
        key: const ValueKey('account-balance'),
        title: 'Balance',
        caption: a.archived ? 'History kept' : 'Through today',
        accent: true,
        days: balanceByDay(s, [id], addCivilDays(today, -29), today),
        months: balanceByMonth(s, [id], today),
        amount: amount,
        available: source.complete,
        hidden: hidden,
        empty: all.isEmpty,
        lead: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MoneyAmount(
              source.complete ? amount(balance) : null,
              size: MoneySize.tile,
              textAlign: TextAlign.start,
            ),
            if (trend && source.complete) ...[
              const SizedBox(height: Space.xs),
              ChangeLine(
                basisPoints: changeBasisPoints(
                  balance,
                  s.balance(id, through: before),
                ),
                versus: 'since ${civilLabel(before)}',
                meaning: ChangeMeaning.riseIsGood,
              ),
            ],
          ],
        ),
        stats: [
          (
            label: 'Money in',
            value: amount(month.moneyIn),
            detail: 'This month',
          ),
          (
            label: 'Money out',
            value: amount(month.moneyOut),
            detail: 'This month',
          ),
          (label: 'Opening balance', value: amount(opening), detail: null),
          (
            label: 'Last checked',
            value: checked == null ? 'Not yet' : civilLabel(checked),
            detail: null,
          ),
        ],
      );
      final about = OverviewCard(
        key: const ValueKey('account-about'),
        title: 'About this account',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FactRow('Type', a.kind),
            if (a.institution.isNotEmpty) FactRow('Institution', a.institution),
            FactRow('Balance as of', civilDay(a.cutoff)),
            FactRow('Records', '${all.length}'),
            if (a.notes.isNotEmpty) FactRow('Notes', a.notes),
            const ListEnd(key: ValueKey('account-about-end')),
          ],
        ),
      );
      final from = all.isEmpty ? today : all.last.date;
      final statement = Statement.of(s, all, from, today, account: id);
      final list = StatementList(
        key: const ValueKey('account-statement'),
        statement: statement,
        heading: periodHeading(from, today),
        today: today,
        amount: amount,
        hidden: hidden,
        onOpen: actions.openRecord,
      );
      final menu = CardMenu(
        key: const ValueKey('account-activity-menu'),
        tooltip: 'Layout: ${layout.label}',
        icon: Icons.settings_outlined,
        items: [
          for (final l in ActivityLayout.values)
            MenuItemButton(
              key: ValueKey('account-layout-${l.name}'),
              trailingIcon: l == layout ? const Icon(Icons.check) : null,
              onPressed: () => setState(() => layout = l),
              child: Text(l == ActivityLayout.list ? 'Statement' : l.label),
            ),
          const Divider(height: 1),
          MenuItemButton(
            key: const ValueKey('account-open-page'),
            leadingIcon: const Icon(Icons.open_in_full),
            onPressed: () => openDemoPage<void>(
              context,
              StatementPage(title: a.name, list: list),
              'money/statement/$id',
            ),
            child: const Text('Open as a page'),
          ),
        ],
      );
      final activity = layout == ActivityLayout.list
          ? OverviewCard(
              key: const ValueKey('account-statement-card'),
              title: 'Statement',
              corner: menu,
              child: list,
            )
          : ActivityListCard(
              key: const ValueKey('account-activity'),
              title: 'Activity',
              caption:
                  '${all.length} ${all.length == 1 ? 'record' : 'records'}',
              corner: menu,
              rows: all,
              today: today,
              amount: amount,
              hidden: hidden,
              onOpen: actions.openRecord,
              account: id,
              empty: const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No activity yet',
                message: 'What you log on this account shows here.',
              ),
            );
      return SectionPage(
        title: a.name,
        caption: [
          a.kind,
          if (a.institution.isNotEmpty) a.institution,
          'Since ${civilDay(a.cutoff)}',
        ].join(' · '),
        status: a.archived
            ? const StatusPill('Archived', icon: Icons.archive_outlined)
            : balance.isNegative
            ? const StatusPill(
                'Below zero',
                icon: Icons.error_outline,
                tone: PillTone.warning,
              )
            : null,
        actions: [
          if (!a.archived) ...[
            CompactForm(
              child: AppButton(
                'Log expense',
                key: const ValueKey('account-log-expense'),
                icon: Icons.add,
                onPressed: () => actions.logExpense(id),
              ),
            ),
            more(source),
          ],
        ],
        child: DashboardGrid(
          key: ValueKey(('account-grid', id)),
          cards: android
              ? null
              : [(overview, 8, 12), (about, 4, 12), (activity, 12, 12)],
          stacked: [overview, activity, about],
        ),
      );
    },
  );
}

/// One record: what it did, what it is, and every version of it.
class RecordDetailView extends StatelessWidget {
  const RecordDetailView({
    super.key,
    required this.listenable,
    required this.source,
    required this.id,
  });
  final Listenable listenable;
  final MoneySource Function(BuildContext context) source;
  final String id;

  Widget more(MoneySource source, LocalRevision r, RecordActions can) {
    final actions = source.actions;
    return CardMenu(
      key: const ValueKey('record-more'),
      tooltip: 'More actions',
      items: [
        if (can.refund)
          MenuItemButton(
            key: const ValueKey('record-refund'),
            leadingIcon: const Icon(Icons.undo),
            onPressed: () => actions.refund(r),
            child: const Text('Log a refund'),
          ),
        MenuItemButton(
          key: const ValueKey('record-reverse'),
          leadingIcon: const Icon(Icons.remove_circle_outline),
          onPressed: can.blocked == null ? () => actions.reverse(r) : null,
          child: const Text('Reverse transaction'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: listenable,
    builder: (context, _) {
      final source = this.source(context);
      final s = source.snapshot, today = source.today;
      final amount = source.amount, hidden = source.hidden;
      final actions = source.actions;
      final r = s.revisions.where((r) => r.id == id).firstOrNull;
      if (r == null) {
        return const SectionPage(
          title: 'Record',
          child: SurfaceCard(
            child: EmptyState(
              icon: Icons.history,
              title: 'This record is no longer here',
              message: 'Go back to see the others.',
            ),
          ),
        );
      }
      final android = !isDesktop(context);
      final versions = s.revisions
          .where((x) => x.actionId == r.actionId)
          .toList();
      final reversed = r.change == 'reverse';
      final effect = reversed
          ? versions.where((x) => x.id == r.previous).firstOrNull ?? r
          : r;
      final row = moneyActivity(
        s,
        source.categoryName,
      ).where((x) => x.record.id == r.id).firstOrNull;
      final can = recordActions(s, r);
      final check = financeType(r) == 'reconcile';
      final state = check ? balanceCheckState(s, r) : null;
      final effects = recordEffects(s, effect, source.categoryName);
      final accounts = {
        for (final p in effect.postings)
          if (p.account != null)
            s.accounts.where((a) => a.id == p.account).firstOrNull?.name ??
                'Account',
        if (check)
          s.accounts
                  .where((a) => a.id == r.values['account'])
                  .firstOrNull
                  ?.name ??
              'Account',
      }.join(' → ');
      final waiting = source.waiting?.call(r.id) ?? false;
      final later = r.date.compareTo(today) > 0;

      final shown = row == null
          ? amount(r.amount)
          : row.shown(amount, hidden: hidden);
      final what = OverviewCard(
        key: const ValueKey('record-effect'),
        title: 'What this did',
        accent: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MoneyAmount(
              shown,
              size: MoneySize.tile,
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: Space.sm),
            if (check) ...[
              _Effect('Actual balance', amount(signedPhp(r.values['amount']!))),
              _Effect(
                'Balance in Salapiya',
                amount(BigInt.parse(r.values['calculated']!)),
                detail: 'At the time of this check',
              ),
              _Effect('Difference', amount(r.amount)),
            ] else if (reversed)
              const _Words(
                'This no longer counts. Its effect was removed from the dates it happened.',
              )
            else ...[
              for (final e in effects)
                _Effect(
                  e.label,
                  e.cash
                      ? signedAmount(e.amount, amount, hidden: hidden)
                      : amount(e.amount),
                  detail: e.detail,
                ),
              if (effects.isEmpty) const _Words('No money moved.'),
            ],
            if (later)
              const _Words(
                'Dated after today, so it isn’t in your balance yet.',
              ),
          ],
        ),
      );
      String? value(String key) => (effect.values[key] ?? '').trim().isEmpty
          ? null
          : effect.values[key]!.trim();
      final facts = <(String, String?)>[
        ('Type', moneyLabel(r)),
        ('Date', civilDay(r.date)),
        if (accounts.isNotEmpty) ('Account', accounts),
        if (row != null && row.categoryLabel.isNotEmpty)
          ('Category', row.categoryLabel),
        ('Merchant', value('merchant')),
        ('Received from', value('sender')),
        ('Income source', value('sourceLabel')),
        if (value('incomeClass') != null && effect.kind == 'income')
          (
            'Type of income',
            switch (value('incomeClass')) {
              'earned' => 'Earned',
              'gift' => 'Gift',
              'reward' => 'Reward',
              _ => 'Other',
            },
          ),
        ('Reference', value('reference')),
        ('Notes', value('notes')),
        if (check) ('Status', state!.label),
        (
          'Saved',
          waiting
              ? 'On this device, waiting to sync'
              : source.waiting == null
              ? 'On this device'
              : 'Synced',
        ),
      ];
      final about = OverviewCard(
        key: const ValueKey('record-about'),
        title: 'About this record',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (label, text) in facts)
              if (text != null) FactRow(label, text),
          ],
        ),
      );

      final versionIds = versions.map((v) => v.id).toSet();
      final related = <String, LocalRevision>{
        for (final x in s.revisions)
          if (x.source != null &&
              versionIds.contains(x.source) &&
              financeType(x) != 'financialFile')
            x.actionId: x,
      };
      final files = [
        for (final f in s.revisions)
          if (financeType(f) == 'financialFile' &&
              versionIds.contains(f.values['sourceRevision']))
            f,
      ];
      String versionLabel(LocalRevision v) => switch (v.change) {
        'reverse' => 'Version ${v.number} · Reversed',
        'replace' => 'Version ${v.number} · Corrected',
        _ => 'Version ${v.number} · Logged',
      };
      final detail = <String, String>{
        for (final e in effect.values.entries)
          if (!const {
                'financeContract',
                'financeType',
                'acknowledge',
              }.contains(e.key) &&
              e.value.isNotEmpty)
            e.key
                .replaceAllMapped(
                  RegExp(r'([a-z])([A-Z])'),
                  (m) => '${m[1]} ${m[2].toString().toLowerCase()}',
                )
                .replaceAll('_', ' '): hidden
                ? 'Hidden'
                : e.value,
      };
      final history = OverviewCard(
        key: const ValueKey('record-history'),
        title: 'Edit history',
        caption: 'Earlier versions stay here',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListGroup(
              children: [
                for (final v in versions.reversed)
                  AdaptiveRow(
                    key: ValueKey('version-${v.id}'),
                    title: versionLabel(v),
                    subtitle: [
                      civilDay(v.date),
                      if ((v.values['reason'] ?? '').isNotEmpty)
                        v.values['reason']!,
                    ].join(' · '),
                    trailing: MoneyAmount(amount(v.amount)),
                    onTap: v.id == id ? null : () => actions.openRecord(v.id),
                  ),
                for (final x in related.values)
                  AdaptiveRow(
                    key: ValueKey('evidence-${x.id}'),
                    title: recordTitle(x),
                    subtitle: '${moneyLabel(x)} · ${civilDay(x.date)}',
                    trailing: MoneyAmount(amount(x.amount)),
                    onTap: () => actions.openRecord(x.id),
                  ),
                for (final f in files)
                  AdaptiveRow(
                    leading: Icons.attach_file,
                    title: f.title,
                    subtitle: 'Attachment · Open Money › Files to view it',
                  ),
              ],
            ),
            const SizedBox(height: Space.sm),
            FormMoreDetails(
              label: 'View details',
              children: [
                FactRow('Record', r.id),
                FactRow('Original', r.actionId),
                if (nativeFinanceCommands.contains(financeType(r)))
                  for (final e in detail.entries) FactRow(e.key, e.value),
              ],
            ),
          ],
        ),
      );
      Widget? notice;
      if (can.shared) {
        notice = InlineNotice(
          'This record is linked to Shared Expenses, so it’s changed there.',
          action: ShellNavigation.maybeOf(context) == null
              ? null
              : AppButton.secondary(
                  'Open Shared Expenses',
                  onPressed: () =>
                      ShellNavigation.of(context).select(AppDestination.shared),
                ),
        );
      } else if (can.superseded != null) {
        notice = InlineNotice(
          'This is an earlier version. It no longer counts.',
          action: AppButton.secondary(
            'See the current version',
            onPressed: () => actions.openRecord(can.superseded!),
          ),
        );
      } else if (can.blocked != null) {
        notice = InlineNotice(can.blocked!);
      }
      final Widget? pill = reversed
          ? const StatusPill('Reversed', icon: Icons.undo)
          : !s.current.contains(r)
          ? const StatusPill('Earlier version', icon: Icons.history)
          : r.change == 'replace'
          ? const StatusPill('Corrected', icon: Icons.edit_outlined)
          : waiting
          ? const StatusPill(
              'Waiting to sync',
              icon: Icons.cloud_upload_outlined,
              tone: PillTone.information,
            )
          : null;
      return SectionPage(
        title: recordTitle(effect),
        caption: [
          moneyLabel(r),
          civilDay(r.date),
          if (accounts.isNotEmpty) accounts,
        ].join(' · '),
        status: pill,
        actions: [
          if (can.adjust)
            CompactForm(
              child: AppButton(
                'Adjust balance to match',
                key: const ValueKey('record-adjust'),
                onPressed: () => actions.adjustToMatch(r),
              ),
            ),
          if (can.checkAgain)
            CompactForm(
              child: AppButton(
                'Check balance',
                key: const ValueKey('record-check'),
                onPressed: () => actions.checkBalance(r.values['account']!),
              ),
            ),
          if (can.correct) ...[
            CompactForm(
              child: AppButton(
                nativeFinanceCommands.contains(financeType(r))
                    ? 'Correct this record'
                    : 'Correct transaction',
                key: const ValueKey('record-correct'),
                icon: Icons.edit_outlined,
                disabledReason: can.blocked,
                onPressed: can.blocked == null
                    ? () => actions.correct(r)
                    : null,
              ),
            ),
            more(source, r, can),
          ],
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (notice != null) ...[
              notice,
              SizedBox(height: Space.cardGapOf(context)),
            ],
            DashboardGrid(
              key: ValueKey(('record-grid', id)),
              cards: android
                  ? null
                  : [(what, 8, 12), (about, 4, 12), (history, 12, 12)],
              stacked: [what, about, history],
            ),
          ],
        ),
      );
    },
  );
}

class _Effect extends StatelessWidget {
  const _Effect(this.label, this.value, {this.detail});
  final String label, value;
  final String? detail;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: LabelAmount(
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.bodyMedium),
            if (detail != null)
              Text(
                detail!,
                style: text.bodySmall?.copyWith(color: c.secondary),
              ),
          ],
        ),
        amount: MoneyAmount(value),
      ),
    );
  }
}

class _Words extends StatelessWidget {
  const _Words(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.xs),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

/// Every category, with Add category.
class CategoriesView extends StatelessWidget {
  const CategoriesView({
    super.key,
    required this.listenable,
    required this.source,
  });
  final Listenable listenable;
  final MoneySource Function(BuildContext context) source;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: listenable,
    builder: (context, _) {
      final source = this.source(context);
      final categories = source.snapshot.categories;
      Widget group(String title, String kind) => OverviewCard(
        title: title,
        child: ListGroup(
          children: [
            for (final c in categories.where((c) => c.kind == kind))
              AdaptiveRow(title: c.name),
          ],
        ),
      );
      final android = !isDesktop(context);
      final spending = group('Spending', 'expense');
      final income = group('Income', 'income');
      return SectionPage(
        title: 'Categories',
        caption: '${categories.length} categories',
        actions: [
          CompactForm(
            child: AppButton(
              'Add category',
              key: const ValueKey('category-add'),
              icon: Icons.add,
              onPressed: source.actions.addCategory,
            ),
          ),
        ],
        child: DashboardGrid(
          key: const ValueKey('categories-grid'),
          cards: android ? null : [(spending, 6, 12), (income, 6, 12)],
          stacked: [spending, income],
        ),
      );
    },
  );
}

/// One saved draft: what it is, and how to reopen it.
class _Draft {
  _Draft(this.operation, this.values);
  final String operation;
  final Map<String, String> values;

  List<String> get parts => operation.split(':');
  bool get native => parts.first == 'finance';
  bool get import => parts.first == 'cash-import';
  FinancialAction? get action =>
      FinancialAction.values.where((a) => a.name == parts.first).firstOrNull;

  String get title => import
      ? 'Imported history'
      : native
      ? switch (parts[1]) {
          'debtPayment' => 'Log a debt payment',
          'debtImport' => 'Add a debt',
          'borrowing' => 'Log a new loan',
          'debtPayoff' => 'Log an early payoff',
          'debtAdjustment' => 'Log a lender charge or waiver',
          'debtClassification' => 'Break down a payment',
          'debtSchedule' => 'Set schedule',
          'financeCorrection' => 'Correct this record',
          'financeReversal' => 'Reverse this record',
          _ => 'Finish this draft',
        }
      : action == null
      ? 'Finish this draft'
      : MoneyEditor.titleFor(action!, parts.length > 2 ? parts[2] : null);

  /// What the user typed, to tell drafts apart.
  String get subtitle {
    final name = (values['name'] ?? '').trim();
    return name.isEmpty ? 'Not in your records yet' : name;
  }
}

/// Unfinished entries, encrypted on this device. Each opens its form; none
/// of them is in the user's records.
class SavedDraftsPage extends StatefulWidget {
  const SavedDraftsPage({super.key, required this.controller, this.onImport});
  final LocalFinancialController controller;

  /// Import keeps its own draft; this goes there.
  final VoidCallback? onImport;
  @override
  State<SavedDraftsPage> createState() => _SavedDraftsPageState();
}

class _SavedDraftsPageState extends State<SavedDraftsPage> {
  LocalFinancialController get c => widget.controller;
  late Future<List<_Draft>> drafts = load();

  Future<List<_Draft>> load() async => [
    for (final row in await c.store.drafts())
      _Draft(
        row['operation'] as String,
        Map<String, String>.from(
          jsonDecode(row['values_json'] as String) as Map,
        ),
      ),
  ];

  void reload() => setState(() => drafts = load());

  Future<void> open(_Draft d) async {
    if (d.import) {
      widget.onImport?.call();
      return;
    }
    if (d.native) {
      final replacing = d.parts[2];
      await openNativeFinance(
        context,
        c,
        d.parts[1],
        d.title,
        replacing: replacing.isEmpty ? null : c.snapshot.revision(replacing),
        draft: d.operation,
      );
    } else {
      await openFinancialEditor(
        context,
        c,
        d.action!,
        sourceId: d.parts.length > 1 && d.parts[1].isNotEmpty
            ? d.parts[1]
            : null,
        initial: d.parts.length > 2 ? {'mode': d.parts[2]} : null,
      );
    }
    if (mounted) reload();
  }

  Future<void> discard(_Draft d) async {
    final yes = await showAppDialog<bool>(
      context,
      title: 'Discard this draft?',
      body: const Text('It isn’t in your records, so nothing else changes.'),
      primary: const ModalAction(
        'Discard draft',
        value: true,
        destructive: true,
      ),
    );
    if (yes != true) return;
    await c.discardDraft(d.operation);
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) => SectionPage(
    title: 'Saved drafts',
    caption: 'Encrypted on this device. Not in your records yet.',
    child: SurfaceCard(
      child: FutureBuilder(
        future: drafts,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Drafts couldn’t be read',
              message: 'Reopen your profile and try again.',
            );
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const EmptyState(
              icon: Icons.drafts_outlined,
              title: 'No saved drafts',
              message: 'Unfinished entries stay here until you finish them.',
            );
          }
          return ListGroup(
            children: [
              for (final d in rows)
                Row(
                  children: [
                    Expanded(
                      child: AdaptiveRow(
                        key: ValueKey('draft-${d.operation}'),
                        title: d.title,
                        subtitle: d.subtitle,
                        onTap: d.import && widget.onImport == null
                            ? null
                            : () => unawaited(open(d)),
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Discard draft',
                      onPressed: () => unawaited(discard(d)),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    ),
  );
}
