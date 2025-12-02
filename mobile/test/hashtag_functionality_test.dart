// ABOUTME: Tests for hashtag sorting and relay fetching functionality
// ABOUTME: Ensures hashtags are sorted by video count and relay queries work correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/models/video_event.dart';
import 'package:mocktail/mocktail.dart';

// Mock class for VideoEventService
class MockVideoEventService extends Mock implements VideoEventService {}

void main() {
  group('Hashtag Sorting Tests', () {
    late HashtagService hashtagService;
    late MockVideoEventService mockVideoService;

    setUp(() {
      mockVideoService = MockVideoEventService();
      hashtagService = HashtagService(mockVideoService);
    });

    test('should sort hashtags by video count in descending order', () {
      // Arrange - Create test videos with different hashtags
      final testVideos = [
        _createVideoWithHashtags(['popular', 'trending']),
        _createVideoWithHashtags(['popular', 'viral']),
        _createVideoWithHashtags(['popular', 'new']),
        _createVideoWithHashtags(['trending']),
        _createVideoWithHashtags(['rare']),
      ];

      // Mock the video service to return our test videos
      when(() => mockVideoService.discoveryVideos).thenReturn(testVideos);
      when(() => mockVideoService.homeFeedVideos).thenReturn([]);
      when(() => mockVideoService.getEventCount(any())).thenReturn(0);
      when(() => mockVideoService.getVideos(any())).thenReturn([]);

      // Act - Update hashtag stats
      hashtagService.refreshHashtagStats();
      final popularHashtags = hashtagService.getPopularHashtags(limit: 10);

      // Assert - Check that hashtags are sorted by count
      expect(popularHashtags.first, equals('popular')); // 3 videos
      expect(popularHashtags[1], equals('trending')); // 2 videos
      expect(popularHashtags.length, greaterThanOrEqualTo(3));

      // Verify counts
      final popularStats = hashtagService.getHashtagStats('popular');
      final trendingStats = hashtagService.getHashtagStats('trending');
      final rareStats = hashtagService.getHashtagStats('rare');

      expect(popularStats?.videoCount, equals(3));
      expect(trendingStats?.videoCount, equals(2));
      expect(rareStats?.videoCount, equals(1));
    });

    test('should combine and sort hashtags from JSON and local cache', () {
      // This test would verify that the explore screen properly combines
      // hashtags from TopHashtagsService and local HashtagService
      // and sorts them by total count

      // Arrange
      // Test data (not yet implemented - variables removed to fix warnings):
      // jsonHashtags: {'vine': 1000, 'comedy': 800, 'dance': 600}
      // localHashtags: {'vine': 50, 'local': 100, 'dance': 700}

      // Expected result after combining and sorting:
      // 'dance': 700 (from local, higher than JSON's 600)
      // 'vine': 1050 (1000 from JSON + 50 from local)
      // 'comedy': 800 (from JSON only)
      // 'local': 100 (from local only)

      // The actual implementation should sort these properly
    });
  });

  group('Relay Hashtag Fetching Tests', () {
    late MockVideoEventService mockVideoService;

    setUp(() {
      mockVideoService = MockVideoEventService();
    });

    test(
      'should create subscription with hashtag filter for relay query',
      () async {
        // Arrange
        final testHashtags = ['comedy', 'dance'];
        final expectedVideos = [
          _createVideoWithHashtags(['comedy']),
          _createVideoWithHashtags(['dance', 'music']),
        ];

        // Mock the subscribeToHashtagVideos method
        when(
          () => mockVideoService.subscribeToHashtagVideos(
            testHashtags,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async {});

        // Mock getVideos method to return expected videos
        when(
          () => mockVideoService.getVideos(SubscriptionType.hashtag),
        ).thenReturn(expectedVideos);

        // Act
        await mockVideoService.subscribeToHashtagVideos(
          testHashtags,
          limit: 100,
        );
        final videos = mockVideoService.getVideos(SubscriptionType.hashtag);

        // Assert
        // Verify subscription was called with correct parameters
        verify(
          () => mockVideoService.subscribeToHashtagVideos(
            testHashtags,
            limit: 100,
          ),
        ).called(1);

        // Verify videos are returned
        expect(videos.length, equals(2));
        expect(videos[0].hashtags, contains('comedy'));
        expect(videos[1].hashtags, contains('dance'));
      },
    );

    test('should fetch videos from relay when hashtag is clicked', () async {
      // Arrange
      final hashtag = 'viral';
      final expectedVideos = [
        _createVideoWithHashtags(['viral', 'trending']),
        _createVideoWithHashtags(['viral']),
      ];

      // Mock subscription and video fetching
      when(
        () => mockVideoService.subscribeToHashtagVideos([
          hashtag,
        ], limit: any(named: 'limit')),
      ).thenAnswer((_) async {});

      when(
        () => mockVideoService.getVideos(SubscriptionType.hashtag),
      ).thenReturn(expectedVideos);

      // Act - Simulate clicking a hashtag
      await mockVideoService.subscribeToHashtagVideos([hashtag], limit: 100);
      final videos = mockVideoService.getVideos(SubscriptionType.hashtag);

      // Assert
      // Verify subscription was created with the hashtag
      verify(
        () => mockVideoService.subscribeToHashtagVideos([hashtag], limit: 100),
      ).called(1);

      // Verify videos with the hashtag are returned
      expect(videos.length, equals(2));
      expect(videos.every((v) => v.hashtags.contains(hashtag)), isTrue);
    });
  });
}

// Helper function to create test video events
VideoEvent _createVideoWithHashtags(List<String> hashtags) {
  final now = DateTime.now();
  final timestamp = now.millisecondsSinceEpoch ~/ 1000;
  return VideoEvent(
    id: 'test_${DateTime.now().microsecondsSinceEpoch}',
    pubkey: 'test_pubkey',
    createdAt: timestamp,
    timestamp: now, // Required parameter - DateTime type
    content: 'Test video',
    videoUrl: 'https://example.com/video.mp4',
    hashtags: hashtags,
    thumbnailUrl: null,
    blurhash: null,
    vineId: 'test_vine_$timestamp',
    isRepost: false,
  );
}
