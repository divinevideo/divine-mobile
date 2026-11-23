// ABOUTME: Verifies the recorder's performance traces: camera startup phases,
// ABOUTME: camera switches, per-take post-processing and stop-motion assembly.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_camera/divine_camera.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import '../../helpers/recording_performance_monitor.dart';
import '../../helpers/test_helpers.dart' show TestHelpers;
import '../../mocks/mock_path_provider_platform.dart';

class _MockCameraService extends Mock implements CameraService {}

class _MockClipManager extends Mock implements ClipManagerNotifier {
  @override
  int get sessionGeneration => 0;

  @override
  bool isSessionCurrent(int expected) => expected == 0;
}

class _MockVideoEditor extends Mock implements VideoEditorNotifier {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _MockEditorVideo extends Mock implements EditorVideo {}

class _MockProVideoEditor extends Mock
    with MockPlatformInterfaceMixin
    implements ProVideoEditor {}

/// Stands in for the wakelock the recorder releases when a take stops.
class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

void main() {
  late _MockCameraService cameraService;
  late _MockClipManager clipManager;
  late _MockVideoEditor videoEditor;
  late _MockSharedPreferences prefs;
  late RecordingPerformanceMonitor monitor;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(DivineCameraLens.back);
    registerFallbackValue(DivineVideoStabilizationMode.off);
    registerFallbackValue(DivineVideoQuality.fhd);
    registerFallbackValue(AppLifecycleState.resumed);
    registerFallbackValue(EditorVideo.file('/fallback.mp4'));
    registerFallbackValue(model.AspectRatio.vertical);
    registerFallbackValue(<StopMotionClipFrame>[]);
    registerFallbackValue(Duration.zero);
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
  });

  setUp(() {
    cameraService = _MockCameraService();
    clipManager = _MockClipManager();
    videoEditor = _MockVideoEditor();
    prefs = _MockSharedPreferences();
    monitor = RecordingPerformanceMonitor();
  });

  /// What every handler reads from the camera, the clip manager and the
  /// preferences. Called by each group's own `setUp`.
  void stubRecorder() {
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
    when(() => cameraService.setOnRemoteRecordTrigger(any())).thenReturn(null);
    when(
      () => cameraService.setRemoteRecordControlEnabled(
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => true);

    when(() => clipManager.clips).thenReturn(const []);
    when(
      () => clipManager.remainingDuration,
    ).thenReturn(const Duration(seconds: 6));
    when(() => clipManager.totalDuration).thenReturn(Duration.zero);

    when(() => videoEditor.state).thenReturn(VideoEditorProviderState());

    when(() => prefs.getString(any())).thenReturn(null);
    when(() => prefs.setString(any(), any())).thenAnswer((_) async => true);
    when(() => prefs.getBool(any())).thenReturn(null);
  }

  void stubCameraInitialize(Future<void> Function() answer) {
    when(
      () => cameraService.initialize(
        videoQuality: any(named: 'videoQuality'),
        initialLens: any(named: 'initialLens'),
        enableAutoLensSwitch: any(named: 'enableAutoLensSwitch'),
        preferUnprocessedAudio: any(named: 'preferUnprocessedAudio'),
        videoStabilizationMode: any(named: 'videoStabilizationMode'),
        mirrorFrontCameraOutput: any(named: 'mirrorFrontCameraOutput'),
      ),
    ).thenAnswer((_) => answer());
  }

  VideoRecorderBloc buildBloc() => VideoRecorderBloc(
    readClipManager: () => clipManager,
    readVideoEditor: () => videoEditor,
    readVideoEditorState: VideoEditorProviderState.new,
    readSharedPreferences: () => prefs,
    cameraService: cameraService,
    performanceMonitor: monitor,
  );

  List<RecordedPerformanceTrace> tracesNamed(String name) =>
      monitor.traces.where((trace) => trace.name == name).toList();

  group('camera_startup trace', () {
    setUp(stubRecorder);

    test('spans the mode the recorder applies once the camera is open', () {
      fakeAsync((async) {
        final opened = Completer<void>();
        final stabilized = Completer<bool>();
        stubCameraInitialize(() => opened.future);
        // Capture runs the saved stabilization, which the camera opened
        // without: applying it is the mode step this trace now covers.
        when(
          () => cameraService.availableVideoStabilizationModes,
        ).thenReturn(const [
          DivineVideoStabilizationMode.off,
          DivineVideoStabilizationMode.standard,
        ]);
        when(
          () => cameraService.setVideoStabilizationMode(any()),
        ).thenAnswer((_) => stabilized.future);
        final bloc = buildBloc()..add(const VideoRecorderInitializeRequested());

        async.elapse(const Duration(milliseconds: 120));
        opened.complete();
        async.flushMicrotasks();

        final trace = tracesNamed('camera_startup').single;
        expect(trace.stops, 0);

        async.elapse(const Duration(milliseconds: 80));
        stabilized.complete(true);
        async.flushMicrotasks();

        expect(trace.stops, 1);
        expect(trace.attributes, {
          'lens': 'back',
          'quality': DivineVideoQuality.fhd.value,
          'outcome': 'success',
          'dual_camera': 'off',
        });
        expect(trace.metrics, {
          'total_ms': 200,
          'init_ms': 120,
          'mode_apply_ms': 80,
        });

        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });

    test('ends as soon as the camera fails to open', () {
      fakeAsync((async) {
        final opened = Completer<void>();
        stubCameraInitialize(() => opened.future);
        when(() => cameraService.isInitialized).thenReturn(false);
        final bloc = buildBloc()..add(const VideoRecorderInitializeRequested());

        async.elapse(const Duration(milliseconds: 90));
        opened.complete();
        async.flushMicrotasks();

        final trace = tracesNamed('camera_startup').single;
        expect(trace.stops, 1);
        expect(trace.attributes, {
          'lens': 'back',
          'quality': DivineVideoQuality.fhd.value,
          'outcome': 'failed',
        });
        expect(trace.metrics, {'total_ms': 90, 'init_ms': 90});

        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });
  });
}
