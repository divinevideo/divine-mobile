import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeConnectionStatusService extends ConnectionStatusService {
  bool online = true;

  @override
  bool get isOnline => online;

  @override
  bool get isConnected => online;

  @override
  Map<String, dynamic> getConnectionInfo() => {'isConnected': online};
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService Timeout Cleanup', () {
    late VideoEventService videoEventService;
    late _MockNostrClient mockNostrService;

    setUp(() {
      mockNostrService = _MockNostrClient();

      // Setup mock NostrService
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      // Ensure we return a stream that hangs (never emits) to simulate
      // timeout conditions. Stream.empty() closes immediately, triggering
      // onDone - we want it to HANG.
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((_) {
        final controller = StreamController<Event>();
        addTearDown(controller.close);
        return controller.stream;
      });

      videoEventService = VideoEventService(
        mockNostrService,
        crashReporter: const SilentCrashReporter(),
      );
    });

    test(
      'should clean up active subscription on timeout so retry is possible',
      () {
        bool wasCancelled = false;
        final controller = StreamController<Event>(
          onCancel: () {
            wasCancelled = true;
          },
        );
        addTearDown(controller.close);

        // Override mock to use our tracked controller
        when(
          () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
        ).thenAnswer((_) => controller.stream);

        fakeAsync((async) {
          // 1. Initial subscription
          videoEventService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.discovery,
          );

          async.flushMicrotasks();

          // Verify subscription started
          verify(
            () =>
                mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
          ).called(1);

          reset(mockNostrService);
          when(() => mockNostrService.isInitialized).thenReturn(true);
          when(() => mockNostrService.connectedRelayCount).thenReturn(1);
          when(
            () =>
                mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
          ).thenAnswer((_) {
            final c = StreamController<Event>();
            addTearDown(c.close);
            return c.stream;
          });

          expect(
            videoEventService.isSubscribed(SubscriptionType.discovery),
            isTrue,
            reason: 'Should be subscribed initially',
          );

          expect(
            videoEventService.isLoadingForSubscription(
              SubscriptionType.discovery,
            ),
            isTrue,
            reason: 'Should be loading initially',
          );

          // 2. Fast forward 30 seconds to trigger timeout
          async.elapse(const Duration(seconds: 31));

          // Verify that cleanup happened
          expect(
            videoEventService.isSubscribed(SubscriptionType.discovery),
            isFalse,
            reason: 'Should be unsubscribed after timeout cleanup',
          );

          // Verify loading state is reset
          expect(
            videoEventService.isLoadingForSubscription(
              SubscriptionType.discovery,
            ),
            isFalse,
            reason: 'Loading state should be reset after timeout',
          );

          // Verify subscription was cancelled (Fix #1 verification)
          expect(
            wasCancelled,
            isTrue,
            reason: 'StreamSubscription should be cancelled on timeout',
          );

          // 3. Try to subscribe again (simulate user coming back)
          videoEventService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.discovery,
          );

          async.flushMicrotasks();

          // 4. Verify that subscribe was called A SECOND TIME
          verify(
            () =>
                mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
          ).called(1);
        });
      },
    );
  });

  // A relay that answers with nothing at all used to be terminal: the timeout
  // dropped the stored filters and scheduled no retry, so the feed stayed empty
  // until the user navigated away and back (#7124).
  group('VideoEventService timeout recovery', () {
    const author =
        '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

    late VideoEventService service;
    late _MockNostrClient mockNostrService;
    late _FakeConnectionStatusService connectionService;
    late List<List<Filter>> subscribeCalls;
    late List<void Function()> eoseCallbacks;

    setUp(() {
      mockNostrService = _MockNostrClient();
      connectionService = _FakeConnectionStatusService();
      subscribeCalls = [];
      eoseCallbacks = [];

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((invocation) {
        subscribeCalls.add(
          (invocation.positionalArguments.first as List<Filter>).toList(),
        );
        final onEose = invocation.namedArguments[#onEose] as void Function()?;
        if (onEose != null) eoseCallbacks.add(onEose);
        // Never emits and never EOSEs: the relay that swallowed the REQ.
        final controller = StreamController<Event>(onCancel: () async {});
        addTearDown(controller.close);
        return controller.stream;
      });

      service = VideoEventService(
        mockNostrService,
        crashReporter: const SilentCrashReporter(),
        connectionService: connectionService,
      );
    });

    tearDown(() {
      service.dispose();
      connectionService.dispose();
    });

    test('re-issues the timed-out feed with its original filters', () {
      fakeAsync((fake) {
        unawaited(
          service.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.profile,
            authors: [author],
          ),
        );
        fake.flushMicrotasks();
        expect(subscribeCalls, hasLength(1));

        fake
          ..elapse(const Duration(seconds: 31))
          ..flushMicrotasks();
        expect(
          subscribeCalls,
          hasLength(1),
          reason: 'the timeout itself must not re-subscribe',
        );

        fake
          ..elapse(const Duration(seconds: 10))
          ..flushMicrotasks();

        expect(subscribeCalls, hasLength(2));
        expect(
          subscribeCalls.last.any(
            (filter) => filter.authors?.contains(author) ?? false,
          ),
          isTrue,
          reason:
              'the retry must re-establish the feed that timed out, which is '
              'only possible if the timeout kept its stored parameters',
        );
      });
    });

    test('gives up after the retry budget instead of re-issuing forever', () {
      fakeAsync((fake) {
        unawaited(
          service.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.profile,
            authors: [author],
          ),
        );
        fake.flushMicrotasks();

        for (var i = 0; i < 30; i++) {
          fake
            ..elapse(const Duration(seconds: 10))
            ..flushMicrotasks();
        }

        expect(
          subscribeCalls,
          hasLength(4),
          reason:
              'the initial load plus three retries. Issuing a REQ always '
              'succeeds, so the retry cycle re-arms its own budget on every '
              'attempt — without a cap on consecutive timeouts a silent relay '
              'is re-subscribed every ~40s for the life of the process',
        );
      });
    });

    test('a load the relay answers restores the retry budget', () {
      fakeAsync((fake) {
        unawaited(
          service.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.profile,
            authors: [author],
          ),
        );
        fake
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 41))
          ..flushMicrotasks();
        expect(subscribeCalls, hasLength(2));

        // The retry is served, so the feed is healthy again.
        eoseCallbacks.last();
        fake.flushMicrotasks();

        // A later load onto a relay that has gone silent again gets the whole
        // budget, not the remainder of the one that timed out before.
        final servedCalls = subscribeCalls.length;
        unawaited(
          service.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.profile,
            authors: [author],
            force: true,
          ),
        );
        fake.flushMicrotasks();
        for (var i = 0; i < 30; i++) {
          fake
            ..elapse(const Duration(seconds: 10))
            ..flushMicrotasks();
        }

        expect(
          subscribeCalls.length - servedCalls,
          4,
          reason: 'the second load plus a full three retries',
        );
      });
    });

    test('does not re-issue while the device is offline', () {
      fakeAsync((fake) {
        unawaited(
          service.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.profile,
            authors: [author],
          ),
        );
        fake
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 31))
          ..flushMicrotasks();

        connectionService.online = false;
        fake
          ..elapse(const Duration(seconds: 30))
          ..flushMicrotasks();
        expect(subscribeCalls, hasLength(1));

        connectionService.online = true;
        fake
          ..elapse(const Duration(seconds: 10))
          ..flushMicrotasks();
        expect(subscribeCalls, hasLength(2));
      });
    });

    test('notifies listeners when the load times out', () {
      fakeAsync((fake) {
        unawaited(
          service.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.profile,
            authors: [author],
          ),
        );
        fake.flushMicrotasks();

        var notifications = 0;
        void onChange() => notifications++;
        service.addListener(onChange);
        addTearDown(() => service.removeListener(onChange));

        fake
          ..elapse(const Duration(seconds: 31))
          ..flushMicrotasks();

        expect(
          notifications,
          greaterThan(0),
          reason:
              'every other completion path notifies; without this the loading '
              'state flips with nothing re-reading it',
        );
      });
    });

    test(
      'cancelling before the fuse expires does not resubscribe or unmap a '
      'replacement',
      () {
        fakeAsync((fake) {
          const authorB =
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

          unawaited(
            service.subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: [author],
            ),
          );
          fake.flushMicrotasks();
          expect(subscribeCalls, hasLength(1));

          // User leaves / replaces the feed well inside the 30s window.
          unawaited(
            service.subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: [authorB],
              force: true,
            ),
          );
          fake.flushMicrotasks();
          expect(subscribeCalls, hasLength(2));
          expect(service.isSubscribed(SubscriptionType.profile), isTrue);

          // Stay inside B's fuse so only a leaked A fuse could fire recovery.
          fake
            ..elapse(const Duration(seconds: 29))
            ..flushMicrotasks();

          expect(
            subscribeCalls,
            hasLength(2),
            reason:
                "A's cancelled fuse must not schedule a retry after replace",
          );
          expect(
            service.isSubscribed(SubscriptionType.profile),
            isTrue,
            reason: "A's cancelled fuse must not unmap B's live subscription",
          );
          expect(
            subscribeCalls.last.any(
              (filter) => filter.authors?.contains(authorB) ?? false,
            ),
            isTrue,
          );
        });
      },
    );

    test(
      'an explicit subscribe after give-up re-arms the timeout retry budget',
      () {
        fakeAsync((fake) {
          unawaited(
            service.subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: [author],
            ),
          );
          fake.flushMicrotasks();

          // Exhaust the consecutive-timeout budget (initial + 3 retries).
          for (var i = 0; i < 30; i++) {
            fake
              ..elapse(const Duration(seconds: 10))
              ..flushMicrotasks();
          }
          expect(subscribeCalls, hasLength(4));

          // User comes back with an explicit subscribe — must not stay latched.
          unawaited(
            service.subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: [author],
              force: true,
            ),
          );
          fake.flushMicrotasks();
          final afterExplicit = subscribeCalls.length;

          for (var i = 0; i < 30; i++) {
            fake
              ..elapse(const Duration(seconds: 10))
              ..flushMicrotasks();
          }

          expect(
            subscribeCalls.length - afterExplicit,
            3,
            reason:
                'explicit subscribe clears the latch so the new load gets a '
                'full three retries again',
          );
        });
      },
    );
  });
}
