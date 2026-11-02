import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../local/finance_domain.dart';

/// Enforce the limit while reading, even if a provider's reported size is stale.
Future<Uint8List> readBoundedFinancialFile(
  PlatformFile file,
  int maximum,
) async {
  final reported = await file.length();
  if (reported == null || reported < 1 || reported > maximum) {
    reject('This file is too big, or it can’t be read. Choose another.');
  }
  final buffer = BytesBuilder(copy: false);
  var count = 0;
  await for (final bytes in file.readAsByteStream()) {
    count += bytes.length;
    if (count > maximum) {
      reject('This file changed or is too big. Nothing was saved.');
    }
    buffer.add(bytes);
  }
  if (count != reported) {
    reject('This file changed while it was being read. Choose it again.');
  }
  return buffer.takeBytes();
}
