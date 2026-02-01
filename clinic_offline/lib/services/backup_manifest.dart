import 'dart:convert';

class ManifestFileEntry {
  ManifestFileEntry({
    required this.path,
    required this.sha256,
    required this.size,
  });

  final String path;
  final String sha256;
  final int size;

  Map<String, dynamic> toJson() => {
        'path': path,
        'sha256': sha256,
        'size': size,
      };

  factory ManifestFileEntry.fromJson(Map<String, dynamic> json) {
    return ManifestFileEntry(
      path: json['path'] as String,
      sha256: json['sha256'] as String,
      size: json['size'] as int,
    );
  }
}

class BackupManifest {
  BackupManifest({
    required this.schemaVersion,
    required this.createdAt,
    required this.appVersion,
    required this.files,
  });

  final int schemaVersion;
  final String createdAt;
  final String appVersion;
  final List<ManifestFileEntry> files;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'createdAt': createdAt,
        'appVersion': appVersion,
        'files': files.map((f) => f.toJson()).toList(),
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    final list = (json['files'] as List<dynamic>)
        .map((e) => ManifestFileEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return BackupManifest(
      schemaVersion: json['schemaVersion'] as int,
      createdAt: json['createdAt'] as String,
      appVersion: json['appVersion'] as String,
      files: list,
    );
  }

  String encode() => jsonEncode(toJson());

  static BackupManifest decode(String raw) {
    return BackupManifest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}