import 'package:analytics/analytics.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/new_videos_feed_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/feed_refresh_control.dart';
import 'package:openvine/widgets/new_videos_tab.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_origin.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/screen_load_recorder.dart';
import '../helpers/test_provider_overrides.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group('NewVideosTab', () {
    late _MockVideosRepository videosRepository;
    late _MockVideoEventService videoEventService;
    late _MockContentBlocklistRepository blocklistRepository;

    setUp(() {
      videosRepository = _MockVideosRepository();
      videoEventService = _MockVideoEventService();
      blocklistRepository = _MockContentBlocklistRepository();

      when(
        () => videosRepository.getNewVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer(
        (_) async => HomeFeedResult(videos: [_video('new-video')]),
      );
      when(
        () => videosRepository.getPopularVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          fetchMultiplier: any(named: 'fetchMultiplier'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer((_) async => [_video('popular-video')]);
      when(() => videoEventService.filterVideoList(any())).thenAnswer(
        (invocation) =>
            List<VideoEvent>.from(invocation.positionalArguments.first as List),
      );
      when(
        () => blocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
    });

    testWidgets('loads newest videos instead of popular videos', (
      tester,
    ) async {
      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            appReadyProvider.overrideWithValue(true),
            videosRepositoryProvider.overrideWithValue(videosRepository),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
          ],
          home: const Scaffold(body: NewVideosTab()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No videos in Latest'), findsNothing);
      verify(
        () => videosRepository.getNewVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          skipCache: any(named: 'skipCache'),
        ),
      ).called(1);
      verifyNever(
        () => videosRepository.getPopularVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          fetchMultiplier: any(named: 'fetchMultiplier'),
          skipCache: any(named: 'skipCache'),
        ),
      );
    });

    testWidgets('tapping a video opens its fullscreen route', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: NewVideosTab()),
          ),
          GoRoute(
            path: PooledFullscreenVideoFeedScreen.path,
            builder: (context, state) => Scaffold(
              body: Text(
                'opened video '
                '${state.uri.queryParameters[PooledFullscreenVideoFeedScreen.videoQueryParameter]}'
                ' from tile '
                '${(state.extra! as PooledFullscreenVideoFeedArgs).tileOrigin?.videoId}',
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            appReadyProvider.overrideWithValue(true),
            videosRepositoryProvider.overrideWithValue(videosRepository),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(VideoTileThumbnailBoundary));
      await tester.pumpAndSettle();

      // The player grows out of the tapped tile.
      expect(
        find.text('opened video new-video from tile new-video'),
        findsOneWidget,
      );
      router.dispose();
    });

    testWidgets('pull-to-refresh bypasses repository cache on retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            appReadyProvider.overrideWithValue(true),
            videosRepositoryProvider.overrideWithValue(videosRepository),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
          ],
          home: const Scaffold(body: NewVideosTab()),
        ),
      );

      await tester.pumpAndSettle();

      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refreshIndicator.onRefresh();
      await tester.pumpAndSettle();

      verify(
        () => videosRepository.getNewVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
        ),
      ).called(1);
      verify(
        () => videosRepository.getNewVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          skipCache: true,
        ),
      ).called(1);
    });

    group('Explore load telemetry', () {
      late ScreenLoadRecorder recorder;
      late ExploreTabsCubit exploreTabs;

      setUp(() {
        recorder = ScreenLoadRecorder();
        exploreTabs = ExploreTabsCubit(
          screenAnalytics: ScreenAnalyticsService(
            history: PageLoadHistory(),
            sink: const NoOpAnalyticsEventSink(),
          ),
          loadTelemetry: recorder.telemetry(AnalyticsSurface.explore),
        )..trackScreenLoad(initialTabName: exploreDefaultTabName);
        addTearDown(exploreTabs.close);
      });

      Future<void> pumpTab(WidgetTester tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              appReadyProvider.overrideWithValue(true),
              videosRepositoryProvider.overrideWithValue(videosRepository),
              videoEventServiceProvider.overrideWithValue(videoEventService),
              contentBlocklistRepositoryProvider.overrideWithValue(
                blocklistRepository,
              ),
            ],
            home: BlocProvider.value(
              value: exploreTabs,
              child: const Scaffold(body: NewVideosTab()),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('reports the grid it shows to Explore', (tester) async {
        await pumpTab(tester);

        expect(recorder.results, [SurfaceLoadResult.success]);
        expect(
          recorder.loads.single,
          containsPair(AnalyticsParam.itemCount, 1),
        );
      });

      testWidgets('reports a failed first page as a failure', (tester) async {
        when(
          () => videosRepository.getNewVideos(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenThrow(Exception('offline'));

        await pumpTab(tester);

        expect(recorder.results, [SurfaceLoadResult.failure]);
      });
    });

    group('New feed', () {
      Widget buildNewTab() => testMaterialApp(
        additionalOverrides: [
          appReadyProvider.overrideWithValue(true),
          videosRepositoryProvider.overrideWithValue(videosRepository),
          videoEventServiceProvider.overrideWithValue(videoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            blocklistRepository,
          ),
        ],
        home: const Scaffold(
          body: NewVideosTab(feed: PublicationFeed.newCreators),
        ),
      );

      testWidgets('loads new-creator videos instead of Latest', (
        tester,
      ) async {
        when(
          () => videosRepository.getNewCreatorVideos(
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (_) async => HomeFeedResult(videos: [_video('debut-video')]),
        );

        await tester.pumpWidget(buildNewTab());
        await tester.pumpAndSettle();

        final grid = tester.widget<ComposableVideoGrid>(
          find.byType(ComposableVideoGrid),
        );
        expect(grid.videos.map((v) => v.id), ['debut-video']);
        verifyNever(
          () => videosRepository.getNewVideos(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
          ),
        );
      });

      testWidgets('shows the New Diviners empty state, not the Latest one', (
        tester,
      ) async {
        when(
          () => videosRepository.getNewCreatorVideos(
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer((_) async => const HomeFeedResult(videos: []));

        await tester.pumpWidget(buildNewTab());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.newDivinersTabEmptyTitle), findsOneWidget);
        expect(find.text(l10n.latestVideosTabEmptyTitle), findsNothing);
      });

      testWidgets(
        'shows a failed first page as an error, and a refresh retries it',
        (tester) async {
          var attempts = 0;
          when(
            () => videosRepository.getNewCreatorVideos(
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
            ),
          ).thenAnswer((_) async {
            if (attempts++ == 0) throw Exception('offline');
            return HomeFeedResult(videos: [_video('debut-video')]);
          });

          await tester.pumpWidget(buildNewTab());
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.text(l10n.feedFailedToLoadVideos), findsOneWidget);
          expect(find.text(l10n.newDivinersTabEmptyTitle), findsNothing);

          await tester
              .widget<FeedRefreshControl>(find.byType(FeedRefreshControl))
              .onRefresh();
          await tester.pumpAndSettle();

          expect(find.text(l10n.feedFailedToLoadVideos), findsNothing);
          final grid = tester.widget<ComposableVideoGrid>(
            find.byType(ComposableVideoGrid),
          );
          expect(grid.videos.map((v) => v.id), ['debut-video']);
        },
      );
    });

    testWidgets('shows a failed Latest first page as an error, not as empty', (
      tester,
    ) async {
      when(
        () => videosRepository.getNewVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenThrow(Exception('offline'));

      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            appReadyProvider.overrideWithValue(true),
            videosRepositoryProvider.overrideWithValue(videosRepository),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
          ],
          home: const Scaffold(body: NewVideosTab()),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.feedFailedToLoadVideos), findsOneWidget);
      expect(find.text(l10n.latestVideosTabEmptyTitle), findsNothing);
      expect(find.byType(ComposableVideoGrid), findsNothing);
    });
  });
}

VideoEvent _video(String id) {
  return VideoEvent(
    id: id,
    pubkey: 'test-pubkey',
    createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
    content: 'Test video',
    timestamp: DateTime(2026),
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
  );
}
