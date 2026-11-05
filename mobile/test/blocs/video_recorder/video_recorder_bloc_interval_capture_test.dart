// ABOUTME: Tests for stop-motion's hands-free interval capture (#6626)
// ABOUTME: Countdown, a still per interval, and every way the loop ends

import 'dart:async';
import 'dart:io';

import 'package:divine_camera/divine_camera.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_service/sound_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _MockCameraService extends Mock implements CameraService {}

class _MockClipManager extends Mock implements ClipManagerNotifier {}

class _MockVideoEditor extends Mock implements VideoEditorNotifier {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _MockCountdownSoundService extends Mock
    implements CountdownSoundService {}

/// Remembers whether the screen is held awake.
class _RecordingWakelockPlatform extends WakelockPlusPlatformInterface {
  bool isEnabled = false;

  @override
  Future<void> toggle({required bool enable}) async => isEnabled = enable;

  @override
  Future<bool> get enabled async => isEnabled;
}

void main() {
  group(VideoRecorderBloc, () {
    late _MockCameraService cameraService;
    late _MockClipManager clipManager;
    late _MockCountdownSoundService sounds;
    late _RecordingWakelockPlatform wakelock;
    late WakelockPlusPlatformInterface previousWakelock;
    late Directory frameDir;
    var framesWritten = 0;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      registerFallbackValue(<StopMotionClipFrame>[]);
      registerFallbackValue(model.AspectRatio.vertical);
      registerFallbackValue(Duration.zero);
      registerFallbackValue(AppLifecycleState.paused);
    });

    setUp(() {
      cameraService = _MockCameraService();
      clipManager = _MockClipManager();
      sounds = _MockCountdownSoundService();
      previousWakelock = wakelockPlusPlatformInstance;
      wakelock = _RecordingWakelockPlatform();
      wakelockPlusPlatformInstance = wakelock;
      frameDir = Directory.systemTemp.createTempSync('interval_frames');
      framesWritten = 0;
    });

    tearDown(() {
      wakelockPlusPlatformInstance = previousWakelock;
      if (frameDir.existsSync()) frameDir.deleteSync(recursive: true);
    });

    /// A still the capture validation accepts: a real, non-empty file.
    PhotoCaptureResult writeFrame() {
      final path = '${frameDir.path}/frame_${framesWritten++}.jpg';
      File(path).writeAsBytesSync(const [0]);
      return PhotoCaptureResult(filePath: path);
    }

    void stubStopMotionRecorder() {
      when(() => cameraService.isInitialized).thenReturn(true);
      when(() => cameraService.isSwitchingCamera).thenReturn(false);
      when(() => cameraService.currentLensMetadata).thenReturn(null);
      when(
        () => cameraService.capturePhoto(),
      ).thenAnswer((_) async => writeFrame());
      when(() => cameraService.dispose()).thenAnswer((_) async {});
      when(() => clipManager.clips).thenReturn(const []);
      when(() => clipManager.totalDuration).thenReturn(Duration.zero);
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
      when(sounds.preload).thenAnswer((_) async {});
      when(sounds.playShortBeep).thenAnswer((_) async {});
      when(sounds.dispose).thenAnswer((_) async {});
    }

    VideoRecorderBloc buildBloc({
      TimerDuration timer = TimerDuration.two,
      CameraServiceFactory? cameraServiceFactory,
    }) =>
        VideoRecorderBloc(
          readClipManager: () => clipManager,
          readVideoEditor: _MockVideoEditor.new,
          readVideoEditorState: VideoEditorProviderState.new,
          readSharedPreferences: _MockSharedPreferences.new,
          cameraService: cameraServiceFactory == null ? cameraService : null,
          cameraServiceFactory: cameraServiceFactory ?? CameraService.create,
          countdownSoundServiceFactory: () => sounds,
        )..emit(
          VideoRecorderBlocState(
            recorderMode: VideoRecorderMode.stopMotion,
            timerDuration: timer,
            isCameraInitialized: true,
            canRecord: true,
          ),
        );

    void tapShutter(VideoRecorderBloc bloc, FakeAsync async) {
      bloc.add(const VideoRecorderRecordingToggleRequested());
      async.flushMicrotasks();
    }

    void elapse(FakeAsync async, Duration duration) {
      async
        ..elapse(duration)
        ..flushMicrotasks();
    }

    void closeBloc(VideoRecorderBloc bloc, FakeAsync async) {
      unawaited(bloc.close());
      async.flushMicrotasks();
    }

    group('shutter with a timer set', () {
      setUp(stubStopMotionRecorder);

      test('waits out a whole countdown before the first still', () {
        fakeAsync((async) {
          final bloc = buildBloc();
          tapShutter(bloc, async);

          expect(bloc.state.isIntervalCaptureRunning, isTrue);
          expect(bloc.state.countdownValue, 2);

          elapse(async, const Duration(seconds: 1));
          expect(bloc.state.countdownValue, 1);
          verifyNever(() => cameraService.capturePhoto());

          closeBloc(bloc, async);
        });
      });

      test('takes a still every interval and beeps for each one', () {
        fakeAsync((async) {
          final bloc = buildBloc();
          tapShutter(bloc, async);

          elapse(async, const Duration(seconds: 2));
          expect(bloc.state.stopMotionFrames, hasLength(1));
          expect(
            bloc.state.countdownValue,
            2,
            reason: 'counts down to the next still once this one landed',
          );

          elapse(async, const Duration(seconds: 2));
          expect(bloc.state.stopMotionFrames, hasLength(2));
          verify(() => cameraService.capturePhoto()).called(2);
          verify(sounds.playShortBeep).called(2);

          closeBloc(bloc, async);
        });
      });

      test('holds the next countdown until the still in flight lands', () {
        fakeAsync((async) {
          final photo = Completer<PhotoCaptureResult?>();
          when(
            () => cameraService.capturePhoto(),
          ).thenAnswer((_) => photo.future);
          final bloc = buildBloc();
          tapShutter(bloc, async);

          elapse(async, const Duration(seconds: 7));
          verify(() => cameraService.capturePhoto()).called(1);
          expect(bloc.state.countdownValue, 0);

          photo.complete(writeFrame());
          async.flushMicrotasks();
          expect(bloc.state.stopMotionFrames, hasLength(1));
          expect(bloc.state.countdownValue, 2);

          closeBloc(bloc, async);
        });
      });

      test('keeps the screen awake while it runs', () {
        fakeAsync((async) {
          final bloc = buildBloc();
          tapShutter(bloc, async);
          expect(wakelock.isEnabled, isTrue);

          tapShutter(bloc, async);
          expect(wakelock.isEnabled, isFalse);

          closeBloc(bloc, async);
        });
      });

      test('keeps running through a native camera re-sync', () {
        fakeAsync((async) {
          late void Function({bool? forceCameraRebuild}) reportCameraUpdate;
          when(() => cameraService.minZoomLevel).thenReturn(1);
          when(() => cameraService.maxZoomLevel).thenReturn(5);
          when(() => cameraService.cameraAspectRatio).thenReturn(9 / 16);
          when(() => cameraService.canRecord).thenReturn(true);
          when(() => cameraService.hasFlash).thenReturn(true);
          when(() => cameraService.canSwitchCamera).thenReturn(true);
          when(() => cameraService.textureId).thenReturn(null);
          when(
            () => cameraService.currentLens,
          ).thenReturn(DivineCameraLens.back);
          when(
            () => cameraService.videoStabilizationMode,
          ).thenReturn(DivineVideoStabilizationMode.off);
          when(
            () => cameraService.availableVideoStabilizationModes,
          ).thenReturn(const [DivineVideoStabilizationMode.off]);
          when(
            () => cameraService.isVideoStabilizationSupported,
          ).thenReturn(false);
          final bloc = buildBloc(
            cameraServiceFactory:
                ({
                  required onUpdateState,
                  required onAutoStopped,
                  onScreenFlashChanged,
                }) {
                  reportCameraUpdate = onUpdateState;
                  return cameraService;
                },
          );
          tapShutter(bloc, async);

          // An automatic lens switch reports through here mid-session.
          reportCameraUpdate();
          async.flushMicrotasks();
          expect(bloc.state.isIntervalCaptureRunning, isTrue);

          elapse(async, const Duration(seconds: 2));
          expect(bloc.state.stopMotionFrames, hasLength(1));

          closeBloc(bloc, async);
        });
      });
    });

    group('ending the loop', () {
      setUp(stubStopMotionRecorder);

      test('a second shutter tap stops it and keeps its stills', () {
        fakeAsync((async) {
          final bloc = buildBloc();
          tapShutter(bloc, async);
          elapse(async, const Duration(seconds: 2));

          tapShutter(bloc, async);
          expect(bloc.state.isIntervalCaptureRunning, isFalse);
          expect(bloc.state.countdownValue, 0);

          elapse(async, const Duration(seconds: 10));
          expect(bloc.state.stopMotionFrames, hasLength(1));
          verify(() => cameraService.capturePhoto()).called(1);

          closeBloc(bloc, async);
        });
      });

      test('stops on its own once the shot budget is full', () {
        fakeAsync((async) {
          // Room for exactly one more still.
          when(() => clipManager.totalDuration).thenReturn(
            VideoEditorConstants.maxDuration -
                StopMotionFrameOps.framesPerImageToDuration(
                  StopMotionFrameOps.defaultFramesPerImage,
                ),
          );
          final bloc = buildBloc();
          tapShutter(bloc, async);

          elapse(async, const Duration(seconds: 2));
          expect(bloc.state.stopMotionFrames, hasLength(1));
          expect(bloc.state.isIntervalCaptureRunning, isFalse);

          elapse(async, const Duration(seconds: 10));
          verify(() => cameraService.capturePhoto()).called(1);

          closeBloc(bloc, async);
        });
      });

      test('stops when the app goes to the background', () {
        fakeAsync((async) {
          when(
            () => cameraService.handleAppLifecycleState(any()),
          ).thenAnswer((_) async {});
          final bloc = buildBloc();
          tapShutter(bloc, async);

          bloc.add(
            const VideoRecorderAppLifecycleChanged(AppLifecycleState.paused),
          );
          async.flushMicrotasks();
          expect(bloc.state.isIntervalCaptureRunning, isFalse);

          elapse(async, const Duration(seconds: 10));
          verifyNever(() => cameraService.capturePhoto());

          closeBloc(bloc, async);
        });
      });
    });

    group('shutter with the timer off', () {
      setUp(stubStopMotionRecorder);

      test('takes a single still straight away', () {
        fakeAsync((async) {
          final bloc = buildBloc(timer: TimerDuration.off);
          tapShutter(bloc, async);

          expect(bloc.state.isIntervalCaptureRunning, isFalse);
          expect(bloc.state.stopMotionFrames, hasLength(1));

          elapse(async, const Duration(seconds: 10));
          verify(() => cameraService.capturePhoto()).called(1);

          closeBloc(bloc, async);
        });
      });
    });
  });
}
