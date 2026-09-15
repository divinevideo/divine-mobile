// ABOUTME: Regression test for the subscribeToVideoFeed check-then-act race
// ABOUTME: Concurrent identical subscribes must produce exactly one relay REQ

import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/event_router.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockNostrEventsDao extends Mock implements NostrEventsDao {}

class _FakeFilter extends Fake implements Filter {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(<Event>[]);
  });

  group('subscribeToVideoFeed concurrency', () {
    late _MockNostrClient mockNostrService;
    late _MockAppDatabase mockDatabase;
    late _MockNostrEventsDao mockNostrEventsDao;
    late VideoEventService service;

    /// Parks *every* cached-events read until the test releases it, so the
    /// caller that claimed the subscription id is guaranteed to sit inside its
    /// async gap while the next call races through. This is the only `await`
    /// between the synchronous claim and the relay `subscribe`, so it is the
    /// seam that opens the window under test.
    ///
    /// Gating every read rather than only the first: a counted gate silently
    /// stops parking anyone if some other reader reaches the DAO first, and
    /// the test then degenerates into two sequential subscribes that pass for
    /// the wrong reason. A caller that is supposed to return at the claim
    /// check never reaches this stub at all.
    late Completer<List<Event>> cacheReadGate;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockDatabase = _MockAppDatabase();
      mockNostrEventsDao = _MockNostrEventsDao();
      cacheReadGate = Completer<List<Event>>();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.publicKey).thenReturn('');
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((_) => StreamController<Event>.broadcast().stream);

      when(() => mockDatabase.nostrEventsDao).thenReturn(mockNostrEventsDao);
      when(
        () => mockNostrEventsDao.upsertEventsBatch(
          any(),
          expireAt: any(named: 'expireAt'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockNostrEventsDao.getEventsByFilter(
          any(),
          sortBy: any(named: 'sortBy'),
        ),
      ).thenAnswer((_) => cacheReadGate.future);

      service = VideoEventService(
        mockNostrService,
        crashReporter: const SilentCrashReporter(),
        eventRouter: EventRouter(mockDatabase),
      );
    });

    tearDown(() {
      service.dispose();
    });

    test(
      'concurrent identical subscribes create exactly one relay subscription',
      () async {
        // First call claims the id, then parks on the cached-events read.
        final first = service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 10,
        );

        // Pin the seam itself: the first call must still be inside its async
        // gap. If it ever ran to completion here the two calls would be
        // sequential, and a green result would say nothing about the race.
        verifyNever(
          () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
        );

        // Second identical call races through while the first is parked, and
        // must reuse the pending claim rather than open a second REQ.
        await _expectReusesClaim(
          service.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.discovery,
            limit: 10,
          ),
        );

        cacheReadGate.complete([]);
        await first;

        verify(
          () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
        ).called(1);
      },
    );

    test('pending reuse does not block retry if first setup fails', () async {
      // The first call's relay subscribe throws, so its `catch` must release
      // the pending claim; otherwise the id stays claimed forever and every
      // later attempt is silently swallowed as a duplicate.
      var subscribeCalls = 0;
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((_) {
        subscribeCalls++;
        if (subscribeCalls == 1) throw StateError('relay subscribe failed');
        return StreamController<Event>.broadcast().stream;
      });

      final first = service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 10,
      );

      // Races in while the first is parked: reuses the claim, no REQ.
      await _expectReusesClaim(
        service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 10,
        ),
      );

      cacheReadGate.complete([]);
      await first;

      // The claim is released, so this retry gets through to the relay.
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 10,
      );

      // Twice: the throwing first attempt plus the successful retry. The
      // racing second call contributed none.
      expect(subscribeCalls, 2);
    });
  });
}

/// Awaits a subscribe that is expected to return at the pending-claim check.
///
/// Such a call never reaches the gated cached-events read, so it completes
/// promptly. One that regresses past the claim parks on the gate forever;
/// bound it here so the failure names the broken invariant instead of
/// surfacing as an unexplained suite timeout.
Future<void> _expectReusesClaim(Future<void> subscribe) => subscribe.timeout(
  const Duration(seconds: 5),
  onTimeout: () => fail(
    'subscribe reached the cached-events read instead of reusing the '
    'pending claim',
  ),
);
