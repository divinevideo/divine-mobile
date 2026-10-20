import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/loop_suggestion/loop_suggestion_cubit.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_clip_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_layer_multi_select_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_loop_suggestion_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_marker_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_multi_select_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_overlay_controls.dart';

/// Shows context-specific controls at the bottom of the timeline based on
/// what is currently active: marker mode, a multi-select mode, a loop point
/// waiting to be kept, a clip (editing), or a selected overlay item.
class TimelineControlsBar extends StatelessWidget {
  const TimelineControlsBar({
    required this.isEditing,
    required this.playheadPosition,
    this.isMarkerMode = false,
    super.key,
  });

  final bool isEditing;
  final bool isMarkerMode;
  final ValueNotifier<Duration> playheadPosition;

  static const _animationDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final (isMultiSelectMode, isStopMotion) = context.select(
      (ClipEditorBloc b) => (
        b.state.isMultiSelectMode,
        isStopMotionComposition(b.state.clips),
      ),
    );
    final isLayerMultiSelectMode = context.select(
      (TimelineOverlayBloc b) => b.state.isLayerMultiSelectMode,
    );
    final hasLoopSuggestion = context.select(
      (LoopSuggestionCubit c) =>
          c.state.status == LoopSuggestionStatus.suggested,
    );
    final selectedOverlayItem = context.select((TimelineOverlayBloc b) {
      final state = b.state;
      final selectedId = state.selectedItemId;
      if (selectedId == null) return null;
      return state.items.where((i) => i.id == selectedId).firstOrNull;
    });

    final showControls =
        isMarkerMode ||
        isMultiSelectMode ||
        isLayerMultiSelectMode ||
        hasLoopSuggestion ||
        isEditing ||
        selectedOverlayItem != null;
    final controlsChild = switch ((
      isMarkerMode,
      isMultiSelectMode,
      isLayerMultiSelectMode,
      showControls,
      isEditing,
    )) {
      // A loop point shown on the last clip is kept or dropped first.
      _ when hasLoopSuggestion => const TimelineLoopSuggestionControls(
        key: ValueKey('timeline_controls_loop_suggestion'),
      ),
      (true, _, _, _, _) => TimelineMarkerControls(
        key: const ValueKey('timeline_controls_marker'),
        playheadPosition: playheadPosition,
      ),
      // Frame multi-select on a stop-motion composition; clip multi-select
      // everywhere else.
      (false, true, _, _, _) when isStopMotion =>
        const TimelineFrameMultiSelectControls(
          key: ValueKey('timeline_controls_frame_multi_select'),
        ),
      (false, true, _, _, _) => const TimelineMultiSelectControls(
        key: ValueKey('timeline_controls_multi_select'),
      ),
      (false, false, true, _, _) => const TimelineLayerMultiSelectControls(
        key: ValueKey('timeline_controls_layer_multi_select'),
      ),
      (false, false, false, true, true) => TimelineClipControls(
        key: const ValueKey('timeline_controls_clip'),
        playheadPosition: playheadPosition,
      ),
      (false, false, false, true, false) => TimelineOverlayControls(
        key: const ValueKey('timeline_controls_overlay'),
        item: selectedOverlayItem!,
      ),
      (false, false, false, false, _) => const SizedBox(
        key: ValueKey('timeline_controls_hidden'),
        width: double.infinity,
      ),
    };

    return AnimatedSwitcher(
      duration: _animationDuration,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: AlignmentDirectional.topStart,
        child: child,
      ),
      child: controlsChild,
    );
  }
}
