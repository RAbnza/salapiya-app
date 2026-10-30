import 'dart:async';

import 'package:flutter/material.dart';

import '../app/overview_cards.dart' show civilLabel;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import 'files_data.dart';
import 'money_data.dart';

/// A file's state as a pill.
Widget filePill(FileRow r) => switch (r.state) {
  FileState.here => StatusPill(
    r.state.label,
    icon: Icons.check_circle_outline,
    tone: PillTone.success,
  ),
  FileState.missing => StatusPill(
    r.state.label,
    icon: Icons.warning_amber_rounded,
    tone: PillTone.warning,
  ),
  FileState.archived => StatusPill(r.state.label, icon: Icons.archive_outlined),
  FileState.unknown => StatusPill(r.state.label, icon: Icons.schedule),
};

enum _Show {
  all('All'),
  missing('Missing'),
  archived('Archived links');

  const _Show(this.label);
  final String label;
}

/// "What's attached, and is anything missing or unverified?" Whether a file
/// is on this device is looked up when the tab opens; Check files reads each
/// one through, which is slower and changes nothing.
class FilesTab extends StatefulWidget {
  const FilesTab({super.key, required this.source});
  final MoneySource source;
  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  final present = <String, bool>{};
  final checks = <String, String?>{};
  List<String> leftovers = const [];
  FileSelection? picked;
  bool checking = false, unreadable = false;
  int checked = 0;
  _Show show = _Show.all;

  MoneySource get source => widget.source;
  FileAccess? get files => source.files;
  List<LocalRevision> get records => [
    for (final r in source.snapshot.current)
      if (financeType(r) == 'financialFile') r,
  ];

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void didUpdateWidget(FilesTab old) {
    super.didUpdateWidget(old);
    if (records.any((r) => !present.containsKey(r.id))) unawaited(load());
  }

  /// Looks once for each file; pages coming back look again.
  Future<void> load() async {
    final access = files;
    if (access == null) return;
    final found = <String, bool>{};
    var failed = false;
    List<String> left = const [];
    FileSelection? selection;
    try {
      for (final r in records) {
        found[r.id] = await access.present(r.id);
      }
      selection = await access.selection();
      left = await access.leftovers();
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      present
        ..clear()
        ..addAll(found);
      picked = selection;
      leftovers = [
        for (final name in left)
          if (name != '${selection?.id}.sfp') name,
      ];
      unreadable = failed;
    });
  }

  Future<void> checkAll() async {
    final access = files;
    if (access == null || checking) return;
    setState(() {
      checking = true;
      checked = 0;
    });
    for (final r in records) {
      if (!mounted) return;
      if (financialFileDetached(source.snapshot, r.id)) continue;
      final found = await access.check(r);
      if (!mounted) return;
      setState(() {
        checks[r.id] = found;
        checked++;
      });
    }
    if (mounted) setState(() => checking = false);
  }

  void open(FileRow r) => unawaited(
    source.actions.openFile(r.id).then((_) {
      if (mounted) unawaited(load());
    }),
  );

  void attach() => unawaited(
    source.actions.attachFile().then((_) {
      if (mounted) unawaited(load());
    }),
  );

  Future<void> onSelection(
    Future<void> Function(BuildContext, FileSelection) act,
  ) async {
    await act(context, picked!);
    if (mounted) await load();
  }

  AppTableRow row(FileRow r) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(
      color: CraftTheme.of(context).secondary,
    );
    return AppTableRow(
      id: 'file-${r.id}',
      spoken: [
        r.name,
        'attached to ${r.attachedTo}',
        r.type,
        fileSize(r.size),
        civilLabel(r.added),
        r.state.label,
      ].join(', '),
      onTap: () => open(r),
      cells: [
        Text(r.name, style: text.titleSmall),
        Text(r.attachedTo, style: text.bodyMedium),
        Text(r.type, style: muted),
        Text(civilLabel(r.added), style: text.bodyMedium),
        Align(alignment: AlignmentDirectional.centerStart, child: filePill(r)),
      ],
      money: [fileSize(r.size)],
      narrow: KeyedSubtree(
        key: ValueKey('row-file-${r.id}'),
        child: AdaptiveRow(
          leading: r.image ? Icons.image_outlined : Icons.description_outlined,
          title: r.name,
          subtitle: detailLine([r.attachedTo, r.state.label]),
          trailing: Text(fileSize(r.size), style: muted),
          onTap: () => open(r),
        ),
      ),
    );
  }

  Widget yourFiles(List<FileRow> rows) {
    final shown = [
      for (final r in rows)
        if (switch (show) {
          _Show.all => true,
          _Show.missing => r.missing,
          _Show.archived => r.archived,
        })
          r,
    ];
    return OverviewCard(
      key: const ValueKey('files-list'),
      title: 'Your files',
      caption: '${rows.length} ${rows.length == 1 ? 'file' : 'files'}',
      stackBelow: rowBase + periodBase,
      trailing: source.complete
          ? CardLink(
              'Attach a file',
              key: const ValueKey('files-attach'),
              icon: Icons.attach_file,
              onPressed: attach,
            )
          : null,
      child: !source.complete
          ? const NotAvailable('Files show once your records are complete.')
          : rows.isEmpty
          ? EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No files yet',
              message: 'Attach a receipt or document to a record.',
              action: AppButton.secondary('Attach a file', onPressed: attach),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MiniSegmented<_Show>(
                    key: const ValueKey('files-filter'),
                    label: 'Show',
                    options: [for (final s in _Show.values) (s, s.label)],
                    selected: show,
                    onSelected: (v) => setState(() => show = v),
                  ),
                ),
                const SizedBox(height: Space.sm),
                if (shown.isEmpty)
                  const EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'Nothing here',
                    message: 'Every file is on this device and linked.',
                  )
                else ...[
                  AppTable(
                    key: const ValueKey('files-table'),
                    columns: const [
                      (label: 'File', flex: 4, width: null),
                      (label: 'Attached to', flex: 3, width: null),
                      (label: 'Type', flex: 1, width: null),
                      (label: 'Added', flex: 0, width: dateColumn),
                      (label: 'Status', flex: 2, width: null),
                    ],
                    moneyColumns: const ['Size'],
                    rows: [for (final r in shown) row(r)],
                  ),
                  const ListEnd(key: ValueKey('files-end')),
                ],
              ],
            ),
    );
  }

  Widget? attention(FilesSummary summary) {
    final failed = summary.failed;
    final missing = summary.linked.where((r) => r.missing).toList();
    final selection = picked;
    if (!unreadable &&
        failed.isEmpty &&
        missing.isEmpty &&
        selection == null &&
        leftovers.isEmpty) {
      return null;
    }
    return OverviewCard(
      key: const ValueKey('files-attention'),
      title: 'Needs your attention',
      corner: selection == null
          ? null
          : CardMenu(
              key: const ValueKey('files-selection-menu'),
              tooltip: 'File you picked',
              items: [
                MenuItemButton(
                  key: const ValueKey('files-selection-resume'),
                  onPressed: () => onSelection(files!.resume),
                  child: const Text('Finish attaching'),
                ),
                MenuItemButton(
                  key: const ValueKey('files-selection-reselect'),
                  onPressed: () => onSelection(files!.reselect),
                  child: const Text('Choose the file again'),
                ),
                MenuItemButton(
                  key: const ValueKey('files-selection-release'),
                  onPressed: () => onSelection(files!.release),
                  child: const Text('Let it go'),
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListGroup(
            leading: true,
            children: [
              if (unreadable)
                const AdaptiveRow(
                  leading: Icons.error_outline,
                  title: 'Files couldn’t be read',
                  subtitle: 'Nothing was removed. Reopen your profile.',
                ),
              for (final r in failed)
                AdaptiveRow(
                  key: ValueKey('files-failed-${r.id}'),
                  leading: Icons.gpp_maybe_outlined,
                  title: r.name,
                  subtitle: r.problem,
                  onTap: () => open(r),
                ),
              for (final r in missing)
                AdaptiveRow(
                  key: ValueKey('files-missing-${r.id}'),
                  leading: Icons.warning_amber_rounded,
                  title: r.name,
                  subtitle:
                      'Not on this device. Restore it from your original.',
                  onTap: () => open(r),
                ),
              if (selection != null)
                AdaptiveRow(
                  key: const ValueKey('files-selection'),
                  leading: Icons.attach_file,
                  title: selection.name,
                  subtitle: 'Picked, but not attached yet',
                  onTap: () => onSelection(files!.resume),
                ),
              if (leftovers.isNotEmpty)
                AdaptiveRow(
                  key: const ValueKey('files-leftovers'),
                  leading: Icons.folder_outlined,
                  title:
                      '${leftovers.length} leftover ${leftovers.length == 1 ? 'file' : 'files'}',
                  subtitle: 'From files picked and never attached. Nothing was removed.',
                ),
            ],
          ),
          const ListEnd(key: ValueKey('files-attention-end')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final android = !isDesktop(context);
    final s = source.snapshot;
    final complete = source.complete;
    final rows = complete
        ? fileRows(s, present: present, checks: checks)
        : const <FileRow>[];
    final summary = FilesSummary(rows);
    final linked = summary.linked.length;
    Widget words(String text) => MoneyAmount(
      complete ? text : null,
      size: MoneySize.tile,
      textAlign: TextAlign.start,
    );
    const labels = ['Attached files', 'On this device', 'Missing', 'Checked'];
    final tiles = <Widget>[
      KpiTile(
        key: const ValueKey('files-attached'),
        labels: labels,
        accent: true,
        icon: Icons.attach_file,
        label: 'Attached files',
        value: words('$linked'),
        caption: complete ? fileSize(summary.totalSize) : null,
      ),
      KpiTile(
        key: const ValueKey('files-here'),
        labels: labels,
        icon: Icons.computer_outlined,
        label: 'On this device',
        value: words('${summary.onDevice} of $linked'),
        caption: complete ? 'Files stay on this device' : null,
      ),
      KpiTile(
        key: const ValueKey('files-missing'),
        labels: labels,
        icon: Icons.warning_amber_rounded,
        label: 'Missing',
        value: words('${summary.missing}'),
        caption: complete ? 'Keep your originals' : null,
      ),
      KpiTile(
        key: const ValueKey('files-checked'),
        labels: labels,
        icon: Icons.verified_outlined,
        label: 'Checked',
        value: words(
          checking
              ? '$checked of $linked'
              : checks.isEmpty
              ? 'Not checked yet'
              : '${summary.verified} verified',
        ),
        caption: !complete
            ? null
            : checking
            ? 'Checking files'
            : 'Check files',
        onTap: complete && linked > 0 && !checking ? checkAll : null,
      ),
    ];
    final list = yourFiles(rows);
    final needs = complete ? attention(summary) : null;
    final backups = OverviewCard(
      key: const ValueKey('files-backups'),
      title: 'What’s in your backups',
      child: Text(
        complete
            ? '${rows.length} ${rows.length == 1 ? 'file' : 'files'} listed, 0 files included. Keep your originals.'
            : 'This shows once your records are complete.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
    return DashboardGrid(
      key: const ValueKey('files-grid'),
      cards: android
          ? null
          : [
              for (final t in tiles) (t, 3, 6),
              (list, needs == null ? 12 : 8, 12),
              ?(needs == null ? null : (needs, 4, 12)),
              (backups, 12, 12),
            ],
      stacked: [...tiles, ?needs, list, backups],
    );
  }
}
