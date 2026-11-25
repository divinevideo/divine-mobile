// ABOUTME: Covers hashtag pagination retry and cursor ownership on refresh.
// ABOUTME: Exercises the same paging state used by the grid and reel.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/hashtag_feed/hashtag_feed_cubit.dart';
import 'package:videos_repository/videos_repository.dart';

VideoEvent _video(String id) => VideoEvent(
  id: id,
  pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  content: '',
  createdAt: 100,
  timestamp: DateTime.fromMillisecondsSinceEpoch(100000),
  videoUrl: 'https://example.com/$id.mp4',
);

void main() {
  group(HashtagFeedCubit, () {
    test('keeps the cursor and loaded videos when a request fails', () async {
      final first = _video('first');
      final next = _video('next');
      var unavailable = true;
      final cubit = HashtagFeedCubit(
        fetchPage: (cursor) async => switch (cursor) {
          null => HashtagFeedVideosResult.success([first], nextCursor: 'o:50'),
          'o:50' when unavailable => const HashtagFeedVideosResult.failure(),
          'o:50' => HashtagFeedVideosResult.success([first, next]),
          _ => throw StateError('Unexpected cursor $cursor'),
        },
        filterVideos: (videos) => videos,
      );
      addTearDown(cubit.close);

      await cubit.refresh();
      await cubit.loadMore();

      expect(cubit.state.videos, [first]);
      expect(cubit.state.nextCursor, 'o:50');
      expect(cubit.state.isLoading, isFalse);

      unavailable = false;
      await cubit.loadMore();

      expect(cubit.state.videos, [first, next]);
      expect(cubit.state.nextCursor, isNull);
    });

    test(
      'appends the next page after a relay video already in the reel',
      () async {
        final first = _video('ranked-first');
        final relay = _video('relay-only');
        final next = _video('ranked-next');
        final cubit = HashtagFeedCubit(
          fetchPage: (cursor) async => cursor == null
              ? HashtagFeedVideosResult.success([first], nextCursor: 'o:50')
              : HashtagFeedVideosResult.success([next]),
          filterVideos: (videos) => videos,
        );
        addTearDown(cubit.close);
        await cubit.refresh();

        final snapshots = StreamIterator(
          cubit.watchPlaybackVideos(
            initialVideos: [first, relay],
            visibleVideos: (ranked) => [...ranked, relay],
          ),
        );
        addTearDown(snapshots.cancel);
        expect(await snapshots.moveNext(), isTrue);
        expect(snapshots.current, [first, relay]);

        final updated = snapshots.moveNext();
        await cubit.loadMore();
        expect(await updated, isTrue);
        expect(snapshots.current, [first, relay, next]);
      },
    );

    test('ignores an older page that arrives after a refresh', () async {
      final first = _video('first');
      final refreshed = _video('refreshed');
      final stalePage = Completer<HashtagFeedVideosResult>();
      var refreshedFirstPage = false;
      final cubit = HashtagFeedCubit(
        fetchPage: (cursor) async => switch (cursor) {
          null when refreshedFirstPage => HashtagFeedVideosResult.success([
            refreshed,
          ], nextCursor: 'o:80'),
          null => HashtagFeedVideosResult.success([first], nextCursor: 'o:50'),
          'o:50' => stalePage.future,
          _ => throw StateError('Unexpected cursor $cursor'),
        },
        filterVideos: (videos) => videos,
      );
      addTearDown(cubit.close);

      await cubit.refresh();
      final pending = cubit.loadMore();
      expect(cubit.state.isLoading, isTrue);

      refreshedFirstPage = true;
      await cubit.refresh();
      stalePage.complete(HashtagFeedVideosResult.success([_video('stale')]));
      await pending;

      expect(cubit.state.videos, [refreshed]);
      expect(cubit.state.nextCursor, 'o:80');
      expect(cubit.state.isLoading, isFalse);
    });

    group('loadMore', () {
      final first = _video('first');

      blocTest<HashtagFeedCubit, HashtagFeedState>(
        'reports an error thrown while loading a page and keeps the cursor',
        build: () => HashtagFeedCubit(
          fetchPage: (cursor) async => cursor == null
              ? HashtagFeedVideosResult.success([first], nextCursor: 'o:50')
              : throw StateError('malformed page'),
          filterVideos: (videos) => videos,
        ),
        act: (cubit) async {
          await cubit.refresh();
          await cubit.loadMore();
        },
        errors: () => [isA<StateError>()],
        verify: (cubit) {
          expect(cubit.state.videos, [first]);
          expect(cubit.state.nextCursor, 'o:50');
          expect(cubit.state.failed, isTrue);
          expect(cubit.state.isLoading, isFalse);
        },
      );

      test('completes normally when a page throws', () async {
        final cubit = HashtagFeedCubit(
          fetchPage: (cursor) async => cursor == null
              ? HashtagFeedVideosResult.success([first], nextCursor: 'o:50')
              : throw StateError('malformed page'),
          filterVideos: (videos) => videos,
        );
        addTearDown(cubit.close);
        await cubit.refresh();

        await expectLater(cubit.loadMore(), completes);
      });

      test('follows the cursor past a page whose videos are hidden', () async {
        final fetches = <String?>[];
        final hidden = _video('hidden');
        final visible = _video('visible');
        final cubit = HashtagFeedCubit(
          fetchPage: (cursor) async {
            fetches.add(cursor);
            return switch (cursor) {
              null => HashtagFeedVideosResult.success([
                first,
              ], nextCursor: 'o:50'),
              'o:50' => HashtagFeedVideosResult.success([
                hidden,
              ], nextCursor: 'o:100'),
              _ => HashtagFeedVideosResult.success([visible]),
            };
          },
          filterVideos: (videos) => [
            for (final video in videos)
              if (video.id != 'hidden') video,
          ],
        );
        addTearDown(cubit.close);
        await cubit.refresh();

        await cubit.loadMore();

        expect(fetches, [null, 'o:50', 'o:100']);
        expect(cubit.state.videos, [first, hidden, visible]);
      });

      test('stops after three pages that add nothing new', () async {
        final fetches = <String?>[];
        final cubit = HashtagFeedCubit(
          fetchPage: (cursor) async {
            fetches.add(cursor);
            return HashtagFeedVideosResult.success([
              first,
            ], nextCursor: 'o:${fetches.length}');
          },
          filterVideos: (videos) => videos,
        );
        addTearDown(cubit.close);
        await cubit.refresh();

        await cubit.loadMore();

        expect(fetches, [null, 'o:1', 'o:2', 'o:3']);
        expect(cubit.state.nextCursor, 'o:4');
      });

      test('ends paging when the server repeats a cursor', () async {
        final fetches = <String?>[];
        final cubit = HashtagFeedCubit(
          fetchPage: (cursor) async {
            fetches.add(cursor);
            return HashtagFeedVideosResult.success([
              first,
            ], nextCursor: 'o:50');
          },
          filterVideos: (videos) => videos,
        );
        addTearDown(cubit.close);
        await cubit.refresh();

        await cubit.loadMore();

        expect(fetches, [null, 'o:50']);
        expect(cubit.state.nextCursor, isNull);
      });

      test('ignores loadMore while a page is already loading', () async {
        final fetches = <String?>[];
        final pending = Completer<HashtagFeedVideosResult>();
        final next = _video('next');
        final cubit = HashtagFeedCubit(
          fetchPage: (cursor) {
            fetches.add(cursor);
            return cursor == null
                ? Future.value(
                    HashtagFeedVideosResult.success([
                      first,
                    ], nextCursor: 'o:50'),
                  )
                : pending.future;
          },
          filterVideos: (videos) => videos,
        );
        addTearDown(cubit.close);
        await cubit.refresh();
        final loading = cubit.loadMore();
        final ignored = cubit.loadMore();

        pending.complete(HashtagFeedVideosResult.success([next]));
        await Future.wait([loading, ignored]);

        expect(fetches, [null, 'o:50']);
        expect(cubit.state.videos, [first, next]);
      });

      test('drops a page that lands after the cubit closes', () async {
        final fetches = <String?>[];
        final pending = Completer<HashtagFeedVideosResult>();
        final cubit = HashtagFeedCubit(
          fetchPage: (cursor) {
            fetches.add(cursor);
            return switch (cursor) {
              null => Future.value(
                HashtagFeedVideosResult.success([first], nextCursor: 'o:50'),
              ),
              'o:50' => pending.future,
              _ => Future.value(
                HashtagFeedVideosResult.success([_video('late')]),
              ),
            };
          },
          filterVideos: (videos) => videos,
        );
        await cubit.refresh();
        final loading = cubit.loadMore();

        await cubit.close();
        pending.complete(
          HashtagFeedVideosResult.success([first], nextCursor: 'o:100'),
        );

        await expectLater(loading, completes);
        expect(fetches, [null, 'o:50']);
      });
    });

    group('watchPlaybackVideos', () {
      Future<(HashtagFeedCubit, StreamIterator<List<VideoEvent>>)> twoPages({
        required Set<String> hidden,
      }) async {
        List<VideoEvent> visible(List<VideoEvent> videos) => [
          for (final video in videos)
            if (!hidden.contains(video.id)) video,
        ];
        final cubit = HashtagFeedCubit(
          fetchPage: (cursor) async => cursor == null
              ? HashtagFeedVideosResult.success([
                  _video('first'),
                ], nextCursor: 'o:50')
              : HashtagFeedVideosResult.success([_video('next')]),
          filterVideos: visible,
        );
        addTearDown(cubit.close);
        await cubit.refresh();
        final snapshots = StreamIterator(
          cubit.watchPlaybackVideos(
            initialVideos: visible(cubit.state.videos),
            visibleVideos: visible,
          ),
        );
        addTearDown(snapshots.cancel);
        expect(await snapshots.moveNext(), isTrue);
        final loaded = snapshots.moveNext();
        await cubit.loadMore();
        expect(await loaded, isTrue);
        expect(snapshots.current.map((video) => video.id), ['first', 'next']);
        return (cubit, snapshots);
      }

      test('keeps later pages in the reel when the feed refreshes', () async {
        final (cubit, snapshots) = await twoPages(hidden: {});

        final refreshed = snapshots.moveNext();
        await cubit.refresh();
        expect(await refreshed, isTrue);

        expect(snapshots.current.map((video) => video.id), ['first', 'next']);
      });

      test('drops a reel video the filters now hide', () async {
        final hidden = <String>{};
        final (cubit, snapshots) = await twoPages(hidden: hidden);

        hidden.add('next');
        final refreshed = snapshots.moveNext();
        await cubit.refresh();
        expect(await refreshed, isTrue);

        expect(snapshots.current.map((video) => video.id), ['first']);
      });
    });
  });
}
