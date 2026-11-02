import 'dart:async';

import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_dashboard.dart' show overviewLongDate;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../finance/form_mechanics.dart';
import '../prototype/scenarios.dart';
import 'life_cards.dart' show lifeClock;
import 'life_data.dart';
import 'life_domain.dart';
import 'life_forms.dart';
import 'life_hub.dart';

/// Stages a form can choose. Accepted comes with its outcome.
final _stages = [
  for (final s in careerPipelineStages)
    if (s != 'Accepted') s,
];

/// The form's values for [r], or a new application's. Every key the command
/// carries is here, shown or not, so editing one thing keeps the rest.
Map<String, String> applicationValues(ApplicationRecord? r, String today) {
  final v = r?.fields ?? lifeDefaults(LifeType.application);
  return {
    'company': v['company'] ?? '',
    'position': r?.position ?? '',
    // An older closed record has no stage to send.
    if (r == null) 'stage': 'Saved',
    if (r != null && careerPipelineStages.contains(r.stage)) 'stage': r.stage,
    'outcome': r?.outcome ?? '',
    'date': v['date'] ?? '',
    'stageDate': r == null ? today : v['stageDate'] ?? today,
    for (final key in const [
      'location',
      'arrangement',
      'postingUrl',
      'source',
      'salaryMin',
      'salaryMax',
      'currency',
      'salaryPeriod',
      'technologies',
      'description',
      'contact',
      'resume',
      'nextAction',
      'followUp',
      'notes',
    ])
      key: v[key] ?? '',
  };
}

/// Add an application, or edit one with [id].
Future<void> openApplicationForm(
  BuildContext context,
  PrototypeSession session, {
  String? id,
}) {
  final source = lifeSource(context, session);
  return openDemoPage<void>(
    context,
    LifeApplicationForm(writer: source.writer, hidden: source.hidden, id: id),
    'life/editor',
    title: id == null ? 'Add an application' : 'Edit application',
  );
}

class LifeApplicationForm extends StatefulWidget {
  const LifeApplicationForm({
    super.key,
    required this.writer,
    this.hidden = false,
    this.id,
  });
  final LifeWriter writer;

  /// Hide amounts is on, so a salary already held doesn't show.
  final bool hidden;

  /// The application being edited.
  final String? id;
  @override
  State<LifeApplicationForm> createState() => _LifeApplicationFormState();
}

class _LifeApplicationFormState extends State<LifeApplicationForm>
    with FormInputs, LifeFormSteps {
  @override
  String get fieldPrefix => 'life-field-';
  @override
  LifeWriter get writer => widget.writer;
  @override
  String? get recordId => widget.id;
  @override
  String get operation => 'life:${widget.id ?? 'new-career'}';

  ApplicationRecord? get record =>
      writer.record(widget.id) as ApplicationRecord?;

  @override
  late final Map<String, String> values = {
    ...applicationValues(record, writer.today),
    if (widget.id == null) 'duplicateConsent': 'false',
    if (widget.id != null) 'reason': '',
    ...meta(record?.id, record?.version ?? 0),
  };

  /// A salary already here, which Hide amounts keeps off the screen. Checked
  /// once, or the field would lock under someone's fingers as they type.
  bool lockedSalary = false;
  bool get hasSalary =>
      answer('salaryMin').isNotEmpty || answer('salaryMax').isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(
      restore().then((_) {
        if (mounted) setState(() => lockedSalary = widget.hidden && hasSalary);
      }),
    );
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  String get stage => values['stage'] ?? '';
  bool get adding => widget.id == null;
  bool get notSent => stage == 'Saved';

  /// A form with no stage field fills in what follows from its answers.
  Map<String, String> get command => Map.unmodifiable({
    ...values,
    'company': answer('company'),
    'currency': answer('currency').toUpperCase(),
    if (notSent) 'date': '',
    if (adding && notSent) 'stageDate': writer.today,
    if (adding && stage == 'Applied') 'stageDate': answer('date'),
  });

  bool get duplicate => adding && writer.duplicateApplication(values);

  @override
  String? ruleField(String message) {
    final field = lifeRuleField(message);
    return field == 'title' ? 'position' : field;
  }

  @override
  void check() {
    if (answer('company').isEmpty) {
      lifeReject('Enter the company, in up to 200 characters.');
    }
    if (answer('position').isEmpty) {
      lifeReject('Enter a title of at most 200 characters.');
    }
    if (!notSent && answer('date').isEmpty) {
      lifeReject('Choose a date between 1900 and 2200.');
    }
    if (!adding && answer('reason').isEmpty) {
      lifeReject('Say why you’re changing this, in up to 2,000 characters.');
    }
    writer.applicationCommand(command, old: widget.id);
  }

  @override
  Future<void> save() => writer.saveApplication(command, old: widget.id);

  String get saveLabel => adding ? 'Add application' : 'Save changes';

  Widget duplicateInput() => Padding(
    key: anchor('duplicateConsent'),
    padding: gapAbove(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InlineNotice(
          'You already have this company and role. Applying again is fine: it’s kept as a separate application.',
          tone: NoticeTone.warning,
        ),
        SizedBox(height: CompactForm.fieldGap(context)),
        SwitchRow(
          label: 'This is a separate application',
          switchKey: const ValueKey('life-field-duplicateConsent'),
          value: values['duplicateConsent'] == 'true',
          onChanged: (on) => changed('duplicateConsent', '$on'),
        ),
      ],
    ),
  );

  /// Salary follows Hide amounts: the values stay in the command.
  List<Widget> salaryInputs() {
    if (lockedSalary) {
      return [
        Padding(
          key: anchor('salaryMin'),
          padding: gapAbove(),
          child: const FactRow(
            'Expected salary',
            'Amount hidden. Turn off Hide amounts to change this.',
          ),
        ),
      ];
    }
    return [
      textInput(
        'salaryMin',
        'Lowest expected salary',
        input: FieldInput.amount,
      ),
      textInput(
        'salaryMax',
        'Highest expected salary',
        input: FieldInput.amount,
      ),
      if (hasSalary) ...[
        textInput(
          'currency',
          'Currency',
          helper: 'Three letters, like PHP.',
        ),
        pickInput('salaryPeriod', 'Paid per', const {
          'hour': 'Hour',
          'month': 'Month',
          'year': 'Year',
        }, required: true),
      ],
    ];
  }

  Widget details() {
    firstField = true;
    final inMore = {
      'location',
      'arrangement',
      'postingUrl',
      'source',
      'salaryMin',
      'salaryMax',
      'currency',
      'salaryPeriod',
      'technologies',
      'description',
      'contact',
      'resume',
      'notes',
    }.contains(errorField);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        notices(),
        textInput('company', 'Company', required: true),
        textInput('position', 'Position', required: true),
        if (duplicate) duplicateInput(),
        if (adding)
          pickInput('stage', 'Stage', {
            for (final s in _stages) s: s,
          }, required: true),
        if (!notSent) dateInput('date', 'Date applied', required: true),
        if (adding && !notSent && stage != 'Applied')
          dateInput('stageDate', 'In this stage since', required: true),
        textInput(
          'nextAction',
          'Next step',
          helper: 'What you’ll do next, in your own words.',
        ),
        dateInput(
          'followUp',
          'Follow up on',
          helper: 'It goes on your calendar, with a reminder.',
        ),
        FormMoreDetails(
          open: inMore,
          children: [
            textInput('location', 'Location'),
            pickInput('arrangement', 'Work arrangement', careerArrangements),
            textInput('postingUrl', 'Posting link'),
            textInput('source', 'Found through'),
            ...salaryInputs(),
            textInput('technologies', 'Technologies'),
            textInput(
              'description',
              'Job description',
              lines: 4,
              helper: 'Postings disappear, so keep what matters.',
            ),
            textInput('contact', 'Contact', lines: 2),
            textInput(
              'resume',
              'Resume used',
              helper: 'The version you sent, so you can find it again.',
            ),
            textInput('notes', 'Notes', lines: 3),
          ],
        ),
        if (!adding)
          textInput('reason', 'Why you’re changing this', required: true),
        SizedBox(height: CompactForm.groupGap(context)),
        stepActions(saveLabel),
      ],
    );
  }

  Widget review() {
    final salary = salaryLine(command, hidden: widget.hidden);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        notices(),
        FactRow('Company', answer('company')),
        FactRow('Position', answer('position')),
        if (stage.isNotEmpty) FactRow('Stage', stage),
        if (!notSent && answer('date').isNotEmpty)
          FactRow('Date applied', overviewLongDate(answer('date'))),
        if (adding && !notSent && stage != 'Applied')
          FactRow('In this stage since', overviewLongDate(answer('stageDate'))),
        if (answer('nextAction').isNotEmpty)
          FactRow('Next step', answer('nextAction')),
        if (answer('followUp').isNotEmpty)
          FactRow('Follow up on', overviewLongDate(answer('followUp'))),
        if (answer('location').isNotEmpty)
          FactRow('Location', answer('location')),
        if (answer('arrangement') != 'unspecified')
          FactRow(
            'Work arrangement',
            careerArrangements[answer('arrangement')] ?? answer('arrangement'),
          ),
        if (answer('postingUrl').isNotEmpty)
          FactRow('Posting link', answer('postingUrl')),
        if (answer('source').isNotEmpty)
          FactRow('Found through', answer('source')),
        if (salary != null) FactRow('Expected salary', salary),
        if (answer('technologies').isNotEmpty)
          FactRow('Technologies', answer('technologies')),
        if (answer('contact').isNotEmpty) FactRow('Contact', answer('contact')),
        if (answer('resume').isNotEmpty)
          FactRow('Resume used', answer('resume')),
        if (answer('notes').isNotEmpty) FactRow('Notes', answer('notes')),
        if (answer('reason').isNotEmpty)
          FactRow('Why you’re changing this', answer('reason')),
        SizedBox(height: CompactForm.groupGap(context)),
        stepActions(saveLabel),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => framed(
    adding ? 'Add an application' : 'Edit application',
    loading
        ? const Center(child: CircularProgressIndicator())
        : saved
        ? savedPanel('Application saved')
        : reviewing
        ? review()
        : details(),
  );
}

/// What a stage form is for. The rules treat them as one change; people don't.
enum StageChange {
  stage('Change stage', 'Save stage', 'Stage saved', 'stage'),
  outcome('Record outcome', 'Record outcome', 'Outcome saved', 'outcome'),
  reopen(
    'Reopen application',
    'Reopen application',
    'Application reopened',
    'reopen',
  );

  const StageChange(this.title, this.action, this.done, this.name_);
  final String title, action, done, name_;
}

/// What each outcome means, in the picker.
const _outcomeNotes = {
  'Accepted': 'You took the job. This also sets the stage to Accepted.',
  'Rejected': 'They said no.',
  'Withdrawn': 'You stepped away.',
  'Declined offer': 'They offered, and you said no.',
  'Expired offer': 'The offer ran out.',
  'Employer-cancelled opening': 'They closed the role.',
};

Future<void> openStageForm(
  BuildContext context,
  PrototypeSession session,
  String id,
  StageChange change,
) => openDemoPage<void>(
  context,
  LifeStageForm(
    writer: lifeSource(context, session).writer,
    id: id,
    change: change,
  ),
  'life/editor',
  title: change.title,
);

/// Change stage, Record outcome and Reopen application: only what each needs,
/// so a stage and an outcome can't refuse each other. The rest of the record
/// goes along unchanged.
class LifeStageForm extends StatefulWidget {
  const LifeStageForm({
    super.key,
    required this.writer,
    required this.id,
    required this.change,
  });
  final LifeWriter writer;
  final String id;
  final StageChange change;
  @override
  State<LifeStageForm> createState() => _LifeStageFormState();
}

class _LifeStageFormState extends State<LifeStageForm>
    with FormInputs, LifeFormSteps {
  @override
  String get fieldPrefix => 'life-field-';
  @override
  LifeWriter get writer => widget.writer;
  @override
  String? get recordId => widget.id;
  @override
  String get operation => 'life:${widget.change.name_}:${widget.id}';

  StageChange get change => widget.change;
  ApplicationRecord get record =>
      writer.record(widget.id)! as ApplicationRecord;

  @override
  late final Map<String, String> values = {
    ...applicationValues(record, writer.today),
    'stage': careerPipelineStages.contains(record.stage) ? record.stage : '',
    'stageDate': writer.today,
    if (change != StageChange.stage) 'outcome': '',
    if (change == StageChange.reopen && record.stage == 'Accepted') 'stage': '',
    'reason': '',
    ...meta(record.id, record.version),
  };

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

  /// Accepted is a stage and an outcome together, so one choice sets both.
  String get stage =>
      answer('outcome') == 'Accepted' ? 'Accepted' : answer('stage');

  Map<String, String> get command => Map.unmodifiable({
    ...values,
    'stage': stage,
    'currency': answer('currency').toUpperCase(),
    if (stage == 'Saved') 'date': '',
  });

  bool get needsDate => stage != 'Saved' && answer('date').isEmpty;

  @override
  void check() {
    if (change == StageChange.outcome && answer('outcome').isEmpty) {
      lifeReject('Choose a stage and an outcome that fit together.');
    }
    if (stage.isEmpty ||
        change == StageChange.stage && stage == record.stage) {
      lifeReject('Choose a stage from the list.');
    }
    if (needsDate) lifeReject('Choose a date between 1900 and 2200.');
    if (answer('reason').isEmpty) {
      lifeReject('Say why you’re changing this, in up to 2,000 characters.');
    }
    writer.applicationCommand(command, old: widget.id);
  }

  @override
  Future<void> save() => writer.saveApplication(command, old: widget.id);

  Widget details() {
    firstField = true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        notices(),
        if (change == StageChange.outcome)
          pickInput(
            'outcome',
            'Outcome',
            {for (final o in careerOutcomes) o: careerOutcomeLabel(o)},
            descriptions: _outcomeNotes,
            required: true,
            style: PickerStyle.radio,
          )
        else
          pickInput(
            'stage',
            'Stage',
            {for (final s in _stages) s: s},
            required: true,
            helper: stage == 'Saved' && record.fields['date']!.isNotEmpty
                ? 'A saved application has no date applied, so that date is cleared.'
                : null,
          ),
        if (needsDate) dateInput('date', 'Date applied', required: true),
        dateInput('stageDate', 'When this happened', required: true),
        textInput('reason', 'Why you’re changing this', required: true),
        SizedBox(height: CompactForm.groupGap(context)),
        stepActions(change.action),
      ],
    );
  }

  Widget review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      notices(),
      FactRow('Application', '${record.company}, ${record.position}'),
      if (change == StageChange.outcome)
        FactRow('Outcome', careerOutcomeLabel(answer('outcome')))
      else
        FactRow('Stage', stage),
      FactRow('When this happened', overviewLongDate(answer('stageDate'))),
      FactRow('Why you’re changing this', answer('reason')),
      SizedBox(height: CompactForm.fieldGap(context)),
      if (change == StageChange.outcome)
        const InlineNotice(
          'This closes the application. Its steps and reminders stop, and it leaves your calendar. Its steps, documents and history stay, and you can reopen it.',
        ),
      if (change == StageChange.reopen)
        const InlineNotice(
          'It comes back to your active applications, with any step or follow-up still ahead of you. Its earlier outcome stays in its history.',
        ),
      SizedBox(height: CompactForm.groupGap(context)),
      stepActions(change.action),
    ],
  );

  @override
  Widget build(BuildContext context) => framed(
    change.title,
    loading
        ? const Center(child: CircularProgressIndicator())
        : saved
        ? savedPanel(change.done)
        : reviewing
        ? review()
        : details(),
  );
}

/// Add a step to [application], or edit one with [id].
Future<void> openStepForm(
  BuildContext context,
  PrototypeSession session,
  String application, {
  String? id,
}) => openDemoPage<void>(
  context,
  LifeStepForm(
    writer: lifeSource(context, session).writer,
    application: application,
    id: id,
  ),
  'life/editor',
  title: id == null ? 'Add a step' : 'Edit step',
);

class LifeStepForm extends StatefulWidget {
  const LifeStepForm({
    super.key,
    required this.writer,
    required this.application,
    this.id,
  });
  final LifeWriter writer;
  final String application;

  /// The step being edited.
  final String? id;
  @override
  State<LifeStepForm> createState() => _LifeStepFormState();
}

class _LifeStepFormState extends State<LifeStepForm>
    with FormInputs, LifeFormSteps, LifeTimeInputs {
  @override
  String get fieldPrefix => 'life-field-';
  @override
  LifeWriter get writer => widget.writer;
  @override
  String? get recordId => widget.id;
  @override
  String get operation =>
      'life:${widget.id ?? 'new-career-event-${widget.application}'}';

  CareerEventRecord? get record =>
      writer.record(widget.id) as CareerEventRecord?;

  @override
  late final Map<String, String> values = () {
    final r = record;
    return <String, String>{
      'kind': r?.kind ?? 'Interview',
      'date': r?.date ?? writer.today,
      'time': r == null ? '10:00' : r.time,
      'timezone': r?.timezone ?? 'Asia/Manila',
      'fold': r?.fields['fold'] ?? '',
      'status': r?.status ?? 'Scheduled',
      'location': r?.fields['location'] ?? '',
      'outcome': r?.fields['outcome'] ?? '',
      'notes': r?.notes ?? '',
      if (r != null) 'reason': '',
      ...meta(r?.id, r?.version ?? 0),
    };
  }();

  String get kind => answer('kind');
  bool get observed => careerObservations.contains(kind);
  bool get needsTime => const {'Interview', 'Assessment'}.contains(kind);
  bool get done => !observed && answer('status') == 'Completed';

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

  /// A step that records what happened is done by its nature, and has no time
  /// of its own to plan around. An interview always has one.
  void kindChanged(String next) {
    if (careerObservations.contains(next)) {
      values['time'] = '';
    } else {
      if (values['status'] != 'Cancelled') values['status'] = 'Scheduled';
      if (const {'Interview', 'Assessment'}.contains(next) &&
          answer('time').isEmpty) {
        values['time'] = lastTime;
      }
    }
    clockChanged();
  }

  Map<String, String> get command => Map.unmodifiable({
    ...values,
    if (observed) 'status': 'Completed',
  });

  @override
  void check() {
    if (answer('date').isEmpty) {
      lifeReject('Choose a date between 1900 and 2200.');
    }
    if (widget.id != null && answer('reason').isEmpty) {
      lifeReject('Say why you’re changing this, in up to 2,000 characters.');
    }
    writer.stepCommand(command, widget.application, old: widget.id);
  }

  @override
  Future<void> save() =>
      writer.saveStep(command, widget.application, old: widget.id);

  String get saveLabel => widget.id == null ? 'Add step' : 'Save changes';

  Widget details() {
    firstField = true;
    final twice = (matches?.length ?? 0) > 1;
    final inMore = {
      'timezone',
      'location',
      'notes',
      'outcome',
    }.contains(errorField);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        notices(),
        pickInput(
          'kind',
          'Type',
          {for (final k in careerEventKinds) k: k},
          required: true,
          onChanged: kindChanged,
        ),
        dateInput('date', observed ? 'When it happened' : 'Date', required: true),
        if (!observed && !needsTime) allDayInput(),
        if (!observed && !allDay) timeInput(),
        if (twice) foldInput(),
        FormMoreDetails(
          open: inMore,
          children: [
            if (!observed && !allDay) timezoneInput(),
            textInput('location', 'Location or link'),
            textInput(
              'notes',
              observed ? 'What happened' : 'Preparation notes',
              lines: 3,
            ),
            if (done) textInput('outcome', 'How it went'),
          ],
        ),
        if (widget.id != null)
          textInput('reason', 'Why you’re changing this', required: true),
        SizedBox(height: CompactForm.groupGap(context)),
        stepActions(saveLabel),
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
        FactRow('Type', kind),
        FactRow('Date', overviewLongDate(answer('date'))),
        if (!observed) FactRow('Time', allDay ? time : '$time in $zone$fold'),
        if (!allDay && zoneLine(context).isNotEmpty)
          FactRow('Your time', zoneLine(context)),
        if (answer('location').isNotEmpty)
          FactRow('Location or link', answer('location')),
        if (answer('notes').isNotEmpty)
          FactRow(
            observed ? 'What happened' : 'Preparation notes',
            answer('notes'),
          ),
        if (done && answer('outcome').isNotEmpty)
          FactRow('How it went', answer('outcome')),
        if (answer('reason').isNotEmpty)
          FactRow('Why you’re changing this', answer('reason')),
        SizedBox(height: CompactForm.groupGap(context)),
        stepActions(saveLabel),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => framed(
    widget.id == null ? 'Add a step' : 'Edit step',
    loading
        ? const Center(child: CircularProgressIndicator())
        : saved
        ? savedPanel('Step saved')
        : reviewing
        ? review()
        : details(),
  );
}
