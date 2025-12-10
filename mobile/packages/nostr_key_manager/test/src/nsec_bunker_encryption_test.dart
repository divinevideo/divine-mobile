// ABOUTME: Unit tests for NsecBunkerClient public interface
// ABOUTME: Tests after migration to use nostr_sdk's NostrRemoteSigner

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';

import '../test_setup.dart';

void main() {
  group('NsecBunkerClient Public Interface Tests', () {
    late NsecBunkerClient bunkerClient;
    const testEndpoint = 'https://bunker.test.com/auth';

    setUp(() {
      setupTestEnvironment();
      bunkerClient = NsecBunkerClient(authEndpoint: testEndpoint);
    });

    tearDown(() {
      bunkerClient.disconnect();
    });

    group('Initialization', () {
      test('should create client with auth endpoint', () {
        // Assert
        expect(bunkerClient, isNotNull);
        expect(bunkerClient.isConnected, isFalse);
        expect(bunkerClient.userPubkey, isNull);
      });

      test('should not be connected initially', () {
        // Assert
        expect(bunkerClient.isConnected, isFalse);
      });
    });

    group('Configuration', () {
      test('should set bunker public key', () {
        // Arrange
        const testPubkey =
            'test_pubkey_123456789012345678901234567890123456789';

        // Act
        bunkerClient.setBunkerPublicKey(testPubkey);

        // Assert - Config should be created
        expect(
          bunkerClient.isConnected,
          isFalse,
        ); // Still not connected without relay
      });

      test('should set bunker config', () {
        // Arrange
        const config = BunkerConfig(
          relayUrl: 'wss://relay.test.com',
          bunkerPubkey: 'test_pubkey',
          secret: 'test_secret',
        );

        // Act
        bunkerClient.config = config;

        // Assert
        expect(bunkerClient.isConnected, isFalse); // Still not connected
      });
    });

    group('Connection State', () {
      test('should track connection state correctly', () {
        // Assert initial state
        expect(bunkerClient.isConnected, isFalse);
        expect(bunkerClient.userPubkey, isNull);
      });

      test('should disconnect cleanly when not connected', () {
        // Act & Assert - Should not throw
        expect(() => bunkerClient.disconnect(), returnsNormally);
        expect(bunkerClient.isConnected, isFalse);
      });
    });

    group('Authentication', () {
      test('should handle authentication failure without server', () async {
        // Act
        final result = await bunkerClient.authenticate(
          username: 'testuser',
          password: 'testpass',
        );

        // Assert - Should fail without real server
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });
    });

    group('BunkerConfig', () {
      test('should create config with default permissions', () {
        // Arrange & Act
        const config = BunkerConfig(
          relayUrl: 'wss://relay.test.com',
          bunkerPubkey: 'pubkey123',
          secret: 'secret123',
        );

        // Assert
        expect(config.relayUrl, equals('wss://relay.test.com'));
        expect(config.bunkerPubkey, equals('pubkey123'));
        expect(config.secret, equals('secret123'));
        expect(config.permissions, isEmpty);
      });

      test('should create config with custom permissions', () {
        // Arrange & Act
        const config = BunkerConfig(
          relayUrl: 'wss://relay.test.com',
          bunkerPubkey: 'pubkey123',
          secret: 'secret123',
          permissions: ['sign_event', 'get_public_key'],
        );

        // Assert
        expect(config.permissions.length, equals(2));
        expect(config.permissions, contains('sign_event'));
        expect(config.permissions, contains('get_public_key'));
      });

      test('should parse config from JSON', () {
        // Arrange
        final json = {
          'relay_url': 'wss://relay.test.com',
          'bunker_pubkey': 'pubkey123',
          'secret': 'secret123',
          'permissions': ['sign_event', 'get_public_key'],
        };

        // Act
        final config = BunkerConfig.fromJson(json);

        // Assert
        expect(config.relayUrl, equals('wss://relay.test.com'));
        expect(config.bunkerPubkey, equals('pubkey123'));
        expect(config.secret, equals('secret123'));
        expect(config.permissions.length, equals(2));
      });
    });

    group('BunkerAuthResult', () {
      test('should create success result', () {
        // Arrange
        const config = BunkerConfig(
          relayUrl: 'wss://relay.test.com',
          bunkerPubkey: 'pubkey123',
          secret: 'secret123',
        );

        // Act
        const result = BunkerAuthResult(
          success: true,
          config: config,
          userPubkey: 'user_pubkey_123',
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.config, isNotNull);
        expect(result.userPubkey, equals('user_pubkey_123'));
        expect(result.error, isNull);
      });

      test('should create failure result', () {
        // Act
        const result = BunkerAuthResult(
          success: false,
          error: 'Invalid credentials',
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.error, equals('Invalid credentials'));
        expect(result.config, isNull);
        expect(result.userPubkey, isNull);
      });
    });
  });
}
