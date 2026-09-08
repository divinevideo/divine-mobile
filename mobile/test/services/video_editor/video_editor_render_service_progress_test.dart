// ABOUTME: Tests for composite export progress in VideoEditorRenderService
// ABOUTME: Verifies render/proof sequencing and ProofMode budget allocation

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../mocks/mock_path_provider_platform.dart';

class _ProgressProVideoEditor extends ProVideoEditor {
  final _progressController = StreamController<ProgressModel>.broadcast();
  final renderStarts = StreamController<VideoRenderData>.broadcast();
  final _pendingRenders = <_PendingRender>[];
  final cancelCalls = <String>[];

  @override
  void initializeStream() {}

  void emitProgress(String taskId, double progress) {
    _progressController.add(ProgressModel(id: taskId, progress: progress));
  }

  @override
  Stream<ProgressModel> progressStreamById(String taskId) {
    return _progressController.stream.where(
      (progress) => progress.id == taskId,
    );
  }

  @override
  Future<String> renderVideoToFile(
    String filePath,
    VideoRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    final pending = _PendingRender(filePath: filePath, task: value);
    _pendingRenders.add(pending);
    renderStarts.add(value);
    await pending.completer.future;
    return filePath;
  }

  @override
  Future<void> cancel(String taskId) async {
    cancelCalls.add(taskId);
    final matchingRender = _pendingRenders.where(
      (pending) => pending.task.id == taskId && !pending.completer.isCompleted,
    );
    if (matchingRender.isNotEmpty) {
      matchingRender.first.completer.completeError(
        const RenderCanceledException(),
      );
    }
  }

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async {
    return VideoMetadata(
      duration: const Duration(seconds: 6),
      extension: 'mp4',
      fileSize: 1024,
      resolution: const Size(1080, 1920),
      rotation: 0,
      bitrate: 1_000_000,
    );
  }

  Future<void> dispose() async {
    await _progressController.close();
    await renderStarts.close();
  }
}

class _PendingRender {
  _PendingRender({required this.filePath, required this.task});

  final String filePath;
  final VideoRenderData task;
  final completer = Completer<void>();
}

/// Renders synchronously to a real on-disk file (or throws), so
/// [VideoEditorRenderService.limitClipDuration] can be exercised against the
/// actual file-replacement logic without a native renderer.
class _ImmediateRenderProVideoEditor extends ProVideoEditor {
  _ImmediateRenderProVideoEditor({this.throwOnRender = false});

  final bool throwOnRender;
  final cancelCalls = <String>[];

  @override
  void initializeStream() {}

  @override
  Future<String> renderVideoToFile(
    String filePath,
    VideoRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    if (throwOnRender) {
      throw Exception('native render failed');
    }
    File(filePath).writeAsStringSync('trimmed');
    return filePath;
  }

  @override
  Future<void> cancel(String taskId) async {
    cancelCalls.add(taskId);
  }
}

Future<void> _flushStreamEvents() => Future<void>.delayed(Duration.zero);

DivineVideoClip _createClip(int index) {
  return DivineVideoClip(
    id: 'clip-$index',
    video: EditorVideo.file('${Directory.systemTemp.path}/clip-$index.mp4'),
    duration: const Duration(seconds: 2),
    recordedAt: DateTime(2026, 6, 5, 12, index),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    thumbnailPath: '${Directory.systemTemp.path}/clip-$index-thumb.jpg',
  );
}

void main() {
  group('VideoEditorRenderService proof progress allocation', () {
    test('reserves a minimum of 5 percent for proof finalization', () {
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(1),
        closeTo(0.05, 1e-9),
      );
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(3),
        closeTo(0.05, 1e-9),
      );
    });

    test('scales proof budget with clip count until the 10 percent cap', () {
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(5),
        closeTo(0.05, 1e-9),
      );
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(7),
        closeTo(0.07, 1e-9),
      );
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(10),
        closeTo(0.10, 1e-9),
      );
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(30),
        closeTo(0.10, 1e-9),
      );
    });
  });

  group('VideoEditorRenderService composite progress sequence', () {
    late ProVideoEditor originalProVideoEditor;
    late _ProgressProVideoEditor proVideoEditor;

    setUp(() {
      originalProVideoEditor = ProVideoEditor.instance;
      proVideoEditor = _ProgressProVideoEditor();
      ProVideoEditor.instance = proVideoEditor;
      // materialize probes the assembled mp4's real duration; the assembled
      // path here is a stub, so force the frame-hold estimate fallback for a
      // deterministic materialized duration.
      StopMotionRenderService.probeDurationOverride = (_) async => null;
      VideoEditorRenderService.resetActiveNativeTaskIdsForTesting();
    });

    tearDown(() async {
      VideoEditorRenderService.renderVideoOverride = null;
      NativeProofModeService.proofFileOverride = null;
      StopMotionRenderService.assembleOverride = null;
      StopMotionRenderService.probeDurationOverride = null;
      VideoEditorRenderService.resetActiveNativeTaskIdsForTesting();
      await proVideoEditor.dispose();
      ProVideoEditor.instance = originalProVideoEditor;
    });

    test(
      'scales render progress, counts proof steps, and stays monotonic',
      () async {
        const taskId = 'composite-sequence-test';
        final progressValues = <double>[];
        final proofCallClipCounts = <int?>[];
        final editorStateHistory = <String, dynamic>{
          'clips': ['clip-0', 'clip-1', 'clip-2'],
        };

        final progressSubscription =
            VideoEditorRenderService.compositeProgressStreamById(
              () => taskId,
            ).listen((progress) => progressValues.add(progress.progress));
        addTearDown(progressSubscription.cancel);

        VideoEditorRenderService.renderVideoOverride =
            ({
              required clips,
              required usePersistentStorage,
              aspectRatio,
              parameters,
              taskId,
              maxOutputDuration,
            }) async {
              expect(usePersistentStorage, isTrue);
              expect(taskId, equals('composite-sequence-test'));

              proVideoEditor.emitProgress(taskId!, 0.25);
              await _flushStreamEvents();
              proVideoEditor.emitProgress(taskId, 0.75);
              await _flushStreamEvents();
              proVideoEditor.emitProgress(taskId, 0.40);
              await _flushStreamEvents();

              return '${Directory.systemTemp.path}/rendered-composite.mp4';
            };

        NativeProofModeService.proofFileOverride =
            (
              File videoFile, {
              required bool enableAdvancedCawgEmbedding,
              creatorBindingAssertion,
              cawgIdentityAssertion,
              verifiedIdentityBundle,
              clips,
              editorStateHistory,
            }) async {
              proofCallClipCounts.add(clips?.length);

              if (proofCallClipCounts.length == 1) {
                proVideoEditor.emitProgress(taskId, 0.10);
                await _flushStreamEvents();
              }

              return model.NativeProofData(
                videoHash: 'proof-${proofCallClipCounts.length}',
              );
            };

        final result = await VideoEditorRenderService.renderVideoToClip(
          clips: [_createClip(0), _createClip(1), _createClip(2)],
          editorStateHistory: editorStateHistory,
          taskId: taskId,
        );
        await _flushStreamEvents();

        expect(result.$2, isNotNull);
        // Cover extraction cannot succeed here (the render output is never
        // written), so the clip must fall back to the first source clip's
        // thumbnail rather than being left without a preview.
        expect(
          result.$1.thumbnailPath,
          equals('${Directory.systemTemp.path}/clip-0-thumb.jpg'),
        );
        expect(
          proofCallClipCounts,
          equals([null, null, null, 3]),
          reason:
              'three clip-proof steps plus the final combined proofFile step',
        );

        const renderBudget = 0.95;
        const proofBudget = 0.05;
        final expectedProgressValues = [
          0.0,
          0.25 * renderBudget,
          0.75 * renderBudget,
          renderBudget,
          renderBudget + proofBudget / 4,
          renderBudget + proofBudget * 2 / 4,
          renderBudget + proofBudget * 3 / 4,
          1.0,
        ];

        expect(progressValues, hasLength(expectedProgressValues.length));
        for (var i = 0; i < expectedProgressValues.length; i++) {
          expect(progressValues[i], closeTo(expectedProgressValues[i], 1e-9));
        }
        for (var i = 1; i < progressValues.length; i++) {
          expect(
            progressValues[i],
            greaterThanOrEqualTo(progressValues[i - 1]),
          );
        }
        expect(progressValues.last, equals(1.0));
      },
    );

    test(
      'gives the stop-motion assembly its own progress slice before the '
      'composite render',
      () async {
        const taskId = 'stop-motion-progress-test';
        final progressValues = <double>[];

        final progressSubscription =
            VideoEditorRenderService.compositeProgressStreamById(
              () => taskId,
            ).listen((progress) => progressValues.add(progress.progress));
        addTearDown(progressSubscription.cancel);

        StopMotionRenderService.assembleOverride =
            ({
              required frames,
              required aspectRatio,
              frameRate = StopMotionRenderService.defaultFrameRate,
              String? taskId,
            }) async {
              expect(taskId, equals('stop-motion-progress-test-stop-motion-0'));
              proVideoEditor.emitProgress(taskId!, 0.5);
              await _flushStreamEvents();
              return '${Directory.systemTemp.path}/assembled.mp4';
            };

        VideoEditorRenderService.renderVideoOverride =
            ({
              required clips,
              required usePersistentStorage,
              aspectRatio,
              parameters,
              taskId,
              maxOutputDuration,
            }) async {
              // The composite render receives the materialized (video-backed)
              // clip, not the frames-only one.
              expect(clips.single.video, isNotNull);
              proVideoEditor.emitProgress(taskId!, 0.5);
              await _flushStreamEvents();
              return '${Directory.systemTemp.path}/rendered-sm.mp4';
            };

        NativeProofModeService.proofFileOverride =
            (
              File videoFile, {
              required bool enableAdvancedCawgEmbedding,
              creatorBindingAssertion,
              cawgIdentityAssertion,
              verifiedIdentityBundle,
              clips,
              editorStateHistory,
            }) async => const model.NativeProofData(videoHash: 'proof');

        final stopMotionClip = DivineVideoClip(
          id: 'sm-clip',
          stopMotionFrames: const [
            StopMotionClipFrame(
              path: '/frames/f0.jpg',
              duration: Duration(milliseconds: 83),
            ),
          ],
          duration: const Duration(milliseconds: 83),
          recordedAt: DateTime(2026),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
        );

        await VideoEditorRenderService.renderVideoToClip(
          clips: [stopMotionClip],
          editorStateHistory: const {},
          taskId: taskId,
        );
        await _flushStreamEvents();

        // One clip → 5% proof budget; the remaining 95% splits evenly
        // between the assembly pass and the composite render.
        const proofBudget = 0.05;
        const assemblyBudget = (1 - proofBudget) * 0.5;
        const renderBudget = 1 - proofBudget - assemblyBudget;
        final expectedProgressValues = [
          0.0,
          assemblyBudget * 0.5,
          assemblyBudget,
          assemblyBudget + renderBudget * 0.5,
          1 - proofBudget,
          1 - proofBudget + proofBudget / 2,
          1.0,
        ];

        expect(progressValues, hasLength(expectedProgressValues.length));
        for (var i = 0; i < expectedProgressValues.length; i++) {
          expect(progressValues[i], closeTo(expectedProgressValues[i], 1e-9));
        }
      },
    );

    test(
      'tracks native renders and clears them when teardown cancellation throws',
      () async {
        final renderStarted = proVideoEditor.renderStarts.stream.first;
        final renderFuture = VideoEditorRenderService.renderNativeVideoToFile(
          '${Directory.systemTemp.path}/render-cancelled.mp4',
          VideoRenderData(
            id: 'tracked-render',
            videoSegments: [
              VideoSegment(
                video: EditorVideo.file('${Directory.systemTemp.path}/a.mp4'),
              ),
            ],
          ),
        );

        await renderStarted;
        expect(
          proVideoEditor.cancelCalls,
          isEmpty,
          reason: 'new renders do not cancel native work before registration',
        );
        expect(
          VideoEditorRenderService.activeNativeTaskIdsForTesting,
          contains('tracked-render'),
        );

        final renderCancellation = expectLater(
          renderFuture,
          throwsA(isA<RenderCanceledException>()),
        );
        await VideoEditorRenderService.cancelActiveNativeTasks();

        expect(
          proVideoEditor.cancelCalls,
          equals(['tracked-render']),
        );
        await renderCancellation;
        expect(VideoEditorRenderService.activeNativeTaskIdsForTesting, isEmpty);
      },
    );

    test('keeps a reused task id tracked for the latest render', () async {
      final firstRenderStarted = proVideoEditor.renderStarts.stream.first;
      final firstRender = VideoEditorRenderService.renderNativeVideoToFile(
        '${Directory.systemTemp.path}/first.mp4',
        VideoRenderData(
          id: 'reused-render-id',
          videoSegments: [
            VideoSegment(
              video: EditorVideo.file('${Directory.systemTemp.path}/first.mov'),
            ),
          ],
        ),
      );
      await firstRenderStarted;

      final firstCancellation = expectLater(
        firstRender,
        throwsA(isA<RenderCanceledException>()),
      );
      final secondRenderStarted = proVideoEditor.renderStarts.stream.first;
      final secondRender = VideoEditorRenderService.renderNativeVideoToFile(
        '${Directory.systemTemp.path}/second.mp4',
        VideoRenderData(
          id: 'reused-render-id',
          videoSegments: [
            VideoSegment(
              video: EditorVideo.file(
                '${Directory.systemTemp.path}/second.mov',
              ),
            ),
          ],
        ),
      );
      await secondRenderStarted;

      await firstCancellation;
      expect(
        VideoEditorRenderService.activeNativeTaskIdsForTesting,
        equals({'reused-render-id'}),
      );

      final secondCancellation = expectLater(
        secondRender,
        throwsA(isA<RenderCanceledException>()),
      );
      await VideoEditorRenderService.cancelActiveNativeTasks();

      await secondCancellation;
      expect(VideoEditorRenderService.activeNativeTaskIdsForTesting, isEmpty);
    });
  });

  group('VideoEditorRenderService limitClipDuration', () {
    late ProVideoEditor originalProVideoEditor;
    late PathProviderPlatform originalPathProvider;
    late Directory tempDir;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      originalProVideoEditor = ProVideoEditor.instance;
      VideoEditorRenderService.resetActiveNativeTaskIdsForTesting();

      tempDir = Directory.systemTemp.createTempSync('limit_clip_duration_test');
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setTemporaryPath(tempDir.path);
    });

    tearDown(() {
      VideoEditorRenderService.resetActiveNativeTaskIdsForTesting();
      ProVideoEditor.instance = originalProVideoEditor;
      PathProviderPlatform.instance = originalPathProvider;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    DivineVideoClip clipForPath(String inputPath) {
      return DivineVideoClip(
        id: 'limit-clip',
        video: EditorVideo.file(inputPath),
        duration: const Duration(seconds: 6),
        recordedAt: DateTime(2026, 6, 5, 12),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );
    }

    test(
      'moves the trimmed output into place when the source file is gone',
      () async {
        ProVideoEditor.instance = _ImmediateRenderProVideoEditor();
        // Simulate the concurrent-cleanup race: the source vanished before the
        // trim output is moved into place. The file is intentionally not
        // created.
        final inputPath = '${tempDir.path}/VID_missing.mp4';

        bool? completed;
        await VideoEditorRenderService.limitClipDuration(
          clip: clipForPath(inputPath),
          duration: const Duration(seconds: 6),
          onComplete: (value) => completed = value,
        );

        expect(completed, isTrue);
        expect(
          File(inputPath).existsSync(),
          isTrue,
          reason: 'trimmed output should be renamed into the source path',
        );
        expect(File(inputPath).readAsStringSync(), equals('trimmed'));
      },
    );

    test('replaces an existing source file with the trimmed output', () async {
      ProVideoEditor.instance = _ImmediateRenderProVideoEditor();
      final inputPath = '${tempDir.path}/VID_present.mp4';
      File(inputPath).writeAsStringSync('original');

      bool? completed;
      await VideoEditorRenderService.limitClipDuration(
        clip: clipForPath(inputPath),
        duration: const Duration(seconds: 6),
        onComplete: (value) => completed = value,
      );

      expect(completed, isTrue);
      expect(File(inputPath).readAsStringSync(), equals('trimmed'));
    });

    test('reports failure when the render genuinely fails', () async {
      ProVideoEditor.instance = _ImmediateRenderProVideoEditor(
        throwOnRender: true,
      );
      final inputPath = '${tempDir.path}/VID_render_fail.mp4';
      File(inputPath).writeAsStringSync('original');

      bool? completed;
      await VideoEditorRenderService.limitClipDuration(
        clip: clipForPath(inputPath),
        duration: const Duration(seconds: 6),
        onComplete: (value) => completed = value,
      );

      expect(completed, isFalse);
      expect(
        File(inputPath).readAsStringSync(),
        equals('original'),
        reason: 'a failed render must leave the source untouched',
      );
    });
  });
}
