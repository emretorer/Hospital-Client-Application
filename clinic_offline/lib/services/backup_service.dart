import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db/app_db.dart';
import 'app_paths.dart';
import 'backup_crypto.dart';
import 'backup_manifest.dart';
import 'backup_validator.dart';

class BackupService {
  BackupService({required this.paths, required this.db});

  final AppPaths paths;
  final AppDatabase db;
  final BackupCrypto _crypto = BackupCrypto();

  static const String backupFileName = 'clinicbackup.enc';
  static const String manifestName = 'manifest.json';
  static const String lastBackupKey = 'last_backup_iso';

  Future<File> exportBackup(String password) async {
    final tempDir = await paths.tempDir();
    final dbCopy = await db.checkpointToTempFile(tempDir);

    final docs = await paths.documentsDir();
    final photosDir = await paths.photosDir();
    final thumbsDir = await paths.thumbsDir();

    final files = <_FileEntry>[];
    files.add(await _entryFromFile(dbCopy, 'db.sqlite'));

    await for (final entry in _walkDir(photosDir, 'photos')) {
      files.add(entry);
    }
    await for (final entry in _walkDir(thumbsDir, 'thumbs')) {
      files.add(entry);
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final manifest = BackupManifest(
      schemaVersion: db.schemaVersion,
      createdAt: DateTime.now().toIso8601String(),
      appVersion: packageInfo.version,
      files: files
          .map((e) => ManifestFileEntry(
                path: e.relativePath,
                sha256: e.sha256,
                size: e.bytes.length,
              ))
          .toList(),
    );

    final archive = Archive();
    archive.addFile(ArchiveFile('db.sqlite', files.first.bytes.length, files.first.bytes));

    for (final file in files.skip(1)) {
      archive.addFile(ArchiveFile(file.relativePath, file.bytes.length, file.bytes));
    }

    final manifestBytes = utf8.encode(manifest.encode());
    archive.addFile(ArchiveFile(manifestName, manifestBytes.length, manifestBytes));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('Failed to create backup zip.');
    }

    final encrypted = await _crypto.encrypt(Uint8List.fromList(zipBytes), password);

    final backupFile = File(p.join(docs.path, backupFileName));
    await backupFile.writeAsBytes(encrypted, flush: true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastBackupKey, DateTime.now().toIso8601String());

    await dbCopy.delete();
    return backupFile;
  }

  Future<void> importBackup(File file, String password) async {
    final encrypted = await file.readAsBytes();
    final zipBytes = await _crypto.decrypt(Uint8List.fromList(encrypted), password);

    final archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
    final tempDir = await paths.tempDir();
    final restoreDir = Directory(p.join(tempDir.path, 'restore_${DateTime.now().millisecondsSinceEpoch}'));
    await restoreDir.create(recursive: true);

    for (final file in archive.files) {
      if (file.isFile) {
        final outFile = File(p.join(restoreDir.path, file.name));
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>, flush: true);
      }
    }

    final manifestFile = File(p.join(restoreDir.path, manifestName));
    if (!await manifestFile.exists()) {
      throw StateError('Backup manifest missing.');
    }

    final manifest = BackupManifest.decode(await manifestFile.readAsString());
    await BackupValidator.verify(restoreDir, manifest);

    await _replaceData(restoreDir);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastBackupKey, DateTime.now().toIso8601String());
  }

  Future<String?> lastBackupTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(lastBackupKey);
  }

  Future<void> _replaceData(Directory restoreDir) async {
    final docs = await paths.documentsDir();
    final dbFile = await paths.databaseFile();
    final restoreDb = File(p.join(restoreDir.path, 'db.sqlite'));
    if (!await restoreDb.exists()) {
      throw StateError('Backup database missing.');
    }

    await db.close();

    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    await restoreDb.copy(dbFile.path);

    final restorePhotos = Directory(p.join(restoreDir.path, 'photos'));
    final restoreThumbs = Directory(p.join(restoreDir.path, 'thumbs'));
    await _replaceDir(Directory(p.join(docs.path, 'photos')), restorePhotos);
    await _replaceDir(Directory(p.join(docs.path, 'thumbs')), restoreThumbs);
  }

  Future<void> _replaceDir(Directory target, Directory source) async {
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    await source.create(recursive: true);
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: true)) {
      if (entity is File) {
        final relative = p.relative(entity.path, from: source.path);
        final dest = File(p.join(target.path, relative));
        await dest.parent.create(recursive: true);
        await entity.copy(dest.path);
      }
    }
  }

  Stream<_FileEntry> _walkDir(Directory dir, String rootName) async* {
    if (!await dir.exists()) return;

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final relative = p.join(rootName, p.relative(entity.path, from: dir.path));
        yield await _entryFromFile(entity, relative);
      }
    }
  }

  Future<_FileEntry> _entryFromFile(File file, String relativePath) async {
    final bytes = await file.readAsBytes();
    return _FileEntry(
      relativePath: relativePath,
      bytes: bytes,
      sha256: sha256.convert(bytes).toString(),
    );
  }
}

class _FileEntry {
  _FileEntry({
    required this.relativePath,
    required this.bytes,
    required this.sha256,
  });

  final String relativePath;
  final List<int> bytes;
  final String sha256;
}
