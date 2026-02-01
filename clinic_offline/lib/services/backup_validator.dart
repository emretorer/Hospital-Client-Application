import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'backup_manifest.dart';

class BackupValidator {
  static Future<void> verify(Directory root, BackupManifest manifest) async {
    for (final entry in manifest.files) {
      final file = File(p.join(root.path, entry.path));
      if (!await file.exists()) {
        throw StateError('Missing file from backup: ${entry.path}');
      }
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      if (hash != entry.sha256) {
        throw StateError('Hash mismatch for ${entry.path}.');
      }
    }
  }
}