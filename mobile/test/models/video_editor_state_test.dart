// ABOUTME: Unit tests for VideoEditorProviderState model validating state
// ABOUTME: management, copyWith behavior, and computed properties

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_metadata/video_metadata_expiration.dart';

void main() {
  group(VideoEditorProviderState, () {
    test('creates instance with default values', () {
      final state = VideoEditorProviderState();

      expect(state.isProcessing, isFalse);
      expect(state.isSavingDraft, isFalse);
      expect(state.allowAudioReuse, isFalse);
      expect(state.title, isEmpty);
      expect(state.description, isEmpty);
      expect(state.tags, isEmpty);
      expect(state.expiration, equals(VideoMetadataExpiration.notExpire));
      expect(state.metadataLimitReached, isFalse);
      expect(state.finalRenderedClip, isNull);
      expect(state.editorStateHistory, isEmpty);
      expect(state.editorEditingParameters, isNull);
      expect(state.collaboratorPubkeys, isEmpty);
      expect(state.inspiredByVideo, isNull);
      expect(state.inspiredByNpub, isNull);
      expect(state.selectedSound, isNull);
      expect(state.seedSelectedSoundAsAudioTrack, isFalse);
      expect(state.contentWarnings, isEmpty);
      expect(state.proofManifestJson, isNull);
      expect(state.deleteButtonKey, isA<GlobalKey>());
    });

    test('copyWith updates specified fields only', () {
      final initial = VideoEditorProviderState(title: 'Original Title');

      final updated = initial.copyWith(
        isProcessing: true,
        description: 'New description',
      );

      expect(updated.title, equals('Original Title'));
      expect(updated.isProcessing, isTrue);
      expect(updated.description, equals('New description'));
      expect(updated.isSavingDraft, isFalse);
    });

    test('copyWith preserves all fields when none specified', () {
      final state = VideoEditorProviderState(
        isProcessing: true,
        isSavingDraft: true,
        title: 'Test Title',
        description: 'Test Description',
        tags: const {'tag1', 'tag2'},
        metadataLimitReached: true,
        collaboratorPubkeys: const {'pubkey1'},
        contentWarnings: const {ContentLabel.nudity},
      );

      final copied = state.copyWith();

      expect(copied.isProcessing, state.isProcessing);
      expect(copied.isSavingDraft, state.isSavingDraft);
      expect(copied.allowAudioReuse, state.allowAudioReuse);
      expect(copied.title, state.title);
      expect(copied.description, state.description);
      expect(copied.tags, state.tags);
      expect(copied.metadataLimitReached, state.metadataLimitReached);
      expect(copied.collaboratorPubkeys, state.collaboratorPubkeys);
      expect(copied.contentWarnings, state.contentWarnings);
    });

    group('isValidToPost', () {
      test('returns false when isProcessing is true', () {
        final state = VideoEditorProviderState(isProcessing: true);

        expect(state.isValidToPost, isFalse);
      });

      test('returns false when finalRenderedClip is null', () {
        final state = VideoEditorProviderState();

        expect(state.isValidToPost, isFalse);
      });

      test('returns false when metadataLimitReached is true', () {
        final state = VideoEditorProviderState(metadataLimitReached: true);

        expect(state.isValidToPost, isFalse);
      });
    });

    test('copyWith with clearFinalRenderedClip sets clip to null', () {
      final state = VideoEditorProviderState();

      final cleared = state.copyWith(clearFinalRenderedClip: true);

      expect(cleared.finalRenderedClip, isNull);
    });

    test('copyWith with clearInspiredByNpub sets npub to null', () {
      final state = VideoEditorProviderState(
        inspiredByNpubs: const ['npub123'],
      );

      final cleared = state.copyWith(clearInspiredByNpub: true);

      expect(cleared.inspiredByNpub, isNull);
    });

    test('copyWith with clearSelectedSound sets sound to null', () {
      final state = VideoEditorProviderState(
        selectedSound: _sound,
        seedSelectedSoundAsAudioTrack: true,
      );

      final cleared = state.copyWith(clearSelectedSound: true);

      expect(cleared.selectedSound, isNull);
      expect(cleared.seedSelectedSoundAsAudioTrack, isFalse);
    });

    test('copyWith can mark selected sound as recorder audio handoff', () {
      final state = VideoEditorProviderState(selectedSound: _sound);

      final updated = state.copyWith(seedSelectedSoundAsAudioTrack: true);

      expect(updated.selectedSound, _sound);
      expect(updated.seedSelectedSoundAsAudioTrack, isTrue);
    });

    test('thumbnailTimestamp defaults to null', () {
      final state = VideoEditorProviderState();

      expect(state.thumbnailTimestamp, isNull);
    });

    test('copyWith updates thumbnailTimestamp', () {
      final state = VideoEditorProviderState();

      final updated = state.copyWith(
        thumbnailTimestamp: const Duration(seconds: 2),
      );

      expect(updated.thumbnailTimestamp, const Duration(seconds: 2));
    });

    test('thumbnailTimestamp survives clearFinalRenderedClip', () {
      final state = VideoEditorProviderState(
        thumbnailTimestamp: const Duration(seconds: 2),
      );

      final cleared = state.copyWith(clearFinalRenderedClip: true);

      expect(
        cleared.thumbnailTimestamp,
        const Duration(seconds: 2),
        reason:
            'invalidating the rendered clip must not discard the selected '
            'cover position',
      );
    });

    test('copyWith with clearThumbnailTimestamp sets it to null', () {
      final state = VideoEditorProviderState(
        thumbnailTimestamp: const Duration(seconds: 2),
      );

      final cleared = state.copyWith(clearThumbnailTimestamp: true);

      expect(cleared.thumbnailTimestamp, isNull);
    });

    test('customThumbnailPath defaults to null', () {
      final state = VideoEditorProviderState();

      expect(state.customThumbnailPath, isNull);
    });

    test('customThumbnailPath survives clearFinalRenderedClip', () {
      final state = VideoEditorProviderState(
        customThumbnailPath: '/docs/cover.jpg',
      );

      final cleared = state.copyWith(clearFinalRenderedClip: true);

      expect(
        cleared.customThumbnailPath,
        '/docs/cover.jpg',
        reason:
            'invalidating the rendered clip must not discard the selected '
            'cover image path',
      );
    });

    test('copyWith with clearCustomThumbnailPath sets it to null', () {
      final state = VideoEditorProviderState(
        customThumbnailPath: '/docs/cover.jpg',
      );

      final cleared = state.copyWith(clearCustomThumbnailPath: true);

      expect(cleared.customThumbnailPath, isNull);
    });
  });
}

final _sound = AudioEvent(
  id: 'sound-id',
  pubkey: 'pubkey',
  createdAt: 1704067200,
  url: 'https://example.com/sound.mp3',
  duration: 5,
);
