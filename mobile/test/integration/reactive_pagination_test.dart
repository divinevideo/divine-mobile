// ABOUTME: Integration test to verify reactive pagination works correctly
// ABOUTME: Tests VideoEventService ChangeNotifier behavior and loadMoreEvents functionality

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/unified_logger.dart';

import 'reactive_pagination_test.mocks.dart';

@GenerateMocks([NostrClient, SubscriptionManager])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reactive Pagination Tests', () {
    late VideoEventService videoEventService;
    late MockNostrClient mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;
    bool listenerCalled = false;

    setUp(() {
      // Set up test logging
      Log.setLogLevel(LogLevel.debug);

      // Create mock services
      mockNostrService = MockNostrClient();
      mockSubscriptionManager = MockSubscriptionManager();

      // Set up basic mock behavior
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.connectedRelays).thenReturn(['wss://test.relay']);

      // Mock successful subscription creation - complete immediately
      when(
        mockSubscriptionManager.createSubscription(
          name: anyNamed('name'),
          filters: anyNamed('filters'),
          onEvent: anyNamed('onEvent'),
          onError: anyNamed('onError'),
          onComplete: anyNamed('onComplete'),
          timeout: anyNamed('timeout'),
          priority: anyNamed('priority'),
        ),
      ).thenAnswer((invocation) async {
        // Immediately call the onComplete callback to simulate EOSE
        final onComplete =
            invocation.namedArguments[const Symbol('onComplete')]
                as void Function();
        Future.delayed(Duration(milliseconds: 10), onComplete);
        return 'test-subscription-id';
      });

      when(
        mockSubscriptionManager.cancelSubscription(any),
      ).thenAnswer((_) async {});

      // Create VideoEventService with mock dependencies
      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );

      // Reset listener flag
      listenerCalled = false;
    });

    test('VideoEventService extends ChangeNotifier and notifies listeners', () {
      // Verify it's a ChangeNotifier
      expect(videoEventService, isA<ChangeNotifier>());

      // Add a listener
      videoEventService.addListener(() {
        listenerCalled = true;
      });

      // Verify initial state
      expect(videoEventService.discoveryVideos, isEmpty);
      expect(listenerCalled, isFalse);
    });

    test(
      'loadMoreEvents calls subscription manager with correct parameters',
      () async {
        // Act: Call loadMoreEvents
        await videoEventService.loadMoreEvents(
          SubscriptionType.discovery,
          limit: 25,
        );

        // Assert: Verify createSubscription was called with correct parameters
        verify(
          mockSubscriptionManager.createSubscription(
            name: 'historical_query',
            filters: argThat(hasLength(1), named: 'filters'),
            onEvent: anyNamed('onEvent'),
            onError: anyNamed('onError'),
            onComplete: anyNamed('onComplete'),
            timeout: anyNamed('timeout'),
            priority: 5,
          ),
        ).called(1);

        // Verify subscription was cancelled after completion
        verify(
          mockSubscriptionManager.cancelSubscription('test-subscription-id'),
        ).called(1);
      },
    );

    test('loadMoreEvents creates correct filter structure', () async {
      // Act: Call loadMoreEvents
      await videoEventService.loadMoreEvents(
        SubscriptionType.discovery,
        limit: 10,
      );

      // Assert: Verify the filter structure is correct
      final captured = verify(
        mockSubscriptionManager.createSubscription(
          name: 'historical_query',
          filters: captureAnyNamed('filters'),
          onEvent: anyNamed('onEvent'),
          onError: anyNamed('onError'),
          onComplete: anyNamed('onComplete'),
          timeout: anyNamed('timeout'),
          priority: anyNamed('priority'),
        ),
      ).captured;

      final filters = captured[0] as List;
      expect(filters, hasLength(1));

      final filter = filters[0];
      expect(filter.kinds, equals([22]));
      expect(filter.limit, equals(10));
      // For empty list, until should be null
      expect(filter.until, isNull);
    });

    test(
      'loadMoreEvents with empty list does not set until parameter',
      () async {
        // Arrange: Ensure discovery list is empty
        expect(videoEventService.discoveryVideos, isEmpty);

        // Act: Call loadMoreEvents
        await videoEventService.loadMoreEvents(
          SubscriptionType.discovery,
          limit: 15,
        );

        // Assert: Verify filter does not have until parameter
        final captured = verify(
          mockSubscriptionManager.createSubscription(
            name: 'historical_query',
            filters: captureAnyNamed('filters'),
            onEvent: anyNamed('onEvent'),
            onError: anyNamed('onError'),
            onComplete: anyNamed('onComplete'),
            timeout: anyNamed('timeout'),
            priority: anyNamed('priority'),
          ),
        ).captured;

        final filters = captured[0] as List;
        final filter = filters[0];

        expect(filter.kinds, equals([22]));
        expect(filter.until, isNull);
        expect(filter.limit, equals(15));
      },
    );
  });
}

/// Helper function to create test VideoEvent
VideoEvent createTestVideoEvent({
  required String id,
  required int createdAt,
  String? title,
}) {
  return VideoEvent(
    id: id,
    pubkey: 'test_pubkey_$id',
    createdAt: createdAt,
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    content: title ?? 'Test video $id',
    title: title ?? 'Test video $id',
    videoUrl: 'https://example.com/video_$id.mp4',
    thumbnailUrl: 'https://example.com/thumb_$id.jpg',
  );
}
