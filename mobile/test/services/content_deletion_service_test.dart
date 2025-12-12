// ABOUTME: Tests for NIP-09 content deletion service
// ABOUTME: Verifies kind 5 event creation with k tag and deletion history

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_deletion_service_test.mocks.dart';

@GenerateMocks([NostrClient, NostrKeyManager])
void main() {
  group('ContentDeletionService', () {
    late MockNostrClient mockNostrService;
    late MockNostrKeyManager mockKeyManager;
    late ContentDeletionService service;
    late SharedPreferences prefs;
    late String testPrivateKey;
    late String testPublicKey;
    late Keychain testKeychain;

    setUp(() async {
      // Generate valid keys for testing
      testPrivateKey = generatePrivateKey();
      testPublicKey = getPublicKey(testPrivateKey);
      testKeychain = Keychain(testPrivateKey);

      // Setup SharedPreferences mock
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      mockNostrService = MockNostrClient();
      mockKeyManager = MockNostrKeyManager();

      // Setup common mocks with valid keys
      when(mockKeyManager.keyPair).thenReturn(testKeychain);
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.hasKeys).thenReturn(true);
      when(mockNostrService.publicKey).thenReturn(testPublicKey);

      service = ContentDeletionService(
        nostrService: mockNostrService,
        keyManager: mockKeyManager,
        prefs: prefs,
      );

      await service.initialize();
    });

    VideoEvent createTestVideoEvent(String pubkey) {
      final event = Event(
        pubkey,
        34236, // Video event kind
        [
          ['title', 'Test Video'],
          ['url', 'https://example.com/video.mp4'],
        ],
        'Test video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event.id = 'test_event_id_${DateTime.now().millisecondsSinceEpoch}';
      event.sig = 'test_signature';
      return VideoEvent.fromNostrEvent(event);
    }

    test('deleteContent should create NIP-09 kind 5 delete event', () async {
      // Arrange
      final video = createTestVideoEvent(testPublicKey);

      when(mockNostrService.broadcast(any)).thenAnswer(
        (_) async => NostrBroadcastResult(
          event: Event(
            testPublicKey,
            5, // Delete event kind
            [
              ['e', video.id],
              ['k', '34236'],
            ],
            'CONTENT DELETION',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
          successCount: 3,
          totalRelays: 3,
          results: {'relay1': true, 'relay2': true, 'relay3': true},
          errors: {},
        ),
      );

      // Act
      final result = await service.deleteContent(
        video: video,
        reason: 'Personal choice',
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.deleteEventId, isNotNull);

      // Verify broadcast was called with kind 5 event
      final capturedEvent =
          verify(mockNostrService.broadcast(captureAny)).captured.single
              as Event;
      expect(capturedEvent.kind, equals(5));
    });

    test(
      'deleteContent should include k tag with video kind per NIP-09',
      () async {
        // Arrange
        final video = createTestVideoEvent(testPublicKey);

        when(mockNostrService.broadcast(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: Event(
              testPublicKey,
              5,
              [
                ['e', video.id],
                ['k', '34236'],
              ],
              'CONTENT DELETION',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
            successCount: 1,
            totalRelays: 1,
            results: {'relay1': true},
            errors: {},
          ),
        );

        // Act
        await service.deleteContent(video: video, reason: 'Personal choice');

        // Assert - verify the delete event has the 'k' tag
        final capturedEvent =
            verify(mockNostrService.broadcast(captureAny)).captured.single
                as Event;

        // Find the 'k' tag
        final kTag = capturedEvent.tags.firstWhere(
          (tag) => tag.isNotEmpty && tag[0] == 'k',
          orElse: () => <String>[],
        );

        expect(kTag, isNotEmpty, reason: 'Delete event should have k tag');
        expect(
          kTag[1],
          equals('34236'),
          reason: 'k tag should contain video event kind',
        );
      },
    );

    test('deleteContent should save deletion to history', () async {
      // Arrange
      final video = createTestVideoEvent(testPublicKey);

      when(mockNostrService.broadcast(any)).thenAnswer(
        (_) async => NostrBroadcastResult(
          event: Event(
            testPublicKey,
            5,
            [
              ['e', video.id],
              ['k', '34236'],
            ],
            'CONTENT DELETION',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        ),
      );

      // Act
      await service.deleteContent(video: video, reason: 'Privacy concerns');

      // Assert
      expect(service.hasBeenDeleted(video.id), isTrue);
      expect(service.deletionHistory.length, equals(1));
      expect(service.deletionHistory.first.originalEventId, equals(video.id));
      expect(service.deletionHistory.first.reason, equals('Privacy concerns'));
    });

    test(
      'deleteContent should fail when trying to delete other user content',
      () async {
        // Arrange - create video from different user
        final otherUserPubkey = getPublicKey(generatePrivateKey());
        final video = createTestVideoEvent(otherUserPubkey);

        // Act
        final result = await service.deleteContent(
          video: video,
          reason: 'Personal choice',
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Can only delete your own content'));

        // Verify broadcast was NOT called
        verifyNever(mockNostrService.broadcast(any));
      },
    );

    test(
      'deleteContent should still save locally even if broadcast fails',
      () async {
        // Arrange
        final video = createTestVideoEvent(testPublicKey);

        when(mockNostrService.broadcast(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: Event(
              testPublicKey,
              5,
              [
                ['e', video.id],
                ['k', '34236'],
              ],
              'CONTENT DELETION',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
            successCount: 0, // Broadcast failed
            totalRelays: 3,
            results: {'relay1': false, 'relay2': false, 'relay3': false},
            errors: {'relay1': 'error', 'relay2': 'error', 'relay3': 'error'},
          ),
        );

        // Act
        final result = await service.deleteContent(
          video: video,
          reason: 'Personal choice',
        );

        // Assert - should still succeed locally (deletion saved to history)
        expect(result.success, isTrue);
        expect(service.hasBeenDeleted(video.id), isTrue);
      },
    );

    test('quickDelete should use predefined reason text', () async {
      // Arrange
      final video = createTestVideoEvent(testPublicKey);

      when(mockNostrService.broadcast(any)).thenAnswer(
        (_) async => NostrBroadcastResult(
          event: Event(
            testPublicKey,
            5,
            [
              ['e', video.id],
              ['k', '34236'],
            ],
            'CONTENT DELETION',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        ),
      );

      // Act
      final result = await service.quickDelete(
        video: video,
        reason: DeleteReason.privacy,
      );

      // Assert
      expect(result.success, isTrue);
      final deletion = service.getDeletionForEvent(video.id);
      expect(deletion, isNotNull);
      expect(deletion!.reason, contains('Privacy concerns'));
    });

    test('hasBeenDeleted should return false for non-deleted content', () {
      // Assert
      expect(service.hasBeenDeleted('non_existent_event_id'), isFalse);
    });

    test('getDeletionForEvent should return null for non-deleted content', () {
      // Assert
      expect(service.getDeletionForEvent('non_existent_event_id'), isNull);
    });

    test('deleteContent should fail when service not initialized', () async {
      // Arrange - create new service without initializing
      final uninitializedService = ContentDeletionService(
        nostrService: mockNostrService,
        keyManager: mockKeyManager,
        prefs: prefs,
      );

      final video = createTestVideoEvent(testPublicKey);

      // Act
      final result = await uninitializedService.deleteContent(
        video: video,
        reason: 'Test reason',
      );

      // Assert
      expect(result.success, isFalse);
      expect(result.error, contains('not initialized'));
    });
  });
}
