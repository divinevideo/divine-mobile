import 'package:comments_repository/comments_repository.dart';
import 'package:test/test.dart';

void main() {
  group(CommentDeletion, () {
    const commentId =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
    const otherCommentId =
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
    const authorPubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const otherPubkey =
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
    const rootEventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    Comment comment({String id = commentId, String author = authorPubkey}) =>
        Comment(
          id: id,
          content: 'comment',
          authorPubkey: author,
          createdAt: DateTime.fromMillisecondsSinceEpoch(1000000),
          rootEventId: rootEventId,
          rootAuthorPubkey: otherPubkey,
        );

    group('appliesTo', () {
      test('is true for the named comment by the same author', () {
        const deletion = CommentDeletion(
          commentId: commentId,
          requesterPubkey: authorPubkey,
        );

        expect(deletion.appliesTo(comment()), isTrue);
      });

      test('is false when the requester did not author the comment', () {
        const deletion = CommentDeletion(
          commentId: commentId,
          requesterPubkey: otherPubkey,
        );

        expect(deletion.appliesTo(comment()), isFalse);
      });

      test('is false for another comment by the requester', () {
        const deletion = CommentDeletion(
          commentId: commentId,
          requesterPubkey: authorPubkey,
        );

        expect(deletion.appliesTo(comment(id: otherCommentId)), isFalse);
      });

      test('compares pubkeys case-insensitively', () {
        final deletion = CommentDeletion(
          commentId: commentId,
          requesterPubkey: authorPubkey.toUpperCase(),
        );

        expect(deletion.appliesTo(comment()), isTrue);
      });
    });

    test('deletions by different requesters are not equal', () {
      expect(
        const CommentDeletion(
          commentId: commentId,
          requesterPubkey: authorPubkey,
        ),
        isNot(
          equals(
            const CommentDeletion(
              commentId: commentId,
              requesterPubkey: otherPubkey,
            ),
          ),
        ),
      );
    });
  });
}
