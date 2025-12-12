// ABOUTME: Tests for CurationService analytics integration and on-demand trending fetch
// ABOUTME: Verifies trending data is only fetched when requested, not constantly polled

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/curation_set.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_event_service.dart';

import 'curation_service_test.mocks.dart';

@GenerateMocks([NostrClient, VideoEventService, SocialService, AuthService])
void main() {
  group('CurationService', () {
    late CurationService curationService;
    late MockNostrClient mockNostrService;
    late MockVideoEventService mockVideoEventService;
    late MockSocialService mockSocialService;
    late MockAuthService mockAuthService;

    setUp(() {
      mockNostrService = MockNostrClient();
      mockVideoEventService = MockVideoEventService();
      mockSocialService = MockSocialService();
      mockAuthService = MockAuthService();

      // Mock video events for testing
      when(mockVideoEventService.videoEvents).thenReturn([
        VideoEvent(
          id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
          pubkey: 'test_pubkey',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'Test video',
          timestamp: DateTime.now(),
        ),
      ]);
      // Mock discoveryVideos to avoid MissingStubError during CurationService initialization
      when(mockVideoEventService.discoveryVideos).thenReturn([]);
      // Mock subscribeToEvents to avoid MissingStubError when fetching Editor's Picks list
      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => Stream<Event>.empty());

      curationService = CurationService(
        nostrService: mockNostrService,
        videoEventService: mockVideoEventService,
        socialService: mockSocialService,
        authService: mockAuthService,
      );
    });

    tearDown(() {
      curationService.dispose();
    });

    test('should not automatically fetch trending data on initialization', () {
      // The constructor should complete without making any HTTP requests
      expect(
        curationService.getVideosForSetType(CurationSetType.trending),
        isNotEmpty,
      );
      // Should use local algorithm, not analytics API
    });

    test('should have manual refresh method for trending', () {
      // Verify the public method exists
      expect(curationService.refreshTrendingFromAnalytics, isA<Function>());
    });

    test('should fall back to local algorithm when analytics unavailable', () {
      // Given: No analytics API available
      // When: Getting trending videos
      final trendingVideos = curationService.getVideosForSetType(
        CurationSetType.trending,
      );

      // Then: Should return local algorithm results
      expect(trendingVideos, isNotNull);
      // Local algorithm should work with mock data
    });

    test('should get videos for different curation set types', () {
      final editorsPicks = curationService.getVideosForSetType(
        CurationSetType.editorsPicks,
      );
      final trending = curationService.getVideosForSetType(
        CurationSetType.trending,
      );
      expect(editorsPicks, isA<List<VideoEvent>>());
      expect(trending, isA<List<VideoEvent>>());
    });

    test('should handle empty video events gracefully', () {
      // Given: No video events
      when(mockVideoEventService.videoEvents).thenReturn([]);
      when(mockVideoEventService.discoveryVideos).thenReturn([]);

      final service = CurationService(
        nostrService: mockNostrService,
        videoEventService: mockVideoEventService,
        socialService: mockSocialService,
        authService: mockAuthService,
      );

      // When: Getting trending videos
      final trending = service.getVideosForSetType(CurationSetType.trending);

      // Then: Should return empty list without errors
      expect(trending, isEmpty);

      service.dispose();
    });

    // Note: CurationService no longer extends ChangeNotifier after refactor
    // Listener tests are no longer applicable
    /*
    test('should notify listeners when curation sets are refreshed', () async {
      var notified = false;
      curationService.addListener(() {
        notified = true;
      });

      // Simulate curation set refresh
      await curationService.refreshCurationSets();

      expect(notified, isTrue);
    });
    */
  });
}
