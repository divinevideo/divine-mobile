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
  // A well-formed payload this sender encrypted to a third key, so the test
  // key cannot read it.
  const otherSenderPubkey =
      '6f84e1157c594a3a30ee25943c44a96106076e9184aded89c2f73946e0252286';
  const payloadForAnotherRecipient =
      'frkb1N4rnki0zNjn4gnQKSbcUEcgY2X8lgN8zk+MT4qUxMB2IIlUH9dURh0H014W'
      '?iv=KR5RbN4CZE7tdq9XxeeLsA==';

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

      test('uses native Schnorr signer when available', () async {
        when(
          () => mockKeyContainer.withPrivateKey<Future<String>>(any()),
        ).thenAnswer((invocation) {
          final callback =
              invocation.positionalArguments[0]
                  as Future<String> Function(String);
          return callback(testPrivateKey);
        });

        var nativeCalls = 0;
        final fakeSig = 'a' * 128;
        final signer = LocalKeySigner(
          mockKeyContainer,
          nativeSchnorrSigner:
              ({
                required privateKey,
                required message,
                auxRand,
              }) async {
                nativeCalls++;
                expect(privateKey, equals(testPrivateKey));
                expect(message, hasLength(64));
                expect(auxRand, hasLength(64));
                return fakeSig;
              },
        );
        final event = Event(
          testPublicKey,
          EventKind.textNote,
          [],
          'Native sign test',
        );

        final signedEvent = await signer.signEvent(event);

        expect(nativeCalls, equals(1));
        expect(signedEvent.sig, equals(fakeSig));
      });

      test(
        'falls back to Dart signing permanently after a native signer failure',
        () async {
          when(
            () => mockKeyContainer.withPrivateKey<Future<String>>(any()),
          ).thenAnswer((invocation) {
            final callback =
                invocation.positionalArguments[0]
                    as Future<String> Function(String);
            return callback(testPrivateKey);
          });
          when(() => mockKeyContainer.withPrivateKey<Event>(any())).thenAnswer((
            invocation,
          ) {
            final callback =
                invocation.positionalArguments[0] as Event Function(String);
            return callback(testPrivateKey);
          });

          var nativeCalls = 0;
          final signer = LocalKeySigner(
            mockKeyContainer,
            nativeSchnorrSigner:
                ({
                  required privateKey,
                  required message,
                  auxRand,
                }) async {
                  nativeCalls++;
                  throw UnsupportedError('WebCrypto unavailable');
                },
          );

          final first = await signer.signEvent(
            Event(testPublicKey, EventKind.textNote, [], 'First'),
          );
          final second = await signer.signEvent(
            Event(testPublicKey, EventKind.textNote, [], 'Second'),
          );

          expect(nativeCalls, equals(1));
          expect(first.isSigned, isTrue);
          expect(second.isSigned, isTrue);
        },
      );
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

      test(
        'uses native Schnorr signer with deterministic zero auxRand',
        () async {
          when(
            () => mockKeyContainer.withPrivateKey<Future<String>>(any()),
          ).thenAnswer((invocation) {
            final callback =
                invocation.positionalArguments[0]
                    as Future<String> Function(String);
            return callback(testPrivateKey);
          });

          String? capturedAux;
          final fakeSig = 'b' * 128;
          final signer = LocalKeySigner(
            mockKeyContainer,
            nativeSchnorrSigner:
                ({
                  required privateKey,
                  required message,
                  auxRand,
                }) async {
                  capturedAux = auxRand;
                  return fakeSig;
                },
          );

          final sig = await signer.signCanonicalPayload(
            Uint8List.fromList([1, 2, 3]),
          );

          expect(sig, equals(fakeSig));
          expect(capturedAux, equals('0' * 64));
        },
      );
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

        // A well-formed payload, so the peer key is what fails here and not
        // the payload shape NIP04.decrypt rejects on its own (#8712).
        await expectLater(
          signer.decrypt(
            offCurvePubkey,
            'AAAAAAAAAAAAAAAAAAAAAA==?iv=AAAAAAAAAAAAAAAAAAAAAA==',
          ),
          throwsA(
            isA<LocalSignerOperationException>().having(
              (e) => e.cause,
              'cause',
              isA<Error>(),
            ),
          ),
        );
      });

      test(
        'decrypt throws a typed failure for a payload without ?iv=',
        () async {
          when(() => mockKeyContainer.withPrivateKey<String>(any())).thenAnswer(
            (
              invocation,
            ) {
              final callback =
                  invocation.positionalArguments[0] as String Function(String);
              return callback(testPrivateKey);
            },
          );

          final signer = LocalKeySigner(mockKeyContainer);

          // This used to come back as "", which callers read as a message that
          // decrypted to nothing (#8712).
          await expectLater(
            signer.decrypt(testPublicKey, 'garbage!!!'),
            throwsA(
              isA<LocalSignerOperationException>().having(
                (e) => e.cause,
                'cause',
                isA<FormatException>(),
              ),
            ),
          );
        },
      );

      test(
        'decrypt throws a typed failure for a payload sent to another key',
        () async {
          when(() => mockKeyContainer.withPrivateKey<String>(any())).thenAnswer(
            (invocation) {
              final callback =
                  invocation.positionalArguments[0] as String Function(String);
              return callback(testPrivateKey);
            },
          );

          final signer = LocalKeySigner(mockKeyContainer);

          // The cipher used to throw a raw ArgumentError here (#8712).
          await expectLater(
            signer.decrypt(otherSenderPubkey, payloadForAnotherRecipient),
            throwsA(
              isA<LocalSignerOperationException>().having(
                (e) => e.cause,
                'cause',
                isA<FormatException>(),
              ),
            ),
          );
        },
      );

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
