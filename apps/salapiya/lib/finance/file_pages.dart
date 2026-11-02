import 'dart:async';

import 'package:flutter/material.dart';

import '../app/overview_cards.dart' show civilLabel;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import 'files_data.dart';
import 'files_tab.dart';
import 'money_data.dart';

/// One attached file. What it offers depends on where the file stands.
class FileDetailView extends StatefulWidget {
  const FileDetailView({
    super.key,
    required this.listenable,
    required this.source,
    required this.id,
  });
  final Listenable listenable;
  final MoneySource Function(BuildContext context) source;
  final String id;
  @override
  State<FileDetailView> createState() => _FileDetailViewState();
}

class _FileDetailViewState extends State<FileDetailView> {
  bool? present;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(look());
  }

  Future<void> look() async {
    final found = await widget.source(context).files?.present(widget.id);
    if (mounted && found != present) setState(() => present = found);
  }

  Future<void> act(Future<void> Function() step) async {
    await step();
    if (mounted) await look();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.listenable,
    builder: (context, _) {
      final source = widget.source(context);
      final s = source.snapshot, actions = source.actions;
      final r = fileRows(
        s,
        present: {widget.id: ?present},
      ).where((r) => r.id == widget.id).firstOrNull;
      final files = source.files;
      if (r == null || files == null) {
        return const SectionPage(
          title: 'File',
          child: SurfaceCard(
            child: EmptyState(
              icon: Icons.folder_off_outlined,
              title: 'This file is no longer here',
              message: 'Go back to see the others.',
            ),
          ),
        );
      }
      final here = r.state == FileState.here;
      final canOpen = here && !r.archived;
      final more = CardMenu(
        key: const ValueKey('file-menu'),
        tooltip: 'More',
        items: [
          if (!r.archived)
            MenuItemButton(
              key: const ValueKey('file-restore'),
              leadingIcon: const Icon(Icons.restore),
              onPressed: () => act(() => files.restore(context, r.record)),
              child: const Text('Restore from original'),
            ),
          if (here)
            MenuItemButton(
              key: const ValueKey('file-remove'),
              leadingIcon: const Icon(Icons.delete_outline),
              onPressed: () => act(() => files.removeCopy(context, r.record)),
              child: const Text('Remove from this device'),
            ),
          if (!r.archived)
            MenuItemButton(
              key: const ValueKey('file-archive'),
              leadingIcon: const Icon(Icons.archive_outlined),
              onPressed: () => actions.form(
                'fileDetach',
                'Archive file link',
                initial: {'file': r.id},
              ),
              child: const Text('Archive link'),
            ),
          MenuItemButton(
            key: const ValueKey('file-record'),
            leadingIcon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => actions.openRecord(r.id),
            child: const Text('View record'),
          ),
        ],
      );
      final source_ = r.record.values['sourceRevision'];
      final about = OverviewCard(
        key: const ValueKey('file-about'),
        title: 'About this file',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FactRow('Attached to', r.attachedTo),
            FactRow('Type', r.type),
            FactRow('Size', fileSize(r.size)),
            FactRow('Added', civilLabel(r.added)),
            if (source.waiting?.call(r.id) ?? false)
              const FactRow('Details', 'On this device, waiting to sync'),
            const SizedBox(height: Space.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CardLink(
                'Open ${r.attachedTo}',
                key: const ValueKey('file-attached-to'),
                onPressed: source_ == null
                    ? () {}
                    : () => actions.openRecord(source_),
              ),
            ),
            const SizedBox(height: Space.sm),
            FormMoreDetails(
              label: 'View details',
              children: [
                FactRow('Fingerprint', r.record.values['checksum'] ?? ''),
              ],
            ),
          ],
        ),
      );
      return SectionPage(
        title: r.name,
        status: filePill(r),
        caption: 'Attached to ${r.attachedTo}',
        actions: [
          if (canOpen && r.image)
            AppButton(
              'Preview',
              key: const ValueKey('file-preview'),
              icon: Icons.visibility_outlined,
              onPressed: () => act(() => files.preview(context, r.record)),
            ),
          if (canOpen && !r.image)
            AppButton(
              'Open in another app',
              key: const ValueKey('file-open'),
              icon: Icons.open_in_new,
              onPressed: () =>
                  act(() => files.openElsewhere(context, r.record)),
            ),
          if (canOpen)
            AppButton.secondary(
              'Save a copy',
              key: const ValueKey('file-save'),
              onPressed: () => act(() => files.saveCopy(context, r.record)),
            ),
          more,
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InlineNotice(
              r.missing
                  ? 'This file isn’t on this device. Restore it from your original.'
                  : r.archived
                  ? 'This file’s link is archived. Attach your original again to link it.'
                  : 'Not virus-scanned. Open it only in an app you trust.',
              key: const ValueKey('file-notice'),
              tone: NoticeTone.warning,
            ),
            SizedBox(height: Space.cardGapOf(context)),
            about,
          ],
        ),
      );
    },
  );
}

/// Attach a file: find the record, then pick the file. The review that
/// follows is a dialog, as it's always been.
class AttachFilePage extends StatefulWidget {
  const AttachFilePage({
    super.key,
    required this.listenable,
    required this.source,
  });
  final Listenable listenable;
  final MoneySource Function(BuildContext context) source;
  @override
  State<AttachFilePage> createState() => _AttachFilePageState();
}

class _AttachFilePageState extends State<AttachFilePage> {
  static const pageSize = 25;
  final search = TextEditingController();
  int shown = pageSize;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  /// Comes back to Files once the file is attached.
  Future<void> attach(MoneySource source, String record) async {
    final attached = await source.files?.attach(context, record) ?? false;
    if (attached && mounted) await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.listenable,
    builder: (context, _) {
      final source = widget.source(context);
      final s = source.snapshot;
      final words = search.text.trim().toLowerCase();
      final records = [
        for (final r in s.current.reversed)
          if (!nativeFileCommands.contains(financeType(r)) &&
              !nativeCashImportCommands.contains(financeType(r)) &&
              (words.isEmpty ||
                  '${recordTitle(r)} ${moneyLabel(r)} ${civilLabel(r.date)}'
                      .toLowerCase()
                      .contains(words)))
            r,
      ]..sort((a, b) => b.date.compareTo(a.date));
      return SectionPage(
        title: 'Attach a file',
        caption: 'Choose a record, then a PDF, JPEG or PNG up to 10 MB',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CompactForm(
              child: Semantics(
                label: 'Search records',
                textField: true,
                child: TextField(
                  key: const ValueKey('attach-search'),
                  controller: search,
                  decoration: const InputDecoration(
                    hintText: 'Search records',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() => shown = pageSize),
                ),
              ),
            ),
            SizedBox(height: Space.cardGapOf(context)),
            SurfaceCard(
              child: records.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off,
                      title: 'No records match',
                      message: 'Try other words.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListGroup(
                          children: [
                            for (final r in records.take(shown))
                              AdaptiveRow(
                                key: ValueKey('attach-${r.id}'),
                                title: recordTitle(r),
                                subtitle: detailLine([
                                  moneyLabel(r),
                                  civilLabel(r.date),
                                ]),
                                onTap: () => unawaited(attach(source, r.id)),
                              ),
                          ],
                        ),
                        if (records.length > shown) ...[
                          const SizedBox(height: Space.sm),
                          ShowMore(
                            left: records.length - shown,
                            onPressed: () => setState(() => shown += pageSize),
                          ),
                        ] else
                          const ListEnd(key: ValueKey('attach-end')),
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );
}
