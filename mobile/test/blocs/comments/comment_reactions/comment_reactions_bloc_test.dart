// ABOUTME: Tests for CommentReactionsBloc — votes (up/down/switch), vote-count
// ABOUTME: batch fetch, block (with outbox), delete (with outbox).
// ABOUTME: Asserts #4478 cache-fix: rootAddressableId threaded into
// ABOUTME: CommentsRepository.deleteComment. Pins #8168: an action on one
// ABOUTME: target is never dropped while another target's is in flight.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group(CommentReactionsBloc, () {
    late _MockCommentsRepository mockCommentsRepository;
    late _MockAuthService mockAuthService;
    late _MockLikesRepository mockLikesRepository;
    late _MockContentBlocklistRepository mockContentBlocklistRepository;

    String validId(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() {
      mockCommentsRepository = _MockCommentsRepository();
      mockAuthService = _MockAuthService();
      mockLikesRepository = _MockLikesRepository();
      mockContentBlocklistRepository = _MockContentBlocklistRepository();

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(validId('currentuser'));

      when(() => mockLikesRepository.getVoteCounts(any())).thenAnswer(
        (_) async => (upvotes: <String, int>{}, downvotes: <String, int>{}),
      );
      when(() => mockLikesRepository.getUserVoteStatuses(any())).thenAnswer(
        (_) async => (upvotedIds: <String>{}, downvotedIds: <String>{}),
      );
    });

    CommentReactionsBloc createBloc({String? rootAddressableId}) =>
        CommentReactionsBloc(
          authService: mockAuthService,
          likesRepository: mockLikesRepository,
          commentsRepository: mockCommentsRepository,
          contentBlocklistRepository: mockContentBlocklistRepository,
          rootEventId: validId('root'),
          rootAddressableId: rootAddressableId,
        );

    test('initial state is empty', () async {
      final bloc = createBloc();
      expect(bloc.state.commentUpvoteCounts, isEmpty);
      expect(bloc.state.commentDownvoteCounts, isEmpty);
      expect(bloc.state.upvotedCommentIds, isEmpty);
      expect(bloc.state.downvotedCommentIds, isEmpty);
      expect(bloc.state.error, isNull);
      expect(bloc.state.outbox, isNull);
      await bloc.close();
    });

    group('CommentVoteCountsFetchRequested', () {
      test('publishes totals while the viewer vote is still loading', () async {
        final id = validId('c1');
        final viewerVote =
            Completer<({Set<String> upvotedIds, Set<String> downvotedIds})>();
        when(() => mockLikesRepository.getVoteCounts([id])).thenAnswer(
          (_) async => (upvotes: {id: 4}, downvotes: {id: 2}),
        );
        when(() => mockLikesRepository.getUserVoteStatuses([id])).thenAnswer(
          (_) => viewerVote.future,
        );

        final bloc = createBloc();
        addTearDown(() async {
          if (!viewerVote.isCompleted) {
            viewerVote.complete((upvotedIds: {id}, downvotedIds: <String>{}));
          }
          await bloc.close();
        });
        bloc.add(CommentVoteCountsFetchRequested([id]));
        await pumpEventQueue();

        expect(bloc.state.commentUpvoteCounts[id], 4);
        expect(bloc.state.commentDownvoteCounts[id], 2);
        expect(bloc.state.upvotedCommentIds, isEmpty);

        viewerVote.complete((upvotedIds: {id}, downvotedIds: <String>{}));
        await pumpEventQueue();

        expect(bloc.state.upvotedCommentIds, {id});
      });

      test('a new batch keeps earlier vote reads in flight', () async {
        final firstId = validId('c1');
        final secondId = validId('c2');
        final first =
            Completer<
              ({Map<String, int> upvotes, Map<String, int> downvotes})
            >();
        when(() => mockLikesRepository.getVoteCounts([firstId])).thenAnswer(
          (_) => first.future,
        );
        when(() => mockLikesRepository.getVoteCounts([secondId])).thenAnswer(
          (_) async => (upvotes: {secondId: 2}, downvotes: <String, int>{}),
        );
        // The previous handler re-queried the earlier id with each new batch.
        when(
          () => mockLikesRepository.getVoteCounts([firstId, secondId]),
        ).thenAnswer(
          (_) async => (upvotes: {secondId: 2}, downvotes: <String, int>{}),
        );

        final bloc = createBloc();
        addTearDown(() async {
          if (!first.isCompleted) {
            first.complete((upvotes: {firstId: 4}, downvotes: <String, int>{}));
          }
          await bloc.close();
        });
        bloc.add(CommentVoteCountsFetchRequested([firstId]));
        await pumpEventQueue();
        bloc.add(CommentVoteCountsFetchRequested([firstId, secondId]));
        await pumpEventQueue();

        expect(bloc.state.commentUpvoteCounts[secondId], 2);

        first.complete((upvotes: {firstId: 4}, downvotes: <String, int>{}));
        await pumpEventQueue();

        expect(bloc.state.commentUpvoteCounts, {firstId: 4, secondId: 2});
        verifyNever(
          () => mockLikesRepository.getVoteCounts([firstId, secondId]),
        );
      });

      for (final succeeds in [true, false]) {
        test(
          'refreshes totals after an early vote, succeeds: $succeeds',
          () async {
            final id = validId('c1');
            final initialCounts =
                Completer<
                  ({Map<String, int> upvotes, Map<String, int> downvotes})
                >();
            final publish = Completer<String>();
            var reads = 0;
            when(() => mockLikesRepository.getVoteCounts([id])).thenAnswer(
              (_) async {
                reads++;
                if (reads == 1) return initialCounts.future;
                return (upvotes: {id: succeeds ? 21 : 20}, downvotes: {id: 5});
              },
            );
            when(
              () => mockLikesRepository.likeEvent(
                eventId: any(named: 'eventId'),
                authorPubkey: any(named: 'authorPubkey'),
                targetKind: any(named: 'targetKind'),
              ),
            ).thenAnswer((_) => publish.future);

            final bloc = createBloc();
            addTearDown(bloc.close);
            bloc.add(CommentVoteCountsFetchRequested([id]));
            await pumpEventQueue();
            bloc.add(
              CommentVoteToggled(
                commentId: id,
                authorPubkey: validId('author1'),
                vote: Vote.up,
              ),
            );
            await pumpEventQueue();

            if (succeeds) {
              // The read returns while publishing. Refresh waits for publish.
              initialCounts.complete((upvotes: {id: 20}, downvotes: {id: 5}));
              await pumpEventQueue();
              expect(reads, 1);
              // The stale read is dropped, and no total is guessed meanwhile.
              expect(bloc.state.commentUpvoteCounts[id], isNull);
              publish.complete(validId('vote'));
            } else {
              // Rollback can finish before the invalidated read returns.
              publish.completeError(const LikesRepositoryException('offline'));
              await pumpEventQueue();
              initialCounts.complete((upvotes: {id: 20}, downvotes: {id: 5}));
            }
            await pumpEventQueue();

            expect(reads, 2);
            expect(bloc.state.commentUpvoteCounts[id], succeeds ? 21 : 20);
            expect(bloc.state.commentDownvoteCounts[id], 5);
            expect(bloc.state.upvotedCommentIds.contains(id), succeeds);
          },
        );
      }

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'populates counts and statuses from likes repo',
        setUp: () {
          when(() => mockLikesRepository.getVoteCounts(any())).thenAnswer(
            (_) async =>
                (upvotes: {validId('c1'): 5}, downvotes: {validId('c1'): 1}),
          );
          when(() => mockLikesRepository.getUserVoteStatuses(any())).thenAnswer(
            (_) async =>
                (upvotedIds: {validId('c1')}, downvotedIds: <String>{}),
          );
        },
        build: createBloc,
        act: (b) => b.add(CommentVoteCountsFetchRequested([validId('c1')])),
        expect: () => [
          isA<CommentReactionsState>()
              .having((s) => s.commentUpvoteCounts[validId('c1')], 'up', 5)
              .having((s) => s.commentDownvoteCounts[validId('c1')], 'down', 1),
          isA<CommentReactionsState>()
              .having((s) => s.commentUpvoteCounts[validId('c1')], 'up', 5)
              .having(
                (s) => s.upvotedCommentIds.contains(validId('c1')),
                'isUpvoted',
                true,
              ),
        ],
      );

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'forwards the coordinates to both read paths (#6124)',
        setUp: () {
          when(
            () => mockLikesRepository.getVoteCounts(
              any(),
              addressableIds: any(named: 'addressableIds'),
            ),
          ).thenAnswer(
            (_) async => (upvotes: <String, int>{}, downvotes: <String, int>{}),
          );
          when(
            () => mockLikesRepository.getUserVoteStatuses(
              any(),
              addressableIds: any(named: 'addressableIds'),
            ),
          ).thenAnswer(
            (_) async => (upvotedIds: <String>{}, downvotedIds: <String>{}),
          );
        },
        build: createBloc,
        act: (b) => b.add(
          CommentVoteCountsFetchRequested(
            [validId('c1')],
            addressableIdsByCommentId: {
              validId('c1'): '34236:${validId('author1')}:reply-d',
            },
          ),
        ),
        verify: (_) {
          // Both reads are e-only without this; a vote on an edited video
          // reply then reads as zero for the counts and unvoted for the arrow.
          final expected = {
            validId('c1'): '34236:${validId('author1')}:reply-d',
          };
          verify(
            () => mockLikesRepository.getVoteCounts([
              validId('c1'),
            ], addressableIds: expected),
          ).called(1);
          verify(
            () => mockLikesRepository.getUserVoteStatuses([
              validId('c1'),
            ], addressableIds: expected),
          ).called(1);
        },
      );

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'no-ops when commentIds is empty',
        build: createBloc,
        act: (b) => b.add(const CommentVoteCountsFetchRequested([])),
        expect: () => isEmpty,
      );

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'reports a failure from each read, not only the first',
        setUp: () {
          when(
            () => mockLikesRepository.getVoteCounts(any()),
          ).thenThrow(const LikesRepositoryException('offline'));
          when(
            () => mockLikesRepository.getUserVoteStatuses(any()),
          ).thenThrow(StateError('malformed vote status'));
        },
        build: createBloc,
        act: (b) => b.add(CommentVoteCountsFetchRequested([validId('c1')])),
        errors: () => [
          isA<LikesRepositoryException>(),
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );
    });

    group('CommentVoteToggled (upvote)', () {
      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'optimistically adds upvote then publishes via LikesRepository',
        setUp: () {
          when(
            () => mockLikesRepository.likeEvent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer((_) async => 'like-event-id');
        },
        build: createBloc,
        seed: () => CommentReactionsState(
          commentUpvoteCounts: {validId('c1'): 4},
          commentDownvoteCounts: {validId('c1'): 0},
        ),
        act: (b) => b.add(
          CommentVoteToggled(
            commentId: validId('c1'),
            authorPubkey: validId('author1'),
            vote: Vote.up,
          ),
        ),
        expect: () => [
          isA<CommentReactionsState>()
              .having(
                (s) => s.upvotedCommentIds.contains(validId('c1')),
                'isUpvoted',
                true,
              )
              .having((s) => s.commentUpvoteCounts[validId('c1')], 'up', 5),
        ],
        verify: (_) {
          verify(
            () => mockLikesRepository.likeEvent(
              eventId: validId('c1'),
              authorPubkey: validId('author1'),
              targetKind: any(named: 'targetKind'),
            ),
          ).called(1);
        },
      );

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'reverts optimistic and emits voteFailed on LikesRepository throw',
        setUp: () {
          when(
            () => mockLikesRepository.likeEvent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenThrow(const LikesRepositoryException('publish failed'));
        },
        build: createBloc,
        act: (b) => b.add(
          CommentVoteToggled(
            commentId: validId('c2'),
            authorPubkey: validId('author2'),
            vote: Vote.up,
          ),
        ),
        errors: () => [isA<LikesRepositoryException>()],
        expect: () => [
          isA<CommentReactionsState>().having(
            (s) => s.upvotedCommentIds.contains(validId('c2')),
            'optimistic added',
            true,
          ),
          isA<CommentReactionsState>()
              .having(
                (s) => s.upvotedCommentIds.contains(validId('c2')),
                'reverted',
                false,
              )
              .having((s) => s.error, 'error', ReactionsError.voteFailed),
        ],
      );

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'silently reconciles on AlreadyLikedException without emitting error',
        setUp: () {
          when(
            () => mockLikesRepository.likeEvent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenThrow(const AlreadyLikedException('already liked'));
        },
        build: createBloc,
        act: (b) => b.add(
          CommentVoteToggled(
            commentId: validId('c3'),
            authorPubkey: validId('author3'),
            vote: Vote.up,
          ),
        ),
        errors: () => isEmpty,
        verify: (b) {
          expect(b.state.error, isNull);
          expect(b.state.upvotedCommentIds.contains(validId('c3')), isTrue);
        },
      );
    });

    group('CommentVoteToggled (unknown totals)', () {
      void stubLike(Future<String> Function() answer) {
        when(
          () => mockLikesRepository.likeEvent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) => answer());
      }

      test('shows no guessed total, then reads both after the vote', () async {
        final id = validId('c1');
        final publish = Completer<String>();
        stubLike(() => publish.future);
        when(() => mockLikesRepository.getVoteCounts([id])).thenAnswer(
          (_) async => (upvotes: {id: 8}, downvotes: {id: 2}),
        );

        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(
          CommentVoteToggled(
            commentId: id,
            authorPubkey: validId('author1'),
            vote: Vote.up,
          ),
        );
        await pumpEventQueue();

        expect(bloc.state.upvotedCommentIds, {id});
        expect(bloc.state.commentUpvoteCounts, isNot(contains(id)));
        expect(bloc.state.commentDownvoteCounts, isNot(contains(id)));
        verifyNever(() => mockLikesRepository.getVoteCounts([id]));

        publish.complete(validId('vote'));
        await pumpEventQueue();

        expect(bloc.state.commentUpvoteCounts[id], 8);
        expect(bloc.state.commentDownvoteCounts[id], 2);
        expect(bloc.state.upvotedCommentIds, {id});
      });

      test('a failed vote leaves an unread total unread', () async {
        final id = validId('c1');
        stubLike(
          () => Future.error(const LikesRepositoryException('offline')),
        );
        when(
          () => mockLikesRepository.getVoteCounts([id]),
        ).thenThrow(const LikesRepositoryException('offline'));

        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(
          CommentVoteToggled(
            commentId: id,
            authorPubkey: validId('author1'),
            vote: Vote.up,
          ),
        );
        await pumpEventQueue();

        expect(bloc.state.error, ReactionsError.voteFailed);
        expect(bloc.state.upvotedCommentIds, isEmpty);
        // Both totals were unknown before the tap; a rollback to 0 would
        // render "0" on both arrows and stop the list asking again.
        expect(bloc.state.commentUpvoteCounts, isNot(contains(id)));
        expect(bloc.state.commentDownvoteCounts, isNot(contains(id)));
        verify(() => mockLikesRepository.getVoteCounts([id])).called(1);
      });
    });

    group('CommentVoteToggled (downvote)', () {
      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'optimistically adds downvote then publishes',
        setUp: () {
          when(
            () => mockLikesRepository.downvoteEvent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer((_) async => 'downvote-event-id');
        },
        build: createBloc,
        act: (b) => b.add(
          CommentVoteToggled(
            commentId: validId('c1'),
            authorPubkey: validId('author1'),
            vote: Vote.down,
          ),
        ),
        expect: () => [
          isA<CommentReactionsState>().having(
            (s) => s.downvotedCommentIds.contains(validId('c1')),
            'isDownvoted',
            true,
          ),
        ],
        verify: (_) {
          verify(
            () => mockLikesRepository.downvoteEvent(
              eventId: validId('c1'),
              authorPubkey: validId('author1'),
              targetKind: any(named: 'targetKind'),
            ),
          ).called(1);
        },
      );
    });

    group('CommentVoteToggled (vote switch)', () {
      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'removes upvote and applies downvote when switching',
        setUp: () {
          when(
            () => mockLikesRepository.unlikeEvent(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockLikesRepository.downvoteEvent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer((_) async => 'downvote-event-id');
        },
        build: createBloc,
        seed: () => CommentReactionsState(
          upvotedCommentIds: {validId('c1')},
          commentUpvoteCounts: {validId('c1'): 3},
        ),
        act: (b) => b.add(
          CommentVoteToggled(
            commentId: validId('c1'),
            authorPubkey: validId('author1'),
            vote: Vote.down,
          ),
        ),
        verify: (b) {
          expect(b.state.upvotedCommentIds.contains(validId('c1')), isFalse);
          expect(b.state.downvotedCommentIds.contains(validId('c1')), isTrue);
          verify(
            () => mockLikesRepository.unlikeEvent(validId('c1')),
          ).called(1);
          verify(
            () => mockLikesRepository.downvoteEvent(
              eventId: validId('c1'),
              authorPubkey: validId('author1'),
              targetKind: any(named: 'targetKind'),
            ),
          ).called(1);
        },
      );

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'tags a video-reply vote with its OWN coordinate and real kind '
        '(#6124)',
        setUp: () {
          when(
            () => mockLikesRepository.downvoteEvent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              targetKind: any(named: 'targetKind'),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer((_) async => 'downvote-event-id');
        },
        build: createBloc,
        act: (b) => b.add(
          CommentVoteToggled(
            commentId: validId('c1'),
            authorPubkey: validId('author1'),
            vote: Vote.down,
            addressableId: '34236:${validId('author1')}:reply-d',
            targetKind: 34236,
          ),
        ),
        verify: (_) {
          // The parent video's coordinate must never be used here: funnelcake
          // counts kind-7 by a-tag with no content filter, so it would inflate
          // the parent's public reaction_count.
          verify(
            () => mockLikesRepository.downvoteEvent(
              eventId: validId('c1'),
              authorPubkey: validId('author1'),
              targetKind: 34236,
              addressableId: '34236:${validId('author1')}:reply-d',
            ),
          ).called(1);
        },
      );

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'tears down an upvote by coordinate when switching to a downvote '
        '(#6124)',
        setUp: () {
          when(
            () => mockLikesRepository.unlikeEvent(
              any(),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockLikesRepository.downvoteEvent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              targetKind: any(named: 'targetKind'),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer((_) async => 'downvote-event-id');
        },
        build: createBloc,
        seed: () => CommentReactionsState(
          upvotedCommentIds: {validId('c1')},
          commentUpvoteCounts: {validId('c1'): 3},
        ),
        act: (b) => b.add(
          CommentVoteToggled(
            commentId: validId('c1'),
            authorPubkey: validId('author1'),
            vote: Vote.down,
            addressableId: '34236:${validId('author1')}:reply-d',
            targetKind: 34236,
          ),
        ),
        verify: (_) {
          // Symmetric with removeDownvote: an edited target answers to a new
          // event id, so an id-only teardown throws NotLikedException and
          // strands the upvote reaction.
          verify(
            () => mockLikesRepository.unlikeEvent(
              validId('c1'),
              addressableId: '34236:${validId('author1')}:reply-d',
            ),
          ).called(1);
        },
      );

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'falls back to kind 1111 and no coordinate for a plain comment '
        '(#6124)',
        setUp: () {
          when(
            () => mockLikesRepository.likeEvent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              targetKind: any(named: 'targetKind'),
              addressableId: any(named: 'addressableId'),
            ),
          ).thenAnswer((_) async => 'like-event-id');
        },
        build: createBloc,
        act: (b) => b.add(
          CommentVoteToggled(
            commentId: validId('c1'),
            authorPubkey: validId('author1'),
            vote: Vote.up,
          ),
        ),
        verify: (_) {
          // Captured rather than matched inline: passing `addressableId: null`
          // to verify() reads as a redundant default, but the null IS the
          // assertion — a Kind 1111 comment has no coordinate to send.
          final captured = verify(
            () => mockLikesRepository.likeEvent(
              eventId: validId('c1'),
              authorPubkey: validId('author1'),
              targetKind: 1111,
              addressableId: captureAny(named: 'addressableId'),
            ),
          ).captured;
          expect(captured, hasLength(1));
          expect(captured.single, isNull);
        },
      );

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'still publishes the upvote when the downvote teardown reports none '
        '(#6124)',
        setUp: () {
          // Downvotes live only in memory, so after a cold start the teardown
          // of a pre-restart downvote reports "not downvoted". That must not
          // abort the upvote — previously it threw past the likeEvent call and
          // the UI showed an upvote that was never published.
          when(
            () => mockLikesRepository.removeDownvote(any()),
          ).thenThrow(NotDownvotedException(validId('c1')));
          when(
            () => mockLikesRepository.likeEvent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer((_) async => 'like-event-id');
        },
        build: createBloc,
        seed: () => CommentReactionsState(
          downvotedCommentIds: {validId('c1')},
          commentDownvoteCounts: {validId('c1'): 2},
        ),
        act: (b) => b.add(
          CommentVoteToggled(
            commentId: validId('c1'),
            authorPubkey: validId('author1'),
            vote: Vote.up,
          ),
        ),
        verify: (b) {
          verify(
            () => mockLikesRepository.likeEvent(
              eventId: validId('c1'),
              authorPubkey: validId('author1'),
              targetKind: any(named: 'targetKind'),
            ),
          ).called(1);
          expect(b.state.upvotedCommentIds.contains(validId('c1')), isTrue);
          expect(b.state.downvotedCommentIds.contains(validId('c1')), isFalse);
          expect(b.state.error, isNull);
        },
      );
    });

    group('CommentBlockUserRequested', () {
      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'blocks user and emits ReactionsOutboxRemoveByAuthor',
        setUp: () {
          when(
            () => mockContentBlocklistRepository.blockUser(any()),
          ).thenAnswer((_) async => true);
        },
        build: createBloc,
        act: (b) => b.add(CommentBlockUserRequested(validId('blocked'))),
        verify: (b) {
          verify(
            () => mockContentBlocklistRepository.blockUser(validId('blocked')),
          ).called(1);
          expect(b.state.outbox, isA<ReactionsOutboxRemoveByAuthor>());
          expect(
            (b.state.outbox! as ReactionsOutboxRemoveByAuthor).authorPubkey,
            validId('blocked'),
          );
        },
      );

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'emits blockFailed when block throws',
        setUp: () {
          when(
            () => mockContentBlocklistRepository.blockUser(any()),
          ).thenThrow(Exception('block io error'));
        },
        build: createBloc,
        act: (b) => b.add(CommentBlockUserRequested(validId('blocked'))),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<CommentReactionsState>().having(
            (s) => s.error,
            'error',
            ReactionsError.blockFailed,
          ),
        ],
      );
    });

    group('CommentDeleteRequested', () {
      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'deletes via repo and emits ReactionsOutboxRemoveComment',
        setUp: () {
          when(
            () => mockCommentsRepository.deleteComment(
              commentId: any(named: 'commentId'),
              rootEventId: any(named: 'rootEventId'),
              rootAddressableId: any(named: 'rootAddressableId'),
            ),
          ).thenAnswer((_) async {});
        },
        build: () => createBloc(rootAddressableId: 'fake-address'),
        act: (b) => b.add(CommentDeleteRequested(validId('c1'))),
        verify: (b) {
          // #4478 — rootAddressableId must be threaded to deleteComment.
          verify(
            () => mockCommentsRepository.deleteComment(
              commentId: validId('c1'),
              rootEventId: validId('root'),
              rootAddressableId: 'fake-address',
            ),
          ).called(1);
          expect(b.state.outbox, isA<ReactionsOutboxRemoveComment>());
          expect(
            (b.state.outbox! as ReactionsOutboxRemoveComment).commentId,
            validId('c1'),
          );
        },
      );

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'emits notAuthenticated when not signed in',
        setUp: () {
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
        },
        build: createBloc,
        act: (b) => b.add(CommentDeleteRequested(validId('c1'))),
        expect: () => [
          isA<CommentReactionsState>().having(
            (s) => s.error,
            'error',
            ReactionsError.notAuthenticated,
          ),
        ],
      );

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'emits deleteCommentFailed when repo throws',
        setUp: () {
          when(
            () => mockCommentsRepository.deleteComment(
              commentId: any(named: 'commentId'),
              rootEventId: any(named: 'rootEventId'),
              rootAddressableId: any(named: 'rootAddressableId'),
            ),
          ).thenThrow(const DeleteCommentFailedException('relay error'));
        },
        build: createBloc,
        act: (b) => b.add(CommentDeleteRequested(validId('c1'))),
        errors: () => [isA<DeleteCommentFailedException>()],
        expect: () => [
          isA<CommentReactionsState>().having(
            (s) => s.error,
            'error',
            ReactionsError.deleteCommentFailed,
          ),
        ],
      );
    });

    group('actions on a second target while the first is in flight', () {
      test('a vote on another comment publishes without waiting', () async {
        final firstPublish = Completer<String>();
        when(
          () => mockLikesRepository.likeEvent(
            eventId: validId('c1'),
            authorPubkey: any(named: 'authorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) => firstPublish.future);
        when(
          () => mockLikesRepository.likeEvent(
            eventId: validId('c2'),
            authorPubkey: any(named: 'authorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => 'like-c2');
        final bloc = createBloc();
        addTearDown(() async {
          if (!firstPublish.isCompleted) firstPublish.complete('like-c1');
          await bloc.close();
        });

        bloc
          ..add(
            CommentVoteToggled(
              commentId: validId('c1'),
              authorPubkey: validId('author1'),
              vote: Vote.up,
            ),
          )
          ..add(
            CommentVoteToggled(
              commentId: validId('c2'),
              authorPubkey: validId('author2'),
              vote: Vote.up,
            ),
          );
        await pumpEventQueue();

        verify(
          () => mockLikesRepository.likeEvent(
            eventId: validId('c2'),
            authorPubkey: validId('author2'),
            targetKind: any(named: 'targetKind'),
          ),
        ).called(1);
        expect(bloc.state.upvotedCommentIds, {validId('c1'), validId('c2')});
      });

      test('a delete of another comment publishes without waiting', () async {
        final firstDelete = Completer<void>();
        when(
          () => mockCommentsRepository.deleteComment(
            commentId: validId('c1'),
            rootEventId: any(named: 'rootEventId'),
            rootAddressableId: any(named: 'rootAddressableId'),
          ),
        ).thenAnswer((_) => firstDelete.future);
        when(
          () => mockCommentsRepository.deleteComment(
            commentId: validId('c2'),
            rootEventId: any(named: 'rootEventId'),
            rootAddressableId: any(named: 'rootAddressableId'),
          ),
        ).thenAnswer((_) async {});
        final bloc = createBloc();
        addTearDown(() async {
          if (!firstDelete.isCompleted) firstDelete.complete();
          await bloc.close();
        });

        bloc
          ..add(CommentDeleteRequested(validId('c1')))
          ..add(CommentDeleteRequested(validId('c2')));
        await pumpEventQueue();

        verify(
          () => mockCommentsRepository.deleteComment(
            commentId: validId('c2'),
            rootEventId: any(named: 'rootEventId'),
            rootAddressableId: any(named: 'rootAddressableId'),
          ),
        ).called(1);
      });

      // The repository skips a comment it already deleted only once the
      // first request has landed, so a repeat must not start before then.
      test('a second delete of the same comment waits for the first', () async {
        final firstDelete = Completer<void>();
        var deleteCalls = 0;
        when(
          () => mockCommentsRepository.deleteComment(
            commentId: validId('c1'),
            rootEventId: any(named: 'rootEventId'),
            rootAddressableId: any(named: 'rootAddressableId'),
          ),
        ).thenAnswer(
          (_) => ++deleteCalls == 1 ? firstDelete.future : Future.value(),
        );
        final bloc = createBloc();
        addTearDown(() async {
          if (!firstDelete.isCompleted) firstDelete.complete();
          await bloc.close();
        });

        bloc
          ..add(CommentDeleteRequested(validId('c1')))
          ..add(CommentDeleteRequested(validId('c1')));
        await pumpEventQueue();
        expect(deleteCalls, equals(1));

        firstDelete.complete();
        await pumpEventQueue();

        expect(deleteCalls, equals(2));
      });

      test('a block of another author runs once the first finishes', () async {
        final firstBlock = Completer<bool>();
        when(
          () => mockContentBlocklistRepository.blockUser(validId('a1')),
        ).thenAnswer((_) => firstBlock.future);
        when(
          () => mockContentBlocklistRepository.blockUser(validId('a2')),
        ).thenAnswer((_) async => true);
        final bloc = createBloc();
        addTearDown(() async {
          if (!firstBlock.isCompleted) firstBlock.complete(true);
          await bloc.close();
        });

        bloc
          ..add(CommentBlockUserRequested(validId('a1')))
          ..add(CommentBlockUserRequested(validId('a2')));
        await pumpEventQueue();
        verifyNever(
          () => mockContentBlocklistRepository.blockUser(validId('a2')),
        );

        firstBlock.complete(true);
        await pumpEventQueue();

        verify(
          () => mockContentBlocklistRepository.blockUser(validId('a2')),
        ).called(1);
      });

      test(
        'a second tap on the same comment undoes the vote after it lands',
        () async {
          final firstPublish = Completer<String>();
          when(
            () => mockLikesRepository.likeEvent(
              eventId: validId('c1'),
              authorPubkey: any(named: 'authorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer((_) => firstPublish.future);
          when(
            () => mockLikesRepository.unlikeEvent(validId('c1')),
          ).thenAnswer((_) async {});
          final bloc = createBloc();
          addTearDown(() async {
            if (!firstPublish.isCompleted) firstPublish.complete('like-c1');
            await bloc.close();
          });
          final tap = CommentVoteToggled(
            commentId: validId('c1'),
            authorPubkey: validId('author1'),
            vote: Vote.up,
          );

          bloc
            ..add(tap)
            ..add(tap);
          await pumpEventQueue();
          verifyNever(() => mockLikesRepository.unlikeEvent(validId('c1')));

          firstPublish.complete('like-c1');
          await pumpEventQueue();

          verifyInOrder([
            () => mockLikesRepository.likeEvent(
              eventId: validId('c1'),
              authorPubkey: validId('author1'),
              targetKind: any(named: 'targetKind'),
            ),
            () => mockLikesRepository.unlikeEvent(validId('c1')),
          ]);
          expect(bloc.state.upvotedCommentIds, isEmpty);
        },
      );
    });

    group('ReactionsOutboxConsumed', () {
      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'clears outbox to null',
        build: createBloc,
        seed: () => CommentReactionsState(
          outbox: ReactionsOutboxRemoveComment(validId('c1')),
        ),
        act: (b) => b.add(const ReactionsOutboxConsumed()),
        expect: () => [
          isA<CommentReactionsState>().having(
            (s) => s.outbox,
            'outbox',
            isNull,
          ),
        ],
      );
    });
  });
}
