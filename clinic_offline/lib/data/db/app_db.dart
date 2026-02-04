import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../services/app_paths.dart';
import 'tables.dart';

part 'app_db.g.dart';

@DriftDatabase(
  tables: [
    Patients,
    Visits,
    Appointments,
    Photos,
    Products,
    ProductUsages,
    ManualIncomes,
    Procedures,
    VisitProcedures,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(this._paths) : super(_openConnection(_paths));

  // ignore: unused_field
  final AppPaths _paths;

  AppDatabase.test(super.executor) : _paths = const AppPaths();

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX visits_patient_visitAt ON visits (patient_id, visit_at DESC)',
      );
      await customStatement(
        'CREATE INDEX appointments_scheduledAt ON appointments (scheduled_at)',
      );
      await customStatement(
        'CREATE INDEX photos_patient_takenAt ON photos (patient_id, taken_at DESC)',
      );
      await customStatement('CREATE INDEX products_name ON products (name)');
      await customStatement(
        'CREATE INDEX product_usages_visitId ON product_usages (visit_id)',
      );
      await customStatement(
        'CREATE INDEX product_usages_productId ON product_usages (product_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS manual_incomes_incomeAt ON manual_incomes (income_at DESC)',
      );
      await customStatement(
        'CREATE INDEX visit_procedures_visitId ON visit_procedures (visit_id)',
      );
      await customStatement(
        'CREATE INDEX visit_procedures_procedureId ON visit_procedures (procedure_id)',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 1) {
        await m.createAll();
      }
      if (from < 2) {
        await m.createTable(procedures);
        await m.createTable(visitProcedures);
        await customStatement(
          'CREATE INDEX visit_procedures_visitId ON visit_procedures (visit_id)',
        );
        await customStatement(
          'CREATE INDEX visit_procedures_procedureId ON visit_procedures (procedure_id)',
        );
      }
      if (from < 3) {
        await m.createTable(products);
        await customStatement('CREATE INDEX products_name ON products (name)');
      }
      if (from < 4) {
        await m.createTable(productUsages);
        await customStatement(
          'CREATE INDEX product_usages_visitId ON product_usages (visit_id)',
        );
        await customStatement(
          'CREATE INDEX product_usages_productId ON product_usages (product_id)',
        );
      }
      if (from < 5) {
        await m.addColumn(patients, patients.gender);
      }
      if (from < 6) {
        await m.createTable(manualIncomes);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS manual_incomes_incomeAt ON manual_incomes (income_at DESC)',
        );
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
