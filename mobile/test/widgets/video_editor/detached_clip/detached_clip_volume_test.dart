// ABOUTME: Tests the write of a detached clip's volume onto its layer, which
// ABOUTME: the timeline's volume panel makes when an arc is let go or tapped.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_volume.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show Layer, ProImageEditorState, WidgetLayer, WidgetLayerExportConfigs;
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _FakeLayer extends Fake implements Layer {}

/// A clip detached onto the canvas as the layer `layer-d`, at [volume].
WidgetLayer _detachedLayer({required double volume}) {
  final meta = DetachedClipLayerData(
    clip: DivineVideoClip(
      id: 'clip-d',
      video: EditorVideo.file('/test/clip-d.mp4'),
      duration: const Duration(seconds: 2),
      recordedAt: DateTime(2025),
      originalAspectRatio: 9 / 16,
      targetAspectRatio: .vertical,
      volume: volume,
    ),
    layerId: 'layer-d',
  ).toMeta();
  return WidgetLayer(
    id: 'layer-d',
    widget: const SizedBox.shrink(),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(id: 'layer-d', meta: meta),
  );
}

void main() {
  group('setDetachedClipVolume', () {
    late _MockProImageEditorState editor;

    setUpAll(() => registerFallbackValue(_FakeLayer()));

    setUp(() {
      editor = _MockProImageEditorState();
      when(() => editor.activeLayers).thenReturn([
        _detachedLayer(volume: 0.5),
      ]);
      when(
        () => editor.replaceLayer(
          index: any(named: 'index'),
          layer: any(named: 'layer'),
        ),
      ).thenAnswer((_) {});
    });

    test('writes the new volume onto the layer, export included', () {
      setDetachedClipVolume(editor, 'layer-d', 2);

      final written =
          verify(
                () => editor.replaceLayer(
                  index: 0,
                  layer: captureAny(named: 'layer'),
                ),
              ).captured.single
              as WidgetLayer;
      expect(DetachedClipLayerData.volumeOf(written.meta), 2);
      expect(DetachedClipLayerData.volumeOf(written.exportConfigs.meta), 2);
    });

    test('writes nothing when a drag ends on the volume the clip plays at', () {
      // The arc reports every drag's end, moved or not; an undo step that
      // undoes nothing reads as a broken undo.
      setDetachedClipVolume(editor, 'layer-d', 0.5);

      verifyNever(
        () => editor.replaceLayer(
          index: any(named: 'index'),
          layer: any(named: 'layer'),
        ),
      );
    });

    test('writes nothing for a layer that is gone', () {
      setDetachedClipVolume(editor, 'layer-x', 0);

      verifyNever(
        () => editor.replaceLayer(
          index: any(named: 'index'),
          layer: any(named: 'layer'),
        ),
      );
    });
  });
}
