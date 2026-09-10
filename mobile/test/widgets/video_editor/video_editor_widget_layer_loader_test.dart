// ABOUTME: Round-trip coverage for the editor's widget-layer loader: a
// ABOUTME: detached clip and a sticker share one meta channel and must not be
// ABOUTME: rebuilt as each other after an export/reopen.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart'
    show LocalizedText, StickerData, StickerPackData;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';
import 'package:openvine/widgets/video_editor/video_editor_widget_layer_loader.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show
        ImportEditorConfigs,
        ImportStateHistory,
        WidgetLayer,
        WidgetLayerExportConfigs;
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

DivineVideoClip _clip() => DivineVideoClip(
  id: 'clip-1',
  video: EditorVideo.file('/documents/clip-1.mp4'),
  duration: const Duration(seconds: 4),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

const _sticker = StickerData.network(
  'https://stickers.example.com/heart.png',
  description: LocalizedText({'en': 'Red heart'}),
  tags: ['heart'],
  packData: StickerPackData(packId: 'reactions', packName: 'Reactions'),
);

/// Wraps [layer] in the shape `ExportStateHistory.toMap` produces, which is
/// what a draft persists.
Map<String, dynamic> _exportedHistory(WidgetLayer layer) => {
  'position': 0,
  'history': [
    {
      'layers': [layer.toMap()],
    },
  ],
};

/// Re-imports through the same loader `VideoEditorCanvas` installs.
List<Object?> _reopen(Map<String, dynamic> history) {
  final imported = ImportStateHistory.fromMap(
    history,
    configs: const ImportEditorConfigs(
      widgetLoader: videoEditorWidgetLayerLoader,
    ),
  );
  return imported.stateHistory.first.layers;
}

void main() {
  group('videoEditorWidgetLayerLoader', () {
    test('rebuilds a detached clip as its live canvas view', () {
      final meta = DetachedClipLayerData(
        clip: _clip(),
        layerId: 'layer-1',
      ).toMeta();
      final layer = WidgetLayer(
        width: 120,
        widget: DetachedClipLayerView(meta: meta),
        meta: meta,
        exportConfigs: WidgetLayerExportConfigs(id: 'detached-1', meta: meta),
      );

      final restored = _reopen(_exportedHistory(layer)).single! as WidgetLayer;

      // Nothing but the meta map survives the round-trip, so the kind marker is
      // the only thing that can tell the loader which widget to rebuild.
      expect(restored.widget, isA<DetachedClipLayerView>());
      expect((restored.widget as DetachedClipLayerView).meta, equals(meta));
    });

    test('still rebuilds a sticker as a sticker', () {
      final layer = WidgetLayer(
        width: 120,
        widget: const VideoEditorSticker(
          sticker: _sticker,
          enableLimitCacheSize: false,
        ),
        meta: _sticker.toJson(),
        exportConfigs: WidgetLayerExportConfigs(
          id: 'sticker-1',
          meta: _sticker.toJson(),
        ),
      );

      final restored = _reopen(_exportedHistory(layer)).single! as WidgetLayer;

      // Detached clips joined a channel stickers already owned; an older
      // draft's layers carry no kind marker at all and must still come back.
      expect(restored.widget, isA<VideoEditorSticker>());
    });

    test('falls back to the sticker loader for unknown meta', () {
      expect(videoEditorWidgetLayerLoader('x'), isA<SizedBox>());
    });
  });
}
