// ABOUTME: Tests that a camera re-sync keeps the chroma-key setup: the key,
// ABOUTME: the backdrop photo the recorder owns, and a running measurement.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:divine_camera/divine_camera.dart'
    show
        DivineCameraLens,
        DivineVideoQuality,
        DivineVideoStabilizationMode,
        PhotoCaptureResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show ChromaKeyDetection;
import 'package:shared_preferences/shared_preferences.dart';

class _MockCameraService extends Mock implements CameraService {}

class _MockClipManager extends Mock implements ClipManagerNotifier {}

class _MockVideoEditor extends Mock implements VideoEditorNotifier {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

const _measured = ChromaKeyDetection(
  color: Color(0xFFB0B8C0),
  similarity: 0.12,
  coverage: 0.95,
  spread: 0.04,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderBloc chroma key across a camera re-sync', () {
    late _MockCameraService camera;
    late _MockClipManager clipManager;
    late _MockSharedPreferences prefs;
    late Directory tmp;
    late DivineCameraLens lens;
    late void Function({bool? forceCameraRebuild}) reportCameraUpdate;

    setUpAll(() {
      registerFallbackValue(DivineVideoQuality.fhd);
      registerFallbackValue(DivineCameraLens.back);
      registerFallbackValue(DivineVideoStabilizationMode.off);
      registerFallbackValue(DivineFlashMode.off);
    });

    setUp(() {
      camera = _MockCameraService();
      clipManager = _MockClipManager();
      prefs = _MockSharedPreferences();
      tmp = Directory.systemTemp.createTempSync('camera_sync_chroma_key');
      lens = DivineCameraLens.back;
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    /// A live camera that reports re-syncs the way `CameraMobileService`
    /// does, on a recorder last left in chroma key mode.
    void stubLiveCamera() {
      when(() => camera.canRecord).thenReturn(true);
      when(() => camera.isInitialized).thenReturn(true);
      when(() => camera.canSwitchCamera).thenReturn(true);
      when(() => camera.hasFlash).thenReturn(true);
      when(() => camera.cameraAspectRatio).thenReturn(9 / 16);
      when(() => camera.minZoomLevel).thenReturn(0.5);
      when(() => camera.maxZoomLevel).thenReturn(5);
      when(() => camera.isSwitchingCamera).thenReturn(false);
      when(() => camera.currentLens).thenAnswer((_) => lens);
      when(() => camera.textureId).thenReturn(7);
      when(
        () => camera.videoStabilizationMode,
      ).thenReturn(DivineVideoStabilizationMode.off);
      when(() => camera.availableVideoStabilizationModes).thenReturn(const [
        DivineVideoStabilizationMode.off,
        DivineVideoStabilizationMode.standard,
      ]);
      when(() => camera.isVideoStabilizationSupported).thenReturn(true);
      when(() => camera.initializationError).thenReturn(null);
      when(() => camera.dispose()).thenAnswer((_) async {});
      when(() => camera.setFlashMode(any())).thenAnswer((_) async => true);
      // What CameraMobileService does: a flip reports a forced rebuild.
      when(() => camera.switchCamera()).thenAnswer((_) async {
        lens = lens.isFrontFacing
            ? DivineCameraLens.back
            : DivineCameraLens.front;
        reportCameraUpdate(forceCameraRebuild: true);
        return true;
      });
      when(() => camera.setOnRemoteRecordTrigger(any())).thenReturn(null);
      when(
        () => camera.setRemoteRecordControlEnabled(
          enabled: any(named: 'enabled'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => camera.setVolumeKeysEnabled(enabled: any(named: 'enabled')),
      ).thenAnswer((_) async => true);
      when(
        () => camera.initialize(
          videoQuality: any(named: 'videoQuality'),
          initialLens: any(named: 'initialLens'),
          enableAutoLensSwitch: any(named: 'enableAutoLensSwitch'),
          preferUnprocessedAudio: any(named: 'preferUnprocessedAudio'),
          videoStabilizationMode: any(named: 'videoStabilizationMode'),
        ),
      ).thenAnswer((_) async => reportCameraUpdate(forceCameraRebuild: true));
      when(
        () => camera.capturePhoto(
          outputDirectory: any(named: 'outputDirectory'),
        ),
      ).thenAnswer((_) async {
        final still = File('${tmp.path}/still.jpg')..writeAsStringSync('jpg');
        return PhotoCaptureResult(filePath: still.path);
      });
      when(() => clipManager.clips).thenReturn(const []);
      when(() => prefs.setString(any(), any())).thenAnswer((_) async => true);
      when(() => prefs.getBool(any())).thenReturn(null);
      // The recorder was last left in chroma key mode.
      when(() => prefs.getString(any())).thenAnswer(
        (invocation) =>
            invocation.positionalArguments.first ==
                VideoRecorderMode.persistenceKey
            ? VideoRecorderMode.chromaKey.name
            : null,
      );
    }

    VideoRecorderBloc buildBloc({ChromaKeyStillDetector? detect}) {
      final bloc = VideoRecorderBloc(
        readClipManager: () => clipManager,
        readVideoEditor: _MockVideoEditor.new,
        readVideoEditorState: VideoEditorProviderState.new,
        readSharedPreferences: () => prefs,
        cameraServiceFactory:
            ({
              required onUpdateState,
              required onAutoStopped,
              onScreenFlashChanged,
            }) {
              reportCameraUpdate = onUpdateState;
              return camera;
            },
        liveChromaKeySupported: true,
        detectChromaKeyStill:
            detect ?? (_, {required visibleAspectRatio}) async => _measured,
      );
      return bloc..emit(
        const VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.chromaKey,
          isCameraInitialized: true,
        ),
      );
    }

    group('VideoRecorderCameraSwitched', () {
      setUp(stubLiveCamera);

      test('keeps the chosen backdrop and key', () async {
        final bloc = buildBloc()
          ..add(
            const VideoRecorderChromaKeyBackdropSet.color(Color(0xFFFF0000)),
          )
          ..add(const VideoRecorderChromaKeySettingsChanged(similarity: 0.33));
        addTearDown(bloc.close);
        await pumpEventQueue();
        expect(
          bloc.state.chromaKey.backgroundType,
          ClipChromaKeyBackgroundType.color,
        );

        bloc.add(const VideoRecorderCameraSwitched());
        await pumpEventQueue();

        expect(bloc.state.isFrontCamera, isTrue);
        expect(
          bloc.state.chromaKey.backgroundType,
          ClipChromaKeyBackgroundType.color,
          reason: 'a camera flip must not throw away the chosen backdrop',
        );
        expect(
          bloc.state.chromaKey.key.similarity,
          0.33,
          reason: 'a camera flip must not reset the tuned key',
        );
      });

      test(
        'writes off a running measurement and drops its result',
        () async {
          final measured = Completer<ChromaKeyDetection>();
          final bloc = buildBloc(
            detect: (_, {required visibleAspectRatio}) => measured.future,
          );
          addTearDown(bloc.close);

          bloc.add(const VideoRecorderChromaKeyMeasureRequested());
          await pumpEventQueue();
          expect(
            bloc.state.chromaKeyMeasurementStatus,
            ChromaKeyMeasurementStatus.detecting,
          );

          bloc.add(const VideoRecorderCameraSwitched());
          await pumpEventQueue();
          expect(bloc.state.isFrontCamera, isTrue);
          expect(
            bloc.state.chromaKeyMeasurementStatus,
            ChromaKeyMeasurementStatus.superseded,
            reason:
                'the wall behind the other lens is not the one measured, and '
                'Auto-detect must stay busy until the running measurement ends',
          );

          measured.complete(_measured);
          await pumpEventQueue();
          expect(
            bloc.state.chromaKeyMeasurementStatus,
            ChromaKeyMeasurementStatus.idle,
          );
          expect(
            bloc.state.chromaKey.key.color,
            isNot(_measured.color),
            reason: 'a written-off measurement must not land on the key',
          );
        },
      );

      test(
        'still owns an unrecorded backdrop photo and deletes it on close',
        () async {
          final photo = File('${tmp.path}/chroma_bg_recorder_1.png')
            ..writeAsStringSync('png');
          final bloc = buildBloc()
            ..add(VideoRecorderChromaKeyBackdropSet.image(photo.path));
          await pumpEventQueue();
          expect(bloc.state.unrecordedChromaKeyImagePath, photo.path);

          bloc.add(const VideoRecorderCameraSwitched());
          await pumpEventQueue();
          expect(
            bloc.state.unrecordedChromaKeyImagePath,
            photo.path,
            reason: 'the recorder still owns the photo it shot',
          );

          await bloc.close();
          expect(
            photo.existsSync(),
            isFalse,
            reason:
                'close() deletes a backdrop photo no clip was recorded with',
          );
        },
      );
    });

    group('VideoRecorderInitializeRequested', () {
      setUp(stubLiveCamera);

      test(
        'keeps the chosen backdrop when coming back from the editor',
        () async {
          final bloc = buildBloc()
            ..add(
              const VideoRecorderChromaKeyBackdropSet.color(Color(0xFF00FF00)),
            );
          addTearDown(bloc.close);
          await pumpEventQueue();

          // What openVideoEditorFromRecorder dispatches once the editor pops.
          bloc.add(const VideoRecorderInitializeRequested());
          await pumpEventQueue(times: 50);
          verify(
            () => camera.initialize(
              videoQuality: any(named: 'videoQuality'),
              initialLens: any(named: 'initialLens'),
              enableAutoLensSwitch: any(named: 'enableAutoLensSwitch'),
              preferUnprocessedAudio: any(named: 'preferUnprocessedAudio'),
              videoStabilizationMode: any(named: 'videoStabilizationMode'),
            ),
          ).called(1);

          expect(
            bloc.state.chromaKey.backgroundType,
            ClipChromaKeyBackgroundType.color,
            reason: 'coming back from the editor must find the backdrop as set',
          );
        },
      );
    });
  });
}
