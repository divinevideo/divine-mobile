// ABOUTME: Compatibility contract for the VideoEventService feed facade.
// ABOUTME: Locks observable behavior that must survive responsibility extraction.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

class _FakeFilter extends Fake implements Filter {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[_FakeFilter()]);
  });

  late _MockNostrClient nostrClient;
  late VideoEventService service;
  late List<List<Filter>> requestedFilters;
  late List<StreamController<Event>> subscriptions;

  setUp(() {
    nostrClient = _MockNostrClient();
    requestedFilters = [];
    subscriptions = [];

    when(() => nostrClient.isInitialized).thenReturn(true);
    when(() => nostrClient.publicKey).thenReturn('');
    when(() => nostrClient.connectedRelayCount).thenReturn(1);
    when(() => nostrClient.subscribe(any(), onEose: any(named: 'onEose')))
        .thenAnswer((invocation) {
          requestedFilters.add(
            invocation.positionalArguments.single as List<Filter>,
          );
          final controller = StreamController<Event>.broadcast();
          subscriptions.add(controller);
          return controller.stream;
        });

    service = VideoEventService(
      nostrClient,
      subscriptionManager: _MockSubscriptionManager(),
      crashReporter: const SilentCrashReporter(),
    );
  });

  tearDown(() async {
    // Cancel subscriptions and clear params BEFORE closing the controllers,
    // so onDone never fires on a still-registered listener and no 5s
    // reconnection Timer leaks into later suites in the merged VGV isolate.
    // Mirrors video_event_service_deduplication_test.dart.
    await service.unsubscribeFromVideoFeed();
    service.dispose();
    for (final subscription in subscriptions) {
      await subscription.close();
    }
  });

  group('feed facade compatibility', () {
    test(
      'reuses identical subscriptions and replaces changed filters',
      () async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.homeFeed,
          authors: const ['author-a'],
          limit: 20,
        );
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.homeFeed,
          authors: const ['author-a'],
          limit: 20,
        );
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.homeFeed,
          authors: const ['author-b'],
          limit: 20,
        );

        expect(requestedFilters, hasLength(2));
        // everyElement passes vacuously on an empty list, so the length
        // check on each call's filter set is what actually proves a filter
        // (e.g. the kind-5 deletion filter) was not silently dropped.
        expect(requestedFilters[0], hasLength(2));
        expect(
          requestedFilters[0].map((filter) => filter.authors),
          everyElement(['author-a']),
        );
        expect(
          requestedFilters[0].map((filter) => filter.limit),
          everyElement(20),
        );
        expect(requestedFilters[1], hasLength(2));
        expect(
          requestedFilters[1].map((filter) => filter.authors),
          everyElement(['author-b']),
        );
        expect(
          requestedFilters[1].map((filter) => filter.limit),
          everyElement(20),
        );
      },
    );

    test('pagination keeps the oldest timestamp and page-size contract', () {
      final state = service
          .getPaginationStatesForTesting()[SubscriptionType.discovery]!;

      state
        ..startQuery()
        ..updateOldestTimestamp(300)
        ..updateOldestTimestamp(100)
        ..updateOldestTimestamp(200)
        ..recordReceivedCount(3)
        ..completeQuery(5);

      expect(state.oldestTimestamp, 100);
      expect(state.eventsReceivedInCurrentQuery, 3);
      expect(state.hasMore, isFalse);
      expect(state.isLoading, isFalse);
    });

    test(
      'keeps home, explore, profile, hashtag, and search feeds isolated',
      () {
        const feedTypes = [
          SubscriptionType.homeFeed,
          SubscriptionType.discovery,
          SubscriptionType.profile,
          SubscriptionType.hashtag,
          SubscriptionType.search,
        ];

        for (final (index, type) in feedTypes.indexed) {
          service.addVideoEventForTesting(
            _video(type.name, createdAt: index + 1),
            type,
            isHistorical: false,
          );
        }

        for (final type in feedTypes) {
          expect(service.getVideos(type).map((video) => video.id), [
            type.name,
          ], reason: '${type.name} consumers must only observe their own feed');
        }
      },
    );

    test('filtering preserves accepted feed order', () {
      final videos = [
        _video('newest', createdAt: 300),
        _video('middle', createdAt: 200),
        _video('oldest', createdAt: 100),
      ];

      final filtered = service.filterVideoList(videos);

      expect(filtered.map((video) => video.id), ['newest', 'middle', 'oldest']);
    });

    test('batches synchronous feed additions into one notification', () async {
      var notifications = 0;
      service.addListener(() => notifications++);

      service
        ..addVideoEvent(_video('first', createdAt: 100))
        ..addVideoEvent(_video('second', createdAt: 200));
      await pumpEventQueue();

      expect(notifications, 1);
    });
  });
}

VideoEvent _video(String id, {required int createdAt}) => VideoEvent(
  id: id,
  pubkey: 'pubkey-$id',
  createdAt: createdAt,
  content: id,
  timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
  videoUrl: 'https://media.example.com/$id.mp4',
);
