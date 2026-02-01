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

  Future<void> normalizeAllNames() async {
    final rows = await _db.select(_db.patients).get();
    await _db.transaction(() async {
      for (final row in rows) {
        final normalized = normalizePatientName(row.fullName);
        if (normalized == row.fullName) continue;
        await (_db.update(_db.patients)..where((t) => t.id.equals(row.id)))
            .write(PatientsCompanion(fullName: Value(normalized)));
      }
    });
  }

  static String normalizePatientName(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    final parts = trimmed.split(RegExp(r'\s+'));
    final normalized = parts.map((part) {
      if (part.isEmpty) return part;
      final lower = _trToLower(part);
      final first = _trToUpper(lower.substring(0, 1));
      final rest = lower.substring(1);
      return '$first$rest';
    }).join(' ');
    return normalized;
  }

  Future<void> deleteById(String id) async {
    await (_db.delete(_db.patients)..where((t) => t.id.equals(id))).go();
  }
}

String _trToUpper(String value) {
  return value
      .replaceAll('i', '\u0130')
      .replaceAll('\u0131', 'I')
      .toUpperCase();
}

String _trToLower(String value) {
  return value
      .replaceAll('I', '\u0131')
      .replaceAll('\u0130', 'i')
      .toLowerCase();
}


