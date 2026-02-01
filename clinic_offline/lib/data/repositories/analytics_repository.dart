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

class AnalyticsRepository {
  AnalyticsRepository(this._db);

  final AppDatabase _db;

  Future<int> getMonthlyRevenue(DateTime monthStart, DateTime monthEnd) async {
    final row = await _db.customSelect(
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
    ).getSingle();
    return row.read<int>('total');
  }

  Future<List<ProcedureBreakdown>> getMonthlyBreakdownByProcedure(
    DateTime monthStart,
    DateTime monthEnd,
  ) async {
    final rows = await _db.customSelect(
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
    ).get();

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
    final rows = await _db.customSelect(
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
    ).get();

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
}
