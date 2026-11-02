import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../local/finance_domain.dart';
import '../local/local_store.dart';

class FinancialFileStore {
  FinancialFileStore(this.store, this.directory, this.databaseKey);
  final LocalStore store;
  final Directory directory;
  final Future<String> Function() databaseKey;
  static final cipher = AesGcm.with256bits();
  static final header = utf8.encode('SALAPIYA-FINANCIAL-FILE-1\n');
  static const maxBytes = 10 * 1024 * 1024;
  File object(String id) {
    if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(id)) {
      reject('Invalid private file identity.');
    }
    return File(p.join(directory.path, '$id.sfp'));
  }

  Future<SecretKey> key() async {
    final bytes = base64Url.decode(await databaseKey());
    if (bytes.length != 32) {
      reject(
        'This profile’s file key isn’t available. Your files are safe. Reopen your profile.',
      );
    }
    return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(bytes),
      info: utf8.encode('Salapiya financial files v1:${store.owner}'),
    );
  }

  List<int> aad(String id, Map<String, String> v) => utf8.encode(
    jsonEncode([
      store.owner,
      id,
      v['mime'],
      v['size'],
      v['checksum'],
      v['name'],
      v['sourceRevision'],
    ]),
  );
  static String validateFormat(String name, List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      reject('Choose a file that isn’t empty, up to 10 MB.');
    }
    final extension = p.extension(name).toLowerCase();
    final pdf =
        bytes.length >= 8 &&
        ascii.decode(bytes.take(5).toList(), allowInvalid: true) == '%PDF-';
    final jpeg =
        bytes.length >= 4 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    final png =
        bytes.length >= 24 &&
        List.generate(
          8,
          (i) => bytes[i] == [137, 80, 78, 71, 13, 10, 26, 10][i],
        ).every((v) => v);
    if (extension == '.pdf' && pdf) return 'application/pdf';
    if (['.jpg', '.jpeg'].contains(extension) && jpeg) return 'image/jpeg';
    if (extension == '.png' && png) return 'image/png';
    reject(
      'This file’s name and contents don’t match. Choose a real PDF, JPEG or PNG.',
    );
  }

  Future<void> write(
    String id,
    Map<String, String> metadata,
    List<int> bytes,
  ) async {
    if (validateFormat(metadata['name']!, bytes) != metadata['mime'] ||
        '${bytes.length}' != metadata['size'] ||
        sha256.convert(bytes).toString() != metadata['checksum']) {
      reject('This isn’t the same file. Choose the original.');
    }
    await directory.create(recursive: true);
    final target = object(id);
    if (await target.exists()) {
      await readMetadata(id, metadata);
      return;
    }
    var objects = 0, storedBytes = 0;
    await for (final item in directory.list(followLinks: false)) {
      if (item is File) {
        objects++;
        storedBytes += await item.length();
      }
    }
    if (objects >= 1000 ||
        storedBytes + bytes.length + header.length + 28 > 1024 * 1024 * 1024) {
      reject(
        'This device has reached 1,000 files or 1 GB. Save copies and remove some before adding another.',
      );
    }
    final box = await cipher.encrypt(
      bytes,
      secretKey: await key(),
      aad: aad(id, metadata),
    );
    final staging = File('${target.path}.pending');
    await staging.writeAsBytes([
      ...header,
      ...box.concatenation(),
    ], flush: true);
    await staging.rename(target.path);
    await readMetadata(id, metadata);
  }

  Future<Uint8List> readMetadata(
    String id,
    Map<String, String> metadata,
  ) async {
    final target = object(id);
    if (!await target.exists()) {
      reject('This file isn’t on this device. Restore it from your original.');
    }
    final size = await target.length();
    if (size < header.length + 28 || size > maxBytes + header.length + 28) {
      reject(
        'This file looks damaged. Keep it, and restore from your original.',
      );
    }
    final bytes = await target.readAsBytes();
    if (!List.generate(
      header.length,
      (i) => bytes[i] == header[i],
    ).every((v) => v)) {
      reject('This file can’t be read here. Keep your original.');
    }
    final plain = await cipher.decrypt(
      SecretBox.fromConcatenation(
        bytes.sublist(header.length),
        nonceLength: 12,
        macLength: 16,
      ),
      secretKey: await key(),
      aad: aad(id, metadata),
    );
    if ('${plain.length}' != metadata['size'] ||
        sha256.convert(plain).toString() != metadata['checksum']) {
      reject(
        'This file didn’t pass its check, so it can’t be opened. Restore it from your original.',
      );
    }
    return Uint8List.fromList(plain);
  }

  Future<Uint8List> read(String id) async {
    final s = await store.snapshot();
    final file = financeSource(s, id, {'financialFile'});
    if (financialFileDetached(s, id)) {
      reject(
        'This file’s link is archived. Attach your original again to link it.',
      );
    }
    s.revision(file.values['sourceRevision']!);
    return readMetadata(id, file.values);
  }

  Future<bool> present(String id) => object(id).exists();
  Future<void> removeLocalCopy(String id) async {
    final s = await store.snapshot();
    financeSource(s, id, {'financialFile'});
    final target = object(id);
    if (await target.exists()) await target.delete();
  }

  Future<List<String>> orphans() async {
    if (!await directory.exists()) return [];
    final s = await store.snapshot(),
        known = s.revisions
            .where((r) => financeType(r) == 'financialFile')
            .map((r) => '${r.id}.sfp')
            .toSet();
    return [
      await for (final file in directory.list(followLinks: false))
        if (file is File && !known.contains(p.basename(file.path)))
          p.basename(file.path),
    ];
  }
}
