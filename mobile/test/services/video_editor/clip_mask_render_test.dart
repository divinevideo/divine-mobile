import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/extensions/layer_mask_keyframes.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/clip_mask_render.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerMask, LayerMaskKeyframe, LayerMaskShape;
import 'package:pro_video_editor/pro_video_editor.dart'
    show
        AnimationPhase,
        ClipTransition,
        ClipTransitionType,
        EditorLayerImage,
        EditorVideo,
        ImageLayer,
        LayerAnimationType,
        LayerShapeMaskShape,
        VideoRenderData,
        VideoSegment;

void main() {
  const circle = LayerMask(shape: LayerMaskShape.ellipse, size: Size(1, 1));

  DivineVideoClip clip(
    String id, {
    LayerMask? mask,
    ClipTransition? transition,
  }) => DivineVideoClip(
    id: id,
    video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
    duration: const Duration(seconds: 2),
    recordedAt: DateTime(2026),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    mask: mask,
    transition: transition,
  );

  group('clipMaskCoverLayers', () {
    final renders = <Size>[];
    final rendered = <LayerMask>[];

    /// A blank image of [size], so the layers can be built without drawing.
    Future<ui.Image> fakeRender(LayerMask mask, Size size) {
      renders.add(size);
      rendered.add(mask);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder);
      return recorder.endRecording().toImage(2, 2);
    }

    setUp(() {
      renders.clear();
      rendered.clear();
    });

    testWidgets('covers what each masked clip hides while it plays, over the '
        'part of the frame the export keeps', (tester) async {
      final clips = [clip('a'), clip('b', mask: circle)];

      final layers = (await tester.runAsync(
        () => clipMaskCoverLayers(
          clips: clips,
          videoSize: const Size(1080, 1920),
          targetAspectRatio: 1,
          timelineMap: TransitionTimelineMap.fromClips(clips),
          render: fakeRender,
        ),
      ))!;

      expect(layers, hasLength(1));
      expect(layers.single.startTime, const Duration(seconds: 2));
      expect(layers.single.endTime, const Duration(seconds: 4));
      expect(layers.single.offset, const Offset(0, 420));
      expect(layers.single.size, const Size(1080, 1080));
      expect(layers.single.animations, isEmpty);
      expect(renders, [const Size(1080, 1080)]);
    });

    testWidgets('fades the cover across an overlap transition, on the output '
        'timeline', (tester) async {
      const dissolve = ClipTransition(
        type: ClipTransitionType.dissolve,
        duration: Duration(milliseconds: 300),
      );
      final clips = [
        clip('a', transition: dissolve),
        clip('b', mask: circle),
      ];

      final layers = (await tester.runAsync(
        () => clipMaskCoverLayers(
          clips: clips,
          videoSize: const Size(1080, 1920),
          targetAspectRatio: 9 / 16,
          timelineMap: TransitionTimelineMap.fromClips(clips),
          render: fakeRender,
        ),
      ))!;

      final layer = layers.single;
      // The 300 ms blend plays from 1.7 s to 2.0 s of the shortened output.
      expect(layer.startTime, const Duration(milliseconds: 1700));
      expect(layer.endTime, const Duration(milliseconds: 3700));
      final fadeIn = layer.animations.single;
      expect(fadeIn.type, LayerAnimationType.fade);
      expect(fadeIn.phase, AnimationPhase.animateIn);
      expect(fadeIn.duration, const Duration(milliseconds: 300));
    });

    group('a mask with keyframes', () {
      final moving = circle.withKeyframes(const [
        LayerMaskKeyframe(time: Duration.zero, size: Size(0.2, 0.2)),
        LayerMaskKeyframe(
          time: Duration(seconds: 1),
          size: Size(1, 1),
          feather: 0.1,
        ),
      ]);

      Future<List<ImageLayer>> coverLayers(
        WidgetTester tester,
        List<DivineVideoClip> clips,
      ) async => (await tester.runAsync(
        () => clipMaskCoverLayers(
          clips: clips,
          videoSize: const Size(1080, 1920),
          targetAspectRatio: 9 / 16,
          timelineMap: TransitionTimelineMap.fromClips(clips),
          render: fakeRender,
        ),
      ))!;

      testWidgets('leaves the shape to the export and covers with plain '
          'black', (tester) async {
        final layers = await coverLayers(tester, [
          clip('a'),
          clip('b', mask: moving),
        ]);

        final shapeMask = layers.single.shapeMask!;
        // The cover is what the mask hides: the mask turned inside out.
        expect(shapeMask.invert, isTrue);
        expect(shapeMask.shape, LayerShapeMaskShape.ellipse);
        expect(rendered.single.hasKeyframes, isFalse);
        expect(rendered.single.size, Size.zero);
      });

      testWidgets('times the keyframes from the clip start on the editor '
          'timeline, read on its clock', (tester) async {
        const dissolve = ClipTransition(
          type: ClipTransitionType.dissolve,
          duration: Duration(milliseconds: 300),
        );
        final clips = [
          clip('a', transition: dissolve),
          clip('b', mask: moving),
        ];

        final layer = (await coverLayers(tester, clips)).single;

        expect(layer.shapeMask!.keyframes.map((k) => k.time), [
          const Duration(seconds: 2),
          const Duration(seconds: 3),
        ]);
        expect(layer.keyframeClock, isNotEmpty);
      });

      testWidgets('shares one black image between moving masks', (
        tester,
      ) async {
        final layers = await coverLayers(tester, [
          clip('a', mask: moving),
          clip('b', mask: moving.shiftedBy(const Duration(seconds: 1))),
          clip('c', mask: circle),
        ]);

        expect(identical(layers[0].image, layers[1].image), isTrue);
        expect(layers[2].shapeMask, isNull);
        expect(layers[2].keyframeClock, isEmpty);
        expect(renders, hasLength(2));
      });
    });

    testWidgets('renders a mask shared by several clips once', (tester) async {
      final clips = [clip('a', mask: circle), clip('b', mask: circle)];

      final layers = (await tester.runAsync(
        () => clipMaskCoverLayers(
          clips: clips,
          videoSize: const Size(1080, 1920),
          targetAspectRatio: 9 / 16,
          timelineMap: TransitionTimelineMap.fromClips(clips),
          render: fakeRender,
        ),
      ))!;

      expect(layers, hasLength(2));
      expect(identical(layers.first.image, layers.last.image), isTrue);
      expect(renders, hasLength(1));
    });
  });

  group('withClipMaskCovers', () {
    Future<ui.Image> blank(LayerMask mask, Size size) {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder);
      return recorder.endRecording().toImage(2, 2);
    }

    final overlay = ImageLayer(
      image: EditorLayerImage.memory(Uint8List.fromList([1])),
    );

    VideoRenderData task() => VideoRenderData(
      id: 'task',
      videoSegments: [
        VideoSegment(video: EditorVideo.file('/a.mp4')),
        VideoSegment(video: EditorVideo.file('/b.mp4')),
      ],
      imageLayers: [overlay],
    );

    test('leaves a render without masked clips as it is', () async {
      final unmasked = task();

      expect(
        await withClipMaskCovers(unmasked, [
          clip('a'),
        ], model.AspectRatio.vertical),
        same(unmasked),
      );
    });

    testWidgets('lays the covers under the overlays, in the frame of the '
        'largest segment', (tester) async {
      final resolutions = {
        '/a.mp4': const Size(720, 1280),
        '/b.mp4': const Size(1080, 1920),
      };

      final masked = (await tester.runAsync(
        () => withClipMaskCovers(
          task(),
          [clip('a', mask: circle), clip('b')],
          model.AspectRatio.vertical,
          render: blank,
          readResolution: (video) async => resolutions[video.file!.path]!,
        ),
      ))!;

      expect(masked.imageLayers, hasLength(2));
      expect(masked.imageLayers!.first.size, const Size(1080, 1920));
      expect(masked.imageLayers!.last, same(overlay));
    });
  });

  group('renderClipMaskCover', () {
    testWidgets('is black where the mask hides the clip and clear where it '
        'shows it', (tester) async {
      final bytes = (await tester.runAsync(() async {
        final image = await renderClipMaskCover(circle, const Size(40, 40));
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List();
      }))!;

      List<int> pixel(int x, int y) =>
          bytes.sublist((y * 40 + x) * 4, (y * 40 + x) * 4 + 4);
      expect(pixel(20, 20)[3], 0);
      expect(pixel(1, 1), [0, 0, 0, 255]);
    });
  });
}
