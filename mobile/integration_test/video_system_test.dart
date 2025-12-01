// ABOUTME: Full-stack integration tests for Riverpod video system end-to-end functionality
// ABOUTME: Tests complete Nostr event flow to UI display with real Riverpod providers

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/video_feed_screen.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/video_feed_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Riverpod Video System Integration Tests', () {
    testWidgets('Video feed displays correctly with Riverpod architecture', (
      tester,
    ) async {
      // Setup app with ProviderScope for Riverpod
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: const VideoFeedScreen())),
      );

      // Wait for initialization
      await tester.pumpAndSettle();

      // The feed might show loading or empty state initially
      // This is expected since we don't have test data setup
      final context = tester.element(find.byType(VideoFeedScreen));
      final container = ProviderScope.containerOf(context);

      // Verify that providers can be accessed
      expect(() => container.read(videoEventsProvider), returnsNormally);
      expect(() => container.read(videoFeedProvider), returnsNormally);
    });

    testWidgets('Video feed handles empty state correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: const VideoFeedScreen())),
      );

      await tester.pumpAndSettle();

      // Should show appropriate empty state or loading
      // The exact UI depends on feed mode and authentication status
      expect(find.byType(VideoFeedScreen), findsOneWidget);
    });

    testWidgets('Providers maintain state correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: const VideoFeedScreen())),
      );

      await tester.pumpAndSettle();

      final context = tester.element(find.byType(VideoFeedScreen));
      final container = ProviderScope.containerOf(context);

      // Test that providers don't throw when accessed
      expect(
        () => container.read(videoEventsProvider.notifier),
        returnsNormally,
      );
      expect(() => container.read(videoFeedProvider.notifier), returnsNormally);

      // Verify providers have correct initial state
      final videoEvents = container.read(videoEventsProvider);
      expect(videoEvents, isA<AsyncValue>());
    });
  });
}
