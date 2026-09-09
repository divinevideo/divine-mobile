import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

DivineVideoClip _clip({String id = 'clip-1'}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/docs/$id.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.square,
  originalAspectRatio: 1,
  trimStart: const Duration(seconds: 1),
  volume: 0.5,
);

WidgetLayer _widgetLayer({
  Map<String, dynamic>? meta,
  Map<String, dynamic>? exportMeta,
}) => WidgetLayer(
  widget: const SizedBox.shrink(),
  meta: meta,
  exportConfigs: WidgetLayerExportConfigs(id: 'l1', meta: exportMeta),
);

void main() {
  group(DetachedClipLayerData, () {
    group('toMeta', () {
      test('marks the map as a detached clip and carries the clip', () {
        final meta = DetachedClipLayerData(
          clip: _clip(),
          layerId: 'layer-1',
        ).toMeta();

        expect(meta[detachedClipLayerKindKey], detachedClipLayerKind);
        expect(meta[detachedClipLayerClipKey], isA<Map<String, dynamic>>());
      });

      test('snapshots how long the clip plays', () {
        final meta = DetachedClipLayerData(
          clip: _clip(),
          layerId: 'layer-1',
        ).toMeta();

        // 6 s file trimmed 1 s at the head.
        expect(
          DetachedClipLayerData.playbackDurationOf(meta),
          const Duration(seconds: 5),
        );
      });
    });

    group('fromMeta', () {
      test('round-trips the clip, resolving paths against documentsPath', () {
        final meta = DetachedClipLayerData(
          clip: _clip(),
          layerId: 'layer-1',
        ).toMeta();

        final restored = DetachedClipLayerData.fromMeta(meta, '/new-docs');

        expect(restored, isNotNull);
        expect(restored!.clip.id, 'clip-1');
        // The clip serializes basenames so an iOS container move cannot strand
        // the layer's video; the path has to come back rooted at the new one.
        expect(restored.clip.video?.file?.path, '/new-docs/clip-1.mp4');
        expect(restored.clip.trimStart, const Duration(seconds: 1));
        expect(restored.clip.volume, 0.5);
      });

      test('returns null for a sticker meta', () {
        final restored = DetachedClipLayerData.fromMeta({
          'description': 'a sticker',
        }, '/docs');

        expect(restored, isNull);
      });

      test('returns null rather than throwing on a corrupt clip payload', () {
        final restored = DetachedClipLayerData.fromMeta({
          detachedClipLayerKindKey: detachedClipLayerKind,
          detachedClipLayerClipKey: {'id': 'clip-1'},
        }, '/docs');

        // A single unreadable layer must not abort the whole editor import.
        expect(restored, isNull);
      });

      test('returns null when the clip payload is not a map', () {
        expect(
          DetachedClipLayerData.fromMeta({
            detachedClipLayerKindKey: detachedClipLayerKind,
            detachedClipLayerClipKey: 'nonsense',
          }, '/docs'),
          isNull,
        );
      });
    });

    group('playbackDurationOf', () {
      test('returns null for a sticker meta', () {
        expect(
          DetachedClipLayerData.playbackDurationOf({'description': 'sticker'}),
          isNull,
        );
      });

      test('returns null for a detached meta written before the key', () {
        // An older draft's layer has no snapshot; the timeline then leaves the
        // bar unbounded rather than capping it at zero.
        expect(
          DetachedClipLayerData.playbackDurationOf({
            detachedClipLayerKindKey: detachedClipLayerKind,
          }),
          isNull,
        );
      });
    });

    group('isDetachedClipLayer', () {
      test('is true for a layer whose export meta carries the marker', () {
        final meta = DetachedClipLayerData(
          clip: _clip(),
          layerId: 'layer-1',
        ).toMeta();

        expect(
          DetachedClipLayerData.isDetachedClipLayer(
            _widgetLayer(exportMeta: meta),
          ),
          isTrue,
        );
      });

      test('is true for a live layer that only set Layer.meta', () {
        final meta = DetachedClipLayerData(
          clip: _clip(),
          layerId: 'layer-1',
        ).toMeta();

        expect(
          DetachedClipLayerData.isDetachedClipLayer(_widgetLayer(meta: meta)),
          isTrue,
        );
      });

      test('is false for a sticker layer', () {
        expect(
          DetachedClipLayerData.isDetachedClipLayer(
            _widgetLayer(meta: {'description': 'a sticker'}),
          ),
          isFalse,
        );
      });

      test('is false for a non-widget layer', () {
        expect(
          DetachedClipLayerData.isDetachedClipLayer(TextLayer(text: 'hi')),
          isFalse,
        );
      });
    });

    group('metaOf', () {
      test('prefers the export meta a re-imported layer comes back with', () {
        final exportMeta = DetachedClipLayerData(
          clip: _clip(id: 'a'),
          layerId: 'layer-1',
        ).toMeta();

        final found = DetachedClipLayerData.metaOf(
          _widgetLayer(meta: {'description': 'stale'}, exportMeta: exportMeta),
        );

        expect(found, same(exportMeta));
      });

      test('falls back to the live layer meta', () {
        final meta = DetachedClipLayerData(
          clip: _clip(),
          layerId: 'layer-1',
        ).toMeta();

        expect(
          DetachedClipLayerData.metaOf(_widgetLayer(meta: meta)),
          same(meta),
        );
      });

      test('returns null when neither slot carries the marker', () {
        expect(DetachedClipLayerData.metaOf(_widgetLayer()), isNull);
      });
    });
  });
}
