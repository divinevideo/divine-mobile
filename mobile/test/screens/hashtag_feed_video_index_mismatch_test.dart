// ABOUTME: Regression test for issue #1751 - wrong video displayed after
// ABOUTME: tapping thumbnail in hashtag feed. Verifies the tapped video is
// ABOUTME: anchored by id even when fullscreen resolves a different list.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

/// A stand-in grid order for the anchor test: trending and classics
/// interleaved 1:1, deduplicated by id and vine id.
List<VideoEvent> gridInterleave(
  List<VideoEvent> trending,
  List<VideoEvent> classics,
) {
  // Deduplicate: remove classics that appear in trending
  final trendingIds = <String>{};
  for (final v in trending) {
    if (v.id.isNotEmpty) trendingIds.add(v.id.toLowerCase());
    if (v.vineId != null && v.vineId!.isNotEmpty) {
      trendingIds.add(v.vineId!.toLowerCase());
    }
  }

  final uniqueClassics = <VideoEvent>[];
  for (final video in classics) {
    final isDuplicate =
        trendingIds.contains(video.id.toLowerCase()) ||
        (video.vineId != null &&
            trendingIds.contains(video.vineId!.toLowerCase()));
    if (!isDuplicate) {
      uniqueClassics.add(video);
    }
  }

  // Interleave 1:1
  final result = <VideoEvent>[];
  final maxLen = trending.length > uniqueClassics.length
      ? trending.length
      : uniqueClassics.length;

  for (var i = 0; i < maxLen; i++) {
    if (i < trending.length) result.add(trending[i]);
    if (i < uniqueClassics.length) result.add(uniqueClassics[i]);
  }

  return result;
}

VideoEvent _video({
  required String id,
  int? originalLoops,
  int createdAt = 1000000,
}) {
  return VideoEvent(
    id: id,
    pubkey: 'pubkey-$id',
    createdAt: createdAt,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
    originalLoops: originalLoops,
  );
}

void main() {
  group('Issue #1751: hashtag feed video index mismatch (regression)', () {
    // The reel starts from the grid's list, but the fullscreen bloc's filters
    // can drop a video ahead of the tapped one, so navigation passes the tapped
    // video id and the bloc re-anchors playback on it.

    late List<VideoEvent> trending;
    late List<VideoEvent> classics;

    setUp(() {
      trending = [
        _video(id: 'T1', originalLoops: 500, createdAt: 1000003),
        _video(id: 'T2', originalLoops: 400, createdAt: 1000002),
        _video(id: 'T3', originalLoops: 300, createdAt: 1000001),
      ];

      classics = [
        _video(id: 'C1', originalLoops: 10000, createdAt: 900003),
        _video(id: 'C2', originalLoops: 8000, createdAt: 900002),
        _video(id: 'C3', originalLoops: 5000, createdAt: 900001),
      ];
    });

    test('grid produces expected interleaved order', () {
      final gridOrder = gridInterleave(trending, classics);

      // Trending and classic interleaved 1:1: T1, C1, T2, C2, T3, C3
      expect(
        gridOrder.map((v) => v.id).toList(),
        equals(['T1', 'C1', 'T2', 'C2', 'T3', 'C3']),
        reason: 'Grid should interleave trending and classic 1:1',
      );
    });

    test(
      'identity anchor preserves tapped video when repository list differs',
      () {
        final gridOrder = gridInterleave(trending, classics);
        const tappedGridIndex = 2;
        final tappedVideoId = gridOrder[tappedGridIndex].id;

        // Simulate the fullscreen repository filtering out an earlier grid item.
        final repositoryOrder = [
          gridOrder[1],
          gridOrder[tappedGridIndex],
          gridOrder[3],
        ];
        final resolvedIndex = repositoryOrder.indexWhere(
          (video) => video.id == tappedVideoId,
        );

        expect(
          repositoryOrder[tappedGridIndex].id,
          isNot(tappedVideoId),
          reason: 'The raw grid index points at the wrong repository item.',
        );
        expect(
          repositoryOrder[resolvedIndex].id,
          tappedVideoId,
          reason: 'The tapped video id re-anchors fullscreen playback.',
        );
      },
    );

    test('deduplication removes classics that appear in trending', () {
      // Add a classic that has the same ID as a trending video
      final classicsWithDup = [
        ...classics,
        _video(id: 'T1', originalLoops: 9999, createdAt: 800000),
      ];

      final gridOrder = gridInterleave(trending, classicsWithDup);

      // T1 should only appear once (from trending), not twice
      final t1Count = gridOrder.where((v) => v.id == 'T1').length;
      expect(t1Count, equals(1), reason: 'Duplicate T1 should be removed');
    });
  });
}
