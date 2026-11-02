import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';

/// A sample of the app on the greeting, built from its real cards, so people
/// see what they're getting. Every figure is made up and the panel says so.
/// It does nothing: it can't be pressed, focused or read as a real balance.
class GreetingPreview extends StatelessWidget {
  const GreetingPreview({super.key});

  /// These rows' words and amounts are short, so they stay side by side in
  /// the half-width cards.
  static const _rowFits = Space.xxxl * 3;

  static const _balances = [
    2410000,
    2385000,
    2462000,
    2440000,
    2518000,
    2496000,
    2610000,
    2588000,
    2694000,
    2672000,
    2790000,
    2764000,
    2865000,
    2930075,
  ];
  static const _spent = [
    42000,
    60500,
    136500,
    167500,
    225500,
    237500,
    334000,
    358000,
    405000,
    473000,
    488500,
    540500,
    623500,
    644500,
    683500,
    821450,
  ];
  static const _spending = [
    42000,
    18500,
    0,
    76000,
    31000,
    58000,
    12000,
    96500,
    24000,
    0,
    47000,
    68000,
    15500,
    52000,
    83000,
    21000,
    0,
    39000,
  ];

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final gap = Space.cardGapOf(context);
    const labels = ['Available money', 'Spent this month'];
    // A change line under the amount, as the real tiles have, so the amount
    // starts level with the sparkline.
    final available = KpiTile(
      icon: Icons.account_balance_wallet_outlined,
      label: 'Available money',
      labels: labels,
      compactSpark: true,
      value: const MoneyAmount(
        '₱29,300.75',
        size: MoneySize.tile,
        textAlign: TextAlign.start,
      ),
      change: const ChangeLine(
        basisPoints: 420,
        versus: 'vs last month',
        meaning: ChangeMeaning.riseIsGood,
      ),
      spark: [for (final v in _balances) BigInt.from(v)],
      caption: 'Cash and bank',
    );
    final spent = KpiTile(
      icon: Icons.north_east,
      label: 'Spent this month',
      labels: labels,
      compactSpark: true,
      value: const MoneyAmount(
        '₱18,214.50',
        size: MoneySize.tile,
        textAlign: TextAlign.start,
      ),
      change: const ChangeLine(
        basisPoints: 310,
        versus: 'vs last month',
        meaning: ChangeMeaning.riseIsBad,
      ),
      spark: [for (final v in _spent) BigInt.from(v)],
      caption: 'After refunds',
    );
    final chart = OverviewCard(
      title: 'Spending this month',
      child: OverviewBarChart(
        height: heroChartHeight,
        values: [for (final v in _spending) BigInt.from(v)],
        label: (i) => i % 4 == 0 ? '${i + 1}' : null,
        tooltip: (_) => '',
        semanticsLabel: 'Sample spending',
      ),
    );
    const due = OverviewCard(
      title: 'Due next',
      child: ListGroup(
        children: [
          AdaptiveRow(
            title: 'Car loan',
            subtitle: 'In 3 days',
            narrowBelow: _rowFits,
            trailing: MoneyAmount('₱4,500.00'),
          ),
          AdaptiveRow(
            title: 'Card statement',
            subtitle: 'In 5 days',
            narrowBelow: _rowFits,
            trailing: MoneyAmount('₱2,180.25'),
          ),
        ],
      ),
    );
    const shared = OverviewCard(
      title: 'Shared Expenses',
      child: ListGroup(
        children: [
          AdaptiveRow(
            title: 'Household',
            subtitle: 'You owe Tala',
            narrowBelow: _rowFits,
            trailing: MoneyAmount('₱640.00'),
          ),
          AdaptiveRow(
            title: 'Boracay trip',
            subtitle: 'Nico owes you',
            narrowBelow: _rowFits,
            trailing: MoneyAmount('₱1,635.00', kind: MoneyKind.owedToYou),
          ),
        ],
      ),
    );
    final tiles = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: available),
        SizedBox(width: gap),
        Expanded(child: spent),
      ],
    );
    const pill = Align(
      alignment: AlignmentDirectional.centerStart,
      child: StatusPill('Sample', icon: Icons.visibility_outlined),
    );
    return Semantics(
      container: true,
      label: 'A sample of Salapiya, with made-up figures.',
      excludeSemantics: true,
      child: IgnorePointer(
        child: ExcludeFocus(
          child: DecoratedBox(
            key: const ValueKey('greeting-preview'),
            decoration: BoxDecoration(
              color: c.selection,
              borderRadius: BorderRadius.circular(Radii.overlayOf(context)),
            ),
            child: Padding(
              padding: EdgeInsets.all(Space.cardPaddingOf(context)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  pill,
                  SizedBox(height: gap),
                  tiles,
                  SizedBox(height: gap),
                  chart,
                  SizedBox(height: gap),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: due),
                      SizedBox(width: Space.md),
                      Expanded(child: shared),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
