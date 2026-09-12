// ABOUTME: Widget tests for CommentsList component
// ABOUTME: Tests loading, error, empty, and data state rendering with the
// ABOUTME: split CommentsListBloc + CommentReactionsBloc provider tree.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/comments/comments.dart';

import '../../builders/comment_builder.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockCommentsListBloc
    extends MockBloc<CommentsListEvent, CommentsListState>
    implements CommentsListBloc {}

class _MockCommentReactionsBloc
    extends MockBloc<CommentReactionsEvent, CommentReactionsState>
    implements CommentReactionsBloc {}

// Full 64-character test IDs.
const testVideoEventId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const testVideoAuthorPubkey =
    'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a';

void main() {
  group('CommentsList', () {
    late _MockNostrClient mockNostrClient;
    late _MockCommentsListBloc mockListBloc;
    late _MockCommentReactionsBloc mockReactionsBloc;

    setUpAll(() {
      registerFallbackValue(const CommentsLoadRequested());
      registerFallbackValue(const CommentVoteCountsFetchRequested([]));
    });

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockListBloc = _MockCommentsListBloc();
      mockReactionsBloc = _MockCommentReactionsBloc();

      when(() => mockNostrClient.publicKey).thenReturn('');
      when(() => mockReactionsBloc.state).thenReturn(
        const CommentReactionsState(),
      );
    });

    Widget buildTestWidget({
      required CommentsListState listState,
      bool showClassicVineNotice = false,
      bool showVideoReplies = true,
      ScrollController? scrollController,
    }) {
      final sc = scrollController ?? ScrollController();

      when(() => mockListBloc.state).thenReturn(listState);

      return ProviderScope(
        overrides: [nostrServiceProvider.overrideWithValue(mockNostrClient)],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<CommentsListBloc>.value(value: mockListBloc),
                BlocProvider<CommentReactionsBloc>.value(
                  value: mockReactionsBloc,
                ),
              ],
              child: CommentsList(
                showClassicVineNotice: showClassicVineNotice,
                scrollController: sc,
                showVideoReplies: showVideoReplies,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows skeleton loader when loading', (tester) async {
      const state = CommentsListState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.loading,
      );

      await tester.pumpWidget(buildTestWidget(listState: state));
      await tester.pump();

      expect(find.byType(CommentsSkeletonLoader), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows error message when state has error', (tester) async {
      const state = CommentsListState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.failure,
        error: CommentsListError.loadFailed,
      );

      await tester.pumpWidget(buildTestWidget(listState: state));
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.commentsErrorLoadFailed), findsOneWidget);
    });

    testWidgets('shows CommentsEmptyState when no comments', (tester) async {
      const state = CommentsListState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.success,
      );

      await tester.pumpWidget(buildTestWidget(listState: state));
      await tester.pump();

      expect(find.byType(CommentsEmptyState), findsOneWidget);
    });

    testWidgets('shows Classic Vine notice when requested', (tester) async {
      const state = CommentsListState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.success,
      );

      await tester.pumpWidget(
        buildTestWidget(listState: state, showClassicVineNotice: true),
      );
      await tester.pump();

      expect(find.text('Classic Vine'), findsOneWidget);
    });

    testWidgets('renders CommentItem for each comment', (tester) async {
      final comment1 = CommentBuilder()
          .withId(TestCommentIds.comment1Id)
          .withContent('First comment')
          .build();

      final comment2 = CommentBuilder()
          .withId(TestCommentIds.comment2Id)
          .withContent('Second comment')
          .build();

      final state = CommentsListState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.success,
        commentsById: {comment1.id: comment1, comment2.id: comment2},
      );

      await tester.pumpWidget(buildTestWidget(listState: state));
      await tester.pump();

      expect(find.byType(CommentItem), findsNWidgets(2));
      expect(find.text('First comment'), findsOneWidget);
      expect(find.text('Second comment'), findsOneWidget);
    });

    testWidgets('filters video comments when video replies are hidden', (
      tester,
    ) async {
      final textComment = CommentBuilder()
          .withId(TestCommentIds.comment1Id)
          .withContent('Text only comment')
          .build();

      final videoComment = CommentBuilder()
          .withId(TestCommentIds.comment2Id)
          .withContent('Video comment https://cdn.example.com/reply.mp4')
          .build()
          .copyWith(videoUrl: 'https://cdn.example.com/reply.mp4');

      final state = CommentsListState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.success,
        commentsById: {
          textComment.id: textComment,
          videoComment.id: videoComment,
        },
      );

      await tester.pumpWidget(
        buildTestWidget(listState: state, showVideoReplies: false),
      );
      await tester.pump();

      expect(find.text('Text only comment'), findsOneWidget);
      expect(
        find.text('Video comment https://cdn.example.com/reply.mp4'),
        findsNothing,
      );
    });

    testWidgets('uses provided scroll controller', (tester) async {
      final scrollController = ScrollController();
      final comment = CommentBuilder().build();
      final state = CommentsListState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.success,
        commentsById: {comment.id: comment},
      );

      await tester.pumpWidget(
        buildTestWidget(listState: state, scrollController: scrollController),
      );
      await tester.pump();

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.controller, equals(scrollController));

      scrollController.dispose();
    });

    testWidgets(
      'scrolls the flagged comment into view and acks it (#5854)',
      (tester) async {
        final comments = [
          for (var i = 0; i < 12; i++)
            CommentBuilder()
                .withId('$i'.padLeft(64, 'a'))
                .withContent('comment number $i')
                // Newest-first sort: minute 12-i means i=0 is newest (top),
                // so higher indices sit lower in the list.
                .withCreatedAt(DateTime(2026).add(Duration(minutes: 12 - i)))
                .build(),
        ];
        final commentsById = {for (final c in comments) c.id: c};
        // A comment below the initial fold but within the build cache extent.
        final target = comments[5];

        final base = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: commentsById,
        );
        final withScroll = base.copyWith(scrollToCommentId: target.id);

        whenListen(
          mockListBloc,
          Stream.fromIterable([base, withScroll]),
          initialState: base,
        );

        final sc = ScrollController();
        addTearDown(sc.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nostrServiceProvider.overrideWithValue(mockNostrClient),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MultiBlocProvider(
                  providers: [
                    BlocProvider<CommentsListBloc>.value(value: mockListBloc),
                    BlocProvider<CommentReactionsBloc>.value(
                      value: mockReactionsBloc,
                    ),
                  ],
                  child: CommentsList(
                    showClassicVineNotice: false,
                    scrollController: sc,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The list scrolled down to reveal the flagged comment, and the
        // one-shot scroll signal was acknowledged.
        expect(sc.offset, greaterThan(0));
        verify(() => mockListBloc.add(const CommentsScrollHandled())).called(1);
      },
    );

    testWidgets(
      'ListView declares onDrag keyboard-dismiss behavior',
      (tester) async {
        final comment = CommentBuilder().build();
        final state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: {comment.id: comment},
        );

        await tester.pumpWidget(buildTestWidget(listState: state));
        await tester.pump();

        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(
          listView.keyboardDismissBehavior,
          ScrollViewKeyboardDismissBehavior.onDrag,
        );
      },
    );
  });
}
