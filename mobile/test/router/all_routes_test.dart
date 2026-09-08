// ABOUTME: Comprehensive test verifying all app routes are properly configured
// ABOUTME: Tests both grid and feed modes for explore, hashtag, and profile routes

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/apps/app_detail_screen.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  group('App Router - All Routes', () {
    testWidgets('${VideoFeedPage.pathWithIndex} route works', (tester) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);
      router.go(VideoFeedPage.pathForIndex(0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoFeedPage.pathForIndex(0),
      );
      expect(
        router.configuration
            .findMatch(Uri.parse(VideoFeedPage.pathForIndex(0)))
            .isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );

      router.go(VideoFeedPage.pathForIndex(5));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoFeedPage.pathForIndex(5),
      );
      expect(
        router.configuration
            .findMatch(Uri.parse(VideoFeedPage.pathForIndex(5)))
            .isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );
    });

    testWidgets('${ExploreScreen.path} route works (grid mode)', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);
      router.go(ExploreScreen.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ExploreScreen.path,
      );
      expect(
        router.configuration.findMatch(Uri.parse(ExploreScreen.path)).isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );
    });

    testWidgets('${ExploreScreen.pathWithIndex} route works (feed mode)', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);
      router.go(ExploreScreen.pathForIndex(0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ExploreScreen.pathForIndex(0),
      );
      expect(
        router.configuration
            .findMatch(Uri.parse(ExploreScreen.pathForIndex(0)))
            .isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );

      router.go(ExploreScreen.pathForIndex(3));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ExploreScreen.pathForIndex(3),
      );
      expect(
        router.configuration
            .findMatch(Uri.parse(ExploreScreen.pathForIndex(3)))
            .isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );
    });

    testWidgets('${NotificationsPage.pathWithIndex} route works', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);
      router.go(NotificationsPage.pathForIndex(0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        NotificationsPage.pathForIndex(0),
      );
      expect(
        router.configuration
            .findMatch(Uri.parse(NotificationsPage.pathForIndex(0)))
            .isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );

      router.go(NotificationsPage.pathForIndex(2));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        NotificationsPage.pathForIndex(2),
      );
      expect(
        router.configuration
            .findMatch(Uri.parse(NotificationsPage.pathForIndex(2)))
            .isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );
    });

    testWidgets('${ProfileScreenRouter.pathWithIndex} route works', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);
      router.go(ProfileScreenRouter.pathForIndex('me', 0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ProfileScreenRouter.pathForIndex('me', 0),
      );
      expect(
        router.configuration
            .findMatch(Uri.parse(ProfileScreenRouter.pathForIndex('me', 0)))
            .isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );

      router.go(ProfileScreenRouter.pathForIndex('npub1abc', 5));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ProfileScreenRouter.pathForIndex('npub1abc', 5),
      );
      expect(
        router.configuration
            .findMatch(
              Uri.parse(ProfileScreenRouter.pathForIndex('npub1abc', 5)),
            )
            .isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );
    });

    testWidgets('${HashtagScreenRouter.path} route works (grid mode)', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);
      router.go(HashtagScreenRouter.pathForTag('bitcoin'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        HashtagScreenRouter.pathForTag('bitcoin'),
      );
      expect(
        router.configuration
            .findMatch(Uri.parse(HashtagScreenRouter.pathForTag('bitcoin')))
            .isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );
    });

    testWidgets('${SettingsScreen.path} route works', (tester) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);
      router.go(SettingsScreen.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        SettingsScreen.path,
      );
      expect(
        router.configuration.findMatch(Uri.parse(SettingsScreen.path)).isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );
    });

    testWidgets('${AppsDirectoryScreen.path} route works', (tester) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);
      router.go(AppsDirectoryScreen.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        AppsDirectoryScreen.path,
      );
      expect(
        router.configuration
            .findMatch(Uri.parse(AppsDirectoryScreen.path))
            .isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );
    });

    testWidgets('${AppDetailScreen.path} route works', (tester) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);
      router.go(AppDetailScreen.pathForSlug('primal'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        AppDetailScreen.pathForSlug('primal'),
      );
      expect(
        router.configuration
            .findMatch(Uri.parse(AppDetailScreen.pathForSlug('primal')))
            .isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );
    });

    testWidgets('${VideoRecorderScreen.path} route works', (tester) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);
      router.go(VideoRecorderScreen.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoRecorderScreen.path,
      );
      expect(
        router.configuration
            .findMatch(Uri.parse(VideoRecorderScreen.path))
            .isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );
    });

    testWidgets('${VideoEditorScreen.path} route works', (tester) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);
      router.go(VideoEditorScreen.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoEditorScreen.path,
      );
      expect(
        router.configuration
            .findMatch(Uri.parse(VideoEditorScreen.path))
            .isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );
    });

    testWidgets('${VideoMetadataScreen.path} route works', (tester) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);
      router.go(VideoMetadataScreen.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoMetadataScreen.path,
      );
      expect(
        router.configuration
            .findMatch(Uri.parse(VideoMetadataScreen.path))
            .isError,
        isFalse,
        reason: 'route must resolve to a registered route, not the error route',
      );
    });
  });
}
