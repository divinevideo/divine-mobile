// ABOUTME: Tests for DivineVideoDraft.copyWith clear* boolean parameters
// ABOUTME: Validates selectedSound, publishError, proofManifest clear logic

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

const _testPubkey =
    'abc123def456789012345678901234567890123456789012345678901234abcd';

DivineVideoClip _createTestClip() => DivineVideoClip(
  id: 'clip_1',
  video: EditorVideo.file('/tmp/test.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2025),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
);

DivineVideoDraft _createDraft({AudioEvent? selectedSound}) => DivineVideoDraft(
  id: 'draft_1',
  clips: [_createTestClip()],
  title: 'Test Draft',
  description: 'A test draft',
  hashtags: const {'test'},
  selectedApproach: 'camera',
  createdAt: DateTime(2025),
  lastModified: DateTime(2025),
  publishStatus: PublishStatus.draft,
  publishAttempts: 0,
  publishError: 'some error',
  proofManifestJson: '{"videoHash":"abc"}',
  selectedSound:
      selectedSound ??
      AudioEvent(
        id: 'sound-id-12345678901234567890123456789012345678901234567890123',
        pubkey: _testPubkey,
        createdAt: 1700000000,
        url: 'https://blossom.example/audio.aac',
        title: 'Test Sound',
        startOffset: const Duration(milliseconds: 2000),
      ),
);

void main() {
  group(DivineVideoDraft, () {
    test('preserves public audio attribution through JSON and copyWith', () {
      const attribution = AudioShareAttribution(
        title: 'My sound',
        creatorName: 'Rabble',
        creatorPubkey: _testPubkey,
        publicTags: ['original'],
        confirmedOwnWork: true,
      );
      final draft = _createDraft().copyWith(
        audioShareAttribution: attribution,
        skipUpdateLastModified: true,
      );

      final copied = draft.copyWith(
        title: 'Changed',
        skipUpdateLastModified: true,
      );
      final restored = DivineVideoDraft.fromJson(draft.toJson(), '/tmp');

      expect(copied.audioShareAttribution, attribution);
      expect(restored.audioShareAttribution, attribution);
    });

    group('copyWith clearSelectedSound', () {
      test('clears selectedSound when clearSelectedSound is true', () {
        final draft = _createDraft();
        expect(draft.selectedSound, isNotNull);

        final cleared = draft.copyWith(
          clearSelectedSound: true,
          skipUpdateLastModified: true,
        );

        expect(cleared.selectedSound, isNull);
      });

      test('preserves selectedSound when clearSelectedSound is false', () {
        final draft = _createDraft();
        final preserved = draft.copyWith(skipUpdateLastModified: true);

        expect(preserved.selectedSound, isNotNull);
        expect(preserved.selectedSound!.id, equals(draft.selectedSound!.id));
      });

      test('replaces selectedSound when new value is provided', () {
        final draft = _createDraft();

        final newSound = AudioEvent(
          id: 'new-sound-1234567890123456789012345678901234567890123456789012',
          pubkey: _testPubkey,
          createdAt: 1700000001,
          url: 'https://blossom.example/new-audio.aac',
          title: 'New Sound',
        );

        final updated = draft.copyWith(
          selectedSound: newSound,
          skipUpdateLastModified: true,
        );

        expect(updated.selectedSound, isNotNull);
        expect(updated.selectedSound!.id, equals(newSound.id));
        expect(updated.selectedSound!.title, equals('New Sound'));
      });

      test('clearSelectedSound takes precedence over new selectedSound', () {
        final draft = _createDraft();

        final newSound = AudioEvent(
          id: 'ignored-id-123456789012345678901234567890123456789012345678901',
          pubkey: _testPubkey,
          createdAt: 1700000001,
        );

        final cleared = draft.copyWith(
          selectedSound: newSound,
          clearSelectedSound: true,
          skipUpdateLastModified: true,
        );

        expect(cleared.selectedSound, isNull);
      });

      test('preserves selectedSound startOffset through copyWith', () {
        final sound = AudioEvent(
          id: 'offset-sound-12345678901234567890123456789012345678901234567',
          pubkey: _testPubkey,
          createdAt: 1700000000,
          url: 'https://blossom.example/audio.aac',
          startOffset: const Duration(milliseconds: 3500),
        );

        final draft = _createDraft(selectedSound: sound);
        final copy = draft.copyWith(
          title: 'Updated Title',
          skipUpdateLastModified: true,
        );

        expect(copy.selectedSound, isNotNull);
        expect(
          copy.selectedSound!.startOffset,
          equals(const Duration(milliseconds: 3500)),
        );
      });
    });

    group('copyWith clearPublishError', () {
      test('clears publishError when clearPublishError is true', () {
        final draft = _createDraft();
        expect(draft.publishError, isNotNull);

        final cleared = draft.copyWith(
          clearPublishError: true,
          skipUpdateLastModified: true,
        );

        expect(cleared.publishError, isNull);
      });

      test('preserves publishError when clearPublishError is false', () {
        final draft = _createDraft();
        final preserved = draft.copyWith(skipUpdateLastModified: true);

        expect(preserved.publishError, equals('some error'));
      });
    });

    group('copyWith clearSourceDraftId', () {
      test('clears sourceDraftId when clearSourceDraftId is true', () {
        final draft = _createDraft().copyWith(
          sourceDraftId: 'draft_source',
          skipUpdateLastModified: true,
        );

        final cleared = draft.copyWith(
          clearSourceDraftId: true,
          skipUpdateLastModified: true,
        );

        expect(cleared.sourceDraftId, isNull);
      });

      test('preserves sourceDraftId when clearSourceDraftId is false', () {
        final draft = _createDraft().copyWith(
          sourceDraftId: 'draft_source',
          skipUpdateLastModified: true,
        );

        final preserved = draft.copyWith(skipUpdateLastModified: true);

        expect(preserved.sourceDraftId, equals('draft_source'));
      });
    });

    group('scheduledAt', () {
      final scheduledAt = DateTime.utc(2026, 10, 1, 9, 30);

      test('round-trips through JSON as UTC', () {
        final draft = _createDraft().copyWith(
          scheduledAt: scheduledAt,
          skipUpdateLastModified: true,
        );

        final json = draft.toJson();
        expect(json['scheduledAt'], '2026-10-01T09:30:00.000Z');

        final restored = DivineVideoDraft.fromJson(json, '/tmp');
        expect(restored.scheduledAt, scheduledAt);
        expect(restored.scheduledAt!.isUtc, isTrue);
      });

      test('is omitted from JSON and null when never set', () {
        final draft = _createDraft();

        expect(draft.scheduledAt, isNull);
        expect(draft.toJson().containsKey('scheduledAt'), isFalse);
        expect(
          DivineVideoDraft.fromJson(draft.toJson(), '/tmp').scheduledAt,
          isNull,
        );
      });

      test('clearScheduledAt drops the time; copyWith otherwise keeps it', () {
        final draft = _createDraft().copyWith(
          scheduledAt: scheduledAt,
          skipUpdateLastModified: true,
        );

        expect(
          draft.copyWith(skipUpdateLastModified: true).scheduledAt,
          scheduledAt,
        );
        expect(
          draft
              .copyWith(clearScheduledAt: true, skipUpdateLastModified: true)
              .scheduledAt,
          isNull,
        );
      });

      test('duplicate starts as an unscheduled draft', () {
        final draft = _createDraft().copyWith(
          scheduledAt: scheduledAt,
          publishStatus: PublishStatus.scheduled,
          skipUpdateLastModified: true,
        );
        expect(draft.isScheduled, isTrue);

        final copy = draft.duplicate();

        expect(copy.scheduledAt, isNull);
        expect(copy.publishStatus, PublishStatus.draft);
        expect(copy.isScheduled, isFalse);
      });
    });

    group('copyWith clearProofManifestJson', () {
      test('clears proofManifestJson when flag is true', () {
        final draft = _createDraft();
        expect(draft.proofManifestJson, isNotNull);

        final cleared = draft.copyWith(
          clearProofManifestJson: true,
          skipUpdateLastModified: true,
        );

        expect(cleared.proofManifestJson, isNull);
      });

      test('preserves proofManifestJson when flag is false', () {
        final draft = _createDraft();
        final preserved = draft.copyWith(skipUpdateLastModified: true);

        expect(preserved.proofManifestJson, equals('{"videoHash":"abc"}'));
      });
    });

    group('toJson selectedSound', () {
      test('includes selectedSound when present', () {
        final draft = _createDraft();
        final json = draft.toJson();

        expect(json.containsKey('selectedSound'), isTrue);
        final soundJson = json['selectedSound'] as Map<String, dynamic>;
        expect(soundJson['id'], equals(draft.selectedSound!.id));
        expect(soundJson['url'], equals('https://blossom.example/audio.aac'));
        expect(soundJson['startOffsetMs'], equals(2000));
      });

      test('omits selectedSound when null', () {
        final draft = _createDraft().copyWith(
          clearSelectedSound: true,
          skipUpdateLastModified: true,
        );
        final json = draft.toJson();

        expect(json.containsKey('selectedSound'), isFalse);
      });
    });

    test('persists sourceDraftId through JSON', () {
      final draft = _createDraft().copyWith(
        sourceDraftId: 'draft_source',
        skipUpdateLastModified: true,
      );

      final json = draft.toJson();
      final restored = DivineVideoDraft.fromJson(json, '/tmp');

      expect(json['sourceDraftId'], equals('draft_source'));
      expect(restored.sourceDraftId, equals('draft_source'));
    });
  });
}
