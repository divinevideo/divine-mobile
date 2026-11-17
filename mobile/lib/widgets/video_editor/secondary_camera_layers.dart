// ABOUTME: Turns the second-camera takes of dual-camera clips into
// ABOUTME: picture-in-picture detached-clip layers when the editor opens

import 'dart:ui';

import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_editor/detached_clip_window.dart';
import 'package:openvine/models/video_recorder/secondary_camera_take.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerMask, LayerMaskShape, WidgetLayer, WidgetLayerExportConfigs;

/// The picture-in-picture layers of the dual-camera takes in [clips], one per
/// take with the take's id, leaving out the takes in [placedTakeIds].
///
/// Each take becomes a detached-clip layer over its clip's stretch of the
/// timeline, sized and placed where the recorder showed the second camera's
/// window, so move, resize, shape masks, keyframes and split-screen layouts
/// all work on it like on any detached clip. The take stays on its clip: the
/// session records which takes it placed, so a layer is made once and one the
/// creator removed stays removed.
///
/// [canvasRenderSize] is the editor's render surface: layer widths and
/// offsets are render coordinates. [now] stamps the layer ids, which must be
/// unique per call.
List<({String takeId, WidgetLayer layer})> secondaryCameraTakeLayers({
  required List<DivineVideoClip> clips,
  required Size canvasRenderSize,
  required DateTime now,
  Set<String> placedTakeIds = const {},
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
  required String layerId,
}) {
  // The take's own trim is the lead-in before the clip's first frame; past
  // that the two films run together, so it follows the clip's trims and
  // plays no longer than the clip does.
  final second = take.clip.copyWith(
    trimStart: take.clip.trimStart + owner.trimStart,
    targetAspectRatio: owner.targetAspectRatio,
  );
  final playback = second.playbackDuration < owner.playbackDuration
      ? second.playbackDuration
      : owner.playbackDuration;
  final window = detachedClipWindow(
    slotStart: slotStart,
    playbackDuration: playback,
    compositionDuration: compositionDuration,
  );
  final meta = DetachedClipLayerData(
    clip: second.copyWith(originalAspectRatio: second.videoAspectRatio),
    layerId: layerId,
  ).toMeta();

  final width = canvasRenderSize.width * SecondaryCameraTake.pipWidthFraction;
  final height = width / second.videoAspectRatio;
  // A layer offset is measured from the canvas center. The window is kept
  // whole inside the frame, as the viewfinder kept it.
  final halfFreeWidth = ((canvasRenderSize.width - width) / 2).clamp(
    0.0,
    double.infinity,
  );
  final halfFreeHeight = ((canvasRenderSize.height - height) / 2).clamp(
    0.0,
    double.infinity,
  );
  final offset = Offset(
    ((take.pipCenter.dx - 0.5) * canvasRenderSize.width).clamp(
      -halfFreeWidth,
      halfFreeWidth,
    ),
    ((take.pipCenter.dy - 0.5) * canvasRenderSize.height).clamp(
      -halfFreeHeight,
      halfFreeHeight,
    ),
  );

  return WidgetLayer(
    id: layerId,
    startTime: window.start,
    endTime: window.end,
    width: width,
    offset: offset,
    widget: DetachedClipLayerView(meta: meta),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(id: layerId, meta: meta),
    // Rounded like the viewfinder window, in the export too; the user can
    // change it to any other shape.
    mask: const LayerMask(
      shape: LayerMaskShape.rectangle,
      size: Size(1, 1),
      cornerRadius: SecondaryCameraTake.pipCornerRadius,
    ),
  );
}
