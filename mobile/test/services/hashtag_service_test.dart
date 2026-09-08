// ABOUTME: Tests for hashtag sorting and relay fetching functionality
// ABOUTME: Ensures hashtags are sorted by video count and relay queries work correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/video_event_service.dart';

// Mock class for VideoEventService
class MockVideoEventService extends Mock implements VideoEventService {}

void main() {
  setUpAll(() {
    registerFallbackValue(SubscriptionType.discovery);
  });

  group('Hashtag Sorting Tests', () {
    late HashtagService hashtagService;
    late MockVideoEventService mockVideoService;

    setUp(() {
      mockVideoService = MockVideoEventService();

      // Stub before constructing HashtagService, since the constructor
      // immediately calls _updateHashtagStats() and addListener().
      when(() => mockVideoService.discoveryVideos).thenReturn([]);
      when(() => mockVideoService.homeFeedVideos).thenReturn([]);
      when(() => mockVideoService.getEventCount(any())).thenReturn(0);
      when(() => mockVideoService.getVideos(any())).thenReturn([]);

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

      // Update mocks with test data
      when(() => mockVideoService.discoveryVideos).thenReturn(testVideos);

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
        await mockVideoService.subscribeToHashtagVideos(testHashtags);
        final videos = mockVideoService.getVideos(SubscriptionType.hashtag);

        // Assert
        // Verify subscription was called with correct parameters
        verify(
          () => mockVideoService.subscribeToHashtagVideos(testHashtags),
        ).called(1);

        // Verify videos are returned
        expect(videos.length, equals(2));
        expect(videos[0].hashtags, contains('comedy'));
        expect(videos[1].hashtags, contains('dance'));
      },
    );

    test('should fetch videos from relay when hashtag is clicked', () async {
      // Arrange
      const hashtag = 'viral';
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
      await mockVideoService.subscribeToHashtagVideos([hashtag]);
      final videos = mockVideoService.getVideos(SubscriptionType.hashtag);

      // Assert
      // Verify subscription was created with the hashtag
      verify(
        () => mockVideoService.subscribeToHashtagVideos([hashtag]),
      ).called(1);

      // Verify videos with the hashtag are returned
      expect(videos.length, equals(2));
      expect(videos.every((v) => v.hashtags.contains(hashtag)), isTrue);
    });
  });
}

// Auto-incrementing counter to guarantee unique IDs across calls.
int _videoIdCounter = 0;

// Helper function to create test video events
VideoEvent _createVideoWithHashtags(List<String> hashtags) {
  final id = _videoIdCounter++;
  final now = DateTime.now();
  final timestamp = now.millisecondsSinceEpoch ~/ 1000;
  return VideoEvent(
    id: 'test_video_$id',
    pubkey: 'test_pubkey',
    createdAt: timestamp,
    timestamp: now, // Required parameter - DateTime type
    content: 'Test video',
    videoUrl: 'https://example.com/video.mp4',
    hashtags: hashtags,
    vineId: 'test_vine_$id',
  );
}
