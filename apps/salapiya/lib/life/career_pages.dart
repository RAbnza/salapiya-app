import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/demo_routes.dart';
import '../app/overview_cards.dart' show civilLabel, duePill;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../features/life/application/life_controller.dart' show AgendaItem;
import '../local/finance_domain.dart' show DebtDueStatus;
import '../prototype/scenarios.dart';
import 'career_documents.dart' show LifeDocumentsCard;
import 'life_cards.dart';
import 'life_data.dart';
import 'life_domain.dart';
import 'life_hub.dart';
import 'life_pages_detail.dart'
    show LifeHistoryCard, LifeWhenCard, ReasonForm, ReasonFormState;

/// A stage's name is long, so a row needs this much room to keep it beside the
/// text. Narrower, the pill goes on the title's line.
const applicationRowBase = Space.xxxl * 9;

/// Where an application stands, as a pill. [short] is for a narrow row, whose
/// title's line can't hold the longest stage's name.
StatusPill applicationPill(ApplicationRow r, {bool short = false}) {
  final words = short && r.standing == 'Technical assessment'
      ? 'Assessment'
      : r.standing;
  return r.archived
      ? const StatusPill('Archived', icon: Icons.archive_outlined)
      : r.outcome == 'Accepted'
      ? StatusPill(words, icon: Icons.task_alt, tone: PillTone.success)
      : r.closed
      ? StatusPill(words, icon: Icons.flag_outlined)
      : StatusPill(
          words,
          icon: Icons.work_outline,
          tone: r.saved ? PillTone.neutral : PillTone.information,
        );
}

/// A row's details in a narrow list. "Next" stays whole where "Follow-up"
/// would break at its hyphen.
List<String> applicationDetails(ApplicationRow r) => [
  r.position,
  if (r.applied.isNotEmpty) 'Applied ${civilLabel(r.applied)}',
  if (r.applied.isEmpty) 'Not sent',
  if (r.next != null) 'Next ${civilLabel(r.next!.date)}',
];

/// Where a step stands, or null when it's simply ahead.
Widget? stepPill(StepRow r) => switch (r.state) {
  CareerStepState.scheduled => null,
  CareerStepState.logged => null,
  CareerStepState.overdue => duePill(DebtDueStatus.overdue),
  CareerStepState.past => const StatusPill('Past', icon: Icons.history),
  CareerStepState.done => const StatusPill(
    'Done',
    icon: Icons.task_alt,
    tone: PillTone.success,
  ),
  CareerStepState.cancelled => const StatusPill(
    'Cancelled',
    icon: Icons.event_busy_outlined,
  ),
};

/// When a step is, in words: its own timezone too, when that's different.
List<String> stepWhen(BuildContext context, StepRow r, String timezone) {
  final other = !r.allDay && r.record.timezone != timezone;
  return [
    civilLabel(r.date),
    if (r.allDay)
      if (!r.observed) 'All day' else ''
    else
      lifeClock(context, r.time),
    if (other)
      '${lifeClock(context, r.record.time)} in ${zoneName(r.record.timezone)}',
  ].where((d) => d.isNotEmpty).toList();
}

/// "Interview · Wed, 4 Nov", for a next step in a table.
String nextLine(LifeRow r) => detailLine([
  r.title.split(' · ').first,
  civilLabel(r.date),
]);

/// An agenda row's page: a step's, or the application's for its follow-up date.
void openCareerItem(
  BuildContext context,
  PrototypeSession session,
  String row,
  String application,
) => row.startsWith('life:')
    ? openCareerStep(context, session, row.substring('life:'.length))
    : openLifeApplication(context, session, application);

/// An application's page, from anywhere.
void openLifeApplication(
  BuildContext context,
  PrototypeSession session,
  String id,
) => openDemoPage<void>(
  context,
  LifeApplicationPage(
    listenable: Listenable.merge([session, lifeHubOf(session)]),
    source: (context) => lifeSource(context, session),
    id: id,
  ),
  'life/career/$id',
);

/// A step's page, from anywhere.
void openCareerStep(
  BuildContext context,
  PrototypeSession session,
  String id,
) => openDemoPage<void>(
  context,
  LifeStepPage(
    listenable: Listenable.merge([session, lifeHubOf(session)]),
    source: (context) => lifeSource(context, session),
    id: id,
  ),
  'life/career-step/$id',
);

/// Runs a page's change, and shows a refusal on the page.
mixin _PageChanges<T extends StatefulWidget> on State<T> {
  String? problem;

  Future<void> run(
    LifeSource source,
    String id,
    int version,
    Map<String, String> fields,
    String reason,
  ) async {
    setState(() => problem = null);
    try {
      await source.writer.change(id, version, fields, reason);
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

  Widget menu(
    String key,
    List<(String, String, IconData, VoidCallback)> items,
  ) => MenuAnchor(
    alignmentOffset: const Offset(0, Space.xs),
    menuChildren: [
      for (final (key, label, icon, go) in items)
        MenuItemButton(
          key: ValueKey(key),
          leadingIcon: Icon(icon),
          onPressed: go,
          child: Text(label),
        ),
    ],
    builder: (context, controller, _) => AppIconButton(
      key: ValueKey(key),
      icon: Icons.more_horiz,
      tooltip: 'More actions',
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}

/// An application: where it stands, what's next, what's happened and what's
/// been kept about it. Contact, notes and salary stay on this page and its
/// forms: no list, notification or shared view has them.
class LifeApplicationPage extends StatefulWidget {
  const LifeApplicationPage({
    super.key,
    required this.listenable,
    required this.source,
    required this.id,
  });
  final Listenable listenable;
  final LifeSource Function(BuildContext context) source;
  final String id;
  @override
  State<LifeApplicationPage> createState() => _LifeApplicationPageState();
}

class _LifeApplicationPageState extends State<LifeApplicationPage>
    with _PageChanges {
  Future<void> archive(LifeSource source, ApplicationRow r) async {
    final yes = await showAppDialog<bool>(
      context,
      title: 'Archive this application?',
      body: const Text(
        'It leaves your applications and calendar, and its reminders stop. Its steps, documents and history stay, and you can restore it.',
      ),
      primary: const ModalAction('Archive application', value: true),
    );
    if (yes == true) {
      await run(source, r.id, r.record.version, {
        'archived': 'true',
      }, 'Archived');
    }
  }

  Widget more(LifeSource source, ApplicationRow r) {
    final a = source.actions;
    return menu('life-application-more', [
      if (r.archived)
        (
          'life-application-restore',
          'Restore application',
          Icons.restore,
          () => run(source, r.id, r.record.version, {
            'archived': 'false',
          }, 'Restored'),
        )
      else ...[
        (
          'life-application-edit',
          'Edit application',
          Icons.edit_outlined,
          () => a.editApplication(r.id),
        ),
        if (r.active)
          (
            'life-application-outcome',
            'Record outcome',
            Icons.flag_outlined,
            () => a.recordOutcome(r.id),
          ),
        if (r.closed)
          (
            'life-application-reopen',
            'Reopen application',
            Icons.undo,
            () => a.reopenApplication(r.id),
          ),
        if (r.active && r.followUp.isNotEmpty)
          (
            'life-application-followed',
            'Mark follow-up done',
            Icons.task_alt,
            () => run(source, r.id, r.record.version, {
              'followUp': '',
            }, 'Follow-up done'),
          ),
        (
          'life-application-archive',
          'Archive application',
          Icons.archive_outlined,
          () => archive(source, r),
        ),
      ],
    ]);
  }

  Widget standingCard(
    BuildContext context,
    LifeSource source,
    ApplicationRow r,
  ) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final next = r.next;
    return OverviewCard(
      key: const ValueKey('life-application-standing'),
      title: 'Where it stands',
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(r.standing, style: text.titleMedium),
          const SizedBox(height: Space.xxs),
          Text(
            'Since ${civilLabel(r.stageDate)}',
            style: text.bodySmall?.copyWith(color: c.secondary),
          ),
          if (r.nextAction.isNotEmpty && r.active) ...[
            const SizedBox(height: Space.sm),
            Text(r.nextAction, style: text.bodyMedium),
          ],
          const SizedBox(height: Space.md),
          StatStrip(
            key: const ValueKey('life-application-stats'),
            stats: [
              (
                label: 'Date applied',
                value: r.applied.isEmpty ? 'Not sent' : civilLabel(r.applied),
                detail: null,
              ),
              (
                label: 'Next step',
                value: next != null
                    ? next.title.split(' · ').first
                    : r.active
                    ? 'None yet'
                    : 'None',
                detail: next == null
                    ? null
                    : detailLine([
                        civilLabel(next.date),
                        if (next.late)
                          '${-next.days} ${next.days == -1 ? 'day' : 'days'} overdue',
                      ]),
              ),
              (
                label: 'Steps',
                value: '${r.steps.length}',
                detail: null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget aboutCard(BuildContext context, LifeSource source, ApplicationRow r) {
    final v = r.record.fields;
    final link = v['postingUrl']!;
    final salary = salaryLine(v, hidden: source.hidden);
    return OverviewCard(
      key: const ValueKey('life-application-about'),
      title: 'About this application',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FactRow('Company', r.company),
          if (v['location']!.isNotEmpty) FactRow('Location', v['location']!),
          if (v['arrangement'] != 'unspecified')
            FactRow(
              'Work arrangement',
              careerArrangements[v['arrangement']] ?? v['arrangement']!,
            ),
          ?salary == null ? null : FactRow('Expected salary', salary),
          if (v['source']!.isNotEmpty) FactRow('Found through', v['source']!),
          if (v['technologies']!.isNotEmpty)
            FactRow('Technologies', v['technologies']!),
          if (v['resume']!.isNotEmpty) FactRow('Resume used', v['resume']!),
          if (v['contact']!.isNotEmpty) FactRow('Contact', v['contact']!),
          if (r.record.notes.isNotEmpty) FactRow('Notes', r.record.notes),
          if (link.isNotEmpty) ...[
            FactRow('Posting link', link),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: CardLink(
                'Copy link',
                key: const ValueKey('life-application-copy'),
                chevron: false,
                onPressed: () => Clipboard.setData(ClipboardData(text: link)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget stepsCard(BuildContext context, LifeSource source, ApplicationRow r) =>
      OverviewCard(
        key: const ValueKey('life-application-steps'),
        title: 'Steps',
        caption: 'What’s ahead, then what’s happened',
        child: r.steps.isEmpty
            ? EmptyState(
                icon: Icons.event_note_outlined,
                title: 'No steps yet',
                message: r.active
                    ? 'Interviews, assessments and follow-ups go here.'
                    : 'Reopen this application to add one.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListGroup(
                    children: [
                      for (final s in r.steps)
                        AdaptiveRow(
                          key: ValueKey('life-step-${s.id}'),
                          title: s.kind,
                          subtitle: detailLine(
                            stepWhen(context, s, source.timezone),
                          ),
                          pill: stepPill(s),
                          onTap: () => source.actions.openStep(s.id),
                        ),
                    ],
                  ),
                  const ListEnd(),
                ],
              ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.listenable,
    builder: (context, _) {
      final source = widget.source(context);
      final r = applicationRows(
        source.records,
        source.today,
        source.timezone,
      ).where((a) => a.id == widget.id).firstOrNull;
      if (r == null) {
        return const SectionPage(
          title: 'Application',
          child: SurfaceCard(
            child: EmptyState(
              icon: Icons.history,
              title: 'This application is no longer here',
              message: 'Go back to Career to see what’s left.',
            ),
          ),
        );
      }
      final a = source.actions;
      final standing = standingCard(context, source, r);
      final about = aboutCard(context, source, r);
      final steps = stepsCard(context, source, r);
      final files = source.documents;
      final documents = files == null
          ? const SizedBox.shrink()
          : LifeDocumentsCard(
              source: source,
              documents: files,
              application: r.id,
              archived: r.archived,
            );
      final description = r.record.fields['description']!;
      final job = description.isEmpty
          ? null
          : OverviewCard(
              key: const ValueKey('life-application-job'),
              title: 'Job description',
              caption: 'As you saved it',
              child: Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
      final item = r.active && r.followUp.isNotEmpty
          ? a.reminderFor(
              AgendaItem(
                'followUp:${r.id}',
                r.id,
                'Career',
                'Follow-up · ${r.company}',
                r.followUp,
                'All day',
                r.record.version,
              ),
            )
          : null;
      final reminder = OverviewCard(
        key: const ValueKey('life-application-reminder'),
        title: 'Follow-up reminder',
        child:
            item ??
            Text(
              r.active
                  ? 'Add a follow-up date to get a reminder.'
                  : 'Closed and archived applications don’t remind you.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
      );
      final history = LifeHistoryCard(
        writer: source.writer,
        id: r.id,
        version: r.record.version,
        hidden: source.hidden,
      );
      return SectionPage(
        title: r.position,
        caption: detailLine([
          r.company,
          r.applied.isEmpty
              ? 'Not sent yet'
              : 'Applied ${civilLabel(r.applied)}',
        ]),
        status: applicationPill(r),
        actions: [
          if (r.active) ...[
            AppButton(
              'Add a step',
              key: const ValueKey('life-application-step'),
              icon: Icons.add,
              onPressed: () => a.addStep(r.id),
            ),
            AppButton.secondary(
              'Change stage',
              key: const ValueKey('life-application-stage'),
              onPressed: () => a.changeStage(r.id),
            ),
          ],
          more(source, r),
        ],
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
                      // About runs long, so two cards stack beside it and
                      // nothing empty sits next to it.
                      (SideStack(top: standing, rest: steps), 8, 12),
                      (about, 4, 12),
                      (documents, 12, 12),
                      if (job != null) (job, 12, 12),
                      (reminder, 12, 12),
                      (history, 12, 12),
                    ]
                  : null,
              stacked: [
                standing,
                steps,
                about,
                documents,
                ?job,
                reminder,
                history,
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// One interview, assessment, follow-up or thing that happened. It offers only
/// what the rules allow: nothing on a closed or archived application, and a
/// step that records what happened stays done.
class LifeStepPage extends StatefulWidget {
  const LifeStepPage({
    super.key,
    required this.listenable,
    required this.source,
    required this.id,
  });
  final Listenable listenable;
  final LifeSource Function(BuildContext context) source;
  final String id;
  @override
  State<LifeStepPage> createState() => _LifeStepPageState();
}

class _LifeStepPageState extends State<LifeStepPage> with _PageChanges {
  Future<void> done(LifeSource source, StepRow r) async {
    final yes = await showAppDialog<bool>(
      context,
      title: 'Mark this step as done?',
      body: const Text(
        'It leaves your calendar and its reminder stops. Its history stays.',
      ),
      primary: const ModalAction('Mark as done', value: true),
    );
    if (yes == true) {
      await run(source, r.id, r.record.version, {
        'status': 'Completed',
      }, 'Completed event');
    }
  }

  /// Cancelling asks why, and keeps the record.
  Future<void> cancel(LifeSource source, StepRow r) async {
    final form = GlobalKey<ReasonFormState>();
    String? reason;
    final yes = await showAppDialog<bool>(
      context,
      title: 'Cancel this step?',
      body: ReasonForm(
        key: form,
        message:
            'It leaves your calendar and its reminder stops. Its history stays, and you can restore it.',
        label: 'Why you’re cancelling',
        missing: 'Say why you’re cancelling.',
        fieldKey: const ValueKey('life-step-cancel-why'),
      ),
      primary: ModalAction(
        'Cancel step',
        value: true,
        destructive: true,
        onPressed: () {
          reason = form.currentState?.answer();
          return reason != null;
        },
      ),
      secondary: const ModalAction.cancel(label: 'Keep step'),
    );
    if (yes == true) {
      await run(source, r.id, r.record.version, {
        'status': 'Cancelled',
      }, reason!);
    }
  }

  Widget more(LifeSource source, StepRow r) => menu('life-step-more', [
    if (r.open) ...[
      (
        'life-step-done',
        'Mark as done',
        Icons.task_alt,
        () => done(source, r),
      ),
      (
        'life-step-cancel',
        'Cancel step',
        Icons.event_busy_outlined,
        () => cancel(source, r),
      ),
    ],
    if (r.state == CareerStepState.done)
      (
        'life-step-reopen',
        'Mark as not done',
        Icons.undo,
        () => run(source, r.id, r.record.version, {
          'status': 'Scheduled',
        }, 'Reopened event'),
      ),
    if (r.state == CareerStepState.cancelled)
      (
        'life-step-restore',
        'Restore step',
        Icons.restore,
        () => run(source, r.id, r.record.version, {
          'status': 'Scheduled',
        }, 'Restored'),
      ),
  ]);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.listenable,
    builder: (context, _) {
      final source = widget.source(context);
      final record = source.records[widget.id];
      if (record is! CareerEventRecord) {
        return const SectionPage(
          title: 'Step',
          child: SurfaceCard(
            child: EmptyState(
              icon: Icons.history,
              title: 'This step is no longer here',
              message: 'Go back to Career to see what’s next.',
            ),
          ),
        );
      }
      final r = StepRow(record, source.today, source.timezone);
      final app = source.records[record.applicationId];
      final a = source.actions;
      final company = app is ApplicationRecord ? app.company : '';
      final locked =
          app is! ApplicationRecord || app.archived || app.terminal;
      final when = LifeWhenCard(
        key: const ValueKey('life-step-when'),
        record: record,
        timezone: source.timezone,
      );
      final about = OverviewCard(
        key: const ValueKey('life-step-about'),
        title: 'About this step',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FactRow('Status', r.state.label),
            if (company.isNotEmpty) FactRow('Company', company),
            if (record.fields['location']!.isNotEmpty)
              FactRow('Location or link', record.fields['location']!),
            if (record.notes.isNotEmpty)
              FactRow(
                r.observed ? 'What happened' : 'Preparation notes',
                record.notes,
              ),
            if (record.fields['outcome']!.isNotEmpty)
              FactRow('How it went', record.fields['outcome']!),
            if (app is ApplicationRecord)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: CardLink(
                  'Open application',
                  key: const ValueKey('life-step-application'),
                  onPressed: () => a.openApplication(app.id),
                ),
              ),
          ],
        ),
      );
      final item = r.open && !locked
          ? a.reminderFor(
              AgendaItem(
                r.id,
                record.applicationId,
                'Career',
                '${r.kind} · $company',
                r.date,
                r.time,
                record.version,
              ),
            )
          : null;
      final reminder = OverviewCard(
        key: const ValueKey('life-step-reminder'),
        title: 'Reminder',
        child:
            item ??
            Text(
              'Only a step still ahead of you, on an open application, reminds you.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
      );
      final history = LifeHistoryCard(
        writer: source.writer,
        id: r.id,
        version: record.version,
      );
      final pill = stepPill(r);
      return SectionPage(
        title: r.kind,
        caption: detailLine([
          if (company.isNotEmpty) company,
          ...stepWhen(context, r, source.timezone).take(2),
        ]),
        status: pill,
        actions: [
          if (!locked) ...[
            AppButton.secondary(
              'Edit step',
              key: const ValueKey('life-step-edit'),
              icon: Icons.edit_outlined,
              onPressed: () => a.editStep(record.applicationId, r.id),
            ),
            if (r.open ||
                const {
                  CareerStepState.done,
                  CareerStepState.cancelled,
                }.contains(r.state))
              more(source, r),
          ],
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (locked) ...[
              const InlineNotice(
                'This application is closed or archived, so its steps can’t change. Reopen or restore it first.',
              ),
              SizedBox(height: Space.cardGapOf(context)),
            ],
            if (problem != null) ...[
              InlineNotice(problem!, tone: NoticeTone.error, live: true),
              SizedBox(height: Space.cardGapOf(context)),
            ],
            DashboardGrid(
              cards: isDesktop(context)
                  ? [
                      (when, 8, 12),
                      (about, 4, 12),
                      (reminder, 12, 12),
                      (history, 12, 12),
                    ]
                  : null,
              stacked: [when, about, reminder, history],
            ),
          ],
        ),
      );
    },
  );
}

/// One screenshot of active applications. Company, role, stage and dates only:
/// no notes, contacts, salary, links or documents.
class LifeApplicationsListPage extends StatelessWidget {
  const LifeApplicationsListPage({
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
      final rows = applicationRows(s.records, s.today, s.timezone);
      final counts = CareerCounts(
        rows,
        nextSteps(careerRows(s.records, s.today, s.timezone)),
      );
      return ShareableList<int>(
        title: 'Applications',
        caption: 'Life',
        heading: 'Where my applications stand',
        asOf: 'As of ${civilLabel(s.today)}',
        empty: counts.active.isEmpty,
        stats: [
          (label: 'Active', value: '${counts.active.length}', detail: null),
          (
            label: 'Interviewing',
            value: '${counts.interviewing}',
            detail: null,
          ),
          (label: 'Closed', value: '${counts.closed.length}', detail: null),
        ],
        child: ListGroup(
          children: [
            for (final r in counts.active)
              AdaptiveRow(
                title: r.company,
                subtitle: detailLine(applicationDetails(r)),
                pill: applicationPill(r, short: !isDesktop(context)),
                narrowBelow: applicationRowBase,
                onTap: () => s.actions.openApplication(r.id),
              ),
          ],
        ),
      );
    },
  );
}
