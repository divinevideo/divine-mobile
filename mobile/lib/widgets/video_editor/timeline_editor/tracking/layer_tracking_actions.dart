// ABOUTME: Pins a layer to a moving object: frames the object, tracks it, and
// ABOUTME: turns its path into the layer's keyframes as one undo step (#9848).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/layer_tracking/layer_tracking_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/extensions/layer_tracking.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/layer_track_target.dart';
import 'package:openvine/models/video_editor/track_frame_mapping.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/keyframes/layer_keyframe_actions.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/tracking/layer_track_region_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show Layer;
import 'package:pro_video_editor/pro_video_editor.dart' show VideoObjectTrack;

/// Whether [layer] can follow a tracked object: every layer keyframes can
/// move, since the track becomes its keyframes.
bool canTrackLayer(Layer? layer) => canKeyframeLayer(layer);

/// Lets the creator frame the object [layer], selected in the timeline as
/// [item], should follow, then tracks it.
///
/// The object is marked on the frame at the playhead; a playhead outside the
/// layer is moved onto its start first, as the keyframe sheet does, since the
/// layer is not drawn there. The clip under the playhead is the one tracked:
/// a cut to another clip shows something else, so the layer follows the
/// object as far as that clip goes. [LayerTrackingResultListener] pins the
/// layer to the path once the cubit has it.
Future<void> trackLayerObject(
  BuildContext context,
  Layer layer, {
  required TimelineOverlayItem item,
}) async {
  final cubit = context.read<LayerTrackingCubit>();
  if (cubit.state.isTracking) return;
  final scope = VideoEditorScope.of(context);
  final mainBloc = context.read<VideoEditorMainBloc>();

  var time = scope.playTimeNotifier.value;
  if (time < item.startTime || time > item.endTime) {
    time = item.startTime;
    mainBloc.add(VideoEditorSeekRequested(time));
  }
  final target = layerTrackTargetFor(
    clips: context.read<ClipEditorBloc>().state.clips,
    anchor: time,
    layerStart: item.startTime,
    layerEnd: item.endTime,
  );
  if (target == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.videoEditorTrackUnavailable,
      ),
    );
    return;
  }

  final region = await pickLayerTrackRegion(
    context,
    // Read live: the editor rescales every layer as the canvas resizes.
    layerCenter: () => layerPlacementAt(layer, target.anchor).offset,
    videoAspectRatio: target.videoAspectRatio,
    targetAspectRatio: target.targetAspectRatio,
  );
  if (region == null || cubit.isClosed) return;
  await cubit.track(layerId: layer.id, target: target, region: region);
}

/// [layer] pinned to the object [track] followed through [target], or
/// `null` when the track covers too little of the layer's stretch to move
/// it.
///
/// [mapping] places the frame on the canvas as it is laid out now, which is
/// what the layer's own coordinates are measured against.
@visibleForTesting
Layer? layerPinnedToTrack(
  Layer layer, {
  required VideoObjectTrack track,
  required LayerTrackTarget target,
  required TrackFrameMapping mapping,
}) {
  final keyframes = trackedLayerKeyframes(
    layer: layer,
    track: track,
    target: target,
    mapping: mapping,
    placementAt: (time) => layerPlacementAt(layer, time),
  );
  if (keyframes == null) return null;
  return layerWithKeyframes(layer, keyframes);
}

/// Blocks the editor while an object is tracked, with its progress and a
/// way to stop it.
class LayerTrackingProgressOverlay extends StatelessWidget {
  const LayerTrackingProgressOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final tracking = context.select(
      (LayerTrackingCubit cubit) => cubit.state.isTracking,
    );
    if (!tracking) return const SizedBox.shrink();
    return ColoredBox(
      color: context.vineColors.background.withAlpha(210),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 24,
          children: [
            const RepaintBoundary(child: _TrackingSpinner()),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                context.l10n.videoEditorTrackProgressLabel,
                textAlign: TextAlign.center,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
            ),
            DivineButton(
              label: context.l10n.commonCancel,
              type: .secondary,
              size: .small,
              onPressed: () => context.read<LayerTrackingCubit>().cancel(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The share of the clip tracked so far.
class _TrackingSpinner extends StatelessWidget {
  const _TrackingSpinner();

  @override
  Widget build(BuildContext context) {
    final progress = context.select(
      (LayerTrackingCubit cubit) => cubit.state.progress,
    );
    return PartialCircleSpinner(progress: progress);
  }
}

/// Pins the layer to the tracked path once the object was followed, and
/// says so when it could not be, or only part of the way.
///
/// Kept at the scaffold level, always mounted, so the result lands even
/// when the timeline controls changed while tracking ran.
class LayerTrackingResultListener extends StatelessWidget {
  const LayerTrackingResultListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<LayerTrackingCubit, LayerTrackingState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status != LayerTrackingStatus.idle &&
          current.status != LayerTrackingStatus.tracking,
      listener: _onResult,
      child: child,
    );
  }

  void _onResult(BuildContext context, LayerTrackingState state) {
    final l10n = context.l10n;
    final message = switch (state.status) {
      LayerTrackingStatus.followed => _pin(context, state),
      LayerTrackingStatus.notFollowed => l10n.videoEditorTrackNotFollowed,
      LayerTrackingStatus.failed => l10n.videoEditorTrackFailed,
      LayerTrackingStatus.idle || LayerTrackingStatus.tracking => null,
    };
    context.read<LayerTrackingCubit>().resultHandled();
    if (message == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(DivineSnackbarContainer.snackBar(message));
  }

  /// Pins the tracked layer to its path, as one history step, and returns
  /// what to tell the creator about it, if anything.
  String? _pin(BuildContext context, LayerTrackingState state) {
    final l10n = context.l10n;
    final track = state.track;
    final target = state.target;
    final scope = VideoEditorScope.of(context);
    final editor = scope.editor;
    if (track == null || target == null || editor == null || !editor.mounted) {
      return null;
    }
    final index = editor.activeLayers.indexWhere((l) => l.id == state.layerId);
    // The layer was deleted while tracking ran.
    if (index < 0) return null;
    final pinned = layerPinnedToTrack(
      editor.activeLayers[index],
      track: track,
      target: target,
      mapping: TrackFrameMapping(
        canvasSize: scope.canvasGeometry.renderSize,
        videoAspectRatio: target.videoAspectRatio,
        targetAspectRatio: target.targetAspectRatio,
      ),
    );
    if (pinned == null) return l10n.videoEditorTrackNotFollowed;
    editor.replaceLayer(index: index, layer: pinned);
    return track.reachedStart && track.reachedEnd
        ? null
        : l10n.videoEditorTrackLostPartway;
  }
}
