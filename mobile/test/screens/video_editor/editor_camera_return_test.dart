// ABOUTME: Tests settling the camera's clips on return to the editor, including
// ABOUTME: an editor left while that cleanup is still running.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/screens/video_editor/editor_camera_return.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

/// Removes clips only once [removalGate] completes, as the real removal
/// awaits autosave and file cleanup.
class _ClipManager extends ClipManagerNotifier {
  _ClipManager(this._initialClips);

  final List<DivineVideoClip> _initialClips;
  final removedIds = <String>[];
  Completer<void>? removalGate;

  @override
  ClipManagerState build() => ClipManagerState(clips: _initialClips);

  @override
  List<DivineVideoClip> get clips => state.clips;

  @override
  Future<bool> removeClipById(String clipId) async {
    await removalGate?.future;
    removedIds.add(clipId);
    state = state.copyWith(
      clips: [
        for (final clip in state.clips)
          if (clip.id != clipId) clip,
      ],
    );
    return true;
  }
}

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file(''),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.vertical,
  originalAspectRatio: 9 / 16,
);

void main() {
  group('settleEditorCameraReturn', () {
    final kept = _clip('kept');
    final take = _clip('take');

    late _ClipManager clipManager;
    late ProviderContainer container;
    late _MockClipEditorBloc clipEditorBloc;
    late BuildContext editorContext;
    late WidgetRef editorRef;

    setUpAll(() {
      registerFallbackValue(const ClipEditorInitialized([]));
    });

    setUp(() {
      clipManager = _ClipManager([kept, take]);
      container = ProviderContainer(
        overrides: [clipManagerProvider.overrideWith(() => clipManager)],
      );
      clipEditorBloc = _MockClipEditorBloc();
      when(() => clipEditorBloc.state)
          .thenReturn(ClipEditorState(clips: [kept]));
    });

    tearDown(() => container.dispose());

    Future<void> pumpEditor(WidgetTester tester) => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            editorContext = context;
            editorRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );

    Future<void> settleCancelledCamera() => settleEditorCameraReturn(
      editorContext,
      editorRef,
      recorded: false,
      initialIds: {kept.id},
      stopMotionTarget: null,
      playhead: Duration.zero,
      clipEditorBloc: clipEditorBloc,
      editor: () => null,
    );

    testWidgets('removes a cancelled take and syncs the editor', (
      tester,
    ) async {
      await pumpEditor(tester);

      await settleCancelledCamera();

      expect(clipManager.removedIds, equals([take.id]));
      verify(() => clipEditorBloc.add(ClipEditorInitialized([kept]))).called(1);
    });

    testWidgets('finishes removing the take but leaves a closed editor alone', (
      tester,
    ) async {
      final removalGate = Completer<void>();
      clipManager.removalGate = removalGate;
      await pumpEditor(tester);

      final settled = settleCancelledCamera();
      // Leaving the editor while the take is still being removed disposes
      // its `ref`; a read through it throws.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox(),
        ),
      );
      removalGate.complete();
      await settled;

      expect(clipManager.removedIds, equals([take.id]));
      verifyNever(() => clipEditorBloc.add(any()));
    });
  });
}
