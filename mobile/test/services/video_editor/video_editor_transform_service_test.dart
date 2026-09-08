import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_transform_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform({required this.documentsPath});

  final String documentsPath;

  @override
  Future<String?> getApplicationCachePath() async {
    return path.join(path.dirname(documentsPath), 'cache');
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return documentsPath;
  }
}

class _FakeProVideoEditor extends ProVideoEditor {
  final canceledTaskIds = <String>[];
  final renderedPaths = <String>[];
  final renderedData = <VideoRenderData>[];

  bool cancelShouldThrow = false;
  bool renderShouldThrow = false;
  bool createPartialOutputBeforeThrow = false;

  @override
  void initializeStream() {}

  @override
  Future<void> cancel(String taskId) async {
    canceledTaskIds.add(taskId);
    if (cancelShouldThrow) {
      throw ArgumentError('unknown task');
    }
  }

  @override
  Future<String> renderVideoToFile(
    String filePath,
    VideoRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    renderedPaths.add(filePath);
    renderedData.add(value);

    if (renderShouldThrow) {
      if (createPartialOutputBeforeThrow) {
        await File(filePath).writeAsString('partial transform render');
      }
      throw Exception('transform render failed');
    }

    return filePath;
  }
}

void main() {
  late Directory tempDir;
  late String documentsPath;
  late PathProviderPlatform originalPathProvider;
  late ProVideoEditor originalProVideoEditor;
  late _FakeProVideoEditor proVideoEditor;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    originalPathProvider = PathProviderPlatform.instance;
    originalProVideoEditor = ProVideoEditor.instance;

    tempDir = await Directory.systemTemp.createTemp(
      'video_editor_transform_service_test_',
    );
    documentsPath = path.join(tempDir.path, 'documents');
    await Directory(documentsPath).create(recursive: true);

    PathProviderPlatform.instance = _FakePathProviderPlatform(
      documentsPath: documentsPath,
    );
    proVideoEditor = _FakeProVideoEditor();
    ProVideoEditor.instance = proVideoEditor;
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    ProVideoEditor.instance = originalProVideoEditor;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('VideoEditorTransformService', () {
    test(
      'renders the full clip with the transform baked into a new file',
      () async {
        final inputPath = path.join(tempDir.path, 'source.mp4');
        final sourceClip = _clip(id: 'clip-1', inputPath: inputPath);
        const transform = ExportTransform(
          x: 10,
          y: 20,
          width: 100,
          height: 100,
          rotateTurns: 1,
          flipX: true,
        );

        final result = await VideoEditorTransformService.transformClip(
          sourceClip: sourceClip,
          transform: transform,
          renderId: 'transform-render-1',
        );

        expect(proVideoEditor.canceledTaskIds, isEmpty);
        expect(proVideoEditor.renderedPaths, hasLength(1));

        // The output filename is timestamped per render (so a repeat transform
        // never targets the previous output), so assert on its shape rather than
        // an exact path.
        final outputPath = proVideoEditor.renderedPaths.single;
        expect(result.file?.path, outputPath);
        expect(path.dirname(outputPath), documentsPath);
        expect(path.basename(outputPath), startsWith('clip-1_transformed_'));
        expect(path.basename(outputPath), endsWith('.mp4'));

        final renderData = proVideoEditor.renderedData.single;
        expect(renderData.id, 'transform-render-1');
        expect(renderData.transform, same(transform));
        expect(renderData.shouldOptimizeForNetworkUse, isTrue);
        expect(renderData.videoSegments, hasLength(1));
        expect(
          await renderData.videoSegments!.single.video.safeFilePath(),
          inputPath,
        );
      },
    );

    test(
      'does not cancel before rendering when there is no active render',
      () async {
        proVideoEditor.cancelShouldThrow = true;
        final sourceClip = _clip(
          id: 'clip-cancel-miss',
          inputPath: path.join(tempDir.path, 'source.mp4'),
        );

        await VideoEditorTransformService.transformClip(
          sourceClip: sourceClip,
          transform: const ExportTransform(),
          renderId: 'transform-render-missing',
        );

        expect(proVideoEditor.canceledTaskIds, isEmpty);
        expect(proVideoEditor.renderedData, hasLength(1));
      },
    );

    test('deletes partial output when rendering fails', () async {
      proVideoEditor
        ..renderShouldThrow = true
        ..createPartialOutputBeforeThrow = true;
      final sourceClip = _clip(
        id: 'clip-partial-output',
        inputPath: path.join(tempDir.path, 'source.mp4'),
      );

      await expectLater(
        () => VideoEditorTransformService.transformClip(
          sourceClip: sourceClip,
          transform: const ExportTransform(),
          renderId: 'transform-render-failure',
        ),
        throwsException,
      );

      expect(proVideoEditor.renderedPaths, hasLength(1));
      expect(File(proVideoEditor.renderedPaths.single).existsSync(), isFalse);
    });
  });
}

DivineVideoClip _clip({
  required String id,
  required String inputPath,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file(inputPath),
    duration: const Duration(seconds: 6),
    recordedAt: DateTime(2026, 6, 10, 12),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
  );
}
