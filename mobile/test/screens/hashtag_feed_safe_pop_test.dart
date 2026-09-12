import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockHashtagService extends Mock implements HashtagService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group('navigation', () {
    testWidgets('single-entry hashtag back falls back instead of throwing', (
      tester,
    ) async {
      final videosRepository = _MockVideosRepository();
      final hashtagService = _MockHashtagService();
      final blocklistRepository = _MockContentBlocklistRepository();

      when(() => hashtagService.getVideosByHashtags(any())).thenReturn([]);
      when(() => hashtagService.getHashtagStats(any())).thenReturn(null);
      when(
        () => hashtagService.subscribeToHashtagVideos(any()),
      ).thenAnswer((_) async {});
      when(
        () => videosRepository.getHashtagFeedVideos(
          hashtag: any(named: 'hashtag'),
        ),
      ).thenAnswer((_) async => const HashtagFeedVideosResult.success([]));
      when(
        () => blocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);

      final router = GoRouter(
        initialLocation: '/hashtag/funny',
        routes: [
          GoRoute(
            path: VideoFeedPage.pathWithIndex,
            builder: (_, _) => const Scaffold(body: Text('feed fallback')),
          ),
          GoRoute(
            path: '/hashtag/:hashtag',
            builder: (_, state) => HashtagFeedScreen(
              hashtag: state.pathParameters['hashtag'] ?? '',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videosRepositoryProvider.overrideWithValue(videosRepository),
            hashtagServiceProvider.overrideWith((ref) => hashtagService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
            subscribedListVideoCacheProvider.overrideWithValue(null),
          ],
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      // Identifier, not label: the back label is now
      // MaterialLocalizations.backButtonTooltip and moves per locale.
      await tester.tap(find.bySemanticsIdentifier('back_button'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(router.routeInformationProvider.value.uri.toString(), '/home/0');
      expect(defaultSafePopFallback, '/home/0');
    });
  });
}
