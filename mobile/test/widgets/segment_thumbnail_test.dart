// ABOUTME: Widget tests for SegmentThumbnail - clip grid item display
// ABOUTME: Validates thumbnail display, duration badge, delete button

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/widgets/clip_manager/segment_thumbnail.dart';

void main() {
  group('SegmentThumbnail', () {
    final testClip = RecordingClip(
      id: 'clip_001',
      filePath: '/path/to/video.mp4',
      duration: const Duration(milliseconds: 2500),
      orderIndex: 0,
      recordedAt: DateTime.now(),
    );

    testWidgets('displays duration badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentThumbnail(
              clip: testClip,
              onTap: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('2.5s'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentThumbnail(
              clip: testClip,
              onTap: () => tapped = true,
              onDelete: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SegmentThumbnail));
      expect(tapped, isTrue);
    });

    testWidgets('calls onDelete when delete button tapped', (tester) async {
      var deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentThumbnail(
              clip: testClip,
              onTap: () {},
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(deleted, isTrue);
    });

    testWidgets('shows play icon overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentThumbnail(
              clip: testClip,
              onTap: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    });
  });
}
