// ABOUTME: Widget tests for CreatorAnalyticsScreen settings-linked layout.
// ABOUTME: Verifies analytics content aligns with settings menu max width.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/post_analytics_detail/post_analytics_detail_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:openvine/features/creator_analytics/video_performance.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_analytics_providers.dart';
import 'package:openvine/providers/post_live_activity_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/go_router.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockPostAnalyticsDetailCubit extends MockCubit<PostAnalyticsDetailState>
    implements PostAnalyticsDetailCubit {}

class _MockPostLiveActivityRepository extends Mock
    implements PostLiveActivityRepository {}

class _MockCreatorAnalyticsRepository extends Mock
    implements CreatorAnalyticsRepository {}

void main() {
  Future<CreatorAnalyticsRepository> pumpAnalyticsScreen(
    WidgetTester tester, {
    required List<VideoEvent> videos,
    SocialCounts? socialCounts,
    bool hasSocialCounts = true,
    Set<AnalyticsDataSource> failedSources = const {},
    List<CreatorSound> sounds = const [],
    MockGoRouter? goRouter,
  }) async {
    final authService = _MockAuthService();
    final repository = _MockCreatorAnalyticsRepository();
    final now = DateTime.now();

    when(() => authService.currentPublicKeyHex).thenReturn('a' * 64);
    when(() => repository.fetchCreatorSounds('a' * 64))
        .thenAnswer((_) async => sounds);
    when(() => repository.fetchCreatorAnalytics(any())).thenAnswer(
      (_) async => CreatorAnalyticsSnapshot(
        videos: videos,
        socialCounts: hasSocialCounts
            ? socialCounts ??
                  SocialCounts(
                    pubkey: 'a' * 64,
                    followerCount: 10,
                    followingCount: 2,
                  )
            : null,
        diagnostics: CreatorAnalyticsDiagnostics(
          totalVideos: videos.length,
          videosWithAnyViews: videos.length,
          videosMissingViews: 0,
          videosHydratedByBulkStats: 1,
          videosHydratedByViewsEndpoint: 0,
          sourcesUsed: const {AnalyticsDataSource.bulkVideoStats},
          failedSources: failedSources,
          fetchedAt: now,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          creatorAnalyticsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: goRouter == null
              ? const CreatorAnalyticsScreen()
              : MockGoRouterProvider(
                  goRouter: goRouter,
                  child: const CreatorAnalyticsScreen(),
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  Future<void> pumpAnalyticsSignedOutScreen(WidgetTester tester) async {
    final authService = _MockAuthService();
    final repository = _MockCreatorAnalyticsRepository();

    when(() => authService.currentPublicKeyHex).thenReturn(null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          creatorAnalyticsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const CreatorAnalyticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<CreatorAnalyticsRepository> pumpAnalyticsErrorScreen(
    WidgetTester tester, {
    required Object error,
  }) async {
    final authService = _MockAuthService();
    final repository = _MockCreatorAnalyticsRepository();

    when(() => authService.currentPublicKeyHex).thenReturn('a' * 64);
    when(() => repository.fetchCreatorAnalytics(any())).thenThrow(error);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          creatorAnalyticsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const CreatorAnalyticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  VideoEvent analyticsVideo({
    required String id,
    required int views,
    int? uniqueViewers,
    int? originalLikes,
    int? originalComments,
    int? originalReposts,
    int? nostrLikeCount,
    int? nostrCommentCount,
    int? nostrRepostCount,
  }) {
    final now = DateTime.now();
    return VideoEvent(
      id: id,
      pubkey: 'a' * 64,
      createdAt: now.millisecondsSinceEpoch ~/ 1000,
      content: 'Analytics fixture video',
      timestamp: now,
      title: 'Analytics Fixture Video',
      rawTags: {
        'views': '$views',
        if (uniqueViewers != null) 'unique_viewers': '$uniqueViewers',
      },
      originalLikes: originalLikes,
      originalComments: originalComments,
      originalReposts: originalReposts,
      originalLoops: views,
      nostrLikeCount: nostrLikeCount,
      nostrCommentCount: nostrCommentCount,
      nostrRepostCount: nostrRepostCount,
    );
  }

  /// The Page provides its cubit from these, so a warm entry needs them too
  /// even though it never fetches.
  List<Override> postDetailOverrides() {
    final authService = _MockAuthService();
    when(() => authService.currentPublicKeyHex).thenReturn('a' * 64);
    return [
      authServiceProvider.overrideWithValue(authService),
      creatorAnalyticsRepositoryProvider.overrideWithValue(
        _MockCreatorAnalyticsRepository(),
      ),
    ];
  }

  group(CreatorAnalyticsScreen, () {
    testWidgets('shows unique viewers in per-video analytics', (tester) async {
      final video = analyticsVideo(
        id: 'video-unique',
        views: 120,
        uniqueViewers: 45,
      );
      final performance = VideoPerformance.fromVideo(video);
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: postDetailOverrides(),
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: PostAnalyticsDetailScreen(
              videoId: video.id,
              performance: performance,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.analyticsUniqueViewers), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
    });

    testWidgets('shows N/A when unique-viewer data is missing', (tester) async {
      final video = analyticsVideo(
        id: 'video-no-unique-data',
        views: 120,
        originalLikes: 3,
        originalComments: 1,
        originalReposts: 1,
      );
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: postDetailOverrides(),
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: PostAnalyticsDetailScreen(
              videoId: video.id,
              performance: VideoPerformance.fromVideo(video),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.analyticsUniqueViewers), findsOneWidget);
      expect(find.text(l10n.analyticsNa), findsOneWidget);
    });

    testWidgets('does not show unique viewers as total views', (tester) async {
      final video = analyticsVideo(
        id: 'video-only-unique',
        views: 120,
      ).copyWith(rawTags: const {'unique_viewers': '11'});
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: postDetailOverrides(),
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: PostAnalyticsDetailScreen(
              videoId: video.id,
              performance: VideoPerformance.fromVideo(video),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.analyticsViews), findsOneWidget);
      expect(find.text(l10n.analyticsUniqueViewers), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
      expect(find.text(l10n.analyticsNa), findsAtLeastNWidgets(2));
    });

    testWidgets(
      'CreatorAnalyticsScreen constrains content width on wide screens',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpAnalyticsScreen(
          tester,
          videos: [
            analyticsVideo(
              id: 'video-1',
              views: 120,
              nostrLikeCount: 19,
              nostrCommentCount: 7,
              nostrRepostCount: 1,
            ),
          ],
        );

        final listViewWidth = tester.getSize(find.byType(ListView).first).width;
        expect(listViewWidth, moreOrLessEquals(600));
      },
    );

    testWidgets('lists the creator sounds with their video counts', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpAnalyticsScreen(
        tester,
        videos: [analyticsVideo(id: 'video-1', views: 120)],
        sounds: [
          CreatorSound(
            id: 'sound-hit',
            title: 'Test sound',
            createdAt: DateTime.now().toUtc(),
            videoCount: 42,
          ),
        ],
      );

      expect(find.text(l10n.analyticsYourSounds), findsOneWidget);
      expect(find.text('Test sound'), findsOneWidget);
      expect(find.text(l10n.soundVideoCount(42)), findsOneWidget);
    });

    testWidgets('keeps the sounds card loaded while it is scrolled away', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final l10n = lookupAppLocalizations(const Locale('en'));

      final repository = await pumpAnalyticsScreen(
        tester,
        videos: [analyticsVideo(id: 'video-1', views: 120)],
        sounds: [
          CreatorSound(
            id: 'sound-hit',
            title: 'Hit sound',
            createdAt: DateTime.now().toUtc(),
            videoCount: 42,
          ),
        ],
      );
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );

      await tester.scrollUntilVisible(
        find.text(l10n.analyticsYourSounds),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final cardOffset = scrollable.position.pixels;
      expect(find.text('Hit sound'), findsOneWidget);

      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      scrollable.position.jumpTo(cardOffset);
      await tester.pumpAndSettle();

      expect(find.text('Hit sound'), findsOneWidget);
      verify(() => repository.fetchCreatorSounds('a' * 64)).called(1);
    });

    testWidgets('reloads the sounds when the dashboard is refreshed', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = await pumpAnalyticsScreen(
        tester,
        videos: [analyticsVideo(id: 'video-1', views: 120)],
      );
      when(() => repository.fetchCreatorAnalytics(any())).thenAnswer(
        (_) async => CreatorAnalyticsSnapshot(
          videos: [analyticsVideo(id: 'video-1', views: 120)],
          socialCounts: null,
          diagnostics: CreatorAnalyticsDiagnostics(
            totalVideos: 1,
            videosWithAnyViews: 1,
            videosMissingViews: 0,
            videosHydratedByBulkStats: 1,
            videosHydratedByViewsEndpoint: 0,
            sourcesUsed: const {AnalyticsDataSource.bulkVideoStats},
            fetchedAt: DateTime.now().add(const Duration(minutes: 1)),
          ),
        ),
      );

      final refresh = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await refresh;

      verify(() => repository.fetchCreatorSounds('a' * 64)).called(2);
    });

    testWidgets('counts native Divine engagement in creator analytics', (
      tester,
    ) async {
      await pumpAnalyticsScreen(
        tester,
        videos: [
          analyticsVideo(
            id: 'native-video',
            views: 120,
            nostrLikeCount: 19,
            nostrCommentCount: 7,
            nostrRepostCount: 1,
          ),
        ],
      );

      expect(find.text('27'), findsWidgets);
    });

    testWidgets('adds archived and live engagement for restored Vines', (
      tester,
    ) async {
      await pumpAnalyticsScreen(
        tester,
        videos: [
          analyticsVideo(
            id: 'mixed-video',
            views: 200,
            originalLikes: 10,
            originalComments: 1,
            originalReposts: 4,
            nostrLikeCount: 2,
            nostrCommentCount: 3,
            nostrRepostCount: 5,
          ),
        ],
      );

      expect(find.text('25'), findsWidgets);
    });

    group('back', () {
      Future<GoRouter> pumpRouted(
        WidgetTester tester, {
        required String initialLocation,
      }) async {
        final authService = _MockAuthService();
        final repository = _MockCreatorAnalyticsRepository();
        when(() => authService.currentPublicKeyHex).thenReturn('a' * 64);
        when(() => repository.fetchCreatorSounds(any()))
            .thenAnswer((_) async => const <CreatorSound>[]);
        when(() => repository.fetchCreatorAnalytics(any())).thenAnswer(
          (_) async => CreatorAnalyticsSnapshot(
            videos: const [],
            socialCounts: null,
            diagnostics: CreatorAnalyticsDiagnostics(
              totalVideos: 0,
              videosWithAnyViews: 0,
              videosMissingViews: 0,
              videosHydratedByBulkStats: 0,
              videosHydratedByViewsEndpoint: 0,
              sourcesUsed: const {AnalyticsDataSource.bulkVideoStats},
              fetchedAt: DateTime.now(),
            ),
          ),
        );
        final router = GoRouter(
          initialLocation: initialLocation,
          routes: [
            GoRoute(
              path: defaultSafePopFallback,
              builder: (_, _) => const Text('feed'),
            ),
            GoRoute(
              path: RoutePaths.creatorAnalytics,
              builder: (_, _) => const CreatorAnalyticsScreen(),
              routes: [
                GoRoute(
                  path: ':videoId',
                  builder: (_, _) => const Text('post stats'),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(authService),
              creatorAnalyticsRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        return router;
      }

      Future<void> tapBack(WidgetTester tester) async {
        await tester.tap(find.bySemanticsIdentifier('back_button'));
        await tester.pumpAndSettle();
      }

      testWidgets('falls back to the home feed when nothing is beneath', (
        tester,
      ) async {
        final router = await pumpRouted(
          tester,
          initialLocation: RoutePaths.creatorAnalytics,
        );

        await tapBack(tester);

        expect(router.state.uri.path, equals(defaultSafePopFallback));
        expect(find.text('feed'), findsOneWidget);
      });

      testWidgets('from a post opened by link lands on account stats, then '
          'the feed', (tester) async {
        final router = await pumpRouted(
          tester,
          initialLocation: RoutePaths.postAnalytics('a' * 64),
        );
        expect(find.text('post stats'), findsOneWidget);

        router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(CreatorAnalyticsScreen), findsOneWidget);

        await tapBack(tester);
        expect(find.text('feed'), findsOneWidget);
      });
    });

    testWidgets('toggles diagnostics from the app bar action', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpAnalyticsScreen(
        tester,
        videos: [
          analyticsVideo(
            id: 'diagnostics-video',
            views: 120,
            nostrLikeCount: 19,
            nostrCommentCount: 7,
            nostrRepostCount: 1,
          ),
        ],
      );

      expect(find.text(l10n.analyticsDiagnosticsTotalVideos(1)), findsNothing);

      await tester.tap(find.bySemanticsLabel('Toggle diagnostics'));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.analyticsDiagnosticsTotalVideos(1)),
        findsOneWidget,
      );
      expect(
        find.text(l10n.analyticsDiagnosticsSources('bulk-video-stats')),
        findsOneWidget,
      );
      expect(
        find.text(l10n.analyticsDiagnosticsFailedSources('none')),
        findsOneWidget,
      );
    });

    testWidgets('maps server errors to localized copy without raw details', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpAnalyticsErrorScreen(
        tester,
        error: const CreatorAnalyticsLoadException(
          CreatorAnalyticsFailureKind.serverUnavailable,
          cause: 'raw server detail',
        ),
      );

      expect(find.text(l10n.analyticsServerUnavailable), findsOneWidget);
      expect(find.textContaining('raw server detail'), findsNothing);
    });

    testWidgets('maps connection errors to localized copy', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpAnalyticsErrorScreen(
        tester,
        error: const CreatorAnalyticsLoadException(
          CreatorAnalyticsFailureKind.connectionIssue,
        ),
      );

      expect(find.text(l10n.analyticsConnectionIssue), findsOneWidget);
    });

    group('when a reload fails', () {
      testWidgets('shows a failed retry without leaking the error', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final repository = await pumpAnalyticsErrorScreen(
          tester,
          error: const CreatorAnalyticsLoadException(
            CreatorAnalyticsFailureKind.serverUnavailable,
          ),
        );
        when(() => repository.fetchCreatorAnalytics(any())).thenAnswer(
          (_) async => throw const CreatorAnalyticsLoadException(
            CreatorAnalyticsFailureKind.unableToLoad,
          ),
        );

        await tester.tap(find.text(l10n.analyticsRetry));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(l10n.analyticsUnableToLoad), findsOneWidget);
        verify(() => repository.fetchCreatorAnalytics(any())).called(2);
      });

      testWidgets('shows a failed pull-to-refresh without leaking the error', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final repository = await pumpAnalyticsScreen(
          tester,
          videos: [analyticsVideo(id: 'video-1', views: 120)],
        );
        when(() => repository.fetchCreatorAnalytics(any())).thenAnswer(
          (_) async => throw const CreatorAnalyticsLoadException(
            CreatorAnalyticsFailureKind.serverUnavailable,
          ),
        );

        final refresh = tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show();
        await tester.pumpAndSettle();
        await refresh;

        expect(tester.takeException(), isNull);
        expect(find.text(l10n.analyticsServerUnavailable), findsOneWidget);
      });

      testWidgets('still reports a failed retry that is not an Exception', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final repository = await pumpAnalyticsErrorScreen(
          tester,
          error: const CreatorAnalyticsLoadException(
            CreatorAnalyticsFailureKind.serverUnavailable,
          ),
        );
        when(
          () => repository.fetchCreatorAnalytics(any()),
        ).thenAnswer((_) async => throw StateError('invariant broken'));

        // An Error is a broken invariant, so it must stay reportable rather
        // than being absorbed with the expected load failures. It escapes as
        // an unhandled async error, which only a guarded zone can observe.
        final unhandled = <Object>[];
        await runZonedGuarded(() async {
          await tester.tap(find.text(l10n.analyticsRetry));
          await tester.pumpAndSettle();
        }, (error, _) => unhandled.add(error));

        expect(unhandled, [isA<StateError>()]);
      });
    });

    testWidgets('shows sign-in copy when no user is authenticated', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpAnalyticsSignedOutScreen(tester);

      expect(find.text(l10n.analyticsSignInRequired), findsOneWidget);
    });

    testWidgets('renders failed social counts as unavailable', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpAnalyticsScreen(
        tester,
        videos: [
          analyticsVideo(
            id: 'social-failed-video',
            views: 120,
            nostrLikeCount: 19,
            nostrCommentCount: 7,
            nostrRepostCount: 1,
          ),
        ],
        hasSocialCounts: false,
        failedSources: const {AnalyticsDataSource.socialCounts},
      );

      expect(find.text(l10n.analyticsNa), findsWidgets);
      expect(find.text(l10n.analyticsFollowersCount('0')), findsNothing);
      expect(find.text(l10n.analyticsFollowingCount('0')), findsNothing);
    });

    testWidgets(
      'does not claim engagement metrics are accurate when stats fail',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));

        await pumpAnalyticsScreen(
          tester,
          videos: [analyticsVideo(id: 'bulk-failed-video', views: 0)],
          failedSources: const {AnalyticsDataSource.bulkVideoStats},
        );

        expect(find.text(l10n.analyticsViewDataUnavailable), findsNothing);
        expect(find.text(l10n.analyticsNa), findsWidgets);
      },
    );

    testWidgets(
      'renders the engagement rate as unavailable when bulk stats fail',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));

        await pumpAnalyticsScreen(
          tester,
          videos: [
            analyticsVideo(
              id: 'engagement-rate-video',
              views: 120,
              nostrLikeCount: 19,
              nostrCommentCount: 7,
              nostrRepostCount: 1,
            ),
          ],
          failedSources: const {AnalyticsDataSource.bulkVideoStats},
        );

        // Seed counts survive a bulk-stats failure, so the rate is computable
        // (27/120). Bulk stats are authoritative, so the KPI must read N/A like
        // every other engagement surface, not a confident percentage beside an
        // "Interactions: N/A" card.
        expect(find.textContaining('%'), findsNothing);
        expect(find.text(l10n.analyticsNa), findsWidgets);
      },
    );

    testWidgets(
      'ranks top content by views, not hidden likes, when bulk stats fail',
      (tester) async {
        tester.view.physicalSize = const Size(900, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final now = DateTime.now();
        final older = now.subtract(const Duration(days: 2));

        await pumpAnalyticsScreen(
          tester,
          videos: [
            VideoEvent(
              id: 'high-likes-older',
              pubkey: 'a' * 64,
              createdAt: older.millisecondsSinceEpoch ~/ 1000,
              content: 'older high likes',
              timestamp: older,
              title: 'Older High Likes',
              rawTags: const {'views': '120'},
              nostrLikeCount: 50,
            ),
            VideoEvent(
              id: 'low-likes-newer',
              pubkey: 'a' * 64,
              createdAt: now.millisecondsSinceEpoch ~/ 1000,
              content: 'newer low likes',
              timestamp: now,
              title: 'Newer Low Likes',
              rawTags: const {'views': '120'},
              nostrLikeCount: 1,
            ),
          ],
          failedSources: const {AnalyticsDataSource.bulkVideoStats},
        );

        // Same views, so recency (not the hidden 50-vs-1 likes) decides order.
        // The newer title also appears in the most-viewed highlight; the last
        // match is the top-content row.
        final newerTop = tester
            .getTopLeft(find.text('Newer Low Likes').last)
            .dy;
        final olderTop = tester.getTopLeft(find.text('Older High Likes')).dy;
        expect(newerTop, lessThan(olderTop));
      },
    );

    testWidgets('renders non-empty failed sources diagnostics', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpAnalyticsScreen(
        tester,
        videos: [analyticsVideo(id: 'diagnostics-failure-video', views: 120)],
        failedSources: const {
          AnalyticsDataSource.bulkVideoStats,
          AnalyticsDataSource.socialCounts,
        },
      );

      await tester.tap(find.bySemanticsLabel('Toggle diagnostics'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          l10n.analyticsDiagnosticsFailedSources(
            'bulk-video-stats, social-counts',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'explains social counts from an accessible info affordance on the '
      'audience snapshot card (#8276)',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));

        // The Audience Snapshot card sits low in the lazy ListView; a tall
        // viewport builds the whole list so the affordance is present.
        tester.view.physicalSize = const Size(1200, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpAnalyticsScreen(
          tester,
          videos: [analyticsVideo(id: 'v1', views: 5)],
        );

        // The affordance carries a clear accessibility label.
        final affordance = find.bySemanticsLabel(
          l10n.analyticsSocialCountsInfoLabel,
        );
        expect(affordance, findsOneWidget);

        await tester.tap(affordance);
        await tester.pumpAndSettle();

        expect(find.text(l10n.analyticsFollowerCountsBody), findsOneWidget);
      },
    );

    group('opening the post video from post analytics', () {
      late MockGoRouter goRouter;
      late LogCaptureService logCapture;

      setUp(() async {
        goRouter = MockGoRouter();
        logCapture = LogCaptureService();
        await logCapture.clearAllLogs();
      });

      tearDown(() async {
        await logCapture.clearAllLogs();
      });

      Future<void> tapOpenPost(WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final video = analyticsVideo(id: 'video-open', views: 120);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: postDetailOverrides(),
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              home: MockGoRouterProvider(
                goRouter: goRouter,
                child: PostAnalyticsDetailScreen(
                  videoId: video.id,
                  performance: VideoPerformance.fromVideo(video),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.analyticsOpenPost));
        await tester.pump();
      }

      testWidgets('pushes the video detail route', (tester) async {
        when(() => goRouter.push<void>(any())).thenAnswer((_) async {});

        await tapOpenPost(tester);

        verify(
          () => goRouter.push<void>(VideoDetailScreen.pathForId('video-open')),
        ).called(1);
      });

      testWidgets('logs a failed route push instead of leaking it', (
        tester,
      ) async {
        when(() => goRouter.push<void>(any()))
            .thenAnswer((_) => Future<void>.error(Exception('route failed')));

        await tapOpenPost(tester);
        await tester.pump();

        expect(tester.takeException(), isNull);
        final logs = logCapture.getRecentLogs();
        expect(logs, hasLength(1));
        expect(logs.single.level, LogLevel.error);
        expect(logs.single.name, 'CreatorAnalyticsScreen');
        expect(logs.single.category, LogCategory.ui);
        expect(
          logs.single.message,
          'Failed to open post video: Exception: route failed',
        );
      });
    });

    group('opening post analytics', () {
      late MockGoRouter goRouter;
      late LogCaptureService logCapture;

      setUp(() async {
        goRouter = MockGoRouter();
        logCapture = LogCaptureService();
        await logCapture.clearAllLogs();
      });

      tearDown(() async {
        await logCapture.clearAllLogs();
      });

      Future<void> tapFixtureVideo(WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpAnalyticsScreen(
          tester,
          videos: [analyticsVideo(id: 'video-open', views: 120)],
          goRouter: goRouter,
        );

        await tester.tap(find.text('Analytics Fixture Video').first);
        await tester.pump();
      }

      testWidgets('pushes the detail route with the tapped performance', (
        tester,
      ) async {
        when(() => goRouter.push<void>(any(), extra: any(named: 'extra')))
            .thenAnswer((_) async {});

        await tapFixtureVideo(tester);

        final captured = verify(
          () => goRouter.push<void>(
            '/creator-analytics/video-open',
            extra: captureAny(named: 'extra'),
          ),
        ).captured;
        expect(
          captured.single,
          isA<VideoPerformance>().having(
            (performance) => performance.video.id,
            'video id',
            'video-open',
          ),
        );
        expect(logCapture.getRecentLogs(), isEmpty);
      });

      testWidgets('logs a failed route push instead of leaking it', (
        tester,
      ) async {
        when(() => goRouter.push<void>(any(), extra: any(named: 'extra')))
            .thenAnswer((_) => Future<void>.error(Exception('route failed')));

        await tapFixtureVideo(tester);
        await tester.pump();

        expect(tester.takeException(), isNull);
        final logs = logCapture.getRecentLogs();
        expect(logs, hasLength(1));
        expect(logs.single.level, LogLevel.error);
        expect(logs.single.name, 'CreatorAnalyticsScreen');
        expect(logs.single.category, LogCategory.ui);
        expect(
          logs.single.message,
          'Failed to open post analytics: Exception: route failed',
        );
      });
    });
  });

  group(PostAnalyticsDetailScreen, () {
    testWidgets('draws a warm post on the first frame, before the Live '
        'Activity answers', (tester) async {
      final liveActivity = _MockPostLiveActivityRepository();
      when(
        () => liveActivity.postedAtFor(any()),
      ).thenAnswer((_) => Completer<DateTime?>().future);
      when(
        () => liveActivity.isRunningFor(any()),
      ).thenAnswer((_) => Completer<bool>().future);
      // An address, so the Live Activity lookups actually run.
      final video = analyticsVideo(
        id: 'video-warm',
        views: 120,
      ).copyWith(vineId: 'post-d-tag');
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...postDetailOverrides(),
            postLiveActivityRepositoryProvider.overrideWithValue(liveActivity),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: PostAnalyticsDetailScreen(
              videoId: video.id,
              performance: VideoPerformance.fromVideo(video),
            ),
          ),
        ),
      );

      expect(find.text('Analytics Fixture Video'), findsOneWidget);
      expect(find.text(l10n.analyticsViews), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
    });
  });

  group(PostAnalyticsDetailView, () {
    const coordinate =
        '34236:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        ':post-d-tag';
    late _MockPostAnalyticsDetailCubit cubit;
    late MockGoRouter goRouter;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockPostAnalyticsDetailCubit();
      goRouter = MockGoRouter();
      when(() => goRouter.push<void>(any())).thenAnswer((_) async {});
      when(() => cubit.retry()).thenAnswer((_) async {});
      when(() => cubit.stop()).thenAnswer((_) async {});
      when(() => cubit.refreshLiveActivity()).thenAnswer((_) async {});
    });

    Future<void> pumpView(
      WidgetTester tester,
      PostAnalyticsDetailState state,
    ) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      when(() => cubit.state).thenReturn(state);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: MockGoRouterProvider(
            goRouter: goRouter,
            child: BlocProvider<PostAnalyticsDetailCubit>.value(
              value: cubit,
              child: const PostAnalyticsDetailView(videoId: 'video-id'),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    group('renders', () {
      testWidgets('the on-their-way copy', (tester) async {
        await pumpView(
          tester,
          const PostAnalyticsDetailState(
            status: PostAnalyticsDetailStatus.onTheirWay,
          ),
        );

        expect(find.text(l10n.analyticsStatsOnTheirWay), findsOneWidget);
      });

      testWidgets('how long the post has been live when nothing came yet', (
        tester,
      ) async {
        await pumpView(
          tester,
          const PostAnalyticsDetailState(
            status: PostAnalyticsDetailStatus.nothingYet,
            counts: PostCounts(views: 0, likes: 0, comments: 0),
            liveMinutes: 14,
          ),
        );

        expect(find.text(l10n.analyticsNoViewsYet(14)), findsOneWidget);
      });

      testWidgets('the cannot-find copy', (tester) async {
        await pumpView(
          tester,
          const PostAnalyticsDetailState(
            status: PostAnalyticsDetailStatus.cantFind,
            coordinate: coordinate,
          ),
        );

        expect(find.text(l10n.analyticsCantFindStats), findsOneWidget);
        expect(find.text(l10n.analyticsViewPost), findsOneWidget);
      });

      testWidgets('the could-not-load copy with a retry', (tester) async {
        await pumpView(
          tester,
          const PostAnalyticsDetailState(
            status: PostAnalyticsDetailStatus.couldNotLoad,
          ),
        );

        expect(find.text(l10n.analyticsUnableToLoad), findsOneWidget);
        expect(find.text(l10n.analyticsRetry), findsOneWidget);
        expect(find.text(l10n.analyticsCantFindStats), findsNothing);
      });

      testWidgets('an unknown count as N/A, never as zero', (tester) async {
        final video = analyticsVideo(id: 'video-id', views: 9);
        await pumpView(
          tester,
          PostAnalyticsDetailState(
            status: PostAnalyticsDetailStatus.ready,
            performance: VideoPerformance.fromVideo(video),
            counts: const PostCounts(views: 9),
          ),
        );

        expect(find.text('9'), findsOneWidget);
        expect(find.text('0'), findsNothing);
        expect(find.text(l10n.analyticsNa), findsWidgets);
      });

      group('the ready card', () {
        final video = analyticsVideo(id: 'video-id', views: 9);

        Future<(Rect, Rect)> openPostAndCard(
          WidgetTester tester, {
          required bool running,
        }) async {
          await pumpView(
            tester,
            PostAnalyticsDetailState(
              status: PostAnalyticsDetailStatus.ready,
              performance: VideoPerformance.fromVideo(video),
              counts: const PostCounts(views: 9),
              coordinate: coordinate,
              liveActivityRunning: running,
            ),
          );
          final openPost = find.widgetWithText(
            DivineButton,
            l10n.analyticsOpenPost,
          );
          final cardColumn = find
              .ancestor(of: openPost, matching: find.byType(Column))
              .first;
          return (tester.getRect(openPost), tester.getRect(cardColumn));
        }

        testWidgets('ends at Open post, with no gap, when Stop is hidden', (
          tester,
        ) async {
          final (openPost, card) = await openPostAndCard(
            tester,
            running: false,
          );

          expect(openPost.bottom, equals(card.bottom));
        });

        testWidgets('puts a gap between Open post and Stop', (tester) async {
          final (openPost, _) = await openPostAndCard(tester, running: true);
          final stop = tester.getRect(
            find.widgetWithText(DivineButton, l10n.analyticsStopLiveActivity),
          );

          expect(stop.top - openPost.bottom, equals(10));
        });
      });

      group('a message with Stop hidden', () {
        for (final (state, lastButton) in [
          (PostAnalyticsDetailStatus.cantFind, l10n.analyticsViewPost),
          (PostAnalyticsDetailStatus.couldNotLoad, l10n.analyticsRetry),
        ]) {
          testWidgets('$state ends at its last button, with no gap', (
            tester,
          ) async {
            await pumpView(
              tester,
              PostAnalyticsDetailState(status: state, coordinate: coordinate),
            );
            final button = find.widgetWithText(DivineButton, lastButton);
            final column = find
                .ancestor(of: button, matching: find.byType(Column))
                .first;

            expect(
              tester.getRect(button).bottom,
              equals(tester.getRect(column).bottom),
            );
          });
        }
      });

      testWidgets('Stop only while the Lock Screen activity runs', (
        tester,
      ) async {
        await pumpView(
          tester,
          const PostAnalyticsDetailState(
            status: PostAnalyticsDetailStatus.cantFind,
            coordinate: coordinate,
          ),
        );

        expect(find.text(l10n.analyticsStopLiveActivity), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('View post opens the post by its address', (tester) async {
        await pumpView(
          tester,
          const PostAnalyticsDetailState(
            status: PostAnalyticsDetailStatus.cantFind,
            coordinate: coordinate,
          ),
        );

        await tester.tap(find.text(l10n.analyticsViewPost));
        await tester.pump();

        verify(
          () => goRouter.push<void>(VideoDetailScreen.pathForId(coordinate)),
        ).called(1);
      });

      testWidgets('retry reloads', (tester) async {
        await pumpView(
          tester,
          const PostAnalyticsDetailState(
            status: PostAnalyticsDetailStatus.couldNotLoad,
          ),
        );

        await tester.tap(find.text(l10n.analyticsRetry));
        await tester.pump();

        verify(() => cubit.retry()).called(1);
      });

      testWidgets('Stop ends the Lock Screen activity', (tester) async {
        await pumpView(
          tester,
          const PostAnalyticsDetailState(
            status: PostAnalyticsDetailStatus.onTheirWay,
            coordinate: coordinate,
            liveActivityRunning: true,
          ),
        );

        await tester.tap(find.text(l10n.analyticsStopLiveActivity));
        await tester.pump();

        verify(() => cubit.stop()).called(1);
      });

      testWidgets('returning to the app re-checks the Lock Screen activity', (
        tester,
      ) async {
        await pumpView(
          tester,
          const PostAnalyticsDetailState(
            status: PostAnalyticsDetailStatus.onTheirWay,
            coordinate: coordinate,
            liveActivityRunning: true,
          ),
        );
        verifyNever(() => cubit.refreshLiveActivity());

        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();

        verify(() => cubit.refreshLiveActivity()).called(1);
      });
    });
  });
}
