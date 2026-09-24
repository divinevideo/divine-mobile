// ABOUTME: Unit tests for DmVideoEncryption
// ABOUTME: Verifies AES-256-GCM round-trip, separate hashes, and the size cap.

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

  group(DmVideoEncryption, () {
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

    test('rejects a file larger than the plaintext ceiling', () async {
      // A sparse file, so the test does not actually write 100 MB to disk.
      final oversized = File('${tempDir.path}/big.mp4');
      final handle = oversized.openSync(mode: FileMode.write)
        ..truncateSync(dmVideoMaxPlaintextBytes + 1);
      handle.closeSync();

      await expectLater(
        DmVideoEncryption().encryptFile(oversized),
        throwsA(isA<DmVideoTooLargeException>()),
      );
    });
  });
}
