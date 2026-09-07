// ABOUTME: Proves a user cancel stops the export's clip-normalization pass
// ABOUTME: Captures and restores ProVideoEditor and PathProviderPlatform

import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/render_cancellation_registry.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _MockPathProviderPlatform({required this.root, required this.documentsRoot});

  final String root;
  final String documentsRoot;

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => root;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsRoot;
}

class _MockProVideoEditor extends ProVideoEditor {
  _MockProVideoEditor({
    required this.resolutions,
    this.onRender,
    this.failEncoderTaskIds = const {},
  });

  /// Reported resolution per source file path. Anything else reports a
  /// already-vertical resolution, which needs no crop.
  final Map<String, Size> resolutions;

  /// Runs inside `renderVideoToFile`, so a test can cancel mid-render.
  final void Function(VideoRenderData task)? onRender;

  /// Task ids whose render writes its partial output file and then throws a
  /// [RenderEncoderException], modelling an encoder that fails after starting
  /// to write. The file is created first so the failure leaves a real partial.
  final Set<String> failEncoderTaskIds;

  /// Every render the service asked the plugin for, in order.
  final List<String> renderedTaskIds = [];

  /// Every output path the service asked the plugin to write, in order.
  final List<String> renderedFilePaths = [];

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
    resolution: resolutions[value.file?.path] ?? const Size(1080, 1920),
    rotation: 0,
    bitrate: 1000,
  );

  @override
  Future<String> renderVideoToFile(
    String filePath,
    VideoRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    renderedTaskIds.add(value.id);
    renderedFilePaths.add(filePath);
    onRender?.call(value);
    File(filePath).createSync(recursive: true);
    if (failEncoderTaskIds.contains(value.id)) {
      throw const RenderEncoderException('mock encoder failure');
    }
    return filePath;
  }

  @override
  Future<void> cancel(String taskId) async {}
}

void main() {
  const exportTaskId = 'export-task';

  late Directory tempDir;
  late Directory documentsDir;
  late PathProviderPlatform originalPathProvider;
  late ProVideoEditor originalProVideoEditor;

  // Landscape and 720p sources crop to different rectangles for a vertical
  // target, which is what pushes the export onto the per-clip normalization
  // path instead of a single global transform.
  late Map<String, Size> resolutions;
  late List<DivineVideoClip> clips;

  DivineVideoClip clipFor(String id) => DivineVideoClip(
    id: id,
    video: EditorVideo.file('${tempDir.path}/$id.mp4'),
    duration: const Duration(seconds: 3),
    recordedAt: DateTime(2026),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 16 / 9,
  );

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync('openvine_render_cancel_');
    documentsDir = Directory.systemTemp.createTempSync(
      'openvine_render_documents_',
    );
    originalPathProvider = PathProviderPlatform.instance;
    originalProVideoEditor = ProVideoEditor.instance;
    PathProviderPlatform.instance = _MockPathProviderPlatform(
      root: tempDir.path,
      documentsRoot: documentsDir.path,
    );
    clips = [clipFor('clip-a'), clipFor('clip-b')];
    resolutions = {
      '${tempDir.path}/clip-a.mp4': const Size(1920, 1080),
      '${tempDir.path}/clip-b.mp4': const Size(1280, 720),
    };
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
    ProVideoEditor.instance = originalProVideoEditor;
    RenderCancellationRegistry.reset();
    VideoEditorRenderService.resetActiveNativeTaskIdsForTesting();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    if (documentsDir.existsSync()) documentsDir.deleteSync(recursive: true);
  });

  group('clip normalization cancellation (#7833/#7834)', () {
    test('normalizes every mixed-resolution clip and concatenates when '
        'nothing cancels', () async {
      final plugin = _MockProVideoEditor(resolutions: resolutions);
      ProVideoEditor.instance = plugin;

      final outputPath = await VideoEditorRenderService.renderVideo(
        clips: clips,
        aspectRatio: model.AspectRatio.vertical,
        taskId: exportTaskId,
      );

      expect(outputPath, isNotNull);
      expect(plugin.renderedTaskIds, [
        'clip-a_normalized',
        'clip-b_normalized',
        exportTaskId,
      ]);
    });

    test('stops the pass when the user cancels the export mid-clip', () async {
      // renderVideoToClip owns this generation in production; a cancel that
      // arrives with no active generation is dropped by the registry.
      RenderCancellationRegistry.start(exportTaskId);
      final plugin = _MockProVideoEditor(
        resolutions: resolutions,
        onRender: (_) => RenderCancellationRegistry.cancel(exportTaskId),
      );
      ProVideoEditor.instance = plugin;

      final outputPath = await VideoEditorRenderService.renderVideo(
        clips: clips,
        aspectRatio: model.AspectRatio.vertical,
        taskId: exportTaskId,
      );

      // The cancel lands during the first clip's render, so the second clip is
      // never normalized and the full video is never concatenated.
      expect(plugin.renderedTaskIds, ['clip-a_normalized']);
      expect(outputPath, isNull);
      expect(
        tempDir.listSync().whereType<File>().where(
          (file) => file.path.endsWith('.mp4'),
        ),
        isEmpty,
      );
    });

    test(
      'deletes earlier normalized clips when a later clip is cancelled',
      () async {
        RenderCancellationRegistry.start(exportTaskId);
        final plugin = _MockProVideoEditor(
          resolutions: resolutions,
          onRender: (task) {
            if (task.id == 'clip-b_normalized') {
              RenderCancellationRegistry.cancel(exportTaskId);
            }
          },
        );
        ProVideoEditor.instance = plugin;

        final outputPath = await VideoEditorRenderService.renderVideo(
          clips: clips,
          aspectRatio: model.AspectRatio.vertical,
          taskId: exportTaskId,
        );

        expect(plugin.renderedTaskIds, [
          'clip-a_normalized',
          'clip-b_normalized',
        ]);
        expect(outputPath, isNull);
        expect(
          tempDir.listSync().whereType<File>().where(
            (file) => file.path.endsWith('.mp4'),
          ),
          isEmpty,
        );
      },
    );

    test(
      'deletes the partial final output when the export is cancelled during '
      'concatenation (#8818)',
      () async {
        // Cancel while the FINAL concatenation render runs, after normalization
        // has completed — so the partial `divine_*.mp4` has been written to the
        // output directory and must not be left orphaned.
        RenderCancellationRegistry.start(exportTaskId);
        final plugin = _MockProVideoEditor(
          resolutions: resolutions,
          onRender: (task) {
            if (task.id == exportTaskId) {
              RenderCancellationRegistry.cancel(exportTaskId);
            }
          },
        );
        ProVideoEditor.instance = plugin;

        final outputPath = await VideoEditorRenderService.renderVideo(
          clips: clips,
          aspectRatio: model.AspectRatio.vertical,
          taskId: exportTaskId,
        );

        // Normalization ran for both clips, then the concat render was reached
        // and cancelled.
        expect(plugin.renderedTaskIds, [
          'clip-a_normalized',
          'clip-b_normalized',
          exportTaskId,
        ]);
        expect(outputPath, isNull);
        expect(
          tempDir.listSync().whereType<File>().where(
            (file) => file.path.endsWith('.mp4'),
          ),
          isEmpty,
          reason: 'the partial divine_*.mp4 must not be left behind on cancel',
        );
      },
    );

    test(
      'a persistent export leaves no partial file in the documents directory '
      'on cancel (#8818)',
      () async {
        // The AC names the documents directory specifically. A distinct mock
        // root proves usePersistentStorage routes the final output there rather
        // than to the cache path.
        RenderCancellationRegistry.start(exportTaskId);
        final plugin = _MockProVideoEditor(
          resolutions: resolutions,
          onRender: (task) {
            if (task.id == exportTaskId) {
              RenderCancellationRegistry.cancel(exportTaskId);
            }
          },
        );
        ProVideoEditor.instance = plugin;

        final outputPath = await VideoEditorRenderService.renderVideo(
          clips: clips,
          aspectRatio: model.AspectRatio.vertical,
          taskId: exportTaskId,
          usePersistentStorage: true,
        );

        expect(outputPath, isNull);
        expect(
          plugin.renderedFilePaths.last,
          startsWith(
            '${documentsDir.path}${Platform.pathSeparator}divine_',
          ),
        );
        expect(
          documentsDir.listSync().whereType<File>().where(
            (file) => file.path.endsWith('.mp4'),
          ),
          isEmpty,
          reason:
              'a cancelled persistent export must not orphan a divine_*.mp4 '
              'in the documents directory',
        );
      },
    );

    test(
      'deletes the partial final output when the final encoder attempt fails '
      'during concatenation (#8818)',
      () async {
        // Not a cancel: the concat render itself fails. The encoder writes a
        // partial `divine_*.mp4` and then throws on every attempt, so the
        // retry chain is exhausted and the failure propagates. The partial
        // must be cleaned up, exactly as on cancel.
        final plugin = _MockProVideoEditor(
          resolutions: resolutions,
          failEncoderTaskIds: {exportTaskId},
        );
        ProVideoEditor.instance = plugin;

        final outputPath = await VideoEditorRenderService.renderVideo(
          clips: clips,
          aspectRatio: model.AspectRatio.vertical,
          taskId: exportTaskId,
          usePersistentStorage: true,
        );

        // Normalization succeeded for both clips, then the concat render was
        // attempted and failed.
        expect(plugin.renderedTaskIds.take(2), [
          'clip-a_normalized',
          'clip-b_normalized',
        ]);
        expect(plugin.renderedTaskIds, contains(exportTaskId));
        expect(outputPath, isNull);
        expect(
          documentsDir.listSync().whereType<File>().where(
            (file) => file.path.endsWith('.mp4'),
          ),
          isEmpty,
          reason: 'a failed export must not orphan a partial divine_*.mp4',
        );
      },
    );
  });
}
