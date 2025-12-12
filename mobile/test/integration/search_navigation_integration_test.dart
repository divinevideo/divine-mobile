// ABOUTME: Integration test for complete search navigation flow with real router
// ABOUTME: Tests URL updates, search term persistence, and video feed navigation

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:nostr_client/nostr_client.dart';

import 'search_navigation_integration_test.mocks.dart';

@GenerateMocks([VideoEventService, NostrClient])
void main() {
  group('Search Navigation Integration Tests', () {
    late MockVideoEventService mockVideoEventService;
    late MockNostrClient mockNostrService;

    setUp(() {
      mockVideoEventService = MockVideoEventService();
      mockNostrService = MockNostrClient();

      // Setup default mock behavior
      when(mockNostrService.isInitialized).thenReturn(true);
      when(
        mockVideoEventService.searchVideos(any, limit: anyNamed('limit')),
      ).thenAnswer((_) async {});
      when(mockVideoEventService.searchResults).thenReturn([]);
    });

    testWidgets('Complete search flow: enter term → URL updates', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );

      // Build widget tree with router
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Navigate to /search
      container.read(goRouterProvider).go('/search');
      await tester.pumpAndSettle();

      // Assert: Should be on search screen in grid mode
      expect(find.byType(SearchScreenPure), findsOneWidget);
      final pageContext1 = container.read(pageContextProvider);
      expect(pageContext1.value?.type, RouteType.search);
      expect(pageContext1.value?.searchTerm, isNull);
      expect(pageContext1.value?.videoIndex, isNull);

      // Step 2: User enters "bitcoin" in search field
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'bitcoin');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Assert: URL should update to /search/bitcoin
      final router = container.read(goRouterProvider);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        contains('/search/bitcoin'),
      );

      // Assert: Search should be triggered
      verify(
        mockVideoEventService.searchVideos('bitcoin', limit: anyNamed('limit')),
      ).called(greaterThan(0));

      // Wait for UI to settle
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Step 3: Simulate user tapping video (by navigating to feed mode)
      container.read(goRouterProvider).go('/search/bitcoin/1');
      await tester.pumpAndSettle();

      // Assert: URL should update to /search/bitcoin/1
      expect(
        router.routeInformationProvider.value.uri.toString(),
        equals('/search/bitcoin/1'),
      );

      // Assert: PageContext should reflect feed mode
      final pageContext2 = container.read(pageContextProvider);
      expect(pageContext2.value?.type, RouteType.search);
      expect(pageContext2.value?.searchTerm, 'bitcoin');
      expect(pageContext2.value?.videoIndex, 1);

      container.dispose();
    });

    testWidgets('Direct URL access to /search/bitcoin loads results', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
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

      container.read(goRouterProvider).go('/search/bitcoin');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('bitcoin'));

      verify(
        mockVideoEventService.searchVideos('bitcoin', limit: anyNamed('limit')),
      ).called(greaterThan(0));

      final pageContext = container.read(pageContextProvider);
      expect(pageContext.value?.type, RouteType.search);
      expect(pageContext.value?.searchTerm, 'bitcoin');

      container.dispose();
    });

    testWidgets('Direct URL access to /search/bitcoin/3 loads video feed', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
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

      container.read(goRouterProvider).go('/search/bitcoin/2');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final pageContext = container.read(pageContextProvider);
      expect(pageContext.value?.type, RouteType.search);
      expect(pageContext.value?.searchTerm, 'bitcoin');
      expect(pageContext.value?.videoIndex, 2);

      container.dispose();
    });

    testWidgets(
      'Back navigation from /search/bitcoin/1 returns to /search/bitcoin',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWithValue(mockNostrService),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
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

        container.read(goRouterProvider).go('/search/bitcoin/1');
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        final pageContext1 = container.read(pageContextProvider);
        expect(pageContext1.value?.videoIndex, 1);

        final router = container.read(goRouterProvider);
        router.go('/search/bitcoin');
        await tester.pumpAndSettle();

        final pageContext2 = container.read(pageContextProvider);
        expect(pageContext2.value?.type, RouteType.search);
        expect(pageContext2.value?.searchTerm, 'bitcoin');
        expect(pageContext2.value?.videoIndex, isNull);

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, equals('bitcoin'));

        container.dispose();
      },
    );

    testWidgets('Changing search term updates URL', (tester) async {
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
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

      container.read(goRouterProvider).go('/search/bitcoin');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      verify(
        mockVideoEventService.searchVideos('bitcoin', limit: anyNamed('limit')),
      ).called(greaterThan(0));

      reset(mockVideoEventService);
      when(mockNostrService.isInitialized).thenReturn(true);
      when(
        mockVideoEventService.searchVideos(any, limit: anyNamed('limit')),
      ).thenAnswer((_) async {});
      when(mockVideoEventService.searchResults).thenReturn([]);

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'nostr');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final router = container.read(goRouterProvider);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        contains('/search/nostr'),
      );

      verify(
        mockVideoEventService.searchVideos('nostr', limit: anyNamed('limit')),
      ).called(greaterThan(0));

      final pageContext = container.read(pageContextProvider);
      expect(pageContext.value?.searchTerm, 'nostr');

      container.dispose();
    });
  });
}
