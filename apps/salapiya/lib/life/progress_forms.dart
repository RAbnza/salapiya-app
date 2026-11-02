import 'dart:async';

import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_dashboard.dart' show overviewLongDate;
import '../design_system/kit/kit.dart';
import '../finance/form_mechanics.dart';
import '../prototype/scenarios.dart';
import 'life_data.dart';
import 'life_domain.dart';
import 'life_forms.dart';
import 'life_hub.dart';

/// "5 of 12 lessons".
String progressLine(ProgressRow r, ProgressWords words) =>
    '${r.done} of ${r.total} ${words.units}';

/// Add a learning goal or a book, or edit one with [id]. The same keys as
/// before; a blank total sends the rules' default instead of a made-up number.
Future<void> openEntryForm(
  BuildContext context,
  PrototypeSession session,
  LifeType type, {
  String? id,
}) => openDemoPage<void>(
  context,
  LifeEntryForm(
    writer: lifeSource(context, session).writer,
    type: type,
    id: id,
  ),
  'life/editor',
  title: id == null
      ? ProgressWords.of(type).adding
      : ProgressWords.of(type).editing,
);

class LifeEntryForm extends StatefulWidget {
  const LifeEntryForm({
    super.key,
    required this.writer,
    required this.type,
    this.id,
  });
  final LifeWriter writer;
  final LifeType type;

  /// The item being edited.
  final String? id;
  @override
  State<LifeEntryForm> createState() => _LifeEntryFormState();
}

class _LifeEntryFormState extends State<LifeEntryForm>
    with FormInputs, LifeFormSteps {
  ProgressWords get words => ProgressWords.of(widget.type);
  bool get book => widget.type == LifeType.book;

  @override
  String get fieldPrefix => 'life-field-';
  @override
  LifeWriter get writer => widget.writer;
  @override
  String? get recordId => widget.id;
  @override
  String get operation =>
      'life:${widget.id ?? (book ? 'new-book' : 'new-learning')}';

  ProgressRecord? get record => writer.record(widget.id) as ProgressRecord?;

  @override
  late final Map<String, String> values = () {
    final r = record;
    return <String, String>{
      'title': r?.title ?? '',
      'detail': r?.fields['detail'] ?? '',
      'due': r?.due ?? '',
      // A total of one is how the rules hold "I don't know".
      'total': r == null || r.total == 1 ? '' : '${r.total}',
      'progress': '${r?.progress ?? 0}',
      'status': r?.status ?? 'Not started',
      'started': r?.fields['started'] ?? '',
      'completed': r?.fields['completed'] ?? '',
      if (book) 'rating': r?.fields['rating'] ?? '',
      'notes': r?.notes ?? '',
      if (r != null) 'reason': '',
      ...meta(r?.id, r?.version ?? 0),
    };
  }();

  bool get hasTotal => answer('total').isNotEmpty;
  bool get finished => answer('status') == 'Completed';

  /// What the command holds: blanks become the rules' own defaults.
  Map<String, String> get command => Map.unmodifiable({
    ...values,
    'total': hasTotal ? answer('total') : '1',
    'progress': hasTotal
        ? (answer('progress').isEmpty ? '0' : answer('progress'))
        : (finished ? '1' : '0'),
  });

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
    writer.entryCommand(widget.type, command, old: widget.id);
  }

  @override
  Future<void> save() => writer.saveEntry(widget.type, command, old: widget.id);

  String get saveLabel => widget.id == null ? words.adding : 'Save changes';

  Widget details() {
    firstField = true;
    final inMore = {
      'status',
      'started',
      'completed',
      'rating',
      'notes',
    }.contains(errorField);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        notices(),
        textInput('title', 'Title', required: true),
        textInput('detail', words.detail),
        textInput(
          'total',
          words.total,
          input: FieldInput.wholeNumber,
          helper: 'Leave this blank if you don’t know.',
        ),
        if (hasTotal)
          textInput('progress', words.done, input: FieldInput.wholeNumber),
        dateInput('due', 'Due date'),
        FormMoreDetails(
          open: inMore,
          children: [
            pickInput('status', 'Status', {
              for (final s in lifeStatuses)
                s: s == 'Completed' ? 'Finished' : s,
            }, required: true),
            dateInput('started', 'Date started'),
            if (finished)
              dateInput(
                'completed',
                'Date finished',
                helper: 'Optional. Your history keeps the day you saved this.',
              ),
            if (book && (finished || answer('rating').isNotEmpty))
              textInput(
                'rating',
                'Rating',
                input: FieldInput.rating,
                helper: 'From 0 to 5.',
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

  Widget review() {
    String date(String key) =>
        answer(key).isEmpty ? 'None' : overviewLongDate(answer(key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        notices(),
        FactRow('Title', answer('title')),
        if (answer('detail').isNotEmpty)
          FactRow(words.detail, answer('detail')),
        FactRow(
          'Progress',
          hasTotal
              ? '${command['progress']} of ${answer('total')} ${words.units}'
              : 'No total',
        ),
        FactRow('Due date', date('due')),
        FactRow('Status', finished ? 'Finished' : answer('status')),
        if (answer('started').isNotEmpty)
          FactRow('Date started', date('started')),
        if (finished && answer('completed').isNotEmpty)
          FactRow('Date finished', date('completed')),
        if (book && answer('rating').isNotEmpty)
          FactRow('Rating', '${answer('rating')} of 5'),
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
    widget.id == null ? words.adding : words.editing,
    loading
        ? const Center(child: CircularProgressIndicator())
        : saved
        ? savedPanel(book ? 'Book saved' : 'Learning goal saved')
        : reviewing
        ? review()
        : details(),
  );
}

/// Log progress on item [id]. [draft] is a draft's own name, for one the old
/// form saved.
Future<void> openProgressForm(
  BuildContext context,
  PrototypeSession session,
  String id, {
  String? draft,
}) => openDemoPage<void>(
  context,
  LifeProgressForm(
    writer: lifeSource(context, session).writer,
    id: id,
    draft: draft,
  ),
  'life/editor',
  title: 'Log progress',
);

class LifeProgressForm extends StatefulWidget {
  const LifeProgressForm({
    super.key,
    required this.writer,
    required this.id,
    this.draft,
  });
  final LifeWriter writer;
  final String id;
  final String? draft;
  @override
  State<LifeProgressForm> createState() => _LifeProgressFormState();
}

class _LifeProgressFormState extends State<LifeProgressForm>
    with FormInputs, LifeFormSteps {
  @override
  String get fieldPrefix => 'life-field-';
  @override
  LifeWriter get writer => widget.writer;
  @override
  String? get recordId => widget.id;
  @override
  String get operation => widget.draft ?? 'life:progress:${widget.id}';

  ProgressRecord get record => writer.record(widget.id)! as ProgressRecord;
  ProgressWords get words => ProgressWords.of(record.type);

  @override
  late final Map<String, String> values = {
    'progress': '${record.progress}',
    'completed': record.fields['completed'] ?? '',
    'note': '',
    ...meta(record.id, record.version),
  };

  bool get reaching => int.tryParse(answer('progress')) == record.total;

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
    writer.progressCommand(Map.unmodifiable(values), widget.id);
  }

  @override
  Future<void> save() =>
      writer.saveProgress(Map.unmodifiable(values), widget.id);

  Widget details() {
    firstField = true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        notices(),
        textInput(
          'progress',
          words.done,
          required: true,
          input: FieldInput.wholeNumber,
          helper: 'Out of ${record.total} ${words.units}.',
        ),
        if (reaching)
          dateInput(
            'completed',
            'Date finished',
            helper: 'Optional. Your history keeps the day you saved this.',
          ),
        textInput('note', 'Note', lines: 3),
        SizedBox(height: CompactForm.groupGap(context)),
        stepActions('Log progress'),
      ],
    );
  }

  Widget review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      notices(),
      FactRow('Title', record.title),
      FactRow(
        'Progress',
        '${answer('progress')} of ${record.total} ${words.units}',
      ),
      if (reaching) const FactRow('Status', 'Finished'),
      if (reaching && answer('completed').isNotEmpty)
        FactRow('Date finished', overviewLongDate(answer('completed'))),
      if (answer('note').isNotEmpty) FactRow('Note', answer('note')),
      SizedBox(height: CompactForm.groupGap(context)),
      stepActions('Log progress'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final gone = writer.record(widget.id) is! ProgressRecord;
    return framed(
      'Log progress',
      gone
          ? const EmptyState(
              icon: Icons.history,
              title: 'This item is no longer here',
              message: 'Go back to see what’s left.',
            )
          : loading
          ? const Center(child: CircularProgressIndicator())
          : saved
          ? savedPanel('Progress saved')
          : reviewing
          ? review()
          : details(),
    );
  }
}
