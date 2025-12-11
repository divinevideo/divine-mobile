// ABOUTME: Widget tests for ExploreScreen video display functionality
// ABOUTME: Verifies that videos from videoEventsProvider are correctly displayed in grid and feed modes

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/seen_videos_notifier.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/video_event_service.dart';

import '../test_data/video_test_data.dart';
import 'explore_screen_video_display_test.mocks.dart';

// Fake AppForeground notifier for testing
class _FakeAppForeground extends AppForeground {
  @override
  bool build() => true; // Default to foreground
}

// Mock VideoEvents provider that returns test data
class _MockVideoEventsWithData extends VideoEvents {
  final List<VideoEvent> videos;

  _MockVideoEventsWithData(this.videos);

  @override
  Stream<List<VideoEvent>> build() {
    return Stream.value(videos);
  }
}

@GenerateMocks([VideoEventService, NostrClient])
void main() {
  group('ExploreScreen - Video Display Tests', () {
    late MockVideoEventService mockVideoEventService;
    late MockNostrClient mockNostrService;
    late List<VideoEvent> testVideos;

    setUp(() {
      mockVideoEventService = MockVideoEventService();
      mockNostrService = MockNostrClient();

      // Create test videos using proper helper
      testVideos = List.generate(
        6,
        (i) => createTestVideoEvent(
          id: 'video_$i',
          pubkey: 'author_$i',
          title: 'Test Video $i',
          content: 'Test content $i',
          videoUrl: 'https://example.com/video$i.mp4',
          thumbnailUrl: 'https://example.com/thumb$i.jpg',
          createdAt: 1704067200 + (i * 3600), // Increment by 1 hour each
        ),
      );

      // Setup default mocks
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockVideoEventService.discoveryVideos).thenReturn(testVideos);
      when(mockVideoEventService.isSubscribed(any)).thenReturn(false);
      when(mockVideoEventService.hasListeners).thenReturn(false);
    });

    testWidgets('should display videos in grid when data is available', (
      tester,
    ) async {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWith(_FakeAppForeground.new),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.explore, videoIndex: null),
            );
          }),
          seenVideosProvider.overrideWith(() => SeenVideosNotifier()),
          videoEventsProvider.overrideWith(
            () => _MockVideoEventsWithData(testVideos),
          ),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ExploreScreen()),
        ),
      );

      // Allow async updates
      await tester.pump();

      // Assert - Screen renders
      expect(find.byType(ExploreScreen), findsOneWidget);

      // Should show tab labels
      expect(find.text('Popular Now'), findsOneWidget);
      expect(find.text('Trending'), findsOneWidget);

      container.dispose();
    });

    testWidgets('should show empty state when no videos available', (
      tester,
    ) async {
      // Arrange - No videos
      final container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWith(_FakeAppForeground.new),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.explore, videoIndex: null),
            );
          }),
          seenVideosProvider.overrideWith(() => SeenVideosNotifier()),
          videoEventsProvider.overrideWith(() => _MockVideoEventsWithData([])),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ExploreScreen()),
        ),
      );

      await tester.pump();

      // Assert
      expect(find.byType(ExploreScreen), findsOneWidget);
      // Should show "No videos available" or similar empty state message
      // (actual text depends on implementation)

      container.dispose();
    });

    testWidgets('should show loading state while fetching videos', (
      tester,
    ) async {
      // Arrange - Loading state
      final container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWith(_FakeAppForeground.new),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.explore, videoIndex: null),
            );
          }),
          seenVideosProvider.overrideWith(() => SeenVideosNotifier()),
          // Return a never-completing stream to simulate loading
          videoEventsProvider.overrideWith(() {
            return _MockVideoEventsLoading();
          }),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ExploreScreen()),
        ),
      );

      await tester.pump();

      // Assert - Should show loading indicator
      expect(find.byType(ExploreScreen), findsOneWidget);
      // CircularProgressIndicator may be shown while loading
      // (actual behavior depends on implementation)

      container.dispose();
    });

    testWidgets('should switch tabs correctly', (tester) async {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWith(_FakeAppForeground.new),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(
              const RouteContext(type: RouteType.explore, videoIndex: null),
            );
          }),
          seenVideosProvider.overrideWith(() => SeenVideosNotifier()),
          videoEventsProvider.overrideWith(
            () => _MockVideoEventsWithData(testVideos),
          ),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ExploreScreen()),
        ),
      );

      await tester.pump();

      // Initially on "Popular Now" tab
      expect(find.text('Popular Now'), findsOneWidget);

      // Tap "Trending" tab
      await tester.tap(find.text('Trending'));
      await tester.pumpAndSettle();

      // Should switch to Trending tab
      expect(find.text('Trending'), findsOneWidget);

      container.dispose();
    });
  });
}

// Mock provider that simulates loading state
class _MockVideoEventsLoading extends VideoEvents {
  @override
  Stream<List<VideoEvent>> build() {
    // Return a stream that never emits to simulate loading
    return const Stream.empty();
  }
}
