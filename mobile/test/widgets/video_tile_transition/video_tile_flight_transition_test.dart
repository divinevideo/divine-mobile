import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_flight_transition.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_origin.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_transition_target.dart';

import 'sequenced_image_provider.dart';

const _screenSize = Size(400, 800);
const _tileRect = Rect.fromLTWH(20, 100, 120, 180);

/// Where the page letterboxes the square test video.
const _landing = Rect.fromLTWH(0, 200, 400, 400);

/// The page's rounded bottom corners, when it has them.
const _pageCorners = BorderRadius.vertical(bottom: Radius.circular(24));

/// The color the page draws the video in, where the video is drawn.
const _videoColor = Color(0xFFFF0000);

/// The color the page draws the video after the tile's in.
const _nextVideoColor = Color(0xFF00FF00);

class _Page extends StatelessWidget {
  const _Page({
    this.showsVideo = true,
    this.drawsVideo = false,
    this.roundedCover = false,
    this.bottomBar = false,
    this.movedOn = false,
    this.safetyOverlay = false,
    this.warning,
  });

  /// Whether the page has moved on from the tile's video to the next, which
  /// covers it, keeping the tile's built one page above, as a feed does.
  final bool movedOn;

  final bool showsVideo;

  /// Whether the target draws the video itself, in [_videoColor], rather
  /// than standing in for it.
  final bool drawsVideo;
  final bool safetyOverlay;

  /// Puts the safety overlay up and down from inside the page, which then
  /// rebuilds without the transition above it, when given; it overrides
  /// [safetyOverlay].
  final ValueListenable<bool>? warning;

  /// Whether the video sits above a 100 px bar, as over a comment bar.
  final bool bottomBar;

  /// Whether the video covers the page, which rounds its bottom corners,
  /// instead of being letterboxed.
  final bool roundedCover;

  @override
  Widget build(BuildContext context) {
    if (movedOn) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: -_screenSize.height,
            height: _screenSize.height,
            child: const VideoTileTransitionTarget(
              videoId: 'video1',
              aspectRatio: 1,
              coversViewport: false,
              showsVideo: true,
              child: ColoredBox(color: _videoColor),
            ),
          ),
          const Positioned.fill(
            child: VideoTileTransitionTarget(
              videoId: 'video2',
              aspectRatio: 9 / 16,
              coversViewport: true,
              showsVideo: true,
              child: ColoredBox(color: _nextVideoColor),
            ),
          ),
        ],
      );
    }
    if (roundedCover) {
      return const ClipRRect(
        borderRadius: _pageCorners,
        child: VideoTileTransitionTarget(
          videoId: 'video1',
          aspectRatio: 9 / 16,
          coversViewport: true,
          child: SizedBox.expand(),
        ),
      );
    }
    Widget? target;
    if (showsVideo) {
      Widget content = const SizedBox.expand();
      if (drawsVideo) content = const ColoredBox(color: _videoColor);
      target = VideoTileTransitionTarget(
        videoId: 'video1',
        aspectRatio: 1,
        coversViewport: false,
        showsVideo: drawsVideo,
        child: content,
      );
    }
    final warning = this.warning;
    final Widget video = warning == null
        ? _Video(target: target, warned: safetyOverlay)
        // Behind a repaint boundary of its own, as each video in a feed is,
        // so the warning arriving repaints nothing above the page.
        : RepaintBoundary(
            child: ValueListenableBuilder<bool>(
              valueListenable: warning,
              builder: (context, warned, _) =>
                  _Video(target: target, warned: warned),
            ),
          );
    if (!bottomBar) return video;
    return Column(
      children: [
        Expanded(child: video),
        const SizedBox(height: 100),
      ],
    );
  }
}

/// The page's black backdrop with its video [target], under a black safety
/// overlay when [warned].
class _Video extends StatelessWidget {
  const _Video({required this.target, required this.warned});

  final Widget? target;
  final bool warned;

  @override
  Widget build(BuildContext context) {
    final target = this.target;
    return ColoredBox(
      color: const Color(0xFF000000),
      child: warned
          ? Stack(
              fit: StackFit.expand,
              children: [
                ?target,
                const VideoTileTransitionTarget.safetyOverlay(
                  videoId: 'video1',
                  child: ColoredBox(
                    key: ValueKey('warning'),
                    color: Color(0xFF000000),
                  ),
                ),
              ],
            )
          : target,
    );
  }
}

/// A grid tile with, optionally, the route's transition drawn over it.
class _Harness extends StatelessWidget {
  const _Harness({
    required this.image,
    this.tileImageProvider,
    this.showTile = true,
    this.animation,
    this.origin,
    this.pageShowsVideo = true,
    this.pageDrawsVideo = false,
    this.popGestureInProgress,
    this.pageRoundedCover = false,
    this.pageBottomBar = false,
    this.pageMovedOn = false,
    this.safetyOverlay = false,
    this.warning,
    this.disableAnimations = false,
    this.tileAlignment = Alignment.center,
    this.tileScrim = false,
    this.onTileContext,
    this.tileView,
    this.tileViewCorners = BorderRadius.zero,
  });

  final ui.Image image;

  /// Shows the tile's thumbnail through an [Image] instead of [image].
  final ImageProvider<Object>? tileImageProvider;
  final bool showTile;
  final Animation<double>? animation;
  final VideoTileOrigin? origin;
  final bool pageShowsVideo;
  final bool pageDrawsVideo;
  final ValueListenable<bool>? popGestureInProgress;
  final bool pageRoundedCover;
  final bool pageBottomBar;
  final bool pageMovedOn;
  final bool safetyOverlay;
  final ValueListenable<bool>? warning;
  final bool disableAnimations;
  final Alignment tileAlignment;

  /// Whether the tile darkens its bottom 40 px with a scrim.
  final bool tileScrim;
  final ValueChanged<BuildContext>? onTileContext;

  /// Where a scrolling view around the tile shows it, when it is in one.
  final Rect? tileView;

  /// The corners of a panel the view is clipped to.
  final BorderRadius tileViewCorners;

  @override
  Widget build(BuildContext context) {
    final animation = this.animation;
    final origin = this.origin;
    final tile = Positioned.fromRect(
      rect: _tileRect,
      child: Builder(
        builder: (tileContext) {
          onTileContext?.call(tileContext);
          final provider = tileImageProvider;
          Widget picture = RawImage(
            image: image,
            fit: BoxFit.cover,
            alignment: tileAlignment,
          );
          if (provider != null) {
            picture = Image(
              image: provider,
              fit: BoxFit.cover,
              alignment: tileAlignment,
            );
          }
          final thumbnail = VideoTileThumbnailBoundary(
            child: picture,
          );
          if (!tileScrim) return thumbnail;
          return Stack(
            fit: StackFit.expand,
            children: [
              thumbnail,
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 40,
                child: VideoTileScrimBoundary(
                  opacity: 0.5,
                  child: SizedBox.expand(),
                ),
              ),
            ],
          );
        },
      ),
    );
    Widget? placedTile;
    if (showTile) placedTile = tile;
    final view = tileView;
    if (showTile && view != null) {
      // The tile in a scrolling view showing only [view] of it.
      placedTile = Positioned.fromRect(
        rect: view,
        child: ClipRRect(
          borderRadius: tileViewCorners,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox.fromSize(
              size: _screenSize,
              child: Stack(children: [tile]),
            ),
          ),
        ),
      );
    }
    return MediaQuery(
      data: MediaQueryData(
        size: _screenSize,
        disableAnimations: disableAnimations,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            ?placedTile,
            if (animation != null && origin != null)
              Positioned.fill(
                child: VideoTileFlightTransition(
                  animation: animation,
                  origin: origin,
                  popGestureInProgress: popGestureInProgress,
                  child: _Page(
                    showsVideo: pageShowsVideo,
                    drawsVideo: pageDrawsVideo,
                    roundedCover: pageRoundedCover,
                    bottomBar: pageBottomBar,
                    movedOn: pageMovedOn,
                    safetyOverlay: safetyOverlay,
                    warning: warning,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Finder get _picture => find.descendant(
  of: find.byType(VideoTileFlightTransition),
  matching: find.byType(RawImage),
);

/// Pumps to the transition's last frame, where the picture has landed and the
/// page has faded in: the route reports it has opened on the next one.
Future<void> _pumpToLastFlightFrame(WidgetTester tester) =>
    tester.pump(VideoTileFlightTransition.openDuration);

bool _pageHasLanded(WidgetTester tester) =>
    VideoTileTransitionScope.hasLandedOf(tester.element(find.byType(_Page)));

bool _pageMayPlay(WidgetTester tester) =>
    VideoTileTransitionScope.mayPlayOf(tester.element(find.byType(_Page)));

/// The picture's own corners: its nearest rounded clip, inside the flight's.
BorderRadiusGeometry? _pictureCorners(WidgetTester tester) => tester
    .widget<ClipRRect>(
      find.ancestor(of: _picture, matching: find.byType(ClipRRect)).first,
    )
    .borderRadius;

VideoTileFlightFrame? _flightFrame(WidgetTester tester) =>
    VideoTileTransitionScope.flightOf(
      tester.element(find.byType(_Page)),
    )!.value;

VideoTileScrimPainter _scrims(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is CustomPaint &&
                    widget.painter is VideoTileScrimPainter,
              ),
            )
            .painter!
        as VideoTileScrimPainter;

/// Where a snapshot of the page reads the player's frames.
const _readsFrames = TargetPlatformVariant({
  TargetPlatform.iOS,
  TargetPlatform.android,
});

/// Where it does not, so the tile's picture flies instead.
TargetPlatformVariant get _readsNoFrames =>
    TargetPlatformVariant.only(TargetPlatform.linux);

Matcher _rectCloseTo(Rect expected) => isA<Rect>()
    .having((r) => r.left, 'left', closeTo(expected.left, 0.01))
    .having((r) => r.top, 'top', closeTo(expected.top, 0.01))
    .having((r) => r.right, 'right', closeTo(expected.right, 0.01))
    .having((r) => r.bottom, 'bottom', closeTo(expected.bottom, 0.01));

double _pageOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: find.byType(_Page), matching: find.byType(Opacity)),
    )
    .opacity;

/// The red, green, blue and alpha the screen showed at [point] in the frame
/// last drawn, read from the layers that frame was composited from.
Future<(int, int, int, int)> _shownAt(WidgetTester tester, Offset point) async {
  final screen = tester.binding.renderViews.single;
  final layer = screen.debugLayer! as OffsetLayer;
  final shown = (await tester.runAsync(
    () => layer.toImage(screen.paintBounds),
  ))!;
  try {
    final bytes = (await tester.runAsync(shown.toByteData))!;
    final offset = (point.dy.toInt() * shown.width + point.dx.toInt()) * 4;
    return (
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
      bytes.getUint8(offset + 3),
    );
  } finally {
    shown.dispose();
  }
}

void main() {
  group(VideoTileFlightTransition, () {
    late AnimationController controller;
    late ui.Image image;

    Future<VideoTileOrigin> pumpTile(
      WidgetTester tester, {
      double? letterboxAspectRatio,
      Alignment tileAlignment = Alignment.center,
      bool tileScrim = false,
      Size imageSize = const Size(300, 300),
      Rect? tileView,
      BorderRadius tileViewCorners = BorderRadius.zero,
    }) async {
      tester.view.physicalSize = _screenSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      image = (await tester.runAsync(
        () => createTestImage(
          width: imageSize.width.toInt(),
          height: imageSize.height.toInt(),
        ),
      ))!;
      addTearDown(image.dispose);
      controller = AnimationController(
        vsync: tester,
        duration: VideoTileFlightTransition.openDuration,
        reverseDuration: VideoTileFlightTransition.closeDuration,
      );
      addTearDown(controller.dispose);
      late BuildContext tileContext;
      await tester.pumpWidget(
        _Harness(
          image: image,
          tileAlignment: tileAlignment,
          tileScrim: tileScrim,
          tileView: tileView,
          tileViewCorners: tileViewCorners,
          onTileContext: (c) => tileContext = c,
        ),
      );
      return VideoTileOrigin.capture(
        tileContext,
        videoId: 'video1',
        letterboxAspectRatio: letterboxAspectRatio,
      )!;
    }

    group('opening', () {
      testWidgets('keeps the warning over an opening video until reveal', (
        tester,
      ) async {
        final origin = await pumpTile(tester);
        final warning = ValueNotifier(true);
        addTearDown(warning.dispose);
        controller.forward();

        await tester.pumpWidget(
          _Harness(
            image: image,
            animation: controller,
            origin: origin,
            pageDrawsVideo: true,
            warning: warning,
          ),
        );
        await tester.pump(const Duration(milliseconds: 140));

        expect(find.byKey(const ValueKey('warning')), findsOneWidget);
        expect(_picture, findsNothing);

        await tester.pumpAndSettle();
        expect(await _shownAt(tester, _landing.center), (0, 0, 0, 0xFF));

        warning.value = false;
        await tester.pump();
        expect(find.byKey(const ValueKey('warning')), findsNothing);
        expect(await _shownAt(tester, _landing.center), (0xFF, 0, 0, 0xFF));
      });

      testWidgets('starts with the picture over the tile, page hidden', (
        tester,
      ) async {
        final origin = await pumpTile(tester);
        controller.forward();

        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );

        expect(tester.getRect(_picture), equals(_tileRect));
        expect(_pageOpacity(tester), equals(0));
        await tester.pumpAndSettle();
      });

      testWidgets('lands on the frame the page shows the video in', (
        tester,
      ) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );

        await _pumpToLastFlightFrame(tester);

        expect(tester.getRect(_picture), equals(_landing));
        expect(_pageOpacity(tester), equals(1));
        await tester.pumpAndSettle();
      });

      testWidgets('fades the page in as the picture flies', (tester) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );
        expect(_pageOpacity(tester), equals(0));

        await tester.pump(VideoTileFlightTransition.openDuration ~/ 2);

        expect(_pageOpacity(tester), allOf(greaterThan(0), lessThan(1)));
        await tester.pumpAndSettle();
      });

      testWidgets('shows the page only around the video and inside the clip', (
        tester,
      ) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(
            image: image,
            animation: controller,
            origin: origin,
            pageBottomBar: true,
          ),
        );
        // The page's frame is known once it has been laid out.
        await tester.pump(const Duration(milliseconds: 1));
        final shown = tester
            .widget<ClipPath>(
              find.ancestor(
                of: find.byType(_Page),
                matching: find.byType(ClipPath),
              ),
            )
            .clipper!
            .getClip(_screenSize);

        // The bar below the video fades in from the start...
        expect(shown.contains(const Offset(200, 750)), isTrue);
        // ...while the video's part of the page shows only where the clip
        // has grown, which starts as the tile.
        expect(shown.contains(_tileRect.center), isTrue);
        expect(shown.contains(const Offset(300, 500)), isFalse);
        await tester.pumpAndSettle();
      });

      testWidgets('crops the picture like the tile, then like the player', (
        tester,
      ) async {
        final origin = await pumpTile(
          tester,
          tileAlignment: Alignment.topCenter,
        );
        controller.forward();
        await tester.pumpWidget(
          _Harness(
            image: image,
            tileAlignment: Alignment.topCenter,
            animation: controller,
            origin: origin,
          ),
        );
        Alignment? pictureAlignment() =>
            tester.widget<RawImage>(_picture).alignment as Alignment;

        expect(pictureAlignment(), equals(Alignment.topCenter));

        await _pumpToLastFlightFrame(tester);

        expect(pictureAlignment(), equals(Alignment.center));
        await tester.pumpAndSettle();
      });

      testWidgets('hands over to the player the moment it lands', (
        tester,
      ) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );
        await _pumpToLastFlightFrame(tester);
        expect(_picture, findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1));

        // Removed at once rather than faded, which would show the picture
        // and the playing video on top of each other.
        expect(_picture, findsNothing);
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('rounds into the corners the page clips the video to', (
        tester,
      ) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(
            image: image,
            animation: controller,
            origin: origin,
            pageRoundedCover: true,
          ),
        );
        expect(_pictureCorners(tester), equals(BorderRadius.circular(4)));

        await _pumpToLastFlightFrame(tester);

        expect(tester.getRect(_picture), equals(Offset.zero & _screenSize));
        expect(_pictureCorners(tester), equals(_pageCorners));
        await tester.pumpAndSettle();
      });

      testWidgets('holds the page until the picture lands', (tester) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );
        expect(_pageHasLanded(tester), isFalse);

        await _pumpToLastFlightFrame(tester);
        expect(_pageHasLanded(tester), isFalse);

        await tester.pump(const Duration(milliseconds: 1));

        expect(_pageHasLanded(tester), isTrue);
      });

      testWidgets('lets the page play just before the picture lands', (
        tester,
      ) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );
        final untilArrival =
            VideoTileFlightTransition.openDuration -
            VideoTileFlightTransition.playbackLead;

        await tester.pump(untilArrival - const Duration(milliseconds: 2));
        expect(_pageMayPlay(tester), isFalse);

        await tester.pump(const Duration(milliseconds: 4));
        expect(_pageMayPlay(tester), isTrue);
        expect(_pageHasLanded(tester), isFalse);
        expect(_picture, findsOneWidget);
        await tester.pumpAndSettle();
      });

      testWidgets('lands full screen while the page shows no video yet', (
        tester,
      ) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(
            image: image,
            animation: controller,
            origin: origin,
            pageShowsVideo: false,
          ),
        );

        await _pumpToLastFlightFrame(tester);

        expect(tester.getRect(_picture), equals(Offset.zero & _screenSize));
        await tester.pumpAndSettle();
      });

      testWidgets('aims at the letterbox before the page shows the video', (
        tester,
      ) async {
        final origin = await pumpTile(tester, letterboxAspectRatio: 1);
        controller.forward();
        await tester.pumpWidget(
          _Harness(
            image: image,
            animation: controller,
            origin: origin,
            pageShowsVideo: false,
          ),
        );

        await _pumpToLastFlightFrame(tester);

        expect(tester.getRect(_picture), equals(_landing));
        await tester.pumpAndSettle();
      });

      testWidgets('keeps its course when the page starts showing the video', (
        tester,
      ) async {
        final origin = await pumpTile(tester, letterboxAspectRatio: 1);
        controller.forward();
        await tester.pumpWidget(
          _Harness(
            image: image,
            animation: controller,
            origin: origin,
            pageShowsVideo: false,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final predicted = tester.getRect(_picture);

        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );

        expect(tester.getRect(_picture), equals(predicted));
        await tester.pumpAndSettle();
      });

      testWidgets('keeps its landing when the page briefly loses the video', (
        tester,
      ) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );
        await tester.pump(const Duration(milliseconds: 100));

        await tester.pumpWidget(
          _Harness(
            image: image,
            animation: controller,
            origin: origin,
            pageShowsVideo: false,
          ),
        );
        await tester.pump(
          VideoTileFlightTransition.openDuration -
              const Duration(milliseconds: 100),
        );

        expect(tester.getRect(_picture), equals(_landing));
        await tester.pumpAndSettle();
      });

      testWidgets('keeps the picture through an offstage first frame', (
        tester,
      ) async {
        final origin = await pumpTile(tester);
        // The navigator builds a pushed route's first frame offstage, with
        // its animation standing in as complete, before it starts to open.
        final routeAnimation = ProxyAnimation(kAlwaysCompleteAnimation);
        await tester.pumpWidget(
          _Harness(image: image, animation: routeAnimation, origin: origin),
        );
        expect(_picture, findsNothing);

        controller.forward();
        routeAnimation.parent = controller;
        await tester.pump();

        expect(tester.getRect(_picture), equals(_tileRect));
        await tester.pumpAndSettle();
        expect(_picture, findsNothing);
      });
    });

    group('with a tile decoded at its own size', () {
      late ui.Image playerDecode;
      late ImageProvider<Object> tileProvider;

      /// Pumps a tile showing [image] resized, whose source decodes at the
      /// player's size as [playerLoad].
      Future<VideoTileOrigin> pumpResizedTile(
        WidgetTester tester,
        Future<ui.Image> Function(ui.Image playerDecode) playerLoad,
      ) async {
        await pumpTile(tester);
        playerDecode = (await tester.runAsync(
          () => createTestImage(width: 600, height: 600),
        ))!;
        addTearDown(playerDecode.dispose);
        addTearDown(() {
          imageCache
            ..clear()
            ..clearLiveImages();
        });
        tileProvider = ResizeImage(
          SequencedImageProvider([
            () => SynchronousFuture(image),
            () => playerLoad(playerDecode),
          ]),
          width: image.width,
        );
        late BuildContext tileContext;
        await tester.pumpWidget(
          _Harness(
            image: image,
            tileImageProvider: tileProvider,
            onTileContext: (c) => tileContext = c,
          ),
        );
        await tester.pump();
        return VideoTileOrigin.capture(tileContext, videoId: 'video1')!;
      }

      Future<void> pumpTransition(
        WidgetTester tester,
        VideoTileOrigin origin,
      ) => tester.pumpWidget(
        _Harness(
          image: image,
          tileImageProvider: tileProvider,
          animation: controller,
          origin: origin,
        ),
      );

      ui.Image? flyingImage(WidgetTester tester) =>
          tester.widget<RawImage>(_picture).image;

      testWidgets('switches to the player-size decode once it has loaded', (
        tester,
      ) async {
        final playerLoad = Completer<ui.Image>();
        final origin = await pumpResizedTile(tester, (_) => playerLoad.future);
        controller.forward();
        await pumpTransition(tester, origin);
        await tester.pump(const Duration(milliseconds: 40));

        expect(flyingImage(tester)!.isCloneOf(image), isTrue);

        playerLoad.complete(playerDecode);
        await tester.pump();

        expect(flyingImage(tester)!.isCloneOf(playerDecode), isTrue);
        await tester.pumpAndSettle();
      });

      testWidgets('flies the player-size decode back on close', (
        tester,
      ) async {
        final origin = await pumpResizedTile(tester, SynchronousFuture.new);
        controller.forward();
        await pumpTransition(tester, origin);
        await tester.pumpAndSettle();
        expect(_picture, findsNothing);

        controller.reverse();
        await tester.pump();

        expect(flyingImage(tester)!.isCloneOf(playerDecode), isTrue);
        await tester.pumpAndSettle();
      });

      testWidgets("keeps flying the tile's decode when the other fails", (
        tester,
      ) async {
        final origin = await pumpResizedTile(
          tester,
          (_) => Future.error(StateError('unreadable')),
        );
        controller.forward();
        await pumpTransition(tester, origin);
        await tester.pump(const Duration(milliseconds: 40));

        expect(flyingImage(tester)!.isCloneOf(image), isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
      });
    });

    group('controls', () {
      testWidgets('start hidden, clipped to the tile', (tester) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );

        final frame = _flightFrame(tester)!;
        expect(frame.opacity, equals(0));
        expect(
          frame.clip,
          equals(RRect.fromRectAndRadius(_tileRect, const Radius.circular(4))),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('stay over the same part of the picture as it flies', (
        tester,
      ) async {
        // A portrait picture landing on a frame of another shape, so the
        // picture's crop differs from the frame's.
        final origin = await pumpTile(tester, imageSize: const Size(180, 320));
        controller.forward();
        await tester.pumpWidget(
          _Harness(
            image: image,
            animation: controller,
            origin: origin,
            pageRoundedCover: true,
          ),
        );

        await tester.pump(VideoTileFlightTransition.openDuration ~/ 2);

        // The picture covers the frame at its landing, and the moving rect
        // now: the controls laid out over the one are drawn over the other.
        Rect cover(Rect box, Alignment alignment) {
          final size = Size(image.width.toDouble(), image.height.toDouble());
          final scale = math.max(
            box.width / size.width,
            box.height / size.height,
          );
          return alignment.inscribe(size * scale, box);
        }

        final rect = tester.getRect(_picture);
        final alignment = tester.widget<RawImage>(_picture).alignment;
        final frame = _flightFrame(tester)!;
        expect(
          MatrixUtils.transformRect(
            frame.transform,
            cover(Offset.zero & _screenSize, Alignment.center),
          ),
          _rectCloseTo(cover(rect, alignment as Alignment)),
        );
        expect(frame.opacity, allOf(greaterThan(0), lessThan(1)));
        await tester.pumpAndSettle();
      });

      testWidgets('reach the page as the picture lands', (tester) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );

        await _pumpToLastFlightFrame(tester);

        final frame = _flightFrame(tester)!;
        expect(
          MatrixUtils.transformRect(frame.transform, _landing),
          _rectCloseTo(_landing),
        );
        expect(frame.opacity, equals(1));
        expect(
          frame.clip,
          equals(
            RRect.fromRectAndRadius(
              Offset.zero & _screenSize,
              Radius.zero,
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('stop flying once the page has the picture', (tester) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );

        await tester.pumpAndSettle();

        expect(_flightFrame(tester), isNull);
      });

      testWidgets('fly back with the picture on close', (tester) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );
        await tester.pumpAndSettle();

        controller.reverse();
        await tester.pump();

        expect(_flightFrame(tester)?.opacity, equals(1));
        await tester.pumpAndSettle();
      });
    });

    group('under a bar over the tile', () {
      // The grid's view ends 50 points into the tile, where a bar begins.
      const view = Rect.fromLTWH(0, 0, 400, 230);

      Future<void> pumpOpening(
        WidgetTester tester, {
        bool pageShowsVideo = true,
        BorderRadius corners = BorderRadius.zero,
      }) async {
        final origin = await pumpTile(
          tester,
          tileView: view,
          tileViewCorners: corners,
        );
        controller.forward();
        await tester.pumpWidget(
          _Harness(
            image: image,
            animation: controller,
            origin: origin,
            tileView: view,
            tileViewCorners: corners,
            pageShowsVideo: pageShowsVideo,
          ),
        );
      }

      /// What the flight is clipped to: the clip with a clipper, as the
      /// picture's own corners have none.
      RRect flightBounds(WidgetTester tester) => tester
          .widgetList<ClipRRect>(
            find.ancestor(of: _picture, matching: find.byType(ClipRRect)),
          )
          .map((clip) => clip.clipper?.getClip(_screenSize))
          .whereType<RRect>()
          .single;

      bool pageShowsAt(WidgetTester tester, Offset point) => tester
          .widget<ClipPath>(
            find.ancestor(
              of: find.byType(_Page),
              matching: find.byType(ClipPath),
            ),
          )
          .clipper!
          .getClip(_screenSize)
          .contains(point);

      testWidgets('starts with only what the view shows of the tile', (
        tester,
      ) async {
        await pumpOpening(tester);

        expect(tester.getRect(_picture), equals(_tileRect));
        expect(flightBounds(tester).outerRect, equals(view));
        expect(_flightFrame(tester)!.bounds.outerRect, equals(view));
        expect(pageShowsAt(tester, const Offset(70, 200)), isTrue);
        expect(pageShowsAt(tester, const Offset(70, 260)), isFalse);
        await tester.pumpAndSettle();
      });

      testWidgets(
        'keeps to the bottom of the view until the page is laid out',
        (
          tester,
        ) async {
          // A page that never shows the video leaves the landing predicted, as
          // every flight's first frame is.
          await pumpOpening(tester, pageShowsVideo: false);

          await tester.pump(VideoTileFlightTransition.openDuration ~/ 2);

          expect(flightBounds(tester).bottom, equals(view.bottom));
          expect(_flightFrame(tester)!.bounds.bottom, equals(view.bottom));
          await tester.pumpAndSettle();
        },
      );

      testWidgets('grows its bounds from the view to the page as it flies', (
        tester,
      ) async {
        await pumpOpening(tester);

        await tester.pump(VideoTileFlightTransition.openDuration ~/ 2);

        final progress = Curves.easeOutCubic.transform(controller.value);
        final bounds = Rect.lerp(view, Offset.zero & _screenSize, progress)!;
        expect(flightBounds(tester).outerRect, _rectCloseTo(bounds));
        expect(_flightFrame(tester)!.bounds.outerRect, _rectCloseTo(bounds));
        await tester.pumpAndSettle();
      });

      testWidgets("rounds from the panel's corners to the page's", (
        tester,
      ) async {
        // A panel around the view rounding its bottom corners.
        const corners = BorderRadius.vertical(bottom: Radius.circular(30));
        await pumpOpening(tester, corners: corners);
        final start = corners.toRRect(view);
        expect(flightBounds(tester), equals(start));
        expect(_flightFrame(tester)!.bounds, equals(start));

        await tester.pump(VideoTileFlightTransition.openDuration ~/ 2);

        final progress = Curves.easeOutCubic.transform(controller.value);
        final bounds = RRect.lerp(
          start,
          RRect.fromRectAndRadius(Offset.zero & _screenSize, Radius.zero),
          progress,
        )!;
        expect(flightBounds(tester), equals(bounds));
        expect(_flightFrame(tester)!.bounds, equals(bounds));
        await tester.pumpAndSettle();
      });
    });

    group('scrims', () {
      testWidgets("start from the tile's bottom scrim", (tester) async {
        final origin = await pumpTile(tester, tileScrim: true);
        controller.forward();
        await tester.pumpWidget(
          _Harness(
            image: image,
            tileScrim: true,
            animation: controller,
            origin: origin,
          ),
        );

        final scrims = _scrims(tester);
        expect(
          scrims.bottom.rect,
          _rectCloseTo(Rect.fromLTRB(20, _tileRect.bottom - 40, 140, 280)),
        );
        expect(scrims.bottom.opacity, equals(0.5));
        expect(scrims.top.opacity, equals(0));
        await tester.pumpAndSettle();
      });

      testWidgets("carry the tile's scrim along with the picture", (
        tester,
      ) async {
        final origin = await pumpTile(tester, tileScrim: true);
        controller.forward();
        await tester.pumpWidget(
          _Harness(
            image: image,
            tileScrim: true,
            animation: controller,
            origin: origin,
          ),
        );

        await tester.pump(VideoTileFlightTransition.openDuration ~/ 2);

        // The tile's scrim, its bottom 40 of 180 points, kept on the same
        // part of the picture, on its way to the player's.
        final progress = Curves.easeOutCubic.transform(controller.value);
        final picture = tester.getRect(_picture);
        final carried = Rect.fromLTRB(
          picture.left,
          picture.top + picture.height * 140 / 180,
          picture.right,
          picture.bottom,
        );
        final height = _screenSize.height;
        final players = MatrixUtils.transformRect(
          _flightFrame(tester)!.transform,
          Rect.fromLTRB(
            0,
            height * (1 - VideoOverlayScrims.bottomHeightFactor),
            _screenSize.width,
            height,
          ),
        );
        // Across all of what shows.
        final shown = _scrims(tester).clip.outerRect;
        final band = Rect.lerp(carried, players, progress)!;
        expect(
          _scrims(tester).bottom.rect,
          _rectCloseTo(
            Rect.fromLTRB(shown.left, band.top, shown.right, band.bottom),
          ),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('span the whole picture where the page laid over it is '
          'narrower', (tester) async {
        // A portrait picture covering a wider tile, cropped top and bottom,
        // with the full screen page laid over it narrower than the tile.
        final origin = await pumpTile(tester, imageSize: const Size(180, 320));
        controller.forward();
        await tester.pumpWidget(
          _Harness(
            image: image,
            animation: controller,
            origin: origin,
            pageRoundedCover: true,
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));

        final picture = tester.getRect(_picture);
        final scrims = _scrims(tester);
        expect(scrims.top.rect.left, lessThanOrEqualTo(picture.left));
        expect(scrims.top.rect.right, greaterThanOrEqualTo(picture.right));
        expect(scrims.bottom.rect.left, lessThanOrEqualTo(picture.left));
        expect(scrims.bottom.rect.right, greaterThanOrEqualTo(picture.right));
        await tester.pumpAndSettle();
      });

      testWidgets('start clear when the tile has no scrim', (tester) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );

        expect(_scrims(tester).bottom.opacity, equals(0));
        await tester.pumpAndSettle();
      });

      testWidgets("land as the player's", (tester) async {
        final origin = await pumpTile(tester, tileScrim: true);
        controller.forward();
        await tester.pumpWidget(
          _Harness(
            image: image,
            tileScrim: true,
            animation: controller,
            origin: origin,
          ),
        );

        await _pumpToLastFlightFrame(tester);

        final scrims = _scrims(tester);
        final height = _screenSize.height;
        expect(
          scrims.bottom.rect,
          _rectCloseTo(
            Rect.fromLTRB(
              0,
              height * (1 - VideoOverlayScrims.bottomHeightFactor),
              _screenSize.width,
              height,
            ),
          ),
        );
        expect(scrims.bottom.opacity, equals(VideoOverlayScrims.bottomOpacity));
        expect(
          scrims.top.rect,
          _rectCloseTo(
            Rect.fromLTWH(
              0,
              0,
              _screenSize.width,
              height * VideoOverlayScrims.topHeightFactor,
            ),
          ),
        );
        expect(scrims.top.opacity, equals(VideoOverlayScrims.topOpacity));
        await tester.pumpAndSettle();
      });
    });

    group('closing', () {
      testWidgets('flies the picture back into the tile', (tester) async {
        final origin = await pumpTile(tester);
        controller.value = 1;
        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );
        expect(_picture, findsNothing);

        controller.reverse();
        await tester.pump();
        expect(tester.getRect(_picture), equals(_landing));
        expect(_pageOpacity(tester), equals(1));

        await tester.pump(
          VideoTileFlightTransition.closeDuration -
              const Duration(milliseconds: 1),
        );

        final rect = tester.getRect(_picture);
        expect(rect.center.dx, closeTo(_tileRect.center.dx, 1));
        expect(rect.center.dy, closeTo(_tileRect.center.dy, 1));
        expect(_pageOpacity(tester), closeTo(0, 0.01));
        await tester.pumpAndSettle();
      });

      testWidgets('holds the page again as the picture flies back', (
        tester,
      ) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );
        await tester.pumpAndSettle();
        expect(_pageHasLanded(tester), isTrue);

        controller.reverse();
        await tester.pump();

        expect(_pageHasLanded(tester), isFalse);
        expect(_pageMayPlay(tester), isFalse);
        await tester.pumpAndSettle();
      });

      testWidgets('only fades the page out when the tile is gone', (
        tester,
      ) async {
        final origin = await pumpTile(tester);
        controller.value = 1;
        await tester.pumpWidget(
          _Harness(
            image: image,
            showTile: false,
            animation: controller,
            origin: origin,
          ),
        );
        expect(origin.rect, isNull);

        controller.reverse();
        await tester.pump();
        // Nothing to read from a tile that is gone, so no picture flies.
        expect(_picture, findsNothing);

        await tester.pump(VideoTileFlightTransition.closeDuration);
        expect(_pageOpacity(tester), equals(0));
        await tester.pumpAndSettle();
      });
    });

    group('closing from the player', () {
      /// Lands the page, drawing the video, over the tile, and then, when
      /// [thenMoveOn], moves it on to the next video.
      Future<void> pumpLanded(
        WidgetTester tester, {
        ValueListenable<bool>? popGestureInProgress,
        bool thenMoveOn = false,
        bool safetyOverlay = false,
      }) async {
        final origin = await pumpTile(tester);
        controller.forward();
        Widget harness({required bool movedOn}) => _Harness(
          image: image,
          animation: controller,
          origin: origin,
          pageDrawsVideo: true,
          pageMovedOn: movedOn,
          safetyOverlay: safetyOverlay,
          popGestureInProgress: popGestureInProgress,
        );
        await tester.pumpWidget(harness(movedOn: false));
        await tester.pumpAndSettle();
        expect(_pageHasLanded(tester), isTrue);
        if (thenMoveOn) await tester.pumpWidget(harness(movedOn: true));
      }

      final snapshot = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter is VideoTilePageSnapshotPainter,
      );

      VideoTilePageSnapshotPainter snapshotPainter(WidgetTester tester) =>
          tester.widget<CustomPaint>(snapshot).painter!
              as VideoTilePageSnapshotPainter;

      /// Whether the page itself shows at [point].
      bool pageShowsAt(WidgetTester tester, Offset point) => tester
          .widget<ClipPath>(
            find.ancestor(
              of: find.byType(_Page),
              matching: find.byType(ClipPath),
            ),
          )
          .clipper!
          .getClip(_screenSize)
          .contains(point);

      double pictureOpacity(WidgetTester tester) => tester
          .widget<Opacity>(
            find.ancestor(of: _picture, matching: find.byType(Opacity)),
          )
          .opacity;

      /// The color of the snapshot flying at [point] of the page.
      Future<Color> snapshotColorAt(WidgetTester tester, Offset point) async {
        final image = snapshotPainter(tester).image;
        final bytes = (await tester.runAsync(image.toByteData))!;
        final offset = (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
        return Color.fromARGB(
          bytes.getUint8(offset + 3),
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
      }

      group('after the page has moved on to another video', () {
        final screen = Offset.zero & _screenSize;

        testWidgets(
          'flies a snapshot of the video it shows, from where it shows it',
          (tester) async {
            await pumpLanded(tester, thenMoveOn: true);

            controller.reverse();
            await tester.pump();

            expect(snapshotPainter(tester).page, equals(screen));
            expect(snapshotPainter(tester).clip.outerRect, equals(screen));
            expect(
              await snapshotColorAt(tester, screen.center),
              equals(_nextVideoColor),
            );
            expect(pageShowsAt(tester, screen.center), isFalse);
            await tester.pumpAndSettle();
          },
          variant: _readsFrames,
        );

        testWidgets(
          "lands in the tile as the tile's picture",
          (tester) async {
            await pumpLanded(tester, thenMoveOn: true);
            controller.reverse();
            await tester.pump();

            while (controller.value > 0.02) {
              await tester.pump(const Duration(milliseconds: 2));
            }

            expect(controller.isAnimating, isTrue);
            expect(pictureOpacity(tester), closeTo(1, 0.01));
            expect(
              tester.widget<RawImage>(_picture).image!.width,
              equals(image.width),
            );
            // On its way from the page the video covers into the tile.
            expect(
              tester.getRect(_picture),
              _rectCloseTo(
                Rect.lerp(
                  _tileRect,
                  screen,
                  Curves.easeInCubic.transform(controller.value),
                )!,
              ),
            );
            await tester.pumpAndSettle();
          },
          variant: _readsFrames,
        );

        testWidgets(
          'covers the video it shows from the start of a drag back',
          (tester) async {
            final dragging = ValueNotifier(false);
            addTearDown(dragging.dispose);
            await pumpLanded(
              tester,
              popGestureInProgress: dragging,
              thenMoveOn: true,
            );

            dragging.value = true;
            await tester.pump();

            expect(snapshotPainter(tester).page, equals(screen));
            expect(
              await snapshotColorAt(tester, screen.center),
              equals(_nextVideoColor),
            );
            expect(pageShowsAt(tester, screen.center), isFalse);
          },
          variant: _readsFrames,
        );

        testWidgets(
          "flies the tile's picture from where the video shows",
          (tester) async {
            await pumpLanded(tester, thenMoveOn: true);

            controller.reverse();
            await tester.pump();

            expect(snapshot, findsNothing);
            expect(tester.getRect(_picture), equals(screen));
            await tester.pumpAndSettle();
          },
          variant: _readsNoFrames,
        );
      });

      for (final drag in [false, true]) {
        testWidgets(
          'keeps the safety overlay on the live page during '
          '${drag ? 'a back drag' : 'a pop'}',
          (tester) async {
            final dragging = ValueNotifier(false);
            addTearDown(dragging.dispose);
            await pumpLanded(
              tester,
              safetyOverlay: true,
              popGestureInProgress: dragging,
            );

            if (drag) {
              dragging.value = true;
              controller.value = 0.7;
            } else {
              controller.reverse();
            }
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 40));

            expect(find.byKey(const ValueKey('warning')), findsOneWidget);
            expect(snapshot, findsNothing);
            expect(_picture, findsNothing);
            expect(find.byType(ClipPath), findsNothing);
            if (drag) dragging.value = false;
            await tester.pumpAndSettle();
          },
          variant: _readsFrames,
        );
      }

      for (final drag in [false, true]) {
        testWidgets(
          'stops flying for the rest of '
          '${drag ? 'a held back drag' : 'a pop'} once a safety overlay '
          'arrives',
          (tester) async {
            final dragging = ValueNotifier(false);
            addTearDown(dragging.dispose);
            final warning = ValueNotifier(false);
            addTearDown(warning.dispose);
            final origin = await pumpTile(tester);
            controller.forward();
            await tester.pumpWidget(
              _Harness(
                image: image,
                animation: controller,
                origin: origin,
                pageDrawsVideo: true,
                warning: warning,
                popGestureInProgress: dragging,
              ),
            );
            await tester.pumpAndSettle();
            expect(_pageHasLanded(tester), isTrue);

            if (drag) {
              dragging.value = true;
              controller.value = 0.7;
            } else {
              controller.reverse();
            }
            await tester.pump();
            if (!drag) await tester.pump(const Duration(milliseconds: 40));
            expect(snapshot, findsOneWidget);
            // Where the snapshot draws the video, in red, before the warning.
            final video = _landing.center;
            expect(await _shownAt(tester, video), (0xFF, 0, 0, 0xFF));

            // The finger holds still: nothing moves the animation from here.
            if (drag) controller.stop();
            // From inside the page, as moderation labels arrive in a feed,
            // so only the page rebuilds.
            warning.value = true;
            await tester.pump();

            // In the very frame it arrives, the black warning shows on the
            // live page, faded as far as the close has got, with nothing
            // flying over it.
            final (red, green, blue, alpha) = await _shownAt(tester, video);
            expect((red, green, blue), (0, 0, 0));
            expect(alpha, closeTo(0xFF * _pageOpacity(tester), 1));

            await tester.pump();
            expect(find.byKey(const ValueKey('warning')), findsOneWidget);
            expect(snapshot, findsNothing);
            expect(_picture, findsNothing);
            expect(find.byType(ClipPath), findsNothing);

            // The page snapshot predates the warning, so it stays down even
            // once the warning has gone.
            warning.value = false;
            await tester.pump();
            expect(snapshot, findsNothing);
            expect(_picture, findsNothing);

            if (drag) dragging.value = false;
            await tester.pumpAndSettle();
          },
          variant: _readsFrames,
        );
      }

      testWidgets(
        'flies a snapshot of the page, hiding the page beneath',
        (tester) async {
          await pumpLanded(tester);

          controller.reverse();
          await tester.pump();

          final painter = snapshotPainter(tester);
          expect(painter.page, equals(Offset.zero & _screenSize));
          expect(painter.image.width, equals(_screenSize.width));
          expect(painter.image.height, equals(_screenSize.height));
          final bytes = (await tester.runAsync(painter.image.toByteData))!;
          final middle =
              (_landing.center.dy.toInt() * painter.image.width +
                  _landing.center.dx.toInt()) *
              4;
          expect(
            Color.fromARGB(
              bytes.getUint8(middle + 3),
              bytes.getUint8(middle),
              bytes.getUint8(middle + 1),
              bytes.getUint8(middle + 2),
            ),
            equals(_videoColor),
          );
          // The tile's picture has not started fading in.
          expect(_picture, findsNothing);
          expect(pageShowsAt(tester, _landing.center), isFalse);

          await tester.pump(VideoTileFlightTransition.closeDuration ~/ 2);
          expect(pageShowsAt(tester, _landing.center), isFalse);
          expect(snapshotPainter(tester).clip.outerRect, isNot(_landing));
          await tester.pumpAndSettle();
        },
        variant: _readsFrames,
      );

      testWidgets(
        "cross-fades into the tile's picture over the last of the way",
        (tester) async {
          await pumpLanded(tester);
          controller.reverse();
          await tester.pump();

          double progress() => Curves.easeInCubic.transform(controller.value);

          // Not yet faded in a little before the last quarter.
          while (progress() > VideoTileFlightTransition.closeCrossFade + 0.05) {
            await tester.pump(const Duration(milliseconds: 10));
          }
          expect(_picture, findsNothing);

          // Halfway faded in halfway through the last quarter.
          while (progress() > VideoTileFlightTransition.closeCrossFade / 2) {
            await tester.pump(const Duration(milliseconds: 10));
          }
          expect(
            pictureOpacity(tester),
            closeTo(
              1 - progress() / VideoTileFlightTransition.closeCrossFade,
              0.001,
            ),
          );
          expect(
            tester.widget<RawImage>(_picture).image!.width,
            equals(image.width),
          );
          expect(snapshot, findsOneWidget);

          // Fully faded in as it reaches the tile.
          while (controller.value > 0.02) {
            await tester.pump(const Duration(milliseconds: 2));
          }
          expect(controller.isAnimating, isTrue);
          expect(pictureOpacity(tester), closeTo(1, 0.01));
          await tester.pumpAndSettle();
        },
        variant: _readsFrames,
      );

      testWidgets(
        "flies the tile's picture where the player's frames cannot be read",
        (tester) async {
          await pumpLanded(tester);

          controller.reverse();
          await tester.pump();

          expect(snapshot, findsNothing);
          expect(pictureOpacity(tester), equals(1));
          expect(
            tester.widget<RawImage>(_picture).image!.width,
            equals(image.width),
          );
          await tester.pumpAndSettle();
        },
        variant: _readsNoFrames,
      );

      testWidgets(
        'covers the page from the start of a drag back',
        (tester) async {
          final dragging = ValueNotifier(false);
          addTearDown(dragging.dispose);
          await pumpLanded(tester, popGestureInProgress: dragging);

          // The drag has started but not moved the animation yet.
          dragging.value = true;
          await tester.pump();

          expect(controller.status, equals(AnimationStatus.completed));
          expect(snapshot, findsOneWidget);
          expect(
            snapshotPainter(tester).clip.outerRect,
            equals(Offset.zero & _screenSize),
          );
          expect(pageShowsAt(tester, _landing.center), isFalse);
          expect(_flightFrame(tester), isNotNull);
          expect(_pageHasLanded(tester), isFalse);
        },
        variant: _readsFrames,
      );

      testWidgets(
        'hands back to the page when a drag is let go without moving',
        (tester) async {
          final dragging = ValueNotifier(false);
          addTearDown(dragging.dispose);
          await pumpLanded(tester, popGestureInProgress: dragging);
          dragging.value = true;
          await tester.pump();

          dragging.value = false;
          await tester.pump();

          expect(snapshot, findsNothing);
          expect(_picture, findsNothing);
          expect(_flightFrame(tester), isNull);
          expect(_pageHasLanded(tester), isTrue);
        },
        variant: _readsFrames,
      );
    });

    group('reduced motion', () {
      testWidgets('cross-fades the page instead of flying the picture', (
        tester,
      ) async {
        final origin = await pumpTile(tester);
        controller.forward();

        await tester.pumpWidget(
          _Harness(
            image: image,
            animation: controller,
            origin: origin,
            disableAnimations: true,
          ),
        );

        expect(_picture, findsNothing);
        expect(
          find.ancestor(
            of: find.byType(_Page),
            matching: find.byType(FadeTransition),
          ),
          findsOneWidget,
        );
        await tester.pumpAndSettle();
      });
    });
  });

  group('contentTransform', () {
    test('leaves what lands where it is', () {
      final transform = contentTransform(
        content: const Size(300, 300),
        landing: _landing,
        rect: _landing,
        alignment: Alignment.center,
      );

      expect(MatrixUtils.transformRect(transform, _landing), equals(_landing));
    });

    test('moves the landing frame to where the image covers the rect', () {
      // A portrait video, covering a page a little narrower than it, flown
      // into a square tile that keeps the top of the frame.
      final transform = contentTransform(
        content: const Size(90, 160),
        landing: const Rect.fromLTWH(0, 0, 400, 800),
        rect: const Rect.fromLTWH(20, 100, 120, 120),
        alignment: Alignment.topCenter,
      );

      // The image covers the page at 450 x 800, centred; in the tile it is
      // 120 wide and starts at the tile's top.
      expect(
        MatrixUtils.transformRect(
          transform,
          const Rect.fromLTWH(-25, 0, 450, 800),
        ),
        _rectCloseTo(const Rect.fromLTWH(20, 100, 120, 160 * 120 / 90)),
      );
    });

    test('is the identity for an empty rect', () {
      expect(
        contentTransform(
          content: const Size(90, 160),
          landing: _landing,
          rect: Rect.zero,
          alignment: Alignment.center,
        ),
        equals(Matrix4.identity()),
      );
    });
  });
}
