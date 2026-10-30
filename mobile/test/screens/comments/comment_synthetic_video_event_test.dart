import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/comments/comment_synthetic_video_event.dart';

void main() {
  group('CommentSyntheticVideoEventX', () {
    test('preserves addressable root tags for video reply navigation', () {
      const rootEventId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const rootAuthorPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      const rootAddressableId = '34236:$rootAuthorPubkey:parent-video';

      final comment = Comment(
        id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        content: 'video reply',
        authorPubkey:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        rootEventId: rootEventId,
        rootAuthorPubkey: rootAuthorPubkey,
        rootAddressableId: rootAddressableId,
        videoUrl: 'https://media.divine.video/reply-video',
      );

      final video = comment.toSyntheticVideoEvent();

      expect(video.rawTags['A'], rootAddressableId);
      expect(video.rawTags['a'], rootAddressableId);
      expect(video.replyRootAddressableId, rootAddressableId);
      expect(video.replyRootRouteId, rootAddressableId);
    });

    test('keeps the stickers a viewer can tap on the video reply', () {
      const rootEventId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const parentCommentId =
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
      final comment = Comment(
        id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        content: '',
        authorPubkey:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        rootEventId: rootEventId,
        rootAuthorPubkey:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        replyToEventId: parentCommentId,
        videoUrl: 'https://media.divine.video/reply-video',
        stickerTags: const [
          ['sticker', 'reply', parentCommentId, '0.5 0.5 0.6 0.1', '0'],
        ],
      );

      final video = comment.toSyntheticVideoEvent();

      expect(video.stickerRegions.single.target, equals(parentCommentId));
      expect(video.replyRootEventId, equals(rootEventId));
    });
  });
}
