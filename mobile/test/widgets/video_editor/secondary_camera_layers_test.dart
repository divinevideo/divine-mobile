import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_recorder/secondary_camera_take.dart';
import 'package:openvine/widgets/video_editor/secondary_camera_layers.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerMaskShape, WidgetLayer;
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('secondaryCameraTakeLayers', () {
    const canvas = Size(1080, 1920);
    final now = DateTime.utc(2026, 11, 17);

    DivineVideoClip clip(
      String id, {
      Duration duration = const Duration(seconds: 4),
      SecondaryCameraTake? take,
      Duration trimStart = Duration.zero,
    }) => DivineVideoClip(
      id: id,
      video: EditorVideo.file(File('/docs/$id.mp4')),
      duration: duration,
      recordedAt: now,
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
      trimStart: trimStart,
      secondaryCamera: take,
    );

    SecondaryCameraTake take(
      String id, {
      Duration duration = const Duration(seconds: 4),
      Offset pipCenter = SecondaryCameraTake.defaultPipCenter,
    }) => SecondaryCameraTake(
      clip: DivineVideoClip(
        id: id,
        video: EditorVideo.file(File('/docs/$id.mp4')),
        duration: duration,
        recordedAt: now,
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
        volume: 0,
      ),
      pipCenter: pipCenter,
    );

    List<WidgetLayer> layersFor(
      List<DivineVideoClip> clips, {
      Size canvasRenderSize = canvas,
      Set<String> placedTakeIds = const {},
    }) => [
      for (final placement in secondaryCameraTakeLayers(
        clips: clips,
        canvasRenderSize: canvasRenderSize,
        now: now,
        placedTakeIds: placedTakeIds,
      ))
        placement.layer,
    ];

    test('makes no layer for clips without a take', () {
      expect(layersFor([clip('a'), clip('b')]), isEmpty);
    });

    test('makes no layer while the canvas has no size yet', () {
      expect(
        layersFor([
          clip('a', take: take('a_second')),
        ], canvasRenderSize: Size.zero),
        isEmpty,
      );
    });

    test("puts each take over its clip's stretch of the timeline", () {
      final layers = layersFor(
        [
          clip('a', duration: const Duration(seconds: 2)),
          clip('b', take: take('b_second')),
        ],
      );

      expect(layers, hasLength(1));
      final layer = layers.single;
      expect(layer.startTime, equals(const Duration(seconds: 2)));
      expect(layer.endTime, equals(const Duration(seconds: 6)));
      expect(DetachedClipLayerData.isDetachedClipLayer(layer), isTrue);
      expect(
        DetachedClipLayerData.layerIdOf(DetachedClipLayerData.metaOf(layer)),
        equals(layer.id),
      );
    });

    test('names the take each layer belongs to', () {
      final placements = secondaryCameraTakeLayers(
        clips: [
          clip('a', take: take('a_second')),
          clip('b', take: take('b_second')),
        ],
        canvasRenderSize: canvas,
        now: now,
      );

      expect(
        placements.map((placement) => placement.takeId),
        equals(['a_second', 'b_second']),
      );
    });

    test('leaves out the takes the session already placed', () {
      final layers = layersFor(
        [
          clip('a', duration: const Duration(seconds: 2), take: take('a_s')),
          clip('b', take: take('b_s')),
        ],
        placedTakeIds: {'a_s'},
      );

      expect(layers, hasLength(1));
      // Still over its own clip, after the first one.
      expect(layers.single.startTime, const Duration(seconds: 2));
    });

    test('sizes the layer like the viewfinder window, where it was', () {
      final layers = layersFor(
        [
          clip(
            'a',
            take: take('a_second', pipCenter: const Offset(0.75, 0.25)),
          ),
        ],
      );

      final layer = layers.single;
      expect(
        layer.width,
        closeTo(canvas.width * SecondaryCameraTake.pipWidthFraction, 1e-9),
      );
      expect(layer.offset.dx, closeTo(0.25 * canvas.width, 1e-9));
      expect(layer.offset.dy, closeTo(-0.25 * canvas.height, 1e-9));
    });

    test('rounds the layer like the viewfinder window', () {
      final layers = layersFor(
        [clip('a', take: take('a_second'))],
      );

      final mask = layers.single.mask;
      expect(mask?.shape, LayerMaskShape.rectangle);
      expect(mask?.size, const Size(1, 1));
      expect(mask?.cornerRadius, SecondaryCameraTake.pipCornerRadius);
    });

    test('keeps a window dragged to the edge whole inside the frame', () {
      final layers = layersFor(
        [
          clip('a', take: take('a_second', pipCenter: const Offset(1, 0))),
        ],
      );

      final layer = layers.single;
      final width = layer.width!;
      final height = width / (9 / 16);
      expect(layer.offset.dx, closeTo((canvas.width - width) / 2, 1e-9));
      expect(layer.offset.dy, closeTo(-(canvas.height - height) / 2, 1e-9));
    });

    test('follows the clip trims and plays no longer than the clip', () {
      final layers = layersFor(
        [
          clip(
            'a',
            trimStart: const Duration(seconds: 1),
            take: take('a_second', duration: const Duration(seconds: 6)),
          ),
        ],
      );

      final layer = layers.single;
      expect(layer.startTime, equals(Duration.zero));
      expect(layer.endTime, equals(const Duration(seconds: 3)));
      final data = DetachedClipLayerData.fromMeta(
        DetachedClipLayerData.metaOf(layer),
        '/docs',
      );
      expect(data?.clip.trimStart, equals(const Duration(seconds: 1)));
      expect(data?.clip.volume, equals(0));
    });

    test("skips the take's lead-in and covers its clip without a gap", () {
      final lead = take(
        'a_second',
        duration: const Duration(milliseconds: 4300),
      );
      final layers = layersFor(
        [
          clip(
            'a',
            take: lead.copyWith(
              clip: lead.clip.copyWith(
                trimStart: const Duration(milliseconds: 150),
              ),
            ),
          ),
          clip('b', take: take('b_second')),
        ],
      );

      final first = layers.first;
      expect(first.startTime, Duration.zero);
      // The clip plays 4 s; the take, 4.15 s after its lead-in, fills it.
      expect(first.endTime, const Duration(seconds: 4));
      expect(layers.last.startTime, first.endTime);
      final data = DetachedClipLayerData.fromMeta(
        DetachedClipLayerData.metaOf(first),
        '/docs',
      );
      expect(data?.clip.trimStart, const Duration(milliseconds: 150));
    });

    test('gives every take a layer id of its own', () {
      final layers = layersFor(
        [
          clip('a', take: take('a_second')),
          clip('b', take: take('b_second')),
        ],
      );

      expect(
        layers.map((layer) => layer.id).toSet(),
        hasLength(2),
      );
    });
  });
}
