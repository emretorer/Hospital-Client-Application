import 'package:drift/drift.dart';

import '../db/app_db.dart';

class ProductUsagesRepository {
  ProductUsagesRepository(this._db);

  final AppDatabase _db;

  Future<void> insert(ProductUsagesCompanion companion) async {
    await _db.into(_db.productUsages).insert(companion);
  }

  Stream<List<ProductUsage>> watchByVisit(String visitId) {
    return (_db.select(_db.productUsages)
          ..where((t) => t.visitId.equals(visitId)))
        .watch();
  }
}
