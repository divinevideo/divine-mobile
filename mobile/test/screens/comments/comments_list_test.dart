// ABOUTME: Widget tests for CommentsList component
// ABOUTME: Tests loading, error, empty, and data state rendering with the
// ABOUTME: split CommentsListBloc + CommentReactionsBloc provider tree.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/comments/comments.dart';

import '../../builders/comment_builder.dart';

// Nobody is signed in, so no comment renders as the viewer's own.
class _SignedOutNostrSession extends NostrSession {
  @override
  NostrSessionReadiness build() => const NostrSessionReadiness.signedOut();
}

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
    late _MockCommentsListBloc mockListBloc;
    late _MockCommentReactionsBloc mockReactionsBloc;

    setUpAll(() {
      registerFallbackValue(const CommentsLoadRequested());
      registerFallbackValue(const CommentVoteCountsFetchRequested([]));
    });

    setUp(() {
      mockListBloc = _MockCommentsListBloc();
      mockReactionsBloc = _MockCommentReactionsBloc();

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
        overrides: [
          nostrSessionProvider.overrideWith(_SignedOutNostrSession.new),
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
                showClassicVineNotice: showClassicVineNotice,
                scrollController: sc,
                showVideoReplies: showVideoReplies,
              ),
            ),
          ),
        ),
      );
    }

    group('comments the video owner hid', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      const harasserPubkey =
          'c3d4e5f6789012345678901234567890abcdef123456789012345678901234ab';
      final hidden = CommentBuilder()
          .withId('1' * 64)
          .withAuthorPubkey(harasserPubkey)
          .withRootEventId(testVideoEventId)
          .withRootAuthorPubkey(testVideoAuthorPubkey)
          .withContent('Unwanted comment')
          .build();
      final shown = CommentBuilder()
          .withId('2' * 64)
          .withRootEventId(testVideoEventId)
          .withRootAuthorPubkey(testVideoAuthorPubkey)
          .withContent('Kind comment')
          .build();

      CommentsListState stateWith({
        bool showHiddenComments = false,
        String? viewerPubkey,
      }) => CommentsListState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.success,
        commentsById: {hidden.id: hidden, shown.id: shown},
        moderation: const CommentModeration(
          autoHiddenAuthors: {harasserPubkey},
        ),
        showHiddenComments: showHiddenComments,
        viewerPubkey: viewerPubkey,
      );

      testWidgets('leaves them out by default', (tester) async {
        await tester.pumpWidget(buildTestWidget(listState: stateWith()));
        await tester.pump();

        expect(find.text('Kind comment'), findsOneWidget);
        expect(find.text('Unwanted comment'), findsNothing);
        expect(find.byType(HiddenCommentsNotice), findsNothing);
      });

      for (final coordinate in <String?>[
        null,
        '34235:$testVideoAuthorPubkey:video',
      ]) {
        testWidgets(
          'passes root moderation capability for coordinate $coordinate',
          (tester) async {
            final state = CommentsListState(
              rootEventId: testVideoEventId,
              rootAuthorPubkey: testVideoAuthorPubkey,
              rootAddressableId: coordinate,
              viewerPubkey: testVideoAuthorPubkey,
              status: CommentsStatus.success,
              commentsById: {shown.id: shown},
            );
            await tester.pumpWidget(buildTestWidget(listState: state));
            await tester.pump();
            final item = tester.widget<CommentItem>(find.byType(CommentItem));
            expect(item.viewerOwnsVideo, isTrue);
            expect(item.supportsModeration, coordinate != null);
          },
        );
      }

      testWidgets('shows them below a notice once the viewer asks', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(listState: stateWith(showHiddenComments: true)),
        );
        await tester.pump();

        expect(find.text(l10n.commentsHiddenNotice), findsOneWidget);
        expect(find.text('Unwanted comment'), findsOneWidget);
        expect(find.text(l10n.commentHiddenByCreator), findsOneWidget);
        expect(
          tester.getTopLeft(find.byType(HiddenCommentsNotice)).dy,
          lessThan(tester.getTopLeft(find.text('Kind comment')).dy),
        );
      });

      testWidgets('tells the owner they hid them', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            listState: stateWith(
              showHiddenComments: true,
              viewerPubkey: testVideoAuthorPubkey,
            ),
          ),
        );
        await tester.pump();

        expect(find.text(l10n.commentsHiddenNoticeOwner), findsOneWidget);
        expect(find.text(l10n.commentHiddenByYou), findsOneWidget);
      });

      // A reply to a hidden comment is listed on its own, and its reply line
      // must not name the author the owner hid.
      group('a reply to one of them', () {
        final reply = CommentBuilder()
            .withId('3' * 64)
            .withRootEventId(testVideoEventId)
            .withRootAuthorPubkey(testVideoAuthorPubkey)
            .withReplyToEventId(hidden.id)
            .withReplyToAuthorPubkey(harasserPubkey)
            .withContent('A reply')
            .build();

        CommentItem replyItem(WidgetTester tester) => tester.widget(
          find.ancestor(
            of: find.text('A reply'),
            matching: find.byType(CommentItem),
          ),
        );

        testWidgets('leaves the hidden author out of its reply line', (
          tester,
        ) async {
          await tester.pumpWidget(
            buildTestWidget(
              listState: stateWith().copyWith(
                commentsById: {hidden.id: hidden, reply.id: reply},
              ),
            ),
          );
          await tester.pump();

          expect(replyItem(tester).repliesToHiddenComment, isTrue);
        });

        testWidgets('names the author once the hidden comments are shown', (
          tester,
        ) async {
          await tester.pumpWidget(
            buildTestWidget(
              listState: stateWith(showHiddenComments: true).copyWith(
                commentsById: {hidden.id: hidden, reply.id: reply},
              ),
            ),
          );
          await tester.pump();

          expect(replyItem(tester).repliesToHiddenComment, isFalse);
        });
      });
    });

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

    testWidgets(
      'ranks replies with all comments and reorders when downvotes change',
      (
        tester,
      ) async {
        final highest = CommentBuilder()
            .withId('1' * 64)
            .withCreatedAt(DateTime.utc(2026))
            .withReplyToEventId('2' * 64)
            .withReplyToAuthorPubkey(testVideoAuthorPubkey)
            .build();
        final runnerUp = CommentBuilder()
            .withId('2' * 64)
            .withCreatedAt(DateTime.utc(2026, 2))
            .build();
        final unvoted = CommentBuilder()
            .withId('3' * 64)
            .withCreatedAt(DateTime.utc(2026, 3))
            .build();
        final reactions = CommentReactionsState(
          commentUpvoteCounts: {highest.id: 6, runnerUp.id: 4},
        );
        final updates = StreamController<CommentReactionsState>();
        addTearDown(updates.close);
        whenListen(mockReactionsBloc, updates.stream, initialState: reactions);

        await tester.pumpWidget(
          buildTestWidget(
            listState: CommentsListState(
              rootEventId: testVideoEventId,
              rootAuthorPubkey: testVideoAuthorPubkey,
              status: CommentsStatus.success,
              commentsById: {
                highest.id: highest,
                runnerUp.id: runnerUp,
                unvoted.id: unvoted,
              },
            ),
          ),
        );
        await tester.pump();

        Iterable<String> displayedOrder() => tester
            .widgetList<CommentItem>(find.byType(CommentItem))
            .map((item) => item.comment.id);

        expect(displayedOrder(), [highest.id, runnerUp.id, unvoted.id]);

        updates.add(reactions.copyWith(commentDownvoteCounts: {highest.id: 7}));
        await tester.pump();

        expect(displayedOrder(), [runnerUp.id, unvoted.id, highest.id]);
      },
    );

    testWidgets('keeps the state of a row that Top moves', (tester) async {
      final newer = CommentBuilder()
          .withId('1' * 64)
          .withCreatedAt(DateTime.utc(2026, 2))
          .build();
      final older = CommentBuilder()
          .withId('2' * 64)
          .withCreatedAt(DateTime.utc(2026))
          .build();
      const reactions = CommentReactionsState();
      final updates = StreamController<CommentReactionsState>();
      addTearDown(updates.close);
      whenListen(mockReactionsBloc, updates.stream, initialState: reactions);

      await tester.pumpWidget(
        buildTestWidget(
          listState: CommentsListState(
            rootEventId: testVideoEventId,
            rootAuthorPubkey: testVideoAuthorPubkey,
            status: CommentsStatus.success,
            commentsById: {newer.id: newer, older.id: older},
          ),
        ),
      );
      await tester.pump();

      Iterable<String> displayedOrder() => tester
          .widgetList<CommentItem>(find.byType(CommentItem))
          .map((item) => item.comment.id);
      final olderRow = find.byKey(ValueKey('comment_${older.id}'));
      expect(displayedOrder(), [newer.id, older.id]);
      final rowState = tester.state(olderRow);

      updates.add(reactions.copyWith(commentUpvoteCounts: {older.id: 1}));
      await tester.pump();

      // A rebuilt row would stop an inline video reply and drop focus.
      expect(displayedOrder(), [older.id, newer.id]);
      expect(tester.state(olderRow), same(rowState));
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
                // No votes, so Top falls back to newest first: minute 12-i
                // puts i=0 on top and higher indices lower in the list.
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
              nostrSessionProvider.overrideWith(_SignedOutNostrSession.new),
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
        verify(
          () => mockListBloc.add(
            any(
              that: isA<CommentsScrollHandled>().having(
                (event) => event.commentId,
                'commentId',
                target.id,
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'reveals a far-off post when confirmation replaces its placeholder',
      (tester) async {
        final comments = [
          for (var i = 0; i < 80; i++)
            CommentBuilder()
                .withId('$i'.padLeft(64, 'a'))
                .withContent('comment number $i')
                .withCreatedAt(DateTime(2026).add(Duration(minutes: 80 - i)))
                .build(),
        ];
        // Far past the build cache extent of the first frame.
        final target = comments[70];
        final placeholder = target.copyWith(id: 'pending_comment_70');
        final base = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: {
            for (final c in comments)
              if (c.id != target.id) c.id: c,
            placeholder.id: placeholder,
          },
        );

        whenListen(
          mockListBloc,
          Stream.fromIterable([
            base,
            base.copyWith(scrollToCommentId: placeholder.id),
            base.copyWith(
              commentsById: {for (final c in comments) c.id: c},
              scrollToCommentId: target.id,
            ),
          ]),
          initialState: base,
        );

        final sc = ScrollController();
        addTearDown(sc.dispose);
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

        final shown = find.text('comment number 70');
        expect(shown, findsOneWidget);
        final viewport = tester.getRect(find.byType(ListView));
        expect(viewport.contains(tester.getCenter(shown)), isTrue);
        // Matched by field: the event has no value equality, so a const
        // instance would never equal the one the widget builds.
        verifyNever(
          () => mockListBloc.add(
            any(
              that: isA<CommentsScrollHandled>().having(
                (event) => event.commentId,
                'commentId',
                'pending_comment_70',
              ),
            ),
          ),
        );
        verify(
          () => mockListBloc.add(
            any(
              that: isA<CommentsScrollHandled>().having(
                (event) => event.commentId,
                'commentId',
                target.id,
              ),
            ),
          ),
        ).called(1);
      },
    );

    for (final mode in CommentsSortMode.values) {
      final acknowledges = mode == CommentsSortMode.newest;
      testWidgets(
        'scrolling back to the top '
        '${acknowledges ? 'acknowledges' : 'keeps'} new comments in '
        '${mode.name}',
        (tester) async {
          final comments = [
            for (var i = 0; i < 30; i++)
              CommentBuilder()
                  .withId('$i'.padLeft(64, 'a'))
                  .withContent('comment number $i')
                  .withCreatedAt(DateTime(2026).add(Duration(minutes: 30 - i)))
                  .build(),
          ];
          final sc = ScrollController();
          addTearDown(sc.dispose);
          await tester.pumpWidget(
            buildTestWidget(
              scrollController: sc,
              listState: CommentsListState(
                rootEventId: testVideoEventId,
                rootAuthorPubkey: testVideoAuthorPubkey,
                status: CommentsStatus.success,
                sortMode: mode,
                commentsById: {for (final c in comments) c.id: c},
                newCommentIds: {comments.first.id},
              ),
            ),
          );
          await tester.pump();

          sc.jumpTo(200);
          await tester.pump();
          expect(sc.offset, 200);
          sc.jumpTo(0);
          await tester.pump();

          // In Top the new comments rank further down, so the top of the
          // list has not shown them.
          if (acknowledges) {
            verify(
              () => mockListBloc.add(const NewCommentsAcknowledged()),
            ).called(1);
          } else {
            verifyNever(
              () => mockListBloc.add(const NewCommentsAcknowledged()),
            );
          }
        },
      );
    }

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
