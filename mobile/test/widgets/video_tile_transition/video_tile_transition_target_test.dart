import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_transition_target.dart';

const _pageSize = Size(400, 500);

/// Where the page letterboxes a square video.
const _squareBand = Rect.fromLTWH(0, 50, 400, 400);

const _black = Color(0xFF000000);
const _red = Color(0xFFFF0000);

/// The color of [image]'s pixel at [x], [y].
Future<Color> _pixel(WidgetTester tester, ui.Image image, int x, int y) async {
  final bytes = (await tester.runAsync(
    () => image.toByteData(),
  ))!;
  final offset = (y * image.width + x) * 4;
  return Color.fromARGB(
    bytes.getUint8(offset + 3),
    bytes.getUint8(offset),
    bytes.getUint8(offset + 1),
    bytes.getUint8(offset + 2),
  );
}

void main() {
  group(VideoTileTransitionTargets, () {
    late VideoTileTransitionTargets targets;
    late ValueNotifier<VideoTileFlightPhase> phase;
    late ValueNotifier<VideoTileFlightFrame?> flight;
    final pageKey = GlobalKey();

    setUp(() {
      targets = VideoTileTransitionTargets();
      phase = ValueNotifier(VideoTileFlightPhase.landed);
      addTearDown(phase.dispose);
      flight = ValueNotifier(null);
      addTearDown(flight.dispose);
    });

    Rect? mediaRect(String videoId, RenderBox page) =>
        targets.landingOf(videoId, page)?.media.outerRect;

    Future<RenderBox> pumpPage(
      WidgetTester tester, {
      String videoId = 'video1',
      double? aspectRatio,
      bool coversViewport = false,
      bool showTarget = true,
      bool showsVideo = false,
      BorderRadius? clipRadius,
    }) async {
      Widget target = VideoTileTransitionTarget(
        videoId: videoId,
        aspectRatio: aspectRatio,
        coversViewport: coversViewport,
        showsVideo: showsVideo,
        // A black backdrop with the video red in the square band.
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: _black),
            Positioned.fromRect(
              rect: _squareBand,
              child: const ColoredBox(color: _red),
            ),
          ],
        ),
      );
      if (clipRadius != null) {
        target = ClipRRect(borderRadius: clipRadius, child: target);
      }
      Widget content = const SizedBox.expand();
      if (showTarget) content = target;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              key: pageKey,
              size: _pageSize,
              child: VideoTileTransitionScope(
                targets: targets,
                phase: phase,
                flight: flight,
                child: content,
              ),
            ),
          ),
        ),
      );
      return pageKey.currentContext!.findRenderObject()! as RenderBox;
    }

    group('active safety overlays', () {
      testWidgets('notifies when an existing warning becomes active', (
        tester,
      ) async {
        final active = ValueNotifier(false);
        addTearDown(active.dispose);
        final notifications = <bool>[];
        targets = VideoTileTransitionTargets(
          onSafetyOverlaysChanged: () =>
              notifications.add(targets.hasActiveSafetyOverlay),
        );

        await tester.pumpWidget(
          VideoTileTransitionScope(
            targets: targets,
            phase: phase,
            flight: flight,
            child: ValueListenableBuilder<bool>(
              valueListenable: active,
              builder: (context, isActive, _) =>
                  VideoTileTransitionTarget.safetyOverlay(
                    videoId: 'neighbour',
                    isActive: isActive,
                    child: const SizedBox.expand(),
                  ),
            ),
          ),
        );
        expect(targets.blocksFlightFor('neighbour'), isTrue);
        expect(notifications, [false]);

        active.value = true;
        await tester.pump();
        expect(notifications, [false, true]);

        active.value = false;
        await tester.pump();
        expect(notifications, [false, true, false]);
      });
    });

    group('landingOf', () {
      testWidgets('waits for a newly grafted transform ancestor layout', (
        tester,
      ) async {
        final target = SizedBox(
          key: GlobalKey(),
          width: 200,
          height: 200,
          child: const VideoTileTransitionTarget(
            videoId: 'video1',
            aspectRatio: null,
            coversViewport: true,
            child: SizedBox.expand(),
          ),
        );
        Widget tree(List<Widget> children) => VideoTileTransitionScope(
          targets: targets,
          phase: phase,
          flight: flight,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(key: pageKey, children: children),
          ),
        );
        await tester.pumpWidget(tree([target]));
        final page = pageKey.currentContext!.findRenderObject()! as RenderBox;
        expect(mediaRect('video1', page), const Rect.fromLTWH(0, 0, 200, 200));
        final translationKey = GlobalKey();
        Rect? duringBuild;
        var readDuringBuild = false;
        await tester.pumpWidget(
          tree([
            FractionalTranslation(
              key: translationKey,
              translation: const Offset(0, 0.5),
              child: target,
            ),
            Builder(
              builder: (_) {
                final ancestor =
                    translationKey.currentContext!.findRenderObject()!
                        as RenderFractionalTranslation;
                expect(ancestor.hasSize, isFalse);
                expect(page.hasSize, isTrue);
                duringBuild = mediaRect('video1', page);
                readDuringBuild = true;
                return const SizedBox.shrink();
              },
            ),
          ]),
        );

        expect(tester.takeException(), isNull);
        expect(readDuringBuild, isTrue);
        expect(duringBuild, isNull);
        expect(
          mediaRect('video1', page),
          const Rect.fromLTWH(0, 100, 200, 200),
        );
      });

      testWidgets('letterboxes a square video in the middle of the page', (
        tester,
      ) async {
        final page = await pumpPage(tester, aspectRatio: 1);

        expect(
          mediaRect('video1', page),
          equals(const Rect.fromLTWH(0, 50, 400, 400)),
        );
      });

      testWidgets('fills the page with a video that covers it', (
        tester,
      ) async {
        final page = await pumpPage(
          tester,
          aspectRatio: 9 / 16,
          coversViewport: true,
        );

        expect(
          mediaRect('video1', page),
          equals(Offset.zero & _pageSize),
        );
      });

      testWidgets('fills the page when the dimensions are unknown', (
        tester,
      ) async {
        final page = await pumpPage(tester);

        expect(
          mediaRect('video1', page),
          equals(Offset.zero & _pageSize),
        );
      });

      testWidgets('knows only the videos the page shows', (tester) async {
        final page = await pumpPage(tester, aspectRatio: 1);
        expect(mediaRect('video1', page), isNotNull);

        expect(mediaRect('video2', page), isNull);
      });

      testWidgets('forgets a target once it leaves the page', (tester) async {
        final page = await pumpPage(tester, aspectRatio: 1);
        expect(mediaRect('video1', page), isNotNull);

        await pumpPage(tester, showTarget: false);

        expect(mediaRect('video1', page), isNull);
      });

      testWidgets('follows a target that changes video', (tester) async {
        final page = await pumpPage(tester, aspectRatio: 1);
        expect(mediaRect('video1', page), isNotNull);

        await pumpPage(tester, videoId: 'video2', aspectRatio: 1);

        expect(mediaRect('video1', page), isNull);
        expect(mediaRect('video2', page), isNotNull);
      });

      testWidgets('rounds the corners the page clips the video to', (
        tester,
      ) async {
        const bottom = BorderRadius.vertical(bottom: Radius.circular(24));
        final page = await pumpPage(
          tester,
          aspectRatio: 9 / 16,
          coversViewport: true,
          clipRadius: bottom,
        );

        expect(
          targets.landingOf('video1', page)!.media,
          equals(
            RRect.fromRectAndCorners(
              Offset.zero & _pageSize,
              bottomLeft: const Radius.circular(24),
              bottomRight: const Radius.circular(24),
            ),
          ),
        );
      });

      testWidgets('keeps square corners on a band clear of the clip corners', (
        tester,
      ) async {
        final page = await pumpPage(
          tester,
          aspectRatio: 1,
          clipRadius: BorderRadius.circular(24),
        );

        expect(
          targets.landingOf('video1', page)!.media,
          equals(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(0, 50, 400, 400),
              Radius.zero,
            ),
          ),
        );
      });

      testWidgets('reports the whole page, rounded like its clip', (
        tester,
      ) async {
        const bottom = BorderRadius.vertical(bottom: Radius.circular(24));
        final page = await pumpPage(
          tester,
          aspectRatio: 1,
          clipRadius: bottom,
        );

        expect(
          targets.landingOf('video1', page)!.page,
          equals(
            RRect.fromRectAndCorners(
              Offset.zero & _pageSize,
              bottomLeft: const Radius.circular(24),
              bottomRight: const Radius.circular(24),
            ),
          ),
        );
      });

      testWidgets('keeps the video when its loading layer is dropped', (
        tester,
      ) async {
        // The feed stacks a loading layer and a video layer for one page,
        // both targets, and drops the loading layer once the first frame is
        // up. The feed keys them; unkeyed, as here, the framework keeps the
        // loading layer's element for the video layer and disposes the other.
        Widget layers({required bool loading}) => Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              key: pageKey,
              size: _pageSize,
              child: VideoTileTransitionScope(
                targets: targets,
                phase: phase,
                flight: flight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (loading)
                      const VideoTileTransitionTarget(
                        videoId: 'video1',
                        aspectRatio: 1,
                        coversViewport: false,
                        child: SizedBox.expand(),
                      ),
                    const VideoTileTransitionTarget(
                      videoId: 'video1',
                      aspectRatio: 1,
                      coversViewport: false,
                      child: SizedBox.expand(),
                    ),
                    const Text('overlay'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(layers(loading: true));
        final page = pageKey.currentContext!.findRenderObject()! as RenderBox;
        expect(mediaRect('video1', page), isNotNull);

        await tester.pumpWidget(layers(loading: false));

        expect(
          mediaRect('video1', page),
          equals(const Rect.fromLTWH(0, 50, 400, 400)),
        );
      });
    });

    group('shownIn', () {
      /// A page holding one target per video, each laid out a page tall from
      /// the top it is given, as a feed scrolled to that point does.
      Future<RenderBox> pumpPages(
        WidgetTester tester,
        Map<String, double> tops,
      ) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(
                key: pageKey,
                size: _pageSize,
                child: VideoTileTransitionScope(
                  targets: targets,
                  phase: phase,
                  flight: flight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final MapEntry(key: videoId, value: top)
                          in tops.entries)
                        Positioned(
                          left: 0,
                          top: top,
                          width: _pageSize.width,
                          height: _pageSize.height,
                          child: VideoTileTransitionTarget(
                            videoId: videoId,
                            aspectRatio: 1,
                            coversViewport: false,
                            child: const SizedBox.expand(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return pageKey.currentContext!.findRenderObject()! as RenderBox;
      }

      testWidgets('is the video on the page, not those built around it', (
        tester,
      ) async {
        final page = await pumpPages(tester, {
          'video1': -_pageSize.height,
          'video2': 0,
          'video3': _pageSize.height,
        });

        expect(targets.shownIn(page), equals('video2'));
      });

      testWidgets('is the video covering most of the page mid-scroll', (
        tester,
      ) async {
        final page = await pumpPages(tester, {
          'video1': -100,
          'video2': _pageSize.height - 100,
        });

        expect(targets.shownIn(page), equals('video1'));
      });

      testWidgets('is null while no video is on the page', (tester) async {
        final page = await pumpPages(tester, {'video1': -_pageSize.height});

        expect(targets.shownIn(page), isNull);
      });
    });

    group('readPageOf', () {
      testWidgets('reads the page as drawn, backdrop and all', (tester) async {
        await pumpPage(tester, aspectRatio: 1, showsVideo: true);

        final page = targets.readPageOf('video1', pixelRatio: 2)!;
        addTearDown(page.dispose);

        expect(page.width, equals(800));
        expect(page.height, equals(1000));
        expect(await _pixel(tester, page, 0, 0), equals(_black));
        expect(await _pixel(tester, page, 400, 500), equals(_red));
      });

      testWidgets('reads nothing from a page that does not draw the video', (
        tester,
      ) async {
        await pumpPage(tester, aspectRatio: 1);

        expect(targets.readPageOf('video1', pixelRatio: 1), isNull);
      });

      testWidgets('reads nothing while a poster stands in for the video', (
        tester,
      ) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: VideoTileTransitionScope(
              targets: targets,
              phase: phase,
              flight: flight,
              child: const Stack(
                fit: StackFit.expand,
                children: [
                  VideoTileTransitionTarget(
                    videoId: 'video1',
                    aspectRatio: 1,
                    coversViewport: false,
                    child: ColoredBox(color: _black),
                  ),
                  VideoTileTransitionTarget(
                    videoId: 'video1',
                    aspectRatio: 1,
                    coversViewport: false,
                    showsVideo: true,
                    child: ColoredBox(color: _red),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(targets.readPageOf('video1', pixelRatio: 1), isNull);
      });
    });

    group('flightOf', () {
      testWidgets('is null outside a tile transition', (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        );

        expect(VideoTileTransitionScope.flightOf(context), isNull);
      });

      testWidgets("is the scope's flight inside one", (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          VideoTileTransitionScope(
            targets: targets,
            phase: phase,
            flight: flight,
            child: Builder(
              builder: (c) {
                context = c;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(VideoTileTransitionScope.flightOf(context), same(flight));
      });
    });

    group('hasLandedOf and mayPlayOf', () {
      Widget reader(ValueChanged<(bool, bool)> onRead) => Builder(
        builder: (context) {
          onRead((
            VideoTileTransitionScope.hasLandedOf(context),
            VideoTileTransitionScope.mayPlayOf(context),
          ));
          return const SizedBox.shrink();
        },
      );

      testWidgets('let a page no picture flies over show and play', (
        tester,
      ) async {
        (bool, bool)? read;
        await tester.pumpWidget(reader((value) => read = value));

        expect(read, equals((true, true)));
      });

      testWidgets('follow the scope as the picture flies, arrives and lands', (
        tester,
      ) async {
        phase.value = VideoTileFlightPhase.flying;
        (bool, bool)? read;
        await tester.pumpWidget(
          VideoTileTransitionScope(
            targets: targets,
            phase: phase,
            flight: flight,
            child: reader((value) => read = value),
          ),
        );
        expect(read, equals((false, false)));

        phase.value = VideoTileFlightPhase.arriving;
        await tester.pump();
        expect(read, equals((false, true)));

        phase.value = VideoTileFlightPhase.landed;
        await tester.pump();
        expect(read, equals((true, true)));
      });
    });
  });

  group(VideoTileFlightCopy, () {
    testWidgets('marks only what is inside it', (tester) async {
      final inside = <bool>[];
      Widget reader() => Builder(
        builder: (context) {
          inside.add(VideoTileFlightCopy.isIn(context));
          return const SizedBox.shrink();
        },
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              reader(),
              VideoTileFlightCopy(child: reader()),
            ],
          ),
        ),
      );

      expect(inside, equals([false, true]));
    });
  });
}
