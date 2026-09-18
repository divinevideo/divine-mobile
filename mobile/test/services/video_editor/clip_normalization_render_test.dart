// ABOUTME: Tests for ClipNormalizationRender — which clips an export re-encodes
// ABOUTME: to reach the target aspect ratio, and which it passes straight through.

import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/clip_normalization_models.dart';
import 'package:openvine/services/video_editor/clip_normalization_render.dart';
import 'package:openvine/services/video_editor/render_cancellation_registry.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockProVideoEditor extends ProVideoEditor {
  _MockProVideoEditor({required this.resolutions});

  /// Reported resolution per source file path.
  final Map<String, Size> resolutions;

  /// Every render the pass asked the plugin for, in order.
  final List<VideoRenderData> renders = [];

  @override
  Stream<dynamic> initializeStream() => const Stream.empty();

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async => VideoMetadata(
    duration: const Duration(seconds: 3),
    extension: 'mp4',
    fileSize: 1024,
    resolution: resolutions[value.file!.path]!,
    rotation: 0,
    bitrate: 1000,
  );

  @override
  Future<String> renderVideoToFile(
    String filePath,
    VideoRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    renders.add(value);
    File(filePath).createSync(recursive: true);
    return filePath;
  }

  @override
  Future<void> cancel(String taskId) async {}
}

void main() {
  group(ClipNormalizationRender, () {
    const landscape = Size(1920, 1080);
    const vertical = Size(1080, 1920);
    // Also exactly 9:16, so it needs no crop, but its crop box differs from
    // [vertical]'s — which is what puts a no-render pair on the mixed path.
    const smallVertical = Size(540, 960);

    late Directory cacheDir;
    late ProVideoEditor originalProVideoEditor;
    late _MockProVideoEditor plugin;
    late Map<String, Size> resolutions;

    DivineVideoClip clipFor(String id, Size resolution) {
      final path = '${cacheDir.path}/$id.mp4';
      resolutions[path] = resolution;
      return DivineVideoClip(
        id: id,
        video: EditorVideo.file(path),
        duration: const Duration(seconds: 3),
        trimStart: const Duration(milliseconds: 500),
        recordedAt: DateTime(2026),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: resolution.aspectRatio,
      );
    }

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      cacheDir = Directory.systemTemp.createTempSync('openvine_normalize_');
      resolutions = {};
      plugin = _MockProVideoEditor(resolutions: resolutions);
      originalProVideoEditor = ProVideoEditor.instance;
      ProVideoEditor.instance = plugin;
    });

    tearDown(() {
      ProVideoEditor.instance = originalProVideoEditor;
      RenderCancellationRegistry.reset();
      VideoEditorRenderService.resetActiveNativeTaskIdsForTesting();
      cacheDir.deleteSync(recursive: true);
    });

    Future<NormalizationResult> normalize(List<DivineVideoClip> clips) =>
        ClipNormalizationRender.normalizeClipsToAspectRatio(
          clips: clips,
          aspectRatio: model.AspectRatio.vertical,
          cacheDir: cacheDir,
          parameters: null,
          taskId: 'export',
          tempFilePaths: [],
        );

    test('uses one global crop instead of re-encoding when every clip needs '
        'the same crop', () async {
      final result = await normalize([
        clipFor('a', landscape),
        clipFor('b', landscape),
      ]);

      expect(plugin.renders, isEmpty);
      expect(result.globalTransform, isNotNull);
      expect(result.segments.map((s) => s.video.file!.path), [
        '${cacheDir.path}/a.mp4',
        '${cacheDir.path}/b.mp4',
      ]);
      // The trimmed window travels with the untouched source.
      expect(
        result.segments.first.startTime,
        const Duration(milliseconds: 500),
      );
    });

    test('passes matching clips through untouched with no transform', () async {
      final result = await normalize([
        clipFor('a', vertical),
        clipFor('b', vertical),
      ]);

      expect(plugin.renders, isEmpty);
      expect(result.globalTransform, isNull);
      expect(result.segments, hasLength(2));
    });

    test('re-encodes only the clips whose crop differs when resolutions are '
        'mixed', () async {
      final tempFilePaths = <String>[];
      final result = await ClipNormalizationRender.normalizeClipsToAspectRatio(
        clips: [clipFor('wide', landscape), clipFor('tall', vertical)],
        aspectRatio: model.AspectRatio.vertical,
        cacheDir: cacheDir,
        parameters: null,
        taskId: 'export',
        tempFilePaths: tempFilePaths,
      );

      expect(plugin.renders.map((r) => r.id), ['wide_normalized']);
      expect(result.globalTransform, isNull);
      // The re-encoded file replaces the wide source and is registered for
      // cleanup; the tall source plays as-is with its trim.
      expect(tempFilePaths, hasLength(1));
      expect(result.segments.first.video.file!.path, tempFilePaths.single);
      expect(result.segments.first.startTime, isNull);
      expect(
        result.segments.last.video.file!.path,
        '${cacheDir.path}/tall.mp4',
      );
      expect(result.segments.last.startTime, const Duration(milliseconds: 500));
    });

    test('stops at the next clip when the export is cancelled', () async {
      // Neither clip needs cropping, so this pass renders nothing and its own
      // per-clip check is the only thing that can see the cancel: a user
      // cancel targets the export id, and the encoder-fallback helper that
      // would otherwise notice it only runs for a clip being re-encoded.
      RenderCancellationRegistry.start('export');
      RenderCancellationRegistry.cancel('export');

      await expectLater(
        normalize([
          clipFor('tall', vertical),
          clipFor('small', smallVertical),
        ]),
        throwsA(isA<RenderCanceledException>()),
      );

      expect(plugin.renders, isEmpty);
    });
  });
}
