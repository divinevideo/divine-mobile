// ABOUTME: Simple integration test for HashtagFeedScreen grid view
// ABOUTME: Verifies hashtag feed shows grid when embedded and list when standalone

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/video_event_service.dart';
import '../builders/test_video_event_builder.dart';

class MockVideoEventService extends Mock implements VideoEventService {}

class MockHashtagService extends Mock implements HashtagService {
  @override
  Future<void> subscribeToHashtagVideos(
    List<String> hashtags, {
    int limit = 100,
    int? until,
  }) async {
    return Future.value();
  }
}

void main() {
  group('HashtagFeedScreen grid view', () {
    late MockVideoEventService mockVideoService;
    late MockHashtagService mockHashtagService;

    setUp(() {
      mockVideoService = MockVideoEventService();
      mockHashtagService = MockHashtagService();

      when(() => mockVideoService.isLoading).thenReturn(false);
    });

    testWidgets('shows grid view when embedded', (tester) async {
      final testVideos = TestVideoEventBuilder.createMultiple(count: 6);

      when(
        () => mockHashtagService.getVideosByHashtags(['funny']),
      ).thenReturn(testVideos);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoService),
            hashtagServiceProvider.overrideWithValue(mockHashtagService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HashtagFeedScreen(hashtag: 'funny', embedded: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify GridView is used
      expect(find.byType(GridView), findsOneWidget);

      // Verify video tiles are displayed
      expect(find.byIcon(Icons.play_arrow), findsWidgets);
    });

    testWidgets('shows ListView when not embedded', (tester) async {
      final testVideos = TestVideoEventBuilder.createMultiple(count: 3);

      when(
        () => mockHashtagService.getVideosByHashtags(['funny']),
      ).thenReturn(testVideos);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoService),
            hashtagServiceProvider.overrideWithValue(mockHashtagService),
          ],
          child: const MaterialApp(
            home: HashtagFeedScreen(hashtag: 'funny', embedded: false),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify ListView is used in standalone mode
      expect(find.byType(ListView), findsOneWidget);

      // Verify GridView is NOT used in standalone mode
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('shows empty state when no videos', (tester) async {
      when(
        () => mockHashtagService.getVideosByHashtags(['empty']),
      ).thenReturn([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoService),
            hashtagServiceProvider.overrideWithValue(mockHashtagService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HashtagFeedScreen(hashtag: 'empty', embedded: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify empty state is shown
      expect(find.text('No videos found for #empty'), findsOneWidget);
      expect(find.byIcon(Icons.tag), findsOneWidget);
    });
  });
}
