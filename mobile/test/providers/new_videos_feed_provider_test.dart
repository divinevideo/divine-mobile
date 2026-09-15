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
          expect(
            container.read(newVideosFeedProvider).requireValue.hasMoreContent,
            isTrue,
          );
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
      pubkey: 'test-pubkey',
      createdAt: DateTime(2026, 1, count - i).millisecondsSinceEpoch ~/ 1000,
      content: 'Test video',
      timestamp: DateTime(2026, 1, count - i),
      videoUrl: 'https://example.com/$idPrefix-$i.mp4',
      thumbnailUrl: 'https://example.com/$idPrefix-$i.jpg',
    ),
];
