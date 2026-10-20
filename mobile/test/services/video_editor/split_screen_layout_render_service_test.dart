// ABOUTME: Tests the composition a split-screen layout renders: each cell's
// ABOUTME: placement and matte, and the held last frame of a shorter cell

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show Alignment;
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/services/video_editor/split_screen_layout_render_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Thrown by the fake renderer once it has recorded the task, so the test
/// stops at the composition instead of signing a file that was never written.
class _Rendered implements Exception {}

class _RecordingProVideoEditor extends ProVideoEditor {
  _RecordingProVideoEditor(this.frame);

  Uint8List frame;
  final tasks = <VideoRenderData>[];
  final thumbnailRequests = <ThumbnailConfigs>[];

  @override
  Stream<dynamic> initializeStream() => const Stream.empty();

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async => VideoMetadata(
    duration: const Duration(seconds: 4),
    extension: 'mp4',
    fileSize: 1,
    resolution: const ui.Size(1080, 1920),
    rotation: 0,
    bitrate: 1,
  );

  @override
  Future<List<Uint8List>> getThumbnails(
    ThumbnailConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    thumbnailRequests.add(value);
    return [frame];
  }

  @override
  Future<String> renderVideoToFile(
    String outputPath,
    VideoRenderData renderData, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    tasks.add(renderData);
    throw _Rendered();
  }
}

DivineVideoClip _clip(String id, {int seconds = 2}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: Duration(seconds: seconds),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

Future<Uint8List> _pngFrame() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xFF00FF00), ui.BlendMode.src);
  final image = await recorder.endRecording().toImage(9, 16);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(SplitScreenLayoutRenderService, () {
    final canvas = VideoEditorConstants.quality.resolutionForAspectRatio(
      model.AspectRatio.vertical,
    );
    late Directory documents;
    late PathProviderPlatform originalPathProvider;
    late ProVideoEditor originalEditor;
    late _RecordingProVideoEditor editor;

    setUp(() async {
      documents = Directory.systemTemp.createTempSync('split_layout');
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProvider(documents.path);
      originalEditor = ProVideoEditor.instance;
      editor = _RecordingProVideoEditor(await _pngFrame());
      ProVideoEditor.instance = editor;
    });

    tearDown(() {
      PathProviderPlatform.instance = originalPathProvider;
      ProVideoEditor.instance = originalEditor;
      if (documents.existsSync()) documents.deleteSync(recursive: true);
    });

    /// Renders [cells] side by side and returns the task the renderer got.
    Future<VideoRenderData> renderSideBySide(
      List<({DivineVideoClip clip, double zoom})> cells,
    ) async {
      await expectLater(
        SplitScreenLayoutRenderService.render(
          cells: [
            for (final (index, cell) in cells.indexed)
              (
                clip: cell.clip,
                rect: ui.Rect.fromLTRB(index * 0.5, 0, index * 0.5 + 0.5, 1),
                alignment: Alignment.center,
                zoom: cell.zoom,
              ),
          ],
          aspectRatio: model.AspectRatio.vertical,
          backgroundColor: const ui.Color(0xFFFF0000),
          taskId: 'layout',
        ),
        throwsA(isA<_Rendered>()),
      );
      return editor.tasks.single;
    }

    test('places an untouched cell with the renderer’s cover fit', () async {
      final task = await renderSideBySide([
        (clip: _clip('a'), zoom: 1),
        (clip: _clip('b'), zoom: 1),
      ]);

      final composition = task.composition!;
      expect(composition.canvasSize, canvas);
      expect(composition.backgroundColor, const ui.Color(0xFFFF0000));
      expect(task.endTime, const Duration(seconds: 2));
      final transforms = [
        for (final layer in composition.layers) layer.clips.single.transform!,
      ];
      expect(transforms.map((t) => t.offset), [
        ui.Offset.zero,
        ui.Offset(canvas.width / 2, 0),
      ]);
      expect(transforms.first.size, ui.Size(canvas.width / 2, canvas.height));
      expect(transforms.first.fit, SegmentFit.cover);
      expect(composition.layers.map((layer) => layer.mask), [null, null]);
      expect(task.imageLayers, isEmpty);
    });

    test('draws a zoomed cell larger and cuts it back with a matte', () async {
      final task = await renderSideBySide([
        (clip: _clip('a'), zoom: 2),
        (clip: _clip('b'), zoom: 1),
      ]);

      final layer = task.composition!.layers.first;
      final transform = layer.clips.single.transform!;
      // A 9:16 clip covering a half-width cell is as wide as the canvas;
      // zoomed twice, it overhangs the cell on every side by the same amount.
      final cellWidth = canvas.width / 2;
      expect(
        transform.size,
        ui.Size(canvas.width * 2, canvas.height * 2),
      );
      expect(
        transform.offset,
        ui.Offset(-(canvas.width * 2 - cellWidth) / 2, -canvas.height / 2),
      );
      expect(transform.fit, SegmentFit.fill);
      expect(layer.mask, isNotNull);
    });

    test('leaves a green-screen clip as its file was keyed', () async {
      final keyed = _clip(
        'a',
      ).copyWith(chromaKey: const ClipChromaKey(key: ChromaKey()));
      expect(keyed.chromaKey, isNotNull);

      final task = await renderSideBySide([
        (clip: keyed, zoom: 1),
        (clip: _clip('b'), zoom: 1),
      ]);

      expect(task.composition!.layers.map((layer) => layer.chromaKey), [
        null,
        null,
      ]);
    });

    test('holds a shorter cell on its last frame until the end', () async {
      final task = await renderSideBySide([
        (clip: _clip('long', seconds: 3), zoom: 1),
        (clip: _clip('short'), zoom: 1),
      ]);

      expect(task.endTime, const Duration(seconds: 3));
      final hold = task.imageLayers!.single;
      expect(hold.offset, ui.Offset(canvas.width / 2, 0));
      expect(hold.size, ui.Size(canvas.width / 2, canvas.height));
      expect(hold.startTime, lessThan(const Duration(seconds: 2)));
      expect(hold.endTime, isNull);
      // The frame is read just inside the short clip's end.
      final requested = editor.thumbnailRequests.single.timestamps.single;
      expect(requested, lessThan(const Duration(seconds: 2)));
      expect(requested, greaterThan(const Duration(milliseconds: 1900)));
    });

    test(
      'renders without the hold when the last frame cannot be decoded',
      () async {
        editor.frame = Uint8List.fromList(const [1, 2, 3]);

        final task = await renderSideBySide([
          (clip: _clip('long', seconds: 3), zoom: 1),
          (clip: _clip('short'), zoom: 1),
        ]);

        expect(editor.thumbnailRequests, hasLength(1));
        expect(task.endTime, const Duration(seconds: 3));
        expect(task.imageLayers, isEmpty);
      },
    );
  });
}
