// ABOUTME: Widget tests for FeedReactionsOverlay — hidden until the top comment
// ABOUTME: is due, its author row, dismissal, and reduced motion.

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/feed_top_comment/feed_top_comment_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_feed_item/feed_reactions_overlay.dart';
import 'package:riverpod/misc.dart' show Override;

class _MockFeedTopCommentCubit extends MockCubit<FeedTopCommentState>
    implements FeedTopCommentCubit {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockLikesRepository extends Mock implements LikesRepository {}

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
      List<Override> extraOverrides = const [],
    }) => ProviderScope(
      overrides: [
        ...extraOverrides,
        userProfileReactiveProvider(
          _commenter,
        ).overrideWith((ref) => Stream<UserProfile?>.value(null)),
      ],
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
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

      testWidgets('the top comment with who posted it', (tester) async {
        when(() => cubit.state).thenReturn(_visibleState);
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text(_topComment.content), findsOneWidget);
        expect(find.byType(UserAvatar), findsOneWidget);
        expect(
          find.text(UserProfile.generatedNameFor(_commenter)),
          findsOneWidget,
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
          expect(
            solidRect.bottom,
            commentRect.bottom + FeedReactionsOverlayLayout.solidBelowComment,
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
          // Beside the comment, inside the solid part.
          final comment = tester.getRect(find.text(_topComment.content));
          await tester.tapAt(Offset(comment.left + 2, comment.bottom + 8));

          verify(() => cubit.dismiss()).called(2);
        },
      );
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

    setUp(() {
      commentsRepository = _MockCommentsRepository();
      likesRepository = _MockLikesRepository();
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
    }) => ProviderScope(
      overrides: [
        commentsRepositoryProvider.overrideWithValue(commentsRepository),
        likesRepositoryProvider.overrideWithValue(likesRepository),
      ],
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FeedTopCommentHost(
          enabled: enabled,
          video: _video,
          loopCompletions: const Stream<void>.empty(),
          child: _MountCounter(onMount: onMount),
        ),
      ),
    );

    group('renders', () {
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
  });
}
