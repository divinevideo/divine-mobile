// ABOUTME: TDD tests for moderation flag icon on VideoFeedItem
// ABOUTME: Tests visibility and interaction of report/block quick actions

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/widgets/video_feed_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_helper.dart';
import 'video_feed_item_moderation_icon_test.mocks.dart';

@GenerateMocks([SharedPreferences])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoFeedItem Moderation Icon - TDD', () {
    late VideoEvent mockVideo;
    late MockSharedPreferences mockPrefs;

    setUp(() {
      final now = DateTime.now();
      mockVideo = VideoEvent(
        id: 'test_event_id_123',
        pubkey: 'test_pubkey_456',
        content: 'Test video description',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        title: 'Test Video',
        duration: 15,
        hashtags: ['test'],
      );

      mockPrefs = MockSharedPreferences();
      createMockSharedPreferences(mockPrefs);
    });

    // RED TEST 1: Flag icon should appear on video feed item
    testWidgets('displays flag icon in video overlay', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            mockPrefs: mockPrefs,
            child: VideoFeedItem(
              video: mockVideo,
              index: 0,
              disableAutoplay: true,
              forceShowOverlay: true,
            ),
          ),
        );

        // Pump a few frames to let widget build
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // RED: Expect to find flag icon (Icons.flag_outlined)
        expect(
          find.byIcon(Icons.flag_outlined),
          findsOneWidget,
          reason: 'Flag icon should be visible in video overlay',
        );
      });
    });

    // RED TEST 2: Flag icon should have correct size
    testWidgets('flag icon has correct sizing', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            mockPrefs: mockPrefs,
            child: VideoFeedItem(
              video: mockVideo,
              index: 0,
              disableAutoplay: true,
              forceShowOverlay: true,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final flagIcon = find.byIcon(Icons.flag_outlined);
        expect(flagIcon, findsOneWidget);

        // RED: Check icon size (should be 32px to match other action buttons)
        final iconWidget = tester.widget<Icon>(flagIcon);
        expect(
          iconWidget.size,
          equals(32.0),
          reason: 'Flag icon should be 32px to match other action buttons',
        );
      });
    });
  });
}
