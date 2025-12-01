// ABOUTME: Simplified tests for VideoEvents provider listener attachment fix
// ABOUTME: Verifies that listener attachment works correctly after the idempotent fix

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/seen_videos_notifier.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';

import 'video_events_listener_simple_test.mocks.dart';

// Fake AppForeground notifier for testing
class _FakeAppForeground extends AppForeground {
  @override
  bool build() => true; // Default to foreground
}

@GenerateMocks([VideoEventService, INostrService])
void main() {
  group('VideoEvents Provider - Listener Attachment Fix', () {
    late MockVideoEventService mockVideoEventService;
    late MockINostrService mockNostrService;

    setUp(() {
      mockVideoEventService = MockVideoEventService();
      mockNostrService = MockINostrService();

      // Setup default mocks
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockVideoEventService.discoveryVideos).thenReturn([]);
      when(mockVideoEventService.isSubscribed(any)).thenReturn(false);
      when(mockVideoEventService.hasListeners).thenReturn(false);
    });

    test('should call addListener on VideoEventService', () async {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWith(_FakeAppForeground.new),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.explore, videoIndex: 0),
            );
          }),
          seenVideosProvider.overrideWith(() => SeenVideosNotifier()),
        ],
      );

      // Act - Subscribe to provider
      final listener = container.listen(videoEventsProvider, (prev, next) {});

      // Allow async processing
      await pumpEventQueue();

      // Assert - Verify listener was attached (remove-then-add pattern)
      verify(
        mockVideoEventService.removeListener(any),
      ).called(greaterThanOrEqualTo(1));
      verify(
        mockVideoEventService.addListener(any),
      ).called(greaterThanOrEqualTo(1));

      listener.close();
      container.dispose();
    });

    test('should subscribe to discovery videos', () async {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWith(_FakeAppForeground.new),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.explore, videoIndex: 0),
            );
          }),
          seenVideosProvider.overrideWith(() => SeenVideosNotifier()),
        ],
      );

      // Act
      final listener = container.listen(videoEventsProvider, (prev, next) {});

      await pumpEventQueue();

      // Assert
      verify(mockVideoEventService.subscribeToDiscovery(limit: 100)).called(1);

      listener.close();
      container.dispose();
    });

    test('should emit existing videos from service', () async {
      // Arrange - Service has videos
      final now = DateTime.now();
      final testVideos = <VideoEvent>[
        VideoEvent(
          id: 'video1',
          pubkey: 'author1',
          title: 'Test Video 1',
          content: 'Content 1',
          videoUrl: 'https://example.com/video1.mp4',
          createdAt: now.millisecondsSinceEpoch,
          timestamp: now,
        ),
        VideoEvent(
          id: 'video2',
          pubkey: 'author2',
          title: 'Test Video 2',
          content: 'Content 2',
          videoUrl: 'https://example.com/video2.mp4',
          createdAt: now.millisecondsSinceEpoch,
          timestamp: now,
        ),
      ];

      when(mockVideoEventService.discoveryVideos).thenReturn(testVideos);

      final container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWith(_FakeAppForeground.new),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.explore, videoIndex: 0),
            );
          }),
          seenVideosProvider.overrideWith(() => SeenVideosNotifier()),
        ],
      );

      // Act
      final states = <AsyncValue<List<VideoEvent>>>[];
      final listener = container.listen(videoEventsProvider, (prev, next) {
        states.add(next);
      }, fireImmediately: true);

      await pumpEventQueue();

      // Assert - Should emit videos
      expect(
        states.any((s) => s.hasValue && s.value!.length == 2),
        isTrue,
        reason: 'Should emit 2 videos from service',
      );

      listener.close();
      container.dispose();
    });

    test('should cleanup listener on dispose', () async {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWith(_FakeAppForeground.new),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.explore, videoIndex: 0),
            );
          }),
          seenVideosProvider.overrideWith(() => SeenVideosNotifier()),
        ],
      );

      final listener = container.listen(videoEventsProvider, (prev, next) {});

      await pumpEventQueue();

      // Act - Dispose
      listener.close();
      container.dispose();

      // Assert - Should remove listener on cleanup
      verify(
        mockVideoEventService.removeListener(any),
      ).called(greaterThanOrEqualTo(1));
    });

    test('idempotent listener attachment - remove then add', () async {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWith(_FakeAppForeground.new),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.explore, videoIndex: 0),
            );
          }),
          seenVideosProvider.overrideWith(() => SeenVideosNotifier()),
        ],
      );

      // Act
      final listener = container.listen(videoEventsProvider, (prev, next) {});

      await pumpEventQueue();

      // Assert - Should use remove-then-add pattern for idempotency
      final allCalls = verify(
        mockVideoEventService.removeListener(captureAny),
      ).captured;
      final allAdds = verify(
        mockVideoEventService.addListener(captureAny),
      ).captured;

      expect(allCalls.isNotEmpty, isTrue, reason: 'Should call removeListener');
      expect(allAdds.isNotEmpty, isTrue, reason: 'Should call addListener');

      listener.close();
      container.dispose();
    });
  });
}
