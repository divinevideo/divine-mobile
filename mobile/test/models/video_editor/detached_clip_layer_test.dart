import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

DivineVideoClip _clip({
  String id = 'clip-1',
  String? filePath,
  String? thumbnailPath,
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file(filePath ?? '/docs/$id.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.square,
  originalAspectRatio: 1,
  trimStart: const Duration(seconds: 1),
  volume: 0.5,
  thumbnailPath: thumbnailPath,
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
    test(
      'finds every detached clip asset reachable through editor history',
      () {
        final first = _clip(
          id: 'first',
          filePath: '/old/container/first.mp4',
          thumbnailPath: '/old/container/first.jpg',
        );
        final second = _clip(
          id: 'second',
          filePath: '/old/container/second.mp4',
          thumbnailPath: '/old/container/second.jpg',
        );

        final history = <String, dynamic>{
          'history': [
            {
              'layers': [
                DetachedClipLayerData(clip: first, layerId: 'layer-1').toMeta(),
              ],
            },
            {
              'layers': [
                DetachedClipLayerData(
                  clip: second,
                  layerId: 'layer-2',
                ).toMeta(),
              ],
            },
          ],
        };

        expect(
          DetachedClipLayerData.ownedFilePathsInHistory(history, '/documents'),
          {
            '/documents/first.mp4',
            '/documents/first.jpg',
            '/documents/second.mp4',
            '/documents/second.jpg',
          },
        );
      },
    );

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

    group('rebase', () {
      test('re-points a copy at its own layer', () {
        final meta = DetachedClipLayerData(
          clip: _clip(),
          layerId: 'layer-1',
        ).toMeta();

        final copy = DetachedClipLayerData.rebase(
          meta,
          layerId: 'layer-1_copy',
        );

        // Without this the copy reads the original's window off the timeline
        // while the export uses its own, and the two only agree while the copy
        // has not been moved.
        expect(DetachedClipLayerData.layerIdOf(copy), 'layer-1_copy');
        expect(copy![detachedClipLayerClipKey], meta[detachedClipLayerClipKey]);
      });

      test('keeps the existing offset when none is given', () {
        final meta = DetachedClipLayerData(
          clip: _clip(),
          layerId: 'layer-1',
          sourceOffset: const Duration(seconds: 2),
        ).toMeta();

        final copy = DetachedClipLayerData.rebase(meta, layerId: 'copy');

        // A duplicate shows the same stretch of footage as its source.
        expect(
          DetachedClipLayerData.sourceOffsetOf(copy),
          const Duration(seconds: 2),
        );
      });

      test('carries a new offset for a split tail', () {
        final meta = DetachedClipLayerData(
          clip: _clip(),
          layerId: 'layer-1',
        ).toMeta();

        final tail = DetachedClipLayerData.rebase(
          meta,
          layerId: 'tail',
          sourceOffset: const Duration(seconds: 3),
        );

        expect(
          DetachedClipLayerData.sourceOffsetOf(tail),
          const Duration(seconds: 3),
        );
      });

      test('leaves a sticker alone', () {
        expect(
          DetachedClipLayerData.rebase({'kind': 'sticker'}, layerId: 'x'),
          isNull,
        );
      });
    });

    group('remainingPlaybackOf', () {
      test('is the whole clip for a layer that starts at its head', () {
        final meta = DetachedClipLayerData(
          clip: _clip(),
          layerId: 'layer-1',
        ).toMeta();

        // Six seconds of source less the one-second trim.
        expect(
          DetachedClipLayerData.remainingPlaybackOf(meta),
          const Duration(seconds: 5),
        );
      });

      test('is what is left after a split', () {
        final meta = DetachedClipLayerData(
          clip: _clip(),
          layerId: 'tail',
          sourceOffset: const Duration(seconds: 4),
        ).toMeta();

        // The timeline caps the bar at this, so a tail cannot be stretched
        // back over footage that is behind its own start.
        expect(
          DetachedClipLayerData.remainingPlaybackOf(meta),
          const Duration(seconds: 1),
        );
      });

      test('never goes negative', () {
        final meta = DetachedClipLayerData(
          clip: _clip(),
          layerId: 'tail',
          sourceOffset: const Duration(seconds: 9),
        ).toMeta();

        expect(
          DetachedClipLayerData.remainingPlaybackOf(meta),
          Duration.zero,
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
