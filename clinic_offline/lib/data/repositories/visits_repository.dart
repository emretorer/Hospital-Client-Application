import 'package:drift/drift.dart';

import '../db/app_db.dart';

class VisitsRepository {
  VisitsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Visit>> watchByPatient(String patientId) {
    final query = (_db.select(_db.visits)
      ..where((t) => t.patientId.equals(patientId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.visitAt, mode: OrderingMode.desc)
      ]));
    return query.watch();
  }

  Future<Visit> getById(String id) {
    return (_db.select(_db.visits)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> insert(VisitsCompanion companion) async {
    await _db.into(_db.visits).insert(companion);
  }
}
