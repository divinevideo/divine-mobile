// ABOUTME: Tests what close() does with a chroma-key backdrop photo that no
// ABOUTME: clip was recorded with: delete it unless a take could still own it.

import 'dart:async';
import 'dart:io';

import 'package:divine_camera/divine_camera.dart'
    show DivineCameraLens, DivineVideoStabilizationMode;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
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

class _MockCountdownSounds extends Mock implements CountdownSoundService {}

class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderBloc close', () {
    late _MockCameraService camera;
    late _MockClipManager clipManager;
    late _MockCountdownSounds countdown;
    late WakelockPlusPlatformInterface previousWakelock;
    late Directory tmp;
    late File photo;

    setUp(() {
      camera = _MockCameraService();
      clipManager = _MockClipManager();
      countdown = _MockCountdownSounds();
      previousWakelock = wakelockPlusPlatformInstance;
      wakelockPlusPlatformInstance = _FakeWakelockPlatform();
      tmp = Directory.systemTemp.createTempSync('close_backdrop_photo');
      photo = File('${tmp.path}/chroma_bg_recorder_1.png')
        ..writeAsStringSync('png');

      when(() => camera.canRecord).thenReturn(true);
      when(() => camera.isInitialized).thenReturn(true);
      when(() => camera.currentLens).thenReturn(DivineCameraLens.back);
      when(() => camera.minZoomLevel).thenReturn(1);
      when(() => camera.maxZoomLevel).thenReturn(5);
      when(() => camera.cameraAspectRatio).thenReturn(9 / 16);
      when(() => camera.hasFlash).thenReturn(true);
      when(() => camera.canSwitchCamera).thenReturn(true);
      when(() => camera.textureId).thenReturn(null);
      when(
        () => camera.availableVideoStabilizationModes,
      ).thenReturn(const [DivineVideoStabilizationMode.off]);
      when(() => camera.isVideoStabilizationSupported).thenReturn(false);
      when(
        () => camera.videoStabilizationMode,
      ).thenReturn(DivineVideoStabilizationMode.off);
      when(
        () => camera.setVolumeKeysEnabled(enabled: any(named: 'enabled')),
      ).thenAnswer((_) async => true);
      when(camera.suspendAudioCapture).thenAnswer((_) async {});
      when(camera.resumeAudioCapture).thenAnswer((_) async {});
      when(
        () => camera.startRecording(maxDuration: any(named: 'maxDuration')),
      ).thenAnswer((_) async => true);
      when(camera.dispose).thenAnswer((_) async {});
      when(
        () => clipManager.remainingDuration,
      ).thenReturn(const Duration(seconds: 6));
      when(clipManager.holdCapturedChromaKeyBakes).thenReturn(null);
      when(clipManager.releaseCapturedChromaKeyBakes).thenReturn(null);
      when(clipManager.startRecording).thenReturn(null);
      when(countdown.preload).thenAnswer((_) async {});
      when(countdown.playShortBeep).thenAnswer((_) async {});
      when(countdown.playLongBeepAndWait).thenAnswer((_) async {});
      when(countdown.dispose).thenAnswer((_) async {});
    });

    tearDown(() {
      wakelockPlusPlatformInstance = previousWakelock;
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    VideoRecorderBloc buildBloc({required TimerDuration timer}) =>
        VideoRecorderBloc(
            readClipManager: () => clipManager,
            readVideoEditor: _MockVideoEditor.new,
            readVideoEditorState: VideoEditorProviderState.new,
            readSharedPreferences: _MockSharedPreferences.new,
            cameraService: camera,
            countdownSoundServiceFactory: () => countdown,
            liveChromaKeySupported: true,
          )
          ..emit(
            VideoRecorderBlocState(
              recorderMode: VideoRecorderMode.chromaKey,
              timerDuration: timer,
            ),
          )
          ..add(VideoRecorderChromaKeyBackdropSet.image(photo.path));

    test('deletes the backdrop photo when backed out of a countdown', () {
      fakeAsync((async) {
        final bloc = buildBloc(timer: TimerDuration.three)
          ..add(const VideoRecorderRecordingStartRequested());
        async.flushMicrotasks();
        expect(bloc.state.unrecordedChromaKeyImagePath, photo.path);
        expect(bloc.state.isRecording, isTrue, reason: 'countdown running');
        expect(bloc.state.isCapturingFootage, isFalse);

        unawaited(bloc.close());
        async
          ..elapse(const Duration(seconds: 4))
          ..flushMicrotasks();

        expect(bloc.isClosed, isTrue);
        expect(
          photo.existsSync(),
          isFalse,
          reason: 'the countdown never produced a clip to own the photo',
        );
      });
    });

    test('keeps the backdrop photo for a take that is capturing', () {
      fakeAsync((async) {
        final bloc = buildBloc(timer: TimerDuration.off)
          ..add(const VideoRecorderRecordingStartRequested());
        async.flushMicrotasks();
        expect(bloc.state.isCapturingFootage, isTrue);

        unawaited(bloc.close());
        async.flushMicrotasks();

        expect(bloc.isClosed, isTrue);
        expect(
          photo.existsSync(),
          isTrue,
          reason: 'a take on the camera may still become a clip that uses it',
        );
      });
    });
  });
}
