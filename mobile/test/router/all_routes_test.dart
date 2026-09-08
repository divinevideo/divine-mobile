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

      router.go(VideoFeedPage.pathForIndex(5));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoFeedPage.pathForIndex(5),
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

      router.go(ExploreScreen.pathForIndex(3));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ExploreScreen.pathForIndex(3),
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

      router.go(NotificationsPage.pathForIndex(2));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        NotificationsPage.pathForIndex(2),
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

      router.go(ProfileScreenRouter.pathForIndex('npub1abc', 5));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ProfileScreenRouter.pathForIndex('npub1abc', 5),
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
    });
  });
}
