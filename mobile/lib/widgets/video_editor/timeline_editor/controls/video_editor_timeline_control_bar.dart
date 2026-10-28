import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_clip_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_editing_tools_bar.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_layer_multi_select_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_marker_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_multi_select_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_overlay_controls.dart';

/// Shows context-specific controls at the bottom of the timeline based on
/// what is currently active: marker mode, a multi-select mode, a clip
/// (editing), or a selected overlay item. With none of them, it shows the
/// editing tools bar when [showEditingTools] allows it.
class TimelineControlsBar extends StatelessWidget {
  const TimelineControlsBar({
    required this.isEditing,
    required this.playheadPosition,
    this.isMarkerMode = false,
    this.showEditingTools = false,
    super.key,
  });

  final bool isEditing;
  final bool isMarkerMode;
  final ValueNotifier<Duration> playheadPosition;

  /// Whether the editing tools bar may fill the slot while no
  /// context-specific controls do.
  final bool showEditingTools;

  static const _animationDuration = Duration(milliseconds: 200);
  static final Tween<Offset> _riseTween = Tween(
    begin: const Offset(0, 0.2),
    end: Offset.zero,
  );

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
        isEditing ||
        selectedOverlayItem != null;
    final controlsChild = switch ((
      isMarkerMode,
      isMultiSelectMode,
      isLayerMultiSelectMode,
      showControls,
      isEditing,
    )) {
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
      (false, false, false, false, _) when showEditingTools =>
        const TimelineEditingToolsBar(
          key: ValueKey('timeline_controls_editing_tools'),
        ),
      (false, false, false, false, _) => const SizedBox(
        key: ValueKey('timeline_controls_hidden'),
        width: double.infinity,
      ),
    };

    return AnimatedSwitcher(
      duration: _animationDuration,
      // Bottom-anchored, so a short control and a tall one swap in place
      // instead of the short one floating up to the tall one's middle.
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.bottomCenter,
        children: [...previousChildren, ?currentChild],
      ),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      // A short rise instead of growing from the screen edge, which would
      // carry the controls up through the system navigation bar.
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: _riseTween.animate(animation),
          child: child,
        ),
      ),
      child: controlsChild,
    );
  }
}
