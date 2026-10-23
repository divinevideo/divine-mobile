import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_boomerang_service.dart';
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
  final renderedPaths = <String>[];
  final renderedData = <VideoRenderData>[];

  double? frameRate = 30;
  bool metadataShouldThrow = false;
  bool renderShouldThrow = false;

  @override
  void initializeStream() {}

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async {
    if (metadataShouldThrow) throw Exception('no metadata');
    return VideoMetadata(
      duration: const Duration(seconds: 6),
      extension: 'mp4',
      fileSize: 1024,
      resolution: const Size(1080, 1920),
      rotation: 0,
      bitrate: 1000,
      frameRate: frameRate,
    );
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
      await File(filePath).writeAsString('partial boomerang');
      throw Exception('boomerang render failed');
    }
    return filePath;
  }
}

void main() {
  late Directory tempDir;
  late String documentsPath;
  late String inputPath;
  late PathProviderPlatform originalPathProvider;
  late ProVideoEditor originalProVideoEditor;
  late _FakeProVideoEditor proVideoEditor;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    originalPathProvider = PathProviderPlatform.instance;
    originalProVideoEditor = ProVideoEditor.instance;

    tempDir = await Directory.systemTemp.createTemp(
      'video_editor_boomerang_service_test_',
    );
    documentsPath = path.join(tempDir.path, 'documents');
    await Directory(documentsPath).create(recursive: true);
    inputPath = path.join(tempDir.path, 'source.mp4');

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

  group(VideoEditorBoomerangService, () {
    group('renderBoomerang', () {
      test('plays the clip forward, then back without its turning '
          'frames', () async {
        final result = await VideoEditorBoomerangService.renderBoomerang(
          sourceClip: _clip(inputPath: inputPath),
          renderId: 'boomerang-1',
        );

        final renderData = proVideoEditor.renderedData.single;
        expect(renderData.id, 'boomerang-1');
        final [forward, backward] = renderData.videoSegments!;
        expect(forward.reverseVideo, isFalse);
        expect(forward.startTime, isNull);
        expect(forward.endTime, const Duration(seconds: 6));
        expect(backward.reverseVideo, isTrue);
        expect(await forward.video.safeFilePath(), inputPath);
        expect(await backward.video.safeFilePath(), inputPath);

        expect(result.forwardDuration, const Duration(seconds: 6));
        expect(
          result.duration,
          result.forwardDuration + backward.endTime! - backward.startTime!,
        );
        final outputPath = result.video.file!.path;
        expect(proVideoEditor.renderedPaths, [outputPath]);
        expect(path.dirname(outputPath), documentsPath);
        expect(path.basename(outputPath), startsWith('clip_boomerang_'));
      });

      group('cuts the turning frames', () {
        // A frame lasts 33333.3 µs at 30 fps, and the renderers cut a
        // reversed segment differently, so each platform rounds its own way.
        test('on Android onto the timestamps of the frames next to the '
            'turns', () async {
          await VideoEditorBoomerangService.renderBoomerang(
            sourceClip: _clip(inputPath: inputPath),
            renderId: 'boomerang-android',
          );

          final backward = proVideoEditor.renderedData.single.videoSegments![1];
          // Frame timestamps are whole microseconds rounded down: the second
          // frame's is 33333, the last frame's 5966666 must fall outside.
          expect(backward.startTime, const Duration(microseconds: 33333));
          expect(backward.endTime, const Duration(microseconds: 5966666));
        });

        test('on iOS just past the frame boundaries', () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);

          await VideoEditorBoomerangService.renderBoomerang(
            sourceClip: _clip(inputPath: inputPath),
            renderId: 'boomerang-ios',
          );

          final backward = proVideoEditor.renderedData.single.videoSegments![1];
          // Reversed in one-frame slices from the end: a cut a fraction of
          // a microsecond early picks the frame before it.
          expect(backward.startTime, const Duration(microseconds: 33335));
          expect(backward.endTime, const Duration(microseconds: 5966667));
        });
      });

      test('bounces only the part of the clip that plays', () async {
        proVideoEditor.frameRate = 60;

        final result = await VideoEditorBoomerangService.renderBoomerang(
          sourceClip: _clip(
            inputPath: inputPath,
            trimStart: const Duration(seconds: 1),
            trimEnd: const Duration(milliseconds: 500),
          ),
          renderId: 'boomerang-window',
        );

        final [forward, backward] =
            proVideoEditor.renderedData.single.videoSegments!;
        expect(forward.startTime, const Duration(seconds: 1));
        expect(forward.endTime, const Duration(milliseconds: 5500));
        expect(backward.startTime, const Duration(microseconds: 1016666));
        expect(backward.endTime, const Duration(microseconds: 5483333));
        expect(result.forwardDuration, const Duration(milliseconds: 4500));
      });

      test('assumes 30 fps when the source reports no frame rate', () async {
        proVideoEditor.metadataShouldThrow = true;

        await VideoEditorBoomerangService.renderBoomerang(
          sourceClip: _clip(inputPath: inputPath),
          renderId: 'boomerang-no-rate',
        );

        final backward = proVideoEditor.renderedData.single.videoSegments![1];
        expect(backward.startTime, const Duration(microseconds: 33333));
      });

      test('deletes partial output when rendering fails', () async {
        proVideoEditor.renderShouldThrow = true;

        await expectLater(
          () => VideoEditorBoomerangService.renderBoomerang(
            sourceClip: _clip(inputPath: inputPath),
            renderId: 'boomerang-failure',
          ),
          throwsException,
        );

        expect(
          File(proVideoEditor.renderedPaths.single).existsSync(),
          isFalse,
        );
      });
    });
  });
}

DivineVideoClip _clip({
  required String inputPath,
  Duration trimStart = Duration.zero,
  Duration trimEnd = Duration.zero,
}) {
  return DivineVideoClip(
    id: 'clip',
    video: EditorVideo.file(inputPath),
    duration: const Duration(seconds: 6),
    recordedAt: DateTime(2026, 6, 10, 12),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    trimStart: trimStart,
    trimEnd: trimEnd,
  );
}
