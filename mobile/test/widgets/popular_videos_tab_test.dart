// ABOUTME: Tests for PopularVideosTab widget extracted from ExploreScreen
// ABOUTME: Verifies loading, error, and data states for trending/popular videos

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/widgets/popular_videos_tab.dart';

import '../test_data/video_test_data.dart';
import 'popular_videos_tab_test.mocks.dart';

/// Mock VideoEvents provider that returns test data via stream
class _MockVideoEventsWithData extends VideoEvents {
  final List<VideoEvent> videos;

  _MockVideoEventsWithData(this.videos);

  @override
  Stream<List<VideoEvent>> build() {
    return Stream.value(videos);
  }
}

/// Mock VideoEvents provider that returns loading state
class _MockVideoEventsLoading extends VideoEvents {
  @override
  Stream<List<VideoEvent>> build() {
    // Return a stream that never completes to simulate loading
    return const Stream.empty();
  }
}

/// Mock VideoEvents provider that returns an error
class _MockVideoEventsError extends VideoEvents {
  @override
  Stream<List<VideoEvent>> build() {
    return Stream.error(Exception('Network error'));
  }
}

@GenerateMocks([VideoEventService, NostrClient])
void main() {
  group('PopularVideosTab', () {
    late MockVideoEventService mockVideoEventService;
    late MockNostrClient mockNostrService;
    late List<VideoEvent> testVideos;

    setUp(() {
      mockVideoEventService = MockVideoEventService();
      mockNostrService = MockNostrClient();

      // Create test videos with different loop counts
      testVideos = [
        createTestVideoEvent(
          id: 'video_1',
          pubkey: 'author_1',
          originalLoops: 50,
        ),
        createTestVideoEvent(
          id: 'video_2',
          pubkey: 'author_2',
          originalLoops: 100,
        ),
        createTestVideoEvent(
          id: 'video_3',
          pubkey: 'author_3',
          originalLoops: 75,
        ),
      ];

      // Setup default mocks
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockVideoEventService.discoveryVideos).thenReturn(testVideos);
      when(mockVideoEventService.isSubscribed(any)).thenReturn(false);
      when(mockVideoEventService.hasListeners).thenReturn(false);
    });

    Widget buildTestWidget({
      required VideoEvents Function() videoEventsBuilder,
    }) {
      return ProviderScope(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          videoEventsProvider.overrideWith(videoEventsBuilder),
        ],
        child: MaterialApp(
          home: Scaffold(body: PopularVideosTab(onVideoTap: (_, __) {})),
        ),
      );
    }

    testWidgets('shows loading indicator when data is loading', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(videoEventsBuilder: () => _MockVideoEventsLoading()),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when loading fails', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(videoEventsBuilder: () => _MockVideoEventsError()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load trending videos'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('shows trending hashtags section when data is available', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          videoEventsBuilder: () => _MockVideoEventsWithData(testVideos),
        ),
      );
      await tester.pumpAndSettle();

      // Should show the Trending Hashtags title
      expect(find.text('Trending Hashtags'), findsOneWidget);
    });

    testWidgets('handles empty video list', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(videoEventsBuilder: () => _MockVideoEventsWithData([])),
      );
      await tester.pumpAndSettle();

      // Should still show hashtags section even with no videos
      expect(find.text('Trending Hashtags'), findsOneWidget);
    });
  });
}
