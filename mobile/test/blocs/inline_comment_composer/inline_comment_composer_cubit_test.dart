// ABOUTME: Tests for InlineCommentComposerCubit — the publish flow behind
// ABOUTME: the inline comment bar at the bottom of the fullscreen feed.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/inline_comment_composer/inline_comment_composer_cubit.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

void main() {
  group(InlineCommentComposerCubit, () {
    late _MockCommentsRepository commentsRepository;

    VideoEvent buildVideo({
      String id = 'video-id',
      String pubkey = 'author-pubkey',
    }) {
      final now = DateTime.now();
      return VideoEvent(
        id: id,
        pubkey: pubkey,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'caption',
        videoUrl: 'https://example.com/v.mp4',
      );
    }

    Comment buildComment() {
      return Comment(
        id: 'comment-id',
        content: 'hello world',
        authorPubkey: 'commenter-pubkey',
        createdAt: DateTime.now(),
        rootEventId: 'video-id',
        rootAuthorPubkey: 'author-pubkey',
      );
    }

    setUp(() {
      commentsRepository = _MockCommentsRepository();
    });

    test('starts in idle status', () {
      final cubit = InlineCommentComposerCubit(
        commentsRepository: commentsRepository,
      );
      addTearDown(cubit.close);
      expect(cubit.state.status, InlineCommentComposerStatus.idle);
    });

    group('submit', () {
      blocTest<InlineCommentComposerCubit, InlineCommentComposerState>(
        'emits [submitting, submitted] on successful publish',
        setUp: () {
          when(
            () => commentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
            ),
          ).thenAnswer((_) async => buildComment());
        },
        build: () => InlineCommentComposerCubit(
          commentsRepository: commentsRepository,
        ),
        act: (cubit) =>
            cubit.submit(video: buildVideo(), content: 'hello world'),
        expect: () => const [
          InlineCommentComposerState(
            status: InlineCommentComposerStatus.submitting,
          ),
          InlineCommentComposerState(
            status: InlineCommentComposerStatus.submitted,
          ),
        ],
        verify: (_) {
          verify(
            () => commentsRepository.postComment(
              content: 'hello world',
              rootEventId: 'video-id',
              rootEventKind: NIP71VideoKinds.addressableShortVideo,
              rootEventAuthorPubkey: 'author-pubkey',
              rootAddressableId: any(named: 'rootAddressableId'),
            ),
          ).called(1);
        },
      );

      blocTest<InlineCommentComposerCubit, InlineCommentComposerState>(
        'trims whitespace before publishing',
        setUp: () {
          when(
            () => commentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
            ),
          ).thenAnswer((_) async => buildComment());
        },
        build: () => InlineCommentComposerCubit(
          commentsRepository: commentsRepository,
        ),
        act: (cubit) =>
            cubit.submit(video: buildVideo(), content: '   hi there  \n'),
        verify: (_) {
          verify(
            () => commentsRepository.postComment(
              content: 'hi there',
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
            ),
          ).called(1);
        },
      );

      blocTest<InlineCommentComposerCubit, InlineCommentComposerState>(
        'is a no-op for empty / whitespace-only content',
        build: () => InlineCommentComposerCubit(
          commentsRepository: commentsRepository,
        ),
        act: (cubit) async {
          await cubit.submit(video: buildVideo(), content: '');
          await cubit.submit(video: buildVideo(), content: '   ');
          await cubit.submit(video: buildVideo(), content: '\n\t');
        },
        expect: () => <InlineCommentComposerState>[],
        verify: (_) {
          verifyNever(
            () => commentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
            ),
          );
        },
      );

      blocTest<InlineCommentComposerCubit, InlineCommentComposerState>(
        'emits [submitting, failure] when the repository throws',
        setUp: () {
          when(
            () => commentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
            ),
          ).thenThrow(
            const PostCommentFailedException('Failed to publish comment'),
          );
        },
        build: () => InlineCommentComposerCubit(
          commentsRepository: commentsRepository,
        ),
        act: (cubit) => cubit.submit(video: buildVideo(), content: 'oops'),
        expect: () => const [
          InlineCommentComposerState(
            status: InlineCommentComposerStatus.submitting,
          ),
          InlineCommentComposerState(
            status: InlineCommentComposerStatus.failure,
          ),
        ],
        errors: () => [isA<PostCommentFailedException>()],
      );

      test('drops re-entrant submits while one is in flight', () async {
        final publishResult = Completer<Comment>();
        when(
          () => commentsRepository.postComment(
            content: any(named: 'content'),
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
            rootAddressableId: any(named: 'rootAddressableId'),
          ),
        ).thenAnswer((_) => publishResult.future);
        final cubit = InlineCommentComposerCubit(
          commentsRepository: commentsRepository,
        );
        final firstSubmit = cubit.submit(video: buildVideo(), content: 'first');
        Future<void>? secondSubmit;
        try {
          expect(cubit.state.status, InlineCommentComposerStatus.submitting);
          secondSubmit = cubit.submit(video: buildVideo(), content: 'second');
          await pumpEventQueue();

          expect(cubit.state.status, InlineCommentComposerStatus.submitting);
          verifyNever(
            () => commentsRepository.postComment(
              content: 'second',
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
            ),
          );

          publishResult.complete(buildComment());
          await firstSubmit;
          await secondSubmit;
          expect(cubit.state.status, InlineCommentComposerStatus.submitted);
          verify(
            () => commentsRepository.postComment(
              content: 'first',
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
            ),
          ).called(1);
          verifyNever(
            () => commentsRepository.postComment(
              content: 'second',
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
            ),
          );
        } finally {
          if (!publishResult.isCompleted) {
            publishResult.complete(buildComment());
          }
          await firstSubmit;
          await secondSubmit;
          await cubit.close();
        }
      });
    });

    group('acknowledge', () {
      blocTest<InlineCommentComposerCubit, InlineCommentComposerState>(
        'returns to idle from submitted',
        seed: () => const InlineCommentComposerState(
          status: InlineCommentComposerStatus.submitted,
        ),
        build: () => InlineCommentComposerCubit(
          commentsRepository: commentsRepository,
        ),
        act: (cubit) => cubit.acknowledge(),
        expect: () => const [InlineCommentComposerState()],
      );

      blocTest<InlineCommentComposerCubit, InlineCommentComposerState>(
        'returns to idle from failure',
        seed: () => const InlineCommentComposerState(
          status: InlineCommentComposerStatus.failure,
        ),
        build: () => InlineCommentComposerCubit(
          commentsRepository: commentsRepository,
        ),
        act: (cubit) => cubit.acknowledge(),
        expect: () => const [InlineCommentComposerState()],
      );

      blocTest<InlineCommentComposerCubit, InlineCommentComposerState>(
        'is a no-op when already idle',
        build: () => InlineCommentComposerCubit(
          commentsRepository: commentsRepository,
        ),
        act: (cubit) => cubit.acknowledge(),
        expect: () => <InlineCommentComposerState>[],
      );
    });
  });
}
