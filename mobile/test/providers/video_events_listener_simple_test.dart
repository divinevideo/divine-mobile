// ABOUTME: Simplified tests for VideoEvents provider listener attachment fix
// ABOUTME: Verifies that listener attachment works correctly after the
// ABOUTME: idempotent fix

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/seen_videos_notifier.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockNostrClient extends Mock implements NostrClient {}

// Fake AppForeground notifier for testing
class _FakeAppForeground extends AppForeground {
  @override
  bool build() => true; // Default to foreground
}

void main() {
  setUpAll(() {
    registerFallbackValue(SubscriptionType.discovery);
    registerFallbackValue(() {});
    registerFallbackValue(<VideoEvent>[]);
  });

  group('VideoEvents Provider - Listener Attachment Fix', () {
    late _MockVideoEventService mockVideoEventService;
    late _MockNostrClient mockNostrService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockVideoEventService = _MockVideoEventService();
      mockNostrService = _MockNostrClient();

      // Setup default mocks
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockVideoEventService.discoveryVideos).thenReturn([]);
      when(() => mockVideoEventService.isSubscribed(any())).thenReturn(false);
      when(
        () => mockVideoEventService.addVideoUpdateListener(any()),
      ).thenReturn(() {});
      when(
        () => mockVideoEventService.subscribeToDiscovery(
          nip50Sort: NIP50SortMode.hot,
        ),
      ).thenAnswer((_) async {});
      when(() => mockVideoEventService.filterVideoList(any())).thenAnswer(
        (invocation) =>
            invocation.positionalArguments.first as List<VideoEvent>,
      );
      // This mock exposes ChangeNotifier listener state to isolate the provider.
      // ignore: invalid_use_of_protected_member
      when(() => mockVideoEventService.hasListeners).thenReturn(false);
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

      when(() => mockVideoEventService.discoveryVideos).thenReturn(testVideos);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          appForegroundProvider.overrideWith(_FakeAppForeground.new),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.explore, videoIndex: 0),
            );
          }),
          seenVideosProvider.overrideWith(SeenVideosNotifier.new),
        ],
      );

      // Act
      addTearDown(container.dispose);
      final states = <AsyncValue<List<VideoEvent>>>[];
      final listener = container.listen(videoEventsProvider, (prev, next) {
        states.add(next);
      }, fireImmediately: true);
      addTearDown(listener.close);

      // Pump event queue multiple times for async operations
      await pumpEventQueue();
      await pumpEventQueue();
      await pumpEventQueue();

      expect(states, contains(AsyncData<List<VideoEvent>>(testVideos)));
    });

    test('late provider subscribers receive existing videos', () async {
      // Arrange - Service has videos ready
      final now = DateTime.now();
      final testVideos = <VideoEvent>[
        VideoEvent(
          id: 'cached_video_1',
          pubkey: 'author1',
          title: 'Cached Video',
          content: 'Content',
          videoUrl: 'https://example.com/cached.mp4',
          createdAt: now.millisecondsSinceEpoch,
          timestamp: now,
        ),
      ];

      when(() => mockVideoEventService.discoveryVideos).thenReturn(testVideos);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          appForegroundProvider.overrideWith(_FakeAppForeground.new),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.explore, videoIndex: 0),
            );
          }),
          seenVideosProvider.overrideWith(SeenVideosNotifier.new),
        ],
      );

      // Act - First subscriber triggers data emission
      addTearDown(container.dispose);
      final firstListener = container.listen(
        videoEventsProvider,
        (prev, next) {},
      );
      addTearDown(firstListener.close);

      await pumpEventQueue();
      await pumpEventQueue();

      expect(container.read(videoEventsProvider).value, testVideos);

      // Late subscriber - like PopularVideosTab subscribing after
      // data emits
      final lateStates = <AsyncValue<List<VideoEvent>>>[];
      final lateListener = container.listen(videoEventsProvider, (prev, next) {
        lateStates.add(next);
      }, fireImmediately: true);
      addTearDown(lateListener.close);

      await pumpEventQueue();
      await pumpEventQueue();

      expect(lateStates.first.value, testVideos);
    });
  });
}
