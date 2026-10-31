// ABOUTME: Where a poll, quiz or slider may stand on a video: above every other
// ABOUTME: layer, and inside the part of the frame the feed leaves clear.

import 'dart:math' as math;
import 'dart:ui';

import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:pro_image_editor/core/models/layers/layer_interaction.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Where a poll, quiz or slider may stand on the video, as fractions of its
/// frame: below the feed's top bar, left of the buttons down its right side,
/// above the name and caption under the video, and a little in from the left
/// edge a tall phone crops. Measured against the feed on a 20:9 phone, where
/// the top bar ends at 0.14, the buttons start at 0.86 and the name at 0.85,
/// with some room to spare for phones that crop more. Its answers are buttons
/// a viewer has to reach.
const Rect pollSafeArea = Rect.fromLTRB(0.06, 0.17, 0.82, 0.82);

/// Whether [layer] is a poll, quiz or slider.
bool isPollLayer(Layer layer) =>
    SocialStickerData.of(layer)?.kind.isPoll ?? false;

/// How a poll, quiz or slider may be handled on the canvas: moved, but not
/// turned or pinched to another size. Its answers are buttons a viewer taps,
/// so it stays upright and as large as it was placed.
LayerInteraction pollLayerInteraction() =>
    LayerInteraction(enableRotate: false, enableScale: false);

/// Whether [layer], a poll, quiz or slider, can still be turned or resized,
/// or stands turned, as one placed before [pollLayerInteraction] may.
bool pollLayerNeedsLocking(Layer layer) =>
    layer.interaction.enableRotate ||
    layer.interaction.enableScale ||
    layer.rotation != 0;

/// [pollSafeArea] in an editor body of [bodySize], whose export of
/// [targetAspectRatio] crops it to its frame.
Rect pollSafeRect({required Size bodySize, required double targetAspectRatio}) {
  final frame = ExportLayerMapping.keptRect(bodySize, targetAspectRatio);
  return Rect.fromLTRB(
    frame.left + frame.width * pollSafeArea.left,
    frame.top + frame.height * pollSafeArea.top,
    frame.left + frame.width * pollSafeArea.right,
    frame.top + frame.height * pollSafeArea.bottom,
  );
}

/// Whether [item] is the timeline bar of a poll, quiz or slider.
///
/// The bar keeps the last layer row, the layer drawn in front, and cannot be
/// dragged out of it.
bool isPollTimelineItem(TimelineOverlayItem item) =>
    item.type == TimelineOverlayType.layer &&
    item.layer != null &&
    isPollLayer(item.layer!);

/// Where another layer dropped on the timeline at [row] lands, so it stays
/// behind the poll, quiz or slider among [items].
///
/// A drop on or past the poll's row takes that row and pushes the poll down,
/// so the poll keeps the last row. Without a poll the drop is unchanged.
({int row, bool insertAbove}) layerDropBehindPoll({
  required Iterable<TimelineOverlayItem> items,
  required int row,
  required bool insertAbove,
}) {
  final pollRow = items.where(isPollTimelineItem).firstOrNull?.row;
  if (pollRow == null || row < pollRow || (row == pollRow && insertAbove)) {
    return (row: row, insertAbove: insertAbove);
  }
  return (row: pollRow, insertAbove: true);
}

/// The index of the poll, quiz or slider among [layers] when another layer
/// stands above it, or `null` when there is none or it is on top already.
///
/// A poll stands above every other layer: nothing may cover its answers, and
/// the player draws the votes over them.
int? pollLayerIndexBelowTop(List<Layer> layers) {
  final index = layers.lastIndexWhere(isPollLayer);
  return index < 0 || index == layers.length - 1 ? null : index;
}

/// Keeps the poll, quiz or slider among [editor]'s layers above every other
/// layer, upright and locked ([pollLayerInteraction]), and inside
/// [pollSafeArea] of an export of [targetAspectRatio].
///
/// Each change is made to the current history step rather than adding one, so
/// undo goes back past the change that moved the poll. No history callback
/// fires for it, so [onChanged] is where a caller saves the history again.
void keepPollInPlace(
  ProImageEditorState editor, {
  required double? targetAspectRatio,
  required VoidCallback onChanged,
}) {
  if (_placePoll(editor, targetAspectRatio)) onChanged();
}

/// Whether [keepPollInPlace] had anything to correct.
bool _placePoll(ProImageEditorState editor, double? targetAspectRatio) {
  var changed = false;
  final layers = editor.activeLayers;
  final below = pollLayerIndexBelowTop(layers);
  if (below != null) {
    editor.moveLayerListPosition(
      oldIndex: below,
      newIndex: layers.length - 1,
      skipUpdateHistory: true,
    );
    changed = true;
  }
  final index = layers.lastIndexWhere(isPollLayer);
  if (index < 0) return changed;
  final layer = layers[index];
  if (pollLayerNeedsLocking(layer)) {
    layer
      ..interaction = pollLayerInteraction()
      ..rotation = 0;
    editor.replaceLayer(index: index, layer: layer, skipUpdateHistory: true);
    changed = true;
  }
  final size = layer.keyInternalSize.currentContext?.size;
  if (size == null || targetAspectRatio == null) return changed;
  final fit = fitPollIntoSafeArea(
    offset: layer.offset,
    size: size,
    rotation: layer.rotation,
    bodySize: editor.sizesManager.bodySize,
    targetAspectRatio: targetAspectRatio,
  );
  if (fit == null) return changed;
  layer
    ..offset += fit.shift
    ..scale *= fit.scale;
  editor.replaceLayer(index: index, layer: layer, skipUpdateHistory: true);
  return true;
}

/// How to move and shrink a poll so it lies inside [pollSafeArea]: the shift
/// to add to its offset and the factor to scale it by, or `null` when it lies
/// inside already.
///
/// The poll stands [size] big, turned by [rotation], with its centre
/// [offset] from the centre of an editor body of [bodySize], which an export
/// of [targetAspectRatio] crops to its frame.
({Offset shift, double scale})? fitPollIntoSafeArea({
  required Offset offset,
  required Size size,
  required double rotation,
  required Size bodySize,
  required double targetAspectRatio,
}) {
  if (size.isEmpty || bodySize.isEmpty) return null;
  final safe = pollSafeRect(
    bodySize: bodySize,
    targetAspectRatio: targetAspectRatio,
  );
  // The box the turned poll covers.
  final cos = math.cos(rotation).abs();
  final sin = math.sin(rotation).abs();
  final bounds = Rect.fromCenter(
    center: bodySize.center(Offset.zero) + offset,
    width: size.width * cos + size.height * sin,
    height: size.width * sin + size.height * cos,
  );
  // Half a unit of slack, so a poll put on the edge stays where it is.
  if (safe.inflate(0.5).contains(bounds.topLeft) &&
      safe.inflate(0.5).contains(bounds.bottomRight)) {
    return null;
  }
  final scale = math.min(
    1.0,
    math.min(safe.width / bounds.width, safe.height / bounds.height),
  );
  final shrunk = Rect.fromCenter(
    center: bounds.center,
    width: bounds.width * scale,
    height: bounds.height * scale,
  );
  double into(double low, double high, double min, double max) => low < min
      ? min - low
      : high > max
      ? max - high
      : 0;
  return (
    shift: Offset(
      into(shrunk.left, shrunk.right, safe.left, safe.right),
      into(shrunk.top, shrunk.bottom, safe.top, safe.bottom),
    ),
    scale: scale,
  );
}
