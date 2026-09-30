import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:videos_repository/src/badge_video_pager.dart';

class _Client extends Mock implements FunnelcakeApiClient {}

VideoStats _video(int id, int createdAt) => VideoStats(
  id: id.toRadixString(16).padLeft(64, '0'),
  pubkey: 'a' * 64,
  createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000, isUtc: true),
  kind: 34236,
  dTag: 'video-$id',
  title: 'Video $id',
  thumbnail: '',
  videoUrl: 'https://example.com/$id.mp4',
  reactions: 0,
  comments: 0,
  reposts: 0,
  engagementScore: 0,
);

void main() {
  setUpAll(() => registerFallbackValue(<String>[]));

  test(
    'merges over 200 authors with stable pagination and deduplication',
    () async {
      final client = _Client();
      final calls = <(int, int)>[];
      when(
        () => client.getVideosByAuthors(
          authors: any(named: 'authors'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((invocation) async {
        final authors = invocation.namedArguments[#authors]! as List<String>;
        final offset = invocation.namedArguments[#offset]! as int;
        calls.add((authors.length, offset));
        final videos = switch ((authors.length, offset)) {
          (200, 0) => [_video(1, 300)],
          (200, 1) => [_video(3, 100)],
          (5, 0) => [_video(1, 300), _video(2, 200)],
          _ => <VideoStats>[],
        };
        return RecentVideosResponse(
          videos: videos,
          serverItemCount: videos.length,
          hasMore: authors.length == 200 && offset == 0,
        );
      });
      final pager = BadgeVideoPager(
        client: client,
        authors: [
          for (var i = 0; i < 205; i++) i.toRadixString(16).padLeft(64, '0'),
        ],
        transform: (stats) =>
            stats.map((video) => video.toVideoEvent()).toList(),
        before: 400,
      );

      final first = await pager.loadMore(limit: 2);
      final second = await pager.loadMore(limit: 1);

      expect(first.map((video) => video.id), [
        _video(1, 300).id,
        _video(2, 200).id,
      ]);
      expect(second.map((video) => video.id), [_video(3, 100).id]);
      expect(calls, containsAll([(200, 0), (5, 0), (200, 1)]));
      expect(pager.hasMore, isFalse);
    },
  );
}
