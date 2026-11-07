import 'package:comments_repository/comments_repository.dart';
import 'package:test/test.dart';

const _authorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherAuthorPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

const _replyAddress = '34236:$_authorPubkey:reply';

Comment _comment(
  String id, {
  String authorPubkey = _authorPubkey,
  String? addressableId,
}) => Comment(
  id: id,
  content: 'content of $id',
  authorPubkey: authorPubkey,
  createdAt: DateTime.utc(2026),
  rootEventId: 'root',
  rootAuthorPubkey: 'owner',
  addressableId: addressableId,
);

void main() {
  group(CommentModeration, () {
    group('keyOf', () {
      test('keeps the Divine curation key for a horizontal video reply', () {
        final reply = _comment(
          'c1',
          addressableId: '34235:$_authorPubkey:reply',
        );
        expect(CommentModeration.keyOf(reply), _replyAddress);
        expect(
          const CommentModeration(
            hiddenCommentIds: {_replyAddress},
          ).hides(reply),
          isTrue,
        );
        expect(
          const CommentModeration(
            hiddenCommentIds: {_replyAddress},
          ).restore(reply).hiddenCommentIds,
          isEmpty,
        );
      });

      test('names a comment by its event id', () {
        expect(CommentModeration.keyOf(_comment('C1')), 'c1');
      });

      test('names a video reply by its address', () {
        expect(
          CommentModeration.keyOf(_comment('c1', addressableId: _replyAddress)),
          _replyAddress,
        );
      });
    });

    group('hides', () {
      test('hides a video reply by its address or its event id', () {
        final reply = _comment('c1', addressableId: _replyAddress);

        expect(
          const CommentModeration(hiddenCommentIds: {_replyAddress}).hides(
            reply,
          ),
          isTrue,
        );
        expect(
          const CommentModeration(hiddenCommentIds: {'c1'}).hides(reply),
          isTrue,
        );
      });

      test('hides nothing when empty', () {
        expect(CommentModeration.empty.hides(_comment('c1')), isFalse);
      });

      test('hides a comment the owner hid', () {
        const moderation = CommentModeration(hiddenCommentIds: {'c1'});

        expect(moderation.hides(_comment('c1')), isTrue);
        expect(moderation.hides(_comment('c2')), isFalse);
      });

      test('hides every comment by an auto-hidden author', () {
        const moderation = CommentModeration(
          autoHiddenAuthors: {_authorPubkey},
        );

        expect(moderation.hides(_comment('c1')), isTrue);
        expect(
          moderation.hides(
            _comment('c2', authorPubkey: _otherAuthorPubkey),
          ),
          isFalse,
        );
      });

      test('shows a restored comment by an auto-hidden author', () {
        const moderation = CommentModeration(
          restoredCommentIds: {'c1'},
          autoHiddenAuthors: {_authorPubkey},
        );

        expect(moderation.hides(_comment('c1')), isFalse);
        expect(moderation.hides(_comment('c2')), isTrue);
      });

      test('lets a restore win over a hide of the same comment', () {
        const moderation = CommentModeration(
          hiddenCommentIds: {'c1'},
          restoredCommentIds: {'c1'},
        );

        expect(moderation.hides(_comment('c1')), isFalse);
      });
    });

    group('hide', () {
      test('hides the comment and drops its restore', () {
        const moderation = CommentModeration(
          restoredCommentIds: {'c1'},
          autoHiddenAuthors: {_authorPubkey},
        );

        final hidden = moderation.hide(_comment('c1'));

        expect(hidden.hides(_comment('c1')), isTrue);
        expect(hidden.hiddenCommentIds, equals({'c1'}));
        expect(hidden.restoredCommentIds, isEmpty);
        expect(hidden.autoHiddenAuthors, equals({_authorPubkey}));
      });
    });

    group('restore', () {
      test('lifts every hide of a video reply', () {
        const moderation = CommentModeration(
          hiddenCommentIds: {'c1', _replyAddress},
        );

        final restored = moderation.restore(
          _comment('c1', addressableId: _replyAddress),
        );

        expect(restored.hiddenCommentIds, isEmpty);
      });

      test('only lifts the hide of a comment whose author is not hidden', () {
        const moderation = CommentModeration(hiddenCommentIds: {'c1'});

        final restored = moderation.restore(_comment('c1'));

        expect(restored.hides(_comment('c1')), isFalse);
        expect(restored.hiddenCommentIds, isEmpty);
        expect(restored.restoredCommentIds, isEmpty);
      });

      test('marks a comment by an auto-hidden author restored', () {
        const moderation = CommentModeration(
          autoHiddenAuthors: {_authorPubkey},
        );

        final restored = moderation.restore(_comment('c1'));

        expect(restored.hides(_comment('c1')), isFalse);
        expect(restored.restoredCommentIds, equals({'c1'}));
        expect(restored.hides(_comment('c2')), isTrue);
      });

      test('approves one version of a video reply, not its address', () {
        const moderation = CommentModeration(
          autoHiddenAuthors: {_authorPubkey},
        );

        final restored = moderation.restore(
          _comment('v1', addressableId: _replyAddress),
        );

        expect(restored.restoredCommentIds, equals({'v1'}));
        expect(
          restored.hides(_comment('v1', addressableId: _replyAddress)),
          isFalse,
        );
        // Its author replaced it under the same address.
        expect(
          restored.hides(_comment('v2', addressableId: _replyAddress)),
          isTrue,
        );
      });
    });

    group('withAutoHiddenAuthors', () {
      test('adds the authors', () {
        const moderation = CommentModeration(hiddenCommentIds: {'c1'});

        final merged = moderation.withAutoHiddenAuthors([_authorPubkey]);

        expect(merged.autoHiddenAuthors, equals({_authorPubkey}));
        expect(merged.hiddenCommentIds, equals({'c1'}));
      });

      test('returns the same moderation when nothing is new', () {
        const moderation = CommentModeration(
          autoHiddenAuthors: {_authorPubkey},
        );

        expect(
          moderation.withAutoHiddenAuthors([_authorPubkey]),
          same(moderation),
        );
      });
    });

    test('compares by value', () {
      expect(
        const CommentModeration(hiddenCommentIds: {'c1'}),
        equals(const CommentModeration(hiddenCommentIds: {'c1'})),
      );
      expect(
        const CommentModeration(hiddenCommentIds: {'c1'}),
        isNot(equals(const CommentModeration(hiddenCommentIds: {'c2'}))),
      );
    });
  });
}
