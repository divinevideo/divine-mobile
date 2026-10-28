// ABOUTME: Tests for FeedTopCommentCubit — top-comment selection with the Top
// ABOUTME: ordering, replied-to context, failures, and overlay visibility.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/feed_top_comment/feed_top_comment_cubit.dart';
import 'package:openvine/observability/reportable_error.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockLikesRepository extends Mock implements LikesRepository {}

const _rootId =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _creator =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _alice =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _bob = '4444444444444444444444444444444444444444444444444444444444444444';

final _now = DateTime(2026, 10, 28, 12);

Comment _comment(
  String id, {
  String content = 'hello',
  String author = _alice,
  Duration age = const Duration(hours: 1),
  String? replyToEventId,
  String? replyToAuthorPubkey,
  String? videoUrl,
}) => Comment(
  id: id,
  content: content,
  authorPubkey: author,
  createdAt: _now.subtract(age),
  rootEventId: _rootId,
  rootAuthorPubkey: _creator,
  replyToEventId: replyToEventId,
  replyToAuthorPubkey: replyToAuthorPubkey,
  videoUrl: videoUrl,
);

void main() {
  group(FeedTopCommentCubit, () {
    late _MockCommentsRepository commentsRepository;
    late _MockLikesRepository likesRepository;
    late StreamController<void> loops;

    setUp(() {
      commentsRepository = _MockCommentsRepository();
      likesRepository = _MockLikesRepository();
      loops = StreamController<void>.broadcast();
    });

    tearDown(() => loops.close());

    void stubComments(List<Comment> comments) {
      when(
        () => commentsRepository.loadComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => CommentThread(rootEventId: _rootId, comments: comments),
      );
    }

    void stubUpvotes(Map<String, int> upvotes) {
      when(
        () => likesRepository.getVoteCounts(
          any(),
          addressableIds: any(named: 'addressableIds'),
        ),
      ).thenAnswer(
        (_) async => (upvotes: upvotes, downvotes: const <String, int>{}),
      );
    }

    FeedTopCommentCubit buildCubit() => FeedTopCommentCubit(
      commentsRepository: commentsRepository,
      likesRepository: likesRepository,
      rootEventId: _rootId,
      rootEventKind: 34236,
      rootAuthorPubkey: _creator,
      rootContent: 'Amineeeee!',
      loopCompletions: loops.stream,
      now: () => _now,
    );

    group('load', () {
      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'selects the most upvoted comment and answers the creator',
        setUp: () {
          stubComments([_comment('a'), _comment('b', content: 'Wanna know')]);
          stubUpvotes({'a': 1, 'b': 9});
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          isA<FeedTopCommentState>()
              .having((s) => s.status, 'status', FeedTopCommentStatus.ready)
              .having((s) => s.topComment?.id, 'topComment', 'b')
              .having((s) => s.repliedToPubkey, 'repliedToPubkey', _creator)
              .having(
                (s) => s.repliedToContent,
                'repliedToContent',
                'Amineeeee!',
              ),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'answers the parent comment for a reply',
        setUp: () {
          stubComments([
            _comment('parent', content: 'Who made this?', author: _bob),
            _comment(
              'reply',
              replyToEventId: 'parent',
              replyToAuthorPubkey: _bob,
            ),
          ]);
          stubUpvotes({'reply': 5});
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          isA<FeedTopCommentState>()
              .having((s) => s.topComment?.id, 'topComment', 'reply')
              .having((s) => s.repliedToPubkey, 'repliedToPubkey', _bob)
              .having(
                (s) => s.repliedToContent,
                'repliedToContent',
                'Who made this?',
              ),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'counts replies toward a comment like the Top ordering does',
        setUp: () {
          stubComments([
            _comment('quiet'),
            _comment('discussed'),
            _comment(
              'answer',
              content: '',
              replyToEventId: 'discussed',
              replyToAuthorPubkey: _alice,
            ),
          ]);
          stubUpvotes({'quiet': 1});
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          isA<FeedTopCommentState>().having(
            (s) => s.topComment?.id,
            'topComment',
            'discussed',
          ),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'breaks a tie in favour of the newer comment',
        // Neither has votes or replies, so both score zero.
        setUp: () {
          stubComments([
            _comment('older', age: const Duration(hours: 5)),
            _comment('newer'),
          ]);
          stubUpvotes({});
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          isA<FeedTopCommentState>().having(
            (s) => s.topComment?.id,
            'topComment',
            'newer',
          ),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'is empty when only video replies and blank comments exist',
        setUp: () {
          stubComments([
            _comment('video', videoUrl: 'https://media.example/v.mp4'),
            _comment('blank', content: '   '),
          ]);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          isA<FeedTopCommentState>().having(
            (s) => s.status,
            'status',
            FeedTopCommentStatus.loading,
          ),
          isA<FeedTopCommentState>()
              .having((s) => s.status, 'status', FeedTopCommentStatus.empty)
              .having((s) => s.topComment, 'topComment', isNull),
        ],
        verify: (_) {
          verifyNever(
            () => likesRepository.getVoteCounts(
              any(),
              addressableIds: any(named: 'addressableIds'),
            ),
          );
        },
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'still selects a comment when vote counts fail',
        setUp: () {
          stubComments([_comment('only')]);
          when(
            () => likesRepository.getVoteCounts(
              any(),
              addressableIds: any(named: 'addressableIds'),
            ),
          ).thenThrow(const LikesRepositoryException('offline'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        errors: () => [isA<LikesRepositoryException>()],
        expect: () => [
          isA<FeedTopCommentState>()
              .having((s) => s.status, 'status', FeedTopCommentStatus.ready)
              .having((s) => s.topComment?.id, 'topComment', 'only'),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'fails without reporting when comments cannot load',
        setUp: () {
          when(
            () => commentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
            ),
          ).thenThrow(const LoadCommentsFailedException('boom'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        errors: () => [isA<LoadCommentsFailedException>()],
        expect: () => [
          isA<FeedTopCommentState>().having(
            (s) => s.status,
            'status',
            FeedTopCommentStatus.failure,
          ),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'reports an unexpected load failure',
        setUp: () {
          when(
            () => commentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
            ),
          ).thenThrow(StateError('invariant'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        errors: () => [isA<Reportable<Object>>()],
        expect: () => [
          isA<FeedTopCommentState>().having(
            (s) => s.status,
            'status',
            FeedTopCommentStatus.failure,
          ),
        ],
      );
    });

    group('isOverlayVisible', () {
      setUp(() {
        stubComments([_comment('only')]);
        stubUpvotes({});
      });

      test('stays hidden until the first loop finishes', () async {
        final cubit = buildCubit();
        await cubit.load();
        expect(cubit.state.status, FeedTopCommentStatus.ready);
        expect(cubit.state.isOverlayVisible, isFalse);

        loops.add(null);
        await pumpEventQueue();
        expect(cubit.state.isOverlayVisible, isTrue);
        await cubit.close();
      });

      test('shows once loaded when the loop finished first', () async {
        final cubit = buildCubit();
        loops.add(null);
        await pumpEventQueue();
        expect(cubit.state.hasCompletedLoop, isTrue);
        expect(cubit.state.isOverlayVisible, isFalse);

        await cubit.load();
        expect(cubit.state.isOverlayVisible, isTrue);
        await cubit.close();
      });

      test('stays hidden after dismiss, across later loops', () async {
        final cubit = buildCubit();
        await cubit.load();
        loops.add(null);
        await pumpEventQueue();
        expect(cubit.state.isOverlayVisible, isTrue);

        cubit.dismiss();
        loops.add(null);
        await pumpEventQueue();
        expect(cubit.state.isOverlayVisible, isFalse);
        await cubit.close();
      });
    });
  });
}
