import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class BackupPayload {
  BackupPayload({
    required this.salt,
    required this.nonce,
    required this.mac,
    required this.ciphertext,
    required this.iterations,
  });

  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List mac;
  final Uint8List ciphertext;
  final int iterations;
}

class BackupCrypto {
  static const String magic = 'CLINICBK';
  static const int version = 1;
  static const int defaultIterations = 150000;

  final Random _random = Random.secure();

  Future<Uint8List> encrypt(Uint8List plaintext, String password) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await _deriveKey(password, salt, defaultIterations);
    final algorithm = AesGcm.with256bits();

    final box = await algorithm.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
    );

    final payload = BackupPayload(
      salt: salt,
      nonce: nonce,
      mac: Uint8List.fromList(box.mac.bytes),
      ciphertext: Uint8List.fromList(box.cipherText),
      iterations: defaultIterations,
    );

    return _encode(payload);
  }

  Future<Uint8List> decrypt(Uint8List input, String password) async {
    final payload = _decode(input);
    final key = await _deriveKey(password, payload.salt, payload.iterations);
    final algorithm = AesGcm.with256bits();
    final box = SecretBox(
      payload.ciphertext,
      nonce: payload.nonce,
      mac: Mac(payload.mac),
    );
    final clear = await algorithm.decrypt(box, secretKey: key);
    return Uint8List.fromList(clear);
  }

  Uint8List _encode(BackupPayload payload) {
    final builder = BytesBuilder();
    builder.add(magic.codeUnits);
    builder.add([version]);

    final iterBytes = ByteData(4)..setUint32(0, payload.iterations, Endian.big);
    builder.add(iterBytes.buffer.asUint8List());

    builder.add([payload.salt.length, payload.nonce.length, payload.mac.length]);
    builder.add(payload.salt);
    builder.add(payload.nonce);
    builder.add(payload.mac);
    builder.add(payload.ciphertext);
    return builder.toBytes();
  }

  BackupPayload _decode(Uint8List input) {
    if (input.length < magic.length + 1 + 4 + 3) {
      throw StateError('Invalid backup header.');
    }

    final magicBytes = input.sublist(0, magic.length);
    final magicValue = String.fromCharCodes(magicBytes);
    if (magicValue != magic) {
      throw StateError('Invalid backup magic header.');
    }

    var offset = magic.length;
    final versionByte = input[offset];
    offset += 1;
    if (versionByte != version) {
      throw StateError('Unsupported backup version.');
    }

    final iter = ByteData.sublistView(input, offset, offset + 4)
        .getUint32(0, Endian.big);
    offset += 4;

    final saltLen = input[offset];
    final nonceLen = input[offset + 1];
    final macLen = input[offset + 2];
    offset += 3;

    final salt = input.sublist(offset, offset + saltLen);
    offset += saltLen;
    final nonce = input.sublist(offset, offset + nonceLen);
    offset += nonceLen;
    final mac = input.sublist(offset, offset + macLen);
    offset += macLen;
    final cipher = input.sublist(offset);

    return BackupPayload(
      salt: Uint8List.fromList(salt),
      nonce: Uint8List.fromList(nonce),
      mac: Uint8List.fromList(mac),
      ciphertext: Uint8List.fromList(cipher),
      iterations: iter,
    );
  }

  Future<SecretKey> _deriveKey(
    String password,
    Uint8List salt,
    int iterations,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(password.codeUnits),
      nonce: salt,
    );
  }

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }
}
