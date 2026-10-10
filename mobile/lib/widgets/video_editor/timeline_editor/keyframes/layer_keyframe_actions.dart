// ABOUTME: Keyframe actions on a timeline layer: add or remove the keyframe at
// ABOUTME: the playhead, ease the motion to the next one, and set the opacity.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_editor/editor_censor_area.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_opacity.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/keyframes/layer_keyframes_sheet.dart';
import 'package:pro_image_editor/features/main_editor/services/layer_copy_manager.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Whether [layer] can be moved by keyframes.
///
/// Every overlay layer can, except a hidden area (blur, pixelate): it hides
/// what is beneath it, and one that drifted would show what it hid for a
/// moment, as an animated one would.
bool canKeyframeLayer(Layer? layer) => layer != null && !isCensorLayer(layer);

/// [layer] with a keyframe at [time] (video time) added, or the one there
/// removed.
///
/// A new keyframe holds what the canvas shows at [time]: where the keyframes
/// already move the layer, or its own placement and opacity when it has none.
/// Removing the last keyframe leaves the layer where it showed at [time],
/// rather than where it was last laid out.
///
/// A detached clip keeps a still opacity in its meta, which its view applies
/// itself. Its keyframes carry its opacity instead, so the value moves into
/// the first keyframe and back out of the last one.
Layer layerWithKeyframeToggled(
  Layer layer,
  Duration time, {
  Duration tolerance = VideoEditorConstants.keyframeTolerance,
}) {
  final updated = _copyKeepingKey(layer);
  final isDetachedClip = DetachedClipLayerData.isDetachedClipLayer(updated);

  if (updated.keyframeIndexAt(time, tolerance: tolerance) >= 0) {
    if (updated.keyframes.length > 1) {
      updated.removeKeyframeAt(time, tolerance: tolerance);
      return updated;
    }
    updated
      ..applyKeyframePlacement(time)
      ..removeKeyframeAt(time, tolerance: tolerance);
    if (isDetachedClip && updated is WidgetLayer) {
      _setDetachedClipOpacity(updated, updated.opacity);
      updated.opacity = 1;
    }
    return updated;
  }

  final shown =
      updated.keyframePlacementAt(time) ??
      LayerPlacement(
        offset: updated.offset,
        scale: updated.scale,
        rotation: updated.rotation,
        opacity: isDetachedClip
            ? DetachedClipLayerData.opacityOf(
                DetachedClipLayerData.metaOf(updated),
              )
            : updated.opacity,
      );
  if (isDetachedClip && !updated.hasKeyframes && updated is WidgetLayer) {
    _setDetachedClipOpacity(updated, 1);
  }
  updated.setKeyframeAt(time, placement: shown, tolerance: tolerance);
  return updated;
}

/// [layer] with the keyframes from the one at or before [time] to the next
/// one eased along [curve].
///
/// Before the first keyframe the first one's curve changes, after the last
/// one the curve into it. Returns [layer] unchanged when it has fewer than two
/// keyframes, which leaves no motion to ease.
Layer layerWithKeyframeCurve(
  Layer layer,
  Duration time,
  AnimationCurve curve,
) {
  final index = keyframeSegmentIndex(layer, time);
  if (index == null) return layer;
  final keyframes = [...layer.keyframes];
  keyframes[index] = keyframes[index].copyWith(curve: curve);
  return _copyKeepingKey(layer)..keyframes = keyframes;
}

/// The effects a motion between two keyframes can play: the loops that read
/// well over and over, as the layer animation sheet offers them. A scale is
/// shown as a pulse.
const keyframeEffectTypes = <LayerAnimationType>[
  LayerAnimationType.wiggle,
  LayerAnimationType.bounce,
  LayerAnimationType.scale,
];

/// A loop of [type] with the cycle, curve and strength the layer animation
/// sheet starts a loop with.
LayerAnimation defaultKeyframeEffect(LayerAnimationType type) => switch (type) {
  LayerAnimationType.wiggle => const LayerAnimation(
    type: LayerAnimationType.wiggle,
    phase: AnimationPhase.loop,
    duration: VideoEditorConstants.loopWiggleCycle,
    curve: AnimationCurve.easeIn,
    wiggleAngle: LayerAnimation.defaultWiggleAngle,
  ),
  LayerAnimationType.bounce => const LayerAnimation(
    type: LayerAnimationType.bounce,
    phase: AnimationPhase.loop,
    duration: VideoEditorConstants.loopBounceCycle,
    curve: AnimationCurve.easeIn,
    bounceHeight: LayerAnimation.defaultBounceHeight,
  ),
  _ => const LayerAnimation(
    type: LayerAnimationType.scale,
    phase: AnimationPhase.loop,
    duration: VideoEditorConstants.loopPulseCycle,
    curve: AnimationCurve.easeInOut,
    scaleFrom: VideoEditorConstants.loopPulseScaleFrom,
  ),
};

/// Whether [layer] can play effects between its keyframes.
///
/// A detached clip cannot: the export composites it as a video layer, which
/// carries no animations, as its own enter and leave animations are off.
bool canPlayKeyframeEffects(Layer layer) =>
    !DetachedClipLayerData.isDetachedClipLayer(layer);

/// The effect [layer]'s motion at [time] plays, or `null` when it plays none
/// or the layer has fewer than two keyframes.
LayerAnimation? layerKeyframeEffectAt(Layer layer, Duration time) {
  final index = keyframeSegmentIndex(layer, time);
  if (index == null) return null;
  return layer.keyframes[index].effects
      .where((effect) => effect.phase == AnimationPhase.loop)
      .firstOrNull;
}

/// [layer] with its motion at [time] playing [effect], or none for `null`.
/// Returns [layer] unchanged when it has fewer than two keyframes.
Layer layerWithKeyframeEffect(
  Layer layer,
  Duration time,
  LayerAnimation? effect,
) {
  final index = keyframeSegmentIndex(layer, time);
  if (index == null) return layer;
  final keyframes = [...layer.keyframes];
  keyframes[index] = keyframes[index].copyWith(
    effects: effect == null ? const [] : [effect],
  );
  return _copyKeepingKey(layer)..keyframes = keyframes;
}

/// Index of the keyframe whose curve eases [layer]'s motion at [time]: the
/// last one at or before [time], held between the first and the second to
/// last. `null` when the layer has fewer than two keyframes.
int? keyframeSegmentIndex(Layer layer, Duration time) {
  final keyframes = layer.keyframes;
  if (keyframes.length < 2) return null;
  final local = time - layer.keyframeOrigin;
  final atOrBefore = keyframes.lastIndexWhere(
    (k) => k.time <= local + VideoEditorConstants.keyframeTolerance,
  );
  return atOrBefore.clamp(0, keyframes.length - 2);
}

/// [layer] showing [opacity] at [time]: in the keyframe there for a keyframed
/// layer, adding one when there is none, else as its own opacity.
Layer layerWithOpacity(Layer layer, Duration time, double opacity) {
  final updated = _copyKeepingKey(layer);
  final placement = updated.keyframePlacementAt(time);
  if (placement == null) {
    updated.opacity = opacity;
    return updated;
  }
  updated.setKeyframeAt(
    time,
    placement: LayerPlacement(
      offset: placement.offset,
      scale: placement.scale,
      rotation: placement.rotation,
      opacity: opacity,
    ),
    tolerance: VideoEditorConstants.keyframeTolerance,
  );
  return updated;
}

/// The opacity [layer] shows at [time].
double layerOpacityAt(Layer layer, Duration time) =>
    layer.keyframePlacementAt(time)?.opacity ??
    (DetachedClipLayerData.isDetachedClipLayer(layer)
        ? DetachedClipLayerData.opacityOf(DetachedClipLayerData.metaOf(layer))
        : layer.opacity);

/// Replaces the layer [layerId] in the editor with what [update] makes of it,
/// as one history step; `null` from [update] writes nothing.
void _updateLiveLayer(
  VideoEditorScope scope,
  String layerId,
  Layer? Function(Layer live) update,
) {
  final editor = scope.editor;
  if (editor == null || !editor.mounted) return;
  final index = editor.activeLayers.indexWhere((l) => l.id == layerId);
  if (index < 0) return;
  final updated = update(editor.activeLayers[index]);
  if (updated == null) return;
  editor.replaceLayer(index: index, layer: updated);
}

/// Opens the keyframe sheet for [layer], selected in the timeline as [item]:
/// a line on how keyframes work, the button that adds the keyframe at the
/// playhead or removes the one there, the opacity of the keyframe the
/// playhead is on, and the effect and curve of the motion the playhead is in.
///
/// A playhead outside the layer is moved onto its start first, as the opacity
/// slider does: the layer is not drawn there, so a keyframe placed there could
/// not be seen.
///
/// Everything changed in the sheet shows on the canvas without a history step
/// of its own and is written as one when the sheet is confirmed, or swiped
/// away, as the opacity sheet keeps what the canvas shows. Cancelling puts the
/// layer back. The keyframe button confirms at once and closes the sheet, so
/// the layer can be moved, which is what sets the next keyframe.
Future<void> editLayerKeyframes(
  BuildContext context,
  Layer layer, {
  required TimelineOverlayItem item,
}) async {
  final scope = VideoEditorScope.of(context);
  final mainBloc = context.read<VideoEditorMainBloc>();
  // The canvas/diamond follow this live clock while a seek is pending; the
  // bloc's currentPosition only catches up after the player reports it.
  var time = scope.playTimeNotifier.value;
  if (time < item.startTime || time > item.endTime) {
    time = item.startTime;
    mainBloc.add(VideoEditorSeekRequested(time));
  }

  final isOnKeyframe =
      layer.keyframeIndexAt(
        time,
        tolerance: VideoEditorConstants.keyframeTolerance,
      ) >=
      0;
  final segmentIndex = keyframeSegmentIndex(layer, time);

  var edited = layer;
  void show(Layer shown) {
    final editor = scope.editor;
    if (editor == null || !editor.mounted) return;
    final index = editor.activeLayers.indexWhere((l) => l.id == layer.id);
    if (index < 0) return;
    editor.replaceLayer(index: index, layer: shown, skipUpdateHistory: true);
  }

  void edit(Layer Function(Layer edited) update) {
    edited = update(edited);
    show(edited);
  }

  // Set by the body: the header buttons are built outside the sheet's route.
  BuildContext? sheetContext;
  void close({required bool confirmed}) {
    final routeContext = sheetContext;
    if (routeContext != null) Navigator.of(routeContext).pop(confirmed);
  }

  final l10n = context.l10n;
  final confirmed = await VineBottomSheet.show<bool>(
    context: context,
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    // Clear, so the opacity and the motion are judged on the canvas itself.
    barrierColor: VineTheme.transparent,
    title: Text(
      l10n.videoEditorKeyframesLabel,
      style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
    ),
    headerLeadingAction: DivineIconButton(
      icon: .x,
      type: .secondary,
      size: .small,
      semanticLabel: l10n.commonCancel,
      onPressed: () => close(confirmed: false),
    ),
    headerTrailingAction: DivineIconButton(
      icon: .check,
      size: .small,
      semanticLabel: l10n.videoEditorDoneLabel,
      onPressed: () => close(confirmed: true),
    ),
    body: Builder(
      builder: (context) {
        sheetContext = context;
        return LayerKeyframesSheet(
          isOnKeyframe: isOnKeyframe,
          opacity: isOnKeyframe ? layerOpacityAt(layer, time) : null,
          segment: segmentIndex == null
              ? null
              : (
                  from: segmentIndex + 1,
                  curve: layer.keyframes[segmentIndex].curve,
                  effect: layerKeyframeEffectAt(layer, time),
                ),
          allowsEffects: canPlayKeyframeEffects(layer),
          onToggleKeyframe: () {
            edit((edited) => layerWithKeyframeToggled(edited, time));
            close(confirmed: true);
          },
          onOpacityChanged: (opacity) =>
              edit((edited) => layerWithOpacity(edited, time, opacity)),
          onEffectChanged: (effect) => edit(
            (edited) => layerWithKeyframeEffect(edited, time, effect),
          ),
          onCurveSelected: (curve) =>
              edit((edited) => layerWithKeyframeCurve(edited, time, curve)),
        );
      },
    ),
  );

  if (identical(edited, layer)) return;
  // The previews changed the layer in place of the current history step; it
  // is put back first so the step records the change.
  show(layer);
  // A change taken back within the sheet would be an undo step that undoes
  // nothing.
  if (confirmed == false || edited == layer) return;
  _updateLiveLayer(scope, layer.id, (_) => edited);
}

/// Opens the opacity slider for [layer], selected in the timeline as [item],
/// and writes the value it settles on as one history step.
///
/// A keyframed layer's opacity goes into the keyframe at the playhead, which
/// is added when there is none, as a gesture on the canvas adds one. A
/// detached clip without keyframes keeps its own opacity path, see
/// [editDetachedClipOpacity].
///
/// Every step of the slider shows on the canvas without a history step of its
/// own, and the step is put back before the final value is written, so the
/// edit is one undo however long the slider was dragged.
Future<void> editLayerOpacity(
  BuildContext context,
  Layer layer, {
  required TimelineOverlayItem item,
}) async {
  if (DetachedClipLayerData.isDetachedClipLayer(layer) && !layer.hasKeyframes) {
    return editDetachedClipOpacity(context, layer, item: item);
  }

  final scope = VideoEditorScope.of(context);
  final editor = scope.editor;
  if (editor == null) return;
  final mainBloc = context.read<VideoEditorMainBloc>();

  // A layer is not drawn outside its time range, so a playhead outside it is
  // moved to the layer's start first; the slider would fade nothing visible.
  var time = scope.playTimeNotifier.value;
  if (time < item.startTime || time > item.endTime) {
    time = item.startTime;
    mainBloc.add(VideoEditorSeekRequested(time));
  }

  void show(Layer shown) {
    if (!editor.mounted) return;
    final index = editor.activeLayers.indexWhere((l) => l.id == layer.id);
    if (index < 0) return;
    editor.replaceLayer(index: index, layer: shown, skipUpdateHistory: true);
  }

  final initial = layerOpacityAt(layer, time);
  double? chosen;
  final confirmed = await VineBottomSheet.show<bool>(
    context: context,
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    barrierColor: VineTheme.transparent,
    body: LayerOpacitySheet(
      initialOpacity: initial,
      onChanged: (opacity) {
        chosen = opacity;
        show(layerWithOpacity(layer, time, opacity));
      },
    ),
  );

  final value = chosen;
  if (value == null) return;
  show(layer);
  if (confirmed == false || value == initial || !editor.mounted) return;
  final index = editor.activeLayers.indexWhere((l) => l.id == layer.id);
  if (index < 0) return;
  editor.replaceLayer(
    index: index,
    layer: layerWithOpacity(editor.activeLayers[index], time, value),
  );
}

/// A copy of [layer] that keeps its widget key, so the canvas updates the
/// layer it shows instead of building a new one.
Layer _copyKeepingKey(Layer layer) => LayerCopyManager().copyLayer(layer);

/// Sets the still opacity a detached clip's meta carries, which its view
/// reads, on [layer] in place.
void _setDetachedClipOpacity(WidgetLayer layer, double opacity) {
  final meta = DetachedClipLayerData.withOpacity(
    DetachedClipLayerData.metaOf(layer),
    opacity,
  );
  if (meta == null) return;
  layer
    ..meta = meta
    ..widget = DetachedClipLayerView(meta: meta)
    ..exportConfigs = layer.exportConfigs.copyWith(meta: meta);
}
