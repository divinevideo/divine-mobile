// ABOUTME: Marks where a fullscreen player shows a video, so a grid tile's
// ABOUTME: picture can fly to exactly that frame when the player opens.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/widgets/video_feed_item/blurred_video_backdrop.dart';

/// Where a player letterboxing a video at [aspectRatio] draws it in
/// [viewport]: fitted inside it and centered, or the whole [viewport] when
/// [aspectRatio] is `null` because the video fills it.
Rect letterboxedVideoRect(Rect viewport, double? aspectRatio) {
  if (aspectRatio == null || aspectRatio <= 0) return viewport;
  return letterboxVideoRect(
    aspectRatio,
    viewport.size,
  ).shift(viewport.topLeft);
}

/// Wraps one page of a fullscreen video feed and reports where its video is
/// drawn, for a [VideoTileTransitionScope] above it.
///
/// The page decides the frame, not the transition: a video that
/// [coversViewport] fills the page, any other is fitted inside it at its
/// [aspectRatio], centered, the way the player letterboxes it. A corner of
/// the frame that sits in the corner of a rounded clip around the page, such
/// as the feed's rounded bottom, takes that clip's radius.
class VideoTileTransitionTarget extends StatefulWidget {
  /// Marks [child] as the page showing [videoId].
  const VideoTileTransitionTarget({
    required this.videoId,
    required this.aspectRatio,
    required this.coversViewport,
    required this.child,
    super.key,
  });

  /// The video the page shows.
  final String videoId;

  /// The video's width over its height, or `null` when it is unknown and the
  /// video fills the page.
  final double? aspectRatio;

  /// Whether the video is cropped to fill the page rather than letterboxed.
  final bool coversViewport;

  /// The page.
  final Widget child;

  @override
  State<VideoTileTransitionTarget> createState() =>
      _VideoTileTransitionTargetState();
}

class _VideoTileTransitionTargetState extends State<VideoTileTransitionTarget> {
  VideoTileTransitionTargets? _targets;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final targets = context
        .dependOnInheritedWidgetOfExactType<VideoTileTransitionScope>()
        ?.targets;
    if (identical(targets, _targets)) return;
    _targets?._unregister(widget.videoId, this);
    _targets = targets?.._register(widget.videoId, this);
  }

  @override
  void didUpdateWidget(VideoTileTransitionTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId == widget.videoId) return;
    _targets?._unregister(oldWidget.videoId, this);
    _targets?._register(widget.videoId, this);
  }

  @override
  void dispose() {
    _targets?._unregister(widget.videoId, this);
    super.dispose();
  }

  /// Where the video is drawn, with the corners it is clipped to, in
  /// [ancestor]'s coordinates, or `null` before the page is laid out.
  RRect? mediaShapeIn(RenderBox ancestor) {
    final page = context.findRenderObject();
    if (page is! RenderBox || !page.attached || !page.hasSize) return null;
    if (!ancestor.attached) return null;
    final viewport = MatrixUtils.transformRect(
      page.getTransformTo(ancestor),
      Offset.zero & page.size,
    );
    final media = letterboxedVideoRect(
      viewport,
      widget.coversViewport ? null : widget.aspectRatio,
    );
    return _roundedByClips(media, page, ancestor);
  }

  /// [media] with each corner that sits in the corner of a rounded clip
  /// above [page], up to and including [ancestor], rounded like that clip.
  static RRect _roundedByClips(
    Rect media,
    RenderObject page,
    RenderBox ancestor,
  ) {
    var topLeft = Radius.zero;
    var topRight = Radius.zero;
    var bottomLeft = Radius.zero;
    var bottomRight = Radius.zero;
    bool meets(Offset a, Offset b) => (a - b).distance < 0.5;
    // The ancestor itself can be the clip: it is the page's first render
    // object, which is whatever the page puts outermost.
    for (
      RenderObject? node = page.parent;
      node != null;
      node = identical(node, ancestor) ? null : node.parent
    ) {
      // A custom clipper's shape is not its border radius.
      if (node is! RenderClipRRect || node.clipper != null || !node.hasSize) {
        continue;
      }
      final clip = MatrixUtils.transformRect(
        node.getTransformTo(ancestor),
        Offset.zero & node.size,
      );
      final radius = node.borderRadius.resolve(node.textDirection);
      if (topLeft == Radius.zero && meets(media.topLeft, clip.topLeft)) {
        topLeft = radius.topLeft;
      }
      if (topRight == Radius.zero && meets(media.topRight, clip.topRight)) {
        topRight = radius.topRight;
      }
      if (bottomLeft == Radius.zero &&
          meets(media.bottomLeft, clip.bottomLeft)) {
        bottomLeft = radius.bottomLeft;
      }
      if (bottomRight == Radius.zero &&
          meets(media.bottomRight, clip.bottomRight)) {
        bottomRight = radius.bottomRight;
      }
    }
    return RRect.fromRectAndCorners(
      media,
      topLeft: topLeft,
      topRight: topRight,
      bottomLeft: bottomLeft,
      bottomRight: bottomRight,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The [VideoTileTransitionTarget]s below a [VideoTileTransitionScope], so a
/// route transition can find where its page will show a video.
class VideoTileTransitionTargets {
  // More than one target can show a video at once: the feed stacks a loading
  // layer and the video layer for the same page, and when the loading layer
  // goes the framework may keep its element for the video layer and dispose
  // the other one. Keeping only the last one registered lost the video
  // mid-flight whenever that happened.
  final _targets = <String, Set<_VideoTileTransitionTargetState>>{};

  /// Where the page shows [videoId], with the corners it clips it to, in
  /// [ancestor]'s coordinates, or `null` when it does not show it yet.
  RRect? mediaShapeOf(String videoId, RenderBox ancestor) {
    for (final target
        in _targets[videoId] ?? const <_VideoTileTransitionTargetState>{}) {
      final shape = target.mediaShapeIn(ancestor);
      if (shape != null) return shape;
    }
    return null;
  }

  void _register(String videoId, _VideoTileTransitionTargetState target) =>
      (_targets[videoId] ??= {}).add(target);

  void _unregister(String videoId, _VideoTileTransitionTargetState target) {
    final targets = _targets[videoId];
    if (targets == null) return;
    targets.remove(target);
    if (targets.isEmpty) _targets.remove(videoId);
  }
}

/// Hands [targets] to the [VideoTileTransitionTarget]s in [child], and tells
/// the page in [child] whether a tile's picture is flying over it.
class VideoTileTransitionScope
    extends InheritedNotifier<ValueListenable<bool>> {
  /// Collects the targets in [child] into [targets]; [landed] is whether the
  /// picture has handed over to the page.
  const VideoTileTransitionScope({
    required this.targets,
    required ValueListenable<bool> landed,
    required super.child,
    super.key,
  }) : super(notifier: landed);

  /// Where the targets register.
  final VideoTileTransitionTargets targets;

  /// Whether the page in [context] is free to play and show its controls:
  /// `false` while a tile's picture flies over it, on the way in or out, and
  /// `true` once it has landed or when no picture flies at all.
  ///
  /// Holding playback until the picture lands lets it hand over to the
  /// video's first frame rather than to a frame further on, and holding the
  /// controls lets them fade in over the video instead of appearing at once
  /// from under the picture.
  static bool hasLandedOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<VideoTileTransitionScope>()
          ?.notifier
          ?.value ??
      true;

  @override
  bool updateShouldNotify(VideoTileTransitionScope oldWidget) =>
      super.updateShouldNotify(oldWidget) ||
      !identical(targets, oldWidget.targets);
}
