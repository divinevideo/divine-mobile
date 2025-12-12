// ABOUTME: Integration test for end-to-end video loading flow
// ABOUTME: Tests that videos load from VideoEventService through providers to UI display

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
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/video_event_service.dart';

import '../test_data/video_test_data.dart';
import 'video_loading_flow_test.mocks.dart';

// Fake AppForeground notifier for testing
class _FakeAppForeground extends AppForeground {
  @override
  bool build() => true; // Default to foreground
}

@GenerateMocks([VideoEventService, NostrClient])
void main() {
  group('Video Loading Flow Integration Tests', () {
    late MockVideoEventService mockVideoEventService;
    late MockNostrClient mockNostrService;
    late List<VideoEvent> testVideos;
    late ProviderContainer container;

    setUp(() {
      mockVideoEventService = MockVideoEventService();
      mockNostrService = MockNostrClient();

      // Create test videos using proper helper
      testVideos = List.generate(
        10,
        (i) => createTestVideoEvent(
          id: 'video_$i',
          pubkey: 'author_$i',
          title: 'Test Video $i',
          content: 'Test content $i',
          videoUrl: 'https://example.com/video$i.mp4',
          thumbnailUrl: 'https://example.com/thumb$i.jpg',
          createdAt: 1704067200 + (i * 3600), // Increment by 1 hour each
        ),
      );

      // Setup mocks
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockVideoEventService.discoveryVideos).thenReturn(testVideos);
      when(mockVideoEventService.isSubscribed(any)).thenReturn(false);
      when(mockVideoEventService.hasListeners).thenReturn(false);
    });

    tearDown(() {
      container.dispose();
    });

    test('complete flow: service -> provider -> state emission', () async {
      // Arrange
      container = ProviderContainer(
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

      // Act - Subscribe to video events provider
      final states = <AsyncValue<List<VideoEvent>>>[];
      final listener = container.listen(videoEventsProvider, (prev, next) {
        states.add(next);
      }, fireImmediately: true);

      await pumpEventQueue();

      // Assert - Flow verifications

      // 1. Service subscription should be triggered
      verify(mockVideoEventService.subscribeToDiscovery(limit: 100)).called(1);

      // 2. Listener should be attached to service
      verify(
        mockVideoEventService.removeListener(any),
      ).called(greaterThanOrEqualTo(1));
      verify(
        mockVideoEventService.addListener(any),
      ).called(greaterThanOrEqualTo(1));

      // 3. Provider should emit videos from service
      expect(
        states.any((s) => s.hasValue && s.value!.length == 10),
        isTrue,
        reason: 'Provider should emit all 10 test videos',
      );

      // 4. Videos should be in correct state
      final videoState = states.firstWhere(
        (s) => s.hasValue && s.value!.isNotEmpty,
      );
      expect(videoState.value!.first.id, equals('video_0'));
      expect(videoState.value!.length, equals(10));

      listener.close();
    });

    test('flow: service notifies -> provider emits update', () async {
      // Arrange - Start with empty videos
      when(mockVideoEventService.discoveryVideos).thenReturn([]);

      void Function()? attachedListener;
      when(mockVideoEventService.addListener(any)).thenAnswer((invocation) {
        attachedListener = invocation.positionalArguments[0] as void Function();
      });

      container = ProviderContainer(
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

      final states = <AsyncValue<List<VideoEvent>>>[];
      final listener = container.listen(videoEventsProvider, (prev, next) {
        states.add(next);
      }, fireImmediately: true);

      await pumpEventQueue();

      // Clear initial states
      states.clear();

      // Act - Simulate service receiving new videos
      when(mockVideoEventService.discoveryVideos).thenReturn(testVideos);
      attachedListener?.call(); // Trigger the listener

      // Wait for debounce (500ms) + processing
      await Future.delayed(const Duration(milliseconds: 600));
      await pumpEventQueue();

      // Assert - Provider should emit updated videos
      expect(
        states.any((s) => s.hasValue && s.value!.length == 10),
        isTrue,
        reason:
            'Provider should emit updated video list after service notification',
      );

      listener.close();
    });

    test('flow: seen video reordering works correctly', () async {
      // Arrange - Create container first, then mark videos as seen
      container = ProviderContainer(
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

      // Mark some videos as seen using the container's notifier
      final seenNotifier = container.read(seenVideosProvider.notifier);
      await seenNotifier.markVideoAsSeen('video_0');
      await seenNotifier.markVideoAsSeen('video_1');
      await seenNotifier.markVideoAsSeen('video_2');

      // Act
      final states = <AsyncValue<List<VideoEvent>>>[];
      final listener = container.listen(videoEventsProvider, (prev, next) {
        states.add(next);
      }, fireImmediately: true);

      await pumpEventQueue();

      // Assert - Unseen videos should be first
      final dataStates = states
          .where((s) => s.hasValue && s.value!.isNotEmpty)
          .toList();
      expect(dataStates.isNotEmpty, isTrue, reason: 'Should have data states');

      final videos = dataStates.last.value!;

      // First video should be unseen (video_3 or higher)
      expect(
        int.parse(videos.first.id.split('_').last) >= 3,
        isTrue,
        reason: 'First video should be unseen (index 3+)',
      );

      // Seen videos should be at the end
      final seenState = container.read(seenVideosProvider);
      final seenVideosInList = videos
          .where((v) => seenState.seenVideoIds.contains(v.id))
          .toList();
      final unseenVideosInList = videos
          .where((v) => !seenState.seenVideoIds.contains(v.id))
          .toList();

      expect(
        unseenVideosInList.length,
        equals(7),
        reason: 'Should have 7 unseen videos',
      );
      expect(
        seenVideosInList.length,
        equals(3),
        reason: 'Should have 3 seen videos',
      );

      // Unseen should come before seen in the list
      final firstSeenIndex = videos.indexWhere(
        (v) => seenState.seenVideoIds.contains(v.id),
      );
      final lastUnseenIndex = videos.lastIndexWhere(
        (v) => !seenState.seenVideoIds.contains(v.id),
      );

      expect(
        lastUnseenIndex < firstSeenIndex,
        isTrue,
        reason: 'All unseen videos should come before seen videos',
      );

      listener.close();
    });

    test('flow: cleanup on provider disposal', () async {
      // Arrange
      container = ProviderContainer(
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

      // Verify listener was attached
      verify(
        mockVideoEventService.addListener(any),
      ).called(greaterThanOrEqualTo(1));

      // Act - Dispose provider
      listener.close();
      container.dispose();

      // Assert - Listener should be removed
      verify(
        mockVideoEventService.removeListener(any),
      ).called(greaterThanOrEqualTo(1));
    });

    test('flow: empty state when gates not satisfied', () async {
      // Arrange - Wrong tab (not explore)
      container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWith(_FakeAppForeground.new),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(
                type: RouteType.home,
                videoIndex: 0,
              ), // NOT explore
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

      // Assert - Should emit empty list
      final dataStates = states.where((s) => s.hasValue).toList();
      expect(dataStates.isNotEmpty, isTrue);
      expect(
        dataStates.last.value!,
        isEmpty,
        reason: 'Should emit empty when not on explore tab',
      );

      // Should NOT subscribe when gates not satisfied
      verifyNever(
        mockVideoEventService.subscribeToDiscovery(limit: anyNamed('limit')),
      );

      listener.close();
    });
  });
}
