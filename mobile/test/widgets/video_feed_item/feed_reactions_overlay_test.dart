// ABOUTME: Widget tests for FeedReactionsOverlay — hidden until the top comment
// ABOUTME: is due, its replied-to context, dismissal, and reduced motion.

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/feed_top_comment/feed_top_comment_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/video_feed_item/feed_reactions_overlay.dart';

class _MockFeedTopCommentCubit extends MockCubit<FeedTopCommentState>
    implements FeedTopCommentCubit {}

const _creator =
    '2222222222222222222222222222222222222222222222222222222222222222';

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
  authorPubkey:
      '3333333333333333333333333333333333333333333333333333333333333333',
  createdAt: DateTime(2026, 10, 28),
  rootEventId: _video.id,
  rootAuthorPubkey: _creator,
);

final _visibleState = FeedTopCommentState(
  status: FeedTopCommentStatus.ready,
  topComment: _topComment,
  repliedToPubkey: _creator,
  repliedToContent: 'Amineeeee!',
  hasCompletedLoop: true,
);

void main() {
  group(FeedReactionsOverlay, () {
    late _MockFeedTopCommentCubit cubit;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockFeedTopCommentCubit();
    });

    Widget buildSubject({bool reducedMotion = false}) => ProviderScope(
      overrides: [
        userProfileReactiveProvider(
          _creator,
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

      testWidgets('the top comment with what it replied to', (tester) async {
        when(() => cubit.state).thenReturn(_visibleState);
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text(_topComment.content), findsOneWidget);
        expect(find.text('Amineeeee!'), findsOneWidget);
        expect(find.text(l10n.commentReplyToPrefix), findsOneWidget);
        expect(
          find.text(UserProfile.generatedNameFor(_creator)),
          findsOneWidget,
        );
      });

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
      testWidgets('tapping the dimmed area dismisses the reaction', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(_visibleState);
        await tester.pumpWidget(buildSubject());

        await tester.tapAt(const Offset(200, 500));

        verify(() => cubit.dismiss()).called(1);
      });
    });
  });
}
