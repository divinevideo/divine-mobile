import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_camera/divine_camera.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio, AudioEvent;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/camera_initialization_error.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/music_mode_preference_service.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_service/sound_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import '../../mocks/mock_path_provider_platform.dart';

class _MockCameraService extends Mock implements CameraService {}

/// An operation-scoped trace handle that records its attributes and stop count.
class _RecordingTrace implements PerformanceTrace {
  final Map<String, String> attributes = {};
  final Map<String, int> metrics = {};
  int stopCount = 0;

  @override
  void putAttribute(String attribute, String value) =>
      attributes[attribute] = value;

  @override
  void setMetric(String metric, int value) => metrics[metric] = value;

  @override
  Future<void> stop() async => stopCount++;
}

/// Hands out a [_RecordingTrace] per operation so the `camera_startup` outcome
/// mapping can be asserted; the bloc's default [NoOpPerformanceTraceMonitor]
/// would swallow it.
class _RecordingTraceMonitor implements PerformanceTraceMonitor {
  final List<_RecordingTrace> traces = [];

  @override
  PerformanceTrace startOperationTrace(String traceName) {
    final trace = _RecordingTrace();
    traces.add(trace);
    return trace;
  }
}

class _MockClipManager extends Mock implements ClipManagerNotifier {}

class _MockVideoEditor extends Mock implements VideoEditorNotifier {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _MockEditorVideo extends Mock implements EditorVideo {}

class _MockFile extends Mock implements File {}

/// A fake wakelock platform —
/// production code calls `WakelockPlus.enable/disable` around every
/// recording session, which hits a platform channel that isn't bound
/// in unit tests. Override the platform instance with a fake so the
/// channel call is a no-op.
class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

/// Throws when the wakelock is disabled (`WakelockPlus.disable()` →
/// `toggle(enable: false)`) so the best-effort teardown path can be
/// exercised. Enabling stays a no-op so a recording can still start.
class _ThrowingWakelockDisablePlatform extends WakelockPlusPlatformInterface {
  int disableCalls = 0;

  @override
  Future<void> toggle({required bool enable}) async {
    if (!enable) {
      disableCalls++;
      throw Exception('wakelock disable failed');
    }
  }

  @override
  Future<bool> get enabled async => false;
}

/// Blocks `WakelockPlus.enable()` until [enableGate] completes, so a test can
/// land an event in the window where the start handler awaits the wakelock
/// after the native session has already started.
class _GatedWakelockPlatform extends WakelockPlusPlatformInterface {
  final Completer<void> enableGate = Completer<void>();

  @override
  Future<void> toggle({required bool enable}) async {
    if (enable) await enableGate.future;
  }

  @override
  Future<bool> get enabled async => false;
}

class _MockProVideoEditor extends Mock
    with MockPlatformInterfaceMixin
    implements ProVideoEditor {}

class _MockAudioPlaybackService extends Mock implements AudioPlaybackService {}

void main() {
  late _MockCameraService cameraService;
  late _MockClipManager clipManager;
  late _MockVideoEditor videoEditor;
  late _MockSharedPreferences prefs;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    wakelockPlusPlatformInstance = _FakeWakelockPlatform();
    registerFallbackValue(DivineFlashMode.off);
    registerFallbackValue(DivineCameraLens.back);
    registerFallbackValue(DivineVideoStabilizationMode.off);
    registerFallbackValue(DivineVideoQuality.fhd);
    registerFallbackValue(AppLifecycleState.resumed);
    registerFallbackValue(Offset.zero);
    registerFallbackValue(EditorVideo.file('/fallback.mp4'));
    registerFallbackValue(model.AspectRatio.vertical);
    registerFallbackValue(
      ThumbnailConfigs(
        video: EditorVideo.file('/fallback.mp4'),
        outputSize: const Size(1, 1),
        timestamps: const [Duration.zero],
      ),
    );
    registerFallbackValue(
      SingleThumbnailConfigs(
        video: EditorVideo.file('/fallback.mp4'),
        outputSize: const Size(1, 1),
        position: ThumbnailPosition.last,
      ),
    );
    registerFallbackValue(
      DivineVideoClip(
        id: 'fallback',
        video: EditorVideo.file('/fallback.mp4'),
        duration: Duration.zero,
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 1,
      ),
    );
    registerFallbackValue(<StopMotionClipFrame>[]);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    cameraService = _MockCameraService();
    clipManager = _MockClipManager();
    videoEditor = _MockVideoEditor();
    prefs = _MockSharedPreferences();

    // Sensible defaults that keep the bloc's core handlers from
    // throwing on noSuchMethod when not explicitly stubbed by a test.
    when(() => cameraService.canRecord).thenReturn(true);
    when(() => cameraService.isInitialized).thenReturn(true);
    when(() => cameraService.canSwitchCamera).thenReturn(true);
    when(() => cameraService.hasFlash).thenReturn(true);
    when(() => cameraService.cameraAspectRatio).thenReturn(9 / 16);
    when(() => cameraService.minZoomLevel).thenReturn(0.5);
    when(() => cameraService.maxZoomLevel).thenReturn(5);
    when(() => cameraService.isSwitchingCamera).thenReturn(false);
    when(() => cameraService.currentLens).thenReturn(DivineCameraLens.back);
    when(
      () => cameraService.availableLenses,
    ).thenReturn(const [DivineCameraLens.back, DivineCameraLens.front]);
    when(() => cameraService.currentLensMetadata).thenReturn(null);
    when(
      () => cameraService.videoStabilizationMode,
    ).thenReturn(DivineVideoStabilizationMode.off);
    when(
      () => cameraService.availableVideoStabilizationModes,
    ).thenReturn(const [DivineVideoStabilizationMode.off]);
    when(() => cameraService.isVideoStabilizationSupported).thenReturn(false);
    when(() => cameraService.initializationError).thenReturn(null);
    when(() => cameraService.dispose()).thenAnswer((_) async {});
    when(
      () => cameraService.handleAppLifecycleState(any()),
    ).thenAnswer((_) async {});

    when(() => clipManager.clips).thenReturn(const []);
    when(
      () => clipManager.remainingDuration,
    ).thenReturn(const Duration(seconds: 6));
    when(() => clipManager.totalDuration).thenReturn(Duration.zero);
    when(
      () => clipManager.clearAll(
        keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
      ),
    ).thenAnswer((_) async {});

    when(() => videoEditor.state).thenReturn(VideoEditorProviderState());
    when(
      () => videoEditor.reset(
        keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
      ),
    ).thenAnswer((_) async {});

    when(() => prefs.getString(any())).thenReturn(null);
    when(() => prefs.setString(any(), any())).thenAnswer((_) async => true);
    when(() => prefs.getBool(any())).thenReturn(null);
    when(() => prefs.setBool(any(), any())).thenAnswer((_) async => true);
  });

  /// Builds a bloc with all dependencies wired to the mocks.
  VideoRecorderBloc buildBloc({
    RecordingStartedCallback? onRecordingStarted,
  }) {
    return VideoRecorderBloc(
      readClipManager: () => clipManager,
      readVideoEditor: () => videoEditor,
      readVideoEditorState: VideoEditorProviderState.new,
      readSharedPreferences: () => prefs,
      cameraService: cameraService,
      onRecordingStarted: onRecordingStarted,
    );
  }

  group(VideoRecorderBloc, () {
    test('initial state has all defaults zeroed', () {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      expect(bloc.state, const VideoRecorderBlocState());
      expect(bloc.state.recordingState, VideoRecorderState.idle);
      expect(bloc.state.isStartingRecording, isFalse);
      expect(bloc.state.isStoppingRecording, isFalse);
      expect(bloc.state.zoomLevel, 1.0);
      expect(bloc.state.baseZoomLevel, 1.0);
      expect(bloc.state.snappedTo1x, isFalse);
    });

    test('exposes camera-service delegating getters', () {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      expect(bloc.currentLens, DivineCameraLens.back);
      expect(bloc.availableLenses, hasLength(2));
      expect(bloc.currentLensMetadata, isNull);
    });

    group('showZoomIndicator', () {
      test('shows the zoom ruler when a two-pointer pinch starts', () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(VideoRecorderScaleStarted(ScaleStartDetails(pointerCount: 2)));
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.showZoomIndicator, isTrue);
      });

      test('does not summon the zoom ruler on a one-pointer pan', () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(VideoRecorderScaleStarted(ScaleStartDetails(pointerCount: 1)));
        bloc.add(
          VideoRecorderScaleUpdated(ScaleUpdateDetails(pointerCount: 1)),
        );
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.showZoomIndicator, isFalse);
      });

      test(
        'summons the zoom ruler when a second finger lands mid-pan',
        () async {
          final bloc = buildBloc();
          addTearDown(bloc.close);

          // Pan→pinch escalation: the just-landed second finger reports an
          // unchanged scale (1.0) but a pointerCount of 2, so the update must
          // proceed past the one-pointer pan guard and summon the ruler.
          bloc.add(
            VideoRecorderScaleStarted(ScaleStartDetails(pointerCount: 1)),
          );
          await Future<void>.delayed(Duration.zero);
          bloc.add(
            VideoRecorderScaleUpdated(ScaleUpdateDetails(pointerCount: 2)),
          );
          await Future<void>.delayed(Duration.zero);

          expect(bloc.state.showZoomIndicator, isTrue);
        },
      );

      test('shows the zoom ruler when the zoom level is set', () async {
        when(
          () => cameraService.setZoomLevel(any()),
        ).thenAnswer((inv) async => inv.positionalArguments.first as double);
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(const VideoRecorderZoomLevelSet(2));
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.showZoomIndicator, isTrue);
      });

      test('auto-hides the zoom ruler after the pinch settles', () {
        // Drive the 1000ms auto-hide timer with fakeAsync instead of racing
        // wall-clock, which flakes under the merged-isolate CI run.
        fakeAsync((async) {
          final bloc = buildBloc();

          bloc.add(
            VideoRecorderScaleStarted(ScaleStartDetails(pointerCount: 2)),
          );
          async.flushMicrotasks();
          expect(bloc.state.showZoomIndicator, isTrue);

          async.elapse(const Duration(milliseconds: 1000));
          async.flushMicrotasks();

          expect(bloc.state.showZoomIndicator, isFalse);

          // Close inside the fake zone: a real-zone teardown would await
          // microtasks this (now dead) zone can no longer drain and hang.
          unawaited(bloc.close());
          async.flushMicrotasks();
        });
      });
    });

    group('isPinchActive', () {
      test('is set while a preview scale gesture is in progress', () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(VideoRecorderScaleStarted(ScaleStartDetails(pointerCount: 1)));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.isPinchActive, isTrue);

        bloc.add(const VideoRecorderScaleEnded());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.isPinchActive, isFalse);
      });

      test('is cleared by the indicator auto-hide timer as a safety net '
          'when the scale-end callback is lost', () {
        fakeAsync((async) {
          final bloc = buildBloc();

          bloc.add(
            VideoRecorderScaleStarted(ScaleStartDetails(pointerCount: 2)),
          );
          async.flushMicrotasks();
          // No VideoRecorderScaleEnded — the 1000ms auto-hide timer must
          // release the guard so the ruler doesn't stay non-interactive.
          async.elapse(const Duration(milliseconds: 1000));
          async.flushMicrotasks();

          expect(bloc.state.isPinchActive, isFalse);

          // Close inside the fake zone: a real-zone teardown would await
          // microtasks this (now dead) zone can no longer drain and hang.
          unawaited(bloc.close());
          async.flushMicrotasks();
        });
      });

      test('is re-asserted when a stationary pinch resumes after the timer '
          'fired mid-gesture', () {
        fakeAsync((async) {
          final bloc = buildBloc();

          bloc.add(
            VideoRecorderScaleStarted(ScaleStartDetails(pointerCount: 2)),
          );
          async.flushMicrotasks();
          // Held stationary >1s: no updates, so the auto-hide timer fires
          // while the two fingers are still down and clears the guard.
          async.elapse(const Duration(milliseconds: 1000));
          async.flushMicrotasks();
          expect(bloc.state.isPinchActive, isFalse);

          // The pinch resumes (second finger still down, unchanged scale):
          // the flag must come back so the ruler can't turn interactive and
          // swallow the lower pinch finger.
          bloc.add(
            VideoRecorderScaleUpdated(ScaleUpdateDetails(pointerCount: 2)),
          );
          async.flushMicrotasks();

          expect(bloc.state.isPinchActive, isTrue);
          expect(bloc.state.showZoomIndicator, isTrue);

          unawaited(bloc.close());
          async.flushMicrotasks();
        });
      });
    });

    group('pinch-to-zoom snap', () {
      test('pinching down across the 1× detent snaps zoom to 1.0', () async {
        when(
          () => cameraService.setZoomLevel(any()),
        ).thenAnswer((inv) async => inv.positionalArguments.first as double);
        final bloc = buildBloc();
        addTearDown(bloc.close);

        // Start zoomed in past the detent (base = 1.5), then pinch down so
        // the multiplicative zoom (base × scale) crosses 1.0 — the gravity
        // well + detent should lock it to 1×.
        bloc.emit(const VideoRecorderBlocState(zoomLevel: 1.5));
        bloc.add(VideoRecorderScaleStarted(ScaleStartDetails()));
        await Future<void>.delayed(Duration.zero);
        // 1.5 × 0.9 = 1.35 (still above the detent).
        bloc.add(VideoRecorderScaleUpdated(ScaleUpdateDetails(scale: 0.9)));
        await Future<void>.delayed(Duration.zero);
        // 1.5 × 0.66 = 0.99 (within the snap tolerance of 1.0).
        bloc.add(VideoRecorderScaleUpdated(ScaleUpdateDetails(scale: 0.66)));
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.snappedTo1x, isTrue);
        expect(bloc.state.zoomLevel, closeTo(1.0, 0.02));
      });

      test('maps zoom multiplicatively as base × pinch scale', () async {
        when(
          () => cameraService.setZoomLevel(any()),
        ).thenAnswer((inv) async => inv.positionalArguments.first as double);
        final bloc = buildBloc();
        addTearDown(bloc.close);

        // From 2×, a 1.5× spread reaches 3× (2 × 1.5) regardless of where in
        // the range the gesture starts — uniform sensitivity.
        bloc.emit(const VideoRecorderBlocState(zoomLevel: 2));
        bloc.add(VideoRecorderScaleStarted(ScaleStartDetails()));
        await Future<void>.delayed(Duration.zero);
        bloc.add(VideoRecorderScaleUpdated(ScaleUpdateDetails(scale: 1.5)));
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.zoomLevel, closeTo(3.0, 0.01));
      });
    });

    group('VideoRecorderZoomedByLongPress', () {
      // minZoomLevel = 0.5, maxZoomLevel = 5, base = 1.0 (default),
      // maxDragDistance = 240. Up is negative dy.
      setUp(() {
        when(
          () => cameraService.setZoomLevel(any()),
        ).thenAnswer((inv) async => inv.positionalArguments.first as double);
      });

      test('a full upward drag reaches the camera max zoom', () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(const VideoRecorderZoomedByLongPress(Offset(0, -240)));
        await pumpEventQueue();

        expect(bloc.state.zoomLevel, closeTo(5.0, 0.01));
      });

      test('maps the upward drag exponentially, not linearly', () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);

        // Half the drag lands on the geometric midpoint sqrt(1 × 5) ≈ 2.236,
        // not the linear midpoint of 3.0. This keeps the most-used low end
        // (1×→2×) gentle instead of jumpy.
        bloc.add(const VideoRecorderZoomedByLongPress(Offset(0, -120)));
        await pumpEventQueue();

        expect(bloc.state.zoomLevel, closeTo(2.2360, 0.01));
        expect(bloc.state.zoomLevel, lessThan(3.0));
      });

      test(
        'a downward drag zooms out below 1× toward the camera min',
        () async {
          final bloc = buildBloc();
          addTearDown(bloc.close);

          // A full downward drag (positive dy) reaches the ultra-wide min 0.5×.
          bloc.add(const VideoRecorderZoomedByLongPress(Offset(0, 240)));
          await pumpEventQueue();

          expect(bloc.state.zoomLevel, closeTo(0.5, 0.01));
          verify(() => cameraService.setZoomLevel(0.5)).called(1);
        },
      );

      test('the downward drag is also mapped exponentially', () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);

        // Half the downward drag lands on sqrt(1 × 0.5) ≈ 0.707.
        bloc.add(const VideoRecorderZoomedByLongPress(Offset(0, 120)));
        await pumpEventQueue();

        expect(bloc.state.zoomLevel, closeTo(0.7071, 0.01));
      });

      test(
        'equal upward drag steps multiply zoom by a constant factor',
        () async {
          final bloc = buildBloc();
          addTearDown(bloc.close);

          // Uniform perceived sensitivity: the zoom at the midpoint squared
          // equals base × the zoom at the endpoint (2.236² ≈ 1 × 5).
          bloc.add(const VideoRecorderZoomedByLongPress(Offset(0, -120)));
          await pumpEventQueue();
          final midZoom = bloc.state.zoomLevel;

          bloc.add(const VideoRecorderZoomedByLongPress(Offset(0, -240)));
          await pumpEventQueue();
          final endZoom = bloc.state.zoomLevel;

          expect(midZoom * midZoom, closeTo(1.0 * endZoom, 0.05));
        },
      );
    });

    group('VideoRecorderLongPressZoomStarted', () {
      setUp(() {
        when(
          () => cameraService.setZoomLevel(any()),
        ).thenAnswer((inv) async => inv.positionalArguments.first as double);
      });

      test('captures the current zoom as the drag base', () async {
        // baseZoomLevel defaults to 1×; the gesture must re-anchor it to the
        // live 3× zoom.
        final bloc = buildBloc()
          ..emit(const VideoRecorderBlocState(zoomLevel: 3));
        addTearDown(bloc.close);

        bloc.add(const VideoRecorderLongPressZoomStarted());
        await pumpEventQueue();

        expect(bloc.state.baseZoomLevel, 3.0);
      });

      test(
        'anchors a following drag so it does not snap back to a stale base',
        () async {
          // Path-B regression: recording started elsewhere and a pinch moved
          // zoom to 3× while baseZoomLevel is still the pinch-start 1×. Without
          // the start capture the first drag would jump toward 1×.
          final bloc = buildBloc()
            ..emit(const VideoRecorderBlocState(zoomLevel: 3));
          addTearDown(bloc.close);

          bloc.add(const VideoRecorderLongPressZoomStarted());
          await pumpEventQueue();
          // A small upward drag (10% of the range) nudges zoom up from 3×,
          // not down toward the stale 1× base (which would land near 1.17×).
          bloc.add(const VideoRecorderZoomedByLongPress(Offset(0, -24)));
          await pumpEventQueue();

          expect(bloc.state.zoomLevel, greaterThan(3.0));
          expect(bloc.state.zoomLevel, closeTo(3.155, 0.05));
        },
      );
    });

    group('VideoRecorderFlashToggled', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'cycles off → torch → auto → off and persists each new mode',
        setUp: () {
          when(
            () => cameraService.setFlashMode(any()),
          ).thenAnswer((_) async => true);
        },
        build: () => buildBloc()
          ..emit(const VideoRecorderBlocState(flashMode: DivineFlashMode.off)),
        act: (bloc) async {
          bloc.add(const VideoRecorderFlashToggled());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoRecorderFlashToggled());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoRecorderFlashToggled());
        },
        // off → torch → auto → off. Third state asserts flashMode: off
        // explicitly; second state uses the default (auto) implicitly.
        expect: () => [
          const VideoRecorderBlocState(flashMode: DivineFlashMode.torch),
          const VideoRecorderBlocState(),
          const VideoRecorderBlocState(flashMode: DivineFlashMode.off),
        ],
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does not emit when camera service refuses the change',
        setUp: () {
          when(
            () => cameraService.setFlashMode(any()),
          ).thenAnswer((_) async => false);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderFlashToggled()),
        expect: () => const <VideoRecorderBlocState>[],
      );
    });

    group('VideoRecorderCameraSwitched', () {
      late Completer<bool> switchGate;

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'raises then clears isSwitchingCamera and propagates the new '
        'previewTextureId on a successful switch',
        setUp: () {
          when(
            () => cameraService.switchCamera(),
          ).thenAnswer((_) async => true);
          when(() => cameraService.textureId).thenReturn(42);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderCameraSwitched()),
        expect: () => [
          isA<VideoRecorderBlocState>().having(
            (s) => s.isSwitchingCamera,
            'isSwitchingCamera',
            isTrue,
          ),
          isA<VideoRecorderBlocState>()
              .having((s) => s.isSwitchingCamera, 'isSwitchingCamera', isFalse)
              .having((s) => s.previewTextureId, 'previewTextureId', 42),
        ],
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'still clears isSwitchingCamera via the finally when the switch fails',
        setUp: () {
          when(
            () => cameraService.switchCamera(),
          ).thenAnswer((_) async => false);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderCameraSwitched()),
        expect: () => [
          isA<VideoRecorderBlocState>().having(
            (s) => s.isSwitchingCamera,
            'isSwitchingCamera',
            isTrue,
          ),
          isA<VideoRecorderBlocState>().having(
            (s) => s.isSwitchingCamera,
            'isSwitchingCamera',
            isFalse,
          ),
        ],
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'clears isSwitchingCamera and surfaces the error when the switch '
        'throws',
        // Production CameraService catches internally and returns false; the
        // finally exists for an implementation that violates that contract.
        // Without it the blur would stick and block every later switch.
        setUp: () {
          when(
            () => cameraService.switchCamera(),
          ).thenThrow(PlatformException(code: 'SWITCH_FAILED'));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderCameraSwitched()),
        expect: () => [
          isA<VideoRecorderBlocState>().having(
            (s) => s.isSwitchingCamera,
            'isSwitchingCamera',
            isTrue,
          ),
          isA<VideoRecorderBlocState>().having(
            (s) => s.isSwitchingCamera,
            'isSwitchingCamera',
            isFalse,
          ),
        ],
        errors: () => [isA<PlatformException>()],
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'drops a second switch tap that lands mid-switch (droppable)',
        setUp: () {
          switchGate = Completer<bool>();
          when(
            () => cameraService.switchCamera(),
          ).thenAnswer((_) => switchGate.future);
          when(() => cameraService.textureId).thenReturn(42);
        },
        build: buildBloc,
        act: (bloc) async {
          bloc
            ..add(const VideoRecorderCameraSwitched())
            ..add(const VideoRecorderCameraSwitched());
          await Future<void>.delayed(Duration.zero);
          switchGate.complete(true);
          await Future<void>.delayed(Duration.zero);
        },
        // Only the first tap's emit pair — a rapid double-tap must not queue
        // a second rebind that would just toggle straight back.
        expect: () => [
          isA<VideoRecorderBlocState>().having(
            (s) => s.isSwitchingCamera,
            'isSwitchingCamera',
            isTrue,
          ),
          isA<VideoRecorderBlocState>()
              .having((s) => s.isSwitchingCamera, 'isSwitchingCamera', isFalse)
              .having((s) => s.previewTextureId, 'previewTextureId', 42),
        ],
        verify: (_) {
          verify(() => cameraService.switchCamera()).called(1);
        },
      );
    });

    group('VideoRecorderStabilizationModeSet', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'persists the new mode when the camera accepts it',
        setUp: () {
          when(
            () => cameraService.setVideoStabilizationMode(any()),
          ).thenAnswer((_) async => true);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoRecorderStabilizationModeSet(
            DivineVideoStabilizationMode.cinematic,
          ),
        ),
        expect: () => const [
          VideoRecorderBlocState(
            videoStabilizationMode: DivineVideoStabilizationMode.cinematic,
          ),
        ],
        verify: (_) {
          verify(
            () => cameraService.setVideoStabilizationMode(
              DivineVideoStabilizationMode.cinematic,
            ),
          ).called(1);
          verify(
            () =>
                prefs.setString('camera_last_used_stabilization', 'cinematic'),
          ).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does not emit when camera service refuses the change',
        setUp: () {
          when(
            () => cameraService.setVideoStabilizationMode(any()),
          ).thenAnswer((_) async => false);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoRecorderStabilizationModeSet(
            DivineVideoStabilizationMode.standard,
          ),
        ),
        expect: () => const <VideoRecorderBlocState>[],
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'ignores a no-op set to the already-active mode',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoRecorderStabilizationModeSet(
            DivineVideoStabilizationMode.off,
          ),
        ),
        expect: () => const <VideoRecorderBlocState>[],
        verify: (_) {
          verifyNever(() => cameraService.setVideoStabilizationMode(any()));
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'ignores mode changes while recording',
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
            ),
          ),
        act: (bloc) => bloc.add(
          const VideoRecorderStabilizationModeSet(
            DivineVideoStabilizationMode.standard,
          ),
        ),
        expect: () => const <VideoRecorderBlocState>[],
        verify: (_) {
          verifyNever(() => cameraService.setVideoStabilizationMode(any()));
          verifyNever(
            () => prefs.setString('camera_last_used_stabilization', any()),
          );
        },
      );
    });

    group('VideoRecorderAspectRatioToggled', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'flips vertical → square → vertical',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderAspectRatioToggled());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoRecorderAspectRatioToggled());
        },
        expect: () => [
          const VideoRecorderBlocState(aspectRatio: model.AspectRatio.square),
          const VideoRecorderBlocState(),
        ],
      );
    });

    group('VideoRecorderTimerCycled', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'cycles off → three → ten → off',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderTimerCycled());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoRecorderTimerCycled());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoRecorderTimerCycled());
        },
        expect: () => [
          const VideoRecorderBlocState(timerDuration: TimerDuration.three),
          const VideoRecorderBlocState(timerDuration: TimerDuration.ten),
          const VideoRecorderBlocState(),
        ],
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does not enable the timer outside capture mode',
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recorderMode: VideoRecorderMode.classic,
              aspectRatio: model.AspectRatio.square,
              showGridLines: true,
            ),
          ),
        act: (bloc) => bloc.add(const VideoRecorderTimerCycled()),
        expect: () => const <VideoRecorderBlocState>[],
      );
    });

    group('VideoRecorderGridLinesToggled', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'toggles showGridLines',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderGridLinesToggled());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoRecorderGridLinesToggled());
        },
        expect: () => [
          const VideoRecorderBlocState(showGridLines: true),
          const VideoRecorderBlocState(),
        ],
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'persists each choice',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderGridLinesToggled());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoRecorderGridLinesToggled());
        },
        verify: (_) {
          verify(
            () => prefs.setBool('camera_grid_lines_enabled', true),
          ).called(1);
          verify(
            () => prefs.setBool('camera_grid_lines_enabled', false),
          ).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'a persisted off choice keeps the grid hidden on mode switch',
        setUp: () {
          when(
            () => prefs.getBool('camera_grid_lines_enabled'),
          ).thenReturn(false);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoRecorderRecorderModeSet(VideoRecorderMode.classic),
        ),
        verify: (bloc) {
          expect(bloc.state.recorderMode, VideoRecorderMode.classic);
          expect(bloc.state.showGridLines, isFalse);
        },
      );
    });

    group('VideoRecorderShowLastClipOverlayToggled', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'toggles showLastClipOverlay',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoRecorderShowLastClipOverlayToggled()),
        expect: () => const [VideoRecorderBlocState(showLastClipOverlay: true)],
      );
    });

    group('VideoRecorderZoomLevelSet', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'emits new zoom level when in bounds and camera accepts',
        setUp: () {
          when(
            () => cameraService.setZoomLevel(any()),
          ).thenAnswer((inv) async => inv.positionalArguments.first as double);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderZoomLevelSet(2)),
        expect: () => const [
          VideoRecorderBlocState(
            zoomLevel: 2,
            minZoomLevel: 0.5,
            maxZoomLevel: 5,
            showZoomIndicator: true,
          ),
        ],
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'emits the zoom the camera actually applied — not the request — '
        'when the OS silently clamps it, and mirrors the shrunk range',
        setUp: () {
          // Runtime-restricted camera: requests above 2.5 are applied as
          // 2.5 (iOS clamps them silently, without an error). The service
          // getters still report the stale configure-time range (5.0)
          // until the first set refreshes them to the live range (2.5) —
          // mirroring how the real service learns of the restriction.
          var restricted = false;
          when(() => cameraService.setZoomLevel(any())).thenAnswer((inv) async {
            final requested = inv.positionalArguments.first as double;
            if (requested <= 2.5) return requested;
            restricted = true;
            return 2.5;
          });
          when(
            () => cameraService.maxZoomLevel,
          ).thenAnswer((_) => restricted ? 2.5 : 5.0);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderZoomLevelSet(4)),
        expect: () => const [
          VideoRecorderBlocState(
            zoomLevel: 2.5,
            minZoomLevel: 0.5,
            maxZoomLevel: 2.5,
            showZoomIndicator: true,
          ),
        ],
      );

      test('heals a stale shrunk ceiling on pinch-out even when the clamp '
          'pins the zoom to the current level', () async {
        // The live max was restricted to 2.5 and the user is pinned there.
        // The restriction has since lifted (live max back to 5.0) but the
        // service still advertises the stale 2.5 until the next set's
        // read-back refreshes it. A pinch-out clamps back to 2.5 (== the
        // current zoom), so the applied zoom doesn't move — the dispatch
        // must still fire so the ceiling heals on this gesture rather than
        // staying capped until the user first pinches back in.
        var healed = false;
        when(() => cameraService.setZoomLevel(any())).thenAnswer((inv) async {
          healed = true;
          return inv.positionalArguments.first as double;
        });
        when(
          () => cameraService.maxZoomLevel,
        ).thenAnswer((_) => healed ? 5.0 : 2.5);

        final bloc = buildBloc()
          ..emit(
            const VideoRecorderBlocState(zoomLevel: 2.5, maxZoomLevel: 2.5),
          );
        addTearDown(bloc.close);

        bloc.add(VideoRecorderScaleStarted(ScaleStartDetails(pointerCount: 2)));
        await pumpEventQueue();
        // 2.5 × 1.6 = 4.0 > stale max 2.5, so clampedZoom pins back to 2.5.
        bloc.add(VideoRecorderScaleUpdated(ScaleUpdateDetails(scale: 1.6)));
        await pumpEventQueue();

        verify(() => cameraService.setZoomLevel(2.5)).called(1);
        expect(bloc.state.maxZoomLevel, 5.0);
      });

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'no-op when zoom value out of bounds',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderZoomLevelSet(99)),
        expect: () => const <VideoRecorderBlocState>[],
        verify: (_) {
          verifyNever(() => cameraService.setZoomLevel(any()));
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'no-op when camera service refuses',
        setUp: () {
          when(
            () => cameraService.setZoomLevel(any()),
          ).thenAnswer((_) async => null);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderZoomLevelSet(2)),
        expect: () => const <VideoRecorderBlocState>[],
      );
    });

    group('VideoRecorderFocusPointSet', () {
      test(
        'emits focusPoint then resets to zero after the auto-hide timer',
        () {
          fakeAsync((async) {
            when(
              () => cameraService.setFocusPoint(any()),
            ).thenAnswer((_) async => true);

            final bloc = buildBloc();
            bloc.add(const VideoRecorderFocusPointSet(Offset(0.5, 0.5)));
            async.flushMicrotasks();
            expect(bloc.state.focusPoint, const Offset(0.5, 0.5));

            async.elapse(const Duration(milliseconds: 800));
            async.flushMicrotasks();
            expect(bloc.state.focusPoint, Offset.zero);

            unawaited(bloc.close());
            async.flushMicrotasks();
          });
        },
      );
    });

    group('VideoRecorderRecordingToggleRequested', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'when idle, dispatches RecordingStartRequested',
        setUp: () {
          when(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          ).thenAnswer((_) async => true);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderRecordingToggleRequested()),
        // start emits: isStartingRecording=true → recording → isStartingRecording=false
        verify: (bloc) {
          expect(bloc.state.isStartingRecording, isFalse);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'when camera is mid-switch, the toggle is ignored',
        setUp: () {
          when(() => cameraService.isSwitchingCamera).thenReturn(true);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderRecordingToggleRequested()),
        expect: () => const <VideoRecorderBlocState>[],
        verify: (_) {
          verifyNever(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          );
        },
      );
    });

    group('sound playback source selection', () {
      late _MockAudioPlaybackService audioService;

      setUp(() {
        audioService = _MockAudioPlaybackService();
        when(audioService.configureForRecording).thenAnswer((_) async {});
        when(
          () => audioService.loadAudio(any()),
        ).thenAnswer((_) async => const Duration(seconds: 5));
        when(
          () => audioService.loadAudioFromFile(any()),
        ).thenAnswer((_) async => const Duration(seconds: 5));
        when(audioService.play).thenAnswer((_) async {});
        when(audioService.dispose).thenAnswer((_) async {});
        when(
          () => cameraService.startRecording(
            maxDuration: any(named: 'maxDuration'),
          ),
        ).thenAnswer((_) async => true);
      });

      VideoRecorderBloc buildBlocWithSound(model.AudioEvent sound) {
        return VideoRecorderBloc(
          readClipManager: () => clipManager,
          readVideoEditor: () => videoEditor,
          readVideoEditorState: () =>
              VideoEditorProviderState(selectedSound: sound),
          readSharedPreferences: () => prefs,
          cameraService: cameraService,
          audioPlaybackServiceFactory: () => audioService,
        );
      }

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'loads imported audio from file instead of parsing it as a URL',
        build: () => buildBlocWithSound(
          model.AudioEvent.fromLocalImport(
            id: '${model.AudioEvent.localImportMarker}_1',
            filePath: '/var/mobile/draft_audio/import.mp3',
            createdAt: 0,
            title: 'Imported',
            mimeType: 'audio/mpeg',
          ),
        ),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStartRequested()),
        verify: (_) {
          verify(
            () => audioService.loadAudioFromFile(
              '/var/mobile/draft_audio/import.mp3',
            ),
          ).called(1);
          verifyNever(() => audioService.loadAudio(any()));
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'loads remote audio via loadAudio',
        build: () => buildBlocWithSound(
          model.AudioEvent(
            id: 'remote',
            pubkey: 'abc',
            createdAt: 0,
            url: 'https://example.com/audio.mp3',
          ),
        ),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStartRequested()),
        verify: (_) {
          verify(
            () => audioService.loadAudio('https://example.com/audio.mp3'),
          ).called(1);
          verifyNever(() => audioService.loadAudioFromFile(any()));
        },
      );
    });

    group('RecordingStartRequested → flags-in-state migration', () {
      test('reports analytics only after native recording succeeds', () async {
        final reportedModes = <VideoRecorderMode>[];
        when(
          () => cameraService.startRecording(
            maxDuration: any(named: 'maxDuration'),
          ),
        ).thenAnswer((_) async => true);
        final bloc = buildBloc(onRecordingStarted: reportedModes.add);
        addTearDown(bloc.close);

        bloc.add(const VideoRecorderRecordingStartRequested());
        await bloc.stream.firstWhere(
          (state) =>
              state.recordingState == VideoRecorderState.recording &&
              !state.isStartingRecording,
        );

        expect(reportedModes, [VideoRecorderMode.capture]);
      });

      test('does not report analytics when native recording fails', () async {
        final reportedModes = <VideoRecorderMode>[];
        when(
          () => cameraService.startRecording(
            maxDuration: any(named: 'maxDuration'),
          ),
        ).thenAnswer((_) async => false);
        final bloc = buildBloc(onRecordingStarted: reportedModes.add);
        addTearDown(bloc.close);

        bloc.add(const VideoRecorderRecordingStartRequested());
        await bloc.stream.firstWhere(
          (state) =>
              state.recordingState == VideoRecorderState.idle &&
              !state.isStartingRecording,
        );

        expect(reportedModes, isEmpty);
      });

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'sets isStartingRecording true before the camera call and false '
        'after, with recordingState transitioning to recording',
        setUp: () {
          when(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          ).thenAnswer((_) async => true);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderRecordingStartRequested()),
        // Expected sequence:
        //   1. isStartingRecording=true, baseZoomLevel=1.0
        //   2. recordingState=recording (no countdown path)
        //   3. isStartingRecording=false (success)
        verify: (bloc) {
          expect(bloc.state.recordingState, VideoRecorderState.recording);
          expect(bloc.state.isStartingRecording, isFalse);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'on camera-rejected start, recordingState returns to idle and '
        'isStartingRecording resets to false',
        setUp: () {
          when(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          ).thenAnswer((_) async => false);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderRecordingStartRequested()),
        verify: (bloc) {
          expect(bloc.state.recordingState, VideoRecorderState.idle);
          expect(bloc.state.isStartingRecording, isFalse);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'guards against re-entry when isStartingRecording is already true',
        build: () =>
            buildBloc()
              ..emit(const VideoRecorderBlocState(isStartingRecording: true)),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStartRequested()),
        expect: () => const <VideoRecorderBlocState>[],
        verify: (_) {
          verifyNever(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'guards against start when isStoppingRecording is true',
        build: () =>
            buildBloc()
              ..emit(const VideoRecorderBlocState(isStoppingRecording: true)),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStartRequested()),
        expect: () => const <VideoRecorderBlocState>[],
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'starts classic recording immediately when capture timer was set',
        setUp: () {
          when(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          ).thenAnswer((_) async => true);
        },
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recorderMode: VideoRecorderMode.classic,
              aspectRatio: model.AspectRatio.square,
              showGridLines: true,
              timerDuration: TimerDuration.three,
            ),
          ),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStartRequested()),
        expect: () => const [
          VideoRecorderBlocState(
            recorderMode: VideoRecorderMode.classic,
            aspectRatio: model.AspectRatio.square,
            showGridLines: true,
            timerDuration: TimerDuration.three,
            isStartingRecording: true,
          ),
          VideoRecorderBlocState(
            recorderMode: VideoRecorderMode.classic,
            recordingState: VideoRecorderState.recording,
            aspectRatio: model.AspectRatio.square,
            showGridLines: true,
            timerDuration: TimerDuration.three,
            isStartingRecording: true,
          ),
          VideoRecorderBlocState(
            recorderMode: VideoRecorderMode.classic,
            recordingState: VideoRecorderState.recording,
            aspectRatio: model.AspectRatio.square,
            showGridLines: true,
            timerDuration: TimerDuration.three,
          ),
        ],
        verify: (_) {
          verifyNever(
            () => cameraService.setVolumeKeysEnabled(
              enabled: any(named: 'enabled'),
            ),
          );
          verify(
            () => cameraService.startRecording(
              maxDuration: const Duration(seconds: 6),
            ),
          ).called(1);
        },
      );
    });

    group('RecordingStopRequested → start-cancel fast path', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'when called during startRecording, sets pendingStopAfterStart '
        'without touching the camera service',
        build: () =>
            buildBloc()
              ..emit(const VideoRecorderBlocState(isStartingRecording: true)),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
        expect: () => const [
          VideoRecorderBlocState(
            isStartingRecording: true,
            pendingStopAfterStart: true,
          ),
        ],
        verify: (_) {
          // No native stop is fired — the start handler will dispatch a
          // proper stop after startRecording() completes.
          verifyNever(() => cameraService.stopRecording());
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'when isStoppingRecording is already true, is fully ignored',
        build: () =>
            buildBloc()
              ..emit(const VideoRecorderBlocState(isStoppingRecording: true)),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
        expect: () => const <VideoRecorderBlocState>[],
        verify: (_) {
          verifyNever(() => cameraService.stopRecording());
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'when idle with no video result, the stop event is a no-op',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
        expect: () => const <VideoRecorderBlocState>[],
        verify: (_) {
          verifyNever(() => cameraService.stopRecording());
        },
      );
    });

    group('RecordingStopRequested → failure recovery', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'resets to idle when the native stop throws, so isStoppingRecording '
        'is never latched true and future stops are not permanently blocked',
        setUp: () {
          when(
            () => cameraService.stopRecording(),
          ).thenThrow(Exception('native stop failed'));
        },
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
            ),
          ),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<VideoRecorderBlocState>()
              .having(
                (s) => s.isStoppingRecording,
                'isStoppingRecording',
                isTrue,
              )
              .having(
                (s) => s.recordingState,
                'recordingState',
                VideoRecorderState.recording,
              ),
          isA<VideoRecorderBlocState>()
              .having(
                (s) => s.isStoppingRecording,
                'isStoppingRecording',
                isFalse,
              )
              .having(
                (s) => s.recordingState,
                'recordingState',
                VideoRecorderState.idle,
              ),
        ],
        verify: (bloc) {
          expect(bloc.state.isStoppingRecording, isFalse);
          expect(bloc.state.recordingState, VideoRecorderState.idle);
          // stopRecording() must run on the recovery path too — it cancels the
          // periodic duration timer that resetRecording() leaves running.
          verify(() => clipManager.stopRecording()).called(1);
          verify(() => clipManager.resetRecording()).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'a wakelock disable failure is swallowed (best-effort) — the stop '
        'still completes, no error is surfaced, and the recorder is not '
        'driven into the recovery path',
        setUp: () {
          wakelockPlusPlatformInstance = _ThrowingWakelockDisablePlatform();
          when(
            () => cameraService.stopRecording(),
          ).thenAnswer((_) async => null);
        },
        tearDown: () {
          wakelockPlusPlatformInstance = _FakeWakelockPlatform();
        },
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
            ),
          ),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
        // No error reaches addError: the wakelock failure is logged and
        // swallowed by _disableWakelockSafely, never the recovery catch.
        errors: () => const <Object>[],
        verify: (bloc) {
          expect(bloc.state.isStoppingRecording, isFalse);
          expect(bloc.state.recordingState, VideoRecorderState.idle);
          // The duration timer is still cancelled even though wakelock threw.
          verify(() => clipManager.stopRecording()).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'on a clean stop, clipManager.stopRecording() is called so the '
        'periodic duration timer is cancelled on the normal path',
        setUp: () {
          when(
            () => cameraService.stopRecording(),
          ).thenAnswer((_) async => null);
        },
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
            ),
          ),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
        errors: () => const <Object>[],
        verify: (bloc) {
          expect(bloc.state.isStoppingRecording, isFalse);
          expect(bloc.state.recordingState, VideoRecorderState.idle);
          verify(() => clipManager.stopRecording()).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'a new stop is honored after a recovery — isStoppingRecording is '
        'cleared, not latched, so the recorder is not permanently blocked',
        setUp: () {
          var calls = 0;
          when(() => cameraService.stopRecording()).thenAnswer((_) async {
            calls++;
            if (calls == 1) throw Exception('native stop failed');
            return null;
          });
        },
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
            ),
          ),
        act: (bloc) async {
          bloc.add(const VideoRecorderRecordingStopRequested());
          await Future<void>.delayed(Duration.zero);
          // Re-arm to recording; the second stop must reach the native call
          // rather than bail on a latched isStoppingRecording guard.
          bloc.emit(
            const VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
            ),
          );
          bloc.add(const VideoRecorderRecordingStopRequested());
        },
        errors: () => [isA<Exception>()],
        verify: (bloc) {
          // Both stops reached the native call — the first recovered without
          // latching isStoppingRecording=true (which would have bailed the
          // second at the top of the handler).
          verify(() => cameraService.stopRecording()).called(2);
          expect(bloc.state.isStoppingRecording, isFalse);
          expect(bloc.state.recordingState, VideoRecorderState.idle);
        },
      );
    });

    group('sequential() transformer contract', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'queued RecordingStartRequested events process FIFO, not '
        'concurrently — the second start is rejected by the in-flight '
        'guard (isStartingRecording=true) instead of racing it',
        setUp: () {
          when(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          ).thenAnswer((_) async {
            // Simulate a slow native start so the second event would
            // otherwise overlap if the transformer were concurrent.
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return true;
          });
        },
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderRecordingStartRequested());
          bloc.add(const VideoRecorderRecordingStartRequested());
        },
        wait: const Duration(milliseconds: 200),
        verify: (_) {
          // Sequential: both events ran in order. The second one saw
          // recordingState=recording and short-circuited (no camera
          // start was issued). Net camera-start calls: 1.
          verify(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'a hung clip post-processing does not strand the next stop — the '
        'detached enrichment must not hold the sequential() stop bucket',
        setUp: () {
          // The first stop yields a clip whose post-processing hangs forever
          // at its first await (safeFilePath). Before the fix that await ran
          // *inside* the sequential() stop handler, so the handler never
          // completed and the next stop could never be processed — the field
          // symptom was a volume-button stop that did nothing for ~1 minute.
          final hangingVideo = _MockEditorVideo();
          when(
            hangingVideo.safeFilePath,
          ).thenAnswer((_) => Completer<String>().future);
          when(
            () => cameraService.stopRecording(),
          ).thenAnswer((_) async => hangingVideo);
          when(
            () => clipManager.addClip(
              video: any(named: 'video'),
              originalAspectRatio: any(named: 'originalAspectRatio'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
              lensMetadata: any(named: 'lensMetadata'),
              limitClipDuration: any(named: 'limitClipDuration'),
            ),
          ).thenReturn(
            DivineVideoClip(
              id: 'hung-clip',
              video: hangingVideo,
              duration: const Duration(seconds: 2),
              recordedAt: DateTime(2024),
              targetAspectRatio: model.AspectRatio.vertical,
              originalAspectRatio: 9 / 16,
            ),
          );
          when(
            () => clipManager.saveClipToLibrary(any()),
          ).thenAnswer((_) async => true);
        },
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
            ),
          ),
        act: (bloc) async {
          bloc.add(const VideoRecorderRecordingStopRequested());
          await pumpEventQueue();
          // The first stop's enrichment is now hanging in the background.
          // Re-arm to recording and request a second stop: it must still be
          // honored rather than queued behind the hung post-processing.
          bloc.emit(
            const VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
            ),
          );
          bloc.add(const VideoRecorderRecordingStopRequested());
          await pumpEventQueue();
        },
        verify: (_) {
          // Both stops reached the native stop — the second was not stranded
          // behind the first stop's hung post-processing in the sequential()
          // bucket.
          verify(() => cameraService.stopRecording()).called(2);
        },
      );
    });

    group('detached enrichment', () {
      late Directory docsDir;
      late File recordingFile;
      late ProVideoEditor originalProVideoEditor;
      late PathProviderPlatform originalPathProvider;

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'saves the common track end after detached enrichment settles',
        setUp: () {
          docsDir = Directory.systemTemp.createTempSync('rec_enrich_docs');
          originalPathProvider = PathProviderPlatform.instance;
          PathProviderPlatform.instance = MockPathProviderPlatform()
            ..setApplicationDocumentsPath(docsDir.path)
            ..setTemporaryPath(docsDir.path);

          final editor = _MockProVideoEditor();
          when(() => editor.getMetadata(any())).thenAnswer(
            (_) async => VideoMetadata(
              duration: const Duration(milliseconds: 6033),
              audioDuration: const Duration(milliseconds: 5998),
              extension: 'mp4',
              fileSize: 1024,
              resolution: const Size(720, 1280),
              rotation: 0,
              bitrate: 2000000,
            ),
          );
          when(() => editor.getThumbnails(any())).thenAnswer(
            (_) async => [
              Uint8List.fromList(const [1, 2, 3]),
            ],
          );
          when(
            () => editor.getSingleThumbnail(any()),
          ).thenAnswer((_) async => Uint8List.fromList(const [1, 2, 3]));
          originalProVideoEditor = ProVideoEditor.instance;
          ProVideoEditor.instance = editor;

          recordingFile = File('${docsDir.path}/recording.mp4')
            ..writeAsStringSync('recorded clip');
          final recorded = _MockEditorVideo();
          when(
            recorded.safeFilePath,
          ).thenAnswer((_) async => recordingFile.path);
          when(
            () => cameraService.stopRecording(),
          ).thenAnswer((_) async => recorded);

          var currentClip = DivineVideoClip(
            id: 'aligned-clip',
            video: recorded,
            duration: const Duration(milliseconds: 6033),
            recordedAt: DateTime(2024),
            targetAspectRatio: model.AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
          );
          when(
            () => clipManager.addClip(
              video: any(named: 'video'),
              originalAspectRatio: any(named: 'originalAspectRatio'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
              lensMetadata: any(named: 'lensMetadata'),
              limitClipDuration: any(named: 'limitClipDuration'),
            ),
          ).thenReturn(currentClip);
          when(() => clipManager.updateClipDuration(any(), any())).thenAnswer((
            invocation,
          ) {
            currentClip = currentClip.copyWith(
              duration: invocation.positionalArguments[1] as Duration,
            );
          });
          when(
            () => clipManager.updateThumbnail(
              clipId: any(named: 'clipId'),
              thumbnailPath: any(named: 'thumbnailPath'),
              thumbnailTimestamp: any(named: 'thumbnailTimestamp'),
            ),
          ).thenAnswer((_) {});
          when(
            () => clipManager.updateGhostFrame(
              clipId: any(named: 'clipId'),
              ghostFramePath: any(named: 'ghostFramePath'),
            ),
          ).thenAnswer((_) {});
          var clipsReadCount = 0;
          when(() => clipManager.clips).thenAnswer((_) {
            clipsReadCount += 1;
            // Skip preloading in this unit test; the final enrichment lookup
            // still sees the clip after the duration update.
            return clipsReadCount == 1 ? const [] : [currentClip];
          });
          when(
            () => clipManager.saveClipToLibrary(any()),
          ).thenAnswer((_) async => true);
        },
        tearDown: () {
          ProVideoEditor.instance = originalProVideoEditor;
          PathProviderPlatform.instance = originalPathProvider;
          if (docsDir.existsSync()) docsDir.deleteSync(recursive: true);
        },
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
            ),
          ),
        act: (bloc) async {
          bloc.add(const VideoRecorderRecordingStopRequested());
          await pumpEventQueue(times: 100);
        },
        verify: (_) {
          verify(
            () => clipManager.updateClipDuration(
              'aligned-clip',
              const Duration(milliseconds: 5998),
            ),
          ).called(1);
          final savedClips = verify(
            () => clipManager.saveClipToLibrary(captureAny()),
          ).captured.cast<DivineVideoClip>();
          expect(savedClips, hasLength(2));
          expect(
            savedClips.last.duration,
            equals(const Duration(milliseconds: 5998)),
          );
          expect(File('${recordingFile.path}.work.mp4').existsSync(), isFalse);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'skips the enriched save and still deletes the work copy when the clip '
        'is gone before the metadata save — the work copy must not leak',
        setUp: () {
          // Stub path provider + ProVideoEditor so the detached enrichment runs
          // to completion (thumbnail + ghost frame succeed on the first try, no
          // retries) and reaches the clip lookup.
          docsDir = Directory.systemTemp.createTempSync('rec_enrich_docs');
          originalPathProvider = PathProviderPlatform.instance;
          PathProviderPlatform.instance = MockPathProviderPlatform()
            ..setApplicationDocumentsPath(docsDir.path)
            ..setTemporaryPath(docsDir.path);

          final editor = _MockProVideoEditor();
          when(() => editor.getMetadata(any())).thenAnswer(
            (_) async => VideoMetadata.fromMap(const {'duration': 2000}, 'mp4'),
          );
          when(() => editor.getThumbnails(any())).thenAnswer(
            (_) async => [
              Uint8List.fromList(const [1, 2, 3]),
            ],
          );
          when(
            () => editor.getSingleThumbnail(any()),
          ).thenAnswer((_) async => Uint8List.fromList(const [1, 2, 3]));
          originalProVideoEditor = ProVideoEditor.instance;
          ProVideoEditor.instance = editor;

          recordingFile = File('${docsDir.path}/recording.mp4')
            ..writeAsStringSync('recorded clip');
          final recorded = _MockEditorVideo();
          when(
            recorded.safeFilePath,
          ).thenAnswer((_) async => recordingFile.path);
          when(
            () => cameraService.stopRecording(),
          ).thenAnswer((_) async => recorded);
          when(
            () => clipManager.addClip(
              video: any(named: 'video'),
              originalAspectRatio: any(named: 'originalAspectRatio'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
              lensMetadata: any(named: 'lensMetadata'),
              limitClipDuration: any(named: 'limitClipDuration'),
            ),
          ).thenReturn(
            DivineVideoClip(
              id: 'removed-clip',
              video: recorded,
              duration: const Duration(seconds: 2),
              recordedAt: DateTime(2024),
              targetAspectRatio: model.AspectRatio.vertical,
              originalAspectRatio: 9 / 16,
            ),
          );
          // clips stays empty (the shared setUp default), modelling a clip that
          // was removed before the detached enrichment looks it up
          // (delete-last-clip undo, capture↔classic switch).
          when(
            () => clipManager.saveClipToLibrary(any()),
          ).thenAnswer((_) async => true);
        },
        tearDown: () {
          ProVideoEditor.instance = originalProVideoEditor;
          PathProviderPlatform.instance = originalPathProvider;
          if (docsDir.existsSync()) docsDir.deleteSync(recursive: true);
        },
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
            ),
          ),
        act: (bloc) async {
          bloc.add(const VideoRecorderRecordingStopRequested());
          await pumpEventQueue(times: 100);
        },
        verify: (_) {
          // Only the bare clip save ran; the enriched save was skipped because
          // the clip was gone (firstWhereOrNull → null, not a thrown
          // StateError swallowed by catchError).
          verify(() => clipManager.saveClipToLibrary(any())).called(1);
          // The work copy is always cleaned up in the finally — before the fix
          // the firstWhere StateError jumped past the delete and leaked it.
          expect(File('${recordingFile.path}.work.mp4').existsSync(), isFalse);
        },
      );
    });

    group('VideoRecorderCameraPausedForNavigation → recording lock', () {
      late Completer<bool> startGate;

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'resets an active recording to idle when the camera is released for '
        'navigation, so it cannot survive as an unstoppable session',
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
            ),
          ),
        act: (bloc) => bloc.add(const VideoRecorderCameraPausedForNavigation()),
        verify: (bloc) {
          expect(bloc.state.recordingState, VideoRecorderState.idle);
          expect(bloc.state.isStartingRecording, isFalse);
          verify(() => clipManager.stopRecording()).called(1);
          verify(() => clipManager.resetRecording()).called(1);
          // Disposed by the pause handler (the bloc also disposes on close()).
          verify(() => cameraService.dispose());
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'rejects a record start while locked for navigation — a volume / BLE '
        'trigger that races the push must not start a recording',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderCameraPausedForNavigation());
          await pumpEventQueue();
          bloc.add(const VideoRecorderRecordingStartRequested());
          await pumpEventQueue();
        },
        verify: (_) {
          // canRecord is still true on the mock, so only the navigation lock
          // can stop the start from reaching the camera.
          verifyNever(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'aborts an in-flight start when the camera is released mid-start, '
        'returning to idle instead of latching an unstoppable recording',
        setUp: () {
          // The native start hangs until [startGate] completes, modelling a
          // slow start that is still in flight when navigation releases the
          // camera.
          startGate = Completer<bool>();
          when(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          ).thenAnswer((_) => startGate.future);
          when(
            () => cameraService.stopRecording(),
          ).thenAnswer((_) async => null);
        },
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderRecordingStartRequested());
          await pumpEventQueue();
          // Camera released for navigation while the native start is pending.
          bloc.add(const VideoRecorderCameraPausedForNavigation());
          await pumpEventQueue();
          // Native start finally reports success — the handler must see the
          // lock and abort rather than latch a recording.
          startGate.complete(true);
          await pumpEventQueue();
        },
        verify: (bloc) {
          expect(bloc.state.recordingState, VideoRecorderState.idle);
          expect(bloc.state.isStartingRecording, isFalse);
          // Best-effort stop of the just-started native session.
          verify(() => cameraService.stopRecording()).called(1);
          // Disposed by the pause handler (the bloc also disposes on close()).
          verify(() => cameraService.dispose());
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'completes the navigation completer after the camera is disposed — the '
        'audio-session handoff must run strictly after dispose',
        build: buildBloc,
        act: (bloc) {
          // act awaits the returned future, so a completer that never resolves
          // fails the test by timing out.
          final completion = Completer<void>();
          bloc.add(
            VideoRecorderCameraPausedForNavigation(completion: completion),
          );
          return completion.future;
        },
        verify: (_) {
          // Disposed by the pause handler (the bloc also disposes on close()).
          verify(() => cameraService.dispose());
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'still completes the navigation completer when camera dispose throws — '
        'the finally must unblock the caller even on failure',
        setUp: () {
          when(
            () => cameraService.dispose(),
          ).thenThrow(Exception('dispose failed'));
        },
        build: buildBloc,
        act: (bloc) {
          final completion = Completer<void>();
          bloc.add(
            VideoRecorderCameraPausedForNavigation(completion: completion),
          );
          return completion.future;
        },
        errors: () => [isA<Exception>()],
      );
    });

    group('VideoRecorderRecordingLockedForNavigation → recording lock', () {
      late Completer<bool> startGate;
      late File orphanFile;
      late _GatedWakelockPlatform gatedWakelock;

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'resets an active recording to idle without disposing the camera — the '
        'camera is released later by CameraPausedForNavigation',
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
            ),
          ),
        act: (bloc) =>
            bloc.add(const VideoRecorderRecordingLockedForNavigation()),
        verify: (bloc) {
          expect(bloc.state.recordingState, VideoRecorderState.idle);
          expect(bloc.state.isStartingRecording, isFalse);
          verify(() => clipManager.stopRecording()).called(1);
          verify(() => clipManager.resetRecording()).called(1);
          // The lock itself does NOT dispose — the single dispose is the
          // bloc's own close() teardown.
          verify(() => cameraService.dispose()).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'rejects a record start while locked — a volume / BLE trigger that '
        'races the push must not start a recording',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderRecordingLockedForNavigation());
          await pumpEventQueue();
          bloc.add(const VideoRecorderRecordingStartRequested());
          await pumpEventQueue();
        },
        verify: (_) {
          verifyNever(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'aborts an in-flight start when navigation locks, on the still-live '
        'camera — the start resolves and returns to idle, no dispose race',
        setUp: () {
          startGate = Completer<bool>();
          when(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          ).thenAnswer((_) => startGate.future);
          when(
            () => cameraService.stopRecording(),
          ).thenAnswer((_) async => null);
        },
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderRecordingStartRequested());
          await pumpEventQueue();
          // Navigation locks while the native start is still pending — the
          // camera is NOT disposed here (that is deferred), so the start can
          // resolve and abort cleanly.
          bloc.add(const VideoRecorderRecordingLockedForNavigation());
          await pumpEventQueue();
          startGate.complete(true);
          await pumpEventQueue();
        },
        verify: (bloc) {
          expect(bloc.state.recordingState, VideoRecorderState.idle);
          expect(bloc.state.isStartingRecording, isFalse);
          // Best-effort stop of the just-started native session.
          verify(() => cameraService.stopRecording()).called(1);
          // No dispose during the abort — the single dispose is close().
          verify(() => cameraService.dispose()).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'discards the orphaned file of an aborted in-flight start — the '
        'recording is never surfaced, so its file must not leak on disk',
        setUp: () {
          startGate = Completer<bool>();
          when(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          ).thenAnswer((_) => startGate.future);
          // The aborted native session yields a real file that, without the
          // discard, would be orphaned (never added to the library).
          orphanFile = File(
            '${Directory.systemTemp.createTempSync('rec_abort').path}/clip.mp4',
          )..writeAsStringSync('aborted recording');
          final aborted = _MockEditorVideo();
          when(aborted.safeFilePath).thenAnswer((_) async => orphanFile.path);
          when(
            () => cameraService.stopRecording(),
          ).thenAnswer((_) async => aborted);
        },
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderRecordingStartRequested());
          await pumpEventQueue();
          bloc.add(const VideoRecorderRecordingLockedForNavigation());
          await pumpEventQueue();
          // Native start finally reports success after the lock landed — the
          // handler stops it and must delete the orphaned file.
          startGate.complete(true);
          await pumpEventQueue();
        },
        verify: (_) {
          verify(() => cameraService.stopRecording()).called(1);
          expect(orphanFile.existsSync(), isFalse);
          orphanFile.parent.deleteSync(recursive: true);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'aborts a started recording when navigation locks during the '
        'wakelock-enable await — the clip manager timer is never armed and '
        "the just-started session's file is discarded",
        setUp: () {
          gatedWakelock = _GatedWakelockPlatform();
          wakelockPlusPlatformInstance = gatedWakelock;
          when(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          ).thenAnswer((_) async => true);
          orphanFile = File(
            '${Directory.systemTemp.createTempSync('rec_wakelock').path}'
            '/clip.mp4',
          )..writeAsStringSync('aborted recording');
          final aborted = _MockEditorVideo();
          when(aborted.safeFilePath).thenAnswer((_) async => orphanFile.path);
          when(
            () => cameraService.stopRecording(),
          ).thenAnswer((_) async => aborted);
        },
        tearDown: () {
          wakelockPlusPlatformInstance = _FakeWakelockPlatform();
          orphanFile.parent.deleteSync(recursive: true);
        },
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderRecordingStartRequested());
          await pumpEventQueue();
          // The native start has returned true; the handler is now parked on
          // the gated WakelockPlus.enable() await. The lock lands in that
          // window, before clipManager.startRecording() runs.
          bloc.add(const VideoRecorderRecordingLockedForNavigation());
          await pumpEventQueue();
          gatedWakelock.enableGate.complete();
          await pumpEventQueue();
        },
        verify: (bloc) {
          expect(bloc.state.recordingState, VideoRecorderState.idle);
          // The re-arm after the await never happened — without the post-await
          // re-check this would start a 60fps timer that nothing cancels.
          verifyNever(() => clipManager.startRecording());
          // The just-started native session was stopped and its file discarded.
          verify(() => cameraService.stopRecording()).called(1);
          expect(orphanFile.existsSync(), isFalse);
        },
      );
    });

    group('VideoRecorderResetRequested', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'restores the default state object',
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
              zoomLevel: 3,
              isStartingRecording: true,
            ),
          ),
        act: (bloc) => bloc.add(const VideoRecorderResetRequested()),
        expect: () => const [VideoRecorderBlocState()],
      );
    });

    group('VideoRecorderRecorderModeSet', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'capture → classic flips defaults and clears clips + editor',
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              timerDuration: TimerDuration.three,
              countdownValue: 2,
            ),
          ),
        act: (bloc) => bloc.add(
          const VideoRecorderRecorderModeSet(VideoRecorderMode.classic),
        ),
        expect: () => const [
          VideoRecorderBlocState(
            recorderMode: VideoRecorderMode.classic,
            aspectRatio: model.AspectRatio.square,
            showGridLines: true,
          ),
        ],
        verify: (_) {
          verify(
            () => prefs.setString(
              VideoRecorderMode.persistenceKey,
              VideoRecorderMode.classic.name,
            ),
          ).called(1);
          // `keepAutosavedDraft` defaults to false in the event; the
          // bloc forwards that default to both helpers.
          verify(
            () => clipManager.clearAll(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          ).called(1);
          verify(
            () => videoEditor.reset(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'transitions involving upload preserve clips and editor',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoRecorderRecorderModeSet(VideoRecorderMode.upload),
        ),
        verify: (_) {
          verifyNever(
            () => clipManager.clearAll(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          );
          verifyNever(
            () => videoEditor.reset(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          );
        },
      );
    });

    group('VideoRecorderInitializeRequested', () {
      setUp(() {
        when(
          () => cameraService.initialize(
            videoQuality: any(named: 'videoQuality'),
            initialLens: any(named: 'initialLens'),
            enableAutoLensSwitch: any(named: 'enableAutoLensSwitch'),
            preferUnprocessedAudio: any(named: 'preferUnprocessedAudio'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => cameraService.setRemoteRecordControlEnabled(
            enabled: any(named: 'enabled'),
          ),
        ).thenAnswer((_) async => true);
      });

      group('camera_startup trace', () {
        // Telemetry-only: a regression here mislabels a Firebase sample, not a
        // user-facing bug — a touch belt-and-suspenders, kept so the outcome
        // mapping can't silently rot.
        late _RecordingTraceMonitor monitor;

        setUp(() {
          monitor = _RecordingTraceMonitor();
        });

        VideoRecorderBloc buildTraced() => VideoRecorderBloc(
          readClipManager: () => clipManager,
          readVideoEditor: () => videoEditor,
          readVideoEditorState: VideoEditorProviderState.new,
          readSharedPreferences: () => prefs,
          cameraService: cameraService,
          performanceMonitor: monitor,
        );

        blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
          'tags outcome=success and stops the trace when the camera '
          'initializes',
          build: buildTraced,
          act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
          verify: (_) {
            expect(monitor.traces.single.attributes['outcome'], 'success');
            expect(monitor.traces.single.stopCount, 1);
          },
        );

        blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
          'tags outcome=failed when initialize completes but the camera '
          'never becomes ready',
          setUp: () =>
              when(() => cameraService.isInitialized).thenReturn(false),
          build: buildTraced,
          act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
          verify: (_) {
            expect(monitor.traces.single.attributes['outcome'], 'failed');
          },
        );

        blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
          'tags outcome=error when initialize throws',
          setUp: () => when(
            () => cameraService.initialize(
              videoQuality: any(named: 'videoQuality'),
              initialLens: any(named: 'initialLens'),
              enableAutoLensSwitch: any(named: 'enableAutoLensSwitch'),
              preferUnprocessedAudio: any(named: 'preferUnprocessedAudio'),
            ),
          ).thenThrow(Exception('camera boom')),
          build: buildTraced,
          act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
          verify: (_) {
            expect(monitor.traces.single.attributes['outcome'], 'error');
          },
          errors: () => [isA<Exception>()],
        );
      });

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'initializes the camera with auto lens switching enabled',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        verify: (_) {
          verify(
            () => cameraService.initialize(
              videoQuality: any(named: 'videoQuality'),
              initialLens: any(named: 'initialLens'),
              enableAutoLensSwitch: true,
              preferUnprocessedAudio: any(named: 'preferUnprocessedAudio'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'asks for unprocessed capture when Music mode is on',
        setUp: () {
          when(
            () => prefs.getBool(MusicModePreferenceService.prefsKey),
          ).thenReturn(true);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        verify: (_) {
          verify(
            () => cameraService.initialize(
              videoQuality: any(named: 'videoQuality'),
              initialLens: any(named: 'initialLens'),
              enableAutoLensSwitch: any(named: 'enableAutoLensSwitch'),
              preferUnprocessedAudio: true,
            ),
          ).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'releases the navigation recording lock even when re-init fails — a '
        'failed camera return must not leave the recorder permanently locked',
        setUp: () {
          when(() => cameraService.isInitialized).thenReturn(false);
          when(
            () => cameraService.initializationError,
          ).thenReturn(CameraInitializationError.failed);
        },
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(recordingLockedForNavigation: true),
          ),
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        verify: (bloc) {
          // Confirm we actually hit the init-failure return path…
          expect(bloc.state.initializationError, isNotNull);
          // …and the lock was still cleared up front.
          expect(bloc.state.recordingLockedForNavigation, isFalse);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does NOT restore persisted mode when opened from the editor '
        '(keeps editor state intact)',
        setUp: () {
          when(
            () => prefs.getString(VideoRecorderMode.persistenceKey),
          ).thenReturn(VideoRecorderMode.classic.name);
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoRecorderInitializeRequested(fromEditor: true)),
        verify: (_) {
          verifyNever(
            () => clipManager.clearAll(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          );
          verifyNever(
            () => videoEditor.reset(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'switches to stop-motion mode when opened from a stop-motion editor',
        setUp: () {
          when(() => clipManager.clips).thenReturn([
            DivineVideoClip(
              id: 'clip_sm_1',
              stopMotionFrames: const [
                StopMotionClipFrame(
                  path: '/f0.jpg',
                  duration: Duration(milliseconds: 42),
                ),
              ],
              duration: const Duration(milliseconds: 42),
              recordedAt: DateTime(2024),
              targetAspectRatio: model.AspectRatio.vertical,
              originalAspectRatio: 9 / 16,
            ),
          ]);
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoRecorderInitializeRequested(fromEditor: true)),
        verify: (bloc) {
          expect(bloc.state.recorderMode, VideoRecorderMode.stopMotion);
          // The mode's grid default applies even on this direct switch.
          expect(bloc.state.showGridLines, isTrue);
          // Setting the mode directly must not clear the composition.
          verifyNever(
            () => clipManager.clearAll(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'restores persisted mode when NOT opened from the editor',
        setUp: () {
          when(
            () => prefs.getString(VideoRecorderMode.persistenceKey),
          ).thenReturn(VideoRecorderMode.classic.name);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        verify: (_) {
          verify(
            () => clipManager.clearAll(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          ).called(1);
          verify(
            () => videoEditor.reset(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'restores the persisted stabilization mode the camera supports',
        setUp: () {
          when(
            () => prefs.getString('camera_last_used_stabilization'),
          ).thenReturn(DivineVideoStabilizationMode.cinematic.toNativeString());
          when(
            () => cameraService.availableVideoStabilizationModes,
          ).thenReturn(const [
            DivineVideoStabilizationMode.off,
            DivineVideoStabilizationMode.cinematic,
          ]);
          when(
            () => cameraService.setVideoStabilizationMode(any()),
          ).thenAnswer((_) async => true);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        verify: (_) {
          verify(
            () => cameraService.setVideoStabilizationMode(
              DivineVideoStabilizationMode.cinematic,
            ),
          ).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does not restore a stabilization mode the camera does not support',
        setUp: () {
          when(
            () => prefs.getString('camera_last_used_stabilization'),
          ).thenReturn(DivineVideoStabilizationMode.cinematic.toNativeString());
          // availableVideoStabilizationModes stays [off] from the outer setUp.
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        verify: (_) {
          verifyNever(() => cameraService.setVideoStabilizationMode(any()));
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does not restore when no stabilization mode is persisted',
        // prefs.getString returns null by default (see outer setUp).
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        verify: (_) {
          verifyNever(() => cameraService.setVideoStabilizationMode(any()));
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does not restore when the persisted mode is off',
        setUp: () {
          when(
            () => prefs.getString('camera_last_used_stabilization'),
          ).thenReturn(DivineVideoStabilizationMode.off.toNativeString());
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        verify: (_) {
          verifyNever(() => cameraService.setVideoStabilizationMode(any()));
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'leaves the mode at off when the camera refuses the restore',
        setUp: () {
          when(
            () => prefs.getString('camera_last_used_stabilization'),
          ).thenReturn(DivineVideoStabilizationMode.cinematic.toNativeString());
          when(
            () => cameraService.availableVideoStabilizationModes,
          ).thenReturn(const [
            DivineVideoStabilizationMode.off,
            DivineVideoStabilizationMode.cinematic,
          ]);
          when(
            () => cameraService.setVideoStabilizationMode(any()),
          ).thenAnswer((_) async => false);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        verify: (bloc) {
          verify(
            () => cameraService.setVideoStabilizationMode(
              DivineVideoStabilizationMode.cinematic,
            ),
          ).called(1);
          expect(
            bloc.state.videoStabilizationMode,
            DivineVideoStabilizationMode.off,
          );
        },
      );
    });

    group('close()', () {
      test('disposes camera service exactly once', () async {
        final bloc = buildBloc();
        await bloc.close();
        verify(() => cameraService.dispose()).called(1);
      });

      test(
        'disables wakelock without letting a failure abort cleanup',
        () async {
          final platform = _ThrowingWakelockDisablePlatform();
          wakelockPlusPlatformInstance = platform;
          addTearDown(() {
            wakelockPlusPlatformInstance = _FakeWakelockPlatform();
          });
          final bloc = buildBloc();

          await expectLater(bloc.close(), completes);

          expect(platform.disableCalls, 1);
          verify(() => cameraService.dispose()).called(1);
        },
      );
    });

    group('stop-motion', () {
      // Ingest and eager-persist filter unreadable stills via existsSync, so
      // the frame paths used here must be real, non-empty files.
      late Directory frameDir;
      late String framePath;
      late String frameAPath;
      late String frameBPath;
      // Releases a gated capturePhoto() in the tests that force a still to
      // land after a session-claiming event.
      late Completer<void> captureGate;

      DivineVideoClip fakeClip() => DivineVideoClip(
        id: 'clip_sm_1',
        video: EditorVideo.file('/out.mp4'),
        duration: const Duration(milliseconds: 250),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      void stubClipIngest() {
        when(
          () => clipManager.addStopMotionClip(
            id: any(named: 'id'),
            frames: any(named: 'frames'),
            originalAspectRatio: any(named: 'originalAspectRatio'),
            targetAspectRatio: any(named: 'targetAspectRatio'),
            duration: any(named: 'duration'),
            thumbnailPath: any(named: 'thumbnailPath'),
            lensMetadata: any(named: 'lensMetadata'),
          ),
        ).thenReturn(fakeClip());
        when(() => clipManager.clips).thenReturn([fakeClip()]);
        when(
          () => clipManager.saveClipToLibrary(any()),
        ).thenAnswer((_) async => true);
      }

      setUp(() {
        frameDir = Directory.systemTemp.createTempSync('sm_frames');
        framePath = '${frameDir.path}/frame.jpg';
        frameAPath = '${frameDir.path}/a.jpg';
        frameBPath = '${frameDir.path}/b.jpg';
        for (final path in [framePath, frameAPath, frameBPath]) {
          File(path).writeAsBytesSync(const [0]);
        }

        when(
          () => cameraService.capturePhoto(),
        ).thenAnswer((_) async => PhotoCaptureResult(filePath: framePath));
        // Capture and undo eagerly mirror the session into the library.
        when(
          () => clipManager.saveStopMotionSessionToLibrary(
            id: any(named: 'id'),
            frames: any(named: 'frames'),
            originalAspectRatio: any(named: 'originalAspectRatio'),
            targetAspectRatio: any(named: 'targetAspectRatio'),
            duration: any(named: 'duration'),
            thumbnailPath: any(named: 'thumbnailPath'),
            lensMetadata: any(named: 'lensMetadata'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => clipManager.removeStopMotionSessionFromLibrary(any()),
        ).thenAnswer((_) async {});
      });

      tearDown(() {
        if (frameDir.existsSync()) frameDir.deleteSync(recursive: true);
      });

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'a camera re-sync keeps the captured frames (session not split)',
        setUp: () {
          when(
            () => cameraService.switchCamera(),
          ).thenAnswer((_) async => true);
        },
        build: buildBloc,
        seed: () => VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
          stopMotionFrames: [frameAPath, frameBPath],
        ),
        act: (bloc) => bloc.add(const VideoRecorderCameraSwitched()),
        verify: (bloc) =>
            expect(bloc.state.stopMotionFrames, [frameAPath, frameBPath]),
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'a captured frame is appended without rendering a clip',
        build: buildBloc,
        seed: () => const VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
        ),
        act: (bloc) => bloc.add(const VideoRecorderStopMotionFrameCaptured()),
        wait: const Duration(milliseconds: 20),
        verify: (bloc) {
          verify(() => cameraService.capturePhoto()).called(1);
          expect(bloc.state.stopMotionFrames, [framePath]);
          verifyNever(
            () => clipManager.addClip(
              video: any(named: 'video'),
              originalAspectRatio: any(named: 'originalAspectRatio'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
              limitClipDuration: any(named: 'limitClipDuration'),
              duration: any(named: 'duration'),
              thumbnailPath: any(named: 'thumbnailPath'),
              lensMetadata: any(named: 'lensMetadata'),
            ),
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'a frame captured while ready (assemble done, navigation pending) '
        'skips the wasted native capture',
        build: buildBloc,
        seed: () => const VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
          stopMotionStatus: StopMotionStatus.ready,
        ),
        act: (bloc) => bloc.add(const VideoRecorderStopMotionFrameCaptured()),
        wait: const Duration(milliseconds: 20),
        verify: (bloc) {
          // The after-await guard deletes such a still anyway; the top guard
          // short-circuits the native capture in the ~1-frame ready window.
          verifyNever(() => cameraService.capturePhoto());
          expect(bloc.state.stopMotionStatus, StopMotionStatus.ready);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'clears a leftover ready on re-init so the shutter works after '
        'backing out of the editor',
        setUp: () {
          when(
            () => cameraService.initialize(
              videoQuality: any(named: 'videoQuality'),
              initialLens: any(named: 'initialLens'),
              enableAutoLensSwitch: any(named: 'enableAutoLensSwitch'),
              preferUnprocessedAudio: any(named: 'preferUnprocessedAudio'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => cameraService.setRemoteRecordControlEnabled(
              enabled: any(named: 'enabled'),
            ),
          ).thenAnswer((_) async => true);
          // Same mode persisted, so init's mode branch is skipped and nothing
          // else would move a leftover `ready` back to `idle`.
          when(
            () => prefs.getString(VideoRecorderMode.persistenceKey),
          ).thenReturn(VideoRecorderMode.stopMotion.name);
        },
        build: buildBloc,
        seed: () => const VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
          stopMotionStatus: StopMotionStatus.ready,
        ),
        act: (bloc) async {
          bloc.add(const VideoRecorderInitializeRequested());
          await Future<void>.delayed(const Duration(milliseconds: 10));
          bloc.add(const VideoRecorderStopMotionFrameCaptured());
        },
        wait: const Duration(milliseconds: 40),
        verify: (bloc) {
          // Without the reset the top guard would swallow this tap (leftover
          // `ready`): no capture, empty frames. With it, a fresh session
          // starts.
          verify(() => cameraService.capturePhoto()).called(1);
          expect(bloc.state.stopMotionFrames, [framePath]);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'a frame that lands after an assemble started is dropped, not '
        're-persisted as a new session',
        setUp: () {
          stubClipIngest();
          // "Next" stays tappable across the slow native capture, so the
          // assemble claims the session while this still is in flight. The
          // gate holds the capture open until the act has run the assemble,
          // so the interleave is forced rather than timed.
          captureGate = Completer<void>();
          when(() => cameraService.capturePhoto()).thenAnswer((_) async {
            await captureGate.future;
            return PhotoCaptureResult(filePath: framePath);
          });
        },
        build: buildBloc,
        seed: () => VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
          stopMotionFrames: [frameAPath],
        ),
        act: (bloc) async {
          bloc.add(const VideoRecorderStopMotionFrameCaptured());
          // Let the handler reach the gated capturePhoto().
          await pumpEventQueue();
          // Tap "Next" while the capture is still in flight.
          bloc.add(const VideoRecorderStopMotionAssembleRequested());
          await pumpEventQueue();
          // Only now does the still land — strictly after the assemble.
          captureGate.complete();
          await pumpEventQueue();
        },
        verify: (bloc) {
          // A late still must not reopen the session the assemble just closed,
          // nor clobber the terminal status back to `idle` — that reopens the
          // mode wheel mid-save and re-writes a phantom one-frame library row.
          expect(bloc.state.stopMotionFrames, isEmpty);
          expect(bloc.state.stopMotionStatus, StopMotionStatus.ready);
          verifyNever(
            () => clipManager.saveStopMotionSessionToLibrary(
              id: any(named: 'id'),
              frames: any(named: 'frames'),
              originalAspectRatio: any(named: 'originalAspectRatio'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
              duration: any(named: 'duration'),
              thumbnailPath: any(named: 'thumbnailPath'),
              lensMetadata: any(named: 'lensMetadata'),
            ),
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'a frame that lands after a mode switch is dropped, not re-persisted '
        'on the new mode',
        setUp: () {
          stubClipIngest();
          // The mode wheel stays live during an idle capture, so a swipe can
          // land the switch while this still is in flight. The gate holds the
          // capture open until the act has run the switch, so the interleave
          // is forced rather than timed.
          captureGate = Completer<void>();
          when(() => cameraService.capturePhoto()).thenAnswer((_) async {
            await captureGate.future;
            return PhotoCaptureResult(filePath: framePath);
          });
        },
        build: buildBloc,
        seed: () => VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
          stopMotionFrames: [frameAPath],
        ),
        act: (bloc) async {
          bloc.add(const VideoRecorderStopMotionFrameCaptured());
          // Let the handler reach the gated capturePhoto().
          await pumpEventQueue();
          // Swipe the wheel off stop-motion while the capture is in flight.
          bloc.add(
            const VideoRecorderRecorderModeSet(VideoRecorderMode.upload),
          );
          await pumpEventQueue();
          // Only now does the still land — strictly after the switch.
          captureGate.complete();
          await pumpEventQueue();
        },
        verify: (bloc) {
          // The switch discarded the session and moved the recorder off
          // stop-motion; appending the resumed still would write a phantom
          // one-frame library row on the new mode, so it is dropped with its
          // file.
          expect(bloc.state.recorderMode, VideoRecorderMode.upload);
          expect(bloc.state.stopMotionFrames, isEmpty);
          expect(File(framePath).existsSync(), isFalse);
          verifyNever(
            () => clipManager.saveStopMotionSessionToLibrary(
              id: any(named: 'id'),
              frames: any(named: 'frames'),
              originalAspectRatio: any(named: 'originalAspectRatio'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
              duration: any(named: 'duration'),
              thumbnailPath: any(named: 'thumbnailPath'),
              lensMetadata: any(named: 'lensMetadata'),
            ),
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'the shutter tick fires before the captured frame lands',
        setUp: () {
          // Simulate the slow native capture: the blink must not wait for it.
          when(() => cameraService.capturePhoto()).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return PhotoCaptureResult(filePath: framePath);
          });
        },
        build: buildBloc,
        seed: () => const VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
        ),
        act: (bloc) => bloc.add(const VideoRecorderStopMotionFrameCaptured()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<VideoRecorderBlocState>()
              .having(
                (s) => s.stopMotionShutterTick,
                'stopMotionShutterTick',
                1,
              )
              .having((s) => s.stopMotionFrames, 'stopMotionFrames', isEmpty),
          isA<VideoRecorderBlocState>().having(
            (s) => s.stopMotionFrames,
            'stopMotionFrames',
            hasLength(1),
          ),
        ],
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'a captured frame is persisted to the library immediately',
        build: buildBloc,
        seed: () => const VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
        ),
        act: (bloc) => bloc.add(const VideoRecorderStopMotionFrameCaptured()),
        wait: const Duration(milliseconds: 20),
        verify: (bloc) {
          final captured = verify(
            () => clipManager.saveStopMotionSessionToLibrary(
              id: captureAny(named: 'id'),
              frames: captureAny(named: 'frames'),
              originalAspectRatio: any(named: 'originalAspectRatio'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
              duration: any(named: 'duration'),
              thumbnailPath: any(named: 'thumbnailPath'),
              lensMetadata: any(named: 'lensMetadata'),
            ),
          )..called(1);
          // Session id is derived from the first frame's filename so it stays
          // stable as the session grows.
          expect(captured.captured[0], 'clip_sm_frame');
          final frames = captured.captured[1] as List<StopMotionClipFrame>;
          expect(frames.map((f) => f.path), [framePath]);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'the shutter toggle captures a frame in stop-motion mode',
        build: buildBloc,
        seed: () => const VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
        ),
        act: (bloc) => bloc.add(const VideoRecorderRecordingToggleRequested()),
        wait: const Duration(milliseconds: 20),
        verify: (bloc) {
          verify(() => cameraService.capturePhoto()).called(1);
          expect(bloc.state.stopMotionFrames, hasLength(1));
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'no frame is appended when the camera returns no photo',
        setUp: () {
          when(
            () => cameraService.capturePhoto(),
          ).thenAnswer((_) async => null);
        },
        build: buildBloc,
        seed: () => const VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
        ),
        act: (bloc) => bloc.add(const VideoRecorderStopMotionFrameCaptured()),
        verify: (bloc) => expect(bloc.state.stopMotionFrames, isEmpty),
      );

      test(
        'waits for unreadable frame deletion before accepting another capture',
        () {
          fakeAsync((async) {
            const unreadablePath = '/unreadable.jpg';
            final unreadableFile = _MockFile();
            final deleteGate = Completer<File>();
            when(unreadableFile.existsSync).thenReturn(true);
            when(unreadableFile.lengthSync).thenReturn(0);
            when(unreadableFile.delete).thenAnswer((_) => deleteGate.future);
            when(() => cameraService.capturePhoto()).thenAnswer(
              (_) async => const PhotoCaptureResult(filePath: unreadablePath),
            );

            IOOverrides.runZoned(() {
              final bloc = buildBloc();
              bloc.emit(
                const VideoRecorderBlocState(
                  recorderMode: VideoRecorderMode.stopMotion,
                ),
              );

              bloc.add(const VideoRecorderStopMotionFrameCaptured());
              async.flushMicrotasks();
              verify(() => cameraService.capturePhoto()).called(1);

              // The droppable handler must still own the invalid capture
              // until its file is deleted, so a second shutter event cannot
              // start another native capture in the cleanup window.
              bloc.add(const VideoRecorderStopMotionFrameCaptured());
              async.flushMicrotasks();
              verifyNever(() => cameraService.capturePhoto());

              deleteGate.complete(unreadableFile);
              async.flushMicrotasks();
              unawaited(bloc.close());
              async.flushMicrotasks();

              verifyNever(
                () => clipManager.saveStopMotionSessionToLibrary(
                  id: any(named: 'id'),
                  frames: any(named: 'frames'),
                  originalAspectRatio: any(named: 'originalAspectRatio'),
                  targetAspectRatio: any(named: 'targetAspectRatio'),
                  duration: any(named: 'duration'),
                  thumbnailPath: any(named: 'thumbnailPath'),
                  lensMetadata: any(named: 'lensMetadata'),
                ),
              );
            }, createFile: (_) => unreadableFile);
          });
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'undo removes the last captured frame and re-syncs the library',
        build: buildBloc,
        seed: () => VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
          stopMotionFrames: [frameAPath, frameBPath],
        ),
        act: (bloc) => bloc.add(const VideoRecorderStopMotionFrameUndone()),
        wait: const Duration(milliseconds: 20),
        verify: (bloc) {
          expect(bloc.state.stopMotionFrames, [frameAPath]);
          final captured = verify(
            () => clipManager.saveStopMotionSessionToLibrary(
              id: captureAny(named: 'id'),
              frames: captureAny(named: 'frames'),
              originalAspectRatio: any(named: 'originalAspectRatio'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
              duration: any(named: 'duration'),
              thumbnailPath: any(named: 'thumbnailPath'),
              lensMetadata: any(named: 'lensMetadata'),
            ),
          )..called(1);
          // Same session id — the first frame is unchanged.
          expect(captured.captured[0], 'clip_sm_a');
          final frames = captured.captured[1] as List<StopMotionClipFrame>;
          expect(frames.map((f) => f.path), [frameAPath]);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'undoing the final frame drops the session library row',
        build: buildBloc,
        seed: () => VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
          stopMotionFrames: [frameAPath],
        ),
        act: (bloc) => bloc.add(const VideoRecorderStopMotionFrameUndone()),
        wait: const Duration(milliseconds: 20),
        verify: (bloc) {
          expect(bloc.state.stopMotionFrames, isEmpty);
          verify(
            () => clipManager.removeStopMotionSessionFromLibrary('clip_sm_a'),
          ).called(1);
          verifyNever(
            () => clipManager.saveStopMotionSessionToLibrary(
              id: any(named: 'id'),
              frames: any(named: 'frames'),
              originalAspectRatio: any(named: 'originalAspectRatio'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
              duration: any(named: 'duration'),
              thumbnailPath: any(named: 'thumbnailPath'),
              lensMetadata: any(named: 'lensMetadata'),
            ),
          );
        },
      );

      test('undo removal waits for the in-flight eager save', () async {
        final calls = <String>[];
        when(
          () => clipManager.saveStopMotionSessionToLibrary(
            id: any(named: 'id'),
            frames: any(named: 'frames'),
            originalAspectRatio: any(named: 'originalAspectRatio'),
            targetAspectRatio: any(named: 'targetAspectRatio'),
            duration: any(named: 'duration'),
            thumbnailPath: any(named: 'thumbnailPath'),
            lensMetadata: any(named: 'lensMetadata'),
          ),
        ).thenAnswer((_) async {
          calls.add('save-start');
          await Future<void>.delayed(const Duration(milliseconds: 20));
          calls.add('save-end');
          return true;
        });
        when(
          () => clipManager.removeStopMotionSessionFromLibrary(any()),
        ).thenAnswer((_) async {
          calls.add('remove');
        });

        final bloc = buildBloc();
        final stopMotionMode = bloc.stream.firstWhere(
          (state) => state.recorderMode == VideoRecorderMode.stopMotion,
        );
        bloc.add(
          const VideoRecorderRecorderModeSet(VideoRecorderMode.stopMotion),
        );
        await stopMotionMode;

        final captured = bloc.stream.firstWhere(
          (state) => state.stopMotionFrames.isNotEmpty,
        );
        bloc.add(const VideoRecorderStopMotionFrameCaptured());
        await captured;
        await Future<void>.delayed(Duration.zero);
        expect(calls, ['save-start']);

        bloc.add(const VideoRecorderStopMotionFrameUndone());
        await Future<void>.delayed(Duration.zero);

        expect(calls, ['save-start']);

        await Future<void>.delayed(const Duration(milliseconds: 40));
        await bloc.close();

        expect(calls, ['save-start', 'save-end', 'remove']);
      });

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'switching modes discards the session and drops its library row',
        build: buildBloc,
        seed: () => VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
          stopMotionFrames: [frameAPath, frameBPath],
        ),
        act: (bloc) => bloc.add(
          const VideoRecorderRecorderModeSet(VideoRecorderMode.classic),
        ),
        wait: const Duration(milliseconds: 20),
        verify: (bloc) {
          expect(bloc.state.stopMotionFrames, isEmpty);
          // Files deleted AND the eager-saved row removed — no orphan.
          verify(
            () => clipManager.removeStopMotionSessionFromLibrary('clip_sm_a'),
          ).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'reset discards the session and drops its library row',
        build: buildBloc,
        seed: () => VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
          stopMotionFrames: [frameAPath, frameBPath],
        ),
        act: (bloc) => bloc.add(const VideoRecorderResetRequested()),
        wait: const Duration(milliseconds: 20),
        verify: (bloc) {
          expect(bloc.state.stopMotionFrames, isEmpty);
          verify(
            () => clipManager.removeStopMotionSessionFromLibrary('clip_sm_a'),
          ).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'ingest saves the captured frames as a clip and signals ready',
        setUp: stubClipIngest,
        build: buildBloc,
        seed: () => VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
          stopMotionFrames: [frameAPath, frameBPath],
        ),
        act: (bloc) =>
            bloc.add(const VideoRecorderStopMotionAssembleRequested()),
        verify: (bloc) {
          final captured = verify(
            () => clipManager.addStopMotionClip(
              id: captureAny(named: 'id'),
              frames: captureAny(named: 'frames'),
              originalAspectRatio: any(named: 'originalAspectRatio'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
              duration: any(named: 'duration'),
              thumbnailPath: any(named: 'thumbnailPath'),
              lensMetadata: any(named: 'lensMetadata'),
            ),
          )..called(1);
          // Captured values follow the method's parameter declaration order:
          // frames is declared before id.
          final frames = captured.captured[0] as List<StopMotionClipFrame>;
          expect(frames.map((f) => f.path), [frameAPath, frameBPath]);
          // Assemble reuses the capture session's library id so the row
          // written during capture is updated, not duplicated.
          expect(captured.captured[1], 'clip_sm_a');
          verify(() => clipManager.saveClipToLibrary(any())).called(1);
          expect(bloc.state.stopMotionStatus, StopMotionStatus.ready);
          expect(bloc.state.stopMotionFrames, isEmpty);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'ingest stretches a session too short to fill the minimum duration',
        setUp: stubClipIngest,
        build: buildBloc,
        seed: () => VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
          stopMotionFrames: [frameAPath],
        ),
        act: (bloc) =>
            bloc.add(const VideoRecorderStopMotionAssembleRequested()),
        verify: (bloc) {
          final captured = verify(
            () => clipManager.addStopMotionClip(
              id: any(named: 'id'),
              frames: captureAny(named: 'frames'),
              originalAspectRatio: any(named: 'originalAspectRatio'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
              duration: captureAny(named: 'duration'),
              thumbnailPath: any(named: 'thumbnailPath'),
              lensMetadata: any(named: 'lensMetadata'),
            ),
          )..called(1);
          // Captured values follow the method's parameter declaration order:
          // frames is declared before duration.
          final frames = captured.captured[0] as List<StopMotionClipFrame>;
          expect(
            frames.single.duration,
            StopMotionFrameOps.minimumInitialDuration,
          );
          expect(
            captured.captured[1],
            StopMotionFrameOps.minimumInitialDuration,
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'emits failure when ingest throws',
        setUp: () {
          when(
            () => clipManager.addStopMotionClip(
              id: any(named: 'id'),
              frames: any(named: 'frames'),
              originalAspectRatio: any(named: 'originalAspectRatio'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
              duration: any(named: 'duration'),
              thumbnailPath: any(named: 'thumbnailPath'),
              lensMetadata: any(named: 'lensMetadata'),
            ),
          ).thenThrow(Exception('ingest failed'));
        },
        build: buildBloc,
        seed: () => VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
          stopMotionFrames: [frameAPath],
        ),
        act: (bloc) =>
            bloc.add(const VideoRecorderStopMotionAssembleRequested()),
        errors: () => [isA<Exception>()],
        verify: (bloc) {
          expect(bloc.state.stopMotionStatus, StopMotionStatus.failure);
          verifyNever(() => clipManager.saveClipToLibrary(any()));
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'retrying a failing assemble re-emits failure',
        setUp: () {
          when(
            () => clipManager.addStopMotionClip(
              id: any(named: 'id'),
              frames: any(named: 'frames'),
              originalAspectRatio: any(named: 'originalAspectRatio'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
              duration: any(named: 'duration'),
              thumbnailPath: any(named: 'thumbnailPath'),
              lensMetadata: any(named: 'lensMetadata'),
            ),
          ).thenThrow(Exception('ingest failed'));
        },
        build: buildBloc,
        seed: () => VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.stopMotion,
          stopMotionFrames: [frameAPath],
        ),
        act: (bloc) async {
          bloc.add(const VideoRecorderStopMotionAssembleRequested());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoRecorderStopMotionAssembleRequested());
        },
        errors: () => [isA<Exception>(), isA<Exception>()],
        // The snackbar fires on the status *transition*, and `emit` drops a
        // state equal to the current one — so the transient `assembling` in
        // between is what lets a second identical failure reach the UI.
        expect: () => [
          isA<VideoRecorderBlocState>().having(
            (s) => s.stopMotionStatus,
            'status',
            StopMotionStatus.assembling,
          ),
          isA<VideoRecorderBlocState>().having(
            (s) => s.stopMotionStatus,
            'status',
            StopMotionStatus.failure,
          ),
          isA<VideoRecorderBlocState>().having(
            (s) => s.stopMotionStatus,
            'status',
            StopMotionStatus.assembling,
          ),
          isA<VideoRecorderBlocState>().having(
            (s) => s.stopMotionStatus,
            'status',
            StopMotionStatus.failure,
          ),
        ],
      );
    });
  });
}
