import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'app_paths.dart';

class StoredPhoto {
  StoredPhoto({
    required this.relativePath,
    required this.thumbRelativePath,
    required this.sha256,
  });

  final String relativePath;
  final String thumbRelativePath;
  final String sha256;
}

class ImageStorageService {
  ImageStorageService(this._paths);

  final AppPaths _paths;

  Future<StoredPhoto> saveImage({
    required String patientId,
    required String photoId,
    required Uint8List bytes,
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Unsupported image format.');
    }

    final reEncoded = Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
    final hash = sha256.convert(reEncoded).toString();

    final patientPhotos = await _paths.patientPhotosDir(patientId);
    final patientThumbs = await _paths.patientThumbsDir(patientId);

    final photoPath = p.join(patientPhotos.path, '$photoId.jpg');
    final thumbPath = p.join(patientThumbs.path, '$photoId.jpg');

    final photoFile = File(photoPath);
    await photoFile.writeAsBytes(reEncoded, flush: true);

    final thumbImage = img.copyResize(decoded, width: 320);
    final thumbBytes = Uint8List.fromList(img.encodeJpg(thumbImage, quality: 80));
    await File(thumbPath).writeAsBytes(thumbBytes, flush: true);

    final docs = await _paths.documentsDir();
    final relativePath = _paths.relativeToDocuments(photoPath, docs.path);
    final thumbRelativePath = _paths.relativeToDocuments(thumbPath, docs.path);

    return StoredPhoto(
      relativePath: relativePath,
      thumbRelativePath: thumbRelativePath,
      sha256: hash,
    );
  }

  Future<File> resolveFromRelative(String relativePath) async {
    final docs = await _paths.documentsDir();
    return File(p.join(docs.path, relativePath));
  }

  Future<void> deleteRelative(String relativePath) async {
    final file = await resolveFromRelative(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}