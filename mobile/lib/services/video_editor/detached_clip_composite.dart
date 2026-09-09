// ABOUTME: Turns detached-clip layers into the composition the export
// ABOUTME: composites over the finished timeline track

import 'dart:ui' show Offset, Size;

import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show ExportedLayer, Layer;
import 'package:pro_video_editor/pro_video_editor.dart'
    show EditorVideo, SegmentFit, SegmentTransform, VideoLayer, VideoSegment;

/// One detached clip, paired with the layer that places it on the canvas.
class DetachedClipExportLayer {
  const DetachedClipExportLayer({
    required this.clip,
    required this.layer,
    required this.logicalSize,
    this.sourceOffset = Duration.zero,
  });

  /// The clip's own media, with its trim, volume and speed.
  final DivineVideoClip clip;

  /// The canvas layer: where it sits, how big it is, when it is on screen.
  final Layer layer;

  /// The layer's laid-out size in editor body space, scale already folded in.
  final Size logicalSize;

  /// Where this layer starts inside the clip, in playback time — non-zero for
  /// the tail half of a split.
  final Duration sourceOffset;
}

/// The captured layers sorted into what renders under the detached clips, the
/// detached clips themselves, and what renders over them.
///
/// Layers arrive bottom-to-top, so the split point is the lowest detached clip:
/// everything below it is baked into the base track in the first pass, and
/// everything above it is composited on top in the second.
///
/// The one case this cannot express is an image layer sandwiched *between* two
/// detached clips — it ends up above both. Ordering a raster between two video
/// layers would need a render pass per detached clip, which is not worth paying
/// on every export for a stacking order nothing in the UI encourages.
typedef PartitionedLayers = ({
  List<ExportedLayer> below,
  List<DetachedClipExportLayer> detached,
  List<ExportedLayer> above,
});

/// Splits [layers] into the three groups described by [PartitionedLayers].
///
/// [documentsPath] resolves the clip file paths stored in each detached layer's
/// meta as basenames. A detached layer whose clip cannot be read is treated as
/// an ordinary layer — its raster is at least the frame the user last saw,
/// which beats dropping it from the export entirely.
PartitionedLayers partitionDetachedClipLayers(
  List<ExportedLayer> layers,
  String documentsPath,
) {
  final below = <ExportedLayer>[];
  final detached = <DetachedClipExportLayer>[];
  final above = <ExportedLayer>[];

  for (final item in layers) {
    final meta = DetachedClipLayerData.metaOf(item.layer);
    final data = meta == null
        ? null
        : DetachedClipLayerData.fromMeta(meta, documentsPath);
    final clip = data?.clip;

    if (clip == null || clip.video == null) {
      (detached.isEmpty ? below : above).add(item);
      continue;
    }
    detached.add(
      DetachedClipExportLayer(
        clip: clip,
        layer: item.layer,
        logicalSize: item.logicalSize,
        sourceOffset: data!.sourceOffset,
      ),
    );
  }

  return (below: below, detached: detached, above: above);
}

/// Builds the composition layer that places [item] over the base track.
///
/// Geometry mirrors `VideoEditorRenderService.buildImageLayers` exactly, so a
/// detached clip lands where its raster would have: editor body space scaled by
/// `videoSize.width / bodySize.width`, with the layer's centre-relative offset
/// converted to a top-left corner.
///
/// [resolvedVideo] is the clip's media as the composition can take it — the
/// clip's own file, or a speed-flattened re-render, since a composition layer
/// rejects `playbackSpeed`.
///
/// Time is mapped through [timelineMap] like every other overlay window: an
/// overlap transition shortens the output, and without the mapping a clip near
/// the end would be placed past the real video end.
VideoLayer buildDetachedClipVideoLayer({
  required DetachedClipExportLayer item,
  required EditorVideo resolvedVideo,
  required Size bodySize,
  required Size videoSize,
  required TransitionTimelineMap timelineMap,
  required bool speedFlattened,
}) {
  final scale = videoSize.width / bodySize.width;
  final layer = item.layer;
  final clip = item.clip;

  final offset = Offset(
    (bodySize.width / 2 + layer.offset.dx - item.logicalSize.width / 2) * scale,
    (bodySize.height / 2 + layer.offset.dy - item.logicalSize.height / 2) *
        scale,
  );
  final size = Size(
    item.logicalSize.width * scale,
    item.logicalSize.height * scale,
  );

  final start = timelineMap.editorToOutputOrNull(layer.startTime);
  final end = timelineMap.editorToOutputOrNull(layer.endTime);

  // A speed-flattened file already *is* the trimmed, sped-up section, so it
  // plays from its own zero. The clip's own file still needs its trim window.
  //
  // A split tail starts partway in, and its offset is playback time — the same
  // units the flattened file is already in, but source time has to be derived
  // for the clip's own file.
  final offsetIntoSource = speedFlattened
      ? item.sourceOffset
      : _sourceSpanFor(clip, item.sourceOffset, speedFlattened: false);
  final trimStart =
      (speedFlattened ? Duration.zero : clip.trimStart) + offsetIntoSource;
  final whole = speedFlattened ? clip.playbackDuration : clip.trimmedDuration;
  final available = whole - offsetIntoSource;

  // A layer window shorter than the clip cuts the clip; a longer one leaves it
  // to end on its own last frame rather than freezing.
  final windowed = start != null && end != null && end > start
      ? _sourceSpanFor(clip, end - start, speedFlattened: speedFlattened)
      : available;
  final span = windowed < available ? windowed : available;

  return VideoLayer(
    clips: [
      VideoSegment(
        video: resolvedVideo,
        startTime: trimStart == Duration.zero ? null : trimStart,
        endTime: trimStart + span,
        volume: clip.volume,
        timelineStart: start == null || start == Duration.zero ? null : start,
        transform: SegmentTransform(
          offset: offset,
          size: size,
          // The layer box already carries the clip's aspect ratio, so contain
          // and cover agree — contain is the one that cannot crop if rounding
          // pulls them a pixel apart.
          fit: SegmentFit.contain,
        ),
      ),
    ],
  );
}

/// How much of [clip]'s source media fills [playbackSpan] of wall clock.
Duration _sourceSpanFor(
  DivineVideoClip clip,
  Duration playbackSpan, {
  required bool speedFlattened,
}) => speedFlattened
    ? playbackSpan
    : clip.playbackDurationToSourceDuration(playbackSpan);
