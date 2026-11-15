// ABOUTME: Route transition that flies a grid tile's picture to where the
// ABOUTME: fullscreen player shows the video, and back into the tile on pop.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_origin.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_transition_target.dart';

/// Flies [origin]'s picture from its tile to the frame the page shows the
/// video in as [animation] runs forward, and back into the tile in reverse.
///
/// The page fades in as the picture flies, but only around the video, such
/// as its comment bar, and inside a clip growing from the tile to the page:
/// the player never shows behind the picture still on its way, and the page
/// is whole the moment the picture lands.
///
/// The frame is whatever the page's [VideoTileTransitionTarget] reports, so a
/// letterboxed square video lands on its letterboxed band rather than filling
/// the screen, and the picture's corners round into the frame's. Until the
/// page shows the video, the frame is predicted from
/// [VideoTileOrigin.letterboxAspectRatio]. The picture is drawn covering the
/// moving rect, which reproduces the tile's crop at one end and the player's
/// at the other: the crop's alignment moves from the tile's to the player's
/// centered one with the rect. When the tile has left the screen the picture
/// flies to the middle of the screen instead.
///
/// The picture starts as the tile's own decode and switches to
/// [VideoTileOrigin.playerSizeImage] once that has loaded, while it is still
/// small enough for the two to look alike. Closing flies the player-size one
/// too, as it starts out at the player's size.
///
/// The page's controls fly with the picture, fading in as it grows: each
/// [VideoTileFlightFrame] places them with the transform that places the
/// picture's image, so they stay over the same part of it. Between the
/// picture and the controls, the tile's bottom scrim grows into the player's,
/// and the player's top scrim darkens in.
///
/// Once the picture has landed, it is removed at once, uncovering the
/// player's own poster or video in the same place: fading it out would show
/// both pictures at once, doubling anything that has moved since the poster.
/// The page holds its playback and controls until then, through
/// [VideoTileTransitionScope], so the video starts from where the picture
/// shows it and the controls take over from their flying copy.
class VideoTileFlightTransition extends StatefulWidget {
  /// Creates the transition for one route.
  const VideoTileFlightTransition({
    required this.animation,
    required this.origin,
    required this.child,
    super.key,
  });

  /// The route's primary animation.
  final Animation<double> animation;

  /// The tile the picture flies out of.
  final VideoTileOrigin origin;

  /// The page.
  final Widget child;

  /// How long the picture takes to fly from the tile to the player.
  static const openDuration = Duration(milliseconds: 280);

  /// How long the picture takes to fly back into the tile on close.
  static const closeDuration = Duration(milliseconds: 250);

  @override
  State<VideoTileFlightTransition> createState() =>
      _VideoTileFlightTransitionState();
}

class _VideoTileFlightTransitionState extends State<VideoTileFlightTransition> {
  late final CurvedAnimation _motion = CurvedAnimation(
    parent: widget.animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  final _targets = VideoTileTransitionTargets();
  final GlobalKey _pageKey = GlobalKey();

  ui.Image? _picture;

  ImageStream? _playerSizeStream;
  ImageInfo? _playerSize;
  late final _playerSizeListener = ImageStreamListener(
    _onPlayerSize,
    onError: (error, stackTrace) {
      // The tile's own decode keeps flying: the sharper one is only a nicety.
    },
  );

  VideoTileLanding? _lastLanding;

  final _landed = ValueNotifier<bool>(false);

  final _flight = ValueNotifier<VideoTileFlightFrame?>(null);

  /// Whether the route has started opening. Its first frame can be built
  /// offstage, for hero measurement, with the animation standing in as
  /// complete, so a completed status alone does not mean it has opened.
  bool _hasOpened = false;

  @override
  void initState() {
    super.initState();
    _picture = widget.origin.takeImage();
    _playerSizeStream = widget.origin.playerSizeImage
      ?..addListener(_playerSizeListener);
    _hasOpened = widget.animation.status == AnimationStatus.forward;
    widget.animation.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
        _hasOpened = true;
      case AnimationStatus.completed when _hasOpened:
        setState(_releasePicture);
        _landed.value = true;
      case AnimationStatus.reverse:
        _landed.value = false;
        // Closing: fly what the tile shows now, which is where it lands,
        // unless the player-size decode has loaded.
        setState(() {
          _picture?.dispose();
          _picture = widget.origin.readImage();
        });
      case AnimationStatus.completed:
      case AnimationStatus.dismissed:
        break;
    }
  }

  void _onPlayerSize(ImageInfo image, bool synchronousCall) {
    setState(() {
      _playerSize?.dispose();
      _playerSize = image;
    });
  }

  void _releasePicture() {
    _picture?.dispose();
    _picture = null;
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    _motion.dispose();
    _landed.dispose();
    _flight.dispose();
    _releasePicture();
    _playerSizeStream?.removeListener(_playerSizeListener);
    _playerSize?.dispose();
    super.dispose();
  }

  /// Where the page shows the video, and the page itself, with their
  /// corners, in screen coordinates.
  ///
  /// Until the page has built the layer that shows the video, which can take
  /// a good part of the flight, the frame is predicted from the video's
  /// dimensions. Once found, it is kept while the page swaps the layers that
  /// show the video, rather than aiming elsewhere for those frames.
  VideoTileLanding _landing(Rect screen) {
    final page = _pageKey.currentContext?.findRenderObject();
    if (page is RenderBox && page.attached) {
      final landing = _targets.landingOf(widget.origin.videoId, page);
      if (landing != null) {
        _lastLanding = landing.shift(page.localToGlobal(Offset.zero));
      }
    }
    return _lastLanding ??
        VideoTileLanding(
          media: RRect.fromRectAndRadius(
            letterboxedVideoRect(screen, widget.origin.letterboxAspectRatio),
            Radius.zero,
          ),
          page: RRect.fromRectAndRadius(screen, Radius.zero),
        );
  }

  @override
  Widget build(BuildContext context) {
    final page = VideoTileTransitionScope(
      targets: _targets,
      landed: _landed,
      flight: _flight,
      child: KeyedSubtree(key: _pageKey, child: widget.child),
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: widget.animation, child: page);
    }
    return AnimatedBuilder(
      animation: _motion,
      child: page,
      builder: (context, page) {
        final progress = _motion.value;
        final screen = Offset.zero & MediaQuery.sizeOf(context);
        final from =
            widget.origin.rect ??
            Rect.fromCenter(
              center: screen.center,
              width: screen.width / 3,
              height: screen.height / 3,
            );
        final landing = _landing(screen);
        final media = landing.media.outerRect;
        final rect = Rect.lerp(from, media, progress)!;
        final borderRadius = BorderRadius.lerp(
          BorderRadius.circular(widget.origin.borderRadius),
          BorderRadius.only(
            topLeft: landing.media.tlRadius,
            topRight: landing.media.trRadius,
            bottomLeft: landing.media.blRadius,
            bottomRight: landing.media.brRadius,
          ),
          progress,
        )!;
        final alignment = Alignment.lerp(
          widget.origin.alignment,
          Alignment.center,
          progress,
        )!;
        final picture = _picture == null
            ? null
            : _playerSize?.image ?? _picture;
        final status = widget.animation.status;
        final flying =
            picture != null &&
            (status == AnimationStatus.forward ||
                status == AnimationStatus.reverse);
        final transform = contentTransform(
          content: picture == null
              ? media.size
              : Size(picture.width.toDouble(), picture.height.toDouble()),
          landing: media,
          rect: rect,
          alignment: alignment,
        );
        final clip = RRect.lerp(
          RRect.fromRectAndRadius(
            from,
            Radius.circular(widget.origin.borderRadius),
          ),
          landing.page,
          progress,
        )!;
        // The page's controls rebuild from this while they fly, which is
        // allowed during this build: they are below it.
        _flight.value = flying
            ? VideoTileFlightFrame(
                transform: transform,
                clip: clip,
                opacity: progress,
              )
            : null;
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: progress,
              child: flying
                  ? ClipPath(
                      clipper: _PageReveal(page: landing.page, flight: clip),
                      child: page,
                    )
                  : page,
            ),
            if (flying) ...[
              Positioned.fromRect(
                rect: rect,
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: borderRadius,
                    child: RawImage(
                      image: picture,
                      fit: BoxFit.cover,
                      alignment: alignment,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: VideoTileScrimPainter(
                      clip: clip,
                      top: VideoTileScrimBand(
                        rect: MatrixUtils.transformRect(
                          transform,
                          _playerTopScrim(landing.page.outerRect, screen),
                        ),
                        opacity: VideoOverlayScrims.topOpacity * progress,
                      ),
                      bottom: _bottomScrim(
                        landing: MatrixUtils.transformRect(
                          transform,
                          _playerBottomScrim(landing.page.outerRect, screen),
                        ),
                        from: from,
                        rect: rect,
                        progress: progress,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// The bottom scrim [progress] of the way from the tile's, carried along
  /// with the picture, to the player's at [landing].
  VideoTileScrimBand _bottomScrim({
    required Rect landing,
    required Rect from,
    required Rect rect,
    required double progress,
  }) {
    final tileScrim = widget.origin.scrimRect;
    final start = tileScrim == null || from.isEmpty
        ? landing
        : Rect.fromLTRB(
            rect.left + (tileScrim.left - from.left) / from.width * rect.width,
            rect.top + (tileScrim.top - from.top) / from.height * rect.height,
            rect.left + (tileScrim.right - from.left) / from.width * rect.width,
            rect.top +
                (tileScrim.bottom - from.top) / from.height * rect.height,
          );
    return VideoTileScrimBand(
      rect: Rect.lerp(start, landing, progress)!,
      opacity: ui.lerpDouble(
        tileScrim == null ? 0 : widget.origin.scrimOpacity,
        VideoOverlayScrims.bottomOpacity,
        progress,
      )!,
    );
  }

  /// Where the player draws its top scrim across [page].
  static Rect _playerTopScrim(Rect page, Rect screen) => Rect.fromLTWH(
    page.left,
    page.top,
    page.width,
    screen.height * VideoOverlayScrims.topHeightFactor,
  );

  /// Where the player draws its bottom scrim across [page].
  static Rect _playerBottomScrim(Rect page, Rect screen) => Rect.fromLTRB(
    page.left,
    page.bottom - screen.height * VideoOverlayScrims.bottomHeightFactor,
    page.right,
    page.bottom,
  );
}

/// Shows the page around [page], where the video is, and inside [flight],
/// the clip growing from the tile to the page.
class _PageReveal extends CustomClipper<Path> {
  const _PageReveal({required this.page, required this.flight});

  final RRect page;
  final RRect flight;

  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.union,
    Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(page),
    ),
    Path()..addRRect(flight),
  );

  @override
  bool shouldReclip(_PageReveal oldClipper) =>
      page != oldClipper.page || flight != oldClipper.flight;
}

/// The transform that moves what is drawn over [content] covering [landing],
/// centered, to where it is when [content] covers [rect] at [alignment]: the
/// flying picture's image, and with it the controls laid out over the video.
@visibleForTesting
Matrix4 contentTransform({
  required Size content,
  required Rect landing,
  required Rect rect,
  required Alignment alignment,
}) {
  if (content.isEmpty || landing.isEmpty || rect.isEmpty) {
    return Matrix4.identity();
  }
  Rect cover(Rect box, Alignment alignment) => alignment.inscribe(
    content * math.max(box.width / content.width, box.height / content.height),
    box,
  );
  final from = cover(landing, Alignment.center);
  final to = cover(rect, alignment);
  final scale = to.width / from.width;
  return Matrix4.identity()
    ..translateByDouble(to.left, to.top, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1)
    ..translateByDouble(-from.left, -from.top, 0, 1);
}

/// A scrim fading from clear to [opacity] of [VideoOverlayScrims.color]
/// across [rect], towards its outer edge.
@immutable
@visibleForTesting
class VideoTileScrimBand {
  /// A scrim over [rect].
  const VideoTileScrimBand({required this.rect, required this.opacity});

  /// Where the scrim is, in global coordinates.
  final Rect rect;

  /// How dark it is at its outer edge.
  final double opacity;
}

/// Paints the flying picture's top and bottom scrims inside [clip].
@visibleForTesting
class VideoTileScrimPainter extends CustomPainter {
  /// Paints [top] and [bottom] inside [clip].
  VideoTileScrimPainter({
    required this.clip,
    required this.top,
    required this.bottom,
  });

  /// What of the page shows, as for the controls.
  final RRect clip;

  /// The scrim along the top of the page, darkening in.
  final VideoTileScrimBand top;

  /// The scrim along the bottom, growing from the tile's into the player's.
  final VideoTileScrimBand bottom;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipRRect(clip);
    _paintBand(canvas, top, Alignment.bottomCenter, Alignment.topCenter);
    _paintBand(canvas, bottom, Alignment.topCenter, Alignment.bottomCenter);
    canvas.restore();
  }

  static void _paintBand(
    Canvas canvas,
    VideoTileScrimBand band,
    Alignment clear,
    Alignment dark,
  ) {
    if (band.rect.isEmpty || band.opacity <= 0) return;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: clear,
        end: dark,
        colors: [
          VideoOverlayScrims.color.withValues(alpha: 0),
          VideoOverlayScrims.color.withValues(alpha: band.opacity),
        ],
      ).createShader(band.rect);
    canvas.drawRect(band.rect, paint);
  }

  @override
  bool shouldRepaint(VideoTileScrimPainter oldDelegate) =>
      clip != oldDelegate.clip ||
      top.rect != oldDelegate.top.rect ||
      top.opacity != oldDelegate.top.opacity ||
      bottom.rect != oldDelegate.bottom.rect ||
      bottom.opacity != oldDelegate.bottom.opacity;
}
