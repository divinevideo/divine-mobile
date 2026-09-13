// ABOUTME: Unit tests for DmVideoEncryption
// ABOUTME: Verifies AES-256-GCM round-trip and separate ciphertext/plaintext hashes.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/dm_video_encryption.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dm_video_encryption_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'encryptFile round-trips and hashes ciphertext and plaintext separately',
    () async {
      final service = DmVideoEncryption();
      final input = File('${tempDir.path}/in.mp4')
        ..writeAsBytesSync(List<int>.generate(4096, (i) => i % 251));
      final out = await service.encryptFile(input);

      expect(out.plaintextHash, HashUtil.sha256Hash(input.readAsBytesSync()));
      expect(
        out.ciphertextHash,
        HashUtil.sha256Hash(out.ciphertextFile.readAsBytesSync()),
      );
      expect(out.ciphertextHash, isNot(out.plaintextHash));
      expect(out.ciphertextSize, out.ciphertextFile.lengthSync());

      final plain = await service.decryptBytes(
        ciphertext: out.ciphertextFile.readAsBytesSync(),
        key: out.key,
        nonce: out.nonce,
      );
      expect(plain, input.readAsBytesSync());
    },
  );
}
