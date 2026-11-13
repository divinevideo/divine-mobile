// ABOUTME: Regression tests for #10921 through the real sheet wiring: the list
// ABOUTME: and reactions blocs, the OutboxBridges and CommentsList. A vote in
// ABOUTME: Top must not move the row under the viewer's finger.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/comments/comment_composer/comment_composer_bloc.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;

import '../../builders/comment_builder.dart';

class _SignedOutNostrSession extends NostrSession {
  @override
  NostrSessionReadiness build() => const NostrSessionReadiness.signedOut();
}

class _MockComposerBloc
    extends MockBloc<CommentComposerEvent, CommentComposerState>
    implements CommentComposerBloc {}

class _MockAuthService extends Mock implements AuthService {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

const _videoId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const _videoAuthor =
    'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a';

void main() {
  group('$CommentsList Top order (#10921)', () {
    late _MockAuthService auth;
    late _MockLikesRepository likes;
    late _MockCommentsRepository commentsRepository;
    late CommentsListBloc listBloc;
    late CommentReactionsBloc reactions;
    late Completer<String> publish;

    setUp(() {
      auth = _MockAuthService();
      likes = _MockLikesRepository();
      commentsRepository = _MockCommentsRepository();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(
        () => likes.likeEvent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          targetKind: any(named: 'targetKind'),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenAnswer((_) => publish.future);
      when(
        () => likes.downvoteEvent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          targetKind: any(named: 'targetKind'),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenAnswer((_) => publish.future);
      when(
        () => likes.unlikeEvent(
          any(),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => likes.getUserVoteStatuses(
          any(),
          addressableIds: any(named: 'addressableIds'),
        ),
      ).thenAnswer(
        (_) async => (upvotedIds: <String>{}, downvotedIds: <String>{}),
      );
      when(
        () => commentsRepository.watchComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          includeVideoReplies: any(named: 'includeVideoReplies'),
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

    void stubCounts(Map<String, int> up, [Map<String, int> down = const {}]) {
      when(
        () => likes.getVoteCounts(
          any(),
          addressableIds: any(named: 'addressableIds'),
        ),
      ).thenAnswer((invocation) async {
        final ids = invocation.positionalArguments.first as List<String>;
        return (
          upvotes: {for (final id in ids) id: up[id] ?? 0},
          downvotes: {for (final id in ids) id: down[id] ?? 0},
        );
      });
    }

    List<Comment> comments(int n) => [
      for (var i = 0; i < n; i++)
        CommentBuilder()
            .withId('${i + 1}'.padLeft(64, 'c'))
            .withRootEventId(_videoId)
            .withRootAuthorPubkey(_videoAuthor)
            .withContent('comment $i')
            .withCreatedAt(DateTime.utc(2026, 1, 1 + n - i))
            .build(),
    ];

    // The blocs are built in the test body: built in setUp, their async work
    // would run outside testWidgets' fake-async zone, which pump() never
    // drives.
    Future<void> pumpSheet(
      WidgetTester tester,
      List<Comment> page, {
      bool readsSettle = true,
    }) async {
      publish = Completer<String>();
      when(
        () => commentsRepository.loadComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          limit: any(named: 'limit'),
          includeVideoReplies: any(named: 'includeVideoReplies'),
        ),
      ).thenAnswer(
        (_) async => CommentThread(
          rootEventId: _videoId,
          comments: page,
          totalCount: page.length,
          hasMore: false,
          commentCache: {for (final c in page) c.id: c},
        ),
      );
      listBloc = CommentsListBloc(
        commentsRepository: commentsRepository,
        rootEventId: _videoId,
        rootEventKind: 34236,
        rootAuthorPubkey: _videoAuthor,
      );
      reactions = CommentReactionsBloc(
        authService: auth,
        likesRepository: likes,
        commentsRepository: commentsRepository,
        contentBlocklistRepository: _MockContentBlocklistRepository(),
        rootEventId: _videoId,
      );
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final composer = _MockComposerBloc();
      when(() => composer.state).thenReturn(const CommentComposerState());
      // Not awaited: teardown runs in fake async, where nothing flushes the
      // microtasks close() waits on.
      addTearDown(() {
        if (!publish.isCompleted) publish.complete('reaction');
        unawaited(reactions.close());
        unawaited(listBloc.close());
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nostrSessionProvider.overrideWith(_SignedOutNostrSession.new),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MultiBlocProvider(
                providers: [
                  BlocProvider<CommentsListBloc>.value(value: listBloc),
                  BlocProvider<CommentReactionsBloc>.value(value: reactions),
                  BlocProvider<CommentComposerBloc>.value(value: composer),
                ],
                child: OutboxBridges(
                  onCommentCountChanged: null,
                  child: CommentsList(
                    showClassicVineNotice: false,
                    scrollController: scrollController,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      listBloc.add(const CommentsLoadRequested());
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(listBloc.state.status, CommentsStatus.success);
      expect(reactions.state.isLoadingVoteCounts, isNot(readsSettle));
    }

    List<String> order(WidgetTester tester) => [
      for (final item in tester.widgetList<CommentItem>(
        find.byType(CommentItem),
      ))
        item.comment.id,
    ];

    Finder arrow(String commentId, String id) => find.descendant(
      of: find.byKey(ValueKey('comment_$commentId')),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == id,
      ),
    );

    testWidgets('an upvote leaves the voted row in place', (tester) async {
      final [newer, older] = comments(2);
      stubCounts({});
      await pumpSheet(tester, [newer, older]);
      expect(order(tester), [newer.id, older.id]);

      await tester.tap(arrow(older.id, 'upvote_button'));
      await tester.pump();

      expect(reactions.state.commentUpvoteCounts[older.id], 1);
      expect(order(tester), [newer.id, older.id]);
    });

    testWidgets('a second tap at the same spot votes the same comment', (
      tester,
    ) async {
      final [newer, older] = comments(2);
      stubCounts({});
      await pumpSheet(tester, [newer, older]);
      final spot = tester.getCenter(arrow(older.id, 'upvote_button'));

      await tester.tapAt(spot);
      await tester.pump();
      await tester.tapAt(spot);
      await tester.pump();

      verify(
        () => likes.likeEvent(
          eventId: older.id,
          authorPubkey: any(named: 'authorPubkey'),
          targetKind: any(named: 'targetKind'),
          addressableId: any(named: 'addressableId'),
        ),
      ).called(1);
      verifyNever(
        () => likes.likeEvent(
          eventId: newer.id,
          authorPubkey: any(named: 'authorPubkey'),
          targetKind: any(named: 'targetKind'),
          addressableId: any(named: 'addressableId'),
        ),
      );
    });

    testWidgets('a downvote keeps the first row first', (tester) async {
      final page = comments(12);
      stubCounts({});
      await pumpSheet(tester, page);
      final first = page.first;
      expect(order(tester).first, first.id);

      await tester.tap(arrow(first.id, 'downvote_button'));
      await tester.pump();

      expect(reactions.state.commentDownvoteCounts[first.id], 1);
      expect(order(tester).first, first.id);
    });

    testWidgets('ranks the sheet once the first totals land', (tester) async {
      final [newer, older] = comments(2);
      stubCounts({older.id: 1});
      await pumpSheet(tester, [newer, older]);

      expect(order(tester), [older.id, newer.id]);

      // Ranked live, the downvote would tie them and the newer would rise.
      await tester.tap(arrow(older.id, 'downvote_button'));
      await tester.pump();

      expect(reactions.state.commentDownvoteCounts[older.id], 1);
      expect(order(tester), [older.id, newer.id]);
    });

    testWidgets("a vote while the viewer's own votes still load holds the "
        'order', (tester) async {
      final [newer, older] = comments(2);
      stubCounts({});
      final viewerVotes =
          Completer<({Set<String> upvotedIds, Set<String> downvotedIds})>();
      when(
        () => likes.getUserVoteStatuses(
          any(),
          addressableIds: any(named: 'addressableIds'),
        ),
      ).thenAnswer((_) => viewerVotes.future);
      addTearDown(() {
        if (!viewerVotes.isCompleted) {
          viewerVotes.complete((
            upvotedIds: <String>{},
            downvotedIds: <String>{},
          ));
        }
      });
      await pumpSheet(tester, [newer, older], readsSettle: false);
      expect(reactions.state.commentUpvoteCounts, hasLength(2));

      await tester.tap(arrow(older.id, 'upvote_button'));
      await tester.pump();

      expect(reactions.state.commentUpvoteCounts[older.id], 1);
      expect(order(tester), [newer.id, older.id]);
    });

    testWidgets('a vote after switching back to Top holds the order', (
      tester,
    ) async {
      final [newer, older] = comments(2);
      stubCounts({});
      await pumpSheet(tester, [newer, older]);
      listBloc
        ..add(const CommentsSortModeChanged(CommentsSortMode.newest))
        ..add(const CommentsSortModeChanged(CommentsSortMode.topEngagement));
      await tester.pump();

      await tester.tap(arrow(older.id, 'upvote_button'));
      await tester.pump();

      expect(reactions.state.commentUpvoteCounts[older.id], 1);
      expect(order(tester), [newer.id, older.id]);
    });

    testWidgets("the viewer's post goes on top after switching back to Top", (
      tester,
    ) async {
      final [newer, older] = comments(2);
      stubCounts({older.id: 2});
      await pumpSheet(tester, [newer, older]);
      listBloc
        ..add(const CommentsSortModeChanged(CommentsSortMode.newest))
        ..add(const CommentsSortModeChanged(CommentsSortMode.topEngagement));
      await tester.pump();
      expect(order(tester), [older.id, newer.id]);

      final post = comments(3).first.copyWith(id: 'pending_comment_mine');
      // As the composer bridge does once the viewer sends it.
      listBloc.add(OptimisticCommentInserted(post));
      await tester.pump();
      await tester.pump();

      expect(order(tester), [post.id, older.id, newer.id]);
    });

    testWidgets('a comment posted live goes on top', (tester) async {
      final [live, newer, older] = comments(3);
      stubCounts({older.id: 2});
      final relay = StreamController<Comment>();
      addTearDown(relay.close);
      void Function()? endOfStoredComments;
      when(
        () => commentsRepository.watchComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          includeVideoReplies: any(named: 'includeVideoReplies'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((invocation) {
        endOfStoredComments =
            invocation.namedArguments[#onEose] as void Function()?;
        return relay.stream;
      });
      await pumpSheet(tester, [newer, older]);
      expect(order(tester), [older.id, newer.id]);

      endOfStoredComments!();
      await tester.pump();
      relay.add(live);
      // Live comments reach the list in 100 ms batches.
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }

      expect(reactions.state.commentUpvoteCounts[live.id], 0);
      expect(order(tester), [live.id, older.id, newer.id]);
    });

    testWidgets('keeps a voted row in place once a total that failed to '
        'load is read again', (tester) async {
      final [newer, older] = comments(2);
      when(
        () => likes.getVoteCounts(
          any(),
          addressableIds: any(named: 'addressableIds'),
        ),
      ).thenThrow(const LikesRepositoryException('read failed'));
      await pumpSheet(tester, [newer, older]);
      expect(reactions.state.commentUpvoteCounts, isEmpty);
      expect(order(tester), [newer.id, older.id]);

      await tester.tap(arrow(older.id, 'upvote_button'));
      await tester.pump();
      expect(reactions.state.upvotedCommentIds, {older.id});

      // The vote settles and its total is read again.
      stubCounts({older.id: 1});
      publish.complete('reaction');
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }

      expect(reactions.state.commentUpvoteCounts[older.id], 1);
      expect(order(tester), [newer.id, older.id]);
    });
  });
}
