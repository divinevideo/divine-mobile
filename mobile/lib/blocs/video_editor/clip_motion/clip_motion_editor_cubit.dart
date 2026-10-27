// ABOUTME: Sets the keyframes that pan, zoom and turn one timeline clip, as
// ABOUTME: its motion editor changes them, before they are written to the clip.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/clip_keyframes.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show AnimationCurve, SegmentKeyframe;

part 'clip_motion_editor_state.dart';

/// The motion editor of one timeline clip.
///
/// Every time it is handed is a timestamp in the clip's file, the frame the
/// playhead shows, so a keyframe stays on the frame it was set on.
class ClipMotionEditorCubit extends Cubit<ClipMotionEditorState> {
  /// Creates the editor for [clip], starting from its keyframes.
  ClipMotionEditorCubit({required DivineVideoClip clip})
    : super(ClipMotionEditorState(keyframes: clip.keyframes));

  static const Duration _tolerance = VideoEditorConstants.keyframeTolerance;

  /// Adds a keyframe at [time] holding what the picture shows there, or
  /// removes the one there.
  void toggleKeyframeAt(Duration time) => emit(
    state.copyWith(
      keyframes: state.keyframes.toggledAt(time, tolerance: _tolerance),
    ),
  );

  /// Places the picture at [motion] in the keyframe at [time], which is
  /// added when there is none: moving the picture is what sets a keyframe.
  void moveAt(Duration time, ClipMotion motion) => emit(
    state.copyWith(
      keyframes: state.keyframes.withMotionAt(
        time,
        motion,
        tolerance: _tolerance,
      ),
    ),
  );

  /// Eases the motion at [time] along [curve].
  void setCurveAt(Duration time, AnimationCurve curve) => emit(
    state.copyWith(
      keyframes: state.keyframes.withCurveAt(
        time,
        curve,
        tolerance: _tolerance,
      ),
    ),
  );

  /// Takes every keyframe off, so the clip keeps still.
  void reset() => emit(state.copyWith(keyframes: const []));
}
