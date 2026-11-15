import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_transition_target.dart';

const _pageSize = Size(400, 500);

void main() {
  group(VideoTileTransitionTargets, () {
    late VideoTileTransitionTargets targets;
    late ValueNotifier<bool> landed;
    final pageKey = GlobalKey();

    setUp(() {
      targets = VideoTileTransitionTargets();
      landed = ValueNotifier(true);
      addTearDown(landed.dispose);
    });

    Rect? mediaRect(String videoId, RenderBox page) =>
        targets.mediaShapeOf(videoId, page)?.outerRect;

    Future<RenderBox> pumpPage(
      WidgetTester tester, {
      String videoId = 'video1',
      double? aspectRatio,
      bool coversViewport = false,
      bool showTarget = true,
      BorderRadius? clipRadius,
    }) async {
      Widget target = VideoTileTransitionTarget(
        videoId: videoId,
        aspectRatio: aspectRatio,
        coversViewport: coversViewport,
        child: const ColoredBox(color: Color(0xFF000000)),
      );
      if (clipRadius != null) {
        target = ClipRRect(borderRadius: clipRadius, child: target);
      }
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
                landed: landed,
                child: showTarget ? target : const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      return pageKey.currentContext!.findRenderObject()! as RenderBox;
    }

    group('mediaShapeOf', () {
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
          targets.mediaShapeOf('video1', page),
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
          targets.mediaShapeOf('video1', page),
          equals(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(0, 50, 400, 400),
              Radius.zero,
            ),
          ),
        );
      });

      testWidgets('keeps the video when its loading layer is dropped', (
        tester,
      ) async {
        // The feed stacks a loading layer and a video layer for one page,
        // both targets, and drops the loading layer once the first frame is
        // up. Unkeyed, the framework keeps the loading layer's element for
        // the video layer and disposes the other one.
        Widget layers({required bool loading}) => Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              key: pageKey,
              size: _pageSize,
              child: VideoTileTransitionScope(
                targets: targets,
                landed: landed,
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

    group('hasLandedOf', () {
      Widget reader(ValueChanged<bool> onLanded) => Builder(
        builder: (context) {
          onLanded(VideoTileTransitionScope.hasLandedOf(context));
          return const SizedBox.shrink();
        },
      );

      testWidgets('is true for a page no picture flies over', (tester) async {
        bool? hasLanded;
        await tester.pumpWidget(reader((value) => hasLanded = value));

        expect(hasLanded, isTrue);
      });

      testWidgets('follows the scope as the picture flies and lands', (
        tester,
      ) async {
        landed.value = false;
        bool? hasLanded;
        await tester.pumpWidget(
          VideoTileTransitionScope(
            targets: targets,
            landed: landed,
            child: reader((value) => hasLanded = value),
          ),
        );
        expect(hasLanded, isFalse);

        landed.value = true;
        await tester.pump();

        expect(hasLanded, isTrue);
      });
    });
  });
}
