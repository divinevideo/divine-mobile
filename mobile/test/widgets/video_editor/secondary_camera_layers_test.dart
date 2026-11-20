import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_recorder/secondary_camera_take.dart';
import 'package:openvine/widgets/video_editor/secondary_camera_layers.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show Layer, LayerMaskShape, WidgetLayer;
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
      model.AspectRatio targetAspectRatio = model.AspectRatio.vertical,
    }) => DivineVideoClip(
      id: id,
      video: EditorVideo.file(File('/docs/$id.mp4')),
      duration: duration,
      recordedAt: now,
      targetAspectRatio: targetAspectRatio,
      originalAspectRatio: 9 / 16,
      trimStart: trimStart,
      secondaryCamera: take,
    );

    SecondaryCameraTake take(
      String id, {
      Duration duration = const Duration(seconds: 4),
      Offset pipCenter = SecondaryCameraTake.defaultPipCenter,
      double pipScale = 1,
      double pipRotation = 0,
      model.AspectRatio pipAspectRatio = model.AspectRatio.vertical,
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
      pipScale: pipScale,
      pipRotation: pipRotation,
      pipAspectRatio: pipAspectRatio,
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

    test('pinches and turns the layer like the viewfinder window, whole '
        'inside the frame', () {
      final layer = layersFor([
        clip(
          'a',
          take: take(
            'a_second',
            pipCenter: const Offset(1, 0),
            pipScale: 1.5,
            pipRotation: math.pi / 2,
          ),
        ),
      ]).single;

      expect(layer.scale, 1.5);
      expect(layer.rotation, math.pi / 2);
      // 486 by 864 upright, so on its side it covers 864 by 486.
      expect(layer.offset.dx, closeTo((canvas.width - 864) / 2, 1e-6));
      expect(layer.offset.dy, closeTo(-(canvas.height - 486) / 2, 1e-6));
    });

    test('masks a square window to the middle of the second picture, whole '
        'inside the frame', () {
      final layer = layersFor([
        clip(
          'a',
          take: take(
            'a_second',
            pipCenter: const Offset(0.5, 0),
            pipAspectRatio: model.AspectRatio.square,
          ),
        ),
      ]).single;

      final width = canvas.width * SecondaryCameraTake.pipWidthFraction;
      expect(layer.width, closeTo(width, 1e-9));
      expect(layer.mask?.center, const Offset(0.5, 0.5));
      expect(layer.mask?.size.width, closeTo(1, 1e-9));
      expect(layer.mask?.size.height, closeTo(9 / 16, 1e-9));
      // Kept inside by the square it shows, not by the taller layer box.
      expect(layer.offset.dy, closeTo(-(canvas.height - width) / 2, 1e-6));
    });

    group('a square take', () {
      // The viewfinder of a square take shows the middle square of the
      // frame, 1080 wide here, and measures the window against it.
      const kept = 1080.0;

      test('places the window against the square it keeps', () {
        final layer = layersFor([
          clip(
            'a',
            targetAspectRatio: model.AspectRatio.square,
            take: take('a_second', pipCenter: const Offset(0.5, 0.3)),
          ),
        ]).single;

        expect(
          layer.width,
          closeTo(kept * SecondaryCameraTake.pipWidthFraction, 1e-9),
        );
        expect(layer.offset.dy, closeTo(-0.2 * kept, 1e-9));
      });

      test('keeps a window dragged to the top inside the square', () {
        final layer = layersFor([
          clip(
            'a',
            targetAspectRatio: model.AspectRatio.square,
            take: take('a_second', pipCenter: const Offset(0.5, 0)),
          ),
        ]).single;

        final height = layer.width! / (9 / 16);
        expect(layer.offset.dy, closeTo(-(kept - height) / 2, 1e-9));
      });
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

    group('following its clip', () {
      List<Layer> follow(
        List<Layer> layers,
        List<DivineVideoClip> clips, {
        Set<String> removed = const {},
      }) => secondaryCameraLayersFollowingClips(
        layers,
        clips: clips,
        removedClipIds: removed,
      );

      DetachedClipLayerData? dataOf(Layer layer) =>
          DetachedClipLayerData.fromMeta(
            DetachedClipLayerData.metaOf(layer),
            '/docs',
          );

      DetachedClipAnchor? anchorOf(Layer layer) =>
          DetachedClipLayerData.anchorOf(DetachedClipLayerData.metaOf(layer));

      test('follows the clip it was placed over', () {
        final layer = layersFor([clip('a', take: take('a_second'))]).single;

        expect(anchorOf(layer)?.clipId, 'a');
      });

      test('moves with its clip when an earlier clip is deleted', () {
        final owner = clip('b', take: take('b_second'));
        final layers = layersFor([clip('a'), owner]);
        expect(layers.single.startTime, const Duration(seconds: 4));

        final followed = follow(layers, [owner]).single;

        expect(followed.startTime, Duration.zero);
        expect(followed.endTime, const Duration(seconds: 4));
      });

      test('moves with its clip when the clips are reordered', () {
        final owner = clip('a', take: take('a_second'));
        final other = clip('b', duration: const Duration(seconds: 2));
        final layers = layersFor([owner, other]);

        final followed = follow(layers, [other, owner]).single;

        expect(followed.startTime, const Duration(seconds: 2));
        expect(followed.endTime, const Duration(seconds: 6));
      });

      test('plays the stretch its trimmed clip plays', () {
        final owner = clip(
          'a',
          duration: const Duration(seconds: 6),
          take: take('a_second', duration: const Duration(seconds: 6)),
        );
        final layers = layersFor([owner]);

        final followed = follow(layers, [
          owner.copyWith(
            trimStart: const Duration(seconds: 1),
            trimEnd: const Duration(seconds: 2),
          ),
        ]).single;

        expect(followed.endTime, const Duration(seconds: 3));
        final played = dataOf(followed)!.clip;
        expect(played.trimStart, const Duration(seconds: 1));
        expect(played.trimmedDuration, const Duration(seconds: 3));
      });

      test('plays at its clip speed', () {
        final owner = clip('a', take: take('a_second'));
        final layers = layersFor([owner]);

        final followed = follow(layers, [
          owner.copyWith(playbackSpeed: 2),
        ]).single;

        expect(followed.endTime, const Duration(seconds: 2));
        expect(dataOf(followed)!.clip.playbackSpeed, 2);
      });

      test('goes with its clip when the clip is deleted', () {
        final layers = layersFor([clip('a', take: take('a_second'))]);

        expect(follow(layers, const [], removed: {'a'}), isEmpty);
      });

      test('keeps the place the creator moved it to', () {
        final owner = clip('a', take: take('a_second'));
        final layer = layersFor([owner, clip('b')]).single
          ..startTime = const Duration(seconds: 1)
          ..endTime = const Duration(seconds: 5);

        final followed = follow([layer], [clip('b'), owner]).single;

        expect(followed.startTime, const Duration(seconds: 1));
        expect(anchorOf(followed), isNull);
      });

      test('stops following once its clip is gone, as after a split', () {
        final layers = layersFor([clip('a', take: take('a_second'))]);

        final followed = follow(layers, [
          clip('a_start', duration: const Duration(seconds: 2)),
        ]).single;

        expect(followed.startTime, Duration.zero);
        expect(followed.endTime, const Duration(seconds: 4));
        expect(anchorOf(followed), isNull);
      });

      test('leaves the layers alone when nothing moved', () {
        final clips = [clip('a', take: take('a_second')), clip('b')];
        final layers = layersFor(clips);

        expect(identical(follow(layers, clips), layers), isTrue);
      });
    });
  });
}
