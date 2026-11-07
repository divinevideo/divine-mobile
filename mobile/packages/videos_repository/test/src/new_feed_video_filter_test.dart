import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

VideoEvent _video(int id, String pubkey) => VideoEvent(
  id: id.toRadixString(16).padLeft(64, '0'),
  pubkey: pubkey,
  createdAt: 1000 - id,
  content: '',
  timestamp: DateTime.utc(2026),
  videoUrl: 'https://example.com/$id.mp4',
);

void main() {
  group('filterNewFeedVideos', () {
    test('caps each creator at two without reordering other creators', () {
      final videos = [
        _video(1, 'a' * 64),
        _video(2, 'b' * 64),
        _video(3, 'a' * 64),
        _video(4, 'a' * 64),
        _video(5, 'c' * 64),
        _video(6, 'b' * 64),
        _video(7, 'b' * 64),
      ];

      expect(filterNewFeedVideos(videos), [
        videos[0],
        videos[1],
        videos[2],
        videos[4],
        videos[5],
      ]);
      expect(videos, hasLength(7));
    });

    test('a fresh window has its own creator allowance', () {
      final older = [_video(1, 'a' * 64), _video(2, 'a' * 64)];
      final fresh = [_video(3, 'a' * 64), _video(4, 'a' * 64)];

      expect(filterNewFeedVideos(older), older);
      expect(filterNewFeedVideos(fresh), fresh);
      expect(filterNewFeedVideos(const []), isEmpty);
    });
  });
}
