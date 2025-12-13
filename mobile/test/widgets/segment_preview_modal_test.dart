// ABOUTME: Widget tests for SegmentPreviewModal - video playback overlay
// ABOUTME: Validates video player display and close behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/widgets/clip_manager/segment_preview_modal.dart';

void main() {
  group('SegmentPreviewModal', () {
    final testClip = RecordingClip(
      id: 'clip_001',
      filePath: '/path/to/video.mp4',
      duration: const Duration(seconds: 2),
      orderIndex: 0,
      recordedAt: DateTime.now(),
    );

    testWidgets('displays close button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentPreviewModal(
              clip: testClip,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('calls onClose when close button tapped', (tester) async {
      var closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentPreviewModal(
              clip: testClip,
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
    });

    testWidgets('displays duration info', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentPreviewModal(
              clip: testClip,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('2'), findsWidgets);
    });
  });
}
