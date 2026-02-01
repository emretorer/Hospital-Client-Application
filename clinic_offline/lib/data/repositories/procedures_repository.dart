import 'package:drift/drift.dart';

import '../db/app_db.dart';

class ProceduresRepository {
  ProceduresRepository(this._db);

  final AppDatabase _db;

  Stream<List<Procedure>> watchAll() {
    final query = (_db.select(_db.procedures)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]));
    return query.watch();
  }

  Future<Procedure> getById(String id) {
    return (_db.select(_db.procedures)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> upsert(ProceduresCompanion companion) async {
    await _db.into(_db.procedures).insertOnConflictUpdate(companion);
  }

  Future<void> deleteById(String id) async {
    await (_db.delete(_db.procedures)..where((t) => t.id.equals(id))).go();
  }
}