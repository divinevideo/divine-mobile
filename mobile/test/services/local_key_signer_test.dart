// ABOUTME: Tests for LocalKeySigner backed by a local SecureKeyContainer
// ABOUTME: Validates event signing, encryption, and key access through secure container

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/local_key_signer.dart';

class _MockSecureKeyContainer extends Mock implements SecureKeyContainer {}

void main() {
  late _MockSecureKeyContainer mockKeyContainer;

  const testPrivateKey =
      '6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e';
  const testPublicKey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';
  // Well-formed 32-byte hex that is not a point on secp256k1.
  const offCurvePubkey =
      '0000000000000000000000000000000000000000000000000000000000000000';

  setUpAll(() {
    registerFallbackValue(_MockSecureKeyContainer());
  });

  setUp(() {
    mockKeyContainer = _MockSecureKeyContainer();
    when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);
    when(() => mockKeyContainer.isDisposed).thenReturn(false);
  });

  group('LocalKeySigner', () {
    group('getPublicKey', () {
      test('returns public key from secure container', () async {
        final signer = LocalKeySigner(mockKeyContainer);

        final publicKey = await signer.getPublicKey();

        expect(publicKey, equals(testPublicKey));
        verify(() => mockKeyContainer.publicKeyHex).called(1);
      });

      // The keyless case is no longer representable here — the container is
      // non-nullable. `UnauthenticatedSigner` owns that state now, and its
      // empty-pubkey contract is pinned in
      // packages/nostr_sdk/test/signer/unauthenticated_signer_test.dart.
    });

    group('signEvent', () {
      test('signs event using secure container', () async {
        when(() => mockKeyContainer.withPrivateKey<Event>(any())).thenAnswer((
          invocation,
        ) {
          final callback =
              invocation.positionalArguments[0] as Event Function(String);
          return callback(testPrivateKey);
        });

        final signer = LocalKeySigner(mockKeyContainer);
        final event = Event(
          testPublicKey,
          EventKind.textNote,
          [],
          'Test content',
        );

        final signedEvent = await signer.signEvent(event);

        expect(signedEvent.sig, isNotEmpty);
        verify(() => mockKeyContainer.withPrivateKey<Event>(any())).called(1);
      });

      test('throws a typed failure when the key container refuses', () async {
        when(
          () => mockKeyContainer.withPrivateKey<Event>(any()),
        ).thenThrow(const SecureKeyException('Failed to sign'));

        final signer = LocalKeySigner(mockKeyContainer);
        final event = Event(
          testPublicKey,
          EventKind.textNote,
          [],
          'Test content',
        );

        await expectLater(
          signer.signEvent(event),
          throwsA(
            isA<LocalSignerOperationException>().having(
              (error) => error.cause,
              'cause',
              isA<SecureKeyException>(),
            ),
          ),
        );
      });

      test('does not hide programming errors', () async {
        when(
          () => mockKeyContainer.withPrivateKey<Event>(any()),
        ).thenThrow(StateError('broken signing invariant'));

        final signer = LocalKeySigner(mockKeyContainer);
        final event = Event(
          testPublicKey,
          EventKind.textNote,
          [],
          'Test content',
        );

        await expectLater(signer.signEvent(event), throwsStateError);
      });
    });

    group('signCanonicalPayload', () {
      test('throws a typed failure when the key container refuses', () async {
        when(
          () => mockKeyContainer.withPrivateKey<String>(any()),
        ).thenThrow(const SecureKeyException('Failed to sign'));

        final signer = LocalKeySigner(mockKeyContainer);

        await expectLater(
          signer.signCanonicalPayload(Uint8List.fromList([1, 2, 3])),
          throwsA(
            isA<LocalSignerOperationException>().having(
              (error) => error.operation,
              'operation',
              LocalSignerOperation.signCanonicalPayload,
            ),
          ),
        );
      });

      test('does not hide programming errors', () async {
        when(
          () => mockKeyContainer.withPrivateKey<String>(any()),
        ).thenThrow(StateError('broken canonical-signing invariant'));

        final signer = LocalKeySigner(mockKeyContainer);

        await expectLater(
          signer.signCanonicalPayload(Uint8List.fromList([1, 2, 3])),
          throwsStateError,
        );
      });
    });

    group('getRelays', () {
      test('returns null (no relay config)', () async {
        final signer = LocalKeySigner(mockKeyContainer);

        final relays = await signer.getRelays();

        expect(relays, isNull);
      });
    });

    group('encrypt/decrypt (NIP-04)', () {
      test('encrypt encrypts plaintext', () async {
        when(() => mockKeyContainer.withPrivateKey<String>(any())).thenAnswer((
          invocation,
        ) {
          final callback =
              invocation.positionalArguments[0] as String Function(String);
          return callback(testPrivateKey);
        });

        final signer = LocalKeySigner(mockKeyContainer);
        const plaintext = 'Hello, World!';

        final ciphertext = await signer.encrypt(testPublicKey, plaintext);

        expect(ciphertext, isNotNull);
        expect(ciphertext, isNot(equals(plaintext)));
      });

      // #7332: NIP-04 has no un-awaited-future bug — its callback is
      // synchronous — but `on Exception` still let an `Error` through.
      // `NIP04.getPubkey` catches the off-curve `Error` from `liftX`, leaves
      // `y` null, then dereferences `y!`, so an off-curve pubkey raised a
      // `TypeError` out of a method declared `Future<String?>`.
      test('encrypt throws a typed failure for an off-curve pubkey', () async {
        when(() => mockKeyContainer.withPrivateKey<String>(any())).thenAnswer((
          invocation,
        ) {
          final callback =
              invocation.positionalArguments[0] as String Function(String);
          return callback(testPrivateKey);
        });

        final signer = LocalKeySigner(mockKeyContainer);

        await expectLater(
          signer.encrypt(offCurvePubkey, 'Hello!'),
          throwsA(isA<LocalSignerOperationException>()),
        );
      });

      test('decrypt throws a typed failure for an off-curve pubkey', () async {
        when(() => mockKeyContainer.withPrivateKey<String>(any())).thenAnswer((
          invocation,
        ) {
          final callback =
              invocation.positionalArguments[0] as String Function(String);
          return callback(testPrivateKey);
        });

        final signer = LocalKeySigner(mockKeyContainer);

        // The IV must be real base64, or `base64.decode` throws a
        // FormatException — an Exception, which the old handler already
        // caught — and we never reach the off-curve `Error` path.
        await expectLater(
          signer.decrypt(offCurvePubkey, 'AA==?iv=AAAAAAAAAAAAAAAAAAAAAA=='),
          throwsA(isA<LocalSignerOperationException>()),
        );
      });

      test('decrypt decrypts ciphertext', () async {
        when(() => mockKeyContainer.withPrivateKey<String>(any())).thenAnswer((
          invocation,
        ) {
          final callback =
              invocation.positionalArguments[0] as String Function(String);
          return callback(testPrivateKey);
        });

        final signer = LocalKeySigner(mockKeyContainer);
        const plaintext = 'Hello, World!';

        // First encrypt
        final ciphertext = await signer.encrypt(testPublicKey, plaintext);
        // Then decrypt
        final decrypted = await signer.decrypt(testPublicKey, ciphertext);

        expect(decrypted, equals(plaintext));
      });
    });

    group('nip44Encrypt/nip44Decrypt', () {
      // The conversation key is derived inside the synchronous
      // `withPrivateKey` scope; the cipher call happens outside it.
      void stubConversationKeyDerivation() {
        when(
          () => mockKeyContainer.withPrivateKey<Uint8List>(any()),
        ).thenAnswer((invocation) {
          final callback =
              invocation.positionalArguments[0] as Uint8List Function(String);
          return callback(testPrivateKey);
        });
      }

      test('nip44Encrypt encrypts plaintext', () async {
        stubConversationKeyDerivation();

        final signer = LocalKeySigner(mockKeyContainer);
        const plaintext = 'Hello, NIP-44!';

        final ciphertext = await signer.nip44Encrypt(testPublicKey, plaintext);

        expect(ciphertext, isNotNull);
        expect(ciphertext, isNot(equals(plaintext)));
      });

      test('nip44Decrypt decrypts ciphertext', () async {
        stubConversationKeyDerivation();

        final signer = LocalKeySigner(mockKeyContainer);
        const plaintext = 'Hello, NIP-44!';

        // First encrypt
        final ciphertext = await signer.nip44Encrypt(testPublicKey, plaintext);
        // Then decrypt
        final decrypted = await signer.nip44Decrypt(testPublicKey, ciphertext);

        expect(decrypted, equals(plaintext));
      });

      // #7332: these methods returned a future out of the `try`, so the
      // `on Exception` handler was unreachable. The signer now exposes the
      // failure as one typed exception, and Keycast decides explicitly whether
      // to fall back to RPC.
      test('nip44Decrypt throws a typed failure for an invalid MAC', () async {
        stubConversationKeyDerivation();

        final signer = LocalKeySigner(mockKeyContainer);
        final ciphertext = await signer.nip44Encrypt(testPublicKey, 'hello');
        // Flip the last byte of the payload so the HMAC check fails.
        final bytes = List<int>.from(base64Decode(ciphertext));
        bytes[bytes.length - 1] ^= 0xFF;

        await expectLater(
          signer.nip44Decrypt(testPublicKey, base64Encode(bytes)),
          throwsA(isA<LocalSignerOperationException>()),
        );
      });

      test(
        'nip44Decrypt throws a typed failure for an invalid payload',
        () async {
          stubConversationKeyDerivation();

          final signer = LocalKeySigner(mockKeyContainer);

          await expectLater(
            signer.nip44Decrypt(testPublicKey, 'not-base64-!!!'),
            throwsA(isA<LocalSignerOperationException>()),
          );
        },
      );

      test(
        'nip44Encrypt throws a typed failure for an off-curve pubkey',
        () async {
          stubConversationKeyDerivation();

          final signer = LocalKeySigner(mockKeyContainer);

          // A Nostr pubkey is a secp256k1 x-coordinate and only about half of
          // all 32-byte values have a matching y, so a well-formed hex string
          // can still name nobody. ECDH raises ArgumentError — an Error, not an
          // Exception, so `on Exception` would not have caught it either.
          await expectLater(
            signer.nip44Encrypt(offCurvePubkey, 'hello'),
            throwsA(isA<LocalSignerOperationException>()),
          );
        },
      );

      test(
        'nip44Decrypt throws a typed failure for an off-curve pubkey',
        () async {
          stubConversationKeyDerivation();

          final signer = LocalKeySigner(mockKeyContainer);

          await expectLater(
            signer.nip44Decrypt(offCurvePubkey, 'AgAB'),
            throwsA(isA<LocalSignerOperationException>()),
          );
        },
      );

      test(
        'nip44Encrypt throws a typed failure when the container refuses',
        () async {
          when(
            () => mockKeyContainer.withPrivateKey<Uint8List>(any()),
          ).thenThrow(const SecureKeyException('Container has been disposed'));

          final signer = LocalKeySigner(mockKeyContainer);

          await expectLater(
            signer.nip44Encrypt(testPublicKey, 'hello'),
            throwsA(
              isA<LocalSignerOperationException>().having(
                (error) => error.cause,
                'cause',
                isA<SecureKeyException>(),
              ),
            ),
          );
        },
      );
    });

    group('close', () {
      test('closes without error', () {
        final signer = LocalKeySigner(mockKeyContainer);

        expect(signer.close, returnsNormally);
      });
    });
  });
}
