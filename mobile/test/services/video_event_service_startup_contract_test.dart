import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/event_router.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockNostrEventsDao extends Mock implements NostrEventsDao {}

class _MockRelayCapabilityService extends Mock
    implements RelayCapabilityService {}

class _FakeFilter extends Fake implements Filter {}

class _RecordingPerformanceMonitor implements PerformanceTraceMonitor {
  final startedTraces = <String>[];
  final stoppedTraces = <String>[];
  final metrics = <String, Map<String, int>>{};
  final attributes = <String, Map<String, String>>{};

  @override
  PerformanceTrace startOperationTrace(String traceName) {
    startedTraces.add(traceName);
    return _RecordingTrace(this, traceName);
  }
}

/// Records a single handle's calls back into its [_RecordingPerformanceMonitor]
/// under the trace name, so the assertions stay keyed by name even though the
/// production code now addresses traces by handle.
class _RecordingTrace implements PerformanceTrace {
  _RecordingTrace(this._monitor, this._traceName);

  final _RecordingPerformanceMonitor _monitor;
  final String _traceName;

  @override
  void putAttribute(String attribute, String value) {
    _monitor.attributes.putIfAbsent(_traceName, () => {})[attribute] = value;
  }

  @override
  void setMetric(String metric, int value) {
    _monitor.metrics.putIfAbsent(_traceName, () => {})[metric] = value;
  }

  @override
  Future<void> stop() async {
    _monitor.stoppedTraces.add(_traceName);
  }
}

/// Asserts a feed-load trace was started once, stopped exactly once, and closed
/// with the expected first-wins [completion] label and [eventCount] metric.
///
/// The "exactly once" check on [stoppedTraces] is what enforces the trace
/// completion guard's idempotency: if a later completion path leaked past
/// the FeedLoadTrace first-wins latch it would append a second stop (and
/// overwrite the completion attribute), failing this helper.
void _expectSingleCompletion(
  _RecordingPerformanceMonitor monitor, {
  required String traceName,
  required String completion,
  required int eventCount,
}) {
  expect(monitor.startedTraces, contains(traceName));
  expect(
    monitor.stoppedTraces.where((t) => t == traceName).length,
    1,
    reason: 'trace $traceName must be stopped exactly once (first-wins guard)',
  );
  expect(monitor.metrics[traceName]?['event_count'], eventCount);
  expect(monitor.attributes[traceName]?['completion'], completion);
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(<Event>[]);
  });

  group('VideoEventService startup contract', () {
    late _MockNostrClient mockNostrService;
    late _MockProfileRepository mockProfileRepository;
    late _MockAppDatabase mockDatabase;
    late _MockNostrEventsDao mockNostrEventsDao;
    late _MockRelayCapabilityService mockRelayCapabilityService;
    late StreamController<Event> relayController;
    late VideoEventService videoEventService;
    late Completer<Map<String, UserProfile>> batchFetchCompleter;
    late _RecordingPerformanceMonitor performanceMonitor;
    late void Function()? relayEose;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockProfileRepository = _MockProfileRepository();
      mockDatabase = _MockAppDatabase();
      mockNostrEventsDao = _MockNostrEventsDao();
      mockRelayCapabilityService = _MockRelayCapabilityService();
      relayController = StreamController<Event>.broadcast();
      batchFetchCompleter = Completer<Map<String, UserProfile>>();
      performanceMonitor = _RecordingPerformanceMonitor();
      relayEose = null;

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(() => mockNostrService.connectedRelays).thenReturn(const <String>[]);
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((invocation) {
        relayEose = invocation.namedArguments[#onEose] as void Function()?;
        return relayController.stream;
      });

      when(() => mockDatabase.nostrEventsDao).thenReturn(mockNostrEventsDao);
      when(
        () => mockNostrEventsDao.getEventsByFilter(
          any(),
          sortBy: any(named: 'sortBy'),
        ),
      ).thenAnswer((_) async => [_cachedVideoEvent()]);
      when(
        () => mockNostrEventsDao.upsertEventsBatch(
          any(),
          expireAt: any(named: 'expireAt'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockProfileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) => batchFetchCompleter.future);
      when(
        () => mockRelayCapabilityService.getRelayCapabilities(any()),
      ).thenAnswer(
        (invocation) async => RelayCapabilities(
          relayUrl: invocation.positionalArguments.single as String,
          rawData: const {},
        ),
      );

      videoEventService = VideoEventService(
        mockNostrService,
        crashReporter: const SilentCrashReporter(),
        profileRepository: mockProfileRepository,
        eventRouter: EventRouter(mockDatabase),
        performanceMonitor: performanceMonitor,
        videoFilterBuilder: VideoFilterBuilder(mockRelayCapabilityService),
      );
    });

    tearDown(() async {
      if (!batchFetchCompleter.isCompleted) {
        batchFetchCompleter.complete(<String, UserProfile>{});
      }
      // Cancel the stream subscription and clear params BEFORE closing the
      // controller, so onDone never fires and no 5s reconnection Timer leaks
      // into later suites in the merged VGV isolate.
      await videoEventService.unsubscribeFromVideoFeed();
      if (!relayController.isClosed) {
        await relayController.close();
      }
    });

    // Configures the cache DAO to return no cached events, so the relay
    // completion paths — not the 'cache' path — win the trace.
    void withEmptyCache() {
      when(
        () => mockNostrEventsDao.getEventsByFilter(
          any(),
          sortBy: any(named: 'sortBy'),
        ),
      ).thenAnswer((_) async => const <Event>[]);
    }

    test(
      'returns after cached events without waiting for batch profile hydration',
      () async {
        await videoEventService
            .subscribeToVideoFeed(subscriptionType: SubscriptionType.discovery)
            .timeout(const Duration(milliseconds: 100));

        expect(videoEventService.discoveryVideos, isNotEmpty);
        verify(
          () => mockProfileRepository.fetchBatchProfiles(pubkeys: ['a' * 64]),
        ).called(1);
        verify(
          () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
        ).called(1);
      },
    );

    group('feed-load trace completion', () {
      test('cache: cached events populate the feed', () async {
        await videoEventService
            .subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['a' * 64],
            )
            .timeout(const Duration(milliseconds: 100));

        _expectSingleCompletion(
          performanceMonitor,
          traceName: 'feed_load_profile',
          completion: 'cache',
          eventCount: 1,
        );
        expect(
          performanceMonitor.metrics['feed_load_profile']!.keys,
          unorderedEquals(['event_count', 'cache_read_ms', 'cache_ingest_ms']),
        );
      });

      test('eose_empty: relay completes with no events', () async {
        withEmptyCache();

        await videoEventService
            .subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['a' * 64],
            )
            .timeout(const Duration(milliseconds: 100));

        relayEose!();

        _expectSingleCompletion(
          performanceMonitor,
          traceName: 'feed_load_profile',
          completion: 'eose_empty',
          eventCount: 0,
        );
      });

      test('first_relay_event: first relay event arrives', () async {
        withEmptyCache();

        await videoEventService
            .subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['a' * 64],
            )
            .timeout(const Duration(milliseconds: 100));

        relayController.add(_relayVideoEvent());
        await pumpEventQueue();

        _expectSingleCompletion(
          performanceMonitor,
          traceName: 'feed_load_profile',
          completion: 'first_relay_event',
          eventCount: 1,
        );
        expect(
          performanceMonitor.attributes['feed_load_profile']!['terminal_phase'],
          'relay_wait_ms',
        );
        expect(
          performanceMonitor.metrics['feed_load_profile']!.keys,
          unorderedEquals([
            'event_count',
            'cache_read_ms',
            'cache_ingest_ms',
            'relay_wait_ms',
          ]),
        );
      });

      test('error: relay stream errors before any completion', () async {
        withEmptyCache();

        await videoEventService
            .subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['a' * 64],
            )
            .timeout(const Duration(milliseconds: 100));

        relayController.addError(Exception('relay boom'));
        await pumpEventQueue();

        _expectSingleCompletion(
          performanceMonitor,
          traceName: 'feed_load_profile',
          completion: 'error',
          eventCount: 0,
        );
      });

      test('done: relay stream closes before any completion', () async {
        withEmptyCache();

        // Non-persistent type: onDone cleans up instead of scheduling a
        // reconnection timer, keeping the test timer-clean.
        await videoEventService
            .subscribeToVideoFeed(subscriptionType: SubscriptionType.search)
            .timeout(const Duration(milliseconds: 100));

        await relayController.close();

        _expectSingleCompletion(
          performanceMonitor,
          traceName: 'feed_load_search',
          completion: 'done',
          eventCount: 0,
        );
      });

      test('timeout: no events and no EOSE within the timeout window', () {
        withEmptyCache();

        fakeAsync((async) {
          videoEventService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.profile,
            authors: ['a' * 64],
          );
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 31));
          async.flushMicrotasks();

          _expectSingleCompletion(
            performanceMonitor,
            traceName: 'feed_load_profile',
            completion: 'timeout',
            eventCount: 0,
          );
        });
      });

      test(
        'idempotent: first relay event wins, later EOSE does not re-complete',
        () async {
          withEmptyCache();

          await videoEventService
              .subscribeToVideoFeed(
                subscriptionType: SubscriptionType.profile,
                authors: ['a' * 64],
              )
              .timeout(const Duration(milliseconds: 100));

          relayController.add(_relayVideoEvent());
          await pumpEventQueue();

          // eventCount is now 1, so this drives the 'eose' branch — which must
          // be blocked by the first-wins guard rather than re-completing.
          relayEose!();
          await pumpEventQueue();

          _expectSingleCompletion(
            performanceMonitor,
            traceName: 'feed_load_profile',
            completion: 'first_relay_event',
            eventCount: 1,
          );
        },
      );

      test(
        'idempotent: first relay event wins, later done does not re-complete',
        () async {
          withEmptyCache();

          await videoEventService
              .subscribeToVideoFeed(subscriptionType: SubscriptionType.search)
              .timeout(const Duration(milliseconds: 100));

          relayController.add(_relayVideoEvent());
          await pumpEventQueue();

          await relayController.close();

          _expectSingleCompletion(
            performanceMonitor,
            traceName: 'feed_load_search',
            completion: 'first_relay_event',
            eventCount: 1,
          );
        },
      );

      test('cancelled: the feed is unsubscribed mid-load', () async {
        withEmptyCache();

        await videoEventService
            .subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['a' * 64],
            )
            .timeout(const Duration(milliseconds: 100));

        await videoEventService.unsubscribeFromVideoFeed();

        _expectSingleCompletion(
          performanceMonitor,
          traceName: 'feed_load_profile',
          completion: 'cancelled',
          eventCount: 0,
        );
      });

      test('cancelled: the load is replaced by a newer one', () async {
        withEmptyCache();

        await videoEventService
            .subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['a' * 64],
            )
            .timeout(const Duration(milliseconds: 100));

        // Same type, different authors: replaces the in-flight load. Its trace
        // must close here rather than stay open until the app is torn down,
        // which is what made the abandoned sample session-length.
        await videoEventService
            .subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['b' * 64],
            )
            .timeout(const Duration(milliseconds: 100));

        // The replacement's trace is still running, so exactly one stop for
        // this name means the first load's — and only the first load's.
        _expectSingleCompletion(
          performanceMonitor,
          traceName: 'feed_load_profile',
          completion: 'cancelled',
          eventCount: 0,
        );
        expect(
          performanceMonitor.startedTraces
              .where((t) => t == 'feed_load_profile')
              .length,
          2,
        );
      });

      test('disposed: load abandoned before any completion path', () async {
        withEmptyCache();

        await videoEventService
            .subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['a' * 64],
            )
            .timeout(const Duration(milliseconds: 100));

        // Nothing arrives and the 30s fuse never fires: without the pending
        // registry this handle would stay open for the process lifetime.
        videoEventService.dispose();

        _expectSingleCompletion(
          performanceMonitor,
          traceName: 'feed_load_profile',
          completion: 'disposed',
          eventCount: 0,
        );
      });

      test(
        'disposed: load still mid-setup has no subscription to tear down',
        () async {
          // Hangs the cache read so the load is disposed before it ever
          // registers a stream subscription — the one abandoned load the
          // teardown sweep cannot see.
          final cacheRead = Completer<List<Event>>();
          when(
            () => mockNostrEventsDao.getEventsByFilter(
              any(),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer((_) => cacheRead.future);

          unawaited(
            videoEventService.subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['a' * 64],
            ),
          );
          await pumpEventQueue();

          videoEventService.dispose();

          _expectSingleCompletion(
            performanceMonitor,
            traceName: 'feed_load_profile',
            completion: 'disposed',
            eventCount: 0,
          );
        },
      );

      test(
        'disposed: does not re-complete a trace that already reported',
        () async {
          await videoEventService
              .subscribeToVideoFeed(
                subscriptionType: SubscriptionType.profile,
                authors: ['a' * 64],
              )
              .timeout(const Duration(milliseconds: 100));

          videoEventService.dispose();

          _expectSingleCompletion(
            performanceMonitor,
            traceName: 'feed_load_profile',
            completion: 'cache',
            eventCount: 1,
          );
        },
      );

      test(
        'disposed: cached events resolve after the service is gone',
        () async {
          // The cache read is the await a dispose races with. Resolving it
          // afterwards ran the cache-first notifyListeners on a dead
          // ChangeNotifier, which the load then swallowed as its own failure.
          final cacheRead = Completer<List<Event>>();
          when(
            () => mockNostrEventsDao.getEventsByFilter(
              any(),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer((_) => cacheRead.future);

          unawaited(
            videoEventService.subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['a' * 64],
            ),
          );
          await pumpEventQueue();

          videoEventService.dispose();
          cacheRead.complete([_cachedVideoEvent()]);
          await pumpEventQueue();

          expect(videoEventService.error, isNull);
          _expectSingleCompletion(
            performanceMonitor,
            traceName: 'feed_load_profile',
            completion: 'disposed',
            eventCount: 0,
          );
        },
      );

      test(
        'disposed: sorted load starts trace after dispose drain already ran',
        () async {
          final capabilitiesRead = Completer<RelayCapabilities>();
          when(
            () => mockRelayCapabilityService.getRelayCapabilities(any()),
          ).thenAnswer((_) => capabilitiesRead.future);
          withEmptyCache();

          final subscribe = videoEventService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.discovery,
            sortBy: VideoSortField.loopCount,
          );
          await pumpEventQueue();

          // The sorted filter is still awaiting NIP-11 capabilities, so the
          // trace has not been registered and dispose drains an empty map.
          videoEventService.dispose();
          capabilitiesRead.complete(
            RelayCapabilities(
              relayUrl: 'wss://relay.divine.video',
              rawData: const {},
            ),
          );
          await subscribe.timeout(const Duration(milliseconds: 100));

          _expectSingleCompletion(
            performanceMonitor,
            traceName: 'feed_load_discovery',
            completion: 'disposed',
            eventCount: 0,
          );
        },
      );

      test('setup_error: creating the relay subscription throws', () async {
        withEmptyCache();
        when(
          () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
        ).thenThrow(StateError('relay unavailable'));

        await videoEventService
            .subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['a' * 64],
            )
            .timeout(const Duration(milliseconds: 100));

        // Setup threw before anything was registered, so no teardown path can
        // reach this handle — the catch has to close it or it survives to
        // dispose and reports the session as the load's duration.
        _expectSingleCompletion(
          performanceMonitor,
          traceName: 'feed_load_profile',
          completion: 'setup_error',
          eventCount: 0,
        );
      });
    });
  });
}

Event _cachedVideoEvent() {
  final event = Event(
    'a' * 64,
    34236,
    const [
      ['url', 'https://example.com/cached-video.mp4'],
      ['m', 'video/mp4'],
      ['thumb', 'https://example.com/cached-thumb.jpg'],
      ['title', 'Cached video'],
    ],
    'cached content',
    createdAt: 1_700_000_000,
  );
  event.id = 'b' * 64;
  return event;
}

Event _relayVideoEvent() {
  final event = Event(
    'a' * 64,
    34236,
    const [
      ['url', 'https://example.com/relay-video.mp4'],
      ['m', 'video/mp4'],
      ['thumb', 'https://example.com/relay-thumb.jpg'],
      ['title', 'Relay video'],
    ],
    'relay content',
    createdAt: 1_700_000_001,
  );
  event.id = 'c' * 64;
  return event;
}
