import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_demo.dart';
import '../app/previews.dart';
import '../features/finance/contracts/financial_models.dart';
import '../features/finance/presentation/financial_editor.dart';
import '../local/finance_domain.dart';
import '../prototype/scenarios.dart';
import 'money_data.dart';
import 'money_details.dart';

/// The Money screens in the demo build: the Overview's sample profile, so
/// all three agree, with the demo session's scenario and hidden amounts
/// applied. Nothing is stored. The demo can't open the real Money forms,
/// which need the encrypted store, so Log expense, income and a transfer open
/// the demo's own forms, and the rest open a placeholder.
MoneySource demoMoneySource(BuildContext context, PrototypeSession session) {
  final today = civilToday();
  final s = demoSample(today, empty: session.empty);
  final finance = session.finance;
  void demo(String label) => openDemoPage<void>(
    context,
    DemoActionPage(label: label),
    'money/demo',
    title: label,
  );
  void editor(FinancialAction action) =>
      session.complete ? openFinancialEditor(context, finance, action) : null;
  String name(String? id) =>
      s.categories.where((c) => c.id == id).firstOrNull?.name ?? 'No category';
  final cards = s.current.where((r) => financeType(r) == 'creditCard');
  final owed = sumMinor(
    cards.map(
      (card) => -financeBalance(
        s,
        'card_liability',
        'card',
        card.actionId,
        through: today,
      ),
    ),
  );
  final newest = s.revisions.lastOrNull?.id;
  return MoneySource(
    today: today,
    snapshot: s,
    complete: session.complete,
    hidden: session.hideAmounts,
    amount: session.amount,
    categoryName: name,
    cards: cards.isEmpty ? null : (owed, BigInt.zero),
    waiting: session.pending ? (id) => id == newest : null,
    pending: session.pending,
    pendingCount: session.pending ? 1 : 0,
    needsReview: session.needsReview,
    syncLabel: session.syncLabel,
    actions: MoneyActions(
      logExpense: (_) => editor(FinancialAction.expense),
      logIncome: (_) => editor(FinancialAction.income),
      logTransfer: (_) => editor(FinancialAction.transfer),
      addAccount: () => demo('Add account'),
      addCategory: () => demo('Add category'),
      checkBalance: (_) => demo('Check a balance'),
      adjustBalance: (_) => demo('Adjust account balance'),
      archive: (_) => demo('Archive account'),
      openAccount: (id) => openDemoPage<void>(
        context,
        AccountDetailView(
          listenable: session,
          source: (context) => demoMoneySource(context, session),
          accountId: id,
        ),
        'money/account/$id',
        title: s.account(id).name,
      ),
      openRecord: (id) => openDemoPage<void>(
        context,
        RecordDetailView(
          listenable: session,
          source: (context) => demoMoneySource(context, session),
          id: id,
        ),
        'money/transaction/$id',
        title: recordTitle(s.revision(id)),
      ),
      openCategories: () => openDemoPage<void>(
        context,
        CategoriesView(
          listenable: session,
          source: (context) => demoMoneySource(context, session),
        ),
        'money/categories',
      ),
      openDrafts: () => demo('Saved drafts'),
      correct: (_) => demo('Correct transaction'),
      reverse: (_) => demo('Reverse transaction'),
      refund: (_) => demo('Log a refund'),
      adjustToMatch: (_) => demo('Adjust balance to match'),
    ),
  );
}
