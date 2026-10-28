// ABOUTME: Folds the image layers one editor layer exports as, one per image
// ABOUTME: shown after the other, into one layer that plays them in sequence.

import 'package:pro_video_editor/pro_video_editor.dart'
    show ImageLayer, ImageLayerFrame;

/// The image layers [parts] of one editor layer — one for each image it
/// shows, each starting where the one before ends — as one layer that plays
/// them as a frame sequence.
///
/// A text that types itself out, reveals word by word or lights its words up
/// one at a time exports an image for every step. Android draws every layer
/// with its own time range as a pass over the whole picture, so a long
/// typewriter text made the export crawl; a sequence is one overlay that
/// swaps its image.
///
/// Every frame lasts from its part's start until the next part starts, and
/// the last one holds until the last part ends. Where and how the frames are
/// drawn comes from the first part, which all parts share.
ImageLayer imageLayerSequence(List<ImageLayer> parts) {
  final first = parts.first;
  final frames = <ImageLayerFrame>[];
  for (final (index, part) in parts.indexed) {
    final duration = index < parts.length - 1
        ? (parts[index + 1].startTime ?? Duration.zero) -
              (part.startTime ?? Duration.zero)
        : _lastFrameDuration;
    // A step squeezed to nothing by the output timeline never shows.
    if (duration <= Duration.zero) continue;
    frames.add(ImageLayerFrame(image: part.image, duration: duration));
  }
  return ImageLayer.sequence(
    frames: frames,
    startTime: first.startTime,
    endTime: parts.last.endTime,
    offset: first.offset,
    size: first.size,
    rotation: first.rotation,
    // The last frame holds until the layer ends.
    loop: false,
    animations: first.animations,
    animationStartTime: first.animationStartTime,
    animationEndTime: first.animationEndTime,
    keyframes: first.keyframes,
    keyframeClock: first.keyframeClock,
    blendMode: first.blendMode,
    shapeMask: first.shapeMask,
  );
}

/// How long the last frame of a sequence lasts; it holds until the layer
/// ends anyway, as the sequence does not loop.
const _lastFrameDuration = Duration(seconds: 1);
