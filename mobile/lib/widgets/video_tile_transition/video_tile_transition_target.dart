// ABOUTME: Marks where a fullscreen player shows a video, so a grid tile's
// ABOUTME: picture can fly to exactly that frame, and back from it on close.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/widgets/video_feed_item/blurred_video_backdrop.dart';
import 'package:openvine/widgets/video_tile_transition/rounded_by_clips.dart';

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

/// Where a fullscreen player shows a video, in some ancestor's coordinates.
@immutable
class VideoTileLanding {
  /// The frame showing the video, inside [page].
  const VideoTileLanding({required this.media, required this.page});

  /// Where the video is drawn, with the corners it is clipped to.
  final RRect media;

  /// The page the video is drawn on, with its corners: the controls over the
  /// video are laid out across it.
  final RRect page;

  /// This landing moved by [offset].
  VideoTileLanding shift(Offset offset) =>
      VideoTileLanding(media: media.shift(offset), page: page.shift(offset));
}

/// Wraps one page of a fullscreen video feed and reports where its video is
/// drawn, for a [VideoTileTransitionScope] above it.
///
/// The page decides the frame, not the transition: a video that
/// [coversViewport] fills the page, any other is fitted inside it at its
/// [aspectRatio], centered, the way the player letterboxes it. A corner of
/// the frame that sits in the corner of a rounded clip around the page, such
/// as the feed's rounded bottom, takes that clip's radius.
///
/// A target that [showsVideo] can also be read, so the picture flying back
/// into the tile on close starts as the page the player was showing.
class VideoTileTransitionTarget extends StatefulWidget {
  /// Marks [child] as the page showing [videoId].
  const VideoTileTransitionTarget({
    required this.videoId,
    required this.aspectRatio,
    required this.coversViewport,
    required this.child,
    this.showsVideo = false,
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

  /// Whether [child] draws the video itself, rather than a poster standing in
  /// for it while it loads.
  final bool showsVideo;

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

  /// Where the video and its page are drawn, with the corners they are
  /// clipped to, in [ancestor]'s coordinates, or `null` before the page is
  /// laid out.
  VideoTileLanding? landingIn(RenderBox ancestor) {
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
    return VideoTileLanding(
      media: _roundedByClips(media, page, ancestor),
      page: _roundedByClips(viewport, page, ancestor),
    );
  }

  /// [rect] with each corner that sits in the corner of a rounded clip
  /// above [page], up to and including [ancestor], rounded like that clip.
  static RRect _roundedByClips(
    Rect rect,
    RenderObject page,
    RenderBox ancestor,
  ) {
    final clips = <RenderClipRRect>[];
    // The ancestor itself can be the clip: it is the page's first render
    // object, which is whatever the page puts outermost.
    for (
      RenderObject? node = page.parent;
      node != null;
      node = identical(node, ancestor) ? null : node.parent
    ) {
      if (node is RenderClipRRect) clips.add(node);
    }
    return roundedByClips(rect, clips, ancestor: ancestor);
  }

  /// The page as it is drawn now, at [pixelRatio], or `null` when it does
  /// not draw the video or has not painted it. The caller owns the image and
  /// must dispose it.
  ui.Image? readPage({required double pixelRatio}) {
    final page = context.findRenderObject();
    if (!widget.showsVideo ||
        page is! RenderRepaintBoundary ||
        !page.attached ||
        !page.hasSize) {
      return null;
    }
    var painted = true;
    assert(() {
      painted = !page.debugNeedsPaint;
      return true;
    }(), 'debugNeedsPaint is only readable in debug builds');
    if (!painted) return null;
    try {
      return page.toImageSync(pixelRatio: pixelRatio);
    } on Object {
      // The picture is decoration: without it the tile's own picture flies.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showsVideo) return widget.child;
    return RepaintBoundary(child: widget.child);
  }
}

/// The [VideoTileTransitionTarget]s below a [VideoTileTransitionScope], so a
/// route transition can find where its page will show a video.
class VideoTileTransitionTargets {
  // More than one target can show a video at once: the feed stacks a loading
  // layer and the video layer for the same page. Unkeyed, the framework may
  // hand one's element to the other and dispose the second as the loading
  // layer goes, which lost the video mid-flight when only the last target
  // registered was kept.
  final _targets = <String, Set<_VideoTileTransitionTargetState>>{};

  /// Where the page shows [videoId], in [ancestor]'s coordinates, or `null`
  /// when it does not show it yet.
  VideoTileLanding? landingOf(String videoId, RenderBox ancestor) {
    for (final target
        in _targets[videoId] ?? const <_VideoTileTransitionTargetState>{}) {
      final landing = target.landingIn(ancestor);
      if (landing != null) return landing;
    }
    return null;
  }

  /// The page drawing [videoId] as it is drawn now, at [pixelRatio], or
  /// `null` while the page does not draw the video itself, such as while a
  /// poster stands in for it. The caller owns the image and must dispose it.
  ui.Image? readPageOf(String videoId, {required double pixelRatio}) {
    final targets =
        _targets[videoId] ?? const <_VideoTileTransitionTargetState>{};
    // A poster standing in means the video has no frame to show yet.
    if (targets.any((target) => !target.widget.showsVideo)) return null;
    for (final target in targets) {
      final page = target.readPage(pixelRatio: pixelRatio);
      if (page != null) return page;
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

/// Where the page's controls are drawn in one frame of a tile's picture
/// flying over it.
@immutable
class VideoTileFlightFrame {
  /// A frame of the flight.
  const VideoTileFlightFrame({
    required this.transform,
    required this.clip,
    required this.bounds,
    required this.opacity,
  });

  /// Maps where the page lays its controls out, in global coordinates, to
  /// where they are drawn now: the transform that also places the flying
  /// picture's image, so the controls stay over the same part of it.
  final Matrix4 transform;

  /// What of the page shows now, in global coordinates: growing from the
  /// tile to the page.
  final RRect clip;

  /// Where anything flying may be drawn now, in global coordinates, with its
  /// corners: growing from where the tile can be seen to the page, so bars
  /// and rounded panels around the grid, such as the bottom navigation, stay
  /// over the flight.
  final RRect bounds;

  /// How far the controls have faded in.
  final double opacity;
}

/// How far a tile's picture flying over a page has got.
enum VideoTileFlightPhase {
  /// The picture is on its way: the page holds its playback and controls.
  flying,

  /// The picture covers the page while it plays beneath: the picture is
  /// about to land, so the video is moving by the time it is uncovered, or is
  /// being dragged back, so the video goes on if the drag is let go. The page
  /// still holds its controls.
  arriving,

  /// The picture has handed over to the page, or no picture flies.
  landed,
}

/// Hands [targets] to the [VideoTileTransitionTarget]s in [child], and tells
/// the page in [child] how far a tile's picture flying over it has got.
class VideoTileTransitionScope
    extends InheritedNotifier<ValueListenable<VideoTileFlightPhase>> {
  /// Collects the targets in [child] into [targets]; [phase] is how far the
  /// picture has got, and [flight] where the page's controls fly with it.
  const VideoTileTransitionScope({
    required this.targets,
    required ValueListenable<VideoTileFlightPhase> phase,
    required this.flight,
    required super.child,
    super.key,
  }) : super(notifier: phase);

  /// Where the targets register.
  final VideoTileTransitionTargets targets;

  /// The current frame of the flight, or `null` while no picture flies.
  final ValueListenable<VideoTileFlightFrame?> flight;

  /// The flight the page in [context] takes part in, or `null` outside a
  /// tile transition. Reading it does not rebuild [context] when a frame
  /// changes; listen to it for that.
  static ValueListenable<VideoTileFlightFrame?>? flightOf(
    BuildContext context,
  ) =>
      context.getInheritedWidgetOfExactType<VideoTileTransitionScope>()?.flight;

  static VideoTileFlightPhase _phaseOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<VideoTileTransitionScope>()
          ?.notifier
          ?.value ??
      VideoTileFlightPhase.landed;

  /// Whether the page in [context] is free to play: `false` while a tile's
  /// picture flies over it, on the way in or out, until it is about to land.
  ///
  /// The player takes a moment to start moving once asked to play, so
  /// starting just before the picture lands, hidden beneath it, uncovers a
  /// video that is already moving from near its first frame.
  static bool mayPlayOf(BuildContext context) =>
      _phaseOf(context) != VideoTileFlightPhase.flying;

  /// Whether the page in [context] is free to show its controls: `false`
  /// while a tile's picture flies over it, on the way in or out, and `true`
  /// once it has landed or when no picture flies at all.
  ///
  /// Holding the controls lets their copy flying with the picture hand over
  /// to them in the same place.
  static bool hasLandedOf(BuildContext context) =>
      _phaseOf(context) == VideoTileFlightPhase.landed;

  @override
  bool updateShouldNotify(VideoTileTransitionScope oldWidget) =>
      super.updateShouldNotify(oldWidget) ||
      !identical(targets, oldWidget.targets) ||
      !identical(flight, oldWidget.flight);
}

/// Marks the copy of the page's controls that flies with a tile's picture.
///
/// The transition draws the picture's scrims itself, between the picture and
/// the controls, so a control that carries its own scrim leaves it out here.
class VideoTileFlightCopy extends InheritedWidget {
  /// Marks [child] as flying.
  const VideoTileFlightCopy({required super.child, super.key});

  /// Whether [context] is in the flying copy of the controls.
  static bool isIn(BuildContext context) =>
      context.getInheritedWidgetOfExactType<VideoTileFlightCopy>() != null;

  @override
  bool updateShouldNotify(VideoTileFlightCopy oldWidget) => false;
}
