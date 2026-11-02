import 'dart:async';

import 'package:flutter/material.dart';

import '../app/overview_cards.dart' show civilLabel;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'import_data.dart';
import 'money_data.dart';

/// An import's status as a pill.
Widget importPill(ImportStatus status) => switch (status) {
  ImportStatus.done => StatusPill(
    status.label,
    icon: Icons.check_circle_outline,
    tone: PillTone.success,
  ),
  ImportStatus.stopped => StatusPill(status.label, icon: Icons.block),
  _ => StatusPill(status.label, icon: Icons.schedule, tone: PillTone.warning),
};

/// "38 of 40 imported".
String importedLine(ImportBatch b) =>
    '${b.importedCount} of ${b.rowCount} imported';

/// "What's waiting, and did my last import work?" The review itself is a page,
/// so this tab only ever reports.
class ImportTab extends StatefulWidget {
  const ImportTab({super.key, required this.source});
  final MoneySource source;
  @override
  State<ImportTab> createState() => _ImportTabState();
}

class _ImportTabState extends State<ImportTab> {
  /// The protected draft: a file chosen and not finished.
  Map<String, String>? draft;

  MoneySource get source => widget.source;

  @override
  void initState() {
    super.initState();
    unawaited(read());
  }

  @override
  void didUpdateWidget(ImportTab old) {
    super.didUpdateWidget(old);
    unawaited(read());
  }

  Future<void> read() async {
    final saved = await source.importDraft?.call();
    if (!mounted || saved?['batch'] == draft?['batch']) return;
    setState(() => draft = saved);
  }

  Future<void> after(Future<void> step) async {
    await step;
    await read();
  }

  void importFile() => unawaited(after(source.actions.importFile()));

  void resume(String? batch) =>
      unawaited(after(source.actions.continueImport(batch)));

  String accountName(ImportBatch b) =>
      source.snapshot.accounts
          .where((a) => a.id == b.account)
          .firstOrNull
          ?.name ??
      'Account';

  Widget waiting(List<ImportBatch> batches) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(
      color: CraftTheme.of(context).secondary,
    );
    final saved = draft;
    final open =
        batches.where((b) => b.id == saved?['batch']).firstOrNull ??
        batches.where((b) => b.open).firstOrNull;
    final onlyDraft = open == null && saved != null;
    Widget body(String title, List<String> details, Widget? pill, String? id) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title, style: text.titleSmall),
                ?pill,
              ],
            ),
            const SizedBox(height: Space.xxs),
            Text(detailLine(details), style: muted),
            const SizedBox(height: Space.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton(
                'Continue review',
                key: const ValueKey('import-continue'),
                onPressed: () => resume(id),
              ),
            ),
          ],
        );
    return OverviewCard(
      key: const ValueKey('import-waiting'),
      title: 'Waiting for you',
      caption: 'Nothing is in your records until the Import step',
      centered: true,
      trailing: source.complete && (open != null || onlyDraft)
          ? CardLink(
              'Import a file',
              key: const ValueKey('import-another'),
              icon: Icons.upload_file_outlined,
              onPressed: importFile,
            )
          : null,
      child: !source.complete
          ? const NotAvailable('This shows once your records are complete.')
          : open != null
          ? body(
              open.name,
              [
                '${open.rowCount} ${open.rowCount == 1 ? 'row' : 'rows'}',
                accountName(open),
                if (open.needsLook > 0 && open.decision == null)
                  '${open.needsLook} need a look',
              ],
              importPill(open.status),
              open.id,
            )
          : onlyDraft
          ? body(
              saved['fileName'] ?? 'Cash activity file',
              ['${saved['rowCount']} rows', 'Not saved to your records yet'],
              null,
              null,
            )
          : EmptyState(
              icon: Icons.upload_file_outlined,
              title: 'Nothing waiting',
              message: 'Import a file to bring in past income and expenses.',
              action: AppButton(
                'Import a file',
                key: const ValueKey('import-file'),
                icon: Icons.upload_file_outlined,
                onPressed: importFile,
              ),
            ),
    );
  }

  Widget last(List<ImportBatch> batches) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(
      color: CraftTheme.of(context).secondary,
    );
    final b = batches.where((b) => !b.open).firstOrNull;
    return OverviewCard(
      key: const ValueKey('import-last'),
      title: 'Last import',
      centered: true,
      child: !source.complete
          ? const NotAvailable('This shows once your records are complete.')
          : b == null
          ? const EmptyState(
              icon: Icons.history,
              title: 'No imports yet',
              message: 'Your finished imports show here.',
            )
          : Pressable(
              key: const ValueKey('import-last-open'),
              onTap: () => unawaited(source.actions.openImport(b.id)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  importPill(b.status),
                  const SizedBox(height: Space.sm),
                  Text(importedLine(b), style: text.titleSmall),
                  Text(
                    detailLine([
                      civilLabel(b.date),
                      if (b.leftOut > 0) '${b.leftOut} left out',
                    ]),
                    style: muted,
                  ),
                ],
              ),
            ),
    );
  }

  Widget history(List<ImportBatch> batches) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(
      color: CraftTheme.of(context).secondary,
    );
    return OverviewCard(
      key: const ValueKey('import-history'),
      title: 'Import history',
      caption: 'Newest first',
      child: !source.complete
          ? const NotAvailable('This shows once your records are complete.')
          : batches.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'No imports yet',
              message: 'Each file you import shows here.',
            )
          : AppTable(
              key: const ValueKey('import-history-table'),
              columns: const [
                (label: 'Date', flex: 0, width: dateColumn),
                (label: 'File', flex: 4, width: null),
                (label: 'Account', flex: 3, width: null),
                (label: 'Rows', flex: 1, width: null),
                (label: 'Imported', flex: 1, width: null),
                (label: 'Status', flex: 2, width: null),
              ],
              rows: [
                for (final b in batches)
                  AppTableRow(
                    id: 'import-${b.id}',
                    spoken: [
                      civilLabel(b.date),
                      b.name,
                      accountName(b),
                      importedLine(b),
                      b.status.label,
                    ].join(', '),
                    onTap: () => unawaited(source.actions.openImport(b.id)),
                    cells: [
                      Text(civilLabel(b.date), style: text.bodyMedium),
                      Text(b.name, style: text.bodyMedium),
                      Text(accountName(b), style: muted),
                      Text('${b.rowCount}', style: text.bodyMedium),
                      Text('${b.importedCount}', style: text.bodyMedium),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: importPill(b.status),
                      ),
                    ],
                    money: const [],
                    narrow: KeyedSubtree(
                      key: ValueKey('row-import-${b.id}'),
                      child: AdaptiveRow(
                        title: b.name,
                        subtitle: detailLine([
                          civilLabel(b.date),
                          importedLine(b),
                          b.status.label,
                        ]),
                        onTap: () => unawaited(source.actions.openImport(b.id)),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final android = !isDesktop(context);
    final batches = source.complete
        ? importBatches(source.snapshot)
        : const <ImportBatch>[];
    final wait = waiting(batches), latest = last(batches);
    final past = history(batches);
    const supported = _WhatCanBeImported(key: ValueKey('import-supported'));
    return DashboardGrid(
      key: const ValueKey('import-grid'),
      cards: android
          ? null
          : [
              (wait, 8, 12),
              (latest, 4, 12),
              (past, 12, 12),
              (supported, 12, 12),
            ],
      stacked: [wait, latest, past, supported],
    );
  }
}

class _WhatCanBeImported extends StatelessWidget {
  const _WhatCanBeImported({super.key});
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget line(String words) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xxs),
      child: Text(words, style: text.bodyMedium),
    );
    return OverviewCard(
      title: 'What can be imported',
      caption: 'A CSV file of past income and expenses, in pesos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line(
            'Six columns: date, kind, amount_minor, classification, description and reference.',
          ),
          line('Up to 1 MB and 500 rows, one account at a time.'),
          line(
            'Not cards, debts, transfers, bank statements or dates after today.',
          ),
        ],
      ),
    );
  }
}
