// ABOUTME: Tests for ClipLibraryService - persistent storage for video clips
// ABOUTME: Covers save, load, delete, and thumbnail generation for clips

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ClipLibraryService', () {
    late ClipLibraryService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = ClipLibraryService(prefs);
    });

    group('saveClip', () {
      test('saves a clip and retrieves it', () async {
        final clip = SavedClip(
          id: 'clip_123',
          filePath: '/tmp/test_video.mp4',
          thumbnailPath: '/tmp/test_thumb.jpg',
          duration: const Duration(seconds: 2),
          createdAt: DateTime.now(),
          aspectRatio: 'square',
        );

        await service.saveClip(clip);
        final clips = await service.getAllClips();

        expect(clips.length, 1);
        expect(clips.first.id, 'clip_123');
        expect(clips.first.filePath, '/tmp/test_video.mp4');
      });

      test('updates existing clip with same ID', () async {
        final clip1 = SavedClip(
          id: 'clip_123',
          filePath: '/tmp/test_video.mp4',
          thumbnailPath: null,
          duration: const Duration(seconds: 2),
          createdAt: DateTime.now(),
          aspectRatio: 'square',
        );

        final clip2 = SavedClip(
          id: 'clip_123',
          filePath: '/tmp/test_video.mp4',
          thumbnailPath: '/tmp/updated_thumb.jpg',
          duration: const Duration(seconds: 2),
          createdAt: DateTime.now(),
          aspectRatio: 'square',
        );

        await service.saveClip(clip1);
        await service.saveClip(clip2);
        final clips = await service.getAllClips();

        expect(clips.length, 1);
        expect(clips.first.thumbnailPath, '/tmp/updated_thumb.jpg');
      });
    });

    group('deleteClip', () {
      test('removes clip by ID', () async {
        final clip = SavedClip(
          id: 'clip_to_delete',
          filePath: '/tmp/test_video.mp4',
          thumbnailPath: null,
          duration: const Duration(seconds: 2),
          createdAt: DateTime.now(),
          aspectRatio: 'square',
        );

        await service.saveClip(clip);
        expect((await service.getAllClips()).length, 1);

        await service.deleteClip('clip_to_delete');
        expect((await service.getAllClips()).length, 0);
      });

      test('does nothing when clip ID not found', () async {
        final clip = SavedClip(
          id: 'existing_clip',
          filePath: '/tmp/test_video.mp4',
          thumbnailPath: null,
          duration: const Duration(seconds: 2),
          createdAt: DateTime.now(),
          aspectRatio: 'square',
        );

        await service.saveClip(clip);
        await service.deleteClip('nonexistent_clip');

        expect((await service.getAllClips()).length, 1);
      });
    });

    group('getAllClips', () {
      test('returns empty list when no clips saved', () async {
        final clips = await service.getAllClips();
        expect(clips, isEmpty);
      });

      test('returns clips sorted by creation date (newest first)', () async {
        final oldClip = SavedClip(
          id: 'old_clip',
          filePath: '/tmp/old.mp4',
          thumbnailPath: null,
          duration: const Duration(seconds: 1),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          aspectRatio: 'square',
        );

        final newClip = SavedClip(
          id: 'new_clip',
          filePath: '/tmp/new.mp4',
          thumbnailPath: null,
          duration: const Duration(seconds: 1),
          createdAt: DateTime.now(),
          aspectRatio: 'square',
        );

        await service.saveClip(oldClip);
        await service.saveClip(newClip);

        final clips = await service.getAllClips();
        expect(clips.first.id, 'new_clip');
        expect(clips.last.id, 'old_clip');
      });
    });

    group('getClipById', () {
      test('returns clip when found', () async {
        final clip = SavedClip(
          id: 'find_me',
          filePath: '/tmp/test.mp4',
          thumbnailPath: null,
          duration: const Duration(seconds: 2),
          createdAt: DateTime.now(),
          aspectRatio: 'vertical',
        );

        await service.saveClip(clip);
        final found = await service.getClipById('find_me');

        expect(found, isNotNull);
        expect(found!.id, 'find_me');
        expect(found.aspectRatio, 'vertical');
      });

      test('returns null when clip not found', () async {
        final found = await service.getClipById('nonexistent');
        expect(found, isNull);
      });
    });

    group('clearAllClips', () {
      test('removes all clips', () async {
        for (var i = 0; i < 5; i++) {
          await service.saveClip(SavedClip(
            id: 'clip_$i',
            filePath: '/tmp/video_$i.mp4',
            thumbnailPath: null,
            duration: const Duration(seconds: 1),
            createdAt: DateTime.now(),
            aspectRatio: 'square',
          ));
        }

        expect((await service.getAllClips()).length, 5);

        await service.clearAllClips();
        expect((await service.getAllClips()).length, 0);
      });
    });
  });

  group('SavedClip', () {
    test('serializes to and from JSON correctly', () {
      final original = SavedClip(
        id: 'test_clip',
        filePath: '/path/to/video.mp4',
        thumbnailPath: '/path/to/thumb.jpg',
        duration: const Duration(milliseconds: 2500),
        createdAt: DateTime(2024, 1, 15, 10, 30),
        aspectRatio: 'vertical',
      );

      final json = original.toJson();
      final restored = SavedClip.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.filePath, original.filePath);
      expect(restored.thumbnailPath, original.thumbnailPath);
      expect(restored.duration, original.duration);
      expect(restored.createdAt, original.createdAt);
      expect(restored.aspectRatio, original.aspectRatio);
    });

    test('handles null thumbnailPath in JSON', () {
      final clip = SavedClip(
        id: 'no_thumb',
        filePath: '/path/to/video.mp4',
        thumbnailPath: null,
        duration: const Duration(seconds: 3),
        createdAt: DateTime.now(),
        aspectRatio: 'square',
      );

      final json = clip.toJson();
      final restored = SavedClip.fromJson(json);

      expect(restored.thumbnailPath, isNull);
    });

    test('durationInSeconds returns correct value', () {
      final clip = SavedClip(
        id: 'test',
        filePath: '/test.mp4',
        thumbnailPath: null,
        duration: const Duration(milliseconds: 2500),
        createdAt: DateTime.now(),
        aspectRatio: 'square',
      );

      expect(clip.durationInSeconds, 2.5);
    });

    test('displayDuration formats correctly', () {
      final recentClip = SavedClip(
        id: 'recent',
        filePath: '/test.mp4',
        thumbnailPath: null,
        duration: const Duration(seconds: 1),
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        aspectRatio: 'square',
      );

      expect(recentClip.displayDuration, '5m ago');

      final oldClip = SavedClip(
        id: 'old',
        filePath: '/test.mp4',
        thumbnailPath: null,
        duration: const Duration(seconds: 1),
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        aspectRatio: 'square',
      );

      expect(oldClip.displayDuration, '2d ago');
    });
  });
}
