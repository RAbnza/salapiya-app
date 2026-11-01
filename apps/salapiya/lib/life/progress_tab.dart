import 'package:flutter/material.dart';

import '../app/overview_cards.dart' show civilLabel;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'life_data.dart';
import 'life_domain.dart';
import 'life_hub.dart';
import 'progress_forms.dart' show progressLine;
import 'progress_pages.dart';

/// A one-tap change from a list, with the same command its page sends. A
/// refusal shows above the cards.
Future<void> changeEntry(
  LifeSource source,
  LifeHub hub,
  ProgressRow r,
  Map<String, String> fields,
  String reason,
) async {
  hub.setProblem(null);
  try {
    await source.writer.change(r.id, r.record.version, fields, reason);
    if (source.writer.demo) {
      hub.setProblem('This is the demo, so nothing was saved.');
    }
  } on FormatException catch (e) {
    hub.setProblem(e.message);
  } catch (_) {
    hub.setProblem('That didn’t save. Your records are unchanged.');
  }
}

/// Moves an item from its list to In progress, with no date: starting is a
/// status, and a date is the user's to give.
Future<void> startEntry(LifeSource source, LifeHub hub, ProgressRow r) =>
    changeEntry(source, hub, r, {'status': 'In progress'}, 'Started');

/// An item with no total has nothing to count, so it's finished or not.
Future<void> finishEntry(LifeSource source, LifeHub hub, ProgressRow r) =>
    changeEntry(
      source,
      hub,
      r,
      {'progress': '1', 'status': 'Completed'},
      'Completed',
    );

/// One item in progress: what it is, how far along, and one tap to log more.
class ProgressTile extends StatelessWidget {
  const ProgressTile({
    super.key,
    required this.row,
    required this.words,
    required this.onOpen,
    required this.onLog,
    required this.onFinish,
  });
  final ProgressRow row;
  final ProgressWords words;
  final VoidCallback onOpen, onLog, onFinish;
  @override
  Widget build(BuildContext context) {
    final r = row;
    final c = CraftTheme.of(context);
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: c.secondary,
    );
    final details = progressDetails(r);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveRow(
          key: ValueKey('life-entry-${r.id}'),
          title: r.title,
          subtitle: details.isEmpty ? null : detailLine(details),
          pill: progressPill(r),
          onTap: onOpen,
        ),
        Padding(
          // In line with the row's text, and with its chevron at the end.
          padding: const EdgeInsets.only(
            left: ListRow.horizontalPadding,
            right: ListRow.horizontalPadding,
            bottom: Space.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (r.hasTotal) ...[
                ProgressBar(row: r),
                const SizedBox(height: Space.xs),
              ],
              LayoutBuilder(
                builder: (context, box) {
                  final line = Text(
                    r.hasTotal
                        ? detailLine([
                            progressLine(r, words),
                            '${r.left} left',
                          ])
                        : 'No total',
                    style: muted,
                  );
                  final link = r.hasTotal
                      ? CardLink(
                          'Log progress',
                          key: ValueKey('life-log-${r.id}'),
                          chevron: false,
                          onPressed: onLog,
                        )
                      : CardLink(
                          'Mark as finished',
                          key: ValueKey('life-finish-${r.id}'),
                          chevron: false,
                          onPressed: onFinish,
                        );
                  // Large text can't hold both on one line.
                  return narrowAt(context, box.maxWidth, _lineBase)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            line,
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: link,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: line),
                            const SizedBox(width: Space.sm),
                            link,
                          ],
                        );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Learning: what am I learning, how far along, and what's next? Books: what
/// am I reading, and what's next on my list? The same parts, each with its own
/// figures and words.
const _lineBase = Space.xxxl * 5;

class LifeProgressTab extends StatelessWidget {
  const LifeProgressTab({
    super.key,
    required this.type,
    required this.source,
    required this.hub,
    required this.listenable,
    required this.live,
  });
  final LifeType type;
  final LifeSource source;
  final LifeHub hub;
  final Listenable listenable;
  final LifeSource Function(BuildContext context) live;

  static const _shown = 5;

  ProgressWords get words => ProgressWords.of(type);
  bool get book => type == LifeType.book;

  void openList() => source.actions.openList(
    LifeProgressListPage(listenable: listenable, source: live, type: type),
    book ? 'Reading list' : 'Learning list',
  );

  Widget tile(
    String key,
    String label,
    IconData icon,
    Widget value,
    String? caption, {
    bool accent = false,
    VoidCallback? onTap,
  }) => KpiTile(
    key: ValueKey(key),
    labels: book
        ? const ['Reading', 'On your list', 'Finished']
        : const ['In progress', 'Next date', 'Not started', 'Finished'],
    accent: accent,
    icon: icon,
    label: label,
    value: source.lifeComplete
        ? value
        : const MoneyAmount(
            null,
            size: MoneySize.tile,
            textAlign: TextAlign.start,
          ),
    caption: source.lifeComplete ? caption : null,
    onTap: source.lifeComplete ? onTap : null,
  );

  Widget number(int n) =>
      MoneyAmount('$n', size: MoneySize.tile, textAlign: TextAlign.start);

  /// A hold is worth a word; otherwise the tile says what its figure means.
  String holdLine(ProgressCounts counts, String quiet) =>
      counts.onHold == 0 ? quiet : '${counts.onHold} on hold';

  List<Widget> learningTiles(BuildContext context, ProgressCounts counts) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final next = counts.nextDated;
    final doing = counts.inProgress.length;
    final waiting = counts.notStarted.length;
    return [
      tile(
        'life-progress-doing',
        'In progress',
        Icons.school_outlined,
        number(doing),
        doing == 0 ? 'Nothing right now' : holdLine(counts, 'Being learned now'),
        accent: true,
      ),
      tile(
        'life-progress-next',
        'Next date',
        Icons.upcoming_outlined,
        Text(
          next?.title ?? 'No dates set',
          style: text.titleSmall?.copyWith(
            color: next == null ? c.secondary : c.text,
          ),
        ),
        next == null
            ? null
            : detailLine([
                'Due ${civilLabel(next.due)}',
                if (next.late)
                  '${-next.days!} ${next.days == -1 ? 'day' : 'days'} overdue',
              ]),
        onTap: next == null ? null : () => source.actions.openEntry(next.id),
      ),
      tile(
        'life-progress-waiting',
        'Not started',
        Icons.playlist_add_outlined,
        number(waiting),
        waiting == 0 ? 'Nothing waiting' : 'Ready to begin',
      ),
      tile(
        'life-progress-finished',
        'Finished',
        Icons.task_alt,
        number(counts.finished),
        counts.finished == 0 ? 'None yet' : 'All time',
      ),
    ];
  }

  List<Widget> bookTiles(ProgressCounts counts) {
    final doing = counts.inProgress.length;
    final waiting = counts.notStarted.length;
    final thisYear = counts.finishedIn(source.today.substring(0, 4));
    return [
      tile(
        'life-progress-doing',
        'Reading',
        Icons.auto_stories_outlined,
        number(doing),
        doing == 0 ? 'Nothing open' : holdLine(counts, 'Open right now'),
        accent: true,
      ),
      tile(
        'life-progress-waiting',
        'On your list',
        Icons.playlist_add_outlined,
        number(waiting),
        waiting == 0 ? 'Nothing waiting' : 'Not started yet',
      ),
      tile(
        'life-progress-finished',
        'Finished',
        Icons.task_alt,
        number(counts.finished),
        counts.finished == 0
            ? 'None yet'
            : thisYear == 0
            ? 'All time'
            : '$thisYear this year',
      ),
    ];
  }

  Widget nowCard(ProgressCounts counts) {
    final rows = counts.inProgress;
    final left = rows.length - _shown;
    return OverviewCard(
      key: const ValueKey('life-progress-now'),
      title: book ? 'Reading now' : 'Now learning',
      caption: 'How far along you are',
      child: rows.isEmpty
          ? EmptyState(
              icon: book ? Icons.auto_stories_outlined : Icons.school_outlined,
              title: words.notDoing,
              message: book
                  ? 'Books you start show here, with your place in them.'
                  : 'What you’re learning shows here, with how far along it is.',
              action: AppButton.secondary(
                words.adding,
                onPressed: () => source.actions.addEntry(type),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListGroup(
                  children: [
                    for (final r in rows.take(_shown))
                      ProgressTile(
                        row: r,
                        words: words,
                        onOpen: () => source.actions.openEntry(r.id),
                        onLog: () => source.actions.logProgress(r.id),
                        onFinish: () => finishEntry(source, hub, r),
                      ),
                  ],
                ),
                left > 0
                    ? ListEnd(label: '$left more', onPressed: openList)
                    : const ListEnd(),
              ],
            ),
    );
  }

  Widget nextRow(ProgressRow r) => AdaptiveRow(
    key: ValueKey('life-next-${r.id}'),
    title: r.title,
    subtitle: detailLine([
      if (r.detail.isNotEmpty) r.detail,
      r.due.isEmpty ? 'Not started' : 'Due ${civilLabel(r.due)}',
    ]),
    trailing: r.notStarted
        ? CardLink(
            book ? 'Start reading' : 'Start',
            key: ValueKey('life-start-${r.id}'),
            chevron: false,
            onPressed: () => startEntry(source, hub, r),
          )
        : null,
    pill: r.late ? progressPill(r) : null,
    narrowBelow: _lineBase,
    onTap: () => source.actions.openEntry(r.id),
  );

  Widget nextCard(ProgressCounts counts) {
    final rows = book ? counts.notStarted : counts.next;
    final left = rows.length - _shown;
    return OverviewCard(
      key: const ValueKey('life-progress-up-next'),
      title: book ? 'Up next' : 'What’s next',
      caption: book ? 'On your list, soonest first' : 'By date, then not started',
      child: rows.isEmpty
          ? EmptyState(
              icon: Icons.upcoming_outlined,
              title: 'Nothing lined up',
              message: book
                  ? 'Books you want to read next show here.'
                  : 'Due dates and what you haven’t started show here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListGroup(children: [for (final r in rows.take(_shown)) nextRow(r)]),
                left > 0
                    ? ListEnd(label: '$left more', onPressed: openList)
                    : const ListEnd(),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = progressRows(source.records, type, source.today);
    final counts = ProgressCounts(rows);
    final t = book ? bookTiles(counts) : learningTiles(context, counts);
    final now = nowCard(counts);
    final next = nextCard(counts);
    final list = LifeProgressList(
      key: ValueKey('life-progress-list-${type.name}'),
      type: type,
      source: source,
      hub: hub,
      rows: rows,
      onPage: openList,
    );
    return DashboardGrid(
      key: ValueKey('life-progress-${type.name}'),
      cards: isDesktop(context)
          ? [
              for (final tile in t) (tile, book ? 4 : 3, book ? 4 : 6),
              (now, 7, 12),
              (next, 5, 12),
              (list, 12, 12),
            ]
          : null,
      stacked: [
        KeyedSubtree(child: t.first),
        ...t.skip(1),
        if (book) ...[now, next] else ...[next, now],
        list,
      ],
    );
  }
}

/// Every item, with a filter and search.
class LifeProgressList extends StatefulWidget {
  const LifeProgressList({
    super.key,
    required this.type,
    required this.source,
    required this.hub,
    required this.rows,
    required this.onPage,
  });
  final LifeType type;
  final LifeSource source;
  final LifeHub hub;
  final List<ProgressRow> rows;
  final VoidCallback onPage;
  @override
  State<LifeProgressList> createState() => _LifeProgressListState();
}

class _LifeProgressListState extends State<LifeProgressList> {
  static const page = 25;
  int shown = page;
  late final search = TextEditingController(
    text: widget.hub.progressQuery(widget.type),
  );

  bool get book => widget.type == LifeType.book;
  ProgressWords get words => ProgressWords.of(widget.type);

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  AppTableRow row(BuildContext context, ProgressRow r, ProgressFilter filter) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(
      color: CraftTheme.of(context).secondary,
    );
    final pill = progressPill(r);
    final details = progressDetails(r);
    // One column, so one meaning: the filter names which date it holds.
    final date = filter == ProgressFilter.finished ? r.finishedOn : r.due;
    final when = date == null || date.isEmpty ? '—' : civilLabel(date);
    final open = widget.source.actions.openEntry;
    return AppTableRow(
      id: r.id,
      onTap: () => open(r.id),
      spoken: [
        r.title,
        ...details,
        if (r.hasTotal) progressLine(r, words),
        if (r.rating != null) 'Rated ${r.rating} of 5',
        statusWord(r),
      ].join(', '),
      money: const [],
      narrow: AdaptiveRow(
        key: ValueKey('life-entry-row-${r.id}'),
        title: r.title,
        subtitle: detailLine([
          ...details,
          if (r.hasTotal) progressLine(r, words),
          if (r.rating != null) '${r.rating} of 5',
        ]),
        trailing: pill,
        onTap: () => open(r.id),
      ),
      cells: [
        Text(r.title, style: text.bodyMedium),
        if (book) Text(r.detail.isEmpty ? '—' : r.detail, style: muted),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              r.hasTotal ? '${r.done} of ${r.total}' : 'No total',
              style: muted,
            ),
            if (r.hasTotal) ...[
              const SizedBox(height: Space.xxs),
              SlimBar(fraction: r.done / r.total),
            ],
          ],
        ),
        if (book) Text(r.rating == null ? '—' : '${r.rating} of 5', style: muted),
        Text(when, style: muted),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: pill ?? Text(statusWord(r), style: muted),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hub = widget.hub, source = widget.source, type = widget.type;
    final filter = hub.progressFilter(type);
    final query = hub.progressQuery(type);
    final found = filterProgress(widget.rows, filter, query);
    return OverviewCard(
      title: book ? 'Your books' : 'All learning',
      caption:
          '${found.length} ${found.length == 1 ? words.one : '${words.one}s'}',
      stackBelow: Space.xxxl * 8,
      trailing: MiniSegmented<ProgressFilter>(
        key: ValueKey('life-progress-filter-${type.name}'),
        label: book ? 'Which books' : 'Which learning goals',
        options: [for (final f in ProgressFilter.values) (f, f.label)],
        selected: filter,
        onSelected: (f) {
          shown = page;
          hub.setProgressFilter(type, f);
        },
      ),
      corner: CardMenu(
        key: ValueKey('life-progress-menu-${type.name}'),
        tooltip: book ? 'Book options' : 'Learning options',
        items: [
          MenuItemButton(
            key: ValueKey('life-progress-open-list-${type.name}'),
            leadingIcon: const Icon(Icons.open_in_full),
            onPressed: widget.onPage,
            child: const Text('Open as a page'),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.notifications_none),
            onPressed: source.actions.reminders,
            child: const Text('Reminders'),
          ),
          if (source.actions.preferences != null)
            MenuItemButton(
              leadingIcon: const Icon(Icons.settings_outlined),
              onPressed: source.actions.preferences,
              child: const Text('Preferences & help'),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: ValueKey('life-progress-search-${type.name}'),
            controller: search,
            decoration: InputDecoration(
              hintText: book ? 'Search books' : 'Search learning',
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (v) {
              shown = page;
              hub.setProgressQuery(type, v);
            },
          ),
          const SizedBox(height: Space.md),
          if (found.isEmpty)
            EmptyState(
              icon: book ? Icons.auto_stories_outlined : Icons.school_outlined,
              title: query.trim().isNotEmpty
                  ? 'Nothing matches that'
                  : switch (filter) {
                      ProgressFilter.finished => 'Nothing finished yet',
                      ProgressFilter.archived => 'Nothing archived',
                      _ => book ? 'No books yet' : 'No learning goals yet',
                    },
              message: query.trim().isNotEmpty
                  ? 'Try other words, or another filter.'
                  : book
                  ? 'Books you add show here.'
                  : 'Learning goals you add show here.',
            )
          else ...[
            AppTable(
              columns: [
                (label: book ? 'Book' : 'Item', flex: 4, width: null),
                if (book) (label: 'Author', flex: 3, width: null),
                (label: 'Progress', flex: 2, width: null),
                if (book) (label: 'Rating', flex: 2, width: null),
                (
                  label: filter == ProgressFilter.finished ? 'Finished' : 'Due',
                  flex: 2,
                  width: null,
                ),
                (label: 'Status', flex: 2, width: null),
              ],
              dense: true,
              rows: [
                for (final r in found.take(shown)) row(context, r, filter),
              ],
            ),
            if (found.length > shown)
              ShowMore(
                left: found.length - shown,
                onPressed: () => setState(() => shown += page),
              )
            else
              const ListEnd(),
          ],
        ],
      ),
    );
  }
}
