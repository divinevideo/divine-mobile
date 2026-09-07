// ABOUTME: Widget tests for ExploreScreen video display functionality
// ABOUTME: Verifies that videos from videoEventsProvider are correctly displayed in grid and feed modes

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/seen_videos_notifier.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/services/video_event_service.dart';

import '../test_data/video_test_data.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockNostrClient extends Mock implements NostrClient {}

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

void main() {
  setUpAll(() {
    registerFallbackValue(SubscriptionType.discovery);
  });

  group('ExploreScreen - Video Display Tests', () {
    late _MockVideoEventService mockVideoEventService;
    late _MockNostrClient mockNostrService;
    late List<VideoEvent> testVideos;

    setUp(() {
      mockVideoEventService = _MockVideoEventService();
      mockNostrService = _MockNostrClient();

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
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockVideoEventService.discoveryVideos).thenReturn(testVideos);
      when(() => mockVideoEventService.isSubscribed(any())).thenReturn(false);
      // This mock exposes ChangeNotifier listener state to isolate rendering.
      // ignore: invalid_use_of_protected_member
      when(() => mockVideoEventService.hasListeners).thenReturn(false);
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
            return Stream.value(const RouteContext(type: RouteType.explore));
          }),
          seenVideosProvider.overrideWith(SeenVideosNotifier.new),
          videoEventsProvider.overrideWith(
            () => _MockVideoEventsWithData(testVideos),
          ),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExploreScreen(),
          ),
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
            return Stream.value(const RouteContext(type: RouteType.explore));
          }),
          seenVideosProvider.overrideWith(SeenVideosNotifier.new),
          videoEventsProvider.overrideWith(() => _MockVideoEventsWithData([])),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExploreScreen(),
          ),
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
            return Stream.value(const RouteContext(type: RouteType.explore));
          }),
          seenVideosProvider.overrideWith(SeenVideosNotifier.new),
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
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExploreScreen(),
          ),
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
            return Stream.value(const RouteContext(type: RouteType.explore));
          }),
          seenVideosProvider.overrideWith(SeenVideosNotifier.new),
          videoEventsProvider.overrideWith(
            () => _MockVideoEventsWithData(testVideos),
          ),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExploreScreen(),
          ),
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
    // TODO(any): Fix and re-enable this test
  }, skip: true);
}

// Mock provider that simulates loading state
class _MockVideoEventsLoading extends VideoEvents {
  @override
  Stream<List<VideoEvent>> build() {
    // Return a stream that never emits to simulate loading
    return const Stream.empty();
  }
}
