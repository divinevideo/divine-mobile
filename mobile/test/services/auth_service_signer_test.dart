// ABOUTME: Tests for AuthServiceSigner that bridges AuthService with NostrSigner
// ABOUTME: Validates event signing, encryption, and key access through secure container

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service_signer.dart';

class _MockSecureKeyContainer extends Mock implements SecureKeyContainer {}

void main() {
  late _MockSecureKeyContainer mockKeyContainer;

  const testPrivateKey =
      '6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e';
  const testPublicKey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  setUpAll(() {
    registerFallbackValue(_MockSecureKeyContainer());
  });

  setUp(() {
    mockKeyContainer = _MockSecureKeyContainer();
    when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);
    when(() => mockKeyContainer.isDisposed).thenReturn(false);
  });

  group('AuthServiceSigner', () {
    group('getPublicKey', () {
      test('returns public key from secure container', () async {
        final signer = AuthServiceSigner(mockKeyContainer);

        final publicKey = await signer.getPublicKey();

        expect(publicKey, equals(testPublicKey));
        verify(() => mockKeyContainer.publicKeyHex).called(1);
      });

      test('throws when container is disposed', () async {
        when(() => mockKeyContainer.isDisposed).thenReturn(true);
        when(() => mockKeyContainer.publicKeyHex)
            .thenThrow(const SecureKeyException('Container has been disposed'));

        final signer = AuthServiceSigner(mockKeyContainer);

        expect(
          () => signer.getPublicKey(),
          throwsA(isA<SecureKeyException>()),
        );
      });
    });

    group('signEvent', () {
      test('signs event using secure container', () async {
        when(() => mockKeyContainer.withPrivateKey<Event>(any()))
            .thenAnswer((invocation) {
          final callback =
              invocation.positionalArguments[0] as Event Function(String);
          return callback(testPrivateKey);
        });

        final signer = AuthServiceSigner(mockKeyContainer);
        final event = Event(
          testPublicKey,
          EventKind.textNote,
          <List<dynamic>>[],
          'Test content',
        );

        final signedEvent = await signer.signEvent(event);

        expect(signedEvent, isNotNull);
        expect(signedEvent!.sig, isNotEmpty);
        verify(() => mockKeyContainer.withPrivateKey<Event>(any())).called(1);
      });

      test('returns null when signing fails', () async {
        when(() => mockKeyContainer.withPrivateKey<Event>(any()))
            .thenThrow(const SecureKeyException('Failed to sign'));

        final signer = AuthServiceSigner(mockKeyContainer);
        final event = Event(
          testPublicKey,
          EventKind.textNote,
          <List<dynamic>>[],
          'Test content',
        );

        final signedEvent = await signer.signEvent(event);

        expect(signedEvent, isNull);
      });
    });

    group('getRelays', () {
      test('returns null (no relay config)', () async {
        final signer = AuthServiceSigner(mockKeyContainer);

        final relays = await signer.getRelays();

        expect(relays, isNull);
      });
    });

    group('encrypt/decrypt (NIP-04)', () {
      test('encrypt encrypts plaintext', () async {
        when(() => mockKeyContainer.withPrivateKey<String?>(any()))
            .thenAnswer((invocation) {
          final callback =
              invocation.positionalArguments[0] as String? Function(String);
          return callback(testPrivateKey);
        });

        final signer = AuthServiceSigner(mockKeyContainer);
        const plaintext = 'Hello, World!';

        final ciphertext = await signer.encrypt(testPublicKey, plaintext);

        expect(ciphertext, isNotNull);
        expect(ciphertext, isNot(equals(plaintext)));
      });

      test('decrypt decrypts ciphertext', () async {
        when(() => mockKeyContainer.withPrivateKey<String?>(any()))
            .thenAnswer((invocation) {
          final callback =
              invocation.positionalArguments[0] as String? Function(String);
          return callback(testPrivateKey);
        });

        final signer = AuthServiceSigner(mockKeyContainer);
        const plaintext = 'Hello, World!';

        // First encrypt
        final ciphertext = await signer.encrypt(testPublicKey, plaintext);
        expect(ciphertext, isNotNull);

        // Then decrypt
        final decrypted = await signer.decrypt(testPublicKey, ciphertext!);

        expect(decrypted, equals(plaintext));
      });
    });

    group('nip44Encrypt/nip44Decrypt', () {
      test('nip44Encrypt encrypts plaintext', () async {
        when(() => mockKeyContainer.withPrivateKey<Future<String?>>(any()))
            .thenAnswer((invocation) {
          final callback = invocation.positionalArguments[0]
              as Future<String?> Function(String);
          return callback(testPrivateKey);
        });

        final signer = AuthServiceSigner(mockKeyContainer);
        const plaintext = 'Hello, NIP-44!';

        final ciphertext = await signer.nip44Encrypt(testPublicKey, plaintext);

        expect(ciphertext, isNotNull);
        expect(ciphertext, isNot(equals(plaintext)));
      });

      test('nip44Decrypt decrypts ciphertext', () async {
        when(() => mockKeyContainer.withPrivateKey<Future<String?>>(any()))
            .thenAnswer((invocation) {
          final callback = invocation.positionalArguments[0]
              as Future<String?> Function(String);
          return callback(testPrivateKey);
        });

        final signer = AuthServiceSigner(mockKeyContainer);
        const plaintext = 'Hello, NIP-44!';

        // First encrypt
        final ciphertext = await signer.nip44Encrypt(testPublicKey, plaintext);
        expect(ciphertext, isNotNull);

        // Then decrypt
        final decrypted =
            await signer.nip44Decrypt(testPublicKey, ciphertext!);

        expect(decrypted, equals(plaintext));
      });
    });

    group('close', () {
      test('closes without error', () {
        final signer = AuthServiceSigner(mockKeyContainer);

        expect(() => signer.close(), returnsNormally);
      });
    });
  });
}
