import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import '../local/local_runtime.dart';
import 'bounded_file_read.dart';
import 'file_preview.dart';
import 'file_store.dart';
import 'files_data.dart';

const _channel = MethodChannel('salapiya/open_file');

/// Sharp enough to zoom into; wider images are scaled down to this.
const previewDecodeWidth = 4096;

/// How long a copy stays for the app reading it.
const _openedFor = Duration(minutes: 10);

Future<Directory> _openedFolder() async =>
    Directory(p.join((await getTemporaryDirectory()).path, 'salapiya-open'));

Future<void> _remove(Directory folder) async {
  try {
    if (await folder.exists()) await folder.delete(recursive: true);
  } on FileSystemException {
    // The app reading it still has it open; the next start clears it.
  }
}

/// Another app can't read Salapiya's encrypted store, so opening a file there
/// needs a plain copy. Each one goes in a private temporary folder and is
/// removed after [_openedFor]. Anything left, say after a crash, goes here,
/// when the app starts.
Future<void> clearOpenedCopies() async {
  try {
    await _remove(await _openedFolder());
  } catch (_) {
    // Startup never fails over this; the next start tries again.
  }
}

/// A copy's name: the file's own, in safe characters, with the extension of
/// the type its contents were checked to be. The stored name never decides
/// what the system runs.
String openedName(String title, String? mime) {
  final base = p
      .basenameWithoutExtension(title)
      .replaceAll(RegExp(r'[^\w .-]'), '_')
      .trim();
  final extension = switch (mime) {
    'application/pdf' => '.pdf',
    'image/jpeg' => '.jpg',
    'image/png' => '.png',
    _ => reject('This file can’t be read here. Keep your original.'),
  };
  return '${base.isEmpty ? 'file' : base}$extension';
}

/// A real profile's files. Same store, draft and command as ever: a picked
/// file is saved encrypted and kept as a draft before the review, so a file
/// that's picked is never lost to a closed page.
class LocalFileAccess implements FileAccess {
  LocalFileAccess(this.session);
  final LocalSession session;

  static const operation = 'files:attach';

  late final c = session.localFinance;
  late final files = FinancialFileStore(
    c.store,
    Directory(
      p.join(
        session.runtime.profiles.directory.path,
        '${c.store.owner}.attachments',
      ),
    ),
    () async {
      final raw = await session.runtime.profiles.vault.read();
      if (raw == null) {
        reject(
          'This profile’s file key isn’t available. Your files are safe. Reopen your profile.',
        );
      }
      final descriptor = jsonDecode(raw) as Map;
      if (descriptor['id'] != c.store.owner) {
        reject('This file key belongs to another profile.');
      }
      return descriptor['key'] as String;
    },
  );

  void _tell(ScaffoldMessengerState messenger, String words) =>
      messenger.showSnackBar(SnackBar(content: Text(words)));

  /// Runs an action, saying what went wrong in place of a false success.
  Future<void> _run(
    BuildContext context,
    Future<String?> Function() work,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final done = await work();
      if (done != null) _tell(messenger, done);
    } on LocalRuleException catch (e) {
      _tell(messenger, e.message);
    } catch (_) {
      _tell(messenger, 'That didn’t work. Nothing was changed.');
    }
  }

  @override
  Future<bool> present(String id) => files.present(id);

  @override
  Future<String?> check(LocalRevision file) async {
    if (financialFileDetached(c.snapshot, file.id)) return null;
    try {
      await files.readMetadata(file.id, file.values);
      return null;
    } on LocalRuleException catch (e) {
      return e.message;
    } catch (_) {
      return 'This file couldn’t be checked.';
    }
  }

  @override
  Future<List<String>> leftovers() => files.orphans();

  @override
  Future<FileSelection?> selection() async {
    final saved = await c.store.draft(operation);
    return saved == null
        ? null
        : FileSelection(
            saved['command'] as String,
            Map<String, String>.from(saved['values'] as Map),
          );
  }

  @override
  Future<bool> attach(BuildContext context, String source) async {
    final before = c.snapshot.current.length;
    await _pick(context, source);
    return c.snapshot.current.length > before;
  }

  Future<void> _pick(BuildContext context, String source) =>
      _run(context, () async {
        if (await selection() != null) {
          reject('Finish or let go of the file you already picked first.');
        }
        final picked = await FilePicker.pickFile();
        if (picked == null) return null;
        final length = await picked.length();
        if (length == null ||
            length < 1 ||
            length > FinancialFileStore.maxBytes) {
          reject('Choose a PDF, JPEG or PNG file up to 10 MB.');
        }
        final bytes = await readBoundedFinancialFile(
              picked,
              FinancialFileStore.maxBytes,
            ),
            name = p.basename(picked.name),
            mime = FinancialFileStore.validateFormat(name, bytes),
            id = newLocalId();
        final values = {
          'name': name,
          'date': civilToday(),
          'sourceRevision': source,
          'mime': mime,
          'size': '${bytes.length}',
          'checksum': sha256.convert(bytes).toString(),
        };
        await c.store.saveDraft(operation, id, values);
        await files.write(id, values, bytes);
        if (!context.mounted) return null;
        return _finish(context, id, values);
      });

  Future<String?> _finish(
    BuildContext context,
    String id,
    Map<String, String> values,
  ) async {
    await files.readMetadata(id, values);
    await c.reload();
    final old = await c.store.db.getAll(
      'SELECT payload FROM local_command WHERE id=? UNION ALL SELECT payload FROM connected_intent WHERE id=?',
      [id, id],
    );
    final command = old.isEmpty
        ? LocalCommand(
            id: id,
            owner: c.store.owner,
            expectedVersion: c.snapshot.version,
            kind: 'financialFile',
            values: values,
          )
        : LocalCommand.decode(id, old.first['payload'] as String);
    final plan = planLocal(
      c.snapshot,
      LocalCommand(
        id: command.id,
        owner: command.owner,
        expectedVersion: c.snapshot.version,
        kind: command.kind,
        values: command.values,
      ),
    );
    if (!context.mounted) return null;
    final accepted = await showAppDialog<bool>(
      context,
      title: 'Attach this file?',
      primary: const ModalAction('Attach file', value: true),
      secondary: const ModalAction('Keep for later'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FactRow('File', values['name']!),
          FactRow(
            'Type',
            '${fileType(values['mime'])} · ${fileSize(int.parse(values['size']!))}',
          ),
          const SizedBox(height: Space.sm),
          InlineNotice(
            'Not virus-scanned. Its name and format don’t show it’s safe.',
            tone: NoticeTone.warning,
          ),
          const SizedBox(height: Space.sm),
          for (final note in plan.effects) Text(note),
        ],
      ),
    );
    if (accepted != true) {
      return 'Kept for later. It isn’t attached yet.';
    }
    await c.store.commit(command);
    await c.reload();
    return c.connected
        ? 'Attached. The file stays on this device, and its details are waiting to sync.'
        : 'Attached. The file stays on this device.';
  }

  @override
  Future<void> resume(BuildContext context, FileSelection selection) =>
      _run(context, () => _finish(context, selection.id, selection.values));

  @override
  Future<void> reselect(BuildContext context, FileSelection selection) =>
      _run(context, () async {
        final picked = await FilePicker.pickFile();
        if (picked == null) return null;
        final length = await picked.length();
        if (length == null || length > FinancialFileStore.maxBytes) {
          reject('Choose the same file, up to 10 MB.');
        }
        final bytes = await readBoundedFinancialFile(
          picked,
          FinancialFileStore.maxBytes,
        );
        await files.write(selection.id, selection.values, bytes);
        if (!context.mounted) return null;
        return _finish(context, selection.id, selection.values);
      });

  @override
  Future<void> release(BuildContext context, FileSelection selection) =>
      _run(context, () async {
        await c.store.discardDraft(operation);
        return 'Let go. Its saved copy stays on this device.';
      });

  @override
  Future<void> preview(
    BuildContext context,
    LocalRevision file,
  ) => _run(context, () async {
    final bytes = await files.read(file.id);
    if (file.values['mime'] == 'application/pdf') {
      reject('PDFs don’t open here. Open it in another app.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    int width;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      width = descriptor.width;
      if (width > 20000 ||
          descriptor.height > 20000 ||
          width * descriptor.height > 40000000) {
        reject('This image is too large to show here. Open it in another app.');
      }
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
    if (!context.mounted) return null;
    final size = previewSize(context);
    final problem = ValueNotifier<String?>(null);
    await showAppDialog<void>(
      context,
      title: file.title,
      maxWidth: size.width,
      primary: ModalAction(
        'Open in another app',
        onPressed: () async {
          problem.value = await _open(file);
          return false;
        },
      ),
      secondary: const ModalAction('Close'),
      body: ImagePreview(
        bytes: bytes,
        decodeWidth: width > previewDecodeWidth ? previewDecodeWidth : width,
        height: size.height,
        problem: problem,
        note:
            'Not virus-scanned. The check only shows the file hasn’t changed.',
      ),
    );
    problem.dispose();
    return null;
  });

  @override
  Future<void> openElsewhere(BuildContext context, LocalRevision file) =>
      _run(context, () => _open(file));

  /// Writes a plain copy where another app can read it, and opens it. Null
  /// once it's opened; otherwise what went wrong. See [clearOpenedCopies].
  Future<String?> _open(LocalRevision file) async {
    final bytes = await files.read(file.id);
    final folder = Directory(
      p.join((await _openedFolder()).path, newLocalId()),
    );
    await folder.create(recursive: true);
    final copy = File(
      p.join(folder.path, openedName(file.title, file.values['mime'])),
    );
    await copy.writeAsBytes(bytes, flush: true);
    Timer(_openedFor, () => unawaited(_remove(folder)));
    final opened = Platform.isWindows
        ? await _openOnWindows(copy)
        : await _channel.invokeMethod<bool>('open', {
                'path': copy.path,
                'mime': file.values['mime'],
              }) ??
              false;
    if (opened) return null;
    await _remove(folder);
    return 'No app on this device can open this file.';
  }

  Future<bool> _openOnWindows(File copy) async {
    await Process.start('explorer.exe', [copy.path]);
    return true;
  }

  @override
  Future<void> saveCopy(
    BuildContext context,
    LocalRevision file,
  ) => _run(context, () async {
    final bytes = await files.read(file.id);
    final uri = await FilePicker.saveFile(fileName: file.title, bytes: bytes);
    return uri == null
        ? 'Copy cancelled.'
        : 'Copy saved. It isn’t virus-scanned, so open it in an app you trust.';
  });

  @override
  Future<void> restore(
    BuildContext context,
    LocalRevision file,
  ) => _run(context, () async {
    if (financialFileDetached(c.snapshot, file.id)) {
      reject(
        'This file’s link is archived. Attach your original again to link it.',
      );
    }
    final picked = await FilePicker.pickFile();
    if (picked == null) return null;
    final bytes = await readBoundedFinancialFile(
      picked,
      FinancialFileStore.maxBytes,
    );
    await files.write(file.id, file.values, bytes);
    return 'Restored from your original.';
  });

  @override
  Future<void> removeCopy(
    BuildContext context,
    LocalRevision file,
  ) => _run(context, () async {
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
    if (yes != true) return null;
    await files.removeLocalCopy(file.id);
    return 'Removed from this device. Its details stay, and it shows as Missing.';
  });
}
