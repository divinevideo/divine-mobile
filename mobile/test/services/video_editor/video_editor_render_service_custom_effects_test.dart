// ABOUTME: Proves the export hands Divine's own effects (the echo trail) to
// ABOUTME: pro_video_editor, read from the editor history like the built-in ones

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/services/video_editor/render_cancellation_registry.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show CompleteParameters;
import 'package:pro_video_editor/pro_video_editor.dart';

class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// Records every render the service asks for, and writes its output file.
class _RecordingProVideoEditor extends ProVideoEditor {
  final List<VideoRenderData> tasks = [];

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
    // Already vertical, so the export renders the clip in one pass.
    resolution: const Size(1080, 1920),
    rotation: 0,
    bitrate: 1000,
  );

  @override
  Future<String> renderVideoToFile(
    String filePath,
    VideoRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    tasks.add(value);
    File(filePath).createSync(recursive: true);
    return filePath;
  }

  @override
  Future<void> cancel(String taskId) async {}
}

CompleteParameters _parameters(Map<String, dynamic> meta) => CompleteParameters(
  meta: meta,
  blur: 0,
  originalImageSize: const Size(1080, 1920),
  temporaryDecodedImageSize: const Size(1080, 1920),
  bodySize: const Size(400, 800),
  editorSize: const Size(400, 800),
  matrixFilterList: const [],
  matrixTuneAdjustmentsList: const [],
  startTime: null,
  endTime: null,
  cropWidth: null,
  cropHeight: null,
  rotateTurns: 0,
  cropX: null,
  cropY: null,
  flipX: false,
  flipY: false,
  image: Uint8List(0),
  isTransformed: false,
  layers: const [],
);

void main() {
  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;
  late ProVideoEditor originalProVideoEditor;
  late _RecordingProVideoEditor plugin;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync('openvine_custom_effects_');
    originalPathProvider = PathProviderPlatform.instance;
    originalProVideoEditor = ProVideoEditor.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    plugin = _RecordingProVideoEditor();
    ProVideoEditor.instance = plugin;
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
    ProVideoEditor.instance = originalProVideoEditor;
    RenderCancellationRegistry.reset();
    VideoEditorRenderService.resetActiveNativeTaskIdsForTesting();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('VideoEditorRenderService.renderVideo', () {
    test(
      'hands the echo trail from the editor history to the export',
      () async {
        final echo = EditorVideoEffect.of(
          id: 'echo-1',
          type: EditorEffectType.echo,
          intensity: 0.5,
          startTime: const Duration(seconds: 1),
          endTime: const Duration(seconds: 2),
        );

        await VideoEditorRenderService.renderVideo(
          clips: [
            DivineVideoClip(
              id: 'clip-a',
              video: EditorVideo.file('${tempDir.path}/clip-a.mp4'),
              duration: const Duration(seconds: 3),
              recordedAt: DateTime(2026),
              targetAspectRatio: model.AspectRatio.vertical,
              originalAspectRatio: 9 / 16,
            ),
          ],
          aspectRatio: model.AspectRatio.vertical,
          taskId: 'export',
          parameters: _parameters({
            VideoEditorConstants.effectsStateHistoryKey: [echo.toMap()],
          }),
        );

        expect(plugin.tasks, hasLength(1));
        expect(plugin.tasks.single.customEffects, const [
          CustomVideoEffect(
            id: echoVideoEffectId,
            params: {EditorVideoEffect.intensityParam: 0.5},
            startTime: Duration(seconds: 1),
            endTime: Duration(seconds: 2),
          ),
        ]);
      },
    );
  });
}
