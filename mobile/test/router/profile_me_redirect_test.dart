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
        equals('/profile/$syntheticTestNpub/0'),
      );
    });

    test('preserves a non-zero video index', () {
      expect(
        ProfileScreenRouter.meProfileRedirectPath(
          isAuthenticated: true,
          currentPublicKeyHex: syntheticTestPubkey,
          videoIndex: 1,
        ),
        equals('/profile/$syntheticTestNpub/1'),
      );
    });

    test('resolves a null video index to the profile grid', () {
      expect(
        ProfileScreenRouter.meProfileRedirectPath(
          isAuthenticated: true,
          currentPublicKeyHex: syntheticTestPubkey,
          videoIndex: null,
        ),
        equals('/profile/$syntheticTestNpub'),
      );
    });

    test('sends a signed-out session to the home feed', () {
      expect(
        ProfileScreenRouter.meProfileRedirectPath(
          isAuthenticated: false,
          currentPublicKeyHex: null,
          videoIndex: 0,
        ),
        equals('/home/0'),
      );
    });

    // These two pin the isAuthenticated half of the guard: it and
    // currentPublicKeyHex are independent AuthService fields, so either can be
    // present without the other. Without them, dropping `!isAuthenticated ||`
    // keeps the suite green while sending a signed-out session to a profile.
    test(
      'sends a known pubkey with an unsettled auth state to the home feed',
      () {
        expect(
          ProfileScreenRouter.meProfileRedirectPath(
            isAuthenticated: false,
            currentPublicKeyHex: syntheticTestPubkey,
            videoIndex: 0,
          ),
          equals('/home/0'),
        );
      },
    );

    test('sends an authenticated session with no pubkey to the home feed', () {
      expect(
        ProfileScreenRouter.meProfileRedirectPath(
          isAuthenticated: true,
          currentPublicKeyHex: null,
          videoIndex: 0,
        ),
        equals('/home/0'),
      );
    });
  });
}
