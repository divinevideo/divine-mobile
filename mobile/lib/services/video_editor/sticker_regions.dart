// ABOUTME: Works out where a rendered video's tappable stickers stand: the
// ABOUTME: area and time of each link, mention and hashtag sticker.

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
    for (final item in capturedLayers)
      ?_regionOf(
        item,
        bodySize: bodySize,
        frame: frame,
        timelineMap: timelineMap,
      ),
  ];
}

VideoStickerRegion? _regionOf(
  ExportedLayer item, {
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
  if (layer.hasKeyframes || layer.divineAnimations.isNotEmpty) return null;

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
    // Only a still sticker can be drawn again over the frames: a turning
    // record or an equalizer would not keep time with the video beneath.
    style: sticker.isAnimated ? null : sticker.style.name,
    label: sticker.tapLabel,
  );
  final start = region.start;
  final end = region.end;
  if (start != null && end != null && end <= start) return null;
  return _isOnFrame(region) ? region : null;
}

/// Whether any of [region] can lie on the frame, measured generously by the
/// circle around the turned sticker.
bool _isOnFrame(VideoStickerRegion region) {
  final reach = region.width + region.height;
  return region.centerX + reach > 0 &&
      region.centerX - reach < 1 &&
      region.centerY + reach > 0 &&
      region.centerY - reach < 1;
}
