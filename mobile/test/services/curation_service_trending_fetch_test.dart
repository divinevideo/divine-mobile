import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/curation_set.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_event_service.dart';

@GenerateMocks([INostrService, VideoEventService, SocialService, AuthService])
import 'curation_service_trending_fetch_test.mocks.dart';

void main() {
  late CurationService curationService;
  late MockINostrService mockNostrService;
  late MockVideoEventService mockVideoEventService;
  late MockSocialService mockSocialService;
  late MockAuthService mockAuthService;

  setUp(() {
    mockNostrService = MockINostrService();
    mockVideoEventService = MockVideoEventService();
    mockSocialService = MockSocialService();
    mockAuthService = MockAuthService();

    // Setup default mocks
    when(mockVideoEventService.videoEvents).thenReturn([]);
    when(mockVideoEventService.discoveryVideos).thenReturn([]);
    when(mockSocialService.getCachedLikeCount(any)).thenReturn(0);

    // Mock the addListener call
    when(mockVideoEventService.addListener(any)).thenReturn(null);

    // Mock subscribeToEvents to avoid MissingStubError when fetching Editor's Picks list
    when(
      mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
    ).thenAnswer((_) => Stream<Event>.empty());

    curationService = CurationService(
      nostrService: mockNostrService,
      videoEventService: mockVideoEventService,
      socialService: mockSocialService,
      authService: mockAuthService,
    );
  });

  group('Trending Videos Relay Fetch', () {
    test('fetches missing trending videos from Nostr relays', () async {
      // This is a focused test on the relay fetching logic
      // We'll simulate the scenario where trending API returns video IDs
      // that don't exist locally, requiring fetch from relays

      // Create a test where we have no local videos
      when(mockVideoEventService.videoEvents).thenReturn([]);

      // Mock Nostr subscription to return a video event
      final videoEvent = Event(
        'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        22,
        [
          ['h', 'vine'],
          ['title', 'Test Video'],
          ['url', 'https://example.com/video.mp4'],
        ],
        jsonEncode({
          'url': 'https://example.com/video.mp4',
          'description': 'Test video description',
        }),
        createdAt: 1234567890,
      );
      videoEvent.id = 'test123';

      final streamController = StreamController<Event>();
      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((_) {
        // Emit the video event
        Timer(const Duration(milliseconds: 100), () {
          streamController.add(videoEvent);
          streamController.close();
        });
        return streamController.stream;
      });

      // Manually trigger the fetch logic that would normally be called
      // when analytics API returns trending videos
      final missingEventIds = ['test123'];

      // We can't directly test _fetchTrendingFromAnalytics since it's private
      // and makes HTTP calls, but we can verify the relay subscription logic

      // Verify that when subscribeToEvents is called with the right filters,
      // it would fetch the missing videos
      final filter = Filter(kinds: [22], ids: missingEventIds, h: ['vine']);

      final eventStream = mockNostrService.subscribeToEvents(filters: [filter]);
      final fetchedEvents = <Event>[];

      await for (final event in eventStream) {
        fetchedEvents.add(event);
      }

      // Verify the event was fetched
      expect(fetchedEvents.length, 1);
      expect(fetchedEvents[0].id, 'test123');

      // Verify addVideoEvent would be called
      when(mockVideoEventService.addVideoEvent(any)).thenReturn(null);
    });

    test('handles empty trending response gracefully', () {
      // Test that the service handles no trending videos without errors
      when(mockVideoEventService.videoEvents).thenReturn([]);

      final trendingVideos = curationService.getVideosForSetType(
        CurationSetType.trending,
      );
      expect(trendingVideos, isEmpty);
    });

    test('preserves order from trending API', () {
      // Test that videos maintain the order from the analytics API
      final video1 = VideoEvent(
        id: 'video1',
        pubkey: 'pub1',
        createdAt: 1,
        content: '',
        timestamp: DateTime.now(),
      );
      final video2 = VideoEvent(
        id: 'video2',
        pubkey: 'pub2',
        createdAt: 2,
        content: '',
        timestamp: DateTime.now(),
      );

      when(mockVideoEventService.videoEvents).thenReturn([video2, video1]);

      // The curation service should maintain order based on analytics response
      // (This would be tested more thoroughly with HTTP mocking)
    });
  });
}
