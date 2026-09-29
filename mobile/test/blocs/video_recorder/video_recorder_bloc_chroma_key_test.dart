import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_camera/divine_camera.dart'
    show
        DivineCameraLens,
        DivineVideoQuality,
        DivineVideoStabilizationMode,
        PhotoCaptureResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _MockCameraService extends Mock implements CameraService {}

class _MockClipManager extends Mock implements ClipManagerNotifier {}

class _MockVideoEditor extends Mock implements VideoEditorNotifier {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _MockEditorVideo extends Mock implements EditorVideo {}

class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

const _measured = ChromaKeyDetection(
  color: Color(0xFFB0B8C0),
  similarity: 0.12,
  coverage: 0.95,
  spread: 0.04,
);

void main() {
  late _MockCameraService cameraService;
  late _MockClipManager clipManager;
  late _MockVideoEditor videoEditor;
  late _MockSharedPreferences prefs;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    wakelockPlusPlatformInstance = _FakeWakelockPlatform();
    registerFallbackValue(EditorVideo.file('/fallback.mp4'));
    registerFallbackValue(DivineVideoQuality.fhd);
    registerFallbackValue(DivineCameraLens.back);
    registerFallbackValue(DivineVideoStabilizationMode.off);
    registerFallbackValue(DivineFlashMode.off);
    registerFallbackValue(model.AspectRatio.vertical);
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
    tempDir = Directory.systemTemp.createTempSync('chroma_key_bloc');

    // Every test closes its bloc, which releases the camera.
    when(() => cameraService.dispose()).thenAnswer((_) async {});
  });

  /// A mode switch persists the mode and clears the session it leaves.
  void stubModeSwitch() {
    when(() => prefs.getString(any())).thenReturn(null);
    when(() => prefs.setString(any(), any())).thenAnswer((_) async => true);
    when(() => prefs.getBool(any())).thenReturn(null);
    when(
      () => clipManager.clearAll(
        keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => videoEditor.reset(
        keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
      ),
    ).thenAnswer((_) async {});
  }

  /// A camera that is up and can take a still.
  void stubReadyCamera() {
    when(() => cameraService.isInitialized).thenReturn(true);
    when(() => cameraService.isSwitchingCamera).thenReturn(false);
    when(() => cameraService.setFlashMode(any())).thenAnswer((_) async => true);
  }

  /// What a stop reads off the camera and the clip manager around the add.
  void stubStopReads() {
    when(() => cameraService.cameraAspectRatio).thenReturn(9 / 16);
    when(() => cameraService.currentLensMetadata).thenReturn(null);
    when(() => clipManager.clips).thenReturn(const []);
    when(
      () => clipManager.remainingDuration,
    ).thenReturn(const Duration(seconds: 6));
    when(() => clipManager.totalDuration).thenReturn(Duration.zero);
  }

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  VideoRecorderBloc buildBloc({
    bool liveChromaKeySupported = true,
    ChromaKeyStillDetector? detect,
  }) {
    return VideoRecorderBloc(
      readClipManager: () => clipManager,
      readVideoEditor: () => videoEditor,
      readVideoEditorState: VideoEditorProviderState.new,
      readSharedPreferences: () => prefs,
      cameraService: cameraService,
      liveChromaKeySupported: liveChromaKeySupported,
      detectChromaKeyStill:
          detect ?? (_, {required visibleAspectRatio}) async => _measured,
    );
  }

  /// Writes a file standing in for the still the camera captures.
  File stubStill() {
    final still = File('${tempDir.path}/still.jpg')..writeAsStringSync('jpg');
    when(
      () => cameraService.capturePhoto(
        outputDirectory: any(named: 'outputDirectory'),
      ),
    ).thenAnswer((_) async => PhotoCaptureResult(filePath: still.path));
    return still;
  }

  const chromaKeyState = VideoRecorderBlocState(
    recorderMode: VideoRecorderMode.chromaKey,
  );

  /// Requests a measurement and waits for it to land: the still is real file
  /// IO, which a bare event-queue pump does not wait out.
  Future<void> detect(VideoRecorderBloc bloc) async {
    final landed = bloc.stream.firstWhere(
      (state) =>
          state.chromaKeyMeasurementStatus !=
          ChromaKeyMeasurementStatus.detecting,
    );
    bloc.add(const VideoRecorderChromaKeyMeasureRequested());
    await landed;
  }

  group(VideoRecorderBloc, () {
    group('VideoRecorderRecorderModeSet', () {
      setUp(stubModeSwitch);

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'enters chroma key when the renderer can draw the live key',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoRecorderRecorderModeSet(VideoRecorderMode.chromaKey),
        ),
        verify: (bloc) {
          expect(bloc.state.recorderMode, VideoRecorderMode.chromaKey);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'stays put when the renderer cannot draw the live key',
        build: () => buildBloc(liveChromaKeySupported: false),
        act: (bloc) => bloc.add(
          const VideoRecorderRecorderModeSet(VideoRecorderMode.chromaKey),
        ),
        expect: () => const <VideoRecorderBlocState>[],
        verify: (_) {
          // Nothing was discarded for a mode that never opened.
          verifyNever(
            () => clipManager.clearAll(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          );
        },
      );
    });

    group('VideoRecorderInitializeRequested', () {
      setUp(() {
        stubModeSwitch();
        when(
          () => prefs.getString(VideoRecorderMode.persistenceKey),
        ).thenReturn(VideoRecorderMode.chromaKey.name);
        when(
          () => cameraService.initialize(
            videoQuality: any(named: 'videoQuality'),
            initialLens: any(named: 'initialLens'),
            enableAutoLensSwitch: any(named: 'enableAutoLensSwitch'),
            preferUnprocessedAudio: any(named: 'preferUnprocessedAudio'),
            videoStabilizationMode: any(named: 'videoStabilizationMode'),
          ),
        ).thenThrow(StateError('camera stays down in this test'));
      });

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'restores a persisted chroma key where it can be shown',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        errors: () => [isA<StateError>()],
        verify: (bloc) {
          expect(bloc.state.recorderMode, VideoRecorderMode.chromaKey);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'falls back to capture on a device that cannot show chroma key',
        build: () => buildBloc(liveChromaKeySupported: false),
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        errors: () => [isA<StateError>()],
        verify: (bloc) {
          expect(bloc.state.recorderMode, VideoRecorderMode.capture);
        },
      );
    });

    group('VideoRecorderChromaKeyMeasureRequested', () {
      setUp(stubReadyCamera);

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'adopts the measured colour and amount, keeping the backdrop',
        setUp: stubStill,
        build: () => buildBloc()
          ..emit(
            chromaKeyState.copyWith(
              chromaKey: const ClipChromaKey(
                key: ChromaKey.greenScreen(
                  spill: 0.2,
                  backgroundColor: Color(0xFF102030),
                ),
              ),
            ),
          ),
        act: detect,
        verify: (bloc) {
          final key = bloc.state.chromaKey.key;
          expect(key.color, _measured.color);
          expect(key.similarity, _measured.similarity);
          expect(key.spill, 0.2);
          expect(key.backgroundColor, const Color(0xFF102030));
          expect(
            bloc.state.chromaKeyMeasurementStatus,
            ChromaKeyMeasurementStatus.idle,
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'measures only the part of the still the video keeps, then deletes it',
        setUp: stubStill,
        build: () {
          late final double measuredAspectRatio;
          late final bool stillExisted;
          return buildBloc(
            detect: (path, {required visibleAspectRatio}) async {
              measuredAspectRatio = visibleAspectRatio;
              stillExisted = File(path).existsSync();
              expect(measuredAspectRatio, 9 / 16);
              expect(stillExisted, isTrue);
              return _measured;
            },
          )..emit(chromaKeyState);
        },
        act: detect,
        // The expects above run inside the detector, where the measurement's
        // catch-all turns a failure into a bloc error instead of failing the
        // test. Asserting no errors surfaces them.
        errors: () => const <Object>[],
        verify: (_) {
          expect(File('${tempDir.path}/still.jpg').existsSync(), isFalse);
        },
      );

      test('holds auto flash off for the still, then restores it', () async {
        stubStill();
        final flashAtCapture = <DivineFlashMode>[];
        var flash = DivineFlashMode.auto;
        when(() => cameraService.setFlashMode(any())).thenAnswer((invocation) {
          flash = invocation.positionalArguments.single as DivineFlashMode;
          return Future.value(true);
        });
        when(
          () => cameraService.capturePhoto(
            outputDirectory: any(named: 'outputDirectory'),
          ),
        ).thenAnswer((_) async {
          flashAtCapture.add(flash);
          return PhotoCaptureResult(filePath: '${tempDir.path}/still.jpg');
        });
        final bloc = buildBloc()..emit(chromaKeyState);
        addTearDown(bloc.close);

        await detect(bloc);

        // A flash burst lights the wall in a way the video never is.
        expect(flashAtCapture, [DivineFlashMode.off]);
        expect(flash, DivineFlashMode.auto);
      });

      test('keeps a torch on for the still', () async {
        stubStill();
        final bloc = buildBloc()
          ..emit(chromaKeyState.copyWith(flashMode: DivineFlashMode.torch));
        addTearDown(bloc.close);

        await detect(bloc);

        verifyNever(() => cameraService.setFlashMode(any()));
      });

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'reports a wall it could not find and leaves the key alone',
        setUp: stubStill,
        build: () => buildBloc(
          detect: (_, {required visibleAspectRatio}) async =>
              throw const ChromaKeyDetectionException('grey border'),
        )..emit(chromaKeyState),
        act: detect,
        expect: () => [
          chromaKeyState.copyWith(
            chromaKeyMeasurementStatus: ChromaKeyMeasurementStatus.detecting,
          ),
          chromaKeyState.copyWith(
            chromaKeyMeasurementStatus: ChromaKeyMeasurementStatus.failed,
          ),
        ],
        errors: () => const <Object>[],
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'treats a camera that returns no still as a failed measurement',
        setUp: () => when(
          () => cameraService.capturePhoto(
            outputDirectory: any(named: 'outputDirectory'),
          ),
        ).thenAnswer((_) async => null),
        build: () => buildBloc()..emit(chromaKeyState),
        act: detect,
        verify: (bloc) {
          expect(
            bloc.state.chromaKeyMeasurementStatus,
            ChromaKeyMeasurementStatus.failed,
          );
        },
      );

      test('drops a measurement a hand edit overtook', () async {
        stubStill();
        final gate = Completer<ChromaKeyDetection>();
        final bloc = buildBloc(
          detect: (_, {required visibleAspectRatio}) => gate.future,
        )..emit(chromaKeyState);
        addTearDown(bloc.close);

        bloc.add(const VideoRecorderChromaKeyMeasureRequested());
        await pumpEventQueue();
        expect(bloc.state.isMeasuringChromaKey, isTrue);

        bloc.add(
          const VideoRecorderChromaKeySettingsChanged(similarity: 0.3),
        );
        await pumpEventQueue();
        gate.complete(_measured);
        await pumpEventQueue();

        // The edit was deliberate and the measurement a guess: nothing it
        // measured lands on top of the user's choice.
        expect(bloc.state.chromaKey.key.similarity, 0.3);
        expect(
          bloc.state.chromaKey.key.color,
          const ChromaKey.greenScreen().color,
        );
        expect(
          bloc.state.chromaKeyMeasurementStatus,
          ChromaKeyMeasurementStatus.idle,
        );
      });

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does not take a still outside chroma key mode',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderChromaKeyMeasureRequested()),
        expect: () => const <VideoRecorderBlocState>[],
        verify: (_) {
          verifyNever(
            () => cameraService.capturePhoto(
              outputDirectory: any(named: 'outputDirectory'),
            ),
          );
        },
      );
    });

    group('VideoRecorderChromaKeyPresetSelected', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'switches the screen colour and clears a failed measurement',
        build: () => buildBloc()
          ..emit(
            chromaKeyState.copyWith(
              chromaKeyMeasurementStatus: ChromaKeyMeasurementStatus.failed,
            ),
          ),
        act: (bloc) => bloc.add(
          const VideoRecorderChromaKeyPresetSelected(ChromaKey.blueScreen()),
        ),
        verify: (bloc) {
          expect(
            bloc.state.chromaKey.key.color,
            const ChromaKey.blueScreen().color,
          );
          expect(
            bloc.state.chromaKeyMeasurementStatus,
            ChromaKeyMeasurementStatus.idle,
          );
        },
      );
    });

    group('VideoRecorderChromaKeySettingsChanged', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'changes only the settings it carries',
        build: () => buildBloc()..emit(chromaKeyState),
        act: (bloc) => bloc
          ..add(const VideoRecorderChromaKeySettingsChanged(spill: 0.9))
          ..add(
            const VideoRecorderChromaKeySettingsChanged(
              color: Color(0xFF334455),
            ),
          ),
        verify: (bloc) {
          final key = bloc.state.chromaKey.key;
          expect(key.spill, 0.9);
          expect(key.color, const Color(0xFF334455));
          expect(key.similarity, const ChromaKey.greenScreen().similarity);
        },
      );
    });

    group('VideoRecorderChromaKeyBackdropSet', () {
      late File first;
      late File second;

      setUp(() {
        first = File('${tempDir.path}/chroma_bg_1.png')..writeAsStringSync('');
        second = File('${tempDir.path}/chroma_bg_2.png')..writeAsStringSync('');
      });

      test(
        'deletes an image no clip was recorded with once it is replaced',
        () async {
          final bloc = buildBloc()..emit(chromaKeyState);
          addTearDown(bloc.close);

          bloc
            ..add(VideoRecorderChromaKeyBackdropSet.image(first.path))
            ..add(VideoRecorderChromaKeyBackdropSet.image(second.path));
          await pumpEventQueue();

          expect(first.existsSync(), isFalse);
          expect(second.existsSync(), isTrue);
          expect(bloc.state.chromaKey.backgroundImagePath, second.path);
          expect(bloc.state.unrecordedChromaKeyImagePath, second.path);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'deletes an unrecorded image when a clip backdrop replaces it',
        build: () => buildBloc()..emit(chromaKeyState),
        act: (bloc) => bloc
          ..add(VideoRecorderChromaKeyBackdropSet.image(first.path))
          ..add(const VideoRecorderChromaKeyBackdropSet.video('/lib/a.mp4')),
        verify: (bloc) {
          expect(first.existsSync(), isFalse);
          expect(
            bloc.state.chromaKey.backgroundType,
            ClipChromaKeyBackgroundType.video,
          );
          expect(bloc.state.unrecordedChromaKeyImagePath, isNull);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'fills the keyed area with a colour',
        build: () => buildBloc()..emit(chromaKeyState),
        act: (bloc) => bloc.add(
          const VideoRecorderChromaKeyBackdropSet.color(Color(0xFF223344)),
        ),
        verify: (bloc) {
          expect(
            bloc.state.chromaKey.key.backgroundColor,
            const Color(0xFF223344),
          );
        },
      );

      test('deletes an image no clip was recorded with on close', () async {
        final bloc = buildBloc()..emit(chromaKeyState);
        bloc.add(VideoRecorderChromaKeyBackdropSet.image(first.path));
        await pumpEventQueue();

        await bloc.close();

        expect(first.existsSync(), isFalse);
      });
    });

    group('VideoRecorderRecordingStopRequested', () {
      late _MockEditorVideo recorded;

      setUp(() {
        stubStopReads();
        recorded = _MockEditorVideo();
        // Post-processing is detached from the stop and irrelevant here.
        when(
          recorded.safeFilePath,
        ).thenAnswer((_) => Completer<String>().future);
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
            captureChromaKey: any(named: 'captureChromaKey'),
          ),
        ).thenAnswer(
          (invocation) => DivineVideoClip(
            id: 'recorded',
            video: recorded,
            duration: const Duration(seconds: 2),
            recordedAt: DateTime(2024),
            targetAspectRatio: model.AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
            captureChromaKey:
                invocation.namedArguments[#captureChromaKey] as ClipChromaKey?,
          ),
        );
        when(
          () => clipManager.saveClipToLibrary(any()),
        ).thenAnswer((_) async => true);
      });

      ClipChromaKey? recordedIntent() =>
          verify(
                () => clipManager.addClip(
                  video: any(named: 'video'),
                  originalAspectRatio: any(named: 'originalAspectRatio'),
                  targetAspectRatio: any(named: 'targetAspectRatio'),
                  lensMetadata: any(named: 'lensMetadata'),
                  limitClipDuration: any(named: 'limitClipDuration'),
                  captureChromaKey: captureAny(named: 'captureChromaKey'),
                ),
              ).captured.single
              as ClipChromaKey?;

      final backdropKey = const ClipChromaKey(
        key: ChromaKey.blueScreen(),
      ).withColorBackground(const Color(0xFF445566));

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'hands the chroma-key key to the clip as an intent',
        build: () => buildBloc()
          ..emit(
            chromaKeyState.copyWith(
              recordingState: VideoRecorderState.recording,
              chromaKey: backdropKey,
            ),
          ),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
        verify: (_) => expect(recordedIntent(), backdropKey),
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'records no intent outside chroma key mode',
        build: () => buildBloc()
          ..emit(
            VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
              chromaKey: backdropKey,
            ),
          ),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
        verify: (_) => expect(recordedIntent(), isNull),
      );

      test('hands the backdrop image over to the recorded clip', () async {
        final image = File('${tempDir.path}/chroma_bg.png')
          ..writeAsStringSync('');
        final bloc = buildBloc()..emit(chromaKeyState);
        bloc.add(VideoRecorderChromaKeyBackdropSet.image(image.path));
        await pumpEventQueue();
        bloc.emit(
          bloc.state.copyWith(recordingState: VideoRecorderState.recording),
        );

        bloc.add(const VideoRecorderRecordingStopRequested());
        await pumpEventQueue();
        await bloc.close();

        // The clip owns it now; closing the recorder must not delete it.
        expect(recordedIntent()?.backgroundImagePath, image.path);
        expect(image.existsSync(), isTrue);
      });
    });

    group('background chroma-key bakes', () {
      test('are held while a take starts and records', () {
        final bloc = buildBloc()..emit(chromaKeyState);
        addTearDown(bloc.close);

        bloc
          ..emit(bloc.state.copyWith(isStartingRecording: true))
          ..emit(
            bloc.state.copyWith(
              isStartingRecording: false,
              recordingState: VideoRecorderState.recording,
            ),
          );

        // The camera's encoder gets the hardware to itself.
        verify(() => clipManager.holdCapturedChromaKeyBakes()).called(1);
        verifyNever(() => clipManager.releaseCapturedChromaKeyBakes());

        bloc.emit(bloc.state.copyWith(recordingState: VideoRecorderState.idle));

        verify(() => clipManager.releaseCapturedChromaKeyBakes()).called(1);
      });

      test('are let go when the recorder closes mid-take', () async {
        final bloc = buildBloc()
          ..emit(
            chromaKeyState.copyWith(
              recordingState: VideoRecorderState.recording,
            ),
          );

        await bloc.close();

        verify(() => clipManager.holdCapturedChromaKeyBakes()).called(1);
        verify(() => clipManager.releaseCapturedChromaKeyBakes()).called(1);
      });

      test('bake a take once its post-processing is done', () async {
        stubStopReads();
        final recorded = _MockEditorVideo();
        // Post-processing fails straight away, which ends it just the same.
        when(
          recorded.safeFilePath,
        ).thenAnswer((_) async => throw Exception('no file'));
        when(
          () => cameraService.stopRecording(),
        ).thenAnswer((_) async => recorded);
        final take = DivineVideoClip(
          id: 'recorded',
          video: EditorVideo.file('/documents/raw.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime(2024),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          captureChromaKey: const ClipChromaKey(key: ChromaKey.greenScreen()),
        );
        when(
          () => clipManager.addClip(
            video: any(named: 'video'),
            originalAspectRatio: any(named: 'originalAspectRatio'),
            targetAspectRatio: any(named: 'targetAspectRatio'),
            lensMetadata: any(named: 'lensMetadata'),
            limitClipDuration: any(named: 'limitClipDuration'),
            captureChromaKey: any(named: 'captureChromaKey'),
          ),
        ).thenReturn(take);
        when(
          () => clipManager.saveClipToLibrary(any()),
        ).thenAnswer((_) async => true);
        when(() => clipManager.getClipById('recorded')).thenReturn(take);
        when(
          () => clipManager.bakeCapturedChromaKey(any()),
        ).thenAnswer((_) async => take);
        final bloc = buildBloc()
          ..emit(
            chromaKeyState.copyWith(
              recordingState: VideoRecorderState.recording,
            ),
          );
        addTearDown(bloc.close);

        bloc.add(const VideoRecorderRecordingStopRequested());
        await pumpEventQueue();

        final baked =
            verify(
                  () => clipManager.bakeCapturedChromaKey(captureAny()),
                ).captured.single
                as DivineVideoClip;
        expect(baked.id, 'recorded');
      });
    });
  });
}
