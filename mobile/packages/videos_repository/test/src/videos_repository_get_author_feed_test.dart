// ABOUTME: Tests for VideosRepository.getAuthorFeed — the composed author/
// ABOUTME: profile feed (REST envelope, collaborator guard, relay-seed merge,
// ABOUTME: in-memory cache, REST-unavailable + FunnelcakeException fallback).

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

const _author = 'author-pubkey';

VideoStats _stats({
  required String id,
  String pubkey = _author,
  String dTag = 'd',
  String videoUrl = 'https://example.com/v.mp4',
  int reactions = 0,
  int comments = 0,
  int reposts = 0,
  Map<String, String> rawTags = const {},
}) {
  return VideoStats(
    id: id,
    pubkey: pubkey,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
    kind: EventKind.videoVertical,
    dTag: dTag,
    title: 'Test',
    thumbnail: 'https://example.com/t.jpg',
    videoUrl: videoUrl,
    reactions: reactions,
    comments: comments,
    reposts: reposts,
    engagementScore: 0,
    rawTags: rawTags,
  );
}

VideoEvent _seed(String id, {String? vineId, int? originalLikes}) => VideoEvent(
  id: id,
  pubkey: _author,
  createdAt: 1704067200,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
  vineId: vineId,
  originalLikes: originalLikes,
);

void main() {
  setUpAll(() => registerFallbackValue(<String>[]));

  group('VideosRepository.getAuthorFeed', () {
    late _MockNostrClient nostrClient;
    late _MockFunnelcakeApiClient funnelcake;
    late InMemoryFeedCache cache;
    late VideosRepository repository;

    void stubAuthor(VideosByAuthorResponse response) {
      when(
        () => funnelcake.getVideosByAuthor(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) async => response);
    }

    setUp(() {
      nostrClient = _MockNostrClient();
      funnelcake = _MockFunnelcakeApiClient();
      cache = InMemoryFeedCache();
      repository = VideosRepository(
        nostrClient: nostrClient,
        funnelcakeApiClient: funnelcake,
        inMemoryFeedCache: cache,
      );

      when(() => funnelcake.isAvailable).thenReturn(true);
      when(
        () => funnelcake.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
      when(() => funnelcake.getVideoViewStats(any())).thenAnswer(
        (_) async => const VideoViewStats(views: 0),
      );
    });

    test('surfaces the v2 envelope (totalCount/nextOffset/hasMore)', () async {
      stubAuthor(
        VideosByAuthorResponse(
          videos: [_stats(id: 'a')],
          totalCount: 42,
          nextOffset: 50,
          hasMore: true,
        ),
      );

      final result = await repository.getAuthorFeed(authorPubkey: _author);

      expect(result.videos, hasLength(1));
      expect(result.totalCount, equals(42));
      expect(result.nextOffset, equals(50));
      expect(result.hasMore, isTrue);
    });

    test('hydrates REST videos with bulk stats (loops + views)', () async {
      when(() => funnelcake.getBulkVideoStats(any())).thenAnswer(
        (_) async => const BulkVideoStatsResponse(
          stats: {
            'a': BulkVideoStatsEntry(
              eventId: 'a',
              reactions: 6,
              comments: 1,
              reposts: 0,
              views: 14,
              uniqueViewers: 8,
              loops: 7,
              embeddedLoops: 142678928,
            ),
          },
        ),
      );
      stubAuthor(VideosByAuthorResponse(videos: [_stats(id: 'a')]));

      final result = await repository.getAuthorFeed(authorPubkey: _author);

      final video = result.videos.single;
      expect(video.originalLoops, equals(142678928));
      expect(video.rawTags['loops'], equals('142678928'));
      // Bulk stats supply both metrics, so the per-video endpoint is skipped.
      expect(video.rawTags['views'], equals('14'));
      expect(video.rawTags['unique_viewers'], equals('8'));
      verifyNever(() => funnelcake.getVideoViewStats(any()));
    });

    test(
      'live bulk loops never fill the archival originalLoops baseline',
      () async {
        // Bulk stats return a live computed `loops` alongside `views` for
        // native diVine videos. Writing it into originalLoops would both
        // double-count against views in totalLoops and, for classic Vines
        // hydrated from the relay, clobber the multi-million archival count.
        when(() => funnelcake.getBulkVideoStats(any())).thenAnswer(
          (_) async => const BulkVideoStatsResponse(
            stats: {
              'a': BulkVideoStatsEntry(
                eventId: 'a',
                reactions: 6,
                comments: 1,
                reposts: 0,
                views: 14,
                loops: 7,
              ),
            },
          ),
        );
        stubAuthor(VideosByAuthorResponse(videos: [_stats(id: 'a')]));

        final result = await repository.getAuthorFeed(authorPubkey: _author);

        final video = result.videos.single;
        expect(video.originalLoops, isNull);
        expect(video.rawTags['loops'], isNull);
        expect(video.rawTags['views'], equals('14'));
        expect(video.totalLoops, equals(14));
      },
    );

    test(
      'keeps live counts in nostr* fields so the display seed cannot '
      'double-count (#3384)',
      () async {
        // A native diVine video carries no archival likes/comments/reposts
        // rawTags, so toVideoEvent leaves original* null and seeds the live
        // nostr*Count from the author endpoint. Bulk stats report the SAME
        // live counts (one backend source). Filling original* from bulk stats
        // here would make the display seed (original* + nostr*) double.
        when(() => funnelcake.getBulkVideoStats(any())).thenAnswer(
          (_) async => const BulkVideoStatsResponse(
            stats: {
              'a': BulkVideoStatsEntry(
                eventId: 'a',
                reactions: 6,
                comments: 3,
                reposts: 2,
                views: 14,
                loops: 7,
              ),
            },
          ),
        );
        stubAuthor(
          VideosByAuthorResponse(
            videos: [_stats(id: 'a', reactions: 6, comments: 3, reposts: 2)],
          ),
        );

        final video = (await repository.getAuthorFeed(
          authorPubkey: _author,
        )).videos.single;

        // Archival baselines stay untouched; live counts land only in nostr*.
        expect(video.originalLikes, isNull);
        expect(video.originalComments, isNull);
        expect(video.originalReposts, isNull);
        expect(video.nostrLikeCount, equals(6));
        expect(video.nostrCommentCount, equals(3));
        expect(video.nostrRepostCount, equals(2));

        // The display seed is archival + live (see liveLikeCountSeed); with the
        // two sources split it equals the single backend count, not 2x.
        int seed(int? archival, int? live) => (archival ?? 0) + (live ?? 0);
        expect(seed(video.originalLikes, video.nostrLikeCount), equals(6));
        expect(
          seed(video.originalComments, video.nostrCommentCount),
          equals(3),
        );
        expect(seed(video.originalReposts, video.nostrRepostCount), equals(2));
      },
    );

    test(
      'treats a fractional view count as present, skipping the views endpoint',
      () async {
        stubAuthor(
          VideosByAuthorResponse(
            videos: [
              _stats(id: 'a', rawTags: {'views': '12.7'}),
            ],
          ),
        );

        final result = await repository.getAuthorFeed(authorPubkey: _author);

        expect(result.videos, hasLength(1));
        expect(result.videos.single.rawTags['views'], equals('12.7'));
        verify(() => funnelcake.getVideoViewStats('a')).called(1);
      },
    );

    test(
      'falls back to a page-size heuristic for nextOffset/hasMore',
      () async {
        stubAuthor(VideosByAuthorResponse(videos: [_stats(id: 'a')]));

        final result = await repository.getAuthorFeed(authorPubkey: _author);

        // Envelope omitted and the page is underfilled, so the repository
        // treats it as the final page instead of surfacing a dangling offset.
        expect(result.nextOffset, isNull);
        expect(result.hasMore, isFalse);
      },
    );

    test(
      'infers next offset from total count when legacy responses omit '
      'pagination metadata',
      () async {
        stubAuthor(
          VideosByAuthorResponse(
            videos: [
              _stats(id: 'a', dTag: 'a'),
              _stats(id: 'b', dTag: 'b'),
            ],
            totalCount: 5,
          ),
        );

        final result = await repository.getAuthorFeed(authorPubkey: _author);

        expect(result.videos.map((video) => video.id), ['a', 'b']);
        expect(result.nextOffset, equals(2));
        expect(result.hasMore, isTrue);
      },
    );

    test('drops backend-leaked p-tagged collaborator videos', () async {
      stubAuthor(
        VideosByAuthorResponse(
          videos: [
            _stats(id: 'mine'),
            _stats(id: 'leaked', pubkey: 'someone-else'),
          ],
        ),
      );

      final result = await repository.getAuthorFeed(authorPubkey: _author);

      expect(result.videos, hasLength(1));
      expect(result.videos.single.id, equals('mine'));
      expect(result.videos.single.pubkey, equals(_author));
    });

    test(
      'merges the relay seed with REST, deduping by addressable id',
      () async {
        // REST `toVideoEvent` derives stableId from the d-tag ('d' here); the
        // relay seed shares that addressable id so the two copies dedup — the
        // same identity the production relay snapshot and REST row collapse on.
        stubAuthor(VideosByAuthorResponse(videos: [_stats(id: 'a')]));

        final result = await repository.getAuthorFeed(
          authorPubkey: _author,
          relaySeed: [_seed('a', vineId: 'd', originalLikes: 9)],
        );

        expect(result.videos, hasLength(1));
        // Max-merge keeps the relay's higher engagement count (#3384).
        expect(result.videos.single.originalLikes, equals(9));
      },
    );

    test(
      'caches the initial page and serves it without a second fetch',
      () async {
        stubAuthor(VideosByAuthorResponse(videos: [_stats(id: 'a')]));

        await repository.getAuthorFeed(authorPubkey: _author);
        final second = await repository.getAuthorFeed(authorPubkey: _author);

        expect(second.videos, hasLength(1));
        expect(second.isFromCache, isTrue);
        verify(
          () => funnelcake.getVideosByAuthor(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).called(1);
      },
    );

    test('load-more pages (offset != null) bypass the cache', () async {
      stubAuthor(VideosByAuthorResponse(videos: [_stats(id: 'a')]));

      await repository.getAuthorFeed(authorPubkey: _author); // primes cache
      await repository.getAuthorFeed(authorPubkey: _author, offset: 50);

      verify(
        () => funnelcake.getVideosByAuthor(
          pubkey: _author,
          limit: any(named: 'limit'),
          offset: 50,
          before: any(named: 'before'),
        ),
      ).called(1);
    });

    test(
      'returns the relay seed alone when Funnelcake is unavailable',
      () async {
        when(() => funnelcake.isAvailable).thenReturn(false);

        final result = await repository.getAuthorFeed(
          authorPubkey: _author,
          relaySeed: [_seed('a')],
        );

        expect(result.videos.map((v) => v.id).toList(), equals(['a']));
        verifyNever(
          () => funnelcake.getVideosByAuthor(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        );
      },
    );

    test('falls back to the relay seed on FunnelcakeException', () async {
      when(
        () => funnelcake.getVideosByAuthor(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          before: any(named: 'before'),
        ),
      ).thenThrow(const FunnelcakeException('boom'));

      final result = await repository.getAuthorFeed(
        authorPubkey: _author,
        relaySeed: [_seed('a')],
      );

      expect(result.videos.map((v) => v.id).toList(), equals(['a']));
    });

    test(
      'rethrows on FunnelcakeException when there is no relay seed to serve',
      () async {
        when(
          () => funnelcake.getVideosByAuthor(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).thenThrow(const FunnelcakeException('boom'));

        // An empty result here would be indistinguishable from an author who
        // genuinely has no videos, and the profile would claim the account is
        // empty because the network was unreachable.
        await expectLater(
          repository.getAuthorFeed(authorPubkey: _author),
          throwsA(isA<FunnelcakeException>()),
        );
      },
    );
  });
}
