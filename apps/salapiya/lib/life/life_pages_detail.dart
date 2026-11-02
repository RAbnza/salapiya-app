import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_cards.dart' show civilLabel;
import '../app/overview_dashboard.dart' show overviewLongDate;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../features/life/application/life_controller.dart' show AgendaItem;
import '../prototype/scenarios.dart';
import 'life_cards.dart';
import 'life_data.dart';
import 'life_domain.dart';
import 'life_hub.dart';

/// An event's page, from anywhere.
void openLifeEvent(
  BuildContext context,
  PrototypeSession session,
  String id,
) => openDemoPage<void>(
  context,
  LifeEventPage(
    listenable: session,
    source: (context) => lifeSource(context, session),
    id: id,
  ),
  'life/event',
);

/// What a person sees for a field's stored value.
String lifeFieldValue(BuildContext context, String key, String value) {
  if (value.isEmpty) return 'None';
  return switch (key) {
    'date' ||
    'due' ||
    'completed' ||
    'started' ||
    'stageDate' ||
    'followUp' => civilLabel(value),
    'arrangement' => careerArrangements[value] ?? value,
    'time' => lifeClock(context, value),
    'timezone' => zoneName(value),
    'archived' => value == 'true' ? 'Yes' : 'No',
    _ => value,
  };
}

/// One change in a version, in words. A job description is too long for a
/// line, and salary follows Hide amounts.
String lifeChangeLine(
  BuildContext context,
  String key,
  String before,
  String after, {
  required bool hidden,
}) {
  final name = lifeFieldNames[key];
  if (key == 'description') return '$name changed';
  if (hidden && const {'salaryMin', 'salaryMax'}.contains(key)) {
    return '$name: Amount hidden';
  }
  return '$name: ${lifeFieldValue(context, key, before)} → ${lifeFieldValue(context, key, after)}';
}

/// "2 Nov 2026, 9:14 AM" in Asia/Manila.
String lifeStamp(BuildContext context, String at) {
  final local = DateTime.parse(at).toUtc().add(const Duration(hours: 8));
  final text = local.toIso8601String();
  return '${civilLabel(text.substring(0, 10))}, ${lifeClock(context, text.substring(11, 16))}';
}

/// Every saved version, as what changed and why. Ids stay under View details.
class LifeHistoryCard extends StatefulWidget {
  const LifeHistoryCard({
    super.key,
    required this.writer,
    required this.id,
    required this.version,
    this.hidden = false,
  });
  final LifeWriter writer;
  final String id;

  /// A new version reloads the card.
  final int version;

  /// Hide amounts is on, so expected salary doesn't show.
  final bool hidden;
  @override
  State<LifeHistoryCard> createState() => _LifeHistoryCardState();
}

class _LifeHistoryCardState extends State<LifeHistoryCard> {
  static const page = 25;
  late Future<List<(String, LifeCommand)>> saved = load();
  int shown = page;

  Future<List<(String, LifeCommand)>> load() => widget.writer.history(widget.id);

  @override
  void didUpdateWidget(LifeHistoryCard old) {
    super.didUpdateWidget(old);
    if (old.version != widget.version) saved = load();
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return OverviewCard(
      key: const ValueKey('life-history'),
      title: 'Edit history',
      caption: 'Every version stays',
      child: FutureBuilder(
        future: saved,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.history,
              title: 'Couldn’t load the history',
              message: 'Nothing was lost. Go back and open this again.',
            );
          }
          if (!snapshot.hasData) return LoadingSkeleton.lines(label: 'history');
          final changes = lifeChanges(snapshot.data!);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListGroup(
                children: [
                  for (final change in changes.take(shown))
                    ListRow(
                      key: ValueKey('life-change-${change.id}'),
                      title: lifeReasonText(change.reason),
                      subtitle: detailLine([
                        lifeStamp(context, change.at),
                        for (final (key, before, after) in change.fields)
                          if (change.version > 1)
                            lifeChangeLine(
                              context,
                              key,
                              before,
                              after,
                              hidden: widget.hidden,
                            ),
                      ]),
                    ),
                ],
              ),
              if (changes.length > shown)
                ShowMore(
                  left: changes.length - shown,
                  onPressed: () => setState(() => shown += page),
                )
              else
                const ListEnd(),
              const SizedBox(height: Space.sm),
              ExpansionTile(
                key: const ValueKey('life-history-details'),
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'View details',
                  style: text.labelMedium?.copyWith(color: c.primary),
                ),
                children: [
                  for (final change in changes)
                    FactRow('Version ${change.version}', change.id),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// When something is, in the user's timezone and its own, and whether the
/// clocks change around it.
class LifeWhenCard extends StatelessWidget {
  const LifeWhenCard({super.key, required this.record, required this.timezone});
  final ScheduledRecord record;
  final String timezone;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final r = record;
    final (date, time) = eventWhen(r, timezone);
    final other = r.utc != null && r.timezone != timezone;
    final fold =
        r.utc != null &&
        LifeTime.candidates(r.date, r.time, r.timezone).length > 1;
    return OverviewCard(
      title: 'When',
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(overviewLongDate(date), style: text.titleMedium),
          const SizedBox(height: Space.xxs),
          Text(
            r.utc == null
                ? 'All day'
                : '${lifeClock(context, time)} · ${zoneName(timezone)}',
            style: text.bodyMedium,
          ),
          if (other) ...[
            const SizedBox(height: Space.xxs),
            Text(
              '${overviewLongDate(r.date)}, ${lifeClock(context, r.time)} in ${zoneName(r.timezone)}',
              style: text.bodySmall?.copyWith(color: c.secondary),
            ),
          ],
          if (fold) ...[
            const SizedBox(height: Space.xxs),
            Text(
              'This time happens twice on this date, because the clocks change. This is the ${r.fields['fold'] == 'Later' ? 'later' : 'earlier'} one.',
              style: text.bodySmall?.copyWith(color: c.secondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// An event: when it is, in the user's timezone and its own, what it's for
/// and what's been done to it. Its page offers only what applies now.
class LifeEventPage extends StatefulWidget {
  const LifeEventPage({
    super.key,
    required this.listenable,
    required this.source,
    required this.id,
  });
  final Listenable listenable;
  final LifeSource Function(BuildContext context) source;
  final String id;
  @override
  State<LifeEventPage> createState() => _LifeEventPageState();
}

class _LifeEventPageState extends State<LifeEventPage> {
  String? problem;

  Future<void> change(
    LifeSource source,
    PersonalRecord r,
    Map<String, String> fields,
    String reason,
  ) async {
    setState(() => problem = null);
    try {
      await source.writer.change(r.id, r.version, fields, reason);
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

  Future<void> confirm(
    LifeSource source,
    PersonalRecord r, {
    required String title,
    required String body,
    required String label,
    required Map<String, String> fields,
    required String reason,
  }) async {
    final yes = await showAppDialog<bool>(
      context,
      title: title,
      body: Text(body),
      primary: ModalAction(label, value: true),
    );
    if (yes == true) await change(source, r, fields, reason);
  }

  /// Cancelling asks why, as it always has, and keeps the record.
  Future<void> cancel(LifeSource source, PersonalRecord r) async {
    final form = GlobalKey<ReasonFormState>();
    String? reason;
    final yes = await showAppDialog<bool>(
      context,
      title: 'Cancel this event?',
      body: ReasonForm(
        key: form,
        message:
            'It leaves your calendar and its reminder stops. Its history stays, and you can restore it.',
        label: 'Why you’re cancelling',
        missing: 'Say why you’re cancelling.',
        fieldKey: const ValueKey('life-cancel-why'),
      ),
      primary: ModalAction(
        'Cancel event',
        value: true,
        destructive: true,
        onPressed: () {
          reason = form.currentState?.answer();
          return reason != null;
        },
      ),
      secondary: const ModalAction.cancel(label: 'Keep event'),
    );
    if (yes == true) await change(source, r, {'status': 'Cancelled'}, reason!);
  }

  Widget more(LifeSource source, PersonalRecord r, EventState state) {
    final items = <(String, String, IconData, VoidCallback)>[
      if (state == EventState.scheduled || state == EventState.past) ...[
        (
          'life-event-done',
          'Mark as done',
          Icons.task_alt,
          () => confirm(
            source,
            r,
            title: 'Mark this event as done?',
            body:
                'It leaves your calendar and its reminder stops. Its history stays.',
            label: 'Mark as done',
            fields: {'status': 'Completed'},
            reason: 'Completed event',
          ),
        ),
        (
          'life-event-cancel',
          'Cancel event',
          Icons.event_busy_outlined,
          () => cancel(source, r),
        ),
      ],
      if (state == EventState.completed)
        (
          'life-event-reopen',
          'Mark as not done',
          Icons.undo,
          () => change(source, r, {'status': 'Scheduled'}, 'Reopened event'),
        ),
      if (state == EventState.cancelled)
        (
          'life-event-restore',
          'Restore event',
          Icons.restore,
          () => change(source, r, {'status': 'Scheduled'}, 'Restored'),
        ),
      if (state == EventState.archived)
        (
          'life-event-unarchive',
          'Restore event',
          Icons.restore,
          () => change(source, r, {'archived': 'false'}, 'Restored'),
        )
      else
        (
          'life-event-archive',
          'Archive event',
          Icons.archive_outlined,
          () => confirm(
            source,
            r,
            title: 'Archive this event?',
            body:
                'It leaves your calendar and its reminder stops. Its history stays, and you can restore it.',
            label: 'Archive event',
            fields: {'archived': 'true'},
            reason: 'Archived',
          ),
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
        key: const ValueKey('life-event-more'),
        icon: Icons.more_horiz,
        tooltip: 'More actions',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }


  Widget aboutCard(BuildContext context, PersonalRecord r, EventState state) =>
      OverviewCard(
        key: const ValueKey('life-event-about'),
        title: 'About this event',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FactRow('Status', state.label),
            if (r.fields['location']!.isNotEmpty)
              FactRow('Location', r.fields['location']!),
            FactRow(
              'Timezone',
              r.utc == null ? 'None, it’s all day' : zoneName(r.timezone),
            ),
            if (r.notes.isNotEmpty) FactRow('Notes', r.notes),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.listenable,
    builder: (context, _) {
      final source = widget.source(context);
      final r = source.records[widget.id];
      if (r is! PersonalRecord) {
        return const SectionPage(
          title: 'Event',
          child: SurfaceCard(
            child: EmptyState(
              icon: Icons.history,
              title: 'This event is no longer here',
              message: 'Go back to the Calendar to see what’s coming up.',
            ),
          ),
        );
      }
      final android = !isDesktop(context);
      final (date, time) = eventWhen(r, source.timezone);
      final state = eventState(r, source.today, date);
      final when = LifeWhenCard(
        key: const ValueKey('life-event-when'),
        record: r,
        timezone: source.timezone,
      );
      final about = aboutCard(context, r, state);
      final reminder = r.active
          ? OverviewCard(
              key: const ValueKey('life-event-reminder'),
              title: 'Reminder',
              child: source.actions.reminderFor(
                AgendaItem(
                  r.id,
                  r.id,
                  'Personal',
                  r.title,
                  date,
                  time,
                  r.version,
                ),
              ),
            )
          : null;
      final history = LifeHistoryCard(
        writer: source.writer,
        id: r.id,
        version: r.version,
      );
      return SectionPage(
        title: r.title,
        caption: detailLine([
          'Event',
          civilLabel(date),
          if (r.utc == null) 'All day' else lifeClock(context, time),
        ]),
        status: state == EventState.scheduled
            ? null
            : StatusPill(state.label, icon: _stateIcon(state)),
        actions: [
          if (state != EventState.archived)
            AppButton.secondary(
              'Edit event',
              key: const ValueKey('life-event-edit'),
              icon: Icons.edit_outlined,
              onPressed: () => source.actions.editEvent(r.id),
            ),
          more(source, r, state),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (problem != null) ...[
              InlineNotice(problem!, tone: NoticeTone.error, live: true),
              SizedBox(height: Space.cardGapOf(context)),
            ],
            DashboardGrid(
              cards: android
                  ? null
                  : [
                      (when, 8, 12),
                      (about, 4, 12),
                      if (reminder != null) (reminder, 12, 12),
                      (history, 12, 12),
                    ],
              stacked: [when, about, ?reminder, history],
            ),
          ],
        ),
      );
    },
  );
}

/// What a modal says, and the reason it needs.
class ReasonForm extends StatefulWidget {
  const ReasonForm({
    super.key,
    required this.message,
    required this.label,
    required this.missing,
    required this.fieldKey,
  });
  final String message, label, missing;
  final Key fieldKey;
  @override
  State<ReasonForm> createState() => ReasonFormState();
}

class ReasonFormState extends State<ReasonForm> {
  final why = TextEditingController();
  String? error;

  /// The reason, or null after asking for one.
  String? answer() {
    final text = why.text.trim();
    if (text.isNotEmpty) return text;
    setState(() => error = widget.missing);
    return null;
  }

  @override
  void dispose() {
    why.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CompactForm(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.message),
        SizedBox(height: CompactForm.groupGap(context)),
        HelpTextField(
          key: widget.fieldKey,
          label: widget.label,
          controller: why,
          required: true,
          errorText: error,
          onChanged: (_) => setState(() => error = null),
        ),
      ],
    ),
  );
}

IconData _stateIcon(EventState state) => switch (state) {
  EventState.past => Icons.history,
  EventState.completed => Icons.task_alt,
  EventState.cancelled => Icons.event_busy_outlined,
  EventState.archived => Icons.archive_outlined,
  EventState.scheduled => Icons.event_outlined,
};

/// Events that left the Calendar: finished, cancelled or archived.
class LifeRetiredPage extends StatelessWidget {
  const LifeRetiredPage({
    super.key,
    required this.listenable,
    required this.source,
  });
  final Listenable listenable;
  final LifeSource Function(BuildContext context) source;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: listenable,
    builder: (context, _) {
      final s = source(context);
      final events = retiredEvents(s.records);
      return SectionPage(
        title: 'Past and cancelled',
        caption: 'Events that left your calendar. Their history stays.',
        child: SurfaceCard(
          child: events.isEmpty
              ? const EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Nothing here yet',
                  message:
                      'Events you finish, cancel or archive show here.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListGroup(
                      leading: true,
                      children: [
                        for (final r in events)
                          () {
                            final (date, time) = eventWhen(r, s.timezone);
                            final state = eventState(r, s.today, date);
                            return AdaptiveRow(
                              key: ValueKey('life-retired-${r.id}'),
                              leading: _stateIcon(state),
                              title: r.title,
                              subtitle: detailLine([
                                civilLabel(date),
                                if (r.utc == null)
                                  'All day'
                                else
                                  lifeClock(context, time),
                              ]),
                              trailing: StatusPill(
                                state.label,
                                icon: _stateIcon(state),
                              ),
                              onTap: () => s.actions.openEvent(r.id),
                            );
                          }(),
                      ],
                    ),
                    const ListEnd(),
                  ],
                ),
        ),
      );
    },
  );
}
