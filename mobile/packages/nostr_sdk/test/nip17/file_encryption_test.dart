// ABOUTME: Unit tests for AES-GCM file encryption/decryption (NIP-17 Kind 15).
// ABOUTME: Verifies encrypt/decrypt roundtrip, key/nonce formats, tamper
// ABOUTME: detection, and edge cases.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip17/file_encryption.dart';

void main() {
  group(FileEncryption, () {
    late FileEncryption fileEncryption;

    setUp(() {
      fileEncryption = FileEncryption();
    });

    group('encrypt', () {
      test('returns ciphertext different from plaintext', () async {
        final plaintext = Uint8List.fromList(
          List.generate(256, (i) => i % 256),
        );

        final result = await fileEncryption.encrypt(plaintext);

        expect(result.ciphertext, isNot(equals(plaintext)));
      });

      test('returns 64-character hex key (32 bytes)', () async {
        final plaintext = Uint8List.fromList([1, 2, 3, 4]);

        final result = await fileEncryption.encrypt(plaintext);

        expect(result.key, hasLength(64));
        expect(result.key, matches(RegExp(r'^[0-9a-f]{64}$')));
      });

      test('returns 24-character hex nonce (12 bytes)', () async {
        final plaintext = Uint8List.fromList([1, 2, 3, 4]);

        final result = await fileEncryption.encrypt(plaintext);

        expect(result.nonce, hasLength(24));
        expect(result.nonce, matches(RegExp(r'^[0-9a-f]{24}$')));
      });

      test('produces different ciphertext on each call', () async {
        final plaintext = Uint8List.fromList([1, 2, 3, 4]);

        final result1 = await fileEncryption.encrypt(plaintext);
        final result2 = await fileEncryption.encrypt(plaintext);

        // Different key and nonce each time
        expect(result1.key, isNot(equals(result2.key)));
        expect(result1.nonce, isNot(equals(result2.nonce)));
      });

      test(
        'ciphertext includes 16-byte GCM tag (longer than plaintext)',
        () async {
          final plaintext = Uint8List.fromList([1, 2, 3, 4]);

          final result = await fileEncryption.encrypt(plaintext);

          // Ciphertext = encrypted data (same size as plaintext) + 16-byte MAC
          expect(result.ciphertext.length, equals(plaintext.length + 16));
        },
      );
    });

    group('decrypt', () {
      test('roundtrip: decrypt(encrypt(data)) returns original data', () async {
        final plaintext = Uint8List.fromList(
          List.generate(1024, (i) => i % 256),
        );

        final encrypted = await fileEncryption.encrypt(plaintext);
        final decrypted = await fileEncryption.decrypt(
          ciphertext: encrypted.ciphertext,
          hexKey: encrypted.key,
          hexNonce: encrypted.nonce,
        );

        expect(decrypted, equals(plaintext));
      });

      test('roundtrip works with small data (1 byte)', () async {
        final plaintext = Uint8List.fromList([42]);

        final encrypted = await fileEncryption.encrypt(plaintext);
        final decrypted = await fileEncryption.decrypt(
          ciphertext: encrypted.ciphertext,
          hexKey: encrypted.key,
          hexNonce: encrypted.nonce,
        );

        expect(decrypted, equals(plaintext));
      });

      test('roundtrip works with large data (1 MB)', () async {
        final plaintext = Uint8List.fromList(
          List.generate(1024 * 1024, (i) => i % 256),
        );

        final encrypted = await fileEncryption.encrypt(plaintext);
        final decrypted = await fileEncryption.decrypt(
          ciphertext: encrypted.ciphertext,
          hexKey: encrypted.key,
          hexNonce: encrypted.nonce,
        );

        expect(decrypted, equals(plaintext));
      });

      test('roundtrip works with empty data (tag only)', () async {
        final encrypted = await fileEncryption.encrypt(Uint8List(0));
        expect(encrypted.ciphertext, hasLength(16));

        final decrypted = await fileEncryption.decrypt(
          ciphertext: encrypted.ciphertext,
          hexKey: encrypted.key,
          hexNonce: encrypted.nonce,
        );

        expect(decrypted, isEmpty);
      });

      test(
        'decrypts a ciphertext handed in as a view into a larger buffer',
        () async {
          final plaintext = Uint8List.fromList(
            List.generate(33, (i) => i * 7 % 256),
          );
          final encrypted = await fileEncryption.encrypt(plaintext);
          final length = encrypted.ciphertext.length;
          final larger = Uint8List(length + 13)
            ..setRange(5, 5 + length, encrypted.ciphertext);

          final decrypted = await fileEncryption.decrypt(
            ciphertext: Uint8List.sublistView(larger, 5, 5 + length),
            hexKey: encrypted.key,
            hexNonce: encrypted.nonce,
          );

          expect(decrypted, equals(plaintext));
        },
      );

      test('throws on tampered ciphertext', () async {
        final plaintext = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

        final encrypted = await fileEncryption.encrypt(plaintext);

        // Flip a byte in the ciphertext body
        final tampered = Uint8List.fromList(encrypted.ciphertext);
        tampered[0] = tampered[0] ^ 0xFF;

        expect(
          () => fileEncryption.decrypt(
            ciphertext: tampered,
            hexKey: encrypted.key,
            hexNonce: encrypted.nonce,
          ),
          throwsA(anything),
        );
      });

      test('throws on wrong key', () async {
        final plaintext = Uint8List.fromList([1, 2, 3, 4]);

        final encrypted = await fileEncryption.encrypt(plaintext);

        // Use a different key
        final wrongKey = 'a' * 64;

        expect(
          () => fileEncryption.decrypt(
            ciphertext: encrypted.ciphertext,
            hexKey: wrongKey,
            hexNonce: encrypted.nonce,
          ),
          throwsA(anything),
        );
      });

      test('throws on wrong nonce', () async {
        final plaintext = Uint8List.fromList([1, 2, 3, 4]);

        final encrypted = await fileEncryption.encrypt(plaintext);

        // Use a different nonce
        final wrongNonce = 'b' * 24;

        expect(
          () => fileEncryption.decrypt(
            ciphertext: encrypted.ciphertext,
            hexKey: encrypted.key,
            hexNonce: wrongNonce,
          ),
          throwsA(anything),
        );
      });
    });

    group('validation', () {
      test('throws $ArgumentError for key with wrong length', () async {
        final plaintext = Uint8List.fromList([1, 2, 3, 4]);
        final encrypted = await fileEncryption.encrypt(plaintext);

        expect(
          () => fileEncryption.decrypt(
            ciphertext: encrypted.ciphertext,
            hexKey: 'abcd', // too short
            hexNonce: encrypted.nonce,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws $ArgumentError for nonce with wrong length', () async {
        final plaintext = Uint8List.fromList([1, 2, 3, 4]);
        final encrypted = await fileEncryption.encrypt(plaintext);

        expect(
          () => fileEncryption.decrypt(
            ciphertext: encrypted.ciphertext,
            hexKey: encrypted.key,
            hexNonce: 'abcd', // too short
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test(
        'throws $ArgumentError for ciphertext shorter than GCM tag',
        () async {
          final plaintext = Uint8List.fromList([1, 2, 3, 4]);
          final encrypted = await fileEncryption.encrypt(plaintext);

          expect(
            () => fileEncryption.decrypt(
              ciphertext: Uint8List.fromList([1, 2, 3]), // too short
              hexKey: encrypted.key,
              hexNonce: encrypted.nonce,
            ),
            throwsA(isA<ArgumentError>()),
          );
        },
      );

      test('names the key of the wrong size nowhere in its error', () async {
        final encrypted = await fileEncryption.encrypt(
          Uint8List.fromList([1, 2, 3, 4]),
        );
        final shortKey = '0f' * 16;

        await expectLater(
          fileEncryption.decrypt(
            ciphertext: encrypted.ciphertext,
            hexKey: shortKey,
            hexNonce: encrypted.nonce,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.toString(),
              'description',
              isNot(contains(shortKey)),
            ),
          ),
        );
      });

      test('names the nonce of the wrong size nowhere in its error', () async {
        final encrypted = await fileEncryption.encrypt(
          Uint8List.fromList([1, 2, 3, 4]),
        );
        final shortNonce = '0e' * 16;

        await expectLater(
          fileEncryption.decrypt(
            ciphertext: encrypted.ciphertext,
            hexKey: encrypted.key,
            hexNonce: shortNonce,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.toString(),
              'description',
              isNot(contains(shortNonce)),
            ),
          ),
        );
      });

      test(
        'throws $ArgumentError for a key with non-hex characters, quoting none '
        'of them',
        () async {
          final encrypted = await fileEncryption.encrypt(
            Uint8List.fromList([1, 2, 3, 4]),
          );
          final keyWithSecretLookingText = 'zq${'0f' * 31}';

          await expectLater(
            fileEncryption.decrypt(
              ciphertext: encrypted.ciphertext,
              hexKey: keyWithSecretLookingText,
              hexNonce: encrypted.nonce,
            ),
            throwsA(
              isA<ArgumentError>().having(
                (error) => error.toString(),
                'description',
                isNot(contains('zq')),
              ),
            ),
          );
        },
      );

      test('throws $ArgumentError for odd-length hex key', () async {
        final plaintext = Uint8List.fromList([1, 2, 3, 4]);
        final encrypted = await fileEncryption.encrypt(plaintext);

        expect(
          () => fileEncryption.decrypt(
            ciphertext: encrypted.ciphertext,
            hexKey: 'abc', // odd length
            hexNonce: encrypted.nonce,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
