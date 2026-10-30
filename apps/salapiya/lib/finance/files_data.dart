import 'package:flutter/widgets.dart' show BuildContext;

import '../local/finance_domain.dart';
import 'money_data.dart' show moneyLabel, recordTitle;

/// Display-only derivations for Files (DESIGN_SYSTEM §8, Chat 9), and what the
/// screens can ask of a profile's files. What's on the device is read through
/// [FileAccess], so a tab never touches storage.

/// A file picked but not attached yet.
class FileSelection {
  const FileSelection(this.id, this.values);
  final String id;
  final Map<String, String> values;
  String get name => values['name'] ?? 'A file';
}

/// What the Files screens can do with a profile's files. A real profile reads
/// its encrypted store; the demo has no store, so its answers are fixed and
/// its actions open a placeholder.
abstract class FileAccess {
  Future<bool> present(String id);

  /// Reads the file through and compares it with what was attached. Null when
  /// it passes; otherwise what's wrong. Changes nothing.
  Future<String?> check(LocalRevision file);

  /// Files on this device that no record names.
  Future<List<String>> leftovers();
  Future<FileSelection?> selection();
  Future<void> preview(BuildContext context, LocalRevision file);

  /// Opens the file in the app the device uses for its type.
  Future<void> openElsewhere(BuildContext context, LocalRevision file);
  Future<void> saveCopy(BuildContext context, LocalRevision file);
  Future<void> restore(BuildContext context, LocalRevision file);
  Future<void> removeCopy(BuildContext context, LocalRevision file);

  /// Picks a file for [source], then reviews and attaches it. True once it's
  /// attached.
  Future<bool> attach(BuildContext context, String source);

  /// Finishes attaching a file already picked.
  Future<void> resume(BuildContext context, FileSelection selection);

  /// Picks the same file again, when its saved copy is gone.
  Future<void> reselect(BuildContext context, FileSelection selection);

  /// Lets go of a selection. Its saved copy stays.
  Future<void> release(BuildContext context, FileSelection selection);
}

/// Where a file stands, in the words the screens use.
enum FileState {
  here('On this device'),
  missing('Missing'),
  archived('Link archived'),
  unknown('Checking');

  const FileState(this.label);
  final String label;
}

String fileType(String? mime) => switch (mime) {
  'application/pdf' => 'PDF',
  'image/jpeg' => 'JPEG',
  'image/png' => 'PNG',
  _ => 'File',
};

/// A size for the eye: whole bytes, then one decimal of KB or MB.
String fileSize(int bytes) {
  const kb = 1024, mb = 1024 * 1024;
  if (bytes < kb) return '$bytes bytes';
  String one(double v) => v.toStringAsFixed(1);
  return bytes < mb ? '${one(bytes / kb)} KB' : '${one(bytes / mb)} MB';
}

/// One attached file, as the lists show it.
class FileRow {
  FileRow(
    this.record, {
    required this.attachedTo,
    required this.attachedLabel,
    required this.archived,
    required this.present,
    required this.problem,
    required this.verified,
  });
  final LocalRevision record;
  final String attachedTo, attachedLabel;
  final bool archived;

  /// Null until it's been looked for.
  final bool? present;

  /// What a check found wrong, if one ran and failed.
  final String? problem;
  final bool verified;

  String get id => record.id;
  String get name => record.title;
  String get type => fileType(record.values['mime']);
  int get size => int.tryParse(record.values['size'] ?? '') ?? 0;
  String get added => record.date;
  bool get image => record.values['mime'] != 'application/pdf';
  FileState get state => archived
      ? FileState.archived
      : present == null
      ? FileState.unknown
      : present!
      ? FileState.here
      : FileState.missing;
  bool get missing => state == FileState.missing;
}

/// Every attachment, newest first. [present] and the check results come from
/// [FileAccess].
List<FileRow> fileRows(
  LocalSnapshot s, {
  Map<String, bool> present = const {},
  Map<String, String?> checks = const {},
}) {
  final rows = <FileRow>[
    for (final r in s.current.where((r) => financeType(r) == 'financialFile'))
      () {
        final source = s.revisions
            .where((x) => x.id == r.values['sourceRevision'])
            .firstOrNull;
        return FileRow(
          r,
          attachedTo: source == null ? 'A record' : recordTitle(source),
          attachedLabel: source == null ? '' : moneyLabel(source),
          archived: financialFileDetached(s, r.id),
          present: present[r.id],
          problem: checks[r.id],
          verified: checks.containsKey(r.id) && checks[r.id] == null,
        );
      }(),
  ];
  return rows..sort((a, b) => b.added.compareTo(a.added));
}

/// What the Files tiles say, about files still linked to a record.
class FilesSummary {
  FilesSummary(this.rows);
  final List<FileRow> rows;
  List<FileRow> get linked => rows.where((r) => !r.archived).toList();
  int get totalSize => linked.fold(0, (sum, r) => sum + r.size);
  int get onDevice => linked.where((r) => r.state == FileState.here).length;
  int get missing => linked.where((r) => r.missing).length;
  int get verified => linked.where((r) => r.verified).length;
  List<FileRow> get failed =>
      linked.where((r) => r.problem != null && !r.missing).toList();
}
