import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_cards.dart' show civilLabel, duePill;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../features/life/application/life_controller.dart' show AgendaItem;
import '../local/finance_domain.dart' show DebtDueStatus;
import '../prototype/scenarios.dart';
import 'life_data.dart';
import 'life_domain.dart';
import 'life_hub.dart';
import 'life_pages_detail.dart' show LifeHistoryCard;
import 'progress_forms.dart' show progressLine;

/// A row's details, each whole, so a line breaks between them.
List<String> progressDetails(ProgressRow r, {bool due = true}) => [
  if (r.detail.isNotEmpty) r.detail,
  if (due && r.due.isNotEmpty) 'Due ${civilLabel(r.due)}',
  if (r.late) '${-r.days!} ${r.days == -1 ? 'day' : 'days'} overdue',
];

/// The pill a row needs, or null when nothing's off.
Widget? progressPill(ProgressRow r) => r.archived
    ? const StatusPill('Archived', icon: Icons.archive_outlined)
    : r.finished
    ? const StatusPill('Finished', icon: Icons.task_alt, tone: PillTone.success)
    : r.onHold
    ? const StatusPill('On hold', icon: Icons.pause_circle_outline)
    : r.late
    ? duePill(DebtDueStatus.overdue)
    : r.dueToday
    ? duePill(DebtDueStatus.dueToday)
    : null;

/// What a tile or row says when an item has no parts to count.
String statusWord(ProgressRow r) => r.finished
    ? 'Finished'
    : r.archived
    ? 'Archived'
    : r.status;

/// How far along, in words and as a bar. One step per lesson or page up to
/// the kit's limit, then one bar, so a long book is never drawn as finished.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.row, this.track});
  final ProgressRow row;
  final Color? track;
  @override
  Widget build(BuildContext context) =>
      SegmentBar(done: row.done, total: row.total, track: track);
}

/// A learning item or book's page, from anywhere.
void openLifeEntry(BuildContext context, PrototypeSession session, String id) =>
    openDemoPage<void>(
      context,
      LifeEntryPage(
        listenable: Listenable.merge([session, lifeHubOf(session)]),
        source: (context) => lifeSource(context, session),
        id: id,
      ),
      'life/entry/$id',
    );

/// A learning item or book: how far along, what it is, and what's been done.
/// It offers only what applies now.
class LifeEntryPage extends StatefulWidget {
  const LifeEntryPage({
    super.key,
    required this.listenable,
    required this.source,
    required this.id,
  });
  final Listenable listenable;
  final LifeSource Function(BuildContext context) source;
  final String id;
  @override
  State<LifeEntryPage> createState() => _LifeEntryPageState();
}

class _LifeEntryPageState extends State<LifeEntryPage> {
  String? problem;

  Future<void> change(
    LifeSource source,
    ProgressRow r,
    Map<String, String> fields,
    String reason,
  ) async {
    setState(() => problem = null);
    try {
      await source.writer.change(r.id, r.record.version, fields, reason);
      if (source.writer.demo && mounted) {
        setState(() => problem = 'This is the demo, so nothing was saved.');
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => problem = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => problem = 'That didn’t save. Your records are unchanged.',
        );
      }
    }
  }

  Future<void> archive(
    LifeSource source,
    ProgressRow r,
    ProgressWords words,
  ) async {
    final yes = await showAppDialog<bool>(
      context,
      title: 'Archive this ${words.one}?',
      body: Text(
        'It leaves your lists and calendar, and its reminder stops. Its progress and history stay, and you can restore it.',
      ),
      primary: ModalAction('Archive ${words.one}', value: true),
    );
    if (yes == true) await change(source, r, {'archived': 'true'}, 'Archived');
  }

  Widget more(LifeSource source, ProgressRow r, ProgressWords words) {
    final items = <(String, String, IconData, VoidCallback)>[
      if (!r.archived) ...[
        (
          'life-entry-edit',
          'Edit ${words.one}',
          Icons.edit_outlined,
          () => source.actions.editEntry(r.id),
        ),
        if (r.notStarted || r.onHold)
          (
            'life-entry-start',
            r.onHold ? 'Pick it up again' : 'Start',
            Icons.play_arrow_outlined,
            () => change(source, r, {'status': 'In progress'}, 'Started'),
          ),
        if (r.inProgress)
          (
            'life-entry-hold',
            'Put on hold',
            Icons.pause_circle_outline,
            () => change(source, r, {'status': 'On hold'}, 'Put on hold'),
          ),
        (
          'life-entry-archive',
          'Archive ${words.one}',
          Icons.archive_outlined,
          () => archive(source, r, words),
        ),
      ] else
        (
          'life-entry-restore',
          'Restore ${words.one}',
          Icons.restore,
          () => change(source, r, {'archived': 'false'}, 'Restored'),
        ),
    ];
    return MenuAnchor(
      alignmentOffset: const Offset(0, Space.xs),
      menuChildren: [
        for (final (key, label, icon, run) in items)
          MenuItemButton(
            key: ValueKey(key),
            leadingIcon: Icon(icon),
            onPressed: run,
            child: Text(label),
          ),
      ],
      builder: (context, controller, _) => AppIconButton(
        key: const ValueKey('life-entry-more'),
        icon: Icons.more_horiz,
        tooltip: 'More actions',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  /// The one thing to do now. An item with no total has nothing to count, so
  /// it's simply finished or not.
  Widget? mainAction(LifeSource source, ProgressRow r) {
    if (r.archived) return null;
    if (r.hasTotal) {
      return r.finished
          ? AppButton.secondary(
              'Log progress',
              key: const ValueKey('life-entry-log'),
              icon: Icons.edit_note,
              onPressed: () => source.actions.logProgress(r.id),
            )
          : AppButton(
              'Log progress',
              key: const ValueKey('life-entry-log'),
              icon: Icons.edit_note,
              onPressed: () => source.actions.logProgress(r.id),
            );
    }
    return r.finished
        ? AppButton.secondary(
            'Mark as not finished',
            key: const ValueKey('life-entry-reopen'),
            icon: Icons.undo,
            onPressed: () => change(source, r, {
              'progress': '0',
              'status': 'In progress',
            }, 'Reopened'),
          )
        : AppButton(
            'Mark as finished',
            key: const ValueKey('life-entry-finish'),
            icon: Icons.task_alt,
            onPressed: () => change(source, r, {
              'progress': '1',
              'status': 'Completed',
            }, 'Completed'),
          );
  }

  Widget progressCard(
    BuildContext context,
    ProgressRow r,
    ProgressWords words,
  ) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: c.secondary);
    return OverviewCard(
      key: const ValueKey('life-entry-progress'),
      title: 'Progress',
      accent: true,
      centered: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            r.hasTotal ? progressLine(r, words) : statusWord(r),
            style: text.titleMedium,
          ),
          const SizedBox(height: Space.xs),
          if (r.hasTotal) ...[
            ProgressBar(row: r, track: c.surface),
            const SizedBox(height: Space.xs + Space.xxs),
            Text(
              r.left == 0
                  ? 'All ${r.total} ${words.units} done'
                  : '${r.left} ${r.left == 1 ? words.unit : words.units} left',
              style: muted,
            ),
          ] else
            Text(
              r.finished
                  ? 'This has no total, so there’s nothing to count.'
                  : 'This has no total. Add one to count ${words.units}.',
              style: muted,
            ),
        ],
      ),
    );
  }

  Widget aboutCard(ProgressRow r, ProgressWords words) => OverviewCard(
    key: const ValueKey('life-entry-about'),
    title: 'About this ${words.one}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FactRow('Status', statusWord(r)),
        if (r.detail.isNotEmpty) FactRow(words.detail, r.detail),
        FactRow('Due date', r.due.isEmpty ? 'None' : civilLabel(r.due)),
        if (r.started.isNotEmpty)
          FactRow('Date started', civilLabel(r.started)),
        // A reopened item keeps its old date in its record; it isn't true now.
        if (r.finishedOn != null)
          FactRow('Date finished', civilLabel(r.finishedOn!)),
        if (r.rating != null) FactRow('Rating', '${r.rating} of 5'),
        if (r.record.notes.isNotEmpty) FactRow('Notes', r.record.notes),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.listenable,
    builder: (context, _) {
      final source = widget.source(context);
      final record = source.records[widget.id];
      if (record is! ProgressRecord) {
        return const SectionPage(
          title: 'Item',
          child: SurfaceCard(
            child: EmptyState(
              icon: Icons.history,
              title: 'This item is no longer here',
              message: 'Go back to see what’s left.',
            ),
          ),
        );
      }
      final words = ProgressWords.of(record.type);
      final r = ProgressRow(record, source.today, 0);
      final progress = progressCard(context, r, words);
      final about = aboutCard(r, words);
      final item = r.open && r.due.isNotEmpty
          ? source.actions.reminderFor(
              AgendaItem(
                r.id,
                r.id,
                words.module,
                r.title,
                r.due,
                'All day',
                record.version,
              ),
            )
          : null;
      final reminder = OverviewCard(
        key: const ValueKey('life-entry-reminder'),
        title: 'Reminder',
        child:
            item ??
            Text(
              !r.open
                  ? 'Finished and archived items don’t remind you.'
                  : 'Add a due date to get a reminder.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
      );
      final history = LifeHistoryCard(
        writer: source.writer,
        id: r.id,
        version: record.version,
      );
      final action = mainAction(source, r);
      return SectionPage(
        title: r.title,
        caption: detailLine([
          words.tab == 'Books' ? 'Book' : words.tab,
          if (r.detail.isNotEmpty) r.detail,
          r.due.isEmpty ? 'No due date' : 'Due ${civilLabel(r.due)}',
        ]),
        status: progressPill(r),
        actions: [?action, more(source, r, words)],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (problem != null) ...[
              InlineNotice(problem!, tone: NoticeTone.error, live: true),
              SizedBox(height: Space.cardGapOf(context)),
            ],
            DashboardGrid(
              cards: isDesktop(context)
                  ? [
                      (progress, 8, 12),
                      (about, 4, 12),
                      (reminder, 12, 12),
                      (history, 12, 12),
                    ]
                  : null,
              stacked: [progress, about, reminder, history],
            ),
          ],
        ),
      );
    },
  );
}

/// One screenshot of what's being learned or read and what's next, with no
/// notes, dates of finishing or actions.
class LifeProgressListPage extends StatelessWidget {
  const LifeProgressListPage({
    super.key,
    required this.listenable,
    required this.source,
    required this.type,
  });
  final Listenable listenable;
  final LifeSource Function(BuildContext context) source;
  final LifeType type;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: listenable,
    builder: (context, _) {
      final s = source(context);
      final words = ProgressWords.of(type);
      final counts = ProgressCounts(progressRows(s.records, type, s.today));
      final groups = [
        (words.doing, counts.inProgress),
        (
          type == LifeType.book ? 'On your list' : 'Not started',
          counts.notStarted,
        ),
      ];
      return ShareableList<int>(
        title: type == LifeType.book ? 'Reading list' : 'Learning list',
        caption: 'Life',
        heading: type == LifeType.book
            ? 'What I’m reading'
            : 'What I’m learning',
        asOf: 'As of ${civilLabel(s.today)}',
        empty: counts.inProgress.isEmpty && counts.notStarted.isEmpty,
        stats: [
          (
            label: words.doing,
            value: '${counts.inProgress.length}',
            detail: null,
          ),
          (
            label: groups.last.$1,
            value: '${counts.notStarted.length}',
            detail: null,
          ),
          (label: 'Finished', value: '${counts.finished}', detail: null),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (label, rows) in groups)
              if (rows.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(
                    top: Space.md,
                    bottom: Space.xs,
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                ListGroup(
                  children: [
                    for (final r in rows)
                      AdaptiveRow(
                        title: r.title,
                        subtitle: detailLine([
                          ...progressDetails(r),
                          if (r.hasTotal) progressLine(r, words),
                        ]),
                        trailing: progressPill(r),
                        onTap: () => s.actions.openEntry(r.id),
                      ),
                  ],
                ),
              ],
          ],
        ),
      );
    },
  );
}
