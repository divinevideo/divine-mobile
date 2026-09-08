// ABOUTME: Tests for CommentReactionsBloc — votes (up/down/switch), vote-count
// ABOUTME: batch fetch, report, block (with outbox), delete (with outbox).
// ABOUTME: Asserts #4478 cache-fix: rootAddressableId threaded into
// ABOUTME: CommentsRepository.deleteComment.

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/content_moderation_types.dart';
import 'package:openvine/services/content_reporting_service.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockContentReportingService extends Mock
    implements ContentReportingService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(ContentFilterReason.spam);
  });

  group(CommentReactionsBloc, () {
    late _MockCommentsRepository mockCommentsRepository;
    late _MockAuthService mockAuthService;
    late _MockLikesRepository mockLikesRepository;
    late _MockContentReportingService mockContentReportingService;
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
      mockContentReportingService = _MockContentReportingService();
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
          contentReportingServiceFuture: Future.value(
            mockContentReportingService,
          ),
          contentBlocklistRepository: mockContentBlocklistRepository,
          rootEventId: validId('root'),
          rootAddressableId: rootAddressableId,
        );

    test('initial state is empty', () {
      final bloc = createBloc();
      expect(bloc.state.commentUpvoteCounts, isEmpty);
      expect(bloc.state.commentDownvoteCounts, isEmpty);
      expect(bloc.state.upvotedCommentIds, isEmpty);
      expect(bloc.state.downvotedCommentIds, isEmpty);
      expect(bloc.state.error, isNull);
      expect(bloc.state.outbox, isNull);
      bloc.close();
    });

    group('CommentVoteCountsFetchRequested', () {
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
              .having((s) => s.commentDownvoteCounts[validId('c1')], 'down', 1)
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
              .having((s) => s.commentUpvoteCounts[validId('c1')], 'up', 1),
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

    group('CommentReportRequested', () {
      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'calls ContentReportingService.reportContent and emits no state',
        setUp: () {
          when(
            () => mockContentReportingService.reportContent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              reason: any(named: 'reason'),
              details: any(named: 'details'),
            ),
          ).thenAnswer(
            (_) async => ReportResult.createSuccess(
              'rid',
              delivery: ReportDelivery.reached,
            ),
          );
        },
        build: createBloc,
        act: (b) => b.add(
          CommentReportRequested(
            commentId: validId('c1'),
            authorPubkey: validId('a1'),
            reason: ContentFilterReason.spam,
          ),
        ),
        expect: () => isEmpty,
        verify: (_) {
          verify(
            () => mockContentReportingService.reportContent(
              eventId: validId('c1'),
              authorPubkey: validId('a1'),
              reason: ContentFilterReason.spam,
              details: any(named: 'details'),
            ),
          ).called(1);
        },
      );

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'emits no error when the report is deliberately refused',
        setUp: () {
          when(
            () => mockContentReportingService.reportContent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              reason: any(named: 'reason'),
              details: any(named: 'details'),
            ),
          ).thenAnswer(
            (_) async => ReportResult.createSuccess(
              'rid',
              delivery: ReportDelivery.refused,
            ),
          );
        },
        build: createBloc,
        act: (b) => b.add(
          CommentReportRequested(
            commentId: validId('c1'),
            authorPubkey: validId('a1'),
            reason: ContentFilterReason.spam,
          ),
        ),
        expect: () => isEmpty,
      );

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'emits reportFailed when reporting throws',
        setUp: () {
          when(
            () => mockContentReportingService.reportContent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              reason: any(named: 'reason'),
              details: any(named: 'details'),
            ),
          ).thenThrow(Exception('boom'));
        },
        build: createBloc,
        act: (b) => b.add(
          CommentReportRequested(
            commentId: validId('c1'),
            authorPubkey: validId('a1'),
            reason: ContentFilterReason.spam,
          ),
        ),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<CommentReactionsState>().having(
            (s) => s.error,
            'error',
            ReactionsError.reportFailed,
          ),
        ],
      );

      // #6595: the sibling test above stubs a throw, which the handler
      // already caught before the fix — so it passed either way. These two
      // stub the shapes reportContent actually produces: a RETURNED failure
      // and a success that reached no channel. Both showed nothing.
      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'emits reportFailed when reporting returns a failure',
        setUp: () {
          when(
            () => mockContentReportingService.reportContent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              reason: any(named: 'reason'),
              details: any(named: 'details'),
            ),
          ).thenAnswer((_) async => ReportResult.failure('Not authenticated'));
        },
        build: createBloc,
        act: (b) => b.add(
          CommentReportRequested(
            commentId: validId('c1'),
            authorPubkey: validId('a1'),
            reason: ContentFilterReason.spam,
          ),
        ),
        expect: () => [
          isA<CommentReactionsState>().having(
            (s) => s.error,
            'error',
            ReactionsError.reportFailed,
          ),
        ],
      );

      blocTest<CommentReactionsBloc, CommentReactionsState>(
        'emits reportFailed when the report reached no channel',
        setUp: () {
          when(
            () => mockContentReportingService.reportContent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              reason: any(named: 'reason'),
              details: any(named: 'details'),
            ),
          ).thenAnswer(
            (_) async => ReportResult.createSuccess(
              'rid',
              delivery: ReportDelivery.localOnly,
            ),
          );
        },
        build: createBloc,
        act: (b) => b.add(
          CommentReportRequested(
            commentId: validId('c1'),
            authorPubkey: validId('a1'),
            reason: ContentFilterReason.spam,
          ),
        ),
        expect: () => [
          isA<CommentReactionsState>().having(
            (s) => s.error,
            'error',
            ReactionsError.reportFailed,
          ),
        ],
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
