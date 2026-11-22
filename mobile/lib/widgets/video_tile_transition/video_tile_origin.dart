// ABOUTME: The grid tile a fullscreen video was opened from, so the player
// ABOUTME: can grow out of the tile and shrink back into it on close.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/video_feed_item/blurred_video_backdrop.dart';
import 'package:openvine/widgets/video_tile_transition/rounded_by_clips.dart';

/// Marks the thumbnail a fullscreen player grows out of.
///
/// [VideoTileOrigin.capture] looks for this widget under the tapped tile, and
/// takes the tile's image and bounds from it.
class VideoTileThumbnailBoundary extends StatelessWidget {
  /// Wraps [child], the tile's thumbnail.
  const VideoTileThumbnailBoundary({required this.child, super.key});

  /// The thumbnail.
  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: child);
}

/// Marks the scrim a grid tile darkens the bottom of its thumbnail with, so
/// the player's own scrim can grow out of it.
///
/// The scrim fades from clear at its top to [opacity] of black at its bottom.
class VideoTileScrimBoundary extends StatelessWidget {
  /// Marks [child], the scrim.
  const VideoTileScrimBoundary({
    required this.opacity,
    required this.child,
    super.key,
  });

  /// How dark the scrim is at its bottom edge.
  final double opacity;

  /// The scrim.
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Where a fullscreen video was opened from.
///
/// Holds the tapped thumbnail's render objects rather than a fixed rect, so
/// the close transition aims at wherever the tile is when the player is
/// popped.
class VideoTileOrigin {
  VideoTileOrigin._({
    required this.videoId,
    required this.borderRadius,
    required this.letterboxAspectRatio,
    required RenderRepaintBoundary boundary,
    required RenderImage? image,
    required RenderBox? scrim,
    required this.scrimOpacity,
  }) : _boundary = boundary,
       _image = image,
       _scrim = scrim,
       alignment = image == null
           ? Alignment.center
           : image.alignment.resolve(image.textDirection);

  /// Captures a laid-out video tile using the player's fit for [video].
  static VideoTileOrigin? captureVideo(
    BuildContext tileContext,
    VideoEvent video, {
    BorderRadiusGeometry borderRadius = const BorderRadius.all(
      Radius.circular(4),
    ),
  }) => capture(
    tileContext,
    videoId: video.id,
    borderRadius: borderRadius,
    letterboxAspectRatio: fullscreenFeedLetterboxAspectRatio(
      video.width,
      video.height,
    ),
  );

  /// The origin of the tile under [tileContext] showing [videoId], or `null`
  /// when the tile holds no laid-out [VideoTileThumbnailBoundary], or when the
  /// platform asks for reduced motion: without an origin the player opens
  /// with the plain page transition instead of growing out of the tile.
  ///
  /// Also keeps what the tile shows, for [takeImage]: the decoded thumbnail
  /// when it has loaded, so the player can grow it into a frame of another
  /// shape without losing what the tile cropped away, or else a snapshot of
  /// the tile. That happens here, on the tap: by the time the player's first
  /// frame builds, the push may already have marked the tile for repaint, and
  /// an unpainted tile cannot be read.
  ///
  /// [borderRadius] is the tile's corners, resolved against the tile's text
  /// direction.
  static VideoTileOrigin? capture(
    BuildContext tileContext, {
    required String videoId,
    double? letterboxAspectRatio,
    BorderRadiusGeometry borderRadius = const BorderRadius.all(
      Radius.circular(4),
    ),
  }) {
    if (MediaQuery.maybeDisableAnimationsOf(tileContext) ?? false) return null;
    final boundaryElement = _findWidget<VideoTileThumbnailBoundary>(
      tileContext,
    );
    final boundary = boundaryElement?.findRenderObject();
    if (boundaryElement == null || boundary is! RenderRepaintBoundary) {
      return null;
    }
    final image = _findImage(boundary);
    final scrimElement = _findWidget<VideoTileScrimBoundary>(tileContext);
    final scrim = scrimElement?.findRenderObject();
    final origin = VideoTileOrigin._(
      videoId: videoId,
      borderRadius: borderRadius.resolve(Directionality.maybeOf(tileContext)),
      letterboxAspectRatio: letterboxAspectRatio,
      boundary: boundary,
      image: image,
      scrim: scrim is RenderBox ? scrim : null,
      scrimOpacity: switch (scrimElement?.widget) {
        VideoTileScrimBoundary(:final opacity) => opacity,
        _ => 0,
      },
    );
    if (origin.rect == null) return null;
    origin
      .._taken =
          origin.readImage() ??
          origin._snapshot(
            pixelRatio: MediaQuery.devicePixelRatioOf(tileContext),
          )
      .._playerSizeImage = _loadPlayerSize(tileContext, boundaryElement, image);
    return origin;
  }

  /// The video the tile shows.
  final String videoId;

  /// The tile's corners, which the transition starts from.
  final BorderRadius borderRadius;

  /// The aspect ratio the player will letterbox the video at, or `null` when
  /// it fills the screen.
  ///
  /// Known from the video's dimensions on the tap, so the transition can aim
  /// at the right frame before the player has built the page that shows it.
  final double? letterboxAspectRatio;

  /// Where in [rect] the tile places its picture when cropping it, which
  /// drawing [takeImage] covering [rect] must match to reproduce the tile.
  ///
  /// Grid thumbnails keep the top of the frame, where faces usually are,
  /// rather than its middle. A snapshot is already the crop, so for one this
  /// is [Alignment.center].
  final Alignment alignment;

  /// How dark the tile's scrim is at its bottom edge, or 0 when it has none.
  final double scrimOpacity;

  final RenderRepaintBoundary _boundary;
  final RenderImage? _image;
  final RenderBox? _scrim;

  ui.Image? _taken;

  ImageStream? _playerSizeImage;

  /// The tile's thumbnail decoded at the size the player shows it, loading
  /// from the tap, or `null` when the tile's own decode is already that size.
  ///
  /// Grid tiles decode their thumbnails at the tile's size, to keep many in
  /// the image cache. Grown to the player's size, that decode is visibly
  /// softer than the video, which shows where the picture hands over to it.
  /// The source is read from the cache the tile loaded it through, and the
  /// decode is capped at the screen's size.
  ImageStream? get playerSizeImage => _playerSizeImage;

  /// Where the tile's picture is now, in global coordinates, or `null` once
  /// the tile is no longer laid out. A tile scrolled out of view but still
  /// built keeps its rect, off screen.
  ///
  /// A decoded thumbnail fitted with `BoxFit.cover` fills the tile; one
  /// fitted to `contain` is only the part it paints. Drawing [takeImage]
  /// covering this rect at [alignment] reproduces the tile.
  Rect? get rect {
    if (!_boundary.attached || !_boundary.hasSize) return null;
    final tile = _boundary.localToGlobal(Offset.zero) & _boundary.size;
    final image = _liveImage;
    final decoded = image?.image;
    if (image == null || decoded == null || !image.hasSize) return tile;
    final box = image.localToGlobal(Offset.zero) & image.size;
    final fitted = applyBoxFit(
      image.fit ?? BoxFit.scaleDown,
      Size(decoded.width.toDouble(), decoded.height.toDouble()),
      box.size,
    ).destination;
    final painted = image.alignment
        .resolve(image.textDirection)
        .inscribe(fitted, box);
    return painted.intersect(tile);
  }

  /// The part of the screen the tile can be seen in now, in global
  /// coordinates, or `null` when the tile is in no scrolling view, which
  /// leaves the whole screen, or is no longer laid out.
  ///
  /// This is where the scrolling views around the tile show their content,
  /// which ends where bars around the grid, such as the bottom navigation,
  /// begin, and within the rounded clips around those views, such as a
  /// panel's: a corner that sits in a clip's corner is rounded like it.
  /// Clips inside the scrolling content, such as the tile's own, scroll with
  /// it and play no part.
  RRect? get visibleBounds {
    if (!_boundary.attached || !_boundary.hasSize) return null;
    Rect? shown;
    final clips = <RenderClipRRect>[];
    for (
      RenderObject? node = _boundary.parent;
      node != null;
      node = node.parent
    ) {
      if (node is! RenderBox || !node.hasSize) continue;
      final Rect bounds = node.localToGlobal(Offset.zero) & node.size;
      if (node is RenderAbstractViewport) {
        shown = shown?.intersect(bounds) ?? bounds;
      } else if (shown != null && node is RenderClipRRect) {
        clips.add(node);
        shown = shown.intersect(bounds);
      }
    }
    if (shown == null) return null;
    return roundedByClips(shown, clips);
  }

  /// Where the tile's bottom scrim is on screen now, in global coordinates,
  /// or `null` when the tile has none or is no longer laid out.
  Rect? get scrimRect {
    final scrim = _scrim;
    if (scrim == null || !scrim.attached || !scrim.hasSize) return null;
    return scrim.localToGlobal(Offset.zero) & scrim.size;
  }

  /// The tile's picture as it was tapped, or `null` when it could not be read
  /// or was already taken. The caller owns the image and must dispose it.
  ui.Image? takeImage() {
    final image = _taken;
    _taken = null;
    return image;
  }

  /// A copy of the decoded thumbnail the tile shows now, or `null` when it
  /// shows none or is no longer laid out. The caller owns the image and must
  /// dispose it.
  ui.Image? readImage() => _liveImage?.image?.clone();

  RenderImage? get _liveImage {
    final image = _image;
    return image != null && image.attached ? image : null;
  }

  ui.Image? _snapshot({required double pixelRatio}) {
    var painted = true;
    assert(() {
      painted = !_boundary.debugNeedsPaint;
      return true;
    }(), 'debugNeedsPaint is only readable in debug builds');
    if (!painted) return null;
    try {
      return _boundary.toImageSync(pixelRatio: pixelRatio);
    } on Object {
      // The picture is decoration: without one only the page appears.
      return null;
    }
  }

  static Element? _findWidget<T extends Widget>(BuildContext context) {
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      if (element.widget is T) {
        found = element;
        return;
      }
      element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  /// Starts decoding [image]'s source at the size covering the screen when
  /// the tile shows it resized smaller than that.
  static ImageStream? _loadPlayerSize(
    BuildContext context,
    Element boundary,
    RenderImage? image,
  ) {
    final decoded = image?.image;
    final screen = MediaQuery.maybeSizeOf(context);
    if (image == null || decoded == null || screen == null) return null;
    final source = _resizedSourceOf(boundary, image);
    if (source == null) return null;
    final aspectRatio = decoded.width / decoded.height;
    final width =
        (math.max(screen.width, screen.height * aspectRatio) *
                MediaQuery.devicePixelRatioOf(context))
            .ceil();
    if (width <= decoded.width) return null;
    // Never upscales: a source narrower than this decodes at its own size.
    return ResizeImage(
      source,
      width: width,
    ).resolve(createLocalImageConfiguration(context));
  }

  /// The provider [image] was resized from, when the [Image] that painted it
  /// decoded a [ResizeImage].
  static ImageProvider<Object>? _resizedSourceOf(
    Element boundary,
    RenderImage image,
  ) {
    ImageProvider<Object>? provider;
    void visit(Element element) {
      if (provider != null) return;
      if (element is RenderObjectElement &&
          identical(element.renderObject, image)) {
        element.visitAncestorElements((ancestor) {
          final widget = ancestor.widget;
          if (widget is Image) {
            provider = widget.image;
            return false;
          }
          return !identical(ancestor, boundary);
        });
        return;
      }
      element.visitChildElements(visit);
    }

    boundary.visitChildElements(visit);
    final resized = provider;
    return resized is ResizeImage ? resized.imageProvider : null;
  }

  /// The last decoded image painted under [boundary]: a thumbnail stacked
  /// over its blurhash paints after it.
  static RenderImage? _findImage(RenderObject boundary) {
    RenderImage? found;
    void visit(RenderObject child) {
      if (child is RenderImage && child.image != null) found = child;
      child.visitChildren(visit);
    }

    boundary.visitChildren(visit);
    return found;
  }

  @override
  String toString() => 'VideoTileOrigin($videoId, $rect)';
}
