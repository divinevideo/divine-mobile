// ABOUTME: Tests all real navigation scenarios used in the app
// ABOUTME: Verifies every route pattern and navigation flow works

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  group('Real Navigation Scenarios', () {
    testWidgets('Home tab navigation', (tester) async {
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

    testWidgets('Explore tab tap - grid mode', (tester) async {
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
        reason: 'Explore tab tap should navigate to grid mode',
      );
    });

    testWidgets('Explore grid → feed navigation', (tester) async {
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

    testWidgets('Hashtag grid mode', (tester) async {
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

    testWidgets('Profile navigation', (tester) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);

      router.go(ProfileScreenRouter.pathForIndex('npub1xyz', 0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ProfileScreenRouter.pathForIndex('npub1xyz', 0),
      );

      router.go(ProfileScreenRouter.pathForIndex('npub1xyz', 5));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ProfileScreenRouter.pathForIndex('npub1xyz', 5),
      );
    });

    testWidgets('Settings route', (tester) async {
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

    testWidgets('Notifications navigation', (tester) async {
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

    testWidgets('Profile/me special route', (tester) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);

      // /profile/me/0 should be handled (used in camera after upload)
      router.go(ProfileScreenRouter.pathForIndex('me', 0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ProfileScreenRouter.pathForIndex('me', 0),
        reason: 'Profile me route should work for current user navigation',
      );
    });

    testWidgets('Edit video route', (tester) async {
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
        reason: 'Edit video route should exist',
      );
    });

    testWidgets('Home video feed swiping', (tester) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);

      // Swiping through home feed updates index in URL
      router.go(VideoFeedPage.pathForIndex(0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoFeedPage.pathForIndex(0),
      );

      router.go(VideoFeedPage.pathForIndex(1));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoFeedPage.pathForIndex(1),
      );

      router.go(VideoFeedPage.pathForIndex(10));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoFeedPage.pathForIndex(10),
      );
    });

    testWidgets('Explore back to grid from feed', (tester) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);

      // Navigate to feed mode
      router.go(ExploreScreen.pathForIndex(5));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ExploreScreen.pathForIndex(5),
      );

      // Back button should go to grid mode
      router.go(ExploreScreen.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ExploreScreen.path,
        reason: 'Back from explore feed should return to grid mode',
      );
    });

    testWidgets('URL-encoded hashtags', (tester) async {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);

      // Hashtags with spaces or special chars should be URL-encoded
      router.go(HashtagScreenRouter.pathForTag('my%20tag'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        HashtagScreenRouter.pathForTag('my%20tag'),
        reason: 'URL-encoded hashtags should work',
      );
    });
  });
}
