// ABOUTME: Tests for the OutboxBridges widget in comments_screen.dart that
// ABOUTME: translates ComposerOutbox / ReactionsOutbox signals into
// ABOUTME: CommentsListBloc store-mutation events and triggers vote-count
// ABOUTME: refetches when the loaded comment set changes.

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/comments/comment_composer/comment_composer_bloc.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/comments/comments_screen.dart';

class _MockListBloc extends MockBloc<CommentsListEvent, CommentsListState>
    implements CommentsListBloc {}

class _MockComposerBloc
    extends MockBloc<CommentComposerEvent, CommentComposerState>
    implements CommentComposerBloc {}

class _MockReactionsBloc
    extends MockBloc<CommentReactionsEvent, CommentReactionsState>
    implements CommentReactionsBloc {}

String validId(String suffix) {
  final hexSuffix = suffix.codeUnits
      .map((c) => c.toRadixString(16).padLeft(2, '0'))
      .join();
  return hexSuffix.padLeft(64, '0');
}

Comment makeComment(String id, {String? authorPubkey, String? content}) =>
    Comment(
      id: id,
      content: content ?? 'hi',
      authorPubkey: authorPubkey ?? validId('author'),
      createdAt: DateTime.now(),
      rootEventId: validId('root'),
      rootAuthorPubkey: validId('rootauthor'),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(const ComposerOutboxConsumed());
    registerFallbackValue(const ReactionsOutboxConsumed());
    registerFallbackValue(const CommentVoteCountsFetchRequested([]));
    registerFallbackValue(OptimisticCommentInserted(makeComment(validId('x'))));
  });

  group('OutboxBridges', () {
    late _MockListBloc list;
    late _MockComposerBloc composer;
    late _MockReactionsBloc reactions;

    setUp(() {
      list = _MockListBloc();
      composer = _MockComposerBloc();
      reactions = _MockReactionsBloc();
      when(() => list.state).thenReturn(const CommentsListState());
      when(() => composer.state).thenReturn(const CommentComposerState());
      when(() => reactions.state).thenReturn(const CommentReactionsState());
    });

    Future<void> pumpBridges(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<CommentsListBloc>.value(value: list),
                BlocProvider<CommentComposerBloc>.value(value: composer),
                BlocProvider<CommentReactionsBloc>.value(value: reactions),
              ],
              child: const OutboxBridges(
                onCommentCountChanged: null,
                child: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'composer InsertPlaceholder → list.OptimisticCommentInserted + ack',
      (tester) async {
        final placeholder = makeComment('pending_comment_1');
        whenListen(
          composer,
          Stream.fromIterable([
            const CommentComposerState(),
            CommentComposerState(
              outbox: ComposerOutboxInsertPlaceholder(placeholder),
            ),
          ]),
          initialState: const CommentComposerState(),
        );

        await pumpBridges(tester);
        await tester.pump();

        final captured = verify(() => list.add(captureAny())).captured;
        expect(captured, hasLength(1));
        expect(captured.first, isA<OptimisticCommentInserted>());
        expect(
          (captured.first as OptimisticCommentInserted).placeholder.id,
          'pending_comment_1',
        );
        verify(() => composer.add(const ComposerOutboxConsumed())).called(1);
      },
    );

    testWidgets(
      'composer ConfirmPlaceholder → list.OptimisticCommentConfirmed + ack',
      (tester) async {
        final confirmed = makeComment(validId('confirmed'));
        whenListen(
          composer,
          Stream.fromIterable([
            const CommentComposerState(),
            CommentComposerState(
              outbox: ComposerOutboxConfirmPlaceholder(
                placeholderId: 'pending_comment_1',
                confirmed: confirmed,
              ),
            ),
          ]),
          initialState: const CommentComposerState(),
        );

        await pumpBridges(tester);
        await tester.pump();

        final captured = verify(() => list.add(captureAny())).captured;
        expect(captured.first, isA<OptimisticCommentConfirmed>());
        expect(
          (captured.first as OptimisticCommentConfirmed).placeholderId,
          'pending_comment_1',
        );
        verify(() => composer.add(const ComposerOutboxConsumed())).called(1);
      },
    );

    testWidgets(
      'composer RollbackPlaceholder → list.OptimisticCommentRolledBack + ack',
      (tester) async {
        whenListen(
          composer,
          Stream.fromIterable([
            const CommentComposerState(),
            const CommentComposerState(
              outbox: ComposerOutboxRollbackPlaceholder('pending_comment_1'),
            ),
          ]),
          initialState: const CommentComposerState(),
        );

        await pumpBridges(tester);
        await tester.pump();

        final captured = verify(() => list.add(captureAny())).captured;
        expect(captured.first, isA<OptimisticCommentRolledBack>());
        expect(
          (captured.first as OptimisticCommentRolledBack).placeholderId,
          'pending_comment_1',
        );
        verify(() => composer.add(const ComposerOutboxConsumed())).called(1);
      },
    );

    testWidgets(
      'composer ReplaceComment → list.CommentReplacedInStore + ack',
      (tester) async {
        final newComment = makeComment(validId('new'));
        whenListen(
          composer,
          Stream.fromIterable([
            const CommentComposerState(),
            CommentComposerState(
              outbox: ComposerOutboxReplaceComment(
                oldId: validId('old'),
                newComment: newComment,
              ),
            ),
          ]),
          initialState: const CommentComposerState(),
        );

        await pumpBridges(tester);
        await tester.pump();

        final captured = verify(() => list.add(captureAny())).captured;
        expect(captured.first, isA<CommentReplacedInStore>());
        expect(
          (captured.first as CommentReplacedInStore).oldId,
          validId('old'),
        );
        verify(() => composer.add(const ComposerOutboxConsumed())).called(1);
      },
    );

    testWidgets(
      'reactions RemoveComment → list.CommentRemovedFromStore + ack',
      (tester) async {
        whenListen(
          reactions,
          Stream.fromIterable([
            const CommentReactionsState(),
            CommentReactionsState(
              outbox: ReactionsOutboxRemoveComment(validId('c1')),
            ),
          ]),
          initialState: const CommentReactionsState(),
        );

        await pumpBridges(tester);
        await tester.pump();

        final captured = verify(() => list.add(captureAny())).captured;
        expect(captured.first, isA<CommentRemovedFromStore>());
        expect(
          (captured.first as CommentRemovedFromStore).commentId,
          validId('c1'),
        );
        verify(() => reactions.add(const ReactionsOutboxConsumed())).called(1);
      },
    );

    testWidgets(
      'reactions RemoveByAuthor → list.CommentsRemovedByAuthorFromStore + ack',
      (tester) async {
        whenListen(
          reactions,
          Stream.fromIterable([
            const CommentReactionsState(),
            CommentReactionsState(
              outbox: ReactionsOutboxRemoveByAuthor(validId('blocked')),
            ),
          ]),
          initialState: const CommentReactionsState(),
        );

        await pumpBridges(tester);
        await tester.pump();

        final captured = verify(() => list.add(captureAny())).captured;
        expect(captured.first, isA<CommentsRemovedByAuthorFromStore>());
        expect(
          (captured.first as CommentsRemovedByAuthorFromStore).authorPubkey,
          validId('blocked'),
        );
        verify(() => reactions.add(const ReactionsOutboxConsumed())).called(1);
      },
    );

    testWidgets(
      'vote-counts fetch dispatched only for NEW non-placeholder ids',
      (tester) async {
        final c1 = makeComment(validId('c1'));
        final c2 = makeComment(validId('c2'));
        when(() => reactions.state).thenReturn(
          // Pretend we already fetched counts for c1.
          CommentReactionsState(commentUpvoteCounts: {validId('c1'): 0}),
        );
        whenListen(
          list,
          Stream.fromIterable([
            CommentsListState(commentsById: {c1.id: c1}),
            CommentsListState(commentsById: {c1.id: c1, c2.id: c2}),
          ]),
          initialState: CommentsListState(commentsById: {c1.id: c1}),
        );

        await pumpBridges(tester);
        await tester.pump();

        // Only c2 (the NEW id) should be requested — c1 was already in the
        // reactions cache.
        final captured = verify(
          () => reactions.add(captureAny<CommentVoteCountsFetchRequested>()),
        ).captured;
        expect(captured, hasLength(1));
        final req = captured.first as CommentVoteCountsFetchRequested;
        expect(req.commentIds, [validId('c2')]);
      },
    );

    testWidgets(
      'vote-counts fetch filters out optimistic placeholder ids',
      (tester) async {
        final placeholder = makeComment('pending_comment_1');
        when(() => reactions.state).thenReturn(const CommentReactionsState());
        whenListen(
          list,
          Stream.fromIterable([
            const CommentsListState(),
            CommentsListState(commentsById: {placeholder.id: placeholder}),
          ]),
          initialState: const CommentsListState(),
        );

        await pumpBridges(tester);
        await tester.pump();

        verifyNever(
          () => reactions.add(any<CommentVoteCountsFetchRequested>()),
        );
      },
    );
  });
}
