import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:clinic_offline/services/backup_manifest.dart';
import 'package:clinic_offline/services/backup_validator.dart';

void main() {
  test('manifest hash validation', () async {
    final root = await Directory.systemTemp.createTemp('clinic_manifest');
    final file = File(p.join(root.path, 'photos', 'a.jpg'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes([1, 2, 3, 4, 5]);

    final hash = sha256.convert(await file.readAsBytes()).toString();
    final manifest = BackupManifest(
      schemaVersion: 1,
      createdAt: DateTime.now().toIso8601String(),
      appVersion: '1.0.0',
      files: [
        ManifestFileEntry(path: 'photos/a.jpg', sha256: hash, size: 5),
      ],
    );

    await BackupValidator.verify(root, manifest);

    await file.writeAsBytes([9, 9, 9]);
    expect(
      () => BackupValidator.verify(root, manifest),
      throwsA(isA<StateError>()),
    );
  });
}