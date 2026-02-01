import 'package:drift/drift.dart';

import '../db/app_db.dart';

class VisitProcedureWithName {
  VisitProcedureWithName({
    required this.id,
    required this.visitId,
    required this.procedureId,
    required this.procedureName,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String visitId;
  final String procedureId;
  final String procedureName;
  final int quantity;
  final int unitPrice;
  final int discount;
  final String? notes;
  final DateTime createdAt;

  int get lineTotalCents => quantity * unitPrice - discount;
}

class VisitProceduresRepository {
  VisitProceduresRepository(this._db);

  final AppDatabase _db;

  Stream<List<VisitProcedureWithName>> watchByVisit(String visitId) {
    final query = _db.customSelect(
      'SELECT vp.id, vp.visit_id, vp.procedure_id, vp.quantity, vp.unit_price, '
      'vp.discount, vp.notes, vp.created_at, p.name AS procedure_name '
      'FROM visit_procedures vp '
      'INNER JOIN procedures p ON p.id = vp.procedure_id '
      'WHERE vp.visit_id = ? '
      'ORDER BY vp.created_at ASC',
      variables: [Variable<String>(visitId)],
      readsFrom: {_db.visitProcedures, _db.procedures},
    );

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => VisitProcedureWithName(
                  id: row.read<String>('id'),
                  visitId: row.read<String>('visit_id'),
                  procedureId: row.read<String>('procedure_id'),
                  procedureName: row.read<String>('procedure_name'),
                  quantity: row.read<int>('quantity'),
                  unitPrice: row.read<int>('unit_price'),
                  discount: row.read<int?>('discount') ?? 0,
                  notes: row.read<String?>('notes'),
                  createdAt: row.read<DateTime>('created_at'),
                ),
              )
              .toList(),
        );
  }

  Stream<int> watchVisitTotalCents(String visitId) {
    final query = _db.customSelect(
      'SELECT COALESCE(SUM(quantity * unit_price - COALESCE(discount, 0)), 0) '
      'AS total FROM visit_procedures WHERE visit_id = ?',
      variables: [Variable<String>(visitId)],
      readsFrom: {_db.visitProcedures},
    );
    return query.watch().map((rows) {
      if (rows.isEmpty) return 0;
      return rows.first.read<int>('total');
    });
  }

  Future<int> getVisitTotalCents(String visitId) async {
    final row = await _db.customSelect(
      'SELECT COALESCE(SUM(quantity * unit_price - COALESCE(discount, 0)), 0) '
      'AS total FROM visit_procedures WHERE visit_id = ?',
      variables: [Variable<String>(visitId)],
      readsFrom: {_db.visitProcedures},
    ).getSingle();
    return row.read<int>('total');
  }

  Future<void> upsert(VisitProceduresCompanion companion) async {
    await _db.into(_db.visitProcedures).insertOnConflictUpdate(companion);
  }

  Future<void> deleteById(String id) async {
    await (_db.delete(_db.visitProcedures)..where((t) => t.id.equals(id))).go();
  }
}