import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'shared_bills_tab.dart' show StandingWords;
import 'shared_data.dart';
import 'shared_header.dart';

/// "Which group do you want to open?" The first thing Shared Expenses shows
/// with two or more active groups, unless the user has a default. Each group
/// says where the user stands in it, so this answers that across all of them.
class SharedGroupChooser extends StatelessWidget {
  const SharedGroupChooser({
    super.key,
    required this.source,
    required this.defaultGroup,
    required this.onOpen,
    required this.onAbout,
    required this.onDefault,
    required this.onCreate,
    required this.onJoin,
  });
  final SharedSource source;
  final String? defaultGroup;
  final ValueChanged<String> onOpen;
  final ValueChanged<SharedGroupRow> onAbout;

  /// Makes a group the default, or clears it with null.
  final ValueChanged<String?> onDefault;
  final VoidCallback onCreate, onJoin;

  @override
  Widget build(BuildContext context) {
    final android = !isDesktop(context);
    final rows = sharedGroupRows(source);
    final current = rows.where((r) => r.current).toList();
    final earlier = rows.where((r) => !r.current).toList();
    final cards = [
      for (final r in current)
        _GroupCard(
          key: ValueKey('group-card-${r.group.id}'),
          row: r,
          source: source,
          isDefault: r.group.id == defaultGroup,
          onOpen: () => onOpen(r.group.id),
          onAbout: () => onAbout(r),
          onDefault: () =>
              onDefault(r.group.id == defaultGroup ? null : r.group.id),
        ),
    ];
    final others = earlier.isEmpty
        ? null
        : OverviewCard(
            key: const ValueKey('groups-earlier'),
            title: 'Archived or left',
            caption: 'Their records stay here',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListGroup(
                  children: [
                    for (final r in earlier)
                      AdaptiveRow(
                        key: ValueKey('group-${r.group.id}'),
                        title: r.group.name,
                        subtitle: detailLine([
                          groupRowLine(r, source),
                          groupFacts(r.group),
                        ]),
                        onTap: () => onOpen(r.group.id),
                      ),
                  ],
                ),
                const ListEnd(),
              ],
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardGrid(
          key: const ValueKey('shared-chooser'),
          cards: android
              ? null
              : [
                  for (final c in cards) (c, 4, 6),
                  ?(others == null ? null : (others, 12, 12)),
                ],
          stacked: [...cards, ?others],
        ),
        // Windows has these in the header; phones have no action buttons there.
        if (android) ...[
          SizedBox(height: Space.cardGapOf(context)),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Space.lg,
            children: [
              CardLink(
                'Create a group',
                key: const ValueKey('chooser-create'),
                onPressed: onCreate,
              ),
              CardLink(
                'Join with a code',
                key: const ValueKey('chooser-join'),
                onPressed: onJoin,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    super.key,
    required this.row,
    required this.source,
    required this.isDefault,
    required this.onOpen,
    required this.onAbout,
    required this.onDefault,
  });
  final SharedGroupRow row;
  final SharedSource source;
  final bool isDefault;
  final VoidCallback onOpen, onAbout, onDefault;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final g = row.group, standing = row.standing;
    final hasAmount =
        standing.kind == StandingKind.owedToYou ||
        standing.kind == StandingKind.youOwe;
    return SurfaceCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GroupInitial(g.name),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: text.titleSmall),
                    Text(
                      groupFacts(g),
                      style: text.bodySmall?.copyWith(color: c.secondary),
                    ),
                  ],
                ),
              ),
              CardMenu(
                key: ValueKey('group-menu-${g.id}'),
                tooltip: 'More for ${g.name}',
                items: [
                  MenuItemButton(
                    key: ValueKey('group-default-${g.id}'),
                    leadingIcon: Icon(
                      isDefault ? Icons.star : Icons.star_outline,
                    ),
                    onPressed: onDefault,
                    child: Text(
                      isDefault
                          ? 'Stop opening this first'
                          : 'Make this my default',
                    ),
                  ),
                  MenuItemButton(
                    key: ValueKey('group-about-${g.id}'),
                    leadingIcon: const Icon(Icons.info_outline),
                    onPressed: onAbout,
                    child: const Text('About this group'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          MoneyAmount(
            !source.complete || standing.kind == StandingKind.unknown
                ? null
                : hasAmount
                ? source.amount(standing.amount)
                : standing.kind.label,
            kind: standing.kind == StandingKind.owedToYou
                ? MoneyKind.owedToYou
                : hasAmount
                ? MoneyKind.owed
                : MoneyKind.neutral,
            size: MoneySize.tile,
            textAlign: TextAlign.start,
          ),
          if (hasAmount && source.complete) ...[
            const SizedBox(height: Space.xs),
            StandingWords(standing.kind),
          ],
          if (row.toConfirm > 0 || isDefault) ...[
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.xs,
              children: [
                if (row.toConfirm > 0)
                  StatusPill(
                    '${row.toConfirm} to confirm',
                    icon: Icons.how_to_reg_outlined,
                    tone: PillTone.warning,
                  ),
                if (isDefault)
                  const StatusPill('Default', icon: Icons.star_outline),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
