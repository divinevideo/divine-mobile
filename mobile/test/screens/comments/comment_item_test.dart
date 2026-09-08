// ABOUTME: Widget tests for CommentItem with the split CommentComposerBloc +
// ABOUTME: CommentReactionsBloc provider tree.

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/comments/comment_composer/comment_composer_bloc.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_helpers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/comments/widgets/comment_item.dart';
import 'package:openvine/screens/comments/widgets/video_comment_player.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../builders/comment_builder.dart';

class _FakeNostrClient implements NostrClient {
  const _FakeNostrClient();

  @override
  String get publicKey => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockComposerBloc
    extends MockBloc<CommentComposerEvent, CommentComposerState>
    implements CommentComposerBloc {}

class _MockReactionsBloc
    extends MockBloc<CommentReactionsEvent, CommentReactionsState>
    implements CommentReactionsBloc {}

const _testHexPubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _testRootEventId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _testRootAuthorPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    registerFallbackValue(const CommentReplyToggled(''));
    registerFallbackValue(const CommentReactionsErrorCleared());
  });

  ({_MockComposerBloc composer, _MockReactionsBloc reactions}) buildMocks() {
    final composer = _MockComposerBloc();
    final reactions = _MockReactionsBloc();
    when(() => composer.state).thenReturn(const CommentComposerState());
    when(() => reactions.state).thenReturn(const CommentReactionsState());
    return (composer: composer, reactions: reactions);
  }

  Widget buildTestWidget(
    String content, {
    required _MockComposerBloc composerBloc,
    required _MockReactionsBloc reactionsBloc,
    Comment? comment,
  }) {
    comment ??= CommentBuilder()
        .withAuthorPubkey(_testHexPubkey)
        .withRootEventId(_testRootEventId)
        .withRootAuthorPubkey(_testRootAuthorPubkey)
        .withContent(content)
        .build();

    return ProviderScope(
      overrides: [
        nostrServiceProvider.overrideWithValue(const _FakeNostrClient()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<CommentComposerBloc>.value(value: composerBloc),
              BlocProvider<CommentReactionsBloc>.value(value: reactionsBloc),
            ],
            child: SingleChildScrollView(child: CommentItem(comment: comment)),
          ),
        ),
      ),
    );
  }

  Text contentText(WidgetTester tester) {
    return tester.widget<Text>(
      find.descendant(
        of: find.byType(LinkifiedText),
        matching: find.byType(Text),
      ),
    );
  }

  testWidgets('votes a video reply with its own coordinate and kind, not the '
      "parent video's (#6124)", (tester) async {
    // The reply's own coordinate is deliberate: funnelcake's
    // engagement_counts_by_coordinate_a_mv counts kind-7 `a` tags with no
    // content filter, so sending the parent video's coordinate would make
    // every comment vote inflate that video's public reaction_count.
    const ownCoordinate = '34236:$_testHexPubkey:reply-d-tag';
    final mocks = buildMocks();
    final reply = CommentBuilder()
        .withAuthorPubkey(_testHexPubkey)
        .withRootEventId(_testRootEventId)
        .withRootAuthorPubkey(_testRootAuthorPubkey)
        .withContent('a video reply')
        .asVideoReply(ownCoordinate: ownCoordinate)
        .build();

    await tester.pumpWidget(
      buildTestWidget(
        'a video reply',
        composerBloc: mocks.composer,
        reactionsBloc: mocks.reactions,
        comment: reply,
      ),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsIdentifier('upvote_button'));
    await tester.pump();

    final dispatched = verify(
      () => mocks.reactions.add(captureAny()),
    ).captured.whereType<CommentVoteToggled>().single;

    expect(dispatched.addressableId, equals(ownCoordinate));
    expect(dispatched.targetKind, equals(34236));
    expect(dispatched.commentId, equals(reply.id));
    // The root event is the parent video; its id must not leak into the vote.
    expect(dispatched.addressableId, isNot(contains(_testRootEventId)));
  });

  testWidgets('renders bare npub mentions as interactive profile links', (
    tester,
  ) async {
    final mocks = buildMocks();
    final npub = NostrKeyUtils.encodePubKey(_testHexPubkey);

    await tester.pumpWidget(
      buildTestWidget(
        'My account is $npub',
        composerBloc: mocks.composer,
        reactionsBloc: mocks.reactions,
      ),
    );
    await tester.pump();

    expect(find.byType(LinkifiedText), findsOneWidget);
    final fallbackName = UserProfile.defaultDisplayNameFor(_testHexPubkey);
    expect(find.textContaining('@$fallbackName'), findsOneWidget);
  });

  testWidgets('renders comment urls with tappable spans', (tester) async {
    final mocks = buildMocks();

    await tester.pumpWidget(
      buildTestWidget(
        'checkout https://divine.video/leaderboard',
        composerBloc: mocks.composer,
        reactionsBloc: mocks.reactions,
      ),
    );
    await tester.pump();

    expect(find.byType(LinkifiedText), findsOneWidget);

    final text = contentText(tester);
    final textSpan = text.textSpan! as TextSpan;
    final spans = textSpan.children!.cast<TextSpan>();
    final linkSpan = spans.firstWhere(
      (span) => span.text == 'https://divine.video/leaderboard',
    );

    expect(linkSpan.recognizer, isA<TapGestureRecognizer>());
  });

  testWidgets(
    'tapping Reply still dispatches CommentReplyToggled (#5854 scroll intact)',
    (tester) async {
      final mocks = buildMocks();

      await tester.pumpWidget(
        buildTestWidget(
          'hello there',
          composerBloc: mocks.composer,
          reactionsBloc: mocks.reactions,
        ),
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.commentReply));
      await tester.pump();

      // The reply-tap now also scrolls the comment into view (#5854); the
      // reply-mode toggle must still fire.
      verify(
        () => mocks.composer.add(any(that: isA<CommentReplyToggled>())),
      ).called(1);
    },
  );

  testWidgets('pending placeholders do not expose live comment actions', (
    tester,
  ) async {
    final mocks = buildMocks();
    final pending = CommentBuilder()
        .withId('${commentPlaceholderIdPrefix}1')
        .withAuthorPubkey(_testHexPubkey)
        .withRootEventId(_testRootEventId)
        .withRootAuthorPubkey(_testRootAuthorPubkey)
        .withContent('Posting...')
        .build();

    await tester.pumpWidget(
      buildTestWidget(
        'Posting...',
        composerBloc: mocks.composer,
        reactionsBloc: mocks.reactions,
        comment: pending,
      ),
    );
    await tester.pump();

    expect(find.bySemanticsIdentifier('reply_button'), findsNothing);
    expect(find.bySemanticsIdentifier('upvote_button'), findsNothing);
    expect(find.bySemanticsIdentifier('downvote_button'), findsNothing);

    await tester.longPress(find.byType(CommentItem));
    await tester.pumpAndSettle();

    // The title is shared by both modal variants; a delete-option assertion
    // would pass even with the sheet open, since isCurrentUser is false here.
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.commentOptionsTitle), findsNothing);
    verifyNever(() => mocks.composer.add(any()));
    verifyNever(() => mocks.reactions.add(any()));
  });

  testWidgets('opens video comments with hydrated route data', (tester) async {
    final mocks = buildMocks();

    final comment = CommentBuilder()
        .withId(
          '232cc79d5c91b01d538b2111df380b521f8a927fa52de3844b5feac7aff40c2f',
        )
        .withAuthorPubkey(_testHexPubkey)
        .withRootEventId(_testRootEventId)
        .withRootAuthorPubkey(_testRootAuthorPubkey)
        .withContent('Ferns')
        .build()
        .copyWith(
          videoUrl: 'https://media.divine.video/6ab6f26428369761ff7fda84166f5dc4981d93d43370c30171d74b036286b020',
          thumbnailUrl: 'https://media.divine.video/748855341e45388bc6a2aeacccc68161b8da4a817b11b1e7527423582ec6d42b',
          videoDimensions: '1080x1920',
          videoDuration: 6,
          videoBlurhash:
              'vjIOqbD%t7M{~q%MM{WA?bWBWBt7t8Rjt7ofV[j@ayt7RjoffQWBogWAofay',
        );

    VideoDetailRouteExtra? capturedExtra;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<CommentComposerBloc>.value(value: mocks.composer),
                BlocProvider<CommentReactionsBloc>.value(
                  value: mocks.reactions,
                ),
              ],
              child: SingleChildScrollView(
                child: CommentItem(comment: comment),
              ),
            ),
          ),
        ),
        GoRoute(
          path: VideoDetailScreen.path,
          builder: (context, state) {
            capturedExtra = state.extra as VideoDetailRouteExtra?;
            return const Scaffold(body: Text('video route'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nostrServiceProvider.overrideWithValue(const _FakeNostrClient()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Open video comment'));
    await tester.pumpAndSettle();

    expect(find.text('video route'), findsOneWidget);
    expect(capturedExtra?.initialVideo, isA<VideoEvent>());
    expect(capturedExtra?.initialVideo?.id, comment.id);
    expect(capturedExtra?.initialVideo?.videoUrl, comment.videoUrl);
    expect(capturedExtra?.initialVideo?.thumbnailUrl, comment.thumbnailUrl);
    expect(capturedExtra?.initialVideo?.title, comment.content);
    expect(capturedExtra?.initialVideo?.isVideoReply, isTrue);
    expect(capturedExtra?.initialVideo?.replyRootRouteId, _testRootEventId);
  });

  testWidgets('wraps the inline video player with rounded corners', (
    tester,
  ) async {
    final mocks = buildMocks();
    final comment = CommentBuilder()
        .withAuthorPubkey(_testHexPubkey)
        .withRootEventId(_testRootEventId)
        .withRootAuthorPubkey(_testRootAuthorPubkey)
        .withContent('Ferns')
        .build()
        .copyWith(
          videoUrl: 'https://media.divine.video/some-video.mp4',
          thumbnailUrl: 'https://media.divine.video/some-thumb.jpg',
          videoDimensions: '1080x1920',
          videoDuration: 6,
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nostrServiceProvider.overrideWithValue(const _FakeNostrClient()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<CommentComposerBloc>.value(value: mocks.composer),
                BlocProvider<CommentReactionsBloc>.value(
                  value: mocks.reactions,
                ),
              ],
              child: SingleChildScrollView(
                child: CommentItem(comment: comment),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final player = tester.widget<VideoCommentPlayer>(
      find.byType(VideoCommentPlayer),
    );
    expect(player.borderRadius, BorderRadius.circular(12));

    // Drain VisibilityDetector's 500ms debounce and the identity skeleton's
    // 7s fallthrough so no pending timers leak into the next test.
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  });

  group('Identity skeleton (#4163 follow-up)', () {
    testWidgets(
      'wraps the author row in IdentitySkeletonizer with isLoading=true '
      'while the profile has not resolved',
      (tester) async {
        final mocks = buildMocks();

        await tester.pumpWidget(
          buildTestWidget(
            'hello',
            composerBloc: mocks.composer,
            reactionsBloc: mocks.reactions,
          ),
        );
        await tester.pump();

        final skeletonizer = tester.widget<IdentitySkeletonizer>(
          find.byType(IdentitySkeletonizer),
        );
        expect(
          skeletonizer.isLoading,
          isTrue,
          reason:
              'profile is null → IdentitySkeletonizer.isLoading should be true',
        );

        expect(
          find.text(UserProfile.generatedNameFor(_testHexPubkey)),
          findsOneWidget,
        );

        // Past the 7s fallthrough — let the timer fire and the switch
        // animation settle so no pending timers leak into the next test.
        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();
      },
    );
  });

  group('author navigation', () {
    testWidgets('tapping the author avatar opens the author profile', (
      tester,
    ) async {
      final mocks = buildMocks();

      final comment = CommentBuilder()
          .withAuthorPubkey(_testHexPubkey)
          .withRootEventId(_testRootEventId)
          .withRootAuthorPubkey(_testRootAuthorPubkey)
          .withContent('hello')
          .build();

      // Resolve the author profile so IdentitySkeletonizer is disabled —
      // Skeletonizer.ignorePointers defaults to true, so a still-loading
      // (null) profile would swallow the avatar tap.
      const cleanedName = 'Ada\u0300\u0301';
      final profile = UserProfile(
        pubkey: _testHexPubkey,
        displayName: '',
        name: '$cleanedName\u0302\u0303',
        rawData: const {},
        createdAt: DateTime.utc(2026, 6, 28),
        eventId:
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
      );

      final expectedNpub = NostrKeyUtils.encodePubKey(_testHexPubkey);
      const expectedProfileLabel = "View $cleanedName's profile";

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: MultiBlocProvider(
                providers: [
                  BlocProvider<CommentComposerBloc>.value(
                    value: mocks.composer,
                  ),
                  BlocProvider<CommentReactionsBloc>.value(
                    value: mocks.reactions,
                  ),
                ],
                child: SingleChildScrollView(
                  child: CommentItem(comment: comment),
                ),
              ),
            ),
          ),
          GoRoute(
            path: OtherProfileScreen.pathWithNpub,
            builder: (context, state) =>
                Scaffold(body: Text('profile:${state.pathParameters['npub']}')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nostrServiceProvider.overrideWithValue(const _FakeNostrClient()),
            userProfileReactiveProvider(
              _testHexPubkey,
            ).overrideWith((ref) => Stream.value(profile)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == expectedProfileLabel &&
              widget.properties.button == true,
        ),
        findsNWidgets(2),
        reason:
            'The avatar and visible author name should both be announced as '
            'profile-opening buttons with the same sanitized display name.',
      );

      await tester.tap(find.byType(UserAvatar));
      await tester.pumpAndSettle();

      expect(find.text('profile:$expectedNpub'), findsOneWidget);
    });
  });
}
