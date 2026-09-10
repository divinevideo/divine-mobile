// ABOUTME: Route tests for the per-post analytics screen (#6481).
// ABOUTME: Covers the warm extra path and the cold-entry refetch path.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_analytics_providers.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockRepository extends Mock implements CreatorAnalyticsRepository {}

VideoEvent _video(String id) => VideoEvent(
  id: id,
  pubkey: 'a' * 64,
  createdAt: 1700000000,
  content: '',
  title: 'Post $id',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
);

void main() {
  group('PostAnalyticsDetailScreen route', () {
    late _MockAuthService auth;
    late _MockRepository repository;

    setUp(() {
      auth = _MockAuthService();
      repository = _MockRepository();
      when(() => auth.currentPublicKeyHex).thenReturn('a' * 64);
    });

    Future<void> pump(
      WidgetTester tester, {
      required String location,
      Object? extra,
    }) async {
      final router = GoRouter(
        initialLocation: location,
        initialExtra: extra,
        routes: [
          GoRoute(
            path: CreatorAnalyticsScreen.path,
            builder: (_, _) => const Scaffold(body: Text('DASHBOARD-STUB')),
            routes: [
              GoRoute(
                path: PostAnalyticsDetailScreen.subpath,
                builder: (_, st) => PostAnalyticsDetailScreen(
                  videoId: st.pathParameters['videoId'] ?? '',
                  performance: st.extra as VideoPerformance?,
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            creatorAnalyticsRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('warm entry renders without touching the repository', (
      tester,
    ) async {
      final performance = VideoPerformance.fromVideo(_video('v1'));

      await pump(
        tester,
        location: PostAnalyticsDetailScreen.pathForId('v1'),
        extra: performance,
      );

      expect(find.text('Post v1'), findsWidgets);
      verifyNever(() => repository.fetchCreatorAnalytics(any()));
    });

    testWidgets('cold entry refetches and rebuilds the post', (tester) async {
      when(() => repository.fetchCreatorAnalytics(any())).thenAnswer(
        (_) async => CreatorAnalyticsSnapshot(
          videos: [_video('v1'), _video('v2')],
          socialCounts: null,
          diagnostics: CreatorAnalyticsDiagnostics(
            totalVideos: 2,
            videosWithAnyViews: 0,
            videosMissingViews: 2,
            videosHydratedByBulkStats: 0,
            videosHydratedByViewsEndpoint: 0,
            sourcesUsed: const {AnalyticsDataSource.authorVideos},
            fetchedAt: DateTime.utc(2026),
          ),
        ),
      );

      await pump(tester, location: PostAnalyticsDetailScreen.pathForId('v2'));

      expect(find.text('Post v2'), findsWidgets);
      verify(() => repository.fetchCreatorAnalytics(any())).called(1);
    });
  });
}
