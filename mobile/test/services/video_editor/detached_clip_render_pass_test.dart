// ABOUTME: Tests the export's second pass — when it runs, what it hands the
// ABOUTME: base render, and the composition it builds over the finished track.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/services/video_editor/detached_clip_render_pass.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_image_editor/pro_image_editor.dart' as pie;
import 'package:pro_video_editor/pro_video_editor.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '/documents';
}

/// Records the render tasks the pass submits, without touching a codec.
class _RecordingProVideoEditor extends ProVideoEditor {
  final tasks = <VideoRenderData>[];

  /// Thrown by every render instead of finishing it, when set.
  Object? renderError;

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
    resolution: const Size(1080, 1920),
    rotation: 0,
    bitrate: 1,
  );

  @override
  Future<String> renderVideoToFile(
    String outputPath,
    VideoRenderData renderData, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    tasks.add(renderData);
    final error = renderError;
    if (error != null) throw error;
    return outputPath;
  }
}

DivineVideoClip _clip({String id = 'clip-1', double? playbackSpeed}) =>
    DivineVideoClip(
      id: id,
      video: EditorVideo.file('/documents/$id.mp4'),
      duration: const Duration(seconds: 4),
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
      playbackSpeed: playbackSpeed,
    );

pie.ExportedLayer _detachedLayer(DivineVideoClip clip) {
  final meta = DetachedClipLayerData(clip: clip, layerId: 'layer-1').toMeta();
  return pie.ExportedLayer(
    layer: pie.WidgetLayer(
      widget: const SizedBox.shrink(),
      exportConfigs: pie.WidgetLayerExportConfigs(id: clip.id, meta: meta),
    ),
    bytes: Uint8List.fromList(const [1]),
    logicalSize: const Size(90, 90),
  );
}

pie.ExportedLayer _textLayer(String text) => pie.ExportedLayer(
  layer: pie.TextLayer(text: text),
  bytes: Uint8List.fromList(const [1]),
  logicalSize: const Size(40, 20),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory cacheDir;
  late PathProviderPlatform originalPathProvider;
  late ProVideoEditor originalEditor;
  late _RecordingProVideoEditor editor;

  setUp(() {
    cacheDir = Directory.systemTemp.createTempSync('detached_pass');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider();
    originalEditor = ProVideoEditor.instance;
    editor = _RecordingProVideoEditor();
    ProVideoEditor.instance = editor;
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
    ProVideoEditor.instance = originalEditor;
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  Future<DetachedClipRenderPass> prepare(
    List<pie.ExportedLayer> layers,
  ) => DetachedClipRenderPass.prepare(
    capturedLayers: layers,
    cacheDir: cacheDir,
    finalOutputPath: '${cacheDir.path}/final.mp4',
  );

  group(DetachedClipRenderPass, () {
    group('prepare', () {
      test('stays out of the way when nothing is detached', () async {
        final pass = await prepare([_textLayer('hello')]);

        // The ordinary export must still be one encode straight to the final
        // path — no temp file, no second pass.
        expect(pass.isActive, isFalse);
        expect(pass.basePath, '${cacheDir.path}/final.mp4');
        expect(pass.baseImageLayers, isNull);
      });

      test(
        'routes the base render to a temp file when one is detached',
        () async {
          final pass = await prepare([_detachedLayer(_clip())]);

          expect(pass.isActive, isTrue);
          expect(pass.basePath, startsWith(cacheDir.path));
          expect(pass.basePath, isNot('${cacheDir.path}/final.mp4'));
        },
      );

      test(
        'holds back the layers that belong over the detached clip',
        () async {
          final under = _textLayer('under');
          final over = _textLayer('over');

          final pass = await prepare([under, _detachedLayer(_clip()), over]);

          // Only what sat below the clip is baked into the base track; the rest
          // goes on top in the second pass so z-order survives.
          expect(pass.baseImageLayers, [under]);
        },
      );
    });

    group('composite', () {
      Future<String> run(DetachedClipRenderPass pass, {Size? bodySize}) =>
          pass.composite(
            clips: [_clip(id: 'track')],
            bodySize: bodySize ?? const Size(360, 640),
            aspectRatio: model.AspectRatio.vertical,
            taskId: 'task-1',
            tempFilePaths: [],
            maxOutputDuration: const Duration(seconds: 6),
          );

      test('does nothing when nothing is detached', () async {
        final pass = await prepare([_textLayer('hello')]);

        final output = await run(pass);

        expect(output, pass.basePath);
        expect(editor.tasks, isEmpty);
      });

      test('stacks the detached clip over the base track', () async {
        final pass = await prepare([_detachedLayer(_clip())]);
        File(pass.basePath).writeAsBytesSync(const [1]);

        await run(pass);

        expect(editor.tasks, hasLength(1));
        final composition = editor.tasks.single.composition;
        expect(composition, isNotNull);
        // Bottom layer is the finished track; the detached clip goes above it.
        expect(composition!.layers, hasLength(2));
        expect(
          composition.layers.first.clips.single.video.file?.path,
          pass.basePath,
        );
        expect(
          composition.layers.last.clips.single.video.file?.path,
          '/documents/clip-1.mp4',
        );
      });

      test('writes to the final path, not the base one', () async {
        final pass = await prepare([_detachedLayer(_clip())]);
        File(pass.basePath).writeAsBytesSync(const [1]);

        final output = await run(pass);

        expect(output, '${cacheDir.path}/final.mp4');
      });

      test('puts the held-back layers over the composition', () async {
        final pass = await prepare([
          _detachedLayer(_clip()),
          _textLayer('over'),
        ]);
        File(pass.basePath).writeAsBytesSync(const [1]);

        await run(pass);

        expect(editor.tasks.single.imageLayers, hasLength(1));
      });

      test('flattens a sped-up clip before compositing it', () async {
        final pass = await prepare([
          _detachedLayer(_clip(playbackSpeed: 2)),
        ]);
        File(pass.basePath).writeAsBytesSync(const [1]);

        await run(pass);

        // A composition layer asserts against playbackSpeed, so the speed has
        // to be baked into a file first — two renders, flatten then composite.
        expect(editor.tasks, hasLength(2));
        expect(editor.tasks.first.videoSegments!.single.playbackSpeed, 2);
        expect(editor.tasks.last.composition, isNotNull);
      });

      group('when the device runs out of codecs', () {
        /// Runs the pass to its end under fake time, so the encoder retries'
        /// settle delays elapse instantly, and returns what it threw.
        Object? failureOf(Object renderError) {
          Object? failure;
          fakeAsync((async) {
            editor.renderError = renderError;
            DetachedClipRenderPass? pass;
            unawaited(prepare([_detachedLayer(_clip())]).then((p) => pass = p));
            async.flushMicrotasks();
            File(pass!.basePath).writeAsBytesSync(const [1]);
            unawaited(
              run(pass!).then<void>((_) {}, onError: (Object e) => failure = e),
            );
            async.elapse(const Duration(seconds: 10));
          });
          return failure;
        }

        test('blames the detached clips once every retry failed', () {
          // How `pro_video_editor` reported the decoders a Galaxy S26 could
          // not start for 12 detached clips (#10141).
          final failure = failureOf(
            const RenderEncoderException.transient(
              'Underlying error: ERROR_CODE_DECODER_INIT_FAILED',
            ),
          );

          expect(
            failure,
            isA<VideoRenderFailedException>()
                .having(
                  (e) => e.reason,
                  'reason',
                  VideoRenderFailureReason.tooManyDetachedClips,
                )
                .having(
                  (e) => e.traceValue,
                  'traceValue',
                  'too_many_detached_clips:codec_exhausted',
                ),
          );
          expect(
            editor.tasks,
            hasLength(3),
            reason: 'the encoder retries run before the clips are blamed',
          );
        });

        test('leaves an unsupported encoder unclassified', () {
          const unsupported = RenderEncoderException('profile rejected');

          expect(failureOf(unsupported), same(unsupported));
        });
      });

      test('ships the base track when the body size is unknown', () async {
        final pass = await prepare([_detachedLayer(_clip())]);
        File(pass.basePath).writeAsBytesSync(const [1]);

        final output = await run(pass, bodySize: Size.zero);

        // Layer offsets are meaningless without the body they were laid out
        // against; a guessed position is worse than no overlay.
        expect(output, '${cacheDir.path}/final.mp4');
        expect(editor.tasks, isEmpty);
        expect(File('${cacheDir.path}/final.mp4').existsSync(), isTrue);
      });
    });
  });
}
