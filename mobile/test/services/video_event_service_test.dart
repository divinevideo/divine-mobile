// ABOUTME: Compatibility contract for the VideoEventService feed facade.
// ABOUTME: Locks observable behavior that must survive responsibility extraction.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late List<void Function()?> onEoseCallbacks;

  setUp(() {
    nostrClient = _MockNostrClient();
    requestedFilters = [];
    subscriptions = [];
    onEoseCallbacks = [];

    when(() => nostrClient.isInitialized).thenReturn(true);
    when(() => nostrClient.publicKey).thenReturn('');
    when(() => nostrClient.connectedRelayCount).thenReturn(1);
    when(() => nostrClient.subscribe(any(), onEose: any(named: 'onEose')))
        .thenAnswer((invocation) {
          requestedFilters.add(
            invocation.positionalArguments.single as List<Filter>,
          );
          onEoseCallbacks.add(
            invocation.namedArguments[#onEose] as void Function()?,
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
    // Unsubscribe before closing controllers so onDone can't arm a 5s
    // reconnection Timer that leaks into later suites in the merged VGV
    // isolate. Mirrors video_event_service_deduplication_test.dart.
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

    test(
      'pagination keeps the oldest timestamp and page-size contract',
      () async {
        // Drives pagination through subscribe + EOSE rather than
        // PaginationState's own methods (isolated coverage for those lives
        // in video_event_service_pagination_state_test.dart).
        const limit = 5;
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: limit,
        );

        // Out-of-order arrival: only a real running-min tracker gets
        // oldestTimestamp right below, not a hardcoded value.
        subscriptions.single
          ..add(_relayVideoEvent(0, createdAt: 300))
          ..add(_relayVideoEvent(1, createdAt: 100))
          ..add(_relayVideoEvent(2, createdAt: 200));
        await Future<void>.delayed(Duration.zero);

        onEoseCallbacks.single!();
        await Future<void>.delayed(Duration.zero);

        final state = service
            .getPaginationStatesForTesting()[SubscriptionType.discovery]!;

        expect(state.oldestTimestamp, 100);
        expect(state.eventsReceivedInCurrentQuery, 3);
        expect(state.hasMore, isFalse);
        expect(state.isLoading, isFalse);
      },
    );

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
            _video(
              type.name,
              createdAt: index + 1,
              hashtags: type == SubscriptionType.hashtag
                  ? const ['vine']
                  : const [],
            ),
            type,
            isHistorical: false,
          );
        }

        // Discovery's classic-vine branch is otherwise uncovered. createdAt
        // is set above the loop's values so the equal-engagement tiebreak
        // (newest createdAt first) sorts this one first, deterministically.
        service.addVideoEventForTesting(
          _video(
            'classic-vine',
            createdAt: 99,
            pubkey: AppConstants.classicVinesPubkey,
          ),
          SubscriptionType.discovery,
          isHistorical: false,
        );

        for (final type in feedTypes) {
          final expectedIds = type == SubscriptionType.discovery
              ? ['classic-vine', type.name]
              : [type.name];
          expect(
            service.getVideos(type).map((video) => video.id),
            expectedIds,
            reason: '${type.name} consumers must only observe their own feed',
          );
        }

        // getVideos(hashtag) reads a different, generic list; real
        // hashtag routes read the tag-keyed bucket via hashtagVideos().
        expect(
          service.hashtagVideos('vine').map((video) => video.id),
          ['hashtag'],
          reason: 'hashtag-route consumers must read from the tag bucket',
        );
      },
    );

    test(
      'filtering removes hidden videos and preserves accepted feed order',
      () async {
        // filterVideoList's hide/warn decision only runs with a real
        // ContentFilterService attached; unset, it's a no-op passthrough.
        SharedPreferences.setMockInitialValues({});
        final contentFilterService = ContentFilterService(
          ageVerificationService: AgeVerificationService(
            preferences: await SharedPreferences.getInstance(),
          ),
        );
        await contentFilterService.initialize();
        service.setContentFilterService(contentFilterService);

        final videos = [
          _video('newest', createdAt: 300),
          _video(
            'hidden',
            createdAt: 250,
            contentWarningLabels: const ['violence'],
          ),
          _video('middle', createdAt: 200),
          _video('oldest', createdAt: 100),
        ];

        final filtered = service.filterVideoList(videos);

        expect(filtered.map((video) => video.id), [
          'newest',
          'middle',
          'oldest',
        ]);
      },
    );

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

VideoEvent _video(
  String id, {
  required int createdAt,
  String? pubkey,
  List<String> contentWarningLabels = const [],
  List<String> hashtags = const [],
}) => VideoEvent(
  id: id,
  pubkey: pubkey ?? 'pubkey-$id',
  createdAt: createdAt,
  content: id,
  timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
  videoUrl: 'https://media.example.com/$id.mp4',
  contentWarningLabels: contentWarningLabels,
  hashtags: hashtags,
);

/// A minimal, valid NIP-71 kind-34236 relay event — enough for
/// VideoEvent.fromNostrEvent to parse a usable video URL, matching the
/// shape proven in video_event_service_initial_page_pagination_test.dart.
Event _relayVideoEvent(int index, {required int createdAt}) {
  final event = Event(
    'f' * 64,
    34236,
    [
      ['url', 'https://media.example.com/relay-$index.mp4'],
      ['m', 'video/mp4'],
    ],
    'relay video $index',
    createdAt: createdAt,
  );
  event.id = index.toRadixString(16).padLeft(64, '0');
  event.sig = 'f' * 128;
  event.sources.add('wss://relay.example.com');
  return event;
}
