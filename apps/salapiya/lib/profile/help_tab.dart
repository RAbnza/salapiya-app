import 'package:flutter/material.dart';

import '../app/release_identity.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'help_data.dart';
import 'profile_source.dart';

/// "How do I find the answer to what I'm stuck on?" Every question is on the
/// page, so search works offline and sends nothing anywhere.
class HelpTab extends StatefulWidget {
  const HelpTab({super.key, required this.source});
  final ProfileSource source;
  @override
  State<HelpTab> createState() => _HelpTabState();
}

class _HelpTabState extends State<HelpTab> {
  final search = TextEditingController();
  final open = <HelpEntry>{};
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Widget topicCard(HelpTopic topic, List<HelpEntry> entries) => OverviewCard(
    key: ValueKey('help-${topic.title}'),
    title: topic.title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListGroup(
          children: [
            for (final entry in entries)
              _Question(
                entry: entry,
                open: open.contains(entry),
                onToggle: () => setState(() {
                  if (!open.remove(entry)) open.add(entry);
                }),
                onLink: widget.source.goTo,
              ),
          ],
        ),
        const ListEnd(),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final words = search.text.trim();
    final cards = [
      for (final topic in helpTopics)
        if (topic.entries.where((e) => e.matches(words)).toList()
            case final entries when entries.isNotEmpty)
          topicCard(topic, entries),
    ];
    final about = OverviewCard(
      key: const ValueKey('help-about'),
      title: 'About Salapiya',
      trailing: CardLink(
        'Licenses',
        key: const ValueKey('help-licenses'),
        onPressed: () => showLicensePage(
          context: context,
          applicationName: 'Salapiya',
          applicationVersion: salapiyaReleaseVersion,
        ),
      ),
      child: const FactRow('Version', salapiyaReleaseVersion),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CompactForm(
          child: HelpTextField(
            key: const ValueKey('help-search'),
            label: 'Search help',
            hintText: 'Try “backup” or “card”',
            controller: search,
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(height: Space.cardGapOf(context)),
        if (cards.isEmpty) ...[
          const OverviewCard(
            title: 'Search help',
            child: EmptyState(
              icon: Icons.search_off_outlined,
              title: 'Nothing matches that',
              message: 'Try fewer or different words.',
            ),
          ),
          SizedBox(height: Space.cardGapOf(context)),
        ] else ...[
          DashboardGrid(
            cards: isDesktop(context)
                ? [for (final c in cards) (c, 6, 12)]
                : null,
            stacked: cards,
          ),
          SizedBox(height: Space.cardGapOf(context)),
        ],
        about,
      ],
    );
  }
}

/// A question that opens in place. Its link, if it has one, goes to the screen
/// the answer is about.
class _Question extends StatelessWidget {
  const _Question({
    required this.entry,
    required this.open,
    required this.onToggle,
    required this.onLink,
  });
  final HelpEntry entry;
  final bool open;
  final VoidCallback onToggle;
  final ProfileGoTo? onLink;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final link = entry.link;
    final go = onLink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          onTap: onToggle,
          button: true,
          expanded: open,
          label: entry.question,
          excludeSemantics: true,
          child: Pressable(
            onTap: onToggle,
            padding: const EdgeInsets.symmetric(
              horizontal: ListRow.horizontalPadding,
              vertical: Space.sm,
            ),
            child: Row(
              children: [
                Expanded(child: Text(entry.question, style: text.bodyMedium)),
                const SizedBox(width: Space.sm),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  size: ListRow.leadingSize(context),
                  color: c.secondary,
                ),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ListRow.horizontalPadding,
              0,
              ListRow.horizontalPadding,
              Space.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.answer,
                  style: text.bodyMedium?.copyWith(color: c.secondary),
                ),
                if (link != null && go != null)
                  CardLink(
                    link.label,
                    onPressed: () => go(link.destination, link.tab),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
