import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';

import 'package:clinic_offline/data/db/app_db.dart';
import 'package:clinic_offline/data/repositories/analytics_repository.dart';

void main() {
  test('monthly revenue totals across months', () async {
    final db = AppDatabase.test(NativeDatabase.memory());
    final analytics = AnalyticsRepository(db);

    await db.into(db.patients).insert(
          PatientsCompanion.insert(
            id: 'p1',
            fullName: 'Test',
            createdAt: DateTime(2026, 1, 1),
          ),
        );
    await db.into(db.procedures).insert(
          ProceduresCompanion.insert(
            id: 'pr1',
            name: 'Filler',
            createdAt: DateTime(2026, 1, 1),
          ),
        );

    await db.into(db.visits).insert(
          VisitsCompanion.insert(
            id: 'v1',
            patientId: 'p1',
            visitAt: DateTime(2026, 1, 10),
          ),
        );
    await db.into(db.visitProcedures).insert(
          VisitProceduresCompanion.insert(
            id: 'vp1',
            visitId: 'v1',
            procedureId: 'pr1',
            quantity: const Value(1),
            unitPrice: 20000,
            createdAt: DateTime(2026, 1, 10),
          ),
        );

    await db.into(db.visits).insert(
          VisitsCompanion.insert(
            id: 'v2',
            patientId: 'p1',
            visitAt: DateTime(2026, 2, 2),
          ),
        );
    await db.into(db.visitProcedures).insert(
          VisitProceduresCompanion.insert(
            id: 'vp2',
            visitId: 'v2',
            procedureId: 'pr1',
            quantity: const Value(2),
            unitPrice: 15000,
            discount: const Value(1000),
            createdAt: DateTime(2026, 2, 2),
          ),
        );

    final janStart = DateTime(2026, 1, 1);
    final febStart = DateTime(2026, 2, 1);
    final marStart = DateTime(2026, 3, 1);

    final janTotal = await analytics.getMonthlyRevenue(janStart, febStart);
    final febTotal = await analytics.getMonthlyRevenue(febStart, marStart);

    expect(janTotal, 20000);
    expect(febTotal, 2 * 15000 - 1000);

    await db.close();
  });
}
