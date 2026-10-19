import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';

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
}
