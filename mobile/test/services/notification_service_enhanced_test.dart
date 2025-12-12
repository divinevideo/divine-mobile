// ABOUTME: Tests for NotificationServiceEnhanced social notification handling
// ABOUTME: Verifies race condition fixes and concurrent notification deduplication

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/services/notification_service_enhanced.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_event_service.dart';

@GenerateMocks([NostrClient, UserProfileService, VideoEventService])
import 'notification_service_enhanced_test.mocks.dart';

void main() {
  group('NotificationServiceEnhanced Race Condition Tests', () {
    late NotificationServiceEnhanced service;
    late MockNostrClient mockNostrService;
    late MockUserProfileService mockProfileService;
    late MockVideoEventService mockVideoService;

    setUp(() {
      service = NotificationServiceEnhanced();
      mockNostrService = MockNostrClient();
      mockProfileService = MockUserProfileService();
      mockVideoService = MockVideoEventService();

      // Setup mock responses
      when(mockNostrService.hasKeys).thenReturn(true);
      when(mockNostrService.publicKey).thenReturn('test-pubkey-123');
      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => Stream.empty());
    });

    tearDown(() {
      service.dispose();
    });

    test(
      'concurrent addNotificationForTesting calls with same ID should only add once',
      () async {
        // Initialize the service
        await service.initialize(
          nostrService: mockNostrService,
          profileService: mockProfileService,
          videoService: mockVideoService,
        );

        // Create identical notifications (same ID)
        final notification1 = NotificationModel(
          id: 'duplicate-test-id',
          type: NotificationType.like,
          actorPubkey: 'actor-pubkey',
          actorName: 'Test User',
          message: 'Test User liked your video',
          timestamp: DateTime.now(),
        );

        final notification2 = NotificationModel(
          id: 'duplicate-test-id', // Same ID - should be deduplicated
          type: NotificationType.like,
          actorPubkey: 'actor-pubkey',
          actorName: 'Test User',
          message: 'Test User liked your video',
          timestamp: DateTime.now(),
        );

        // Simulate race condition: add both concurrently
        // This tests that the fix (mutex lock) prevents duplicates
        await Future.wait([
          service.addNotificationForTesting(notification1),
          service.addNotificationForTesting(notification2),
        ]);

        // Should only have ONE notification, not two
        expect(
          service.notifications.length,
          equals(1),
          reason: 'Race condition: duplicate notification was added',
        );
        expect(service.notifications.first.id, equals('duplicate-test-id'));
      },
    );

    test(
      'concurrent addNotificationForTesting calls with different IDs should add both',
      () async {
        await service.initialize(
          nostrService: mockNostrService,
          profileService: mockProfileService,
          videoService: mockVideoService,
        );

        final notification1 = NotificationModel(
          id: 'notification-1',
          type: NotificationType.like,
          actorPubkey: 'actor-1',
          actorName: 'User 1',
          message: 'User 1 liked your video',
          timestamp: DateTime.now(),
        );

        final notification2 = NotificationModel(
          id: 'notification-2',
          type: NotificationType.comment,
          actorPubkey: 'actor-2',
          actorName: 'User 2',
          message: 'User 2 commented on your video',
          timestamp: DateTime.now(),
        );

        // Add both concurrently
        await Future.wait([
          service.addNotificationForTesting(notification1),
          service.addNotificationForTesting(notification2),
        ]);

        // Should have BOTH notifications
        expect(service.notifications.length, equals(2));
        expect(
          service.notifications.map((n) => n.id).toSet(),
          equals({'notification-1', 'notification-2'}),
        );
      },
    );

    test('rapid sequential adds with same ID should only add once', () async {
      await service.initialize(
        nostrService: mockNostrService,
        profileService: mockProfileService,
        videoService: mockVideoService,
      );

      final notification = NotificationModel(
        id: 'rapid-test-id',
        type: NotificationType.like,
        actorPubkey: 'actor-pubkey',
        actorName: 'Test User',
        message: 'Test User liked your video',
        timestamp: DateTime.now(),
      );

      // Add same notification 10 times rapidly
      await Future.wait(
        List.generate(
          10,
          (_) => service.addNotificationForTesting(notification),
        ),
      );

      // Should only have ONE notification
      expect(service.notifications.length, equals(1));
    });

    test('stress test: 100 concurrent adds with mixed IDs', () async {
      await service.initialize(
        nostrService: mockNostrService,
        profileService: mockProfileService,
        videoService: mockVideoService,
      );

      // Create 10 unique notification IDs, but add each one 10 times
      final futures = <Future<void>>[];
      for (var i = 0; i < 10; i++) {
        for (var j = 0; j < 10; j++) {
          final notification = NotificationModel(
            id: 'notification-$i', // Same ID for all j iterations
            type: NotificationType.like,
            actorPubkey: 'actor-$i',
            actorName: 'User $i',
            message: 'User $i liked your video',
            timestamp: DateTime.now(),
          );
          futures.add(service.addNotificationForTesting(notification));
        }
      }

      await Future.wait(futures);

      // Should only have 10 unique notifications (not 100)
      expect(
        service.notifications.length,
        equals(10),
        reason: 'Stress test: duplicates were not properly filtered',
      );

      // Verify all 10 unique IDs are present
      final ids = service.notifications.map((n) => n.id).toSet();
      expect(ids.length, equals(10));
      for (var i = 0; i < 10; i++) {
        expect(ids.contains('notification-$i'), isTrue);
      }
    });
  });
}
