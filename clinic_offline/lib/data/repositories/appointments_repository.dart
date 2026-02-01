import 'package:drift/drift.dart';

import '../db/app_db.dart';

class AppointmentsRepository {
  AppointmentsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Appointment>> watchUpcoming() {
    final now = DateTime.now();
    final query = (_db.select(_db.appointments)
      ..where((t) => t.scheduledAt.isBiggerOrEqualValue(now))
      ..orderBy([
        (t) => OrderingTerm(expression: t.scheduledAt, mode: OrderingMode.asc)
      ]));
    return query.watch();
  }

  Stream<List<Appointment>> watchPast() {
    final now = DateTime.now();
    final query = (_db.select(_db.appointments)
      ..where((t) => t.scheduledAt.isSmallerThanValue(now))
      ..orderBy([
        (t) => OrderingTerm(expression: t.scheduledAt, mode: OrderingMode.desc)
      ]));
    return query.watch();
  }

  Stream<List<Appointment>> watchByPatient(String patientId) {
    final query = (_db.select(_db.appointments)
      ..where((t) => t.patientId.equals(patientId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.scheduledAt, mode: OrderingMode.desc)
      ]));
    return query.watch();
  }

  Future<void> upsert(AppointmentsCompanion companion) async {
    await _db.into(_db.appointments).insertOnConflictUpdate(companion);
  }
}