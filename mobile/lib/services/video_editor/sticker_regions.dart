// ABOUTME: Works out where a rendered video's tappable stickers stand: the
// ABOUTME: area and time of each link, mention, hashtag and sound sticker.

import 'dart:math' as math;
import 'dart:ui';

import 'package:models/models.dart' show VideoStickerRegion;
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// The stickers among [capturedLayers] a viewer can tap, placed on a video rendered
/// from them the way the export places them: against the part of [bodySize]
/// an export of [targetAspectRatio] keeps, and timed on the output through
/// [timelineMap].
///
/// Empty without a [bodySize], which the layers' offsets are measured in.
List<VideoStickerRegion> stickerRegionsFor({
  required List<ExportedLayer> capturedLayers,
  required Size? bodySize,
  required double targetAspectRatio,
  required TransitionTimelineMap timelineMap,
}) {
  if (bodySize == null || bodySize.isEmpty) return const [];
  final frame = ExportLayerMapping.keptRect(bodySize, targetAspectRatio);
  return [
    for (final (index, item) in capturedLayers.indexed)
      ?_regionOf(
        item,
        above: capturedLayers.skip(index + 1),
        bodySize: bodySize,
        frame: frame,
        timelineMap: timelineMap,
      ),
  ];
}

VideoStickerRegion? _regionOf(
  ExportedLayer item, {
  required Iterable<ExportedLayer> above,
  required Size bodySize,
  required Rect frame,
  required TransitionTimelineMap timelineMap,
}) {
  final layer = item.layer;
  final sticker = SocialStickerData.of(layer);
  if (sticker == null) return null;
  final target = sticker.tapTarget;
  if (target == null) return null;
  // A sticker that moves has no one place to tap. The editor offers no way
  // to move one; this keeps an older draft's from landing beside it.
  if (_moves(layer)) return null;
  // Nothing on the video would show a viewer there is a button.
  if (layer.opacity == 0) return null;

  final center = bodySize.center(Offset.zero) + layer.offset;
  // The capture is turned already; its box is the sticker before turning.
  final size = item.boxSize;
  final region = VideoStickerRegion(
    kind: sticker.tapKind,
    target: target,
    centerX: (center.dx - frame.left) / frame.width,
    centerY: (center.dy - frame.top) / frame.height,
    width: size.width / frame.width,
    height: size.height / frame.height,
    rotation: layer.rotation,
    start: timelineMap.editorToOutputOrNull(layer.startTime),
    end: timelineMap.editorToOutputOrNull(layer.endTime),
    // Only a still sticker drawn as it is, with nothing over it, can be drawn
    // again over the frames: a turning record or an equalizer would not keep
    // time with the video beneath, a faded, blended or masked one would come
    // back solid, and a copy would hide what lies on it.
    style:
        sticker.isAnimated ||
            !sticker.style.coversBakedCopy ||
            !_isDrawnPlainly(layer) ||
            above.any((upper) => _isCoveredBy(item, upper, bodySize))
        ? null
        : sticker.style.name,
    label: sticker.tapLabel,
  );
  final start = region.start;
  final end = region.end;
  if (start != null && end != null && end <= start) return null;
  return region.isOnFrame ? region : null;
}

/// Whether [layer] moves across the video.
bool _moves(Layer layer) =>
    layer.hasKeyframes || layer.divineAnimations.isNotEmpty;

/// Whether [layer] is drawn onto the video fully opaque, unblended and
/// whole, as a redraw of its sticker would be.
bool _isDrawnPlainly(Layer layer) =>
    layer.opacity == 1 &&
    layer.blendMode == BlendMode.srcOver &&
    layer.mask == null;

/// Whether [upper], drawn after [sticker], can show over any of it at the
/// same time; one that moves or animates is taken to cross it somewhere.
bool _isCoveredBy(ExportedLayer sticker, ExportedLayer upper, Size bodySize) {
  final a = sticker.layer;
  final b = upper.layer;
  final showTogether =
      (a.startTime == null || b.endTime == null || a.startTime! < b.endTime!) &&
      (b.startTime == null || a.endTime == null || b.startTime! < a.endTime!);
  if (!showTogether) return false;
  if (_moves(b)) return true;
  return _overlap(_corners(sticker, bodySize), _corners(upper, bodySize));
}

/// The corners of [item]'s box as it stands turned on the body.
List<Offset> _corners(ExportedLayer item, Size bodySize) {
  final center = bodySize.center(Offset.zero) + item.layer.offset;
  final cos = math.cos(item.layer.rotation);
  final sin = math.sin(item.layer.rotation);
  final half = item.boxSize / 2;
  return [
    for (final (x, y) in [
      (-half.width, -half.height),
      (half.width, -half.height),
      (half.width, half.height),
      (-half.width, half.height),
    ])
      center + Offset(x * cos - y * sin, x * sin + y * cos),
  ];
}

/// Whether two turned boxes, given by their corners in order, overlap: no
/// side of either one has the other wholly beyond it.
bool _overlap(List<Offset> a, List<Offset> b) {
  for (final box in [a, b]) {
    for (var i = 0; i < box.length; i++) {
      final side = box[(i + 1) % box.length] - box[i];
      double across(Offset point) => point.dx * -side.dy + point.dy * side.dx;
      final onA = a.map(across);
      final onB = b.map(across);
      if (onA.reduce(math.max) <= onB.reduce(math.min) ||
          onB.reduce(math.max) <= onA.reduce(math.min)) {
        return false;
      }
    }
  }
  return true;
}
