import 'package:comments_repository/comments_repository.dart';
import 'package:test/test.dart';

void main() {
  group('Comment', () {
    group('hasVideo', () {
      test('returns true when videoUrl is set', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
          videoUrl: 'https://example.com/video.mp4',
        );

        expect(comment.hasVideo, isTrue);
      });

      test('returns false when videoUrl is null', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        expect(comment.hasVideo, isFalse);
      });

      test('returns false when videoUrl is empty', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
          videoUrl: '',
        );

        expect(comment.hasVideo, isFalse);
      });
    });

    group('copyWith', () {
      late Comment original;

      setUp(() {
        original = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
          replyToEventId: 'replyTo',
          replyToAuthorPubkey: 'replyAuthor',
        );
      });

      test('creates copy with updated id', () {
        final copy = original.copyWith(id: 'newId');

        expect(copy.id, equals('newId'));
        expect(copy.content, equals('content'));
      });

      test('creates copy with updated content', () {
        final copy = original.copyWith(content: 'new content');

        expect(copy.id, equals('id'));
        expect(copy.content, equals('new content'));
      });

      test('creates copy with updated authorPubkey', () {
        final copy = original.copyWith(authorPubkey: 'newAuthor');

        expect(copy.authorPubkey, equals('newAuthor'));
        expect(copy.content, equals('content'));
      });

      test('creates copy with updated createdAt', () {
        final newDate = DateTime(2025);
        final copy = original.copyWith(createdAt: newDate);

        expect(copy.createdAt, equals(newDate));
      });

      test('creates copy with updated rootEventId', () {
        final copy = original.copyWith(rootEventId: 'newRoot');

        expect(copy.rootEventId, equals('newRoot'));
      });

      test('creates copy with updated rootAuthorPubkey', () {
        final copy = original.copyWith(rootAuthorPubkey: 'newRootAuthor');

        expect(copy.rootAuthorPubkey, equals('newRootAuthor'));
      });

      test('creates copy with updated replyToEventId', () {
        final copy = original.copyWith(replyToEventId: 'newReplyTo');

        expect(copy.replyToEventId, equals('newReplyTo'));
      });

      test('creates copy with updated replyToAuthorPubkey', () {
        final copy = original.copyWith(replyToAuthorPubkey: 'newReplyAuthor');

        expect(copy.replyToAuthorPubkey, equals('newReplyAuthor'));
      });

      test('preserves all fields when no parameters provided', () {
        final copy = original.copyWith();

        expect(copy, equals(original));
      });
    });

    group('equality', () {
      test('two comments with same values are equal', () {
        final comment1 = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        final comment2 = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        expect(comment1, equals(comment2));
      });

      test('two comments with different values are not equal', () {
        final comment1 = Comment(
          id: 'id1',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        final comment2 = Comment(
          id: 'id2',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        expect(comment1, isNot(equals(comment2)));
      });

      test('props includes all fields', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
          addressableId: '34236:author:d-tag',
          eventKind: 34236,
          replyToEventId: 'replyTo',
          replyToAuthorPubkey: 'replyAuthor',
          videoUrl: 'https://example.com/video.mp4',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          videoDimensions: '1080x1920',
          videoDuration: 30,
          videoBlurhash: 'LEHV6nWB2y',
          stickerTags: const [
            ['sticker', 'reply', 'root', '0.5 0.5 0.5 0.1', '0'],
          ],
        );

        expect(comment.props, hasLength(17));
        expect(
          comment.props,
          equals([
            'id',
            'content',
            'author',
            DateTime(2024),
            'root',
            'rootAuthor',
            null,
            '34236:author:d-tag',
            34236,
            'replyTo',
            'replyAuthor',
            'https://example.com/video.mp4',
            'https://example.com/thumb.jpg',
            '1080x1920',
            30,
            'LEHV6nWB2y',
            [
              ['sticker', 'reply', 'root', '0.5 0.5 0.5 0.1', '0'],
            ],
          ]),
        );
      });
    });
  });
}
