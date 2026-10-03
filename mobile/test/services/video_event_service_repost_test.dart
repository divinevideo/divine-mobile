// ABOUTME: Tests VideoEventService wiring for Kind 16 generic reposts.
// ABOUTME: Covers opt-in filters, cached/query resolution, and hashtag filtering.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _authorPubkey =
    '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
const _reposterPubkey =
    'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
const _originalId =
    'aaaa567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
const _repostId =
    'bbbb567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
const _videoUrl = 'https://example.com/video.mp4';
const _dTag = 'original-video';

Event _originalEvent() {
  return Event(
    _authorPubkey,
    NIP71VideoKinds.addressableShortVideo,
    [
      ['d', _dTag],
      ['url', _videoUrl],
      ['m', 'video/mp4'],
      ['title', 'Original Video'],
      ['t', 'nostr'],
    ],
    'Original video content',
    createdAt: 1000,
  )..id = _originalId;
}

Event _repostEvent({bool addressable = false}) {
  return Event(
    _reposterPubkey,
    NIP71VideoKinds.repost,
    [
      ['k', '${NIP71VideoKinds.addressableShortVideo}'],
      if (addressable)
        ['a', '${NIP71VideoKinds.addressableShortVideo}:$_authorPubkey:$_dTag']
      else
        ['e', _originalId],
      ['p', _authorPubkey],
    ],
    '',
    createdAt: 2000,
  )..id = _repostId;
}

void _expectRepost(VideoEvent video) {
  expect(video.isRepost, isTrue);
  expect(video.reposterId, _repostId);
  expect(video.reposterPubkey, _reposterPubkey);
  expect(video.repostedAt, DateTime.fromMillisecondsSinceEpoch(2000000));
  expect(video.id, _originalId);
  expect(video.pubkey, _authorPubkey);
  expect(video.title, 'Original Video');
  expect(video.videoUrl, _videoUrl);
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(Duration.zero);
  });

  group('VideoEventService Kind 16 generic repost processing', () {
    late VideoEventService service;
    late _MockNostrClient client;
    late Map<SubscriptionType, StreamController<Event>> streams;
    late List<List<Filter>> subscriptionFilters;
    late List<List<Filter>> queryFilters;
    late List<Event> queryResults;

    setUp(() {
      client = _MockNostrClient();
      streams = {
        for (final type in SubscriptionType.values)
          type: StreamController<Event>.broadcast(),
      };
      subscriptionFilters = [];
      queryFilters = [];
      queryResults = [];
      when(() => client.isInitialized).thenReturn(true);
      when(() => client.connectedRelayCount).thenReturn(1);
      when(
        () => client.subscribe(
          any(),
          onEose: any(named: 'onEose'),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
        ),
      ).thenAnswer((invocation) {
        final filters = invocation.positionalArguments.first as List<Filter>;
        subscriptionFilters.add(filters);
        final type = filters.first.authors?.contains(_reposterPubkey) ?? false
            ? SubscriptionType.profile
            : SubscriptionType.discovery;
        return streams[type]!.stream;
      });
      when(
        () => client.queryEventsDetailed(
          any(),
          timeout: any(named: 'timeout'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer((invocation) async {
        queryFilters.add(invocation.positionalArguments.first as List<Filter>);
        return (events: queryResults, timedOut: false, noRelays: false);
      });
      service = VideoEventService(
        client,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() async {
      service.dispose();
      for (final stream in streams.values) {
        await stream.close();
      }
    });

    test('adds a separate Kind 16 filter when reposts are enabled', () async {
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        includeReposts: true,
      );

      final filters = subscriptionFilters.single;
      expect(filters, hasLength(2));
      expect(filters.first.kinds, NIP71VideoKinds.getAllVideoKinds());
      expect(filters.last.kinds, [NIP71VideoKinds.repost]);
    });

    test('omits the Kind 16 filter when reposts are disabled', () async {
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      final filters = subscriptionFilters.single;
      expect(filters, hasLength(1));
      expect(filters.single.kinds, NIP71VideoKinds.getAllVideoKinds());
      expect(filters.single.kinds, isNot(contains(NIP71VideoKinds.repost)));
    });

    test('drops delivered Kind 16 events when reposts are disabled', () async {
      queryResults = [_originalEvent()];
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      streams[SubscriptionType.discovery]!.add(_repostEvent());
      await pumpEventQueue();
      expect(queryFilters, isEmpty);
      expect(service.discoveryVideos, isEmpty);

      streams[SubscriptionType.discovery]!.add(_originalEvent());
      await pumpEventQueue();
      expect(service.discoveryVideos.single.id, _originalId);
      expect(service.discoveryVideos.single.isRepost, isFalse);
    });

    test('resolves an e-tag repost from another feed cache', () async {
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      streams[SubscriptionType.discovery]!.add(_originalEvent());
      await pumpEventQueue();
      expect(service.discoveryVideos.single.id, _originalId);

      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.profile,
        authors: [_reposterPubkey],
        includeReposts: true,
      );
      streams[SubscriptionType.profile]!.add(_repostEvent());
      await pumpEventQueue();

      _expectRepost(service.getVideos(SubscriptionType.profile).single);
      expect(queryFilters, isEmpty);
    });

    test('queries an uncached e-tag original and adds its repost', () async {
      queryResults = [_originalEvent()];
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        includeReposts: true,
      );
      streams[SubscriptionType.discovery]!.add(_repostEvent());
      await pumpEventQueue();

      _expectRepost(service.discoveryVideos.single);
      final filter = queryFilters.single.single;
      expect(filter.ids, [_originalId]);
      expect(filter.kinds, NIP71VideoKinds.getAllVideoKinds());
      expect(subscriptionFilters, hasLength(1));
    });

    test('keeps a queried repost matching the hashtag filter', () async {
      queryResults = [_originalEvent()];
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        hashtags: ['Nostr'],
        includeReposts: true,
      );
      streams[SubscriptionType.discovery]!.add(_repostEvent());
      await pumpEventQueue();

      expect(queryFilters, hasLength(1));
      _expectRepost(service.discoveryVideos.single);
      expect(service.discoveryVideos.single.hashtags, contains('nostr'));
    });

    test('rejects a queried repost with an unrelated hashtag', () async {
      queryResults = [_originalEvent()];
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        hashtags: ['bitcoin'],
        includeReposts: true,
      );
      streams[SubscriptionType.discovery]!.add(_repostEvent());
      await pumpEventQueue();

      expect(queryFilters.single.single.ids, [_originalId]);
      expect(service.discoveryVideos, isEmpty);
    });

    test(
      'resolves an a-tag addressable repost from another feed cache',
      () async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
        );
        streams[SubscriptionType.discovery]!.add(_originalEvent());
        await pumpEventQueue();
        expect(service.discoveryVideos.single.id, _originalId);

        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.profile,
          authors: [_reposterPubkey],
          includeReposts: true,
        );
        streams[SubscriptionType.profile]!.add(_repostEvent(addressable: true));
        await pumpEventQueue();

        _expectRepost(service.getVideos(SubscriptionType.profile).single);
        expect(queryFilters, isEmpty);
      },
    );
  });
}
