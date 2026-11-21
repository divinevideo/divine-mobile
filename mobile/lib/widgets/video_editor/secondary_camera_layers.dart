// ABOUTME: Turns the second-camera takes of dual-camera clips into
// ABOUTME: picture-in-picture layers that follow their clips on the timeline

import 'dart:math' as math;
import 'dart:ui';

import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:models/models.dart' as model show AspectRatio;

import 'package:openvine/extensions/layer_animation_storage.dart'
    show ExportLayerMapping;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_editor/detached_clip_window.dart';
import 'package:openvine/models/video_recorder/secondary_camera_take.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:path/path.dart' as p;
import 'package:pro_image_editor/features/main_editor/services/layer_copy_manager.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show
        Layer,
        LayerMask,
        LayerMaskShape,
        WidgetLayer,
        WidgetLayerExportConfigs;

/// The picture-in-picture layers of the dual-camera takes in [clips], one per
/// take with the take's id, leaving out the takes in [placedTakeIds].
///
/// Each take becomes a detached-clip layer over its clip's stretch of the
/// timeline, sized, turned and placed where the recorder showed the second
/// camera's window, so move, resize, shape masks, keyframes and split-screen
/// layouts all work on it like on any detached clip. The take stays on its
/// clip: the session records which takes it placed, so a layer is made once
/// and one the creator removed stays removed. The layer follows its clip on
/// the timeline; see [secondaryCameraLayersFollowingClips].
///
/// [canvasRenderSize] is the editor's render surface: layer widths and
/// offsets are render coordinates. [now] stamps the layer ids, which must be
/// unique per call. A render without an editor passes [poster]: the layer
/// then mounts the clip's poster, which opens no decoder, since the render
/// composites the take's own video over it anyway.
List<({String takeId, WidgetLayer layer})> secondaryCameraTakeLayers({
  required List<DivineVideoClip> clips,
  required Size canvasRenderSize,
  required DateTime now,
  Set<String> placedTakeIds = const {},
  bool poster = false,
}) {
  // Without a laid-out canvas there is nothing to size the layers against.
  if (canvasRenderSize.isEmpty) return const [];
  final compositionDuration = clips.fold(
    Duration.zero,
    (total, clip) => total + clip.playbackDuration,
  );
  final layers = <({String takeId, WidgetLayer layer})>[];
  var slotStart = Duration.zero;
  for (final clip in clips) {
    final take = clip.secondaryCamera;
    if (take != null && !placedTakeIds.contains(take.clip.id)) {
      layers.add((
        takeId: take.clip.id,
        layer: _layerFor(
          take: take,
          owner: clip,
          slotStart: slotStart,
          compositionDuration: compositionDuration,
          canvasRenderSize: canvasRenderSize,
          poster: poster,
          layerId:
              'detached_${take.clip.id}_${now.microsecondsSinceEpoch}'
              '_${layers.length}',
        ),
      ));
    }
    slotStart += clip.playbackDuration;
  }
  return layers;
}

WidgetLayer _layerFor({
  required SecondaryCameraTake take,
  required DivineVideoClip owner,
  required Duration slotStart,
  required Duration compositionDuration,
  required Size canvasRenderSize,
  required bool poster,
  required String layerId,
}) {
  final second = secondaryCameraPlayback(take: take, owner: owner);
  final window = detachedClipWindow(
    slotStart: slotStart,
    playbackDuration: second.playbackDuration,
    compositionDuration: compositionDuration,
  );
  final meta = DetachedClipLayerData.withAnchor(
    DetachedClipLayerData(
      clip: second.copyWith(originalAspectRatio: second.videoAspectRatio),
      layerId: layerId,
    ).toMeta(),
    DetachedClipAnchor(clipId: owner.id, start: window.start, end: window.end),
  )!;

  // The take's position is measured against the part of the picture the
  // post keeps, as the viewfinder measured it: a square take keeps the middle
  // of the surface.
  final kept = ExportLayerMapping.keptRect(
    canvasRenderSize,
    owner.targetAspectRatio.value,
  );
  final unscaledWidth = kept.width * SecondaryCameraTake.pipWidthFraction;
  final layerSize = Size(
    unscaledWidth,
    unscaledWidth / second.videoAspectRatio,
  );
  // A square window is the middle of the second picture, as the viewfinder's
  // window covers it: the layer keeps the whole picture and its mask shows
  // the square, so the creator can widen it again in the editor.
  final isSquare = take.pipAspectRatio == model.AspectRatio.square;
  final side = math.min(layerSize.width, layerSize.height);
  final unscaledSize = isSquare ? Size(side, side) : layerSize;
  final scale = SecondaryCameraTake.fittingPipScale(
    scale: take.pipScale,
    unscaledSize: unscaledSize,
    rotation: take.pipRotation,
    area: kept.size,
  );
  // A layer offset is measured from the canvas center, which is also the
  // kept part's. The turned window is kept whole inside that part, as the
  // viewfinder kept it.
  final bounds = SecondaryCameraTake.turnedPipBounds(
    unscaledSize * scale,
    take.pipRotation,
  );
  final halfFreeWidth = math.max(0.0, (kept.width - bounds.width) / 2);
  final halfFreeHeight = math.max(0.0, (kept.height - bounds.height) / 2);
  final offset = Offset(
    ((take.pipCenter.dx - 0.5) * kept.width).clamp(
      -halfFreeWidth,
      halfFreeWidth,
    ),
    ((take.pipCenter.dy - 0.5) * kept.height).clamp(
      -halfFreeHeight,
      halfFreeHeight,
    ),
  );

  return WidgetLayer(
    id: layerId,
    startTime: window.start,
    endTime: window.end,
    width: unscaledWidth,
    offset: offset,
    // Pinched and turned as the viewfinder showed the window.
    scale: scale,
    rotation: take.pipRotation,
    widget: poster
        ? DetachedClipPoster(meta: meta)
        : DetachedClipLayerView(meta: meta),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(id: layerId, meta: meta),
    // Shaped and rounded like the viewfinder window, in the export too; the
    // user can change it to any other shape.
    mask: LayerMask(
      shape: LayerMaskShape.rectangle,
      size: Size(
        unscaledSize.width / layerSize.width,
        unscaledSize.height / layerSize.height,
      ),
      cornerRadius: SecondaryCameraTake.pipCornerRadius,
    ),
  );
}

/// The second camera's recording as it plays under [owner]: the stretch
/// filmed together with the owner's trimmed footage, at the owner's speed.
///
/// The take's own trim is the lead-in before the clip's first frame; past
/// that the two films run together, so the owner's trims and speed carry
/// over and the take plays exactly as long as its clip.
DivineVideoClip secondaryCameraPlayback({
  required SecondaryCameraTake take,
  required DivineVideoClip owner,
}) {
  final trimStart = take.clip.trimStart + owner.trimStart;
  final available = take.clip.duration - trimStart;
  final played = owner.trimmedDuration < available
      ? owner.trimmedDuration
      : available;
  final trimEnd = take.clip.duration - trimStart - played;
  return take.clip.copyWith(
    trimStart: trimStart,
    trimEnd: trimEnd.isNegative ? Duration.zero : trimEnd,
    playbackSpeed: owner.playbackSpeed,
    speedRamp: owner.speedRamp,
    targetAspectRatio: owner.targetAspectRatio,
  );
}

/// [layers] with each picture-in-picture layer moved along with its clip in
/// [clips], so a take's two cameras stay together however the timeline is
/// edited.
///
/// A layer follows while it still sits where following last put it and
/// still plays its take's footage. One the creator moved or trimmed on its
/// own, re-rendered (a crop), or whose clip is gone from [clips] (a split
/// gives the pieces new ids) keeps its place and stops following. A layer
/// whose clip is in [removedClipIds] is removed with it.
///
/// Returns [layers] itself when nothing moved, so a caller can tell with
/// `identical`. Moved layers are copies; the others are passed through.
List<Layer> secondaryCameraLayersFollowingClips(
  List<Layer> layers, {
  required List<DivineVideoClip> clips,
  Set<String> removedClipIds = const {},
}) {
  if (!layers.any(
    (layer) =>
        DetachedClipLayerData.anchorOf(DetachedClipLayerData.metaOf(layer)) !=
        null,
  )) {
    return layers;
  }
  final slotStarts = <String, Duration>{};
  final clipsById = <String, DivineVideoClip>{};
  var compositionDuration = Duration.zero;
  for (final clip in clips) {
    slotStarts[clip.id] = compositionDuration;
    clipsById[clip.id] = clip;
    compositionDuration += clip.playbackDuration;
  }

  var changed = false;
  final result = <Layer>[];
  for (final layer in layers) {
    final meta = DetachedClipLayerData.metaOf(layer);
    final anchor = DetachedClipLayerData.anchorOf(meta);
    if (anchor == null || meta == null || layer is! WidgetLayer) {
      result.add(layer);
      continue;
    }
    if (removedClipIds.contains(anchor.clipId)) {
      changed = true;
      continue;
    }
    final owner = clipsById[anchor.clipId];
    final take = owner?.secondaryCamera;
    if (owner == null ||
        take == null ||
        layer.startTime != anchor.start ||
        layer.endTime != anchor.end ||
        !_playsTake(meta, take)) {
      result.add(
        _withMeta(layer, DetachedClipLayerData.withAnchor(meta, null)!),
      );
      changed = true;
      continue;
    }

    final second = secondaryCameraPlayback(take: take, owner: owner);
    final window = detachedClipWindow(
      slotStart: slotStarts[owner.id]!,
      playbackDuration: second.playbackDuration,
      compositionDuration: compositionDuration,
    );
    final followed = DetachedClipLayerData.withAnchor(
      DetachedClipLayerData.withClipTiming(meta, second),
      DetachedClipAnchor(
        clipId: owner.id,
        start: window.start,
        end: window.end,
      ),
    )!;
    if (const DeepCollectionEquality().equals(followed, meta)) {
      result.add(layer);
      continue;
    }
    result.add(
      _withMeta(layer, followed)
        ..startTime = window.start
        ..endTime = window.end,
    );
    changed = true;
  }
  return changed ? result : layers;
}

/// Whether the layer [meta] describes still plays [take]'s own file, rather
/// than another take or footage a crop rendered.
bool _playsTake(Map<String, dynamic> meta, SecondaryCameraTake take) {
  final clip = meta[detachedClipLayerClipKey];
  if (clip is! Map) return false;
  final path = take.clip.video?.file?.path;
  return clip['id'] == take.clip.id &&
      path != null &&
      clip['filePath'] == p.basename(path);
}

/// A copy of [layer] carrying [meta], which keeps the layer's widget key, so
/// the canvas updates the layer it shows instead of building a new one.
WidgetLayer _withMeta(WidgetLayer layer, Map<String, dynamic> meta) =>
    (LayerCopyManager().copyLayer(layer) as WidgetLayer)
      ..meta = meta
      ..widget = DetachedClipLayerView(meta: meta)
      ..exportConfigs = layer.exportConfigs.copyWith(meta: meta);
