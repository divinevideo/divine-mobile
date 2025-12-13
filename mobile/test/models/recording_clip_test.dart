// ABOUTME: Tests for RecordingClip model - segment data with thumbnail support
// ABOUTME: Validates serialization, ordering, and duration calculations

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/recording_clip.dart';

void main() {
  group('RecordingClip', () {
    test('creates clip with required fields', () {
      final clip = RecordingClip(
        id: 'clip_001',
        filePath: '/path/to/video.mp4',
        duration: const Duration(seconds: 2),
        orderIndex: 0,
        recordedAt: DateTime(2025, 12, 13, 10, 0, 0),
      );

      expect(clip.id, equals('clip_001'));
      expect(clip.filePath, equals('/path/to/video.mp4'));
      expect(clip.duration.inSeconds, equals(2));
      expect(clip.orderIndex, equals(0));
    });

    test('durationInSeconds returns correct value', () {
      final clip = RecordingClip(
        id: 'clip_001',
        filePath: '/path/to/video.mp4',
        duration: const Duration(milliseconds: 2500),
        orderIndex: 0,
        recordedAt: DateTime.now(),
      );

      expect(clip.durationInSeconds, equals(2.5));
    });

    test('copyWith creates new instance with updated fields', () {
      final clip = RecordingClip(
        id: 'clip_001',
        filePath: '/path/to/video.mp4',
        duration: const Duration(seconds: 2),
        orderIndex: 0,
        recordedAt: DateTime.now(),
      );

      final updated = clip.copyWith(orderIndex: 3);

      expect(updated.orderIndex, equals(3));
      expect(updated.id, equals(clip.id));
      expect(updated.filePath, equals(clip.filePath));
    });

    test('toJson and fromJson roundtrip preserves data', () {
      final clip = RecordingClip(
        id: 'clip_001',
        filePath: '/path/to/video.mp4',
        duration: const Duration(milliseconds: 2500),
        orderIndex: 1,
        recordedAt: DateTime(2025, 12, 13, 10, 0, 0),
        thumbnailPath: '/path/to/thumb.jpg',
      );

      final json = clip.toJson();
      final restored = RecordingClip.fromJson(json);

      expect(restored.id, equals(clip.id));
      expect(restored.filePath, equals(clip.filePath));
      expect(restored.duration, equals(clip.duration));
      expect(restored.orderIndex, equals(clip.orderIndex));
      expect(restored.thumbnailPath, equals(clip.thumbnailPath));
    });
  });
}
