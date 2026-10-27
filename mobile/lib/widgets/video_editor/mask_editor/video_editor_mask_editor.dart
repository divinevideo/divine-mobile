// ABOUTME: Opens the shape mask editor for a layer or a timeline clip and
// ABOUTME: writes the mask it settles on, and a clip's background color, as
// ABOUTME: one undo step.

import 'package:collection/collection.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/clip_mask_window.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/mask_editor/video_editor_mask_editor_view.dart';
import 'package:pro_image_editor/features/main_editor/services/layer_copy_manager.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show Layer, LayerMask, ProImageEditorState;

/// Opens the mask editor for [layer], selected in the timeline as [item].
///
/// A playhead outside the layer is moved onto its start first: the layer is
/// not drawn there, so there would be nothing to shape. Every change shows on
/// the canvas without a history step of its own, and the mask confirmed is
/// written as one, so cancelling puts the layer back as it was.
Future<void> editLayerMask(
  BuildContext context,
  Layer layer, {
  required TimelineOverlayItem item,
}) async {
  final scope = VideoEditorScope.of(context);
  final editor = scope.editor;
  if (editor == null) return;
  final mainBloc = context.read<VideoEditorMainBloc>();

  var time = scope.playTimeNotifier.value;
  if (time < item.startTime || time > item.endTime) {
    time = item.startTime;
    mainBloc.add(VideoEditorSeekRequested(time));
  }

  void show(LayerMask? mask) => _replaceLayer(
    editor,
    layer.id,
    (live) => layerWithMask(live, mask),
    skipUpdateHistory: true,
  );

  final result = await _runMaskEditor(
    context,
    initialMask: layer.mask,
    // Mask keyframes count from the layer's start, as its own do.
    keyframeTime: time - layer.keyframeOrigin,
    resolveGeometry: () => _layerGeometry(editor, layer.id),
    onChanged: (result) => show(result.mask),
  );

  // The previews changed the layer in place of the current history step; it
  // is put back first so the step records the change.
  _replaceLayer(editor, layer.id, (_) => layer, skipUpdateHistory: true);
  if (result == null || result.mask == layer.mask) return;
  _replaceLayer(editor, layer.id, (live) => layerWithMask(live, result.mask));
}

/// Opens the mask editor for the timeline clip [clipId].
///
/// A playhead outside the clip is moved into its middle first, where neither
/// neighbour's transition blends into it. The mask and the color it covers
/// the rest of the frame with preview through
/// [VideoEditorScope.liveClipMaskNotifier] and are written to the clip, as
/// one history step, only when they are confirmed.
Future<void> editClipMask(BuildContext context, String clipId) async {
  final scope = VideoEditorScope.of(context);
  final editor = scope.editor;
  if (editor == null) return;
  final clipBloc = context.read<ClipEditorBloc>();
  final mainBloc = context.read<VideoEditorMainBloc>();

  final clips = clipBloc.state.clips;
  final index = clips.indexWhere((clip) => clip.id == clipId);
  if (index < 0) return;
  final clip = clips[index];
  var clipStart = Duration.zero;
  for (final previous in clips.take(index)) {
    clipStart += previous.playbackDuration;
  }
  final clipEnd = clipStart + clip.playbackDuration;
  var time = scope.playTimeNotifier.value;
  if (time < clipStart || time >= clipEnd) {
    time = clipStart + clip.playbackDuration ~/ 2;
    mainBloc.add(VideoEditorSeekRequested(time));
  }

  final live = scope.liveClipMaskNotifier;
  final result = await _runMaskEditor(
    context,
    initialMask: clip.mask,
    // A clip's mask keyframes count from the clip's start on the timeline.
    keyframeTime: time - clipStart,
    initialBackgroundColor:
        clip.maskBackgroundColor ?? defaultClipMaskBackgroundColor,
    resolveGeometry: () => _boxGeometry(scope.clipFrameTracker?.box),
    onChanged: (result) => live?.value = (
      clipId: clipId,
      mask: result.mask,
      backgroundColor: result.backgroundColor,
    ),
  );
  // The notifier goes with the editor, which can be torn down meanwhile.
  if (!editor.mounted) return;
  live?.value = null;

  // Re-read after the editor closed, as the speed sheet does: the clip list
  // may have changed meanwhile.
  if (result == null || clipBloc.isClosed) return;
  final currentClips = clipBloc.state.clips;
  final currentIndex = currentClips.indexWhere((c) => c.id == clipId);
  if (currentIndex < 0) return;
  final current = currentClips[currentIndex];
  // Black is what a clip shows without a color of its own, and a clip without
  // a mask covers nothing, so neither keeps one.
  final color =
      result.mask == null ||
          result.backgroundColor == defaultClipMaskBackgroundColor
      ? null
      : result.backgroundColor;
  if (result.mask == current.mask && color == current.maskBackgroundColor) {
    return;
  }

  final updated = current.copyWith(
    mask: result.mask,
    clearMask: result.mask == null,
    maskBackgroundColor: color,
    clearMaskBackgroundColor: color == null,
  );
  final newClips = List.of(currentClips)..[currentIndex] = updated;
  clipBloc.add(ClipEditorClipUpdated(clipId: clipId, clip: updated));
  editor.setClipState(newClips);
}

/// Hands the screen to the mask editor and returns what it closed with, or
/// `null` when it was cancelled.
///
/// [initialBackgroundColor] is the color the item is covered with around the
/// shape, `null` for an item without one to pick.
///
/// The editor gives up the screen meanwhile — timeline and actions step aside
/// so the video is as large as it gets — and playback pauses so the frame
/// holds still, resuming afterwards only if it was running.
Future<MaskEditorResult?> _runMaskEditor(
  BuildContext context, {
  required LayerMask? initialMask,
  required Duration keyframeTime,
  required MaskTargetGeometry? Function() resolveGeometry,
  required ValueChanged<MaskEditorResult> onChanged,
  Color? initialBackgroundColor,
}) async {
  final scope = VideoEditorScope.of(context);
  final mainBloc = context.read<VideoEditorMainBloc>();
  final wasPlaying = mainBloc.state.isPlaying;
  if (wasPlaying) {
    mainBloc.add(const VideoEditorExternalPauseRequested(isPaused: true));
  }
  // Set before the editor makes room for the panel, so it makes as much as
  // the panel takes from the start.
  final panelHeight = scope.maskPanelHeightNotifier;
  final withBackground = initialBackgroundColor != null;
  panelHeight?.value = videoEditorMaskPanelHeight(
    initialMask,
    withBackground: withBackground,
  );
  mainBloc.add(const VideoEditorMaskEditingChanged(isEditing: true));

  // The canvas resizes as the timeline collapses, and the editor rescales
  // every layer with it, so the editor follows both rather than measuring
  // once.
  final canvasChanges = Listenable.merge([
    scope.bodySizeNotifier,
    scope.zoomMatrixNotifier,
  ]);

  final result = await Navigator.of(context).push<MaskEditorResult>(
    PageRouteBuilder<MaskEditorResult>(
      opaque: false,
      barrierColor: VineTheme.transparent,
      settings: const RouteSettings(name: 'video_editor_mask_editor'),
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => VideoEditorMaskEditorView(
        initialMask: initialMask,
        keyframeTime: keyframeTime,
        initialBackgroundColor: initialBackgroundColor,
        resolveGeometry: resolveGeometry,
        canvasChanges: canvasChanges,
        onChanged: (result) {
          // The panel grows or shrinks with the settings the mask brings, and
          // the canvas with it.
          panelHeight?.value = videoEditorMaskPanelHeight(
            result.mask,
            withBackground: withBackground,
          );
          onChanged(result);
        },
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  // Guarded on the bloc rather than on `context.mounted`, as the slide point
  // picker does: the editor giving up the screen is exactly what this
  // restores, so it must run even if the widget that opened the mask editor
  // went away meanwhile.
  if (!mainBloc.isClosed) {
    mainBloc.add(const VideoEditorMaskEditingChanged(isEditing: false));
    if (wasPlaying) {
      mainBloc.add(const VideoEditorExternalPauseRequested(isPaused: false));
    }
  }
  return result;
}

/// A copy of [layer] showing [mask], `null` for none.
///
/// The copy keeps the widget keys of [layer], so the canvas updates the layer
/// it shows instead of building a new one: a detached clip would otherwise
/// start its player over on every change of the mask.
Layer layerWithMask(Layer layer, LayerMask? mask) {
  final copy = LayerCopyManager().copyLayer(layer);
  // The copy manager hands a plain [Layer] back as it is.
  final owned = identical(copy, layer) ? layer.copyWith() : copy;
  return owned
    ..key = layer.key
    ..keyInternalSize = layer.keyInternalSize
    ..repaintBoundaryKey = layer.repaintBoundaryKey
    ..mask = mask;
}

/// Replaces the layer [layerId] in [editor] with what [update] makes of it.
void _replaceLayer(
  ProImageEditorState editor,
  String layerId,
  Layer Function(Layer live) update, {
  bool skipUpdateHistory = false,
}) {
  if (!editor.mounted) return;
  final index = editor.activeLayers.indexWhere((l) => l.id == layerId);
  if (index < 0) return;
  editor.replaceLayer(
    index: index,
    layer: update(editor.activeLayers[index]),
    skipUpdateHistory: skipUpdateHistory,
  );
}

/// Where the layer [layerId] sits on screen: the box its content is laid out
/// in, which its mask is measured in.
MaskTargetGeometry? _layerGeometry(ProImageEditorState editor, String id) {
  if (!editor.mounted) return null;
  final layer = editor.activeLayers.firstWhereOrNull((l) => l.id == id);
  return _boxGeometry(
    layer?.repaintBoundaryKey.currentContext?.findRenderObject(),
  );
}

/// [box]'s size and its transform to the screen.
MaskTargetGeometry? _boxGeometry(RenderObject? box) {
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return (size: box.size, transform: box.getTransformTo(null));
}
