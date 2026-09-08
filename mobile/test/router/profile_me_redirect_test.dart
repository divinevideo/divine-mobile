// ABOUTME: Tests resolution of the /profile/me placeholder.
// ABOUTME: Ensures the current user's npub and requested view are preserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/profile_screen_router.dart';

import '../helpers/test_pubkeys.dart';

void main() {
  group('Profile /me/ redirect', () {
    test('resolves the feed index to the current user npub', () {
      expect(
        ProfileScreenRouter.meProfileRedirectPath(
          isAuthenticated: true,
          currentPublicKeyHex: syntheticTestPubkey,
          videoIndex: 0,
        ),
        '/profile/$syntheticTestNpub/0',
      );
    });

    test('resolves the grid index to the current user npub', () {
      expect(
        ProfileScreenRouter.meProfileRedirectPath(
          isAuthenticated: true,
          currentPublicKeyHex: syntheticTestPubkey,
          videoIndex: 1,
        ),
        '/profile/$syntheticTestNpub/1',
      );
    });

    test('preserves the profile route when no video index is present', () {
      expect(
        ProfileScreenRouter.meProfileRedirectPath(
          isAuthenticated: true,
          currentPublicKeyHex: syntheticTestPubkey,
          videoIndex: null,
        ),
        '/profile/$syntheticTestNpub',
      );
    });

    test('sends unauthenticated users to the home feed', () {
      expect(
        ProfileScreenRouter.meProfileRedirectPath(
          isAuthenticated: false,
          currentPublicKeyHex: null,
          videoIndex: 0,
        ),
        '/home/0',
      );
    });
  });
}
