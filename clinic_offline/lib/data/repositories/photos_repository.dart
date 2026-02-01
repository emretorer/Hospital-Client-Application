import 'package:drift/drift.dart';

import '../db/app_db.dart';

class PhotosRepository {
  PhotosRepository(this._db);

  final AppDatabase _db;

  Stream<List<Photo>> watchByPatient(String patientId) {
    final query = (_db.select(_db.photos)
      ..where((t) => t.patientId.equals(patientId) & t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.takenAt, mode: OrderingMode.desc)
      ]));
    return query.watch();
  }

  Future<void> insert(PhotosCompanion companion) async {
    await _db.into(_db.photos).insert(companion);
  }

  Future<void> softDelete(String photoId) async {
    await (_db.update(_db.photos)..where((t) => t.id.equals(photoId))).write(
      PhotosCompanion(deletedAt: Value(DateTime.now())),
    );
  }
}