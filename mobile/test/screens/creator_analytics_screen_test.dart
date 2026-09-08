// ABOUTME: Widget tests for CreatorAnalyticsScreen settings-linked layout.
// ABOUTME: Verifies analytics content aligns with settings menu max width.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_analytics_providers.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockCreatorAnalyticsRepository extends Mock
    implements CreatorAnalyticsRepository {}

void main() {
  Future<void> pumpAnalyticsScreen(
    WidgetTester tester, {
    required List<VideoEvent> videos,
    SocialCounts? socialCounts,
    bool hasSocialCounts = true,
    Set<AnalyticsDataSource> failedSources = const {},
  }) async {
    final authService = _MockAuthService();
    final repository = _MockCreatorAnalyticsRepository();
    final now = DateTime.now();

    when(() => authService.currentPublicKeyHex).thenReturn('a' * 64);
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const CreatorAnalyticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const CreatorAnalyticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpAnalyticsErrorScreen(
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const CreatorAnalyticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  VideoEvent analyticsVideo({
    required String id,
    required int views,
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
      rawTags: {'views': '$views'},
      originalLikes: originalLikes,
      originalComments: originalComments,
      originalReposts: originalReposts,
      originalLoops: views,
      nostrLikeCount: nostrLikeCount,
      nostrCommentCount: nostrCommentCount,
      nostrRepostCount: nostrRepostCount,
    );
  }

  group(CreatorAnalyticsScreen, () {
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
      (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));

        await pumpAnalyticsScreen(
          tester,
          videos: [
            analyticsVideo(id: 'bulk-failed-video', views: 0),
          ],
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
        videos: [
          analyticsVideo(id: 'diagnostics-failure-video', views: 120),
        ],
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
          'How social counts are calculated',
        );
        expect(affordance, findsOneWidget);

        await tester.tap(affordance);
        await tester.pumpAndSettle();

        // Both copy blocks are readable in the opened explanation.
        expect(
          find.textContaining('counts the accounts that currently follow you'),
          findsOneWidget,
        );
        expect(
          find.textContaining('stops showing you their content'),
          findsOneWidget,
        );
      },
    );
  });
}
