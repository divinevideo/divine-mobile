// ABOUTME: Tests for SearchScreenPure URL integration
// ABOUTME: Verifies search screen reads search term from URL and triggers search

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:nostr_client/nostr_client.dart';

import 'search_screen_pure_url_test.mocks.dart';

@GenerateMocks([VideoEventService, NostrClient])
void main() {
  group('SearchScreenPure URL Integration', () {
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

    testWidgets('reads search term from URL and populates text field', (
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

      // Navigate to search with term 'nostr'
      container.read(goRouterProvider).go('/search/nostr');
      await tester.pump(); // Trigger initial navigation
      await tester.pump(); // Render the screen
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // Allow postFrameCallback to run
      await tester.pump(); // Process search initiation
      await tester.pump(
        const Duration(milliseconds: 800),
      ); // Complete the Future.delayed in _performSearch

      // Assert: Search text field should contain 'nostr'
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('nostr'));

      // Assert: PageContext should reflect search term
      final pageContext = container.read(pageContextProvider);
      expect(pageContext.value?.type, RouteType.search);
      expect(pageContext.value?.searchTerm, 'nostr');

      container.dispose();
    });

    testWidgets('automatically triggers search when search term is in URL', (
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

      // Navigate to search with term 'bitcoin'
      container.read(goRouterProvider).go('/search/bitcoin');
      await tester.pump(); // Trigger initial navigation
      await tester.pump(); // Render the screen
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // Allow postFrameCallback to run
      await tester.pump(); // Process search initiation
      await tester.pump(
        const Duration(milliseconds: 800),
      ); // Complete the Future.delayed in _performSearch

      // Assert: Search should be triggered with 'bitcoin'
      verify(
        mockVideoEventService.searchVideos('bitcoin', limit: anyNamed('limit')),
      ).called(greaterThan(0));

      container.dispose();
    });

    testWidgets('shows empty state when search term is null', (tester) async {
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

      // Navigate to search without term
      container.read(goRouterProvider).go('/search');
      await tester.pumpAndSettle();

      // Assert: Empty state UI should be shown
      expect(find.text('Search for videos'), findsOneWidget);
      expect(
        find.text('Enter keywords, hashtags, or user names'),
        findsOneWidget,
      );

      // Assert: Search should NOT be triggered
      verifyNever(
        mockVideoEventService.searchVideos(any, limit: anyNamed('limit')),
      );

      container.dispose();
    });

    testWidgets('updates search when URL changes', (tester) async {
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

      // Navigate to search with term 'nostr'
      container.read(goRouterProvider).go('/search/nostr');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Verify initial search
      verify(
        mockVideoEventService.searchVideos('nostr', limit: anyNamed('limit')),
      ).called(greaterThan(0));

      // Reset mock to clear call history
      reset(mockVideoEventService);
      when(
        mockVideoEventService.searchVideos(any, limit: anyNamed('limit')),
      ).thenAnswer((_) async {});
      when(mockVideoEventService.searchResults).thenReturn([]);

      // Act: Navigate to search with term 'bitcoin'
      container.read(goRouterProvider).go('/search/bitcoin');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Assert: Text field should update to 'bitcoin'
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('bitcoin'));

      // Assert: New search should be triggered with 'bitcoin'
      verify(
        mockVideoEventService.searchVideos('bitcoin', limit: anyNamed('limit')),
      ).called(greaterThan(0));

      container.dispose();
    });
  });
}
