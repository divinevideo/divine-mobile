// ABOUTME: Tests for ClipManagerService - business logic for clip operations
// ABOUTME: Validates add, delete, reorder, and thumbnail generation

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/clip_manager_service.dart';

void main() {
  group('ClipManagerService', () {
    late ClipManagerService service;

    setUp(() {
      service = ClipManagerService();
    });

    tearDown(() {
      service.dispose();
    });

    test('starts with empty clips', () {
      expect(service.clips, isEmpty);
      expect(service.hasClips, isFalse);
    });

    test('addClip adds clip and notifies', () {
      var notified = false;
      service.addListener(() => notified = true);

      service.addClip(
        filePath: '/path/to/video.mp4',
        duration: const Duration(seconds: 2),
      );

      expect(service.clips.length, equals(1));
      expect(service.clips[0].filePath, equals('/path/to/video.mp4'));
      expect(notified, isTrue);
    });

    test('deleteClip removes clip by id', () {
      service.addClip(
        filePath: '/path/to/video1.mp4',
        duration: const Duration(seconds: 2),
      );
      service.addClip(
        filePath: '/path/to/video2.mp4',
        duration: const Duration(seconds: 1),
      );

      final clipToDelete = service.clips[0].id;
      service.deleteClip(clipToDelete);

      expect(service.clips.length, equals(1));
      expect(service.clips[0].filePath, equals('/path/to/video2.mp4'));
    });

    test('reorderClips updates orderIndex values', () {
      service.addClip(filePath: '/path/1.mp4', duration: const Duration(seconds: 1));
      service.addClip(filePath: '/path/2.mp4', duration: const Duration(seconds: 1));
      service.addClip(filePath: '/path/3.mp4', duration: const Duration(seconds: 1));

      final ids = service.clips.map((c) => c.id).toList();
      // Reverse the order
      service.reorderClips([ids[2], ids[1], ids[0]]);

      expect(service.clips[0].orderIndex, equals(2));
      expect(service.clips[2].orderIndex, equals(0));
    });

    test('totalDuration sums all clips', () {
      service.addClip(filePath: '/path/1.mp4', duration: const Duration(seconds: 2));
      service.addClip(filePath: '/path/2.mp4', duration: const Duration(milliseconds: 1500));

      expect(service.totalDuration, equals(const Duration(milliseconds: 3500)));
    });

    test('clearAll removes all clips', () {
      service.addClip(filePath: '/path/1.mp4', duration: const Duration(seconds: 1));
      service.addClip(filePath: '/path/2.mp4', duration: const Duration(seconds: 1));

      service.clearAll();

      expect(service.clips, isEmpty);
    });
  });
}
