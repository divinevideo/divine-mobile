// TDD: client-side seen-video filtering across feeds
// Covers: home (following) demotes, new stays chronological (including cache
// hits, relay fallback, and page boundaries), classic drops + deep-fetch,
// profile untouched, deep-fetch triggers when filtering removes most of page.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/videos_repository.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {
  // A live client reports false; an unstubbed mock getter would return null.
  @override
  bool isDisposed = false;
}

class StubRandom implements Random {
  StubRandom({int? offsetPage}) : _offsetPage = offsetPage;
  int? _offsetPage;
  final Random _inner = Random(0);
  @override
  int nextInt(int max) {
    if (_offsetPage != null) {
      final v = _offsetPage!;
      _offsetPage = null;
      return v % max;
    }
    return _inner.nextInt(max);
  }

  @override
  bool nextBool() => _inner.nextBool();
  @override
  double nextDouble() => _inner.nextDouble();
}

VideoStats _stats(
  String id, {
  String? pubkey,
  int? createdAt,
  String? platform,
}) => VideoStats(
  rawTags: platform != null ? {'platform': platform} : const {},
  id: id,
  pubkey: pubkey ?? 'pubkey-$id',
  createdAt: DateTime.fromMillisecondsSinceEpoch(
    (createdAt ?? 1704067200) * 1000,
  ),
  kind: EventKind.videoVertical,
  dTag: 'dtag-$id',
  title: 'Test',
  thumbnail: 'https://example.com/thumb.jpg',
  videoUrl: 'https://example.com/$id.mp4',
  reactions: 0,
  comments: 0,
  reposts: 0,
  engagementScore: 0,
);

Event _event(
  String id, {
  String pubkey = 'author',
  int createdAt = 1704067200,
}) {
  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': EventKind.videoVertical,
    'tags': [
      ['url', 'https://example.com/$id.mp4'],
      ['d', 'd-$id'],
    ],
    'content': '',
    'sig': '',
  });
}

void main() {
  late MockNostrClient mockNostr;
  late MockFunnelcakeApiClient mockFunnelcake;

  setUp(() {
    mockNostr = MockNostrClient();
    mockFunnelcake = MockFunnelcakeApiClient();
    when(() => mockFunnelcake.isAvailable).thenReturn(true);
    when(() => mockNostr.publicKey).thenReturn('');
  });

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(PopularVideosVariant.classic);
  });

  group('Seen filtering per surface', () {
    test('getHomeFeedVideos drops videos the viewer has seen', () async {
      const seenId = 'seen-home';
      const unseenId = 'unseen-home';
      when(
        () => mockFunnelcake.getHomeFeed(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => HomeFeedResponse(
          videos: [_stats(seenId), _stats(unseenId)],
          rawBody: '{}',
        ),
      );

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              id == seenId,
        ),
      );

      final result = await repo.getHomeFeedVideos(
        authors: ['a'],
        userPubkey: 'u',
      );
      expect(result.videos.map((v) => v.id).toList(), [unseenId]);
    });

    test('getHomeFeedVideos hides videos seen up to a year ago', () async {
      when(
        () => mockFunnelcake.getHomeFeed(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => HomeFeedResponse(
          videos: [_stats('seen-months-ago'), _stats('never-seen')],
          rawBody: '{}',
        ),
      );

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              id == 'seen-months-ago' && within >= const Duration(days: 300),
        ),
      );

      final result = await repo.getHomeFeedVideos(
        authors: ['a'],
        userPubkey: 'u',
      );
      expect(result.videos.map((v) => v.id).toList(), ['never-seen']);
    });

    test(
      'getHomeFeedVideos reads past pages the viewer has fully seen',
      () async {
        when(
          () => mockFunnelcake.getHomeFeed(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((invocation) async {
          final before = invocation.namedArguments[#before] as int?;
          if (before == null) {
            return HomeFeedResponse(
              videos: [_stats('seen-newest', createdAt: 1000)],
              nextCursor: 1000,
              hasMore: true,
              rawBody: '{}',
            );
          }
          return HomeFeedResponse(
            videos: [_stats('unseen-older', createdAt: 900)],
            rawBody: '{}',
          );
        });

        final repo = VideosRepository(
          nostrClient: mockNostr,
          funnelcakeApiClient: mockFunnelcake,
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
                id == 'seen-newest',
          ),
        );

        final result = await repo.getHomeFeedVideos(
          authors: ['a'],
          userPubkey: 'u',
          limit: 1,
        );
        expect(result.videos.map((v) => v.id).toList(), ['unseen-older']);
        expect(result.hasMore, isFalse);
      },
    );

    test(
      'getHomeFeedVideos ends the feed after a long run of seen pages',
      () async {
        var cursor = 100000;
        when(
          () => mockFunnelcake.getHomeFeed(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async {
          cursor -= 10;
          return HomeFeedResponse(
            videos: [_stats('seen-$cursor', createdAt: cursor)],
            nextCursor: cursor,
            hasMore: true,
            rawBody: '{}',
          );
        });

        final repo = VideosRepository(
          nostrClient: mockNostr,
          funnelcakeApiClient: mockFunnelcake,
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (_, {within = const Duration(hours: 24)}) => true,
          ),
        );

        final result = await repo.getHomeFeedVideos(
          authors: ['a'],
          userPubkey: 'u',
        );
        expect(result.videos, isEmpty);
        expect(result.hasMore, isFalse);
        expect(result.paginationCursor, isNull);
        verify(
          () => mockFunnelcake.getHomeFeed(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).called(maxSeenOnlyFeedPages);
      },
    );

    test('getHomeFeedVideos drops seen videos from relays', () async {
      when(() => mockFunnelcake.isAvailable).thenReturn(false);
      when(() => mockNostr.queryEventsDetailed(any())).thenAnswer(
        (_) async => (
          events: [
            _event('relay-seen', createdAt: 1704067300),
            _event('relay-unseen'),
          ],
          noRelays: false,
          timedOut: false,
        ),
      );

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              id == 'relay-seen',
        ),
      );

      final result = await repo.getHomeFeedVideos(authors: ['author']);
      expect(result.videos.map((v) => v.id).toList(), ['relay-unseen']);
    });

    // The New feed is chronological by contract: the label promises recency.
    // Seen videos are dropped rather than demoted, so what remains keeps its
    // place; demotion partitioned each page and produced a sawtooth.
    test(
      'getNewVideos drops seen videos and keeps the rest in order',
      () async {
        when(
          () => mockFunnelcake.getRecentVideosPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => RecentVideosResponse(
            videos: [
              _stats('newest', createdAt: 1000),
              _stats('seen-new', createdAt: 900),
              _stats('oldest', createdAt: 800),
            ],
            serverItemCount: 3,
          ),
        );
        when(
          () => mockFunnelcake.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

        final repo = VideosRepository(
          nostrClient: mockNostr,
          funnelcakeApiClient: mockFunnelcake,
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
                id == 'seen-new',
          ),
        );

        final result = await repo.getNewVideos();
        expect(result.videos.map((v) => v.id).toList(), ['newest', 'oldest']);
      },
    );

    test(
      'getNewVideos tops up a page whose seen videos were dropped',
      () async {
        when(
          () => mockFunnelcake.getRecentVideosPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((invocation) async {
          final before = invocation.namedArguments[#before] as int?;
          if (before == null) {
            return RecentVideosResponse(
              videos: [
                _stats('p1-seen-newest', createdAt: 1000),
                _stats('p1-mid', createdAt: 900),
                _stats('p1-tail', createdAt: 800),
              ],
              serverItemCount: 3,
            );
          }
          return RecentVideosResponse(
            videos: [
              _stats('p2-seen-head', createdAt: 700),
              _stats('p2-older', createdAt: 600),
            ],
            serverItemCount: 2,
          );
        });
        when(
          () => mockFunnelcake.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

        final repo = VideosRepository(
          nostrClient: mockNostr,
          funnelcakeApiClient: mockFunnelcake,
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
                id == 'p1-seen-newest' || id == 'p2-seen-head',
          ),
        );

        final page = await repo.getNewVideos(limit: 3);
        expect(page.videos.map((v) => v.id).toList(), [
          'p1-mid',
          'p1-tail',
          'p2-older',
        ]);
      },
    );

    test('getNewVideos stops after a long run of seen pages', () async {
      var page = 0;
      when(
        () => mockFunnelcake.getRecentVideosPage(
          limit: any(named: 'limit'),
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer((_) async {
        page++;
        return RecentVideosResponse(
          videos: [_stats('seen-$page')],
          serverItemCount: 1,
          hasMore: true,
          nextCursor: 'cursor-$page',
        );
      });
      when(
        () => mockFunnelcake.getRecentVideosPage(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) async {
        page++;
        return RecentVideosResponse(
          videos: [_stats('seen-$page')],
          serverItemCount: 1,
          hasMore: true,
          nextCursor: 'cursor-$page',
        );
      });
      when(
        () => mockFunnelcake.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (_, {within = const Duration(hours: 24)}) => true,
        ),
      );

      final result = await repo.getNewVideos(limit: 1);
      expect(result.videos, isEmpty);
      expect(page, equals(maxSeenOnlyFeedPages));
      expect(result.paginationCursor, equals('cursor-$page'));
    });

    test('getNewVideos cache hit drops videos seen since caching', () async {
      final seenIds = <String>{};
      when(
        () => mockFunnelcake.getRecentVideosPage(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => RecentVideosResponse(
          videos: [_stats('cache-a'), _stats('cache-b')],
          serverItemCount: 2,
        ),
      );
      when(
        () => mockFunnelcake.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        inMemoryFeedCache: InMemoryFeedCache(),
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              seenIds.contains(id),
        ),
      );

      final first = await repo.getNewVideos();
      seenIds.add('cache-a');
      final second = await repo.getNewVideos();
      expect(first.videos.map((v) => v.id).toList(), ['cache-a', 'cache-b']);
      expect(second.videos.map((v) => v.id).toList(), ['cache-b']);
      verify(
        () => mockFunnelcake.getRecentVideosPage(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).called(1);
    });

    test('getNewVideos refetches when every cached video was seen', () async {
      final seenIds = <String>{};
      var calls = 0;
      when(
        () => mockFunnelcake.getRecentVideosPage(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) async {
        calls++;
        return RecentVideosResponse(
          videos: [_stats(calls == 1 ? 'cached-only' : 'freshly-posted')],
          serverItemCount: 1,
        );
      });
      when(
        () => mockFunnelcake.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        inMemoryFeedCache: InMemoryFeedCache(),
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              seenIds.contains(id),
        ),
      );

      await repo.getNewVideos();
      seenIds.add('cached-only');
      final second = await repo.getNewVideos();
      expect(second.videos.map((v) => v.id).toList(), ['freshly-posted']);
      expect(calls, equals(2));
    });

    // With Funnelcake down, the relay path drops seen videos too and keeps
    // the rest chronological.
    test('getNewVideos relay fallback drops seen videos', () async {
      final newestSeen = _event('relay-seen-newest', createdAt: 1704067300);
      final middle = _event('relay-mid', createdAt: 1704067250);
      final oldest = _event('relay-oldest');
      when(
        () => mockFunnelcake.getRecentVideosPage(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenThrow(const FunnelcakeException('stats API down'));
      when(
        () => mockFunnelcake.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
      when(
        () => mockNostr.queryEvents(any()),
      ).thenAnswer((_) async => [middle, oldest, newestSeen]);

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              id == 'relay-seen-newest',
        ),
      );

      final result = await repo.getNewVideos(limit: 10);
      expect(result.videos.map((v) => v.id).toList(), [
        'relay-mid',
        'relay-oldest',
      ]);
    });

    test(
      'getClassicVideos drops recently seen (inventory unlimited)',
      () async {
        final seen = _stats('seen-classic', platform: 'vine');
        final unseen = _stats('unseen-classic', platform: 'vine');
        when(
          () => mockFunnelcake.getClassicVines(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => [seen, unseen]);
        when(
          () => mockFunnelcake.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

        final repo = VideosRepository(
          nostrClient: mockNostr,
          funnelcakeApiClient: mockFunnelcake,
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
                id == 'seen-classic',
          ),
          random: StubRandom(offsetPage: 0),
        );

        final result = await repo.getClassicVideos(limit: 2);
        expect(result.videos.any((v) => v.id == 'seen-classic'), isFalse);
        expect(result.videos.any((v) => v.id == 'unseen-classic'), isTrue);
      },
    );

    test('getProfileVideos is untouched even if seen', () async {
      final seen = _event('seen-profile');
      final unseen = _event('unseen-profile', createdAt: 1704067100);
      when(
        () => mockNostr.queryEvents(any()),
      ).thenAnswer((_) async => [seen, unseen]);

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (_, {within = const Duration(hours: 24)}) => true,
        ),
      );

      final videos = await repo.getProfileVideos(authorPubkey: 'author');
      expect(
        videos.map((v) => v.id),
        containsAll(['seen-profile', 'unseen-profile']),
      );
      expect(videos.length, 2);
    });

    test('without SeenVideoLookup, no filtering occurs', () async {
      final v1 = _stats('v1');
      final v2 = _stats('v2');
      when(
        () => mockFunnelcake.getHomeFeed(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => HomeFeedResponse(videos: [v1, v2], rawBody: '{}'),
      );

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
      );
      final result = await repo.getHomeFeedVideos(
        authors: ['a'],
        userPubkey: 'u',
      );
      expect(result.videos.map((v) => v.id).toList(), ['v1', 'v2']);
    });

    test(
      'classic deep-fetch triggers when filtering removes most of page',
      () async {
        final seenPage = List.generate(
          5,
          (i) => _stats('seen-$i', platform: 'vine'),
        );
        final freshPage = [
          _stats('fresh-0', platform: 'vine'),
          _stats('fresh-1', platform: 'vine'),
        ];
        var call = 0;
        when(
          () => mockFunnelcake.getClassicVines(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async {
          call++;
          if (call == 1) return seenPage;
          if (call == 2) return freshPage;
          return [];
        });
        when(
          () => mockFunnelcake.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

        final repo = VideosRepository(
          nostrClient: mockNostr,
          funnelcakeApiClient: mockFunnelcake,
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
                id.startsWith('seen-'),
          ),
          random: StubRandom(offsetPage: 0),
        );

        final result = await repo.getClassicVideos(limit: 2);
        expect(result.videos.any((v) => v.id.startsWith('seen-')), isFalse);
        expect(result.videos.any((v) => v.id.startsWith('fresh-')), isTrue);
        expect(call, greaterThan(1));
      },
    );

    test('classic returns a cursor after eight all-seen pages', () async {
      when(
        () => mockFunnelcake.getClassicVines(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((invocation) async {
        final offset = invocation.namedArguments[#offset] as int;
        return [
          _stats('seen-$offset-a', platform: 'vine'),
          _stats('seen-$offset-b', platform: 'vine'),
        ];
      });
      when(
        () => mockFunnelcake.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (_, {within = const Duration(hours: 24)}) => true,
        ),
        random: StubRandom(offsetPage: 0),
      );

      final result = await repo.getClassicVideos(limit: 2);

      expect(result.videos, isEmpty);
      expect(result.paginationCursor, 'classic-offset:16');
      expect(result.hasMore, isTrue);
      verify(
        () => mockFunnelcake.getClassicVines(
          limit: 2,
          offset: any(named: 'offset'),
        ),
      ).called(8);
    });

    test('classic cache drops videos watched after it was populated', () async {
      final seenIds = <String>{};
      when(
        () => mockFunnelcake.getClassicVines(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => [
          _stats('cached-seen', platform: 'vine'),
          _stats('cached-fresh', platform: 'vine'),
        ],
      );
      when(
        () => mockFunnelcake.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        inMemoryFeedCache: InMemoryFeedCache(),
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              seenIds.contains(id),
        ),
        random: StubRandom(offsetPage: 0),
      );

      final initial = await repo.getClassicVideos(limit: 2);
      seenIds.add('cached-seen');
      final cached = await repo.getClassicVideos(limit: 2);

      expect(initial.videos, hasLength(2));
      expect(cached.videos.map((video) => video.id), ['cached-fresh']);
      verify(
        () => mockFunnelcake.getClassicVines(
          limit: 2,
          offset: any(named: 'offset'),
        ),
      ).called(1);
    });

    test('classic skips its cache once every cached video was seen', () async {
      final seenIds = <String>{};
      var calls = 0;
      when(
        () => mockFunnelcake.getClassicVines(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? [
                _stats('cached-a', platform: 'vine'),
                _stats('cached-b', platform: 'vine'),
              ]
            : [_stats('fresh-classic', platform: 'vine')];
      });
      when(
        () => mockFunnelcake.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        inMemoryFeedCache: InMemoryFeedCache(),
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              seenIds.contains(id),
        ),
        random: StubRandom(offsetPage: 0),
      );

      await repo.getClassicVideos(limit: 2);
      seenIds.addAll(['cached-a', 'cached-b']);
      final refreshed = await repo.getClassicVideos(limit: 2);

      expect(
        refreshed.videos.map((video) => video.id),
        contains('fresh-classic'),
      );
      expect(
        refreshed.videos.map((video) => video.id),
        isNot(contains('cached-a')),
      );
    });

    test('forYou deep-fetch via getRecommendedVideos', () async {
      final seen = _stats('seen-foyou');
      final fresh = _stats('fresh-foyou');
      when(
        () => mockFunnelcake.getRecommendations(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          seed: any(named: 'seed'),
          preferredLanguages: any(named: 'preferredLanguages'),
          viewerCountry: any(named: 'viewerCountry'),
        ),
      ).thenAnswer(
        (_) async => RecommendationsResponse(
          videos: [seen],
          source: 'personalized',
          hasMore: true,
          nextCursor: 'c1',
        ),
      );
      when(
        () => mockFunnelcake.getRecommendations(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          cursor: 'c1',
          seed: any(named: 'seed'),
          preferredLanguages: any(named: 'preferredLanguages'),
          viewerCountry: any(named: 'viewerCountry'),
        ),
      ).thenAnswer(
        (_) async =>
            RecommendationsResponse(videos: [fresh], source: 'personalized'),
      );

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              id == 'seen-foyou',
        ),
      );

      final result = await repo.getRecommendedVideos(
        userPubkey: 'u',
        limit: 10,
      );
      expect(result.videos.map((v) => v.id), contains('fresh-foyou'));
    });
  });

  group('filterOutRecentlySeenVideos helper', () {
    test('drops recently seen, keeps unseen', () {
      final vSeen = VideoEvent(
        id: 'seen',
        pubkey: 'p',
        createdAt: 1,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        videoUrl: 'https://x/1.mp4',
      );
      final vUnseen = VideoEvent(
        id: 'unseen',
        pubkey: 'p',
        createdAt: 1,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        videoUrl: 'https://x/2.mp4',
      );
      final filtered = filterOutRecentlySeenVideos(
        [vSeen, vUnseen],
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              id == 'seen',
        ),
      );
      expect(filtered.map((v) => v.id), ['unseen']);
    });

    test('returns original if would empty', () {
      final v1 = VideoEvent(
        id: 'a',
        pubkey: 'p',
        createdAt: 1,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        videoUrl: 'https://x/1.mp4',
      );
      final filtered = filterOutRecentlySeenVideos(
        [v1],
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (_, {within = const Duration(hours: 24)}) => true,
        ),
      );
      expect(filtered.map((v) => v.id), ['a']);
    });
  });

  group('getVideoDiscoveryPage', () {
    late List<VideoStats> recommendationPage;
    late List<String> requestedSeeds;

    setUp(() {
      recommendationPage = [];
      requestedSeeds = [];
      when(
        () => mockFunnelcake.getRecommendations(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          seed: any(named: 'seed'),
          preferredLanguages: any(named: 'preferredLanguages'),
          viewerCountry: any(named: 'viewerCountry'),
        ),
      ).thenAnswer((invocation) async {
        requestedSeeds.add(invocation.namedArguments[#seed] as String);
        return RecommendationsResponse(
          videos: List.of(recommendationPage),
          source: 'personalized',
        );
      });
    });

    VideosRepository buildRepository({Set<String> watched = const {}}) =>
        VideosRepository(
          nostrClient: mockNostr,
          funnelcakeApiClient: mockFunnelcake,
          inMemoryFeedCache: InMemoryFeedCache(),
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
                watched.contains(id),
          ),
        );

    test(
      'fetches a new first page instead of replaying the cached For You page',
      () async {
        final repo = buildRepository();
        recommendationPage = [_stats('home-first-page')];
        await repo.getRecommendedVideos(userPubkey: 'u', limit: 10);

        recommendationPage = [_stats('fresh-discovery')];
        final result = await repo.getVideoDiscoveryPage(
          userPubkey: 'u',
          limit: 10,
        );

        expect(result.videos.map((v) => v.id), equals(['fresh-discovery']));
      },
    );

    test('leaves the For You tab cached first page in place', () async {
      final repo = buildRepository();
      recommendationPage = [_stats('home-first-page')];
      await repo.getRecommendedVideos(userPubkey: 'u', limit: 10);

      recommendationPage = [_stats('fresh-discovery')];
      await repo.getVideoDiscoveryPage(userPubkey: 'u', limit: 10);
      final home = await repo.getRecommendedVideos(userPubkey: 'u', limit: 10);

      expect(home.videos.map((v) => v.id), equals(['home-first-page']));
    });

    test('keeps the For You session seed', () async {
      final repo = buildRepository();
      recommendationPage = [_stats('home-first-page')];
      await repo.getRecommendedVideos(userPubkey: 'u', limit: 10);
      await repo.getVideoDiscoveryPage(userPubkey: 'u', limit: 10);

      expect(requestedSeeds, hasLength(2));
      expect(requestedSeeds.last, equals(requestedSeeds.first));
    });

    test(
      'drops videos the viewer has watched instead of replaying them',
      () async {
        final repo = buildRepository(watched: {'watched'});
        recommendationPage = [_stats('watched'), _stats('unwatched')];

        final result = await repo.getVideoDiscoveryPage(
          userPubkey: 'u',
          limit: 10,
        );

        expect(result.videos.map((v) => v.id), equals(['unwatched']));
      },
    );

    test(
      'falls back to unwatched popular videos when every recommendation was '
      'watched',
      () async {
        when(
          () => mockFunnelcake.getWatchingVideos(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async => [_stats('watched'), _stats('popular-new')]);
        final repo = buildRepository(watched: {'watched'});
        recommendationPage = [_stats('watched')];

        final result = await repo.getVideoDiscoveryPage(
          userPubkey: 'u',
          limit: 10,
        );

        expect(result.videos.map((v) => v.id), equals(['popular-new']));
        expect(result.paginationCursor, isNull);
      },
    );
  });
}
