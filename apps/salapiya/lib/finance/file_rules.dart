part of '../local/finance_domain.dart';

const nativeFileCommands = {'financialFile', 'fileDetach'};
bool financialFileDetached(LocalSnapshot s, String id) => s.current.any(
  (r) => financeType(r) == 'fileDetach' && r.values['file'] == id,
);
LocalPlan planFinancialFile(LocalSnapshot s, LocalCommand command) {
  final v = Map<String, String>.from(command.values),
      op = command.kind,
      date = civilDate(v['date'] ?? '');
  final title = (v['name'] ?? '').trim();
  if (title.isEmpty || title.length > 200) {
    reject('Enter a file name of up to 200 characters.');
  }
  String? source;
  if (op == 'financialFile') {
    if (!['application/pdf', 'image/jpeg', 'image/png'].contains(v['mime']) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(v['checksum'] ?? '')) {
      reject('Choose a PDF, JPEG or PNG file.');
    }
    final size = parseMinor(v['size'] ?? '');
    if (size <= BigInt.zero ||
        size > BigInt.from(10 * 1024 * 1024) ||
        RegExp(r'[\\/:\x00-\x1f\x7f]').hasMatch(title)) {
      reject('This file’s name can’t be used, or it’s over 10 MB.');
    }
    final original = s.revision(v['sourceRevision'] ?? '');
    if (nativeFileCommands.contains(financeType(original)) ||
        [
          'cashImport',
          'cashImportChunk',
          'cashImportPreview',
          'cashImportDecision',
          'cashImportProcess',
          'cashImportCancel',
        ].contains(financeType(original))) {
      reject(
        'Attach files to a transaction or other record, not to a file or an import.',
      );
    }
    final files = s.current.where(
      (r) =>
          financeType(r) == 'financialFile' && !financialFileDetached(s, r.id),
    );
    if (files.length >= 1000 ||
        sumMinor(files.map((r) => parseMinor(r.values['size']!))) + size >
            BigInt.from(1024 * 1024 * 1024)) {
      reject(
        'You’ve reached the limit of 1,000 files or 1 GB. Archive a file link to make room.',
      );
    }
    source = original.id;
    v.addAll({
      'cloudState': 'unavailable_unscanned',
      'byteCoverage': 'device-local-only',
      'sourceKind': financeType(original),
    });
  } else if (op == 'fileDetach') {
    final file = financeSource(s, v['file'] ?? '', {'financialFile'});
    if (financialFileDetached(s, file.id) ||
        (v['reason'] ?? '').trim().isEmpty) {
      reject('Choose an attached file and say why you’re archiving its link.');
    }
    source = file.id;
  } else {
    reject('Unsupported supporting-file command.');
  }
  v.addAll({'financeType': op, 'financeContract': '1'});
  return LocalPlan(
    revision: LocalRevision(
      id: command.id,
      actionId: command.id,
      kind: 'adjustment',
      change: 'create',
      date: date,
      title: title,
      amount: BigInt.zero,
      values: v,
      postings: const [],
      number: 1,
      source: source,
    ),
    effects: [
      'This attaches a file. No money or records change.',
      'The file stays on this device. It isn’t uploaded or virus-scanned.',
    ],
  );
}
