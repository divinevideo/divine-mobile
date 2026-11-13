import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/new_videos_feed_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group(NewVideosFeed, () {
    late _MockVideosRepository videosRepository;
    late _MockVideoEventService videoEventService;
    late _MockContentBlocklistRepository blocklistRepository;

    setUp(() {
      videosRepository = _MockVideosRepository();
      videoEventService = _MockVideoEventService();
      blocklistRepository = _MockContentBlocklistRepository();

      when(() => videoEventService.filterVideoList(any())).thenAnswer(
        (invocation) =>
            List<VideoEvent>.from(invocation.positionalArguments.first as List),
      );
      when(
        () => blocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
    });

    ProviderContainer createContainer({bool overrideAppReady = true}) {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(),
          if (overrideAppReady) appReadyProvider.overrideWithValue(true),
          videosRepositoryProvider.overrideWithValue(videosRepository),
          videoEventServiceProvider.overrideWithValue(videoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            blocklistRepository,
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    /// Stubs the first page (`until` null) and every page after it.
    void stubPages({
      required HomeFeedResult first,
      HomeFeedResult? subsequent,
    }) {
      when(
        () => videosRepository.getNewVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until', that: isNull),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer((_) async => first);
      when(
        () => videosRepository.getNewVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until', that: isNotNull),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer((_) async => subsequent ?? const HomeFeedResult(videos: []));
    }

    group('creator limit', () {
      test(
        'keeps only the first two videos per creator in source order',
        () async {
          final videos = _videos(5);
          final repeated = [
            videos[0],
            videos[1],
            videos[2].copyWith(pubkey: videos[0].pubkey),
            videos[3].copyWith(pubkey: videos[0].pubkey),
            videos[4],
          ];
          stubPages(first: HomeFeedResult(videos: repeated, hasMore: true));

          final state = await createContainer().read(
            newVideosFeedProvider.future,
          );

          expect(state.videos, [
            repeated[0],
            repeated[1],
            repeated[2],
            repeated[4],
          ]);
          expect(state.hasMoreContent, isTrue);
        },
      );

      test(
        'skips capped pages and advances the raw timestamp cursor',
        () async {
          final videos = _videos(6);
          final author = videos.first.pubkey;
          final first = [videos[0], videos[1].copyWith(pubkey: author)];
          final hidden = [
            videos[2].copyWith(pubkey: author),
            videos[3].copyWith(pubkey: author),
          ];
          when(
            () => videosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((call) async {
            final until = call.namedArguments[#until];
            if (until == null) {
              return HomeFeedResult(videos: first, hasMore: true);
            }
            if (until == first.last.createdAt) {
              return HomeFeedResult(videos: hidden, hasMore: true);
            }
            if (until == hidden.last.createdAt) {
              return HomeFeedResult(videos: [videos[4]], hasMore: false);
            }
            throw StateError('Unexpected pagination timestamp');
          });
          final container = createContainer();
          await container.read(newVideosFeedProvider.future);

          await container.read(newVideosFeedProvider.notifier).loadMore();

          final state = container.read(newVideosFeedProvider).requireValue;
          expect(state.videos, [...first, videos[4]]);
          expect(state.hasMoreContent, isFalse);
        },
      );

      test('refresh starts a fresh creator allowance', () async {
        final first = _videos(
          3,
          idPrefix: 'old',
        ).map((v) => v.copyWith(pubkey: '1' * 64)).toList();
        final fresh = _videos(
          3,
          idPrefix: 'fresh',
        ).map((v) => v.copyWith(pubkey: '1' * 64)).toList();
        when(
          () => videosRepository.getNewVideos(
            limit: any(named: 'limit'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer(
          (call) async => HomeFeedResult(
            videos: call.namedArguments[#skipCache] == true ? fresh : first,
            hasMore: false,
          ),
        );
        final container = createContainer();
        await container.read(newVideosFeedProvider.future);

        await container.read(newVideosFeedProvider.notifier).refresh();

        expect(
          container.read(newVideosFeedProvider).requireValue.videos,
          fresh.take(2),
        );
      });
    });

    for (final repeatsCursor in [false, true]) {
      test(
        'capped opaque pages keep advancing: repeated cursor $repeatsCursor',
        () async {
          final videos = _videos(4);
          final author = videos.first.pubkey;
          final first = [videos[0], videos[1].copyWith(pubkey: author)];
          var secondPageRequests = 0;
          when(
            () => videosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              cursor: any(named: 'cursor'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((call) async {
            final cursor = call.namedArguments[#cursor];
            // A walk that never stops would starve the test's timers and hang
            // it, so fail on the first repeated request instead.
            if (cursor == 'page-2' && secondPageRequests++ > 0) {
              throw StateError('page-2 requested twice');
            }
            return switch (cursor) {
              null => HomeFeedResult(
                videos: first,
                hasMore: true,
                paginationCursor: 'page-2',
              ),
              'page-2' => HomeFeedResult(
                videos: [videos[2].copyWith(pubkey: author)],
                hasMore: true,
                paginationCursor: repeatsCursor ? 'page-2' : 'page-3',
              ),
              'page-3' => HomeFeedResult(videos: [videos[3]], hasMore: false),
              _ => throw StateError('Unexpected cursor'),
            };
          });
          final container = createContainer();
          await container.read(newVideosFeedProvider.future);

          await container.read(newVideosFeedProvider.notifier).loadMore();

          final state = container.read(newVideosFeedProvider).requireValue;
          expect(state.videos, repeatsCursor ? first : [...first, videos[3]]);
          expect(state.hasMoreContent, isFalse);
          expect(state.isLoadingMore, isFalse);
          expect(secondPageRequests, equals(1));
        },
      );
    }

    test(
      'loadMore stops after maxSeenOnlyFeedPages empty cursor pages',
      () async {
        final first = _videos(1);
        var loadMoreCalls = 0;
        when(
          () => videosRepository.getNewVideos(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((call) async {
          final cursor = call.namedArguments[#cursor] as String?;
          if (cursor == null) {
            return HomeFeedResult(
              videos: first,
              hasMore: true,
              paginationCursor: 'page-1',
            );
          }
          loadMoreCalls++;
          return HomeFeedResult(
            videos: const [],
            hasMore: true,
            paginationCursor: 'page-${loadMoreCalls + 1}',
          );
        });
        final container = createContainer();
        await container.read(newVideosFeedProvider.future);

        await container.read(newVideosFeedProvider.notifier).loadMore();

        final state = container.read(newVideosFeedProvider).requireValue;
        expect(loadMoreCalls, equals(maxSeenOnlyFeedPages));
        expect(state.videos, equals(first));
        expect(state.hasMoreContent, isFalse);
        expect(state.isLoadingMore, isFalse);
      },
    );

    group('build', () {
      test(
        'keeps the cursor when the first page has no visible rows',
        () async {
          stubPages(
            first: const HomeFeedResult(
              videos: [],
              hasMore: true,
              paginationCursor: 'p:next-visible',
            ),
          );
          when(
            () => videosRepository.getNewVideos(
              limit: any(named: 'limit'),
              cursor: 'p:next-visible',
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(videos: _videos(1), hasMore: false),
          );
          final container = createContainer();
          final first = await container.read(newVideosFeedProvider.future);
          expect(first.videos, isEmpty);
          expect(first.hasMoreContent, isTrue);

          await container.read(newVideosFeedProvider.notifier).loadMore();

          expect(
            container.read(newVideosFeedProvider).requireValue.videos,
            hasLength(1),
          );
        },
      );

      // The regression: the home feed warms the shared cache with 25 videos,
      // this feed asks for 50 and gets that cached page back. Inferring
      // "no more content" from the short count killed pagination for the
      // rest of the session.
      test(
        'reports more content behind a page shorter than its page size',
        () async {
          stubPages(first: HomeFeedResult(videos: _videos(2), hasMore: true));

          final state = await createContainer().read(
            newVideosFeedProvider.future,
          );

          expect(state.videos, hasLength(2));
          expect(state.hasMoreContent, isTrue);
        },
      );

      test(
        'stops paginating when the repository reports no more content',
        () async {
          stubPages(
            first: HomeFeedResult(
              videos: _videos(AppConstants.paginationBatchSize),
              hasMore: false,
            ),
          );

          final state = await createContainer().read(
            newVideosFeedProvider.future,
          );

          expect(state.hasMoreContent, isFalse);
        },
      );

      test('re-filters existing videos when appReady is false', () async {
        var hideSecondVideo = false;
        when(() => videoEventService.filterVideoList(any())).thenAnswer((
          invocation,
        ) {
          final videos = List<VideoEvent>.from(
            invocation.positionalArguments.first as List,
          );
          return hideSecondVideo
              ? videos.where((video) => video.id != 'new-1').toList()
              : videos;
        });
        stubPages(first: HomeFeedResult(videos: _videos(2), hasMore: true));
        final container = createContainer(overrideAppReady: false);

        final initial = await container.read(newVideosFeedProvider.future);
        expect(initial.videos.map((v) => v.id), ['new-0', 'new-1']);

        hideSecondVideo = true;
        container.read(appForegroundProvider.notifier).setForeground(false);
        await container.read(newVideosFeedProvider.future);

        final backgrounded = container.read(newVideosFeedProvider).requireValue;
        expect(backgrounded.videos.map((v) => v.id), ['new-0']);
        verify(
          () => videosRepository.getNewVideos(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
          ),
        ).called(1);
      });
    });

    group('loadMore', () {
      test('ends on an until page that brings no older row', () async {
        final author = _videos(1).single.pubkey;
        final first = [
          for (final video in _videos(3)) video.copyWith(pubkey: author),
        ];
        final sameSecond = _videos(1, idPrefix: 'same').single.copyWith(
          pubkey: author,
          createdAt: first.last.createdAt,
        );
        var untilRequests = 0;
        when(
          () => videosRepository.getNewVideos(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((call) async {
          final until = call.namedArguments[#until] as int?;
          if (until == null) {
            return HomeFeedResult(videos: first, hasMore: true);
          }
          if (until == first.last.createdAt && untilRequests++ == 0) {
            return HomeFeedResult(videos: [sameSecond], hasMore: true);
          }
          throw StateError('Unexpected request until $until');
        });
        final container = createContainer();
        await container.read(newVideosFeedProvider.future);

        await container.read(newVideosFeedProvider.notifier).loadMore();

        final state = container.read(newVideosFeedProvider).requireValue;
        expect(untilRequests, equals(1));
        expect(state.videos, first.take(2));
        expect(state.hasMoreContent, isFalse);
      });

      test('ignores a late page from before refresh', () async {
        final oldPage = Completer<HomeFeedResult>();
        final oldPageStarted = Completer<void>();
        when(
          () => videosRepository.getNewVideos(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((call) async {
          if (call.namedArguments[#skipCache] == true) {
            return HomeFeedResult(
              videos: _videos(1, idPrefix: 'fresh'),
              hasMore: true,
              paginationCursor: 'p:fresh',
            );
          }
          if (call.namedArguments[#cursor] == 'p:old') {
            oldPageStarted.complete();
            return oldPage.future;
          }
          if (call.namedArguments[#cursor] == 'p:fresh') {
            return HomeFeedResult(
              videos: _videos(1, idPrefix: 'more'),
              hasMore: false,
            );
          }
          return HomeFeedResult(
            videos: _videos(1),
            hasMore: true,
            paginationCursor: 'p:old',
          );
        });
        final container = createContainer();
        await container.read(newVideosFeedProvider.future);
        final notifier = container.read(newVideosFeedProvider.notifier);
        final pending = notifier.loadMore();
        await oldPageStarted.future;
        await notifier.refresh();
        oldPage.complete(
          HomeFeedResult(videos: _videos(1, idPrefix: 'stale'), hasMore: false),
        );
        await pending;

        expect(
          container
              .read(newVideosFeedProvider)
              .requireValue
              .videos
              .map((v) => v.id),
          ['fresh-0'],
        );
        await notifier.loadMore();
        expect(
          container
              .read(newVideosFeedProvider)
              .requireValue
              .videos
              .map((v) => v.id),
          ['fresh-0', 'more-0'],
        );
      });

      test(
        'refresh replaces the old source cursor before loading more',
        () async {
          final requestedCursors = <String?>[];
          when(
            () => videosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              cursor: any(named: 'cursor'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((call) async {
            final cursor = call.namedArguments[#cursor] as String?;
            requestedCursors.add(cursor);
            if (call.namedArguments[#skipCache] == true) {
              return HomeFeedResult(
                videos: _videos(1, idPrefix: 'fresh'),
                hasMore: true,
                paginationCursor: 'p:fresh',
              );
            }
            if (cursor == 'p:fresh') {
              return HomeFeedResult(
                videos: _videos(1, idPrefix: 'more'),
                hasMore: false,
              );
            }
            return HomeFeedResult(
              videos: _videos(1),
              hasMore: true,
              paginationCursor: 'relay:1000',
            );
          });
          final container = createContainer();
          await container.read(newVideosFeedProvider.future);
          final notifier = container.read(newVideosFeedProvider.notifier);

          await notifier.refresh();
          await notifier.loadMore();

          expect(requestedCursors, [null, null, 'p:fresh']);
          expect(
            container
                .read(newVideosFeedProvider)
                .requireValue
                .videos
                .map((v) => v.id),
            ['fresh-0', 'more-0'],
          );
        },
      );

      test(
        'advances an empty cursor page and retries failures in place',
        () async {
          final requestedCursors = <String?>[];
          var attempts = 0;
          when(
            () => videosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              cursor: any(named: 'cursor'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((invocation) async {
            final cursor = invocation.namedArguments[#cursor] as String?;
            requestedCursors.add(cursor);
            if (cursor == null) {
              return HomeFeedResult(
                videos: _videos(1),
                hasMore: true,
                paginationCursor: 'p:second',
              );
            }
            if (cursor == 'p:second') {
              return const HomeFeedResult(
                videos: [],
                hasMore: true,
                paginationCursor: 'p:third',
              );
            }
            if (attempts++ == 0) throw Exception('Temporary network failure');
            return HomeFeedResult(
              videos: _videos(1, idPrefix: 'more'),
              hasMore: false,
            );
          });
          final container = createContainer();
          await container.read(newVideosFeedProvider.future);
          final notifier = container.read(newVideosFeedProvider.notifier);

          await notifier.loadMore();
          final failed = container.read(newVideosFeedProvider).requireValue;
          expect(failed.hasMoreContent, isTrue);
          expect(failed.isLoadingMore, isFalse);
          expect(failed.videos, hasLength(1));
          await notifier.loadMore();

          expect(requestedCursors, [null, 'p:second', 'p:third', 'p:third']);
          final recovered = container.read(newVideosFeedProvider).requireValue;
          expect(recovered.videos.map((v) => v.id), ['new-0', 'more-0']);
          expect(recovered.hasMoreContent, isFalse);
          expect(recovered.error, isNull);
        },
      );

      test('keeps equal-publication rows across opaque cursor pages', () async {
        const cursor =
            'p:1767225600:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final first = _videos(1);
        final boundary = _videos(1, idPrefix: 'boundary');
        when(
          () => videosRepository.getNewVideos(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((invocation) async {
          if (invocation.namedArguments[#cursor] == cursor) {
            return HomeFeedResult(videos: boundary, hasMore: false);
          }
          if (invocation.namedArguments[#until] != null) {
            return const HomeFeedResult(videos: [], hasMore: false);
          }
          return HomeFeedResult(
            videos: first,
            hasMore: true,
            paginationCursor: cursor,
          );
        });
        final container = createContainer();
        final initial = await container.read(newVideosFeedProvider.future);
        expect(initial.videos.map((video) => video.id), ['new-0']);

        await container.read(newVideosFeedProvider.notifier).loadMore();

        final page = container.read(newVideosFeedProvider).requireValue;
        expect(page.videos.map((video) => video.id), ['new-0', 'boundary-0']);
        expect(page.hasMoreContent, isFalse);
      });

      test(
        'keeps paginating on the flag rather than the returned count',
        () async {
          stubPages(
            first: HomeFeedResult(videos: _videos(2), hasMore: true),
            subsequent: HomeFeedResult(
              videos: _videos(2, idPrefix: 'more'),
              hasMore: true,
            ),
          );
          final container = createContainer();
          await container.read(newVideosFeedProvider.future);

          await container.read(newVideosFeedProvider.notifier).loadMore();

          final state = container.read(newVideosFeedProvider).requireValue;
          expect(state.videos, hasLength(4));
          expect(state.hasMoreContent, isTrue);
        },
      );

      test('stops when the repository reports the source ran dry', () async {
        stubPages(
          first: HomeFeedResult(videos: _videos(2), hasMore: true),
          subsequent: HomeFeedResult(
            videos: _videos(2, idPrefix: 'more'),
            hasMore: false,
          ),
        );
        final container = createContainer();
        await container.read(newVideosFeedProvider.future);

        await container.read(newVideosFeedProvider.notifier).loadMore();

        expect(
          container.read(newVideosFeedProvider).requireValue.hasMoreContent,
          isFalse,
        );
      });
    });
  });
}

List<VideoEvent> _videos(int count, {String idPrefix = 'new'}) => [
  for (var i = 0; i < count; i++)
    VideoEvent(
      id: '$idPrefix-$i',
      pubkey: (i + 1).toRadixString(16).padLeft(64, '0'),
      createdAt: DateTime(2026, 1, count - i).millisecondsSinceEpoch ~/ 1000,
      content: 'Test video',
      timestamp: DateTime(2026, 1, count - i),
      videoUrl: 'https://example.com/$idPrefix-$i.mp4',
      thumbnailUrl: 'https://example.com/$idPrefix-$i.jpg',
    ),
];
