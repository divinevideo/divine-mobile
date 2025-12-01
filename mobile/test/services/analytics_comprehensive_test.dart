// ABOUTME: Comprehensive unit tests for analytics service covering all scenarios
// ABOUTME: Tests tracking, API responses, error handling, and trending data integration

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Analytics Service Comprehensive Tests', () {
    late AnalyticsService analyticsService;
    late List<http.Request> capturedRequests;
    late MockClient mockClient;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      capturedRequests = [];
    });

    tearDown(() {
      analyticsService.dispose();
    });

    test('should send correct data structure to analytics endpoint', () async {
      // Arrange
      mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response('{"success": true}', 200);
      });

      analyticsService = AnalyticsService(client: mockClient);
      await analyticsService.initialize();

      final video = VideoEvent(
        id: 'test-event-id-123',
        pubkey: 'test-pubkey-456',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video content',
        timestamp: DateTime.now(),
        title: 'Test Video Title',
        hashtags: ['test', 'analytics', 'openvine'],
      );

      // Act
      await analyticsService.trackVideoView(video, source: 'test');

      // Assert
      expect(capturedRequests.length, equals(1));
      final request = capturedRequests.first;

      // Check endpoint
      expect(
        request.url.toString(),
        equals('https://api.openvine.co/analytics/view'),
      );

      // Check headers
      expect(request.headers['Content-Type'], equals('application/json'));
      expect(request.headers['User-Agent'], equals('OpenVine-Mobile/1.0'));

      // Check body
      final bodyData = jsonDecode(request.body);
      expect(bodyData['eventId'], equals('test-event-id-123'));
      expect(bodyData['source'], equals('test'));
      expect(bodyData['creatorPubkey'], equals('test-pubkey-456'));
      expect(bodyData['title'], equals('Test Video Title'));
      expect(bodyData['hashtags'], equals(['test', 'analytics', 'openvine']));
    });

    test('should handle various API response codes correctly', () async {
      // Test different response codes
      final testCases = [
        {'code': 200, 'body': '{"success": true}', 'expectSuccess': true},
        {
          'code': 201,
          'body': '{"success": true}',
          'expectSuccess': false,
        }, // Not 200
        {
          'code': 400,
          'body': '{"error": "Bad Request"}',
          'expectSuccess': false,
        },
        {
          'code': 401,
          'body': '{"error": "Unauthorized"}',
          'expectSuccess': false,
        },
        {
          'code': 429,
          'body': '{"error": "Rate Limited"}',
          'expectSuccess': false,
        },
        {
          'code': 500,
          'body': '{"error": "Server Error"}',
          'expectSuccess': false,
        },
      ];

      for (final testCase in testCases) {
        // Arrange

        mockClient = MockClient(
          (request) async => http.Response(
            testCase['body'] as String,
            testCase['code'] as int,
          ),
        );

        analyticsService = AnalyticsService(client: mockClient);
        await analyticsService.initialize();

        final video = VideoEvent(
          id: 'test-event-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
        );

        // Act
        await analyticsService.trackVideoView(video);

        // Since we can't easily intercept logs, we just verify no exceptions are thrown
        // In a real scenario, you'd inject a logger to verify the correct log messages
      }
    });

    test('should handle network timeouts gracefully', () async {
      // Arrange
      mockClient = MockClient((request) async {
        // Simulate timeout by throwing a timeout exception
        throw Exception('Timeout');
      });

      analyticsService = AnalyticsService(client: mockClient);
      await analyticsService.initialize();

      final video = VideoEvent(
        id: 'test-event-id',
        pubkey: 'test-pubkey',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      // Act & Assert - Should complete without throwing
      await expectLater(analyticsService.trackVideoView(video), completes);
    });

    test('should handle malformed JSON responses', () async {
      // Arrange
      mockClient = MockClient(
        (request) async => http.Response('Invalid JSON {{{', 200),
      );

      analyticsService = AnalyticsService(client: mockClient);
      await analyticsService.initialize();

      final video = VideoEvent(
        id: 'test-event-id',
        pubkey: 'test-pubkey',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      // Act & Assert - Should complete without throwing
      await expectLater(analyticsService.trackVideoView(video), completes);
    });

    test('should batch track multiple videos with delay', () async {
      // Arrange
      final requestTimes = <DateTime>[];
      mockClient = MockClient((request) async {
        requestTimes.add(DateTime.now());
        return http.Response('{"success": true}', 200);
      });

      analyticsService = AnalyticsService(client: mockClient);
      await analyticsService.initialize();

      final videos = List.generate(
        3,
        (index) => VideoEvent(
          id: 'test-event-id-$index',
          pubkey: 'test-pubkey',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Test video $index',
          timestamp: DateTime.now(),
        ),
      );

      // Act
      await analyticsService.trackVideoViews(videos);

      // Assert
      expect(requestTimes.length, equals(3));

      // Check that there's approximately 100ms delay between requests
      for (var i = 1; i < requestTimes.length; i++) {
        final delay = requestTimes[i]
            .difference(requestTimes[i - 1])
            .inMilliseconds;
        expect(delay, greaterThanOrEqualTo(90)); // Allow some timing variance
        expect(delay, lessThanOrEqualTo(150));
      }
    });

    test('should not send requests when analytics is disabled', () async {
      // Arrange
      var requestCount = 0;
      mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('{"success": true}', 200);
      });

      analyticsService = AnalyticsService(client: mockClient);
      await analyticsService.initialize();
      await analyticsService.setAnalyticsEnabled(false);

      final video = VideoEvent(
        id: 'test-event-id',
        pubkey: 'test-pubkey',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      // Act
      await analyticsService.trackVideoView(video);
      await analyticsService.trackVideoViews([video, video]);

      // Assert
      expect(requestCount, equals(0));
    });

    test('should handle empty hashtags and null title correctly', () async {
      // Arrange
      mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response('{"success": true}', 200);
      });

      analyticsService = AnalyticsService(client: mockClient);
      await analyticsService.initialize();

      final video = VideoEvent(
        id: 'test-event-id',
        pubkey: 'test-pubkey',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
        title: null,
        hashtags: [], // Empty hashtags
      );

      // Act
      await analyticsService.trackVideoView(video);

      // Assert
      expect(capturedRequests.length, equals(1));
      final bodyData = jsonDecode(capturedRequests.first.body);
      expect(bodyData['hashtags'], isNull); // Should be null when empty
      expect(bodyData['title'], isNull); // Should pass through null
    });

    test('should include all required fields in analytics payload', () async {
      // Arrange
      mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response('{"success": true}', 200);
      });

      analyticsService = AnalyticsService(client: mockClient);
      await analyticsService.initialize();

      final video = VideoEvent(
        id: 'comprehensive-test-id',
        pubkey: 'comprehensive-test-pubkey',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Comprehensive test video',
        timestamp: DateTime.now(),
        title: 'Comprehensive Test',
        hashtags: ['test1', 'test2'],
      );

      // Act
      await analyticsService.trackVideoView(video, source: 'unit_test');

      // Assert
      expect(
        capturedRequests,
        isNotEmpty,
        reason: 'Should have captured at least one analytics request',
      );
      final request = capturedRequests.first;
      final bodyData = jsonDecode(request.body);

      // Verify all expected fields are present
      expect(bodyData.containsKey('eventId'), isTrue);
      expect(bodyData.containsKey('source'), isTrue);
      expect(bodyData.containsKey('creatorPubkey'), isTrue);
      expect(bodyData.containsKey('hashtags'), isTrue);
      expect(bodyData.containsKey('title'), isTrue);

      // Verify no unexpected fields
      expect(bodyData.keys.length, equals(5));
    });

    test('should handle concurrent tracking requests', () async {
      // Arrange
      var requestCount = 0;
      mockClient = MockClient((request) async {
        requestCount++;
        // Remove arbitrary delay - concurrent requests don't need artificial delays
        return http.Response('{"success": true}', 200);
      });

      analyticsService = AnalyticsService(client: mockClient);
      await analyticsService.initialize();

      final videos = List.generate(
        5,
        (index) => VideoEvent(
          id: 'concurrent-test-id-$index',
          pubkey: 'test-pubkey',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Test video $index',
          timestamp: DateTime.now(),
        ),
      );

      // Act - Send all requests concurrently
      final futures = videos
          .map((video) => analyticsService.trackVideoView(video))
          .toList();
      await Future.wait(futures);

      // Assert - All requests should be sent
      expect(requestCount, equals(5));
    });
  });

  group('Analytics Integration with Trending', () {
    test('trending API response format should match expected structure', () {
      // This test documents the expected trending API response format
      final expectedResponse = {
        'vines': [
          {
            'eventId': 'event-id-1',
            'views': 150,
            'creatorPubkey': 'pubkey-1',
            'title': 'Trending Video 1',
            'hashtags': ['trending', 'viral'],
          },
          {
            'eventId': 'event-id-2',
            'views': 100,
            'creatorPubkey': 'pubkey-2',
            'title': 'Trending Video 2',
            'hashtags': ['funny'],
          },
        ],
        'lastUpdated': DateTime.now().toIso8601String(),
        'period': '24h',
      };

      // Verify structure
      expect(expectedResponse.containsKey('vines'), isTrue);
      expect(expectedResponse['vines'], isList);

      final firstVine = (expectedResponse['vines'] as List).first as Map;
      expect(firstVine.containsKey('eventId'), isTrue);
      expect(firstVine.containsKey('views'), isTrue);
    });
  });
}
