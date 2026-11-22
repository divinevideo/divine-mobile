// ABOUTME: Pins that a comments sheet closed while its first page is still
// ABOUTME: loading opens no live relay subscription once the page arrives
// ABOUTME: (#9689): nothing would be left to close it.

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

String _id(int n) => n.toRadixString(16).padLeft(64, '0');

const _rootId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _rootAuthor =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

/// Bounds every wait, so a regression fails here instead of hanging.
const _timeout = Duration(seconds: 5);

/// Completes [loadDone] when a [CommentsLoadRequested] handler has run to its
/// end.
///
/// `close()` does not wait for a running handler, so awaiting it says nothing
/// about whether the late page has been handled yet.
class _LoadObservingBloc extends CommentsListBloc {
  _LoadObservingBloc(CommentsRepository repository)
    : super(
        commentsRepository: repository,
        rootEventId: _rootId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthor,
      );

  final loadDone = Completer<void>();

  @override
  void onDone(
    CommentsListEvent event, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    super.onDone(event, error, stackTrace);
    if (event is CommentsLoadRequested && !loadDone.isCompleted) {
      loadDone.complete();
    }
  }
}

void main() {
  group(CommentsListBloc, () {
    group('$CommentsLoadRequested closed before the first page arrives', () {
      late _MockCommentsRepository repository;
      late Completer<CommentThread> firstPage;

      Stream<Comment> watchComments() => repository.watchComments(
        rootEventId: any(named: 'rootEventId'),
        rootEventKind: any(named: 'rootEventKind'),
        rootAddressableId: any(named: 'rootAddressableId'),
        since: any(named: 'since'),
        includeVideoReplies: any(named: 'includeVideoReplies'),
        onEose: any(named: 'onEose'),
      );

      Stream<CommentDeletion> watchCommentDeletions() =>
          repository.watchCommentDeletions(
            rootEventId: any(named: 'rootEventId'),
            includeVideoReplies: any(named: 'includeVideoReplies'),
          );

      Future<Set<String>> findAuthorDeletedComments() =>
          repository.findAuthorDeletedComments(any());

      CommentThread pageWithOneComment() => CommentThread(
        rootEventId: _rootId,
        comments: [
          Comment(
            id: _id(1),
            content: 'first',
            authorPubkey: _id(1001),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            rootEventId: _rootId,
            rootAuthorPubkey: _rootAuthor,
          ),
        ],
        totalCount: 1,
      );

      setUp(() {
        repository = _MockCommentsRepository();
        firstPage = Completer<CommentThread>();
        when(
          () => repository.loadComments(
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootAddressableId: any(named: 'rootAddressableId'),
            limit: any(named: 'limit'),
            includeVideoReplies: any(named: 'includeVideoReplies'),
          ),
        ).thenAnswer((_) => firstPage.future);
        when(watchComments).thenAnswer((_) => const Stream<Comment>.empty());
        when(watchCommentDeletions)
            .thenAnswer((_) => const Stream<CommentDeletion>.empty());
        when(findAuthorDeletedComments).thenAnswer((_) async => <String>{});
      });

      test(
        'opens no watch when the page arrives after close() finished',
        () async {
          final bloc = _LoadObservingBloc(repository)
            ..add(const CommentsLoadRequested());
          await pumpEventQueue();

          await bloc.close();
          firstPage.complete(pageWithOneComment());
          await bloc.loadDone.future.timeout(_timeout);

          verifyNever(watchComments);
          verifyNever(watchCommentDeletions);
          verifyNever(findAuthorDeletedComments);
        },
      );

      test('opens no watch when the page arrives while close() runs', () async {
        final bloc = _LoadObservingBloc(repository)
          ..add(const CommentsLoadRequested());
        await pumpEventQueue();

        // The page lands before close() has finished its own teardown.
        final closing = bloc.close();
        firstPage.complete(pageWithOneComment());
        await closing.timeout(_timeout);
        await bloc.loadDone.future.timeout(_timeout);

        verifyNever(watchComments);
        verifyNever(watchCommentDeletions);
      });
    });
  });
}
