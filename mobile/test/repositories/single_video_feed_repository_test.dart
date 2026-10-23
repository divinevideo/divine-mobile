import 'dart:async';

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/repositories/single_video_feed_repository.dart';
import 'package:videos_repository/videos_repository.dart';

VideoEvent _video(String id, {int createdAt = 1000, String? dTag}) =>
    VideoEvent(
      id: id,
      pubkey: 'a' * 64,
      createdAt: createdAt,
      content: '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      videoUrl: 'https://media.divine.video/$id.mp4',
      addressableDTag: dTag,
    );

void main() {
  final anchor = _video('anchor', createdAt: 1, dTag: 'original');
  final source = SingleVideoViewSource(anchor);

  group('SingleVideoFeedRepository', () {
    test(
      'plays the anchor before recommendations complete, then appends',
      () async {
        final page = Completer<HomeFeedResult>();
        final repository = SingleVideoFeedRepository(
          video: anchor,
          loadPage: ({cursor, until}) => page.future,
        );
        addTearDown(repository.dispose);
        final videos = StreamIterator(repository.watchView(source));
        addTearDown(videos.cancel);
        expect(await videos.moveNext(), isTrue);
        expect(videos.current, [anchor]);
        page.complete(HomeFeedResult(videos: [_video('next')], hasMore: false));
        expect(await videos.moveNext(), isTrue);
        expect(videos.current.map((v) => v.id), ['anchor', 'next']);
        await expectLater(repository.watchHasMore(source), emits(false));
      },
    );

    test(
      'deduplicates logical videos and keeps page order with opaque cursors',
      () async {
        final calls = <String?>[];
        final repository = SingleVideoFeedRepository(
          video: anchor,
          loadPage: ({cursor, until}) async {
            calls.add(cursor);
            expect(until, isNull);
            return cursor == null
                ? HomeFeedResult(
                    videos: [
                      _video('revision', dTag: 'original'),
                      _video('b'),
                      _video('b'),
                    ],
                    hasMore: true,
                    paginationCursor: 'opaque-next',
                  )
                : HomeFeedResult(
                    videos: [_video('b'), _video('c')],
                    hasMore: false,
                  );
          },
        );
        addTearDown(repository.dispose);
        await repository.loadMore(source);
        await repository.loadMore(source);
        await repository.loadMore(source);
        expect(calls, [null, 'opaque-next']);
        await expectLater(
          repository
              .watchView(source)
              .map((videos) => videos.map((v) => v.id).toList()),
          emits(['anchor', 'b', 'c']),
        );
      },
    );

    test(
      'popular fallback paginates from recommendation age, excluding anchor',
      () async {
        final boundaries = <int?>[];
        final repository = SingleVideoFeedRepository(
          video: anchor,
          loadPage: ({cursor, until}) async {
            expect(cursor, isNull);
            boundaries.add(until);
            return until == null
                ? HomeFeedResult(
                    videos: [
                      _video('b', createdAt: 300),
                      _video('c', createdAt: 200),
                    ],
                  )
                : const HomeFeedResult(videos: []);
          },
        );
        addTearDown(repository.dispose);
        await repository.loadMore(source);
        await repository.loadMore(source);
        expect(boundaries, [null, 200]);
        await expectLater(repository.watchHasMore(source), emits(false));
      },
    );

    test(
      'coalesces concurrent loads and ignores responses after disposal',
      () async {
        final page = Completer<HomeFeedResult>();
        var calls = 0;
        final repository = SingleVideoFeedRepository(
          video: anchor,
          loadPage: ({cursor, until}) {
            calls++;
            return page.future;
          },
        );
        final pending = repository.loadMore(source);
        await repository.loadMore(source);
        expect(calls, 1);
        await repository.dispose();
        page.complete(HomeFeedResult(videos: [_video('late')], hasMore: false));
        await pending;
      },
    );

    test('failure leaves anchor playable and allows a later retry', () async {
      var calls = 0;
      final repository = SingleVideoFeedRepository(
        video: anchor,
        loadPage: ({cursor, until}) async {
          if (calls++ == 0) throw Exception('offline');
          return HomeFeedResult(videos: [_video('next')], hasMore: false);
        },
      );
      addTearDown(repository.dispose);
      await repository.loadMore(source);
      await repository.loadMore(source);
      await expectLater(
        repository
            .watchView(source)
            .map((videos) => videos.map((v) => v.id).toList()),
        emits(['anchor', 'next']),
      );
    });

    test(
      'stops on repeated cursors',
      () async {
        final repository = SingleVideoFeedRepository(
          video: anchor,
          loadPage: ({cursor, until}) async => HomeFeedResult(
            videos: [_video('b')],
            paginationCursor: 'same',
            hasMore: true,
          ),
        );
        addTearDown(repository.dispose);
        await repository.loadMore(source);
        await repository.loadMore(source);
        await expectLater(repository.watchHasMore(source), emits(false));
      },
    );
    test(
      'reapplies filters to recommendations without hiding the overridden anchor',
      () async {
        var hidden = <String>{'blocked'};
        final repository = SingleVideoFeedRepository(
          video: anchor,
          loadPage: ({cursor, until}) async => HomeFeedResult(
            videos: [_video('blocked'), _video('safe')],
            hasMore: false,
          ),
          filter: (videos) =>
              videos.where((v) => !hidden.contains(v.id)).toList(),
        );
        addTearDown(repository.dispose);
        await repository.loadMore(source);
        await expectLater(
          repository
              .watchView(source)
              .map((videos) => videos.map((v) => v.id).toList()),
          emits(['anchor', 'safe']),
        );
        hidden = {'anchor', 'blocked', 'safe'};
        repository.refreshFilters();
        await expectLater(repository.watchView(source), emits([anchor]));
      },
    );

    test(
      'stops timestamp pagination when the fallback repeats the oldest page',
      () async {
        var calls = 0;
        final repository = SingleVideoFeedRepository(
          video: anchor,
          loadPage: ({cursor, until}) async {
            calls++;
            return HomeFeedResult(videos: [_video('b')]);
          },
        );
        addTearDown(repository.dispose);
        await repository.loadMore(source);
        await repository.loadMore(source);
        await repository.loadMore(source);
        expect(calls, 2);
        await expectLater(repository.watchHasMore(source), emits(false));
      },
    );

    test(
      'automatically advances past an anchor-only page without another swipe',
      () async {
        final repository = SingleVideoFeedRepository(
          video: anchor,
          loadPage: ({cursor, until}) async => cursor == null
              ? HomeFeedResult(
                  videos: [anchor],
                  hasMore: true,
                  paginationCursor: 'next',
                )
              : HomeFeedResult(videos: [_video('b')], hasMore: false),
        );
        addTearDown(repository.dispose);
        await repository.loadMore(source);
        await expectLater(repository.watchHasMore(source), emits(false));
        await expectLater(
          repository
              .watchView(source)
              .map((videos) => videos.map((v) => v.id).toList()),
          emits(['anchor', 'b']),
        );
      },
    );
    test(
      'bounds consecutive filtered pages and leaves another request possible',
      () async {
        var calls = 0;
        final repository = SingleVideoFeedRepository(
          video: anchor,
          loadPage: ({cursor, until}) async => HomeFeedResult(
            videos: [_video('hidden-${calls++}')],
            hasMore: true,
            paginationCursor: 'page-$calls',
          ),
          filter: (_) => [],
        );
        addTearDown(repository.dispose);
        await repository.loadMore(source);
        expect(calls, 3);
        await expectLater(repository.watchView(source), emits([anchor]));
        await expectLater(repository.watchHasMore(source), emits(true));
      },
    );

    test('ignores errors from a pending request after disposal', () async {
      final page = Completer<HomeFeedResult>();
      final repository = SingleVideoFeedRepository(
        video: anchor,
        loadPage: ({cursor, until}) => page.future,
      );
      final pending = repository.loadMore(source);
      await repository.dispose();
      page.completeError(StateError('dependency disposed'));
      await expectLater(pending, completes);
    });
  });
}
