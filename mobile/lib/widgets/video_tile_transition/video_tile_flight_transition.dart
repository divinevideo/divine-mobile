// ABOUTME: Route transition that flies a grid tile's picture to where the
// ABOUTME: fullscreen player shows the video, and back into the tile on pop.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
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
/// Everything that flies stays within bounds growing from where the tile can
/// be seen, [VideoTileOrigin.visibleBounds], to the page, their corners from
/// those of a panel around the grid to the page's: a tile partly under a bar
/// around the grid, such as the bottom navigation, flies out from under it,
/// and the bar stays over the flight as it fades into the page's own.
///
/// The frame is whatever the page's [VideoTileTransitionTarget] reports, so a
/// letterboxed square video lands on its letterboxed band rather than filling
/// the screen, and the picture's corners round into the frame's. Until the
/// page shows the video, the frame is predicted from
/// [VideoTileOrigin.letterboxAspectRatio]. The picture is drawn covering the
/// moving rect, which reproduces the tile's crop at one end and the player's
/// at the other: the crop's alignment moves from the tile's to the player's
/// centered one with the rect. When the tile is no longer laid out the
/// picture flies to the middle of the screen instead; a tile scrolled out of
/// view but still built keeps its place.
///
/// The picture starts as the tile's own decode and switches to
/// [VideoTileOrigin.playerSizeImage] whenever that has loaded, usually while
/// it is still small enough for the two to look alike.
///
/// Closing from the landed page flies a snapshot of the page as the player
/// was showing it, where it has been seen to read the player's frames: the
/// frame it was on, with whatever letterboxes it, placed like the controls
/// and hiding the page beneath, which may go on playing. The tile's picture
/// cross-fades in over it in the last [closeCrossFade] of the way, so it
/// lands as the tile.
/// Without a snapshot it flies the tile's picture throughout, the player-size
/// decode when that has loaded, as it starts out at the player's size.
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
/// Through [VideoTileTransitionScope], the page holds its controls until
/// then, so they take over from their flying copy, and its playback until
/// [playbackLead] before then, so the video is already moving from near
/// where the picture shows it.
///
/// While [popGestureInProgress] is `true`, the animation is being dragged
/// back by hand: the picture follows it linearly, so it tracks the finger,
/// and the page keeps playing beneath it in case the drag is let go.
class VideoTileFlightTransition extends StatefulWidget {
  /// Creates the transition for one route.
  const VideoTileFlightTransition({
    required this.animation,
    required this.origin,
    required this.child,
    this.popGestureInProgress,
    super.key,
  });

  /// The route's primary animation.
  final Animation<double> animation;

  /// The tile the picture flies out of.
  final VideoTileOrigin origin;

  /// The page.
  final Widget child;

  /// Whether [animation] is being dragged back by hand, or settling from
  /// such a drag.
  final ValueListenable<bool>? popGestureInProgress;

  /// How long the picture takes to fly from the tile to the player.
  static const openDuration = Duration(milliseconds: 280);

  /// How long the picture takes to fly back into the tile on close.
  static const closeDuration = Duration(milliseconds: 250);

  /// How long before the picture lands the page starts playing beneath it:
  /// about how long the player takes from being asked to play to showing
  /// the video moving.
  static const playbackLead = Duration(milliseconds: 100);

  /// How much of the way back into the tile, at its end, the player's last
  /// frame cross-fades into the tile's picture.
  static const closeCrossFade = 0.25;

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

  /// The page as the player was showing it when closing began.
  ui.Image? _frame;

  ImageStream? _playerSizeStream;
  ImageInfo? _playerSize;
  late final _playerSizeListener = ImageStreamListener(
    _onPlayerSize,
    onError: (error, stackTrace) {
      // The tile's own decode keeps flying: the sharper one is only a nicety.
    },
  );

  VideoTileLanding? _lastLanding;

  final _phase = ValueNotifier<VideoTileFlightPhase>(
    VideoTileFlightPhase.flying,
  );

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
    widget.animation
      ..addStatusListener(_onStatus)
      ..addListener(_onProgress);
    widget.popGestureInProgress?.addListener(_onPopGesture);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A route the navigator adds already open, such as one rebuilt under
    // another page, never runs forward: no picture flies, so it has landed.
    if (!_hasOpened &&
        widget.animation.status == AnimationStatus.completed &&
        ModalRoute.of(context)?.offstage == false) {
      _hasOpened = true;
      _releasePicture();
      _phase.value = VideoTileFlightPhase.landed;
    }
  }

  @override
  void didUpdateWidget(VideoTileFlightTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.popGestureInProgress != widget.popGestureInProgress) {
      oldWidget.popGestureInProgress?.removeListener(_onPopGesture);
      widget.popGestureInProgress?.addListener(_onPopGesture);
    }
  }

  bool get _dragged => widget.popGestureInProgress?.value ?? false;

  void _onPopGesture() {
    if (_dragged) {
      if (_phase.value != VideoTileFlightPhase.landed) return;
      // Dragging back from the landed page: fly what closing would.
      setState(_takeClosingPictures);
      _phase.value = VideoTileFlightPhase.arriving;
    } else if (widget.animation.status == AnimationStatus.completed) {
      // Let go and settled back open, which a drag that never moved does
      // without the animation reporting it.
      setState(_releasePicture);
      _phase.value = VideoTileFlightPhase.landed;
    } else {
      // The picture goes back to following the animation's curves.
      setState(() {});
    }
  }

  /// Whether a snapshot of the page has been seen to read the player's
  /// frames. Only iOS has been checked on a device. The Android feed draws
  /// through a texture too, but there the snapshot is unverified, so the
  /// tile's picture flies instead.
  static bool get _framesReadable => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };

  /// Takes the pictures closing flies: what the tile shows now, which is
  /// where it lands, and, from the landed page, the page as it is shown.
  void _takeClosingPictures() {
    _picture?.dispose();
    _picture = widget.origin.readImage();
    if (_phase.value == VideoTileFlightPhase.landed && _framesReadable) {
      _frame?.dispose();
      _frame = _targets.readPageOf(
        widget.origin.videoId,
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    }
  }

  /// How far through opening the page starts playing.
  static final double _arrivalProgress =
      1 -
      VideoTileFlightTransition.playbackLead.inMicroseconds /
          VideoTileFlightTransition.openDuration.inMicroseconds;

  void _onProgress() {
    if (!_dragged &&
        widget.animation.status == AnimationStatus.forward &&
        widget.animation.value >= _arrivalProgress &&
        _phase.value == VideoTileFlightPhase.flying) {
      _phase.value = VideoTileFlightPhase.arriving;
    }
  }

  void _onStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
        _hasOpened = true;
      // A drag back that returns to where it started reaches completed too,
      // and goes on: the picture keeps flying until the drag has let go.
      case AnimationStatus.completed when _hasOpened && !_dragged:
        setState(_releasePicture);
        _phase.value = VideoTileFlightPhase.landed;
      case AnimationStatus.reverse:
        setState(_takeClosingPictures);
        _phase.value = VideoTileFlightPhase.flying;
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
    _frame?.dispose();
    _frame = null;
  }

  @override
  void dispose() {
    widget.animation
      ..removeStatusListener(_onStatus)
      ..removeListener(_onProgress);
    widget.popGestureInProgress?.removeListener(_onPopGesture);
    _motion.dispose();
    _phase.dispose();
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
      phase: _phase,
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
        final progress = _dragged ? widget.animation.value : _motion.value;
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
          widget.origin.borderRadius,
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
        final frame = _frame;
        final status = widget.animation.status;
        // A drag back starts from the landed page, before the animation
        // reports it is moving.
        final flying =
            (picture != null || frame != null) &&
            (_dragged ||
                status == AnimationStatus.forward ||
                status == AnimationStatus.reverse);
        // With the page's snapshot flying, the video in it is placed as
        // drawn, covering the moving rect, and the controls with it.
        final transform = contentTransform(
          content: picture == null || frame != null
              ? media.size
              : Size(picture.width.toDouble(), picture.height.toDouble()),
          landing: media,
          rect: rect,
          alignment: alignment,
        );
        final pictureOpacity = frame == null
            ? 1.0
            : (1 - progress / VideoTileFlightTransition.closeCrossFade).clamp(
                0.0,
                1.0,
              );
        final clip = RRect.lerp(
          widget.origin.borderRadius.toRRect(from),
          landing.page,
          progress,
        )!;
        // The scrims span all of what shows: the page laid over the
        // picture's crop, as the controls are, can be narrower than it.
        Rect across(Rect band) =>
            Rect.fromLTRB(clip.left, band.top, clip.right, band.bottom);
        final topScrim = VideoTileScrimBand(
          rect: across(
            MatrixUtils.transformRect(
              transform,
              _playerTopScrim(landing.page.outerRect, screen),
            ),
          ),
          opacity: VideoOverlayScrims.topOpacity * progress,
        );
        final bottom = _bottomScrim(
          landing: MatrixUtils.transformRect(
            transform,
            _playerBottomScrim(landing.page.outerRect, screen),
          ),
          from: from,
          rect: rect,
          progress: progress,
        );
        final bottomScrim = VideoTileScrimBand(
          rect: across(bottom.rect),
          opacity: bottom.opacity,
        );
        final visible =
            widget.origin.visibleBounds ??
            RRect.fromRectAndRadius(screen, Radius.zero);
        // Until the page is laid out, where its own bars begin is unknown:
        // the bounds keep to the bottom of the view until then, so the bars
        // below it stay over the flight.
        final bounds = RRect.lerp(
          visible,
          _lastLanding?.page ??
              RRect.fromLTRBAndCorners(
                screen.left,
                screen.top,
                screen.right,
                visible.bottom,
                topLeft: visible.tlRadius,
                topRight: visible.trRadius,
                bottomLeft: visible.blRadius,
                bottomRight: visible.brRadius,
              ),
          progress,
        )!;
        // The page's controls rebuild from this while they fly, which is
        // allowed during this build: they are below it.
        _flight.value = flying
            ? VideoTileFlightFrame(
                transform: transform,
                clip: clip,
                bounds: bounds,
                opacity: progress,
              )
            : null;
        var revealed = page;
        if (flying) {
          revealed = ClipPath(
            clipper: _PageReveal(
              page: landing.page,
              // The snapshot stands in for the page under the clip.
              flight: frame == null ? clip : null,
              bounds: bounds,
            ),
            child: page,
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: progress, child: revealed),
            if (flying)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    clipper: _BoundsClip(bounds),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (frame != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: VideoTilePageSnapshotPainter(
                                  image: frame,
                                  page: landing.page.outerRect,
                                  transform: transform,
                                  clip: clip,
                                ),
                              ),
                            ),
                          ),
                        if (picture != null && pictureOpacity > 0)
                          Positioned.fromRect(
                            rect: rect,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: pictureOpacity,
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
                          ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: VideoTileScrimPainter(
                                clip: clip,
                                top: topScrim,
                                bottom: bottomScrim,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
/// the clip growing from the tile to the page, when there is one, as far as
/// [bounds] reach.
class _PageReveal extends CustomClipper<Path> {
  const _PageReveal({
    required this.page,
    required this.flight,
    required this.bounds,
  });

  final RRect page;
  final RRect? flight;
  final RRect bounds;

  @override
  Path getClip(Size size) {
    final around = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(page),
    );
    final flight = this.flight;
    if (flight == null) return around;
    return Path.combine(
      PathOperation.union,
      around,
      Path.combine(
        PathOperation.intersect,
        Path()..addRRect(flight),
        Path()..addRRect(bounds),
      ),
    );
  }

  @override
  bool shouldReclip(_PageReveal oldClipper) =>
      page != oldClipper.page ||
      flight != oldClipper.flight ||
      bounds != oldClipper.bounds;
}

/// Clips what flies to [bounds], given in the transition's coordinates.
class _BoundsClip extends CustomClipper<RRect> {
  const _BoundsClip(this.bounds);

  final RRect bounds;

  @override
  RRect getClip(Size size) => bounds;

  @override
  bool shouldReclip(_BoundsClip oldClipper) => bounds != oldClipper.bounds;
}

/// Paints [image], a snapshot of the page laid out at [page], moved by
/// [transform] with the controls and clipped to [clip], over the player's
/// background.
@visibleForTesting
class VideoTilePageSnapshotPainter extends CustomPainter {
  /// Paints [image] where [transform] moves [page], inside [clip].
  VideoTilePageSnapshotPainter({
    required this.image,
    required this.page,
    required this.transform,
    required this.clip,
  });

  /// The page as the player was showing it.
  final ui.Image image;

  /// Where the page is laid out, in global coordinates.
  final Rect page;

  /// Where the page's layout is drawn now, as for its controls.
  final Matrix4 transform;

  /// What of the page shows, as for the controls.
  final RRect clip;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipRRect(clip)
      ..drawColor(VineTheme.backgroundColor, BlendMode.srcOver)
      ..transform(transform.storage)
      ..drawImageRect(
        image,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        page,
        Paint()..filterQuality = FilterQuality.medium,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(VideoTilePageSnapshotPainter oldDelegate) =>
      image != oldDelegate.image ||
      page != oldDelegate.page ||
      transform != oldDelegate.transform ||
      clip != oldDelegate.clip;
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
