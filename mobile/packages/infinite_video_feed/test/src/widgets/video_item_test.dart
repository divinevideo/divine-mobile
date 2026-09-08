import 'dart:async';
import 'dart:typed_data';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/widgets/video_item.dart';

import '../../helpers/fake_controller.dart';

void main() {
  group(VideoItemWidget, () {
    testWidgets('renders SizedBox.shrink when controller is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VideoItemWidget(),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(DivineVideoPlayer), findsNothing);
    });

    testWidgets('renders DivineVideoPlayer when controller is provided', (
      tester,
    ) async {
      final controller = FakeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: VideoItemWidget(controller: controller),
        ),
      );

      expect(find.byType(DivineVideoPlayer), findsOneWidget);
    });

    testWidgets('wraps in FittedBox once dimensions are known', (tester) async {
      final controller = FakeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: VideoItemWidget(controller: controller),
        ),
      );

      // Initially no FittedBox (aspectRatio is 0).
      expect(find.byType(FittedBox), findsNothing);

      // Push dimensions.
      controller.pushState(
        const DivineVideoPlayerState(videoWidth: 1920, videoHeight: 1080),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(FittedBox), findsOneWidget);
      expect(find.byType(ClipRect), findsOneWidget);
    });

    testWidgets(
      'uses BoxFit.contain for 1:1 aspect ratio when portait expand',
      (tester) async {
        final controller = FakeController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: VideoItemWidget(controller: controller),
          ),
        );

        controller.pushState(
          const DivineVideoPlayerState(videoWidth: 100, videoHeight: 100),
        );
        await tester.pump();
        await tester.pump();

        final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
        expect(fittedBox.fit, equals(BoxFit.contain));
      },
    );

    testWidgets('uses BoxFit.cover for non-square ratio when portrait expand', (
      tester,
    ) async {
      final controller = FakeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: VideoItemWidget(controller: controller),
        ),
      );

      controller.pushState(
        const DivineVideoPlayerState(videoWidth: 1920, videoHeight: 1080),
      );
      await tester.pump();
      await tester.pump();

      final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fittedBox.fit, equals(BoxFit.cover));
    });

    testWidgets(
      'renders float-rounded anamorphic square video without cropping',
      (tester) async {
        final controller = FakeController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: VideoItemWidget(controller: controller),
          ),
        );

        controller.pushState(
          DivineVideoPlayerState(
            videoWidth: 720,
            videoHeight: 480,
            // Media3 widens its float pixel ratio to a platform-channel double.
            pixelWidthHeightRatio: Float32List.fromList([2 / 3]).single,
          ),
        );
        await tester.pump();
        await tester.pump();

        final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
        final fittedSize = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(FittedBox),
            matching: find.byType(SizedBox),
          ),
        );
        expect(fittedBox.fit, equals(BoxFit.contain));
        expect(fittedSize.width! / fittedSize.height!, closeTo(1.0, 1e-6));
      },
    );

    testWidgets('uses BoxFit.contain when shouldPortraitExpand is false', (
      tester,
    ) async {
      final controller = FakeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: VideoItemWidget(
            controller: controller,
            shouldPortraitExpand: false,
          ),
        ),
      );

      controller.pushState(
        const DivineVideoPlayerState(videoWidth: 1920, videoHeight: 1080),
      );
      await tester.pump();
      await tester.pump();

      final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fittedBox.fit, equals(BoxFit.contain));
    });

    testWidgets('handles controller replacement in didUpdateWidget', (
      tester,
    ) async {
      final controller1 = FakeController();
      final controller2 = FakeController();
      addTearDown(() {
        unawaited(controller1.dispose());
        unawaited(controller2.dispose());
      });

      // Build with controller1.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: VideoItemWidget(controller: controller1),
        ),
      );

      // Push dimensions on controller1 to set aspectRatio.
      controller1.pushState(
        const DivineVideoPlayerState(videoWidth: 640, videoHeight: 480),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(FittedBox), findsOneWidget);

      // Replace with controller2 (no dimensions yet → aspectRatio resets).
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: VideoItemWidget(controller: controller2),
        ),
      );

      // controller2 has no dimensions → back to plain DivineVideoPlayer.
      expect(find.byType(FittedBox), findsNothing);
    });

    testWidgets('handles switch from controller to null', (tester) async {
      final controller = FakeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: VideoItemWidget(controller: controller),
        ),
      );

      expect(find.byType(DivineVideoPlayer), findsOneWidget);

      // Swap to null controller.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VideoItemWidget(),
        ),
      );

      expect(find.byType(DivineVideoPlayer), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('ignores late stream updates after unmount', (tester) async {
      final controller = FakeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: VideoItemWidget(controller: controller),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());

      controller.pushState(
        const DivineVideoPlayerState(videoWidth: 1920, videoHeight: 1080),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
