// ABOUTME: Tests dual-camera capture in the recorder: the toggle, the second
// ABOUTME: camera's window position, and the second file each take carries.

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_camera/divine_camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/secondary_camera_take.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _MockDualCameraService extends Mock
    implements CameraService, DualCameraCapture {}

class _MockClipManager extends Mock implements ClipManagerNotifier {}

class _MockVideoEditor extends Mock implements VideoEditorNotifier {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderBloc dual camera', () {
    late _MockDualCameraService camera;
    late _MockClipManager clipManager;
    late WakelockPlusPlatformInterface previousWakelock;
    late bool dualEnabled;

    setUp(() {
      camera = _MockDualCameraService();
      clipManager = _MockClipManager();
      previousWakelock = wakelockPlusPlatformInstance;
      wakelockPlusPlatformInstance = _FakeWakelockPlatform();
      dualEnabled = false;
    });

    /// The camera a recorder opens on: both cameras, dual capture off until
    /// a toggle turns it on. Each group stubs it in its own setUp.
    void stubCamera() {
      when(() => camera.canRecord).thenReturn(true);
      when(() => camera.isInitialized).thenReturn(true);
      when(() => camera.currentLens).thenReturn(DivineCameraLens.back);
      when(() => camera.minZoomLevel).thenReturn(1);
      when(() => camera.maxZoomLevel).thenReturn(5);
      when(() => camera.cameraAspectRatio).thenReturn(9 / 16);
      when(() => camera.hasFlash).thenReturn(true);
      when(() => camera.canSwitchCamera).thenReturn(true);
      when(() => camera.textureId).thenReturn(1);
      when(
        () => camera.availableVideoStabilizationModes,
      ).thenReturn(const [DivineVideoStabilizationMode.off]);
      when(() => camera.isVideoStabilizationSupported).thenReturn(false);
      when(
        () => camera.videoStabilizationMode,
      ).thenReturn(DivineVideoStabilizationMode.off);
      when(() => camera.isDualCameraSupported).thenReturn(true);
      when(() => camera.isDualCameraEnabled).thenAnswer((_) => dualEnabled);
      when(() => camera.secondaryCamera).thenAnswer(
        (_) => dualEnabled
            ? const SecondaryCameraState(
                lens: DivineCameraLens.front,
                textureId: 2,
              )
            : null,
      );
      when(
        () => camera.setDualCameraEnabled(enabled: any(named: 'enabled')),
      ).thenAnswer((invocation) async {
        dualEnabled = invocation.namedArguments[#enabled] as bool;
        return true;
      });
      when(camera.dispose).thenAnswer((_) async {});
    }

    tearDown(() {
      wakelockPlusPlatformInstance = previousWakelock;
    });

    VideoRecorderBloc buildBloc({
      VideoRecorderMode mode = VideoRecorderMode.capture,
      VideoRecorderState recordingState = VideoRecorderState.idle,
    }) =>
        VideoRecorderBloc(
          readClipManager: () => clipManager,
          readVideoEditor: _MockVideoEditor.new,
          readVideoEditorState: VideoEditorProviderState.new,
          readSharedPreferences: _MockSharedPreferences.new,
          cameraService: camera,
        )..emit(
          VideoRecorderBlocState(
            recorderMode: mode,
            recordingState: recordingState,
          ),
        );

    group(VideoRecorderDualCameraToggled, () {
      setUp(stubCamera);

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'turns dual-camera capture on and shows the second camera',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderDualCameraToggled()),
        verify: (bloc) {
          verify(() => camera.setDualCameraEnabled(enabled: true)).called(1);
          expect(bloc.state.isDualCameraEnabled, isTrue);
          expect(bloc.state.isDualCameraSupported, isTrue);
          expect(bloc.state.secondaryPreviewTextureId, equals(2));
          expect(bloc.state.isSwitchingCamera, isFalse);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'turns dual-camera capture off again',
        setUp: () => dualEnabled = true,
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderDualCameraToggled()),
        verify: (bloc) {
          verify(() => camera.setDualCameraEnabled(enabled: false)).called(1);
          expect(bloc.state.isDualCameraEnabled, isFalse);
          expect(bloc.state.secondaryPreviewTextureId, isNull);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does nothing in a mode without dual-camera capture',
        build: () => buildBloc(mode: VideoRecorderMode.stopMotion),
        act: (bloc) => bloc.add(const VideoRecorderDualCameraToggled()),
        verify: (_) {
          verifyNever(
            () => camera.setDualCameraEnabled(enabled: any(named: 'enabled')),
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does nothing on a device that cannot run both cameras',
        setUp: () {
          when(() => camera.isDualCameraSupported).thenReturn(false);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderDualCameraToggled()),
        verify: (_) {
          verifyNever(
            () => camera.setDualCameraEnabled(enabled: any(named: 'enabled')),
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'refuses while a take is recording',
        build: () => buildBloc(recordingState: VideoRecorderState.recording),
        act: (bloc) => bloc.add(const VideoRecorderDualCameraToggled()),
        verify: (_) {
          verifyNever(
            () => camera.setDualCameraEnabled(enabled: any(named: 'enabled')),
          );
        },
      );
    });

    group(VideoRecorderChromaKeyEnabledSet, () {
      setUp(() {
        stubCamera();
        registerFallbackValue(DivineVideoStabilizationMode.off);
        when(
          () => camera.setVideoStabilizationMode(any()),
        ).thenAnswer((_) async => true);
      });

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'turns dual-camera capture off when the color mask goes on',
        setUp: () => dualEnabled = true,
        build: () {
          final bloc = buildBloc();
          return bloc..emit(
            bloc.state.copyWith(
              isLiveChromaKeySupported: true,
              isDualCameraSupported: true,
              isDualCameraEnabled: true,
            ),
          );
        },
        act: (bloc) =>
            bloc.add(const VideoRecorderChromaKeyEnabledSet(enabled: true)),
        verify: (bloc) {
          verify(() => camera.setDualCameraEnabled(enabled: false)).called(1);
          expect(bloc.state.supportsDualCamera, isFalse);
        },
      );
    });

    group(VideoRecorderDualCameraPipMoved, () {
      setUp(stubCamera);

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'keeps the window center inside the frame',
        build: buildBloc,
        act: (bloc) => bloc
          ..add(const VideoRecorderDualCameraPipMoved(Offset(0.25, 0.6)))
          ..add(const VideoRecorderDualCameraPipMoved(Offset(1.4, -0.2))),
        expect: () => [
          isA<VideoRecorderBlocState>().having(
            (s) => s.dualCameraPipCenter,
            'dualCameraPipCenter',
            const Offset(0.25, 0.6),
          ),
          isA<VideoRecorderBlocState>().having(
            (s) => s.dualCameraPipCenter,
            'dualCameraPipCenter',
            const Offset(1, 0),
          ),
        ],
      );
    });

    group('stopping a dual-camera take', () {
      const second = VideoRecordingResult(
        filePath: '/docs/VID_1_second.mp4',
        lens: DivineCameraLens.front,
      );
      late EditorVideo main;

      setUp(() {
        stubCamera();
        main = EditorVideo.file('/docs/VID_1.mp4');
        when(() => camera.stopRecording()).thenAnswer((_) async => main);
        when(() => camera.takeSecondaryRecording()).thenReturn(second);
        when(
          () => clipManager.remainingDuration,
        ).thenReturn(const Duration(seconds: 60));
        when(
          () => clipManager.addClip(
            video: any(named: 'video'),
            originalAspectRatio: any(named: 'originalAspectRatio'),
            targetAspectRatio: any(named: 'targetAspectRatio'),
            lensMetadata: any(named: 'lensMetadata'),
            limitClipDuration: any(named: 'limitClipDuration'),
            captureChromaKey: any(named: 'captureChromaKey'),
            secondaryRecording: any(named: 'secondaryRecording'),
            secondaryPipCenter: any(named: 'secondaryPipCenter'),
          ),
        ).thenReturn(
          DivineVideoClip(
            id: 'clip_1',
            video: main,
            duration: const Duration(seconds: 2),
            recordedAt: DateTime(2026),
            targetAspectRatio: model.AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
          ),
        );
        when(
          () => clipManager.saveClipToLibrary(any()),
        ).thenAnswer((_) async => true);
      });

      setUpAll(() {
        registerFallbackValue(
          DivineVideoClip(
            id: 'fallback',
            video: EditorVideo.file('/fallback.mp4'),
            duration: Duration.zero,
            recordedAt: DateTime(2026),
            targetAspectRatio: model.AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
          ),
        );
        registerFallbackValue(EditorVideo.file('/fallback.mp4'));
        registerFallbackValue(model.AspectRatio.vertical);
        registerFallbackValue(Offset.zero);
      });

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'hands the second file and the window position to the clip',
        build: () =>
            buildBloc(recordingState: VideoRecorderState.recording)
              ..add(const VideoRecorderDualCameraPipMoved(Offset(0.2, 0.3))),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
        verify: (_) {
          verify(
            () => clipManager.addClip(
              video: main,
              originalAspectRatio: any(named: 'originalAspectRatio'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
              lensMetadata: any(named: 'lensMetadata'),
              limitClipDuration: any(named: 'limitClipDuration'),
              captureChromaKey: any(named: 'captureChromaKey'),
              secondaryRecording: second,
              secondaryPipCenter: const Offset(0.2, 0.3),
            ),
          ).called(1);
        },
      );

      group('when the clip carries the take', () {
        setUp(() {
          registerFallbackValue(Future<void>.value());
          when(
            () => clipManager.addClip(
              video: any(named: 'video'),
              originalAspectRatio: any(named: 'originalAspectRatio'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
              lensMetadata: any(named: 'lensMetadata'),
              limitClipDuration: any(named: 'limitClipDuration'),
              captureChromaKey: any(named: 'captureChromaKey'),
              secondaryRecording: any(named: 'secondaryRecording'),
              secondaryPipCenter: any(named: 'secondaryPipCenter'),
            ),
          ).thenReturn(
            DivineVideoClip(
              id: 'clip_1',
              video: main,
              duration: const Duration(seconds: 2),
              recordedAt: DateTime(2026),
              targetAspectRatio: model.AspectRatio.vertical,
              originalAspectRatio: 9 / 16,
              secondaryCamera: SecondaryCameraTake(
                clip: DivineVideoClip(
                  id: 'clip_1_second',
                  video: EditorVideo.file(second.filePath),
                  duration: const Duration(seconds: 2),
                  recordedAt: DateTime(2026),
                  targetAspectRatio: model.AspectRatio.vertical,
                  originalAspectRatio: 9 / 16,
                ),
              ),
            ),
          );
        });

        blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
          "tracks the take's poster so the editor can wait for it",
          build: () => buildBloc(recordingState: VideoRecorderState.recording),
          act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
          verify: (_) {
            verify(
              () => clipManager.trackClipEnrichment('clip_1_second', any()),
            ).called(1);
          },
        );

        group('once both cameras have thumbnails', () {
          late Directory dir;
          late Completer<String> composed;
          late Completer<void> savedAgain;

          setUp(() {
            dir = Directory.systemTemp.createTempSync('dual_thumbnail_bloc');
            String thumbnail(String name) {
              final path = '${dir.path}/$name';
              File(path).writeAsBytesSync(
                img.encodeJpg(img.Image(width: 90, height: 160)),
              );
              return path;
            }

            final take = SecondaryCameraTake(
              clip: DivineVideoClip(
                id: 'clip_1_second',
                video: EditorVideo.file(second.filePath),
                duration: const Duration(seconds: 2),
                recordedAt: DateTime(2026),
                targetAspectRatio: model.AspectRatio.vertical,
                originalAspectRatio: 9 / 16,
                thumbnailPath: thumbnail('second.jpg'),
              ),
            );
            final enriched = DivineVideoClip(
              id: 'clip_1',
              video: main,
              duration: const Duration(seconds: 2),
              recordedAt: DateTime(2026),
              targetAspectRatio: model.AspectRatio.vertical,
              originalAspectRatio: 9 / 16,
              thumbnailPath: thumbnail('main.jpg'),
              secondaryCamera: take,
            );
            when(() => clipManager.getClipById('clip_1')).thenReturn(enriched);
            composed = Completer<String>();
            savedAgain = Completer<void>();
            when(
              () => clipManager.setSecondaryCameraThumbnail(
                any(),
                takeId: any(named: 'takeId'),
                path: any(named: 'path'),
              ),
            ).thenAnswer((invocation) {
              composed.complete(invocation.namedArguments[#path] as String);
              return true;
            });
            when(
              () => clipManager.waitForSecondaryCameraTakes(),
            ).thenAnswer((_) async {});
            when(() => clipManager.saveClipToLibrary(any())).thenAnswer((
              invocation,
            ) async {
              final saved =
                  invocation.positionalArguments.single as DivineVideoClip;
              // The save that matters is the one after the composite.
              if (saved.id == 'clip_1' &&
                  composed.isCompleted &&
                  !savedAgain.isCompleted) {
                savedAgain.complete();
              }
              return true;
            });
          });

          tearDown(() => dir.deleteSync(recursive: true));

          blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
            'gives the take a picture of both cameras and saves it again',
            build: () =>
                buildBloc(recordingState: VideoRecorderState.recording),
            act: (bloc) async {
              bloc.add(const VideoRecorderRecordingStopRequested());
              await savedAgain.future.timeout(const Duration(seconds: 10));
            },
            verify: (_) {
              final path =
                  verify(
                        () => clipManager.setSecondaryCameraThumbnail(
                          'clip_1',
                          takeId: 'clip_1_second',
                          path: captureAny(named: 'path'),
                        ),
                      ).captured.single
                      as String;
              expect(path, endsWith('main_dual.jpg'));
              expect(File(path).existsSync(), isTrue);
            },
          );
        });
      });

      group('when the main camera produced no file', () {
        late Directory dir;
        late File secondFile;

        setUp(() {
          dir = Directory.systemTemp.createTempSync('dual_camera_stop');
          secondFile = File('${dir.path}/VID_2_second.mp4')
            ..writeAsStringSync('mp4');
          when(() => camera.stopRecording()).thenAnswer((_) async => null);
          when(
            () => camera.takeSecondaryRecording(),
          ).thenReturn(VideoRecordingResult(filePath: secondFile.path));
        });

        tearDown(() {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        });

        blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
          'deletes the second camera file: alone it is no clip',
          build: () => buildBloc(recordingState: VideoRecorderState.recording),
          act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
          errors: () => [isA<RecordingProducedNoVideoException>()],
          verify: (_) {
            expect(secondFile.existsSync(), isFalse);
          },
        );
      });
    });
  });

  group('VideoRecorderBloc without dual-camera capture', () {
    test('reports no dual camera for a camera service without it', () {
      final camera = _SingleCameraService();
      when(camera.dispose).thenAnswer((_) async {});
      final bloc = VideoRecorderBloc(
        readClipManager: _MockClipManager.new,
        readVideoEditor: _MockVideoEditor.new,
        readVideoEditorState: VideoEditorProviderState.new,
        readSharedPreferences: _MockSharedPreferences.new,
        cameraService: camera,
      )..add(const VideoRecorderDualCameraToggled());
      addTearDown(bloc.close);

      expect(bloc.state.isDualCameraSupported, isFalse);
      expect(bloc.state.isDualCameraEnabled, isFalse);
    });
  });
}

class _SingleCameraService extends Mock implements CameraService {}
