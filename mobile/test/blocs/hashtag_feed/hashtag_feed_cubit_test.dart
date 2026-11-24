// ABOUTME: Covers hashtag pagination retry and cursor ownership on refresh.
// ABOUTME: Exercises the same paging state used by the grid and reel.

import 'dart:async';

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
  });
}
