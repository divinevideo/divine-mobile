// ABOUTME: Tests that CommentsListBloc holds the Top order still once it is
// ABOUTME: frozen, so a vote never moves a row under the viewer (#10921), and
// ABOUTME: places comments that arrive later above or below the frozen rows.

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

void main() {
  group('$CommentsListBloc Top order', () {
    late _MockCommentsRepository commentsRepository;

    final rootId = 'a' * 64;
    final rootAuthor = 'b' * 64;
    final commenter = 'c' * 64;

    Comment comment(String idChar, int minute, {String? content}) => Comment(
      id: idChar * 64,
      content: content ?? 'comment $idChar',
      authorPubkey: commenter,
      createdAt: DateTime.utc(2026, 11, 13, 10, minute),
      rootEventId: rootId,
      rootAuthorPubkey: rootAuthor,
    );

    final oldest = comment('1', 1);
    final middle = comment('2', 2);
    final newest = comment('3', 3);

    CommentsListState loaded(
      List<Comment> comments, {
      CommentsSortMode sortMode = CommentsSortMode.topEngagement,
      bool isBackfillComplete = true,
    }) => CommentsListState(
      status: CommentsStatus.success,
      rootEventId: rootId,
      rootEventKind: 34236,
      rootAuthorPubkey: rootAuthor,
      commentsById: {for (final c in comments) c.id: c},
      sortMode: sortMode,
      isBackfillComplete: isBackfillComplete,
    );

    CommentsListBloc createBloc() => CommentsListBloc(
      commentsRepository: commentsRepository,
      rootEventId: rootId,
      rootEventKind: 34236,
      rootAuthorPubkey: rootAuthor,
    );

    List<String> order(
      CommentsListState state, {
      Map<String, int> upvotes = const {},
      Map<String, int> downvotes = const {},
    }) => [
      for (final node in state.displayCommentsWith(
        upvoteCounts: upvotes,
        downvoteCounts: downvotes,
      ))
        node.comment.id,
    ];

    setUp(() {
      commentsRepository = _MockCommentsRepository();
      when(
        () => commentsRepository.findAuthorDeletedComments(any()),
      ).thenAnswer((_) async => <String>{});
      when(
        () => commentsRepository.stopWatchingComments(),
      ).thenAnswer((_) async {});
    });

    setUpAll(() {
      registerFallbackValue(<Comment>[]);
    });

    group('CommentsTopOrderFrozen', () {
      blocTest<CommentsListBloc, CommentsListState>(
        'keeps the ranking it was frozen with when the totals change',
        build: createBloc,
        seed: () => loaded([oldest, middle, newest]),
        act: (bloc) => bloc.add(
          CommentsTopOrderFrozen(
            upvoteCounts: {oldest.id: 2},
            downvoteCounts: const {},
          ),
        ),
        verify: (bloc) {
          final frozen = [oldest.id, newest.id, middle.id];
          expect(order(bloc.state, upvotes: {oldest.id: 2}), frozen);
          // The viewer upvotes the last row and downvotes the first.
          expect(
            order(
              bloc.state,
              upvotes: {oldest.id: 2, middle.id: 1},
              downvotes: {oldest.id: 5},
            ),
            frozen,
          );
        },
      );

      // The switch back to Top would clear an order frozen in Recent anyway,
      // so only the state itself shows that none was frozen.
      blocTest<CommentsListBloc, CommentsListState>(
        'does not freeze Top while the list shows Recent',
        build: createBloc,
        seed: () =>
            loaded([oldest, middle, newest], sortMode: CommentsSortMode.newest),
        act: (bloc) => bloc.add(
          CommentsTopOrderFrozen(
            upvoteCounts: {oldest.id: 2},
            downvoteCounts: const {},
          ),
        ),
        expect: () => isEmpty,
        verify: (bloc) => expect(bloc.state.topOrder, isNull),
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'ranks a page loaded later below the rows already placed',
        setUp: () {
          final page = [comment('4', 0), comment('5', 0)];
          when(
            () => commentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
              offset: any(named: 'offset'),
              includeVideoReplies: any(named: 'includeVideoReplies'),
            ),
          ).thenAnswer(
            (_) async => CommentThread(
              rootEventId: rootId,
              comments: page,
              totalCount: 5,
              hasMore: false,
              commentCache: {for (final c in page) c.id: c},
            ),
          );
        },
        build: createBloc,
        seed: () => loaded([oldest, newest]),
        act: (bloc) async {
          bloc.add(
            CommentsTopOrderFrozen(
              upvoteCounts: {oldest.id: 1},
              downvoteCounts: const {},
            ),
          );
          await pumpEventQueue();
          bloc.add(const CommentsLoadMoreRequested());
          await pumpEventQueue();
          // The page's totals land: one of its rows outranks the frozen ones.
          bloc.add(
            CommentsTopOrderFrozen(
              upvoteCounts: {oldest.id: 1, '5' * 64: 9},
              downvoteCounts: const {},
            ),
          );
        },
        verify: (bloc) {
          final frozen = [oldest.id, newest.id, '5' * 64, '4' * 64];
          expect(
            order(bloc.state, upvotes: {oldest.id: 1, '5' * 64: 9}),
            frozen,
          );
          expect(order(bloc.state, upvotes: {'4' * 64: 20}), frozen);
        },
      );
    });

    group('comments that arrive once the order is frozen', () {
      CommentsTopOrderFrozen frozenWith(Map<String, int> upvotes) =>
          CommentsTopOrderFrozen(
            upvoteCounts: upvotes,
            downvoteCounts: const {},
          );

      blocTest<CommentsListBloc, CommentsListState>(
        'puts live comments on top, newest first',
        build: createBloc,
        seed: () => loaded([oldest, middle]),
        act: (bloc) async {
          bloc.add(frozenWith({middle.id: 1}));
          await pumpEventQueue();
          bloc.add(NewCommentsBatchReceived([comment('4', 4)]));
          await pumpEventQueue();
          bloc.add(NewCommentsBatchReceived([comment('5', 5)]));
        },
        verify: (bloc) => expect(order(bloc.state, upvotes: {'4' * 64: 3}), [
          '5' * 64,
          '4' * 64,
          middle.id,
          oldest.id,
        ]),
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'ranks comments the relay backfill brings below the placed rows',
        build: createBloc,
        seed: () => loaded([middle, newest], isBackfillComplete: false),
        act: (bloc) async {
          bloc.add(frozenWith(const {}));
          await pumpEventQueue();
          bloc.add(NewCommentsBatchReceived([oldest]));
          await pumpEventQueue();
          bloc.add(frozenWith({oldest.id: 5}));
        },
        verify: (bloc) => expect(order(bloc.state, upvotes: {oldest.id: 5}), [
          newest.id,
          middle.id,
          oldest.id,
        ]),
      );

      blocTest<CommentsListBloc, CommentsListState>(
        "puts the viewer's own comment on top and keeps it there once posted",
        build: createBloc,
        seed: () => loaded([oldest, middle]),
        act: (bloc) async {
          bloc.add(frozenWith({oldest.id: 2}));
          await pumpEventQueue();
          final placeholder = comment('p', 9).copyWith(
            id: 'pending_comment_own',
          );
          bloc.add(OptimisticCommentInserted(placeholder));
          await pumpEventQueue();
          bloc.add(
            OptimisticCommentConfirmed(
              placeholderId: placeholder.id,
              confirmed: comment('9', 9),
            ),
          );
        },
        verify: (bloc) => expect(order(bloc.state, upvotes: {oldest.id: 2}), [
          '9' * 64,
          oldest.id,
          middle.id,
        ]),
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'keeps an edited comment where the original was',
        build: createBloc,
        seed: () => loaded([oldest, middle, newest]),
        act: (bloc) async {
          bloc.add(frozenWith({middle.id: 3}));
          await pumpEventQueue();
          bloc.add(
            CommentReplacedInStore(
              oldId: middle.id,
              newComment: comment('7', 7, content: 'edited'),
            ),
          );
        },
        // Ranked live, the upvoted newest comment would rise above it.
        verify: (bloc) => expect(order(bloc.state, upvotes: {newest.id: 1}), [
          '7' * 64,
          newest.id,
          oldest.id,
        ]),
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'closes the gap a removed comment leaves',
        build: createBloc,
        seed: () => loaded([oldest, middle, newest]),
        act: (bloc) async {
          bloc.add(frozenWith({oldest.id: 3}));
          await pumpEventQueue();
          bloc.add(CommentRemovedFromStore(newest.id));
        },
        verify: (bloc) {
          expect(bloc.state.topOrder, [oldest.id, middle.id]);
          expect(order(bloc.state, upvotes: {middle.id: 9}), [
            oldest.id,
            middle.id,
          ]);
        },
      );
    });

    group('CommentsSortModeChanged', () {
      blocTest<CommentsListBloc, CommentsListState>(
        'ranks Top again by the current totals after a switch to Recent',
        build: createBloc,
        seed: () => loaded([oldest, middle, newest]),
        act: (bloc) => bloc
          ..add(
            CommentsTopOrderFrozen(
              upvoteCounts: {oldest.id: 2},
              downvoteCounts: const {},
            ),
          )
          ..add(const CommentsSortModeChanged(CommentsSortMode.newest))
          ..add(const CommentsSortModeChanged(CommentsSortMode.topEngagement)),
        verify: (bloc) => expect(order(bloc.state, upvotes: {middle.id: 4}), [
          middle.id,
          newest.id,
          oldest.id,
        ]),
      );
    });
  });
}
