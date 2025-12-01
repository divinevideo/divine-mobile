// ABOUTME: Tests for PublishStatus enum and publish tracking fields in VineDraft
// ABOUTME: Validates serialization, migration, and status lifecycle

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/models/aspect_ratio.dart';

void main() {
  group('VineDraft PublishStatus', () {
    test('should serialize and deserialize publishStatus correctly', () {
      final now = DateTime.now();
      final draft = VineDraft(
        id: 'test_draft',
        videoFile: File('/path/to/video.mp4'),
        title: 'Test',
        description: 'Desc',
        hashtags: ['test'],
        frameCount: 30,
        selectedApproach: 'native',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
        aspectRatio: AspectRatio.square,
      );

      final json = draft.toJson();
      final deserialized = VineDraft.fromJson(json);

      expect(deserialized.publishStatus, PublishStatus.draft);
      expect(deserialized.publishError, null);
      expect(deserialized.publishAttempts, 0);
    });

    test('should handle all PublishStatus enum values', () {
      final now = DateTime.now();

      for (final status in PublishStatus.values) {
        final draft = VineDraft(
          id: 'test_${status.name}',
          videoFile: File('/path/to/video.mp4'),
          title: 'Test',
          description: '',
          hashtags: [],
          frameCount: 30,
          selectedApproach: 'native',
          createdAt: now,
          lastModified: now,
          publishStatus: status,
          publishError: null,
          publishAttempts: 0,
          aspectRatio: AspectRatio.square,
        );

        final json = draft.toJson();
        final deserialized = VineDraft.fromJson(json);

        expect(deserialized.publishStatus, status);
      }
    });

    test('should migrate old drafts without publishStatus to draft status', () {
      final json = {
        'id': 'old_draft',
        'videoFilePath': '/path/to/video.mp4',
        'title': 'Old Draft',
        'description': 'From before publish status existed',
        'hashtags': ['old'],
        'frameCount': 30,
        'selectedApproach': 'native',
        'createdAt': '2025-01-01T00:00:00.000Z',
        'lastModified': '2025-01-01T00:00:00.000Z',
        // publishStatus, publishError, publishAttempts missing
      };

      final draft = VineDraft.fromJson(json);

      expect(draft.publishStatus, PublishStatus.draft);
      expect(draft.publishError, null);
      expect(draft.publishAttempts, 0);
    });

    test('should serialize publishError when present', () {
      final now = DateTime.now();
      final draft = VineDraft(
        id: 'failed_draft',
        videoFile: File('/path/to/video.mp4'),
        title: 'Failed',
        description: '',
        hashtags: [],
        frameCount: 30,
        selectedApproach: 'native',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.failed,
        publishError: 'Network error',
        publishAttempts: 2,
        aspectRatio: AspectRatio.square,
      );

      final json = draft.toJson();
      expect(json['publishError'], 'Network error');
      expect(json['publishAttempts'], 2);

      final deserialized = VineDraft.fromJson(json);
      expect(deserialized.publishError, 'Network error');
      expect(deserialized.publishAttempts, 2);
    });
  });

  group('VineDraft.copyWith with publish fields', () {
    test('should update publishStatus via copyWith', () {
      final now = DateTime.now();
      final draft = VineDraft(
        id: 'test',
        videoFile: File('/path/to/video.mp4'),
        title: 'Test',
        description: '',
        hashtags: [],
        frameCount: 30,
        selectedApproach: 'native',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
        aspectRatio: AspectRatio.square,
      );

      final publishing = draft.copyWith(
        publishStatus: PublishStatus.publishing,
      );
      expect(publishing.publishStatus, PublishStatus.publishing);
      expect(publishing.id, draft.id);
    });

    test('should update publishError and attempts via copyWith', () {
      final now = DateTime.now();
      final draft = VineDraft(
        id: 'test',
        videoFile: File('/path/to/video.mp4'),
        title: 'Test',
        description: '',
        hashtags: [],
        frameCount: 30,
        selectedApproach: 'native',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
        aspectRatio: AspectRatio.square,
      );

      final failed = draft.copyWith(
        publishStatus: PublishStatus.failed,
        publishError: 'Upload failed',
        publishAttempts: 1,
      );

      expect(failed.publishStatus, PublishStatus.failed);
      expect(failed.publishError, 'Upload failed');
      expect(failed.publishAttempts, 1);
    });

    test('should explicitly clear publishError to null via copyWith', () {
      final now = DateTime.now();
      final draft = VineDraft(
        id: 'test',
        videoFile: File('/path/to/video.mp4'),
        title: 'Test',
        description: '',
        hashtags: [],
        frameCount: 30,
        selectedApproach: 'native',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.failed,
        publishError: 'Previous error',
        publishAttempts: 1,
        aspectRatio: AspectRatio.square,
      );

      // Explicitly set publishError to null
      final cleared = draft.copyWith(
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
      );

      expect(cleared.publishStatus, PublishStatus.draft);
      expect(cleared.publishError, null);
      expect(cleared.publishAttempts, 0);
    });
  });
}
