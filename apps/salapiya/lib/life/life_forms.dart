import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../app/demo_routes.dart';
import '../app/overview_cards.dart' show civilLabel;
import '../app/overview_dashboard.dart' show overviewLongDate;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../design_system/kit/review.dart' show FormExitGuard;
import '../finance/form_mechanics.dart';
import '../local/finance_domain.dart' show newLocalId;
import '../prototype/scenarios.dart';
import 'life_cards.dart' show lifeClock;
import 'life_controller.dart' show tzTime;
import 'life_data.dart';
import 'life_domain.dart';
import 'career_forms.dart';
import 'life_hub.dart';
import 'progress_forms.dart';

/// Rules that name no field are matched by their words, first match first, so
/// a refusal lands on its field (§6). `rule_messages_test` holds these to the
/// rules.
const lifeRuleFields = [
  ('Enter a title', 'title'),
  ('between 1900 and 2200', 'date'),
  ('timezone from the list', 'timezone'),
  ('like 14:30', 'time'),
  ('doesn’t happen on this date', 'time'),
  ('happens twice', 'fold'),
  ('Say why', 'reason'),
  ('date finished can’t be', 'completed'),
  ('Enter progress', 'progress'),
  ('Enter a rating', 'rating'),
  ('Enter the company', 'company'),
  ('stage from the list', 'stage'),
  ('no date applied', 'date'),
  ('stage date can’t be', 'stageDate'),
  ('work arrangement from', 'arrangement'),
  ('Choose a currency', 'currency'),
  ('Enter the salary', 'salaryMin'),
  ('lowest salary', 'salaryMax'),
  ('posting’s web address', 'postingUrl'),
  ('type from the list', 'kind'),
  ('need a time', 'time'),
  ('already happened', 'kind'),
  ('separate application', 'duplicateConsent'),
];

String? lifeRuleField(String message) {
  for (final (text, field) in lifeRuleFields) {
    if (message.contains(text)) return field;
  }
  return null;
}

/// Every timezone the rules know, with Manila first, by plain name.
List<(String, String)> timezoneOptions() {
  LifeTime.initialize();
  final zones = [
    for (final name in tz.timeZoneDatabase.locations.keys)
      if (name.contains('/') && !name.startsWith('Etc/')) name,
  ]..sort((a, b) => zoneName(a).compareTo(zoneName(b)));
  String label(String name) => '${zoneName(name)} · $name';
  return [
    ('Asia/Manila', label('Asia/Manila')),
    for (final name in zones)
      if (name != 'Asia/Manila') (name, label(name)),
  ];
}

const lostSaveTitle = 'We couldn’t tell if this saved';
const lostSaveMessage =
    'What you entered is kept. Check again: it won’t be added twice.';

/// The steps Life's forms share: details, review, save. Each form has one
/// command id. Values freeze once a save's answer is lost, and "Check again"
/// sends the same command, which the store recognizes; it's never a second one.
mixin LifeFormSteps<T extends StatefulWidget> on State<T>, FormInputs<T> {
  LifeWriter get writer;
  String get operation;

  /// The record being edited.
  String? get recordId;

  /// Checks the answers. Throws a rule's refusal.
  void check();

  /// Saves the frozen values.
  Future<void> save();

  /// The field a refusal belongs on.
  String? ruleField(String message) => lifeRuleField(message);

  bool loading = true, busy = false, dirty = false, reviewing = false;
  bool saved = false, unknown = false, stale = false, draftFailed = false;
  String? error;
  Future<void> writes = Future.value();

  Map<String, String> meta(String? id, int version) => {
    '__command': newLocalId(),
    '__record': id ?? newLocalId(),
    '__version': '$version',
    '__recordedAt': DateTime.now().toUtc().toIso8601String(),
    '__draft': operation,
  };

  /// Brings back a draft, frozen if its save's answer was lost.
  Future<void> restore() async {
    try {
      final draft = await writer.draft(operation);
      if (draft != null) {
        for (final e in draft.entries) {
          values[e.key] = e.value;
        }
        dirty = true;
        if (draft['__lost'] == 'true') unknown = reviewing = true;
      }
    } catch (_) {
      error = 'Your saved draft could not be read. Go back and try again.';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> keep() {
    final frozen = Map<String, String>.of(values);
    writes = writes
        .catchError((Object _) {})
        .then((_) => writer.saveDraft(operation, frozen['__command']!, frozen))
        .then((_) {
          if (mounted && draftFailed) setState(() => draftFailed = false);
        })
        .catchError((Object _) {
          if (mounted) {
            setState(() {
              draftFailed = true;
              error =
                  'Your draft could not be saved. Check storage before leaving.';
            });
          }
        });
    return writes;
  }

  @override
  void retain() {
    setState(() => dirty = true);
    unawaited(keep());
  }

  /// Moves on from details, or saves what was reviewed.
  Future<void> advance() async {
    String? problem, field;
    setState(() {
      busy = true;
      error = null;
      errorField = errorMessage = null;
      stale = false;
    });
    try {
      await writes;
      final record = writer.record(recordId);
      if (recordId != null && '${record?.version}' != values['__version']) {
        stale = true;
      } else if (!reviewing) {
        check();
        reviewing = true;
      } else {
        await save();
        await writer.discardDraft(operation);
        saved = true;
      }
    } on FormatException catch (e) {
      problem = e.message;
      field = ruleField(problem);
      // Refused: nothing was kept, so the next try is a new command.
      if (reviewing) values['__command'] = newLocalId();
      if (field != null) reviewing = false;
    } catch (_) {
      if (reviewing) {
        unknown = true;
        values['__lost'] = 'true';
        unawaited(keep());
      } else {
        error = 'That didn’t work. What you entered is kept.';
      }
    }
    if (mounted) {
      setState(() {
        busy = false;
        errorField = field;
        errorMessage = problem;
      });
    }
    if (problem != null && mounted) await showProblem(problem, field);
  }

  /// Asks about the same command. It stays frozen until there's an answer.
  Future<void> checkAgain() async {
    setState(() => busy = true);
    try {
      await save();
      await writer.discardDraft(operation);
      saved = true;
      unknown = false;
    } on FormatException catch (e) {
      // An answer at last: it was refused, and nothing was kept.
      errorMessage = e.message;
      errorField = ruleField(e.message);
      unknown = false;
      reviewing = false;
      values
        ..remove('__lost')
        ..['__command'] = newLocalId();
      unawaited(keep());
    } catch (_) {
      // Still no answer: keep waiting.
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> discard() async {
    await writes;
    await writer.discardDraft(operation);
  }

  Widget notices() {
    final gap = SizedBox(height: CompactForm.fieldGap(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          InlineNotice(error!, tone: NoticeTone.error, live: true),
          gap,
        ],
        if (errorMessage != null && !anchors.containsKey(errorField)) ...[
          InlineNotice(errorMessage!, tone: NoticeTone.error, live: true),
          gap,
        ],
        if (stale) ...[
          InlineNotice(
            'This changed while you were working. Check it, then try again. What you entered is kept.',
            title: 'This changed',
            tone: NoticeTone.warning,
            live: true,
            action: AppButton.secondary(
              'Discard draft',
              key: const ValueKey('life-discard-draft'),
              onPressed: () async {
                await discard();
                if (mounted) {
                  dirty = false;
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
          gap,
        ],
        if (unknown) ...[
          const InlineNotice(
            lostSaveMessage,
            title: lostSaveTitle,
            tone: NoticeTone.warning,
            live: true,
          ),
          gap,
        ],
      ],
    );
  }

  Widget stepActions(String reviewLabel) => actions(
    unknown
        ? FilledButton(
            key: const ValueKey('life-check-again'),
            onPressed: busy ? null : checkAgain,
            child: const Text('Check again'),
          )
        : FilledButton(
            key: const ValueKey('life-submit'),
            onPressed: busy || draftFailed ? null : advance,
            child: Text(
              busy
                  ? 'Saving…'
                  : !reviewing
                  ? 'Review'
                  : reviewLabel,
            ),
          ),
    !reviewing || unknown
        ? null
        : TextButton(
            key: const ValueKey('life-edit'),
            onPressed: busy ? null : () => setState(() => reviewing = false),
            child: const Text('Edit'),
          ),
  );

  Widget savedPanel(String title) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InlineNotice(
        writer.savedLine(values['__command']!),
        title: title,
        tone: NoticeTone.success,
        live: true,
      ),
      SizedBox(height: CompactForm.groupGap(context)),
      actions(
        FilledButton(
          key: const ValueKey('life-done'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ),
    ],
  );

  /// The page around a form.
  Widget framed(String title, Widget body) => FormExitGuard(
    dirty: dirty && !saved,
    busy: busy || loading,
    keepDraft: () async {
      await keep();
      if (draftFailed) throw StateError('Draft not saved');
    },
    discardDraft: unknown ? null : discard,
    child: CompactForm(
      child: SectionPage(
        title: title,
        caption: saved
            ? null
            : !reviewing
            ? 'Step 1 of 2 · Details · * Required'
            : 'Step 2 of 2 · Review',
        maxWidth: Space.formMaxWidth,
        child: SurfaceCard(child: body),
      ),
    ),
  );
}

/// The time fields events and Career steps share. A time that doesn't exist
/// errors as it's picked, and one that happens twice asks which.
mixin LifeTimeInputs<T extends StatefulWidget> on FormInputs<T>, LifeFormSteps<T> {
  /// The time to come back to when All day is turned off.
  late String lastTime = values['time']!.isEmpty ? '09:00' : values['time']!;

  bool get allDay => answer('time').isEmpty;

  /// When this date, time and timezone happen: none in a clock-change gap,
  /// two when the clocks go back. Null for an all-day event.
  List<DateTime>? get matches {
    if (allDay || answer('date').isEmpty) return null;
    try {
      return LifeTime.candidates(
        answer('date'),
        answer('time'),
        answer('timezone'),
      );
    } on FormatException {
      return null;
    }
  }

  /// The rules' own words for a time that doesn't exist.
  String? get gap {
    if (matches?.isEmpty != true) return null;
    try {
      LifeTime.instant(answer('date'), answer('time'), answer('timezone'));
    } on FormatException catch (e) {
      return e.message;
    }
    return null;
  }

  /// Which of a repeated time only means something while there are two, and
  /// the user always chooses it: the rules insist.
  void clockChanged() {
    if ((matches?.length ?? 0) < 2) values['fold'] = '';
    retain();
  }

  @override
  void changed(String key, String value) {
    super.changed(key, value);
    if (key == 'date') clockChanged();
  }

  String zoneLine(BuildContext context) {
    final there = matches;
    final display = writer.timezone;
    if (there == null || there.isEmpty || answer('timezone') == display) {
      return '';
    }
    // Until the user chooses, this could be either of two times.
    if (there.length > 1 && answer('fold').isEmpty) return '';
    final at = there[values['fold'] == 'Later' ? there.length - 1 : 0];
    final (date, time) = tzTime(at, display);
    return '${lifeClock(context, time)} on ${civilLabel(date)} in ${zoneName(display)}';
  }

  Widget timeInput() {
    final t = answer('time').split(':');
    final problem = problemFor('time') ?? gap;
    final zone = zoneLine(context);
    return Padding(
      key: anchor('time'),
      padding: gapAbove(),
      child: TimeField(
        key: const ValueKey('life-field-time'),
        label: 'Time',
        required: true,
        value: TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1])),
        helper: zone.isEmpty ? null : 'That’s $zone.',
        errorText: problem,
        onChanged: (v) {
          final text =
              '${'${v.hour}'.padLeft(2, '0')}:${'${v.minute}'.padLeft(2, '0')}';
          lastTime = text;
          values['time'] = text;
          if (errorField == 'time') errorField = errorMessage = null;
          clockChanged();
        },
      ),
    );
  }

  Widget allDayInput() => Padding(
    key: anchor('allDay'),
    padding: gapAbove(),
    child: SwitchRow(
      label: 'All day',
      switchKey: const ValueKey('life-field-allDay'),
      value: allDay,
      onChanged: (on) {
        values['time'] = on ? '' : lastTime;
        clockChanged();
      },
    ),
  );

  Widget timezoneInput() => Padding(
    key: anchor('timezone'),
    padding: gapAbove(),
    child: SearchPickerField(
      key: const ValueKey('life-field-timezone'),
      label: 'Timezone',
      value: values['timezone'],
      helper: 'The time stays as you set it here, wherever you are.',
      searchLabel: 'Search timezones',
      errorText: problemFor('timezone'),
      options: timezoneOptions(),
      onChanged: (v) {
        values['timezone'] = v;
        if (errorField == 'timezone') errorField = errorMessage = null;
        clockChanged();
      },
    ),
  );

  Widget foldInput() => pickInput(
    'fold',
    'Which one?',
    const {'Earlier': 'The earlier one', 'Later': 'The later one'},
    descriptions: const {
      'Earlier': 'Before the clocks change.',
      'Later': 'After the clocks change.',
    },
    required: true,
    helper: 'The clocks change on this date, so this time happens twice.',
    style: PickerStyle.radio,
  );
}

/// Add event, or Edit event with [id]. The same keys and defaults the rules
/// have always had; only the fields changed.
Future<void> openEventForm(
  BuildContext context,
  PrototypeSession session, {
  String? id,
}) => openDemoPage<void>(
  context,
  LifeEventForm(writer: lifeSource(context, session).writer, id: id),
  'life/editor',
  title: id == null ? 'Add event' : 'Edit event',
);

class LifeEventForm extends StatefulWidget {
  const LifeEventForm({super.key, required this.writer, this.id});
  final LifeWriter writer;

  /// The event being edited.
  final String? id;
  @override
  State<LifeEventForm> createState() => _LifeEventFormState();
}

class _LifeEventFormState extends State<LifeEventForm>
    with FormInputs, LifeFormSteps, LifeTimeInputs {
  @override
  String get fieldPrefix => 'life-field-';
  @override
  LifeWriter get writer => widget.writer;
  @override
  String? get recordId => widget.id;
  @override
  String get operation => 'life:${widget.id ?? 'new-event'}';

  PersonalRecord? get record => writer.record(widget.id) as PersonalRecord?;

  @override
  late final Map<String, String> values = () {
    final r = record;
    return <String, String>{
      'title': r?.title ?? '',
      'date': r?.date ?? writer.today,
      'time': r == null ? '09:00' : r.time,
      'timezone': r?.timezone ?? 'Asia/Manila',
      'archived': r?.fields['archived'] ?? 'false',
      'fold': r?.fields['fold'] ?? '',
      'status': r?.status ?? 'Scheduled',
      'location': r?.fields['location'] ?? '',
      'notes': r?.notes ?? '',
      if (r != null) 'reason': '',
      ...meta(r?.id, r?.version ?? 0),
    };
  }();

  @override
  void initState() {
    super.initState();
    unawaited(restore());
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  void check() {
    if (answer('title').isEmpty) lifeReject('Enter a title of at most 200 characters.');
    if (answer('date').isEmpty) {
      lifeReject('Choose a date between 1900 and 2200.');
    }
    if (widget.id != null && answer('reason').isEmpty) {
      lifeReject('Say why you’re changing this, in up to 2,000 characters.');
    }
    writer.eventCommand(Map.unmodifiable(values), old: widget.id);
  }

  @override
  Future<void> save() =>
      writer.saveEvent(Map.unmodifiable(values), old: widget.id);

  Widget details() {
    firstField = true;
    final twice = (matches?.length ?? 0) > 1;
    final inMore = {'timezone', 'location', 'notes'}.contains(errorField);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        notices(),
        textInput('title', 'Title', required: true),
        dateInput('date', 'Date', required: true),
        allDayInput(),
        if (!allDay) timeInput(),
        if (twice) foldInput(),
        FormMoreDetails(
          open: inMore,
          children: [
            timezoneInput(),
            textInput('location', 'Location'),
            textInput('notes', 'Notes', lines: 3),
          ],
        ),
        if (widget.id != null)
          textInput('reason', 'Why you’re changing this', required: true),
        SizedBox(height: CompactForm.groupGap(context)),
        stepActions(widget.id == null ? 'Add event' : 'Save changes'),
      ],
    );
  }

  Widget review() {
    final there = matches;
    final time = allDay ? 'All day' : lifeClock(context, answer('time'));
    final zone = zoneName(answer('timezone'));
    final fold = (there?.length ?? 0) > 1
        ? values['fold'] == 'Later'
              ? ', the later one'
              : ', the earlier one'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        notices(),
        FactRow('Title', answer('title')),
        FactRow('Date', overviewLongDate(answer('date'))),
        FactRow('Time', allDay ? time : '$time in $zone$fold'),
        if (!allDay && zoneLine(context).isNotEmpty)
          FactRow('Your time', zoneLine(context)),
        if (answer('location').isNotEmpty)
          FactRow('Location', answer('location')),
        if (answer('notes').isNotEmpty) FactRow('Notes', answer('notes')),
        if (answer('reason').isNotEmpty)
          FactRow('Why you’re changing this', answer('reason')),
        SizedBox(height: CompactForm.groupGap(context)),
        stepActions(widget.id == null ? 'Add event' : 'Save changes'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.id == null ? 'Add event' : 'Edit event';
    return framed(
      title,
      loading
          ? const Center(child: CircularProgressIndicator())
          : saved
          ? savedPanel('Event saved')
          : reviewing
          ? review()
          : details(),
    );
  }
}

/// Add task, or Edit task with [id]. The same keys and defaults as before;
/// only the fields changed.
Future<void> openTaskForm(
  BuildContext context,
  PrototypeSession session, {
  String? id,
}) => openDemoPage<void>(
  context,
  LifeTaskForm(writer: lifeSource(context, session).writer, id: id),
  'life/editor',
  title: id == null ? 'Add task' : 'Edit task',
);

class LifeTaskForm extends StatefulWidget {
  const LifeTaskForm({super.key, required this.writer, this.id});
  final LifeWriter writer;

  /// The task being edited.
  final String? id;
  @override
  State<LifeTaskForm> createState() => _LifeTaskFormState();
}

class _LifeTaskFormState extends State<LifeTaskForm>
    with FormInputs, LifeFormSteps {
  @override
  String get fieldPrefix => 'life-field-';
  @override
  LifeWriter get writer => widget.writer;
  @override
  String? get recordId => widget.id;
  @override
  String get operation => 'life:${widget.id ?? 'new-task'}';

  TaskRecord? get record => writer.record(widget.id) as TaskRecord?;

  @override
  late final Map<String, String> values = () {
    final r = record;
    return <String, String>{
      'title': r?.title ?? '',
      'detail': r?.fields['detail'] ?? '',
      'due': r?.due ?? '',
      'priority': r?.priority ?? 'Normal',
      'status': r?.status ?? 'Not started',
      'completed': r?.completionDate ?? '',
      'notes': r?.notes ?? '',
      if (r != null) 'reason': '',
      ...meta(r?.id, r?.version ?? 0),
    };
  }();

  @override
  void initState() {
    super.initState();
    unawaited(restore());
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  void check() {
    if (answer('title').isEmpty) {
      lifeReject('Enter a title of at most 200 characters.');
    }
    if (widget.id != null && answer('reason').isEmpty) {
      lifeReject('Say why you’re changing this, in up to 2,000 characters.');
    }
    writer.taskCommand(Map.unmodifiable(values), old: widget.id);
  }

  @override
  Future<void> save() =>
      writer.saveTask(Map.unmodifiable(values), old: widget.id);

  String get saveLabel => widget.id == null ? 'Add task' : 'Save changes';

  Widget details() {
    firstField = true;
    final inMore = {
      'detail',
      'status',
      'completed',
      'notes',
    }.contains(errorField);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        notices(),
        textInput('title', 'Title', required: true),
        dateInput('due', 'Due date'),
        pickInput('priority', 'Priority', const {
          'High': 'High',
          'Normal': 'Normal',
          'Low': 'Low',
        }, required: true),
        FormMoreDetails(
          open: inMore,
          children: [
            textInput('detail', 'Details'),
            pickInput('status', 'Status', {
              for (final s in lifeStatuses) s: s,
            }, required: true, onChanged: (_) => setState(() {})),
            if (answer('status') == 'Completed')
              dateInput(
                'completed',
                'Date finished',
                helper: 'Optional. Your history keeps the day you saved this.',
              ),
            textInput('notes', 'Notes', lines: 3),
          ],
        ),
        if (widget.id != null)
          textInput('reason', 'Why you’re changing this', required: true),
        SizedBox(height: CompactForm.groupGap(context)),
        stepActions(saveLabel),
      ],
    );
  }

  Widget review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      notices(),
      FactRow('Title', answer('title')),
      FactRow(
        'Due date',
        answer('due').isEmpty ? 'None' : overviewLongDate(answer('due')),
      ),
      FactRow('Priority', answer('priority')),
      FactRow('Status', answer('status')),
      if (answer('status') == 'Completed' && answer('completed').isNotEmpty)
        FactRow('Date finished', overviewLongDate(answer('completed'))),
      if (answer('detail').isNotEmpty) FactRow('Details', answer('detail')),
      if (answer('notes').isNotEmpty) FactRow('Notes', answer('notes')),
      if (answer('reason').isNotEmpty)
        FactRow('Why you’re changing this', answer('reason')),
      SizedBox(height: CompactForm.groupGap(context)),
      stepActions(saveLabel),
    ],
  );

  @override
  Widget build(BuildContext context) => framed(
    widget.id == null ? 'Add task' : 'Edit task',
    loading
        ? const Center(child: CircularProgressIndicator())
        : saved
        ? savedPanel('Task saved')
        : reviewing
        ? review()
        : details(),
  );
}

/// What a saved Life draft is, from its operation and what was typed.
({String title, String? form}) lifeDraftKind(
  String operation,
  Map<String, String> values,
) {
  final key = operation.substring('life:'.length);
  return switch (key) {
    'new-task' => (title: 'Add task', form: 'task'),
    'new-event' => (title: 'Add event', form: 'event'),
    'new-learning' => (title: 'Add a learning goal', form: 'learning'),
    'new-book' => (title: 'Add a book', form: 'book'),
    'new-career' => (title: 'Add an application', form: 'application'),
    'reminder-timing' => (title: 'Reminder timing', form: null),
    'calendar-timezone' => (title: 'Calendar timezone', form: null),
    _ when key.startsWith('review:') => (
      title: 'Check a refused edit',
      form: null,
    ),
    _ when key.startsWith('new-career-event-') => (
      title: 'Add a step',
      form: 'step',
    ),
    _ when key.startsWith('stage:') => (title: 'Change stage', form: 'stage'),
    _ when key.startsWith('outcome:') => (
      title: 'Record outcome',
      form: 'outcome',
    ),
    _ when key.startsWith('reopen:') => (
      title: 'Reopen application',
      form: 'reopen',
    ),
    // The old form named its draft after the item, and kept the id inside.
    _ when key.startsWith('progress:') || key.startsWith('Log progress') => (
      title: 'Log progress',
      form: 'progress',
    ),
    _ when values.containsKey('priority') => (
      title: 'Edit task',
      form: 'edit-task',
    ),
    _ when values.containsKey('company') => (
      title: 'Edit application',
      form: 'edit-application',
    ),
    // A step has a timezone too, so this comes before an event.
    _ when values.containsKey('kind') => (
      title: 'Edit step',
      form: 'edit-step',
    ),
    _ when values.containsKey('rating') => (
      title: 'Edit book',
      form: 'edit-entry',
    ),
    _ when values.containsKey('total') => (
      title: 'Edit learning goal',
      form: 'edit-entry',
    ),
    _ when values.containsKey('timezone') => (
      title: 'Edit event',
      form: 'edit-event',
    ),
    _ => (title: 'Finish this draft', form: null),
  };
}

String _after(String text, String start) =>
    text.startsWith(start) ? text.substring(start.length) : text;

/// The item a Log progress draft is for, if it's still here.
String? progressDraftRecord(
  LifeWriter writer,
  String key,
  Map<String, String> values,
) {
  final id = key.startsWith('progress:')
      ? key.substring('progress:'.length)
      : values['__record'];
  return writer.record(id) is ProgressRecord ? id : null;
}

/// Opens a saved Life draft's form. False when it can't: its record is gone,
/// or its form opens from its own page.
Future<bool> openLifeDraft(
  BuildContext context,
  PrototypeSession session,
  String operation,
  Map<String, String> values,
) async {
  final kind = lifeDraftKind(operation, values).form;
  final id = operation.substring('life:'.length);
  final writer = lifeSource(context, session).writer;
  switch (kind) {
    case 'task':
      await openTaskForm(context, session);
    case 'event':
      await openEventForm(context, session);
    case 'learning':
      await openEntryForm(context, session, LifeType.learning);
    case 'book':
      await openEntryForm(context, session, LifeType.book);
    case 'application':
      await openApplicationForm(context, session);
    case 'edit-application' when writer.record(id) is ApplicationRecord:
      await openApplicationForm(context, session, id: id);
    case 'edit-step' when writer.record(id) is CareerEventRecord:
      await openStepForm(
        context,
        session,
        (writer.record(id)! as CareerEventRecord).applicationId,
        id: id,
      );
    case 'step' when writer.record(_after(id, 'new-career-event-')) != null:
      await openStepForm(context, session, _after(id, 'new-career-event-'));
    case 'stage' || 'outcome' || 'reopen'
        when writer.record(id.split(':').last) is ApplicationRecord:
      await openStageForm(
        context,
        session,
        id.split(':').last,
        StageChange.values.byName(kind!),
      );
    case 'edit-entry' when writer.record(id) is ProgressRecord:
      await openEntryForm(context, session, writer.record(id)!.type, id: id);
    case 'progress' when progressDraftRecord(writer, id, values) != null:
      await openProgressForm(
        context,
        session,
        progressDraftRecord(writer, id, values)!,
        draft: operation,
      );
    case 'edit-task' when writer.record(id) is TaskRecord:
      await openTaskForm(context, session, id: id);
    case 'edit-event' when writer.record(id) is PersonalRecord:
      await openEventForm(context, session, id: id);
    default:
      return false;
  }
  return true;
}
