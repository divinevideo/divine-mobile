// ABOUTME: Tests for LocalNostrSigner functionality including key generation and event signing
// ABOUTME: Validates that the local signer properly signs events and handles encryption

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('LocalNostrSigner Tests', () {
    test('Generate new signer with valid key pair', () async {
      final privateKey = generatePrivateKey();
      final signer = LocalNostrSigner(privateKey);
      final publicKey = await signer.getPublicKey();

      expect(publicKey, isNotNull);
      expect(publicKey!.length, equals(64)); // 32 bytes = 64 hex chars
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(publicKey), isTrue);
    });

    test('Create signer from existing private key', () async {
      // Use a test private key (this is just for testing, never use in production)
      final testPrivateKey = 'a' * 64;
      final signer = LocalNostrSigner(testPrivateKey);
      final publicKey = await signer.getPublicKey();

      expect(publicKey, isNotNull);
      expect(publicKey!.length, equals(64));
    });

    test('Sign event successfully', () async {
      final privateKey = generatePrivateKey();
      final signer = LocalNostrSigner(privateKey);
      final publicKey = await signer.getPublicKey();

      final event = Event(
        publicKey!,
        EventKind.textNote,
        [],
        'Test message for signing',
      );

      // Event should not be signed initially
      expect(event.isSigned, isFalse);
      expect(event.sig, isEmpty);

      // Sign the event
      final signedEvent = await signer.signEvent(event);

      expect(signedEvent, isNotNull);
      expect(signedEvent!.sig, isNotEmpty);
      expect(signedEvent.sig.length, equals(128)); // 64 bytes = 128 hex chars
      expect(signedEvent.isSigned, isTrue);
      expect(signedEvent.isValid, isTrue);
    });

    test('Encryption and decryption (NIP-04)', () async {
      final privateKey1 = generatePrivateKey();
      final privateKey2 = generatePrivateKey();
      final signer1 = LocalNostrSigner(privateKey1);
      final signer2 = LocalNostrSigner(privateKey2);

      final pubkey1 = await signer1.getPublicKey();
      final pubkey2 = await signer2.getPublicKey();

      const message = 'Secret message for encryption test';

      // Encrypt with signer1, decrypt with signer2
      final encrypted = await signer1.encrypt(pubkey2!, message);
      expect(encrypted, isNotNull);
      expect(encrypted!, isNot(equals(message)));

      final decrypted = await signer2.decrypt(pubkey1!, encrypted);
      expect(decrypted, equals(message));
    });

    test('NIP-44 encryption and decryption', () async {
      final privateKey1 = generatePrivateKey();
      final privateKey2 = generatePrivateKey();
      final signer1 = LocalNostrSigner(privateKey1);
      final signer2 = LocalNostrSigner(privateKey2);

      final pubkey1 = await signer1.getPublicKey();
      final pubkey2 = await signer2.getPublicKey();

      const message = 'Secret message for NIP-44 encryption test';

      // Encrypt with signer1, decrypt with signer2
      final encrypted = await signer1.nip44Encrypt(pubkey2!, message);
      expect(encrypted, isNotNull);
      expect(encrypted!, isNot(equals(message)));

      final decrypted = await signer2.nip44Decrypt(pubkey1!, encrypted);
      expect(decrypted, equals(message));
    });

    test('Multiple signers generate different keys', () async {
      final privateKey1 = generatePrivateKey();
      final privateKey2 = generatePrivateKey();
      final signer1 = LocalNostrSigner(privateKey1);
      final signer2 = LocalNostrSigner(privateKey2);

      final pubkey1 = await signer1.getPublicKey();
      final pubkey2 = await signer2.getPublicKey();

      expect(pubkey1, isNot(equals(pubkey2)));
    });

    test('Same private key produces same public key', () async {
      final testPrivateKey = 'b' * 64;

      final signer1 = LocalNostrSigner(testPrivateKey);
      final signer2 = LocalNostrSigner(testPrivateKey);

      final pubkey1 = await signer1.getPublicKey();
      final pubkey2 = await signer2.getPublicKey();

      expect(pubkey1, equals(pubkey2));
    });

    test(
      'Sign different events with same key produces different signatures',
      () async {
        final privateKey = generatePrivateKey();
        final signer = LocalNostrSigner(privateKey);
        final publicKey = await signer.getPublicKey();

        final event1 = Event(publicKey!, EventKind.textNote, [], 'Message 1');
        final event2 = Event(publicKey, EventKind.textNote, [], 'Message 2');

        final signed1 = await signer.signEvent(event1);
        final signed2 = await signer.signEvent(event2);

        expect(signed1!.sig, isNot(equals(signed2!.sig)));
        expect(signed1.id, isNot(equals(signed2.id)));
      },
    );

    test('getRelays returns null for LocalNostrSigner', () async {
      final privateKey = generatePrivateKey();
      final signer = LocalNostrSigner(privateKey);
      final relays = await signer.getRelays();

      expect(relays, isNull);
    });

    test('close method executes without error', () {
      final privateKey = generatePrivateKey();
      final signer = LocalNostrSigner(privateKey);

      expect(() => signer.close(), returnsNormally);
    });
  });
}
