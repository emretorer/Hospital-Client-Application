import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';

import 'package:clinic_offline/data/db/app_db.dart';
import 'package:clinic_offline/data/repositories/visit_procedures_repository.dart';

void main() {
  test('visit total computation', () async {
    final db = AppDatabase.test(NativeDatabase.memory());
    final visitRepo = VisitProceduresRepository(db);

    await db.into(db.patients).insert(
          PatientsCompanion.insert(
            id: 'p1',
            fullName: 'Test',
            createdAt: DateTime(2026, 1, 1),
          ),
        );
    await db.into(db.visits).insert(
          VisitsCompanion.insert(
            id: 'v1',
            patientId: 'p1',
            visitAt: DateTime(2026, 1, 5),
          ),
        );
    await db.into(db.procedures).insert(
          ProceduresCompanion.insert(
            id: 'pr1',
            name: 'Botox',
            createdAt: DateTime(2026, 1, 1),
          ),
        );

    await visitRepo.upsert(
      VisitProceduresCompanion.insert(
        id: 'vp1',
        visitId: 'v1',
        procedureId: 'pr1',
        quantity: const Value(2),
        unitPrice: 15000,
        discount: const Value(1000),
        createdAt: DateTime(2026, 1, 5),
      ),
    );

    final total = await visitRepo.getVisitTotalCents('v1');
    expect(total, 2 * 15000 - 1000);

    await db.close();
  });
}
