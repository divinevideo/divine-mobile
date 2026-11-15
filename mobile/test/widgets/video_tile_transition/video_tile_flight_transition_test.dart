import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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

class _Page extends StatelessWidget {
  const _Page({
    this.showsVideo = true,
    this.roundedCover = false,
    this.bottomBar = false,
  });

  final bool showsVideo;

  /// Whether the video sits above a 100 px bar, as over a comment bar.
  final bool bottomBar;

  /// Whether the video covers the page, which rounds its bottom corners,
  /// instead of being letterboxed.
  final bool roundedCover;

  @override
  Widget build(BuildContext context) {
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
    final video = ColoredBox(
      color: const Color(0xFF000000),
      child: showsVideo
          ? const VideoTileTransitionTarget(
              videoId: 'video1',
              aspectRatio: 1,
              coversViewport: false,
              child: SizedBox.expand(),
            )
          : null,
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

/// A grid tile with, optionally, the route's transition drawn over it.
class _Harness extends StatelessWidget {
  const _Harness({
    required this.image,
    this.tileImageProvider,
    this.showTile = true,
    this.animation,
    this.origin,
    this.pageShowsVideo = true,
    this.pageRoundedCover = false,
    this.pageBottomBar = false,
    this.disableAnimations = false,
    this.tileAlignment = Alignment.center,
    this.tileScrim = false,
    this.onTileContext,
  });

  final ui.Image image;

  /// Shows the tile's thumbnail through an [Image] instead of [image].
  final ImageProvider<Object>? tileImageProvider;
  final bool showTile;
  final Animation<double>? animation;
  final VideoTileOrigin? origin;
  final bool pageShowsVideo;
  final bool pageRoundedCover;
  final bool pageBottomBar;
  final bool disableAnimations;
  final Alignment tileAlignment;

  /// Whether the tile darkens its bottom 40 px with a scrim.
  final bool tileScrim;
  final ValueChanged<BuildContext>? onTileContext;

  @override
  Widget build(BuildContext context) {
    final animation = this.animation;
    final origin = this.origin;
    return MediaQuery(
      data: MediaQueryData(
        size: _screenSize,
        disableAnimations: disableAnimations,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            if (showTile)
              Positioned.fromRect(
                rect: _tileRect,
                child: Builder(
                  builder: (tileContext) {
                    onTileContext?.call(tileContext);
                    final provider = tileImageProvider;
                    final thumbnail = VideoTileThumbnailBoundary(
                      child: provider == null
                          ? RawImage(
                              image: image,
                              fit: BoxFit.cover,
                              alignment: tileAlignment,
                            )
                          : Image(
                              image: provider,
                              fit: BoxFit.cover,
                              alignment: tileAlignment,
                            ),
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
              ),
            if (animation != null && origin != null)
              Positioned.fill(
                child: VideoTileFlightTransition(
                  animation: animation,
                  origin: origin,
                  child: _Page(
                    showsVideo: pageShowsVideo,
                    roundedCover: pageRoundedCover,
                    bottomBar: pageBottomBar,
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

BorderRadiusGeometry? _pictureCorners(WidgetTester tester) => tester
    .widget<ClipRRect>(
      find.ancestor(of: _picture, matching: find.byType(ClipRRect)),
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

void main() {
  group(VideoTileFlightTransition, () {
    late AnimationController controller;
    late ui.Image image;

    Future<VideoTileOrigin> pumpTile(
      WidgetTester tester, {
      double? letterboxAspectRatio,
      Alignment tileAlignment = Alignment.center,
      bool tileScrim = false,
    }) async {
      tester.view.physicalSize = _screenSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      image = (await tester.runAsync(
        () => createTestImage(width: 300, height: 300),
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
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );

        await tester.pump(VideoTileFlightTransition.openDuration ~/ 2);

        // Where the picture draws its whole image, which it crops to the
        // rect at its alignment.
        final rect = tester.getRect(_picture);
        final alignment = tester.widget<RawImage>(_picture).alignment;
        final scale = math.max(rect.width, rect.height) / image.width;
        final imageRect = (alignment as Alignment).inscribe(
          Size(image.width * scale, image.height * scale),
          rect,
        );
        final frame = _flightFrame(tester)!;
        expect(
          MatrixUtils.transformRect(frame.transform, _landing),
          _rectCloseTo(imageRect),
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
