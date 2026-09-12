import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/videos_repository.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class MockVideoLocalStorage extends Mock implements VideoLocalStorage {}

/// [Random] that scripts the Classics archive-offset draws and records the
/// bounds it was asked for.
///
/// A fetch draws its offset first and shuffles its page last, so the armed
/// draw ([expectOffsetDraw]) identifies the offset by position; every other
/// call falls through to a seeded [Random] so shuffles stay deterministic.
/// [recordedMaxima] exposes the bounds, so tests can pin the page count the
/// offset was drawn over.
class _StubRandom implements Random {
  _StubRandom({int firstOffsetDraw = 0}) : _pendingOffsetDraw = firstOffsetDraw;

  final Random _shuffleRandom = Random(0);

  /// Every `max` passed to [nextInt], in call order.
  final List<int> recordedMaxima = [];

  int? _pendingOffsetDraw;

  /// Scripts the archive page the next offset draw lands on.
  ///
  /// A Classics fetch draws its offset before its first archive read, so the
  /// armed draw is consumed by the next `nextInt`. Everything after it — the
  /// page shuffle — falls through to [_shuffleRandom]. Position rather than
  /// `max` identifies the draw, because a shuffle of N items walks
  /// `nextInt(N)` down to `nextInt(2)` and would otherwise collide with the
  /// reachable-page count.
  /// Throws when the previously armed draw was never consumed, so a test that
  /// scripts an offset for a fetch that never draws one fails loudly instead
  /// of leaking the value into a later shuffle.
  void expectOffsetDraw(int page) {
    if (_pendingOffsetDraw != null) {
      throw StateError('Scripted Classics offset draw was never consumed');
    }
    _pendingOffsetDraw = page;
  }

  @override
  int nextInt(int max) {
    recordedMaxima.add(max);

    final offsetDraw = _pendingOffsetDraw;
    if (offsetDraw == null) return _shuffleRandom.nextInt(max);

    _pendingOffsetDraw = null;
    return offsetDraw;
  }

  @override
  bool nextBool() => _shuffleRandom.nextBool();

  @override
  double nextDouble() => _shuffleRandom.nextDouble();
}

/// Test helper that tracks content filter calls.
class TestContentFilter {
  TestContentFilter({this.blockedPubkeys = const {}});

  final Set<String> blockedPubkeys;
  final List<String> calls = [];

  bool call(String pubkey) {
    calls.add(pubkey);
    return blockedPubkeys.contains(pubkey);
  }
}

/// Test helper that tracks video event filter calls.
class TestVideoEventFilter {
  TestVideoEventFilter({this.shouldFilter = false});

  final bool shouldFilter;
  final List<VideoEvent> calls = [];

  bool call(VideoEvent video) {
    calls.add(video);
    return shouldFilter;
  }
}

/// Test helper that filters videos with specific hashtags.
class TestNsfwFilter {
  TestNsfwFilter({this.filterNsfw = true});

  final bool filterNsfw;
  final List<VideoEvent> calls = [];

  bool call(VideoEvent video) {
    calls.add(video);
    if (!filterNsfw) return false;

    // Check for NSFW hashtags
    for (final hashtag in video.hashtags) {
      final lowerHashtag = hashtag.toLowerCase();
      if (lowerHashtag == 'nsfw' || lowerHashtag == 'adult') {
        return true;
      }
    }

    // Check for content-warning tag
    if (video.rawTags.containsKey('content-warning')) {
      return true;
    }

    return false;
  }
}

void main() {
  group('VideosRepository', () {
    late MockNostrClient mockNostrClient;
    late VideosRepository repository;

    setUp(() {
      mockNostrClient = MockNostrClient();
      when(() => mockNostrClient.publicKey).thenReturn('');
      repository = VideosRepository(nostrClient: mockNostrClient);
    });

    test('generates non-empty unique recommendation session seeds', () {
      final first = generateRecommendationSessionSeed();
      final second = generateRecommendationSessionSeed();

      expect(first, isNotEmpty);
      expect(second, isNotEmpty);
      expect(second, isNot(first));
    });

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(LeaderboardPeriod.week);
      registerFallbackValue(PopularVideosVariant.classic);
      registerFallbackValue(VideoSearchSort.trending);
    });

    test('can be instantiated', () {
      expect(repository, isNotNull);
    });

    test('isVideoKnownDeleted delegates to the injected deletion filter', () {
      final visibleVideo = VideoEvent(
        id: 'visible-video',
        pubkey: 'pubkey',
        createdAt: 1704067200,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
        videoUrl: 'https://example.com/visible.mp4',
      );
      final deletedVideo = visibleVideo.copyWith(id: 'deleted-video');

      expect(repository.isVideoKnownDeleted(visibleVideo), isFalse);

      final repositoryWithDeletionFilter = VideosRepository(
        nostrClient: mockNostrClient,
        deletedFilter: (video) => video.id == deletedVideo.id,
      );

      expect(
        repositoryWithDeletionFilter.isVideoKnownDeleted(visibleVideo),
        isFalse,
      );
      expect(
        repositoryWithDeletionFilter.isVideoKnownDeleted(deletedVideo),
        isTrue,
      );
    });

    group('getNewVideos', () {
      group('Funnelcake API first', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
        });

        test('returns API results when Funnelcake succeeds', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => _recentPage([
              _createVideoStats(
                id: 'event-1',
                pubkey: 'pubkey-1',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/video.mp4',
              ),
            ]),
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = (await repositoryWithApi.getNewVideos()).videos;

          expect(result, hasLength(1));
          expect(
            result.first.videoUrl,
            equals('https://example.com/video.mp4'),
          );
          // Should NOT query Nostr relay
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test(
          'refresh merges newer relay videos ahead of API results',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getRecentVideosPage(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => _recentPage([
                _createVideoStats(
                  id: 'api-video',
                  pubkey: 'api-pubkey',
                  dTag: 'api-dtag',
                  videoUrl: 'https://example.com/api.mp4',
                ),
              ]),
            );
            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [
                _createVideoEvent(
                  id: 'relay-video',
                  pubkey: 'relay-pubkey',
                  videoUrl: 'https://example.com/relay.mp4',
                  createdAt: 1704067300,
                ),
              ],
            );

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = (await repositoryWithApi.getNewVideos(
              skipCache: true,
            )).videos;

            expect(result.map((video) => video.id), [
              'relay-video',
              'api-video',
            ]);
            verify(() => mockNostrClient.queryEvents(any())).called(1);
          },
        );

        test(
          'refresh does not reintroduce an edit older than the API page',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getRecentVideosPage(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => _recentPage([
                _createVideoStats(
                  id: 'newer-api-video',
                  pubkey: 'newer-api-pubkey',
                  dTag: 'newer-api-dtag',
                  videoUrl: 'https://example.com/newer-api.mp4',
                  createdAt: 2200,
                  publishedAt: 2200,
                ),
                _createVideoStats(
                  id: 'api-video',
                  pubkey: 'api-pubkey',
                  dTag: 'api-dtag',
                  videoUrl: 'https://example.com/api.mp4',
                  createdAt: 2000,
                  publishedAt: 2000,
                ),
              ]),
            );
            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [
                _createVideoEvent(
                  id: 'edited-old-video',
                  pubkey: 'old-pubkey',
                  videoUrl: 'https://example.com/edited-old.mp4',
                  createdAt: 3000,
                  extraTags: const [
                    ['published_at', '500'],
                  ],
                ),
                _createVideoEvent(
                  id: 'new-relay-video',
                  pubkey: 'new-pubkey',
                  videoUrl: 'https://example.com/new.mp4',
                  createdAt: 2500,
                ),
              ],
            );
            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = (await repositoryWithApi.getNewVideos(
              skipCache: true,
              limit: 3,
            )).videos;

            expect(
              result.map((video) => video.id),
              equals([
                'new-relay-video',
                'newer-api-video',
                'api-video',
              ]),
            );
          },
        );

        test('passes limit and before to Funnelcake API', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => _recentPage([
              _createVideoStats(
                id: 'event-1',
                pubkey: 'pubkey-1',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/video.mp4',
              ),
            ]),
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getNewVideos(limit: 10, until: 1704067200);

          verify(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: 10,
              before: 1704067200,
            ),
          ).called(1);
        });

        test(
          'paginates API pages with the opaque publication cursor',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            final requestedCursors = <String?>[];
            when(
              () => mockFunnelcakeClient.getRecentVideosPage(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer((invocation) async {
              return _recentPage([
                _createVideoStats(
                  id: 'edited-old-reply',
                  pubkey: 'test-pubkey',
                  dTag: 'edited-old-reply',
                  videoUrl: 'https://example.com/edited.mp4',
                  createdAt: 2000,
                  publishedAt: 1000,
                  rawTags: const {
                    'E': 'root-event-id',
                    'K': '34236',
                    'P': 'root-author',
                    'e': 'root-event-id',
                    'k': '34236',
                    'p': 'root-author',
                  },
                ),
                _createVideoStats(
                  id: 'visible-video',
                  pubkey: 'test-pubkey',
                  dTag: 'visible-video',
                  videoUrl: 'https://example.com/visible.mp4',
                  createdAt: 1900,
                  publishedAt: 1800,
                ),
              ], nextCursor: 'p:equal-timestamp-and-id');
            });
            when(
              () => mockFunnelcakeClient.getRecentVideosPage(
                limit: any(named: 'limit'),
                cursor: 'p:equal-timestamp-and-id',
              ),
            ).thenAnswer((_) async {
              requestedCursors.add('p:equal-timestamp-and-id');
              return _recentPage(<VideoStats>[], hasMore: false);
            });
            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            await repositoryWithApi.getNewVideos(limit: 2);

            expect(requestedCursors, equals(['p:equal-timestamp-and-id']));
          },
        );

        test('falls back to Nostr when Funnelcake throws', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenThrow(const FunnelcakeException('Network error'));

          final nostrEvent = _createVideoEvent(
            id: 'nostr-video',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/nostr.mp4',
            createdAt: 1704067200,
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [nostrEvent]);

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = (await repositoryWithApi.getNewVideos()).videos;

          expect(result, hasLength(1));
          expect(result.first.id, equals('nostr-video'));
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test(
          'does not replay relay page one when a cursor page fails',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getRecentVideosPage(
                limit: any(named: 'limit'),
                cursor: 'p:next-page',
              ),
            ).thenThrow(const FunnelcakeException('Network error'));

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repositoryWithApi.getNewVideos(
              cursor: 'p:next-page',
            );

            expect(result.videos, isEmpty);
            expect(result.hasMore, isFalse);
            verifyNever(() => mockNostrClient.queryEvents(any()));
          },
        );

        test(
          'trusts empty Funnelcake response without Nostr fallback',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getRecentVideosPage(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer((_) async => _recentPage(<VideoStats>[]));

            final nostrEvent = _createVideoEvent(
              id: 'nostr-video',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/nostr.mp4',
              createdAt: 1704067200,
            );
            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => [nostrEvent]);

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = (await repositoryWithApi.getNewVideos()).videos;

            expect(result, isEmpty);
            verifyNever(() => mockNostrClient.queryEvents(any()));
          },
        );

        test(
          'does not fall back when Funnelcake results are filtered locally',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getRecentVideosPage(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => _recentPage([
                _createVideoStats(
                  id: 'event-1',
                  pubkey: 'blocked-pubkey',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/video.mp4',
                ),
              ]),
            );

            final nostrEvent = _createVideoEvent(
              id: 'nostr-video',
              pubkey: 'allowed-pubkey',
              videoUrl: 'https://example.com/nostr.mp4',
              createdAt: 1704067200,
            );
            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => [nostrEvent]);

            final blockFilter = TestContentFilter(
              blockedPubkeys: {'blocked-pubkey'},
            );
            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
              blockFilter: blockFilter.call,
            );

            final result = (await repositoryWithApi.getNewVideos()).videos;

            expect(result, isEmpty);
            verifyNever(() => mockNostrClient.queryEvents(any()));
          },
        );

        test('skips API when Funnelcake client is null', () async {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          // Default repository has no Funnelcake client
          await repository.getNewVideos();

          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('skips API when Funnelcake is not available', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getNewVideos();

          verifyNever(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('applies content filters to API results', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => _recentPage([
              _createVideoStats(
                id: 'event-1',
                pubkey: 'blocked-pubkey',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/blocked.mp4',
              ),
              _createVideoStats(
                id: 'event-2',
                pubkey: 'allowed-pubkey',
                dTag: 'dtag-2',
                videoUrl: 'https://example.com/allowed.mp4',
              ),
            ]),
          );

          final blockFilter = TestContentFilter(
            blockedPubkeys: {'blocked-pubkey'},
          );
          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            blockFilter: blockFilter.call,
          );

          final result = (await repositoryWithApi.getNewVideos()).videos;

          expect(result, hasLength(1));
          expect(
            result.first.videoUrl,
            equals('https://example.com/allowed.mp4'),
          );
        });

        test('continues past a full API page of reply-only videos', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((invocation) async {
            final before = invocation.namedArguments[#before] as int?;
            final limit = invocation.namedArguments[#limit] as int? ?? 5;

            if (before != null) {
              return _recentPage([
                _createVideoStats(
                  id: 'feed-video',
                  pubkey: 'test-pubkey',
                  dTag: 'feed-dtag',
                  videoUrl: 'https://example.com/feed.mp4',
                  createdAt: 1704060000,
                ),
              ]);
            }

            return _recentPage(
              List.generate(
                limit,
                (index) => _createVideoStats(
                  id: 'video-reply-$index',
                  pubkey: 'test-pubkey',
                  dTag: 'reply-dtag-$index',
                  videoUrl: 'https://example.com/reply-$index.mp4',
                  createdAt: 1704070000 - index,
                  rawTags: const {
                    'E': 'root-event-id',
                    'K': '34236',
                    'P': 'root-author',
                    'e': 'root-event-id',
                    'k': '34236',
                    'p': 'root-author',
                  },
                ),
              ),
            );
          });

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = (await repositoryWithApi.getNewVideos()).videos;

          expect(result.map((video) => video.id), equals(['feed-video']));
          verify(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).called(2);
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test(
          'accumulates visible API videos across mixed reply-heavy pages',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getRecentVideosPage(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer((invocation) async {
              final before = invocation.namedArguments[#before] as int?;
              if (before == null) {
                return _recentPage([
                  _createVideoStats(
                    id: 'video-reply-1',
                    pubkey: 'test-pubkey',
                    dTag: 'reply-1',
                    videoUrl: 'https://example.com/reply-1.mp4',
                    createdAt: 1704070000,
                    rawTags: const {
                      'E': 'root-event-id',
                      'K': '34236',
                      'P': 'root-author',
                      'e': 'root-event-id',
                      'k': '34236',
                      'p': 'root-author',
                    },
                  ),
                  _createVideoStats(
                    id: 'video-reply-2',
                    pubkey: 'test-pubkey',
                    dTag: 'reply-2',
                    videoUrl: 'https://example.com/reply-2.mp4',
                    createdAt: 1704069999,
                    rawTags: const {
                      'E': 'root-event-id',
                      'K': '34236',
                      'P': 'root-author',
                      'e': 'root-event-id',
                      'k': '34236',
                      'p': 'root-author',
                    },
                  ),
                  _createVideoStats(
                    id: 'video-reply-3',
                    pubkey: 'test-pubkey',
                    dTag: 'reply-3',
                    videoUrl: 'https://example.com/reply-3.mp4',
                    createdAt: 1704069998,
                    rawTags: const {
                      'E': 'root-event-id',
                      'K': '34236',
                      'P': 'root-author',
                      'e': 'root-event-id',
                      'k': '34236',
                      'p': 'root-author',
                    },
                  ),
                  _createVideoStats(
                    id: 'video-reply-4',
                    pubkey: 'test-pubkey',
                    dTag: 'reply-4',
                    videoUrl: 'https://example.com/reply-4.mp4',
                    createdAt: 1704069997,
                    rawTags: const {
                      'E': 'root-event-id',
                      'K': '34236',
                      'P': 'root-author',
                      'e': 'root-event-id',
                      'k': '34236',
                      'p': 'root-author',
                    },
                  ),
                  _createVideoStats(
                    id: 'feed-video-1',
                    pubkey: 'test-pubkey',
                    dTag: 'feed-1',
                    videoUrl: 'https://example.com/feed-1.mp4',
                    createdAt: 1704069996,
                  ),
                ]);
              }

              return _recentPage([
                _createVideoStats(
                  id: 'feed-video-2',
                  pubkey: 'test-pubkey',
                  dTag: 'feed-2',
                  videoUrl: 'https://example.com/feed-2.mp4',
                  createdAt: 1704069000,
                ),
              ]);
            });

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = (await repositoryWithApi.getNewVideos(
              limit: 2,
            )).videos;

            expect(
              result.map((video) => video.id),
              equals(['feed-video-1', 'feed-video-2']),
            );
            verify(
              () => mockFunnelcakeClient.getRecentVideosPage(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).called(2);
          },
        );
      });

      test('returns empty list when no events found', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        final result = (await repository.getNewVideos()).videos;

        expect(result, isEmpty);
        verify(() => mockNostrClient.queryEvents(any())).called(1);
      });

      test('queries with correct filter for video kind', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        await repository.getNewVideos(limit: 10);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters, hasLength(1));
        expect(filters.first.kinds, contains(EventKind.videoVertical));
        expect(filters.first.limit, equals(10));
      });

      test('passes until parameter for pagination', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        const until = 1704067200; // 2024-01-01 00:00:00 UTC
        await repository.getNewVideos(until: until);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters.first.until, equals(until));
      });

      test('transforms valid events to VideoEvents', () async {
        final event = _createVideoEvent(
          id: 'test-id-123',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final result = (await repository.getNewVideos()).videos;

        expect(result, hasLength(1));
        expect(result.first.id, equals('test-id-123'));
        expect(result.first.videoUrl, equals('https://example.com/video.mp4'));
      });

      test('filters reply-tagged video events out of normal feeds', () async {
        final feedVideo = _createVideoEvent(
          id: 'feed-video',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/feed.mp4',
          createdAt: 1704067200,
        );
        final videoReply = _createVideoEvent(
          id: 'video-reply',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/reply.mp4',
          createdAt: 1704067201,
          extraTags: const [
            ['E', 'root-event-id', '', 'root-author'],
            ['K', '34236'],
            ['P', 'root-author'],
            ['e', 'root-event-id', '', 'root-author'],
            ['k', '34236'],
            ['p', 'root-author'],
          ],
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [feedVideo, videoReply]);

        final result = (await repository.getNewVideos()).videos;

        expect(result.map((video) => video.id), equals(['feed-video']));
      });

      test('continues past a full relay page of reply-only videos', () async {
        final feedVideo = _createVideoEvent(
          id: 'feed-video',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/feed.mp4',
          createdAt: 1704060000,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments.first as List<Filter>;
          final filter = filters.single;
          final limit = filter.limit ?? 5;

          if (filter.until != null) {
            return [feedVideo];
          }

          return List.generate(
            limit,
            (index) => _createVideoEvent(
              id: 'video-reply-$index',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/reply-$index.mp4',
              createdAt: 1704070000 - index,
              extraTags: const [
                ['E', 'root-event-id', '', 'root-author'],
                ['K', '34236'],
                ['P', 'root-author'],
                ['e', 'root-event-id', '', 'root-author'],
                ['k', '34236'],
                ['p', 'root-author'],
              ],
            ),
          );
        });

        final result = (await repository.getNewVideos()).videos;

        expect(result.map((video) => video.id), equals(['feed-video']));
        verify(() => mockNostrClient.queryEvents(any())).called(2);
      });

      test(
        'accumulates visible relay videos across mixed reply-heavy pages',
        () async {
          when(() => mockNostrClient.queryEvents(any())).thenAnswer((
            invocation,
          ) async {
            final filters =
                invocation.positionalArguments.first as List<Filter>;
            final filter = filters.single;

            if (filter.until == null) {
              return [
                _createVideoEvent(
                  id: 'video-reply-1',
                  pubkey: 'test-pubkey',
                  videoUrl: 'https://example.com/reply-1.mp4',
                  createdAt: 1704070000,
                  extraTags: const [
                    ['E', 'root-event-id', '', 'root-author'],
                    ['K', '34236'],
                    ['P', 'root-author'],
                    ['e', 'root-event-id', '', 'root-author'],
                    ['k', '34236'],
                    ['p', 'root-author'],
                  ],
                ),
                _createVideoEvent(
                  id: 'video-reply-2',
                  pubkey: 'test-pubkey',
                  videoUrl: 'https://example.com/reply-2.mp4',
                  createdAt: 1704069999,
                  extraTags: const [
                    ['E', 'root-event-id', '', 'root-author'],
                    ['K', '34236'],
                    ['P', 'root-author'],
                    ['e', 'root-event-id', '', 'root-author'],
                    ['k', '34236'],
                    ['p', 'root-author'],
                  ],
                ),
                _createVideoEvent(
                  id: 'video-reply-3',
                  pubkey: 'test-pubkey',
                  videoUrl: 'https://example.com/reply-3.mp4',
                  createdAt: 1704069998,
                  extraTags: const [
                    ['E', 'root-event-id', '', 'root-author'],
                    ['K', '34236'],
                    ['P', 'root-author'],
                    ['e', 'root-event-id', '', 'root-author'],
                    ['k', '34236'],
                    ['p', 'root-author'],
                  ],
                ),
                _createVideoEvent(
                  id: 'video-reply-4',
                  pubkey: 'test-pubkey',
                  videoUrl: 'https://example.com/reply-4.mp4',
                  createdAt: 1704069997,
                  extraTags: const [
                    ['E', 'root-event-id', '', 'root-author'],
                    ['K', '34236'],
                    ['P', 'root-author'],
                    ['e', 'root-event-id', '', 'root-author'],
                    ['k', '34236'],
                    ['p', 'root-author'],
                  ],
                ),
                _createVideoEvent(
                  id: 'feed-video-1',
                  pubkey: 'test-pubkey',
                  videoUrl: 'https://example.com/feed-1.mp4',
                  createdAt: 1704069996,
                ),
              ];
            }

            return [
              _createVideoEvent(
                id: 'feed-video-2',
                pubkey: 'test-pubkey',
                videoUrl: 'https://example.com/feed-2.mp4',
                createdAt: 1704069000,
              ),
            ];
          });

          final result = (await repository.getNewVideos(limit: 2)).videos;

          expect(
            result.map((video) => video.id),
            equals(['feed-video-1', 'feed-video-2']),
          );
          verify(() => mockNostrClient.queryEvents(any())).called(2);
        },
      );

      test('keeps reply-tagged videos when marked feed-visible', () async {
        final videoReply = _createVideoEvent(
          id: 'video-reply',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/reply.mp4',
          createdAt: 1704067201,
          extraTags: const [
            ['E', 'root-event-id', '', 'root-author'],
            ['K', '34236'],
            ['P', 'root-author'],
            ['e', 'root-event-id', '', 'root-author'],
            ['k', '34236'],
            ['p', 'root-author'],
            [videoReplyVisibilityTagName, videoReplyVisibilityFeedValue],
          ],
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [videoReply]);

        final result = (await repository.getNewVideos()).videos;

        expect(result.map((video) => video.id), equals(['video-reply']));
      });

      test('filters out videos without valid URL', () async {
        final validEvent = _createVideoEvent(
          id: 'valid-id',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );
        final invalidEvent = _createVideoEvent(
          id: 'invalid-id',
          pubkey: 'test-pubkey',
          videoUrl: null,
          createdAt: 1704067201,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [validEvent, invalidEvent]);

        final result = (await repository.getNewVideos()).videos;

        expect(result, hasLength(1));
        expect(result.first.id, equals('valid-id'));
      });

      test('sorts videos by creation time (newest first)', () async {
        final olderEvent = _createVideoEvent(
          id: 'older',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/old.mp4',
          createdAt: 1704067200,
        );
        final newerEvent = _createVideoEvent(
          id: 'newer',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/new.mp4',
          createdAt: 1704153600,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [olderEvent, newerEvent]);

        final result = (await repository.getNewVideos()).videos;

        expect(result, hasLength(2));
        expect(result.first.id, equals('newer'));
        expect(result.last.id, equals('older'));
      });

      group('in-memory cache', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;
        late InMemoryFeedCache feedCache;
        late VideosRepository repoWithCache;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          feedCache = InMemoryFeedCache();
          repoWithCache = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            inMemoryFeedCache: feedCache,
          );
        });

        test('returns cached result without network call', () async {
          when(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => _recentPage([
              _createVideoStats(
                id: 'v1',
                pubkey: 'p1',
                dTag: 'd1',
                videoUrl: 'https://example.com/v1.mp4',
              ),
            ]),
          );

          // First call → network
          await repoWithCache.getNewVideos();
          verify(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).called(1);

          // Second call → served from cache, no new network call
          final cached = (await repoWithCache.getNewVideos()).videos;
          verifyNever(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
          expect(cached, hasLength(1));
          expect(cached.first.id, equals('v1'));
        });

        test('skipCache bypasses the in-memory cache', () async {
          when(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => _recentPage([
              _createVideoStats(
                id: 'v1',
                pubkey: 'p1',
                dTag: 'd1',
                videoUrl: 'https://example.com/v1.mp4',
              ),
            ]),
          );

          // First call populates cache
          await repoWithCache.getNewVideos();

          // skipCache: true → hits network again
          await repoWithCache.getNewVideos(skipCache: true);
          verify(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).called(2); // 1 initial + 1 skip
        });

        // Session-start revalidation bypasses the cache read like skipCache,
        // but must NOT trigger the pull-to-refresh relay merge (#5913) — that
        // extra relay round-trip is reserved for explicit user refreshes.
        test(
          'revalidate bypasses the in-memory cache without the relay merge',
          () async {
            when(
              () => mockFunnelcakeClient.getRecentVideosPage(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => _recentPage([
                _createVideoStats(
                  id: 'v1',
                  pubkey: 'p1',
                  dTag: 'd1',
                  videoUrl: 'https://example.com/v1.mp4',
                ),
              ]),
            );

            // First call populates cache
            await repoWithCache.getNewVideos();

            // revalidate: true → hits network again, no relay enrichment
            final revalidated = (await repoWithCache.getNewVideos(
              revalidate: true,
            )).videos;
            verify(
              () => mockFunnelcakeClient.getRecentVideosPage(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).called(2); // 1 initial + 1 revalidate
            verifyNever(() => mockNostrClient.queryEvents(any()));
            expect(revalidated, hasLength(1));
            expect(revalidated.first.id, equals('v1'));
          },
        );

        test('pagination calls bypass cache', () async {
          when(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => _recentPage([
              _createVideoStats(
                id: 'v1',
                pubkey: 'p1',
                dTag: 'd1',
                videoUrl: 'https://example.com/v1.mp4',
              ),
            ]),
          );

          // Populate cache
          await repoWithCache.getNewVideos();

          // Pagination (until != null) always hits network
          await repoWithCache.getNewVideos(until: 1000);
          verify(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).called(2);
        });

        // Warms the cache with a page of 2, then reads it back asking for 5 —
        // the home feed's New mode warming what the Explore New tab then
        // opens.
        Future<HomeFeedResult> warmSmallPageThenReadLarger() async {
          when(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((invocation) async {
            final limit = invocation.namedArguments[#limit] as int;
            return _recentPage([
              for (var i = 0; i < limit; i++)
                _createVideoStats(
                  id: 'v$i',
                  pubkey: 'p$i',
                  dTag: 'd$i',
                  videoUrl: 'https://example.com/v$i.mp4',
                ),
            ]);
          });

          await repoWithCache.getNewVideos(limit: 2);
          return repoWithCache.getNewVideos(limit: 5);
        }

        // Explore must get that smaller page instantly — re-fetching it made
        // opening Explore reload from scratch.
        test('serves a smaller cached page to a larger limit', () async {
          final cached = await warmSmallPageThenReadLarger();

          expect(cached.videos, hasLength(2));
          verify(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).called(1);
        });

        // …and that shorter page must not read as "nothing more to load".
        // Deriving it from the video count is what stopped the Explore grid
        // from paginating on scroll.
        test('reports more content behind a smaller cached page', () async {
          final cached = await warmSmallPageThenReadLarger();

          expect(cached.hasMore, isTrue);
        });

        test('reports no more content when the source ran dry', () async {
          when(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => _recentPage([
              _createVideoStats(
                id: 'v1',
                pubkey: 'p1',
                dTag: 'd1',
                videoUrl: 'https://example.com/v1.mp4',
              ),
            ]),
          );

          final page = await repoWithCache.getNewVideos(limit: 5);

          expect(page.videos, hasLength(1));
          expect(page.hasMore, isFalse);
        });

        // The client drops rows with an empty id or videoUrl before the
        // repository ever sees them, so a full server page can arrive short.
        // Reading that as exhaustion pinned `hasMore: false` into the cache
        // for the rest of the process and killed pagination.
        test('keeps paging when the server filled the page but a row was '
            'dropped', () async {
          var call = 0;
          when(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((invocation) async {
            final limit = invocation.namedArguments[#limit] as int;
            final offset = call++ * limit;
            return _recentPage(
              [
                for (var i = 0; i < limit - 1; i++)
                  _createVideoStats(
                    id: 'v${offset + i}',
                    pubkey: 'p${offset + i}',
                    dTag: 'd${offset + i}',
                    videoUrl: 'https://example.com/v${offset + i}.mp4',
                    createdAt: 1704060000 - offset - i,
                  ),
              ],
              // The server sent a full page; one row was unusable.
              serverItemCount: limit,
            );
          });

          final page = await repoWithCache.getNewVideos(limit: 4);

          expect(page.videos, hasLength(4));
          expect(page.hasMore, isTrue);
        });

        test('prefers the server hasMore flag over the page count', () async {
          when(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((invocation) async {
            final limit = invocation.namedArguments[#limit] as int;
            return _recentPage(
              [
                for (var i = 0; i < limit; i++)
                  _createVideoStats(
                    id: 'v$i',
                    pubkey: 'p$i',
                    dTag: 'd$i',
                    videoUrl: 'https://example.com/v$i.mp4',
                    createdAt: 1704060000 - i,
                  ),
              ],
              hasMore: false,
            );
          });

          final page = await repoWithCache.getNewVideos(limit: 3);

          expect(page.videos, hasLength(3));
          expect(page.hasMore, isFalse);
        });
      });

      group('bulk stats hydration', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;
        late VideosRepository repositoryWithApi;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );
        });

        test(
          'hydrates Funnelcake videos that lack views with bulk stats',
          () async {
            when(
              () => mockFunnelcakeClient.getRecentVideosPage(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => _recentPage([
                _createVideoStats(
                  id: 'event-1',
                  pubkey: 'author',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/video.mp4',
                ),
              ]),
            );
            when(
              () => mockFunnelcakeClient.getBulkVideoStats(['event-1']),
            ).thenAnswer(
              (_) async => const BulkVideoStatsResponse(
                stats: {
                  'event-1': BulkVideoStatsEntry(
                    eventId: 'event-1',
                    reactions: 6,
                    comments: 1,
                    reposts: 0,
                    views: 14,
                    loops: 7,
                  ),
                },
              ),
            );

            final result = (await repositoryWithApi.getNewVideos()).videos;

            expect(result, hasLength(1));
            expect(result.first.rawTags['views'], equals('14'));
            // Live computed loops (7) must not inflate totalLoops; only
            // views (14) and archival embedded loops count.
            expect(result.first.totalLoops, equals(14));
            verify(
              () => mockFunnelcakeClient.getBulkVideoStats(['event-1']),
            ).called(1);
          },
        );

        test(
          'hydrates relay-fallback videos that lack views with bulk stats',
          () async {
            when(
              () => mockFunnelcakeClient.getRecentVideosPage(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenThrow(const FunnelcakeException('Network error'));

            final relayEvent = _createVideoEvent(
              id: 'relay-event',
              pubkey: 'author',
              videoUrl: 'https://example.com/relay.mp4',
              createdAt: 1704067200,
            );
            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => [relayEvent]);
            when(
              () => mockFunnelcakeClient.getBulkVideoStats(['relay-event']),
            ).thenAnswer(
              (_) async => const BulkVideoStatsResponse(
                stats: {
                  'relay-event': BulkVideoStatsEntry(
                    eventId: 'relay-event',
                    reactions: 3,
                    comments: 1,
                    reposts: 0,
                    views: 11,
                  ),
                },
              ),
            );

            final result = (await repositoryWithApi.getNewVideos()).videos;

            expect(result, hasLength(1));
            expect(result.first.rawTags['views'], equals('11'));
            expect(result.first.totalLoops, equals(11));
            verify(
              () => mockFunnelcakeClient.getBulkVideoStats(['relay-event']),
            ).called(1);
          },
        );

        test(
          'keeps relay archival tags separate from bulk live engagement stats',
          () async {
            when(
              () => mockFunnelcakeClient.getRecentVideosPage(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenThrow(const FunnelcakeException('Network error'));

            final relayEvent = _createVideoEvent(
              id: 'relay-event',
              pubkey: 'author',
              videoUrl: 'https://example.com/relay.mp4',
              createdAt: 1704067200,
              extraTags: const [
                ['likes', '273622'],
                ['comments', '6023'],
                ['reposts', '122059'],
              ],
            );
            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => [relayEvent]);
            when(
              () => mockFunnelcakeClient.getBulkVideoStats(['relay-event']),
            ).thenAnswer(
              (_) async => const BulkVideoStatsResponse(
                stats: {
                  'relay-event': BulkVideoStatsEntry(
                    eventId: 'relay-event',
                    reactions: 5,
                    comments: 2,
                    reposts: 3,
                    views: 11,
                  ),
                },
              ),
            );

            final result = (await repositoryWithApi.getNewVideos()).videos;

            expect(result, hasLength(1));
            expect(result.first.originalLikes, equals(273622));
            expect(result.first.nostrLikeCount, equals(5));
            expect(result.first.totalLikes, equals(273627));
            expect(result.first.originalComments, equals(6023));
            expect(result.first.nostrCommentCount, equals(2));
            expect(result.first.originalReposts, equals(122059));
            expect(result.first.nostrRepostCount, equals(3));
          },
        );

        test(
          'does not double count REST stats when bulk hydration also returns '
          'them',
          () async {
            when(
              () => mockFunnelcakeClient.getRecentVideosPage(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => _recentPage([
                _createVideoStats(
                  id: 'event-1',
                  pubkey: 'author',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/video.mp4',
                  reactions: 2,
                  comments: 1,
                ),
              ]),
            );
            when(
              () => mockFunnelcakeClient.getBulkVideoStats(['event-1']),
            ).thenAnswer(
              (_) async => const BulkVideoStatsResponse(
                stats: {
                  'event-1': BulkVideoStatsEntry(
                    eventId: 'event-1',
                    reactions: 2,
                    comments: 1,
                    reposts: 0,
                    views: 14,
                  ),
                },
              ),
            );

            final result = (await repositoryWithApi.getNewVideos()).videos;

            expect(result, hasLength(1));
            expect(result.first.originalLikes, isNull);
            expect(result.first.nostrLikeCount, equals(2));
            expect(result.first.totalLikes, equals(2));
            expect(result.first.originalComments, isNull);
            expect(result.first.nostrCommentCount, equals(1));
            expect(
              (result.first.originalComments ?? 0) +
                  (result.first.nostrCommentCount ?? 0),
              equals(1),
            );
            expect(result.first.originalReposts, isNull);
            expect(result.first.nostrRepostCount, equals(0));
            expect(
              (result.first.originalReposts ?? 0) +
                  (result.first.nostrRepostCount ?? 0),
              equals(0),
            );
            verify(
              () => mockFunnelcakeClient.getBulkVideoStats(['event-1']),
            ).called(1);
          },
        );

        test('caches the hydrated videos, not the un-hydrated ones', () async {
          final feedCache = InMemoryFeedCache();
          final repoWithCache = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            inMemoryFeedCache: feedCache,
          );
          when(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => _recentPage([
              _createVideoStats(
                id: 'event-1',
                pubkey: 'author',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/video.mp4',
              ),
            ]),
          );
          when(
            () => mockFunnelcakeClient.getBulkVideoStats(['event-1']),
          ).thenAnswer(
            (_) async => const BulkVideoStatsResponse(
              stats: {
                'event-1': BulkVideoStatsEntry(
                  eventId: 'event-1',
                  reactions: 0,
                  comments: 0,
                  reposts: 0,
                  views: 14,
                ),
              },
            ),
          );

          await repoWithCache.getNewVideos();
          final cached = (await repoWithCache.getNewVideos()).videos;

          expect(cached.first.rawTags['views'], equals('14'));
          expect(cached.first.totalLoops, equals(14));
          verify(
            () => mockFunnelcakeClient.getBulkVideoStats(['event-1']),
          ).called(1);
        });
      });
    });

    group('getHomeFeedVideos', () {
      group('Funnelcake API first', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          when(
            () => mockFunnelcakeClient.getBulkVideoStats(any()),
          ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
        });

        test('returns API results when Funnelcake succeeds', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResponse(
              videos: [
                _createVideoStats(
                  id: 'event-1',
                  pubkey: 'followed-user',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/video.mp4',
                ),
              ],
              hasMore: true,
              nextCursor: 1704067100,
            ),
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['followed-user'],
            userPubkey: 'my-pubkey',
            limit: 101,
          );

          expect(result.videos, hasLength(1));
          expect(
            result.videos.first.videoUrl,
            equals('https://example.com/video.mp4'),
          );
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test(
          'preserves the Funnelcake page order for the Following feed',
          () async {
            // The Following feed stays revision-ordered server-side and
            // pages on a revision-time `next_cursor`. Re-sorting the page on
            // publication time would order rows against the clock the cursor
            // walks, so rows on a later page can be newer by publication than
            // rows already rendered above them.
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getHomeFeed(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => HomeFeedResponse(
                videos: [
                  _createVideoStats(
                    id: 'revised-recently',
                    pubkey: 'followed-user',
                    dTag: 'dtag-1',
                    videoUrl: 'https://example.com/1.mp4',
                    createdAt: 2000,
                    publishedAt: 1000,
                  ),
                  _createVideoStats(
                    id: 'published-later',
                    pubkey: 'followed-user',
                    dTag: 'dtag-2',
                    videoUrl: 'https://example.com/2.mp4',
                    createdAt: 1900,
                    publishedAt: 1800,
                  ),
                ],
              ),
            );

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repositoryWithApi.getHomeFeedVideos(
              authors: ['followed-user'],
              userPubkey: 'my-pubkey',
              limit: 10,
            );

            expect(
              result.videos.map((video) => video.id),
              equals(['revised-recently', 'published-later']),
            );
          },
        );

        test('hydrates sparse API results with bulk loop stats', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResponse(
              videos: [
                _createVideoStats(
                  id: 'event-1',
                  pubkey: 'followed-user',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/video.mp4',
                  loops: 0,
                ),
              ],
            ),
          );
          when(
            () => mockFunnelcakeClient.getBulkVideoStats(['event-1']),
          ).thenAnswer(
            (_) async => const BulkVideoStatsResponse(
              stats: {
                'event-1': BulkVideoStatsEntry(
                  eventId: 'event-1',
                  reactions: 0,
                  comments: 0,
                  reposts: 0,
                  views: 42,
                ),
              },
            ),
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['followed-user'],
            userPubkey: 'my-pubkey',
            limit: 101,
          );

          expect(result.videos, hasLength(1));
          expect(result.videos.first.rawTags['views'], equals('42'));
          expect(result.videos.first.totalLoops, equals(42));
          verify(
            () => mockFunnelcakeClient.getBulkVideoStats(['event-1']),
          ).called(1);
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test(
          'hydrates missing loops without replacing existing views',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getHomeFeed(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => HomeFeedResponse(
                videos: [
                  _createVideoStats(
                    id: 'event-1',
                    pubkey: 'followed-user',
                    dTag: 'dtag-1',
                    videoUrl: 'https://example.com/video.mp4',
                    views: 7,
                  ),
                ],
              ),
            );
            when(
              () => mockFunnelcakeClient.getBulkVideoStats(['event-1']),
            ).thenAnswer(
              (_) async => const BulkVideoStatsResponse(
                stats: {
                  'event-1': BulkVideoStatsEntry(
                    eventId: 'event-1',
                    reactions: 0,
                    comments: 0,
                    reposts: 0,
                    embeddedLoops: 5,
                    views: 42,
                  ),
                },
              ),
            );

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repositoryWithApi.getHomeFeedVideos(
              authors: ['followed-user'],
              userPubkey: 'my-pubkey',
            );

            expect(result.videos, hasLength(1));
            expect(result.videos.first.rawTags['views'], equals('7'));
            expect(result.videos.first.totalLoops, equals(12));
            verify(
              () => mockFunnelcakeClient.getBulkVideoStats(['event-1']),
            ).called(1);
            verifyNever(() => mockNostrClient.queryEvents(any()));
          },
        );

        test('chunks bulk stat hydration for large API result sets', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResponse(
              videos: List.generate(
                101,
                (index) => _createVideoStats(
                  id: 'event-$index',
                  pubkey: 'followed-user',
                  dTag: 'dtag-$index',
                  videoUrl: 'https://example.com/video-$index.mp4',
                  loops: 0,
                ),
              ),
            ),
          );
          when(() => mockFunnelcakeClient.getBulkVideoStats(any())).thenAnswer((
            invocation,
          ) async {
            final ids = invocation.positionalArguments.single as List<String>;
            return BulkVideoStatsResponse(
              stats: {
                for (final id in ids)
                  id: BulkVideoStatsEntry(
                    eventId: id,
                    reactions: 0,
                    comments: 0,
                    reposts: 0,
                    views: int.parse(id.split('-').last) + 1,
                  ),
              },
            );
          });

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['followed-user'],
            userPubkey: 'my-pubkey',
            limit: 101,
          );

          expect(result.videos, hasLength(101));
          final firstVideo = result.videos.firstWhere(
            (video) => video.id == 'event-0',
          );
          final lastVideo = result.videos.firstWhere(
            (video) => video.id == 'event-100',
          );
          expect(firstVideo.totalLoops, equals(1));
          expect(lastVideo.totalLoops, equals(101));
          final captured = verify(
            () => mockFunnelcakeClient.getBulkVideoStats(captureAny()),
          ).captured;
          expect(captured, hasLength(2));
          expect(captured.first as List<String>, hasLength(100));
          expect(captured.last as List<String>, hasLength(1));
          expect(
            captured.expand((ids) => ids as List<String>),
            containsAll(['event-0', 'event-100']),
          );
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test(
          'skips bulk stats when API results already include loops and views',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getHomeFeed(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => HomeFeedResponse(
                videos: [
                  _createVideoStats(
                    id: 'event-1',
                    pubkey: 'followed-user',
                    dTag: 'dtag-1',
                    videoUrl: 'https://example.com/video.mp4',
                    loops: 5,
                    views: 7,
                  ),
                ],
              ),
            );

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repositoryWithApi.getHomeFeedVideos(
              authors: ['followed-user'],
              userPubkey: 'my-pubkey',
            );

            expect(result.videos, hasLength(1));
            expect(result.videos.first.rawTags['views'], equals('7'));
            expect(result.videos.first.totalLoops, equals(12));
            verifyNever(() => mockFunnelcakeClient.getBulkVideoStats(any()));
            verifyNever(() => mockNostrClient.queryEvents(any()));
          },
        );

        test(
          'leaves videos unchanged when bulk stats omit their event id',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getHomeFeed(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => HomeFeedResponse(
                videos: [
                  _createVideoStats(
                    id: 'event-1',
                    pubkey: 'followed-user',
                    dTag: 'dtag-1',
                    videoUrl: 'https://example.com/video-1.mp4',
                    loops: 0,
                  ),
                  _createVideoStats(
                    id: 'event-2',
                    pubkey: 'followed-user',
                    dTag: 'dtag-2',
                    videoUrl: 'https://example.com/video-2.mp4',
                    loops: 0,
                  ),
                ],
              ),
            );
            when(
              () => mockFunnelcakeClient.getBulkVideoStats([
                'event-1',
                'event-2',
              ]),
            ).thenAnswer(
              (_) async => const BulkVideoStatsResponse(
                stats: {
                  'event-1': BulkVideoStatsEntry(
                    eventId: 'event-1',
                    reactions: 0,
                    comments: 0,
                    reposts: 0,
                    views: 42,
                  ),
                },
              ),
            );

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repositoryWithApi.getHomeFeedVideos(
              authors: ['followed-user'],
              userPubkey: 'my-pubkey',
            );

            expect(result.videos, hasLength(2));
            expect(result.videos.first.rawTags['views'], equals('42'));
            expect(result.videos.first.totalLoops, equals(42));
            expect(result.videos.last.id, equals('event-2'));
            expect(result.videos.last.rawTags['views'], isNull);
            expect(result.videos.last.totalLoops, equals(0));
            verify(
              () => mockFunnelcakeClient.getBulkVideoStats([
                'event-1',
                'event-2',
              ]),
            ).called(1);
            verifyNever(() => mockNostrClient.queryEvents(any()));
          },
        );

        test('maps REST moderation labels to moderationLabels '
            '(not contentWarningLabels) and does not apply warn', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResponse(
              videos: [
                _createVideoStats(
                  id: 'event-1',
                  pubkey: 'followed-user',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/video.mp4',
                  moderationLabels: ['violence'],
                ),
              ],
            ),
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            // ML moderation labels should NOT trigger warn
            warningLabelsResolver: (video) => video.contentWarningLabels
                .where((label) => label == 'violence')
                .toList(),
          );

          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['followed-user'],
            userPubkey: 'my-pubkey',
          );

          expect(result.videos, hasLength(1));
          // Moderation labels go to moderationLabels, not contentWarningLabels
          expect(result.videos.first.contentWarningLabels, isEmpty);
          expect(result.videos.first.moderationLabels, equals(['violence']));
          // ML labels should not trigger warn behaviour
          expect(result.videos.first.warnLabels, isEmpty);
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test('clears stale warn labels when resolver returns none', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResponse(
              videos: [
                _VideoStatsWithWarnLabels(
                  base: _createVideoStats(
                    id: 'event-1',
                    pubkey: 'followed-user',
                    dTag: 'dtag-1',
                    videoUrl: 'https://example.com/video.mp4',
                    moderationLabels: ['violence'],
                  ),
                  warnLabels: const ['violence'],
                ),
              ],
            ),
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            warningLabelsResolver: (_) => const <String>[],
          );

          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['followed-user'],
            userPubkey: 'my-pubkey',
          );

          expect(result.videos, hasLength(1));
          // Moderation labels go to moderationLabels, not contentWarningLabels
          expect(result.videos.first.contentWarningLabels, isEmpty);
          expect(result.videos.first.moderationLabels, equals(['violence']));
          expect(result.videos.first.warnLabels, isEmpty);
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test('applies non-empty warn labels from resolver', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResponse(
              videos: [
                _createVideoStats(
                  id: 'event-1',
                  pubkey: 'followed-user',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/video.mp4',
                ),
              ],
            ),
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            warningLabelsResolver: (_) => const ['nudity'],
          );

          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['followed-user'],
            userPubkey: 'my-pubkey',
          );

          expect(result.videos, hasLength(1));
          expect(result.videos.first.warnLabels, equals(['nudity']));
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test('filters hidden labels from REST moderation labels', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResponse(
              videos: [
                _createVideoStats(
                  id: 'event-1',
                  pubkey: 'followed-user',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/video.mp4',
                  moderationLabels: ['nudity'],
                ),
              ],
            ),
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            // Moderation labels now go to video.moderationLabels
            contentFilter: (video) => video.moderationLabels.contains('nudity'),
          );
          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['followed-user'],
            userPubkey: 'my-pubkey',
          );

          expect(result.videos, isEmpty);
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test('passes params to Funnelcake API', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => const HomeFeedResponse(videos: []));
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getHomeFeedVideos(
            authors: ['user1'],
            userPubkey: 'my-pubkey',
            limit: 10,
            until: 1704067200,
          );

          verify(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: 'my-pubkey',
              limit: 10,
              before: 1704067200,
            ),
          ).called(1);
        });

        test('falls back to Nostr when Funnelcake throws', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenThrow(const FunnelcakeException('Network error'));

          final nostrEvent = _createVideoEvent(
            id: 'nostr-video',
            pubkey: 'followed-user',
            videoUrl: 'https://example.com/nostr.mp4',
            createdAt: 1704067200,
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [nostrEvent]);

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['followed-user'],
            userPubkey: 'my-pubkey',
          );

          expect(result.videos, hasLength(1));
          expect(result.videos.first.id, equals('nostr-video'));
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('hydrates Nostr fallback videos with bulk stats', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenThrow(const FunnelcakeException('Network error'));

          final nostrEvent = _createVideoEvent(
            id: 'nostr-video',
            pubkey: 'followed-user',
            videoUrl: 'https://example.com/nostr.mp4',
            createdAt: 1704067200,
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [nostrEvent]);
          when(
            () => mockFunnelcakeClient.getBulkVideoStats(['nostr-video']),
          ).thenAnswer(
            (_) async => const BulkVideoStatsResponse(
              stats: {
                'nostr-video': BulkVideoStatsEntry(
                  eventId: 'nostr-video',
                  reactions: 3,
                  comments: 1,
                  reposts: 2,
                  views: 11,
                ),
              },
            ),
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['followed-user'],
            userPubkey: 'my-pubkey',
          );

          expect(result.videos, hasLength(1));
          expect(result.videos.first.rawTags['views'], equals('11'));
          expect(result.videos.first.totalLoops, equals(11));
          expect(result.videos.first.nostrLikeCount, equals(3));
          expect(result.videos.first.nostrCommentCount, equals(1));
          expect(result.videos.first.nostrRepostCount, equals(2));
          verify(
            () => mockFunnelcakeClient.getBulkVideoStats(['nostr-video']),
          ).called(1);
        });

        test(
          'returns un-hydrated API videos when bulk stats hydration throws',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getHomeFeed(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => HomeFeedResponse(
                videos: [
                  _createVideoStats(
                    id: 'event-1',
                    pubkey: 'followed-user',
                    dTag: 'dtag-1',
                    videoUrl: 'https://example.com/video.mp4',
                  ),
                ],
              ),
            );
            when(
              () => mockFunnelcakeClient.getBulkVideoStats(any()),
            ).thenThrow(const FunnelcakeException('bulk stats down'));

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repositoryWithApi.getHomeFeedVideos(
              authors: ['followed-user'],
              userPubkey: 'my-pubkey',
            );

            expect(result.videos, hasLength(1));
            expect(result.videos.first.id, equals('event-1'));
            expect(result.videos.first.rawTags['views'], isNull);
            expect(result.videos.first.totalLoops, equals(0));
            verify(
              () => mockFunnelcakeClient.getBulkVideoStats(['event-1']),
            ).called(1);
            verifyNever(() => mockNostrClient.queryEvents(any()));
          },
        );

        test('returns un-hydrated Nostr fallback videos when bulk stats '
            'hydration throws', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenThrow(const FunnelcakeException('Network error'));

          final nostrEvent = _createVideoEvent(
            id: 'nostr-video',
            pubkey: 'followed-user',
            videoUrl: 'https://example.com/nostr.mp4',
            createdAt: 1704067200,
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [nostrEvent]);
          when(
            () => mockFunnelcakeClient.getBulkVideoStats(any()),
          ).thenThrow(const FunnelcakeException('bulk stats down'));

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['followed-user'],
            userPubkey: 'my-pubkey',
          );

          expect(result.videos, hasLength(1));
          expect(result.videos.first.id, equals('nostr-video'));
          expect(result.videos.first.rawTags['views'], isNull);
          expect(result.videos.first.nostrLikeCount, isNull);
          verify(
            () => mockFunnelcakeClient.getBulkVideoStats(['nostr-video']),
          ).called(1);
        });

        test(
          'trusts empty Funnelcake home feed without Nostr fallback',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getHomeFeed(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer((_) async => const HomeFeedResponse(videos: []));

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repositoryWithApi.getHomeFeedVideos(
              authors: ['followed-user'],
              userPubkey: 'my-pubkey',
            );

            expect(result.videos, isEmpty);
            verifyNever(() => mockNostrClient.queryEvents(any()));
          },
        );

        test('skips API when userPubkey is null', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getHomeFeedVideos(
            authors: ['user1'],
            // No userPubkey
          );

          verifyNever(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('uses NostrClient public key when userPubkey is null', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(() => mockNostrClient.publicKey).thenReturn('my-pubkey');
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResponse(
              videos: [
                _createVideoStats(
                  id: 'event-1',
                  pubkey: 'followed-user',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/video.mp4',
                ),
              ],
            ),
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['followed-user'],
          );

          expect(result.videos, hasLength(1));
          verify(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: 'my-pubkey',
              limit: 25,
            ),
          ).called(1);
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test('skips API when Funnelcake is not available', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getHomeFeedVideos(
            authors: ['user1'],
            userPubkey: 'my-pubkey',
          );

          verifyNever(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('applies content filters to API results', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResponse(
              videos: [
                _createVideoStats(
                  id: 'event-1',
                  pubkey: 'blocked-pubkey',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/blocked.mp4',
                ),
                _createVideoStats(
                  id: 'event-2',
                  pubkey: 'allowed-pubkey',
                  dTag: 'dtag-2',
                  videoUrl: 'https://example.com/allowed.mp4',
                ),
              ],
            ),
          );

          final blockFilter = TestContentFilter(
            blockedPubkeys: {'blocked-pubkey'},
          );
          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            blockFilter: blockFilter.call,
          );

          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['blocked-pubkey', 'allowed-pubkey'],
            userPubkey: 'my-pubkey',
          );

          expect(result.videos, hasLength(1));
          expect(
            result.videos.first.videoUrl,
            equals('https://example.com/allowed.mp4'),
          );
        });

        test(
          'continues past a full API home page of reply-only videos',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getHomeFeed(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer((invocation) async {
              final before = invocation.namedArguments[#before] as int?;
              final limit = invocation.namedArguments[#limit] as int? ?? 5;

              if (before != null) {
                return HomeFeedResponse(
                  videos: [
                    _createVideoStats(
                      id: 'feed-video',
                      pubkey: 'followed-user',
                      dTag: 'feed-dtag',
                      videoUrl: 'https://example.com/feed.mp4',
                      createdAt: 1704060000,
                    ),
                  ],
                );
              }

              return HomeFeedResponse(
                videos: List.generate(
                  limit,
                  (index) => _createVideoStats(
                    id: 'video-reply-$index',
                    pubkey: 'followed-user',
                    dTag: 'reply-dtag-$index',
                    videoUrl: 'https://example.com/reply-$index.mp4',
                    createdAt: 1704070000 - index,
                    rawTags: const {
                      'E': 'root-event-id',
                      'K': '34236',
                      'P': 'root-author',
                      'e': 'root-event-id',
                      'k': '34236',
                      'p': 'root-author',
                    },
                  ),
                ),
                hasMore: true,
                nextCursor: 1704069000,
              );
            });

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repositoryWithApi.getHomeFeedVideos(
              authors: ['followed-user'],
              userPubkey: 'my-pubkey',
            );

            expect(result.videos.map((video) => video.id), ['feed-video']);
            expect(result.followingPageCount, 2);
            verify(
              () => mockFunnelcakeClient.getHomeFeed(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).called(2);
            verifyNever(() => mockNostrClient.queryEvents(any()));
          },
        );

        test(
          'accumulates visible API home videos across mixed reply-heavy pages',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getHomeFeed(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer((invocation) async {
              final before = invocation.namedArguments[#before] as int?;
              if (before == null) {
                return HomeFeedResponse(
                  videos: [
                    _createVideoStats(
                      id: 'video-reply-1',
                      pubkey: 'followed-user',
                      dTag: 'reply-1',
                      videoUrl: 'https://example.com/reply-1.mp4',
                      createdAt: 1704070000,
                      rawTags: const {
                        'E': 'root-event-id',
                        'K': '34236',
                        'P': 'root-author',
                        'e': 'root-event-id',
                        'k': '34236',
                        'p': 'root-author',
                      },
                    ),
                    _createVideoStats(
                      id: 'video-reply-2',
                      pubkey: 'followed-user',
                      dTag: 'reply-2',
                      videoUrl: 'https://example.com/reply-2.mp4',
                      createdAt: 1704069999,
                      rawTags: const {
                        'E': 'root-event-id',
                        'K': '34236',
                        'P': 'root-author',
                        'e': 'root-event-id',
                        'k': '34236',
                        'p': 'root-author',
                      },
                    ),
                    _createVideoStats(
                      id: 'feed-video-1',
                      pubkey: 'followed-user',
                      dTag: 'feed-1',
                      videoUrl: 'https://example.com/feed-1.mp4',
                      createdAt: 1704069998,
                    ),
                  ],
                  hasMore: true,
                  nextCursor: 1704069000,
                );
              }

              return HomeFeedResponse(
                videos: [
                  _createVideoStats(
                    id: 'feed-video-2',
                    pubkey: 'followed-user',
                    dTag: 'feed-2',
                    videoUrl: 'https://example.com/feed-2.mp4',
                    createdAt: 1704068000,
                  ),
                ],
              );
            });

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repositoryWithApi.getHomeFeedVideos(
              authors: ['followed-user'],
              userPubkey: 'my-pubkey',
              limit: 2,
            );

            expect(
              result.videos.map((video) => video.id),
              equals(['feed-video-1', 'feed-video-2']),
            );
            verify(
              () => mockFunnelcakeClient.getHomeFeed(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).called(2);
          },
        );
      });

      test('returns empty list when authors is empty '
          'and userPubkey is null', () async {
        final result = await repository.getHomeFeedVideos(authors: []);

        expect(result.videos, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('hits Funnelcake API when authors is empty '
          'but userPubkey is provided', () async {
        final mockFunnelcakeClient = MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getHomeFeed(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => HomeFeedResponse(
            videos: [
              _createVideoStats(
                id: 'event-1',
                pubkey: 'followed-user',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/video.mp4',
              ),
            ],
            hasMore: true,
            nextCursor: 1704067100,
          ),
        );

        final repositoryWithApi = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repositoryWithApi.getHomeFeedVideos(
          authors: [],
          userPubkey: 'my-pubkey',
        );

        expect(result.videos, hasLength(1));
        verify(
          () => mockFunnelcakeClient.getHomeFeed(
            pubkey: 'my-pubkey',
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).called(1);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('skips Nostr fallback when authors is empty '
          'and Funnelcake returns empty', () async {
        final mockFunnelcakeClient = MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getHomeFeed(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async => const HomeFeedResponse(videos: []));

        final repositoryWithApi = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repositoryWithApi.getHomeFeedVideos(
          authors: [],
          userPubkey: 'my-pubkey',
        );

        expect(result.videos, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('returns empty list when no events found', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        final result = await repository.getHomeFeedVideos(
          authors: ['pubkey1', 'pubkey2'],
        );

        expect(result.videos, isEmpty);
        verify(() => mockNostrClient.queryEvents(any())).called(1);
      });

      test('queries with correct filter including authors', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        final authors = ['pubkey1', 'pubkey2'];
        await repository.getHomeFeedVideos(authors: authors, limit: 10);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters, hasLength(1));
        expect(filters.first.kinds, contains(EventKind.videoVertical));
        expect(filters.first.authors, equals(authors));
        expect(filters.first.limit, equals(10));
      });

      test('passes until parameter for pagination', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        const until = 1704067200;
        await repository.getHomeFeedVideos(authors: ['pubkey1'], until: until);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters.first.until, equals(until));
      });

      test('transforms and filters events correctly', () async {
        final event = _createVideoEvent(
          id: 'home-video-123',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
        );

        expect(result.videos, hasLength(1));
        expect(result.videos.first.id, equals('home-video-123'));
        expect(result.videos.first.pubkey, equals('followed-user'));
      });

      test(
        'continues past a full relay home page of reply-only videos',
        () async {
          final feedVideo = _createVideoEvent(
            id: 'feed-video',
            pubkey: 'followed-user',
            videoUrl: 'https://example.com/feed.mp4',
            createdAt: 1704060000,
          );

          when(() => mockNostrClient.queryEvents(any())).thenAnswer((
            invocation,
          ) async {
            final filters =
                invocation.positionalArguments.first as List<Filter>;
            final filter = filters.single;
            final limit = filter.limit ?? 5;

            if (filter.until != null) {
              return [feedVideo];
            }

            return List.generate(
              limit,
              (index) => _createVideoEvent(
                id: 'video-reply-$index',
                pubkey: 'followed-user',
                videoUrl: 'https://example.com/reply-$index.mp4',
                createdAt: 1704070000 - index,
                extraTags: const [
                  ['E', 'root-event-id', '', 'root-author'],
                  ['K', '34236'],
                  ['P', 'root-author'],
                  ['e', 'root-event-id', '', 'root-author'],
                  ['k', '34236'],
                  ['p', 'root-author'],
                ],
              ),
            );
          });

          final result = await repository.getHomeFeedVideos(
            authors: ['followed-user'],
          );

          expect(result.videos.map((video) => video.id), ['feed-video']);
          expect(result.followingPageCount, 2);
          verify(() => mockNostrClient.queryEvents(any())).called(2);
        },
      );

      test(
        'accumulates visible relay home videos across mixed reply-heavy pages',
        () async {
          when(() => mockNostrClient.queryEvents(any())).thenAnswer((
            invocation,
          ) async {
            final filters =
                invocation.positionalArguments.first as List<Filter>;
            final filter = filters.single;

            if (filter.until == null) {
              return [
                _createVideoEvent(
                  id: 'video-reply-1',
                  pubkey: 'followed-user',
                  videoUrl: 'https://example.com/reply-1.mp4',
                  createdAt: 1704070000,
                  extraTags: const [
                    ['E', 'root-event-id', '', 'root-author'],
                    ['K', '34236'],
                    ['P', 'root-author'],
                    ['e', 'root-event-id', '', 'root-author'],
                    ['k', '34236'],
                    ['p', 'root-author'],
                  ],
                ),
                _createVideoEvent(
                  id: 'video-reply-2',
                  pubkey: 'followed-user',
                  videoUrl: 'https://example.com/reply-2.mp4',
                  createdAt: 1704069999,
                  extraTags: const [
                    ['E', 'root-event-id', '', 'root-author'],
                    ['K', '34236'],
                    ['P', 'root-author'],
                    ['e', 'root-event-id', '', 'root-author'],
                    ['k', '34236'],
                    ['p', 'root-author'],
                  ],
                ),
                _createVideoEvent(
                  id: 'feed-video-1',
                  pubkey: 'followed-user',
                  videoUrl: 'https://example.com/feed-1.mp4',
                  createdAt: 1704069998,
                ),
              ];
            }

            return [
              _createVideoEvent(
                id: 'feed-video-2',
                pubkey: 'followed-user',
                videoUrl: 'https://example.com/feed-2.mp4',
                createdAt: 1704068000,
              ),
            ];
          });

          final result = await repository.getHomeFeedVideos(
            authors: ['followed-user'],
            limit: 2,
          );

          expect(
            result.videos.map((video) => video.id),
            equals(['feed-video-1', 'feed-video-2']),
          );
          verify(() => mockNostrClient.queryEvents(any())).called(2);
        },
      );

      test('sorts videos by creation time (newest first)', () async {
        final olderEvent = _createVideoEvent(
          id: 'older',
          pubkey: 'user1',
          videoUrl: 'https://example.com/old.mp4',
          createdAt: 1704067200,
        );
        final newerEvent = _createVideoEvent(
          id: 'newer',
          pubkey: 'user2',
          videoUrl: 'https://example.com/new.mp4',
          createdAt: 1704153600,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [olderEvent, newerEvent]);

        final result = await repository.getHomeFeedVideos(
          authors: ['user1', 'user2'],
        );

        expect(result.videos, hasLength(2));
        expect(result.videos.first.id, equals('newer'));
        expect(result.videos.last.id, equals('older'));
      });
    });

    group('getHomeFeedVideos with videoRefs', () {
      test('empty videoRefs returns only following videos', () async {
        final event = _createVideoEvent(
          id: 'following-video',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
        );

        expect(result.videos, hasLength(1));
        expect(result.videos.first.id, equals('following-video'));
        expect(result.videoListSources, isEmpty);
        expect(result.listOnlyVideoIds, isEmpty);
      });

      test('merges list videos with following videos', () async {
        final followingEvent = _createVideoEvent(
          id: 'following-video',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/following.mp4',
          createdAt: 1704067200,
        );

        final listEvent = _createVideoEvent(
          id: 'list-video',
          pubkey: 'list-author',
          videoUrl: 'https://example.com/list.mp4',
          createdAt: 1704067300,
        );

        // Following fetch
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          if (filters.first.authors != null) {
            return [followingEvent];
          }
          // Event ID fetch for list videos
          return [listEvent];
        });

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
          videoRefs: {
            'list-a': ['list-video'],
          },
        );

        expect(result.videos, hasLength(2));
        // Sorted by createdAt desc: list-video (300) then following (200)
        expect(result.videos.first.id, equals('list-video'));
        expect(result.videos.last.id, equals('following-video'));
        expect(result.videoListSources, hasLength(1));
        expect(result.videoListSources['list-video'], contains('list-a'));
        expect(result.listOnlyVideoIds, contains('list-video'));
      });

      test('deduplicates video in both following and list', () async {
        final sharedEvent = _createVideoEvent(
          id: 'shared-video',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/shared.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [sharedEvent]);

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
          videoRefs: {
            'list-a': ['shared-video'],
          },
        );

        // Video appears only once (from following)
        expect(result.videos, hasLength(1));
        expect(result.videos.first.id, equals('shared-video'));
        // Still tracked in videoListSources (it IS in a list)
        expect(result.videoListSources['shared-video'], contains('list-a'));
        // NOT in listOnlyVideoIds (it's from a followed user)
        expect(result.listOnlyVideoIds, isEmpty);
      });

      test(
        'deduplicates republished addressable video in following and list',
        () async {
          final author = 'a' * 64;
          final followingEvent = _createVideoEventWithDTag(
            id: 'following-event-id',
            pubkey: author,
            dTag: 'shared-d-tag',
            videoUrl: 'https://example.com/following.mp4',
            createdAt: 1704067200,
          );
          final listEvent = _createVideoEventWithDTag(
            id: 'republished-event-id',
            pubkey: author,
            dTag: 'shared-d-tag',
            videoUrl: 'https://example.com/list.mp4',
            createdAt: 1704067300,
          );

          var callCount = 0;
          when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return [followingEvent];
            return [listEvent];
          });

          final result = await repository.getHomeFeedVideos(
            authors: [author],
            videoRefs: {
              'list-a': ['34236:$author:shared-d-tag'],
            },
          );

          expect(result.videos, hasLength(1));
          expect(result.videos.single.id, equals('following-event-id'));
          expect(
            result.videoListSources['following-event-id'],
            contains('list-a'),
          );
          expect(result.videoListSources['republished-event-id'], isNull);
          expect(result.listOnlyVideoIds, isEmpty);
        },
      );

      test('keeps same d-tag list videos from different authors', () async {
        const authorA =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        const authorB =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        final videoA = _createVideoEventWithDTag(
          id: 'author-a-event',
          pubkey: authorA,
          dTag: 'shared-d-tag',
          videoUrl: 'https://example.com/a.mp4',
          createdAt: 1704067200,
        );
        final videoB = _createVideoEventWithDTag(
          id: 'author-b-event',
          pubkey: authorB,
          dTag: 'shared-d-tag',
          videoUrl: 'https://example.com/b.mp4',
          createdAt: 1704067300,
        );

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return <Event>[];
          return [videoA, videoB];
        });

        final result = await repository.getHomeFeedVideos(
          authors: [authorA],
          videoRefs: {
            'list-a': [
              '34236:$authorA:shared-d-tag',
              '34236:$authorB:shared-d-tag',
            ],
          },
        );

        expect(
          result.videos.map((v) => v.id),
          containsAll(['author-a-event', 'author-b-event']),
        );
        expect(result.videos, hasLength(2));
        expect(
          result.listOnlyVideoIds,
          containsAll(['author-a-event', 'author-b-event']),
        );
      });

      test('builds correct videoListSources for multi-list refs', () async {
        final event = _createVideoEvent(
          id: 'multi-list-video',
          pubkey: 'some-author',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          if (filters.first.authors != null) return <Event>[];
          return [event];
        });

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
          videoRefs: {
            'list-a': ['multi-list-video'],
            'list-b': ['multi-list-video'],
          },
        );

        expect(result.videos, hasLength(1));
        expect(
          result.videoListSources['multi-list-video'],
          containsAll(['list-a', 'list-b']),
        );
        expect(result.listOnlyVideoIds, contains('multi-list-video'));
      });

      test('handles addressable coordinate refs', () async {
        final followingEvent = _createVideoEvent(
          id: 'following-video',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/following.mp4',
          createdAt: 1704067200,
        );

        final addressableEvent = _createVideoEventWithDTag(
          id: 'addressable-event-id',
          pubkey: 'list-author',
          dTag: 'my-vine',
          videoUrl: 'https://example.com/addressable.mp4',
          createdAt: 1704067300,
        );

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return [followingEvent]; // Following fetch
          return [addressableEvent]; // Addressable fetch
        });

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
          videoRefs: {
            'list-a': ['34236:list-author:my-vine'],
          },
        );

        expect(result.videos, hasLength(2));
        expect(result.listOnlyVideoIds, contains('addressable-event-id'));
      });

      test('handles mixed event ID and addressable refs', () async {
        final followingEvent = _createVideoEvent(
          id: 'following-video',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/following.mp4',
          createdAt: 1704067100,
        );

        final eventIdVideo = _createVideoEvent(
          id: 'event-id-video',
          pubkey: 'author-a',
          videoUrl: 'https://example.com/event.mp4',
          createdAt: 1704067200,
        );

        final addressableVideo = _createVideoEventWithDTag(
          id: 'addressable-id',
          pubkey: 'author-b',
          dTag: 'vine-dtag',
          videoUrl: 'https://example.com/addressable.mp4',
          createdAt: 1704067300,
        );

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return [followingEvent]; // Following
          if (callCount == 2) return [eventIdVideo]; // Event IDs
          return [addressableVideo]; // Addressable
        });

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
          videoRefs: {
            'list-a': ['event-id-video', '34236:author-b:vine-dtag'],
          },
        );

        expect(result.videos, hasLength(3));
        expect(result.listOnlyVideoIds, hasLength(2));
        expect(
          result.listOnlyVideoIds,
          containsAll(['event-id-video', 'addressable-id']),
        );
      });

      test('empty following + non-empty videoRefs', () async {
        final listEvent = _createVideoEvent(
          id: 'list-only-video',
          pubkey: 'list-author',
          videoUrl: 'https://example.com/list.mp4',
          createdAt: 1704067200,
        );

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return <Event>[]; // Following (empty)
          return [listEvent]; // List video fetch
        });

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
          videoRefs: {
            'list-a': ['list-only-video'],
          },
        );

        expect(result.videos, hasLength(1));
        expect(result.videos.first.id, equals('list-only-video'));
        expect(result.listOnlyVideoIds, contains('list-only-video'));
      });

      test('sorted by createdAt descending after merge', () async {
        final old = _createVideoEvent(
          id: 'old-following',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/old.mp4',
          createdAt: 1000,
        );

        final mid = _createVideoEvent(
          id: 'mid-list',
          pubkey: 'list-author',
          videoUrl: 'https://example.com/mid.mp4',
          createdAt: 2000,
        );

        final newest = _createVideoEvent(
          id: 'new-following',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/new.mp4',
          createdAt: 3000,
        );

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return [old, newest]; // Following
          return [mid]; // List videos
        });

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
          videoRefs: {
            'list-a': ['mid-list'],
          },
        );

        expect(result.videos, hasLength(3));
        expect(result.videos[0].id, equals('new-following'));
        expect(result.videos[1].id, equals('mid-list'));
        expect(result.videos[2].id, equals('old-following'));
      });

      test('case-insensitive dedup between following and list', () async {
        final followingEvent = _createVideoEvent(
          id: 'AbCdEf',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          if (filters.first.authors != null) return [followingEvent];
          return [followingEvent]; // Same video from list fetch
        });

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
          videoRefs: {
            'list-a': ['AbCdEf'],
          },
        );

        // Video appears only once despite being in both
        expect(result.videos, hasLength(1));
        expect(result.listOnlyVideoIds, isEmpty);
      });
    });

    group('getVideosForList', () {
      test('returns empty list when videoRefs is empty', () async {
        final result = await repository.getVideosForList([]);

        expect(result, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('fetches event ID refs correctly', () async {
        final event = _createVideoEvent(
          id: 'event-1',
          pubkey: 'author-1',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final result = await repository.getVideosForList(['event-1']);

        expect(result, hasLength(1));
        expect(result.first.id, equals('event-1'));
      });

      test('fetches addressable refs correctly', () async {
        final event = _createVideoEventWithDTag(
          id: 'addr-event-id',
          pubkey: 'author-1',
          dTag: 'my-vine',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final result = await repository.getVideosForList([
          '34236:author-1:my-vine',
        ]);

        expect(result, hasLength(1));
        expect(result.first.vineId, equals('my-vine'));
      });

      test(
        'keeps addressable refs with same d-tag from different authors',
        () async {
          final authorA = 'a' * 64;
          final authorB = 'b' * 64;
          final videoA = _createVideoEventWithDTag(
            id: 'author-a-event',
            pubkey: authorA,
            dTag: 'same-d-tag',
            videoUrl: 'https://example.com/a.mp4',
            createdAt: 1704067200,
          );
          final videoB = _createVideoEventWithDTag(
            id: 'author-b-event',
            pubkey: authorB,
            dTag: 'same-d-tag',
            videoUrl: 'https://example.com/b.mp4',
            createdAt: 1704067300,
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [videoA, videoB]);

          final result = await repository.getVideosForList([
            '34236:$authorA:same-d-tag',
            '34236:$authorB:same-d-tag',
          ]);

          expect(
            result.map((video) => video.id),
            equals(['author-a-event', 'author-b-event']),
          );
        },
      );

      test(
        'deduplicates repeated addressable refs with different event ids',
        () async {
          final author = 'a' * 64;
          final firstCopy = _createVideoEventWithDTag(
            id: 'first-event-id',
            pubkey: author,
            dTag: 'same-d-tag',
            videoUrl: 'https://example.com/first.mp4',
            createdAt: 1704067200,
          );
          final secondCopy = _createVideoEventWithDTag(
            id: 'second-event-id',
            pubkey: author,
            dTag: 'same-d-tag',
            videoUrl: 'https://example.com/second.mp4',
            createdAt: 1704067300,
          );

          var callCount = 0;
          when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return [firstCopy];
            return [secondCopy];
          });

          final result = await repository.getVideosForList([
            'first-event-id',
            '34236:$author:same-d-tag',
          ]);

          expect(result, hasLength(1));
          expect(result.single.id, equals('first-event-id'));
        },
      );

      test('fetches mixed ref types in parallel', () async {
        final eventIdVideo = _createVideoEvent(
          id: 'event-video',
          pubkey: 'author-a',
          videoUrl: 'https://example.com/event.mp4',
          createdAt: 1704067200,
        );

        final addressableVideo = _createVideoEventWithDTag(
          id: 'addr-video',
          pubkey: 'author-b',
          dTag: 'vine-dtag',
          videoUrl: 'https://example.com/addressable.mp4',
          createdAt: 1704067300,
        );

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return [eventIdVideo];
          return [addressableVideo];
        });

        final result = await repository.getVideosForList([
          'event-video',
          '34236:author-b:vine-dtag',
        ]);

        expect(result, hasLength(2));
        expect(result[0].id, equals('event-video'));
        expect(result[1].vineId, equals('vine-dtag'));
      });

      test('preserves ref order in result', () async {
        final video1 = _createVideoEvent(
          id: 'video-1',
          pubkey: 'author',
          videoUrl: 'https://example.com/1.mp4',
          createdAt: 1000,
        );

        final video2 = _createVideoEvent(
          id: 'video-2',
          pubkey: 'author',
          videoUrl: 'https://example.com/2.mp4',
          createdAt: 3000,
        );

        final video3 = _createVideoEvent(
          id: 'video-3',
          pubkey: 'author',
          videoUrl: 'https://example.com/3.mp4',
          createdAt: 2000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [video1, video2, video3]);

        // Request in specific order regardless of createdAt
        final result = await repository.getVideosForList([
          'video-3',
          'video-1',
          'video-2',
        ]);

        expect(result, hasLength(3));
        expect(result[0].id, equals('video-3'));
        expect(result[1].id, equals('video-1'));
        expect(result[2].id, equals('video-2'));
      });

      test('omits unresolved refs from result', () async {
        final video = _createVideoEvent(
          id: 'found-video',
          pubkey: 'author',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [video]);

        final result = await repository.getVideosForList([
          'found-video',
          'missing-video',
        ]);

        expect(result, hasLength(1));
        expect(result.first.id, equals('found-video'));
      });
    });
    group('getProfileVideos', () {
      test('returns empty list when no events found', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        final result = await repository.getProfileVideos(
          authorPubkey: 'test-pubkey',
        );

        expect(result, isEmpty);
        verify(() => mockNostrClient.queryEvents(any())).called(1);
      });

      test('queries with correct filter for single author', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        const authorPubkey = 'user-pubkey-123';
        await repository.getProfileVideos(
          authorPubkey: authorPubkey,
          limit: 10,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters, hasLength(1));
        expect(filters.first.kinds, contains(EventKind.videoVertical));
        expect(filters.first.authors, equals([authorPubkey]));
        expect(filters.first.limit, equals(10));
      });

      test('passes until parameter for pagination', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        const until = 1704067200;
        await repository.getProfileVideos(
          authorPubkey: 'test-pubkey',
          until: until,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters.first.until, equals(until));
      });

      test('transforms and filters events correctly', () async {
        final event = _createVideoEvent(
          id: 'profile-video-123',
          pubkey: 'user-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final result = await repository.getProfileVideos(
          authorPubkey: 'user-pubkey',
        );

        expect(result, hasLength(1));
        expect(result.first.id, equals('profile-video-123'));
        expect(result.first.pubkey, equals('user-pubkey'));
      });

      test('filters out videos without valid URL', () async {
        final validEvent = _createVideoEvent(
          id: 'valid-id',
          pubkey: 'user-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );
        final invalidEvent = _createVideoEvent(
          id: 'invalid-id',
          pubkey: 'user-pubkey',
          videoUrl: null,
          createdAt: 1704067201,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [validEvent, invalidEvent]);

        final result = await repository.getProfileVideos(
          authorPubkey: 'user-pubkey',
        );

        expect(result, hasLength(1));
        expect(result.first.id, equals('valid-id'));
      });

      test('sorts videos by creation time (newest first)', () async {
        final olderEvent = _createVideoEvent(
          id: 'older',
          pubkey: 'user-pubkey',
          videoUrl: 'https://example.com/old.mp4',
          createdAt: 1704067200,
        );
        final newerEvent = _createVideoEvent(
          id: 'newer',
          pubkey: 'user-pubkey',
          videoUrl: 'https://example.com/new.mp4',
          createdAt: 1704153600,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [olderEvent, newerEvent]);

        final result = await repository.getProfileVideos(
          authorPubkey: 'user-pubkey',
        );

        expect(result, hasLength(2));
        expect(result.first.id, equals('newer'));
        expect(result.last.id, equals('older'));
      });

      test('uses default limit of 5 when not specified', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        await repository.getProfileVideos(authorPubkey: 'test-pubkey');

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters.first.limit, equals(25));
      });
    });

    group('getPopularVideosPage', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
        when(
          () => mockFunnelcakeClient.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
        when(
          () => mockFunnelcakeClient.getV2PopularVideosPage(
            variant: any(named: 'variant'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            before: any(named: 'before'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((invocation) async {
          final stats = await mockFunnelcakeClient.getV2PopularVideos(
            variant:
                invocation.namedArguments[#variant] as PopularVideosVariant,
            limit: invocation.namedArguments[#limit] as int? ?? 25,
            before: invocation.namedArguments[#before] as int?,
          );
          return V2PopularVideosResponse(videos: stats);
        });
      });

      test(
        'passes viewer language and country hints to v2 popular API',
        () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getV2PopularVideos(
              variant: any(named: 'variant'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
              preferredLanguages: any(named: 'preferredLanguages'),
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).thenAnswer((_) async => const []);

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getPopularVideosPage(
            variant: PopularVideosVariant.native,
            preferredLanguages: const ['pt'],
            viewerCountry: 'BR',
          );

          verify(
            () => mockFunnelcakeClient.getV2PopularVideosPage(
              variant: PopularVideosVariant.native,
              limit: 25,
              preferredLanguages: const ['pt'],
              viewerCountry: 'BR',
            ),
          ).called(1);
        },
      );

      test(
        'reuses the cached page when only the country hint changes',
        () async {
          // The country hint comes from a 250ms-timeout geo lookup that
          // yields null on a slow network. If it forked the cache key,
          // this second call would miss the cache and hit the API again.
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getV2PopularVideos(
              variant: any(named: 'variant'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
              preferredLanguages: any(named: 'preferredLanguages'),
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'native-1',
                pubkey: 'pubkey-1',
                dTag: 'native-dtag-1',
                videoUrl: 'https://example.com/native-1.mp4',
              ),
            ],
          );

          final feedCache = InMemoryFeedCache();
          final repositoryWithCache = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            inMemoryFeedCache: feedCache,
          );

          final first = await repositoryWithCache.getPopularVideosPage(
            variant: PopularVideosVariant.native,
            preferredLanguages: const ['pt'],
          );
          final second = await repositoryWithCache.getPopularVideosPage(
            variant: PopularVideosVariant.native,
            preferredLanguages: const ['pt'],
            viewerCountry: 'BR',
          );

          expect(
            second.videos.map((video) => video.id),
            equals(first.videos.map((video) => video.id)),
          );
          verify(
            () => mockFunnelcakeClient.getV2PopularVideosPage(
              variant: PopularVideosVariant.native,
              limit: 25,
              preferredLanguages: const ['pt'],
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).called(1);
        },
      );

      test(
        'native variant continues paging until it fills a native-only page',
        () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getV2PopularVideos(
              variant: any(named: 'variant'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((invocation) async {
            final before = invocation.namedArguments[#before] as int?;
            if (before == null) {
              return [
                _createVideoStats(
                  id: 'vine-1',
                  pubkey: 'pubkey-1',
                  dTag: 'vine-1',
                  videoUrl: 'https://example.com/vine-1.mp4',
                  rawTags: const {'platform': 'vine'},
                ),
                _createVideoStats(
                  id: 'vine-2',
                  pubkey: 'pubkey-2',
                  dTag: 'vine-2',
                  videoUrl: 'https://example.com/vine-2.mp4',
                  createdAt: 1_704_067_199,
                  rawTags: const {'platform': 'vine'},
                ),
              ];
            }
            expect(before, equals(1_704_067_198));
            return [
              _createVideoStats(
                id: 'native-popular-1',
                pubkey: 'pubkey-3',
                dTag: 'native-dtag-1',
                videoUrl: 'https://example.com/native1.mp4',
                createdAt: 1_704_067_198,
              ),
              _createVideoStats(
                id: 'native-popular-2',
                pubkey: 'pubkey-4',
                dTag: 'native-dtag-2',
                videoUrl: 'https://example.com/native2.mp4',
                createdAt: 1_704_067_197,
              ),
            ];
          });

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getPopularVideosPage(
            variant: PopularVideosVariant.native,
            limit: 2,
          );

          expect(result.videos.map((video) => video.id), [
            'native-popular-1',
            'native-popular-2',
          ]);
          expect(result.nextCursor, equals('before:1704067196'));
          expect(result.hasMore, isTrue);
          verify(
            () => mockFunnelcakeClient.getV2PopularVideos(
              variant: PopularVideosVariant.native,
              limit: 2,
              before: any(named: 'before'),
            ),
          ).called(2);
          verifyNever(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          );
        },
      );

      test(
        'native variant reports source exhaustion after client-side filtering',
        () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getV2PopularVideos(
              variant: any(named: 'variant'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'vine-only',
                pubkey: 'pubkey-1',
                dTag: 'vine-only',
                videoUrl: 'https://example.com/vine-only.mp4',
                rawTags: const {'platform': 'vine'},
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getPopularVideosPage(
            variant: PopularVideosVariant.native,
            limit: 2,
          );

          expect(result.videos, isEmpty);
          expect(result.nextCursor, isNull);
          expect(result.hasMore, isFalse);
        },
      );

      test('classic variant filters out stray native rows', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getV2PopularVideos(
            variant: any(named: 'variant'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'classic-visible',
              pubkey: 'pubkey-1',
              dTag: 'classic-visible',
              videoUrl: 'https://example.com/classic.mp4',
              rawTags: const {'platform': 'vine'},
            ),
            _createVideoStats(
              id: 'native-stray',
              pubkey: 'pubkey-2',
              dTag: 'native-stray',
              videoUrl: 'https://example.com/native.mp4',
            ),
          ],
        );

        final repositoryWithApi = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repositoryWithApi.getPopularVideosPage(
          variant: PopularVideosVariant.classic,
          limit: 2,
        );

        expect(result.videos.map((video) => video.id), ['classic-visible']);
      });

      test(
        'caches the first v2 popular page with its cursor metadata',
        () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          var callCount = 0;
          when(
            () => mockFunnelcakeClient.getV2PopularVideos(
              variant: any(named: 'variant'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async {
            callCount += 1;
            return [
              _createVideoStats(
                id: 'native-popular-call-$callCount',
                pubkey: 'pubkey-$callCount',
                dTag: 'native-dtag-$callCount',
                videoUrl: 'https://example.com/native-$callCount.mp4',
              ),
            ];
          });

          final feedCache = InMemoryFeedCache();
          final repositoryWithCache = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            inMemoryFeedCache: feedCache,
          );

          final skipped = await repositoryWithCache.getPopularVideosPage(
            variant: PopularVideosVariant.native,
            skipCache: true,
          );
          final fresh = await repositoryWithCache.getPopularVideosPage(
            variant: PopularVideosVariant.native,
          );
          final cached = await repositoryWithCache.getPopularVideosPage(
            variant: PopularVideosVariant.native,
          );

          expect(skipped.videos.first.id, equals('native-popular-call-1'));
          expect(fresh.videos.first.id, equals('native-popular-call-2'));
          expect(cached.videos.first.id, equals('native-popular-call-2'));
          expect(cached.nextCursor, equals(fresh.nextCursor));
          expect(cached.hasMore, equals(fresh.hasMore));
          verify(
            () => mockFunnelcakeClient.getV2PopularVideos(
              variant: PopularVideosVariant.native,
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).called(2);
        },
      );

      test('caches an empty v2 popular page so it is not refetched', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getV2PopularVideos(
            variant: any(named: 'variant'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async => const <VideoStats>[]);

        final feedCache = InMemoryFeedCache();
        final repositoryWithCache = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
          inMemoryFeedCache: feedCache,
        );

        final fresh = await repositoryWithCache.getPopularVideosPage(
          variant: PopularVideosVariant.native,
        );
        final cached = await repositoryWithCache.getPopularVideosPage(
          variant: PopularVideosVariant.native,
        );

        expect(fresh.videos, isEmpty);
        expect(fresh.hasMore, isFalse);
        expect(cached.videos, isEmpty);
        expect(cached.hasMore, isFalse);
        verify(
          () => mockFunnelcakeClient.getV2PopularVideos(
            variant: PopularVideosVariant.native,
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).called(1);
      });

      test('caches a full v2 popular page that still has more', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getV2PopularVideos(
            variant: any(named: 'variant'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'native-1',
              pubkey: 'pubkey-1',
              dTag: 'native-dtag-1',
              videoUrl: 'https://example.com/native-1.mp4',
            ),
            _createVideoStats(
              id: 'native-2',
              pubkey: 'pubkey-2',
              dTag: 'native-dtag-2',
              videoUrl: 'https://example.com/native-2.mp4',
              createdAt: 1_704_067_199,
            ),
          ],
        );

        final feedCache = InMemoryFeedCache();
        final repositoryWithCache = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
          inMemoryFeedCache: feedCache,
        );

        final fresh = await repositoryWithCache.getPopularVideosPage(
          variant: PopularVideosVariant.native,
          limit: 2,
        );
        final cached = await repositoryWithCache.getPopularVideosPage(
          variant: PopularVideosVariant.native,
          limit: 2,
        );

        expect(fresh.videos.map((video) => video.id), ['native-1', 'native-2']);
        expect(fresh.hasMore, isTrue);
        expect(fresh.nextCursor, equals('before:1704067198'));
        expect(cached.videos.map((video) => video.id), [
          'native-1',
          'native-2',
        ]);
        expect(cached.hasMore, isTrue);
        expect(cached.nextCursor, equals(fresh.nextCursor));
        verify(
          () => mockFunnelcakeClient.getV2PopularVideos(
            variant: PopularVideosVariant.native,
            limit: 2,
            before: any(named: 'before'),
          ),
        ).called(1);
      });

      test(
        'restores legacy cached timestamp cursors as before cursors',
        () async {
          final feedCache = InMemoryFeedCache()
            ..set(
              'popular:v2:${PopularVideosVariant.native.name}',
              HomeFeedResult(
                videos: [
                  VideoEvent(
                    id: 'cached-native',
                    pubkey: 'cached-pubkey',
                    createdAt: 1_704_067_200,
                    content: '',
                    timestamp: DateTime.fromMillisecondsSinceEpoch(
                      1_704_067_200 * 1000,
                    ),
                  ),
                ],
                nextCursor: 1_704_067_198,
                hasMore: true,
              ),
            );
          final repositoryWithCache = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            inMemoryFeedCache: feedCache,
          );

          final cached = await repositoryWithCache.getPopularVideosPage(
            variant: PopularVideosVariant.native,
            limit: 1,
          );

          expect(cached.videos.map((video) => video.id), ['cached-native']);
          expect(cached.nextCursor, equals('before:1704067198'));
          expect(cached.hasMore, isTrue);
          verifyNever(
            () => mockFunnelcakeClient.getV2PopularVideosPage(
              variant: any(named: 'variant'),
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              before: any(named: 'before'),
            ),
          );
        },
      );

      test('continues v2 popular pagination with the server cursor', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getV2PopularVideosPage(
            variant: any(named: 'variant'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((invocation) async {
          final cursor = invocation.namedArguments[#cursor] as String?;
          expect(invocation.namedArguments[#before], isNull);
          if (cursor == null) {
            return V2PopularVideosResponse(
              videos: [
                _createVideoStats(
                  id: 'native-1',
                  pubkey: 'pubkey-1',
                  dTag: 'native-dtag-1',
                  videoUrl: 'https://example.com/native-1.mp4',
                ),
                _createVideoStats(
                  id: 'native-2',
                  pubkey: 'pubkey-2',
                  dTag: 'native-dtag-2',
                  videoUrl: 'https://example.com/native-2.mp4',
                  createdAt: 1_704_067_199,
                ),
              ],
              hasMore: true,
              nextCursor: 'o:2',
            );
          }
          expect(cursor, equals('o:2'));
          return V2PopularVideosResponse(
            videos: [
              _createVideoStats(
                id: 'native-3',
                pubkey: 'pubkey-3',
                dTag: 'native-dtag-3',
                videoUrl: 'https://example.com/native-3.mp4',
                createdAt: 1_704_067_300,
              ),
            ],
            hasMore: false,
          );
        });

        final repositoryWithApi = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final first = await repositoryWithApi.getPopularVideosPage(
          variant: PopularVideosVariant.native,
          limit: 2,
        );
        final second = await repositoryWithApi.getPopularVideosPage(
          variant: PopularVideosVariant.native,
          limit: 2,
          cursor: first.nextCursor,
        );

        expect(first.nextCursor, equals('o:2'));
        expect(first.hasMore, isTrue);
        expect(second.videos.map((video) => video.id), ['native-3']);
        expect(second.hasMore, isFalse);
        verify(
          () => mockFunnelcakeClient.getV2PopularVideosPage(
            variant: PopularVideosVariant.native,
            limit: 2,
            cursor: any(named: 'cursor'),
            before: any(named: 'before'),
          ),
        ).called(2);
      });

      test('stops paging when the server repeats an opaque cursor', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getV2PopularVideosPage(
            variant: any(named: 'variant'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((invocation) async {
          expect(invocation.namedArguments[#cursor], equals('o:same'));
          expect(invocation.namedArguments[#before], isNull);
          return V2PopularVideosResponse(
            videos: [
              _createVideoStats(
                id: 'native-1',
                pubkey: 'pubkey-1',
                dTag: 'native-dtag-1',
                videoUrl: 'https://example.com/native-1.mp4',
              ),
              _createVideoStats(
                id: 'native-2',
                pubkey: 'pubkey-2',
                dTag: 'native-dtag-2',
                videoUrl: 'https://example.com/native-2.mp4',
                createdAt: 1_704_067_199,
              ),
            ],
            hasMore: true,
            nextCursor: 'o:same',
          );
        });

        final repositoryWithApi = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repositoryWithApi.getPopularVideosPage(
          variant: PopularVideosVariant.native,
          limit: 2,
          cursor: 'o:same',
        );

        expect(result.videos.map((video) => video.id), [
          'native-1',
          'native-2',
        ]);
        expect(result.nextCursor, isNull);
        expect(result.hasMore, isFalse);
        verify(
          () => mockFunnelcakeClient.getV2PopularVideosPage(
            variant: PopularVideosVariant.native,
            limit: 2,
            cursor: 'o:same',
            before: any(named: 'before'),
          ),
        ).called(1);
      });

      test(
        'continues fallback timestamp pagination with before parameter',
        () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getV2PopularVideosPage(
              variant: any(named: 'variant'),
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((invocation) async {
            final cursor = invocation.namedArguments[#cursor] as String?;
            final before = invocation.namedArguments[#before] as int?;
            expect(cursor, isNull);

            if (before == null) {
              return V2PopularVideosResponse(
                videos: [
                  _createVideoStats(
                    id: 'native-1',
                    pubkey: 'pubkey-1',
                    dTag: 'native-dtag-1',
                    videoUrl: 'https://example.com/native-1.mp4',
                  ),
                  _createVideoStats(
                    id: 'native-2',
                    pubkey: 'pubkey-2',
                    dTag: 'native-dtag-2',
                    videoUrl: 'https://example.com/native-2.mp4',
                    createdAt: 1_704_067_199,
                  ),
                ],
              );
            }

            expect(before, equals(1_704_067_198));
            return V2PopularVideosResponse(
              videos: [
                _createVideoStats(
                  id: 'native-3',
                  pubkey: 'pubkey-3',
                  dTag: 'native-dtag-3',
                  videoUrl: 'https://example.com/native-3.mp4',
                  createdAt: 1_704_067_198,
                ),
              ],
              hasMore: false,
            );
          });

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final first = await repositoryWithApi.getPopularVideosPage(
            variant: PopularVideosVariant.native,
            limit: 2,
          );
          final second = await repositoryWithApi.getPopularVideosPage(
            variant: PopularVideosVariant.native,
            limit: 2,
            cursor: first.nextCursor,
          );

          expect(first.nextCursor, equals('before:1704067198'));
          expect(first.hasMore, isTrue);
          expect(second.videos.map((video) => video.id), ['native-3']);
          expect(second.hasMore, isFalse);
          verify(
            () => mockFunnelcakeClient.getV2PopularVideosPage(
              variant: PopularVideosVariant.native,
              limit: 2,
              cursor: any(named: 'cursor'),
              before: any(named: 'before'),
            ),
          ).called(2);
        },
      );

      test('honors server hasMore when a v2 page is underfilled', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getV2PopularVideosPage(
            variant: any(named: 'variant'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((invocation) async {
          final cursor = invocation.namedArguments[#cursor] as String?;
          if (cursor == null) {
            return V2PopularVideosResponse(
              videos: [
                _createVideoStats(
                  id: 'native-1',
                  pubkey: 'pubkey-1',
                  dTag: 'native-dtag-1',
                  videoUrl: 'https://example.com/native-1.mp4',
                ),
              ],
              hasMore: true,
              nextCursor: 'o:1',
            );
          }
          expect(cursor, equals('o:1'));
          return V2PopularVideosResponse(
            videos: [
              _createVideoStats(
                id: 'native-2',
                pubkey: 'pubkey-2',
                dTag: 'native-dtag-2',
                videoUrl: 'https://example.com/native-2.mp4',
              ),
            ],
            hasMore: false,
          );
        });

        final repositoryWithApi = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repositoryWithApi.getPopularVideosPage(
          variant: PopularVideosVariant.native,
          limit: 2,
        );

        expect(result.videos.map((video) => video.id), [
          'native-1',
          'native-2',
        ]);
        expect(result.hasMore, isFalse);
        verify(
          () => mockFunnelcakeClient.getV2PopularVideosPage(
            variant: PopularVideosVariant.native,
            limit: 2,
            cursor: any(named: 'cursor'),
            before: any(named: 'before'),
          ),
        ).called(2);
      });
    });

    group('getClassicVideos', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      /// Archive page large enough that a shuffle is observable.
      ///
      /// [startIndex] keeps successive pages distinct, so a topped-up fetch
      /// is not silently deduplicated down to one page's worth of rows.
      List<VideoStats> archivePage(int count, {int startIndex = 0}) => [
        for (var i = startIndex; i < startIndex + count; i++)
          _createVideoStats(
            id: 'vine-$i',
            pubkey: 'pubkey-$i',
            dTag: 'vine-$i',
            videoUrl: 'https://example.com/vine-$i.mp4',
            rawTags: const {'platform': 'vine'},
          ),
      ];

      /// Full-length archive page whose rows are all filtered out of Classics
      /// because they are not original vines.
      List<VideoStats> nonVinePage(int count) => [
        for (var i = 0; i < count; i++)
          _createVideoStats(
            id: 'divine-$i',
            pubkey: 'pubkey-$i',
            dTag: 'divine-$i',
            videoUrl: 'https://example.com/divine-$i.mp4',
          ),
      ];

      void stubArchive(List<VideoStats> page) {
        when(
          () => mockFunnelcakeClient.getClassicVines(
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async => page);
      }

      /// Serves a different page per archive offset, so top-up behaviour can
      /// be driven page by page.
      void stubArchiveByOffset(
        List<VideoStats> Function(int offset) pageForOffset,
      ) {
        when(
          () => mockFunnelcakeClient.getClassicVines(
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (invocation) async =>
              pageForOffset(invocation.namedArguments[#offset] as int),
        );
      }

      /// Repository wired to a live cache, so the cache guards are load-bearing
      /// in every test rather than only in the ones that name the cache.
      VideosRepository buildRepository({
        Random? random,
        InMemoryFeedCache? feedCache,
      }) => VideosRepository(
        nostrClient: mockNostrClient,
        funnelcakeApiClient: mockFunnelcakeClient,
        inMemoryFeedCache: feedCache ?? InMemoryFeedCache(),
        random: random,
      );

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
      });

      test('reads the archive at a page-aligned random start offset', () async {
        stubArchive(archivePage(20));

        // Random.nextInt is called once, over the number of reachable pages.
        final random = _StubRandom(firstOffsetDraw: 7);
        await buildRepository(random: random).getClassicVideos(limit: 20);

        // The offset is drawn over the reachable page count, not a raw index.
        expect(random.recordedMaxima.first, 101); // (2000 ~/ 20) + 1
        verify(
          () => mockFunnelcakeClient.getClassicVines(
            sort: any(named: 'sort'),
            limit: 20,
            offset: 140, // 7 * 20
            before: any(named: 'before'),
          ),
        ).called(1);
      });

      test(
        'aligns the offset grid to the page size the feed asks for',
        () async {
          // The home feed passes no limit, so the grid is the default page size
          // rather than the 20 the rest of this group uses.
          stubArchive(archivePage(25));

          final random = _StubRandom(firstOffsetDraw: 7);
          await buildRepository(random: random).getClassicVideos();

          expect(random.recordedMaxima.first, 81); // (2000 ~/ 25) + 1
          verify(
            () => mockFunnelcakeClient.getClassicVines(
              sort: any(named: 'sort'),
              limit: 25,
              offset: 175, // 7 * 25
              before: any(named: 'before'),
            ),
          ).called(1);
        },
      );

      test('reads the loops-sorted archive, like Explore → Classics', () async {
        stubArchive(archivePage(20));

        await buildRepository(
          random: _StubRandom(),
        ).getClassicVideos(limit: 20);

        // The shared window only lines up with the Explore tab while both
        // read the same sort; 'trending' or 'recent' would be a different
        // feed wearing the same name.
        final captured = verify(
          () => mockFunnelcakeClient.getClassicVines(
            sort: captureAny(named: 'sort'),
            limit: captureAny(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).captured;
        expect(captured, ['loops', 20]);
      });

      test('tops up when a page filters down to nothing', () async {
        // The archive answers at full length, but nothing on the first page
        // survives the Classics filter.
        stubArchiveByOffset(
          (offset) => offset == 0 ? nonVinePage(20) : archivePage(20),
        );

        final result = await buildRepository(
          random: _StubRandom(),
        ).getClassicVideos(limit: 20);

        expect(result.videos, hasLength(20));
        expect(result.paginationCursor, 'classic-offset:40');
        expect(result.hasMore, isTrue);
      });

      test('stops topping up after a bounded number of pages', () async {
        stubArchive(nonVinePage(20));

        final result = await buildRepository(
          random: _StubRandom(),
        ).getClassicVideos(limit: 20);

        expect(result.videos, isEmpty);
        // The cursor still advances past every page that was read, so a
        // retry resumes beyond the filtered-out run instead of repeating it.
        expect(result.paginationCursor, 'classic-offset:60');
        verify(
          () => mockFunnelcakeClient.getClassicVines(
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).called(3);
      });

      test('shuffles the page rather than preserving archive order', () async {
        stubArchive(archivePage(20));

        final result = await buildRepository(
          random: Random(7),
        ).getClassicVideos(limit: 20);

        final archiveOrder = [for (var i = 0; i < 20; i++) 'vine-$i'];
        expect(result.videos.map((v) => v.id), isNot(archiveOrder));
        expect(result.videos.map((v) => v.id), unorderedEquals(archiveOrder));
      });

      test('draws a different slice on each cache-missing fetch', () async {
        stubArchive(archivePage(20));

        final random = _StubRandom(firstOffsetDraw: 7);
        final repository = buildRepository(random: random);
        await repository.getClassicVideos(limit: 20);

        // skipCache is what makes the second fetch redraw: without it the
        // repository serves the slice it just pinned.
        random.expectOffsetDraw(3);
        await repository.getClassicVideos(limit: 20, skipCache: true);

        final offsets = verify(
          () => mockFunnelcakeClient.getClassicVines(
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: captureAny(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).captured;
        expect(offsets, [140, 60]); // 7 * 20, then 3 * 20
      });

      test('advances the cursor by a page and resumes from it', () async {
        stubArchive(archivePage(20));

        final repository = buildRepository(random: _StubRandom());
        final first = await repository.getClassicVideos(limit: 20);
        expect(first.paginationCursor, 'classic-offset:20');
        expect(first.hasMore, isTrue);

        await repository.getClassicVideos(
          limit: 20,
          cursor: first.paginationCursor,
        );

        verify(
          () => mockFunnelcakeClient.getClassicVines(
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: 20,
            before: any(named: 'before'),
          ),
        ).called(1);
      });

      test('ends pagination when the archive runs out', () async {
        stubArchiveByOffset(
          (offset) => offset == 0 ? archivePage(3) : const [],
        );

        final result = await buildRepository(
          random: _StubRandom(),
        ).getClassicVideos(limit: 20);

        expect(result.videos, hasLength(3));
        expect(result.paginationCursor, isNull);
        expect(result.hasMore, isFalse);
      });

      test(
        'keeps paginating when a short page is not the archive end',
        () async {
          // The client drops rows with a missing id or URL before the
          // repository sees them, so a short page cannot be read as exhaustion:
          // one dropped row would end the feed mid-archive.
          stubArchiveByOffset(
            (offset) =>
                offset == 0 ? archivePage(19) : archivePage(20, startIndex: 19),
          );

          final result = await buildRepository(
            random: _StubRandom(),
          ).getClassicVideos(limit: 20);

          expect(result.hasMore, isTrue);
          expect(result.paginationCursor, 'classic-offset:40');
          // Both pages are handed back rather than trimmed to `limit`: the
          // cursor has already advanced past them, so trimming would drop
          // those videos instead of deferring them to the next page.
          expect(result.videos, hasLength(39));
        },
      );

      test('keeps the slice stable across cache-eligible fetches', () async {
        stubArchive(archivePage(20));

        final repository = buildRepository(random: _StubRandom());

        final first = await repository.getClassicVideos(limit: 20);
        final second = await repository.getClassicVideos(limit: 20);

        expect(second.videos.map((v) => v.id), first.videos.map((v) => v.id));
        verify(
          () => mockFunnelcakeClient.getClassicVines(
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).called(1);
      });

      test('redraws the cached first page after its TTL expires', () async {
        stubArchiveByOffset(
          (offset) =>
              offset == 0 ? archivePage(20) : archivePage(20, startIndex: 20),
        );
        var now = DateTime(2026, 8, 11, 12);
        final random = _StubRandom();
        final repository = buildRepository(
          random: random,
          feedCache: InMemoryFeedCache(now: () => now),
        );

        final first = await repository.getClassicVideos(limit: 20);
        random.expectOffsetDraw(1);
        now = now.add(const Duration(minutes: 15));
        final reentry = await repository.getClassicVideos(limit: 20);

        expect(
          reentry.videos.map((v) => v.id),
          isNot(first.videos.map((v) => v.id)),
        );
        verify(
          () => mockFunnelcakeClient.getClassicVines(
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).called(2);
      });

      test(
        'does not let a later page overwrite the cached first page',
        () async {
          stubArchiveByOffset(
            (offset) =>
                offset == 0 ? archivePage(20) : archivePage(20, startIndex: 20),
          );

          final random = _StubRandom();
          final repository = buildRepository(random: random);

          final first = await repository.getClassicVideos(limit: 20);
          await repository.getClassicVideos(
            limit: 20,
            cursor: first.paginationCursor,
          );
          final reentry = await repository.getClassicVideos(limit: 20);

          expect(
            reentry.videos.map((v) => v.id),
            first.videos.map((v) => v.id),
          );
        },
      );

      test('does not pin an empty page for the rest of the session', () async {
        // Three full pages that filter down to nothing: the feed cannot
        // paginate out of an empty list, so caching this would keep serving
        // nothing until a manual refresh.
        stubArchiveByOffset(
          (offset) => offset < 200 ? nonVinePage(20) : archivePage(20),
        );

        final random = _StubRandom();
        final repository = buildRepository(random: random);

        final empty = await repository.getClassicVideos(limit: 20);
        expect(empty.videos, isEmpty);

        random.expectOffsetDraw(10); // 10 * 20 = offset 200
        final reentry = await repository.getClassicVideos(limit: 20);

        expect(reentry.videos, hasLength(20));
      });

      test('drops archive rows that are not original vines', () async {
        stubArchive([
          _createVideoStats(
            id: 'vine-1',
            pubkey: 'pubkey-1',
            dTag: 'vine-1',
            videoUrl: 'https://example.com/vine-1.mp4',
            rawTags: const {'platform': 'vine'},
          ),
          _createVideoStats(
            id: 'divine-1',
            pubkey: 'pubkey-2',
            dTag: 'divine-1',
            videoUrl: 'https://example.com/divine-1.mp4',
          ),
        ]);

        final result = await buildRepository(
          random: _StubRandom(),
        ).getClassicVideos(limit: 20);

        expect(result.videos.map((v) => v.id), ['vine-1']);
      });

      test('returns an empty result when Funnelcake is unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final result = await buildRepository().getClassicVideos();

        expect(result.videos, isEmpty);
        expect(result.hasMore, isFalse);
      });

      test('returns an empty result when the archive request fails', () async {
        when(
          () => mockFunnelcakeClient.getClassicVines(
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).thenThrow(const FunnelcakeNotConfiguredException());

        final result = await buildRepository(
          random: _StubRandom(),
        ).getClassicVideos();

        expect(result.videos, isEmpty);
        expect(result.hasMore, isFalse);
      });

      test('serves the pages that succeeded when a top-up fails', () async {
        // The first page filters short, so the fetch tops up — and the
        // top-up is what fails.
        stubArchiveByOffset((offset) {
          if (offset == 0) {
            return [...archivePage(12), ...nonVinePage(8)];
          }
          throw const FunnelcakeNotConfiguredException();
        });

        final random = _StubRandom();
        final repository = buildRepository(random: random);

        final result = await repository.getClassicVideos(limit: 20);

        expect(result.videos, hasLength(12));
        expect(result.hasMore, isFalse);
        expect(result.paginationCursor, isNull);

        // A partial page is not worth pinning: the next entry redraws
        // instead of replaying what the failure left behind.
        stubArchive(archivePage(20));
        random.expectOffsetDraw(2);
        final reentry = await repository.getClassicVideos(limit: 20);

        expect(reentry.videos, hasLength(20));
      });
    });

    group('getPopularVideos', () {
      group('Funnelcake API first', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          when(
            () => mockFunnelcakeClient.getBulkVideoStats(any()),
          ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
        });

        test('returns API results when Funnelcake succeeds', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'event-1',
                pubkey: 'pubkey-1',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/trending.mp4',
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getPopularVideos();

          expect(result, hasLength(1));
          expect(
            result.first.videoUrl,
            equals('https://example.com/trending.mp4'),
          );
          // Should NOT query Nostr relay at all
          verifyNever(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          );
        });

        test('preserves API trending order (no re-sort)', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'event-trending-1',
                pubkey: 'pubkey-1',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/video1.mp4',
              ),
              _createVideoStats(
                id: 'event-trending-2',
                pubkey: 'pubkey-2',
                dTag: 'dtag-2',
                videoUrl: 'https://example.com/video2.mp4',
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getPopularVideos(limit: 2);

          expect(result, hasLength(2));
          // Order should match API response, not sorted by createdAt
          expect(result[0].vineId, equals('dtag-1'));
          expect(result[1].vineId, equals('dtag-2'));
        });

        test('passes limit and before to Funnelcake API', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'event-1',
                pubkey: 'pubkey-1',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/video.mp4',
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getPopularVideos(
            limit: 10,
            until: 1704067200,
          );

          verify(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: 10,
              before: 1704067200,
            ),
          ).called(1);
        });

        test('falls back to NIP-50 when Funnelcake throws', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenThrow(const FunnelcakeException('Network error'));

          final nip50Event = _createVideoEvent(
            id: 'nip50-video',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/nip50.mp4',
            createdAt: 1704067200,
          );
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [nip50Event]);

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getPopularVideos();

          expect(result, hasLength(1));
          expect(result.first.id, equals('nip50-video'));
          verify(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).called(1);
        });

        test(
          'trusts empty Funnelcake popular feed without NIP-50 fallback',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getWatchingVideos(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer((_) async => <VideoStats>[]);

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repositoryWithApi.getPopularVideos();

            expect(result, isEmpty);
            verifyNever(
              () => mockNostrClient.queryEvents(
                any(),
                useCache: any(named: 'useCache'),
              ),
            );
          },
        );

        test('skips API when Funnelcake client is null', () async {
          // getPopularVideos without Funnelcake goes straight to NIP-50
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          await repository.getPopularVideos();

          verify(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).called(greaterThanOrEqualTo(1));
        });

        test('skips API when Funnelcake is not available', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getPopularVideos();

          verifyNever(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
        });

        test('applies content filters to API results', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'event-1',
                pubkey: 'blocked-pubkey',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/blocked.mp4',
              ),
              _createVideoStats(
                id: 'event-2',
                pubkey: 'allowed-pubkey',
                dTag: 'dtag-2',
                videoUrl: 'https://example.com/allowed.mp4',
              ),
            ],
          );

          final blockFilter = TestContentFilter(
            blockedPubkeys: {'blocked-pubkey'},
          );
          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            blockFilter: blockFilter.call,
          );

          final result = await repositoryWithApi.getPopularVideos();

          expect(result, hasLength(1));
          expect(
            result.first.videoUrl,
            equals('https://example.com/allowed.mp4'),
          );
        });
      });

      group('NIP-50 server-side sorting', () {
        test('tries NIP-50 query first with sort:hot', () async {
          final event = _createVideoEvent(
            id: 'popular-video',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1704067200,
          );

          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [event]);

          final result = await repository.getPopularVideos();

          final captured = verify(
            () => mockNostrClient.queryEvents(
              captureAny(),
              useCache: captureAny(named: 'useCache'),
            ),
          ).captured;
          final filters = captured[0] as List<Filter>;
          final useCache = captured[1] as bool;

          expect(filters.first.search, equals('sort:hot'));
          expect(
            filters.first.limit,
            equals(25),
          ); // Default limit, not multiplied
          expect(useCache, isFalse);
          expect(result, hasLength(1));
        });

        test('uses exact limit for NIP-50 query (no multiplier)', () async {
          final event = _createVideoEvent(
            id: 'video-1',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1704067200,
          );

          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [event]);

          await repository.getPopularVideos(limit: 10);

          final captured = verify(
            () => mockNostrClient.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
            ),
          ).captured;
          final filters = captured.first as List<Filter>;

          expect(filters.first.limit, equals(10));
        });

        test('passes until parameter to NIP-50 query', () async {
          final event = _createVideoEvent(
            id: 'video-1',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1704067200,
          );

          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [event]);

          const until = 1704067200;
          await repository.getPopularVideos(until: until);

          final captured = verify(
            () => mockNostrClient.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
            ),
          ).captured;
          final filters = captured.first as List<Filter>;

          expect(filters.first.until, equals(until));
        });

        test('returns NIP-50 results without client-side sorting', () async {
          // NIP-50 results come pre-sorted from relay
          final events = [
            _createVideoEvent(
              id: 'relay-sorted-1',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/video1.mp4',
              createdAt: 1704067200,
              loops: 10, // Lower loops but relay says it's #1
            ),
            _createVideoEvent(
              id: 'relay-sorted-2',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/video2.mp4',
              createdAt: 1704067201,
              loops: 1000, // Higher loops but relay says it's #2
            ),
          ];

          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => events);

          final result = await repository.getPopularVideos(limit: 2);

          // Should preserve relay order, not re-sort by loops
          expect(result, hasLength(2));
          expect(result.first.id, equals('relay-sorted-1'));
          expect(result.last.id, equals('relay-sorted-2'));

          // Only one query should be made (no fallback)
          verify(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).called(1);
        });
      });

      group('fallback to client-side sorting', () {
        test('falls back when NIP-50 returns empty', () async {
          // First call (NIP-50) returns empty
          // Second call (fallback) returns events
          var callCount = 0;
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return <Event>[]; // NIP-50 empty
            return [
              _createVideoEvent(
                id: 'fallback-video',
                pubkey: 'test-pubkey',
                videoUrl: 'https://example.com/video.mp4',
                createdAt: 1704067200,
              ),
            ];
          });

          final result = await repository.getPopularVideos();

          expect(result, hasLength(1));
          expect(result.first.id, equals('fallback-video'));
          verify(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).called(2);
        });

        test('fallback fetches more events than limit for sorting', () async {
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          await repository.getPopularVideos();

          final captured = verify(
            () => mockNostrClient.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
            ),
          ).captured;

          // First call: NIP-50 with exact limit
          final nip50Filters = captured[0] as List<Filter>;
          expect(nip50Filters.first.limit, equals(25));
          expect(nip50Filters.first.search, equals('sort:hot'));

          // Second call: fallback with multiplied limit
          // captured[1] contains filters from second call
          // (only filters are captured)
          final fallbackFilters = captured[1] as List<Filter>;
          expect(fallbackFilters.first.limit, equals(100)); // 25 * 4
          expect(fallbackFilters.first.search, isNull);
        });

        test('fallback respects custom fetch multiplier', () async {
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          await repository.getPopularVideos(fetchMultiplier: 2);

          final captured = verify(
            () => mockNostrClient.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
            ),
          ).captured;

          // Second call: fallback with multiplied limit
          // captured[1] contains filters from second call
          // (only filters are captured)
          final fallbackFilters = captured[1] as List<Filter>;
          expect(fallbackFilters.first.limit, equals(50)); // 25 * 2
        });

        test('fallback sorts by engagement score (highest first)', () async {
          final lowEngagement = _createVideoEvent(
            id: 'low',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/low.mp4',
            createdAt: 1704067200,
            loops: 10,
          );
          final highEngagement = _createVideoEvent(
            id: 'high',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/high.mp4',
            createdAt: 1704067201,
            loops: 1000,
          );

          var callCount = 0;
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return <Event>[]; // NIP-50 empty
            return [lowEngagement, highEngagement];
          });

          final result = await repository.getPopularVideos(limit: 2);

          expect(result, hasLength(2));
          expect(result.first.id, equals('high'));
          expect(result.last.id, equals('low'));
        });

        test('fallback returns only requested limit after sorting', () async {
          final events = List.generate(
            10,
            (i) => _createVideoEvent(
              id: 'video-$i',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/video$i.mp4',
              createdAt: 1704067200 + i,
              loops: i * 100,
            ),
          );

          var callCount = 0;
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return <Event>[]; // NIP-50 empty
            return events;
          });

          final result = await repository.getPopularVideos(limit: 3);

          expect(result, hasLength(3));
        });
      });

      test(
        'returns empty list when both NIP-50 and fallback return empty',
        () async {
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          final result = await repository.getPopularVideos();

          expect(result, isEmpty);
        },
      );

      group('in-memory cache', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;
        late InMemoryFeedCache feedCache;
        late VideosRepository repoWithCache;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          feedCache = InMemoryFeedCache();
          repoWithCache = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            inMemoryFeedCache: feedCache,
          );
        });

        test('returns cached result without network call', () async {
          when(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'pop1',
                pubkey: 'p1',
                dTag: 'd1',
                videoUrl: 'https://example.com/pop1.mp4',
              ),
            ],
          );

          await repoWithCache.getPopularVideos();
          final cached = await repoWithCache.getPopularVideos();

          verify(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).called(1);
          expect(cached, hasLength(1));
          expect(cached.first.id, equals('pop1'));
        });
      });

      group('with period (leaderboard path)', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          when(
            () => mockFunnelcakeClient.getBulkVideoStats(any()),
          ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
        });

        test('calls getLeaderboardVideos when period is set', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getLeaderboardVideos(
              period: any(named: 'period'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'lb-1',
                pubkey: 'pubkey-1',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/leaderboard.mp4',
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final videos = await repositoryWithApi.getPopularVideos(
            limit: 10,
            period: LeaderboardPeriod.week,
          );

          expect(videos, hasLength(1));
          expect(videos.first.id, equals('lb-1'));
          final captured = verify(
            () => mockFunnelcakeClient.getLeaderboardVideos(
              period: captureAny(named: 'period'),
              limit: captureAny(named: 'limit'),
              offset: captureAny(named: 'offset'),
            ),
          ).captured;
          expect(captured, equals([LeaderboardPeriod.week, 10, null]));
          verifyNever(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
        });

        test(
          'hydrates period leaderboard interaction counts before returning',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getLeaderboardVideos(
                period: any(named: 'period'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
              ),
            ).thenAnswer(
              (_) async => [
                _createVideoStats(
                  id: 'leaderboard-1',
                  pubkey: 'pubkey-1',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/leaderboard-1.mp4',
                  loops: 500,
                  views: 600,
                ),
              ],
            );
            when(
              () => mockFunnelcakeClient.getBulkVideoStats(['leaderboard-1']),
            ).thenAnswer(
              (_) async => const BulkVideoStatsResponse(
                stats: {
                  'leaderboard-1': BulkVideoStatsEntry(
                    eventId: 'leaderboard-1',
                    reactions: 21,
                    comments: 5,
                    reposts: 8,
                    loops: 501,
                    views: 601,
                  ),
                },
              ),
            );

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final videos = await repositoryWithApi.getPopularVideos(
              limit: 1,
              period: LeaderboardPeriod.week,
            );

            expect(videos, hasLength(1));
            expect(videos.single.originalLikes, isNull);
            expect(videos.single.originalComments, isNull);
            expect(videos.single.originalReposts, isNull);
            expect(videos.single.nostrLikeCount, equals(21));
            expect(videos.single.nostrCommentCount, equals(5));
            expect(videos.single.nostrRepostCount, equals(8));
            expect(videos.single.totalLikes, equals(21));
            verify(
              () => mockFunnelcakeClient.getBulkVideoStats(['leaderboard-1']),
            ).called(1);
          },
        );

        test('passes offset when provided (period path)', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getLeaderboardVideos(
              period: any(named: 'period'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((_) async => <VideoStats>[]);

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getPopularVideos(
            period: LeaderboardPeriod.month,
            offset: 100,
          );

          verify(
            () => mockFunnelcakeClient.getLeaderboardVideos(
              period: LeaderboardPeriod.month,
              limit: 25,
              offset: 100,
            ),
          ).called(1);
        });

        test(
          'returns empty list (no NIP-50 fallback) when leaderboard throws',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getLeaderboardVideos(
                period: any(named: 'period'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
              ),
            ).thenThrow(const FunnelcakeException('down'));

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final videos = await repositoryWithApi.getPopularVideos(
              limit: 10,
              period: LeaderboardPeriod.day,
            );

            expect(videos, isEmpty);
            verifyNever(
              () => mockNostrClient.queryEvents(
                any(),
                useCache: any(named: 'useCache'),
              ),
            );
          },
        );

        test('uses period-specific cache key '
            '(different periods do not share cache)', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getLeaderboardVideos(
              period: LeaderboardPeriod.week,
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'week-1',
                pubkey: 'p1',
                dTag: 'd1',
                videoUrl: 'https://example.com/week.mp4',
              ),
            ],
          );
          when(
            () => mockFunnelcakeClient.getLeaderboardVideos(
              period: LeaderboardPeriod.month,
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'month-1',
                pubkey: 'p1',
                dTag: 'd1',
                videoUrl: 'https://example.com/month.mp4',
              ),
            ],
          );

          final feedCache = InMemoryFeedCache();
          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            inMemoryFeedCache: feedCache,
          );

          await repositoryWithApi.getPopularVideos(
            period: LeaderboardPeriod.week,
          );
          await repositoryWithApi.getPopularVideos(
            period: LeaderboardPeriod.month,
          );
          // Both calls hit the network — cache is keyed by period.
          verify(
            () => mockFunnelcakeClient.getLeaderboardVideos(
              period: LeaderboardPeriod.week,
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).called(1);
          verify(
            () => mockFunnelcakeClient.getLeaderboardVideos(
              period: LeaderboardPeriod.month,
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).called(1);
        });

        test(
          'null period preserves existing watching path (no regression)',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getWatchingVideos(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => [
                _createVideoStats(
                  id: 'watching-1',
                  pubkey: 'p1',
                  dTag: 'd1',
                  videoUrl: 'https://example.com/watching.mp4',
                ),
              ],
            );

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final videos = await repositoryWithApi.getPopularVideos();

            expect(videos.first.id, equals('watching-1'));
            verifyNever(
              () => mockFunnelcakeClient.getLeaderboardVideos(
                period: any(named: 'period'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
              ),
            );
          },
        );
      });

      group('with v2 popular variant', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          when(
            () => mockFunnelcakeClient.getV2PopularVideosPage(
              variant: any(named: 'variant'),
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((invocation) async {
            final stats = await mockFunnelcakeClient.getV2PopularVideos(
              variant:
                  invocation.namedArguments[#variant] as PopularVideosVariant,
              limit: invocation.namedArguments[#limit] as int? ?? 25,
              before: invocation.namedArguments[#before] as int?,
            );
            return V2PopularVideosResponse(videos: stats);
          });
        });

        test('calls v2 API for classic popular videos', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getV2PopularVideos(
              variant: any(named: 'variant'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'classic-popular',
                pubkey: 'classic-pubkey',
                dTag: 'classic-dtag',
                videoUrl: 'https://example.com/classic.mp4',
                rawTags: const {'platform': 'vine'},
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getPopularVideos(
            variant: PopularVideosVariant.classic,
          );

          expect(result.single.id, equals('classic-popular'));
          verify(
            () => mockFunnelcakeClient.getV2PopularVideos(
              variant: PopularVideosVariant.classic,
              limit: 25,
            ),
          ).called(1);
          verifyNever(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
        });

        test('calls v2 API for native popular videos', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getV2PopularVideos(
              variant: any(named: 'variant'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => <VideoStats>[]);

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getPopularVideos(
            variant: PopularVideosVariant.native,
            limit: 10,
            until: 1704067200,
          );

          verify(
            () => mockFunnelcakeClient.getV2PopularVideos(
              variant: PopularVideosVariant.native,
              limit: 10,
              before: 1704067200,
            ),
          ).called(1);
        });

        test(
          'hydrates v2 native popular interaction counts before returning',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getV2PopularVideos(
                variant: any(named: 'variant'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => [
                _createVideoStats(
                  id: 'v2-native-popular-1',
                  pubkey: 'pubkey-1',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/v2-native-1.mp4',
                  loops: 200,
                  views: 300,
                ),
              ],
            );
            when(
              () => mockFunnelcakeClient.getBulkVideoStats([
                'v2-native-popular-1',
              ]),
            ).thenAnswer(
              (_) async => const BulkVideoStatsResponse(
                stats: {
                  'v2-native-popular-1': BulkVideoStatsEntry(
                    eventId: 'v2-native-popular-1',
                    reactions: 12,
                    comments: 3,
                    reposts: 4,
                    loops: 201,
                    views: 301,
                  ),
                },
              ),
            );

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repositoryWithApi.getPopularVideos(
              variant: PopularVideosVariant.native,
              limit: 1,
            );

            expect(result, hasLength(1));
            expect(result.single.originalLikes, isNull);
            expect(result.single.originalComments, isNull);
            expect(result.single.originalReposts, isNull);
            expect(result.single.nostrLikeCount, equals(12));
            expect(result.single.nostrCommentCount, equals(3));
            expect(result.single.nostrRepostCount, equals(4));
            expect(result.single.totalLikes, equals(12));
            verify(
              () => mockFunnelcakeClient.getBulkVideoStats([
                'v2-native-popular-1',
              ]),
            ).called(1);
          },
        );

        test('returns empty list when v2 API throws', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getV2PopularVideos(
              variant: any(named: 'variant'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenThrow(const FunnelcakeException('Network error'));

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getPopularVideos(
            variant: PopularVideosVariant.native,
          );

          expect(result, isEmpty);
        });
      });
    });

    group('content filtering', () {
      test('filters out videos from blocked pubkeys', () async {
        const blockedPubkey = 'blocked-user-pubkey';
        const allowedPubkey = 'allowed-user-pubkey';

        final filter = TestContentFilter(blockedPubkeys: {blockedPubkey});
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: filter.call,
        );

        final blockedEvent = _createVideoEvent(
          id: 'blocked-video',
          pubkey: blockedPubkey,
          videoUrl: 'https://example.com/blocked.mp4',
          createdAt: 1704067200,
        );
        final allowedEvent = _createVideoEvent(
          id: 'allowed-video',
          pubkey: allowedPubkey,
          videoUrl: 'https://example.com/allowed.mp4',
          createdAt: 1704067201,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [blockedEvent, allowedEvent]);

        final result = (await repositoryWithFilter.getNewVideos()).videos;

        expect(result, hasLength(1));
        expect(result.first.id, equals('allowed-video'));
        expect(result.first.pubkey, equals(allowedPubkey));

        // Verify filter was called for both pubkeys
        expect(filter.calls, contains(blockedPubkey));
        expect(filter.calls, contains(allowedPubkey));
      });

      test('filters deleted videos from event-id lookups', () async {
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          deletedFilter: (video) => video.id == 'deleted-video',
        );

        final deletedEvent = _createVideoEvent(
          id: 'deleted-video',
          pubkey: 'author-1',
          videoUrl: 'https://example.com/deleted.mp4',
          createdAt: 1704067200,
        );
        final visibleEvent = _createVideoEvent(
          id: 'visible-video',
          pubkey: 'author-1',
          videoUrl: 'https://example.com/visible.mp4',
          createdAt: 1704067201,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [deletedEvent, visibleEvent]);

        final result = await repositoryWithFilter.getVideosByIds([
          'deleted-video',
          'visible-video',
        ]);

        expect(result.map((video) => video.id), ['visible-video']);
      });

      test('filters deleted videos from addressable lookups', () async {
        const authorPubkey = 'addressable-author';
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          deletedFilter: (video) => video.addressableDTag == 'deleted-d',
        );

        final deletedEvent = _createVideoEventWithDTag(
          id: 'deleted-event-id',
          pubkey: authorPubkey,
          dTag: 'deleted-d',
          videoUrl: 'https://example.com/deleted.mp4',
          createdAt: 1704067200,
        );
        final visibleEvent = _createVideoEventWithDTag(
          id: 'visible-event-id',
          pubkey: authorPubkey,
          dTag: 'visible-d',
          videoUrl: 'https://example.com/visible.mp4',
          createdAt: 1704067201,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [deletedEvent, visibleEvent]);

        final result = await repositoryWithFilter.getVideosByAddressableIds([
          '${EventKind.videoVertical}:$authorPubkey:deleted-d',
          '${EventKind.videoVertical}:$authorPubkey:visible-d',
        ]);

        expect(result.map((video) => video.addressableDTag), ['visible-d']);
      });

      test('filters blocked pubkeys in home feed', () async {
        const blockedPubkey = 'blocked-followed-user';
        const allowedPubkey = 'allowed-followed-user';

        final filter = TestContentFilter(blockedPubkeys: {blockedPubkey});
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: filter.call,
        );

        final blockedEvent = _createVideoEvent(
          id: 'blocked-video',
          pubkey: blockedPubkey,
          videoUrl: 'https://example.com/blocked.mp4',
          createdAt: 1704067200,
        );
        final allowedEvent = _createVideoEvent(
          id: 'allowed-video',
          pubkey: allowedPubkey,
          videoUrl: 'https://example.com/allowed.mp4',
          createdAt: 1704067201,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [blockedEvent, allowedEvent]);

        final result = await repositoryWithFilter.getHomeFeedVideos(
          authors: [blockedPubkey, allowedPubkey],
        );

        expect(result.videos, hasLength(1));
        expect(result.videos.first.pubkey, equals(allowedPubkey));
      });

      test('filters blocked pubkeys in popular feed', () async {
        const blockedPubkey = 'blocked-popular-user';
        const allowedPubkey = 'allowed-popular-user';

        final filter = TestContentFilter(blockedPubkeys: {blockedPubkey});
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: filter.call,
        );

        final blockedEvent = _createVideoEvent(
          id: 'blocked-video',
          pubkey: blockedPubkey,
          videoUrl: 'https://example.com/blocked.mp4',
          createdAt: 1704067200,
          loops: 1000,
        );
        final allowedEvent = _createVideoEvent(
          id: 'allowed-video',
          pubkey: allowedPubkey,
          videoUrl: 'https://example.com/allowed.mp4',
          createdAt: 1704067201,
          loops: 500,
        );

        when(
          () => mockNostrClient.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => [blockedEvent, allowedEvent]);

        final result = await repositoryWithFilter.getPopularVideos();

        expect(result, hasLength(1));
        expect(result.first.pubkey, equals(allowedPubkey));
      });

      test('works correctly without content filter (null)', () async {
        // Use the default repository without filter
        final event = _createVideoEvent(
          id: 'video-1',
          pubkey: 'any-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final result = (await repository.getNewVideos()).videos;

        expect(result, hasLength(1));
        expect(result.first.id, equals('video-1'));
      });

      test('filters all videos if all pubkeys are blocked', () async {
        final filter = TestContentFilter(blockedPubkeys: {'user-1', 'user-2'});
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: filter.call,
        );

        final events = [
          _createVideoEvent(
            id: 'video-1',
            pubkey: 'user-1',
            videoUrl: 'https://example.com/video1.mp4',
            createdAt: 1704067200,
          ),
          _createVideoEvent(
            id: 'video-2',
            pubkey: 'user-2',
            videoUrl: 'https://example.com/video2.mp4',
            createdAt: 1704067201,
          ),
        ];

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => events);

        final result = (await repositoryWithFilter.getNewVideos()).videos;

        expect(result, isEmpty);
      });

      test('checks filter before parsing event to VideoEvent', () async {
        // This test verifies that filtering happens before the potentially
        // expensive VideoEvent.fromNostrEvent() call
        const blockedPubkey = 'blocked-user';

        final filter = TestContentFilter(blockedPubkeys: {blockedPubkey});
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: filter.call,
        );

        final blockedEvent = _createVideoEvent(
          id: 'blocked-video',
          pubkey: blockedPubkey,
          videoUrl: 'https://example.com/blocked.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [blockedEvent]);

        final result = (await repositoryWithFilter.getNewVideos()).videos;

        expect(result, isEmpty);
        // Filter was called with the raw event pubkey
        expect(filter.calls, contains(blockedPubkey));
      });
    });

    group('getVideosByIds', () {
      test('returns empty list when eventIds is empty', () async {
        final result = await repository.getVideosByIds([]);

        expect(result, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('queries with correct filter for event IDs', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        final eventIds = ['id-1', 'id-2', 'id-3'];
        await repository.getVideosByIds(eventIds);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters, hasLength(1));
        expect(filters.first.ids, equals(eventIds));
        expect(filters.first.kinds, equals(NIP71VideoKinds.getAllVideoKinds()));
      });

      test('transforms valid events to VideoEvents', () async {
        final event = _createVideoEvent(
          id: 'test-id-123',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final result = await repository.getVideosByIds(['test-id-123']);

        expect(result, hasLength(1));
        expect(result.first.id, equals('test-id-123'));
        expect(result.first.videoUrl, equals('https://example.com/video.mp4'));
      });

      test('preserves input order of event IDs', () async {
        final event1 = _createVideoEvent(
          id: 'id-1',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video1.mp4',
          createdAt: 1704067200,
        );
        final event2 = _createVideoEvent(
          id: 'id-2',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video2.mp4',
          createdAt: 1704067201,
        );
        final event3 = _createVideoEvent(
          id: 'id-3',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video3.mp4',
          createdAt: 1704067202,
        );

        // Return events in different order than requested
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event3, event1, event2]);

        final result = await repository.getVideosByIds([
          'id-1',
          'id-2',
          'id-3',
        ]);

        expect(result, hasLength(3));
        expect(result[0].id, equals('id-1'));
        expect(result[1].id, equals('id-2'));
        expect(result[2].id, equals('id-3'));
      });

      test('filters out videos without valid URL', () async {
        final validEvent = _createVideoEvent(
          id: 'valid-id',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );
        final invalidEvent = _createVideoEvent(
          id: 'invalid-id',
          pubkey: 'test-pubkey',
          videoUrl: null,
          createdAt: 1704067201,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [validEvent, invalidEvent]);

        final result = await repository.getVideosByIds([
          'valid-id',
          'invalid-id',
        ]);

        expect(result, hasLength(1));
        expect(result.first.id, equals('valid-id'));
      });

      test('handles missing events gracefully', () async {
        final event = _createVideoEvent(
          id: 'found-id',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final result = await repository.getVideosByIds([
          'found-id',
          'missing-id-1',
          'missing-id-2',
        ]);

        expect(result, hasLength(1));
        expect(result.first.id, equals('found-id'));
      });

      test('filters out videos from blocked pubkeys', () async {
        const blockedPubkey = 'blocked-user-pubkey';
        const allowedPubkey = 'allowed-user-pubkey';

        final filter = TestContentFilter(blockedPubkeys: {blockedPubkey});
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: filter.call,
        );

        final blockedEvent = _createVideoEvent(
          id: 'blocked-video',
          pubkey: blockedPubkey,
          videoUrl: 'https://example.com/blocked.mp4',
          createdAt: 1704067200,
        );
        final allowedEvent = _createVideoEvent(
          id: 'allowed-video',
          pubkey: allowedPubkey,
          videoUrl: 'https://example.com/allowed.mp4',
          createdAt: 1704067201,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [blockedEvent, allowedEvent]);

        final result = await repositoryWithFilter.getVideosByIds([
          'blocked-video',
          'allowed-video',
        ]);

        expect(result, hasLength(1));
        expect(result.first.id, equals('allowed-video'));
      });

      test('filters videos with NSFW hashtag when filter is active', () async {
        final nsfwFilter = TestNsfwFilter();
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          contentFilter: nsfwFilter.call,
        );

        final nsfwEvent = _createVideoEvent(
          id: 'nsfw-video',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/nsfw.mp4',
          createdAt: 1704067200,
          hashtags: ['nsfw'],
        );
        final safeEvent = _createVideoEvent(
          id: 'safe-video',
          pubkey: 'user-2',
          videoUrl: 'https://example.com/safe.mp4',
          createdAt: 1704067201,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [nsfwEvent, safeEvent]);

        final result = await repositoryWithFilter.getVideosByIds([
          'nsfw-video',
          'safe-video',
        ]);

        expect(result, hasLength(1));
        expect(result.first.id, equals('safe-video'));
      });

      group('with Funnelcake bulk-stats hydration', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        });

        test(
          'fills loop counts from bulk stats when relay event has loops: 0',
          () async {
            const eventId = 'liked-tab-video-id';
            final event = _createVideoEvent(
              id: eventId,
              pubkey: 'author-pubkey',
              videoUrl: 'https://example.com/video.mp4',
              createdAt: 1704067200,
              loops: 0,
            );

            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => [event]);
            when(
              () => mockFunnelcakeClient.getBulkVideoStats([eventId]),
            ).thenAnswer(
              (_) async => const BulkVideoStatsResponse(
                stats: {
                  eventId: BulkVideoStatsEntry(
                    eventId: eventId,
                    reactions: 1,
                    comments: 2,
                    reposts: 3,
                    embeddedLoops: 42,
                  ),
                },
              ),
            );

            final repo = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repo.getVideosByIds([eventId]);

            expect(result, hasLength(1));
            expect(result.single.originalLoops, equals(42));
            verify(
              () => mockFunnelcakeClient.getBulkVideoStats([eventId]),
            ).called(1);
          },
        );
      });
    });

    group('getVideosByAddressableIds', () {
      test('returns empty list when addressableIds is empty', () async {
        final result = await repository.getVideosByAddressableIds([]);

        expect(result, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('returns empty list when all addressableIds are invalid', () async {
        final result = await repository.getVideosByAddressableIds([
          'invalid-format',
          'also:invalid', // missing d-tag
        ]);

        expect(result, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('queries with correct filters for addressable IDs', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        final addressableIds = [
          '${EventKind.videoVertical}:pubkey1:dtag1',
          '${EventKind.videoVertical}:pubkey2:dtag2',
        ];
        await repository.getVideosByAddressableIds(addressableIds);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters, hasLength(2));
        expect(filters[0].kinds, equals([EventKind.videoVertical]));
        expect(filters[0].authors, equals(['pubkey1']));
        expect(filters[0].d, equals(['dtag1']));
        // No limit - addressable events are unique by kind:pubkey:d-tag
        expect(filters[1].kinds, equals([EventKind.videoVertical]));
        expect(filters[1].authors, equals(['pubkey2']));
        expect(filters[1].d, equals(['dtag2']));
      });

      test('transforms valid events to VideoEvents', () async {
        final event = _createVideoEvent(
          id: 'test-id-123',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final result = await repository.getVideosByAddressableIds([
          '${EventKind.videoVertical}:test-pubkey:test-id-123',
        ]);

        expect(result, hasLength(1));
        expect(result.first.id, equals('test-id-123'));
        expect(result.first.videoUrl, equals('https://example.com/video.mp4'));
      });

      test('preserves input order of addressable IDs', () async {
        final event1 = _createVideoEvent(
          id: 'dtag-1',
          pubkey: 'pubkey-1',
          videoUrl: 'https://example.com/video1.mp4',
          createdAt: 1704067200,
        );
        final event2 = _createVideoEvent(
          id: 'dtag-2',
          pubkey: 'pubkey-2',
          videoUrl: 'https://example.com/video2.mp4',
          createdAt: 1704067201,
        );
        final event3 = _createVideoEvent(
          id: 'dtag-3',
          pubkey: 'pubkey-3',
          videoUrl: 'https://example.com/video3.mp4',
          createdAt: 1704067202,
        );

        // Return events in different order than requested
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event3, event1, event2]);

        final result = await repository.getVideosByAddressableIds([
          '${EventKind.videoVertical}:pubkey-1:dtag-1',
          '${EventKind.videoVertical}:pubkey-2:dtag-2',
          '${EventKind.videoVertical}:pubkey-3:dtag-3',
        ]);

        expect(result, hasLength(3));
        expect(result[0].vineId, equals('dtag-1'));
        expect(result[1].vineId, equals('dtag-2'));
        expect(result[2].vineId, equals('dtag-3'));
      });

      test('handles d-tags with colons', () async {
        final event = _createVideoEventWithDTag(
          id: 'test-id',
          pubkey: 'test-pubkey',
          dTag: 'dtag:with:colons',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final result = await repository.getVideosByAddressableIds([
          '${EventKind.videoVertical}:test-pubkey:dtag:with:colons',
        ]);

        expect(result, hasLength(1));
        expect(result.first.vineId, equals('dtag:with:colons'));
      });

      test('filters out videos without valid URL', () async {
        final validEvent = _createVideoEvent(
          id: 'valid-dtag',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );
        final invalidEvent = _createVideoEvent(
          id: 'invalid-dtag',
          pubkey: 'test-pubkey',
          videoUrl: null,
          createdAt: 1704067201,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [validEvent, invalidEvent]);

        final result = await repository.getVideosByAddressableIds([
          '${EventKind.videoVertical}:test-pubkey:valid-dtag',
          '${EventKind.videoVertical}:test-pubkey:invalid-dtag',
        ]);

        expect(result, hasLength(1));
        expect(result.first.vineId, equals('valid-dtag'));
      });

      test('handles missing events gracefully', () async {
        final event = _createVideoEvent(
          id: 'found-dtag',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final result = await repository.getVideosByAddressableIds([
          '${EventKind.videoVertical}:test-pubkey:found-dtag',
          '${EventKind.videoVertical}:other-pubkey:missing-dtag-1',
          '${EventKind.videoVertical}:another-pubkey:missing-dtag-2',
        ]);

        expect(result, hasLength(1));
        expect(result.first.vineId, equals('found-dtag'));
      });

      test('filters out non-video kinds', () async {
        // Should skip filters for non-video kinds
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        final result = await repository.getVideosByAddressableIds([
          '1:pubkey:dtag', // kind 1 is not a video kind
          '30023:pubkey:dtag', // kind 30023 is not a video kind
        ]);

        expect(result, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('filters out videos from blocked pubkeys', () async {
        const blockedPubkey = 'blocked-user-pubkey';
        const allowedPubkey = 'allowed-user-pubkey';

        final filter = TestContentFilter(blockedPubkeys: {blockedPubkey});
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: filter.call,
        );

        final blockedEvent = _createVideoEvent(
          id: 'blocked-dtag',
          pubkey: blockedPubkey,
          videoUrl: 'https://example.com/blocked.mp4',
          createdAt: 1704067200,
        );
        final allowedEvent = _createVideoEvent(
          id: 'allowed-dtag',
          pubkey: allowedPubkey,
          videoUrl: 'https://example.com/allowed.mp4',
          createdAt: 1704067201,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [blockedEvent, allowedEvent]);

        final result = await repositoryWithFilter.getVideosByAddressableIds([
          '${EventKind.videoVertical}:$blockedPubkey:blocked-dtag',
          '${EventKind.videoVertical}:$allowedPubkey:allowed-dtag',
        ]);

        expect(result, hasLength(1));
        expect(result.first.vineId, equals('allowed-dtag'));
      });

      test('filters videos with NSFW hashtag when filter is active', () async {
        final nsfwFilter = TestNsfwFilter();
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          contentFilter: nsfwFilter.call,
        );

        final nsfwEvent = _createVideoEvent(
          id: 'nsfw-dtag',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/nsfw.mp4',
          createdAt: 1704067200,
          hashtags: ['nsfw'],
        );
        final safeEvent = _createVideoEvent(
          id: 'safe-dtag',
          pubkey: 'user-2',
          videoUrl: 'https://example.com/safe.mp4',
          createdAt: 1704067201,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [nsfwEvent, safeEvent]);

        final result = await repositoryWithFilter.getVideosByAddressableIds([
          '${EventKind.videoVertical}:user-1:nsfw-dtag',
          '${EventKind.videoVertical}:user-2:safe-dtag',
        ]);

        expect(result, hasLength(1));
        expect(result.first.vineId, equals('safe-dtag'));
      });

      group('with Funnelcake bulk-stats hydration', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        });

        test(
          'fills loop counts from bulk stats when relay event has loops: 0',
          () async {
            const author =
                '4bf0c63fcb93463407af97a5e5ee64fa'
                '883d107ef9e558472c4eb9aaaefa459d';
            const dTag = 'reposted-vine';
            const eventId =
                'b695f6b60119d9521934a691347d9f78'
                'e8770b56da16bb255ee77ac112b4c1f6';
            const addressableId = '${EventKind.videoVertical}:$author:$dTag';
            final event = _createVideoEventWithDTag(
              id: eventId,
              pubkey: author,
              dTag: dTag,
              videoUrl: 'https://example.com/video.mp4',
              createdAt: 1704067200,
              loops: 0,
            );

            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => [event]);
            when(
              () => mockFunnelcakeClient.getBulkVideoStats([eventId]),
            ).thenAnswer(
              (_) async => const BulkVideoStatsResponse(
                stats: {
                  eventId: BulkVideoStatsEntry(
                    eventId: eventId,
                    reactions: 0,
                    comments: 0,
                    reposts: 0,
                    embeddedLoops: 99,
                  ),
                },
              ),
            );

            final repo = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repo.getVideosByAddressableIds([
              addressableId,
            ]);

            expect(result, hasLength(1));
            expect(result.single.originalLoops, equals(99));
            verify(
              () => mockFunnelcakeClient.getBulkVideoStats([eventId]),
            ).called(1);
          },
        );
      });

      group('Funnelcake API fallback', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
        });

        test('does not call Funnelcake API when client is null', () async {
          // Repository without Funnelcake client
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          final result = await repository.getVideosByAddressableIds([
            '${EventKind.videoVertical}:pubkey1:dtag1',
          ]);

          expect(result, isEmpty);
          // No FunnelcakeApiClient calls since none was provided
        });

        test(
          'does not call Funnelcake API when isAvailable is false',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

            final repositoryWithFunnelcake = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => <Event>[]);

            final result = await repositoryWithFunnelcake
                .getVideosByAddressableIds([
                  '${EventKind.videoVertical}:pubkey1:dtag1',
                ]);

            expect(result, isEmpty);
            verifyNever(
              () => mockFunnelcakeClient.getVideosByAuthor(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            );
          },
        );

        test(
          'does not call Funnelcake API when all videos found on Nostr',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

            final repositoryWithFunnelcake = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final event = _createVideoEvent(
              id: 'dtag1',
              pubkey: 'pubkey1',
              videoUrl: 'https://example.com/video.mp4',
              createdAt: 1704067200,
            );

            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => [event]);

            final result = await repositoryWithFunnelcake
                .getVideosByAddressableIds([
                  '${EventKind.videoVertical}:pubkey1:dtag1',
                ]);

            expect(result, hasLength(1));
            verifyNever(
              () => mockFunnelcakeClient.getVideosByAuthor(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            );
          },
        );

        test(
          'uses Funnelcake API fallback when Nostr returns no videos',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

            final repositoryWithFunnelcake = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            // Nostr returns nothing
            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => <Event>[]);

            // Funnelcake returns the video
            final videoStats = _createVideoStats(
              id: 'event-id-1',
              pubkey: 'pubkey1',
              dTag: 'dtag1',
              videoUrl: 'https://example.com/video.mp4',
            );

            when(
              () => mockFunnelcakeClient.getVideosByAuthor(
                pubkey: 'pubkey1',
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => VideosByAuthorResponse(videos: [videoStats]),
            );

            final result = await repositoryWithFunnelcake
                .getVideosByAddressableIds([
                  '${EventKind.videoVertical}:pubkey1:dtag1',
                ]);

            expect(result, hasLength(1));
            expect(result.first.vineId, equals('dtag1'));
            verify(
              () => mockFunnelcakeClient.getVideosByAuthor(
                pubkey: 'pubkey1',
                limit: any(named: 'limit', that: equals(50)),
                before: any(named: 'before'),
              ),
            ).called(1);
          },
        );

        test(
          'combines Nostr results with Funnelcake fallback results',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

            final repositoryWithFunnelcake = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            // Nostr returns only one video
            final nostrEvent = _createVideoEvent(
              id: 'dtag1',
              pubkey: 'pubkey1',
              videoUrl: 'https://example.com/video1.mp4',
              createdAt: 1704067200,
            );

            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => [nostrEvent]);

            // Funnelcake returns the second video
            final videoStats = _createVideoStats(
              id: 'event-id-2',
              pubkey: 'pubkey2',
              dTag: 'dtag2',
              videoUrl: 'https://example.com/video2.mp4',
            );

            when(
              () => mockFunnelcakeClient.getVideosByAuthor(
                pubkey: 'pubkey2',
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => VideosByAuthorResponse(videos: [videoStats]),
            );

            final result = await repositoryWithFunnelcake
                .getVideosByAddressableIds([
                  '${EventKind.videoVertical}:pubkey1:dtag1',
                  '${EventKind.videoVertical}:pubkey2:dtag2',
                ]);

            expect(result, hasLength(2));
            expect(result[0].vineId, equals('dtag1'));
            expect(result[1].vineId, equals('dtag2'));
          },
        );

        test('preserves original addressable ID order with fallback', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

          final repositoryWithFunnelcake = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Nostr returns video 2 (not video 1 or 3)
          final nostrEvent = _createVideoEvent(
            id: 'dtag2',
            pubkey: 'pubkey2',
            videoUrl: 'https://example.com/video2.mp4',
            createdAt: 1704067200,
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [nostrEvent]);

          // Funnelcake returns videos 1 and 3
          final videoStats1 = _createVideoStats(
            id: 'event-id-1',
            pubkey: 'pubkey1',
            dTag: 'dtag1',
            videoUrl: 'https://example.com/video1.mp4',
          );
          final videoStats3 = _createVideoStats(
            id: 'event-id-3',
            pubkey: 'pubkey3',
            dTag: 'dtag3',
            videoUrl: 'https://example.com/video3.mp4',
          );

          when(
            () => mockFunnelcakeClient.getVideosByAuthor(
              pubkey: 'pubkey1',
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => VideosByAuthorResponse(videos: [videoStats1]),
          );

          when(
            () => mockFunnelcakeClient.getVideosByAuthor(
              pubkey: 'pubkey3',
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => VideosByAuthorResponse(videos: [videoStats3]),
          );

          final result = await repositoryWithFunnelcake
              .getVideosByAddressableIds([
                '${EventKind.videoVertical}:pubkey1:dtag1',
                '${EventKind.videoVertical}:pubkey2:dtag2',
                '${EventKind.videoVertical}:pubkey3:dtag3',
              ]);

          expect(result, hasLength(3));
          // Order should match input addressable IDs
          expect(result[0].vineId, equals('dtag1'));
          expect(result[1].vineId, equals('dtag2'));
          expect(result[2].vineId, equals('dtag3'));
        });

        test('handles Funnelcake API failure gracefully', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

          final repositoryWithFunnelcake = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Nostr returns one video
          final nostrEvent = _createVideoEvent(
            id: 'dtag1',
            pubkey: 'pubkey1',
            videoUrl: 'https://example.com/video1.mp4',
            createdAt: 1704067200,
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [nostrEvent]);

          // Funnelcake throws an exception
          when(
            () => mockFunnelcakeClient.getVideosByAuthor(
              pubkey: 'pubkey2',
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenThrow(const FunnelcakeException('Network error'));

          // Should not throw, just return what Nostr found
          final result = await repositoryWithFunnelcake
              .getVideosByAddressableIds([
                '${EventKind.videoVertical}:pubkey1:dtag1',
                '${EventKind.videoVertical}:pubkey2:dtag2',
              ]);

          expect(result, hasLength(1));
          expect(result.first.vineId, equals('dtag1'));
        });

        test('applies block filter to Funnelcake API results', () async {
          const blockedPubkey = 'blocked-pubkey';

          final filter = TestContentFilter(blockedPubkeys: {blockedPubkey});
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

          final repositoryWithFilter = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            blockFilter: filter.call,
          );

          // Nostr returns nothing
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          // Funnelcake returns a video from blocked pubkey
          final videoStats = _createVideoStats(
            id: 'event-id-1',
            pubkey: blockedPubkey,
            dTag: 'dtag1',
            videoUrl: 'https://example.com/video.mp4',
          );

          when(
            () => mockFunnelcakeClient.getVideosByAuthor(
              pubkey: blockedPubkey,
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => VideosByAuthorResponse(videos: [videoStats]),
          );

          final result = await repositoryWithFilter.getVideosByAddressableIds([
            '${EventKind.videoVertical}:$blockedPubkey:dtag1',
          ]);

          // Should be filtered out
          expect(result, isEmpty);
        });

        test('filters out Funnelcake results without video URL', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

          final repositoryWithFunnelcake = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Nostr returns nothing
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          // Funnelcake returns a video without URL
          final videoStats = _createVideoStats(
            id: 'event-id-1',
            pubkey: 'pubkey1',
            dTag: 'dtag1',
            videoUrl: '', // No video URL
          );

          when(
            () => mockFunnelcakeClient.getVideosByAuthor(
              pubkey: 'pubkey1',
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => VideosByAuthorResponse(videos: [videoStats]),
          );

          final result = await repositoryWithFunnelcake
              .getVideosByAddressableIds([
                '${EventKind.videoVertical}:pubkey1:dtag1',
              ]);

          expect(result, isEmpty);
        });

        test('batches Funnelcake requests by pubkey', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

          final repositoryWithFunnelcake = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Nostr returns nothing
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          // Funnelcake returns both videos from the same author
          final videoStats1 = _createVideoStats(
            id: 'event-id-1',
            pubkey: 'same-pubkey',
            dTag: 'dtag1',
            videoUrl: 'https://example.com/video1.mp4',
          );
          final videoStats2 = _createVideoStats(
            id: 'event-id-2',
            pubkey: 'same-pubkey',
            dTag: 'dtag2',
            videoUrl: 'https://example.com/video2.mp4',
          );

          when(
            () => mockFunnelcakeClient.getVideosByAuthor(
              pubkey: 'same-pubkey',
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async =>
                VideosByAuthorResponse(videos: [videoStats1, videoStats2]),
          );

          final result = await repositoryWithFunnelcake
              .getVideosByAddressableIds([
                '${EventKind.videoVertical}:same-pubkey:dtag1',
                '${EventKind.videoVertical}:same-pubkey:dtag2',
              ]);

          expect(result, hasLength(2));
          // Should only make one API call for the same pubkey
          verify(
            () => mockFunnelcakeClient.getVideosByAuthor(
              pubkey: 'same-pubkey',
              limit: any(named: 'limit', that: equals(50)),
              before: any(named: 'before'),
            ),
          ).called(1);
        });
      });
    });

    group('video event filtering (stage 2)', () {
      test('filters videos with NSFW hashtag when filter is active', () async {
        final nsfwFilter = TestNsfwFilter();
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          contentFilter: nsfwFilter.call,
        );

        final nsfwEvent = _createVideoEvent(
          id: 'nsfw-video',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/nsfw.mp4',
          createdAt: 1704067200,
          hashtags: ['nsfw', 'other'],
        );
        final safeEvent = _createVideoEvent(
          id: 'safe-video',
          pubkey: 'user-2',
          videoUrl: 'https://example.com/safe.mp4',
          createdAt: 1704067201,
          hashtags: ['funny', 'cat'],
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [nsfwEvent, safeEvent]);

        final result = (await repositoryWithFilter.getNewVideos()).videos;

        expect(result, hasLength(1));
        expect(result.first.id, equals('safe-video'));
        expect(nsfwFilter.calls, hasLength(2));
      });

      test('filters videos with adult hashtag', () async {
        final nsfwFilter = TestNsfwFilter();
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          contentFilter: nsfwFilter.call,
        );

        final adultEvent = _createVideoEvent(
          id: 'adult-video',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/adult.mp4',
          createdAt: 1704067200,
          hashtags: ['adult'],
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [adultEvent]);

        final result = (await repositoryWithFilter.getNewVideos()).videos;

        expect(result, isEmpty);
      });

      test('filters videos with content-warning tag', () async {
        final nsfwFilter = TestNsfwFilter();
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          contentFilter: nsfwFilter.call,
        );

        final cwEvent = _createVideoEvent(
          id: 'cw-video',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/cw.mp4',
          createdAt: 1704067200,
          hasContentWarning: true,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [cwEvent]);

        final result = (await repositoryWithFilter.getNewVideos()).videos;

        expect(result, isEmpty);
      });

      test('does not filter when videoEventFilter is null', () async {
        // Use default repository without filter
        final nsfwEvent = _createVideoEvent(
          id: 'nsfw-video',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/nsfw.mp4',
          createdAt: 1704067200,
          hashtags: ['nsfw'],
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [nsfwEvent]);

        final result = (await repository.getNewVideos()).videos;

        expect(result, hasLength(1));
        expect(result.first.id, equals('nsfw-video'));
      });

      test('does not filter NSFW when filter returns false', () async {
        final nsfwFilter = TestNsfwFilter(filterNsfw: false);
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          contentFilter: nsfwFilter.call,
        );

        final nsfwEvent = _createVideoEvent(
          id: 'nsfw-video',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/nsfw.mp4',
          createdAt: 1704067200,
          hashtags: ['nsfw'],
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [nsfwEvent]);

        final result = (await repositoryWithFilter.getNewVideos()).videos;

        expect(result, hasLength(1));
        expect(nsfwFilter.calls, hasLength(1));
      });

      test('applies both content filter and video event filter', () async {
        const blockedPubkey = 'blocked-user';
        final contentFilter = TestContentFilter(
          blockedPubkeys: {blockedPubkey},
        );
        final nsfwFilter = TestNsfwFilter();

        final repositoryWithBothFilters = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: contentFilter.call,
          contentFilter: nsfwFilter.call,
        );

        final blockedEvent = _createVideoEvent(
          id: 'blocked-video',
          pubkey: blockedPubkey,
          videoUrl: 'https://example.com/blocked.mp4',
          createdAt: 1704067200,
        );
        final nsfwEvent = _createVideoEvent(
          id: 'nsfw-video',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/nsfw.mp4',
          createdAt: 1704067201,
          hashtags: ['nsfw'],
        );
        final safeEvent = _createVideoEvent(
          id: 'safe-video',
          pubkey: 'user-2',
          videoUrl: 'https://example.com/safe.mp4',
          createdAt: 1704067202,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [blockedEvent, nsfwEvent, safeEvent]);

        final result = (await repositoryWithBothFilters.getNewVideos()).videos;

        expect(result, hasLength(1));
        expect(result.first.id, equals('safe-video'));

        // Content filter was called for all events
        expect(contentFilter.calls, hasLength(3));

        // Video event filter was only called for non-blocked events
        // (blocked event filtered in stage 1, so stage 2 only sees 2 events)
        expect(nsfwFilter.calls, hasLength(2));
      });

      test('video event filter is called after parsing', () async {
        final filter = TestVideoEventFilter();
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          contentFilter: filter.call,
        );

        final event = _createVideoEvent(
          id: 'video-1',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        await repositoryWithFilter.getNewVideos();

        // Filter received a parsed VideoEvent, not raw Event
        expect(filter.calls, hasLength(1));
        expect(filter.calls.first.id, equals('video-1'));
        expect(filter.calls.first.pubkey, equals('user-1'));
      });

      test('applies warn labels from relay content-warning tags', () async {
        final event = _createVideoEvent(
          id: 'cw-video',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
          hasContentWarning: true,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final repositoryWithResolver = VideosRepository(
          nostrClient: mockNostrClient,
          warningLabelsResolver: (video) => video.contentWarningLabels,
        );

        final result = (await repositoryWithResolver.getNewVideos()).videos;

        expect(result, hasLength(1));
        expect(result.first.warnLabels, equals(['adult content']));
      });
    });

    group('local storage caching', () {
      late MockVideoLocalStorage mockLocalStorage;

      setUp(() {
        mockLocalStorage = MockVideoLocalStorage();
      });

      setUpAll(() {
        registerFallbackValue(<Event>[]);
      });

      group('getVideosByIds with localStorage', () {
        test('returns cached events from localStorage', () async {
          final cachedEvent = _createVideoEvent(
            id: 'cached-id',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/cached.mp4',
            createdAt: 1704067200,
          );

          when(
            () => mockLocalStorage.getEventsByIds(any()),
          ).thenAnswer((_) async => [cachedEvent]);

          final repositoryWithCache = VideosRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          final result = await repositoryWithCache.getVideosByIds([
            'cached-id',
          ]);

          expect(result, hasLength(1));
          expect(result.first.id, equals('cached-id'));
          // Should not query relay since all events were cached
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test(
          'queries relay for missing events when cache partial hit',
          () async {
            final cachedEvent = _createVideoEvent(
              id: 'cached-id',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/cached.mp4',
              createdAt: 1704067200,
            );
            final relayEvent = _createVideoEvent(
              id: 'relay-id',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/relay.mp4',
              createdAt: 1704067201,
            );

            when(
              () => mockLocalStorage.getEventsByIds(any()),
            ).thenAnswer((_) async => [cachedEvent]);
            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => [relayEvent]);
            when(
              () => mockLocalStorage.saveEventsBatch(any()),
            ).thenAnswer((_) async {});

            final repositoryWithCache = VideosRepository(
              nostrClient: mockNostrClient,
              localStorage: mockLocalStorage,
            );

            final result = await repositoryWithCache.getVideosByIds([
              'cached-id',
              'relay-id',
            ], cacheResults: true);

            expect(result, hasLength(2));
            // Preserves input order
            expect(result[0].id, equals('cached-id'));
            expect(result[1].id, equals('relay-id'));
            // Should query relay for missing event
            verify(() => mockNostrClient.queryEvents(any())).called(1);
          },
        );

        test(
          'saves fetched events to cache when cacheResults is true',
          () async {
            final relayEvent = _createVideoEvent(
              id: 'relay-id',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/relay.mp4',
              createdAt: 1704067200,
            );

            when(
              () => mockLocalStorage.getEventsByIds(any()),
            ).thenAnswer((_) async => <Event>[]);
            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => [relayEvent]);
            when(
              () => mockLocalStorage.saveEventsBatch(any()),
            ).thenAnswer((_) async {});

            final repositoryWithCache = VideosRepository(
              nostrClient: mockNostrClient,
              localStorage: mockLocalStorage,
            );

            await repositoryWithCache.getVideosByIds([
              'relay-id',
            ], cacheResults: true);

            verify(
              () => mockLocalStorage.saveEventsBatch([relayEvent]),
            ).called(1);
          },
        );

        test('does not save to cache when cacheResults is false', () async {
          final relayEvent = _createVideoEvent(
            id: 'relay-id',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/relay.mp4',
            createdAt: 1704067200,
          );

          when(
            () => mockLocalStorage.getEventsByIds(any()),
          ).thenAnswer((_) async => <Event>[]);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [relayEvent]);

          final repositoryWithCache = VideosRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          await repositoryWithCache.getVideosByIds(['relay-id']);

          verifyNever(() => mockLocalStorage.saveEventsBatch(any()));
        });
      });

      group('getVideosByAddressableIds with localStorage', () {
        test(
          'saves fetched events to cache when cacheResults is true',
          () async {
            final relayEvent = _createVideoEvent(
              id: 'dtag1',
              pubkey: 'pubkey1',
              videoUrl: 'https://example.com/video.mp4',
              createdAt: 1704067200,
            );

            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => [relayEvent]);
            when(
              () => mockLocalStorage.saveEventsBatch(any()),
            ).thenAnswer((_) async {});

            final repositoryWithCache = VideosRepository(
              nostrClient: mockNostrClient,
              localStorage: mockLocalStorage,
            );

            await repositoryWithCache.getVideosByAddressableIds([
              '${EventKind.videoVertical}:pubkey1:dtag1',
            ], cacheResults: true);

            verify(
              () => mockLocalStorage.saveEventsBatch([relayEvent]),
            ).called(1);
          },
        );

        test('does not save to cache when cacheResults is false', () async {
          final relayEvent = _createVideoEvent(
            id: 'dtag1',
            pubkey: 'pubkey1',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1704067200,
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [relayEvent]);

          final repositoryWithCache = VideosRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          await repositoryWithCache.getVideosByAddressableIds([
            '${EventKind.videoVertical}:pubkey1:dtag1',
          ]);

          verifyNever(() => mockLocalStorage.saveEventsBatch(any()));
        });

        test('does not save to cache when no events are fetched', () async {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => <Event>[]);

          final repositoryWithCache = VideosRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          await repositoryWithCache.getVideosByAddressableIds([
            '${EventKind.videoVertical}:pubkey1:dtag1',
          ], cacheResults: true);

          verifyNever(() => mockLocalStorage.saveEventsBatch(any()));
        });
      });
    });

    group('getCollabVideos', () {
      test('returns empty list when Funnelcake is not configured', () async {
        final result = await repository.getCollabVideos(
          taggedPubkey: 'collab-pubkey',
        );

        expect(result, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      group('Funnelcake confirmed collabs', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
        });

        test('returns API results when Funnelcake succeeds', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getCollabVideos(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'collab-event-1',
                pubkey: 'author-pubkey',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/collab.mp4',
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getCollabVideos(
            taggedPubkey: 'collab-pubkey',
          );

          expect(result, hasLength(1));
          expect(
            result.first.videoUrl,
            equals('https://example.com/collab.mp4'),
          );
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test(
          'preserves collaboratorPubkeys from Funnelcake REST response',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getCollabVideos(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => [
                _createVideoStats(
                  id: 'collab-event-1',
                  pubkey: 'author-pubkey',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/collab.mp4',
                  collaboratorPubkeys: const ['collab-pubkey'],
                ),
              ],
            );

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repositoryWithApi.getCollabVideos(
              taggedPubkey: 'collab-pubkey',
            );

            expect(result, hasLength(1));
            expect(result.first.collaboratorPubkeys, equals(['collab-pubkey']));
            expect(result.first.hasCollaborators, isTrue);
          },
        );

        test('passes parameters to Funnelcake API', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getCollabVideos(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'collab-event-1',
                pubkey: 'author-pubkey',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/collab.mp4',
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getCollabVideos(
            taggedPubkey: 'collab-pubkey',
            limit: 10,
            until: 1704067200,
          );

          verify(
            () => mockFunnelcakeClient.getCollabVideos(
              pubkey: 'collab-pubkey',
              limit: 10,
              before: 1704067200,
            ),
          ).called(1);
        });

        test(
          'does not fall back to raw relay p-tags when Funnelcake throws',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getCollabVideos(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenThrow(const FunnelcakeException('Server error'));

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            await expectLater(
              repositoryWithApi.getCollabVideos(taggedPubkey: 'collab-pubkey'),
              throwsA(isA<FunnelcakeException>()),
            );

            verifyNever(() => mockNostrClient.queryEvents(any()));
          },
        );

        test(
          'trusts empty Funnelcake collab results without relay fallback',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getCollabVideos(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer((_) async => <VideoStats>[]);

            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repositoryWithApi.getCollabVideos(
              taggedPubkey: 'collab-pubkey',
            );

            expect(result, isEmpty);
            verifyNever(() => mockNostrClient.queryEvents(any()));
          },
        );

        test('returns empty list when Funnelcake is not available', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getCollabVideos(
            taggedPubkey: 'collab-pubkey',
          );

          verifyNever(
            () => mockFunnelcakeClient.getCollabVideos(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test('treats missing confirmed collabs as empty', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getCollabVideos(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenThrow(FunnelcakeNotFoundException(resource: 'Collab videos'));

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getCollabVideos(
            taggedPubkey: 'collab-pubkey',
          );

          expect(result, isEmpty);
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test('filters blocked pubkeys from API results', () async {
          final blockFilter = TestContentFilter(
            blockedPubkeys: {'blocked-author'},
          );

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getCollabVideos(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'allowed-video',
                pubkey: 'good-author',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/good.mp4',
              ),
              _createVideoStats(
                id: 'blocked-video',
                pubkey: 'blocked-author',
                dTag: 'dtag-2',
                videoUrl: 'https://example.com/blocked.mp4',
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            blockFilter: blockFilter.call,
          );

          final result = await repositoryWithApi.getCollabVideos(
            taggedPubkey: 'collab-pubkey',
          );

          expect(result, hasLength(1));
          expect(result.first.id, equals('allowed-video'));
        });
      });
    });

    group('searchVideosLocally', () {
      test('returns empty list when query is empty', () async {
        final result = await repository.searchVideosLocally(query: '');
        expect(result, isEmpty);
      });

      test('returns empty list when query is whitespace only', () async {
        final result = await repository.searchVideosLocally(query: '   ');
        expect(result, isEmpty);
      });

      test('returns empty list when no local storage', () async {
        final result = await repository.searchVideosLocally(query: 'flutter');
        expect(result, isEmpty);
      });

      test('returns matching videos from local cache', () async {
        final mockLocalStorage = MockVideoLocalStorage();
        final matchingEvent = _createVideoEvent(
          id: 'local-1',
          pubkey: 'pubkey-1',
          videoUrl: 'https://example.com/local.mp4',
          createdAt: 1704067200,
          hashtags: ['flutter'],
        );

        when(
          () => mockLocalStorage.searchEvents(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [matchingEvent]);

        when(
          () => mockLocalStorage.getEventsByHashtags(
            hashtags: any(named: 'hashtags'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [matchingEvent]);

        final repoWithStorage = VideosRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repoWithStorage.searchVideosLocally(
          query: 'flutter',
        );

        expect(result, hasLength(1));
        expect(result.first.id, equals('local-1'));
      });

      test('applies block filter to local results', () async {
        final mockLocalStorage = MockVideoLocalStorage();
        final blockFilter = TestContentFilter(
          blockedPubkeys: {'blocked-pubkey'},
        );

        final okEvent = _createVideoEvent(
          id: 'ok-video',
          pubkey: 'good-pubkey',
          videoUrl: 'https://example.com/ok.mp4',
          createdAt: 1704067200,
          hashtags: ['video'],
        );
        final blockedEvent = _createVideoEvent(
          id: 'blocked-video',
          pubkey: 'blocked-pubkey',
          videoUrl: 'https://example.com/blocked.mp4',
          createdAt: 1704067100,
          hashtags: ['video'],
        );

        when(
          () => mockLocalStorage.searchEvents(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [okEvent, blockedEvent]);

        when(
          () => mockLocalStorage.getEventsByHashtags(
            hashtags: any(named: 'hashtags'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [okEvent, blockedEvent]);

        final repoWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          blockFilter: blockFilter.call,
        );

        final result = await repoWithFilter.searchVideosLocally(query: 'video');

        expect(result, hasLength(1));
        expect(result.first.id, equals('ok-video'));
      });

      test('combines content and hashtag matches without duplicates', () async {
        final mockLocalStorage = MockVideoLocalStorage();

        final contentMatch = _createVideoEvent(
          id: 'content-match',
          pubkey: 'pubkey-1',
          videoUrl: 'https://example.com/content.mp4',
          createdAt: 1704067200,
          content: 'flutter tutorial',
        );
        final hashtagMatch = _createVideoEvent(
          id: 'hashtag-match',
          pubkey: 'pubkey-2',
          videoUrl: 'https://example.com/hashtag.mp4',
          createdAt: 1704067100,
          hashtags: ['flutter'],
        );
        final sharedMatch = _createVideoEvent(
          id: 'shared-match',
          pubkey: 'pubkey-3',
          videoUrl: 'https://example.com/shared.mp4',
          createdAt: 1704067000,
          content: 'flutter tips',
          hashtags: ['flutter'],
        );

        when(
          () => mockLocalStorage.searchEvents(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [contentMatch, sharedMatch]);

        when(
          () => mockLocalStorage.getEventsByHashtags(
            hashtags: any(named: 'hashtags'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [hashtagMatch, sharedMatch]);

        final repoWithStorage = VideosRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repoWithStorage.searchVideosLocally(
          query: 'flutter',
        );

        // Should have 3 unique videos, not 4 (sharedMatch deduplicated)
        expect(result, hasLength(3));
        final ids = result.map((v) => v.id).toSet();
        expect(ids, contains('content-match'));
        expect(ids, contains('hashtag-match'));
        expect(ids, contains('shared-match'));
      });

      test(
        'countVideosLocally returns deduplicated local match count',
        () async {
          final mockLocalStorage = MockVideoLocalStorage();
          final matchingEvent = _createVideoEvent(
            id: 'shared-match',
            pubkey: 'pubkey-1',
            videoUrl: 'https://example.com/shared.mp4',
            createdAt: 1704067200,
            content: 'flutter tutorial',
            hashtags: ['flutter'],
          );

          when(
            () => mockLocalStorage.searchEvents(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => [matchingEvent]);

          when(
            () => mockLocalStorage.getEventsByHashtags(
              hashtags: any(named: 'hashtags'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => [matchingEvent]);

          final repoWithStorage = VideosRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          final count = await repoWithStorage.countVideosLocally(
            query: 'flutter',
          );

          expect(count, equals(1));
        },
      );
    });

    group('searchVideosOnRelays', () {
      test('returns empty list when query is empty', () async {
        final result = await repository.searchVideosOnRelays(query: '');
        expect(result, isEmpty);
      });

      test('returns empty list when query is whitespace only', () async {
        final result = await repository.searchVideosOnRelays(query: '   ');
        expect(result, isEmpty);
      });

      test('returns NIP-50 results', () async {
        final event = _createVideoEvent(
          id: 'nip50-1',
          pubkey: 'pubkey-1',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(
          () => mockNostrClient.searchVideos(any(), limit: any(named: 'limit')),
        ).thenAnswer((_) => Stream.value(event));

        final result = await repository.searchVideosOnRelays(query: 'flutter');

        expect(result, hasLength(1));
        expect(result.first.id, equals('nip50-1'));
        verify(
          () => mockNostrClient.searchVideos('flutter', limit: 100),
        ).called(1);
      });

      test('passes custom limit to NIP-50 search', () async {
        when(
          () => mockNostrClient.searchVideos(any(), limit: any(named: 'limit')),
        ).thenAnswer((_) => const Stream.empty());

        await repository.searchVideosOnRelays(query: 'flutter', limit: 50);

        verify(
          () => mockNostrClient.searchVideos('flutter', limit: 50),
        ).called(1);
      });

      test('handles NIP-50 failure gracefully', () async {
        when(
          () => mockNostrClient.searchVideos(any(), limit: any(named: 'limit')),
        ).thenAnswer((_) => Stream.error(Exception('relay error')));

        final result = await repository.searchVideosOnRelays(query: 'flutter');

        expect(result, isEmpty);
      });

      test('applies block filter to relay results', () async {
        final blockFilter = TestContentFilter(
          blockedPubkeys: {'blocked-pubkey'},
        );

        when(
          () => mockNostrClient.searchVideos(any(), limit: any(named: 'limit')),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            _createVideoEvent(
              id: 'ok-video',
              pubkey: 'good-pubkey',
              videoUrl: 'https://example.com/ok.mp4',
              createdAt: 1704067200,
            ),
            _createVideoEvent(
              id: 'blocked-video',
              pubkey: 'blocked-pubkey',
              videoUrl: 'https://example.com/blocked.mp4',
              createdAt: 1704067100,
            ),
          ]),
        );

        final repoWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: blockFilter.call,
        );

        final result = await repoWithFilter.searchVideosOnRelays(
          query: 'video',
        );

        expect(result, hasLength(1));
        expect(result.first.id, equals('ok-video'));
      });

      test('returns partial results when stream times out', () {
        return fakeAsync((async) {
          final controller = StreamController<Event>();

          when(
            () =>
                mockNostrClient.searchVideos(any(), limit: any(named: 'limit')),
          ).thenAnswer((_) => controller.stream);

          final future = repository.searchVideosOnRelays(query: 'flutter');

          // Advance past the 15-second timeout
          async.elapse(const Duration(seconds: 16));

          return future.then((result) async {
            expect(result, isEmpty);
            await controller.close();
          });
        });
      });

      test('collects stream events within timeout', () async {
        when(
          () => mockNostrClient.searchVideos(any(), limit: any(named: 'limit')),
        ).thenAnswer(
          (_) => Stream.value(
            _createVideoEvent(
              id: 'slow-result',
              pubkey: 'pubkey-1',
              videoUrl: 'https://example.com/video.mp4',
              createdAt: 1704067200,
            ),
          ),
        );

        final result = await repository.searchVideosOnRelays(query: 'flutter');

        expect(result, hasLength(1));
        expect(result.first.id, equals('slow-result'));
      });
    });

    group('searchVideosViaApi', () {
      test('returns empty page when query is empty', () async {
        final result = await repository.searchVideosViaApi(query: '');

        expect(result.videos, isEmpty);
        expect(result.hasMore, isFalse);
      });

      test('returns empty page when query is whitespace only', () async {
        final result = await repository.searchVideosViaApi(query: '   ');

        expect(result.videos, isEmpty);
        expect(result.hasMore, isFalse);
      });

      test('returns empty page when funnelcakeApiClient is null', () async {
        final result = await repository.searchVideosViaApi(query: 'flutter');

        expect(result.videos, isEmpty);
        expect(result.hasMore, isFalse);
      });

      test(
        'returns empty list when funnelcakeApiClient is not available',
        () async {
          final mockFunnelcake = MockFunnelcakeApiClient();
          when(() => mockFunnelcake.isAvailable).thenReturn(false);

          final repoWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcake,
          );

          final result = await repoWithApi.searchVideosViaApi(query: 'flutter');

          expect(result.videos, isEmpty);
          expect(result.hasMore, isFalse);
        },
      );

      test('returns transformed results on success', () async {
        final mockFunnelcake = MockFunnelcakeApiClient();
        when(() => mockFunnelcake.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcake.searchVideos(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sort: any(named: 'sort'),
          ),
        ).thenAnswer(
          (_) async => VideoSearchResponse(
            videos: [
              _createVideoStats(
                id: 'api-1',
                pubkey: 'pubkey-1',
                dTag: 'api-1',
                videoUrl: 'https://example.com/api.mp4',
              ),
            ],
            totalCount: 1,
            hasMore: true,
          ),
        );

        final repoWithApi = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcake,
        );

        final result = await repoWithApi.searchVideosViaApi(query: 'flutter');

        expect(result.videos, hasLength(1));
        expect(result.hasMore, isTrue);
        verify(() => mockFunnelcake.searchVideos(query: 'flutter')).called(1);
      });

      test('returns empty list on FunnelcakeException', () async {
        final mockFunnelcake = MockFunnelcakeApiClient();
        when(() => mockFunnelcake.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcake.searchVideos(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sort: any(named: 'sort'),
          ),
        ).thenThrow(const FunnelcakeException('search failed'));

        final repoWithApi = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcake,
        );

        final result = await repoWithApi.searchVideosViaApi(query: 'flutter');
        expect(result.videos, isEmpty);
      });

      test('applies block filter to API results', () async {
        final mockFunnelcake = MockFunnelcakeApiClient();
        final blockFilter = TestContentFilter(
          blockedPubkeys: {'blocked-pubkey'},
        );
        when(() => mockFunnelcake.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcake.searchVideos(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sort: any(named: 'sort'),
          ),
        ).thenAnswer(
          (_) async => VideoSearchResponse(
            videos: [
              _createVideoStats(
                id: 'ok-video',
                pubkey: 'good-pubkey',
                dTag: 'ok-video',
                videoUrl: 'https://example.com/ok.mp4',
              ),
              _createVideoStats(
                id: 'blocked-video',
                pubkey: 'blocked-pubkey',
                dTag: 'blocked-video',
                videoUrl: 'https://example.com/blocked.mp4',
              ),
            ],
            totalCount: 2,
          ),
        );

        final repoWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcake,
          blockFilter: blockFilter.call,
        );

        final result = await repoWithFilter.searchVideosViaApi(query: 'video');

        expect(result.videos, hasLength(1));
      });

      test('passes custom limit to API', () async {
        final mockFunnelcake = MockFunnelcakeApiClient();
        when(() => mockFunnelcake.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcake.searchVideos(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sort: any(named: 'sort'),
          ),
        ).thenAnswer(
          (_) async => const VideoSearchResponse(videos: [], totalCount: 0),
        );

        final repoWithApi = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcake,
        );

        await repoWithApi.searchVideosViaApi(query: 'flutter', limit: 25);

        verify(
          () => mockFunnelcake.searchVideos(query: 'flutter', limit: 25),
        ).called(1);
      });

      test('passes custom sort to API', () async {
        final mockFunnelcake = MockFunnelcakeApiClient();
        when(() => mockFunnelcake.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcake.searchVideos(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sort: any(named: 'sort'),
          ),
        ).thenAnswer(
          (_) async => const VideoSearchResponse(videos: [], totalCount: 0),
        );

        final repoWithApi = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcake,
        );

        await repoWithApi.searchVideosViaApi(
          query: 'flutter',
          sort: VideoSearchSort.recent,
        );

        verify(
          () => mockFunnelcake.searchVideos(query: 'flutter', sort: 'recent'),
        ).called(1);
      });
    });

    group('deduplicateAndSortVideos', () {
      test('removes duplicate videos by ID', () async {
        final video1 = VideoEvent.fromNostrEvent(
          _createVideoEvent(
            id: 'shared-id',
            pubkey: 'pubkey-1',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1704067200,
          ),
        );
        final video2 = VideoEvent.fromNostrEvent(
          _createVideoEvent(
            id: 'shared-id',
            pubkey: 'pubkey-1',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1704067200,
          ),
        );

        final result = repository.deduplicateAndSortVideos([video1, video2]);

        expect(result, hasLength(1));
        expect(result.first.id, equals('shared-id'));
      });

      test(
        'removes republished addressable duplicates by coordinate',
        () async {
          final author = 'a' * 64;
          final video1 = VideoEvent.fromNostrEvent(
            _createVideoEventWithDTag(
              id: 'first-event-id',
              pubkey: author,
              dTag: 'same-d-tag',
              videoUrl: 'https://example.com/first.mp4',
              createdAt: 1704067200,
            ),
          );
          final video2 = VideoEvent.fromNostrEvent(
            _createVideoEventWithDTag(
              id: 'second-event-id',
              pubkey: author,
              dTag: 'same-d-tag',
              videoUrl: 'https://example.com/second.mp4',
              createdAt: 1704067300,
            ),
          );

          final result = repository.deduplicateAndSortVideos([video1, video2]);

          expect(result, hasLength(1));
        },
      );

      test(
        'does not collapse same d-tag videos from different authors',
        () async {
          final video1 = VideoEvent.fromNostrEvent(
            _createVideoEventWithDTag(
              id: 'author-a-event',
              pubkey: 'a' * 64,
              dTag: 'same-d-tag',
              videoUrl: 'https://example.com/a.mp4',
              createdAt: 1704067200,
            ),
          );
          final video2 = VideoEvent.fromNostrEvent(
            _createVideoEventWithDTag(
              id: 'author-b-event',
              pubkey: 'b' * 64,
              dTag: 'same-d-tag',
              videoUrl: 'https://example.com/b.mp4',
              createdAt: 1704067300,
            ),
          );

          final result = repository.deduplicateAndSortVideos([video1, video2]);

          expect(result, hasLength(2));
        },
      );

      test('sorts by loops then time', () async {
        final videoHighLoops = VideoEvent.fromNostrEvent(
          _createVideoEvent(
            id: 'high-loops',
            pubkey: 'pubkey-1',
            videoUrl: 'https://example.com/popular.mp4',
            createdAt: 1704067100,
            loops: 100,
          ),
        );
        final videoLowLoops = VideoEvent.fromNostrEvent(
          _createVideoEvent(
            id: 'low-loops',
            pubkey: 'pubkey-2',
            videoUrl: 'https://example.com/new.mp4',
            createdAt: 1704067200,
            loops: 5,
          ),
        );

        final result = repository.deduplicateAndSortVideos([
          videoLowLoops,
          videoHighLoops,
        ]);

        expect(result.first.id, equals('high-loops'));
      });

      test('returns empty list for empty input', () {
        final result = repository.deduplicateAndSortVideos([]);
        expect(result, isEmpty);
      });
    });

    group('getHashtagFeedVideos', () {
      test('returns empty list when hashtag is blank', () async {
        final result = await repository.getHashtagFeedVideos(hashtag: '  ');

        expect(result.succeeded, isFalse);
        expect(result.videos, isEmpty);
      });

      test('returns empty list when funnelcakeApiClient is null', () async {
        final result = await repository.getHashtagFeedVideos(hashtag: 'bts');

        expect(result.succeeded, isFalse);
        expect(result.videos, isEmpty);
      });

      test('returns empty list when the API is unavailable', () async {
        final mockFunnelcake = MockFunnelcakeApiClient();
        when(() => mockFunnelcake.isAvailable).thenReturn(false);

        final repoWithApi = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcake,
        );

        final result = await repoWithApi.getHashtagFeedVideos(hashtag: 'bts');

        expect(result.succeeded, isFalse);
        expect(result.videos, isEmpty);
      });

      test(
        'interleaves trending and classic 1:1, deduplicating classics',
        () async {
          final mockFunnelcake = MockFunnelcakeApiClient();
          when(() => mockFunnelcake.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcake.getVideosByHashtag(
              hashtag: 'bts',
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'trend-1',
                pubkey: 'pubkey-1',
                dTag: 'dtag-t1',
                videoUrl: 'https://example.com/t1.mp4',
              ),
              _createVideoStats(
                id: 'trend-2',
                pubkey: 'pubkey-2',
                dTag: 'dtag-t2',
                videoUrl: 'https://example.com/t2.mp4',
              ),
            ],
          );
          when(
            () => mockFunnelcake.getClassicVideosByHashtag(
              hashtag: 'bts',
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              // Duplicate of trend-1 — must be dropped.
              _createVideoStats(
                id: 'trend-1',
                pubkey: 'pubkey-1',
                dTag: 'dtag-t1',
                videoUrl: 'https://example.com/t1.mp4',
              ),
              _createVideoStats(
                id: 'classic-1',
                pubkey: 'pubkey-3',
                dTag: 'dtag-c1',
                videoUrl: 'https://example.com/c1.mp4',
              ),
            ],
          );

          final repoWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcake,
          );

          final result = await repoWithApi.getHashtagFeedVideos(hashtag: 'bts');

          expect(result.succeeded, isTrue);
          expect(result.videos.map((v) => v.id), [
            'trend-1',
            'classic-1',
            'trend-2',
          ]);
          expect(
            verify(
                  () => mockFunnelcake.getVideosByHashtag(
                    hashtag: 'bts',
                    limit: captureAny(named: 'limit'),
                  ),
                ).captured.single
                as int,
            50,
          );
          expect(
            verify(
                  () => mockFunnelcake.getClassicVideosByHashtag(
                    hashtag: 'bts',
                    limit: captureAny(named: 'limit'),
                  ),
                ).captured.single
                as int,
            50,
          );
        },
      );

      test('appends remaining classics when they outnumber trending', () async {
        final mockFunnelcake = MockFunnelcakeApiClient();
        when(() => mockFunnelcake.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcake.getVideosByHashtag(
            hashtag: 'bts',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'trend-1',
              pubkey: 'pubkey-1',
              dTag: 'dtag-t1',
              videoUrl: 'https://example.com/t1.mp4',
            ),
          ],
        );
        when(
          () => mockFunnelcake.getClassicVideosByHashtag(
            hashtag: 'bts',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'classic-1',
              pubkey: 'pubkey-2',
              dTag: 'dtag-c1',
              videoUrl: 'https://example.com/c1.mp4',
            ),
            _createVideoStats(
              id: 'classic-2',
              pubkey: 'pubkey-3',
              dTag: 'dtag-c2',
              videoUrl: 'https://example.com/c2.mp4',
            ),
          ],
        );

        final repoWithApi = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcake,
        );

        final result = await repoWithApi.getHashtagFeedVideos(hashtag: 'bts');

        expect(result.succeeded, isTrue);
        expect(result.videos.map((v) => v.id), [
          'trend-1',
          'classic-1',
          'classic-2',
        ]);
      });

      test(
        'applies block filter to both trending and classic results',
        () async {
          final mockFunnelcake = MockFunnelcakeApiClient();
          when(() => mockFunnelcake.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcake.getVideosByHashtag(
              hashtag: 'bts',
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'trend-blocked',
                pubkey: 'blocked-pubkey',
                dTag: 'dtag-tb',
                videoUrl: 'https://example.com/tb.mp4',
              ),
              _createVideoStats(
                id: 'trend-ok',
                pubkey: 'allowed-pubkey',
                dTag: 'dtag-to',
                videoUrl: 'https://example.com/to.mp4',
              ),
            ],
          );
          when(
            () => mockFunnelcake.getClassicVideosByHashtag(
              hashtag: 'bts',
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'classic-blocked',
                pubkey: 'blocked-pubkey',
                dTag: 'dtag-cb',
                videoUrl: 'https://example.com/cb.mp4',
              ),
            ],
          );

          final blockFilter = TestContentFilter(
            blockedPubkeys: {'blocked-pubkey'},
          );
          final repoWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcake,
            blockFilter: blockFilter.call,
          );

          final result = await repoWithApi.getHashtagFeedVideos(hashtag: 'bts');

          expect(result.succeeded, isTrue);
          expect(result.videos.map((v) => v.id), ['trend-ok']);
        },
      );

      test('returns empty list when the API throws', () async {
        final mockFunnelcake = MockFunnelcakeApiClient();
        when(() => mockFunnelcake.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcake.getVideosByHashtag(
            hashtag: 'bts',
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const FunnelcakeException('boom'));
        when(
          () => mockFunnelcake.getClassicVideosByHashtag(
            hashtag: 'bts',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => []);

        final repoWithApi = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcake,
        );

        final result = await repoWithApi.getHashtagFeedVideos(hashtag: 'bts');

        expect(result.succeeded, isFalse);
        expect(result.videos, isEmpty);
      });
    });

    group('searchVideos', () {
      test('emits nothing for empty query', () async {
        final stream = repository.searchVideos(query: '');
        await expectLater(stream, emitsDone);
      });

      test('emits nothing for whitespace-only query', () async {
        final stream = repository.searchVideos(query: '   ');
        await expectLater(stream, emitsDone);
      });

      test('yields local results first', () async {
        final mockLocalStorage = MockVideoLocalStorage();
        final localEvent = _createVideoEvent(
          id: 'local-1',
          pubkey: 'pubkey-1',
          videoUrl: 'https://example.com/local.mp4',
          createdAt: 1704067200,
          hashtags: ['flutter'],
        );

        when(
          () => mockLocalStorage.searchEvents(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [localEvent]);

        when(
          () => mockLocalStorage.getEventsByHashtags(
            hashtags: any(named: 'hashtags'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [localEvent]);

        when(
          () => mockNostrClient.searchVideos(any(), limit: any(named: 'limit')),
        ).thenAnswer((_) => const Stream.empty());

        final repoWithStorage = VideosRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final results = await repoWithStorage
            .searchVideos(query: 'flutter')
            .toList();

        // First emission should be the local result
        expect(results.first, hasLength(1));
        expect(results.first.first.id, equals('local-1'));
      });

      test('yields combined results as remote sources complete', () async {
        final mockLocalStorage = MockVideoLocalStorage();
        final mockFunnelcake = MockFunnelcakeApiClient();
        final localEvent = _createVideoEvent(
          id: 'local-1',
          pubkey: 'pubkey-1',
          videoUrl: 'https://example.com/local.mp4',
          createdAt: 1704067200,
          hashtags: ['flutter'],
        );

        when(
          () => mockLocalStorage.searchEvents(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [localEvent]);

        when(
          () => mockLocalStorage.getEventsByHashtags(
            hashtags: any(named: 'hashtags'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [localEvent]);

        when(() => mockFunnelcake.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcake.searchVideos(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sort: any(named: 'sort'),
          ),
        ).thenAnswer(
          (_) async => VideoSearchResponse(
            videos: [
              _createVideoStats(
                id: 'api-1',
                pubkey: 'pubkey-2',
                dTag: 'api-1',
                videoUrl: 'https://example.com/api.mp4',
              ),
            ],
            totalCount: 1,
          ),
        );

        when(
          () => mockNostrClient.searchVideos(any(), limit: any(named: 'limit')),
        ).thenAnswer(
          (_) => Stream.value(
            _createVideoEvent(
              id: 'relay-1',
              pubkey: 'pubkey-3',
              videoUrl: 'https://example.com/relay.mp4',
              createdAt: 1704067100,
            ),
          ),
        );

        final repoWithAll = VideosRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          funnelcakeApiClient: mockFunnelcake,
        );

        final results = await repoWithAll
            .searchVideos(query: 'flutter')
            .toList();

        // Should have 3 emissions: local, local+API, local+API+relay
        expect(results, hasLength(3));
        expect(results[0], hasLength(1));
        expect(results[1].first.id, equals('api-1'));
        expect(results.last, hasLength(3));
      });

      test('passes custom sort through progressive API search', () async {
        final mockFunnelcake = MockFunnelcakeApiClient();
        when(() => mockFunnelcake.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcake.searchVideos(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sort: any(named: 'sort'),
          ),
        ).thenAnswer(
          (_) async => const VideoSearchResponse(videos: [], totalCount: 0),
        );
        when(
          () => mockNostrClient.searchVideos(any(), limit: any(named: 'limit')),
        ).thenAnswer((_) => const Stream.empty());

        final repoWithApi = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcake,
        );

        await repoWithApi
            .searchVideos(query: 'flutter', sort: VideoSearchSort.recent)
            .drain<void>();

        verify(
          () => mockFunnelcake.searchVideos(query: 'flutter', sort: 'recent'),
        ).called(1);
      });

      test('skips empty remote results without extra emission', () async {
        final mockLocalStorage = MockVideoLocalStorage();
        final localEvent = _createVideoEvent(
          id: 'local-1',
          pubkey: 'pubkey-1',
          videoUrl: 'https://example.com/local.mp4',
          createdAt: 1704067200,
          hashtags: ['flutter'],
        );

        when(
          () => mockLocalStorage.searchEvents(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [localEvent]);

        when(
          () => mockLocalStorage.getEventsByHashtags(
            hashtags: any(named: 'hashtags'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [localEvent]);

        // Both remote sources return empty
        when(
          () => mockNostrClient.searchVideos(any(), limit: any(named: 'limit')),
        ).thenAnswer((_) => const Stream.empty());

        final repoWithStorage = VideosRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final results = await repoWithStorage
            .searchVideos(query: 'flutter')
            .toList();

        // Only 1 emission (local) since both remotes are empty
        expect(results, hasLength(1));
        expect(results.first, hasLength(1));
      });

      test('deduplicates across sources', () async {
        final mockLocalStorage = MockVideoLocalStorage();

        final sharedEvent = _createVideoEvent(
          id: 'shared-id',
          pubkey: 'pubkey-1',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
          hashtags: ['flutter'],
        );

        when(
          () => mockLocalStorage.searchEvents(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [sharedEvent]);

        when(
          () => mockLocalStorage.getEventsByHashtags(
            hashtags: any(named: 'hashtags'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [sharedEvent]);

        // Relay returns the same video
        when(
          () => mockNostrClient.searchVideos(any(), limit: any(named: 'limit')),
        ).thenAnswer((_) => Stream.value(sharedEvent));

        final repoWithStorage = VideosRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final results = await repoWithStorage
            .searchVideos(query: 'flutter')
            .toList();

        // Last emission should have 1 video (deduplicated)
        expect(results.last, hasLength(1));
      });

      test('handles remote source failure gracefully', () async {
        final mockLocalStorage = MockVideoLocalStorage();
        final localEvent = _createVideoEvent(
          id: 'local-1',
          pubkey: 'pubkey-1',
          videoUrl: 'https://example.com/local.mp4',
          createdAt: 1704067200,
          hashtags: ['flutter'],
        );

        when(
          () => mockLocalStorage.searchEvents(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [localEvent]);

        when(
          () => mockLocalStorage.getEventsByHashtags(
            hashtags: any(named: 'hashtags'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [localEvent]);

        // Relay throws — caught by searchVideosOnRelays internally
        when(
          () => mockNostrClient.searchVideos(any(), limit: any(named: 'limit')),
        ).thenAnswer((_) => Stream.error(Exception('relay error')));

        final repoWithStorage = VideosRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        // The stream should yield local results; relay error is caught
        // internally by searchVideosOnRelays
        final results = <List<VideoEvent>>[];
        await repoWithStorage
            .searchVideos(query: 'flutter')
            .forEach(results.add);

        // searchVideosOnRelays catches exceptions internally and
        // returns [], so the stream completes normally with local only
        expect(results.first, hasLength(1));
      });

      test('catches API phase exception when searchVideosViaApi throws '
          'non-FunnelcakeException', () async {
        final mockLocalStorage = MockVideoLocalStorage();
        final mockFunnelcake = MockFunnelcakeApiClient();

        when(
          () => mockLocalStorage.searchEvents(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => []);

        when(
          () => mockLocalStorage.getEventsByHashtags(
            hashtags: any(named: 'hashtags'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => []);

        // Funnelcake throws a non-FunnelcakeException which escapes
        // searchVideosViaApi's internal catch
        when(() => mockFunnelcake.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcake.searchVideos(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sort: any(named: 'sort'),
          ),
        ).thenThrow(Exception('unexpected API error'));

        when(
          () => mockNostrClient.searchVideos(any(), limit: any(named: 'limit')),
        ).thenAnswer((_) => const Stream.empty());

        final repoWithApi = VideosRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          funnelcakeApiClient: mockFunnelcake,
        );

        final results = await repoWithApi
            .searchVideos(query: 'flutter')
            .toList();

        // Should still complete with local results (empty in this case)
        expect(results, isNotEmpty);
      });
    });
    group('getVideosByLoops', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns videos from Funnelcake API', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByLoops(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'event-1',
              pubkey: 'pubkey-1',
              dTag: 'dtag-1',
              videoUrl: 'https://example.com/video.mp4',
              loops: 100,
            ),
          ],
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideosByLoops();

        expect(result, hasLength(1));
        verify(
          () => mockFunnelcakeClient.getVideosByLoops(limit: 20),
        ).called(1);
      });

      test('returns empty list when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideosByLoops();

        expect(result, isEmpty);
        verifyNever(
          () => mockFunnelcakeClient.getVideosByLoops(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        );
      });

      test('returns empty list when API client is null', () async {
        final result = await repository.getVideosByLoops();

        expect(result, isEmpty);
      });

      test('propagates $FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByLoops(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(message: 'error', statusCode: 500),
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(repo.getVideosByLoops, throwsA(isA<FunnelcakeApiException>()));
      });

      test('applies block filter to results', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByLoops(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'event-1',
              pubkey: 'blocked-pubkey',
              dTag: 'dtag-1',
              videoUrl: 'https://example.com/video.mp4',
            ),
            _createVideoStats(
              id: 'event-2',
              pubkey: 'allowed-pubkey',
              dTag: 'dtag-2',
              videoUrl: 'https://example.com/video2.mp4',
            ),
          ],
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
          blockFilter: (pubkey) => pubkey == 'blocked-pubkey',
        );

        final result = await repo.getVideosByLoops();

        expect(result, hasLength(1));
        expect(result.first.pubkey, equals('allowed-pubkey'));
      });

      test('passes parameters correctly', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByLoops(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async => []);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        await repo.getVideosByLoops(limit: 30, before: 1704067200);

        verify(
          () => mockFunnelcakeClient.getVideosByLoops(
            limit: 30,
            before: 1704067200,
          ),
        ).called(1);
      });
    });

    group('getVideosByHashtag', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns videos from Funnelcake API', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByHashtag(
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'event-1',
              pubkey: 'pubkey-1',
              dTag: 'dtag-1',
              videoUrl: 'https://example.com/video.mp4',
            ),
          ],
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideosByHashtag(hashtag: 'bitcoin');

        expect(result, hasLength(1));
      });

      test('returns empty list when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideosByHashtag(hashtag: 'bitcoin');

        expect(result, isEmpty);
      });

      test('returns empty list when API client is null', () async {
        final result = await repository.getVideosByHashtag(hashtag: 'bitcoin');

        expect(result, isEmpty);
      });

      test('propagates $FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByHashtag(
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(message: 'error', statusCode: 500),
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repo.getVideosByHashtag(hashtag: 'bitcoin'),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('passes parameters correctly', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByHashtag(
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async => []);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        await repo.getVideosByHashtag(
          hashtag: 'nostr',
          limit: 30,
          before: 1704067200,
        );

        verify(
          () => mockFunnelcakeClient.getVideosByHashtag(
            hashtag: 'nostr',
            limit: 30,
            before: 1704067200,
          ),
        ).called(1);
      });
    });

    group('getClassicVideosByHashtag', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns videos from Funnelcake API', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getClassicVideosByHashtag(
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'event-1',
              pubkey: 'pubkey-1',
              dTag: 'dtag-1',
              videoUrl: 'https://example.com/video.mp4',
            ),
          ],
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getClassicVideosByHashtag(hashtag: 'bitcoin');

        expect(result, hasLength(1));
      });

      test('returns empty list when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getClassicVideosByHashtag(hashtag: 'bitcoin');

        expect(result, isEmpty);
      });

      test('returns empty list when API client is null', () async {
        final result = await repository.getClassicVideosByHashtag(
          hashtag: 'bitcoin',
        );

        expect(result, isEmpty);
      });

      test('propagates $FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getClassicVideosByHashtag(
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(message: 'error', statusCode: 500),
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repo.getClassicVideosByHashtag(hashtag: 'bitcoin'),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });
    });

    group('getClassicVines', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns videos from Funnelcake API', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getClassicVines(
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'event-1',
              pubkey: 'pubkey-1',
              dTag: 'dtag-1',
              videoUrl: 'https://example.com/video.mp4',
            ),
          ],
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getClassicVines();

        expect(result, hasLength(1));
      });

      test('returns empty list when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getClassicVines();

        expect(result, isEmpty);
      });

      test('returns empty list when API client is null', () async {
        final result = await repository.getClassicVines();

        expect(result, isEmpty);
      });

      test('propagates FunnelcakeException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getClassicVines(
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).thenThrow(const FunnelcakeException('error'));

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(repo.getClassicVines, throwsA(isA<FunnelcakeException>()));
      });

      test('passes parameters correctly', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getClassicVines(
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async => []);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        await repo.getClassicVines(
          sort: 'recent',
          limit: 30,
          offset: 10,
          before: 1704067200,
        );

        verify(
          () => mockFunnelcakeClient.getClassicVines(
            sort: 'recent',
            limit: 30,
            offset: 10,
            before: 1704067200,
          ),
        ).called(1);
      });
    });

    group('getVideosByAuthor', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns videos from Funnelcake API', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByAuthor(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => VideosByAuthorResponse(
            videos: [
              _createVideoStats(
                id: 'event-1',
                pubkey: 'author-pubkey',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/video.mp4',
              ),
            ],
          ),
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideosByAuthor(pubkey: 'author-pubkey');

        expect(result, hasLength(1));
      });

      test('returns empty list when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideosByAuthor(pubkey: 'author-pubkey');

        expect(result, isEmpty);
      });

      test('returns empty list when API client is null', () async {
        final result = await repository.getVideosByAuthor(
          pubkey: 'author-pubkey',
        );

        expect(result, isEmpty);
      });

      test('propagates FunnelcakeException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByAuthor(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenThrow(const FunnelcakeException('error'));

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repo.getVideosByAuthor(pubkey: 'author-pubkey'),
          throwsA(isA<FunnelcakeException>()),
        );
      });

      test('passes parameters correctly', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByAuthor(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => const VideosByAuthorResponse(videos: <VideoStats>[]),
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        await repo.getVideosByAuthor(
          pubkey: 'author-pubkey',
          limit: 30,
          before: 1704067200,
        );

        verify(
          () => mockFunnelcakeClient.getVideosByAuthor(
            pubkey: 'author-pubkey',
            limit: 30,
            before: 1704067200,
          ),
        ).called(1);
      });
    });

    group('getVideoStats', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns VideoStats on success', () async {
        final testStats = _createVideoStats(
          id: 'event-1',
          pubkey: 'pubkey-1',
          dTag: 'dtag-1',
          videoUrl: 'https://example.com/video.mp4',
          loops: 42,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideoStats('event-1'),
        ).thenAnswer((_) async => testStats);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideoStats('event-1');

        expect(result, isNotNull);
        expect(result!.loops, equals(42));
      });

      test('returns null when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideoStats('event-1');

        expect(result, isNull);
      });

      test('returns null when API client is null', () async {
        final result = await repository.getVideoStats('event-1');

        expect(result, isNull);
      });

      test('propagates FunnelcakeException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideoStats(any()),
        ).thenThrow(const FunnelcakeException('error'));

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repo.getVideoStats('event-1'),
          throwsA(isA<FunnelcakeException>()),
        );
      });
    });

    group('getVideoViews', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns view count on success', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideoViews('event-1'),
        ).thenAnswer((_) async => 1234);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideoViews('event-1');

        expect(result, equals(1234));
      });

      test('returns null when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideoViews('event-1');

        expect(result, isNull);
      });

      test('returns null when API client is null', () async {
        final result = await repository.getVideoViews('event-1');

        expect(result, isNull);
      });

      test('propagates FunnelcakeException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideoViews(any()),
        ).thenThrow(const FunnelcakeException('error'));

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repo.getVideoViews('event-1'),
          throwsA(isA<FunnelcakeException>()),
        );
      });
    });

    group('fetchVideoWithStats', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
      });

      test('returns null for empty event ID', () async {
        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );
        final result = await repo.fetchVideoWithStats('');
        expect(result, isNull);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('returns null when event is not found on relay', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );
        final result = await repo.fetchVideoWithStats('missing-id');
        expect(result, isNull);
      });

      test(
        'merges engagement metadata from bulk-stats into returned video',
        () async {
          const eventId = 'abc123';
          final nostrEvent = _createVideoEvent(
            id: eventId,
            pubkey: 'pubkey-1',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1739350000,
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [nostrEvent]);

          when(
            () => mockFunnelcakeClient.getBulkVideoStats([eventId]),
          ).thenAnswer(
            (_) async => const BulkVideoStatsResponse(
              stats: {
                eventId: BulkVideoStatsEntry(
                  eventId: eventId,
                  reactions: 7,
                  comments: 5,
                  reposts: 3,
                  embeddedLoops: 42,
                  views: 100,
                ),
              },
            ),
          );

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );
          final result = await repo.fetchVideoWithStats(eventId);

          expect(result, isNotNull);
          expect(result!.originalLoops, equals(42));
          expect(result.rawTags['views'], equals('100'));
          expect(result.originalLikes, isNull);
          expect(result.originalComments, isNull);
          expect(result.originalReposts, isNull);
          expect(result.nostrLikeCount, equals(7));
          expect(result.nostrCommentCount, equals(5));
          expect(result.nostrRepostCount, equals(3));
        },
      );

      test(
        'returns video without stats when Funnelcake is unavailable',
        () async {
          const eventId = 'def456';
          final nostrEvent = _createVideoEvent(
            id: eventId,
            pubkey: 'pubkey-1',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1739350000,
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [nostrEvent]);

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );
          final result = await repo.fetchVideoWithStats(eventId);

          expect(result, isNotNull);
          expect(result!.id, equals(eventId));
          expect(result.originalLoops, isNull);
        },
      );

      test('returns video without stats when stats hydration times out', () {
        const eventId = 'timeout-event-id';
        final nostrEvent = _createVideoEvent(
          id: eventId,
          pubkey: 'pubkey-1',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1739350000,
        );

        return fakeAsync((async) {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [nostrEvent]);

          // Funnelcake hangs indefinitely — never completes.
          when(
            () => mockFunnelcakeClient.getBulkVideoStats([eventId]),
          ).thenAnswer((_) => Completer<BulkVideoStatsResponse>().future);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          VideoEvent? result;
          unawaited(repo.fetchVideoWithStats(eventId).then((v) => result = v));

          // Advance past the 3-second stats-fetch timeout.
          async.elapse(const Duration(seconds: 4));

          expect(result, isNotNull);
          expect(result!.id, equals(eventId));
          // No stats hydrated — originalLoops should remain null.
          expect(result!.originalLoops, isNull);
        });
      });
    });

    group('fetchVideoWithStatsForRouteId', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
      });

      const unreachableRouteId =
          'a695f6b60119d9521934a691347d9f78e8770b56da16bb255ee77ac112b4c1f6';
      const absentRouteId =
          'b695f6b60119d9521934a691347d9f78e8770b56da16bb255ee77ac112b4c1f6';

      test(
        'rethrows when Funnelcake was unreachable and no relay answered',
        () async {
          // Returning null here renders "Video not found - it could be gone,
          // out of reach, or hidden by your settings" for a video that exists
          // and that the API serves fine. A failed lookup must stay
          // distinguishable from a confirmed absence.
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getVideoEvent(any()),
          ).thenThrow(const FunnelcakeTimeoutException('https://example.com'));
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => const <Event>[]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await expectLater(
            repo.fetchVideoWithStatsForRouteId(unreachableRouteId),
            throwsA(isA<FunnelcakeException>()),
          );
        },
      );

      test(
        'returns null when Funnelcake confirms absence and no relay answered',
        () async {
          // A 404 surfaces as null from getVideoEvent. That is a real answer,
          // so "not found" is the honest result.
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getVideoEvent(any()),
          ).thenAnswer((_) async => null);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => const <Event>[]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          expect(
            await repo.fetchVideoWithStatsForRouteId(absentRouteId),
            isNull,
          );
        },
      );

      test('resolves note1 route IDs via event ID lookup', () async {
        const eventId =
            'a695f6b60119d9521934a691347d9f78e8770b56da16bb255ee77ac112b4c1f6';
        final noteId = Nip19.encodeNoteId(eventId);
        final event = _createVideoEvent(
          id: eventId,
          pubkey: 'pubkey-1',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1739350000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.fetchVideoWithStatsForRouteId(noteId);

        expect(result, isNotNull);
        expect(result!.id, equals(eventId));
      });

      test('normalizes raw 64-char hex route IDs before lookup', () async {
        const lowerEventId =
            'e695f6b60119d9521934a691347d9f78e8770b56da16bb255ee77ac112b4c1f6';
        const upperEventId =
            'E695F6B60119D9521934A691347D9F78E8770B56DA16BB255EE77AC112B4C1F6';
        final event = _createVideoEvent(
          id: lowerEventId,
          pubkey: 'pubkey-1',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1739350000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.fetchVideoWithStatsForRouteId(upperEventId);

        expect(result, isNotNull);
        expect(result!.id, equals(lowerEventId));
      });

      test(
        'resolves event-id routes from local storage before relay',
        () async {
          const eventId =
              'e96357668c72c8923340b0ecf4bfacea'
              '505172c4190e9953e603124c67175f3b';
          final mockLocalStorage = MockVideoLocalStorage();
          final event = _createVideoEvent(
            id: eventId,
            pubkey: 'pubkey-1',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1739350000,
          );

          when(
            () => mockLocalStorage.getEventsByIds([eventId]),
          ).thenAnswer((_) async => [event]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            localStorage: mockLocalStorage,
          );

          final result = await repo.fetchVideoWithStatsForRouteId(eventId);

          expect(result, isNotNull);
          expect(result!.id, equals(eventId));
          verify(() => mockLocalStorage.getEventsByIds([eventId])).called(1);
          verifyNever(() => mockNostrClient.queryEvents(any()));
        },
      );

      test(
        'resolves acceptable legacy video kinds by raw 64-char route ID',
        () async {
          const eventId =
              'e96357668c72c8923340b0ecf4bfacea'
              '505172c4190e9953e603124c67175f3b';
          final legacyEvent = Event.fromJson({
            'id': eventId,
            'pubkey':
                '5bf0c63fcb93463407af97a5e5ee64fa'
                '883d107ef9e558472c4eb9aaaefa459d',
            'created_at': 1739350000,
            'kind': 22,
            'tags': [
              ['url', 'https://example.com/video.mp4'],
              ['title', 'Legacy Video'],
            ],
            'content': '',
            'sig': 'sig',
          });

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [legacyEvent]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.fetchVideoWithStatsForRouteId(eventId);

          expect(result, isNotNull);
          expect(result!.id, equals(eventId));
        },
      );

      test('falls back to stable-id lookup when a 64-char hex route is not an '
          'event id', () async {
        const hexStableId =
            'cdb77b012caba00133fc071b568e334b27'
            '9947f09d30df0ce819aedcd777b749';
        const eventId =
            'd695f6b60119d9521934a691347d9f78e8'
            '770b56da16bb255ee77ac112b4c1f6';
        const author =
            '5bf0c63fcb93463407af97a5e5ee64fa88'
            '3d107ef9e558472c4eb9aaaefa459d';
        final event = _createVideoEvent(
          id: eventId,
          pubkey: author,
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1739350000,
          extraTags: [
            ['d', hexStableId],
          ],
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments.single as List<Filter>;
          final filter = filters.single;
          if (filter.ids?.contains(hexStableId) ?? false) {
            return <Event>[];
          }
          if (filter.d?.contains(hexStableId) ?? false) {
            return [event];
          }
          return <Event>[];
        });

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.fetchVideoWithStatsForRouteId(hexStableId);

        expect(result, isNotNull);
        expect(result!.id, equals(eventId));
        expect(result.stableId, equals(hexStableId));
      });

      test(
        'falls back to stable-id lookup for acceptable legacy video kinds',
        () async {
          const hexStableId =
              'e96357668c72c8923340b0ecf4bfacea'
              '505172c4190e9953e603124c67175f3b';
          const eventId =
              'd695f6b60119d9521934a691347d9f78'
              'e8770b56da16bb255ee77ac112b4c1f6';
          final legacyEvent = Event.fromJson({
            'id': eventId,
            'pubkey':
                '5bf0c63fcb93463407af97a5e5ee64fa'
                '883d107ef9e558472c4eb9aaaefa459d',
            'created_at': 1739350000,
            'kind': 22,
            'tags': [
              ['url', 'https://example.com/video.mp4'],
              ['title', 'Legacy Stable Video'],
              ['d', hexStableId],
            ],
            'content': '',
            'sig': 'sig',
          });

          when(() => mockNostrClient.queryEvents(any())).thenAnswer((
            invocation,
          ) async {
            final filters =
                invocation.positionalArguments.single as List<Filter>;
            final filter = filters.single;
            if (filter.ids?.contains(hexStableId) ?? false) {
              return <Event>[];
            }
            if (filter.d?.contains(hexStableId) ?? false) {
              return [legacyEvent];
            }
            return <Event>[];
          });

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.fetchVideoWithStatsForRouteId(hexStableId);

          expect(result, isNotNull);
          expect(result!.id, equals(eventId));
          expect(result.stableId, equals(hexStableId));
        },
      );

      test(
        'resolves shared stable IDs via Funnelcake REST without hitting relay',
        () async {
          const stableId =
              'e96357668c72c8923340b0ecf4bfacea'
              '505172c4190e9953e603124c67175f3b';
          const eventId =
              'e46ff7d0d71d6c8114b58728afa43f08'
              'd6286fd9a704683af799fd8f855586c2';
          final apiHit = Event.fromJson({
            'id': eventId,
            'pubkey':
                '076c979382b90f5d3a2b21f95e1ee86b'
                '6033f14c92e79b7fad3fe1f1073f4886',
            'created_at': 1777868006,
            'kind': 34236,
            'tags': [
              ['d', stableId],
              ['url', 'https://media.divine.video/$stableId'],
              ['title', 'Divine team swag'],
            ],
            'content': 'Divine team swag!',
            'sig': 'sig',
          });

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getVideoEvent(stableId),
          ).thenAnswer((_) async => apiHit);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.fetchVideoWithStatsForRouteId(stableId);

          expect(result, isNotNull);
          expect(result!.id, equals(eventId));
          expect(result.stableId, equals(stableId));
          verify(() => mockFunnelcakeClient.getVideoEvent(stableId)).called(1);
          verifyNever(() => mockNostrClient.queryEvents(any()));
        },
      );

      test('falls back to relay when Funnelcake REST returns null '
          '(event only on personal relay)', () async {
        const stableId =
            'e96357668c72c8923340b0ecf4bfacea'
            '505172c4190e9953e603124c67175f3b';
        const eventId =
            'e46ff7d0d71d6c8114b58728afa43f08'
            'd6286fd9a704683af799fd8f855586c2';
        final relayHit = Event.fromJson({
          'id': eventId,
          'pubkey':
              '076c979382b90f5d3a2b21f95e1ee86b'
              '6033f14c92e79b7fad3fe1f1073f4886',
          'created_at': 1777868006,
          'kind': 34236,
          'tags': [
            ['d', stableId],
            ['url', 'https://media.divine.video/$stableId'],
            ['title', 'Personal relay only'],
          ],
          'content': 'Personal relay only',
          'sig': 'sig',
        });

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideoEvent(stableId),
        ).thenAnswer((_) async => null);
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments.single as List<Filter>;
          final filter = filters.single;
          if (filter.d?.contains(stableId) ?? false) {
            return [relayHit];
          }
          return <Event>[];
        });

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.fetchVideoWithStatsForRouteId(stableId);

        expect(result, isNotNull);
        expect(result!.id, equals(eventId));
        verify(() => mockFunnelcakeClient.getVideoEvent(stableId)).called(1);
        verify(() => mockNostrClient.queryEvents(any())).called(greaterThan(0));
      });

      test('falls back to relay when Funnelcake REST throws', () async {
        const stableId =
            'e96357668c72c8923340b0ecf4bfacea'
            '505172c4190e9953e603124c67175f3b';
        const eventId =
            'e46ff7d0d71d6c8114b58728afa43f08'
            'd6286fd9a704683af799fd8f855586c2';
        final relayHit = Event.fromJson({
          'id': eventId,
          'pubkey':
              '076c979382b90f5d3a2b21f95e1ee86b'
              '6033f14c92e79b7fad3fe1f1073f4886',
          'created_at': 1777868006,
          'kind': 34236,
          'tags': [
            ['d', stableId],
            ['url', 'https://media.divine.video/$stableId'],
            ['title', 'REST down'],
          ],
          'content': 'REST down',
          'sig': 'sig',
        });

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideoEvent(stableId),
        ).thenThrow(const FunnelcakeTimeoutException('https://example.test'));
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments.single as List<Filter>;
          final filter = filters.single;
          if (filter.d?.contains(stableId) ?? false) {
            return [relayHit];
          }
          return <Event>[];
        });

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.fetchVideoWithStatsForRouteId(stableId);

        expect(result, isNotNull);
        expect(result!.id, equals(eventId));
      });

      test('tries fallback route IDs when the primary route misses', () async {
        const fallbackEventId =
            'e46ff7d0d71d6c8114b58728afa43f08'
            'd6286fd9a704683af799fd8f855586c2';
        const author =
            '076c979382b90f5d3a2b21f95e1ee86b'
            '6033f14c92e79b7fad3fe1f1073f4886';
        const missingAddressableId = '34236:$author:missing-stable-id';
        final fallbackEvent = _createVideoEvent(
          id: fallbackEventId,
          pubkey: author,
          videoUrl: 'https://example.com/fallback.mp4',
          createdAt: 1777868006,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments.single as List<Filter>;
          final filter = filters.single;
          if (filter.ids?.contains(fallbackEventId) ?? false) {
            return [fallbackEvent];
          }
          return <Event>[];
        });

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.fetchVideoWithStatsForRouteId(
          missingAddressableId,
          fallbackRouteIds: const [fallbackEventId],
        );

        expect(result, isNotNull);
        expect(result!.id, equals(fallbackEventId));
      });

      test(
        'still tries fallback route IDs when the primary lookup was '
        'unreachable',
        () async {
          // The unreachable-lookup rethrow must not pre-empt the fallbacks.
          // A DM-shared video passes the bare stable ID as the primary route
          // and the author-scoped addressable as a fallback, which is a
          // relay-only query that resolves fine while Funnelcake is down.
          const fallbackEventId =
              'e46ff7d0d71d6c8114b58728afa43f08'
              'd6286fd9a704683af799fd8f855586c2';
          const author =
              '076c979382b90f5d3a2b21f95e1ee86b'
              '6033f14c92e79b7fad3fe1f1073f4886';
          const missingAddressableId = '34236:$author:missing-stable-id';
          final fallbackEvent = _createVideoEvent(
            id: fallbackEventId,
            pubkey: author,
            videoUrl: 'https://example.com/fallback.mp4',
            createdAt: 1777868006,
          );

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getVideoEvent(any()),
          ).thenThrow(const FunnelcakeTimeoutException('https://example.com'));
          when(() => mockNostrClient.queryEvents(any())).thenAnswer((
            invocation,
          ) async {
            final filters =
                invocation.positionalArguments.single as List<Filter>;
            final filter = filters.single;
            if (filter.ids?.contains(fallbackEventId) ?? false) {
              return [fallbackEvent];
            }
            return <Event>[];
          });

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.fetchVideoWithStatsForRouteId(
            missingAddressableId,
            fallbackRouteIds: const [fallbackEventId],
          );

          expect(result, isNotNull);
          expect(result!.id, equals(fallbackEventId));
        },
      );

      test(
        'rethrows once every fallback route ID has also come up empty',
        () async {
          const fallbackEventId =
              'e46ff7d0d71d6c8114b58728afa43f08'
              'd6286fd9a704683af799fd8f855586c2';
          const author =
              '076c979382b90f5d3a2b21f95e1ee86b'
              '6033f14c92e79b7fad3fe1f1073f4886';
          const missingAddressableId = '34236:$author:missing-stable-id';

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getVideoEvent(any()),
          ).thenThrow(const FunnelcakeTimeoutException('https://example.com'));
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => const <Event>[]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await expectLater(
            repo.fetchVideoWithStatsForRouteId(
              missingAddressableId,
              fallbackRouteIds: const [fallbackEventId],
            ),
            throwsA(isA<FunnelcakeException>()),
          );
        },
      );

      test('returns null without blocking when relay queries hang past the '
          'route timeout', () async {
        const stableId =
            'e96357668c72c8923340b0ecf4bfacea'
            '505172c4190e9953e603124c67175f3b';

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideoEvent(stableId),
        ).thenAnswer((_) async => null);
        // Relay never completes — simulates a stuck subscription waiting
        // for EOSE from a still-connecting relay during cold start.
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) => Completer<List<Event>>().future);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo
            .fetchVideoWithStatsForRouteId(stableId)
            // Cap above the in-source 3s timeout but well below the 60s+
            // user-visible regression — a passing test proves the in-source
            // timeout fired before the test wrapper.
            .timeout(const Duration(seconds: 10));

        expect(result, isNull);
      });

      test('returns Funnelcake video when bulk-stats hydration hangs past '
          'the stats timeout', () async {
        const stableId =
            'e96357668c72c8923340b0ecf4bfacea'
            '505172c4190e9953e603124c67175f3b';
        const eventId =
            'e46ff7d0d71d6c8114b58728afa43f08'
            'd6286fd9a704683af799fd8f855586c2';
        final apiHit = Event.fromJson({
          'id': eventId,
          'pubkey':
              '076c979382b90f5d3a2b21f95e1ee86b'
              '6033f14c92e79b7fad3fe1f1073f4886',
          'created_at': 1777868006,
          'kind': 34236,
          'tags': [
            ['d', stableId],
            ['url', 'https://media.divine.video/$stableId'],
            ['title', 'Stats hang test'],
          ],
          'content': 'Stats hang test',
          'sig': 'sig',
        });

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideoEvent(stableId),
        ).thenAnswer((_) async => apiHit);
        // Bulk stats endpoint hangs forever — would have re-stalled the
        // spinner before the stats-timeout was added to the route helpers.
        when(
          () => mockFunnelcakeClient.getBulkVideoStats(any()),
        ).thenAnswer((_) => Completer<BulkVideoStatsResponse>().future);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo
            .fetchVideoWithStatsForRouteId(stableId)
            // Wider than the 3s stats timeout but well below the 15s
            // route-relay budget — a passing test proves stats hydration
            // degraded rather than blocking the caller.
            .timeout(const Duration(seconds: 8));

        expect(result, isNotNull);
        expect(result!.id, equals(eventId));
        // Stats never hydrated, so derived fields stay at the parsed
        // event's defaults rather than the (non-existent) API totals.
        verify(() => mockFunnelcakeClient.getVideoEvent(stableId)).called(1);
      });

      test('addressable relay lookup returns the video even when stats hang — '
          'the per-helper timeouts must not compound', () async {
        const eventId =
            'd695f6b60119d9521934a691347d9f78'
            'e8770b56da16bb255ee77ac112b4c1f6';
        const author =
            '4bf0c63fcb93463407af97a5e5ee64fa'
            '883d107ef9e558472c4eb9aaaefa459d';
        const dTag = 'addressable-stats-hang';
        const rawAddressableId = '34236:$author:$dTag';
        final event = _createVideoEventWithDTag(
          id: eventId,
          pubkey: author,
          dTag: dTag,
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1739350000,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        // The parser sets stableId from the raw addressable id's d-tag, so
        // the orchestrator still tries REST first. Stub it to miss so the
        // addressable relay branch is exercised.
        when(
          () => mockFunnelcakeClient.getVideoEvent(dTag),
        ).thenAnswer((_) async => null);
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);
        // Stats endpoint hangs forever. The pre-fix orchestrator wrapped
        // the whole addressable branch in a 3s timeout that would have
        // killed this successful relay lookup once stats stalled.
        when(
          () => mockFunnelcakeClient.getBulkVideoStats(any()),
        ).thenAnswer((_) => Completer<BulkVideoStatsResponse>().future);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo
            .fetchVideoWithStatsForRouteId(rawAddressableId)
            .timeout(const Duration(seconds: 8));

        expect(result, isNotNull);
        expect(result!.id, equals(eventId));
        expect(result.vineId, equals(dTag));
      });

      test('returns blocked-author videos for direct route lookups', () async {
        const stableId =
            'f96357668c72c8923340b0ecf4bfacea505172c4190e9953e603124c67175f3b';
        const eventId =
            'f46ff7d0d71d6c8114b58728afa43f08d6286fd9a704683af799fd8f855586c2';
        const blockedPubkey =
            '076c979382b90f5d3a2b21f95e1ee86b6033f14c92e79b7fad3fe1f1073f4886';
        final blockedEvent = _createVideoEvent(
          id: eventId,
          pubkey: blockedPubkey,
          videoUrl: 'https://media.divine.video/$stableId',
          createdAt: 1777868006,
          extraTags: [
            ['d', stableId],
            ['title', 'Blocked deep-link target'],
          ],
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [blockedEvent]);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
          blockFilter: (pubkey) => pubkey == blockedPubkey,
        );

        final result = await repo.fetchVideoWithStatsForRouteId(stableId);

        expect(result, isNotNull);
        expect(result!.id, equals(eventId));
        expect(result.pubkey, equals(blockedPubkey));
      });

      test('resolves nevent route IDs via event ID lookup', () async {
        const eventId =
            'b695f6b60119d9521934a691347d9f78e8770b56da16bb255ee77ac112b4c1f6';
        const author =
            '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
        final nevent = NIP19Tlv.encodeNevent(
          Nevent(id: eventId, author: author),
        );
        final event = _createVideoEvent(
          id: eventId,
          pubkey: author,
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1739350000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.fetchVideoWithStatsForRouteId(nevent);

        expect(result, isNotNull);
        expect(result!.id, equals(eventId));
      });

      test('resolves naddr route IDs via addressable lookup', () async {
        const eventId =
            'c695f6b60119d9521934a691347d9f78e8770b56da16bb255ee77ac112b4c1f6';
        const author =
            '4bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
        const dTag = 'shared-video';
        final naddr = NIP19Tlv.encodeNaddr(
          Naddr(id: dTag, author: author, kind: EventKind.videoVertical),
        );
        final event = _createVideoEventWithDTag(
          id: eventId,
          pubkey: author,
          dTag: dTag,
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1739350000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.fetchVideoWithStatsForRouteId(naddr);

        expect(result, isNotNull);
        expect(result!.id, equals(eventId));
        expect(result.vineId, equals(dTag));
      });

      test(
        'resolves raw kind:pubkey:d-tag addressable IDs via addressable lookup',
        () async {
          const eventId =
              'd695f6b60119d9521934a691347d9f78'
              'e8770b56da16bb255ee77ac112b4c1f6';
          const author =
              '4bf0c63fcb93463407af97a5e5ee64fa'
              '883d107ef9e558472c4eb9aaaefa459d';
          const dTag = 'my-vine-id';
          // Raw addressable coordinate as produced by
          // VideoNotification.videoAddressableId — no bech32 encoding.
          const rawAddressableId = '34236:$author:$dTag';
          final event = _createVideoEventWithDTag(
            id: eventId,
            pubkey: author,
            dTag: dTag,
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1739350000,
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [event]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.fetchVideoWithStatsForRouteId(
            rawAddressableId,
          );

          expect(result, isNotNull);
          expect(result!.id, equals(eventId));
          expect(result.vineId, equals(dTag));

          // Verify the relay was queried by author + d-tag, not by event ID.
          final captured =
              verify(
                    () => mockNostrClient.queryEvents(captureAny()),
                  ).captured.single
                  as List<Filter>;
          expect(captured, hasLength(1));
          expect(captured.single.authors, equals([author]));
          expect(captured.single.d, equals([dTag]));
        },
      );

      test(
        'raw addressable routes ignore same-d-tag REST hits from a different '
        'author before falling back to relay',
        () async {
          const eventId =
              'd695f6b60119d9521934a691347d9f78'
              'e8770b56da16bb255ee77ac112b4c1f6';
          const wrongEventId =
              'e695f6b60119d9521934a691347d9f78'
              'e8770b56da16bb255ee77ac112b4c1f6';
          const author =
              '4bf0c63fcb93463407af97a5e5ee64fa'
              '883d107ef9e558472c4eb9aaaefa459d';
          const wrongAuthor =
              '5bf0c63fcb93463407af97a5e5ee64fa'
              '883d107ef9e558472c4eb9aaaefa459d';
          const dTag = 'shared-dtag';
          const rawAddressableId = '34236:$author:$dTag';
          final wrongRestEvent = _createVideoEventWithDTag(
            id: wrongEventId,
            pubkey: wrongAuthor,
            dTag: dTag,
            videoUrl: 'https://example.com/wrong.mp4',
            createdAt: 1739350000,
          );
          final relayEvent = _createVideoEventWithDTag(
            id: eventId,
            pubkey: author,
            dTag: dTag,
            videoUrl: 'https://example.com/correct.mp4',
            createdAt: 1739350100,
          );

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getVideoEvent(dTag),
          ).thenAnswer((_) async => wrongRestEvent);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [relayEvent]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.fetchVideoWithStatsForRouteId(
            rawAddressableId,
          );

          expect(result, isNotNull);
          expect(result!.id, equals(eventId));
          expect(result.pubkey, equals(author));
          verify(() => mockFunnelcakeClient.getVideoEvent(dTag)).called(1);

          final captured =
              verify(
                    () => mockNostrClient.queryEvents(captureAny()),
                  ).captured.single
                  as List<Filter>;
          expect(captured.single.authors, equals([author]));
          expect(captured.single.d, equals([dTag]));
        },
      );

      test(
        'addressable relay lookup accepts legacy NIP-71 kinds — '
        'naddr1 pointing at kind 22 must resolve like a raw 64-hex route',
        () async {
          const eventId =
              'a895f6b60119d9521934a691347d9f78'
              'e8770b56da16bb255ee77ac112b4c1f6';
          const author =
              '4bf0c63fcb93463407af97a5e5ee64fa'
              '883d107ef9e558472c4eb9aaaefa459d';
          const dTag = 'legacy-vine-22';
          // naddr1 referencing legacy kind 22 (NIP-71 short video) — the
          // pre-relax addressable branch gated on isVideoKind() and would
          // drop this at the kind check before querying the relay.
          final naddr = NIP19Tlv.encodeNaddr(
            Naddr(id: dTag, author: author, kind: 22),
          );
          final legacyEvent = Event.fromJson({
            'id': eventId,
            'pubkey': author,
            'created_at': 1739350000,
            'kind': 22,
            'tags': [
              ['d', dTag],
              ['url', 'https://example.com/legacy.mp4'],
              ['title', 'Legacy kind-22 addressable'],
            ],
            'content': '',
            'sig': 'sig',
          });

          when(() => mockNostrClient.queryEvents(any())).thenAnswer((
            invocation,
          ) async {
            final filters =
                invocation.positionalArguments.single as List<Filter>;
            final filter = filters.single;
            // Only match the addressable filter (kind + author + d-tag),
            // so the test fails loudly if the gate sends us back to the
            // event-id or stable-id branches instead.
            if ((filter.kinds?.contains(22) ?? false) &&
                (filter.authors?.contains(author) ?? false) &&
                (filter.d?.contains(dTag) ?? false)) {
              return [legacyEvent];
            }
            return <Event>[];
          });

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.fetchVideoWithStatsForRouteId(naddr);

          expect(result, isNotNull);
          expect(result!.id, equals(eventId));
          expect(result.vineId, equals(dTag));
        },
      );

      test(
        'raw addressable coordinates accept legacy NIP-71 kinds — '
        'a 34235:pubkey:d-tag route must stay author-scoped instead of '
        'degrading to a bare d-tag lookup of the whole coordinate string',
        () async {
          const eventId =
              'b995f6b60119d9521934a691347d9f78'
              'e8770b56da16bb255ee77ac112b4c1f6';
          const author =
              '4bf0c63fcb93463407af97a5e5ee64fa'
              '883d107ef9e558472c4eb9aaaefa459d';
          const dTag = 'normal-video-34235';
          // DM share-card fallbacks build raw coordinates from the shared
          // ref's kind, which can be 34235 (addressable normal video). The
          // pre-fix parse branch gated on isVideoKind() (34236 only), so
          // this string fell through to a stableId candidate whose relay
          // query searched d: ['34235:<pubkey>:<d-tag>'] — unmatched.
          const rawAddressableId = '34235:$author:$dTag';
          final legacyEvent = Event.fromJson({
            'id': eventId,
            'pubkey': author,
            'created_at': 1739350000,
            'kind': 34235,
            'tags': [
              ['d', dTag],
              ['url', 'https://example.com/normal.mp4'],
              ['title', 'Kind-34235 addressable'],
            ],
            'content': '',
            'sig': 'sig',
          });

          when(() => mockNostrClient.queryEvents(any())).thenAnswer((
            invocation,
          ) async {
            final filters =
                invocation.positionalArguments.single as List<Filter>;
            final filter = filters.single;
            // Only match the addressable filter (kind + author + d-tag),
            // so the test fails loudly if the parse gate degrades the
            // coordinate to an unscoped stable-id lookup again.
            if ((filter.kinds?.contains(34235) ?? false) &&
                (filter.authors?.contains(author) ?? false) &&
                (filter.d?.contains(dTag) ?? false)) {
              return [legacyEvent];
            }
            return <Event>[];
          });

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.fetchVideoWithStatsForRouteId(
            rawAddressableId,
          );

          expect(result, isNotNull);
          expect(result!.id, equals(eventId));
          expect(result.vineId, equals(dTag));
          expect(result.pubkey, equals(author));
        },
      );

      test(
        'resolves plain stable IDs from local storage before relay',
        () async {
          const eventId =
              'd695f6b60119d9521934a691347d9f78'
              'e8770b56da16bb255ee77ac112b4c1f6';
          const stableId = 'shared-video';
          final event = _createVideoEventWithDTag(
            id: eventId,
            pubkey: 'pubkey-1',
            dTag: stableId,
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1739350000,
          );
          final mockLocalStorage = MockVideoLocalStorage();

          when(
            () => mockLocalStorage.getEventsByDTag(stableId),
          ).thenAnswer((_) async => [event]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.fetchVideoWithStatsForRouteId(stableId);

          expect(result, isNotNull);
          expect(result!.id, equals(eventId));
          verify(() => mockLocalStorage.getEventsByDTag(stableId)).called(1);
          verifyNever(() => mockNostrClient.queryEvents(any()));
        },
      );

      test('raw addressable routes ignore same-d-tag local cache hits from a '
          'different author before falling back to relay', () async {
        const eventId =
            'd695f6b60119d9521934a691347d9f78'
            'e8770b56da16bb255ee77ac112b4c1f6';
        const wrongEventId =
            'e695f6b60119d9521934a691347d9f78'
            'e8770b56da16bb255ee77ac112b4c1f6';
        const author =
            '4bf0c63fcb93463407af97a5e5ee64fa'
            '883d107ef9e558472c4eb9aaaefa459d';
        const wrongAuthor =
            '5bf0c63fcb93463407af97a5e5ee64fa'
            '883d107ef9e558472c4eb9aaaefa459d';
        const dTag = 'cached-shared-dtag';
        const rawAddressableId = '34236:$author:$dTag';
        final wrongCachedEvent = _createVideoEventWithDTag(
          id: wrongEventId,
          pubkey: wrongAuthor,
          dTag: dTag,
          videoUrl: 'https://example.com/wrong.mp4',
          createdAt: 1739350000,
        );
        final relayEvent = _createVideoEventWithDTag(
          id: eventId,
          pubkey: author,
          dTag: dTag,
          videoUrl: 'https://example.com/correct.mp4',
          createdAt: 1739350100,
        );
        final mockLocalStorage = MockVideoLocalStorage();

        when(
          () => mockLocalStorage.getEventsByDTag(dTag),
        ).thenAnswer((_) async => [wrongCachedEvent]);
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [relayEvent]);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.fetchVideoWithStatsForRouteId(
          rawAddressableId,
        );

        expect(result, isNotNull);
        expect(result!.id, equals(eventId));
        expect(result.pubkey, equals(author));
        verify(() => mockLocalStorage.getEventsByDTag(dTag)).called(1);

        final captured =
            verify(
                  () => mockNostrClient.queryEvents(captureAny()),
                ).captured.single
                as List<Filter>;
        expect(captured.single.authors, equals([author]));
        expect(captured.single.d, equals([dTag]));
      });

      test(
        'falls back to relay lookup for stable IDs missing from local cache',
        () async {
          const eventId =
              'f695f6b60119d9521934a691347d9f78'
              'e8770b56da16bb255ee77ac112b4c1f6';
          const stableId = 'relay-only-video';
          final event = _createVideoEventWithDTag(
            id: eventId,
            pubkey: 'pubkey-2',
            dTag: stableId,
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1739350100,
          );
          final mockLocalStorage = MockVideoLocalStorage();

          when(
            () => mockLocalStorage.getEventsByDTag(stableId),
          ).thenAnswer((_) async => const []);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [event]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.fetchVideoWithStatsForRouteId(stableId);

          expect(result, isNotNull);
          expect(result!.id, equals(eventId));
          verify(() => mockLocalStorage.getEventsByDTag(stableId)).called(1);

          final captured =
              verify(
                    () => mockNostrClient.queryEvents(captureAny()),
                  ).captured.single
                  as List<Filter>;
          expect(captured, hasLength(1));
          expect(captured.single.d, equals([stableId]));
          expect(
            captured.single.kinds,
            equals(NIP71VideoKinds.getAllAcceptableVideoKinds()),
          );
        },
      );
    });

    group('getBulkVideoStats', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns BulkVideoStatsResponse on success', () async {
        const testResponse = BulkVideoStatsResponse(
          stats: {
            'event-1': BulkVideoStatsEntry(
              eventId: 'event-1',
              reactions: 10,
              comments: 5,
              reposts: 2,
            ),
          },
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getBulkVideoStats(['event-1']),
        ).thenAnswer((_) async => testResponse);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getBulkVideoStats(['event-1']);

        expect(result, isNotNull);
        expect(result!.stats, hasLength(1));
      });

      test('returns null when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getBulkVideoStats(['event-1']);

        expect(result, isNull);
      });

      test('returns null when API client is null', () async {
        final result = await repository.getBulkVideoStats(['event-1']);

        expect(result, isNull);
      });

      test('propagates FunnelcakeException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getBulkVideoStats(any()),
        ).thenThrow(const FunnelcakeException('error'));

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repo.getBulkVideoStats(['event-1']),
          throwsA(isA<FunnelcakeException>()),
        );
      });
    });

    group('getRecommendedVideos', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
      });

      test('returns home feed result from recommendations endpoint', () async {
        final recommended = _createVideoStats(
          id: 'recommended-video',
          pubkey: 'recommended-pubkey',
          dTag: 'recommended-dtag',
          videoUrl: 'https://example.com/recommended.mp4',
        );
        when(
          () => mockFunnelcakeClient.getRecommendations(
            seed: any(named: 'seed'),
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            fallback: any(named: 'fallback'),
            category: any(named: 'category'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer(
          (_) async => RecommendationsResponse(
            videos: [recommended],
            source: 'personalized',
            rawBody: '{"videos":[{"id":"recommended-video"}]}',
          ),
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getRecommendedVideos(
          userPubkey: 'user-pubkey',
          limit: 10,
        );

        expect(result.videos, hasLength(1));
        expect(result.videos.single.id, equals('recommended-video'));
        expect(result.videoListSources, isEmpty);
        expect(result.listOnlyVideoIds, isEmpty);
        verify(
          () => mockFunnelcakeClient.getRecommendations(
            seed: any(named: 'seed'),
            pubkey: 'user-pubkey',
            limit: 10,
          ),
        ).called(1);
      });

      test(
        'moves recently seen recommendations after unseen candidates',
        () async {
          final recentlySeen = _createVideoStats(
            id: 'recently-seen-video',
            pubkey: 'recently-seen-pubkey',
            dTag: 'recently-seen-dtag',
            videoUrl: 'https://example.com/recently-seen.mp4',
          );
          final unseen = _createVideoStats(
            id: 'unseen-video',
            pubkey: 'unseen-pubkey',
            dTag: 'unseen-dtag',
            videoUrl: 'https://example.com/unseen.mp4',
          );
          when(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
              preferredLanguages: any(named: 'preferredLanguages'),
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).thenAnswer(
            (_) async => RecommendationsResponse(
              videos: [recentlySeen, unseen],
              source: 'personalized',
            ),
          );

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            seenVideoLookup: SeenVideoLookup(
              wasSeenRecently:
                  (videoId, {within = const Duration(hours: 24)}) =>
                      videoId == 'recently-seen-video',
            ),
          );

          final result = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            limit: 10,
          );

          expect(result.videos.map((video) => video.id), [
            'unseen-video',
            'recently-seen-video',
          ]);
        },
      );

      test(
        'keeps recently seen recommendations as fallback when all are seen',
        () async {
          final firstSeen = _createVideoStats(
            id: 'first-seen-video',
            pubkey: 'first-seen-pubkey',
            dTag: 'first-seen-dtag',
            videoUrl: 'https://example.com/first-seen.mp4',
          );
          final secondSeen = _createVideoStats(
            id: 'second-seen-video',
            pubkey: 'second-seen-pubkey',
            dTag: 'second-seen-dtag',
            videoUrl: 'https://example.com/second-seen.mp4',
          );
          when(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
              preferredLanguages: any(named: 'preferredLanguages'),
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).thenAnswer(
            (_) async => RecommendationsResponse(
              videos: [firstSeen, secondSeen],
              source: 'personalized',
            ),
          );

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            seenVideoLookup: SeenVideoLookup(
              wasSeenRecently: (_, {within = const Duration(hours: 24)}) =>
                  true,
            ),
          );

          final result = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            limit: 10,
          );

          expect(result.videos.map((video) => video.id), [
            'first-seen-video',
            'second-seen-video',
          ]);
        },
      );

      test(
        'waits for seen lookup initialization before freshness ordering',
        () async {
          final recentlySeen = _createVideoStats(
            id: 'recently-seen-video',
            pubkey: 'recently-seen-pubkey',
            dTag: 'recently-seen-dtag',
            videoUrl: 'https://example.com/recently-seen.mp4',
          );
          final unseen = _createVideoStats(
            id: 'unseen-video',
            pubkey: 'unseen-pubkey',
            dTag: 'unseen-dtag',
            videoUrl: 'https://example.com/unseen.mp4',
          );
          when(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
              preferredLanguages: any(named: 'preferredLanguages'),
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).thenAnswer(
            (_) async => RecommendationsResponse(
              videos: [recentlySeen, unseen],
              source: 'personalized',
            ),
          );

          final initializeCompleter = Completer<void>();
          var initialized = false;
          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            seenVideoLookup: SeenVideoLookup(
              initialize: () => initializeCompleter.future,
              wasSeenRecently:
                  (videoId, {within = const Duration(hours: 24)}) =>
                      initialized && videoId == 'recently-seen-video',
            ),
          );

          var completed = false;
          final resultFuture = repo
              .getRecommendedVideos(userPubkey: 'user-pubkey', limit: 10)
              .then((result) {
                completed = true;
                return result;
              });

          await pumpEventQueue();
          expect(completed, isFalse);

          initialized = true;
          initializeCompleter.complete();
          final result = await resultFuture;

          expect(result.videos.map((video) => video.id), [
            'unseen-video',
            'recently-seen-video',
          ]);
        },
      );

      test(
        'fetches deeper recommendation pages when the first page is all seen',
        () async {
          final firstSeen = _createVideoStats(
            id: 'first-seen-video',
            pubkey: 'first-seen-pubkey',
            dTag: 'first-seen-dtag',
            videoUrl: 'https://example.com/first-seen.mp4',
          );
          final secondSeen = _createVideoStats(
            id: 'second-seen-video',
            pubkey: 'second-seen-pubkey',
            dTag: 'second-seen-dtag',
            videoUrl: 'https://example.com/second-seen.mp4',
          );
          final deeperUnseen = _createVideoStats(
            id: 'deeper-unseen-video',
            pubkey: 'deeper-unseen-pubkey',
            dTag: 'deeper-unseen-dtag',
            videoUrl: 'https://example.com/deeper-unseen.mp4',
          );
          final requestedCursors = <String?>[];
          when(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
              preferredLanguages: any(named: 'preferredLanguages'),
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).thenAnswer((invocation) async {
            final cursor = invocation.namedArguments[#cursor] as String?;
            requestedCursors.add(cursor);
            if (cursor == null) {
              return RecommendationsResponse(
                videos: [firstSeen, secondSeen],
                source: 'personalized',
                nextCursor: 'page-2',
                hasMore: true,
              );
            }
            expect(cursor, equals('page-2'));
            return RecommendationsResponse(
              videos: [deeperUnseen],
              source: 'personalized',
              nextCursor: 'page-3',
              hasMore: true,
            );
          });

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            seenVideoLookup: SeenVideoLookup(
              wasSeenRecently:
                  (videoId, {within = const Duration(hours: 24)}) =>
                      videoId != 'deeper-unseen-video',
            ),
          );

          final result = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            limit: 2,
          );

          expect(result.videos.map((video) => video.id), [
            'deeper-unseen-video',
            'first-seen-video',
            'second-seen-video',
          ]);
          expect(result.paginationCursor, equals('page-3'));
          expect(result.hasMore, isTrue);
          expect(result.recommendationPageCount, 2);
          expect(requestedCursors, [null, 'page-2']);
        },
      );

      test(
        'orders cursor pages while preserving pagination metadata',
        () async {
          final requestedCursors = <String?>[];
          when(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
              preferredLanguages: any(named: 'preferredLanguages'),
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).thenAnswer((invocation) async {
            final cursor = invocation.namedArguments[#cursor] as String?;
            requestedCursors.add(cursor);
            return RecommendationsResponse(
              videos: [
                _createVideoStats(
                  id: 'recently-seen-$cursor',
                  pubkey: 'recently-seen-pubkey-$cursor',
                  dTag: 'recently-seen-dtag-$cursor',
                  videoUrl: 'https://example.com/recently-seen-$cursor.mp4',
                ),
                _createVideoStats(
                  id: 'unseen-$cursor',
                  pubkey: 'unseen-pubkey-$cursor',
                  dTag: 'unseen-dtag-$cursor',
                  videoUrl: 'https://example.com/unseen-$cursor.mp4',
                ),
              ],
              source: 'personalized',
              nextCursor: 'next-$cursor',
              hasMore: true,
            );
          });

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            seenVideoLookup: SeenVideoLookup(
              wasSeenRecently:
                  (videoId, {within = const Duration(hours: 24)}) =>
                      videoId.startsWith('recently-seen-'),
            ),
          );

          final result = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            cursor: 'cursor-1',
            limit: 10,
          );

          expect(requestedCursors, ['cursor-1']);
          expect(result.paginationCursor, 'next-cursor-1');
          expect(result.hasMore, isTrue);
          expect(result.videos.map((video) => video.id), [
            'unseen-cursor-1',
            'recently-seen-cursor-1',
          ]);
        },
      );

      test(
        'deduplicates videos sharing an addressable identity in one page',
        () async {
          const author = 'recommended-pubkey';
          const sharedDTag = 'shared-dtag';
          // Same kind:pubkey:d-tag republished with a fresh event id — the
          // server's emitted-id cursor dedupes by event id, so this slips
          // through and must be collapsed by feedDedupKey here.
          final first = _createVideoStats(
            id: 'first-event-id',
            pubkey: author,
            dTag: sharedDTag,
            videoUrl: 'https://example.com/first.mp4',
            createdAt: 1704067250,
          );
          final republished = _createVideoStats(
            id: 'republished-event-id',
            pubkey: author,
            dTag: sharedDTag,
            videoUrl: 'https://example.com/republished.mp4',
            createdAt: 1704067150,
          );
          final other = _createVideoStats(
            id: 'other-event-id',
            pubkey: 'other-pubkey',
            dTag: 'other-dtag',
            videoUrl: 'https://example.com/other.mp4',
            createdAt: 1704067100,
          );
          when(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
              preferredLanguages: any(named: 'preferredLanguages'),
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).thenAnswer(
            (_) async => RecommendationsResponse(
              videos: [first, republished, other],
              source: 'personalized',
            ),
          );

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            limit: 10,
          );

          expect(result.videos, hasLength(2));
          expect(
            result.videos.map((v) => v.feedDedupKey).toSet(),
            hasLength(2),
            reason: 'no duplicate feedDedupKey survives',
          );
          expect(
            result.videos.where((v) => v.pubkey == author).length,
            1,
            reason: 'the republished addressable video collapses to one entry',
          );
        },
      );

      test('caches refreshed recommendations for feed remounts', () async {
        final requestedSeeds = <String?>[];
        var callCount = 0;
        when(
          () => mockFunnelcakeClient.getRecommendations(
            seed: any(named: 'seed'),
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            fallback: any(named: 'fallback'),
            category: any(named: 'category'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((invocation) async {
          requestedSeeds.add(invocation.namedArguments[#seed] as String?);
          callCount += 1;
          return RecommendationsResponse(
            videos: [
              _createVideoStats(
                id: 'recommended-video-$callCount',
                pubkey: 'recommended-pubkey-$callCount',
                dTag: 'recommended-dtag-$callCount',
                videoUrl: 'https://example.com/recommended-$callCount.mp4',
              ),
            ],
            source: 'personalized',
            nextCursor: 'cursor-$callCount',
            hasMore: true,
          );
        });

        final feedCache = InMemoryFeedCache();
        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
          inMemoryFeedCache: feedCache,
        );

        final refreshed = await repo.getRecommendedVideos(
          userPubkey: 'user-pubkey',
          skipCache: true,
        );
        final cachedAfterRefresh = await repo.getRecommendedVideos(
          userPubkey: 'user-pubkey',
        );
        final secondRefresh = await repo.getRecommendedVideos(
          userPubkey: 'user-pubkey',
          skipCache: true,
        );
        final cachedAfterSecondRefresh = await repo.getRecommendedVideos(
          userPubkey: 'user-pubkey',
        );

        expect(refreshed.videos.single.id, equals('recommended-video-1'));
        expect(
          cachedAfterRefresh.videos.single.id,
          equals('recommended-video-1'),
        );
        expect(secondRefresh.videos.single.id, equals('recommended-video-2'));
        expect(
          cachedAfterSecondRefresh.videos.single.id,
          equals('recommended-video-2'),
        );
        expect(cachedAfterSecondRefresh.paginationCursor, equals('cursor-2'));
        expect(cachedAfterSecondRefresh.hasMore, isTrue);
        expect(requestedSeeds, hasLength(2));
        expect(requestedSeeds.first, isNotNull);
        expect(requestedSeeds.first, isNotEmpty);
        expect(requestedSeeds.last, isNot(requestedSeeds.first));
        verify(
          () => mockFunnelcakeClient.getRecommendations(
            seed: any(named: 'seed'),
            pubkey: 'user-pubkey',
            limit: any(named: 'limit'),
          ),
        ).called(2);
      });

      // Session-start revalidation bypasses the cache read but must keep the
      // current recommendation session seed: drawing a new seed reshuffles
      // the session, which is reserved for explicit pull-to-refresh
      // (skipCache).
      test(
        'revalidate bypasses the cache but keeps the session seed',
        () async {
          final requestedSeeds = <String?>[];
          var callCount = 0;
          when(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
              preferredLanguages: any(named: 'preferredLanguages'),
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).thenAnswer((invocation) async {
            requestedSeeds.add(invocation.namedArguments[#seed] as String?);
            callCount += 1;
            return RecommendationsResponse(
              videos: [
                _createVideoStats(
                  id: 'recommended-video-$callCount',
                  pubkey: 'recommended-pubkey-$callCount',
                  dTag: 'recommended-dtag-$callCount',
                  videoUrl: 'https://example.com/recommended-$callCount.mp4',
                ),
              ],
              source: 'personalized',
              nextCursor: 'cursor-$callCount',
              hasMore: true,
            );
          });

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            inMemoryFeedCache: InMemoryFeedCache(),
          );

          final first = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
          );
          // Served from the in-memory cache — no second network call.
          final cached = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
          );
          // Revalidation refetches the first page with the same session seed.
          final revalidated = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            revalidate: true,
          );

          expect(first.videos.single.id, equals('recommended-video-1'));
          expect(cached.videos.single.id, equals('recommended-video-1'));
          expect(revalidated.videos.single.id, equals('recommended-video-2'));
          expect(requestedSeeds, hasLength(2));
          expect(requestedSeeds.first, isNotNull);
          expect(requestedSeeds.first, isNotEmpty);
          expect(requestedSeeds.last, requestedSeeds.first);
          verify(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: 'user-pubkey',
              limit: any(named: 'limit'),
            ),
          ).called(2);
        },
      );

      test('reorders cached recommendations when seen state changes', () async {
        final first = _createVideoStats(
          id: 'first-video',
          pubkey: 'first-pubkey',
          dTag: 'first-dtag',
          videoUrl: 'https://example.com/first.mp4',
        );
        final second = _createVideoStats(
          id: 'second-video',
          pubkey: 'second-pubkey',
          dTag: 'second-dtag',
          videoUrl: 'https://example.com/second.mp4',
        );
        when(
          () => mockFunnelcakeClient.getRecommendations(
            seed: any(named: 'seed'),
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            fallback: any(named: 'fallback'),
            category: any(named: 'category'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer(
          (_) async => RecommendationsResponse(
            videos: [first, second],
            source: 'personalized',
            nextCursor: 'page-2',
            hasMore: true,
          ),
        );

        final recentlySeenIds = <String>{};
        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
          inMemoryFeedCache: InMemoryFeedCache(),
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (videoId, {within = const Duration(hours: 24)}) =>
                recentlySeenIds.contains(videoId),
          ),
        );

        final fresh = await repo.getRecommendedVideos(
          userPubkey: 'user-pubkey',
          limit: 10,
        );
        recentlySeenIds.add('first-video');
        final cached = await repo.getRecommendedVideos(
          userPubkey: 'user-pubkey',
          limit: 10,
        );

        expect(fresh.videos.map((video) => video.id), [
          'first-video',
          'second-video',
        ]);
        expect(cached.videos.map((video) => video.id), [
          'second-video',
          'first-video',
        ]);
        expect(cached.paginationCursor, equals('page-2'));
        expect(cached.hasMore, isTrue);
        verify(
          () => mockFunnelcakeClient.getRecommendations(
            seed: any(named: 'seed'),
            pubkey: 'user-pubkey',
            limit: 10,
          ),
        ).called(1);
      });

      test('keeps the same session seed across cursor pagination', () async {
        final requestedSeeds = <String?>[];
        var callCount = 0;
        when(
          () => mockFunnelcakeClient.getRecommendations(
            seed: any(named: 'seed'),
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            fallback: any(named: 'fallback'),
            category: any(named: 'category'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((invocation) async {
          requestedSeeds.add(invocation.namedArguments[#seed] as String?);
          callCount += 1;
          return RecommendationsResponse(
            videos: [
              _createVideoStats(
                id: 'recommended-video-$callCount',
                pubkey: 'recommended-pubkey-$callCount',
                dTag: 'recommended-dtag-$callCount',
                videoUrl: 'https://example.com/recommended-$callCount.mp4',
              ),
            ],
            source: 'personalized',
            nextCursor: 'cursor-${callCount + 1}',
            hasMore: true,
          );
        });

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final firstPage = await repo.getRecommendedVideos(
          userPubkey: 'user-pubkey',
        );
        final cursorPage = await repo.getRecommendedVideos(
          userPubkey: 'user-pubkey',
          cursor: firstPage.paginationCursor,
        );

        expect(cursorPage.videos.single.id, equals('recommended-video-2'));
        expect(requestedSeeds, hasLength(2));
        expect(requestedSeeds.first, isNotNull);
        expect(requestedSeeds.first, isNotEmpty);
        expect(requestedSeeds.last, requestedSeeds.first);
      });

      test(
        'does not commit refreshed session seed when first page fails',
        () async {
          final requestedSeeds = <String?>[];
          final popular = _createVideoStats(
            id: 'popular-video',
            pubkey: 'popular-pubkey',
            dTag: 'popular-dtag',
            videoUrl: 'https://example.com/popular.mp4',
          );
          var callCount = 0;
          when(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
              preferredLanguages: any(named: 'preferredLanguages'),
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).thenAnswer((invocation) async {
            requestedSeeds.add(invocation.namedArguments[#seed] as String?);
            callCount += 1;
            if (callCount == 2) {
              throw const FunnelcakeException('refresh failed');
            }
            return RecommendationsResponse(
              videos: [
                _createVideoStats(
                  id: 'recommended-video-$callCount',
                  pubkey: 'recommended-pubkey-$callCount',
                  dTag: 'recommended-dtag-$callCount',
                  videoUrl: 'https://example.com/recommended-$callCount.mp4',
                ),
              ],
              source: 'personalized',
              nextCursor: 'cursor-${callCount + 1}',
              hasMore: true,
            );
          });
          when(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => [popular]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            inMemoryFeedCache: InMemoryFeedCache(),
          );

          final firstPage = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
          );
          final fallback = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            skipCache: true,
          );
          await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            cursor: firstPage.paginationCursor,
          );

          expect(fallback.videos.single.id, equals('popular-video'));
          expect(requestedSeeds, hasLength(3));
          expect(requestedSeeds[0], isNotNull);
          expect(requestedSeeds[0], isNotEmpty);
          expect(requestedSeeds[1], isNot(requestedSeeds[0]));
          expect(requestedSeeds[2], requestedSeeds[0]);
        },
      );

      test('passes viewer country hint to recommendations endpoint', () async {
        final recommended = _createVideoStats(
          id: 'country-recommended-video',
          pubkey: 'recommended-pubkey',
          dTag: 'recommended-dtag',
          videoUrl: 'https://example.com/country-recommended.mp4',
        );
        when(
          () => mockFunnelcakeClient.getRecommendations(
            seed: any(named: 'seed'),
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            fallback: any(named: 'fallback'),
            category: any(named: 'category'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer(
          (_) async => RecommendationsResponse(
            videos: [recommended],
            source: 'personalized',
          ),
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getRecommendedVideos(
          userPubkey: 'user-pubkey',
          limit: 10,
          viewerCountry: 'BR',
        );

        expect(result.videos, hasLength(1));
        expect(result.videos.single.id, equals('country-recommended-video'));
        verify(
          () => mockFunnelcakeClient.getRecommendations(
            seed: any(named: 'seed'),
            pubkey: 'user-pubkey',
            limit: 10,
            viewerCountry: 'BR',
          ),
        ).called(1);
      });

      test(
        'falls back to popular videos when no pubkey is available',
        () async {
          final popular = _createVideoStats(
            id: 'popular-video',
            pubkey: 'popular-pubkey',
            dTag: 'popular-dtag',
            videoUrl: 'https://example.com/popular.mp4',
          );
          when(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => [popular]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.getRecommendedVideos(
            userPubkey: null,
            limit: 10,
          );

          expect(result.videos, hasLength(1));
          expect(result.videos.single.id, equals('popular-video'));
          verify(
            () => mockFunnelcakeClient.getWatchingVideos(limit: 10),
          ).called(1);
          verifyNever(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
            ),
          );
        },
      );

      test(
        'revalidate bypasses the popular cache in the fallback path',
        () async {
          final popular = _createVideoStats(
            id: 'popular-video',
            pubkey: 'popular-pubkey',
            dTag: 'popular-dtag',
            videoUrl: 'https://example.com/popular.mp4',
          );
          when(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => [popular]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            inMemoryFeedCache: InMemoryFeedCache(),
          );

          // Populate the popular first-page cache.
          await repo.getPopularVideos();

          // Revalidating For You with no pubkey falls back to popular and
          // must not answer that fallback from the cached popular page.
          final result = await repo.getRecommendedVideos(
            userPubkey: null,
            limit: 10,
            revalidate: true,
          );

          expect(result.videos, hasLength(1));
          expect(result.videos.single.id, equals('popular-video'));
          verify(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).called(2); // 1 popular cache fill + 1 revalidated fallback
        },
      );

      test(
        'falls back to popular videos when recommendations are empty',
        () async {
          final seenPopular = _createVideoStats(
            id: 'seen-popular-video',
            pubkey: 'seen-popular-pubkey',
            dTag: 'seen-popular-dtag',
            videoUrl: 'https://example.com/seen-popular.mp4',
          );
          final unseenPopular = _createVideoStats(
            id: 'unseen-popular-video',
            pubkey: 'unseen-popular-pubkey',
            dTag: 'unseen-popular-dtag',
            videoUrl: 'https://example.com/unseen-popular.mp4',
          );
          when(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
            ),
          ).thenAnswer(
            (_) async =>
                const RecommendationsResponse(videos: [], source: 'popular'),
          );
          when(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => [seenPopular, unseenPopular]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            seenVideoLookup: SeenVideoLookup(
              wasSeenRecently:
                  (videoId, {within = const Duration(hours: 24)}) =>
                      videoId == 'seen-popular-video',
            ),
          );

          final result = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            limit: 10,
          );

          expect(result.videos.map((video) => video.id), [
            'unseen-popular-video',
            'seen-popular-video',
          ]);
          verify(
            () => mockFunnelcakeClient.getWatchingVideos(limit: 10),
          ).called(1);
        },
      );

      test(
        'does not cache empty-recommendations popular fallback as recommended',
        () async {
          final popular = _createVideoStats(
            id: 'popular-video',
            pubkey: 'popular-pubkey',
            dTag: 'popular-dtag',
            videoUrl: 'https://example.com/popular.mp4',
          );
          final recommended = _createVideoStats(
            id: 'recommended-video',
            pubkey: 'recommended-pubkey',
            dTag: 'recommended-dtag',
            videoUrl: 'https://example.com/recommended.mp4',
          );
          var recommendationCallCount = 0;
          when(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
              preferredLanguages: any(named: 'preferredLanguages'),
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).thenAnswer((_) async {
            recommendationCallCount += 1;
            if (recommendationCallCount == 1) {
              return const RecommendationsResponse(
                videos: [],
                source: 'popular',
              );
            }
            return RecommendationsResponse(
              videos: [recommended],
              source: 'personalized',
            );
          });
          when(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => [popular]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            inMemoryFeedCache: InMemoryFeedCache(),
          );

          final fallback = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            limit: 10,
          );
          final recovered = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            limit: 10,
          );

          expect(fallback.videos.single.id, equals('popular-video'));
          expect(recovered.videos.single.id, equals('recommended-video'));
          verify(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: 'user-pubkey',
              limit: 10,
            ),
          ).called(2);
        },
      );

      test(
        'falls back to popular videos when recommendations are unavailable',
        () async {
          final popular = _createVideoEvent(
            id: 'popular-video',
            pubkey: 'popular-pubkey',
            videoUrl: 'https://example.com/popular.mp4',
            createdAt: 1700000000,
          );
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
          when(
            () => mockNostrClient.queryEvents(any(), useCache: false),
          ).thenAnswer((_) async => [popular]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            limit: 10,
          );

          expect(result.videos, hasLength(1));
          expect(result.videos.single.id, equals('popular-video'));
          verifyNever(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
            ),
          );
          verify(
            () => mockNostrClient.queryEvents(any(), useCache: false),
          ).called(1);
        },
      );

      test(
        'does not cache unavailable-recommendations fallback as recommended',
        () async {
          var recommendationsAvailable = false;
          final popular = _createVideoEvent(
            id: 'popular-video',
            pubkey: 'popular-pubkey',
            videoUrl: 'https://example.com/popular.mp4',
            createdAt: 1700000000,
          );
          final recommended = _createVideoStats(
            id: 'recommended-video',
            pubkey: 'recommended-pubkey',
            dTag: 'recommended-dtag',
            videoUrl: 'https://example.com/recommended.mp4',
          );
          when(
            () => mockFunnelcakeClient.isAvailable,
          ).thenAnswer((_) => recommendationsAvailable);
          when(
            () => mockNostrClient.queryEvents(any(), useCache: false),
          ).thenAnswer((_) async => [popular]);
          when(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
              preferredLanguages: any(named: 'preferredLanguages'),
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).thenAnswer(
            (_) async => RecommendationsResponse(
              videos: [recommended],
              source: 'personalized',
            ),
          );

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            inMemoryFeedCache: InMemoryFeedCache(),
          );

          final fallback = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            limit: 10,
          );
          recommendationsAvailable = true;
          final recovered = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            limit: 10,
          );

          expect(fallback.videos.single.id, equals('popular-video'));
          expect(recovered.videos.single.id, equals('recommended-video'));
          verify(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: 'user-pubkey',
              limit: 10,
            ),
          ).called(1);
        },
      );

      test('falls back to popular videos when API client is null', () async {
        final popular = _createVideoEvent(
          id: 'popular-video',
          pubkey: 'popular-pubkey',
          videoUrl: 'https://example.com/popular.mp4',
          createdAt: 1700000000,
        );
        when(
          () => mockNostrClient.queryEvents(any(), useCache: false),
        ).thenAnswer((_) async => [popular]);

        final repo = VideosRepository(nostrClient: mockNostrClient);

        final result = await repo.getRecommendedVideos(
          userPubkey: 'user-pubkey',
          limit: 10,
        );

        expect(result.videos, hasLength(1));
        expect(result.videos.single.id, equals('popular-video'));
        verify(
          () => mockNostrClient.queryEvents(any(), useCache: false),
        ).called(1);
      });

      test(
        'falls back to popular videos when no user pubkey is available',
        () async {
          final popular = _createVideoStats(
            id: 'popular-video',
            pubkey: 'popular-pubkey',
            dTag: 'popular-dtag',
            videoUrl: 'https://example.com/popular.mp4',
          );
          when(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => [popular]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.getRecommendedVideos(
            userPubkey: null,
            limit: 10,
          );

          expect(result.videos, hasLength(1));
          expect(result.videos.single.id, equals('popular-video'));
          verifyNever(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
            ),
          );
          verify(
            () => mockFunnelcakeClient.getWatchingVideos(limit: 10),
          ).called(1);
        },
      );

      test(
        'uses recommendations pagination for subsequent forYou pages',
        () async {
          final recommended = _createVideoStats(
            id: 'recommended-page-2-video',
            pubkey: 'recommended-pubkey',
            dTag: 'recommended-dtag',
            videoUrl: 'https://example.com/recommended-page-2.mp4',
          );
          when(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
              cursor: any(named: 'cursor'),
              preferredLanguages: any(named: 'preferredLanguages'),
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).thenAnswer(
            (_) async => RecommendationsResponse(
              videos: [recommended],
              source: 'personalized',
              nextCursor: 'rec-page-3',
              hasMore: true,
            ),
          );

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            limit: 10,
            cursor: 'rec-page-2',
          );

          expect(result.videos, hasLength(1));
          expect(result.videos.single.id, equals('recommended-page-2-video'));
          expect(result.paginationCursor, equals('rec-page-3'));
          expect(result.hasMore, isTrue);
          verify(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: 'user-pubkey',
              limit: 10,
              cursor: 'rec-page-2',
            ),
          ).called(1);
          verifyNever(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
        },
      );

      test(
        'uses timestamp fallback as recommendation cursor when provided',
        () async {
          final recommended = _createVideoStats(
            id: 'recommended-until-video',
            pubkey: 'recommended-pubkey',
            dTag: 'recommended-dtag',
            videoUrl: 'https://example.com/recommended-until.mp4',
          );
          when(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
              cursor: any(named: 'cursor'),
              preferredLanguages: any(named: 'preferredLanguages'),
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).thenAnswer(
            (_) async => RecommendationsResponse(
              videos: [recommended],
              source: 'personalized',
              nextCursor: 'rec-page-3',
              hasMore: true,
            ),
          );

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            limit: 10,
            until: 1700000000,
          );

          expect(result.videos, hasLength(1));
          expect(result.videos.single.id, equals('recommended-until-video'));
          expect(result.paginationCursor, equals('rec-page-3'));
          expect(result.hasMore, isTrue);
          verify(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: 'user-pubkey',
              limit: 10,
              cursor: '1700000000',
            ),
          ).called(1);
          verifyNever(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
        },
      );

      test(
        'falls back to popular videos when recommendations throw on first page',
        () async {
          final popular = _createVideoStats(
            id: 'popular-video',
            pubkey: 'popular-pubkey',
            dTag: 'popular-dtag',
            videoUrl: 'https://example.com/popular.mp4',
          );
          final recommended = _createVideoStats(
            id: 'recommended-video',
            pubkey: 'recommended-pubkey',
            dTag: 'recommended-dtag',
            videoUrl: 'https://example.com/recommended.mp4',
          );
          var recommendationCallCount = 0;
          when(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              fallback: any(named: 'fallback'),
              category: any(named: 'category'),
              preferredLanguages: any(named: 'preferredLanguages'),
              viewerCountry: any(named: 'viewerCountry'),
            ),
          ).thenAnswer((_) async {
            recommendationCallCount += 1;
            if (recommendationCallCount == 1) {
              throw const FunnelcakeException('recommendations failed');
            }
            return RecommendationsResponse(
              videos: [recommended],
              source: 'personalized',
            );
          });
          when(
            () => mockFunnelcakeClient.getWatchingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => [popular]);

          final repo = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            inMemoryFeedCache: InMemoryFeedCache(),
          );

          final fallback = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            limit: 10,
          );
          final recovered = await repo.getRecommendedVideos(
            userPubkey: 'user-pubkey',
            limit: 10,
          );

          expect(fallback.videos.single.id, equals('popular-video'));
          expect(recovered.videos.single.id, equals('recommended-video'));
          verify(
            () => mockFunnelcakeClient.getRecommendations(
              seed: any(named: 'seed'),
              pubkey: 'user-pubkey',
              limit: 10,
            ),
          ).called(2);
          verify(
            () => mockFunnelcakeClient.getWatchingVideos(limit: 10),
          ).called(1);
        },
      );
    });

    group('getRecommendations', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns RecommendationsResponse on success', () async {
        final testStats = _createVideoStats(
          id: 'event-1',
          pubkey: 'pubkey-1',
          dTag: 'dtag-1',
          videoUrl: 'https://example.com/video.mp4',
        );
        final testResponse = RecommendationsResponse(
          videos: [testStats],
          source: 'popular',
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getRecommendations(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            fallback: any(named: 'fallback'),
            category: any(named: 'category'),
          ),
        ).thenAnswer((_) async => testResponse);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getRecommendations(pubkey: 'user-pubkey');

        expect(result, isNotNull);
        expect(result!.videos, hasLength(1));
        expect(result.source, equals('popular'));
      });

      test('returns null when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getRecommendations(pubkey: 'user-pubkey');

        expect(result, isNull);
      });

      test('returns null when API client is null', () async {
        final result = await repository.getRecommendations(
          pubkey: 'user-pubkey',
        );

        expect(result, isNull);
      });

      test('propagates FunnelcakeException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getRecommendations(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            fallback: any(named: 'fallback'),
            category: any(named: 'category'),
          ),
        ).thenThrow(const FunnelcakeException('error'));

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repo.getRecommendations(pubkey: 'user-pubkey'),
          throwsA(isA<FunnelcakeException>()),
        );
      });

      test('passes parameters correctly', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getRecommendations(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            fallback: any(named: 'fallback'),
            category: any(named: 'category'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer(
          (_) async =>
              const RecommendationsResponse(videos: [], source: 'category'),
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        await repo.getRecommendations(
          pubkey: 'user-pubkey',
          limit: 50,
          fallback: 'recent',
          category: 'sports',
          preferredLanguages: const ['pt'],
          viewerCountry: 'BR',
        );

        verify(
          () => mockFunnelcakeClient.getRecommendations(
            pubkey: 'user-pubkey',
            limit: 50,
            fallback: 'recent',
            category: 'sports',
            preferredLanguages: const ['pt'],
            viewerCountry: 'BR',
          ),
        ).called(1);
      });
    });

    group('clearInMemoryFeedCache', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;
      late InMemoryFeedCache feedCache;
      late VideosRepository repoWithCache;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        feedCache = InMemoryFeedCache();
        repoWithCache = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
          inMemoryFeedCache: feedCache,
        );
      });

      test('clears a single key', () async {
        when(
          () => mockFunnelcakeClient.getRecentVideosPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => _recentPage([
            _createVideoStats(
              id: 'v1',
              pubkey: 'p1',
              dTag: 'd1',
              videoUrl: 'https://example.com/v1.mp4',
            ),
          ]),
        );

        // Populate cache
        await repoWithCache.getNewVideos();

        // Clear latest cache
        repoWithCache.clearInMemoryFeedCache(key: 'latest');

        // Next call hits network again
        await repoWithCache.getNewVideos();
        verify(
          () => mockFunnelcakeClient.getRecentVideosPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).called(2);
      });

      test('clears all keys', () async {
        when(
          () => mockFunnelcakeClient.getRecentVideosPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => _recentPage([
            _createVideoStats(
              id: 'v1',
              pubkey: 'p1',
              dTag: 'd1',
              videoUrl: 'https://example.com/v1.mp4',
            ),
          ]),
        );
        when(
          () => mockFunnelcakeClient.getWatchingVideos(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'pop1',
              pubkey: 'p1',
              dTag: 'd1',
              videoUrl: 'https://example.com/pop1.mp4',
            ),
          ],
        );

        // Populate both caches
        await repoWithCache.getNewVideos();
        await repoWithCache.getPopularVideos();

        // Clear all
        repoWithCache.clearInMemoryFeedCache();

        // Both hit network again
        await repoWithCache.getNewVideos();
        await repoWithCache.getPopularVideos();

        verify(
          () => mockFunnelcakeClient.getRecentVideosPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).called(2);
        verify(
          () => mockFunnelcakeClient.getWatchingVideos(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).called(2);
      });
    });

    group('applyContentPreferences', () {
      const goodPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const blockedPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      const cleanId =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
      const nsfwId =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
      const violenceId =
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

      VideoEvent buildVideo({
        required String id,
        required String pubkey,
        List<String> moderationLabels = const [],
        List<String> contentWarningLabels = const [],
        List<String> warnLabels = const [],
      }) {
        return VideoEvent(
          id: id,
          pubkey: pubkey,
          createdAt: 1704067200,
          content: '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
          videoUrl: 'https://example.com/video.mp4',
          moderationLabels: moderationLabels,
          contentWarningLabels: contentWarningLabels,
          warnLabels: warnLabels,
        );
      }

      test('returns videos unchanged when no filters are injected', () {
        final repo = VideosRepository(nostrClient: mockNostrClient);
        final videos = [
          buildVideo(id: cleanId, pubkey: goodPubkey),
          buildVideo(id: nsfwId, pubkey: blockedPubkey),
        ];

        final result = repo.applyContentPreferences(videos);

        expect(result, equals(videos));
      });

      test('removes videos whose pubkey is blocked', () {
        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: (pubkey) => pubkey == blockedPubkey,
        );
        final good = buildVideo(id: cleanId, pubkey: goodPubkey);
        final bad = buildVideo(id: nsfwId, pubkey: blockedPubkey);

        final result = repo.applyContentPreferences([good, bad]);

        expect(result, equals([good]));
      });

      test('removes videos whose content filter returns true', () {
        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          contentFilter: (video) => video.moderationLabels.contains('nudity'),
        );
        final clean = buildVideo(id: cleanId, pubkey: goodPubkey);
        final nsfw = buildVideo(
          id: nsfwId,
          pubkey: goodPubkey,
          moderationLabels: const ['nudity'],
        );

        final result = repo.applyContentPreferences([clean, nsfw]);

        expect(result, equals([clean]));
      });

      test('applies warn labels from the resolver', () {
        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          warningLabelsResolver: (video) =>
              video.contentWarningLabels.contains('violence')
              ? const ['violence']
              : const [],
        );
        final video = buildVideo(
          id: violenceId,
          pubkey: goodPubkey,
          contentWarningLabels: const ['violence'],
        );

        final result = repo.applyContentPreferences([video]);

        expect(result, hasLength(1));
        expect(result.single.warnLabels, equals(const ['violence']));
      });

      test('clears stale warnLabels when resolver returns empty', () {
        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          warningLabelsResolver: (_) => const [],
        );
        final video = buildVideo(
          id: violenceId,
          pubkey: goodPubkey,
          warnLabels: const ['violence'],
        );

        final result = repo.applyContentPreferences([video]);

        expect(result, hasLength(1));
        expect(result.single.warnLabels, isEmpty);
      });
    });

    group('non-loopback http:// filtering (#3836)', () {
      group('via _tryParseAndFilter (Nostr ingest)', () {
        test('filters out non-loopback http:// video URLs', () async {
          final cleartextEvent = _createVideoEvent(
            id: 'cleartext-id',
            pubkey: 'test-pubkey',
            videoUrl: 'http://example.com/video.mp4',
            createdAt: 1704067200,
          );
          final httpsEvent = _createVideoEvent(
            id: 'https-id',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1704067201,
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [cleartextEvent, httpsEvent]);

          final result = (await repository.getNewVideos()).videos;

          expect(result, hasLength(1));
          expect(result.first.id, equals('https-id'));
        });

        test('allows loopback http://10.0.2.2', () async {
          final loopbackEvent = _createVideoEvent(
            id: 'android-emulator-host',
            pubkey: 'test-pubkey',
            videoUrl: 'http://10.0.2.2:8000/video.mp4',
            createdAt: 1704067200,
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [loopbackEvent]);

          final result = (await repository.getNewVideos()).videos;

          expect(result, hasLength(1));
          expect(result.first.id, equals('android-emulator-host'));
        });

        test('allows loopback http://localhost', () async {
          final loopbackEvent = _createVideoEvent(
            id: 'localhost-host',
            pubkey: 'test-pubkey',
            videoUrl: 'http://localhost:8000/video.mp4',
            createdAt: 1704067200,
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [loopbackEvent]);

          final result = (await repository.getNewVideos()).videos;

          expect(result, hasLength(1));
          expect(result.first.id, equals('localhost-host'));
        });

        test('allows loopback http://127.0.0.1', () async {
          final loopbackEvent = _createVideoEvent(
            id: 'ipv4-loopback',
            pubkey: 'test-pubkey',
            videoUrl: 'http://127.0.0.1:8000/video.mp4',
            createdAt: 1704067200,
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [loopbackEvent]);

          final result = (await repository.getNewVideos()).videos;

          expect(result, hasLength(1));
          expect(result.first.id, equals('ipv4-loopback'));
        });

        test(
          'rejects hostnames that contain but do not equal a loopback host',
          () async {
            final spoofA = _createVideoEvent(
              id: 'spoof-a',
              pubkey: 'test-pubkey',
              videoUrl: 'http://10.0.2.2.example.com/video.mp4',
              createdAt: 1704067200,
            );
            final spoofB = _createVideoEvent(
              id: 'spoof-b',
              pubkey: 'test-pubkey',
              videoUrl: 'http://localhost.evil.com/video.mp4',
              createdAt: 1704067201,
            );
            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => [spoofA, spoofB]);

            final result = (await repository.getNewVideos()).videos;

            expect(result, isEmpty);
          },
        );
      });

      group('via _transformVideoStats (Funnelcake API path)', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        });

        test('filters out non-loopback http:// video URLs', () async {
          when(
            () => mockFunnelcakeClient.getRecentVideosPage(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => _recentPage([
              _createVideoStats(
                id: 'cleartext-id',
                pubkey: 'pubkey-1',
                dTag: 'dtag-1',
                videoUrl: 'http://example.com/video.mp4',
              ),
              _createVideoStats(
                id: 'https-id',
                pubkey: 'pubkey-2',
                dTag: 'dtag-2',
                videoUrl: 'https://example.com/video.mp4',
              ),
            ]),
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = (await repositoryWithApi.getNewVideos()).videos;

          expect(result, hasLength(1));
          expect(result.first.id, equals('https-id'));
        });
      });

      group(
        'via _fetchMissingVideosFromFunnelcake (addressable-id fallback)',
        () {
          late MockFunnelcakeApiClient mockFunnelcakeClient;

          setUp(() {
            mockFunnelcakeClient = MockFunnelcakeApiClient();
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          });

          test('filters out non-loopback http:// video URLs', () async {
            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => <Event>[]);

            final cleartextStats = _createVideoStats(
              id: 'cleartext-id',
              pubkey: 'pubkey1',
              dTag: 'dtag1',
              videoUrl: 'http://example.com/video.mp4',
            );

            when(
              () => mockFunnelcakeClient.getVideosByAuthor(
                pubkey: 'pubkey1',
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => VideosByAuthorResponse(videos: [cleartextStats]),
            );

            final repositoryWithFunnelcake = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repositoryWithFunnelcake
                .getVideosByAddressableIds([
                  '${EventKind.videoVertical}:pubkey1:dtag1',
                ]);

            expect(result, isEmpty);
          });
        },
      );

      group('via applyContentPreferences (cache-restoration path)', () {
        VideoEvent buildVideo({required String id, required String videoUrl}) {
          return VideoEvent(
            id: id,
            pubkey: 'test-pubkey',
            createdAt: 1704067200,
            content: '',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
            videoUrl: videoUrl,
          );
        }

        test('filters out non-loopback http:// video URLs', () {
          final repo = VideosRepository(nostrClient: mockNostrClient);
          final cleartext = buildVideo(
            id: 'cleartext-id',
            videoUrl: 'http://example.com/video.mp4',
          );
          final secure = buildVideo(
            id: 'https-id',
            videoUrl: 'https://example.com/video.mp4',
          );

          final result = repo.applyContentPreferences([cleartext, secure]);

          expect(result, hasLength(1));
          expect(result.single.id, equals('https-id'));
        });

        test('allows loopback http:// hosts', () {
          final repo = VideosRepository(nostrClient: mockNostrClient);
          final emulator = buildVideo(
            id: 'android-emulator-host',
            videoUrl: 'http://10.0.2.2:8000/video.mp4',
          );
          final localhost = buildVideo(
            id: 'localhost-host',
            videoUrl: 'http://localhost:8000/video.mp4',
          );
          final ipv4 = buildVideo(
            id: 'ipv4-loopback',
            videoUrl: 'http://127.0.0.1:8000/video.mp4',
          );

          final result = repo.applyContentPreferences([
            emulator,
            localhost,
            ipv4,
          ]);

          expect(
            result.map((v) => v.id),
            equals([
              'android-emulator-host',
              'localhost-host',
              'ipv4-loopback',
            ]),
          );
        });

        test(
          'rejects hostnames that contain but do not equal a loopback host',
          () {
            final repo = VideosRepository(nostrClient: mockNostrClient);
            final spoofA = buildVideo(
              id: 'spoof-a',
              videoUrl: 'http://10.0.2.2.example.com/video.mp4',
            );
            final spoofB = buildVideo(
              id: 'spoof-b',
              videoUrl: 'http://localhost.evil.com/video.mp4',
            );

            final result = repo.applyContentPreferences([spoofA, spoofB]);

            expect(result, isEmpty);
          },
        );
      });
    });
  });
}

/// Wraps [videos] as a recent-videos page.
///
/// [serverItemCount] defaults to the length of [videos]; pass it explicitly to
/// model the server returning rows the client then dropped as malformed.
RecentVideosResponse _recentPage(
  List<VideoStats> videos, {
  int? serverItemCount,
  bool? hasMore,
  String? nextCursor,
}) => RecentVideosResponse(
  videos: videos,
  serverItemCount: serverItemCount ?? videos.length,
  hasMore: hasMore,
  nextCursor: nextCursor,
);

/// Creates a mock video event for testing.
Event _createVideoEvent({
  required String id,
  required String pubkey,
  required String? videoUrl,
  required int createdAt,
  int? loops,
  List<String>? hashtags,
  List<List<String>>? extraTags,
  bool hasContentWarning = false,
  String content = '',
}) {
  final tags = <List<String>>[
    if (videoUrl != null) ['url', videoUrl],
    if (loops != null) ['loops', loops.toString()],
    ['d', id], // Required for addressable events
    if (hashtags != null)
      for (final tag in hashtags) ['t', tag],
    ...?extraTags,
    if (hasContentWarning) ['content-warning', 'adult content'],
  ];

  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': EventKind.videoVertical,
    'tags': tags,
    'content': content,
    'sig': '',
  });
}

/// Creates a mock video event with a custom d-tag for testing.
Event _createVideoEventWithDTag({
  required String id,
  required String pubkey,
  required String dTag,
  required String? videoUrl,
  required int createdAt,
  int? loops,
  List<String>? hashtags,
  bool hasContentWarning = false,
}) {
  final tags = <List<String>>[
    if (videoUrl != null) ['url', videoUrl],
    if (loops != null) ['loops', loops.toString()],
    ['d', dTag], // Custom d-tag
    if (hashtags != null)
      for (final tag in hashtags) ['t', tag],
    if (hasContentWarning) ['content-warning', 'adult content'],
  ];

  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': EventKind.videoVertical,
    'tags': tags,
    'content': '',
    'sig': '',
  });
}

/// Creates a mock VideoStats for testing Funnelcake API fallback.
VideoStats _createVideoStats({
  required String id,
  required String pubkey,
  required String dTag,
  required String videoUrl,
  int createdAt = 1704067200,
  int? publishedAt,
  String title = 'Test Video',
  String thumbnail = 'https://example.com/thumb.jpg',
  int? loops,
  int? views,
  int reactions = 0,
  int comments = 0,
  int reposts = 0,
  Map<String, String> rawTags = const {},
  List<String> moderationLabels = const [],
  List<String> collaboratorPubkeys = const [],
}) {
  return VideoStats(
    id: id,
    pubkey: pubkey,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    kind: EventKind.videoVertical,
    publishedAt: publishedAt,
    dTag: dTag,
    title: title,
    thumbnail: thumbnail,
    videoUrl: videoUrl,
    reactions: reactions,
    comments: comments,
    reposts: reposts,
    engagementScore: 0,
    loops: loops,
    views: views,
    rawTags: rawTags,
    moderationLabels: moderationLabels,
    collaboratorPubkeys: collaboratorPubkeys,
  );
}

class _VideoStatsWithWarnLabels extends VideoStats {
  _VideoStatsWithWarnLabels({required this.base, required this.warnLabels})
    : super(
        id: base.id,
        pubkey: base.pubkey,
        createdAt: base.createdAt,
        dTag: base.dTag,
        title: base.title,
        description: base.description,
        thumbnail: base.thumbnail,
        videoUrl: base.videoUrl,
        kind: base.kind,
        publishedAt: base.publishedAt,
        sha256: base.sha256,
        authorName: base.authorName,
        authorAvatar: base.authorAvatar,
        blurhash: base.blurhash,
        dimensions: base.dimensions,
        reactions: base.reactions,
        comments: base.comments,
        reposts: base.reposts,
        engagementScore: base.engagementScore,
        trendingScore: base.trendingScore,
        loops: base.loops,
        views: base.views,
        rawTags: base.rawTags,
        textTrackRef: base.textTrackRef,
        textTrackContent: base.textTrackContent,
        moderationLabels: base.moderationLabels,
      );

  final VideoStats base;
  final List<String> warnLabels;

  @override
  VideoEvent toVideoEvent() =>
      base.toVideoEvent().copyWith(warnLabels: warnLabels);
}
