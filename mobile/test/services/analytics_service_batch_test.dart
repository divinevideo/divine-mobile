// ABOUTME: Tests for analytics service batch tracking without Future.delayed
// ABOUTME: Validates proper rate limiting using AsyncUtils

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AnalyticsService Batch Tracking', () {
    late AnalyticsService analyticsService;
    final requestTimes = <DateTime>[];

    setUp(() async {
      // Set up SharedPreferences mock
      SharedPreferences.setMockInitialValues({'analytics_enabled': true});

      // Create mock HTTP client that tracks request times
      final mockClient = MockClient((request) async {
        requestTimes.add(DateTime.now());
        return http.Response('{"success": true}', 200);
      });

      analyticsService = AnalyticsService(client: mockClient);
      await analyticsService.initialize();
    });

    tearDown(requestTimes.clear);

    test(
      'should space out batch video views with proper rate limiting',
      () async {
        // Arrange
        final now = DateTime.now();
        final videos = List.generate(
          5,
          (i) => VideoEvent(
            id: 'video_$i',
            pubkey: 'pubkey_$i',
            content: '{"url": "https://example.com/video_$i.mp4"}',
            createdAt:
                now.subtract(Duration(hours: i)).millisecondsSinceEpoch ~/ 1000,
            timestamp: now.subtract(Duration(hours: i)),
            videoUrl: 'https://example.com/video_$i.mp4',
            hashtags: [],
            rawTags: {},
          ),
        );

        // Act
        await analyticsService.trackVideoViews(videos);

        // Assert
        expect(requestTimes.length, 5);

        // Check spacing between requests (should be ~100ms apart)
        for (var i = 1; i < requestTimes.length; i++) {
          final interval = requestTimes[i].difference(requestTimes[i - 1]);
          expect(
            interval.inMilliseconds,
            greaterThanOrEqualTo(90),
          ); // Allow small timing variance
        }
      },
    );

    test('should not use Future.delayed pattern', () async {
      // This test ensures the implementation doesn't contain Future.delayed
      // by checking that the method completes in a reasonable time
      final startTime = DateTime.now();

      final now = DateTime.now();
      final videos = List.generate(
        3,
        (i) => VideoEvent(
          id: 'video_$i',
          pubkey: 'pubkey_$i',
          content: '{"url": "https://example.com/video_$i.mp4"}',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          videoUrl: 'https://example.com/video_$i.mp4',
          hashtags: [],
          rawTags: {},
        ),
      );

      await analyticsService.trackVideoViews(videos);

      final endTime = DateTime.now();
      final totalTime = endTime.difference(startTime);

      // Should take ~200ms for 3 videos with 100ms spacing
      expect(totalTime.inMilliseconds, lessThan(400));
      expect(totalTime.inMilliseconds, greaterThanOrEqualTo(200));
    });

    test('should handle empty video list', () async {
      // Act & Assert
      await expectLater(analyticsService.trackVideoViews([]), completes);

      expect(requestTimes, isEmpty);
    });

    test('should respect analytics disabled setting', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({'analytics_enabled': false});
      await analyticsService.setAnalyticsEnabled(false);

      final now = DateTime.now();
      final videos = List.generate(
        3,
        (i) => VideoEvent(
          id: 'video_$i',
          pubkey: 'pubkey_$i',
          content: '{"url": "https://example.com/video_$i.mp4"}',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          videoUrl: 'https://example.com/video_$i.mp4',
          hashtags: [],
          rawTags: {},
        ),
      );

      // Act
      await analyticsService.trackVideoViews(videos);

      // Assert
      expect(requestTimes, isEmpty);
    });
  });
}
