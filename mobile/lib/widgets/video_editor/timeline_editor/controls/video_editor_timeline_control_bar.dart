import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_clip_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_editing_tools_bar.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_layer_multi_select_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_marker_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_multi_select_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_overlay_controls.dart';

/// The context-specific controls [TimelineControlsBar] can show.
enum _TimelineControls { marker, multiSelect, layerMultiSelect, clip, overlay }

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

  /// Closes the context-specific controls the bar is showing, as their Done
  /// button does, and returns whether it was showing any.
  ///
  /// Lets Android's system back close those controls instead of the editor.
  /// It picks them the way [build] does, so it closes the ones on screen.
  /// Reads [VideoEditorMainBloc], [ClipEditorBloc] and [TimelineOverlayBloc]
  /// from [context], so all three must be provided above it.
  static bool dismissControls(BuildContext context) {
    final mainBloc = context.read<VideoEditorMainBloc>();
    final clipBloc = context.read<ClipEditorBloc>();
    final overlayBloc = context.read<TimelineOverlayBloc>();

    switch (_controlsFor(
      isMarkerMode: mainBloc.state.isMarkerMode,
      isMultiSelectMode: clipBloc.state.isMultiSelectMode,
      isLayerMultiSelectMode: overlayBloc.state.isLayerMultiSelectMode,
      isEditing: clipBloc.state.isEditing,
      hasSelectedItem: _selectedItem(overlayBloc.state) != null,
    )) {
      case _TimelineControls.marker:
        mainBloc.add(const VideoEditorMarkerModeChanged(isActive: false));
      case _TimelineControls.multiSelect:
        clipBloc.add(const ClipEditorMultiSelectCancelled());
      case _TimelineControls.layerMultiSelect:
        overlayBloc.add(const TimelineOverlayLayerMultiSelectCancelled());
      case _TimelineControls.clip:
        clipBloc.add(const ClipEditorEditingStopped());
      case _TimelineControls.overlay:
        overlayBloc.add(const TimelineOverlayItemSelected(null));
      case null:
        return false;
    }
    return true;
  }

  /// The controls to show, or `null` when none apply. The first active mode
  /// wins, so [build] and [dismissControls] agree on which one is on screen.
  static _TimelineControls? _controlsFor({
    required bool isMarkerMode,
    required bool isMultiSelectMode,
    required bool isLayerMultiSelectMode,
    required bool isEditing,
    required bool hasSelectedItem,
  }) {
    if (isMarkerMode) return _TimelineControls.marker;
    if (isMultiSelectMode) return _TimelineControls.multiSelect;
    if (isLayerMultiSelectMode) return _TimelineControls.layerMultiSelect;
    if (isEditing) return _TimelineControls.clip;
    if (hasSelectedItem) return _TimelineControls.overlay;
    return null;
  }

  /// The selected overlay item, or `null` when nothing is selected or the
  /// selected id names no item.
  static TimelineOverlayItem? _selectedItem(TimelineOverlayState state) {
    final selectedId = state.selectedItemId;
    if (selectedId == null) return null;
    return state.items.where((i) => i.id == selectedId).firstOrNull;
  }

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
    final selectedOverlayItem = context.select(
      (TimelineOverlayBloc b) => _selectedItem(b.state),
    );

    final controlsChild = switch (_controlsFor(
      isMarkerMode: isMarkerMode,
      isMultiSelectMode: isMultiSelectMode,
      isLayerMultiSelectMode: isLayerMultiSelectMode,
      isEditing: isEditing,
      hasSelectedItem: selectedOverlayItem != null,
    )) {
      _TimelineControls.marker => TimelineMarkerControls(
        key: const ValueKey('timeline_controls_marker'),
        playheadPosition: playheadPosition,
      ),
      // Frame multi-select on a stop-motion composition; clip multi-select
      // everywhere else.
      _TimelineControls.multiSelect when isStopMotion =>
        const TimelineFrameMultiSelectControls(
          key: ValueKey('timeline_controls_frame_multi_select'),
        ),
      _TimelineControls.multiSelect => const TimelineMultiSelectControls(
        key: ValueKey('timeline_controls_multi_select'),
      ),
      _TimelineControls.layerMultiSelect =>
        const TimelineLayerMultiSelectControls(
          key: ValueKey('timeline_controls_layer_multi_select'),
        ),
      _TimelineControls.clip => TimelineClipControls(
        key: const ValueKey('timeline_controls_clip'),
        playheadPosition: playheadPosition,
      ),
      _TimelineControls.overlay => TimelineOverlayControls(
        key: const ValueKey('timeline_controls_overlay'),
        item: selectedOverlayItem!,
      ),
      null when showEditingTools => const TimelineEditingToolsBar(
        key: ValueKey('timeline_controls_editing_tools'),
      ),
      null => const SizedBox(
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
