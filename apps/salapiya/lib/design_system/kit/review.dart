import 'package:flutter/material.dart';

import '../theme.dart';

/// A form's Review step and saved state, moved from `form_presentation.dart`,
/// `editorial.dart` and `workspace.dart` (Chat 16), same look on tokens.
/// Not exported from `kit.dart`: Profile has its own `ReviewRow` model.

/// Transport state is supplied separately from the local-save outcome.
class FormSyncStatus extends StatelessWidget {
  const FormSyncStatus({super.key, required this.state});
  final String? state;
  @override
  Widget build(BuildContext context) => FormStatus(
    title: switch (state) {
      'pending' => 'Waiting to sync',
      'accepted' => 'Reached the service',
      'reconciled' => 'Synced',
      'review' || 'restored' => 'Needs review',
      _ => 'Sync status unknown',
    },
    message: switch (state) {
      'pending' =>
        'Saved on this device. It syncs when there’s a connection.',
      'accepted' => 'It shows as synced after the next download.',
      'reconciled' => 'Saved on this device and synced.',
      'review' =>
        'The service didn’t accept this change. It’s kept; check it on Profile › Connection.',
      'restored' =>
        'This change came back with a restored backup. Check it on Profile › Connection before it’s sent.',
      _ => 'Saved on this device. Profile › Connection shows whether it synced.',
    },
    tone: state == 'reconciled' ? NoticeTone.success : NoticeTone.warning,
  );
}

/// Presentation only: callers supply the authoritative outcome and recovery.
class FormStatus extends StatelessWidget {
  const FormStatus({
    super.key,
    required this.title,
    required this.message,
    this.tone = NoticeTone.information,
    this.busy = false,
  });
  final String title, message;
  final NoticeTone tone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final (ink, surface) = c.tone(tone);
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.lg),
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(Radii.controlOf(context)),
          border: c.highContrast ? Border.all(color: ink) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: Space.xxl + Space.sm,
              height: Space.xxl + Space.sm,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ink.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: busy
                  ? SizedBox.square(
                      dimension: Space.lg + Space.xs,
                      child: CircularProgressIndicator(
                        strokeWidth: Space.xxs,
                        color: ink,
                      ),
                    )
                  : Icon(
                      switch (tone) {
                        NoticeTone.success => Icons.check_rounded,
                        NoticeTone.error => Icons.error_outline,
                        NoticeTone.warning => Icons.pending_actions_outlined,
                        _ => Icons.info_outline,
                      },
                      color: ink,
                      size: Space.xl,
                    ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleLarge?.copyWith(color: ink)),
                  const SizedBox(height: Space.xs),
                  Text(message, style: text.bodyMedium?.copyWith(color: c.text)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label and value side by side, stacking before either column gets hard to
/// read: in a narrow column or at large text.
class ReviewRow extends StatelessWidget {
  const ReviewRow(
    this.label,
    this.value, {
    super.key,
    this.detail,
    this.emphasis = false,
  });
  final String label, value;
  final String? detail;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final labelWidget = Text(
            label,
            style: text.bodyMedium?.copyWith(color: c.secondary),
          );
          final valueWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.isEmpty ? 'Not provided' : value,
                style: emphasis ? text.titleLarge : text.titleSmall,
              ),
              if (detail != null) ...[
                const SizedBox(height: Space.xs),
                Text(
                  detail!,
                  style: text.bodySmall?.copyWith(color: c.secondary),
                ),
              ],
            ],
          );
          if (bounds.maxWidth < Space.xxxl * 10 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.5) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: Space.xs),
                valueWidget,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: labelWidget),
              const SizedBox(width: Space.lg),
              Expanded(flex: 3, child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

/// A Review step's group heading. With [spaced], it keeps a group's gap from
/// the rows above it (§4: 24, with the row's own `Space.sm`); after a divider
/// the divider is the gap.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.spaced = true});
  final String title;
  final bool spaced;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: spaced ? Space.lg : 0, bottom: Space.md),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}

/// Exact detail behind a quiet disclosure.
class FormEvidence extends StatelessWidget {
  const FormEvidence({
    super.key,
    required this.children,
    this.title = 'View details',
  });
  final List<Widget> children;
  final String title;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: PageStorageKey('form-evidence-$title'),
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: Space.lg),
    shape: const Border(),
    collapsedShape: const Border(),
    leading: Icon(
      Icons.receipt_long_outlined,
      size: Space.compactIcon,
      color: CraftTheme.of(context).secondary,
    ),
    title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
    children: [
      for (final (index, child) in children.indexed)
        Padding(
          key: PageStorageKey('evidence-item-$index'),
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
    ],
  );
}

/// The rules' own notes, one per line.
class ReviewNotes extends StatelessWidget {
  const ReviewNotes(this.notes, {super.key});
  final Iterable<String> notes;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final note in notes)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: Space.compactIcon,
                color: CraftTheme.of(context).secondary,
              ),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(note)),
            ],
          ),
        ),
    ],
  );
}

/// Routes wait for protected draft writes before leaving; failed writes keep
/// the form open. A form without draft storage requires explicit discard.
class FormExitGuard extends StatefulWidget {
  const FormExitGuard({
    super.key,
    required this.child,
    required this.dirty,
    required this.busy,
    this.keepDraft,
    this.discardDraft,
  });
  final Widget child;
  final bool dirty, busy;
  final Future<void> Function()? keepDraft;

  /// Offers to drop the draft too, for forms that bring it back on reopening.
  final Future<void> Function()? discardDraft;
  @override
  State<FormExitGuard> createState() => _FormExitGuardState();
}

class _FormExitGuardState extends State<FormExitGuard> {
  bool leaving = false, allowed = false;
  Future<void> leave() async {
    if (leaving || widget.busy) return;
    leaving = true;
    try {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            widget.keepDraft == null
                ? 'Discard your changes?'
                : 'Keep this draft for later?',
          ),
          content: Text(
            widget.keepDraft == null
                ? 'Leaving discards this unfinished form. Nothing was saved.'
                : 'Your unfinished form stays encrypted on this device. Nothing is logged until you save it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep editing'),
            ),
            if (widget.discardDraft != null)
              TextButton(
                onPressed: () => Navigator.pop(context, 'discard'),
                child: const Text('Discard draft'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'keep'),
              child: Text(
                widget.keepDraft == null
                    ? 'Discard changes'
                    : 'Keep draft & close',
              ),
            ),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == 'discard') {
        await widget.discardDraft!.call();
      } else {
        await widget.keepDraft?.call();
      }
      if (!mounted) return;
      setState(() => allowed = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your draft could not be saved. Keep this form open and check storage.',
            ),
          ),
        );
      }
    } finally {
      leaving = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.busy && (allowed || !widget.dirty),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: widget.child,
  );
}
