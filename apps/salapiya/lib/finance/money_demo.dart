import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_demo.dart';
import '../app/previews.dart';
import '../features/finance/contracts/financial_models.dart';
import '../features/finance/presentation/financial_editor.dart';
import '../local/finance_domain.dart';
import '../prototype/scenarios.dart';
import 'card_pages.dart' show CardDuesPage;
import 'file_pages.dart';
import 'files_data.dart';
import 'forecast_page.dart';
import 'import_review.dart' show ImportDetailView;
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
  // As `LocalFinancialController.cardLiabilityAndCredit` splits them.
  var owed = BigInt.zero, credit = BigInt.zero;
  for (final card in cards) {
    final balance = -financeBalance(
      s,
      'card_liability',
      'card',
      card.actionId,
      through: today,
    );
    if (balance > BigInt.zero) {
      owed += balance;
    } else {
      credit -= balance;
    }
  }
  final newest = s.revisions.lastOrNull?.id;
  return MoneySource(
    today: today,
    snapshot: s,
    complete: session.complete,
    hidden: session.hideAmounts,
    amount: session.amount,
    categoryName: name,
    cards: cards.isEmpty ? null : (owed, credit),
    waiting: session.pending ? (id) => id == newest : null,
    pending: session.pending,
    pendingCount: session.pending ? 1 : 0,
    needsReview: session.needsReview,
    syncLabel: session.syncLabel,
    files: _DemoFiles(s, demo),
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
      form: (_, title, {initial = const {}, replacing, overrides = const {}}) =>
          demo(title),
      openItem: (id) => openMoneyItem(
        context,
        snapshot: s,
        listenable: session,
        source: (context) => demoMoneySource(context, session),
        id: id,
        record: (id) => openDemoPage<void>(
          context,
          RecordDetailView(
            listenable: session,
            source: (context) => demoMoneySource(context, session),
            id: id,
          ),
          'money/transaction/$id',
          title: recordTitle(s.revision(id)),
        ),
      ),
      openForecast: () => openDemoPage<void>(
        context,
        ForecastPage(
          listenable: session,
          source: (context) => demoMoneySource(context, session),
        ),
        'money/forecast',
        title: 'Cash forecast',
      ),
      openCardDues: () => openDemoPage<void>(
        context,
        CardDuesPage(
          listenable: session,
          source: (context) => demoMoneySource(context, session),
        ),
        'money/card-dues',
        title: 'Due on your cards',
      ),
      exportCsv: (_, _, _, _) => demo('Export CSV'),
      importFile: () async => demo('Import a file'),
      continueImport: (_) async => demo('Continue review'),
      openImport: (batch) => openDemoPage<void>(
        context,
        ImportDetailView(
          listenable: session,
          source: (context) => demoMoneySource(context, session),
          id: batch,
        ),
        'money/import/$batch',
        title: 'Import',
      ),
      attachFile: () async => demo('Attach a file'),
      openFile: (id) => openDemoPage<void>(
        context,
        FileDetailView(
          listenable: session,
          source: (context) => demoMoneySource(context, session),
          id: id,
        ),
        'money/file/$id',
        title: 'File',
      ),
    ),
  );
}

/// The demo has no store: files named as missing aren't on this device, the
/// rest are, and what needs real bytes opens a placeholder.
class _DemoFiles implements FileAccess {
  const _DemoFiles(this.snapshot, this.demo);
  final LocalSnapshot snapshot;
  final void Function(String label) demo;

  @override
  Future<bool> present(String id) async =>
      snapshot.current.where((r) => r.id == id).firstOrNull?.title !=
      demoMissingFile;
  @override
  Future<String?> check(LocalRevision file) async =>
      await present(file.id) ? null : 'This file isn’t on this device.';
  @override
  Future<List<String>> leftovers() async => const [];
  @override
  Future<FileSelection?> selection() async => null;
  @override
  Future<void> preview(BuildContext context, LocalRevision file) async =>
      demo('Preview');
  @override
  Future<void> openElsewhere(BuildContext context, LocalRevision file) async =>
      demo('Open in another app');
  @override
  Future<void> saveCopy(BuildContext context, LocalRevision file) async =>
      demo('Save a copy');
  @override
  Future<void> restore(BuildContext context, LocalRevision file) async =>
      demo('Restore from original');
  @override
  Future<void> removeCopy(BuildContext context, LocalRevision file) async =>
      demo('Remove from this device');
  @override
  Future<bool> attach(BuildContext context, String source) async {
    demo('Attach a file');
    return false;
  }

  @override
  Future<void> resume(BuildContext context, FileSelection selection) async {}
  @override
  Future<void> reselect(BuildContext context, FileSelection selection) async {}
  @override
  Future<void> release(BuildContext context, FileSelection selection) async {}
}
