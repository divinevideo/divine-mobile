// TDD: client-side seen-video filtering across feeds
// Covers: home (following) drops seen videos, New keeps watched videos
// (including cache hits, relay fallback, refresh, and page boundaries),
// classic drops + deep-fetch, profile untouched, deep-fetch triggers when
// filtering removes most of page.

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
  String? videoUrl,
}) => VideoStats(
  rawTags: platform != null ? {'platform': platform} : const {},
  isArchiveVerificationUnknown: platform == 'vine',
  id: id,
  pubkey: pubkey ?? 'pubkey-$id',
  createdAt: DateTime.fromMillisecondsSinceEpoch(
    (createdAt ?? 1704067200) * 1000,
  ),
  kind: EventKind.videoVertical,
  dTag: 'dtag-$id',
  title: 'Test',
  thumbnail: 'https://example.com/thumb.jpg',
  videoUrl: videoUrl ?? 'https://example.com/$id.mp4',
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

  group('Own videos stay visible after viewing', () {
    final ownPubkey = 'a' * 64;
    final otherPubkey = 'b' * 64;
    final ownId = '1' * 64;
    final otherId = '2' * 64;
    final freshId = '3' * 64;
    late VideosRepository repository;

    setUp(() {
      when(() => mockNostr.publicKey).thenReturn(ownPubkey);
      final videos = [
        _stats(ownId, pubkey: ownPubkey, createdAt: 1000, platform: 'vine'),
        _stats(otherId, pubkey: otherPubkey, createdAt: 900, platform: 'vine'),
        _stats(freshId, pubkey: otherPubkey, createdAt: 800, platform: 'vine'),
      ];
      when(
        () => mockFunnelcake.getHomeFeed(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => HomeFeedResponse(videos: videos, rawBody: '{}'),
      );
      when(
        () => mockFunnelcake.getWatchingVideos(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) async => videos);
      when(
        () => mockFunnelcake.getClassicVines(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => videos);
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
          videos: videos,
          source: 'personalized',
        ),
      );
      when(
        () => mockFunnelcake.getVideosByAuthors(
          authors: any(named: 'authors'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => RecentVideosResponse(
          videos: videos,
          serverItemCount: 3,
          hasMore: false,
        ),
      );
      when(
        () => mockFunnelcake.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
      repository = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        inMemoryFeedCache: InMemoryFeedCache(),
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = seenVideoExclusionWindow}) =>
              id == ownId || id == otherId,
        ),
        random: StubRandom(offsetPage: 0),
      );
    });

    for (final feed in ['Following', 'Classics', 'For You']) {
      test('$feed keeps watched own videos and hides watched others', () async {
        final result = await switch (feed) {
          'Following' => repository.getHomeFeedVideos(
            authors: [ownPubkey, otherPubkey],
            userPubkey: ownPubkey,
          ),
          'Classics' => repository.getClassicVideos(),
          _ => repository.getRecommendedVideos(userPubkey: ownPubkey),
        };
        expect(
          result.videos.map((video) => video.id),
          containsAll([ownId, freshId]),
        );
        expect(
          result.videos.map((video) => video.id),
          isNot(contains(otherId)),
        );
      });
    }

    test(
      'auth identity keeps own videos visible before the signer is ready',
      () async {
        when(() => mockNostr.publicKey).thenReturn('');
        String? viewerPubkey = ownPubkey;
        final authRepository = VideosRepository(
          nostrClient: mockNostr,
          funnelcakeApiClient: mockFunnelcake,
          inMemoryFeedCache: InMemoryFeedCache(),
          viewerPubkey: () => viewerPubkey,
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (id, {within = seenVideoExclusionWindow}) =>
                id == ownId || id == otherId,
          ),
        );
        final initial = await authRepository.getClassicVideos();
        expect(
          initial.videos.map((video) => video.id),
          unorderedEquals([ownId, freshId]),
        );

        // A stale signer key must not grant an exception after auth signs out.
        when(() => mockNostr.publicKey).thenReturn(ownPubkey);
        viewerPubkey = null;
        final signedOut = await authRepository.getClassicVideos();
        expect(signedOut.videos.map((video) => video.id), [freshId]);
      },
    );

    test(
      'For You accepts an all-watched page containing an own video',
      () async {
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
            videos: [_stats(ownId, pubkey: ownPubkey)],
            source: 'personalized',
            hasMore: true,
            nextCursor: 'next-page',
          ),
        );
        final result = await repository.getRecommendedVideos(
          userPubkey: ownPubkey,
          limit: 1,
        );
        expect(result.videos.map((video) => video.id), [ownId]);
        expect(result.paginationCursor, 'next-page');
        expect(result.hasMore, isTrue);
      },
    );

    test('New relay fallback keeps watched posts by both authors', () async {
      when(() => mockFunnelcake.isAvailable).thenReturn(false);
      when(() => mockNostr.queryEvents(any())).thenAnswer(
        (_) async => [
          _event(ownId, pubkey: ownPubkey, createdAt: 1000),
          _event(otherId, pubkey: otherPubkey, createdAt: 900),
          _event(freshId, pubkey: otherPubkey, createdAt: 800),
        ],
      );
      final result = await repository.getNewVideos();
      expect(result.videos.map((video) => video.id), [ownId, otherId, freshId]);
    });

    test('Following badge pages also keep watched own videos', () async {
      final pager = repository.createBadgeVideoPager(
        [ownPubkey, otherPubkey],
        hideSeen: true,
      );
      expect((await pager.loadMore()).map((video) => video.id), [
        ownId,
        freshId,
      ]);
    });

    test(
      'Classics cache stops exempting videos from the previous account',
      () async {
        final initial = await repository.getClassicVideos();
        expect(
          initial.videos.map((video) => video.id),
          unorderedEquals([ownId, freshId]),
        );
        when(() => mockNostr.publicKey).thenReturn(otherPubkey);
        final switched = await repository.getClassicVideos();
        expect(switched.videos.map((video) => video.id), [freshId]);
        when(() => mockNostr.publicKey).thenReturn('');
        final signedOut = await repository.getClassicVideos();
        expect(signedOut.videos.map((video) => video.id), [freshId]);
      },
    );
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

    test(
      'getHomeFeedVideos does not reset seen-only budget on empty transformed '
      'pages',
      () async {
        var cursor = 1000;
        var calls = 0;
        when(
          () => mockFunnelcake.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
        when(
          () => mockFunnelcake.getHomeFeed(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async {
          calls++;
          cursor -= 10;
          final isEmptyTransformed = calls % 3 == 0;
          return HomeFeedResponse(
            videos: [
              _stats(
                'row-$calls',
                createdAt: cursor,
                videoUrl: isEmptyTransformed ? '' : null,
              ),
            ],
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
        // Calls 3, 6, and 9 transform to empty pages without resetting the
        // 8-page seen budget, so the 8th seen page lands on call 11.
        expect(calls, equals(maxSeenOnlyFeedPages + 3));
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
    // Watching a video must not remove it or change its chronological position.
    test(
      'getNewVideos keeps watched videos in chronological order',
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
        expect(result.videos.map((v) => v.id).toList(), [
          'newest',
          'seen-new',
          'oldest',
        ]);
      },
    );

    test(
      'getNewVideos keeps a full page without fetching past watched videos',
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
          'p1-seen-newest',
          'p1-mid',
          'p1-tail',
        ]);
        verify(
          () => mockFunnelcake.getRecentVideosPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).called(1);
      },
    );

    test('getNewVideos returns a watched-only page with its cursor', () async {
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
      expect(result.videos.map((v) => v.id), ['seen-1']);
      expect(page, equals(1));
      expect(result.hasMore, isTrue);
      expect(result.paginationCursor, 'cursor-1');
    });

    test(
      'getNewVideos retains watched rows when continuing with a cursor',
      () async {
        var page = 0;
        when(
          () => mockFunnelcake.getRecentVideosPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer((invocation) async {
          page++;
          if (invocation.namedArguments[#cursor] == null) {
            return RecentVideosResponse(
              videos: [_stats('unseen-1'), _stats('seen-1')],
              serverItemCount: 2,
              hasMore: true,
              nextCursor: 'cursor-$page',
            );
          }
          return RecentVideosResponse(
            videos: [_stats('seen-${page}a'), _stats('seen-${page}b')],
            serverItemCount: 2,
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
            wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
                id != 'unseen-1',
          ),
        );

        final result = await repo.getNewVideos(limit: 2);
        expect(result.videos.map((v) => v.id), ['unseen-1', 'seen-1']);
        expect(page, equals(1));
        expect(result.hasMore, isTrue);
        expect(result.paginationCursor, 'cursor-1');

        final next = await repo.getNewVideos(limit: 2, cursor: 'cursor-1');
        expect(next.videos.map((v) => v.id), ['seen-2a', 'seen-2b']);
        expect(next.hasMore, isTrue);
        expect(next.paginationCursor, 'cursor-2');
        expect(page, equals(2));
      },
    );

    test('getNewVideos cache retains videos watched since caching', () async {
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
      expect(second.videos.map((v) => v.id).toList(), ['cache-a', 'cache-b']);
      verify(
        () => mockFunnelcake.getRecentVideosPage(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).called(1);
    });

    test('getNewVideos retains an entirely watched cached page', () async {
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

      final first = await repo.getNewVideos();
      expect(first.videos.map((v) => v.id), ['cached-only']);
      seenIds.add('cached-only');
      final second = await repo.getNewVideos();
      expect(second.videos.map((v) => v.id).toList(), ['cached-only']);
      expect(calls, equals(1));
    });

    test('getNewVideos still refetches an empty cached page', () async {
      final videoId = '5' * 64;
      var calls = 0;
      when(
        () => mockFunnelcake.getRecentVideosPage(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) async {
        calls++;
        return RecentVideosResponse(
          videos: calls == 1 ? [] : [_stats(videoId, pubkey: 'a' * 64)],
          serverItemCount: calls == 1 ? 0 : 1,
          hasMore: false,
        );
      });
      when(
        () => mockFunnelcake.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        inMemoryFeedCache: InMemoryFeedCache(),
      );

      final initial = await repo.getNewVideos();
      expect(initial.videos, isEmpty);
      final next = await repo.getNewVideos();
      expect(next.videos.map((video) => video.id), [videoId]);
      expect(calls, 2);
    });

    // With Funnelcake down, watched relay results remain chronological too.
    test('getNewVideos relay fallback keeps watched videos', () async {
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
        'relay-seen-newest',
        'relay-mid',
        'relay-oldest',
      ]);
    });

    for (final manualRefresh in [true, false]) {
      test(
        'getNewVideos ${manualRefresh ? 'refresh' : 'revalidation'} retains '
        'watched posts and replaces the cached page',
        () async {
          final originalId = '1' * 64;
          final newerId = '2' * 64;
          final relayId = '3' * 64;
          final author = 'a' * 64;
          final watched = <String>{};
          var calls = 0;
          when(
            () => mockFunnelcake.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async {
            calls++;
            return RecentVideosResponse(
              videos: [
                if (calls > 1) _stats(newerId, pubkey: author, createdAt: 1000),
                _stats(originalId, pubkey: author, createdAt: 900),
              ],
              serverItemCount: calls > 1 ? 2 : 1,
              hasMore: false,
            );
          });
          when(
            () => mockFunnelcake.getBulkVideoStats(any()),
          ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
          when(() => mockNostr.queryEvents(any())).thenAnswer(
            (_) async => [_event(relayId, pubkey: author, createdAt: 1100)],
          );
          final repo = VideosRepository(
            nostrClient: mockNostr,
            funnelcakeApiClient: mockFunnelcake,
            inMemoryFeedCache: InMemoryFeedCache(),
            seenVideoLookup: SeenVideoLookup(
              wasSeenRecently: (id, {within = seenVideoExclusionWindow}) =>
                  watched.contains(id),
            ),
          );

          final initial = await repo.getNewVideos(limit: 3);
          expect(initial.videos.map((video) => video.id), [originalId]);
          watched.addAll([originalId, newerId, relayId]);

          final refreshed = await repo.getNewVideos(
            limit: 3,
            skipCache: manualRefresh,
            revalidate: !manualRefresh,
          );
          final expectedIds = [
            if (manualRefresh) relayId,
            newerId,
            originalId,
          ];
          expect(refreshed.videos.map((video) => video.id), expectedIds);
          expect(refreshed.hasMore, isFalse);
          final cached = await repo.getNewVideos(limit: 3);
          expect(cached.videos.map((video) => video.id), expectedIds);
          expect(calls, 2);
        },
      );
    }

    test(
      'getNewVideos loads without reading unavailable seen history',
      () async {
        final videoId = '4' * 64;
        when(
          () => mockFunnelcake.getRecentVideosPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => RecentVideosResponse(
            videos: [_stats(videoId, pubkey: 'a' * 64)],
            serverItemCount: 1,
            hasMore: false,
          ),
        );
        when(
          () => mockFunnelcake.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
        final repo = VideosRepository(
          nostrClient: mockNostr,
          funnelcakeApiClient: mockFunnelcake,
          seenVideoLookup: SeenVideoLookup(
            initialize: () async =>
                throw StateError('Seen history unavailable'),
            wasSeenRecently: (_, {within = seenVideoExclusionWindow}) =>
                throw StateError('Seen history unavailable'),
          ),
        );

        final result = await repo.getNewVideos();
        expect(result.videos.map((video) => video.id), [videoId]);
      },
    );

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

    test(
      'getRecommendedVideos stops after maxSeenOnlyFeedPages and falls back to '
      'unseen popular videos',
      () async {
        var page = 0;
        when(
          () => mockFunnelcake.getRecommendations(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            seed: any(named: 'seed'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((_) async {
          page++;
          return RecommendationsResponse(
            videos: [_stats('seen-rec-$page')],
            source: 'personalized',
            hasMore: true,
            nextCursor: 'cursor-$page',
          );
        });
        when(
          () => mockFunnelcake.getWatchingVideos(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => [_stats('seen-rec-1'), _stats('popular-unseen')],
        );

        final repo = VideosRepository(
          nostrClient: mockNostr,
          funnelcakeApiClient: mockFunnelcake,
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
                id.startsWith('seen-'),
          ),
        );

        final result = await repo.getRecommendedVideos(
          userPubkey: 'u',
          limit: 1,
        );
        expect(page, equals(maxSeenOnlyFeedPages));
        expect(result.videos.map((v) => v.id), equals(['popular-unseen']));
        expect(result.paginationCursor, isNull);
      },
    );
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

    test(
      'stops after maxSeenOnlyFeedPages seen recommendation pages and falls '
      'back to unwatched popular videos',
      () async {
        var page = 0;
        when(
          () => mockFunnelcake.getRecommendations(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            seed: any(named: 'seed'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((_) async {
          page++;
          return RecommendationsResponse(
            videos: [_stats('watched-$page')],
            source: 'personalized',
            hasMore: true,
            nextCursor: 'discovery-cursor-$page',
          );
        });
        when(
          () => mockFunnelcake.getWatchingVideos(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => [_stats('watched-1'), _stats('popular-unwatched')],
        );

        final repo = VideosRepository(
          nostrClient: mockNostr,
          funnelcakeApiClient: mockFunnelcake,
          inMemoryFeedCache: InMemoryFeedCache(),
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
                id.startsWith('watched-'),
          ),
        );

        final result = await repo.getVideoDiscoveryPage(
          userPubkey: 'u',
          limit: 1,
        );

        expect(page, equals(maxSeenOnlyFeedPages));
        expect(result.videos.map((v) => v.id), equals(['popular-unwatched']));
        expect(result.paginationCursor, isNull);
      },
    );

    test(
      'Following feed filters seen videos before bulk-stats hydration',
      () async {
        final seenId = 's' * 64;
        final unseenId = 'u' * 64;
        var pageCalls = 0;
        when(
          () => mockFunnelcake.getHomeFeed(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async {
          pageCalls++;
          if (pageCalls == 1) {
            return HomeFeedResponse(
              videos: [_stats(seenId, createdAt: 1000)],
              rawBody: '{}',
              hasMore: true,
              nextCursor: 999,
            );
          }
          return HomeFeedResponse(
            videos: [_stats(unseenId, createdAt: 900)],
            rawBody: '{}',
          );
        });
        final hydratedBatches = <List<String>>[];
        when(() => mockFunnelcake.getBulkVideoStats(any())).thenAnswer((
          inv,
        ) async {
          final ids = List<String>.from(inv.positionalArguments.first as List);
          hydratedBatches.add(ids);
          return const BulkVideoStatsResponse(stats: {});
        });

        final repo = VideosRepository(
          nostrClient: mockNostr,
          funnelcakeApiClient: mockFunnelcake,
          inMemoryFeedCache: InMemoryFeedCache(),
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (id, {within = seenVideoExclusionWindow}) =>
                id == seenId,
          ),
        );

        final result = await repo.getHomeFeedVideos(
          authors: const ['author'],
          userPubkey: 'viewer',
          limit: 1,
        );

        expect(result.videos.map((v) => v.id), equals([unseenId]));
        expect(
          hydratedBatches,
          equals([
            [unseenId],
          ]),
        );
      },
    );
  });
}
