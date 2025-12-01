// ABOUTME: Tests that VideoFeedItem safely handles disposal during video initialization
// ABOUTME: Verifies no "ref after unmount" crashes when navigating away before video loads

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/widgets/video_feed_item.dart';
import 'package:openvine/services/visibility_tracker.dart';

void main() {
  testWidgets(
    'VideoFeedItem does not crash when disposed during video initialization',
    (tester) async {
      final now = DateTime.now();
      final video = VideoEvent(
        id: 'test-video-123',
        pubkey: 'test-pubkey',
        content: 'Test video',
        videoUrl: 'https://example.com/video.mp4',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        title: 'Test',
        hashtags: [],
      );

      final container = ProviderContainer(
        overrides: [
          // Use NoopVisibilityTracker to prevent timer leaks in tests
          visibilityTrackerProvider.overrideWithValue(NoopVisibilityTracker()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: VideoFeedItem(video: video, index: 0)),
          ),
        ),
      );

      // Pump once to start video initialization
      await tester.pump();

      // Pump to let visibility detector timer fire (500ms)
      await tester.pump(const Duration(milliseconds: 600));

      // Now navigate away (simulating Home → Explore navigation during video init)
      // This should dispose the VideoFeedItem while video is initializing
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Center(child: Text('Different screen'))),
          ),
        ),
      );

      // Pump to complete disposal and let any pending callbacks fire
      // Use pumpAndSettle to ensure all timers (including visibility detector) complete
      await tester.pumpAndSettle();

      // Should complete without "ref after unmount" crash
      expect(
        tester.takeException(),
        isNull,
        reason:
            'VideoFeedItem should not crash with ref-after-unmount when disposed during initialization',
      );
    },
  );
}
