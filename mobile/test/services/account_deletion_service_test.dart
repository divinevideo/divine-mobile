// ABOUTME: Tests for NIP-62 account deletion service
// ABOUTME: Verifies kind 62 event creation, ALL_RELAYS tag, and broadcast behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';

import 'account_deletion_service_test.mocks.dart';

@GenerateMocks([INostrService, AuthService, NostrKeyManager, Keychain])
void main() {
  group('AccountDeletionService', () {
    late MockINostrService mockNostrService;
    late MockAuthService mockAuthService;
    late MockNostrKeyManager mockKeyManager;
    late MockKeychain mockKeychain;
    late AccountDeletionService service;
    late String testPrivateKey;
    late String testPublicKey;

    setUp(() {
      // Generate valid keys for testing
      testPrivateKey = generatePrivateKey();
      testPublicKey = getPublicKey(testPrivateKey);

      mockNostrService = MockINostrService();
      mockAuthService = MockAuthService();
      mockKeyManager = MockNostrKeyManager();
      mockKeychain = MockKeychain();
      service = AccountDeletionService(
        nostrService: mockNostrService,
        authService: mockAuthService,
      );

      // Setup common mocks with valid keys
      when(mockNostrService.keyManager).thenReturn(mockKeyManager);
      when(mockKeyManager.keyPair).thenReturn(mockKeychain);
      when(mockKeychain.public).thenReturn(testPublicKey);
      when(mockKeychain.private).thenReturn(testPrivateKey);
    });

    test('createNip62Event should create kind 62 event', () async {
      // Arrange
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(mockNostrService.hasKeys).thenReturn(true);

      // Act
      final event = await service.createNip62Event(
        reason: 'User requested account deletion',
      );

      // Assert
      expect(event, isNotNull);
      expect(event!.kind, equals(62));
    });

    test('createNip62Event should include ALL_RELAYS tag', () async {
      // Arrange
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(mockNostrService.hasKeys).thenReturn(true);

      // Act
      final event = await service.createNip62Event(
        reason: 'User requested account deletion',
      );

      // Assert
      expect(event, isNotNull);
      expect(
        event!.tags.any(
          (tag) =>
              tag.length == 2 && tag[0] == 'relay' && tag[1] == 'ALL_RELAYS',
        ),
        isTrue,
      );
    });

    test('createNip62Event should include user pubkey', () async {
      // Arrange
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(mockNostrService.hasKeys).thenReturn(true);

      // Act
      final event = await service.createNip62Event(
        reason: 'User requested account deletion',
      );

      // Assert
      expect(event, isNotNull);
      expect(event!.pubkey, equals(testPublicKey));
    });

    test('deleteAccount should broadcast NIP-62 event', () async {
      // Arrange
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(mockNostrService.hasKeys).thenReturn(true);

      when(mockNostrService.broadcastEvent(any)).thenAnswer(
        (_) async => NostrBroadcastResult(
          event: Event(
            testPublicKey,
            62,
            [
              ['relay', 'ALL_RELAYS'],
            ],
            'test content',
            createdAt: 1234567890,
          ),
          successCount: 3,
          totalRelays: 3,
          results: {'relay1': true, 'relay2': true, 'relay3': true},
          errors: {},
        ),
      );

      // Act
      await expectLater(service.deleteAccount(), completes);

      // Assert
      verify(mockNostrService.broadcastEvent(any)).called(1);
    });

    test(
      'deleteAccount should return success when broadcast succeeds',
      () async {
        // Arrange
        when(mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
        when(mockNostrService.hasKeys).thenReturn(true);

        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: Event(
              testPublicKey,
              62,
              [
                ['relay', 'ALL_RELAYS'],
              ],
              'test content',
              createdAt: 1234567890,
            ),
            successCount: 3,
            totalRelays: 3,
            results: {'relay1': true, 'relay2': true, 'relay3': true},
            errors: {},
          ),
        );

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isTrue);
        expect(result.error, isNull);
      },
    );

    test('deleteAccount should return failure when broadcast fails', () async {
      // Arrange
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(mockNostrService.hasKeys).thenReturn(true);

      when(mockNostrService.broadcastEvent(any)).thenAnswer(
        (_) async => NostrBroadcastResult(
          event: Event(
            testPublicKey,
            62,
            [
              ['relay', 'ALL_RELAYS'],
            ],
            'test content',
            createdAt: 1234567890,
          ),
          successCount: 0,
          totalRelays: 3,
          results: {'relay1': false, 'relay2': false, 'relay3': false},
          errors: {'relay1': 'error1', 'relay2': 'error2', 'relay3': 'error3'},
        ),
      );

      // Act
      final result = await service.deleteAccount();

      // Assert
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      expect(result.error, contains('Failed to broadcast'));
    });
  });
}
