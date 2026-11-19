// ABOUTME: Tests dual-camera capture in the recorder: the toggle and its
// ABOUTME: restore, the second camera's window, and each take's second file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import '../../mocks/mock_path_provider_platform.dart';

class _MockDualCameraService extends Mock
    implements CameraService, DualCameraCapture {}

class _MockClipManager extends Mock implements ClipManagerNotifier {
  int generation = 0;

  @override
  int get sessionGeneration => generation;

  @override
  bool isSessionCurrent(int expected) => generation == expected;
}

class _GatedProVideoEditor extends Fake
    with MockPlatformInterfaceMixin
    implements ProVideoEditor {
  final thumbnailStarted = Completer<void>();
  final thumbnail = Completer<List<Uint8List>>();

  @override
  Future<List<Uint8List>> getThumbnails(
    ThumbnailConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) {
    thumbnailStarted.complete();
    return thumbnail.future;
  }
}

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
    late SharedPreferences prefs;
    late bool dualEnabled;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
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
      bool liveChromaKeySupported = false,
      VideoEditorNotifier? videoEditor,
      ReactionRecordingOwner? reactionRecordingOwner,
    }) =>
        VideoRecorderBloc(
          readClipManager: () => clipManager,
          readVideoEditor: () => videoEditor ?? _MockVideoEditor(),
          readVideoEditorState: VideoEditorProviderState.new,
          readSharedPreferences: () => prefs,
          cameraService: camera,
          liveChromaKeySupported: liveChromaKeySupported,
          reactionRecordingOwner: reactionRecordingOwner,
        )..emit(
          VideoRecorderBlocState(
            recorderMode: mode,
            recordingState: recordingState,
            isLiveChromaKeySupported: liveChromaKeySupported,
          ),
        );

    group(VideoRecorderDualCameraToggled, () {
      setUp(stubCamera);

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'keeps one camera for a Library reaction',
        build: () => buildBloc(
          reactionRecordingOwner: (
            clipManager: clipManager,
            isCurrent: () => true,
            retain: (_) async {},
          ),
        ),
        act: (bloc) => bloc.add(const VideoRecorderDualCameraToggled()),
        verify: (bloc) {
          expect(bloc.state.isDualCameraSupported, isFalse);
          expect(bloc.state.isDualCameraEnabled, isFalse);
          verifyNever(() => camera.setDualCameraEnabled(enabled: true));
        },
      );

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

    group('reopening the camera', () {
      setUpAll(() {
        registerFallbackValue(DivineVideoQuality.fhd);
        registerFallbackValue(DivineCameraLens.back);
        registerFallbackValue(DivineVideoStabilizationMode.off);
      });

      setUp(() {
        stubCamera();
        // A camera opens with one camera, whatever the last one ran.
        when(
          () => camera.initialize(
            videoQuality: any(named: 'videoQuality'),
            initialLens: any(named: 'initialLens'),
            enableAutoLensSwitch: any(named: 'enableAutoLensSwitch'),
            preferUnprocessedAudio: any(named: 'preferUnprocessedAudio'),
            videoStabilizationMode: any(named: 'videoStabilizationMode'),
            mirrorFrontCameraOutput: any(named: 'mirrorFrontCameraOutput'),
          ),
        ).thenAnswer((_) async => dualEnabled = false);
        when(() => camera.initializationError).thenReturn(null);
        when(
          () => camera.setRemoteRecordControlEnabled(
            enabled: any(named: 'enabled'),
          ),
        ).thenAnswer((_) async => true);
        when(() => clipManager.clips).thenReturn(const []);
      });

      /// Toggles dual capture [times] on a recorder, then reopens its camera
      /// the way returning from the editor or the library does.
      Future<VideoRecorderBloc> toggleAndReopen({required int times}) async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        for (var i = 0; i < times; i++) {
          bloc.add(const VideoRecorderDualCameraToggled());
          await pumpEventQueue();
        }
        bloc.add(const VideoRecorderInitializeRequested());
        await pumpEventQueue();
        return bloc;
      }

      test('turns dual-camera capture back on', () async {
        final bloc = await toggleAndReopen(times: 1);

        verify(() => camera.setDualCameraEnabled(enabled: true)).called(2);
        expect(bloc.state.isDualCameraEnabled, isTrue);
        expect(bloc.state.secondaryPreviewTextureId, equals(2));
        expect(bloc.state.isSwitchingCamera, isFalse);
      });

      test('stays on one camera when dual capture was turned off', () async {
        final bloc = await toggleAndReopen(times: 2);

        verify(() => camera.setDualCameraEnabled(enabled: true)).called(1);
        expect(bloc.state.isDualCameraEnabled, isFalse);
      });

      test('stays on one camera in a mode without dual capture', () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const VideoRecorderDualCameraToggled());
        await pumpEventQueue();
        bloc.emit(bloc.state.copyWith(recorderMode: VideoRecorderMode.classic));
        await prefs.setString(
          VideoRecorderMode.persistenceKey,
          VideoRecorderMode.classic.name,
        );

        bloc.add(const VideoRecorderInitializeRequested());
        await pumpEventQueue();

        verify(() => camera.setDualCameraEnabled(enabled: true)).called(1);
        expect(bloc.state.isDualCameraEnabled, isFalse);
      });

      test('opens a new recorder with one camera', () async {
        final previous = await toggleAndReopen(times: 1);
        expect(previous.state.isDualCameraEnabled, isTrue);
        await previous.close();

        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const VideoRecorderInitializeRequested());
        await pumpEventQueue();

        // The previous recorder's toggle and its own reopen, nothing since.
        verify(() => camera.setDualCameraEnabled(enabled: true)).called(2);
        expect(bloc.state.isDualCameraEnabled, isFalse);
      });
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
          final bloc = buildBloc(liveChromaKeySupported: true);
          return bloc..emit(
            bloc.state.copyWith(
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

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'turns dual-camera capture back on when the color mask goes off',
        build: () => buildBloc(liveChromaKeySupported: true),
        act: (bloc) async {
          bloc.add(const VideoRecorderDualCameraToggled());
          await pumpEventQueue();
          bloc.add(const VideoRecorderChromaKeyEnabledSet(enabled: true));
          await pumpEventQueue();
          bloc.add(const VideoRecorderChromaKeyEnabledSet(enabled: false));
        },
        verify: (bloc) {
          verify(() => camera.setDualCameraEnabled(enabled: true)).called(2);
          expect(bloc.state.isDualCameraEnabled, isTrue);
        },
      );
    });

    group('a change landing while the session rebuilds', () {
      late _MockVideoEditor videoEditor;

      /// The next rebuild, held until the test lets it return.
      late Completer<void> rebuild;

      setUp(() {
        stubCamera();
        registerFallbackValue(DivineVideoStabilizationMode.off);
        when(
          () => camera.setVideoStabilizationMode(any()),
        ).thenAnswer((_) async => true);
        when(
          () => clipManager.clearAll(
            keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
          ),
        ).thenAnswer((_) async {});
        videoEditor = _MockVideoEditor();
        when(
          () => videoEditor.resetForRecorderMode(
            keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
          ),
        ).thenAnswer((_) async {});
        rebuild = Completer<void>()..complete();
        when(
          () => camera.setDualCameraEnabled(enabled: any(named: 'enabled')),
        ).thenAnswer((invocation) async {
          await rebuild.future;
          dualEnabled = invocation.namedArguments[#enabled] as bool;
          return true;
        });
      });

      test('turns dual capture back off when the color mask goes on', () async {
        final bloc = buildBloc(liveChromaKeySupported: true);
        addTearDown(bloc.close);
        rebuild = Completer<void>();
        bloc.add(const VideoRecorderDualCameraToggled());
        await pumpEventQueue();

        bloc.add(const VideoRecorderChromaKeyEnabledSet(enabled: true));
        await pumpEventQueue();
        expect(bloc.state.isChromaKeyEnabled, isTrue);
        rebuild.complete();
        await pumpEventQueue();

        verify(() => camera.setDualCameraEnabled(enabled: true)).called(1);
        verify(() => camera.setDualCameraEnabled(enabled: false)).called(1);
        expect(bloc.state.isDualCameraEnabled, isFalse);
      });

      test('turns dual capture back off in a mode without it', () async {
        final bloc = buildBloc(videoEditor: videoEditor);
        addTearDown(bloc.close);
        rebuild = Completer<void>();
        bloc.add(const VideoRecorderDualCameraToggled());
        await pumpEventQueue();

        bloc.add(
          const VideoRecorderRecorderModeSet(VideoRecorderMode.stopMotion),
        );
        await pumpEventQueue();
        expect(bloc.state.recorderMode, VideoRecorderMode.stopMotion);
        rebuild.complete();
        await pumpEventQueue();

        verify(() => camera.setDualCameraEnabled(enabled: false)).called(1);
        expect(bloc.state.isDualCameraEnabled, isFalse);
      });

      test(
        'turns dual capture back on after a switch there and back',
        () async {
          final bloc = buildBloc(videoEditor: videoEditor);
          addTearDown(bloc.close);
          bloc.add(const VideoRecorderDualCameraToggled());
          await pumpEventQueue();
          expect(bloc.state.isDualCameraEnabled, isTrue);

          rebuild = Completer<void>();
          bloc.add(
            const VideoRecorderRecorderModeSet(VideoRecorderMode.stopMotion),
          );
          await pumpEventQueue();
          bloc.add(
            const VideoRecorderRecorderModeSet(VideoRecorderMode.capture),
          );
          await pumpEventQueue();
          expect(bloc.state.recorderMode, VideoRecorderMode.capture);
          rebuild.complete();
          await pumpEventQueue();

          verify(() => camera.setDualCameraEnabled(enabled: false)).called(1);
          verify(() => camera.setDualCameraEnabled(enabled: true)).called(2);
          expect(bloc.state.isDualCameraEnabled, isTrue);
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
        late DivineVideoClip captured;

        setUp(() {
          registerFallbackValue(Future<void>.value());
          captured = DivineVideoClip(
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
          );
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
          ).thenAnswer((_) => captured);
        });

        Future<void> trackEnrichmentCompletion() {
          final work = <Future<void>>[];
          final completed = Completer<void>();
          when(
            () => clipManager.trackClipEnrichment(any(), any()),
          ).thenAnswer((invocation) {
            work.add(invocation.positionalArguments[1] as Future<void>);
            // The recorder tracks the secondary poster, main enrichment,
            // and final composite separately.
            if (work.length == 3) {
              completed.complete(Future.wait(work).then<void>((_) {}));
            }
          });
          return completed.future;
        }

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

        test('does not give a pending poster to a reimported take', () async {
          final dir = Directory.systemTemp.createTempSync('second_poster_bloc');
          final editor = _GatedProVideoEditor();
          final originalEditor = ProVideoEditor.instance;
          final originalPaths = PathProviderPlatform.instance;
          ProVideoEditor.instance = editor;
          PathProviderPlatform.instance = MockPathProviderPlatform()
            ..setApplicationDocumentsPath(dir.path);
          addTearDown(() {
            ProVideoEditor.instance = originalEditor;
            PathProviderPlatform.instance = originalPaths;
            dir.deleteSync(recursive: true);
          });
          final secondaryFile = File('${dir.path}/second.mp4')
            ..writeAsStringSync('second camera footage');
          final take = captured.secondaryCamera!;
          captured = captured.copyWith(
            secondaryCamera: take.copyWith(
              clip: take.clip.copyWith(video: EditorVideo.file(secondaryFile)),
            ),
          );
          final finished = trackEnrichmentCompletion();
          final bloc = buildBloc(recordingState: VideoRecorderState.recording);
          addTearDown(bloc.close);

          bloc.add(const VideoRecorderRecordingStopRequested());
          await editor.thumbnailStarted.future;
          verify(() => clipManager.saveClipToLibrary(captured)).called(1);
          clipManager.generation++;
          final reimported = captured.copyWith(volume: 0.5);
          when(() => clipManager.getClipById(captured.id))
              .thenReturn(reimported);
          editor.thumbnail.complete([
            Uint8List.fromList([1, 2, 3]),
          ]);
          await finished;

          verifyNever(
            () => clipManager.updateSecondaryCameraClip(any(), any()),
          );
          expect(dir.listSync().map((entry) => entry.path), [
            secondaryFile.path,
          ]);
        });

        group('once both cameras have thumbnails', () {
          late Directory dir;
          late Completer<String> composed;
          late Completer<void> savedAgain;
          late DivineVideoClip enriched;

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
            enriched = DivineVideoClip(
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

          test('reclaims a composite if the take was reimported', () async {
            final finished = trackEnrichmentCompletion();
            final reimported = enriched.copyWith(volume: 0.5);
            var timeline = enriched;
            var lookups = 0;
            when(() => clipManager.getClipById(enriched.id)).thenAnswer((_) {
              // The poster checks the take first. The second lookup is the
              // composer's read of the inputs before it starts its isolate.
              if (++lookups == 2) {
                scheduleMicrotask(() {
                  clipManager.generation++;
                  timeline = reimported;
                });
              }
              return timeline;
            });
            final bloc = buildBloc(
              recordingState: VideoRecorderState.recording,
            );
            addTearDown(bloc.close);

            bloc.add(const VideoRecorderRecordingStopRequested());
            await finished;

            expect(timeline, same(reimported));
            verifyNever(
              () => clipManager.setSecondaryCameraThumbnail(
                any(),
                takeId: any(named: 'takeId'),
                path: any(named: 'path'),
              ),
            );
            expect(File('${dir.path}/main_dual.jpg').existsSync(), isFalse);
          });

          test(
            'does not resave a reimported take after proof finishes',
            () async {
              final finished = trackEnrichmentCompletion();
              final proofStarted = Completer<void>();
              final proofPending = Completer<void>();
              when(
                () => clipManager.waitForSecondaryCameraTakes(),
              ).thenAnswer((_) {
                proofStarted.complete();
                return proofPending.future;
              });
              final bloc = buildBloc(
                recordingState: VideoRecorderState.recording,
              );
              addTearDown(bloc.close);

              bloc.add(const VideoRecorderRecordingStopRequested());
              await proofStarted.future;
              clipManager.generation++;
              final reimported = enriched.copyWith(volume: 0.5);
              when(() => clipManager.getClipById(enriched.id))
                  .thenReturn(reimported);
              proofPending.complete();
              await finished;

              verifyNever(() => clipManager.saveClipToLibrary(reimported));
              expect(File('${dir.path}/main_dual.jpg').existsSync(), isFalse);
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
          'leaves the second file to the auto-stop that parked it',
          build: () => buildBloc(recordingState: VideoRecorderState.recording),
          act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
          errors: () => [isA<RecordingProducedNoVideoException>()],
          verify: (_) {
            verifyNever(() => camera.takeSecondaryRecording());
            expect(secondFile.existsSync(), isTrue);
          },
        );
      });
    });

    group('a take started as navigation takes the camera', () {
      late Directory dir;
      late File mainFile;
      late File secondFile;
      late Completer<bool> started;

      setUp(() {
        stubCamera();
        dir = Directory.systemTemp.createTempSync('dual_camera_abort');
        mainFile = File('${dir.path}/VID_3.mp4')..writeAsStringSync('mp4');
        secondFile = File('${dir.path}/VID_3_second.mp4')
          ..writeAsStringSync('mp4');
        started = Completer<bool>();
        when(
          () => clipManager.remainingDuration,
        ).thenReturn(const Duration(seconds: 60));
        when(
          () => camera.startRecording(maxDuration: any(named: 'maxDuration')),
        ).thenAnswer((_) => started.future);
        when(
          () => camera.stopRecording(),
        ).thenAnswer((_) async => EditorVideo.file(mainFile.path));
        when(
          () => camera.takeSecondaryRecording(),
        ).thenReturn(VideoRecordingResult(filePath: secondFile.path));
      });

      tearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      test("deletes both cameras' files", () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const VideoRecorderRecordingStartRequested());
        await pumpEventQueue();
        bloc.add(const VideoRecorderRecordingLockedForNavigation());
        await pumpEventQueue();

        started.complete(true);
        await pumpEventQueue();

        expect(bloc.state.isRecording, isFalse);
        expect(mainFile.existsSync(), isFalse);
        expect(secondFile.existsSync(), isFalse);
      });
    });
  });

  group('VideoRecorderBloc without dual-camera capture', () {
    late _SingleCameraService camera;

    setUp(() {
      camera = _SingleCameraService();
      when(camera.dispose).thenAnswer((_) async {});
    });

    // The toggle reaches the camera only through the optional
    // DualCameraCapture interface; a service without it must leave the
    // recorder untouched rather than blur it for a rebuild that never comes.
    blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
      'ignores the toggle on a camera service without dual capture',
      build: () => VideoRecorderBloc(
        readClipManager: _MockClipManager.new,
        readVideoEditor: _MockVideoEditor.new,
        readVideoEditorState: VideoEditorProviderState.new,
        readSharedPreferences: _MockSharedPreferences.new,
        cameraService: camera,
      ),
      act: (bloc) => bloc.add(const VideoRecorderDualCameraToggled()),
      expect: () => const <VideoRecorderBlocState>[],
    );
  });
}

class _SingleCameraService extends Mock implements CameraService {}
