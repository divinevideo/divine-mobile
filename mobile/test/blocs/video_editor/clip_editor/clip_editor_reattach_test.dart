// ABOUTME: Tests for putting a detached clip back onto the timeline — into
// ABOUTME: its placeholder's slot, or at the playhead once that is gone

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

DivineVideoClip _clip(
  String id, {
  Duration duration = const Duration(seconds: 2),
  double originalAspectRatio = 9 / 16,
  bool isPlaceholder = false,
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: originalAspectRatio,
  isPlaceholder: isPlaceholder,
);

void main() {
  group('$ClipEditorBloc reattach', () {
    ClipEditorBloc seeded(
      List<DivineVideoClip> clips, {
      MeasureAspectRatioFn? measureAspectRatio,
    }) {
      final bloc = ClipEditorBloc(
        onFinalClipInvalidated: () {},
        saveClipToLibrary: ({required clip}) async => false,
        measureAspectRatio: measureAspectRatio ?? (_) async => 9 / 16,
      );
      addTearDown(bloc.close);
      return bloc..add(ClipEditorInitialized(clips));
    }

    test('takes the slot its placeholder still holds', () async {
      final bloc = seeded([
        _clip('a'),
        _clip('placeholder_1', isPlaceholder: true),
        _clip('c'),
      ]);
      await bloc.stream.first;

      bloc.add(
        ClipEditorDetachedClipReattachRequested(
          layerId: 'detached_b',
          clip: _clip('b'),
          // The playhead points elsewhere; the slot wins.
          playhead: Duration.zero,
          placeholderClipId: 'placeholder_1',
        ),
      );
      final state = await bloc.stream.first;

      expect(state.clips.map((c) => c.id), ['a', 'b', 'c']);
      final result = state.lastDetachedClipReattachResult!;
      // The widget layer removes this layer and rebases markers against the
      // list as it was.
      expect(result.layerId, 'detached_b');
      expect(result.previousClips.map((c) => c.id), [
        'a',
        'placeholder_1',
        'c',
      ]);
    });

    test('joins at the playhead once its placeholder is gone', () async {
      final bloc = seeded([_clip('a'), _clip('c')]);
      await bloc.stream.first;

      bloc.add(
        ClipEditorDetachedClipReattachRequested(
          layerId: 'detached_b',
          clip: _clip('b'),
          playhead: const Duration(seconds: 3),
          placeholderClipId: 'placeholder_1',
        ),
      );
      final state = await bloc.stream.first;

      // The playhead sits inside `c`, so the clip goes in right after it.
      expect(state.clips.map((c) => c.id), ['a', 'c', 'b']);
      expect(state.currentClipIndex, 2);
    });

    test('brings back only the stretch its layer showed', () async {
      final bloc = seeded([_clip('a')]);
      await bloc.stream.first;

      bloc.add(
        ClipEditorDetachedClipReattachRequested(
          layerId: 'detached_b',
          clip: _clip('b', duration: const Duration(seconds: 4)),
          playhead: const Duration(seconds: 2),
          sourceOffset: const Duration(seconds: 1),
          window: const Duration(seconds: 2),
        ),
      );
      final state = await bloc.stream.first;

      final clip = state.clips.last;
      expect(clip.trimStart, const Duration(seconds: 1));
      expect(clip.playbackDuration, const Duration(seconds: 2));
    });

    test('fits its frames by the shape the file has now', () async {
      final bloc = seeded([
        _clip('a'),
      ], measureAspectRatio: (_) async => 1);
      await bloc.stream.first;

      bloc.add(
        ClipEditorDetachedClipReattachRequested(
          layerId: 'detached_b',
          clip: _clip('b'),
          playhead: const Duration(seconds: 2),
        ),
      );
      final state = await bloc.stream.first;

      // Cropped square on the canvas: the preview has to cover the frame with
      // square frames, not stretch them to the recording's 9:16.
      expect(state.clips.last.videoAspectRatio, 1);
    });

    test('keeps the canvas shape when it lands in front', () async {
      final bloc = seeded([
        _clip('placeholder_1', isPlaceholder: true),
        _clip('c'),
      ]);
      await bloc.stream.first;

      bloc.add(
        ClipEditorDetachedClipReattachRequested(
          layerId: 'detached_b',
          // A canvas crop rewrote this clip's ratio to its own square shape.
          clip: _clip('b', originalAspectRatio: 1),
          playhead: Duration.zero,
          placeholderClipId: 'placeholder_1',
        ),
      );
      final state = await bloc.stream.first;

      // The first clip's ratio is the canvas coordinate system; taking the
      // square one would move every other layer.
      expect(state.clips.first.id, 'b');
      expect(state.clips.first.originalAspectRatio, 9 / 16);
    });

    test('gives a second copy of the same clip its own id', () async {
      final bloc = seeded([_clip('a'), _clip('b')]);
      await bloc.stream.first;

      bloc.add(
        ClipEditorDetachedClipReattachRequested(
          layerId: 'detached_b_copy',
          // A duplicated layer carries the id of the clip already back.
          clip: _clip('b'),
          playhead: const Duration(seconds: 4),
        ),
      );
      final state = await bloc.stream.first;

      expect(state.clips, hasLength(3));
      expect(state.clips.map((c) => c.id).toSet(), hasLength(3));
    });
  });
}
