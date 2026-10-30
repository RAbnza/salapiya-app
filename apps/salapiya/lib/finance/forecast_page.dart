import 'package:flutter/material.dart';

import '../app/overview_cards.dart' show Amount, civilLabel;
import '../app/overview_data.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import '../p0/exact_money.dart' show parsePhp;
import 'card_data.dart';
import 'money_data.dart';
import 'planning_cards.dart';

/// What each kind of forecast line is, in everyday words.
const _basisLabels = {
  'Recorded future cash': 'Logged',
  'Explicit card payment assumption': 'Card payment you chose',
  'Explicit installment payment assumption': 'Installment you chose',
  'Recurring expected cash': 'Expected',
  'Hypothetical; not actual money': 'What-if',
};

/// A card's choice meaning "its installment plans".
const _installments = 'installments';

String _civilDate(DateTime d) => d.toIso8601String().substring(0, 10);

/// One row of what-ifs, as typed. It counts once it's complete.
class _WhatIf {
  DateTime? date;
  bool moneyIn = false;
  final amount = TextEditingController();
  final label = TextEditingController();

  void dispose() {
    amount.dispose();
    label.dispose();
  }
}

/// An estimate of the cash ahead. Read-only: nothing here is saved, and no
/// choice changes a record or a balance.
class ForecastPage extends StatefulWidget {
  const ForecastPage({
    super.key,
    required this.listenable,
    required this.source,
  });
  final Listenable listenable;
  final MoneySource Function(BuildContext context) source;
  @override
  State<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<ForecastPage> {
  String? first, last;
  bool independent = false;

  /// Per card: a statement's id, [_installments], or nothing.
  final choices = <String, String>{};

  /// What's been left out: its source id, and its name for Put back.
  final left = <String, String>{};
  final whatIfs = <_WhatIf>[];
  int shown = _pageSize;

  static const _pageSize = 25, _maxWhatIfs = 20;

  @override
  void dispose() {
    for (final w in whatIfs) {
      w.dispose();
    }
    super.dispose();
  }

  /// The row's amount; null while it's blank or can't be read.
  BigInt? amountOf(_WhatIf w) {
    try {
      final value = parsePhp(w.amount.text.trim());
      return value == BigInt.zero ? null : value;
    } on Object {
      return null;
    }
  }

  String? dateProblem(_WhatIf w, String today, String through) {
    final date = w.date;
    if (date == null) return null;
    final day = _civilDate(date);
    return day.compareTo(today) <= 0 || day.compareTo(through) > 0
        ? 'Choose a date in this forecast.'
        : null;
  }

  String? amountProblem(_WhatIf w) =>
      w.amount.text.trim().isEmpty || amountOf(w) != null
      ? null
      : 'Enter an amount above zero, like 1500.00.';

  List<ForecastContribution> ready(String today, String through) => [
    for (final (i, w) in whatIfs.indexed)
      if (w.date != null &&
          dateProblem(w, today, through) == null &&
          amountOf(w) != null &&
          w.label.text.trim().isNotEmpty)
        ForecastContribution(
          'what-if-$i',
          w.label.text.trim(),
          _civilDate(w.date!),
          w.moneyIn ? amountOf(w)! : -amountOf(w)!,
          'Hypothetical',
        ),
  ];

  /// The choices a card has. A statement needs something still due after
  /// today; the rest the forecast would only leave out.
  List<PickerOption<String>> cardOptions(CardRow card, Amount amount) => [
    const PickerOption(value: '', label: 'No payment'),
    for (final r in card.statements)
      if (!r.settled && r.days > 0)
        PickerOption(
          value: r.id,
          label: 'Statement due ${civilLabel(r.due)}',
          description: '${amount(r.stillDue)} still due',
        ),
    if (card.plans.isNotEmpty)
      const PickerOption(
        value: _installments,
        label: 'Its installment plans',
        description: 'Each payment on its due date',
      ),
  ];

  Widget dates(String today, String from, String through, String? error) {
    final soonest = DateTime.parse(addCivilDays(today, 1));
    final latest = DateTime.parse(addCivilDays(today, 366));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DateField(
          key: const ValueKey('forecast-from'),
          label: 'First day',
          required: true,
          value: DateTime.parse(from),
          firstDate: soonest,
          lastDate: latest,
          onChanged: (d) {
            if (d != null) setState(() => first = _civilDate(d));
          },
        ),
        SizedBox(height: CompactForm.fieldGap(context)),
        DateField(
          key: const ValueKey('forecast-through'),
          label: 'Last day',
          required: true,
          value: DateTime.parse(through),
          firstDate: soonest,
          lastDate: latest,
          errorText: error,
          onChanged: (d) {
            if (d != null) setState(() => last = _civilDate(d));
          },
        ),
      ],
    );
  }

  Widget choicesCard(
    List<CardRow> cards,
    Amount amount,
    String today,
    String from,
    String through,
    String? dateError,
  ) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final payable = [
      for (final card in cards)
        if (cardOptions(card, amount).length > 1) card,
    ];
    return OverviewCard(
      key: const ValueKey('forecast-choices'),
      title: 'What to count',
      caption: 'Your choices aren’t saved',
      child: CompactForm(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            dates(today, from, through, dateError),
            SizedBox(height: CompactForm.fieldGap(context)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Count recurring items too', style: text.bodyMedium),
                      Text(
                        'Turn this on if they aren’t the same money as what you’ve logged or a card payment you chose. It’s off so nothing counts twice.',
                        style: text.bodySmall?.copyWith(color: c.secondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                Semantics(
                  label: 'Count recurring items too',
                  child: Switch(
                    key: const ValueKey('forecast-independent'),
                    value: independent,
                    onChanged: (v) => setState(() => independent = v),
                  ),
                ),
              ],
            ),
            for (final card in payable) ...[
              SizedBox(height: CompactForm.fieldGap(context)),
              OptionPicker<String>(
                key: ValueKey('forecast-card-${card.id}'),
                label: card.name,
                style: PickerStyle.radio,
                value:
                    cardOptions(
                      card,
                      amount,
                    ).any((o) => o.value == choices[card.id])
                    ? choices[card.id]
                    : '',
                options: cardOptions(card, amount),
                onChanged: (v) => setState(() => choices[card.id] = v),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget whatIfRow(int i, _WhatIf w, String today, String through) {
    final date = DateField(
      key: ValueKey('what-if-date-$i'),
      label: 'Date',
      value: w.date,
      errorText: dateProblem(w, today, through),
      firstDate: DateTime.parse(addCivilDays(today, 1)),
      lastDate: DateTime.parse(addCivilDays(today, 366)),
      onChanged: (d) => setState(() => w.date = d),
    );
    final amount = AmountField(
      key: ValueKey('what-if-amount-$i'),
      label: 'Amount',
      controller: w.amount,
      errorText: amountProblem(w),
      onChanged: (_) => setState(() {}),
    );
    final name = HelpTextField(
      key: ValueKey('what-if-name-$i'),
      label: 'Name',
      controller: w.label,
      onChanged: (_) => setState(() {}),
    );
    final direction = MiniSegmented<bool>(
      key: ValueKey('what-if-direction-$i'),
      label: 'Direction',
      options: const [(false, 'Money out'), (true, 'Money in')],
      selected: w.moneyIn,
      onSelected: (v) => setState(() => w.moneyIn = v),
    );
    final remove = AppIconButton(
      key: ValueKey('what-if-remove-$i'),
      icon: Icons.close,
      tooltip: 'Remove this what-if',
      onPressed: () => setState(() => whatIfs.removeAt(i).dispose()),
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (narrowAt(context, box.maxWidth, tableBase + rowBase)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: direction,
                    ),
                  ),
                  remove,
                ],
              ),
              SizedBox(height: CompactForm.fieldGap(context)),
              date,
              SizedBox(height: CompactForm.fieldGap(context)),
              amount,
              SizedBox(height: CompactForm.fieldGap(context)),
              name,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(flex: 2, child: date),
            const SizedBox(width: Space.md),
            Expanded(flex: 2, child: amount),
            const SizedBox(width: Space.md),
            Expanded(flex: 3, child: name),
            const SizedBox(width: Space.md),
            direction,
            const SizedBox(width: Space.xs),
            remove,
          ],
        );
      },
    );
  }

  Widget whatIfCard(String today, String through) => OverviewCard(
    key: const ValueKey('forecast-what-ifs'),
    title: 'What if',
    caption: 'Try money that isn’t logged. Nothing is saved.',
    centered: whatIfs.isEmpty,
    trailing: whatIfs.isNotEmpty && whatIfs.length < _maxWhatIfs
        ? CardLink(
            'Add a what-if',
            key: const ValueKey('what-if-add'),
            icon: Icons.add,
            onPressed: () => setState(() => whatIfs.add(_WhatIf())),
          )
        : null,
    child: whatIfs.isEmpty
        ? EmptyState(
            icon: Icons.tune,
            title: 'No what-ifs yet',
            message: 'A big purchase or an expected refund, for example.',
            action: AppButton.secondary(
              'Add a what-if',
              key: const ValueKey('what-if-add'),
              onPressed: () => setState(() => whatIfs.add(_WhatIf())),
            ),
          )
        : CompactForm(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, w) in whatIfs.indexed) ...[
                  if (i > 0) const SizedBox(height: Space.md),
                  whatIfRow(i, w, today, through),
                ],
                const SizedBox(height: Space.sm),
                Text(
                  'A what-if counts once it has a date, an amount and a name.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: CraftTheme.of(context).secondary),
                ),
              ],
            ),
          ),
  );

  AppTableRow includedRow(ForecastContribution row, Amount amount) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(
      color: CraftTheme.of(context).secondary,
    );
    final kind = _basisLabels[row.basis] ?? row.basis;
    final leavable =
        row.basis != 'Recorded future cash' &&
        !row.basis.startsWith('Hypothetical');
    final link = 'included-${row.source}-${row.date}';
    Widget? action({bool narrow = false}) => !leavable
        ? null
        : CardLink(
            'Leave out',
            key: ValueKey('leave-out-$link${narrow ? '-narrow' : ''}'),
            chevron: false,
            onPressed: () => setState(() => left[row.source] = row.label),
          );
    final shown = amount(row.amount);
    return AppTableRow(
      id: link,
      spoken: [civilLabel(row.date), row.label, kind, shown].join(', '),
      cells: [
        Text(civilLabel(row.date), style: text.bodyMedium),
        Text(row.label, style: text.bodyMedium),
        Text(kind, style: muted),
      ],
      money: [shown],
      action: action(),
      narrow: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdaptiveRow(
            title: row.label,
            subtitle: detailLine([civilLabel(row.date), kind]),
            trailing: MoneyAmount(shown),
          ),
          ?(leavable
              ? Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: action(narrow: true),
                )
              : null),
        ],
      ),
    );
  }

  Widget includedCard(FinanceForecast f, Amount amount) {
    final rows = [...f.contributions]
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.label.compareTo(b.label);
      });
    return OverviewCard(
      key: const ValueKey('forecast-included'),
      title: 'What’s included',
      caption:
          'What you’ve logged can’t be left out. Correct the record instead.',
      child: rows.isEmpty
          ? const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nothing else is expected',
              message: 'This forecast is your balance today, carried forward.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTable(
                  key: const ValueKey('forecast-included-table'),
                  dense: true,
                  columns: const [
                    (label: 'Date', flex: 0, width: dateColumn),
                    (label: 'Item', flex: 3, width: null),
                    (label: 'Type', flex: 2, width: null),
                  ],
                  moneyColumns: const ['Amount'],
                  actionLabel: 'Leave out',
                  rows: [
                    for (final r in rows.take(shown)) includedRow(r, amount),
                  ],
                ),
                if (rows.length > shown) ...[
                  const SizedBox(height: Space.sm),
                  ShowMore(
                    left: rows.length - shown,
                    onPressed: () => setState(() => shown += _pageSize),
                  ),
                ] else
                  const ListEnd(key: ValueKey('forecast-included-end')),
              ],
            ),
    );
  }

  Widget leftOutCard(FinanceForecast f) {
    final text = Theme.of(context).textTheme;
    final notes = f.exclusions
        .skip(1)
        .where((e) => !e.endsWith(forecastLeftOutByYou));
    return OverviewCard(
      key: const ValueKey('forecast-left-out-card'),
      title: 'What’s left out',
      caption: f.exclusions.first,
      child: notes.isEmpty && left.isEmpty
          ? Text(
              'Everything else expected is included.',
              style: text.bodySmall?.copyWith(
                color: CraftTheme.of(context).secondary,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in left.entries)
                  Row(
                    key: ValueKey('put-back-row-${e.key}'),
                    children: [
                      Expanded(child: Text(e.value, style: text.bodyMedium)),
                      const SizedBox(width: Space.md),
                      CardLink(
                        'Put back',
                        key: ValueKey('put-back-${e.key}'),
                        chevron: false,
                        onPressed: () => setState(() => left.remove(e.key)),
                      ),
                    ],
                  ),
                for (final n in notes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.xs),
                    child: Text(n, style: text.bodyMedium),
                  ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.listenable,
    builder: (context, _) {
      final source = widget.source(context);
      final s = source.snapshot, today = source.today;
      final amount = source.amount, hidden = source.hidden;
      final from = first ?? addCivilDays(today, 1);
      final through = last ?? addCivilDays(today, 30);
      final dateError = through.compareTo(from) < 0
          ? 'Choose a day on or after the first day.'
          : null;
      final cards = source.complete ? cardRows(s, today) : const <CardRow>[];
      FinanceForecast? f;
      String? problem;
      if (source.complete && dateError == null) {
        final picked = {
          for (final card in cards)
            if (cardOptions(
              card,
              amount,
            ).any((o) => o.value == choices[card.id]))
              card.id: choices[card.id]!,
        };
        try {
          f = financialForecast(
            s,
            today: today,
            from: from,
            through: through,
            independentRecurring: independent,
            cardStatements: [
              for (final v in picked.values)
                if (v != _installments && v.isNotEmpty) v,
            ],
            cardInstallments: [
              for (final e in picked.entries)
                if (e.value == _installments) e.key,
            ],
            excludedSources: left.keys.toSet(),
            adjustments: ready(today, through),
          );
        } on LocalRuleException catch (e) {
          problem = e.message;
        }
      }
      final figures = OverviewCard(
        key: const ValueKey('forecast-figures'),
        title: 'Your cash ahead',
        caption: 'Closing balance each day, across your accounts',
        child: !source.complete
            ? const NotAvailable(
                'The forecast shows once records are complete.',
              )
            : hidden
            ? const AmountsHidden()
            : f == null
            ? NotAvailable(problem ?? dateError ?? 'Check your choices.')
            : f.daily.isEmpty
            ? const NotAvailable('Choose a longer period.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ForecastFigures(
                    forecast: f,
                    amount: amount,
                    height: heroChartHeight,
                  ),
                  if (f.reserved > BigInt.zero) ...[
                    const SizedBox(height: Space.sm),
                    Text(
                      'Includes ${amount(f.reserved)} set aside for goals.',
                      key: const ValueKey('forecast-set-aside'),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: CraftTheme.of(context).secondary),
                    ),
                  ],
                ],
              ),
      );
      final choice = choicesCard(
        cards,
        amount,
        today,
        from,
        through,
        dateError,
      );
      final what = whatIfCard(today, through);
      final detail = f == null
          ? const <Widget>[]
          : [includedCard(f, amount), leftOutCard(f)];
      return SectionPage(
        title: 'Cash forecast',
        caption: 'An estimate, not money you have · as of ${civilLabel(today)}',
        child: DashboardGrid(
          key: const ValueKey('forecast-grid'),
          cards: isDesktop(context)
              ? [
                  (figures, 12, 12),
                  (choice, 5, 12),
                  (what, 7, 12),
                  if (detail.isNotEmpty) ...[
                    (detail.first, 7, 12),
                    (detail.last, 5, 12),
                  ],
                ]
              : null,
          stacked: [figures, choice, what, ...detail],
        ),
      );
    },
  );
}
