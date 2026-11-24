// ABOUTME: Tests that the recorder reports each take's start and stop once.
// ABOUTME: Covers recording_start and recording_stop outcomes from the bloc.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_camera/divine_camera.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';
import 'package:openvine/observability/recording_traces.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_service/sound_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import '../../helpers/recording_performance_monitor.dart';

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

class _MockCountdownSoundService extends Mock
    implements CountdownSoundService {}

/// Keeps `WakelockPlus` off the platform channel, which tests do not bind.
class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

void main() {
  group(VideoRecorderBloc, () {
    late _MockCameraService cameraService;
    late _MockClipManager clipManager;
    late RecordingPerformanceMonitor monitor;
    late WakelockPlusPlatformInterface previousWakelock;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      registerFallbackValue(Duration.zero);
      registerFallbackValue(model.AspectRatio.vertical);
      registerFallbackValue(Offset.zero);
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
      monitor = RecordingPerformanceMonitor();
      previousWakelock = wakelockPlusPlatformInstance;
      wakelockPlusPlatformInstance = _FakeWakelockPlatform();
    });

    tearDown(() => wakelockPlusPlatformInstance = previousWakelock);

    void stubRecorder() {
      when(() => cameraService.canRecord).thenReturn(true);
      when(() => cameraService.cameraAspectRatio).thenReturn(9 / 16);
      when(() => cameraService.currentLensMetadata).thenReturn(null);
      when(() => cameraService.dispose()).thenAnswer((_) async {});
      when(() => clipManager.clips).thenReturn(const []);
      when(
        () => clipManager.remainingDuration,
      ).thenReturn(const Duration(seconds: 6));
      when(() => clipManager.totalDuration).thenReturn(Duration.zero);
    }

    void stubNativeStart(Future<bool> Function() start) => when(
      () => cameraService.startRecording(
        maxDuration: any(named: 'maxDuration'),
      ),
    ).thenAnswer((_) => start());

    VideoRecorderBloc buildBloc({
      ReactionRecordingOwner? reactionRecordingOwner,
      CameraServiceFactory? cameraServiceFactory,
      CountdownSoundServiceFactory? countdownSoundServiceFactory,
    }) => VideoRecorderBloc(
      readClipManager: () => clipManager,
      readVideoEditor: _MockVideoEditor.new,
      readVideoEditorState: VideoEditorProviderState.new,
      readSharedPreferences: _MockSharedPreferences.new,
      reactionRecordingOwner: reactionRecordingOwner,
      cameraService: cameraServiceFactory == null ? cameraService : null,
      cameraServiceFactory: cameraServiceFactory ?? CameraService.create,
      countdownSoundServiceFactory: countdownSoundServiceFactory,
      performanceMonitor: monitor,
    );

    RecordedPerformanceTrace onlyTrace(String name) {
      final traces = monitor.traces.where((trace) => trace.name == name);
      expect(traces, hasLength(1), reason: '$name traces');
      return traces.single;
    }

    group('recording_start trace', () {
      setUp(stubRecorder);

      test(
        'reports a take that starts, with the settings it ran with',
        () async {
          stubNativeStart(() async => true);
          final bloc = buildBloc()
            ..emit(
              const VideoRecorderBlocState(
                videoStabilizationMode: DivineVideoStabilizationMode.cinematic,
                isDualCameraEnabled: true,
              ),
            );
          addTearDown(bloc.close);

          bloc.add(const VideoRecorderRecordingStartRequested());
          await pumpEventQueue();

          final trace = onlyTrace(RecordingStartTrace.traceName);
          expect(trace.stops, 1);
          expect(trace.attributes, {
            'outcome': 'success',
            'sound': 'off',
            'mode': 'capture',
            'stabilization': 'cinematic',
            'dual_camera': 'on',
          });
          expect(
            trace.metrics.keys,
            containsAll([
              'start_ms',
              'sound_prep_ms',
              'native_start_ms',
              'wakelock_ms',
            ]),
          );
          expect(trace.metrics, isNot(contains('countdown_ms')));
          expect(trace.metrics['chroma_key'], 0);
          expect(trace.metrics['reaction'], 0);
        },
      );

      test('reports a camera that refused to start as failed', () async {
        stubNativeStart(() async => false);
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(const VideoRecorderRecordingStartRequested());
        await pumpEventQueue();

        final trace = onlyTrace(RecordingStartTrace.traceName);
        expect(trace.stops, 1);
        expect(trace.attributes['outcome'], 'failed');
      });

      test('reports a start that navigation took the camera from as '
          'aborted', () async {
        final nativeStart = Completer<bool>();
        stubNativeStart(() => nativeStart.future);
        when(
          () => cameraService.stopRecording(),
        ).thenAnswer((_) async => null);
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(const VideoRecorderRecordingStartRequested());
        await pumpEventQueue();
        bloc.add(const VideoRecorderRecordingLockedForNavigation());
        await pumpEventQueue();
        nativeStart.complete(true);
        await pumpEventQueue();

        final trace = onlyTrace(RecordingStartTrace.traceName);
        expect(trace.stops, 1);
        expect(trace.attributes['outcome'], 'aborted');
        expect(trace.metrics, contains('native_start_ms'));
      });

      /// A countdown whose beeps play at once.
      _MockCountdownSoundService stubCountdown() {
        final sounds = _MockCountdownSoundService();
        when(sounds.preload).thenAnswer((_) async {});
        when(sounds.playShortBeep).thenAnswer((_) async {});
        when(sounds.playLongBeepAndWait).thenAnswer((_) async {});
        when(sounds.dispose).thenAnswer((_) async {});
        when(
          () => cameraService.setVolumeKeysEnabled(
            enabled: any(named: 'enabled'),
          ),
        ).thenAnswer((_) async => true);
        when(cameraService.suspendAudioCapture).thenAnswer((_) async {});
        when(cameraService.resumeAudioCapture).thenAnswer((_) async {});
        return sounds;
      }

      test('reports a reaction countdown the user stopped as aborted', () {
        final sounds = stubCountdown();

        fakeAsync((async) {
          final bloc =
              buildBloc(
                reactionRecordingOwner: (
                  clipManager: clipManager,
                  isCurrent: () => true,
                  retain: (_) async {},
                ),
                countdownSoundServiceFactory: () => sounds,
              )..emit(
                const VideoRecorderBlocState(
                  timerDuration: TimerDuration.three,
                ),
              );

          bloc.add(const VideoRecorderRecordingStartRequested());
          async
            ..flushMicrotasks()
            ..elapse(const Duration(milliseconds: 1500));
          bloc.add(const VideoRecorderRecordingStopRequested());
          async
            ..flushMicrotasks()
            ..elapse(const Duration(seconds: 3));

          verifyNever(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          );
          final trace = onlyTrace(RecordingStartTrace.traceName);
          expect(trace.stops, 1);
          expect(trace.attributes['outcome'], 'aborted');
          expect(trace.metrics['countdown_ms'], 1500);
          expect(trace.metrics['reaction'], 1);
          expect(
            monitor.traces.where(
              (t) => t.name == RecordingStopTrace.traceName,
            ),
            isEmpty,
          );

          unawaited(bloc.close());
          async.flushMicrotasks();
        });
      });

      test('keeps the countdown out of the start time', () {
        final sounds = stubCountdown();
        // The countdown ticks two full seconds, then the last one less the
        // "go" beep, which the mocked service plays at once.
        final countdown =
            const Duration(seconds: 3) -
            CountdownSoundService.longBeepDuration -
            CountdownSoundService.postPlaybackBuffer;

        fakeAsync((async) {
          // Made in the fake zone, so completing it runs on the fake clock.
          final nativeStart = Completer<bool>();
          stubNativeStart(() => nativeStart.future);
          final bloc = buildBloc(countdownSoundServiceFactory: () => sounds)
            ..emit(
              const VideoRecorderBlocState(timerDuration: TimerDuration.three),
            );

          bloc.add(const VideoRecorderRecordingStartRequested());
          async.elapse(countdown);
          verify(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          ).called(1);
          // The camera takes 200 ms to start writing once the countdown ends.
          async.elapse(const Duration(milliseconds: 200));
          nativeStart.complete(true);
          async.flushMicrotasks();

          final trace = onlyTrace(RecordingStartTrace.traceName);
          expect(trace.attributes['outcome'], 'success');
          expect(trace.metrics['countdown_ms'], countdown.inMilliseconds);
          expect(trace.metrics['start_ms'], 200);

          unawaited(bloc.close());
          async.flushMicrotasks();
        });
      });

      test('reports nothing for a start the recorder ignores', () async {
        when(() => cameraService.canRecord).thenReturn(false);
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(const VideoRecorderRecordingStartRequested());
        await pumpEventQueue();

        expect(monitor.traces, isEmpty);
      });
    });

    group('recording_stop trace', () {
      setUp(stubRecorder);

      VideoRecorderBlocState recording() => const VideoRecorderBlocState(
        recordingState: VideoRecorderState.recording,
      );

      test('reports a take the user stopped with a file as success', () async {
        final video = _MockEditorVideo();
        when(video.safeFilePath).thenAnswer((_) => Completer<String>().future);
        when(() => cameraService.stopRecording())
            .thenAnswer((_) async => video);
        when(
          () => clipManager.addClip(
            video: video,
            originalAspectRatio: any(named: 'originalAspectRatio'),
            targetAspectRatio: any(named: 'targetAspectRatio'),
            lensMetadata: any(named: 'lensMetadata'),
            limitClipDuration: any(named: 'limitClipDuration'),
            captureChromaKey: any(named: 'captureChromaKey'),
            secondaryRecording: any(named: 'secondaryRecording'),
            secondaryPipCenter: any(named: 'secondaryPipCenter'),
            secondaryPipScale: any(named: 'secondaryPipScale'),
            secondaryPipRotation: any(named: 'secondaryPipRotation'),
            secondaryPipAspectRatio: any(named: 'secondaryPipAspectRatio'),
          ),
        ).thenReturn(
          DivineVideoClip(
            id: 'take',
            video: video,
            duration: const Duration(seconds: 2),
            recordedAt: DateTime(2024),
            targetAspectRatio: model.AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
          ),
        );
        when(
          () => clipManager.saveClipToLibrary(any()),
        ).thenAnswer((_) async => true);
        final bloc = buildBloc()..emit(recording());
        addTearDown(bloc.close);

        bloc.add(const VideoRecorderRecordingStopRequested());
        await pumpEventQueue();

        final trace = onlyTrace(RecordingStopTrace.traceName);
        expect(trace.stops, 1);
        expect(trace.attributes, {
          'outcome': 'success',
          'trigger': 'user',
          'mode': 'capture',
          'stabilization': 'off',
          'dual_camera': 'off',
        });
        expect(
          trace.metrics.keys,
          containsAll(['stop_ms', 'native_stop_ms', 'wakelock_ms']),
        );
        expect(trace.metrics['secondary_file'], 0);
      });

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'reports a take the camera returned no file for as no_file',
        setUp: () => when(
          () => cameraService.stopRecording(),
        ).thenAnswer((_) async => null),
        build: () => buildBloc()..emit(recording()),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
        errors: () => [isA<RecordingProducedNoVideoException>()],
        verify: (_) {
          final trace = onlyTrace(RecordingStopTrace.traceName);
          expect(trace.stops, 1);
          expect(trace.attributes['outcome'], 'no_file');
          expect(trace.attributes['trigger'], 'user');
        },
      );

      test('reports a take the camera ended itself as auto', () async {
        late void Function(EditorVideo? video) autoStop;
        when(() => cameraService.stopRecording()).thenAnswer((_) async => null);
        final bloc = buildBloc(
          cameraServiceFactory:
              ({
                required onUpdateState,
                required onAutoStopped,
                onScreenFlashChanged,
              }) {
                autoStop = onAutoStopped;
                return cameraService;
              },
        )..emit(recording());
        addTearDown(bloc.close);

        autoStop(null);
        await pumpEventQueue();

        final trace = onlyTrace(RecordingStopTrace.traceName);
        expect(trace.attributes['trigger'], 'auto');
        expect(trace.attributes['outcome'], 'no_file');
      });

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'reports a stop that threw as error',
        setUp: () => when(
          () => cameraService.stopRecording(),
        ).thenThrow(Exception('native stop failed')),
        build: () => buildBloc()..emit(recording()),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
        errors: () => [isA<Exception>()],
        verify: (_) {
          final trace = onlyTrace(RecordingStopTrace.traceName);
          expect(trace.stops, 1);
          expect(trace.attributes['outcome'], 'error');
        },
      );

      test('reports a stop asked for during the start once the take runs, '
          'with its length', () async {
        final nativeStart = Completer<bool>();
        stubNativeStart(() => nativeStart.future);
        when(() => cameraService.stopRecording()).thenAnswer((_) async => null);
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(const VideoRecorderRecordingStartRequested());
        await pumpEventQueue();
        bloc.add(const VideoRecorderRecordingStopRequested());
        await pumpEventQueue();

        expect(
          monitor.traces.where((t) => t.name == RecordingStopTrace.traceName),
          isEmpty,
        );

        nativeStart.complete(true);
        await pumpEventQueue();

        expect(onlyTrace(RecordingStartTrace.traceName).stops, 1);
        final stop = onlyTrace(RecordingStopTrace.traceName);
        expect(stop.stops, 1);
        expect(stop.attributes['trigger'], 'user');
        expect(stop.metrics, contains('take_ms'));
      });
    });
  });
}
