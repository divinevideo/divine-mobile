// ABOUTME: Unit tests for WebAuthService nsec bunker authentication integration
// ABOUTME: Tests bunker authentication flow and signer functionality in WebAuthService

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/web_auth_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/utils/unified_logger.dart';

class MockNsecBunkerClient extends Mock implements NsecBunkerClient {}

class FakeUri extends Fake implements Uri {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  group('WebAuthService Bunker Integration Tests', () {
    late WebAuthService authService;
    late MockNsecBunkerClient mockBunkerClient;

    setUp(() {
      authService = WebAuthService();
      mockBunkerClient = MockNsecBunkerClient();
    });

    tearDown(() async {
      await authService.disconnect();
    });

    group('Bunker Authentication', () {
      test('should check if bunker is available in supported methods', () {
        // Act
        final methods = authService.availableMethods;

        // Assert - Currently bunker is disabled
        expect(methods.contains(WebAuthMethod.bunker), isFalse);
      });

      test('should authenticate with bunker using bunker URI', () async {
        // Arrange
        const bunkerUri = 'bunker://npub1234@relay.test.com?secret=test123';

        // Act
        final result = await authService.authenticateWithBunker(bunkerUri);

        // Assert - Currently returns temporary unavailable
        expect(result.success, isFalse);
        expect(result.errorCode, equals('TEMPORARILY_UNAVAILABLE'));
      });

      test(
        'should handle successful bunker authentication when enabled',
        () async {
          // This test will pass once bunker is re-enabled
          // Arrange
          const bunkerUri = 'bunker://npub1234@relay.test.com?secret=test123';
          const expectedPubkey = 'user_pubkey_123abc';

          // Mock the internal bunker service behavior
          authService.setBunkerClient(mockBunkerClient);

          final mockAuthResult = BunkerAuthResult(
            success: true,
            config: const BunkerConfig(
              relayUrl: 'wss://relay.test.com',
              bunkerPubkey: 'bunker_pubkey_456',
              secret: 'test123',
              permissions: ['sign_event', 'nip04_encrypt'],
            ),
            userPubkey: expectedPubkey,
          );

          when(
            () => mockBunkerClient.authenticateFromUri(bunkerUri),
          ).thenAnswer((_) async => mockAuthResult);
          when(() => mockBunkerClient.connect()).thenAnswer((_) async => true);
          when(() => mockBunkerClient.isConnected).thenReturn(true);
          when(() => mockBunkerClient.userPubkey).thenReturn(expectedPubkey);

          // Act
          final result = await authService.authenticateWithBunkerEnabled(
            bunkerUri,
          );

          // Assert
          expect(result.success, isTrue);
          expect(result.method, equals(WebAuthMethod.bunker));
          expect(result.publicKey, equals(expectedPubkey));
          expect(authService.isAuthenticated, isTrue);
          expect(authService.currentMethod, equals(WebAuthMethod.bunker));
          expect(authService.publicKey, equals(expectedPubkey));
        },
      );

      test('should handle bunker authentication failure', () async {
        // Arrange
        const bunkerUri = 'bunker://invalid@relay.test.com';

        authService.setBunkerClient(mockBunkerClient);

        final mockAuthResult = BunkerAuthResult(
          success: false,
          error: 'Invalid bunker URI format',
        );

        when(
          () => mockBunkerClient.authenticateFromUri(bunkerUri),
        ).thenAnswer((_) async => mockAuthResult);

        // Act
        final result = await authService.authenticateWithBunkerEnabled(
          bunkerUri,
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Invalid bunker URI'));
        expect(authService.isAuthenticated, isFalse);
      });

      test('should handle bunker connection failure after auth', () async {
        // Arrange
        const bunkerUri = 'bunker://npub1234@relay.test.com?secret=test123';

        authService.setBunkerClient(mockBunkerClient);

        final mockAuthResult = BunkerAuthResult(
          success: true,
          config: const BunkerConfig(
            relayUrl: 'wss://relay.test.com',
            bunkerPubkey: 'bunker_pubkey_456',
            secret: 'test123',
          ),
          userPubkey: 'user_pubkey_123',
        );

        when(
          () => mockBunkerClient.authenticateFromUri(bunkerUri),
        ).thenAnswer((_) async => mockAuthResult);
        when(
          () => mockBunkerClient.connect(),
        ).thenAnswer((_) async => false); // Connection fails

        // Act
        final result = await authService.authenticateWithBunkerEnabled(
          bunkerUri,
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Failed to connect'));
        expect(authService.isAuthenticated, isFalse);
      });
    });

    group('Bunker Signer', () {
      test('should create bunker signer after authentication', () async {
        // Arrange
        authService.setBunkerClient(mockBunkerClient);
        authService.setAuthenticatedWithBunker('user_pubkey_123');

        // Act
        final signer = authService.signer;

        // Assert
        expect(signer, isNotNull);
        expect(signer, isA<WebSigner>());
      });

      test('should sign events with bunker signer when enabled', () async {
        // Arrange
        authService.setBunkerClient(mockBunkerClient);
        authService.setAuthenticatedWithBunker('user_pubkey_123');

        final event = {
          'kind': 1,
          'content': 'Test note',
          'created_at': 1234567890,
          'tags': [],
        };

        final signedEvent = {
          ...event,
          'id': 'event_id_123',
          'pubkey': 'user_pubkey_123',
          'sig': 'signature_abc123',
        };

        when(
          () => mockBunkerClient.signEvent(event),
        ).thenAnswer((_) async => signedEvent);
        when(() => mockBunkerClient.isConnected).thenReturn(true);

        // Act
        final signer = authService.signer!;
        final result = await signer.signEvent(event);

        // Assert
        expect(result, isNotNull);
        expect(result!['id'], equals('event_id_123'));
        expect(result['sig'], equals('signature_abc123'));
      });

      test('should return null when bunker signing fails', () async {
        // Arrange
        authService.setBunkerClient(mockBunkerClient);
        authService.setAuthenticatedWithBunker('user_pubkey_123');

        final event = {
          'kind': 1,
          'content': 'Test note',
          'created_at': 1234567890,
          'tags': [],
        };

        when(
          () => mockBunkerClient.signEvent(event),
        ).thenAnswer((_) async => null);
        when(() => mockBunkerClient.isConnected).thenReturn(true);

        // Act
        final signer = authService.signer!;
        final result = await signer.signEvent(event);

        // Assert
        expect(result, isNull);
      });

      test('should handle bunker disconnection during signing', () async {
        // Arrange
        authService.setBunkerClient(mockBunkerClient);
        authService.setAuthenticatedWithBunker('user_pubkey_123');

        final event = {
          'kind': 1,
          'content': 'Test note',
          'created_at': 1234567890,
          'tags': [],
        };

        when(() => mockBunkerClient.isConnected).thenReturn(false);

        // Act
        final signer = authService.signer!;
        final result = await signer.signEvent(event);

        // Assert
        expect(result, isNull);
      });
    });

    group('Bunker URI Parsing', () {
      test('should parse valid bunker URI', () {
        // Arrange
        const uri =
            'bunker://npub1234567890abcdef@relay.example.com?secret=mysecret&perms=sign_event,nip04_encrypt';

        // Act
        final parsed = authService.parseBunkerUri(uri);

        // Assert
        expect(parsed, isNotNull);
        expect(parsed!['pubkey'], equals('npub1234567890abcdef'));
        expect(parsed['relay'], equals('relay.example.com'));
        expect(parsed['secret'], equals('mysecret'));
        expect(parsed['permissions'], contains('sign_event'));
        expect(parsed['permissions'], contains('nip04_encrypt'));
      });

      test('should reject invalid bunker URI scheme', () {
        // Arrange
        const uri = 'https://example.com/bunker';

        // Act
        final parsed = authService.parseBunkerUri(uri);

        // Assert
        expect(parsed, isNull);
      });

      test('should handle bunker URI without optional parameters', () {
        // Arrange
        const uri = 'bunker://npub1234567890abcdef@relay.example.com';

        // Act
        final parsed = authService.parseBunkerUri(uri);

        // Assert
        expect(parsed, isNotNull);
        expect(parsed!['pubkey'], equals('npub1234567890abcdef'));
        expect(parsed['relay'], equals('relay.example.com'));
        expect(parsed['secret'], isNull);
        expect(parsed['permissions'], isEmpty);
      });
    });

    group('Method Switching', () {
      test('should disconnect NIP-07 when switching to bunker', () async {
        // Arrange - First authenticate with NIP-07 (mock)
        authService.setAuthenticatedWithNip07('nip07_pubkey');
        expect(authService.currentMethod, equals(WebAuthMethod.nip07));

        // Setup bunker mock
        authService.setBunkerClient(mockBunkerClient);

        const bunkerUri = 'bunker://npub1234@relay.test.com?secret=test123';
        final mockAuthResult = BunkerAuthResult(
          success: true,
          config: const BunkerConfig(
            relayUrl: 'wss://relay.test.com',
            bunkerPubkey: 'bunker_pubkey',
            secret: 'test123',
          ),
          userPubkey: 'bunker_pubkey_user',
        );

        when(
          () => mockBunkerClient.authenticateFromUri(bunkerUri),
        ).thenAnswer((_) async => mockAuthResult);
        when(() => mockBunkerClient.connect()).thenAnswer((_) async => true);
        when(() => mockBunkerClient.isConnected).thenReturn(true);

        // Act
        await authService.authenticateWithBunkerEnabled(bunkerUri);

        // Assert
        expect(authService.currentMethod, equals(WebAuthMethod.bunker));
        expect(authService.publicKey, equals('bunker_pubkey_user'));
      });
    });

    group('Debug Information', () {
      test('should include bunker status in debug info', () {
        // Act
        final debugInfo = authService.getDebugInfo();

        // Assert
        expect(debugInfo['bunkerInfo'], isNotNull);
        expect(
          debugInfo['bunkerInfo']['status'],
          equals('temporarily_disabled'),
        );
      });

      test('should show bunker details when authenticated', () {
        // Arrange
        authService.setBunkerClient(mockBunkerClient);
        authService.setAuthenticatedWithBunker('user_pubkey_123');

        when(() => mockBunkerClient.isConnected).thenReturn(true);
        when(() => mockBunkerClient.userPubkey).thenReturn('user_pubkey_123');

        // Act
        final debugInfo = authService.getDebugInfo();

        // Assert
        expect(debugInfo['isAuthenticated'], isTrue);
        expect(debugInfo['currentMethod'], equals('bunker'));
        expect(debugInfo['publicKey'], equals('user_pubkey_123'));
      });
    });

    group('Bunker Disconnect', () {
      test('should properly disconnect bunker client', () async {
        // Arrange
        authService.setBunkerClient(mockBunkerClient);
        authService.setAuthenticatedWithBunker('user_pubkey_123');

        when(() => mockBunkerClient.disconnect()).thenReturn(null);

        // Act
        await authService.disconnect();

        // Assert
        verify(
          () => mockBunkerClient.disconnect(),
        ).called(2); // Called by WebAuthService and BunkerSignerImpl.dispose()
        expect(authService.isAuthenticated, isFalse);
        expect(authService.currentMethod, equals(WebAuthMethod.none));
        expect(authService.signer, isNull);
      });
    });

    group('Method Display Names', () {
      test('should return correct display name for bunker method', () {
        // Act
        final displayName = authService.getMethodDisplayName(
          WebAuthMethod.bunker,
        );

        // Assert
        expect(displayName, equals('nsec bunker'));
      });
    });
  });

  group('BunkerSigner Implementation', () {
    late BunkerSigner bunkerSigner;
    late MockNsecBunkerClient mockBunkerClient;

    setUp(() {
      mockBunkerClient = MockNsecBunkerClient();
      bunkerSigner = BunkerSigner(mockBunkerClient);
    });

    test('should delegate signing to bunker client when implemented', () async {
      // Arrange
      final event = {
        'kind': 1,
        'content': 'Test',
        'created_at': 1234567890,
        'tags': [],
      };

      final signedEvent = {
        ...event,
        'id': 'event_id',
        'pubkey': 'pubkey',
        'sig': 'signature',
      };

      when(() => mockBunkerClient.isConnected).thenReturn(true);
      when(
        () => mockBunkerClient.signEvent(event),
      ).thenAnswer((_) async => signedEvent);

      // Act
      final result = await bunkerSigner.signEvent(event);

      // Assert
      expect(result, equals(signedEvent));
      verify(() => mockBunkerClient.signEvent(event)).called(1);
    });

    test('should handle signing errors gracefully', () async {
      // Arrange
      final event = {'kind': 1, 'content': 'Test'};

      when(() => mockBunkerClient.isConnected).thenReturn(true);
      when(
        () => mockBunkerClient.signEvent(event),
      ).thenThrow(Exception('Signing failed'));

      // Act
      final result = await bunkerSigner.signEvent(event);

      // Assert
      expect(result, isNull);
    });

    test('should properly dispose bunker resources', () {
      // Arrange
      when(() => mockBunkerClient.disconnect()).thenReturn(null);

      // Act
      bunkerSigner.dispose();

      // Assert
      verify(() => mockBunkerClient.disconnect()).called(1);
    });
  });
}

// Note: Test methods are now implemented in the actual WebAuthService and NsecBunkerClient classes

// Extended BunkerSigner for testing - matches the implementation in WebAuthService
class BunkerSigner extends WebSigner {
  final NsecBunkerClient _client;

  BunkerSigner(this._client);

  @override
  Future<Map<String, dynamic>?> signEvent(Map<String, dynamic> event) async {
    if (!_client.isConnected) {
      Log.error(
        'Cannot sign: bunker not connected',
        name: 'BunkerSigner',
        category: LogCategory.auth,
      );
      return null;
    }

    try {
      return await _client.signEvent(event);
    } catch (e) {
      Log.error(
        'Bunker signing error: $e',
        name: 'BunkerSigner',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  @override
  void dispose() {
    _client.disconnect();
  }
}
