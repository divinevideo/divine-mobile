// ABOUTME: Tests for PublishStatus enum and publish tracking fields in VineDraft
// ABOUTME: Validates serialization, migration, and status lifecycle

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('VineDraft PublishStatus', () {
    test('should serialize and deserialize publishStatus correctly', () {
      final now = DateTime.now();
      final draft = DivineVideoDraft(
        id: 'test_draft',
        clips: [
          DivineVideoClip(
            id: 'test_clip',
            video: EditorVideo.file('/path/to/video.mp4'),
            duration: const Duration(seconds: 6),
            recordedAt: now,
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Test',
        description: 'Desc',
        hashtags: {'test'},
        selectedApproach: 'native',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.draft,
        publishAttempts: 0,
      );

      final json = draft.toJson();
      final deserialized = DivineVideoDraft.fromJson(json, '/path/to');

      expect(deserialized.publishStatus, PublishStatus.draft);
      expect(deserialized.publishError, null);
      expect(deserialized.publishAttempts, 0);
    });

    test('should handle all PublishStatus enum values', () {
      final now = DateTime.now();

      for (final status in PublishStatus.values) {
        final draft = DivineVideoDraft(
          id: 'test_${status.name}',
          clips: [
            DivineVideoClip(
              id: 'test_clip',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Test',
          description: '',
          hashtags: {},
          selectedApproach: 'native',
          createdAt: now,
          lastModified: now,
          publishStatus: status,
          publishAttempts: 0,
        );

        final json = draft.toJson();
        final deserialized = DivineVideoDraft.fromJson(json, '/path/to');

        expect(deserialized.publishStatus, status);
      }
    });

    test('should migrate old drafts without publishStatus to draft status', () {
      final json = {
        'id': 'old_draft',
        'videoFilePath': 'video.mp4',
        'title': 'Old Draft',
        'description': 'From before publish status existed',
        'hashtags': ['old'],
        'frameCount': 30,
        'selectedApproach': 'native',
        'createdAt': '2025-01-01T00:00:00.000Z',
        'lastModified': '2025-01-01T00:00:00.000Z',
        // publishStatus, publishError, publishAttempts missing
      };

      final draft = DivineVideoDraft.fromJson(json, '/path/to');

      expect(draft.publishStatus, PublishStatus.draft);
      expect(draft.publishError, null);
      expect(draft.publishAttempts, 0);
    });

    test('should migrate old drafts without allowAudioReuse to off', () {
      final json = {
        'id': 'old_draft',
        'videoFilePath': 'video.mp4',
        'title': 'Old Draft',
        'description': 'From before audio reuse opt-in existed',
        'hashtags': ['old'],
        'frameCount': 30,
        'selectedApproach': 'native',
        'createdAt': '2025-01-01T00:00:00.000Z',
        'lastModified': '2025-01-01T00:00:00.000Z',
      };

      final draft = DivineVideoDraft.fromJson(json, '/path/to');

      expect(draft.allowAudioReuse, isFalse);
    });

    test('should round-trip allowVideoReuse through JSON', () {
      final now = DateTime.now();
      final draft = DivineVideoDraft(
        id: 'reusable_draft',
        clips: const [],
        title: 'Reusable',
        description: '',
        hashtags: const {},
        selectedApproach: 'native',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.draft,
        publishAttempts: 0,
        allowVideoReuse: true,
      );

      final restored = DivineVideoDraft.fromJson(draft.toJson(), '/path/to');

      expect(restored.allowVideoReuse, isTrue);
    });

    test('should serialize publishError when present', () {
      final now = DateTime.now();
      final draft = DivineVideoDraft(
        id: 'failed_draft',
        clips: [
          DivineVideoClip(
            id: 'test_clip',
            video: EditorVideo.file('/path/to/video.mp4'),
            duration: const Duration(seconds: 6),
            recordedAt: now,
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Failed',
        description: '',
        hashtags: {},
        selectedApproach: 'native',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.failed,
        publishError: 'Network error',
        publishAttempts: 2,
      );

      final json = draft.toJson();
      expect(json['publishError'], 'Network error');
      expect(json['publishAttempts'], 2);

      final deserialized = DivineVideoDraft.fromJson(json, '/path/to');
      expect(deserialized.publishError, 'Network error');
      expect(deserialized.publishAttempts, 2);
    });
  });

  group('VineDraft.copyWith with publish fields', () {
    test('should update publishStatus via copyWith', () {
      final now = DateTime.now();
      final draft = DivineVideoDraft(
        id: 'test',
        clips: [
          DivineVideoClip(
            id: 'test_clip',
            video: EditorVideo.file('/path/to/video.mp4'),
            duration: const Duration(seconds: 6),
            recordedAt: now,
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Test',
        description: '',
        hashtags: {},
        selectedApproach: 'native',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.draft,
        publishAttempts: 0,
      );

      final publishing = draft.copyWith(
        publishStatus: PublishStatus.publishing,
      );
      expect(publishing.publishStatus, PublishStatus.publishing);
      expect(publishing.id, draft.id);
    });

    test('should update publishError and attempts via copyWith', () {
      final now = DateTime.now();
      final draft = DivineVideoDraft(
        id: 'test',
        clips: [
          DivineVideoClip(
            id: 'test_clip',
            video: EditorVideo.file('/path/to/video.mp4'),
            duration: const Duration(seconds: 6),
            recordedAt: now,
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Test',
        description: '',
        hashtags: {},
        selectedApproach: 'native',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.draft,
        publishAttempts: 0,
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
      final draft = DivineVideoDraft(
        id: 'test',
        clips: [
          DivineVideoClip(
            id: 'test_clip',
            video: EditorVideo.file('/path/to/video.mp4'),
            duration: const Duration(seconds: 6),
            recordedAt: now,
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Test',
        description: '',
        hashtags: {},
        selectedApproach: 'native',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.failed,
        publishError: 'Previous error',
        publishAttempts: 1,
      );

      // Explicitly set publishError to null
      final cleared = draft.copyWith(
        publishStatus: PublishStatus.draft,
        clearPublishError: true,
        publishAttempts: 0,
      );

      expect(cleared.publishStatus, PublishStatus.draft);
      expect(cleared.publishError, null);
      expect(cleared.publishAttempts, 0);
    });
  });
}
