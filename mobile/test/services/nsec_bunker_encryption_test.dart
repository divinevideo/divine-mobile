// ABOUTME: Unit tests for NsecBunkerClient NIP-04 encryption functionality
// ABOUTME: Tests encryption/decryption of NIP-46 bunker messages using NIP-04 standard

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/nsec_bunker_client.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:nostr_sdk/client_utils/keys.dart' as keys;
import 'package:nostr_sdk/nip04/nip04.dart';

class MockWebSocketChannel extends Mock {
  // Mock WebSocket channel for testing
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NsecBunkerClient NIP-04 Encryption Tests', () {
    late NsecBunkerClient bunkerClient;
    const testEndpoint = 'https://bunker.test.com/auth';

    // Test keys for encryption
    late String clientPrivateKey;
    late String clientPublicKey;
    late String bunkerPrivateKey;
    late String bunkerPublicKey;

    setUp(() {
      // Generate test keys
      clientPrivateKey = keys.generatePrivateKey();
      clientPublicKey = keys.getPublicKey(clientPrivateKey);
      bunkerPrivateKey = keys.generatePrivateKey();
      bunkerPublicKey = keys.getPublicKey(bunkerPrivateKey);

      Log.info(
        'Test keys generated',
        name: 'Test',
        category: LogCategory.system,
      );

      bunkerClient = NsecBunkerClient(authEndpoint: testEndpoint);
    });

    tearDown(() {
      bunkerClient.disconnect();
    });

    group('Key Generation', () {
      test('should generate valid ephemeral client keypair', () {
        // Act
        final privateKey = bunkerClient.generateClientPrivateKey();
        final publicKey = bunkerClient.getClientPublicKey(privateKey);

        // Assert
        expect(privateKey, isNotNull);
        expect(privateKey.length, equals(64)); // 32 bytes hex
        expect(keys.keyIsValid(privateKey), isTrue);

        expect(publicKey, isNotNull);
        expect(publicKey.length, equals(64)); // 32 bytes hex
        expect(keys.keyIsValid(publicKey), isTrue);
      });

      test('should generate different keys each time', () {
        // Act
        final key1 = bunkerClient.generateClientPrivateKey();
        final key2 = bunkerClient.generateClientPrivateKey();

        // Assert
        expect(key1, isNot(equals(key2)));
      });
    });

    group('NIP-04 Encryption', () {
      test('should encrypt content using NIP-04 standard', () {
        // Arrange
        const plaintext = 'Test message for encryption';
        bunkerClient.setClientKeys(clientPrivateKey, clientPublicKey);
        bunkerClient.setBunkerPublicKey(bunkerPublicKey);

        // Act
        final encrypted = bunkerClient.encryptContent(plaintext);

        // Assert
        expect(encrypted, isNotNull);
        expect(encrypted, contains('?iv=')); // NIP-04 format
        expect(NIP04.isEncrypted(encrypted), isTrue);
        expect(encrypted, isNot(equals(plaintext)));
      });

      test('should decrypt content using NIP-04 standard', () {
        // Arrange
        const plaintext = 'Test message for decryption';

        // Encrypt using bunker's perspective
        final agreement = NIP04.getAgreement(bunkerPrivateKey);
        final encrypted = NIP04.encrypt(plaintext, agreement, clientPublicKey);

        bunkerClient.setClientKeys(clientPrivateKey, clientPublicKey);
        bunkerClient.setBunkerPublicKey(bunkerPublicKey);

        // Act
        final decrypted = bunkerClient.decryptContent(encrypted);

        // Assert
        expect(decrypted, equals(plaintext));
      });

      test('should handle round-trip encryption/decryption', () {
        // Arrange
        const plaintext = 'Round-trip test message';
        bunkerClient.setClientKeys(clientPrivateKey, clientPublicKey);
        bunkerClient.setBunkerPublicKey(bunkerPublicKey);

        // Act - Client encrypts to bunker
        final clientEncrypted = bunkerClient.encryptContent(plaintext);

        // Bunker decrypts
        final bunkerAgreement = NIP04.getAgreement(bunkerPrivateKey);
        final bunkerDecrypted = NIP04.decrypt(
          clientEncrypted,
          bunkerAgreement,
          clientPublicKey,
        );

        // Bunker encrypts response
        const response = 'Response from bunker';
        final bunkerEncrypted = NIP04.encrypt(
          response,
          bunkerAgreement,
          clientPublicKey,
        );

        // Client decrypts response
        final clientDecrypted = bunkerClient.decryptContent(bunkerEncrypted);

        // Assert
        expect(bunkerDecrypted, equals(plaintext));
        expect(clientDecrypted, equals(response));
      });

      test('should fail to decrypt with wrong key', () {
        // Arrange
        const plaintext = 'Secret message';
        final wrongPrivateKey = keys.generatePrivateKey();
        final wrongPublicKey = keys.getPublicKey(wrongPrivateKey);

        // Encrypt with correct key
        final agreement = NIP04.getAgreement(bunkerPrivateKey);
        final encrypted = NIP04.encrypt(plaintext, agreement, clientPublicKey);

        // Try to decrypt with wrong key
        bunkerClient.setClientKeys(wrongPrivateKey, wrongPublicKey);
        bunkerClient.setBunkerPublicKey(bunkerPublicKey);

        // Act
        final decrypted = bunkerClient.decryptContent(encrypted);

        // Assert - Wrong key should result in garbage or empty string
        expect(decrypted, isNot(equals(plaintext)));
      });

      test('should handle invalid encrypted content gracefully', () {
        // Arrange
        bunkerClient.setClientKeys(clientPrivateKey, clientPublicKey);
        bunkerClient.setBunkerPublicKey(bunkerPublicKey);

        // Act & Assert
        expect(
          bunkerClient.decryptContent('invalid_encrypted_data'),
          equals(''),
        ); // Returns empty string for invalid data
        expect(
          bunkerClient.decryptContent('no_iv_marker'),
          equals(''),
        ); // Returns empty string when no IV marker
      });
    });

    group('NIP-46 Request Event Creation', () {
      test('should create properly formatted NIP-46 request event', () {
        // Arrange
        bunkerClient.setClientKeys(clientPrivateKey, clientPublicKey);
        bunkerClient.setBunkerPublicKey(bunkerPublicKey);

        final request = {
          'id': '12345',
          'method': 'sign_event',
          'params': [
            {
              'kind': 1,
              'content': 'Test note',
              'created_at': 1234567890,
              'tags': [],
            },
          ],
        };

        // Act
        final event = bunkerClient.createRequestEvent(request);

        // Assert
        expect(event['kind'], equals(24133)); // NIP-46 request kind
        expect(event['pubkey'], equals(clientPublicKey));
        expect(event['tags'], isA<List>());

        // Check p tag for bunker pubkey
        final pTags = (event['tags'] as List)
            .where((tag) => tag[0] == 'p')
            .toList();
        expect(pTags.length, equals(1));
        expect(pTags[0][1], equals(bunkerPublicKey));

        // Check content is encrypted
        expect(NIP04.isEncrypted(event['content'] as String), isTrue);

        // Verify bunker can decrypt the content
        final bunkerAgreement = NIP04.getAgreement(bunkerPrivateKey);
        final decryptedContent = NIP04.decrypt(
          event['content'] as String,
          bunkerAgreement,
          clientPublicKey,
        );
        expect(decryptedContent, contains('sign_event'));
      });

      test('should handle connect request with secret', () {
        // Arrange
        bunkerClient.setClientKeys(clientPrivateKey, clientPublicKey);
        bunkerClient.setBunkerPublicKey(bunkerPublicKey);
        const secret = 'test_secret_123';

        final connectRequest = {
          'id': 'connect_1',
          'method': 'connect',
          'params': [clientPublicKey, secret],
        };

        // Act
        final event = bunkerClient.createRequestEvent(connectRequest);

        // Assert
        expect(event['kind'], equals(24133));

        // Decrypt and verify content
        final bunkerAgreement = NIP04.getAgreement(bunkerPrivateKey);
        final decryptedContent = NIP04.decrypt(
          event['content'] as String,
          bunkerAgreement,
          clientPublicKey,
        );

        expect(decryptedContent, contains('connect'));
        expect(decryptedContent, contains(secret));
      });
    });

    group('NIP-46 Response Processing', () {
      test('should process encrypted response from bunker', () {
        // Arrange
        bunkerClient.setClientKeys(clientPrivateKey, clientPublicKey);
        bunkerClient.setBunkerPublicKey(bunkerPublicKey);

        const responseData = {
          'id': '12345',
          'result': {
            'id': 'event_id_123',
            'pubkey': 'user_pubkey',
            'sig': 'signature_abc',
          },
        };

        // Bunker encrypts response
        final bunkerAgreement = NIP04.getAgreement(bunkerPrivateKey);
        final encryptedContent = NIP04.encrypt(
          jsonEncode(responseData),
          bunkerAgreement,
          clientPublicKey,
        );

        final event = {
          'kind': 24133,
          'pubkey': bunkerPublicKey,
          'content': encryptedContent,
          'tags': [
            ['p', clientPublicKey],
          ],
        };

        // Act
        final response = bunkerClient.processResponse(event);

        // Assert
        expect(response, isNotNull);
        expect(response!['id'], equals('12345'));
        expect(response['result'], isA<Map>());
        expect(response['result']['id'], equals('event_id_123'));
      });

      test('should handle error responses', () {
        // Arrange
        bunkerClient.setClientKeys(clientPrivateKey, clientPublicKey);
        bunkerClient.setBunkerPublicKey(bunkerPublicKey);

        const errorResponse = {
          'id': '12345',
          'error': 'User rejected signing request',
        };

        // Bunker encrypts error response
        final bunkerAgreement = NIP04.getAgreement(bunkerPrivateKey);
        final encryptedContent = NIP04.encrypt(
          jsonEncode(errorResponse),
          bunkerAgreement,
          clientPublicKey,
        );

        final event = {
          'kind': 24133,
          'pubkey': bunkerPublicKey,
          'content': encryptedContent,
          'tags': [
            ['p', clientPublicKey],
          ],
        };

        // Act
        final response = bunkerClient.processResponse(event);

        // Assert
        expect(response, isNotNull);
        expect(response!['id'], equals('12345'));
        expect(response['error'], equals('User rejected signing request'));
        expect(response['result'], isNull);
      });
    });

    group('Integration with BunkerConfig', () {
      test('should use bunker pubkey from config for encryption', () {
        // Arrange
        final config = BunkerConfig(
          relayUrl: 'wss://relay.test.com',
          bunkerPubkey: bunkerPublicKey,
          secret: 'config_secret',
          permissions: ['sign_event', 'nip04_encrypt', 'nip04_decrypt'],
        );

        bunkerClient.setConfig(config);
        bunkerClient.setClientKeys(clientPrivateKey, clientPublicKey);

        // Act
        const message = 'Test with config';
        final encrypted = bunkerClient.encryptContent(message);

        // Bunker can decrypt
        final bunkerAgreement = NIP04.getAgreement(bunkerPrivateKey);
        final decrypted = NIP04.decrypt(
          encrypted,
          bunkerAgreement,
          clientPublicKey,
        );

        // Assert
        expect(decrypted, equals(message));
      });

      test('should verify NIP-04 permissions in config', () {
        // Arrange
        final config = BunkerConfig(
          relayUrl: 'wss://relay.test.com',
          bunkerPubkey: bunkerPublicKey,
          secret: 'config_secret',
          permissions: ['sign_event', 'nip04_encrypt', 'nip04_decrypt'],
        );

        // Act & Assert
        expect(config.permissions.contains('nip04_encrypt'), isTrue);
        expect(config.permissions.contains('nip04_decrypt'), isTrue);
      });
    });
  });

  group('NsecBunkerClient Public Methods', () {
    late NsecBunkerClient bunkerClient;

    setUp(() {
      bunkerClient = NsecBunkerClient(authEndpoint: 'https://test.com');
    });

    test('should expose encryption capability check', () {
      // Act & Assert
      expect(bunkerClient.supportsNIP04Encryption(), isTrue);
    });

    test('should require configuration before encryption', () {
      // Act & Assert
      expect(
        () => bunkerClient.encryptContent('test'),
        throwsA(isA<StateError>()),
      );
    });
  });
}

// Note: Test methods are now implemented in the actual NsecBunkerClient class
