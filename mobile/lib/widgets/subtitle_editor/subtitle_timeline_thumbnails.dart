// ABOUTME: Filmstrip ribbon under the subtitle editor's ruler, showing the
// ABOUTME: video's frames so cues can be timed against what is on screen.

import 'dart:io';
import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/subtitle_editor/timeline_frame.dart';

/// The video's frames laid out along the timeline axis.
///
/// Renders whatever [thumbnails] holds right now — extraction streams
/// progressively denser batches, so the ribbon fills in rather than waiting
/// for a complete strip. Falls back to a plain surface while empty.
class SubtitleTimelineThumbnails extends StatelessWidget {
  /// Creates the ribbon.
  const SubtitleTimelineThumbnails({
    required this.thumbnails,
    required this.width,
    required this.totalDuration,
    super.key,
  });

  /// Frames extracted so far, in ascending timestamp order.
  final ValueListenable<List<TimelineFrame>> thumbnails;

  /// Width of the timeline axis in pixels.
  final double width;

  /// Length of the timeline axis.
  final Duration totalDuration;

  @override
  Widget build(BuildContext context) {
    final slotCount = math.max(
      1,
      (width / TimelineConstants.thumbnailWidth).ceil(),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(TimelineConstants.thumbnailRadius),
      child: SizedBox(
        width: width,
        height: TimelineConstants.thumbnailStripHeight,
        child: ColoredBox(
          color: context.vineColors.surfaceContainer,
          child: ValueListenableBuilder<List<TimelineFrame>>(
            valueListenable: thumbnails,
            builder: (context, frames, _) {
              if (frames.isEmpty) return const SizedBox.expand();
              // Every frame keeps its full width and the row is clipped at
              // the axis end, so the last one is cut off mid-frame instead of
              // being squeezed narrower than the rest.
              return OverflowBox(
                alignment: AlignmentDirectional.centerStart,
                maxWidth: slotCount * TimelineConstants.thumbnailWidth,
                child: Row(
                  children: [
                    for (var slot = 0; slot < slotCount; slot++)
                      SizedBox(
                        width: TimelineConstants.thumbnailWidth,
                        child: _Frame(
                          frame: _frameForSlot(frames, slot, slotCount),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The extracted frame closest to the middle of [slot].
  ///
  /// Slots outnumber frames until extraction finishes, so neighbouring slots
  /// legitimately share a frame; the ribbon sharpens as denser batches land.
  TimelineFrame _frameForSlot(
    List<TimelineFrame> frames,
    int slot,
    int slotCount,
  ) {
    if (width <= 0) return frames.first;
    final slotCenterPx = math.min(
      (slot + 0.5) * TimelineConstants.thumbnailWidth,
      width,
    );
    final targetMs = slotCenterPx / width * totalDuration.inMilliseconds;
    var best = frames.first;
    var bestDistance = (best.timestamp.inMilliseconds - targetMs).abs();
    for (final frame in frames.skip(1)) {
      final distance = (frame.timestamp.inMilliseconds - targetMs).abs();
      if (distance >= bestDistance) continue;
      best = frame;
      bestDistance = distance;
    }
    return best;
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.frame});

  final TimelineFrame frame;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(frame.path),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      // Frames are swapped as denser batches arrive; without this the slot
      // blanks for a frame on every swap.
      gaplessPlayback: true,
      errorBuilder: (context, _, _) =>
          ColoredBox(color: context.vineColors.surfaceContainer),
    );
  }
}
