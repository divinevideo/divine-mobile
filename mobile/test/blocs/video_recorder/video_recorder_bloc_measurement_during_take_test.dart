// ABOUTME: Tests a chroma-key wall measurement that outlives the moment it
// ABOUTME: was asked for: the take it must not re-key, the flash it restores.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:divine_camera/divine_camera.dart' show PhotoCaptureResult;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
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

/// What the wall measurement reports: a grey wall, far from the green preset
/// the recorder starts on.
const _measured = ChromaKeyDetection(
  color: Color(0xFFB0B8C0),
  similarity: 0.12,
  coverage: 0.95,
  spread: 0.04,
);

const _chromaKeyState = VideoRecorderBlocState(
  recorderMode: VideoRecorderMode.chromaKey,
);

void main() {
  late _MockCameraService cameraService;
  late _MockClipManager clipManager;
  late _MockVideoEditor videoEditor;
  late _MockSharedPreferences prefs;
  late Directory tempDir;
  late File still;
  late WakelockPlusPlatformInterface originalWakelock;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(DivineFlashMode.off);
    registerFallbackValue(EditorVideo.file('/fallback.mp4'));
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
    originalWakelock = wakelockPlusPlatformInstance;
    wakelockPlusPlatformInstance = _FakeWakelockPlatform();

    cameraService = _MockCameraService();
    clipManager = _MockClipManager();
    videoEditor = _MockVideoEditor();
    prefs = _MockSharedPreferences();
    tempDir = Directory.systemTemp.createTempSync('measurement_during_take');
    still = File('${tempDir.path}/still.jpg')..writeAsStringSync('jpg');
  });

  tearDown(() {
    wakelockPlusPlatformInstance = originalWakelock;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Stubs a camera that is up and can take a still.
  void stubReadyCamera() {
    when(() => cameraService.isInitialized).thenReturn(true);
    when(() => cameraService.isSwitchingCamera).thenReturn(false);
    when(() => cameraService.setFlashMode(any())).thenAnswer((_) async => true);
    when(
      () => cameraService.capturePhoto(
        outputDirectory: any(named: 'outputDirectory'),
      ),
    ).thenAnswer((_) async => PhotoCaptureResult(filePath: still.path));
    when(() => cameraService.dispose()).thenAnswer((_) async {});
  }

  VideoRecorderBloc buildBloc({required ChromaKeyStillDetector detect}) {
    final bloc = VideoRecorderBloc(
      readClipManager: () => clipManager,
      readVideoEditor: () => videoEditor,
      readVideoEditorState: VideoEditorProviderState.new,
      readSharedPreferences: () => prefs,
      cameraService: cameraService,
      liveChromaKeySupported: true,
      detectChromaKeyStill: detect,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  group('$VideoRecorderBloc wall measurement', () {
    group('landing after footage capture started', () {
      late _MockEditorVideo recorded;

      setUp(() {
        stubReadyCamera();
        // What a take reads off the camera and the clip manager.
        when(() => cameraService.canRecord).thenReturn(true);
        when(() => cameraService.cameraAspectRatio).thenReturn(9 / 16);
        when(() => cameraService.currentLensMetadata).thenReturn(null);
        when(() => clipManager.clips).thenReturn(const []);
        when(
          () => clipManager.remainingDuration,
        ).thenReturn(const Duration(seconds: 6));
        when(() => clipManager.totalDuration).thenReturn(Duration.zero);
        when(
          () => cameraService.startRecording(
            maxDuration: any(named: 'maxDuration'),
          ),
        ).thenAnswer((_) async => true);
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
            id: 'take',
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

      /// Measures, starts a take with [start] before the measurement lands,
      /// lets it land mid-take, and stops: returns the key the take started
      /// under.
      Future<ClipChromaKey> recordThroughMeasurement(
        VideoRecorderEvent start,
      ) async {
        final detectionGate = Completer<ChromaKeyDetection>();
        final detectionStarted = Completer<void>();
        final bloc = buildBloc(
          detect: (_, {required visibleAspectRatio}) {
            detectionStarted.complete();
            return detectionGate.future;
          },
        )..emit(_chromaKeyState);

        // The user taps Detect, and records before the still is measured.
        bloc.add(const VideoRecorderChromaKeyMeasureRequested());
        await detectionStarted.future;
        expect(bloc.state.isMeasuringChromaKey, isTrue);

        final capturing = bloc.stream.firstWhere(
          (state) => state.isCapturingFootage,
        );
        bloc.add(start);
        final keyAtFootageStart = (await capturing).chromaKey;

        // The measurement lands while the camera is writing the take.
        final landed = bloc.stream.firstWhere(
          (state) =>
              state.chromaKeyMeasurementStatus !=
              ChromaKeyMeasurementStatus.detecting,
        );
        detectionGate.complete(_measured);
        await landed;
        expect(bloc.state.isCapturingFootage, isTrue);

        final stopped = bloc.stream.firstWhere((state) => !state.isRecording);
        bloc.add(const VideoRecorderRecordingStopRequested());
        await stopped;
        await pumpEventQueue();

        expect(bloc.state.chromaKey.key.color, _measured.color);
        return keyAtFootageStart;
      }

      test(
        'records the take with the key that was in effect when footage '
        'capture started',
        () async {
          final keyAtFootageStart = await recordThroughMeasurement(
            const VideoRecorderRecordingStartRequested(),
          );

          // Every frame already written was keyed, in the viewfinder, against
          // keyAtFootageStart; the take has to carry that key.
          expect(
            recordedIntent(),
            keyAtFootageStart,
            reason:
                'the measurement that landed mid-take must not re-key frames '
                'captured before it landed',
          );
        },
      );

      test('does the same for a take a remote trigger started', () async {
        // What a volume key or a Bluetooth shutter dispatches.
        final keyAtFootageStart = await recordThroughMeasurement(
          const VideoRecorderRecordingToggleRequested(),
        );

        expect(recordedIntent(), keyAtFootageStart);
      });
    });

    group('while the flash is changed', () {
      late List<DivineFlashMode> flashCalls;

      setUp(() {
        stubReadyCamera();
        flashCalls = [];
        when(() => cameraService.setFlashMode(any())).thenAnswer((
          invocation,
        ) async {
          flashCalls.add(
            invocation.positionalArguments.single as DivineFlashMode,
          );
          return true;
        });
      });

      /// Holds the still until [gate] completes. The returned completer
      /// completes once the camera is asked for the still.
      Completer<void> holdStillUntil(Completer<PhotoCaptureResult?> gate) {
        final requested = Completer<void>();
        when(
          () => cameraService.capturePhoto(
            outputDirectory: any(named: 'outputDirectory'),
          ),
        ).thenAnswer((_) {
          requested.complete();
          return gate.future;
        });
        return requested;
      }

      VideoRecorderBloc measuringBloc() => VideoRecorderBloc(
        readClipManager: () => clipManager,
        readVideoEditor: () => videoEditor,
        readVideoEditorState: VideoEditorProviderState.new,
        readSharedPreferences: () => prefs,
        cameraService: cameraService,
        liveChromaKeySupported: true,
        detectChromaKeyStill: (_, {required visibleAspectRatio}) async =>
            _measured,
      )..emit(_chromaKeyState);

      test(
        'leaves the camera flash on the mode the recorder shows when it is '
        'changed while the still is taken',
        () async {
          final stillGate = Completer<PhotoCaptureResult?>();
          final stillRequested = holdStillUntil(stillGate);
          final bloc = measuringBloc();
          addTearDown(bloc.close);
          expect(bloc.state.flashMode, DivineFlashMode.auto);

          bloc.add(const VideoRecorderChromaKeyMeasureRequested());
          await stillRequested.future;

          final toggled = bloc.stream.firstWhere(
            (state) => state.flashMode != DivineFlashMode.auto,
          );
          bloc.add(const VideoRecorderFlashToggled());
          await toggled;

          final landed = bloc.stream.firstWhere(
            (state) =>
                state.chromaKeyMeasurementStatus !=
                ChromaKeyMeasurementStatus.detecting,
          );
          stillGate.complete(PhotoCaptureResult(filePath: still.path));
          await landed;
          // The measurement ran to its end: it measured and deleted the still.
          expect(still.existsSync(), isFalse);

          expect(
            flashCalls.last,
            bloc.state.flashMode,
            reason:
                'the last flash mode sent to the camera must be the one the '
                'recorder shows (calls: $flashCalls)',
          );
        },
      );

      test(
        'leaves the camera flash on the mode the recorder shows when it is '
        'changed after the measurement timed out',
        () {
          fakeAsync((async) {
            // Created inside the fake zone, so completing it resumes the
            // measurement on this zone's microtask queue.
            final stillGate = Completer<PhotoCaptureResult?>();
            holdStillUntil(stillGate);
            final bloc = measuringBloc();
            expect(bloc.state.flashMode, DivineFlashMode.auto);

            bloc.add(const VideoRecorderChromaKeyMeasureRequested());
            async
              ..flushMicrotasks()
              ..elapse(VideoEditorConstants.chromaKeyDetectTimeout);
            expect(
              bloc.state.chromaKeyMeasurementStatus,
              ChromaKeyMeasurementStatus.timedOut,
            );

            // The panel asks for a retry; the user turns the flash off.
            bloc.add(const VideoRecorderFlashToggled());
            async.flushMicrotasks();
            expect(bloc.state.flashMode, DivineFlashMode.off);

            // The stalled still comes back after all, and the measurement
            // that gave up on it runs on to its end.
            stillGate.complete(PhotoCaptureResult(filePath: still.path));
            async.flushMicrotasks();
            expect(still.existsSync(), isFalse);

            expect(
              flashCalls.last,
              bloc.state.flashMode,
              reason:
                  'the last flash mode sent to the camera must be the one '
                  'the recorder shows (calls: $flashCalls)',
            );

            unawaited(bloc.close());
            async.flushMicrotasks();
          });
        },
      );
    });
  });
}
