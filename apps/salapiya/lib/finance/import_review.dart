import 'dart:async';

import 'package:flutter/material.dart';

import '../app/overview_cards.dart' show civilLabel;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import 'import_data.dart';
import 'import_flow.dart';
import 'import_tab.dart';
import 'money_cards.dart';
import 'money_data.dart';

const _pageSize = 25;

/// The steps, as words: where you are, what's done and what's next.
class _Steps extends StatelessWidget {
  const _Steps(this.current);

  /// From 1.
  final int current;
  static const names = ['Match columns', 'Check rows', 'Import'];
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: 'Step $current of 3: ${names[current - 1]}',
      excludeSemantics: true,
      child: Wrap(
        spacing: Space.md,
        runSpacing: Space.xs,
        children: [
          for (final (i, name) in names.indexed)
            Text(
              '${i + 1}. $name',
              style: (i + 1 == current ? text.titleSmall : text.bodySmall)
                  ?.copyWith(color: i + 1 == current ? c.text : c.secondary),
            ),
        ],
      ),
    );
  }
}

/// A checkbox with its words beside it, the whole row its target.
class _Tick extends StatelessWidget {
  const _Tick({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => CheckboxListTile(
    dense: true,
    visualDensity: VisualDensity.compact,
    horizontalTitleGap: Space.xs,
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    value: value,
    title: Text(label),
    onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
  );
}

/// Match columns, check rows, import: the same commands in the same order as
/// ever, on one page. One button runs the last step, sending each group of
/// rows in turn with the ids kept in the draft.
class ImportReviewPage extends StatefulWidget {
  const ImportReviewPage({super.key, required this.flow, required this.source});
  final ImportFlow flow;
  final MoneySource Function(BuildContext context) source;
  @override
  State<ImportReviewPage> createState() => _ImportReviewPageState();
}

class _ImportReviewPageState extends State<ImportReviewPage> {
  ImportFlow get flow => widget.flow;
  int shown = _pageSize;
  bool? needsLookOnly;

  /// Confirm was tried, so unconfirmed duplicates say so on their rows.
  bool tried = false;

  /// What finished, once the draft is gone.
  String? finished;

  @override
  void dispose() {
    flow.dispose();
    super.dispose();
  }

  String? fieldError(String key) => flow.errorField == key ? flow.error : null;

  Widget pick(
    String key,
    String label,
    Map<String, String> choices, {
    String? helper,
    required bool locked,
  }) => OptionPicker<String>(
    key: ValueKey('import-$key'),
    label: label,
    style: PickerStyle.dropdown,
    helper: helper,
    required: true,
    value: choices.containsKey(flow.draft[key]) ? flow.draft[key] : null,
    options: [
      for (final e in choices.entries)
        PickerOption(value: e.key, label: e.value),
    ],
    errorText: fieldError(key),
    disabledReason: locked ? 'This can’t change once rows are saved.' : null,
    onChanged: locked || flow.busy ? null : (v) => flow.change(key, v),
  );

  Widget matchColumns(MoneySource source) {
    final locked = flow.head != null;
    final s = source.snapshot;
    final columns = {for (final h in flow.header) h: h};
    final gap = SizedBox(height: CompactForm.fieldGap(context));
    final account = s.accounts
        .where((a) => a.id == flow.draft['account'])
        .firstOrNull;
    final earlier = flow.draft['cutoffStrategy'] == 'rebase_history';
    final file = OverviewCard(
      key: const ValueKey('import-file-card'),
      title: 'Your file',
      caption: '${flow.rowCount} rows',
      child: CompactForm(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            pick('account', 'Account', {
              for (final a in s.accounts.where((a) => !a.archived))
                a.id: a.name,
            }, locked: locked),
            gap,
            pick('dateInterpretation', 'Date format', const {
              'YYYY-MM-DD': 'Year-month-day',
              'DD/MM/YYYY': 'Day/month/year',
              'MM/DD/YYYY': 'Month/day/year',
            }, locked: locked),
            gap,
            OptionPicker<String>(
              key: const ValueKey('import-cutoffStrategy'),
              label: 'Earlier history',
              style: PickerStyle.radio,
              value: flow.draft['cutoffStrategy'],
              options: const [
                PickerOption(
                  value: 'after_opening',
                  label: 'Only rows after the account’s start',
                  description: 'Its starting balance stays as it is.',
                ),
                PickerOption(
                  value: 'rebase_history',
                  label: 'Rows from before the start too',
                  description: 'The start moves earlier, and the rows you choose lead up to today’s starting balance.',
                ),
              ],
              disabledReason: locked
                  ? 'This can’t change once rows are saved.'
                  : null,
              onChanged: locked || flow.busy
                  ? null
                  : (v) => flow.change('cutoffStrategy', v),
            ),
            if (earlier) ...[
              gap,
              DateField(
                key: const ValueKey('import-earlierDate'),
                label: 'Earlier start date',
                required: true,
                value: (flow.draft['earlierDate'] ?? '').isEmpty
                    ? null
                    : DateTime.parse(flow.draft['earlierDate']!),
                lastDate: account == null
                    ? null
                    : DateTime.parse(account.cutoff),
                errorText: fieldError('earlierDate'),
                onChanged: locked || flow.busy
                    ? null
                    : (d) => flow.change(
                        'earlierDate',
                        d?.toIso8601String().substring(0, 10) ?? '',
                      ),
                disabledReason: locked
                    ? 'This can’t change once rows are saved.'
                    : null,
              ),
              gap,
              AmountField(
                key: const ValueKey('import-earlierAmount'),
                label: 'Balance on that date',
                required: true,
                controller: earlierAmount,
                errorText: fieldError('earlierAmount'),
                onChanged: locked
                    ? null
                    : (v) => flow.change('earlierAmount', v),
              ),
            ],
          ],
        ),
      ),
    );
    final mapping = OverviewCard(
      key: const ValueKey('import-mapping-card'),
      title: 'Columns',
      caption: 'Match each one to a column in your file',
      child: CompactForm(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, (key, label, helper)) in const [
              ('date', 'Date', null),
              ('kind', 'Income or expense', null),
              ('amountMinor', 'Amount in centavos', 'So 1500 means ₱15.00.'),
              (
                'classification',
                'Type',
                'Earned, gift, reward or other, or expense.',
              ),
              ('description', 'Description', null),
              ('reference', 'Reference', null),
            ].indexed) ...[
              if (i > 0) gap,
              pick(
                'mapping:$key',
                label,
                columns,
                helper: helper,
                locked: locked,
              ),
            ],
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (flow.c.connected) ...[
          const InlineNotice(
            'Choosing a file and matching columns work offline. Saving the rows and importing need a connection.',
          ),
          SizedBox(height: Space.cardGapOf(context)),
        ],
        DashboardGrid(
          cards: isDesktop(context) ? [(file, 6, 12), (mapping, 6, 12)] : null,
          stacked: [file, mapping],
        ),
        SizedBox(height: Space.cardGapOf(context)),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: AppButton(
            flow.busy
                ? 'Saving ${flow.done} of ${flow.rowCount} rows'
                : 'Check rows',
            key: const ValueKey('import-check-rows'),
            onPressed: flow.busy ? null : () => flow.run(flow.stage),
          ),
        ),
      ],
    );
  }

  Widget categoryChip(ImportRow r, MoneySource source) {
    final id = flow.choice(r.index)['category'] as String;
    final kind = r.income ? 'income' : 'expense';
    return MenuAnchor(
      alignmentOffset: const Offset(0, Space.xs),
      menuChildren: [
        for (final cat in source.snapshot.categories.where(
          (c) => c.kind == kind,
        ))
          MenuItemButton(
            key: ValueKey('import-category-${r.index}-${cat.id}'),
            trailingIcon: cat.id == id ? const Icon(Icons.check) : null,
            onPressed: () =>
                unawaited(flow.updateChoice(r.index, 'category', cat.id)),
            child: Text(cat.name),
          ),
      ],
      builder: (context, controller, _) => ChipButton(
        source.categoryName(id),
        key: ValueKey('import-category-${r.index}'),
        icon: Icons.category_outlined,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  /// What a row needs from the user, under its description.
  List<Widget> rowNotes(ImportRow r) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final warning = text.bodySmall?.copyWith(
      color: c.tone(NoticeTone.warning).$1,
    );
    final included = flow.choice(r.index)['include'] == true;
    return [
      for (final note in [...r.problems, ...r.warnings])
        Text(note, style: warning),
      if (r.hasWarning && included)
        _Tick(
          key: ValueKey('import-duplicate-${r.index}'),
          label: 'This isn’t a duplicate',
          value: flow.choice(r.index)['acknowledgeDuplicates'] == true,
          onChanged: flow.busy
              ? null
              : (v) => unawaited(
                  flow.updateChoice(r.index, 'acknowledgeDuplicates', v),
                ),
        ),
      if (tried && flow.unconfirmed.contains(r.index))
        Text('Confirm this, or leave the row out.', style: warning),
    ];
  }

  AppTableRow row(ImportRow r, MoneySource source) {
    final text = Theme.of(context).textTheme;
    final included = flow.choice(r.index)['include'] == true;
    final money = r.amount == null
        ? null
        : signedAmount(r.amount!, source.amount, hidden: source.hidden);
    final date = r.date == null ? 'No date' : civilLabel(r.date!);
    final include = Checkbox(
      key: ValueKey('import-include-${r.index}'),
      value: included,
      semanticLabel: 'Include row ${r.number}',
      onChanged: r.hasProblem || flow.busy
          ? null
          : (v) => unawaited(flow.updateChoice(r.index, 'include', v ?? false)),
    );
    final category = r.hasProblem ? null : categoryChip(r, source);
    final about = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(r.name, style: text.bodyMedium),
        ...rowNotes(r),
      ],
    );
    return AppTableRow(
      id: 'import-row-${r.index}',
      spoken: [
        'Row ${r.number}',
        date,
        r.name,
        ?money,
        ...r.problems,
        ...r.warnings,
        included ? 'Included' : 'Left out',
      ].join(', '),
      cells: [
        Text(date, style: text.bodyMedium),
        about,
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: category ?? const SizedBox.shrink(),
        ),
        Align(alignment: AlignmentDirectional.centerStart, child: include),
      ],
      money: [money],
      narrow: Padding(
        key: ValueKey('row-import-${r.index}'),
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                include,
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(r.name, style: text.bodyMedium),
                      Text(
                        date,
                        style: text.bodySmall?.copyWith(
                          color: CraftTheme.of(context).secondary,
                        ),
                      ),
                      ...rowNotes(r),
                    ],
                  ),
                ),
                const SizedBox(width: Space.sm),
                MoneyAmount(money),
              ],
            ),
            if (category != null)
              Align(alignment: AlignmentDirectional.centerEnd, child: category),
          ],
        ),
      ),
    );
  }

  Widget checkRows(MoneySource source) {
    final rows = flow.batch?.rows ?? const <ImportRow>[];
    final look = rows.where((r) => r.needsLook).toList();
    final onlyLook = needsLookOnly ?? look.isNotEmpty;
    final list = onlyLook ? look : rows;
    final chosen = flow.chosen;
    final consent = flow.needsConsent;
    final stale = flow.batch?.stale ?? false;
    Future<void> confirm() async {
      setState(() => tried = true);
      if (flow.unconfirmed.isNotEmpty) {
        setState(() {
          needsLookOnly = true;
          shown = rows.length;
        });
        return;
      }
      if (consent && flow.draft['acknowledge'] != 'true') {
        flow.error = 'Confirm the negative balance to go on.';
        flow.errorField = 'acknowledge';
        setState(() {});
        return;
      }
      if (!consent) flow.draft['acknowledge'] = 'false';
      await flow.run(flow.confirm);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stale) ...[
          InlineNotice(
            'This account changed after the review. Check the rows again.',
            key: const ValueKey('import-stale'),
            tone: NoticeTone.warning,
            action: AppButton.secondary(
              'Check the rows again',
              key: const ValueKey('import-refresh'),
              onPressed: () => flow.run(flow.refresh),
            ),
          ),
          SizedBox(height: Space.cardGapOf(context)),
        ],
        StatStrip(
          key: const ValueKey('import-row-totals'),
          stats: [
            (label: 'Rows', value: '${rows.length}', detail: null),
            (label: 'To import', value: '${chosen.length}', detail: null),
            (label: 'Need a look', value: '${look.length}', detail: null),
            (
              label: 'Left out',
              value: '${rows.length - chosen.length}',
              detail: null,
            ),
          ],
        ),
        SizedBox(height: Space.cardGapOf(context)),
        OverviewCard(
          key: const ValueKey('import-rows'),
          title: 'Check rows',
          caption: 'Amounts are exact, in pesos',
          trailing: MiniSegmented<bool>(
            key: const ValueKey('import-row-filter'),
            label: 'Rows',
            options: const [(true, 'Needs a look'), (false, 'All')],
            selected: onlyLook,
            onSelected: (v) => setState(() {
              needsLookOnly = v;
              shown = _pageSize;
            }),
          ),
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'Nothing needs a look',
                  message: 'Switch to All to see every row.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTable(
                      key: const ValueKey('import-rows-table'),
                      columns: const [
                        (label: 'Date', flex: 0, width: dateColumn),
                        (label: 'Description', flex: 4, width: null),
                        (label: 'Category', flex: 2, width: null),
                        (label: 'Include', flex: 1, width: null),
                      ],
                      moneyColumns: const ['Amount'],
                      rows: [for (final r in list.take(shown)) row(r, source)],
                    ),
                    if (list.length > shown) ...[
                      const SizedBox(height: Space.sm),
                      ShowMore(
                        left: list.length - shown,
                        onPressed: () => setState(() => shown += _pageSize),
                      ),
                    ] else
                      const ListEnd(key: ValueKey('import-rows-end')),
                  ],
                ),
        ),
        if (consent) ...[
          SizedBox(height: Space.cardGapOf(context)),
          SurfaceCard(
            key: const ValueKey('import-consent'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Tick(
                  key: const ValueKey('import-acknowledge'),
                  label: 'This import would take the account to a negative balance. That’s right, go on.',
                  value: flow.draft['acknowledge'] == 'true',
                  onChanged: flow.busy
                      ? null
                      : (v) {
                          flow.error = flow.errorField = null;
                          flow.change('acknowledge', '$v');
                        },
                ),
                if (fieldError('acknowledge') case final problem?)
                  Text(
                    problem,
                    key: const ValueKey('import-consent-error'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CraftTheme.of(context).tone(NoticeTone.warning).$1,
                    ),
                  ),
              ],
            ),
          ),
        ],
        SizedBox(height: Space.cardGapOf(context)),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: AppButton(
            'Confirm ${chosen.length} ${chosen.length == 1 ? 'row' : 'rows'}',
            key: const ValueKey('import-confirm'),
            onPressed: flow.busy || stale ? null : confirm,
          ),
        ),
      ],
    );
  }

  Future<void> stop() async {
    final yes = await showAppDialog<bool>(
      context,
      title: 'Stop the remaining rows?',
      body: const Text(
        'Rows already imported stay in your records. The rest won’t go in, and this can’t be undone.',
      ),
      primary: const ModalAction(
        'Stop remaining rows',
        value: true,
        destructive: true,
      ),
    );
    if (yes != true) return;
    finished = flow.draft['batch'];
    if (flow.busy) {
      flow.stopping = true;
      setState(() {});
      return;
    }
    await flow.run(flow.stopRemaining);
    if (flow.error != null) finished = null;
  }

  Future<void> start() async {
    final id = flow.draft['batch'];
    await flow.run(flow.importAll);
    if (flow.error == null) setState(() => finished = id);
  }

  Widget importStep(MoneySource source) {
    final text = Theme.of(context).textTheme;
    final b = flow.batch!;
    final total = b.selected.length;
    final imported = b.importedCount;
    return OverviewCard(
      key: const ValueKey('import-run'),
      title: 'Import',
      caption: b.leftOut == 0 ? null : '${b.leftOut} left out',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            flow.busy
                ? flow.stopping
                      ? 'Stopping after these rows…'
                      : 'Importing $imported of $total rows…'
                : imported == 0
                ? '$total ${total == 1 ? 'row goes' : 'rows go'} into your records.'
                : '$imported of $total rows imported.',
            key: const ValueKey('import-progress-words'),
            style: text.titleSmall,
          ),
          const SizedBox(height: Space.sm),
          SlimBar(
            key: const ValueKey('import-progress'),
            fraction: total == 0 ? 1 : imported / total,
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              AppButton(
                imported == 0 ? 'Import rows' : 'Continue import',
                key: const ValueKey('import-run-all'),
                onPressed: flow.busy ? null : start,
              ),
              AppButton.secondary(
                'Stop remaining rows',
                key: const ValueKey('import-stop'),
                onPressed: flow.stopping ? null : stop,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget result(MoneySource source) {
    final b = importBatches(source.snapshot)
        .where((b) => b.id == finished)
        .firstOrNull;
    final text = Theme.of(context).textTheme;
    return OverviewCard(
      key: const ValueKey('import-finished'),
      title: 'Import finished',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (b != null) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: importPill(b.status),
            ),
            const SizedBox(height: Space.sm),
            Text(importedLine(b), style: text.titleSmall),
            const SizedBox(height: Space.md),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton(
              'Back to Import',
              key: const ValueKey('import-done'),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  late final earlierAmount = TextEditingController(
    text: flow.draft['earlierAmount'] ?? '0.00',
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([flow, flow.c]),
    builder: (context, _) {
      final source = widget.source(context);
      final step = flow.draft.isEmpty
          ? 3
          : flow.preview == null
          ? 1
          : flow.decision == null
          ? 2
          : 3;
      final name = flow.draft['fileName'] ?? 'Cash activity file';
      return PopScope(
        canPop: !flow.busy,
        child: SectionPage(
          title: 'Review import',
          caption: flow.draft.isEmpty ? null : '$name · ${flow.rowCount} rows',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Steps(step),
              SizedBox(height: Space.cardGapOf(context)),
              if (flow.error != null && flow.errorField == null) ...[
                InlineNotice(
                  flow.error!,
                  key: const ValueKey('import-error'),
                  tone: NoticeTone.warning,
                ),
                SizedBox(height: Space.cardGapOf(context)),
              ],
              if (flow.loading)
                const LinearProgressIndicator()
              else if (flow.draft.isEmpty)
                result(source)
              else if (step == 1)
                matchColumns(source)
              else if (step == 2)
                checkRows(source)
              else
                importStep(source),
            ],
          ),
        ),
      );
    },
  );
}

/// One import: what happened to each row. Read-only, so it needs no draft.
class ImportDetailView extends StatefulWidget {
  const ImportDetailView({
    super.key,
    required this.listenable,
    required this.source,
    required this.id,
  });
  final Listenable listenable;
  final MoneySource Function(BuildContext context) source;
  final String id;
  @override
  State<ImportDetailView> createState() => _ImportDetailViewState();
}

class _ImportDetailViewState extends State<ImportDetailView> {
  int shown = _pageSize;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.listenable,
    builder: (context, _) {
      final source = widget.source(context);
      final text = Theme.of(context).textTheme;
      final muted = text.bodySmall?.copyWith(
        color: CraftTheme.of(context).secondary,
      );
      final b = importBatches(source.snapshot)
          .where((b) => b.id == widget.id)
          .firstOrNull;
      if (b == null) {
        return const SectionPage(
          title: 'Import',
          child: SurfaceCard(
            child: EmptyState(
              icon: Icons.history,
              title: 'This import is no longer here',
              message: 'Go back to see the others.',
            ),
          ),
        );
      }
      final account =
          source.snapshot.accounts
              .where((a) => a.id == b.account)
              .firstOrNull
              ?.name ??
          'Account';
      final rows = b.rows;
      return SectionPage(
        title: b.name,
        status: importPill(b.status),
        caption: detailLine([account, civilLabel(b.date), importedLine(b)]),
        actions: [
          if (b.open)
            AppButton(
              'Continue review',
              key: const ValueKey('import-page-continue'),
              onPressed: () => unawaited(source.actions.continueImport(b.id)),
            ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OverviewCard(
              key: const ValueKey('import-page-rows'),
              title: 'Rows',
              caption: '${b.rowCount} in the file',
              child: rows.isEmpty
                  ? const EmptyState(
                      icon: Icons.table_rows_outlined,
                      title: 'Rows aren’t checked yet',
                      message: 'They show here once the review starts.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTable(
                          key: const ValueKey('import-page-table'),
                          dense: true,
                          columns: const [
                            (label: 'Date', flex: 0, width: dateColumn),
                            (label: 'Description', flex: 4, width: null),
                            (label: 'Result', flex: 2, width: null),
                          ],
                          moneyColumns: const ['Amount'],
                          rows: [
                            for (final r in rows.take(shown))
                              () {
                                final money = r.amount == null
                                    ? null
                                    : signedAmount(
                                        r.amount!,
                                        source.amount,
                                        hidden: source.hidden,
                                      );
                                final date = r.date == null
                                    ? 'No date'
                                    : civilLabel(r.date!);
                                final state = b.result(r);
                                return AppTableRow(
                                  id: 'import-result-${r.index}',
                                  spoken: [
                                    date,
                                    r.name,
                                    state,
                                    ?money,
                                  ].join(', '),
                                  cells: [
                                    Text(date, style: text.bodyMedium),
                                    Text(r.name, style: text.bodyMedium),
                                    Text(state, style: muted),
                                  ],
                                  money: [money],
                                  narrow: KeyedSubtree(
                                    key: ValueKey(
                                      'row-import-result-${r.index}',
                                    ),
                                    child: AdaptiveRow(
                                      title: r.name,
                                      subtitle: detailLine([date, state]),
                                      trailing: MoneyAmount(money),
                                    ),
                                  ),
                                );
                              }(),
                          ],
                        ),
                        if (rows.length > shown) ...[
                          const SizedBox(height: Space.sm),
                          ShowMore(
                            left: rows.length - shown,
                            onPressed: () => setState(() => shown += _pageSize),
                          ),
                        ] else
                          const ListEnd(key: ValueKey('import-page-end')),
                        const SizedBox(height: Space.sm),
                        FormMoreDetails(
                          label: 'View details',
                          children: [FactRow('File fingerprint', b.checksum)],
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

/// The error a tab shows when an import can't start, in the snack bar: there's
/// no field or page to put it on yet.
String importProblem(Object e) => e is LocalRuleException
    ? e.message
    : e is FormatException
    ? e.message
    : 'This file couldn’t be read. Check it’s a CSV, and try again.';
