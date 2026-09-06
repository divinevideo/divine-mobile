// ABOUTME: Widget tests for CommentsScreen with the split three-bloc topology.
// ABOUTME: Mocks CommentsListBloc + CommentComposerBloc + CommentReactionsBloc
// ABOUTME: via MultiBlocProvider and exercises a content widget that mirrors
// ABOUTME: the production screen.

import 'package:analytics/analytics.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/comments/comment_composer/comment_composer_bloc.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';
import 'package:openvine/blocs/comments/comments_surface_performance_telemetry.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;

import '../../builders/comment_builder.dart';
import '../../helpers/test_helpers.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockCommentsListBloc
    extends MockBloc<CommentsListEvent, CommentsListState>
    implements CommentsListBloc {}

class _MockCommentComposerBloc
    extends MockBloc<CommentComposerEvent, CommentComposerState>
    implements CommentComposerBloc {}

class _MockCommentReactionsBloc
    extends MockBloc<CommentReactionsEvent, CommentReactionsState>
    implements CommentReactionsBloc {}

class _RecordingAnalyticsEventSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

// Full 64-character test IDs.
const testVideoEventId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const testVideoAuthorPubkey =
    'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a';

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  group(isDuplicatePendingReplySubmission, () {
    const authorPubkey =
        'c3d4e5f6789012345678901234567890abcdef123456789012345678901234ab';
    const parentCommentId =
        'd4e5f6789012345678901234567890abcdef123456789012345678901234abc';

    test('allows repeated top-level comments by the same author', () {
      final existing = CommentBuilder()
          .withId(
            'e5f6789012345678901234567890abcdef123456789012345678901234abcd',
          )
          .withAuthorPubkey(authorPubkey)
          .withContent('lol')
          .build();

      expect(
        isDuplicatePendingReplySubmission(
          comments: [existing],
          content: 'lol',
          authorPubkey: authorPubkey,
        ),
        isFalse,
      );
    });

    test('blocks a matching pending reply resend', () {
      final pendingReply = CommentBuilder()
          .withId('pending_comment_1')
          .withAuthorPubkey(authorPubkey)
          .withContent('box of  krayshawns')
          .withReplyToEventId(parentCommentId)
          .build();

      expect(
        isDuplicatePendingReplySubmission(
          comments: [pendingReply],
          content: ' box of krayshawns ',
          authorPubkey: authorPubkey,
          parentCommentId: parentCommentId,
        ),
        isTrue,
      );
    });

    test('allows the same confirmed reply text later', () {
      final confirmedReply = CommentBuilder()
          .withId(
            'f6789012345678901234567890abcdef123456789012345678901234abcde',
          )
          .withAuthorPubkey(authorPubkey)
          .withContent('same reply')
          .withReplyToEventId(parentCommentId)
          .build();

      expect(
        isDuplicatePendingReplySubmission(
          comments: [confirmedReply],
          content: 'same reply',
          authorPubkey: authorPubkey,
          parentCommentId: parentCommentId,
        ),
        isFalse,
      );
    });
  });

  group('CommentsScreen', () {
    late _MockAuthService mockAuthService;
    late _MockNostrClient mockNostrClient;
    late _MockCommentsListBloc mockListBloc;
    late _MockCommentComposerBloc mockComposerBloc;
    late _MockCommentReactionsBloc mockReactionsBloc;
    late ScrollController scrollController;
    late VideoEvent testVideoEvent;

    setUpAll(() {
      registerFallbackValue(const CommentsLoadRequested());
      registerFallbackValue(const CommentReplyToggled(''));
      registerFallbackValue(const ComposerOutboxConsumed());
      registerFallbackValue(const ReactionsOutboxConsumed());
      registerFallbackValue(const CommentVoteCountsFetchRequested([]));
      registerFallbackValue(
        OptimisticCommentInserted(
          Comment(
            id: 'fb',
            content: '',
            authorPubkey: testVideoAuthorPubkey,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            rootEventId: testVideoEventId,
            rootAuthorPubkey: testVideoAuthorPubkey,
          ),
        ),
      );
      registerFallbackValue(const CommentsRemovedByAuthorFromStore(''));
    });

    setUp(() {
      // Isolate from upstream test-pollution that can shrink the binding
      // surface to ~140px wide (cascading layout overflow exceptions from
      // other test files in the same flutter test run). Always pump our
      // widgets on a stable 800x600 surface.
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(
        800,
        600,
      );
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
      addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
      addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);

      mockAuthService = _MockAuthService();
      mockNostrClient = _MockNostrClient();
      mockListBloc = _MockCommentsListBloc();
      mockComposerBloc = _MockCommentComposerBloc();
      mockReactionsBloc = _MockCommentReactionsBloc();
      scrollController = ScrollController();

      testVideoEvent = TestHelpers.createVideoEvent(
        id: testVideoEventId,
        pubkey: testVideoAuthorPubkey,
      );

      when(() => mockNostrClient.publicKey).thenReturn('');

      when(() => mockListBloc.state).thenReturn(
        const CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
        ),
      );
      when(
        () => mockComposerBloc.state,
      ).thenReturn(const CommentComposerState());
      when(
        () => mockReactionsBloc.state,
      ).thenReturn(const CommentReactionsState());
    });

    tearDown(() {
      scrollController.dispose();
    });

    Widget buildTestWidget({
      CommentsListState? listState,
      CommentComposerState? composerState,
      VideoEvent? videoEvent,
      int? initialCommentCount,
      DraggableScrollableController? draggableController,
    }) {
      if (listState != null) {
        when(() => mockListBloc.state).thenReturn(listState);
      }
      if (composerState != null) {
        when(() => mockComposerBloc.state).thenReturn(composerState);
      }

      final effectiveDraggableController =
          draggableController ?? DraggableScrollableController();
      if (draggableController == null) {
        addTearDown(effectiveDraggableController.dispose);
      }

      final content = draggableController == null
          ? _CommentsScreenTestContent(
              videoEvent: videoEvent ?? testVideoEvent,
              sheetScrollController: scrollController,
              initialCommentCount: initialCommentCount ?? 0,
              draggableController: effectiveDraggableController,
            )
          : DraggableScrollableSheet(
              controller: effectiveDraggableController,
              expand: false,
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.93,
              snap: true,
              snapSizes: const [0.7, 0.93],
              builder: (context, sheetScrollController) =>
                  _CommentsScreenTestContent(
                    videoEvent: videoEvent ?? testVideoEvent,
                    sheetScrollController: sheetScrollController,
                    initialCommentCount: initialCommentCount ?? 0,
                    draggableController: effectiveDraggableController,
                  ),
            );

      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          isFeatureEnabledProvider(
            FeatureFlag.videoReplies,
          ).overrideWithValue(false),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Scaffold(
              body: MultiBlocProvider(
                providers: [
                  BlocProvider<CommentsListBloc>.value(value: mockListBloc),
                  BlocProvider<CommentComposerBloc>.value(
                    value: mockComposerBloc,
                  ),
                  BlocProvider<CommentReactionsBloc>.value(
                    value: mockReactionsBloc,
                  ),
                ],
                child: content,
              ),
            ),
          ),
        ),
      );
    }

    Widget buildTelemetryWidget({
      required SurfacePerformanceTracker tracker,
      Widget child = const SizedBox.shrink(),
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<CommentsListBloc>.value(
            value: mockListBloc,
            child: CommentsSheetLoadTelemetry(
              telemetry: CommentsSurfacePerformanceTelemetry.withTracker(
                tracker,
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    group('surface load telemetry', () {
      late _RecordingAnalyticsEventSink sink;
      late SurfacePerformanceTracker tracker;

      setUp(() {
        sink = _RecordingAnalyticsEventSink();
        tracker = SurfacePerformanceTracker(
          history: PageLoadHistory(),
          sink: sink,
        );
      });

      testWidgets(
        'completes success with comment metrics after loading state',
        (tester) async {
          final comment = CommentBuilder()
              .withId(TestCommentIds.comment1Id)
              .withContent('Loaded comment')
              .build();
          final loaded = CommentsListState(
            rootEventId: testVideoEventId,
            rootAuthorPubkey: testVideoAuthorPubkey,
            status: CommentsStatus.success,
            commentsById: {comment.id: comment},
            hasMoreContent: false,
            sortMode: CommentsSortMode.topEngagement,
          );
          whenListen(
            mockListBloc,
            Stream.fromIterable([
              const CommentsListState(status: CommentsStatus.loading),
              loaded,
            ]),
            initialState: const CommentsListState(
              status: CommentsStatus.loading,
            ),
          );
          tracker.startSurfaceLoad(AnalyticsSurface.commentsSheet);

          await tester.pumpWidget(buildTelemetryWidget(tracker: tracker));
          await tester.pump();

          expect(sink.events, hasLength(1));
          expect(sink.events.single.name, 'surface_load');
          expect(
            sink.events.single.parameters,
            containsPair(AnalyticsParam.result, SurfaceLoadResult.success),
          );
          expect(
            sink.events.single.parameters,
            containsPair(AnalyticsParam.itemCount, 1),
          );
          expect(
            sink.events.single.parameters,
            containsPair(AnalyticsParam.hasMore, 0),
          );
          expect(
            sink.events.single.parameters,
            containsPair(AnalyticsParam.sortMode, 'topEngagement'),
          );
        },
      );

      testWidgets('completes empty when loading resolves with no comments', (
        tester,
      ) async {
        const loaded = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          sortMode: CommentsSortMode.oldest,
        );
        whenListen(
          mockListBloc,
          Stream.fromIterable([
            const CommentsListState(status: CommentsStatus.loading),
            loaded,
          ]),
          initialState: const CommentsListState(status: CommentsStatus.loading),
        );
        tracker.startSurfaceLoad(AnalyticsSurface.commentsSheet);

        await tester.pumpWidget(buildTelemetryWidget(tracker: tracker));
        await tester.pump();

        expect(sink.events, hasLength(1));
        expect(
          sink.events.single.parameters,
          containsPair(AnalyticsParam.result, SurfaceLoadResult.empty),
        );
        expect(
          sink.events.single.parameters,
          containsPair(AnalyticsParam.itemCount, 0),
        );
        expect(
          sink.events.single.parameters,
          containsPair(AnalyticsParam.hasMore, 1),
        );
        expect(
          sink.events.single.parameters,
          containsPair(AnalyticsParam.sortMode, 'oldest'),
        );
      });

      testWidgets('completes failure without unsafe failure type metric', (
        tester,
      ) async {
        const failed = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.failure,
          error: CommentsListError.loadFailed,
        );
        whenListen(
          mockListBloc,
          Stream.fromIterable([
            const CommentsListState(status: CommentsStatus.loading),
            failed,
          ]),
          initialState: const CommentsListState(status: CommentsStatus.loading),
        );
        tracker.startSurfaceLoad(AnalyticsSurface.commentsSheet);

        await tester.pumpWidget(buildTelemetryWidget(tracker: tracker));
        await tester.pump();

        expect(sink.events, hasLength(1));
        expect(
          sink.events.single.parameters,
          containsPair(AnalyticsParam.result, SurfaceLoadResult.failure),
        );
        expect(sink.events.single.parameters, isNot(contains('failure_type')));
      });
    });

    testWidgets('anchors the sheet title for UI tests', (tester) async {
      await tester.pumpWidget(buildTestWidget(initialCommentCount: 3));

      expect(
        find.bySemanticsIdentifier(SemanticIds.commentsSheetTitle),
        findsOneWidget,
      );
    });

    group('widget structure', () {
      testWidgets('renders CommentsList', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.byType(CommentsList), findsOneWidget);
      });

      testWidgets('renders CommentInput', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.byType(CommentInput), findsOneWidget);
      });

      testWidgets('renders Divider between header and list', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.byType(Divider), findsOneWidget);
      });
    });

    group('comment input', () {
      testWidgets('has "Add comment..." hint text', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.commentsInputHint), findsOneWidget);
      });

      testWidgets('adds CommentTextChanged on text entry', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        await tester.enterText(find.byType(TextField).first, 'Test comment');
        await tester.pump();

        final captured =
            verify(() => mockComposerBloc.add(captureAny())).captured.last
                as CommentTextChanged;
        expect(captured.text, 'Test comment');
      });

      testWidgets('expands sheet to max when the composer gains focus', (
        tester,
      ) async {
        final draggableController = DraggableScrollableController();
        addTearDown(draggableController.dispose);
        final comment = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .withContent('Visible comment')
            .build();
        final listState = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: {comment.id: comment},
        );

        await tester.pumpWidget(
          buildTestWidget(
            draggableController: draggableController,
            listState: listState,
            composerState: const CommentComposerState(
              mainInputText: 'ready to send',
            ),
          ),
        );
        await tester.pump();

        expect(draggableController.size, 0.7);

        await tester.tap(find.byType(TextField).first);
        await tester.pumpAndSettle();

        // The sheet fraction reaching max is the guard that keeps the fixed
        // chrome + composer + keyboard padding inside the visible region;
        // button presence alone wouldn't prove that.
        expect(draggableController.size, closeTo(0.93, 0.001));
        // The keyboard-dismiss affordance is focus-gated, so its presence
        // confirms focus actually took effect (not just that a node exists).
        expect(
          find.bySemanticsIdentifier('hide_comment_keyboard_button'),
          findsOneWidget,
        );
        // Draft text survives the focus-driven expand.
        expect(find.text('ready to send'), findsOneWidget);
      });

      testWidgets('keeps focused composer from settling below safe snap size', (
        tester,
      ) async {
        final draggableController = DraggableScrollableController();
        addTearDown(draggableController.dispose);
        final comment = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .withContent('Visible comment')
            .build();
        final listState = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: {comment.id: comment},
        );

        await tester.pumpWidget(
          buildTestWidget(
            draggableController: draggableController,
            listState: listState,
          ),
        );
        await tester.pump();

        await tester.tap(find.byType(TextField).first);
        await tester.pumpAndSettle();
        expect(draggableController.size, closeTo(0.93, 0.001));

        draggableController.jumpTo(0.5);
        await tester.pumpAndSettle();

        expect(draggableController.size, closeTo(0.93, 0.001));
      });

      testWidgets('re-clamps after an interrupted focus expand', (
        tester,
      ) async {
        final draggableController = DraggableScrollableController();
        addTearDown(draggableController.dispose);
        final comment = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .withContent('Visible comment')
            .build();
        final listState = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: {comment.id: comment},
        );

        await tester.pumpWidget(
          buildTestWidget(
            draggableController: draggableController,
            listState: listState,
          ),
        );
        await tester.pump();

        // Kick off the focus-driven expand but do NOT let it settle.
        await tester.tap(find.byType(TextField).first);
        await tester.pump(); // apply focus + start the expand animation
        await tester.pump(const Duration(milliseconds: 80)); // mid-flight
        expect(draggableController.size, greaterThan(0.7));
        expect(draggableController.size, lessThan(0.93));

        // Interrupt the in-flight expand while the composer stays focused.
        // `jumpTo` calls `startActivity`, which cancels the running `animateTo`
        // (a real drag would do the same but also drops focus). That
        // cancellation never resolves the `animateTo` future, so a latch
        // released on that future strands and permanently disables the
        // re-clamp for the rest of the sheet session.
        draggableController.jumpTo(0.5);
        await tester.pump();
        expect(draggableController.size, lessThan(0.7));

        // Elapse past the expand window (250ms) so the latch releases and
        // re-checks, then settle the re-clamp animation. With focus retained,
        // the sheet must return to max.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(draggableController.size, closeTo(0.93, 0.001));
      });

      testWidgets('hide keyboard keeps draft text available', (tester) async {
        final draggableController = DraggableScrollableController();
        addTearDown(draggableController.dispose);

        await tester.pumpWidget(
          buildTestWidget(draggableController: draggableController),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextField).first, 'draft reply');
        await tester.pumpAndSettle();

        await tester.tap(
          find.bySemanticsIdentifier('hide_comment_keyboard_button'),
        );
        await tester.pump();

        expect(find.text('draft reply'), findsOneWidget);
        expect(
          find.bySemanticsIdentifier('hide_comment_keyboard_button'),
          findsNothing,
        );
      });
    });

    group('reply toggling', () {
      testWidgets('tapping Reply adds CommentReplyToggled to composer', (
        tester,
      ) async {
        final comment = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .withContent('Test comment')
            .build();

        final state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: {comment.id: comment},
        );

        await tester.pumpWidget(buildTestWidget(listState: state));
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.commentReply));
        await tester.pump();

        final captured =
            verify(() => mockComposerBloc.add(captureAny())).captured.last
                as CommentReplyToggled;
        expect(captured.commentId, TestCommentIds.comment1Id);
      });

      testWidgets('shows reply indicator when replying', (tester) async {
        final comment = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .withAuthorPubkey(TestCommentIds.author1Pubkey)
            .withContent('Test comment')
            .build();

        final listState = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: {comment.id: comment},
        );
        const composerState = CommentComposerState(
          activeReplyCommentId: TestCommentIds.comment1Id,
        );

        await tester.pumpWidget(
          buildTestWidget(listState: listState, composerState: composerState),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        final generatedAuthorName = UserProfile.generatedNameFor(
          TestCommentIds.author1Pubkey,
        );
        expect(
          find.text('${l10n.commentReplyToPrefix} $generatedAuthorName'),
          findsOneWidget,
        );
        expect(_divineIcon(DivineIconName.x), findsWidgets);
      });
    });

    group('title count', () {
      testWidgets('shows initial count during loading', (tester) async {
        const state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.loading,
        );

        await tester.pumpWidget(
          buildTestWidget(listState: state, initialCommentCount: 5),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.commentsHeaderCount(5)), findsOneWidget);
      });

      testWidgets('shows loaded count after success', (tester) async {
        final c1 = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .withContent('Comment 1')
            .build();
        final c2 = CommentBuilder()
            .withId(TestCommentIds.comment2Id)
            .withContent('Comment 2')
            .build();

        final state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: {c1.id: c1, c2.id: c2},
        );

        await tester.pumpWidget(
          buildTestWidget(listState: state, initialCommentCount: 5),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.commentsHeaderCount(2)), findsOneWidget);
      });

      testWidgets('shows singular "Comment" for count of 1', (tester) async {
        const state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.loading,
        );

        await tester.pumpWidget(
          buildTestWidget(listState: state, initialCommentCount: 1),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.commentsHeaderCount(1)), findsOneWidget);
      });
    });

    group('threaded comments', () {
      testWidgets('renders nested reply with indentation', (tester) async {
        final parent = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .withAuthorPubkey(TestCommentIds.author1Pubkey)
            .withContent('Parent comment')
            .build();
        final reply = CommentBuilder()
            .withId(TestCommentIds.comment2Id)
            .withAuthorPubkey(TestCommentIds.author2Pubkey)
            .withContent('Reply comment')
            .asReplyTo(
              parentEventId: TestCommentIds.comment1Id,
              parentAuthorPubkey: TestCommentIds.author1Pubkey,
            )
            .build();

        final state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: {parent.id: parent, reply.id: reply},
        );

        await tester.pumpWidget(buildTestWidget(listState: state));
        await tester.pump();

        expect(find.text('Parent comment'), findsOneWidget);
        expect(find.text('Reply comment'), findsOneWidget);
        expect(find.byType(CommentItem), findsNWidgets(2));
      });
    });

    group('loading states', () {
      testWidgets('shows loading indicator in list when loading', (
        tester,
      ) async {
        const state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.loading,
        );

        await tester.pumpWidget(buildTestWidget(listState: state));
        await tester.pump();

        expect(find.byType(CommentsSkeletonLoader), findsOneWidget);
      });

      testWidgets('shows empty state when no comments', (tester) async {
        const state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
        );

        await tester.pumpWidget(buildTestWidget(listState: state));
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.commentsEmptyTitle), findsOneWidget);
        expect(find.text(l10n.commentsEmptySubtitle), findsOneWidget);
      });

      testWidgets(
        'does not show archive notice for recent videos with loop stats',
        (tester) async {
          const state = CommentsListState(
            rootEventId: testVideoEventId,
            rootAuthorPubkey: testVideoAuthorPubkey,
            status: CommentsStatus.success,
          );

          final recentVideoWithLoops = VideoEvent(
            id: testVideoEventId,
            pubkey: testVideoAuthorPubkey,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            content: 'recent video',
            timestamp: DateTime.now(),
            originalLoops: 13565,
          );

          await tester.pumpWidget(
            buildTestWidget(listState: state, videoEvent: recentVideoWithLoops),
          );
          await tester.pump();

          expect(find.text('Classic Vine'), findsNothing);
        },
      );

      testWidgets('shows archive notice for vintage recovered vines', (
        tester,
      ) async {
        const state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
        );

        final vintageRecoveredVine = VideoEvent(
          id: testVideoEventId,
          pubkey: testVideoAuthorPubkey,
          createdAt: 1473050841,
          content: 'classic vine',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1473050841 * 1000),
          rawTags: const {'platform': 'vine'},
          originalLoops: 3169386,
        );

        await tester.pumpWidget(
          buildTestWidget(listState: state, videoEvent: vintageRecoveredVine),
        );
        await tester.pump();

        expect(find.text('Classic Vine'), findsOneWidget);
      });

      testWidgets(
        'shows archive notice for original Vines with unknown original dates',
        (tester) async {
          const state = CommentsListState(
            rootEventId: testVideoEventId,
            rootAuthorPubkey: testVideoAuthorPubkey,
            status: CommentsStatus.success,
          );

          final vineWithUnknownOriginalDate = VideoEvent(
            id: '0e5e24db5148c7eda48b874dd44d5365071020e131a4f399f3ea6c7b996d3196',
            pubkey: testVideoAuthorPubkey,
            createdAt: 1777489813,
            content: 'classic vine',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1777489813 * 1000),
            rawTags: const {'platform': 'vine'},
          );

          await tester.pumpWidget(
            buildTestWidget(
              listState: state,
              videoEvent: vineWithUnknownOriginalDate,
            ),
          );
          await tester.pump();

          expect(find.text('Classic Vine'), findsOneWidget);
        },
      );
    });

    group('error handling', () {
      testWidgets('renders without snackbar when no error', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.byType(CommentsList), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      });
    });

    group('OutboxBridges integration (real bridge path, not mirrored)', () {
      testWidgets(
        'composer InsertPlaceholder outbox → list.OptimisticCommentInserted + ack',
        (tester) async {
          final placeholder = Comment(
            id: 'pending_comment_1',
            content: 'wip',
            authorPubkey: testVideoAuthorPubkey,
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
            rootEventId: testVideoEventId,
            rootAuthorPubkey: testVideoAuthorPubkey,
          );

          // Pump the screen with the real OutboxBridges wrapping the test
          // content. The composer mock then emits an outbox transition; the
          // bridges should dispatch the corresponding event onto the list
          // bloc + ack via ComposerOutboxConsumed.
          whenListen(
            mockComposerBloc,
            Stream.fromIterable([
              const CommentComposerState(),
              CommentComposerState(
                outbox: ComposerOutboxInsertPlaceholder(placeholder),
              ),
            ]),
            initialState: const CommentComposerState(),
          );

          await tester.pumpWidget(buildTestWidget());
          await tester.pump();

          final captured = verify(
            () => mockListBloc.add(captureAny<OptimisticCommentInserted>()),
          ).captured;
          expect(captured, hasLength(1));
          expect(
            (captured.first as OptimisticCommentInserted).placeholder.id,
            'pending_comment_1',
          );
          verify(
            () => mockComposerBloc.add(const ComposerOutboxConsumed()),
          ).called(1);
        },
      );

      testWidgets(
        'reactions RemoveByAuthor outbox → list.CommentsRemovedByAuthorFromStore + ack',
        (tester) async {
          whenListen(
            mockReactionsBloc,
            Stream.fromIterable(const [
              CommentReactionsState(),
              CommentReactionsState(
                outbox: ReactionsOutboxRemoveByAuthor(testVideoAuthorPubkey),
              ),
            ]),
            initialState: const CommentReactionsState(),
          );

          await tester.pumpWidget(buildTestWidget());
          await tester.pump();

          final captured = verify(
            () => mockListBloc.add(
              captureAny<CommentsRemovedByAuthorFromStore>(),
            ),
          ).captured;
          expect(
            (captured.first as CommentsRemovedByAuthorFromStore).authorPubkey,
            testVideoAuthorPubkey,
          );
          verify(
            () => mockReactionsBloc.add(const ReactionsOutboxConsumed()),
          ).called(1);
        },
      );
    });

    group('sheet controller disposal', () {
      testWidgets('cancels an in-flight expand before disposing so no '
          '"used after disposed" assert fires', (tester) async {
        final controller = DraggableScrollableController();

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DraggableScrollableSheet(
                controller: controller,
                expand: false,
                initialChildSize: 0.7,
                minChildSize: 0.5,
                maxChildSize: 0.93,
                snap: true,
                snapSizes: const [0.7, 0.93],
                builder: (context, scrollController) => ListView(
                  controller: scrollController,
                  children: const [SizedBox(height: 2000)],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(controller.isAttached, isTrue);

        // Arm a focus-style expand and interrupt it mid-flight, exactly as a
        // scrim / back dismiss does while _expandSheetForKeyboard is still
        // animating. The sheet future disposes the controller at pop-start,
        // before the sheet unmounts and detaches it.
        controller.animateTo(
          0.93,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        await tester.pump(); // start the animation
        await tester.pump(const Duration(milliseconds: 80)); // mid-flight
        expect(controller.size, greaterThan(0.7));
        expect(controller.size, lessThan(0.93));

        disposeCommentsSheetController(controller);

        // Advance past where the leftover animation ticks would have fired.
        // The plain-dispose path notifies the disposed controller on each
        // tick and throws; the cancel-first path leaves nothing ticking.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 40));
        }
        expect(tester.takeException(), isNull);

        // Unmounting the still-mounted sheet detaches the disposed
        // controller; that path must stay clean too.
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      });
    });
  });
}

/// Test content widget that mirrors the CommentsScreen body structure and
/// wraps the column in the production [OutboxBridges] so the integration
/// seam is exercised by every test that pumps the screen, not just the
/// dedicated bridge tests in `outbox_bridges_test.dart`.
class _CommentsScreenTestContent extends StatelessWidget {
  const _CommentsScreenTestContent({
    required this.videoEvent,
    required this.sheetScrollController,
    required this.initialCommentCount,
    required this.draggableController,
  });

  final VideoEvent videoEvent;
  final ScrollController sheetScrollController;
  final int initialCommentCount;
  final DraggableScrollableController draggableController;

  @override
  Widget build(BuildContext context) {
    return OutboxBridges(
      onCommentCountChanged: null,
      child: Column(
        children: [
          _TestCommentsTitle(initialCount: initialCommentCount),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: CommentsList(
              showClassicVineNotice: videoEvent.isOriginalVine,
              scrollController: sheetScrollController,
            ),
          ),
          MainCommentInput(draggableController: draggableController),
        ],
      ),
    );
  }
}

/// Test replica of `_CommentsTitle` from comments_screen.dart.
class _TestCommentsTitle extends StatelessWidget {
  const _TestCommentsTitle({required this.initialCount});

  final int initialCount;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommentsListBloc, CommentsListState>(
      buildWhen: (prev, next) =>
          prev.commentsById.length != next.commentsById.length ||
          prev.status != next.status,
      builder: (context, state) {
        final count = state.status == CommentsStatus.success
            ? state.commentsById.length
            : initialCount;

        return Semantics(
          identifier: SemanticIds.commentsSheetTitle,
          container: true,
          child: Text(context.l10n.commentsHeaderCount(count)),
        );
      },
    );
  }
}
