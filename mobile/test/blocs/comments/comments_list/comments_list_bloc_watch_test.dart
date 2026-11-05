// ABOUTME: Tests for how CommentsListBloc takes in the live watch stream: a
// ABOUTME: burst loses nothing, and the backfill is told apart from live
// ABOUTME: comments (#6744).

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

String _id(int n) => n.toRadixString(16).padLeft(64, '0');

const _rootId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _rootAuthor =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Comment _comment(int n, {String? videoUrl}) => Comment(
  id: _id(n),
  content: 'comment $n',
  authorPubkey: _id(1000 + n),
  createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000 + n * 1000),
  rootEventId: _rootId,
  rootAuthorPubkey: _rootAuthor,
  videoUrl: videoUrl,
);

void main() {
  group('CommentsListBloc watch stream', () {
    late _MockCommentsRepository repository;
    late StreamController<Comment> watch;
    void Function()? onEose;

    setUp(() {
      repository = _MockCommentsRepository();
      watch = StreamController<Comment>.broadcast();
      onEose = null;
      when(
        () => repository.loadComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          limit: any(named: 'limit'),
          includeVideoReplies: any(named: 'includeVideoReplies'),
        ),
      ).thenAnswer(
        (_) async => const CommentThread(rootEventId: _rootId),
      );
      when(
        () => repository.watchComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          includeVideoReplies: any(named: 'includeVideoReplies'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((invocation) {
        onEose = invocation.namedArguments[#onEose] as void Function()?;
        return watch.stream;
      });
      when(
        () => repository.watchCommentDeletions(
          rootEventId: any(named: 'rootEventId'),
          includeVideoReplies: any(named: 'includeVideoReplies'),
        ),
      ).thenAnswer((_) => const Stream<CommentDeletion>.empty());
      when(
        () => repository.findAuthorDeletedComments(any()),
      ).thenAnswer((_) async => <String>{});
      when(() => repository.stopWatchingComments()).thenAnswer((_) async {});
    });

    tearDown(() => watch.close());

    CommentsListBloc createBloc() => CommentsListBloc(
      commentsRepository: repository,
      rootEventId: _rootId,
      rootEventKind: 34236,
      rootAuthorPubkey: _rootAuthor,
      includeVideoReplies: true,
    );

    test('keeps every comment of a burst past ten a second', () {
      fakeAsync((fake) {
        final bloc = createBloc()..add(const CommentsLoadRequested());
        fake.flushMicrotasks();

        // Twenty-five comments, then a video reply, in one burst.
        for (var i = 1; i <= 25; i++) {
          watch.add(_comment(i));
        }
        watch.add(_comment(26, videoUrl: 'https://media.divine.video/reply'));
        fake.flushMicrotasks();
        fake.elapse(const Duration(seconds: 1));

        expect(bloc.state.commentsById, hasLength(26));
        expect(bloc.state.commentsById[_id(26)]?.hasVideo, isTrue);
        unawaited(bloc.close());
      });
    });

    test('does not call a backfilled comment new', () {
      fakeAsync((fake) {
        final bloc = createBloc()..add(const CommentsLoadRequested());
        fake.flushMicrotasks();

        // The relay sends its stored comments and then EOSE, one frame after
        // another, before any window closes.
        watch
          ..add(_comment(1))
          ..add(_comment(2))
          ..add(_comment(3));
        fake.flushMicrotasks();
        onEose!();
        fake.flushMicrotasks();
        fake.elapse(const Duration(seconds: 1));

        expect(bloc.state.isBackfillComplete, isTrue);
        expect(bloc.state.commentsById, hasLength(3));
        expect(bloc.state.newCommentIds, isEmpty);
        unawaited(bloc.close());
      });
    });

    test('calls a comment that arrives after the backfill new', () {
      fakeAsync((fake) {
        final bloc = createBloc()..add(const CommentsLoadRequested());
        fake.flushMicrotasks();
        onEose!();
        fake.flushMicrotasks();

        watch.add(_comment(7));
        fake.flushMicrotasks();
        fake.elapse(const Duration(seconds: 1));

        expect(bloc.state.newCommentIds, equals({_id(7)}));
        unawaited(bloc.close());
      });
    });

    test('does not resurrect a comment deleted while its batch is held', () {
      fakeAsync((fake) {
        final deletions = StreamController<CommentDeletion>.broadcast();
        when(
          () => repository.watchCommentDeletions(
            rootEventId: any(named: 'rootEventId'),
            includeVideoReplies: any(named: 'includeVideoReplies'),
          ),
        ).thenAnswer((_) => deletions.stream);
        final bloc = createBloc()..add(const CommentsLoadRequested());
        fake.flushMicrotasks();
        onEose!();
        fake.flushMicrotasks();

        final comment = _comment(1);
        watch.add(comment);
        fake.flushMicrotasks();
        expect(bloc.state.commentsById, isEmpty, reason: 'batch is held');
        deletions.add(
          CommentDeletion(
            commentId: comment.id,
            requesterPubkey: comment.authorPubkey,
          ),
        );
        fake.flushMicrotasks();
        fake.elapse(const Duration(seconds: 1));

        expect(bloc.state.commentsById, isEmpty);
        expect(bloc.state.newCommentIds, isEmpty);
        unawaited(bloc.close());
        unawaited(deletions.close());
      });
    });

    test('takes in nothing once it is closed', () {
      fakeAsync((fake) {
        final bloc = createBloc()..add(const CommentsLoadRequested());
        fake.flushMicrotasks();

        watch.add(_comment(1));
        fake.flushMicrotasks();
        unawaited(bloc.close());
        fake.flushMicrotasks();
        fake.elapse(const Duration(seconds: 1));

        expect(bloc.state.commentsById, isEmpty);
        expect(fake.nonPeriodicTimerCount, 0);
        expect(fake.periodicTimerCount, 0);
      });
    });
  });
}
