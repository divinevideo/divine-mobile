// ABOUTME: Decides whether the feed fills its viewport with each video or shows
// ABOUTME: the whole video, and where the video frame sits inside the viewport

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:openvine/ui/adaptive_layout.dart';
import 'package:openvine/widgets/video_feed_item/video_sticker_tap_areas.dart';

/// Whether the feed fills its viewport with its videos: the
/// `shouldPortraitExpand` the players, placeholders, error overlays and
/// sticker areas share.
///
/// In a phone-sized window, taller than wide and narrower than
/// [AdaptiveBreakpoints.large], filling crops a little off a vertical video
/// and the feed keeps doing so: on phones, and on the iPhone Duo folded. With
/// [largeScreenLayout] on, any larger or landscape [window] shows the whole
/// video on a blurred backdrop instead: there, filling cut a quarter of a
/// vertical video's height, including heads and the text and stickers near
/// its top and bottom edges.
///
/// Decided from the window rather than the feed's own viewport, so the feed
/// is laid out the way it always was, with no layout-time rebuild.
bool feedFillsViewport({
  required bool shouldPortraitExpand,
  required bool largeScreenLayout,
  required Size window,
}) {
  if (!shouldPortraitExpand || !largeScreenLayout) return shouldPortraitExpand;
  if (window.isEmpty || !window.isFinite) return true;
  return window.width < AdaptiveBreakpoints.large &&
      window.height >= window.width;
}

/// Lays [child] out over the frame of a video of [videoAspectRatio], so the
/// feed's action column and caption sit at the video's edges, not the
/// viewport's.
///
/// Only narrows [child] where the feed shows the whole video
/// ([shouldPortraitExpand] off) and the frame is narrower than the viewport;
/// never below [minWidth], so the caption and the action column keep room.
/// Everywhere else [child] fills the viewport as before.
class FeedVideoFrameBounds extends StatelessWidget {
  const FeedVideoFrameBounds({
    required this.videoAspectRatio,
    required this.shouldPortraitExpand,
    required this.child,
    this.minWidth = 360,
    super.key,
  });

  /// The video's width / height, or null when its dimensions are unknown.
  final double? videoAspectRatio;

  /// Whether the feed fills the viewport with the video (see
  /// [feedFillsViewport]).
  final bool shouldPortraitExpand;

  /// The narrowest width [child] is given.
  final double minWidth;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = videoAspectRatio;
    if (shouldPortraitExpand ||
        aspectRatio == null ||
        aspectRatio <= 0 ||
        !AdaptiveLayoutScope.isEnabledOf(context)) {
      return child;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!size.isFinite || size.isEmpty) return child;
        final frame = videoFrameRect(
          aspectRatio,
          size,
          shouldPortraitExpand: false,
        );
        final width = math.min(size.width, math.max(frame.width, minWidth));
        if (width >= size.width) return child;
        return Center(
          child: SizedBox(width: width, height: size.height, child: child),
        );
      },
    );
  }
}
