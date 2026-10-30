import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';

/// One account: its name and type, balance and a 30-day sparkline.
class AccountMiniCard extends StatelessWidget with PairCard {
  const AccountMiniCard({
    super.key,
    required this.icon,
    required this.name,
    required this.kind,
    required this.balance,
    required this.onTap,
    this.spark = const [],
    this.caption,
  });
  final IconData icon;
  final String name, kind;
  final String? balance;
  final List<BigInt> spark;
  final String? caption;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(icon),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: text.titleSmall),
                    Text(
                      kind,
                      style: text.bodySmall?.copyWith(color: c.secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          MoneyAmount(
            balance,
            size: MoneySize.tile,
            textAlign: TextAlign.start,
          ),
          if (spark.length > 1) ...[
            const SizedBox(height: Space.sm),
            SizedBox(
              height: sparkHeight,
              child: Sparkline(values: spark),
            ),
          ],
          if (caption != null) ...[
            const SizedBox(height: Space.xs),
            Text(caption!, style: text.bodySmall?.copyWith(color: c.secondary)),
          ],
        ],
      ),
    );
  }
}

