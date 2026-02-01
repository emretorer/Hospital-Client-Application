import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  const AppPaths();

  Future<Directory> documentsDir() async {
    return getApplicationDocumentsDirectory();
  }

  Future<Directory> photosDir() async {
    final docs = await documentsDir();
    final dir = Directory(p.join(docs.path, 'photos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> thumbsDir() async {
    final docs = await documentsDir();
    final dir = Directory(p.join(docs.path, 'thumbs'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> tempDir() async {
    final docs = await documentsDir();
    final dir = Directory(p.join(docs.path, 'temp'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> databaseFile() async {
    final docs = await documentsDir();
    return File(p.join(docs.path, 'db.sqlite'));
  }

  Future<Directory> patientPhotosDir(String patientId) async {
    final photos = await photosDir();
    final dir = Directory(p.join(photos.path, patientId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> patientThumbsDir(String patientId) async {
    final thumbs = await thumbsDir();
    final dir = Directory(p.join(thumbs.path, patientId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String relativeToDocuments(String fullPath, String docsPath) {
    return p.relative(fullPath, from: docsPath);
  }
}