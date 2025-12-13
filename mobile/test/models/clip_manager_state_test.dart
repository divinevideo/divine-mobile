// ABOUTME: Tests for ClipManagerState - UI state for clip management screen
// ABOUTME: Validates duration calculations and clip operations

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/clip_manager_state.dart';

void main() {
  group('ClipManagerState', () {
    final clip1 = RecordingClip(
      id: 'clip_001',
      filePath: '/path/to/video1.mp4',
      duration: const Duration(seconds: 2),
      orderIndex: 0,
      recordedAt: DateTime.now(),
    );

    final clip2 = RecordingClip(
      id: 'clip_002',
      filePath: '/path/to/video2.mp4',
      duration: const Duration(milliseconds: 1500),
      orderIndex: 1,
      recordedAt: DateTime.now(),
    );

    test('totalDuration sums all clip durations', () {
      final state = ClipManagerState(clips: [clip1, clip2]);

      expect(state.totalDuration, equals(const Duration(milliseconds: 3500)));
    });

    test('remainingDuration calculates correctly', () {
      final state = ClipManagerState(clips: [clip1, clip2]);

      // Max is 6.3 seconds = 6300ms, used is 3500ms, remaining is 2800ms
      expect(state.remainingDuration, equals(const Duration(milliseconds: 2800)));
    });

    test('canRecordMore is true when under limit', () {
      final state = ClipManagerState(clips: [clip1]);

      expect(state.canRecordMore, isTrue);
    });

    test('canRecordMore is false when at limit', () {
      final fullClip = RecordingClip(
        id: 'clip_full',
        filePath: '/path/to/video.mp4',
        duration: const Duration(milliseconds: 6300),
        orderIndex: 0,
        recordedAt: DateTime.now(),
      );
      final state = ClipManagerState(clips: [fullClip]);

      expect(state.canRecordMore, isFalse);
    });

    test('hasClips returns correct value', () {
      expect(ClipManagerState(clips: []).hasClips, isFalse);
      expect(ClipManagerState(clips: [clip1]).hasClips, isTrue);
    });

    test('sortedClips returns clips by orderIndex', () {
      final state = ClipManagerState(clips: [clip2, clip1]);

      final sorted = state.sortedClips;
      expect(sorted[0].id, equals('clip_001'));
      expect(sorted[1].id, equals('clip_002'));
    });
  });
}
