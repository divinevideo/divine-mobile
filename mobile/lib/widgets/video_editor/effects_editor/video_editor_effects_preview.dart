// ABOUTME: Shows the editor's video effects (glitch, VHS, pixelate) over the
// ABOUTME: canvas video, frame for frame what the export renders.

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show VideoEffectPreview;

/// Applies the effects [VideoEditorEffectsCubit] previews to [child], the
/// canvas frame.
///
/// Effects are timed on the exported video, which an overlap transition makes
/// shorter than the editor timeline, so the playhead and every effect's window
/// are mapped onto the output the same way the export maps them. Without that
/// the glitch bursts and effect edges would drift from the file after every
/// overlap.
class VideoEditorEffectsPreview extends StatefulWidget {
  const VideoEditorEffectsPreview({required this.child, super.key});

  final Widget child;

  @override
  State<VideoEditorEffectsPreview> createState() =>
      _VideoEditorEffectsPreviewState();
}

class _VideoEditorEffectsPreviewState extends State<VideoEditorEffectsPreview> {
  final _outputPosition = ValueNotifier<Duration>(Duration.zero);
  ValueListenable<Duration>? _playTime;
  TransitionTimelineMap? _timelineMap;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final playTime = VideoEditorScope.of(context).playTimeNotifier;
    if (!identical(playTime, _playTime)) {
      _playTime?.removeListener(_onPlayTime);
      _playTime = playTime..addListener(_onPlayTime);
      _onPlayTime();
    }
  }

  @override
  void dispose() {
    _playTime?.removeListener(_onPlayTime);
    _outputPosition.dispose();
    super.dispose();
  }

  void _onPlayTime() {
    final position = _playTime?.value ?? Duration.zero;
    _outputPosition.value = _timelineMap?.editorToOutput(position) ?? position;
  }

  @override
  Widget build(BuildContext context) {
    final effects = context.select(
      (VideoEditorEffectsCubit c) => c.state.previewEffects,
    );
    final clips = context.select((ClipEditorBloc b) => b.state.clips);
    final timelineMap = _timelineMap = TransitionTimelineMap.fromClips(clips);
    _onPlayTime();
    return VideoEffectPreview(
      effects: videoEffectsOnOutput(effects, timelineMap),
      position: _outputPosition,
      child: widget.child,
    );
  }
}
