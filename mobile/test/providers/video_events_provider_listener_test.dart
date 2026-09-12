// ABOUTME: Tests for VideoEvents provider listener attachment and reactive
// ABOUTME: updates. Verifies listener attachment, gate-based initialization,
// ABOUTME: and cleanup behavior.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _FakeAppForeground extends AppForeground {
  @override
  bool build() => true;
}

/// Creates a [ProviderContainer] with standard overrides for testing
/// the [videoEventsProvider].
ProviderContainer _createContainer({
  required _MockVideoEventService mockVideoEventService,
  required SharedPreferences sharedPreferences,
  ContentBlocklistRepository? blocklistRepository,
}) {
  final effectiveBlocklistRepository =
      blocklistRepository ?? _MockContentBlocklistRepository();
  if (effectiveBlocklistRepository is _MockContentBlocklistRepository) {
    when(
      () => effectiveBlocklistRepository.shouldFilterFromFeeds(any()),
    ).thenReturn(false);
  }

  return ProviderContainer(
    overrides: [
      // Override the gate providers directly to avoid complex dependency chains
      appReadyProvider.overrideWith((ref) => true),
      isDiscoveryTabActiveProvider.overrideWith((ref) => true),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),

      // Override blocklist service to avoid SharedPreferences dependency
      contentBlocklistRepositoryProvider.overrideWithValue(
        effectiveBlocklistRepository,
      ),

      // Override foreground provider (used by gate listeners)
      appForegroundProvider.overrideWith(_FakeAppForeground.new),

      // Override VideoEventService
      videoEventServiceProvider.overrideWithValue(mockVideoEventService),

      // Override page context to simulate Explore tab
      pageContextProvider.overrideWith(
        (ref) => Stream.value(
          const RouteContext(
            type: RouteType.explore,
            videoIndex: 0,
          ),
        ),
      ),
    ],
  );
}

/// Sets up standard mock behaviors for [_MockVideoEventService].
void _setupMockDefaults(_MockVideoEventService mock) {
  when(() => mock.discoveryVideos).thenReturn([]);
  when(() => mock.isSubscribed(any())).thenReturn(false);
  when(() => mock.filterVideoList(any())).thenAnswer(
    (invocation) => invocation.positionalArguments.first as List<VideoEvent>,
  );

  // Mock addVideoUpdateListener (called by provider during build)
  when(() => mock.addVideoUpdateListener(any())).thenReturn(() {});

  // Mock ChangeNotifier methods (addListener/removeListener)
  when(() => mock.addListener(any())).thenReturn(null);
  when(() => mock.removeListener(any())).thenReturn(null);
  // This mock exposes ChangeNotifier listener state to isolate the provider.
  // ignore: invalid_use_of_protected_member
  when(() => mock.hasListeners).thenReturn(false);

  // Mock subscription call
  when(
    () => mock.subscribeToDiscovery(
      limit: any(named: 'limit'),
      sortBy: any(named: 'sortBy'),
      nip50Sort: any(named: 'nip50Sort'),
      force: any(named: 'force'),
    ),
  ).thenAnswer((_) async {});
}

void main() {
  setUpAll(() {
    registerFallbackValue(SubscriptionType.discovery);
    registerFallbackValue(() {});
    registerFallbackValue(<VideoEvent>[]);
    registerFallbackValue(NIP50SortMode.hot);
  });

  group('VideoEvents Provider - Listener Attachment', () {
    late _MockVideoEventService mockVideoEventService;
    late SharedPreferences sharedPreferences;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockVideoEventService = _MockVideoEventService();
      _setupMockDefaults(mockVideoEventService);

      container = _createContainer(
        mockVideoEventService: mockVideoEventService,
        sharedPreferences: sharedPreferences,
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'should attach listener when gates are satisfied on initial build',
      () async {
        // Act - Read the provider to trigger build
        final listener = container.listen(videoEventsProvider, (prev, next) {});

        // Allow async processing
        await pumpEventQueue();

        // Assert - Verify ChangeNotifier listener was attached
        verify(
          () => mockVideoEventService.addListener(any()),
        ).called(greaterThanOrEqualTo(1));

        // Also verify addVideoUpdateListener was called during build
        verify(
          () => mockVideoEventService.addVideoUpdateListener(any()),
        ).called(greaterThanOrEqualTo(1));

        listener.close();
      },
    );

    test(
      'should use remove-then-add pattern for idempotent listener attachment',
      () async {
        // Act - Read provider
        final listener = container.listen(videoEventsProvider, (prev, next) {});

        await pumpEventQueue();

        // Assert - _startSubscription does removeListener then addListener
        verify(
          () => mockVideoEventService.removeListener(any()),
        ).called(greaterThanOrEqualTo(1));
        verify(
          () => mockVideoEventService.addListener(any()),
        ).called(greaterThanOrEqualTo(1));

        listener.close();
      },
    );

    test('should subscribe to discovery videos when ready', () async {
      // Act
      final listener = container.listen(videoEventsProvider, (prev, next) {});

      await pumpEventQueue();

      // Assert - subscribeToDiscovery should be called
      verify(
        () => mockVideoEventService.subscribeToDiscovery(
          limit: any(named: 'limit'),
          sortBy: any(named: 'sortBy'),
          nip50Sort: any(named: 'nip50Sort'),
          force: any(named: 'force'),
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

        when(
          () => mockVideoEventService.discoveryVideos,
        ).thenReturn(testVideos);

        // Act
        final states = <AsyncValue<List<VideoEvent>>>[];
        final listener = container.listen(videoEventsProvider, (prev, next) {
          states.add(next);
        }, fireImmediately: true);

        // Pump event queue multiple times for async microtask emission
        await pumpEventQueue();
        await pumpEventQueue();
        await pumpEventQueue();

        expect(
          states.where((state) => state.hasValue).last.value,
          orderedEquals(testVideos),
        );

        listener.close();
      },
    );

    test('should cleanup listener on dispose', () async {
      // Arrange
      final listener = container.listen(videoEventsProvider, (prev, next) {});

      await pumpEventQueue();

      // Verify listener was attached
      verify(
        () => mockVideoEventService.addListener(any()),
      ).called(greaterThanOrEqualTo(1));

      // Act - Dispose
      listener.close();
      container.dispose();

      // Assert - removeListener should be called during disposal
      // (both from _stopSubscription and ref.onDispose)
      verify(
        () => mockVideoEventService.removeListener(any()),
      ).called(greaterThanOrEqualTo(1));
    });
  });

  group('VideoEvents Provider - Reactive Updates', () {
    late _MockVideoEventService mockVideoEventService;
    late SharedPreferences sharedPreferences;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockVideoEventService = _MockVideoEventService();
      _setupMockDefaults(mockVideoEventService);

      container = _createContainer(
        mockVideoEventService: mockVideoEventService,
        sharedPreferences: sharedPreferences,
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should react to service notifyListeners calls', () {
      // Arrange - Start with no videos
      when(() => mockVideoEventService.discoveryVideos).thenReturn([]);

      VoidCallback? attachedListener;

      // Capture the ChangeNotifier listener when it's attached
      when(() => mockVideoEventService.addListener(any())).thenAnswer((
        invocation,
      ) {
        attachedListener = invocation.positionalArguments[0] as VoidCallback;
      });

      fakeAsync((async) {
        final states = <AsyncValue<List<VideoEvent>>>[];
        final listener = container.listen(videoEventsProvider, (prev, next) {
          states.add(next);
        }, fireImmediately: true);
        async.flushMicrotasks();

        // Ignore the initial empty-list emission and observe only the update.
        states.clear();

        final now = DateTime.now();
        final newVideos = <VideoEvent>[
          VideoEvent(
            id: 'new1',
            pubkey: 'author1',
            title: 'New Video',
            content: 'Content',
            videoUrl: 'https://example.com/new.mp4',
            createdAt: now.millisecondsSinceEpoch,
            timestamp: now,
          ),
        ];
        when(() => mockVideoEventService.discoveryVideos).thenReturn(newVideos);

        // Simulate VideoEventService notifying the provider, then advance the
        // provider's 500 ms batching timer without waiting on wall-clock time.
        attachedListener?.call();
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(
          states.where((state) => state.hasValue).last.value,
          orderedEquals(newVideos),
        );

        listener.close();
      });
    });
  });
}
