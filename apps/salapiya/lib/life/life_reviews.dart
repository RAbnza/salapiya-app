import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart' show newLocalId;
import 'life_data.dart';
import 'life_domain.dart';
import 'life_forms.dart' show lostSaveMessage, lostSaveTitle;
import 'life_pages_detail.dart'
    show ReasonForm, ReasonFormState, lifeFieldValue;

/// What a refused edit was to.
String _kind(LifeType type) => switch (type) {
  LifeType.task => 'Task',
  LifeType.personal => 'Event',
  LifeType.learning => 'Learning',
  LifeType.book => 'Book',
  LifeType.application => 'Application',
  LifeType.careerEvent => 'Career step',
  LifeType.document => 'Document',
};

/// A command to save a refused edit, kept so a lost answer asks about the
/// same one.
class _Retry {
  _Retry(this.command, this.original);
  final LifeCommand command;
  final String original;
}

/// Edits that couldn't be saved. Each stays on record whatever the user
/// chooses, and choosing closes it.
class LifeChecksPage extends StatefulWidget {
  const LifeChecksPage({
    super.key,
    required this.listenable,
    required this.source,
  });
  final Listenable listenable;
  final LifeSource Function(BuildContext context) source;
  @override
  State<LifeChecksPage> createState() => _LifeChecksPageState();
}

class _LifeChecksPageState extends State<LifeChecksPage> {
  String? problem;
  _Retry? lost;
  bool busy = false;

  Future<void> run(Future<void> Function() work) async {
    setState(() {
      busy = true;
      problem = null;
    });
    try {
      await work();
      lost = null;
    } on FormatException catch (e) {
      problem = e.message;
      lost = null;
    } catch (_) {
      if (lost == null) problem = 'That didn’t save. Nothing changed.';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> use(LifeSource source, LifeReviewRow r) async {
    final form = GlobalKey<ReasonFormState>();
    String? reason;
    final yes = await showAppDialog<bool>(
      context,
      title: 'Use your edit?',
      body: ReasonForm(
        key: form,
        message: 'Your edit replaces what’s there now. What’s there stays in Edit history.',
        label: 'Why you’re using it',
        missing: 'Say why you’re using it.',
        fieldKey: const ValueKey('life-check-why'),
      ),
      primary: ModalAction(
        'Use my edit',
        value: true,
        onPressed: () {
          reason = form.currentState?.answer();
          return reason != null;
        },
      ),
    );
    if (yes != true || !mounted) return;
    final command = LifeCommand(
      id: newLocalId(),
      owner: r.original.owner,
      recordId: r.original.recordId,
      type: r.original.type,
      expectedVersion: r.current?.version ?? 0,
      fields: r.original.fields,
      reason: reason!,
    );
    lost = _Retry(command, r.id);
    await run(() => source.writer.useEdit(command, r.id));
  }

  Future<void> keep(LifeSource source, LifeReviewRow r) async {
    final yes = await showAppDialog<bool>(
      context,
      title: 'Keep what’s there?',
      body: const Text(
        'Your record stays as it is, and your edit isn’t used. It stays on record, so nothing is lost.',
      ),
      primary: const ModalAction('Keep what’s there', value: true),
    );
    if (yes == true) await run(() => source.writer.keepCurrent(r.id));
  }

  Widget card(BuildContext context, LifeSource source, LifeReviewRow r) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: c.secondary);
    String shown(String key, String value) =>
        source.hidden && ['salaryMin', 'salaryMax'].contains(key)
        ? 'Amount hidden'
        : lifeFieldValue(context, key, value);
    return OverviewCard(
      key: ValueKey('life-check-${r.id}'),
      title: r.current?.title ?? r.original.fields['title'] ?? 'An edit',
      caption: '${_kind(r.original.type)} · ${lifeReason(r.reason)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (key, now, mine) in r.differences)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(lifeFieldNames[key]!, style: text.labelMedium),
                  const SizedBox(height: Space.xxs),
                  FactRow('Now', shown(key, now)),
                  FactRow('Your edit', shown(key, mine)),
                ],
              ),
            ),
          if (r.differences.isEmpty)
            Text('Your edit changes nothing you can see here.', style: muted),
          const SizedBox(height: Space.md),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              AppButton.tertiary(
                'Keep what’s there',
                key: ValueKey('life-check-keep-${r.id}'),
                onPressed: busy ? null : () => keep(source, r),
              ),
              if (r.usable)
                AppButton.secondary(
                  'Use my edit',
                  key: ValueKey('life-check-use-${r.id}'),
                  onPressed: busy ? null : () => use(source, r),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.listenable,
    builder: (context, _) {
      final source = widget.source(context);
      final gap = SizedBox(height: Space.cardGapOf(context));
      final retry = lost;
      return SectionPage(
        title: 'Changes to check',
        caption: 'Edits that couldn’t be saved. You choose what happens.',
        maxWidth: Space.reviewMaxWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (retry != null && !busy) ...[
              InlineNotice(
                lostSaveMessage,
                title: lostSaveTitle,
                tone: NoticeTone.warning,
                live: true,
                action: AppButton.secondary(
                  'Check again',
                  key: const ValueKey('life-check-retry'),
                  onPressed: () => run(
                    () => source.writer.useEdit(retry.command, retry.original),
                  ),
                ),
              ),
              gap,
            ],
            if (problem != null) ...[
              InlineNotice(problem!, tone: NoticeTone.error, live: true),
              gap,
            ],
            if (source.reviews.isEmpty)
              const SurfaceCard(
                child: EmptyState(
                  icon: Icons.task_alt,
                  title: 'Nothing to check',
                  message: 'Edits that can’t be saved show here.',
                ),
              )
            else
              for (final (i, r) in source.reviews.indexed) ...[
                if (i > 0) gap,
                card(context, source, r),
              ],
          ],
        ),
      );
    },
  );
}
