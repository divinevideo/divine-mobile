// ABOUTME: Tests resolution of the /profile/me placeholder.
// ABOUTME: Ensures the current user's npub and requested view are preserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/profile_screen_router.dart';

import '../helpers/test_pubkeys.dart';

void main() {
  group('Profile /me/ redirect', () {
    test('resolves index 0 to the first video of the profile feed', () {
      expect(
        ProfileScreenRouter.meProfileRedirectPath(
          isAuthenticated: true,
          currentPublicKeyHex: syntheticTestPubkey,
          videoIndex: 0,
        ),
        '/profile/$syntheticTestNpub/0',
      );
    });

    test('preserves a non-zero video index', () {
      expect(
        ProfileScreenRouter.meProfileRedirectPath(
          isAuthenticated: true,
          currentPublicKeyHex: syntheticTestPubkey,
          videoIndex: 1,
        ),
        '/profile/$syntheticTestNpub/1',
      );
    });

    test('resolves a null video index to the profile grid', () {
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
