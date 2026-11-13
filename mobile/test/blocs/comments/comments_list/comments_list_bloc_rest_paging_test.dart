// ABOUTME: Tests that CommentsListBloc keeps the REST position of the comment
// ABOUTME: list and hands it back when paging, so later pages come from REST.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

void main() {
  group('$CommentsListBloc REST paging', () {
    late _MockCommentsRepository commentsRepository;

    final rootId = 'a' * 64;
    final authorId = 'b' * 64;
    final commenterId = 'c' * 64;

    Comment makeComment(String id, int createdAtSeconds) => Comment(
      id: id,
      content: 'comment $id',
      authorPubkey: commenterId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSeconds * 1000),
      rootEventId: rootId,
      rootAuthorPubkey: authorId,
    );

    CommentThread threadOf(List<Comment> comments, {int? nextOffset}) =>
        CommentThread(
          rootEventId: rootId,
          comments: comments,
          totalCount: comments.length,
          hasMore: true,
          nextOffset: nextOffset,
          commentCache: {for (final c in comments) c.id: c},
        );

    void stubLoadMore(CommentThread thread) {
      when(
        () => commentsRepository.loadComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => thread);
    }

    CommentsListState loadedState({int? nextOffset}) {
      final newest = makeComment('f' * 64, 5000);
      return CommentsListState(
        status: CommentsStatus.success,
        rootEventId: rootId,
        rootEventKind: 34236,
        rootAuthorPubkey: authorId,
        rootAddressableId: '34236:$authorId:edited-video',
        commentsById: {newest.id: newest},
        nextOffset: nextOffset,
      );
    }

    CommentsListBloc createBloc() => CommentsListBloc(
      commentsRepository: commentsRepository,
      rootEventId: rootId,
      rootEventKind: 34236,
      rootAuthorPubkey: authorId,
      rootAddressableId: '34236:$authorId:edited-video',
    );

    setUp(() {
      commentsRepository = _MockCommentsRepository();
      when(
        () => commentsRepository.watchComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          since: any(named: 'since'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => const Stream<Comment>.empty());
      when(
        () => commentsRepository.watchCommentDeletions(
          rootEventId: any(named: 'rootEventId'),
          includeVideoReplies: any(named: 'includeVideoReplies'),
        ),
      ).thenAnswer((_) => const Stream<CommentDeletion>.empty());
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

    group('CommentsLoadRequested', () {
      blocTest<CommentsListBloc, CommentsListState>(
        'remembers where the next REST page starts',
        setUp: () {
          when(
            () => commentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async =>
                threadOf([makeComment('1' * 64, 4000)], nextOffset: 50),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const CommentsLoadRequested()),
        verify: (bloc) => expect(bloc.state.nextOffset, 50),
      );
    });

    group('a load followed by a load more', () {
      blocTest<CommentsListBloc, CommentsListState>(
        'continues from the position the first load reported',
        setUp: () {
          when(
            () => commentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async =>
                threadOf([makeComment('1' * 64, 4000)], nextOffset: 50),
          );
          when(
            () => commentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
              offset: 50,
            ),
          ).thenAnswer(
            (_) async =>
                threadOf([makeComment('2' * 64, 3000)], nextOffset: 100),
          );
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const CommentsLoadRequested());
          await bloc.stream.firstWhere(
            (state) => state.status == CommentsStatus.success,
          );
          bloc.add(const CommentsLoadMoreRequested());
          await pumpEventQueue();
        },
        verify: (bloc) {
          expect(bloc.state.commentsById.keys, ['1' * 64, '2' * 64]);
          expect(bloc.state.nextOffset, 100);
        },
      );
    });

    group('CommentsLoadMoreRequested', () {
      blocTest<CommentsListBloc, CommentsListState>(
        'continues the REST listing from the remembered position',
        setUp: () => stubLoadMore(
          threadOf([makeComment('2' * 64, 3000)], nextOffset: 100),
        ),
        build: createBloc,
        seed: () => loadedState(nextOffset: 50),
        act: (bloc) => bloc.add(const CommentsLoadMoreRequested()),
        verify: (bloc) {
          verify(
            () => commentsRepository.loadComments(
              rootEventId: rootId,
              rootEventKind: 34236,
              rootAddressableId: '34236:$authorId:edited-video',
              limit: any(named: 'limit'),
              before: any(named: 'before'),
              offset: 50,
            ),
          ).called(1);
          expect(bloc.state.nextOffset, 100);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'starts from no REST position when the first page came from the relay',
        setUp: () => stubLoadMore(threadOf([makeComment('2' * 64, 3000)])),
        build: createBloc,
        seed: loadedState,
        act: (bloc) => bloc.add(const CommentsLoadMoreRequested()),
        verify: (bloc) {
          final offsets = verify(
            () => commentsRepository.loadComments(
              rootEventId: rootId,
              rootEventKind: 34236,
              rootAddressableId: '34236:$authorId:edited-video',
              limit: any(named: 'limit'),
              before: any(named: 'before'),
              offset: captureAny(named: 'offset'),
            ),
          ).captured;
          expect(offsets, [0]);
          expect(bloc.state.nextOffset, isNull);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'stops paging when a relay page brings nothing new',
        // The relay reports no hasMore, and a total that counts comments
        // the list never gets would keep the next request identical.
        setUp: () => stubLoadMore(
          CommentThread(rootEventId: rootId, totalCount: 60),
        ),
        build: createBloc,
        seed: loadedState,
        act: (bloc) => bloc.add(const CommentsLoadMoreRequested()),
        verify: (bloc) => expect(bloc.state.hasMoreContent, isFalse),
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'keeps paging past a REST page of comments already loaded',
        setUp: () => stubLoadMore(
          threadOf([makeComment('f' * 64, 5000)], nextOffset: 100),
        ),
        build: createBloc,
        seed: () => loadedState(nextOffset: 50),
        act: (bloc) => bloc.add(const CommentsLoadMoreRequested()),
        verify: (bloc) {
          expect(bloc.state.commentsById, hasLength(1));
          expect(bloc.state.hasMoreContent, isTrue);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'keeps the REST position when the relay served the page',
        setUp: () => stubLoadMore(threadOf([makeComment('2' * 64, 3000)])),
        build: createBloc,
        seed: () => loadedState(nextOffset: 50),
        act: (bloc) => bloc.add(const CommentsLoadMoreRequested()),
        verify: (bloc) => expect(bloc.state.nextOffset, 50),
      );
    });
  });
}
