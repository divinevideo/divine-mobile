// ABOUTME: Tests for analytics service view tracking without duplicate prevention
// ABOUTME: Verifies that users can rewatch videos and all views are counted

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AnalyticsService', () {
    late AnalyticsService analyticsService;
    late MockClient mockClient;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockClient = MockClient((request) async {
        if (request.url.path == '/analytics/view') {
          return http.Response('{"success": true, "views": 1}', 200);
        }
        return http.Response('Not Found', 404);
      });
      analyticsService = AnalyticsService(client: mockClient);
    });

    tearDown(() {
      analyticsService.dispose();
    });

    test('should initialize with analytics enabled by default', () async {
      await analyticsService.initialize();
      expect(analyticsService.analyticsEnabled, isTrue);
    });

    test('should track multiple views of the same video', () async {
      // Arrange
      await analyticsService.initialize();
      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      var requestCount = 0;
      mockClient = MockClient((request) async {
        if (request.url.path == '/analytics/view') {
          requestCount++;
          return http.Response(
            '{"success": true, "views": $requestCount}',
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      analyticsService = AnalyticsService(client: mockClient);
      await analyticsService.initialize();

      // Act - Track the same video 3 times
      await analyticsService.trackVideoView(video);
      await analyticsService.trackVideoView(video);
      await analyticsService.trackVideoView(video);

      // Wait for async fire-and-forget requests to complete
      await Future.delayed(Duration(milliseconds: 100));

      // Assert - All 3 views should be tracked
      expect(requestCount, equals(3));
    });

    test('should not track views when analytics is disabled', () async {
      // Arrange
      await analyticsService.initialize();
      await analyticsService.setAnalyticsEnabled(false);

      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      var requestCount = 0;
      mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('{"success": true, "views": 1}', 200);
      });
      analyticsService = AnalyticsService(client: mockClient);
      await analyticsService.initialize();
      await analyticsService.setAnalyticsEnabled(false);

      // Act
      await analyticsService.trackVideoView(video);

      // Assert
      expect(requestCount, equals(0));
    });

    test('should handle rate limiting gracefully', () async {
      // Arrange
      await analyticsService.initialize();
      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      mockClient = MockClient(
        (request) async =>
            http.Response('{"error": "Rate limit exceeded"}', 429),
      );
      analyticsService = AnalyticsService(client: mockClient);
      await analyticsService.initialize();

      // Act & Assert - Should not throw
      await expectLater(analyticsService.trackVideoView(video), completes);
    });

    test('should allow rapid successive views of the same video', () async {
      // Arrange
      await analyticsService.initialize();
      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      var requestCount = 0;
      mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('{"success": true, "views": $requestCount}', 200);
      });
      analyticsService = AnalyticsService(client: mockClient);
      await analyticsService.initialize();

      // Act - Track rapidly without delays
      final futures = List.generate(
        5,
        (_) => analyticsService.trackVideoView(video),
      );
      await Future.wait(futures);

      // Wait for async fire-and-forget requests to complete
      await Future.delayed(Duration(milliseconds: 200));

      // Assert - All views should be tracked
      expect(requestCount, equals(5));
    });

    test('should persist analytics preference', () async {
      // Arrange
      await analyticsService.initialize();

      // Act
      await analyticsService.setAnalyticsEnabled(false);

      // Create new instance to simulate app restart
      final prefs = await SharedPreferences.getInstance();
      final savedValue = prefs.getBool('analytics_enabled');

      // Assert
      expect(savedValue, isFalse);
    });
  });
}
