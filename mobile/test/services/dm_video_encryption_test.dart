// ABOUTME: Unit tests for DmVideoEncryption
// ABOUTME: Verifies AES-256-GCM round-trip, separate hashes, and the size cap.

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_path_provider_platform.dart';

void main() {
  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dm_video_encryption_test');
    // encryptFile writes its ciphertext to getTemporaryDirectory(), which the
    // shared harness points at /tmp; keep it in this test's directory instead.
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = MockPathProviderPlatform()
      ..setTemporaryPath(tempDir.path);
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
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

    test('gives every file its own key and nonce', () async {
      // Each call copies the cipher into a fresh isolate, so a random source
      // with state would hand every send the same key and nonce.
      final service = DmVideoEncryption();
      final input = File('${tempDir.path}/in.mp4')
        ..writeAsBytesSync(List<int>.generate(4096, (i) => i % 251));

      final first = await service.encryptFile(input);
      final second = await service.encryptFile(input);

      expect(second.key, isNot(equals(first.key)));
      expect(second.nonce, isNot(equals(first.nonce)));
      expect(second.ciphertextHash, isNot(equals(first.ciphertextHash)));
    });

    test('keeps the calling isolate responsive while it encrypts', () async {
      // A clip as large as a typical phone recording. Encrypting it in pure
      // Dart takes over a second on a laptop, and longer on a phone, so work
      // done on the calling isolate shows up as one long stall between ticks.
      final random = Random(7);
      final bytes = Uint8List(24 * 1024 * 1024);
      for (var i = 0; i < bytes.length; i += 4093) {
        bytes[i] = random.nextInt(256);
      }
      final input = File('${tempDir.path}/clip.mp4')..writeAsBytesSync(bytes);

      final clock = Stopwatch()..start();
      var lastTick = Duration.zero;
      var longestStall = Duration.zero;
      final ticker = Timer.periodic(const Duration(milliseconds: 5), (_) {
        final now = clock.elapsed;
        final stall = now - lastTick;
        if (stall > longestStall) longestStall = stall;
        lastTick = now;
      });
      addTearDown(ticker.cancel);

      final out = await DmVideoEncryption().encryptFile(input);
      ticker.cancel();
      final stall = clock.elapsed - lastTick;
      if (stall > longestStall) longestStall = stall;

      expect(out.ciphertextSize, bytes.length + 16);
      expect(longestStall, lessThan(const Duration(milliseconds: 400)));
    });

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
