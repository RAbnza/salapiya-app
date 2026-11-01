import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../finance/bounded_file_read.dart';
import '../finance/file_access.dart' show openPlainCopy, previewImage;
import '../finance/file_store.dart';
import '../finance/files_data.dart' show fileSize, fileType;
import '../local/finance_domain.dart';
import '../local/local_runtime.dart';
import '../local/local_store.dart';
import '../prototype/scenarios.dart';
import 'career_pages.dart' show openLifeApplication;
import 'life_controller.dart';
import 'life_data.dart';
import 'life_domain.dart';
import 'life_hub.dart';

/// A saved draft's file name, for Saved drafts.
String? documentDraftName(Map<String, String> values) {
  try {
    final body = jsonDecode(values['payload'] ?? '') as Map;
    return (body['fields'] as Map)['title'] as String?;
  } catch (_) {
    return null;
  }
}

/// Opens the application a half-attached file belongs to. False when it's gone.
Future<bool> openDocumentDraft(
  BuildContext context,
  PrototypeSession session,
  Map<String, String> values,
) async {
  try {
    final body = jsonDecode(values['payload'] ?? '') as Map;
    final id = (body['fields'] as Map)['application'] as String?;
    final writer = lifeSource(context, session).writer;
    if (writer.record(id) is! ApplicationRecord) return false;
    openLifeApplication(context, session, id!);
    return true;
  } catch (_) {
    return false;
  }
}

/// Discarding a half-attached file's draft takes its encrypted copy too, or
/// nothing could ever reach it again.
Future<void> forgetDocumentDraft(
  PrototypeSession? session,
  String operation,
) async {
  if (session is! LocalSession) return;
  await LocalLifeDocuments.of(
    session,
  ).remove(operation.substring('life-document:'.length));
}

/// A real profile's Career documents: the same encrypted store, draft and
/// command as ever. Only a document's details sync; the file stays here.
class LocalLifeDocuments implements LifeDocuments {
  LocalLifeDocuments(this.c, this.files);

  factory LocalLifeDocuments.of(LocalSession session) {
    final c = session.life as DurableLifeController;
    return LocalLifeDocuments(
      c,
      FinancialFileStore(
        c.store,
        Directory(
          p.join(
            session.runtime.profiles.directory.path,
            '${c.store.owner}.career-attachments',
          ),
        ),
        () async {
          final raw = await session.runtime.profiles.vault.read();
          if (raw == null) {
            lifeReject(
              'This profile’s file key isn’t available. Your files are safe. Reopen your profile.',
            );
          }
          final descriptor = jsonDecode(raw) as Map;
          if (descriptor['id'] != c.store.owner) {
            lifeReject('This file belongs to another profile.');
          }
          return descriptor['key'] as String;
        },
      ),
    );
  }

  final DurableLifeController c;
  final FinancialFileStore files;

  static const _prefix = 'life-document:';
  static const _attached = 'Attached private Career document metadata';

  @override
  bool get demo => false;
  @override
  Future<bool> present(String id) => files.present(id);

  /// The file the user chooses, or null when they don't.
  Future<(String, Uint8List)?> pick() async {
    final picked = await FilePicker.pickFile();
    if (picked == null) return null;
    final bytes = await readBoundedFinancialFile(
      picked,
      FinancialFileStore.maxBytes,
    );
    return (p.basename(picked.name), bytes);
  }

  ApplicationRecord _application(String id) {
    final app = c.records[id];
    if (app is! ApplicationRecord) {
      lifeReject('This application isn’t here any more.');
    }
    return app;
  }

  LifeCommand _command(
    ApplicationRecord app,
    String name,
    List<int> bytes,
    String mime,
  ) => LifeCommand(
    owner: c.store.owner,
    recordId: newLocalId(),
    type: LifeType.document,
    expectedVersion: 0,
    fields: {
      'title': name,
      'application': app.id,
      'sourceVersion': '${app.version}',
      'mime': mime,
      'size': '${bytes.length}',
      'checksum': sha256.convert(bytes).toString(),
    },
    reason: _attached,
  );

  CareerDocumentRecord _record(LifeCommand c) =>
      LifeRecord.read(c.recordId, c.owner, 1, LifeType.document, c.fields)
          as CareerDocumentRecord;

  /// Keeps the encrypted file and a draft first, so an interrupted link leaves
  /// something to finish, never a record of a file that isn't there.
  Future<String> _link(LifeCommand command, List<int> bytes) async {
    final operation = '$_prefix${command.recordId}';
    await c.store.saveDraft(operation, command.id, {
      'payload': command.payload,
    });
    await files.write(
      command.recordId,
      _record(command).fileMetadata,
      bytes,
    );
    await c.store.commitLife(command, draft: operation);
    await c.reload();
    return 'Attached. The file stays on this device, and only its details sync.';
  }

  @override
  Future<String?> attach(BuildContext context, String application) async {
    final app = _application(application);
    final picked = await pick();
    if (picked == null) return null;
    final (name, bytes) = picked;
    final mime = FinancialFileStore.validateFormat(name, bytes);
    final command = _command(app, name, bytes, mime);
    if (!context.mounted) return null;
    final yes = await showAppDialog<bool>(
      context,
      title: 'Attach this file?',
      primary: const ModalAction('Attach file', value: true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FactRow('File', name),
          FactRow('Type', '${fileType(mime)} · ${fileSize(bytes.length)}'),
          const SizedBox(height: Space.sm),
          const InlineNotice(
            'Not virus-scanned. Its name and format don’t show it’s safe.',
            tone: NoticeTone.warning,
          ),
          const SizedBox(height: Space.sm),
          const Text(
            'It’s encrypted on this device. Only its details sync, and backups don’t hold files, so keep your original.',
          ),
        ],
      ),
    );
    if (yes != true) return null;
    return _link(command, bytes);
  }

  @override
  Future<List<PendingDocument>> pending(String application) async {
    final out = <PendingDocument>[];
    for (final row in await c.store.drafts()) {
      final operation = row['operation'] as String;
      if (!operation.startsWith(_prefix)) continue;
      final command = LifeCommand.decode(
        row['command_id'] as String,
        (jsonDecode(row['values_json'] as String) as Map)['payload'] as String,
      );
      if (command.fields['application'] != application) continue;
      final app = c.records[application];
      out.add(
        PendingDocument(
          operation,
          command,
          stale:
              app is ApplicationRecord &&
              '${app.version}' != command.fields['sourceVersion'],
        ),
      );
    }
    return out;
  }

  /// A file's encryption is tied to the application's version. If that moved
  /// on, the file is read back and linked afresh, so nothing has to be chosen
  /// again and the draft can't get stuck.
  @override
  Future<String?> finish(PendingDocument pending) async {
    final record = _record(pending.command);
    final bytes = await files.readMetadata(record.id, record.fileMetadata);
    if (!pending.stale) {
      await c.store.commitLife(pending.command, draft: pending.operation);
      await c.reload();
      return 'Attached. The file stays on this device, and only its details sync.';
    }
    final fresh = _command(
      _application(pending.command.fields['application']!),
      record.title,
      bytes,
      record.fields['mime']!,
    );
    final done = await _link(fresh, bytes);
    await remove(record.id);
    await c.store.discardDraft(pending.operation);
    return done;
  }

  @override
  Future<String?> letGo(PendingDocument pending) async {
    await remove(pending.command.recordId);
    await c.store.discardDraft(pending.operation);
    return 'Let go. Nothing was attached.';
  }

  /// Deletes this device's encrypted file. The record, if any, stays.
  Future<void> remove(String id) async {
    final file = files.object(id);
    if (await file.exists()) await file.delete();
  }

  Future<Uint8List> _bytes(CareerDocumentRecord r) =>
      files.readMetadata(r.id, r.fileMetadata);

  @override
  Future<String?> preview(BuildContext context, CareerDocumentRecord r) async {
    final bytes = await _bytes(r);
    if (!context.mounted) return null;
    await previewImage(
      context,
      title: r.title,
      mime: r.fields['mime'],
      bytes: bytes,
      open: () => openPlainCopy(r.title, r.fields['mime'], bytes),
    );
    return null;
  }

  @override
  Future<String?> openElsewhere(CareerDocumentRecord r) async =>
      openPlainCopy(r.title, r.fields['mime'], await _bytes(r));

  @override
  Future<String?> saveCopy(CareerDocumentRecord r) async {
    final uri = await FilePicker.saveFile(
      fileName: r.title,
      bytes: await _bytes(r),
    );
    return uri == null
        ? 'Copy cancelled.'
        : 'Copy saved. It isn’t virus-scanned, so open it in an app you trust.';
  }

  @override
  Future<String?> restore(CareerDocumentRecord r) async {
    final picked = await pick();
    if (picked == null) return null;
    await files.write(r.id, r.fileMetadata, picked.$2);
    return 'Restored from your original.';
  }

  @override
  Future<String?> removeCopy(CareerDocumentRecord r) async {
    await remove(r.id);
    return 'Removed from this device. Its details stay, and you can restore it from your original.';
  }
}

/// An application's documents. A file is private to this device, so the card
/// says which are here, and offers only what can work on each.
class LifeDocumentsCard extends StatefulWidget {
  const LifeDocumentsCard({
    super.key,
    required this.source,
    required this.documents,
    required this.application,
    required this.archived,
  });
  final LifeSource source;
  final LifeDocuments documents;
  final String application;

  /// The application is archived, so nothing new goes on it.
  final bool archived;
  @override
  State<LifeDocumentsCard> createState() => _LifeDocumentsCardState();
}

class _LifeDocumentsCardState extends State<LifeDocumentsCard> {
  Map<String, bool> here = const {};
  List<PendingDocument> waiting = const [];
  bool busy = false, showArchived = false;
  String? problem, note;

  LifeDocuments get documents => widget.documents;
  List<CareerDocumentRecord> get rows =>
      careerDocuments(widget.source.records, widget.application);

  /// What the rows depend on: a new version reloads them.
  String get versions =>
      rows.map((r) => '${r.id}:${r.version}').join(',');

  @override
  void initState() {
    super.initState();
    // Reading storage can notify the page, so it waits for the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  @override
  void didUpdateWidget(LifeDocumentsCard old) {
    super.didUpdateWidget(old);
    final before = careerDocuments(old.source.records, old.application)
        .map((r) => '${r.id}:${r.version}')
        .join(',');
    if (before != versions) {
      WidgetsBinding.instance.addPostFrameCallback((_) => load());
    }
  }

  Future<void> load() async {
    try {
      final pending = await documents.pending(widget.application);
      final present = {
        for (final r in rows) r.id: await documents.present(r.id),
      };
      if (mounted) {
        setState(() {
          waiting = pending;
          here = present;
        });
      }
    } catch (_) {
      // The rows still show; what can't be read just says so.
    }
  }

  /// One action at a time, and its result stays on the card.
  Future<void> run(Future<String?> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      problem = note = null;
    });
    try {
      note = await work();
    } on FormatException catch (e) {
      problem = e.message;
    } on LocalRuleException catch (e) {
      problem = e.message;
    } catch (_) {
      problem = 'That didn’t work. Nothing was changed.';
    }
    await load();
    if (mounted) setState(() => busy = false);
  }

  Future<String?> change(
    CareerDocumentRecord r,
    String archived,
    String reason,
  ) async {
    await widget.source.writer.change(r.id, r.version, {
      'archived': archived,
    }, reason);
    return widget.source.writer.demo
        ? 'This is the demo, so nothing was saved.'
        : null;
  }

  Future<void> archive(CareerDocumentRecord r) async {
    final yes = await showAppDialog<bool>(
      context,
      title: 'Archive this link?',
      body: const Text(
        'It leaves this application’s documents. The file stays on this device, its history stays, and you can restore the link.',
      ),
      primary: const ModalAction('Archive link', value: true),
    );
    if (yes == true) {
      await run(() => change(r, 'true', 'Archived private document link'));
    }
  }

  Future<void> removeCopy(CareerDocumentRecord r) async {
    final yes = await showAppDialog<bool>(
      context,
      title: 'Remove this file from your device?',
      body: const Text(
        'Salapiya keeps its details, but not the file. There’s no cloud copy and backups don’t include files, so keep your original first.',
      ),
      primary: const ModalAction(
        'Remove from this device',
        value: true,
        destructive: true,
      ),
    );
    if (yes == true) await run(() => documents.removeCopy(r));
  }

  Future<void> letGo(PendingDocument pending) async {
    final yes = await showAppDialog<bool>(
      context,
      title: 'Let go of this file?',
      body: const Text(
        'It was never attached, so nothing else changes. Its encrypted copy goes from this device, and your original stays where it is.',
      ),
      primary: const ModalAction('Let go', value: true),
    );
    if (yes == true) await run(() => documents.letGo(pending));
  }

  Widget menu(CareerDocumentRecord r, bool onDevice) {
    MenuItemButton item(
      String key,
      String label,
      IconData icon,
      VoidCallback go,
    ) => MenuItemButton(
      key: ValueKey('life-document-$key-${r.id}'),
      leadingIcon: Icon(icon),
      onPressed: busy ? null : go,
      child: Text(label),
    );
    final image = r.fields['mime'] != 'application/pdf';
    return CardMenu(
      key: ValueKey('life-document-menu-${r.id}'),
      tooltip: 'File options',
      items: [
        if (onDevice && image && !r.archived)
          item(
            'preview',
            'Preview',
            Icons.visibility_outlined,
            () => run(() => documents.preview(context, r)),
          ),
        if (onDevice && !r.archived)
          item(
            'open',
            'Open in another app',
            Icons.open_in_new,
            () => run(() => documents.openElsewhere(r)),
          ),
        if (onDevice)
          item(
            'save',
            'Save a copy',
            Icons.download_outlined,
            () => run(() => documents.saveCopy(r)),
          ),
        if (!onDevice && !r.archived)
          item(
            'restore',
            'Restore from your original',
            Icons.upload_file_outlined,
            () => run(() => documents.restore(r)),
          ),
        if (onDevice)
          item(
            'remove',
            'Remove from this device',
            Icons.delete_outline,
            () => removeCopy(r),
          ),
        if (r.archived)
          item(
            'unarchive',
            'Restore link',
            Icons.restore,
            () => run(
              () => change(
                r,
                'false',
                'Restored document link; byte presence unchanged',
              ),
            ),
          )
        else
          item(
            'archive',
            'Archive link',
            Icons.archive_outlined,
            () => archive(r),
          ),
      ],
    );
  }

  Widget row(CareerDocumentRecord r) {
    final onDevice = here[r.id] ?? false;
    return AdaptiveRow(
      key: ValueKey('life-document-${r.id}'),
      title: r.title,
      subtitle: detailLine([
        fileType(r.fields['mime']),
        fileSize(int.parse(r.fields['size']!)),
        if (here.containsKey(r.id))
          onDevice ? 'On this device' : 'Not on this device',
      ]),
      trailing: menu(r, onDevice),
      pill: r.archived
          ? const StatusPill('Archived', icon: Icons.archive_outlined)
          : null,
      narrowBelow: Space.xxxl * 3,
    );
  }

  Widget pendingRow(PendingDocument pending) {
    final text = Theme.of(context).textTheme;
    return Padding(
      key: ValueKey('life-document-pending-${pending.command.recordId}'),
      padding: const EdgeInsets.symmetric(
        horizontal: ListRow.horizontalPadding,
        vertical: Space.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(pending.name, style: text.bodyMedium),
          const SizedBox(height: Space.xxs),
          Text(
            'Not attached yet',
            style: text.bodySmall?.copyWith(
              color: CraftTheme.of(context).secondary,
            ),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: Space.md,
            children: [
              CardLink(
                'Let go',
                key: ValueKey(
                  'life-document-letgo-${pending.command.recordId}',
                ),
                chevron: false,
                onPressed: () => letGo(pending),
              ),
              CardLink(
                'Finish attaching',
                key: ValueKey(
                  'life-document-finish-${pending.command.recordId}',
                ),
                chevron: false,
                onPressed: () => run(() => documents.finish(pending)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(
      color: CraftTheme.of(context).secondary,
    );
    final active = [
      for (final r in rows)
        if (!r.archived) r,
    ];
    final archived = [
      for (final r in rows)
        if (r.archived) r,
    ];
    final shown = [...active, if (showArchived) ...archived];
    return OverviewCard(
      key: const ValueKey('life-application-documents'),
      title: 'Documents',
      caption: 'Private files, on this device only',
      trailing: widget.archived
          ? null
          : CardLink(
              'Attach a file',
              key: const ValueKey('life-document-attach'),
              onPressed: () =>
                  run(() => documents.attach(context, widget.application)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (problem != null) ...[
            InlineNotice(problem!, tone: NoticeTone.error, live: true),
            const SizedBox(height: Space.sm),
          ],
          if (note != null) ...[
            InlineNotice(note!, live: true),
            const SizedBox(height: Space.sm),
          ],
          for (final pending in waiting) pendingRow(pending),
          if (shown.isEmpty && waiting.isEmpty)
            Text(
              widget.archived
                  ? 'No files on this application.'
                  : 'Résumés and letters you sent can go here.',
              style: text.bodyMedium,
            )
          else if (shown.isNotEmpty)
            ListGroup(children: [for (final r in shown) row(r)]),
          if (archived.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: CardLink(
                showArchived
                    ? 'Hide archived'
                    : 'Show archived (${archived.length})',
                key: const ValueKey('life-document-archived'),
                chevron: false,
                onPressed: () => setState(() => showArchived = !showArchived),
              ),
            ),
          const SizedBox(height: Space.sm),
          Text(
            'Not virus-scanned. Backups don’t hold files, so keep your originals.',
            style: muted,
          ),
        ],
      ),
    );
  }
}
