// ABOUTME: Tests all real navigation scenarios used in the app
// ABOUTME: Verifies every route pattern and navigation flow works

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/app_router.dart';

void main() {
  group('Real Navigation Scenarios', () {
    testWidgets('Home tab navigation', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go('/home/0');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), '/home/0');

      router.go('/home/5');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), '/home/5');
    });

    testWidgets('Explore tab tap - grid mode', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go('/explore');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/explore',
        reason: 'Explore tab tap should navigate to grid mode',
      );
    });

    testWidgets('Explore grid → feed navigation', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go('/explore/0');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/explore/0',
      );

      router.go('/explore/3');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/explore/3',
      );
    });

    testWidgets('Hashtag grid mode', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go('/hashtag/bitcoin');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/hashtag/bitcoin',
      );
    });

    testWidgets('Hashtag feed mode', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go('/hashtag/bitcoin/0');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/hashtag/bitcoin/0',
      );

      router.go('/hashtag/nostr/5');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/hashtag/nostr/5',
      );
    });

    testWidgets('Profile navigation', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go('/profile/npub1xyz/0');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/profile/npub1xyz/0',
      );

      router.go('/profile/npub1xyz/5');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/profile/npub1xyz/5',
      );
    });

    testWidgets('Search empty', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go('/search');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), '/search');
    });

    testWidgets('Search with term - grid mode', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go('/search/bitcoin');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/search/bitcoin',
      );
    });

    testWidgets('Search with term - feed mode', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go('/search/bitcoin/0');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/search/bitcoin/0',
      );

      router.go('/search/bitcoin/3');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/search/bitcoin/3',
      );
    });

    testWidgets('Camera route', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go('/camera');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), '/camera');
    });

    testWidgets('Settings route', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go('/settings');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), '/settings');
    });

    testWidgets('Notifications navigation', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go('/notifications/0');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/notifications/0',
      );

      router.go('/notifications/2');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/notifications/2',
      );
    });

    testWidgets('Profile/me special route', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // /profile/me/0 should be handled (used in camera after upload)
      router.go('/profile/me/0');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/profile/me/0',
        reason: 'Profile me route should work for current user navigation',
      );
    });

    testWidgets('Edit video route', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Edit video route exists (accessed via context.push with video extra)
      router.go('/edit-video');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/edit-video',
        reason: 'Edit video route should exist',
      );
    });

    testWidgets('Home video feed swiping', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Swiping through home feed updates index in URL
      router.go('/home/0');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), '/home/0');

      router.go('/home/1');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), '/home/1');

      router.go('/home/10');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), '/home/10');
    });

    testWidgets('Explore back to grid from feed', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Navigate to feed mode
      router.go('/explore/5');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/explore/5',
      );

      // Back button should go to grid mode
      router.go('/explore');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/explore',
        reason: 'Back from explore feed should return to grid mode',
      );
    });

    testWidgets('Hashtag back to grid from feed', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Navigate to hashtag feed mode
      router.go('/hashtag/bitcoin/5');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/hashtag/bitcoin/5',
      );

      // Back button should go to hashtag grid mode
      router.go('/hashtag/bitcoin');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/hashtag/bitcoin',
        reason: 'Back from hashtag feed should return to grid mode',
      );
    });

    testWidgets('Search back to grid from feed', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Navigate to search feed mode
      router.go('/search/bitcoin/3');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/search/bitcoin/3',
      );

      // Back button should go to search grid mode
      router.go('/search/bitcoin');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/search/bitcoin',
        reason: 'Back from search feed should return to grid mode',
      );
    });

    testWidgets('URL-encoded hashtags', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Hashtags with spaces or special chars should be URL-encoded
      router.go('/hashtag/my%20tag/0');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/hashtag/my%20tag/0',
        reason: 'URL-encoded hashtags should work',
      );
    });

    testWidgets('URL-encoded search terms', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Search terms with spaces should be URL-encoded
      router.go('/search/hello%20world');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/search/hello%20world',
        reason: 'URL-encoded search terms should work',
      );
    });

    testWidgets('Back button navigates from hashtag feed to grid', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Navigate to hashtag feed mode
      router.go('/hashtag/bitcoin/5');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/hashtag/bitcoin/5',
      );

      // Find and tap the back button in AppBar
      final backButton = find.byIcon(Icons.arrow_back);
      expect(
        backButton,
        findsOneWidget,
        reason: 'Back button should be visible in hashtag feed mode',
      );

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should navigate to hashtag grid mode
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/hashtag/bitcoin',
        reason: 'Tapping back button should navigate from feed to grid mode',
      );
    });

    testWidgets('Back button navigates from search feed to grid', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Navigate to search feed mode
      router.go('/search/nostr/3');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/search/nostr/3',
      );

      // Find and tap the back button
      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should navigate to search grid mode
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/search/nostr',
        reason: 'Tapping back button should navigate from search feed to grid',
      );
    });

    testWidgets('Back button navigates from hashtag grid to explore', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Navigate to hashtag grid mode
      router.go('/hashtag/bitcoin');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/hashtag/bitcoin',
      );

      // Find and tap the back button
      final backButton = find.byIcon(Icons.arrow_back);
      expect(
        backButton,
        findsOneWidget,
        reason: 'Back button should be visible in hashtag grid mode',
      );

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should navigate back to explore
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/explore',
        reason: 'Tapping back from hashtag grid should go to explore',
      );
    });
  });
}
