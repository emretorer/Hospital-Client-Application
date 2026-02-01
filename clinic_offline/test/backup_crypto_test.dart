import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:clinic_offline/services/backup_crypto.dart';

void main() {
  test('backup encryption/decryption roundtrip', () async {
    final crypto = BackupCrypto();
    final data = Uint8List.fromList(List.generate(256, (i) => i));
    final encrypted = await crypto.encrypt(data, 'password123');
    final decrypted = await crypto.decrypt(encrypted, 'password123');
    expect(decrypted, data);
  });
}