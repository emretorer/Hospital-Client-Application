import 'package:drift/drift.dart';

import '../db/app_db.dart';

class ProcedureBreakdown {
  ProcedureBreakdown({
    required this.procedureName,
    required this.count,
    required this.totalCents,
  });

  final String procedureName;
  final int count;
  final int totalCents;
}

class DailyTotal {
  DailyTotal({required this.day, required this.totalCents});

  final DateTime day;
  final int totalCents;
}

class RevenueEntry {
  RevenueEntry({
    required this.id,
    required this.visitId,
    required this.visitAt,
    required this.procedureName,
    required this.patientName,
    required this.patientGender,
    required this.patientDateOfBirth,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.notes,
    required this.isManualIncome,
    required this.productName,
    required this.visitProductCostCents,
    required this.usedProductsSummary,
  });

  final String id;
  final String visitId;
  final DateTime visitAt;
  final String procedureName;
  final String patientName;
  final String? patientGender;
  final DateTime? patientDateOfBirth;
  final int quantity;
  final int unitPrice;
  final int discount;
  final String? notes;
  final bool? isManualIncome;
  final String? productName;
  final int visitProductCostCents;
  final String? usedProductsSummary;
  bool get isManualIncomeSafe => isManualIncome ?? false;

  int get totalCents => quantity * unitPrice - discount;
}

class AnalyticsRepository {
  AnalyticsRepository(this._db);

  final AppDatabase _db;

  Future<int> getMonthlyRevenue(DateTime monthStart, DateTime monthEnd) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(quantity * unit_price - COALESCE(discount, 0)), 0) '
          'AS total '
          'FROM visit_procedures vp '
          'INNER JOIN visits v ON v.id = vp.visit_id '
          'WHERE v.visit_at >= ? AND v.visit_at < ?',
          variables: [
            Variable<DateTime>(monthStart),
            Variable<DateTime>(monthEnd),
          ],
          readsFrom: {_db.visitProcedures, _db.visits},
        )
        .getSingle();
    return row.read<int>('total');
  }

  Future<List<ProcedureBreakdown>> getMonthlyBreakdownByProcedure(
    DateTime monthStart,
    DateTime monthEnd,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT p.name AS name, '
          'COALESCE(SUM(quantity * unit_price - COALESCE(discount, 0)), 0) AS total, '
          'COALESCE(SUM(quantity), 0) AS count '
          'FROM visit_procedures vp '
          'INNER JOIN procedures p ON p.id = vp.procedure_id '
          'INNER JOIN visits v ON v.id = vp.visit_id '
          'WHERE v.visit_at >= ? AND v.visit_at < ? '
          'GROUP BY p.id, p.name '
          'ORDER BY total DESC',
          variables: [
            Variable<DateTime>(monthStart),
            Variable<DateTime>(monthEnd),
          ],
          readsFrom: {_db.visitProcedures, _db.procedures, _db.visits},
        )
        .get();

    return rows
        .map(
          (row) => ProcedureBreakdown(
            procedureName: row.read<String?>('name') ?? 'Unknown',
            count: row.read<int>('count'),
            totalCents: row.read<int>('total'),
          ),
        )
        .toList();
  }

  Future<List<DailyTotal>> getDailyTotals(
    DateTime monthStart,
    DateTime monthEnd,
  ) async {
    final rows = await _db
        .customSelect(
          "SELECT strftime('%Y-%m-%d', v.visit_at) AS day, "
          'COALESCE(SUM(quantity * unit_price - COALESCE(discount, 0)), 0) AS total '
          'FROM visit_procedures vp '
          'INNER JOIN visits v ON v.id = vp.visit_id '
          'WHERE v.visit_at >= ? AND v.visit_at < ? '
          'GROUP BY day '
          'ORDER BY day ASC',
          variables: [
            Variable<DateTime>(monthStart),
            Variable<DateTime>(monthEnd),
          ],
          readsFrom: {_db.visitProcedures, _db.visits},
        )
        .get();

    return rows
        .map((row) {
          final dayString = row.read<String?>('day');
          if (dayString == null || dayString.isEmpty) return null;
          return DailyTotal(
            day: DateTime.parse(dayString),
            totalCents: row.read<int>('total'),
          );
        })
        .whereType<DailyTotal>()
        .toList();
  }

  Future<List<RevenueEntry>> getMonthlyRevenueEntries(
    DateTime monthStart,
    DateTime monthEnd,
  ) async {
    final rows = await _monthlyEntriesSelect(monthStart, monthEnd).get();
    return _mapRevenueEntries(rows);
  }

  Stream<List<RevenueEntry>> watchMonthlyRevenueEntries(
    DateTime monthStart,
    DateTime monthEnd,
  ) {
    return _monthlyEntriesSelect(
      monthStart,
      monthEnd,
    ).watch().map(_mapRevenueEntries);
  }

  Future<void> addManualIncome(ManualIncomesCompanion companion) async {
    await _db.into(_db.manualIncomes).insert(companion);
  }

  Selectable<QueryRow> _monthlyEntriesSelect(
    DateTime monthStart,
    DateTime monthEnd,
  ) {
    return _db.customSelect(
      'SELECT vp.id, vp.visit_id, vp.quantity, vp.unit_price, '
      'COALESCE(vp.discount, 0) AS discount, vp.notes, '
      'v.visit_at, p.name AS procedure_name, pa.full_name AS patient_name, '
      'pa.gender AS patient_gender, pa.date_of_birth AS patient_date_of_birth, '
      '0 AS is_manual_income, '
      'NULL AS product_name, '
      'COALESCE(usage.product_cost, 0) AS visit_product_cost, '
      'usage.products_used AS products_used '
      'FROM visit_procedures vp '
      'INNER JOIN visits v ON v.id = vp.visit_id '
      'INNER JOIN procedures p ON p.id = vp.procedure_id '
      'INNER JOIN patients pa ON pa.id = v.patient_id '
      'LEFT JOIN ('
      '  SELECT pu.visit_id AS visit_id, '
      '  COALESCE(SUM(pu.quantity * pr.unit_cost), 0) AS product_cost, '
      "  GROUP_CONCAT(pr.name || ' (Used: ' || pu.quantity || ')', ', ') AS products_used "
      '  FROM product_usages pu '
      '  INNER JOIN products pr ON pr.id = pu.product_id '
      '  GROUP BY pu.visit_id'
      ') AS usage ON usage.visit_id = vp.visit_id '
      'WHERE v.visit_at >= ? AND v.visit_at < ? '
      'UNION ALL '
      'SELECT mi.id, mi.id AS visit_id, 1 AS quantity, mi.amount AS unit_price, '
      '0 AS discount, mi.notes, mi.income_at AS visit_at, '
      'COALESCE(mi.procedure_name, mi.title) AS procedure_name, '
      'COALESCE(mi.patient_name, \'Manual income\') AS patient_name, '
      'NULL AS patient_gender, NULL AS patient_date_of_birth, '
      '1 AS is_manual_income, '
      'mi.product_name AS product_name, '
      '0 AS visit_product_cost, '
      'mi.product_name AS products_used '
      'FROM manual_incomes mi '
      'WHERE mi.income_at >= ? AND mi.income_at < ?',
      variables: [
        Variable<DateTime>(monthStart),
        Variable<DateTime>(monthEnd),
        Variable<DateTime>(monthStart),
        Variable<DateTime>(monthEnd),
      ],
      readsFrom: {
        _db.visitProcedures,
        _db.visits,
        _db.procedures,
        _db.patients,
        _db.manualIncomes,
        _db.productUsages,
        _db.products,
      },
    );
  }

  List<RevenueEntry> _mapRevenueEntries(List<QueryRow> rows) {
    return rows
        .map(
          (row) => RevenueEntry(
            id: row.read<String>('id'),
            visitId: row.read<String>('visit_id'),
            visitAt: row.read<DateTime>('visit_at'),
            procedureName: row.read<String?>('procedure_name') ?? 'Unknown',
            patientName: row.read<String?>('patient_name') ?? 'Unknown',
            patientGender: row.read<String?>('patient_gender'),
            patientDateOfBirth: row.read<DateTime?>('patient_date_of_birth'),
            quantity: row.read<int>('quantity'),
            unitPrice: row.read<int>('unit_price'),
            discount: row.read<int>('discount'),
            notes: row.read<String?>('notes'),
            isManualIncome: row.read<int>('is_manual_income') == 1,
            productName: row.read<String?>('product_name'),
            visitProductCostCents: row.read<int>('visit_product_cost'),
            usedProductsSummary: row.read<String?>('products_used'),
          ),
        )
        .toList();
  }
}
