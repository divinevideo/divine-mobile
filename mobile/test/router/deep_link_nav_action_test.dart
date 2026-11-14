// ABOUTME: Regression tests for shared deep-link navigation decisions
// ABOUTME: Verifies non-video deep links preserve back stack semantics.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/deep_link_coordinator.dart' as app;
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';

void main() {
  group('resolveDeepLinkNavAction', () {
    test('returns skip when already on the target route', () {
      final action = app.resolveDeepLinkNavAction(
        currentLocation: '/profile/npub1abc',
        targetPath: '/profile/npub1abc',
        isRouteFamilyLocation: (location) =>
            location.startsWith('${ProfileScreenRouter.path}/'),
      );

      expect(action, equals(app.DeepLinkNavAction.skip));
    });

    test('returns go when another route in the same family is showing', () {
      const npub =
          'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwx';
      const otherNpub =
          'npub1zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz';
      final action = app.resolveDeepLinkNavAction(
        currentLocation: ProfileScreenRouter.pathForNpub(otherNpub),
        targetPath: ProfileScreenRouter.pathForNpub(npub),
        isRouteFamilyLocation: (location) =>
            location.startsWith('${ProfileScreenRouter.path}/'),
      );

      expect(action, equals(app.DeepLinkNavAction.go));
    });

    test('returns push from a route outside the target family', () {
      final action = app.resolveDeepLinkNavAction(
        currentLocation: '/settings',
        targetPath: '/profile/npub1abc',
        isRouteFamilyLocation: (location) =>
            location.startsWith('${ProfileScreenRouter.path}/'),
      );

      expect(action, equals(app.DeepLinkNavAction.push));
    });

    test('treats hashtag routes as one route family', () {
      final targetPath = HashtagScreenRouter.pathForTag('cats');
      final otherPath = HashtagScreenRouter.pathForTag('dogs');

      final action = app.resolveDeepLinkNavAction(
        currentLocation: otherPath,
        targetPath: targetPath,
        isRouteFamilyLocation: (location) =>
            location.startsWith('${HashtagScreenRouter.basePath}/'),
      );

      expect(action, equals(app.DeepLinkNavAction.go));
    });

    test('treats search result route shapes as one route family', () {
      final targetPath = SearchResultsPage.pathForQuery(
        'vine classics',
        requestFocusOnMount: false,
      );
      final searchLocations = [
        SearchResultsPage.emptyPath,
        '/search-results?focus=1',
        SearchResultsPage.pathForQuery(
          'dog tricks',
          requestFocusOnMount: false,
        ),
        SearchResultsPage.pathForQuery(
          'vine classics',
          requestFocusOnMount: true,
        ),
      ];

      for (final currentLocation in searchLocations) {
        final action = app.resolveDeepLinkNavAction(
          currentLocation: currentLocation,
          targetPath: targetPath,
          isRouteFamilyLocation: (location) =>
              location == SearchResultsPage.emptyPath ||
              location.startsWith('${SearchResultsPage.pathPrefix}/') ||
              location.startsWith('${SearchResultsPage.emptyPath}?'),
        );

        expect(action, equals(app.DeepLinkNavAction.go));
      }
    });

    test('treats both curated list route shapes as one route family', () {
      const authorPubkey =
          'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
      final targetPath = CuratedListByAuthorScreen.pathFor(
        pubkey: authorPubkey,
        listId: 'my-vines',
      );
      final internalPath = CuratedListFeedScreen.pathForId('local-list');

      final action = app.resolveDeepLinkNavAction(
        currentLocation: internalPath,
        targetPath: targetPath,
        isRouteFamilyLocation: (location) =>
            location.startsWith('${CuratedListFeedScreen.basePath}/'),
      );

      expect(action, equals(app.DeepLinkNavAction.go));
    });

    test('does not treat discover lists as a list detail route', () {
      const authorPubkey =
          'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
      final targetPath = CuratedListByAuthorScreen.pathFor(
        pubkey: authorPubkey,
        listId: 'my-vines',
      );

      final action = app.resolveDeepLinkNavAction(
        currentLocation: '/discover-lists',
        targetPath: targetPath,
        isRouteFamilyLocation: (location) =>
            location.startsWith('${CuratedListFeedScreen.basePath}/'),
      );

      expect(action, equals(app.DeepLinkNavAction.push));
    });

    test('pushes saved videos so back returns to where the user was', () {
      final action = app.resolveDeepLinkNavAction(
        currentLocation: '/home/0',
        targetPath: SavedVideosScreen.path,
        isRouteFamilyLocation: (location) => location == SavedVideosScreen.path,
      );

      expect(action, equals(app.DeepLinkNavAction.push));
    });

    test('skips saved videos when the router redirect already landed '
        'there', () {
      final action = app.resolveDeepLinkNavAction(
        currentLocation: SavedVideosScreen.path,
        targetPath: SavedVideosScreen.path,
        isRouteFamilyLocation: (location) => location == SavedVideosScreen.path,
      );

      expect(action, equals(app.DeepLinkNavAction.skip));
    });
  });
}
