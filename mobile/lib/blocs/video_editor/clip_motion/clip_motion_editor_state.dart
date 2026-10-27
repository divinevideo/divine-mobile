part of 'clip_motion_editor_cubit.dart';

/// The keyframes a timeline clip's motion editor is setting.
class ClipMotionEditorState extends Equatable {
  /// Creates a [ClipMotionEditorState].
  const ClipMotionEditorState({required this.keyframes});

  /// The clip's keyframes as edited so far, sorted by time.
  final List<SegmentKeyframe> keyframes;

  /// Creates a copy with the given fields replaced.
  ClipMotionEditorState copyWith({List<SegmentKeyframe>? keyframes}) =>
      ClipMotionEditorState(keyframes: keyframes ?? this.keyframes);

  @override
  List<Object?> get props => [keyframes];
}
