// ABOUTME: Tests for the online-retry cycle after subscription errors
// ABOUTME: Retries must re-establish the FAILED feed, not hardcode discovery

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockPerformanceTraceMonitor extends Mock
    implements PerformanceTraceMonitor {}

class _FakeFilter extends Fake implements Filter {}

class _FakeConnectionStatusService extends ConnectionStatusService {
  bool online = true;
  final List<bool> onlineReads = [];

  @override
  bool get isOnline =>
      onlineReads.isNotEmpty ? onlineReads.removeAt(0) : online;

  @override
  bool get isConnected => online;

  @override
  Map<String, dynamic> getConnectionInfo() => {
    'isConnected': online,
    'scriptedReads': onlineReads.length,
  };
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Filter>[]);
  });

  group('online retry after subscription error', () {
    const followedAuthor =
        '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

    late _MockNostrClient mockNostrService;
    late _MockPerformanceTraceMonitor mockPerformanceMonitor;
    late _FakeConnectionStatusService connectionService;
    late VideoEventService service;
    late List<List<Filter>> subscribeCalls;
    late List<StreamController<Event>> streamControllers;
    late StreamController<Map<String, RelayConnectionStatus>>
    relayStatusController;
    late int connectedRelayCount;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockPerformanceMonitor = _MockPerformanceTraceMonitor();
      connectionService = _FakeConnectionStatusService();
      subscribeCalls = [];
      streamControllers = [];
      relayStatusController = StreamController.broadcast();
      connectedRelayCount = 1;

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.publicKey).thenReturn('');
      when(
        () => mockNostrService.connectedRelayCount,
      ).thenAnswer((_) => connectedRelayCount);
      when(
        () => mockNostrService.relayStatusStream,
      ).thenAnswer((_) => relayStatusController.stream);
      when(
        () => mockNostrService.retryDisconnectedRelays(),
      ).thenAnswer((_) async {});
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((invocation) {
        subscribeCalls.add(
          (invocation.positionalArguments.first as List<Filter>).toList(),
        );
        // Single-subscription controller with an async onCancel: broadcast
        // subscriptions' cancel() futures cannot be driven by fakeAsync
        // (the service awaits cancel() when force-replacing), so the test
        // would hang at that await with a broadcast controller.
        final controller = StreamController<Event>(onCancel: () async {});
        streamControllers.add(controller);
        return controller.stream;
      });
      when(() => mockNostrService.unsubscribe(any())).thenAnswer((_) async {});

      when(
        () => mockPerformanceMonitor.startOperationTrace(any()),
      ).thenReturn(const NoOpPerformanceTraceMonitor().startOperationTrace(''));

      service = VideoEventService(
        mockNostrService,
        crashReporter: const SilentCrashReporter(),
        performanceMonitor: mockPerformanceMonitor,
        connectionService: connectionService,
      );
    });

    tearDown(() {
      service.dispose();
      unawaited(relayStatusController.close());
      connectionService.dispose();
    });

    test('connection error on home feed retries the home feed with its '
        'original authors', () {
      fakeAsync((fake) {
        unawaited(
          service.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.homeFeed,
            authors: [followedAuthor],
          ),
        );
        fake.flushMicrotasks();
        expect(subscribeCalls, hasLength(1));

        // Relay connection drops — the subscription stream errors out.
        streamControllers.first.addError(
          Exception('websocket connection failed'),
        );
        fake.flushMicrotasks();

        // First retry tick.
        fake
          ..elapse(const Duration(seconds: 10))
          ..flushMicrotasks();

        expect(
          subscribeCalls,
          hasLength(2),
          reason: 'the retry cycle must re-issue a relay subscription',
        );
        final retryFilters = subscribeCalls[1];
        expect(
          retryFilters.any(
            (filter) => filter.authors?.contains(followedAuthor) ?? false,
          ),
          isTrue,
          reason:
              'the retry must re-establish the FAILED home feed with its '
              'original authors, not a parameterless discovery feed',
        );

        // The successful retry ends the cycle — no further re-subscribes.
        fake
          ..elapse(const Duration(seconds: 30))
          ..flushMicrotasks();
        expect(subscribeCalls, hasLength(2));
      });
    });

    test('first subscribe while offline retries with the original authors', () {
      fakeAsync((fake) {
        connectionService.online = false;
        Object? caughtError;

        unawaited(
          service
              .subscribeToVideoFeed(
                subscriptionType: SubscriptionType.homeFeed,
                authors: [followedAuthor],
              )
              .catchError((Object error) {
                caughtError = error;
              }),
        );
        fake.flushMicrotasks();

        expect(caughtError, isA<VideoEventServiceException>());
        expect(subscribeCalls, isEmpty);

        connectionService.online = true;
        fake
          ..elapse(const Duration(seconds: 10))
          ..flushMicrotasks();

        expect(subscribeCalls, hasLength(1));
        expect(
          subscribeCalls.single.any(
            (filter) => filter.authors?.contains(followedAuthor) ?? false,
          ),
          isTrue,
        );
      });
    });

    test('first subscribe with zero relays retries after relay reconnect with '
        'the original authors', () {
      fakeAsync((fake) {
        connectedRelayCount = 0;
        Object? caughtError;

        unawaited(
          service
              .subscribeToVideoFeed(
                subscriptionType: SubscriptionType.profile,
                authors: [followedAuthor],
              )
              .catchError((Object error) {
                caughtError = error;
              }),
        );
        fake.flushMicrotasks();

        expect(caughtError, isA<RelayNotReadyException>());
        expect(subscribeCalls, isEmpty);

        relayStatusController.add({
          'wss://relay.divine.video': RelayConnectionStatus.disconnected(
            'wss://relay.divine.video',
          ),
        });
        fake.flushMicrotasks();
        expect(subscribeCalls, isEmpty);

        connectedRelayCount = 1;
        relayStatusController.add({
          'wss://relay.divine.video': RelayConnectionStatus.connected(
            'wss://relay.divine.video',
          ),
        });
        fake.flushMicrotasks();

        expect(subscribeCalls, hasLength(1));
        expect(
          subscribeCalls.single.any(
            (filter) => filter.authors?.contains(followedAuthor) ?? false,
          ),
          isTrue,
        );

        relayStatusController.add({
          'wss://relay.divine.video': RelayConnectionStatus.connected(
            'wss://relay.divine.video',
          ),
        });
        fake.flushMicrotasks();

        expect(
          subscribeCalls,
          hasLength(1),
          reason: 'relay-ready retry must cancel after a successful retry',
        );
      });
    });

    test('relay-ready retry preserves each pending subscription params without '
        'creating a retry storm', () {
      fakeAsync((fake) {
        connectedRelayCount = 0;

        unawaited(
          service
              .subscribeToVideoFeed(
                subscriptionType: SubscriptionType.profile,
                authors: [followedAuthor],
              )
              .catchError((_) {}),
        );
        unawaited(
          service
              .subscribeToVideoFeed(
                subscriptionType: SubscriptionType.hashtag,
                hashtags: const ['Fresh'],
              )
              .catchError((_) {}),
        );
        fake.flushMicrotasks();

        expect(subscribeCalls, isEmpty);

        connectedRelayCount = 1;
        relayStatusController.add({
          'wss://relay.divine.video': RelayConnectionStatus.connected(
            'wss://relay.divine.video',
          ),
        });
        fake.flushMicrotasks();

        expect(subscribeCalls, hasLength(2));
        expect(
          subscribeCalls.any(
            (filters) => filters.any(
              (filter) => filter.authors?.contains(followedAuthor) ?? false,
            ),
          ),
          isTrue,
        );
        expect(
          subscribeCalls.any(
            (filters) =>
                filters.any((filter) => filter.t?.contains('fresh') ?? false),
          ),
          isTrue,
        );

        relayStatusController.add({
          'wss://relay.divine.video': RelayConnectionStatus.connected(
            'wss://relay.divine.video',
          ),
        });
        fake.flushMicrotasks();

        expect(subscribeCalls, hasLength(2));
      });
    });

    test('online retry waits for relay-ready retry when relays are down', () {
      fakeAsync((fake) {
        unawaited(
          service.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.homeFeed,
            authors: [followedAuthor],
          ),
        );
        fake.flushMicrotasks();
        expect(subscribeCalls, hasLength(1));

        streamControllers.first.addError(
          Exception('websocket connection failed'),
        );
        fake.flushMicrotasks();

        connectedRelayCount = 0;
        fake
          ..elapse(const Duration(seconds: 10))
          ..flushMicrotasks();

        expect(
          subscribeCalls,
          hasLength(1),
          reason:
              'online retry must not create a relay REQ while relays are down',
        );

        fake
          ..elapse(const Duration(seconds: 30))
          ..flushMicrotasks();
        expect(
          subscribeCalls,
          hasLength(1),
          reason:
              'RelayNotReadyException should hand off to relay-ready retry '
              'instead of burning the online retry budget',
        );

        connectedRelayCount = 1;
        relayStatusController.add({
          'wss://relay.divine.video': RelayConnectionStatus.connected(
            'wss://relay.divine.video',
          ),
        });
        fake.flushMicrotasks();

        expect(subscribeCalls, hasLength(2));
        expect(
          subscribeCalls.last.any(
            (filter) => filter.authors?.contains(followedAuthor) ?? false,
          ),
          isTrue,
          reason: subscribeCalls.last
              .map((filter) => filter.toJson())
              .toList()
              .toString(),
        );
      });
    });

    test('exhausted retry entries do not leak into a later retry cycle', () {
      fakeAsync((fake) {
        unawaited(
          service.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.homeFeed,
            authors: [followedAuthor],
          ),
        );
        fake.flushMicrotasks();
        expect(subscribeCalls, hasLength(1));

        streamControllers.first.addError(
          Exception('websocket connection failed'),
        );
        fake.flushMicrotasks();

        connectionService.onlineReads.addAll([
          true,
          false,
          true,
          false,
          true,
          false,
        ]);

        for (var i = 0; i < 3; i++) {
          fake
            ..elapse(const Duration(seconds: 10))
            ..flushMicrotasks();
        }

        expect(
          subscribeCalls,
          hasLength(1),
          reason: 'offline retry attempts throw before creating relay REQs',
        );

        unawaited(
          service.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.hashtag,
            hashtags: const ['Fresh'],
          ),
        );
        fake.flushMicrotasks();
        expect(subscribeCalls, hasLength(2));

        streamControllers.last.addError(Exception('network disconnected'));
        fake.flushMicrotasks();

        connectionService.online = true;
        fake
          ..elapse(const Duration(seconds: 10))
          ..flushMicrotasks();

        final laterRetryCalls = subscribeCalls.skip(2).toList();
        expect(
          laterRetryCalls.any(
            (filters) =>
                filters.any((filter) => filter.t?.contains('fresh') ?? false),
          ),
          isTrue,
        );
        expect(
          laterRetryCalls.any(
            (filters) => filters.any(
              (filter) => filter.authors?.contains(followedAuthor) ?? false,
            ),
          ),
          isFalse,
          reason:
              'the exhausted home-feed retry must not leak into the later '
              'hashtag retry cycle',
        );
      });
    });
  });
}
