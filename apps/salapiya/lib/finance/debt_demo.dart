import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_demo.dart';
import '../app/previews.dart';
import '../features/finance/contracts/financial_models.dart';
import '../features/finance/presentation/financial_editor.dart';
import '../local/finance_domain.dart';
import '../prototype/scenarios.dart';
import 'debt_data.dart';
import 'debt_screen.dart';

/// The Debts screens in the demo build: the Overview's sample profile, so
/// both agree, with the demo session's scenario and hidden amounts applied.
/// Nothing is stored. Saving in a demo editor doesn't change the sample, as
/// on the Overview.
DebtsSource demoDebtsSource(BuildContext context, PrototypeSession session) {
  final today = civilToday();
  final finance = session.finance;
  void demo(String label) => openDemoPage<void>(
    context,
    DemoActionPage(label: label),
    'debt/demo',
    title: label,
  );
  void editor(FinancialAction action) =>
      session.complete ? openFinancialEditor(context, finance, action) : null;
  return DebtsSource(
    today: today,
    snapshot: demoSample(today, empty: session.empty),
    complete: session.complete,
    hidden: session.hideAmounts,
    amount: session.amount,
    pending: session.pending,
    pendingCount: session.pending ? 1 : 0,
    needsReview: session.needsReview,
    syncLabel: session.syncLabel,
    actions: DebtActions(
      logPayment: (_, _) => editor(FinancialAction.debtPayment),
      addDebt: () => editor(FinancialAction.debtImport),
      newLoan: () => editor(FinancialAction.borrowing),
      schedule: (d) => demo(d.scheduled ? 'Edit schedule' : 'Set schedule'),
      updateAmounts: (_) => demo('Update amounts'),
      breakDown: (_, _) => demo('Break down a payment'),
      lenderCharge: (_) => demo('Log a lender charge or waiver'),
      earlyPayoff: (_) => demo('Log an early payoff'),
      openDebt: (d) => openDemoPage<void>(
        context,
        DebtDetailView(
          listenable: session,
          source: (context) => demoDebtsSource(context, session),
          debtId: d.debt.id,
        ),
        'debt/${d.debt.id}',
        title: d.debt.title,
      ),
      openRecord: (_) => demo('View record'),
    ),
  );
}
