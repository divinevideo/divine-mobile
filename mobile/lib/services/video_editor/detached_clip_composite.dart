// ABOUTME: Turns detached-clip layers into the composition the export
// ABOUTME: composites over the finished timeline track

import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:meta/meta.dart';
import 'package:openvine/extensions/layer_animation_storage.dart'
    show exportedLayerTopLeft;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
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
    this.chromaKey,
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

  /// The green screen the layer applies live, or `null` for none.
  ///
  /// Keyed by the composition as the clip is placed over the base track, so
  /// the removed area shows the track underneath — the one place a transparent
  /// key can be honoured literally, since H.264 carries no alpha of its own.
  final ClipChromaKey? chromaKey;
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
        chromaKey: data.chromaKey,
      ),
    );
  }

  return (below: below, detached: detached, above: above);
}

/// The layer's **unrotated** layout box, recovered from the rotated bounding
/// box `pro_image_editor` reports as `ExportedLayer.logicalSize`.
///
/// `Layer.captureAllLayers` grows a rotated layer's reported size to the box
/// that contains the turned content, because the raster it ships alongside is
/// rotated too. A detached clip throws that raster away and re-places the
/// video itself, and `SegmentTransform.rotation` wants the box *before* the
/// turn — so the growth has to be undone, or a rotated clip would be scaled up
/// to its own bounding box. Its centre stays put either way, since placement
/// is anchored on the layer's centre.
///
/// With `w`/`h` the unrotated size and `c`/`s` the absolute cosine and sine:
///
/// ```text
/// bounding.width  = w * c + h * s
/// bounding.height = w * s + h * c
/// ```
///
/// Two equations in two unknowns, but the system is singular at 45°, where
/// every box with the same `w + h` shares one bounding square. [aspectRatio]
/// supplies the missing constraint (`w == aspectRatio * h`), which collapses
/// the sum to a single division that is well conditioned at every angle:
/// `(1 + aspectRatio) * (c + s)` never drops below `1 + aspectRatio`.
///
/// Both measured dimensions feed the result rather than just one, so a pixel
/// of layout rounding in either is halved instead of carried through whole.
@visibleForTesting
Size unrotatedLayerBox({
  required Size boundingBox,
  required double rotation,
  required double aspectRatio,
}) {
  // An unrotated layer is already its own box; an unusable ratio leaves the
  // box alone rather than scaling the clip by a nonsense factor.
  if (rotation == 0 ||
      !rotation.isFinite ||
      !aspectRatio.isFinite ||
      aspectRatio <= 0) {
    return boundingBox;
  }
  final denominator =
      (1 + aspectRatio) * (math.cos(rotation).abs() + math.sin(rotation).abs());
  if (denominator <= 0) return boundingBox;
  final height = (boundingBox.width + boundingBox.height) / denominator;
  return Size(height * aspectRatio, height);
}

/// Builds the composition layer that places [item] over the base track.
///
/// Placement uses the same body-space scale and centre-relative offset
/// convention as `VideoEditorRenderService.buildImageLayers`, but recovers the
/// unrotated box and passes rotation separately: detached clips are composited
/// from their video rather than the rotated raster used for image layers.
///
/// [resolvedVideo] is the clip's media as the composition can take it — the
/// clip's own file, or a speed-flattened re-render, since a composition layer
/// rejects `playbackSpeed`.
///
/// Time is mapped through [timelineMap] like every other overlay window: an
/// overlap transition shortens the output, and without the mapping a clip near
/// the end would be placed past the real video end.
///
/// A live green screen goes on the layer as its `chromaKey`. The composition
/// keys each clip on its own frame before placing it, so a transparent key
/// lets the base track show through the removed area; a colour or image fill
/// travels inside the key itself. A library-clip backdrop has no second track
/// to play on here and is not offered for a detached clip — were one to arrive
/// anyway, its key is transparent and the track shows through instead.
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

  // `logicalSize` is the layer's *rotated* bounding box, while the transform
  // below wants the box before the turn — see [unrotatedLayerBox]. The anchor
  // is the layer's centre either way, since the turn is around that centre.
  final box = unrotatedLayerBox(
    boundingBox: item.logicalSize,
    rotation: layer.rotation,
    aspectRatio: clip.originalAspectRatio,
  );

  final offset = exportedLayerTopLeft(
    anchor: layer.offset,
    bodySize: bodySize,
    logicalSize: box,
    scale: scale,
  );
  final size = Size(box.width * scale, box.height * scale);

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
    chromaKey: item.chromaKey?.key,
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
          // Forwarded straight through: both sides mean a clockwise turn in
          // radians around the box's own centre.
          rotation: layer.rotation,
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
