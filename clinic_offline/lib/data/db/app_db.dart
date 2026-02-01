import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../services/app_paths.dart';
import 'tables.dart';

part 'app_db.g.dart';

@DriftDatabase(tables: [Patients, Visits, Appointments, Photos])
class AppDatabase extends _$AppDatabase {
  AppDatabase(this._paths) : super(_openConnection(_paths));

  // ignore: unused_field
  final AppPaths _paths;

  AppDatabase.test(super.executor) : _paths = const AppPaths();

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
              'CREATE INDEX visits_patient_visitAt ON visits (patient_id, visit_at DESC)');
          await customStatement(
              'CREATE INDEX appointments_scheduledAt ON appointments (scheduled_at)');
          await customStatement(
              'CREATE INDEX photos_patient_takenAt ON photos (patient_id, taken_at DESC)');
        },
        onUpgrade: (m, from, to) async {
          if (from < 1) {
            await m.createAll();
          }
        },
      );

  Future<File> checkpointToTempFile(Directory tempDir) async {
    final tempPath = '${tempDir.path}${Platform.pathSeparator}db_backup.sqlite';
    final escaped = tempPath.replaceAll("'", "''");
    await customStatement("VACUUM INTO '$escaped'");
    return File(tempPath);
  }
}

LazyDatabase _openConnection(AppPaths paths) {
  return LazyDatabase(() async {
    final file = await paths.databaseFile();
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return NativeDatabase(file);
  });
}
