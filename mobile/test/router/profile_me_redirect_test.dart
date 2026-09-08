// ABOUTME: Tests resolution of the /profile/me placeholder.
// ABOUTME: Ensures the current user's npub and requested view are preserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

import '../helpers/test_pubkeys.dart';

void main() {
  group('Profile /me/ redirect', () {
    final testUserNpub = NostrKeyUtils.encodePubKey(syntheticTestPubkey);

    test('resolves the feed index to the current user npub', () {
      expect(
        meProfileRedirectPath(
          isAuthenticated: true,
          currentPublicKeyHex: syntheticTestPubkey,
          videoIndex: 0,
        ),
        ProfileScreenRouter.pathForIndex(testUserNpub, 0),
      );
    });

    test('resolves the grid index to the current user npub', () {
      expect(
        meProfileRedirectPath(
          isAuthenticated: true,
          currentPublicKeyHex: syntheticTestPubkey,
          videoIndex: 1,
        ),
        ProfileScreenRouter.pathForIndex(testUserNpub, 1),
      );
    });

    test('preserves the profile route when no video index is present', () {
      expect(
        meProfileRedirectPath(
          isAuthenticated: true,
          currentPublicKeyHex: syntheticTestPubkey,
          videoIndex: null,
        ),
        ProfileScreenRouter.pathForNpub(testUserNpub),
      );
    });

    test('sends unauthenticated users to the home feed', () {
      expect(
        meProfileRedirectPath(
          isAuthenticated: false,
          currentPublicKeyHex: null,
          videoIndex: 0,
        ),
        VideoFeedPage.pathForIndex(0),
      );
    });
  });
}
