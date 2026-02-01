import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clinic_offline/data/db/app_db.dart';

void main() {
  test('db migration smoke test', () async {
    final db = AppDatabase.test(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    await db.close();
  });
}