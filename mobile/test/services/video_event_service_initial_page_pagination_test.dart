// ABOUTME: Pins that an initial subscription's pre-EOSE events count toward
// ABOUTME: pagination, so a full first page does not report the feed exhausted.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _author =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

Event _videoEvent(int index) {
  final event = Event(
    _author,
    34236,
    [
      ['url', 'https://media.example.com/$index.mp4'],
      ['m', 'video/mp4'],
    ],
    'video $index',
    createdAt: 1700000000 - index,
  );
  event.id = index.toRadixString(16).padLeft(64, '0');
  event.sig = 'f' * 128;
  event.sources.add('wss://relay.example.com');
  return event;
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService initial-page pagination', () {
    late VideoEventService videoEventService;
    late _MockNostrClient mockNostrService;

    setUp(() {
      mockNostrService = _MockNostrClient();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.publicKey).thenReturn('');
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.configuredRelays,
      ).thenReturn(['wss://relay.example.com']);
      when(
        () => mockNostrService.connectedRelays,
      ).thenReturn(['wss://relay.example.com']);
      when(
        () => mockNostrService.queryEvents(any()),
      ).thenAnswer((_) async => <Event>[]);
      when(mockNostrService.getRelayStats).thenAnswer((_) async => null);

      videoEventService = VideoEventService(
        mockNostrService,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() {
      videoEventService.dispose();
    });

    Future<PaginationState> subscribeThroughEose({
      required int eventCount,
      required int limit,
    }) async {
      void Function()? capturedOnEose;
      final controller = StreamController<Event>();
      addTearDown(controller.close);

      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((invocation) {
        capturedOnEose = invocation.namedArguments[#onEose] as void Function()?;
        return controller.stream;
      });

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.profile,
        authors: [_author],
        limit: limit,
      );

      for (var i = 0; i < eventCount; i++) {
        controller.add(_videoEvent(i));
      }
      await Future<void>.delayed(Duration.zero);

      expect(capturedOnEose, isNotNull, reason: 'onEose should be set');
      capturedOnEose!();
      await Future<void>.delayed(Duration.zero);

      return videoEventService
          .getPaginationStatesForTesting()[SubscriptionType.profile]!;
    }

    test('keeps hasMore when a full first page arrives before EOSE', () async {
      // The initial subscription delivers stored events through the real-time
      // handler, so the `isHistorical` counter — which only the load-more path
      // drives — stays at zero. Before the fix, completeQuery read that zero
      // and set hasMore=false however many events had actually landed.
      //
      // Runs on the real event loop rather than under fakeAsync: the subscribe
      // future outlives a fake zone, and its continuation then schedules a real
      // timer that strands whichever widget test runs next in CI's merged
      // isolate.
      const limit = 5;
      final state = await subscribeThroughEose(eventCount: limit, limit: limit);

      expect(
        state.eventsReceivedInCurrentQuery,
        greaterThanOrEqualTo(limit),
        reason:
            'the tally must reflect the events that actually arrived before '
            'EOSE, not the load-more-only isHistorical count',
      );
      expect(
        state.hasMore,
        isTrue,
        reason:
            'a first page that filled the requested limit cannot prove the '
            'feed is exhausted',
      );
    });

    test('clears stale query state before counting a first page', () async {
      const limit = 5;
      final stateBeforeSubscribe = videoEventService
          .getPaginationStatesForTesting()[SubscriptionType.profile]!;
      stateBeforeSubscribe.eventsReceivedInCurrentQuery = 500;
      stateBeforeSubscribe.hasMore = false;

      final state = await subscribeThroughEose(eventCount: limit, limit: limit);

      expect(state.eventsReceivedInCurrentQuery, equals(limit));
      expect(
        state.hasMore,
        isTrue,
        reason:
            'a fresh first-page subscription must not inherit the previous '
            'profile query count or exhausted flag',
      );
    });

    test(
      'marks hasMore false when a short first page arrives before EOSE',
      () async {
        final state = await subscribeThroughEose(eventCount: 3, limit: 5);

        expect(state.eventsReceivedInCurrentQuery, equals(3));
        expect(
          state.hasMore,
          isFalse,
          reason:
              'a first page shorter than the requested limit still indicates '
              'the feed is exhausted',
        );
      },
    );
  });
}
