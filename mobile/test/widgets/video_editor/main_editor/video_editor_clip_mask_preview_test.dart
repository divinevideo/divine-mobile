// ABOUTME: Tests the cover a timeline clip's shape mask draws over the
// ABOUTME: preview frame while that clip plays.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_mask_window.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_clip_mask_preview.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerMask, LayerMaskBox, LayerMaskKeyframe, LayerMaskShape;
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

void main() {
  const heart = LayerMask(shape: LayerMaskShape.heart);

  DivineVideoClip clip(String id, {LayerMask? mask}) => DivineVideoClip(
    id: id,
    video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
    duration: const Duration(seconds: 2),
    recordedAt: DateTime(2026),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    mask: mask,
  );

  group(ClipMaskCover, () {
    late ValueNotifier<Duration> playTime;
    late ValueNotifier<LiveClipMask?> liveMask;

    setUp(() {
      playTime = ValueNotifier(Duration.zero);
      liveMask = ValueNotifier(null);
    });

    tearDown(() {
      playTime.dispose();
      liveMask.dispose();
    });

    Future<void> pumpCover(WidgetTester tester) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ClipMaskCover(
          clips: [
            clip('a'),
            clip('b', mask: heart),
          ],
          playTime: playTime,
          liveMask: liveMask,
        ),
      ),
    );

    /// The masks the cover is drawn through right now: each the inverse of
    /// the clip mask it covers for.
    List<LayerMask?> covers(WidgetTester tester) => [
      for (final box in tester.widgetList<LayerMaskBox>(
        find.byType(LayerMaskBox),
      ))
        box.mask,
    ];

    testWidgets('covers the frame only while the masked clip plays', (
      tester,
    ) async {
      await pumpCover(tester);
      expect(covers(tester), isEmpty);

      playTime.value = const Duration(seconds: 3);
      await tester.pump();
      expect(covers(tester), [heart.copyWith(invert: true)]);

      playTime.value = const Duration(milliseconds: 1500);
      await tester.pump();
      expect(covers(tester), isEmpty);
    });

    testWidgets('moves a mask with keyframes as the playhead moves through '
        'the clip', (tester) async {
      final moving = heart.withKeyframes(const [
        LayerMaskKeyframe(time: Duration.zero, center: Offset(0.2, 0.5)),
        LayerMaskKeyframe(time: Duration(seconds: 2), center: Offset(0.8, 0.5)),
      ]);
      liveMask.value = (clipId: 'b', mask: moving, backgroundColor: null);
      playTime.value = const Duration(seconds: 2);
      await pumpCover(tester);

      // Clip b starts at 2 s, so its mask counts from there.
      expect(covers(tester).single!.center.dx, closeTo(0.2, 1e-9));
      expect(covers(tester).single!.hasKeyframes, isFalse);

      playTime.value = const Duration(seconds: 3);
      await tester.pump();

      expect(covers(tester).single!.center.dx, closeTo(0.5, 1e-9));
      expect(covers(tester).single!.invert, isTrue);
    });

    testWidgets('draws a mask being changed, in its color, in place of the '
        "clip's own", (tester) async {
      const circle = LayerMask(shape: LayerMaskShape.ellipse);
      const pink = Color(0xFFFF7FAF);
      playTime.value = const Duration(milliseconds: 500);
      await pumpCover(tester);
      expect(covers(tester), isEmpty);

      liveMask.value = (clipId: 'a', mask: circle, backgroundColor: pink);
      await tester.pump();

      expect(covers(tester), [circle.copyWith(invert: true)]);
      final fill = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(LayerMaskBox),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(fill.color, pink);
    });
  });

  group(ClipMaskCoverBleed, () {
    testWidgets('reaches one device pixel past its box on every side, '
        'however far the canvas is zoomed', (tester) async {
      const content = Key('content');
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: Center(
            child: Transform.scale(
              scale: 2,
              child: const SizedBox(
                width: 100,
                height: 200,
                child: ClipMaskCoverBleed(child: SizedBox.expand(key: content)),
              ),
            ),
          ),
        ),
      );

      final transform = tester
          .renderObject<RenderBox>(find.byKey(content))
          .getTransformTo(
            tester.renderObject(find.byType(ClipMaskCoverBleed)),
          );

      // One device pixel is a quarter of a box unit at 2x zoom on a 2x
      // screen.
      expect(
        MatrixUtils.transformPoint(transform, Offset.zero),
        offsetMoreOrLessEquals(const Offset(-0.25, -0.25)),
      );
      expect(
        MatrixUtils.transformPoint(transform, const Offset(100, 200)),
        offsetMoreOrLessEquals(const Offset(100.25, 200.25)),
      );
    });
  });
}
