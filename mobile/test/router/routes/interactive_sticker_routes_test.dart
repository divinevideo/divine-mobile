// ABOUTME: Tests the interactive sticker routes: a link carrying what the page
// ABOUTME: needs opens it, and one missing or mangling it ends on an error page.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/routes/interactive_sticker_routes.dart';
import 'package:openvine/screens/question_answer/question_answer_screen.dart';
import 'package:openvine/screens/video_replies/video_replies_screen.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockVideoResponsesRepository extends Mock
    implements VideoResponsesRepository {}

final String _creator = '1'.padLeft(64, '0');
final String _videoId = 'a'.padLeft(64, '0');

void main() {
  group('interactive sticker routes', () {
    late _MockVideoResponsesRepository responses;

    setUp(() {
      responses = _MockVideoResponsesRepository();
      when(
        () => responses.fetchReplies(
          videoId: any(named: 'videoId'),
          videoAddress: any(named: 'videoAddress'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => const VideoResponses());
      when(
        () => responses.fetchCuration(
          creatorPubkey: any(named: 'creatorPubkey'),
          videoAddress: any(named: 'videoAddress'),
        ),
      ).thenAnswer((_) async => const RepliesCuration());
    });

    Future<void> open(WidgetTester tester, String location) async {
      final router = GoRouter(
        initialLocation: location,
        routes: interactiveStickerRoutes(),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dmRepositoryProvider.overrideWithValue(_MockDmRepository()),
            videoResponsesRepositoryProvider.overrideWithValue(responses),
            userProfileReactiveProvider(
              _creator,
            ).overrideWith((ref) => const Stream<UserProfile?>.empty()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
    }

    group(QuestionAnswerRouteData, () {
      testWidgets('opens the answer to the question the link names', (
        tester,
      ) async {
        await open(
          tester,
          QuestionAnswerRouteData(
            pubkey: _creator,
            videoId: _videoId,
            question: 'Ask me anything',
          ).location,
        );

        expect(find.byType(QuestionAnswerScreen), findsOneWidget);
        expect(find.text('Ask me anything'), findsOneWidget);
      });

      testWidgets('ends on an error page without a question', (tester) async {
        await open(
          tester,
          QuestionAnswerRouteData(pubkey: _creator, videoId: _videoId).location,
        );

        expect(find.byType(RouteErrorScreen), findsOneWidget);
      });
    });

    group(VideoRepliesRouteData, () {
      testWidgets('opens the replies to the video the link names', (
        tester,
      ) async {
        await open(
          tester,
          VideoRepliesRouteData(
            videoId: _videoId,
            address: '34236:$_creator:root-d',
          ).location,
        );

        expect(find.byType(VideoRepliesScreen), findsOneWidget);
      });

      testWidgets('ends on an error page without a video address', (
        tester,
      ) async {
        await open(
          tester,
          VideoRepliesRouteData(videoId: _videoId, address: 'nope').location,
        );

        expect(find.byType(RouteErrorScreen), findsOneWidget);
      });
    });
  });
}
