import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
  const _Page({this.showsVideo = true, this.roundedCover = false});

  final bool showsVideo;

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
    return ColoredBox(
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
    this.disableAnimations = false,
    this.tileAlignment = Alignment.center,
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
  final bool disableAnimations;
  final Alignment tileAlignment;
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
                    return VideoTileThumbnailBoundary(
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

/// Pumps to the end of the flight, before the page fades in.
Future<void> _pumpToEndOfFlight(WidgetTester tester) =>
    tester.pump(VideoTileFlightTransition.flightDuration);

bool _pageHasLanded(WidgetTester tester) =>
    VideoTileTransitionScope.hasLandedOf(tester.element(find.byType(_Page)));

BorderRadiusGeometry? _pictureCorners(WidgetTester tester) => tester
    .widget<ClipRRect>(
      find.ancestor(of: _picture, matching: find.byType(ClipRRect)),
    )
    .borderRadius;

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

      testWidgets('fades the page in only once the picture has landed', (
        tester,
      ) async {
        final origin = await pumpTile(tester);
        controller.forward();
        await tester.pumpWidget(
          _Harness(image: image, animation: controller, origin: origin),
        );

        await _pumpToEndOfFlight(tester);

        expect(tester.getRect(_picture), equals(_landing));
        expect(_pageOpacity(tester), equals(0));

        await tester.pump(VideoTileFlightTransition.pageFadeDuration ~/ 2);

        expect(tester.getRect(_picture), equals(_landing));
        expect(_pageOpacity(tester), allOf(greaterThan(0), lessThan(1)));
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
          VideoTileFlightTransition.flightDuration -
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

        // The page fades out first, with the picture still in place.
        final fadeOut =
            VideoTileFlightTransition.closeDuration -
            VideoTileFlightTransition.closeFlightDuration;
        await tester.pump(fadeOut);
        // The picture has barely started back: the close duration is the
        // flight's stretched to a whole microsecond, so not exactly on it.
        final landed = tester.getRect(_picture);
        expect(landed.top, closeTo(_landing.top, 1));
        expect(landed.width, closeTo(_landing.width, 1));
        expect(_pageOpacity(tester), closeTo(0, 0.01));

        await tester.pump(
          VideoTileFlightTransition.closeFlightDuration -
              const Duration(milliseconds: 1),
        );

        final rect = tester.getRect(_picture);
        expect(rect.center.dx, closeTo(_tileRect.center.dx, 1));
        expect(rect.center.dy, closeTo(_tileRect.center.dy, 1));
        expect(_pageOpacity(tester), equals(0));
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

        await tester.pump(
          VideoTileFlightTransition.closeDuration -
              VideoTileFlightTransition.closeFlightDuration,
        );
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
}
