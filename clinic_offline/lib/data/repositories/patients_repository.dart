import 'package:drift/drift.dart';

import '../db/app_db.dart';

class PatientsRepository {
  PatientsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Patient>> watchAll({String? query}) {
    final select = _db.select(_db.patients)
      ..orderBy([(t) => OrderingTerm(expression: t.fullName)]);
    if (query != null && query.trim().isNotEmpty) {
      select.where((t) => t.fullName.like('%${query.trim()}%'));
    }
    return select.watch();
  }

  Future<Patient> getById(String id) {
    return (_db.select(_db.patients)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> upsert(PatientsCompanion companion) async {
    await _db.into(_db.patients).insertOnConflictUpdate(companion);
  }

  Future<void> deleteById(String id) async {
    await (_db.delete(_db.patients)..where((t) => t.id.equals(id))).go();
  }
}