import 'package:comments_repository/comments_repository.dart';
import 'package:test/test.dart';

void main() {
  group('CommentThread', () {
    group('constructor', () {
      test('creates thread with default values', () {
        const thread = CommentThread(rootEventId: 'root');

        expect(thread.rootEventId, equals('root'));
        expect(thread.comments, isEmpty);
        expect(thread.totalCount, equals(0));
        expect(thread.commentCache, isEmpty);
      });

      test('creates thread with provided values', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        final thread = CommentThread(
          rootEventId: 'root',
          comments: [comment],
          totalCount: 1,
          commentCache: {'id': comment},
        );

        expect(thread.rootEventId, equals('root'));
        expect(thread.comments, hasLength(1));
        expect(thread.totalCount, equals(1));
        expect(thread.commentCache, hasLength(1));
      });
    });

    group('empty', () {
      test('creates empty thread with given rootEventId', () {
        const thread = CommentThread.empty('rootId');

        expect(thread.isEmpty, isTrue);
        expect(thread.isNotEmpty, isFalse);
        expect(thread.totalCount, equals(0));
        expect(thread.comments, isEmpty);
        expect(thread.commentCache, isEmpty);
        expect(thread.rootEventId, equals('rootId'));
      });
    });

    group('isEmpty', () {
      test('returns true when totalCount is 0', () {
        const thread = CommentThread(rootEventId: 'root');

        expect(thread.isEmpty, isTrue);
      });

      test('returns false when totalCount is greater than 0', () {
        const thread = CommentThread(rootEventId: 'root', totalCount: 1);

        expect(thread.isEmpty, isFalse);
      });
    });

    group('isNotEmpty', () {
      test('returns false when totalCount is 0', () {
        const thread = CommentThread(rootEventId: 'root');

        expect(thread.isNotEmpty, isFalse);
      });

      test('returns true when totalCount is greater than 0', () {
        const thread = CommentThread(rootEventId: 'root', totalCount: 1);

        expect(thread.isNotEmpty, isTrue);
      });
    });

    group('getComment', () {
      test('returns comment from cache when exists', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        final thread = CommentThread(
          rootEventId: 'root',
          totalCount: 1,
          commentCache: {'id': comment},
        );

        expect(thread.getComment('id'), equals(comment));
      });

      test('returns null when comment does not exist', () {
        const thread = CommentThread(rootEventId: 'root');

        expect(thread.getComment('nonexistent'), isNull);
      });
    });

    group('copyWith', () {
      late CommentThread original;
      late Comment comment;

      setUp(() {
        comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        original = CommentThread(
          rootEventId: 'root',
          comments: [comment],
          totalCount: 1,
          commentCache: {'id': comment},
        );
      });

      test('creates copy with updated rootEventId', () {
        final copy = original.copyWith(rootEventId: 'newRoot');

        expect(copy.rootEventId, equals('newRoot'));
        expect(copy.comments, equals(original.comments));
        expect(copy.totalCount, equals(original.totalCount));
        expect(copy.commentCache, equals(original.commentCache));
      });

      test('creates copy with updated comments', () {
        final newComment = Comment(
          id: 'id2',
          content: 'content2',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        final copy = original.copyWith(comments: [newComment]);

        expect(copy.rootEventId, equals(original.rootEventId));
        expect(copy.comments, equals([newComment]));
        expect(copy.totalCount, equals(original.totalCount));
      });

      test('creates copy with updated totalCount', () {
        final copy = original.copyWith(totalCount: 5);

        expect(copy.totalCount, equals(5));
        expect(copy.rootEventId, equals(original.rootEventId));
      });

      test('creates copy with updated pagination metadata', () {
        final copy = original.copyWith(hasMore: true, hasExactTotal: false);

        expect(copy.hasMore, isTrue);
        expect(copy.hasExactTotal, isFalse);
        expect(copy.rootEventId, equals(original.rootEventId));
      });

      test('creates copy with updated nextOffset', () {
        final copy = original.copyWith(nextOffset: 50);

        expect(copy.nextOffset, equals(50));
        expect(original.nextOffset, isNull);
        expect(copy.rootEventId, equals(original.rootEventId));
      });

      test('creates copy with updated commentCache', () {
        final newComment = Comment(
          id: 'id2',
          content: 'content2',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        final copy = original.copyWith(commentCache: {'id2': newComment});

        expect(copy.commentCache, equals({'id2': newComment}));
        expect(copy.rootEventId, equals(original.rootEventId));
      });

      test('preserves all fields when no parameters provided', () {
        final copy = original.copyWith();

        expect(copy, equals(original));
      });
    });

    group('equality', () {
      test('two threads with same values are equal', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        final thread1 = CommentThread(
          rootEventId: 'root',
          comments: [comment],
          totalCount: 1,
          commentCache: {'id': comment},
        );

        final thread2 = CommentThread(
          rootEventId: 'root',
          comments: [comment],
          totalCount: 1,
          commentCache: {'id': comment},
        );

        expect(thread1, equals(thread2));
      });

      test('two threads with different values are not equal', () {
        const thread1 = CommentThread(rootEventId: 'root1');
        const thread2 = CommentThread(rootEventId: 'root2');

        expect(thread1, isNot(equals(thread2)));
      });

      test('threads that differ only by nextOffset are not equal', () {
        const first = CommentThread(rootEventId: 'root', nextOffset: 50);
        const second = CommentThread(rootEventId: 'root', nextOffset: 100);

        expect(first, isNot(equals(second)));
      });

      test('props includes all fields', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        final thread = CommentThread(
          rootEventId: 'root',
          comments: [comment],
          totalCount: 1,
          commentCache: {'id': comment},
        );

        expect(
          thread.props,
          equals([
            'root',
            [comment],
            1,
            null,
            true,
            {'id': comment},
            null,
          ]),
        );
      });
    });
  });
}
