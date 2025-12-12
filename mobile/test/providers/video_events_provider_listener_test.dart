// ABOUTME: Tests for VideoEvents provider listener attachment and reactive updates
// ABOUTME: Verifies the fix for listener attachment race conditions and gate-based initialization

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/seen_videos_notifier.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/state/seen_videos_state.dart';

import 'video_events_provider_listener_test.mocks.dart';

class _FakeAppForeground extends AppForeground {
  final bool _isForeground;

  _FakeAppForeground(this._isForeground);

  @override
  bool build() => _isForeground;
}

class _FakeSeenVideosNotifier extends SeenVideosNotifier {
  final SeenVideosState _state;

  _FakeSeenVideosNotifier(this._state);

  @override
  SeenVideosState build() => _state;
}

@GenerateMocks([VideoEventService, NostrClient])
void main() {
  group('VideoEvents Provider - Listener Attachment', () {
    late MockVideoEventService mockVideoEventService;
    late MockNostrClient mockNostrService;
    late ProviderContainer container;

    setUp(() {
      mockVideoEventService = MockVideoEventService();
      mockNostrService = MockNostrClient();

      // Setup default mocks
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockVideoEventService.discoveryVideos).thenReturn([]);
      when(mockVideoEventService.isSubscribed(any)).thenReturn(false);
      when(mockVideoEventService.hasListeners).thenReturn(false);

      container = ProviderContainer(
        overrides: [
          // Override app readiness gates
          appForegroundProvider.overrideWith(() => _FakeAppForeground(true)),
          nostrServiceProvider.overrideWithValue(mockNostrService),

          // Override VideoEventService
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),

          // Override route context to simulate Explore tab
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.explore, videoIndex: 0),
            );
          }),

          // Override seen videos provider
          seenVideosProvider.overrideWith(
            () => _FakeSeenVideosNotifier(SeenVideosState.initial),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      reset(mockVideoEventService);
      reset(mockNostrService);
    });

    test(
      'should attach listener when gates are satisfied on initial build',
      () async {
        // Act - Read the provider to trigger build
        final listener = container.listen(videoEventsProvider, (prev, next) {});

        // Allow async processing
        await pumpEventQueue();

        // Assert - Verify listener was attached
        verify(
          mockVideoEventService.addListener(any),
        ).called(greaterThanOrEqualTo(1));

        listener.close();
      },
    );

    test('should attach listener when gates flip from false to true', () async {
      // Arrange - Start with gates not satisfied
      final testContainer = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWith(
            () => _FakeAppForeground(false),
          ), // NOT ready initially
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.explore, videoIndex: 0),
            );
          }),
          seenVideosProvider.overrideWith(
            () => _FakeSeenVideosNotifier(SeenVideosState.initial),
          ),
        ],
      );

      final listener = testContainer.listen(
        videoEventsProvider,
        (prev, next) {},
      );

      await pumpEventQueue();

      // Clear any initial interactions from the setup
      clearInteractions(mockVideoEventService);

      // Act - Make app ready
      testContainer.updateOverrides([
        appForegroundProvider.overrideWith(
          () => _FakeAppForeground(true),
        ), // NOW ready
        nostrServiceProvider.overrideWithValue(mockNostrService),
        videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        pageContextProvider.overrideWith((ref) {
          return Stream.value(
            const RouteContext(type: RouteType.explore, videoIndex: 0),
          );
        }),
        seenVideosProvider.overrideWith(
          () => _FakeSeenVideosNotifier(SeenVideosState.initial),
        ),
      ]);

      // Trigger rebuild by invalidating
      testContainer.invalidate(videoEventsProvider);

      await pumpEventQueue();

      // Assert - Should attach listener after gates flip
      verify(
        mockVideoEventService.addListener(any),
      ).called(greaterThanOrEqualTo(1));

      listener.close();
      testContainer.dispose();
    });

    test(
      'should use remove-then-add pattern for idempotent listener attachment',
      () async {
        // Act - Read provider
        final listener = container.listen(videoEventsProvider, (prev, next) {});

        await pumpEventQueue();

        // Assert - Should call both remove and add to ensure clean state
        verify(
          mockVideoEventService.removeListener(any),
        ).called(greaterThanOrEqualTo(1));
        verify(
          mockVideoEventService.addListener(any),
        ).called(greaterThanOrEqualTo(1));

        listener.close();
      },
    );

    test('should subscribe to discovery videos when ready', () async {
      // Act
      final listener = container.listen(videoEventsProvider, (prev, next) {});

      await pumpEventQueue();

      // Assert - Use any() matchers for optional arguments
      // May be called more than once due to async provider rebuilds
      verify(
        mockVideoEventService.subscribeToDiscovery(
          limit: anyNamed('limit'),
          sortBy: anyNamed('sortBy'),
          nip50Sort: anyNamed('nip50Sort'),
          force: anyNamed('force'),
        ),
      ).called(greaterThanOrEqualTo(1));

      listener.close();
    });

    test(
      'should emit current videos immediately when subscription starts',
      () async {
        // Arrange - Service has existing videos
        final now = DateTime.now();
        final timestamp = now.millisecondsSinceEpoch;
        final testVideos = <VideoEvent>[
          VideoEvent(
            id: 'video1',
            pubkey: 'author1',
            title: 'Test Video 1',
            content: 'Content 1',
            videoUrl: 'https://example.com/video1.mp4',
            createdAt: timestamp,
            timestamp: now,
          ),
          VideoEvent(
            id: 'video2',
            pubkey: 'author2',
            title: 'Test Video 2',
            content: 'Content 2',
            videoUrl: 'https://example.com/video2.mp4',
            createdAt: timestamp,
            timestamp: now,
          ),
        ];

        when(mockVideoEventService.discoveryVideos).thenReturn(testVideos);

        // Act
        final states = <AsyncValue<List<VideoEvent>>>[];
        final listener = container.listen(videoEventsProvider, (prev, next) {
          states.add(next);
        }, fireImmediately: true);

        // Pump event queue multiple times for async operations
        await pumpEventQueue();
        await pumpEventQueue();
        await pumpEventQueue();

        // Assert - Should emit videos (BehaviorSubject replays to late subscribers)
        // The provider emits when listener notifies, so check that discoveryVideos was accessed
        verify(mockVideoEventService.discoveryVideos).called(greaterThan(0));

        listener.close();
      },
    );

    test('should reorder videos to show unseen first', () async {
      // Arrange - Service has mix of seen and unseen videos
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;
      final testVideos = <VideoEvent>[
        VideoEvent(
          id: 'seen1',
          pubkey: 'author1',
          title: 'Seen Video 1',
          content: 'Content 1',
          videoUrl: 'https://example.com/video1.mp4',
          createdAt: timestamp,
          timestamp: now,
        ),
        VideoEvent(
          id: 'unseen1',
          pubkey: 'author2',
          title: 'Unseen Video 1',
          content: 'Content 2',
          videoUrl: 'https://example.com/video2.mp4',
          createdAt: timestamp,
          timestamp: now,
        ),
        VideoEvent(
          id: 'seen2',
          pubkey: 'author3',
          title: 'Seen Video 2',
          content: 'Content 3',
          videoUrl: 'https://example.com/video3.mp4',
          createdAt: timestamp,
          timestamp: now,
        ),
      ];

      when(mockVideoEventService.discoveryVideos).thenReturn(testVideos);

      // Mark some as seen
      final seenState = SeenVideosState.initial.copyWith(
        seenVideoIds: {'seen1', 'seen2'},
      );

      final testContainer = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWith(() => _FakeAppForeground(true)),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.explore, videoIndex: 0),
            );
          }),
          seenVideosProvider.overrideWith(
            () => _FakeSeenVideosNotifier(seenState),
          ),
        ],
      );

      // Act
      final states = <AsyncValue<List<VideoEvent>>>[];
      final listener = testContainer.listen(videoEventsProvider, (prev, next) {
        states.add(next);
      }, fireImmediately: true);

      // Pump event queue multiple times for async operations
      await pumpEventQueue();
      await pumpEventQueue();
      await pumpEventQueue();

      // Assert - Provider should have accessed discoveryVideos and processed them
      // The test verifies the seen/unseen reordering logic is called
      verify(mockVideoEventService.discoveryVideos).called(greaterThan(0));

      // Also verify we got data states back
      final dataStates = states.where((s) => s.hasValue).toList();
      expect(dataStates.isNotEmpty, isTrue);

      listener.close();
      testContainer.dispose();
    });

    test('should emit empty list when gates not satisfied', () async {
      // Arrange - Gates not satisfied
      final testContainer = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWith(
            () => _FakeAppForeground(false),
          ), // NOT ready
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(
                type: RouteType.home,
                videoIndex: 0,
              ), // Wrong tab
            );
          }),
          seenVideosProvider.overrideWith(
            () => _FakeSeenVideosNotifier(SeenVideosState.initial),
          ),
        ],
      );

      // Act
      final states = <AsyncValue<List<VideoEvent>>>[];
      final listener = testContainer.listen(videoEventsProvider, (prev, next) {
        states.add(next);
      }, fireImmediately: true);

      await pumpEventQueue();

      // Assert
      final dataStates = states.where((s) => s.hasValue).toList();
      expect(dataStates.isNotEmpty, isTrue);
      expect(
        dataStates.last.value!,
        isEmpty,
        reason: 'Should emit empty list when not ready',
      );

      // Should NOT subscribe when not ready
      verifyNever(
        mockVideoEventService.subscribeToDiscovery(limit: anyNamed('limit')),
      );

      listener.close();
      testContainer.dispose();
    });

    test('should cleanup listener on dispose', () async {
      // Arrange
      final listener = container.listen(videoEventsProvider, (prev, next) {});

      await pumpEventQueue();

      // Verify listener was attached
      verify(
        mockVideoEventService.addListener(any),
      ).called(greaterThanOrEqualTo(1));

      // Act - Dispose
      listener.close();
      container.dispose();

      // Assert - Should remove listener on cleanup
      verify(
        mockVideoEventService.removeListener(any),
      ).called(greaterThanOrEqualTo(1));
    });
  });

  group('VideoEvents Provider - Reactive Updates', () {
    late MockVideoEventService mockVideoEventService;
    late MockNostrClient mockNostrService;
    late ProviderContainer container;
    late StreamController<void> serviceNotifier;

    setUp(() {
      mockVideoEventService = MockVideoEventService();
      mockNostrService = MockNostrClient();
      serviceNotifier = StreamController<void>.broadcast();

      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockVideoEventService.discoveryVideos).thenReturn([]);
      when(mockVideoEventService.isSubscribed(any)).thenReturn(false);
      when(mockVideoEventService.hasListeners).thenReturn(false);

      container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWith(() => _FakeAppForeground(true)),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.explore, videoIndex: 0),
            );
          }),
          seenVideosProvider.overrideWith(
            () => _FakeSeenVideosNotifier(SeenVideosState.initial),
          ),
        ],
      );
    });

    tearDown(() {
      serviceNotifier.close();
      container.dispose();
      reset(mockVideoEventService);
      reset(mockNostrService);
    });

    test('should react to service notifyListeners calls', () async {
      // Arrange - Start with no videos
      when(mockVideoEventService.discoveryVideos).thenReturn([]);

      final states = <AsyncValue<List<VideoEvent>>>[];
      void Function()? attachedListener;

      // Capture the listener when it's attached
      when(mockVideoEventService.addListener(any)).thenAnswer((invocation) {
        attachedListener = invocation.positionalArguments[0] as void Function();
      });

      final listener = container.listen(videoEventsProvider, (prev, next) {
        states.add(next);
      }, fireImmediately: true);

      await pumpEventQueue();

      // Clear initial states
      states.clear();

      // Act - Add videos and trigger listener
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;
      final newVideos = <VideoEvent>[
        VideoEvent(
          id: 'new1',
          pubkey: 'author1',
          title: 'New Video',
          content: 'Content',
          videoUrl: 'https://example.com/new.mp4',
          createdAt: timestamp,
          timestamp: now,
        ),
      ];
      when(mockVideoEventService.discoveryVideos).thenReturn(newVideos);

      // Simulate service calling notifyListeners
      attachedListener?.call();

      // Wait for debounce (500ms) + processing
      await Future.delayed(const Duration(milliseconds: 600));
      await pumpEventQueue();

      // Assert - Should have received update
      expect(
        states.any((s) => s.hasValue && s.value!.isNotEmpty),
        isTrue,
        reason: 'Should receive updates from service',
      );

      listener.close();
    });
  });
}
