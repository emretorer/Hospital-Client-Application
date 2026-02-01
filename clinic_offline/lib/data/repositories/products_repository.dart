import 'package:drift/drift.dart';

import '../db/app_db.dart';

class ProductsRepository {
  ProductsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Product>> watchAll() {
    final query = (_db.select(_db.products)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]));
    return query.watch();
  }

  Future<Product> getById(String id) {
    return (_db.select(_db.products)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> upsert(ProductsCompanion companion) async {
    await _db.into(_db.products).insertOnConflictUpdate(companion);
  }

  Future<void> deleteById(String id) async {
    await (_db.delete(_db.products)..where((t) => t.id.equals(id))).go();
  }

  Future<void> adjustQuantity(String id, int delta) async {
    final product = await getById(id);
    final nextQty = (product.quantity + delta).clamp(0, 1 << 30);
    await upsert(
      ProductsCompanion(
        id: Value(product.id),
        name: Value(product.name),
        quantity: Value(nextQty),
        unitCost: Value(product.unitCost),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
