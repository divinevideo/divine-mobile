// ABOUTME: Test for /profile/me/:index routing that should redirect to actual user npub
// ABOUTME: Ensures the "me" placeholder is resolved to the current user's profile URL

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/services/auth_service.dart';

void main() {
  group('Profile /me/ Redirect', () {
    testWidgets('should redirect /profile/me/0 to current user npub', (
      tester,
    ) async {
      // ARRANGE: Create a test user with known public key
      const testUserHex =
          '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';
      final testUserNpub = NostrKeyUtils.encodePubKey(testUserHex);

      // Create a mock auth service that returns our test user
      final mockAuthService = _MockAuthService(testUserHex);

      // Create a container with the mock auth service
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
      );

      // Build the app with GoRouter
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Wait for initial route to settle
      await tester.pumpAndSettle();

      // ACT: Navigate to /profile/me/0
      final router = container.read(goRouterProvider);
      router.go('/profile/me/0');
      await tester.pumpAndSettle();

      // ASSERT: The route should have redirected to the actual user's npub
      final location = router.routeInformationProvider.value.uri.toString();
      expect(
        location,
        '/profile/$testUserNpub/0',
        reason: 'Should redirect /profile/me/0 to actual user npub',
      );
    });

    testWidgets('should handle /profile/me/1 (grid tab) redirect', (
      tester,
    ) async {
      // ARRANGE
      const testUserHex =
          '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';
      final testUserNpub = NostrKeyUtils.encodePubKey(testUserHex);

      final mockAuthService = _MockAuthService(testUserHex);
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // ACT: Navigate to /profile/me/1 (grid view)
      final router = container.read(goRouterProvider);
      router.go('/profile/me/1');
      await tester.pumpAndSettle();

      // ASSERT: Should redirect to grid view with actual npub
      final location = router.routeInformationProvider.value.uri.toString();
      expect(
        location,
        '/profile/$testUserNpub/1',
        reason: 'Should redirect /profile/me/1 to actual user npub',
      );
    });

    testWidgets('should NOT redirect when npub is not "me"', (tester) async {
      // ARRANGE
      const currentUserHex =
          '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';
      const otherUserHex =
          'aaaaaa1b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';
      final otherUserNpub = NostrKeyUtils.encodePubKey(otherUserHex);

      final mockAuthService = _MockAuthService(currentUserHex);
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // ACT: Navigate to another user's profile (not "me")
      final router = container.read(goRouterProvider);
      router.go('/profile/$otherUserNpub/0');
      await tester.pumpAndSettle();

      // ASSERT: Should NOT redirect - should stay on other user's profile
      final location = router.routeInformationProvider.value.uri.toString();
      expect(
        location,
        '/profile/$otherUserNpub/0',
        reason: 'Should NOT redirect when viewing other user profiles',
      );
    });

    testWidgets('should redirect to home if not authenticated', (tester) async {
      // ARRANGE: Auth service with no current user
      final mockAuthService = _MockAuthService(null);
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // ACT: Try to navigate to /profile/me/0 when not logged in
      final router = container.read(goRouterProvider);
      router.go('/profile/me/0');
      await tester.pumpAndSettle();

      // ASSERT: Should redirect to home (or login screen)
      final location = router.routeInformationProvider.value.uri.toString();
      expect(
        location.contains('/home'),
        isTrue,
        reason: 'Should redirect to home when not authenticated',
      );
    });
  });
}

/// Mock auth service for testing
class _MockAuthService implements AuthService {
  final String? _currentUserHex;

  _MockAuthService(this._currentUserHex);

  @override
  String? get currentPublicKeyHex => _currentUserHex;

  @override
  bool get isAuthenticated => _currentUserHex != null;

  @override
  AuthState get authState =>
      isAuthenticated ? AuthState.authenticated : AuthState.unauthenticated;

  // Implement other required methods as no-ops for this test
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
