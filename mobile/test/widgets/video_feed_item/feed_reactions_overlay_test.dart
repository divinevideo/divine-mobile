// ABOUTME: Widget tests for FeedReactionsOverlay — hidden until the top comment
// ABOUTME: is due, its author row, dismissal, and reduced motion.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart'
    show LatestAddressableEvents, NostrClient;
import 'package:nostr_sdk/nostr_sdk.dart' as nostr;
import 'package:openvine/blocs/feed_top_comment/feed_top_comment_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/routes/profile_routes.dart';
import 'package:openvine/router/routes/search_routes.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_feed_item/feed_reactions_overlay.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../helpers/go_router.dart';

class _MockFeedTopCommentCubit extends MockCubit<FeedTopCommentState>
    implements FeedTopCommentCubit {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockCommentModerationRepository extends Mock
    implements CommentModerationRepository {}

class _MockBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this.pubkey);
  final String? pubkey;
  @override
  NostrSessionReadiness build() {
    final key = pubkey;
    return key == null
        ? const NostrSessionReadiness.signedOut()
        : NostrSessionReadiness.identityKnown(pubkey: key);
  }
}

/// Counts its own `initState`s, so a test can tell a remount from a rebuild.
class _MountCounter extends StatefulWidget {
  const _MountCounter({required this.onMount});

  final VoidCallback onMount;

  @override
  State<_MountCounter> createState() => _MountCounterState();
}

class _MountCounterState extends State<_MountCounter> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<FeedTopCommentCubit?>();
    return Text(cubit == null ? 'no cubit' : 'cubit');
  }
}

const _creator =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _commenter =
    '3333333333333333333333333333333333333333333333333333333333333333';

final _video = VideoEvent(
  id: '1111111111111111111111111111111111111111111111111111111111111111',
  pubkey: _creator,
  createdAt: 1761650000,
  content: 'Amineeeee!',
  timestamp: DateTime(2026, 10, 28),
);

final _topComment = Comment(
  id: '5555555555555555555555555555555555555555555555555555555555555555',
  content: 'Wanna know more about it',
  authorPubkey: _commenter,
  createdAt: DateTime(2026, 10, 28),
  rootEventId: _video.id,
  rootAuthorPubkey: _creator,
);

final _visibleState = FeedTopCommentState(
  status: FeedTopCommentStatus.ready,
  topComment: _topComment,
  hasCompletedLoop: true,
);

void main() {
  group(FeedReactionsOverlay, () {
    late _MockFeedTopCommentCubit cubit;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockFeedTopCommentCubit();
    });

    Widget buildSubject({
      bool reducedMotion = false,
      TextScaler textScaler = TextScaler.noScaling,
      double topInset = 0,
      Locale? locale,
      List<Override> extraOverrides = const [],
    }) => ProviderScope(
      overrides: [
        ...extraOverrides,
        userProfileReactiveProvider(
          _commenter,
        ).overrideWith((ref) => Stream<UserProfile?>.value(null)),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reducedMotion,
            textScaler: textScaler,
            padding: EdgeInsets.only(top: topInset),
            viewPadding: EdgeInsets.only(top: topInset),
          ),
          child: Scaffold(
            body: BlocProvider<FeedTopCommentCubit>.value(
              value: cubit,
              child: FeedReactionsOverlay(video: _video),
            ),
          ),
        ),
      ),
    );

    group('renders', () {
      testWidgets('nothing before the first loop finishes', (tester) async {
        when(() => cubit.state).thenReturn(
          _visibleState.copyWith(hasCompletedLoop: false),
        );
        await tester.pumpWidget(buildSubject());

        expect(find.text(_topComment.content), findsNothing);
        expect(find.bySemanticsLabel(l10n.feedReactionDismiss), findsNothing);
      });

      testWidgets('the top comment in a white bubble, its author below', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(_visibleState);
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        final comment = find.text(_topComment.content);
        final authorName = find.text(UserProfile.generatedNameFor(_commenter));
        expect(comment, findsOneWidget);
        expect(find.byType(UserAvatar), findsOneWidget);
        expect(authorName, findsOneWidget);

        final bubble = find.ancestor(
          of: comment,
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color ==
                    FeedReactionsOverlayLayout.bubbleColor,
          ),
        );
        expect(bubble, findsOneWidget);
        expect(
          (tester.widget<DecoratedBox>(bubble).decoration as BoxDecoration)
              .borderRadius,
          BorderRadius.circular(FeedReactionsOverlayLayout.bubbleRadius),
        );

        final tail = find.byType(SvgPicture);
        expect(tail, findsOneWidget);
        final bubbleRect = tester.getRect(bubble);
        final tailRect = tester.getRect(tail);
        expect(tailRect.top, bubbleRect.bottom);
        expect(
          tailRect.left,
          bubbleRect.left + FeedReactionsOverlayLayout.tailInset,
        );
        expect(tailRect.size, const Size(22, 16));

        expect(
          tester.getRect(authorName).top,
          greaterThanOrEqualTo(tailRect.bottom),
        );
      });

      testWidgets(
        'the tail by the start edge, mirrored, in a right-to-left locale',
        (tester) async {
          when(() => cubit.state).thenReturn(_visibleState);
          await tester.pumpWidget(buildSubject(locale: const Locale('ar')));
          await tester.pump();

          final bubble = find.ancestor(
            of: find.text(_topComment.content),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).color ==
                      FeedReactionsOverlayLayout.bubbleColor,
            ),
          );
          final tail = find.byType(SvgPicture);
          expect(
            tester.getRect(tail).right,
            tester.getRect(bubble).right - FeedReactionsOverlayLayout.tailInset,
          );
          expect(tester.widget<SvgPicture>(tail).matchTextDirection, isTrue);
        },
      );

      group('a bubble as wide as its comment', () {
        Finder bubbleOf(String content) => find.ancestor(
          of: find.text(content),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color ==
                    FeedReactionsOverlayLayout.bubbleColor,
          ),
        );

        Future<double> pumpWith(WidgetTester tester, String content) async {
          when(() => cubit.state).thenReturn(
            _visibleState.copyWith(
              topComment: Comment(
                id: _topComment.id,
                content: content,
                authorPubkey: _commenter,
                createdAt: DateTime(2026, 10, 28),
                rootEventId: _video.id,
                rootAuthorPubkey: _creator,
              ),
            ),
          );
          await tester.pumpWidget(buildSubject());
          await tester.pump();
          return tester.getSize(bubbleOf(content)).width;
        }

        testWidgets(
          'narrow for a short comment, but wide enough for the tail',
          (
            tester,
          ) async {
            final width = await pumpWith(tester, 'ok');
            final available =
                tester.getSize(find.byType(FeedReactionsOverlay)).width -
                2 * FeedReactionsOverlayLayout.sidePadding;

            expect(width, lessThan(available / 2));
            expect(
              width,
              greaterThanOrEqualTo(FeedReactionsOverlayLayout.bubbleMinWidth),
            );
          },
        );

        testWidgets('its longest line for a comment that wraps short', (
          tester,
        ) async {
          // Two words that each take over half a line, so the comment wraps
          // after the first and its longest line ends well short of the edge.
          final content = '${'w' * 16} ${'w' * 16}';
          final width = await pumpWith(tester, content);
          final available =
              tester.getSize(find.byType(FeedReactionsOverlay)).width -
              2 * FeedReactionsOverlayLayout.sidePadding;
          final style = VineTheme.headlineLargeFont();
          final lineHeight = style.height! * style.fontSize!;

          expect(
            tester.getSize(find.text(content)).height,
            greaterThan(lineHeight * 1.5),
            reason: 'the comment wraps',
          );
          expect(width, lessThan(available * 0.8));
        });

        testWidgets('the full width for a comment that wraps', (tester) async {
          final width = await pumpWith(
            tester,
            'this comment is long enough to wrap onto several lines of the bubble '
            'when it is shown',
          );
          final available =
              tester.getSize(find.byType(FeedReactionsOverlay)).width -
              2 * FeedReactionsOverlayLayout.sidePadding;

          expect(width, greaterThan(available * 0.8));
          expect(width, lessThanOrEqualTo(available));
        });
      });

      testWidgets('a six-line comment on screen at the largest text size', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          _visibleState.copyWith(
            topComment: Comment(
              id: _topComment.id,
              content: List.filled(40, 'reaction').join(' '),
              authorPubkey: _commenter,
              createdAt: DateTime(2026, 10, 28),
              rootEventId: _video.id,
              rootAuthorPubkey: _creator,
            ),
          ),
        );
        await tester.pumpWidget(
          buildSubject(textScaler: const TextScaler.linear(3)),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.byType(UserAvatar)).bottom,
          lessThanOrEqualTo(
            tester.getRect(find.byType(FeedReactionsOverlay)).bottom,
          ),
        );
      });

      testWidgets('a long comment on a short phone at a large text size', (
        tester,
      ) async {
        // A 360x640 dp phone's feed item, under its status bar and bottom nav.
        await tester.binding.setSurfaceSize(const Size(360, 544));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final content = List.filled(40, 'reaction').join(' ');
        when(() => cubit.state).thenReturn(
          _visibleState.copyWith(
            topComment: Comment(
              id: _topComment.id,
              content: content,
              authorPubkey: _commenter,
              createdAt: DateTime(2026, 10, 28),
              rootEventId: _video.id,
              rootAuthorPubkey: _creator,
            ),
          ),
        );
        await tester.pumpWidget(
          buildSubject(textScaler: const TextScaler.linear(2), topInset: 24),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text(content), findsOneWidget);
        expect(
          tester.getRect(find.byType(UserAvatar)).bottom,
          lessThanOrEqualTo(
            tester.getRect(find.byType(FeedReactionsOverlay)).bottom,
          ),
        );
      });

      testWidgets('a mention as the comments sheet does, by display name', (
        tester,
      ) async {
        const mentionedHex =
            '6666666666666666666666666666666666666666666666666666666666666666';
        final npub = NostrKeyUtils.encodePubKey(mentionedHex);
        when(() => cubit.state).thenReturn(
          _visibleState.copyWith(
            topComment: Comment(
              id: _topComment.id,
              content: 'yesss nostr:$npub 👏',
              authorPubkey: _commenter,
              createdAt: DateTime(2026, 10, 28),
              rootEventId: _video.id,
              rootAuthorPubkey: _creator,
            ),
          ),
        );
        await tester.pumpWidget(
          buildSubject(
            extraOverrides: [
              userProfileReactiveProvider(mentionedHex).overrideWith(
                (ref) => Stream<UserProfile?>.value(
                  UserProfile(
                    pubkey: mentionedHex,
                    rawData: const {},
                    createdAt: DateTime(2026),
                    eventId: _topComment.id,
                    displayName: 'Ryohei Nakatake',
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        expect(
          find.textContaining('@Ryohei Nakatake', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('nostr:npub', findRichText: true),
          findsNothing,
        );
        expect(find.byType(LinkifiedText), findsOneWidget);
      });

      testWidgets(
        'a solid scrim down to the comment, then a gradient to the bottom',
        (tester) async {
          when(() => cubit.state).thenReturn(_visibleState);
          await tester.pumpWidget(buildSubject());
          await tester.pump();

          final solid = find.byWidgetPredicate(
            (w) =>
                w is ColoredBox && w.color == FeedReactionsOverlayLayout.scrim,
          );
          final gradient = find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).gradient?.colors.first ==
                    FeedReactionsOverlayLayout.scrim,
          );
          expect(solid, findsOneWidget);
          expect(gradient, findsOneWidget);

          final solidRect = tester.getRect(solid);
          final commentRect = tester.getRect(find.text(_topComment.content));
          final gradientRect = tester.getRect(gradient);
          final screen = tester.getRect(find.byType(FeedReactionsOverlay));
          expect(solidRect.top, screen.top);
          final authorRect = tester.getRect(find.byType(UserAvatar));
          expect(commentRect.bottom, lessThan(authorRect.top));
          expect(
            solidRect.bottom,
            authorRect.bottom + FeedReactionsOverlayLayout.solidBelowContent,
          );
          expect(gradientRect.top, solidRect.bottom);
          expect(gradientRect.bottom, screen.bottom);
          expect(
            (tester.widget<DecoratedBox>(gradient).decoration as BoxDecoration)
                .gradient!
                .colors,
            [FeedReactionsOverlayLayout.scrim, VineTheme.transparent],
          );
        },
      );

      testWidgets('fades in when the overlay becomes due', (tester) async {
        whenListen(
          cubit,
          Stream.value(_visibleState),
          initialState: _visibleState.copyWith(hasCompletedLoop: false),
        );
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, 1);
        expect(opacity.duration, FeedReactionsOverlayLayout.fadeDuration);
      });

      testWidgets('announces the comment to screen readers when it appears', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        whenListen(
          cubit,
          Stream.value(_visibleState),
          initialState: _visibleState.copyWith(hasCompletedLoop: false),
        );
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        expect(
          tester.takeAnnouncements(),
          isEmpty,
          reason: 'not before it has faded in',
        );

        await tester.pumpAndSettle();
        expect(
          tester.takeAnnouncements().map((a) => a.message),
          [_topComment.content],
        );
        handle.dispose();
      });

      testWidgets('does not announce a reaction gone before its fade ended', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final states = StreamController<FeedTopCommentState>();
        addTearDown(states.close);
        whenListen(
          cubit,
          states.stream,
          initialState: _visibleState.copyWith(hasCompletedLoop: false),
        );
        await tester.pumpWidget(buildSubject());
        states.add(_visibleState);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        states.add(_visibleState.copyWith(isDismissed: true));
        await tester.pumpAndSettle();

        expect(tester.takeAnnouncements(), isEmpty);
        handle.dispose();
      });

      testWidgets('announces at once under reduced motion', (tester) async {
        final handle = tester.ensureSemantics();
        whenListen(
          cubit,
          Stream.value(_visibleState),
          initialState: _visibleState.copyWith(hasCompletedLoop: false),
        );
        await tester.pumpWidget(buildSubject(reducedMotion: true));
        await tester.pump();

        expect(
          tester.takeAnnouncements().map((a) => a.message),
          [_topComment.content],
        );
        handle.dispose();
      });

      testWidgets('announces a mention by name, as the bubble shows it', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        const mentionedHex =
            '6666666666666666666666666666666666666666666666666666666666666666';
        final npub = NostrKeyUtils.encodePubKey(mentionedHex);
        final withMention = _visibleState.copyWith(
          topComment: Comment(
            id: _topComment.id,
            content: 'yesss nostr:$npub so good',
            authorPubkey: _commenter,
            createdAt: DateTime(2026, 10, 28),
            rootEventId: _video.id,
            rootAuthorPubkey: _creator,
          ),
        );
        whenListen(
          cubit,
          Stream.value(withMention),
          initialState: withMention.copyWith(hasCompletedLoop: false),
        );
        await tester.pumpWidget(
          buildSubject(
            extraOverrides: [
              userProfileReactiveProvider(mentionedHex).overrideWith(
                (ref) => Stream<UserProfile?>.value(
                  UserProfile(
                    pubkey: mentionedHex,
                    rawData: const {},
                    createdAt: DateTime(2026),
                    eventId: _topComment.id,
                    displayName: 'Ryohei Nakatake',
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeAnnouncements().map((a) => a.message),
          ['yesss @Ryohei Nakatake so good'],
        );
        handle.dispose();
      });

      testWidgets('appears without a fade under reduced motion', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(_visibleState);
        await tester.pumpWidget(buildSubject(reducedMotion: true));

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.duration, Duration.zero);
      });
    });

    group('interactions', () {
      testWidgets(
        'tapping the scrim, solid or gradient, dismisses the reaction',
        (
          tester,
        ) async {
          when(() => cubit.state).thenReturn(_visibleState);
          await tester.pumpWidget(buildSubject());

          // Low on the screen, inside the gradient.
          await tester.tapAt(const Offset(200, 500));
          // Above the comment, inside the solid part.
          await tester.tapAt(const Offset(200, 40));

          verify(() => cubit.dismiss()).called(2);
        },
      );

      testWidgets('reads as a dismiss control and a comment by its author', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        when(() => cubit.state).thenReturn(_visibleState);
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.bySemanticsLabel(l10n.feedReactionDismiss), findsOneWidget);
        // Exactly the comment and its author, each once.
        expect(
          find.bySemanticsLabel(
            '${_topComment.content}\n'
            '${UserProfile.generatedNameFor(_commenter)}',
          ),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(RegExp('avatar')), findsNothing);
        handle.dispose();
      });

      testWidgets('reads a comment with a mention whole, as a button', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        const mentionedHex =
            '6666666666666666666666666666666666666666666666666666666666666666';
        final npub = NostrKeyUtils.encodePubKey(mentionedHex);
        when(() => cubit.state).thenReturn(
          _visibleState.copyWith(
            topComment: Comment(
              id: _topComment.id,
              content: 'yesss nostr:$npub so good',
              authorPubkey: _commenter,
              createdAt: DateTime(2026, 10, 28),
              rootEventId: _video.id,
              rootAuthorPubkey: _creator,
            ),
          ),
        );
        await tester.pumpWidget(
          buildSubject(
            extraOverrides: [
              userProfileReactiveProvider(mentionedHex).overrideWith(
                (ref) => Stream<UserProfile?>.value(
                  UserProfile(
                    pubkey: mentionedHex,
                    rawData: const {},
                    createdAt: DateTime(2026),
                    eventId: _topComment.id,
                    displayName: 'Ryohei Nakatake',
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        final button = find.bySemanticsLabel(
          RegExp(RegExp.escape('yesss @Ryohei Nakatake so good')),
        );
        expect(button, findsOneWidget);
        final data = tester.getSemantics(button).getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.hint, l10n.feedReactionOpenComment);
        handle.dispose();
      });

      testWidgets(
        'keeps inline profile and hashtag actions beside the whole comment',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            const mentioned =
                '6666666666666666666666666666666666666666666666666666666666666666';
            final npub = NostrKeyUtils.encodePubKey(mentioned);
            final router = MockGoRouter();
            when(() => router.push<void>(any())).thenAnswer((_) async {});
            when(() => router.push<Object?>(any()))
                .thenAnswer((_) async => null);
            when(() => cubit.state).thenReturn(
              _visibleState.copyWith(
                topComment: Comment(
                  id: _topComment.id,
                  content:
                      'before nostr:$npub and #synthetic after 💚 '
                      'https://example.com',
                  authorPubkey: _commenter,
                  createdAt: DateTime(2026, 10, 28),
                  rootEventId: _video.id,
                  rootAuthorPubkey: _creator,
                ),
              ),
            );
            await tester.pumpWidget(
              MockGoRouterProvider(
                goRouter: router,
                child: buildSubject(
                  extraOverrides: [
                    userProfileReactiveProvider(mentioned).overrideWith(
                      (ref) => Stream<UserProfile?>.value(
                        UserProfile(
                          pubkey: mentioned,
                          rawData: const {},
                          createdAt: DateTime(2026),
                          eventId: _topComment.id,
                          displayName: 'Synthetic Mention',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            final wholeLabel =
                'before @Synthetic Mention and #synthetic after 💚 '
                'https://example.com\n'
                '${UserProfile.generatedNameFor(_commenter)}';
            final button = find.bySemanticsLabel(wholeLabel);
            expect(button, findsOneWidget);
            final commentNode = tester.getSemantics(button);
            expect(
              commentNode.getSemanticsData().hasAction(SemanticsAction.tap),
              isTrue,
            );
            expect(
              commentNode.getSemanticsData().hint,
              l10n.feedReactionOpenComment,
            );
            final nodes = <SemanticsNode>[];
            void collect(SemanticsNode node) {
              nodes.add(node);
              node.visitChildren((child) {
                collect(child);
                return true;
              });
            }

            collect(commentNode.owner!.rootSemanticsNode!);
            expect(
              nodes.where(
                (node) => const ['before', 'and', 'after', '💚'].contains(
                  node.getSemanticsData().label.trim(),
                ),
              ),
              isEmpty,
              reason: 'plain runs are already read by the complete comment',
            );
            expect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is DivineIcon &&
                    widget.icon == DivineIconName.heartFill,
              ),
              findsOneWidget,
              reason: 'decorative heart painting is unchanged',
            );
            SemanticsNode inlineAction(String label) {
              final matches = nodes.where(
                (node) =>
                    node.getSemanticsData().label.trim() == label &&
                    node.getSemanticsData().hasAction(SemanticsAction.tap),
              );
              expect(
                matches,
                hasLength(1),
                reason: '$label has its own action',
              );
              return matches.single;
            }

            final mention = inlineAction('@Synthetic Mention');
            mention.owner!.performAction(mention.id, SemanticsAction.tap);
            await tester.pump();
            verify(
              () =>
                  router.push<void>(OtherProfileRouteData(npub: npub).location),
            ).called(1);
            final hashtag = inlineAction('#synthetic');
            hashtag.owner!.performAction(hashtag.id, SemanticsAction.tap);
            await tester.pump();
            verify(
              () => router.push<Object?>(
                const HashtagRouteData(tag: 'synthetic').location,
              ),
            ).called(1);
            inlineAction('https://example.com');
            verifyNever(() => cubit.dismiss());
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets('ignores taps until the reaction has faded in', (
        tester,
      ) async {
        whenListen(
          cubit,
          Stream.value(_visibleState),
          initialState: _visibleState.copyWith(hasCompletedLoop: false),
        );
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        await tester.tapAt(const Offset(200, 500));
        verifyNever(() => cubit.dismiss());

        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(200, 500));
        verify(() => cubit.dismiss()).called(1);
      });

      testWidgets('takes taps at once under reduced motion', (tester) async {
        whenListen(
          cubit,
          Stream.value(_visibleState),
          initialState: _visibleState.copyWith(hasCompletedLoop: false),
        );
        await tester.pumpWidget(buildSubject(reducedMotion: true));
        await tester.pump();

        await tester.tapAt(const Offset(200, 500));
        verify(() => cubit.dismiss()).called(1);
      });

      testWidgets('tapping beside a short comment dismisses the reaction', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          _visibleState.copyWith(
            topComment: Comment(
              id: _topComment.id,
              content: 'ok',
              authorPubkey: _commenter,
              createdAt: DateTime(2026, 10, 28),
              rootEventId: _video.id,
              rootAuthorPubkey: _creator,
            ),
          ),
        );
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        final comment = find.text('ok');
        final commentTapArea = find
            .ancestor(of: comment, matching: find.byType(GestureDetector))
            .first;
        final screen = tester.getRect(find.byType(FeedReactionsOverlay));
        expect(
          tester.getRect(commentTapArea).right,
          lessThan(screen.width / 2),
        );

        await tester.tapAt(
          Offset(
            screen.right - FeedReactionsOverlayLayout.sidePadding - 1,
            tester.getCenter(find.byType(UserAvatar)).dy,
          ),
        );
        verify(() => cubit.dismiss()).called(1);
      });
    });
  });

  group(HiddenWhileTopCommentShown, () {
    late _MockFeedTopCommentCubit cubit;

    setUp(() {
      cubit = _MockFeedTopCommentCubit();
    });

    Widget buildSubject({required bool provideCubit}) => MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: provideCubit
          ? BlocProvider<FeedTopCommentCubit>.value(
              value: cubit,
              child: const HiddenWhileTopCommentShown(child: Text('captions')),
            )
          : const HiddenWhileTopCommentShown(child: Text('captions')),
    );

    group('renders', () {
      testWidgets('its child without reactions', (tester) async {
        await tester.pumpWidget(buildSubject(provideCubit: false));

        expect(find.text('captions'), findsOneWidget);
      });

      testWidgets('its child while no reaction is up', (tester) async {
        when(() => cubit.state).thenReturn(const FeedTopCommentState());
        await tester.pumpWidget(buildSubject(provideCubit: true));

        expect(find.text('captions'), findsOneWidget);
      });

      testWidgets('nothing while the reaction is up, keeping its state', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(_visibleState);
        await tester.pumpWidget(buildSubject(provideCubit: true));

        expect(find.text('captions'), findsNothing);
        expect(
          find.text('captions', skipOffstage: false),
          findsOneWidget,
          reason: 'captions are hidden, not removed',
        );
      });
    });
  });

  group(FeedTopCommentHost, () {
    late _MockCommentsRepository commentsRepository;
    late _MockLikesRepository likesRepository;
    late _MockCommentModerationRepository moderationRepository;
    late _MockBlocklistRepository blocklistRepository;
    String? viewer;

    void stubModeration(CommentModeration moderation, {int revision = 0}) {
      when(
        () => moderationRepository.loadModeration(
          rootAddressableId: any(named: 'rootAddressableId'),
        ),
      ).thenAnswer((_) async => moderation);
      when(
        () => moderationRepository.knownModeration(
          rootAddressableId: any(named: 'rootAddressableId'),
        ),
      ).thenReturn((moderation: moderation, revision: revision));
      when(
        () => moderationRepository.watchModeration(
          rootAddressableId: any(named: 'rootAddressableId'),
        ),
      ).thenAnswer((_) => Stream.value(revision));
    }

    setUpAll(() {
      registerFallbackValue(<nostr.Filter>[]);
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      commentsRepository = _MockCommentsRepository();
      likesRepository = _MockLikesRepository();
      moderationRepository = _MockCommentModerationRepository();
      blocklistRepository = _MockBlocklistRepository();
      viewer = null;
      stubModeration(CommentModeration.empty);
      when(() => blocklistRepository.blockedPubkeysForAccount(any()))
          .thenReturn(const {});
      when(
        () => commentsRepository.findAuthorDeletedComments(any()),
      ).thenAnswer((_) async => <String>{});
      when(
        () => commentsRepository.loadComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => CommentThread(rootEventId: _video.id));
    });

    Widget buildSubject({
      required bool enabled,
      required VoidCallback onMount,
      VideoEvent? video,
      Stream<void> loopCompletions = const Stream<void>.empty(),
      LatestAddressableEvents? latestEvents,
      CommentModerationRepository? commentModeration,
    }) => ProviderScope(
      overrides: [
        commentsRepositoryProvider.overrideWithValue(commentsRepository),
        likesRepositoryProvider.overrideWithValue(likesRepository),
        commentModerationRepositoryProvider.overrideWithValue(
          commentModeration ?? moderationRepository,
        ),
        contentBlocklistRepositoryProvider.overrideWithValue(
          blocklistRepository,
        ),
        nostrSessionProvider.overrideWith(() => _TestNostrSession(viewer)),
        if (latestEvents != null)
          latestAddressableEventsProvider.overrideWithValue(latestEvents),
      ],
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FeedTopCommentHost(
          enabled: enabled,
          video: video ?? _video,
          loopCompletions: loopCompletions,
          child: _MountCounter(onMount: onMount),
        ),
      ),
    );

    group('renders', () {
      ({
        VideoEvent video,
        LatestAddressableEvents events,
        CommentModerationRepository moderation,
        String owner,
        String key,
      })
      realModeration() {
        final key = '1'.padLeft(64, '0');
        final owner = nostr.getPublicKey(key);
        final video = _video.copyWith(pubkey: owner, addressableDTag: 'root');
        final events = LatestAddressableEvents();
        addTearDown(events.dispose);
        final event = nostr.Event(
          owner,
          30078,
          [
            ['d', 'divine:replies:34236:$owner:root'],
          ],
          '',
          createdAt: 1000,
        )..sign(key);
        final client = _MockNostrClient();
        when(
          () =>
              client.queryEventsDetailed(any(), timeout: any(named: 'timeout')),
        ).thenAnswer(
          (_) async => (events: [event], timedOut: false, noRelays: false),
        );
        return (
          video: video,
          events: events,
          moderation: CommentModerationRepository(
            nostrClient: client,
            latestEvents: events,
          ),
          owner: owner,
          key: key,
        );
      }

      void stubVisibleComment() {
        when(
          () => commentsRepository.loadComments(
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootAddressableId: any(named: 'rootAddressableId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async =>
              CommentThread(rootEventId: _video.id, comments: [_topComment]),
        );
        when(
          () => likesRepository.getVoteCounts(
            any(),
            addressableIds: any(named: 'addressableIds'),
          ),
        ).thenAnswer(
          (_) async =>
              (upvotes: {_topComment.id: 20}, downvotes: <String, int>{}),
        );
      }

      FeedTopCommentCubit hosted(WidgetTester tester) => tester
          .element(find.byType(_MountCounter))
          .read<FeedTopCommentCubit?>()!;

      testWidgets('reads the comments once when moderation was not cached', (
        tester,
      ) async {
        stubVisibleComment();
        final data = realModeration();
        await tester.pumpWidget(
          buildSubject(
            enabled: true,
            onMount: () {},
            video: data.video,
            latestEvents: data.events,
            commentModeration: data.moderation,
          ),
        );
        await tester.pumpAndSettle();
        expect(hosted(tester).state.status, FeedTopCommentStatus.ready);
        expect(
          data.events.latest(
            pubkey: data.owner,
            kind: 30078,
            dTag: 'divine:replies:34236:${data.owner}:root',
          ),
          isNotNull,
        );
        verify(
          () => commentsRepository.loadComments(
            rootEventId: data.video.id,
            rootEventKind: data.video.referenceKind,
            rootAddressableId: data.video.addressableId,
            limit: FeedTopCommentCubit.commentPageSize,
          ),
        ).called(1);
      });

      testWidgets('does not reload for unrelated moderation coordinates', (
        tester,
      ) async {
        stubVisibleComment();
        final data = realModeration();
        await tester.pumpWidget(
          buildSubject(
            enabled: true,
            onMount: () {},
            video: data.video,
            latestEvents: data.events,
            commentModeration: data.moderation,
          ),
        );
        await tester.pumpAndSettle();
        final first = hosted(tester);
        expect(first.state.status, FeedTopCommentStatus.ready);
        clearInteractions(commentsRepository);
        data.events.remember(
          nostr.Event(
            data.owner,
            30078,
            [
              ['d', 'divine:replies:34236:${data.owner}:other-video'],
            ],
            '',
            createdAt: 2000,
          )..sign(data.key),
        );
        await tester.pumpAndSettle();
        expect(hosted(tester), same(first));
        verifyNever(
          () => commentsRepository.loadComments(
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootAddressableId: any(named: 'rootAddressableId'),
            limit: any(named: 'limit'),
          ),
        );
      });

      testWidgets(
        'does not reload when a scoped revision has unchanged comment policy',
        (tester) async {
          stubVisibleComment();
          final data = realModeration();
          await tester.pumpWidget(
            buildSubject(
              enabled: true,
              onMount: () {},
              video: data.video,
              latestEvents: data.events,
              commentModeration: data.moderation,
            ),
          );
          await tester.pumpAndSettle();
          final first = hosted(tester);
          expect(first.state.status, FeedTopCommentStatus.ready);
          clearInteractions(commentsRepository);
          data.events.remember(
            nostr.Event(
              data.owner,
              30078,
              [
                ['d', 'divine:replies:34236:${data.owner}:root'],
                ['a', '34236:$_commenter:reply', '', 'pinned'],
              ],
              '',
              createdAt: 2000,
            )..sign(data.key),
          );
          await tester.pumpAndSettle();
          expect(hosted(tester), same(first));
          verifyNever(
            () => commentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
            ),
          );
        },
      );

      testWidgets(
        'applies a relevant change during loading without fetching the page twice',
        (tester) async {
          stubVisibleComment();
          final data = realModeration();
          final votes =
              Completer<
                ({Map<String, int> upvotes, Map<String, int> downvotes})
              >();
          when(
            () => likesRepository.getVoteCounts(
              any(),
              addressableIds: any(named: 'addressableIds'),
            ),
          ).thenAnswer((_) => votes.future);
          await tester.pumpWidget(
            buildSubject(
              enabled: true,
              onMount: () {},
              video: data.video,
              latestEvents: data.events,
              commentModeration: data.moderation,
            ),
          );
          await tester.pumpAndSettle();
          final first = hosted(tester);
          expect(first.state.status, FeedTopCommentStatus.loading);
          expect(
            data.events.latest(
              pubkey: data.owner,
              kind: 30078,
              dTag: 'divine:replies:34236:${data.owner}:root',
            ),
            isNotNull,
          );
          data.events.remember(
            nostr.Event(
              data.owner,
              30078,
              [
                ['d', 'divine:replies:34236:${data.owner}:root'],
                ['e', _topComment.id, '', 'hidden'],
              ],
              '',
              createdAt: 2000,
            )..sign(data.key),
          );
          await tester.pumpAndSettle();
          expect(hosted(tester), same(first));
          votes.complete((
            upvotes: {_topComment.id: 20},
            downvotes: <String, int>{},
          ));
          await tester.pumpAndSettle();
          expect(hosted(tester), same(first));
          expect(first.state.status, FeedTopCommentStatus.empty);
          verify(
            () => commentsRepository.loadComments(
              rootEventId: data.video.id,
              rootEventKind: data.video.referenceKind,
              rootAddressableId: data.video.addressableId,
              limit: FeedTopCommentCubit.commentPageSize,
            ),
          ).called(1);
        },
      );

      testWidgets('does not feature a creator-hidden comment', (tester) async {
        stubVisibleComment();
        stubModeration(CommentModeration(hiddenCommentIds: {_topComment.id}));
        await tester.pumpWidget(
          buildSubject(
            enabled: true,
            onMount: () {},
            video: _video.copyWith(addressableDTag: 'root'),
          ),
        );
        await tester.pumpAndSettle();
        expect(hosted(tester).state.status, FeedTopCommentStatus.empty);
        expect(hosted(tester).state.topComment, isNull);
      });

      testWidgets(
        'does not feature a locally blocked author on the owner video',
        (tester) async {
          stubVisibleComment();
          viewer = _creator;
          when(() => blocklistRepository.blockedPubkeysForAccount(_creator))
              .thenReturn({_commenter});
          await tester.pumpWidget(
            buildSubject(
              enabled: true,
              onMount: () {},
              video: _video.copyWith(addressableDTag: 'root'),
            ),
          );
          await tester.pumpAndSettle();
          expect(hosted(tester).state.status, FeedTopCommentStatus.empty);
          expect(hosted(tester).state.topComment, isNull);
        },
      );

      testWidgets('refreshes the featured comment when owner blocks hydrate', (
        tester,
      ) async {
        stubVisibleComment();
        viewer = _creator;
        await tester.pumpWidget(
          buildSubject(
            enabled: true,
            onMount: () {},
            video: _video.copyWith(addressableDTag: 'root'),
          ),
        );
        await tester.pumpAndSettle();
        final first = hosted(tester);
        expect(first.state.status, FeedTopCommentStatus.ready);
        when(() => blocklistRepository.blockedPubkeysForAccount(_creator))
            .thenReturn({_commenter});
        ProviderScope.containerOf(
          tester.element(find.byType(FeedTopCommentHost)),
        ).read(blocklistVersionProvider.notifier).increment();
        await tester.pumpAndSettle();
        expect(hosted(tester), isNot(same(first)));
        expect(hosted(tester).state.status, FeedTopCommentStatus.empty);
      });

      testWidgets('loads comments using the native video kind', (tester) async {
        final horizontal = _video.copyWith(
          eventKind: 34235,
          addressableDTag: 'root',
        );
        await tester.pumpWidget(
          buildSubject(enabled: true, onMount: () {}, video: horizontal),
        );
        await tester.pumpAndSettle();
        verify(
          () => commentsRepository.loadComments(
            rootEventId: horizontal.id,
            rootEventKind: 34235,
            rootAddressableId: horizontal.addressableId,
            limit: FeedTopCommentCubit.commentPageSize,
          ),
        ).called(1);
      });

      testWidgets('keeps dismissal and loop progress across block refresh', (
        tester,
      ) async {
        stubVisibleComment();
        viewer = _creator;
        final loops = StreamController<void>.broadcast();
        addTearDown(loops.close);
        await tester.pumpWidget(
          buildSubject(
            enabled: true,
            onMount: () {},
            video: _video.copyWith(addressableDTag: 'root'),
            loopCompletions: loops.stream,
          ),
        );
        await tester.pumpAndSettle();
        final first = hosted(tester);
        loops.add(null);
        await tester.pump();
        expect(first.state.hasCompletedLoop, isTrue);
        first.dismiss();
        when(() => blocklistRepository.blockedPubkeysForAccount(_creator))
            .thenReturn({'a' * 64});
        ProviderScope.containerOf(
          tester.element(find.byType(FeedTopCommentHost)),
        ).read(blocklistVersionProvider.notifier).increment();
        await tester.pumpAndSettle();
        expect(hosted(tester), isNot(same(first)));
        expect(hosted(tester).state.status, FeedTopCommentStatus.ready);
        expect(hosted(tester).state.hasCompletedLoop, isTrue);
        expect(hosted(tester).state.isDismissed, isTrue);
      });

      testWidgets(
        'updates a featured comment when another surface accepts moderation',
        (tester) async {
          stubVisibleComment();
          final data = realModeration();
          final loops = StreamController<void>.broadcast();
          addTearDown(loops.close);
          await tester.pumpWidget(
            buildSubject(
              enabled: true,
              onMount: () {},
              video: data.video,
              latestEvents: data.events,
              commentModeration: data.moderation,
              loopCompletions: loops.stream,
            ),
          );
          await tester.pumpAndSettle();
          final first = hosted(tester);
          loops.add(null);
          await tester.pump();
          expect(first.state.isOverlayVisible, isTrue);
          data.events.remember(
            nostr.Event(
              data.owner,
              30078,
              [
                ['d', 'divine:replies:34236:${data.owner}:root'],
                ['e', _topComment.id, '', 'hidden'],
              ],
              '',
              createdAt: 2000,
            )..sign(data.key),
          );
          await tester.pumpAndSettle();
          expect(hosted(tester), isNot(same(first)));
          expect(hosted(tester).state.status, FeedTopCommentStatus.empty);
          expect(hosted(tester).state.isOverlayVisible, isFalse);
        },
      );

      testWidgets('no cubit and loads nothing while disabled', (tester) async {
        await tester.pumpWidget(buildSubject(enabled: false, onMount: () {}));

        expect(find.text('no cubit'), findsOneWidget);
        verifyNever(
          () => commentsRepository.loadComments(
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootAddressableId: any(named: 'rootAddressableId'),
            limit: any(named: 'limit'),
          ),
        );
      });

      testWidgets('a cubit that loads the top comment once enabled', (
        tester,
      ) async {
        var mounts = 0;
        await tester.pumpWidget(
          buildSubject(enabled: false, onMount: () => mounts++),
        );
        await tester.pumpWidget(
          buildSubject(enabled: true, onMount: () => mounts++),
        );

        expect(find.text('cubit'), findsOneWidget);
        expect(mounts, 1, reason: 'enabling must not remount the item');
        verify(
          () => commentsRepository.loadComments(
            rootEventId: _video.id,
            rootEventKind: any(named: 'rootEventKind'),
            rootAddressableId: any(named: 'rootAddressableId'),
            limit: any(named: 'limit'),
          ),
        ).called(1);

        await tester.pumpWidget(
          buildSubject(enabled: false, onMount: () => mounts++),
        );
        expect(find.text('no cubit'), findsOneWidget);
        expect(mounts, 1);
      });
    });

    group('lifecycle', () {
      // close() awaits a subscription cancel whose already-completed future
      // belongs to the root zone, so it finishes only on the real event loop.
      Future<void> letCloseFinish(WidgetTester tester) =>
          tester.runAsync(() async {});

      FeedTopCommentCubit hostedCubit(WidgetTester tester) => tester
          .element(find.byType(_MountCounter))
          .read<FeedTopCommentCubit?>()!;

      testWidgets('closes its cubit once disabled', (tester) async {
        await tester.pumpWidget(buildSubject(enabled: true, onMount: () {}));
        final cubit = hostedCubit(tester);
        expect(cubit.isClosed, isFalse);

        await tester.pumpWidget(buildSubject(enabled: false, onMount: () {}));
        await letCloseFinish(tester);

        expect(cubit.isClosed, isTrue);
      });

      testWidgets('closes its cubit when it goes away', (tester) async {
        await tester.pumpWidget(buildSubject(enabled: true, onMount: () {}));
        final cubit = hostedCubit(tester);

        await tester.pumpWidget(const SizedBox());
        await letCloseFinish(tester);

        expect(cubit.isClosed, isTrue);
      });

      testWidgets('replaces its cubit for another video', (tester) async {
        final otherVideo = VideoEvent(
          id: '7777777777777777777777777777777777777777777777777777777777777777',
          pubkey: _creator,
          createdAt: 1761650000,
          content: 'another loop',
          timestamp: DateTime(2026, 10, 28),
        );
        await tester.pumpWidget(buildSubject(enabled: true, onMount: () {}));
        final first = hostedCubit(tester);

        await tester.pumpWidget(
          buildSubject(enabled: true, onMount: () {}, video: otherVideo),
        );
        await letCloseFinish(tester);

        expect(hostedCubit(tester), isNot(same(first)));
        expect(first.isClosed, isTrue);
        verify(
          () => commentsRepository.loadComments(
            rootEventId: otherVideo.id,
            rootEventKind: any(named: 'rootEventKind'),
            rootAddressableId: any(named: 'rootAddressableId'),
            limit: any(named: 'limit'),
          ),
        ).called(1);
      });
    });
  });
}
