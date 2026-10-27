import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/clip_motion/clip_motion_editor_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _clip({
  List<SegmentKeyframe> keyframes = const [],
  Duration duration = const Duration(seconds: 4),
  double? playbackSpeed,
}) => DivineVideoClip(
  id: 'clip',
  video: EditorVideo.file('/tmp/clip.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.vertical,
  originalAspectRatio: 9 / 16,
  playbackSpeed: playbackSpeed,
  keyframes: keyframes,
);

void main() {
  group(ClipMotionEditorCubit, () {
    const second = Duration(seconds: 1);
    const zoomed = (offset: Offset(0.1, 0), scale: 1.5, rotation: 0.0);

    test('starts from the clip keyframes', () {
      const keyframes = [SegmentKeyframe(time: second, scale: 2)];

      expect(
        ClipMotionEditorCubit(clip: _clip(keyframes: keyframes)).state,
        const ClipMotionEditorState(keyframes: keyframes),
      );
    });

    group('moveAt', () {
      blocTest<ClipMotionEditorCubit, ClipMotionEditorState>(
        'adds the keyframe at the playhead that moving the picture sets',
        build: () => ClipMotionEditorCubit(clip: _clip()),
        act: (cubit) => cubit.moveAt(second, zoomed),
        expect: () => [
          const ClipMotionEditorState(
            keyframes: [
              SegmentKeyframe(time: second, offset: Offset(0.1, 0), scale: 1.5),
            ],
          ),
        ],
      );
    });

    group('toggleKeyframeAt', () {
      blocTest<ClipMotionEditorCubit, ClipMotionEditorState>(
        'removes the keyframe at the playhead',
        build: () => ClipMotionEditorCubit(
          clip: _clip(keyframes: const [SegmentKeyframe(time: second)]),
        ),
        act: (cubit) => cubit.toggleKeyframeAt(second),
        expect: () => [const ClipMotionEditorState(keyframes: [])],
      );
    });

    group('setCurveAt', () {
      blocTest<ClipMotionEditorCubit, ClipMotionEditorState>(
        'eases the motion the playhead is in',
        build: () => ClipMotionEditorCubit(
          clip: _clip(
            keyframes: const [
              SegmentKeyframe(time: Duration.zero),
              SegmentKeyframe(time: second, scale: 2),
            ],
          ),
        ),
        act: (cubit) => cubit.setCurveAt(
          const Duration(milliseconds: 500),
          AnimationCurve.easeOutCubic,
        ),
        verify: (cubit) => expect(
          cubit.state.keyframes.first.curve,
          AnimationCurve.easeOutCubic,
        ),
      );
    });

    group('reset', () {
      blocTest<ClipMotionEditorCubit, ClipMotionEditorState>(
        'takes every keyframe off',
        build: () => ClipMotionEditorCubit(
          clip: _clip(keyframes: const [SegmentKeyframe(time: second)]),
        ),
        act: (cubit) => cubit.reset(),
        expect: () => [const ClipMotionEditorState(keyframes: [])],
      );
    });
  });
}
