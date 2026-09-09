import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/detached_clip_composite.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show EditorVideo, SegmentFit;

DivineVideoClip _clip({
  String id = 'clip-1',
  Duration duration = const Duration(seconds: 6),
  Duration trimStart = Duration.zero,
  Duration trimEnd = Duration.zero,
  double? playbackSpeed,
  double volume = 1,
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/docs/$id.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.square,
  originalAspectRatio: 1,
  trimStart: trimStart,
  trimEnd: trimEnd,
  playbackSpeed: playbackSpeed,
  volume: volume,
);

ExportedLayer _exported(Layer layer, {Size size = const Size(90, 90)}) =>
    ExportedLayer(layer: layer, bytes: Uint8List(0), logicalSize: size);

WidgetLayer _detachedLayer(
  DivineVideoClip clip, {
  Offset offset = Offset.zero,
  Duration? startTime,
  Duration? endTime,
}) {
  final meta = DetachedClipLayerData(clip: clip, layerId: 'layer-1').toMeta();
  return WidgetLayer(
    widget: const SizedBox.shrink(),
    offset: offset,
    startTime: startTime,
    endTime: endTime,
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(id: 'l-${clip.id}', meta: meta),
  );
}

void main() {
  // Both clips end-to-end with no transition, so editor time and output time
  // are the same axis. Transition mapping has its own tests.
  final identityMap = TransitionTimelineMap.fromClips([
    _clip(id: 'track-1'),
    _clip(id: 'track-2'),
  ]);

  group('partitionDetachedClipLayers', () {
    test('sorts layers into below / detached / above by z-order', () {
      final below = _exported(TextLayer(text: 'under'));
      final detached = _exported(_detachedLayer(_clip()));
      final above = _exported(TextLayer(text: 'over'));

      final result = partitionDetachedClipLayers([
        below,
        detached,
        above,
      ], '/docs');

      expect(result.below, [below]);
      expect(result.detached.single.clip.id, 'clip-1');
      expect(result.above, [above]);
    });

    test('reports no detached clips for an ordinary layer stack', () {
      final layers = [
        _exported(TextLayer(text: 'a')),
        _exported(TextLayer(text: 'b')),
      ];

      final result = partitionDetachedClipLayers(layers, '/docs');

      // Nothing detached is what keeps the export single-pass for everyone
      // else, so this has to stay empty rather than merely unused.
      expect(result.detached, isEmpty);
      expect(result.below, layers);
      expect(result.above, isEmpty);
    });

    test('keeps every detached clip, in canvas order', () {
      final first = _detachedLayer(_clip(id: 'a'));
      final second = _detachedLayer(_clip(id: 'b'));

      final result = partitionDetachedClipLayers([
        _exported(first),
        _exported(second),
      ], '/docs');

      expect(result.detached.map((d) => d.clip.id), ['a', 'b']);
    });

    test('treats a detached layer with an unreadable clip as a raster', () {
      final broken = WidgetLayer(
        widget: const SizedBox.shrink(),
        exportConfigs: const WidgetLayerExportConfigs(
          id: 'l1',
          meta: {
            detachedClipLayerKindKey: detachedClipLayerKind,
            detachedClipLayerClipKey: {'id': 'oops'},
          },
        ),
      );

      final result = partitionDetachedClipLayers([_exported(broken)], '/docs');

      // Its captured frame is at least what the user last saw; dropping the
      // layer entirely would silently remove it from the export.
      expect(result.detached, isEmpty);
      expect(result.below, hasLength(1));
    });

    test('puts a layer between two detached clips in the above group', () {
      final middle = _exported(TextLayer(text: 'middle'));

      final result = partitionDetachedClipLayers([
        _exported(_detachedLayer(_clip(id: 'a'))),
        middle,
        _exported(_detachedLayer(_clip(id: 'b'))),
      ], '/docs');

      // Documented limitation: a raster sandwiched between two detached clips
      // ends up over both, because ordering it between them would need a
      // render pass per clip.
      expect(result.above, [middle]);
      expect(result.below, isEmpty);
    });
  });

  group('buildDetachedClipVideoLayer', () {
    const bodySize = Size(360, 640);
    const videoSize = Size(1080, 1920);
    // Editor body → video pixels.
    const scale = 3.0;

    DetachedClipExportLayer item(
      DivineVideoClip clip, {
      Offset offset = Offset.zero,
      Size logicalSize = const Size(90, 90),
      Duration? startTime,
      Duration? endTime,
    }) => DetachedClipExportLayer(
      clip: clip,
      layer: _detachedLayer(
        clip,
        offset: offset,
        startTime: startTime,
        endTime: endTime,
      ),
      logicalSize: logicalSize,
    );

    test('places a centred layer at the middle of the canvas', () {
      final layer = buildDetachedClipVideoLayer(
        item: item(_clip()),
        resolvedVideo: EditorVideo.file('/docs/clip-1.mp4'),
        bodySize: bodySize,
        videoSize: videoSize,
        timelineMap: identityMap,
        speedFlattened: false,
      );

      final transform = layer.clips.single.transform!;
      // Layer offsets are centre-relative; the renderer wants a top-left
      // corner, both scaled into video pixels.
      expect(
        transform.offset,
        const Offset((360 / 2 - 45) * scale, (640 / 2 - 45) * scale),
      );
      expect(transform.size, const Size(90 * scale, 90 * scale));
      expect(transform.fit, SegmentFit.contain);
    });

    test('carries the layer offset into video pixel space', () {
      final layer = buildDetachedClipVideoLayer(
        item: item(_clip(), offset: const Offset(20, -30)),
        resolvedVideo: EditorVideo.file('/docs/clip-1.mp4'),
        bodySize: bodySize,
        videoSize: videoSize,
        timelineMap: identityMap,
        speedFlattened: false,
      );

      expect(
        layer.clips.single.transform!.offset,
        const Offset((360 / 2 + 20 - 45) * scale, (640 / 2 - 30 - 45) * scale),
      );
    });

    test('applies the clip trim window and volume', () {
      final layer = buildDetachedClipVideoLayer(
        item: item(
          _clip(
            trimStart: const Duration(seconds: 1),
            trimEnd: const Duration(seconds: 2),
            volume: 0.25,
          ),
        ),
        resolvedVideo: EditorVideo.file('/docs/clip-1.mp4'),
        bodySize: bodySize,
        videoSize: videoSize,
        timelineMap: identityMap,
        speedFlattened: false,
      );

      final segment = layer.clips.single;
      expect(segment.startTime, const Duration(seconds: 1));
      expect(segment.endTime, const Duration(seconds: 4));
      expect(segment.volume, 0.25);
    });

    test('starts a layer with no window at the top of the timeline', () {
      final layer = buildDetachedClipVideoLayer(
        item: item(_clip()),
        resolvedVideo: EditorVideo.file('/docs/clip-1.mp4'),
        bodySize: bodySize,
        videoSize: videoSize,
        timelineMap: identityMap,
        speedFlattened: false,
      );

      expect(layer.clips.single.timelineStart, isNull);
    });

    test('places a windowed layer at its window start', () {
      final layer = buildDetachedClipVideoLayer(
        item: item(
          _clip(),
          startTime: const Duration(seconds: 2),
          endTime: const Duration(seconds: 5),
        ),
        resolvedVideo: EditorVideo.file('/docs/clip-1.mp4'),
        bodySize: bodySize,
        videoSize: videoSize,
        timelineMap: identityMap,
        speedFlattened: false,
      );

      expect(layer.clips.single.timelineStart, const Duration(seconds: 2));
    });

    test('cuts the clip to a window shorter than it', () {
      final layer = buildDetachedClipVideoLayer(
        item: item(
          _clip(),
          startTime: const Duration(seconds: 1),
          endTime: const Duration(seconds: 3),
        ),
        resolvedVideo: EditorVideo.file('/docs/clip-1.mp4'),
        bodySize: bodySize,
        videoSize: videoSize,
        timelineMap: identityMap,
        speedFlattened: false,
      );

      // A 6 s clip on a 2 s window plays 2 s, not 6.
      expect(layer.clips.single.endTime, const Duration(seconds: 2));
    });

    test('leaves a clip shorter than its window at its own end', () {
      final layer = buildDetachedClipVideoLayer(
        item: item(
          _clip(duration: const Duration(seconds: 2)),
          startTime: Duration.zero,
          endTime: const Duration(seconds: 10),
        ),
        resolvedVideo: EditorVideo.file('/docs/clip-1.mp4'),
        bodySize: bodySize,
        videoSize: videoSize,
        timelineMap: identityMap,
        speedFlattened: false,
      );

      expect(layer.clips.single.endTime, const Duration(seconds: 2));
    });

    test('reads a speed-flattened file from its own zero', () {
      final layer = buildDetachedClipVideoLayer(
        item: item(
          _clip(trimStart: const Duration(seconds: 1), playbackSpeed: 2),
        ),
        resolvedVideo: EditorVideo.file('/cache/flat.mp4'),
        bodySize: bodySize,
        videoSize: videoSize,
        timelineMap: identityMap,
        speedFlattened: true,
      );

      final segment = layer.clips.single;
      // The flattened render already is the trimmed, sped-up section, so
      // re-applying the trim would cut a second second off it.
      expect(segment.startTime, isNull);
      // 5 s of source at 2× is 2.5 s of playback.
      expect(segment.endTime, const Duration(milliseconds: 2500));
      expect(segment.video.file?.path, '/cache/flat.mp4');
    });

    test('never carries a playback speed the composition would reject', () {
      final layer = buildDetachedClipVideoLayer(
        item: item(_clip(playbackSpeed: 2)),
        resolvedVideo: EditorVideo.file('/cache/flat.mp4'),
        bodySize: bodySize,
        videoSize: videoSize,
        timelineMap: identityMap,
        speedFlattened: true,
      );

      // VideoLayer.toAsyncMap asserts on this; a speed here fails the export
      // in release with a bare assertion instead of a render.
      expect(layer.clips.single.playbackSpeed, isNull);
      expect(layer.clips.single.reverseVideo, isFalse);
    });
  });
}
