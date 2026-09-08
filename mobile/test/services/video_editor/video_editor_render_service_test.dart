// ABOUTME: Tests VideoEditorRenderService.buildImageLayers and
// ABOUTME: buildColorFilters — the overlay-layer scaling and editor→output
// ABOUTME: timeline mapping applied to layers, tune adjustments and filters at
// ABOUTME: export.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/render_cancellation_registry.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart' as pie;
import 'package:pro_video_editor/pro_video_editor.dart'
    show
        ClipTransition,
        ClipTransitionType,
        EditorVideo,
        ProVideoEditor,
        ProgressModel,
        RenderCanceledException,
        RenderEncoderException,
        VideoQualityConfig,
        VideoRenderData,
        VideoSegment;

void main() {
  DivineVideoClip clip(
    String id,
    Duration duration, {
    ClipTransition? transition,
  }) => DivineVideoClip(
    id: id,
    video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
    duration: duration,
    recordedAt: DateTime(2026),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    transition: transition,
  );

  pie.ExportedLayer layer({
    Duration? startTime,
    Duration? endTime,
    Offset offset = Offset.zero,
    Size logicalSize = const Size(10, 20),
  }) => pie.ExportedLayer(
    layer: pie.Layer(startTime: startTime, endTime: endTime, offset: offset),
    bytes: Uint8List.fromList(const [1, 2, 3]),
    logicalSize: logicalSize,
  );

  // Two 2s clips joined by a 400ms dissolve: an overlap removes its 400ms
  // blend, so the 4s editor timeline renders to a 3.6s output. The transition
  // is the outgoing transition of clip A (the a→b boundary).
  final overlapClips = [
    clip(
      'a',
      const Duration(seconds: 2),
      transition: const ClipTransition(
        type: ClipTransitionType.dissolve,
        duration: Duration(milliseconds: 400),
      ),
    ),
    clip('b', const Duration(seconds: 2)),
  ];
  final noTransitionClips = [
    clip('a', const Duration(seconds: 2)),
    clip('b', const Duration(seconds: 2)),
  ];

  group('buildImageLayers', () {
    test('returns null when there are no captured layers', () {
      expect(
        VideoEditorRenderService.buildImageLayers(
          capturedLayers: const [],
          bodySize: const Size(100, 200),
          videoSize: const Size(300, 600),
          timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
        ),
        isNull,
      );
    });

    test('returns null when bodySize is null', () {
      expect(
        VideoEditorRenderService.buildImageLayers(
          capturedLayers: [layer()],
          bodySize: null,
          videoSize: const Size(300, 600),
          timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
        ),
        isNull,
      );
    });

    test('scales offset and size from body space into video pixel space', () {
      // scale = videoWidth / bodyWidth = 300 / 100 = 3.
      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [layer()],
        bodySize: const Size(100, 200),
        videoSize: const Size(300, 600),
        timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
      )!;

      final built = layers.single;
      // (bodyW/2 + dx - logicalW/2) * scale = (50 + 0 - 5) * 3 = 135.
      expect(built.offset, const Offset(135, 270));
      expect(built.size, const Size(30, 60));
    });

    test('passes layer times through unchanged when there is no overlap '
        'transition', () {
      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [
          layer(startTime: Duration.zero, endTime: const Duration(seconds: 4)),
        ],
        bodySize: const Size(100, 200),
        videoSize: const Size(300, 600),
        timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
      )!;

      expect(layers.single.startTime, Duration.zero);
      expect(layers.single.endTime, const Duration(seconds: 4));
    });

    test('maps a full-length layer end onto the shorter output axis when an '
        'overlap transition compresses the timeline', () {
      final map = TransitionTimelineMap.fromClips(overlapClips);
      // Sanity: the overlap removes its 400ms blend from the 4s editor total.
      expect(map.outputDuration, const Duration(milliseconds: 3600));

      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [
          // A full-length layer whose leave animation is anchored to the
          // editor-timeline end (4s).
          layer(startTime: Duration.zero, endTime: const Duration(seconds: 4)),
        ],
        bodySize: const Size(100, 200),
        videoSize: const Size(300, 600),
        timelineMap: map,
      )!;

      // The end must land on the real (shorter) video end, not 4s past it.
      expect(layers.single.startTime, Duration.zero);
      expect(layers.single.endTime, const Duration(milliseconds: 3600));
    });

    test('leaves null start/end times un-anchored', () {
      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [layer()],
        bodySize: const Size(100, 200),
        videoSize: const Size(300, 600),
        timelineMap: TransitionTimelineMap.fromClips(overlapClips),
      )!;

      expect(layers.single.startTime, isNull);
      expect(layers.single.endTime, isNull);
    });
  });

  group('buildColorFilters', () {
    pie.TuneAdjustmentMatrix tune({Duration? startTime, Duration? endTime}) =>
        pie.TuneAdjustmentMatrix(
          id: 'brightness',
          value: 0.5,
          matrix: const [1, 0, 0],
          startTime: startTime,
          endTime: endTime,
        );

    test('returns an empty list when there are no adjustments or filters', () {
      expect(
        VideoEditorRenderService.buildColorFilters(
          tuneAdjustments: const [],
          filterStates: const [],
          timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
        ),
        isEmpty,
      );
    });

    test('passes tune times through unchanged when there is no overlap '
        'transition', () {
      final filters = VideoEditorRenderService.buildColorFilters(
        tuneAdjustments: [
          tune(startTime: Duration.zero, endTime: const Duration(seconds: 4)),
        ],
        filterStates: const [],
        timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
      );

      expect(filters.single.matrix, const [1, 0, 0]);
      expect(filters.single.startTime, Duration.zero);
      expect(filters.single.endTime, const Duration(seconds: 4));
    });

    test('maps a full-length tune window onto the shorter output axis when an '
        'overlap transition compresses the timeline', () {
      final filters = VideoEditorRenderService.buildColorFilters(
        tuneAdjustments: [
          tune(startTime: Duration.zero, endTime: const Duration(seconds: 4)),
        ],
        filterStates: const [],
        timelineMap: TransitionTimelineMap.fromClips(overlapClips),
      );

      expect(filters.single.startTime, Duration.zero);
      expect(filters.single.endTime, const Duration(milliseconds: 3600));
    });

    test('emits one filter per matrix and maps each window onto the output '
        'axis', () {
      final filters = VideoEditorRenderService.buildColorFilters(
        tuneAdjustments: const [],
        filterStates: [
          pie.FilterState(
            name: 'sepia',
            matrices: const [
              [1, 0, 0],
              [0, 1, 0],
            ],
            startTime: Duration.zero,
            endTime: const Duration(seconds: 4),
          ),
        ],
        timelineMap: TransitionTimelineMap.fromClips(overlapClips),
      );

      expect(filters, hasLength(2));
      expect(filters.map((f) => f.matrix), [
        const [1, 0, 0],
        const [0, 1, 0],
      ]);
      for (final filter in filters) {
        expect(filter.startTime, Duration.zero);
        expect(filter.endTime, const Duration(milliseconds: 3600));
      }
    });

    test('leaves null tune times un-anchored', () {
      final filters = VideoEditorRenderService.buildColorFilters(
        tuneAdjustments: [tune()],
        filterStates: const [],
        timelineMap: TransitionTimelineMap.fromClips(overlapClips),
      );

      expect(filters.single.startTime, isNull);
      expect(filters.single.endTime, isNull);
    });
  });

  group('renderWithEncoderFallback', () {
    tearDown(VideoEditorRenderService.resetActiveNativeTaskIdsForTesting);

    const aspectRatio = model.AspectRatio.vertical;
    final baseResolution = VideoEditorConstants.quality
        .resolutionForAspectRatio(aspectRatio);
    final fallbackResolution = VideoEditorConstants.encoderFallbackQuality
        .resolutionForAspectRatio(aspectRatio);

    VideoRenderData baseTask({
      String id = 'render-task',
      bool trimToCommonTrackEnd = false,
    }) => VideoRenderData(
      id: id,
      videoSegments: [
        VideoSegment(
          video: EditorVideo.file('${Directory.systemTemp.path}/a.mp4'),
        ),
      ],
      trimToCommonTrackEnd: trimToCommonTrackEnd,
      qualityConfig: VideoQualityConfig.custom(
        bitrate: VideoEditorConstants.quality.bitrate,
        resolution: baseResolution,
      ),
    );

    /// An encode that throws [RenderEncoderException] for its first
    /// [failuresBeforeSuccess] calls, then succeeds, recording every task it
    /// was handed.
    ({
      Future<void> Function(VideoRenderData) encode,
      List<VideoRenderData> calls,
    })
    flakyEncoder({required int failuresBeforeSuccess}) {
      final calls = <VideoRenderData>[];
      Future<void> encode(VideoRenderData task) async {
        calls.add(task);
        if (calls.length <= failuresBeforeSuccess) {
          throw const RenderEncoderException('encoder init failed');
        }
      }

      return (encode: encode, calls: calls);
    }

    test('encodes once at full resolution when the first attempt '
        'succeeds', () async {
      final harness = flakyEncoder(failuresBeforeSuccess: 0);

      await VideoEditorRenderService.renderWithEncoderFallback(
        baseTask: baseTask(),
        encode: harness.encode,
        fallbackAspectRatio: aspectRatio,
        settleDelay: Duration.zero,
      );

      expect(harness.calls, hasLength(1));
      expect(harness.calls.single.qualityConfig?.resolution, baseResolution);
    });

    test('retries at full resolution after a single encoder failure', () async {
      final harness = flakyEncoder(failuresBeforeSuccess: 1);

      await VideoEditorRenderService.renderWithEncoderFallback(
        baseTask: baseTask(),
        encode: harness.encode,
        fallbackAspectRatio: aspectRatio,
        settleDelay: Duration.zero,
      );

      expect(harness.calls, hasLength(2));
      expect(
        harness.calls.map((t) => t.qualityConfig?.resolution),
        everyElement(baseResolution),
      );
    });

    test('falls back to the reduced resolution on the third attempt', () async {
      final harness = flakyEncoder(failuresBeforeSuccess: 2);

      await VideoEditorRenderService.renderWithEncoderFallback(
        baseTask: baseTask(),
        encode: harness.encode,
        fallbackAspectRatio: aspectRatio,
        settleDelay: Duration.zero,
      );

      expect(harness.calls, hasLength(3));
      expect(harness.calls[0].qualityConfig?.resolution, baseResolution);
      expect(harness.calls[1].qualityConfig?.resolution, baseResolution);
      expect(harness.calls[2].qualityConfig?.resolution, fallbackResolution);
      expect(
        harness.calls[2].qualityConfig?.bitrate,
        VideoEditorConstants.encoderFallbackQuality.bitrate,
      );
    });

    test('rethrows after every attempt fails', () async {
      final harness = flakyEncoder(failuresBeforeSuccess: 3);

      await expectLater(
        VideoEditorRenderService.renderWithEncoderFallback(
          baseTask: baseTask(),
          encode: harness.encode,
          fallbackAspectRatio: aspectRatio,
          settleDelay: Duration.zero,
        ),
        throwsA(isA<RenderEncoderException>()),
      );

      expect(harness.calls, hasLength(3));
    });

    test('does not retry non-encoder failures', () async {
      var calls = 0;
      Future<void> encode(VideoRenderData task) async {
        calls++;
        throw const RenderCanceledException();
      }

      await expectLater(
        VideoEditorRenderService.renderWithEncoderFallback(
          baseTask: baseTask(),
          encode: encode,
          fallbackAspectRatio: aspectRatio,
          settleDelay: Duration.zero,
        ),
        throwsA(isA<RenderCanceledException>()),
      );

      expect(calls, 1);
    });

    test(
      'uses only the settle retry when reduced fallback is disabled',
      () async {
        final harness = flakyEncoder(failuresBeforeSuccess: 2);

        await expectLater(
          VideoEditorRenderService.renderWithEncoderFallback(
            baseTask: baseTask(),
            encode: harness.encode,
            settleDelay: Duration.zero,
          ),
          throwsA(isA<RenderEncoderException>()),
        );

        expect(harness.calls, hasLength(2));
        expect(
          harness.calls.map((t) => t.qualityConfig?.resolution),
          everyElement(baseResolution),
        );
      },
    );

    test('honors cancellation recorded during the settle window', () {
      fakeAsync((async) {
        const settle = VideoEditorConstants.encoderRetrySettleDelay;
        final harness = flakyEncoder(failuresBeforeSuccess: 1);
        Object? caught;

        unawaited(
          VideoEditorRenderService.renderWithEncoderFallback(
            baseTask: baseTask(),
            encode: harness.encode,
            fallbackAspectRatio: aspectRatio,
          ).catchError((Object error) {
            caught = error;
          }),
        );

        async.flushMicrotasks();
        expect(harness.calls, hasLength(1));

        unawaited(VideoEditorRenderService.cancelTask('render-task'));
        expect(
          VideoEditorRenderService.isTaskCancellationRequestedForTesting(
            'render-task',
          ),
          isTrue,
        );

        async.elapse(settle);
        async.flushMicrotasks();

        expect(caught, isA<RenderCanceledException>());
        expect(harness.calls, hasLength(1));
        expect(
          VideoEditorRenderService.isTaskCancellationRequestedForTesting(
            'render-task',
          ),
          isFalse,
        );
      });
    });

    test(
      'honors cancellation recorded before the encode loop starts',
      () async {
        final token = RenderCancellationRegistry.start('render-task');
        await VideoEditorRenderService.cancelTask('render-task');
        var calls = 0;

        await expectLater(
          VideoEditorRenderService.renderWithEncoderFallback(
            baseTask: baseTask(),
            encode: (_) async {
              calls++;
            },
            fallbackAspectRatio: aspectRatio,
            settleDelay: Duration.zero,
          ),
          throwsA(isA<RenderCanceledException>()),
        );

        expect(calls, 0);
        RenderCancellationRegistry.finish('render-task', token);
      },
    );

    test('honors cancellation recorded while encode is running', () async {
      var calls = 0;

      await expectLater(
        VideoEditorRenderService.renderWithEncoderFallback(
          baseTask: baseTask(),
          encode: (task) async {
            calls++;
            unawaited(VideoEditorRenderService.cancelTask(task.id));
          },
          fallbackAspectRatio: aspectRatio,
          settleDelay: Duration.zero,
        ),
        throwsA(isA<RenderCanceledException>()),
      );

      expect(calls, 1);
      expect(
        VideoEditorRenderService.isTaskCancellationRequestedForTesting(
          'render-task',
        ),
        isFalse,
      );
    });

    test('runs the first attempt immediately and waits settleDelay '
        'before each retry', () {
      fakeAsync((async) {
        const settle = VideoEditorConstants.encoderRetrySettleDelay;
        final harness = flakyEncoder(failuresBeforeSuccess: 2);

        unawaited(
          VideoEditorRenderService.renderWithEncoderFallback(
            baseTask: baseTask(),
            encode: harness.encode,
            fallbackAspectRatio: aspectRatio,
          ),
        );

        // First attempt pays no delay.
        async.flushMicrotasks();
        expect(harness.calls, hasLength(1));

        // The retry waits out the full settle window before firing.
        async.elapse(settle - const Duration(milliseconds: 1));
        expect(harness.calls, hasLength(1));
        async.elapse(const Duration(milliseconds: 1));
        expect(harness.calls, hasLength(2));

        // The reduced-resolution attempt waits another settle window.
        async.elapse(settle - const Duration(milliseconds: 1));
        expect(harness.calls, hasLength(2));
        async.elapse(const Duration(milliseconds: 1));
        expect(harness.calls, hasLength(3));
      });
    });

    // An intermediate pass (clip normalization) renders under an id of its
    // own, while the user's Cancel targets the export's id. Without
    // [ownerTaskId] the retry loop cannot see that cancel at all, so it
    // settles, retries, and finishes work nobody is waiting for (#7833/#7834).
    test("honors the owning export's cancellation during the settle "
        'window', () {
      fakeAsync((async) {
        const settle = VideoEditorConstants.encoderRetrySettleDelay;
        final harness = flakyEncoder(failuresBeforeSuccess: 1);
        // renderVideoToClip owns this generation in production.
        final ownerToken = RenderCancellationRegistry.start('export-task');
        Object? caught;

        unawaited(
          VideoEditorRenderService.renderWithEncoderFallback(
            baseTask: baseTask(id: 'clip-a_normalized'),
            encode: harness.encode,
            ownerTaskId: 'export-task',
          ).catchError((Object error) {
            caught = error;
          }),
        );

        async.flushMicrotasks();
        expect(harness.calls, hasLength(1));

        RenderCancellationRegistry.cancel('export-task');

        async.elapse(settle);
        async.flushMicrotasks();

        expect(caught, isA<RenderCanceledException>());
        expect(harness.calls, hasLength(1));
        RenderCancellationRegistry.finish('export-task', ownerToken);
      });
    });

    test('stops after the running attempt when the owning export is '
        'cancelled', () async {
      final ownerToken = RenderCancellationRegistry.start('export-task');
      var calls = 0;

      await expectLater(
        VideoEditorRenderService.renderWithEncoderFallback(
          baseTask: baseTask(id: 'clip-a_normalized'),
          encode: (_) async {
            calls++;
            RenderCancellationRegistry.cancel('export-task');
          },
          ownerTaskId: 'export-task',
          settleDelay: Duration.zero,
        ),
        throwsA(isA<RenderCanceledException>()),
      );

      expect(calls, 1);
      RenderCancellationRegistry.finish('export-task', ownerToken);
    });

    // The reduced-resolution attempt is rebuilt with copyWith. Rebuilding it
    // with the constructor instead would silently reset every field the
    // rebuild does not name, including trimToCommonTrackEnd (#7788).
    test('carries non-quality task fields into the reduced-resolution '
        'attempt', () async {
      final harness = flakyEncoder(failuresBeforeSuccess: 2);

      await VideoEditorRenderService.renderWithEncoderFallback(
        baseTask: baseTask(trimToCommonTrackEnd: true),
        encode: harness.encode,
        fallbackAspectRatio: aspectRatio,
        settleDelay: Duration.zero,
      );

      expect(harness.calls, hasLength(3));
      expect(
        harness.calls.map((t) => t.trimToCommonTrackEnd),
        everyElement(isTrue),
      );
      expect(harness.calls[2].qualityConfig?.resolution, fallbackResolution);
    });
  });

  group('render failure reporting (#7125)', () {
    late ProVideoEditor originalProVideoEditor;

    setUp(() {
      originalProVideoEditor = ProVideoEditor.instance;
      ProVideoEditor.instance = _StubProVideoEditor();
    });

    tearDown(() {
      ProVideoEditor.instance = originalProVideoEditor;
      VideoEditorRenderService.renderVideoOverride = null;
      StopMotionRenderService.assembleOverride = null;
    });

    test('renderVideoToClip names an empty clip list as the reason', () async {
      await expectLater(
        VideoEditorRenderService.renderVideoToClip(
          clips: const [],
          editorStateHistory: const {},
        ),
        throwsA(
          isA<VideoRenderFailedException>().having(
            (e) => e.reason,
            'reason',
            VideoRenderFailureReason.emptyClips,
          ),
        ),
      );
    });

    test('renderVideoToClip maps a cancelled stop-motion assembly to canceled, '
        'not stop_motion_assembly', () async {
      StopMotionRenderService.assembleOverride = ({
        required frames,
        required aspectRatio,
        frameRate = StopMotionRenderService.defaultFrameRate,
        String? taskId,
      }) async => throw const RenderCanceledException();

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

      await expectLater(
        VideoEditorRenderService.renderVideoToClip(
          clips: [stopMotionClip],
          editorStateHistory: const {},
        ),
        throwsA(
          isA<VideoRenderFailedException>()
              .having(
                (e) => e.reason,
                'reason',
                VideoRenderFailureReason.canceled,
              )
              .having((e) => e.cause, 'cause', isA<RenderCanceledException>()),
        ),
      );
    });

    test('renderVideo keeps returning null so callers that only need the '
        'path are unaffected', () async {
      VideoEditorRenderService.renderVideoOverride = ({
        required clips,
        required usePersistentStorage,
        aspectRatio,
        parameters,
        taskId,
        maxOutputDuration,
      }) async => null;

      expect(
        await VideoEditorRenderService.renderVideo(
          clips: [clip('a', const Duration(seconds: 1))],
        ),
        isNull,
      );
    });

    test('traceValue carries the cause type, never its message', () {
      const failure = VideoRenderFailedException(
        VideoRenderFailureReason.nativeRender,
        cause: FormatException('/var/mobile/Containers/Data/x/clip.mp4'),
      );

      expect(failure.traceValue, 'native_render:FormatException');
      expect(failure.toString(), contains('/var/mobile'));
    });
  });

  // The invisibility #7125 reports: the native pipeline signals its failures as
  // PlatformException, which is not an `Error`, so the old `e is Error` gate
  // dropped the entire population before it reached Crashlytics. Widening it
  // for the export must not drag in the recoverable callers of renderVideo —
  // a failing transition seam falls back to a hard cut and is re-attempted on
  // every timeline change, so reporting each attempt would bury the export
  // failures this is meant to surface.
  group('crash reporting gate (#7125)', () {
    late List<Object> reported;
    late ProVideoEditor originalProVideoEditor;

    setUp(() {
      reported = [];
      originalProVideoEditor = ProVideoEditor.instance;
      ProVideoEditor.instance = _StubProVideoEditor();
      VideoEditorRenderService.crashReporterOverride = (error, _) =>
          reported.add(error);
    });

    tearDown(() {
      ProVideoEditor.instance = originalProVideoEditor;
      VideoEditorRenderService.crashReporterOverride = null;
      VideoEditorRenderService.renderVideoOverride = null;
    });

    void failRenderWith(Object error) {
      VideoEditorRenderService.renderVideoOverride = ({
        required clips,
        required usePersistentStorage,
        aspectRatio,
        parameters,
        taskId,
        maxOutputDuration,
      }) async => throw error;
    }

    Future<void> exportClip() => expectLater(
      VideoEditorRenderService.renderVideoToClip(
        clips: [clip('a', const Duration(seconds: 1))],
        editorStateHistory: const {},
      ),
      throwsA(isA<VideoRenderFailedException>()),
    );

    Future<String?> renderClipPath() => VideoEditorRenderService.renderVideo(
      clips: [clip('a', const Duration(seconds: 1))],
    );

    test('the export reports a native failure that is not an Error', () async {
      final failure = PlatformException(code: 'RENDER_ERROR');
      failRenderWith(failure);

      await exportClip();

      expect(reported, [same(failure)]);
    });

    test('a recoverable caller does not report a native failure', () async {
      failRenderWith(PlatformException(code: 'RENDER_ERROR'));

      expect(await renderClipPath(), isNull);
      expect(
        reported,
        isEmpty,
        reason:
            'a seam re-attempted on every timeline change would flood the '
            'dashboard',
      );
    });

    test('a recoverable caller still reports a programming-invariant '
        'violation', () async {
      final failure = StateError('boom');
      failRenderWith(failure);

      expect(await renderClipPath(), isNull);
      expect(reported, [same(failure)]);
    });

    test('a cancellation is never reported', () async {
      failRenderWith(const RenderCanceledException());

      await exportClip();

      expect(reported, isEmpty);
    });
  });
}

/// Satisfies the composite-progress subscription that
/// [VideoEditorRenderService.renderVideoToClip] opens; the render itself is
/// stubbed out through `renderVideoOverride`.
class _StubProVideoEditor extends ProVideoEditor {
  @override
  void initializeStream() {}

  @override
  Stream<ProgressModel> progressStreamById(String taskId) =>
      const Stream<ProgressModel>.empty();
}
