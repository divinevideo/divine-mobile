// ABOUTME: Tests for putting the clip a split-screen layout was rendered into
// ABOUTME: on the timeline at the seam nearest the playhead

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

DivineVideoClip _clip(String id, {double originalAspectRatio = 9 / 16}) =>
    DivineVideoClip(
      id: id,
      video: EditorVideo.file('/documents/$id.mp4'),
      duration: const Duration(seconds: 2),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: originalAspectRatio,
    );

void main() {
  group('$ClipEditorBloc split-screen layout', () {
    ClipEditorBloc seeded(List<DivineVideoClip> clips) {
      final bloc = ClipEditorBloc(
        onFinalClipInvalidated: () {},
        saveClipToLibrary: ({required clip}) async => false,
      );
      addTearDown(bloc.close);
      return bloc..add(ClipEditorInitialized(clips));
    }

    test('joins after the clip the playhead is in, never cutting it', () async {
      final bloc = seeded([_clip('a'), _clip('b')]);
      await bloc.stream.first;

      bloc.add(
        ClipEditorSplitScreenLayoutInserted(
          clip: _clip('layout'),
          playhead: const Duration(milliseconds: 500),
        ),
      );
      final state = await bloc.stream.first;

      expect(state.clips.map((c) => c.id), ['a', 'layout', 'b']);
      final result = state.lastSplitScreenLayoutResult!;
      expect(result.previousClips.map((c) => c.id), ['a', 'b']);
      expect(result.clipId, 'layout');
    });

    test(
      'keeps the canvas coordinates when it becomes the first clip',
      () async {
        // The first clip's ratio is the canvas coordinate system: a layout
        // that took over with its own would shift every layer already placed.
        final bloc = seeded([_clip('a', originalAspectRatio: 3 / 4)]);
        await bloc.stream.first;

        bloc.add(
          ClipEditorSplitScreenLayoutInserted(
            clip: _clip('layout'),
            playhead: Duration.zero,
          ),
        );
        final state = await bloc.stream.first;

        final layout = state.clips.first;
        expect(layout.id, 'layout');
        expect(layout.originalAspectRatio, 3 / 4);
        expect(layout.videoAspectRatio, 9 / 16);
      },
    );
  });
}
