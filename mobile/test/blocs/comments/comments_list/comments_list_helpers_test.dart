// ABOUTME: Tests the comments-list helpers: the Top vote comparator and the
// ABOUTME: pending video-reply placeholder id convention (#5862).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_helpers.dart';

import '../../../builders/comment_builder.dart';

void main() {
  group('commentVoteComparator', () {
    test('orders a tie on votes and second by id, whatever the input', () {
      // created_at has one-second resolution, and List.sort is not stable,
      // so without a last tiebreak the sheet and the overlay could disagree.
      final createdAt = DateTime.utc(2026, 11);
      final first = CommentBuilder()
          .withId('a' * 64)
          .withCreatedAt(createdAt)
          .build();
      final second = CommentBuilder()
          .withId('b' * 64)
          .withCreatedAt(createdAt)
          .build();
      final compare = commentVoteComparator(
        upvoteCounts: {first.id: 2, second.id: 2},
        downvoteCounts: const {},
      );

      expect([second, first]..sort(compare), [first, second]);
      expect([first, second]..sort(compare), [first, second]);
    });
  });

  group('pending video-reply ids', () {
    test('round-trips the draft id', () {
      final id = pendingVideoReplyId('publish_1234');
      expect(draftIdFromPendingVideoReplyId(id), equals('publish_1234'));
    });

    test('keeps the shared placeholder prefix', () {
      // Load-more cursor selection and the relay-echo swap in CommentsListBloc
      // both key off this prefix; dropping it would silently break both.
      expect(
        pendingVideoReplyId('d1'),
        startsWith(commentPlaceholderIdPrefix),
      );
    });

    test('does not claim a text placeholder', () {
      const textPlaceholder = '${commentPlaceholderIdPrefix}1700000000000000';
      expect(isPendingVideoReplyId(textPlaceholder), isFalse);
      expect(draftIdFromPendingVideoReplyId(textPlaceholder), isNull);
    });

    test('does not claim a real event id', () {
      final eventId = 'a' * 64;
      expect(isPendingVideoReplyId(eventId), isFalse);
      expect(draftIdFromPendingVideoReplyId(eventId), isNull);
    });
  });
}
