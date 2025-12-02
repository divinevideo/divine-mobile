// ABOUTME: Unit tests for Comment model data class
// ABOUTME: Tests comment creation, serialization, and time formatting functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/comment.dart';

void main() {
  group('Comment Model Unit Tests', () {
    const testCommentId =
        'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
    const testContent = 'This is a test comment';
    const testAuthorPubkey =
        'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a';
    const testRootEventId =
        'c3d4e5f6789012345678901234567890abcdef123456789012345678901234ab';
    const testRootAuthorPubkey =
        'd4e5f6789012345678901234567890abcdef123456789012345678901234abc';

    late DateTime testCreatedAt;

    setUp(() {
      testCreatedAt = DateTime.now();
    });

    group('Constructor', () {
      test('should create comment with all required fields', () {
        // Act
        final comment = Comment(
          id: testCommentId,
          content: testContent,
          authorPubkey: testAuthorPubkey,
          createdAt: testCreatedAt,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
        );

        // Assert
        expect(comment.id, equals(testCommentId));
        expect(comment.content, equals(testContent));
        expect(comment.authorPubkey, equals(testAuthorPubkey));
        expect(comment.createdAt, equals(testCreatedAt));
        expect(comment.rootEventId, equals(testRootEventId));
        expect(comment.rootAuthorPubkey, equals(testRootAuthorPubkey));
        expect(comment.replyToEventId, isNull);
        expect(comment.replyToAuthorPubkey, isNull);
      });

      test('should create comment with optional reply fields', () {
        // Arrange
        const replyToEventId =
            'e5f6789012345678901234567890abcdef123456789012345678901234abcd';
        const replyToAuthorPubkey =
            'f6789012345678901234567890abcdef123456789012345678901234abcde';

        // Act
        final comment = Comment(
          id: testCommentId,
          content: testContent,
          authorPubkey: testAuthorPubkey,
          createdAt: testCreatedAt,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          replyToEventId: replyToEventId,
          replyToAuthorPubkey: replyToAuthorPubkey,
        );

        // Assert
        expect(comment.replyToEventId, equals(replyToEventId));
        expect(comment.replyToAuthorPubkey, equals(replyToAuthorPubkey));
      });
    });

    group('isReply getter', () {
      test('should return false for top-level comment', () {
        // Act
        final comment = Comment(
          id: testCommentId,
          content: testContent,
          authorPubkey: testAuthorPubkey,
          createdAt: testCreatedAt,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
        );

        // Assert
        expect(comment.isReply, isFalse);
      });

      test('should return true for reply comment', () {
        // Act
        final comment = Comment(
          id: testCommentId,
          content: testContent,
          authorPubkey: testAuthorPubkey,
          createdAt: testCreatedAt,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          replyToEventId: 'some_parent_id',
        );

        // Assert
        expect(comment.isReply, isTrue);
      });
    });

    group('relativeTime getter', () {
      test('should return "now" for very recent comment', () {
        // Arrange
        final recentTime = DateTime.now().subtract(const Duration(seconds: 5));

        // Act
        final comment = Comment(
          id: testCommentId,
          content: testContent,
          authorPubkey: testAuthorPubkey,
          createdAt: recentTime,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
        );

        // Assert
        expect(comment.relativeTime, equals('now'));
      });

      test('should return "now" for comment under 1 minute', () {
        // Arrange
        final timeAgo = DateTime.now().subtract(const Duration(seconds: 30));

        // Act
        final comment = Comment(
          id: testCommentId,
          content: testContent,
          authorPubkey: testAuthorPubkey,
          createdAt: timeAgo,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
        );

        // Assert
        expect(comment.relativeTime, equals('now'));
      });

      test('should return minutes for comment under 1 hour', () {
        // Arrange
        final timeAgo = DateTime.now().subtract(const Duration(minutes: 15));

        // Act
        final comment = Comment(
          id: testCommentId,
          content: testContent,
          authorPubkey: testAuthorPubkey,
          createdAt: timeAgo,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
        );

        // Assert
        expect(comment.relativeTime, equals('15m ago'));
      });

      test('should return hours for comment under 1 day', () {
        // Arrange
        final timeAgo = DateTime.now().subtract(const Duration(hours: 3));

        // Act
        final comment = Comment(
          id: testCommentId,
          content: testContent,
          authorPubkey: testAuthorPubkey,
          createdAt: timeAgo,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
        );

        // Assert
        expect(comment.relativeTime, equals('3h ago'));
      });

      test('should return days for comment over 1 day', () {
        // Arrange
        final timeAgo = DateTime.now().subtract(const Duration(days: 2));

        // Act
        final comment = Comment(
          id: testCommentId,
          content: testContent,
          authorPubkey: testAuthorPubkey,
          createdAt: timeAgo,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
        );

        // Assert
        expect(comment.relativeTime, equals('2d ago'));
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        // Arrange
        final comment = Comment(
          id: testCommentId,
          content: testContent,
          authorPubkey: testAuthorPubkey,
          createdAt: testCreatedAt,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          replyToEventId: 'reply_id',
          replyToAuthorPubkey: 'reply_author',
        );

        // Act
        final json = comment.toJson();

        // Assert
        expect(json['id'], equals(testCommentId));
        expect(json['content'], equals(testContent));
        expect(json['authorPubkey'], equals(testAuthorPubkey));
        expect(json['createdAt'], equals(testCreatedAt.toIso8601String()));
        expect(json['rootEventId'], equals(testRootEventId));
        expect(json['rootAuthorPubkey'], equals(testRootAuthorPubkey));
        expect(json['replyToEventId'], equals('reply_id'));
        expect(json['replyToAuthorPubkey'], equals('reply_author'));
      });

      test('should deserialize from JSON correctly', () {
        // Arrange
        final json = {
          'id': testCommentId,
          'content': testContent,
          'authorPubkey': testAuthorPubkey,
          'createdAt': testCreatedAt.toIso8601String(),
          'rootEventId': testRootEventId,
          'rootAuthorPubkey': testRootAuthorPubkey,
          'replyToEventId': 'reply_id',
          'replyToAuthorPubkey': 'reply_author',
        };

        // Act
        final comment = Comment.fromJson(json);

        // Assert
        expect(comment.id, equals(testCommentId));
        expect(comment.content, equals(testContent));
        expect(comment.authorPubkey, equals(testAuthorPubkey));
        expect(comment.createdAt, equals(testCreatedAt));
        expect(comment.rootEventId, equals(testRootEventId));
        expect(comment.rootAuthorPubkey, equals(testRootAuthorPubkey));
        expect(comment.replyToEventId, equals('reply_id'));
        expect(comment.replyToAuthorPubkey, equals('reply_author'));
      });

      test('should handle null optional fields in JSON', () {
        // Arrange
        final json = {
          'id': testCommentId,
          'content': testContent,
          'authorPubkey': testAuthorPubkey,
          'createdAt': testCreatedAt.toIso8601String(),
          'rootEventId': testRootEventId,
          'rootAuthorPubkey': testRootAuthorPubkey,
          'replyToEventId': null,
          'replyToAuthorPubkey': null,
        };

        // Act
        final comment = Comment.fromJson(json);

        // Assert
        expect(comment.replyToEventId, isNull);
        expect(comment.replyToAuthorPubkey, isNull);
        expect(comment.isReply, isFalse);
      });
    });

    group('Equality and Hashing', () {
      test('should be equal when all fields match', () {
        // Arrange
        final comment1 = Comment(
          id: testCommentId,
          content: testContent,
          authorPubkey: testAuthorPubkey,
          createdAt: testCreatedAt,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
        );

        final comment2 = Comment(
          id: testCommentId,
          content: testContent,
          authorPubkey: testAuthorPubkey,
          createdAt: testCreatedAt,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
        );

        // Assert
        expect(comment1, equals(comment2));
        expect(comment1.hashCode, equals(comment2.hashCode));
      });

      test('should not be equal when IDs differ', () {
        // Arrange
        final comment1 = Comment(
          id: testCommentId,
          content: testContent,
          authorPubkey: testAuthorPubkey,
          createdAt: testCreatedAt,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
        );

        final comment2 = Comment(
          id: 'different_id_123456789012345678901234567890abcdef123456789012',
          content: testContent,
          authorPubkey: testAuthorPubkey,
          createdAt: testCreatedAt,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
        );

        // Assert
        expect(comment1, isNot(equals(comment2)));
      });
    });

    group('Edge Cases', () {
      test('should handle empty content', () {
        // Act
        final comment = Comment(
          id: testCommentId,
          content: '',
          authorPubkey: testAuthorPubkey,
          createdAt: testCreatedAt,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
        );

        // Assert
        expect(comment.content, equals(''));
      });

      test('should handle very long content', () {
        // Arrange
        final longContent = 'A' * 1000;

        // Act
        final comment = Comment(
          id: testCommentId,
          content: longContent,
          authorPubkey: testAuthorPubkey,
          createdAt: testCreatedAt,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
        );

        // Assert
        expect(comment.content, equals(longContent));
        expect(comment.content.length, equals(1000));
      });

      test('should handle future timestamps', () {
        // Arrange
        final futureTime = DateTime.now().add(const Duration(hours: 1));

        // Act
        final comment = Comment(
          id: testCommentId,
          content: testContent,
          authorPubkey: testAuthorPubkey,
          createdAt: futureTime,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
        );

        // Assert
        expect(comment.createdAt, equals(futureTime));
        expect(
          comment.relativeTime,
          equals('now'),
        ); // Future times show as "now"
      });
    });
  });
}
