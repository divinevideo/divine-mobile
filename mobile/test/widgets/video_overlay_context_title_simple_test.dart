// ABOUTME: Simple widget test for VideoOverlayActions contextTitle display
// ABOUTME: Verifies hashtag/context indicator chip shows correctly

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_feed_item.dart';
import '../builders/test_video_event_builder.dart';
import '../helpers/test_provider_overrides.dart';

void main() {
  group('VideoOverlayActions contextTitle', () {
    testWidgets('shows contextTitle chip when provided', (tester) async {
      final testVideo = TestVideoEventBuilder.create();

      await tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VideoOverlayActions(
                video: testVideo,
                isVisible: true,
                isActive: true,
                contextTitle: '#funny',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify contextTitle chip is displayed
      expect(find.text('#funny'), findsOneWidget);

      // Verify tag icon is present
      expect(find.byIcon(Icons.tag), findsOneWidget);
    });

    testWidgets('does not show contextTitle chip when null', (tester) async {
      final testVideo = TestVideoEventBuilder.create();

      await tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VideoOverlayActions(
                video: testVideo,
                isVisible: true,
                isActive: true,
                contextTitle: null,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify tag icon is NOT present (contextTitle chip not shown)
      expect(find.byIcon(Icons.tag), findsNothing);
    });

    testWidgets('shows both publisher chip and contextTitle chip', (
      tester,
    ) async {
      final testVideo = TestVideoEventBuilder.create();

      await tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VideoOverlayActions(
                video: testVideo,
                isVisible: true,
                isActive: true,
                contextTitle: '#funny',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify both chips are shown
      expect(find.byIcon(Icons.person), findsOneWidget); // Publisher chip
      expect(find.byIcon(Icons.tag), findsOneWidget); // Context title chip
      expect(find.text('#funny'), findsOneWidget);
    });
  });
}
