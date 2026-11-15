// ABOUTME: Route transition that flies a grid tile's picture to where the
// ABOUTME: fullscreen player shows the video, and back into the tile on pop.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_origin.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_transition_target.dart';

/// Flies [origin]'s picture from its tile to the frame the page shows the
/// video in as [animation] runs forward, then fades the page in behind it;
/// running in reverse, fades the page out and flies the picture back.
///
/// The two phases run one after the other, split at [flightShare] of the
/// animation, so the player never shows behind a picture still on its way.
/// [openDuration] and [closeDuration] are the route durations that keep the
/// flight at [flightDuration] and [closeFlightDuration].
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
/// Once the page has faded in, the picture is removed at once, uncovering the
/// player's own poster or video in the same place: fading it out would show
/// both pictures at once, doubling anything that has moved since the poster.
/// The page holds its playback and controls until then, through
/// [VideoTileTransitionScope], so the video starts from where the picture
/// shows it and the controls fade in over it.
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

  static const _flightMs = 280;
  static const _pageFadeMs = 150;

  /// How long the picture takes to fly from the tile to the player.
  static const flightDuration = Duration(milliseconds: _flightMs);

  /// How long the page takes to fade in once the picture has landed.
  static const pageFadeDuration = Duration(milliseconds: _pageFadeMs);

  /// How long the picture takes to fly back into the tile on close.
  static const closeFlightDuration = Duration(milliseconds: 250);

  /// The route's duration when opening: the flight, then the page fade.
  static const openDuration = Duration(milliseconds: _flightMs + _pageFadeMs);

  /// The share of the animation, at its tile end, the flight takes. The page
  /// stays hidden for it and fades over the rest.
  static const double flightShare = _flightMs / (_flightMs + _pageFadeMs);

  /// The route's duration when closing, which keeps the flight back at
  /// [closeFlightDuration] and fades the page out over the same share as it
  /// faded in.
  static final closeDuration = Duration(
    microseconds: (closeFlightDuration.inMicroseconds / flightShare).round(),
  );

  /// How the page's opacity follows the animation: hidden for the flight,
  /// then fading in.
  static const pageFadeInterval = Interval(
    flightShare,
    1,
    curve: Curves.easeOut,
  );

  @override
  State<VideoTileFlightTransition> createState() =>
      _VideoTileFlightTransitionState();
}

class _VideoTileFlightTransitionState extends State<VideoTileFlightTransition> {
  late final CurvedAnimation _motion = CurvedAnimation(
    parent: widget.animation,
    curve: const Interval(
      0,
      VideoTileFlightTransition.flightShare,
      curve: Curves.easeOutCubic,
    ),
    reverseCurve: const Interval(
      0,
      VideoTileFlightTransition.flightShare,
      curve: Curves.easeInCubic,
    ),
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

  RRect? _lastLanding;

  final _landed = ValueNotifier<bool>(false);

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
    _releasePicture();
    _playerSizeStream?.removeListener(_playerSizeListener);
    _playerSize?.dispose();
    super.dispose();
  }

  /// Where the page shows the video, with its corners, in screen
  /// coordinates.
  ///
  /// Until the page has built the layer that shows the video, which can take
  /// a good part of the flight, the frame is predicted from the video's
  /// dimensions. Once found, it is kept while the page swaps the layers that
  /// show the video, rather than aiming elsewhere for those frames.
  RRect _landing(Rect screen) {
    final page = _pageKey.currentContext?.findRenderObject();
    if (page is RenderBox && page.attached) {
      final shape = _targets.mediaShapeOf(widget.origin.videoId, page);
      if (shape != null) {
        _lastLanding = shape.shift(page.localToGlobal(Offset.zero));
      }
    }
    return _lastLanding ??
        RRect.fromRectAndRadius(
          letterboxedVideoRect(screen, widget.origin.letterboxAspectRatio),
          Radius.zero,
        );
  }

  @override
  Widget build(BuildContext context) {
    final page = VideoTileTransitionScope(
      targets: _targets,
      landed: _landed,
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
        final rect = Rect.lerp(from, landing.outerRect, progress)!;
        final borderRadius = BorderRadius.lerp(
          BorderRadius.circular(widget.origin.borderRadius),
          BorderRadius.only(
            topLeft: landing.tlRadius,
            topRight: landing.trRadius,
            bottomLeft: landing.blRadius,
            bottomRight: landing.brRadius,
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
            status == AnimationStatus.forward ||
            status == AnimationStatus.reverse;
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: VideoTileFlightTransition.pageFadeInterval.transform(
                widget.animation.value,
              ),
              child: page,
            ),
            if (picture != null && flying)
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
          ],
        );
      },
    );
  }
}
