import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;

DivineVideoClip _clip(
  String id, {
  bool isFreezeFrame = false,
  ClipChromaKey? captureChromaKey,
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 1),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  isFreezeFrame: isFreezeFrame,
  captureChromaKey: captureChromaKey,
);

void main() {
  group('ClipEditorState.hasPendingClipOperation', () {
    const idle = ClipEditorState();

    test('is false without a pending operation', () {
      expect(idle.hasPendingClipOperation, isFalse);
    });

    final operations = {
      'audio extraction': idle.copyWith(isExtractingAudio: true),
      'split': idle.copyWith(isSplitting: true),
      'reverse': idle.copyWith(isReversing: true),
      'stabilization': idle.copyWith(isStabilizing: true),
      'boomerang': idle.copyWith(isBoomeranging: true),
      'transform': idle.copyWith(isTransforming: true),
      'chroma key': idle.copyWith(isChromaKeying: true),
      'captured chroma key bake': idle.copyWith(
        isBakingCapturedChromaKeys: true,
      ),
      'merge': idle.copyWith(isMerging: true),
      'library save': idle.copyWith(isSavingClipToLibrary: true),
      'detach': idle.copyWith(isDetaching: true),
      'placeholder refill': idle.copyWith(isRefillingPlaceholder: true),
      'freeze frame': idle.copyWith(isFreezingFrame: true),
      'library import': idle.copyWith(isImportingLibraryClips: true),
    };
    for (final operation in operations.entries) {
      test('detects ${operation.key}', () {
        expect(operation.value.hasPendingClipOperation, isTrue);
      });
    }
  });

  group('ClipEditorState.canBoomerangSelection', () {
    final clips = [
      _clip('a'),
      _clip('b', isFreezeFrame: true),
      _clip('c'),
      _clip(
        'd',
        captureChromaKey: const ClipChromaKey(
          key: ChromaKey.greenScreen(backgroundColor: Color(0xFF203040)),
        ),
      ),
    ];

    ClipEditorState selecting(Set<String> ids) =>
        ClipEditorState(clips: clips, selectedClipIds: ids);

    test('is true for neighbouring clips', () {
      expect(selecting({'a', 'b'}).canBoomerangSelection, isTrue);
    });

    test('is false for clips with a gap between them', () {
      expect(selecting({'a', 'c'}).canBoomerangSelection, isFalse);
    });

    test('is false without a selection', () {
      expect(selecting(const {}).canBoomerangSelection, isFalse);
    });

    test('is false for a still picked on its own', () {
      expect(selecting({'a'}).canBoomerangSelection, isTrue);
      expect(selecting({'b'}).canBoomerangSelection, isFalse);
    });

    test('is false while a picked clip waits for its recorded key', () {
      // The bounce or the merge before it would land on the raw take.
      expect(selecting({'d'}).canBoomerangSelection, isFalse);
      expect(selecting({'c', 'd'}).canBoomerangSelection, isFalse);
    });
  });
}
