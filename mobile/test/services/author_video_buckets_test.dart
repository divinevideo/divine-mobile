// ABOUTME: Tests per-author video bucket memoization and invalidation.
// ABOUTME: Guards profile feed reads against repeated sort/allocation churn.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/author_video_buckets.dart';

const _authorA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _authorB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

VideoEvent _video(
  String id, {
  required String pubkey,
  required int createdAt,
  int? eventCreatedAt,
  String? vineId,
  int? nostrLikeCount,
}) => VideoEvent(
  id: id,
  pubkey: pubkey,
  createdAt: createdAt,
  eventCreatedAt: eventCreatedAt,
  content: 'content $id',
  timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
  title: 'Video $id',
  videoUrl: 'https://example.com/$id.mp4',
  vineId: vineId ?? id,
  nostrLikeCount: nostrLikeCount,
);

void main() {
  group('AuthorVideoBuckets', () {
    test('memoizes a sorted immutable view until the bucket changes', () {
      final buckets = AuthorVideoBuckets()
        ..seed(_authorA, [
          _video('old', pubkey: _authorA, createdAt: 100),
          _video('newer-b', pubkey: _authorA, createdAt: 200),
          _video('newer-a', pubkey: _authorA, createdAt: 200),
        ]);

      final first = buckets.videosFor(_authorA);
      final second = buckets.videosFor(_authorA);

      expect(identical(first, second), isTrue);
      expect(first.map((video) => video.id), ['newer-b', 'newer-a', 'old']);
      expect(
        () => first.add(_video('x', pubkey: _authorA, createdAt: 300)),
        throwsUnsupportedError,
      );
    });

    test('changing another author does not invalidate this author', () {
      final buckets = AuthorVideoBuckets()
        ..seed(_authorA, [_video('a', pubkey: _authorA, createdAt: 100)]);
      final before = buckets.videosFor(_authorA);

      buckets.addOrUpdateByVine(
        _video('b', pubkey: _authorB, createdAt: 200),
        authorPubkey: _authorB,
        isHistorical: false,
      );

      expect(identical(buckets.videosFor(_authorA), before), isTrue);
    });

    test('add, replace, stable update, and removal invalidate the author', () {
      final buckets = AuthorVideoBuckets()
        ..seed(_authorA, [_video('a', pubkey: _authorA, createdAt: 100)]);

      final initial = buckets.videosFor(_authorA);
      buckets.addOrUpdateByVine(
        _video('b', pubkey: _authorA, createdAt: 200),
        authorPubkey: _authorA,
        isHistorical: false,
      );
      final afterAdd = buckets.videosFor(_authorA);
      expect(identical(afterAdd, initial), isFalse);
      expect(afterAdd.map((video) => video.id), ['b', 'a']);

      buckets.replaceById(
        _authorA,
        'a',
        _video('a', pubkey: _authorA, createdAt: 100, nostrLikeCount: 7),
      );
      final afterReplace = buckets.videosFor(_authorA);
      expect(identical(afterReplace, afterAdd), isFalse);
      expect(afterReplace.last.nostrLikeCount, 7);

      buckets.replaceByStableId(
        _authorA,
        _video('a-new-id', pubkey: _authorA, createdAt: 300, vineId: 'a'),
        merge: (_, updated) => updated,
      );
      final afterStableUpdate = buckets.videosFor(_authorA);
      expect(identical(afterStableUpdate, afterReplace), isFalse);
      expect(afterStableUpdate.map((video) => video.id), ['a-new-id', 'b']);

      buckets.removeWhere((video) => video.id == 'b');
      final afterRemove = buckets.videosFor(_authorA);
      expect(identical(afterRemove, afterStableUpdate), isFalse);
      expect(afterRemove.map((video) => video.id), ['a-new-id']);
    });

    group('addOrUpdateByVine', () {
      // An edit re-emits the original published_at, which createdAt prefers,
      // so only the signed created_at orders the revisions.
      VideoEvent original() => _video(
        'original',
        pubkey: _authorA,
        createdAt: 100,
        eventCreatedAt: 100,
        vineId: 'clip',
      );
      VideoEvent edited() => _video(
        'edited',
        pubkey: _authorA,
        createdAt: 100,
        eventCreatedAt: 200,
        vineId: 'clip',
      );

      test('replaces the cached revision with a later edit', () {
        final buckets = AuthorVideoBuckets()..seed(_authorA, [original()]);

        buckets.addOrUpdateByVine(
          edited(),
          authorPubkey: _authorA,
          isHistorical: false,
        );

        expect(buckets.videosFor(_authorA).map((video) => video.id), [
          'edited',
        ]);
      });

      test('keeps a later edit when an earlier revision arrives', () {
        final buckets = AuthorVideoBuckets()..seed(_authorA, [edited()]);

        buckets.addOrUpdateByVine(
          original(),
          authorPubkey: _authorA,
          isHistorical: false,
        );

        expect(buckets.videosFor(_authorA).map((video) => video.id), [
          'edited',
        ]);
      });
    });
  });
}
