// ABOUTME: Tests for Riverpod AnalyticsProvider state management and video tracking
// ABOUTME: Verifies reactive analytics state updates and proper initialization

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/state/analytics_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
  });

  group('AnalyticsProvider', () {
    late ProviderContainer container;
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();

      // Setup SharedPreferences mock with initial values
      SharedPreferences.setMockInitialValues({'analytics_enabled': true});

      container = ProviderContainer(
        overrides: [httpClientProvider.overrideWithValue(mockClient)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should start with initial state', () {
      final state = container.read(analyticsProvider);

      expect(state, equals(AnalyticsState.initial));
      expect(state.analyticsEnabled, isTrue);
      expect(state.isInitialized, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.lastEvent, isNull);
      expect(state.error, isNull);
    });

    test('should initialize with analytics enabled by default', () async {
      await container.read(analyticsProvider.notifier).initialize();

      final state = container.read(analyticsProvider);
      expect(state.isInitialized, isTrue);
      expect(state.analyticsEnabled, isTrue);
    });

    test('should initialize with saved analytics preference', () async {
      // Set up SharedPreferences with analytics disabled
      SharedPreferences.setMockInitialValues({'analytics_enabled': false});

      // Create new container with the updated mock values
      final testContainer = ProviderContainer(
        overrides: [httpClientProvider.overrideWithValue(mockClient)],
      );

      await testContainer.read(analyticsProvider.notifier).initialize();

      final state = testContainer.read(analyticsProvider);
      expect(state.isInitialized, isTrue);
      expect(state.analyticsEnabled, isFalse);

      testContainer.dispose();
    });

    test('should toggle analytics enabled state', () async {
      await container
          .read(analyticsProvider.notifier)
          .setAnalyticsEnabled(false);

      final state = container.read(analyticsProvider);
      expect(state.analyticsEnabled, isFalse);
    });

    test('should track video view when analytics enabled', () async {
      // Setup successful HTTP response
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('{"success": true}', 200));

      final video = VideoEvent(
        id: 'test-video-id',
        pubkey: 'test-pubkey',
        title: 'Test Video',
        hashtags: ['test'],
        content: 'test content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      await container.read(analyticsProvider.notifier).trackVideoView(video);

      final state = container.read(analyticsProvider);
      expect(state.lastEvent, equals('test-video-id'));

      verify(
        () => mockClient.post(
          Uri.parse('https://api.openvine.co/analytics/view'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'OpenVine-Mobile/1.0',
          },
          body: any(named: 'body'),
        ),
      ).called(1);
    });

    test('should not track video view when analytics disabled', () async {
      await container
          .read(analyticsProvider.notifier)
          .setAnalyticsEnabled(false);

      final video = VideoEvent(
        id: 'test-video-id',
        pubkey: 'test-pubkey',
        title: 'Test Video',
        hashtags: ['test'],
        content: 'test content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      await container.read(analyticsProvider.notifier).trackVideoView(video);

      verifyNever(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      );
    });

    test('should handle HTTP errors gracefully', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('Error', 500));

      final video = VideoEvent(
        id: 'test-video-id',
        pubkey: 'test-pubkey',
        title: 'Test Video',
        hashtags: ['test'],
        content: 'test content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      // Should not throw
      await container.read(analyticsProvider.notifier).trackVideoView(video);

      final state = container.read(analyticsProvider);
      expect(state.error, isNull); // Errors are logged but don't update state
    });

    test('should track multiple video views', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('{"success": true}', 200));

      final videos = [
        VideoEvent(
          id: 'video-1',
          pubkey: 'pubkey-1',
          title: 'Video 1',
          hashtags: ['test'],
          content: 'content 1',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video1.mp4',
          thumbnailUrl: 'https://example.com/thumb1.jpg',
        ),
        VideoEvent(
          id: 'video-2',
          pubkey: 'pubkey-2',
          title: 'Video 2',
          hashtags: ['test'],
          content: 'content 2',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video2.mp4',
          thumbnailUrl: 'https://example.com/thumb2.jpg',
        ),
      ];

      await container.read(analyticsProvider.notifier).trackVideoViews(videos);

      verify(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).called(2);
    });
  });
}
