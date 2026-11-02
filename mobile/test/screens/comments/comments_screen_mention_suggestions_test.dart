// ABOUTME: Drives the real comment input and composer bloc together: once a
// ABOUTME: mention is picked, a search still running must not reopen the list.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/comments/comment_composer/comment_composer_bloc.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';
import 'package:openvine/features/consumption_analytics/consumption_analytics_tracker.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:profile_repository/profile_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockConsumptionAnalytics extends Mock
    implements ConsumptionAnalyticsTracker {}

class _MockCommentsListBloc
    extends MockBloc<CommentsListEvent, CommentsListState>
    implements CommentsListBloc {}

class _MockCommentReactionsBloc
    extends MockBloc<CommentReactionsEvent, CommentReactionsState>
    implements CommentReactionsBloc {}

const _viewer =
    'facade00facade00facade00facade00facade00facade00facade00facade00';
const _alice =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _bob = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

UserProfile _profile(String pubkey, String name) => UserProfile(
  pubkey: pubkey,
  displayName: name,
  rawData: const {},
  createdAt: DateTime(2026),
  eventId: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
);

void main() {
  group(MainCommentInput, () {
    testWidgets('stays closed after a pick when the remote search returns', (
      tester,
    ) async {
      final profiles = _MockProfileRepository();
      final auth = _MockAuthService();
      final remote = Completer<List<UserProfile>>();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(_viewer);
      when(
        () => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')),
      ).thenAnswer((_) async => [_profile(_alice, 'Alice')]);
      when(
        () => profiles.searchUsersFromApi(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          sortBy: any(named: 'sortBy'),
          hasVideos: any(named: 'hasVideos'),
        ),
      ).thenAnswer((_) => remote.future);

      final bloc = CommentComposerBloc(
        commentsRepository: _MockCommentsRepository(),
        authService: auth,
        rootEventId: _alice,
        rootEventKind: 34236,
        rootAuthorPubkey: _alice,
        consumptionAnalytics: _MockConsumptionAnalytics(),
        profileRepository: profiles,
      );
      final list = _MockCommentsListBloc();
      when(() => list.state).thenReturn(
        const CommentsListState(rootEventId: _alice, rootAuthorPubkey: _alice),
      );
      final reactions = _MockCommentReactionsBloc();
      when(() => reactions.state).thenReturn(const CommentReactionsState());
      final draggable = DraggableScrollableController();
      addTearDown(draggable.dispose);

      await tester.pumpWidget(
        testMaterialApp(
          mockProfileRepository: profiles,
          additionalOverrides: [
            isFeatureEnabledProvider(
              FeatureFlag.videoReplies,
            ).overrideWithValue(false),
          ],
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<CommentsListBloc>.value(value: list),
                BlocProvider<CommentComposerBloc>.value(value: bloc),
                BlocProvider<CommentReactionsBloc>.value(value: reactions),
              ],
              child: Align(
                alignment: Alignment.bottomCenter,
                child: MainCommentInput(draggableController: draggable),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), '@al');
      await tester.pump();
      await tester.pump();
      expect(find.text('Alice'), findsOneWidget);

      await tester.tap(find.text('Alice'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Alice'), findsNothing);
      expect(bloc.state.mentionSuggestions, isEmpty);

      remote.complete([_profile(_bob, 'Albert')]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Albert'), findsNothing);
      expect(bloc.state.mentionSuggestions, isEmpty);

      // Closed here, not in a tearDown: the bloc's work runs on the widget
      // test's fake clock, which a tearDown would wait on for ever.
      unawaited(bloc.close());
      await tester.pump();
    });
  });
}
