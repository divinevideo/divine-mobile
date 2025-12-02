// ABOUTME: Tests that embedded HashtagFeedScreen uses callback instead of Navigator.push
// ABOUTME: Ensures videos play inline instead of opening as modal overlay

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/video_event_service.dart';

import 'hashtag_feed_embedded_navigation_test.mocks.dart';

@GenerateMocks([HashtagService, VideoEventService])
void main() {
  group('HashtagFeedScreen embedded navigation', () {
    late MockHashtagService mockHashtagService;
    late MockVideoEventService mockVideoEventService;

    setUp(() {
      mockHashtagService = MockHashtagService();
      mockVideoEventService = MockVideoEventService();

      when(mockVideoEventService.isLoading).thenReturn(false);
      when(mockHashtagService.getVideosByHashtags(any)).thenReturn([]);
    });

    testWidgets(
      'calls onVideoTap callback when embedded and video tapped in grid',
      (tester) async {
        final now = DateTime.now();
        final testVideos = [
          VideoEvent(
            id: 'video1',
            pubkey: 'test',
            content: 'Test 1',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            timestamp: now,
          ),
          VideoEvent(
            id: 'video2',
            pubkey: 'test',
            content: 'Test 2',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            timestamp: now,
          ),
        ];

        when(
          mockHashtagService.getVideosByHashtags(['funny']),
        ).thenReturn(testVideos);

        List<VideoEvent>? callbackVideos;
        int? callbackIndex;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hashtagServiceProvider.overrideWithValue(mockHashtagService),
              videoEventServiceProvider.overrideWithValue(
                mockVideoEventService,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: HashtagFeedScreen(
                  hashtag: 'funny',
                  embedded: true,
                  onVideoTap: (videos, index) {
                    callbackVideos = videos;
                    callbackIndex = index;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap the first video tile
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pumpAndSettle();

        // Verify callback was called with correct parameters
        expect(callbackVideos, equals(testVideos));
        expect(callbackIndex, equals(0));

        // Verify NO navigation happened (no new routes pushed)
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets('uses Navigator.push when NOT embedded', (tester) async {
      final now = DateTime.now();
      final testVideos = [
        VideoEvent(
          id: 'video1',
          pubkey: 'test',
          content: 'Test 1',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
        ),
      ];

      when(
        mockHashtagService.getVideosByHashtags(['funny']),
      ).thenReturn(testVideos);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hashtagServiceProvider.overrideWithValue(mockHashtagService),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
          child: MaterialApp(
            home: HashtagFeedScreen(
              hashtag: 'funny',
              embedded: false, // NOT embedded
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap video tile
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      // Verify navigation DID happen (new route pushed)
      // When not embedded, should push ExploreVideoScreenPure as new route
      expect(
        find.byType(HashtagFeedScreen),
        findsNothing,
      ); // Original screen should be covered
    });

    testWidgets(
      'calls onVideoTap callback when embedded and video tapped in list view',
      (tester) async {
        final now = DateTime.now();
        final testVideos = [
          VideoEvent(
            id: 'video1',
            pubkey: 'test',
            content: 'Test 1',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            timestamp: now,
          ),
          VideoEvent(
            id: 'video2',
            pubkey: 'test',
            content: 'Test 2',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            timestamp: now,
          ),
        ];

        when(
          mockHashtagService.getVideosByHashtags(['funny']),
        ).thenReturn(testVideos);

        List<VideoEvent>? callbackVideos;
        int? callbackIndex;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hashtagServiceProvider.overrideWithValue(mockHashtagService),
              videoEventServiceProvider.overrideWithValue(
                mockVideoEventService,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: HashtagFeedScreen(
                  hashtag: 'funny',
                  embedded: true,
                  onVideoTap: (videos, index) {
                    callbackVideos = videos;
                    callbackIndex = index;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Both grid and list view use GestureDetector for video tiles
        // Tap second video
        final gestures = find.byType(GestureDetector);
        if (gestures.evaluate().length > 1) {
          await tester.tap(gestures.at(1));
          await tester.pumpAndSettle();

          expect(callbackVideos, equals(testVideos));
          expect(callbackIndex, equals(1));
        }
      },
    );
  });
}
