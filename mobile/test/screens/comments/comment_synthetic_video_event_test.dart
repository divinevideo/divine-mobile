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

    test("carries a Kind 34236 video reply's own coordinate (#6980)", () {
      const authorPubkey =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
      const ownAddressableId = '34236:$authorPubkey:reply-d-tag';
      final comment = Comment(
        id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        content: 'video reply',
        authorPubkey: authorPubkey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        rootEventId:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        rootAuthorPubkey:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        eventKind: 34236,
        addressableId: ownAddressableId,
        videoUrl: 'https://media.divine.video/reply-video',
      );

      final video = comment.toSyntheticVideoEvent();

      expect(video.addressableId, equals(ownAddressableId));
    });

    test('gives a shared Kind 34236 video reply the d tag its citation '
        'needs', () {
      const authorPubkey =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
      final comment = Comment(
        id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        content: 'video reply',
        authorPubkey: authorPubkey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        rootEventId:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        rootAuthorPubkey:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        eventKind: 34236,
        addressableId: '34236:$authorPubkey:reply-d-tag',
        videoUrl: 'https://media.divine.video/reply-video',
      );

      final video = comment.toSyntheticVideoEvent();

      // VideoSharingService cites by (shareKind, vineId): an addressable kind
      // with no d tag builds no citation and the DM degrades to plain text.
      expect(video.shareKind, equals(34236));
      expect(video.vineId, equals('reply-d-tag'));
    });

    test('leaves a reply whose own coordinate is another kind alone', () {
      const authorPubkey =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
      final comment = Comment(
        id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        content: 'long-form video reply',
        authorPubkey: authorPubkey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        rootEventId:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        rootAuthorPubkey:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        eventKind: 34235,
        addressableId: '34235:$authorPubkey:reply-d-tag',
        videoUrl: 'https://media.divine.video/reply-video',
      );

      final video = comment.toSyntheticVideoEvent();

      // VideoEvent.addressableId always mints a 34236 coordinate (#5720), so
      // carrying this d tag would address an event that does not exist.
      expect(video.addressableId, isNull);
    });

    test('leaves a plain Kind 1111 video comment without a coordinate', () {
      final comment = Comment(
        id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        content: 'video comment',
        authorPubkey:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        rootEventId:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        rootAuthorPubkey:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        eventKind: 1111,
        videoUrl: 'https://media.divine.video/reply-video',
      );

      final video = comment.toSyntheticVideoEvent();

      expect(video.addressableId, isNull);
      expect(video.isAddressableShareKind, isFalse);
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
