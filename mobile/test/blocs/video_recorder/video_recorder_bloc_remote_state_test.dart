// ABOUTME: Tests what the recorder tells remote controls (the Apple Watch):
// ABOUTME: when it is open, the clip budget spent, and when a take started.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:divine_camera/divine_camera.dart' show RemoteRecorderState;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _MockCameraService extends Mock implements CameraService {}

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

  group('VideoRecorderBloc remote recorder state', () {
    final now = DateTime.utc(2026, 11, 16, 12);
    const openRecorder = VideoRecorderBlocState(isCameraInitialized: true);

    late _MockCameraService camera;
    late _MockClipManager clipManager;
    late List<RemoteRecorderState?> published;
    late VideoEditorProviderState editorState;
    late WakelockPlusPlatformInterface previousWakelock;

    setUp(() {
      camera = _MockCameraService();
      clipManager = _MockClipManager();
      published = [];
      editorState = VideoEditorProviderState();
      previousWakelock = wakelockPlusPlatformInstance;
      wakelockPlusPlatformInstance = _FakeWakelockPlatform();
      when(camera.dispose).thenAnswer((_) async {});
      when(clipManager.holdCapturedChromaKeyBakes).thenReturn(null);
      when(clipManager.releaseCapturedChromaKeyBakes).thenReturn(null);
    });

    tearDown(() {
      wakelockPlusPlatformInstance = previousWakelock;
    });

    void stubClips({required Duration total, Duration take = Duration.zero}) {
      when(() => clipManager.totalDuration).thenReturn(total);
      when(() => clipManager.activeRecordingDuration).thenReturn(take);
    }

    VideoRecorderBloc buildBloc() => VideoRecorderBloc(
      readClipManager: () => clipManager,
      readVideoEditor: _MockVideoEditor.new,
      readVideoEditorState: () => editorState,
      readSharedPreferences: _MockSharedPreferences.new,
      cameraService: camera,
      publishRemoteRecorderState: (state) async => published.add(state),
    );

    test('publishes nothing before the camera is up', () {
      final bloc = buildBloc()
        ..emit(const VideoRecorderBlocState(zoomLevel: 2));
      addTearDown(bloc.close);

      expect(published, isEmpty);
    });

    test('publishes the clip budget spent once the camera is up', () {
      stubClips(total: const Duration(milliseconds: 3900));
      final bloc = buildBloc()..emit(openRecorder);
      addTearDown(bloc.close);

      expect(published, hasLength(1));
      final state = published.single!;
      expect(state.recorded, equals(const Duration(milliseconds: 3900)));
      expect(state.activeTakeStartedAt, isNull);
      expect(state.budget, equals(VideoEditorConstants.maxDuration));
      expect(state.modeName, equals(VideoRecorderMode.capture.label));
    });

    test('publishes when the running take started', () {
      stubClips(total: const Duration(seconds: 2));
      final bloc = buildBloc()..emit(openRecorder);
      addTearDown(bloc.close);
      stubClips(
        total: const Duration(seconds: 2),
        take: const Duration(milliseconds: 40),
      );

      withClock(Clock.fixed(now), () {
        bloc.emit(
          openRecorder.copyWith(recordingState: VideoRecorderState.recording),
        );
      });

      final state = published.last!;
      expect(state.recorded, equals(const Duration(seconds: 2)));
      expect(
        state.activeTakeStartedAt,
        equals(now.subtract(const Duration(milliseconds: 40))),
      );
      expect(state.isShutterActive, isTrue);
    });

    test('reports an idle shutter while nothing runs', () {
      stubClips(total: const Duration(seconds: 2));
      final bloc = buildBloc()..emit(openRecorder);
      addTearDown(bloc.close);

      expect(published.last!.isShutterActive, isFalse);
    });

    test(
      'keeps the Classic budget visible when the shutter cannot start',
      () async {
        const fullBudget = VideoEditorConstants.maxDuration;
        stubClips(total: fullBudget);
        const classic = VideoRecorderBlocState(
          isCameraInitialized: true,
          canRecord: true,
          recorderMode: VideoRecorderMode.classic,
        );
        final bloc = buildBloc()..emit(classic);
        addTearDown(bloc.close);

        expect(published.last!.recorded, fullBudget);
        expect(published.last!.toMap()['shutterEnabled'], isFalse);

        stubClips(total: const Duration(seconds: 1));
        bloc.add(const VideoRecorderRemoteStateRefreshRequested());
        await pumpEventQueue();

        expect(published.last!.recorded, const Duration(seconds: 1));
        expect(published.last!.toMap()['shutterEnabled'], isTrue);
      },
    );

    test(
      'reports an active shutter while stop-motion captures on its interval',
      () {
        stubClips(total: Duration.zero);
        const stopMotion = VideoRecorderBlocState(
          isCameraInitialized: true,
          recorderMode: VideoRecorderMode.stopMotion,
        );
        final bloc = buildBloc()..emit(stopMotion);
        addTearDown(bloc.close);
        expect(published.last!.isShutterActive, isFalse);

        bloc.emit(stopMotion.copyWith(isIntervalCaptureRunning: true));

        final state = published.last!;
        expect(state.isShutterActive, isTrue);
        expect(state.activeTakeStartedAt, isNull);

        bloc.emit(stopMotion);

        expect(published.last!.isShutterActive, isFalse);
      },
    );

    test('publishes again when a stop-motion frame is taken', () {
      stubClips(total: Duration.zero);
      const stopMotion = VideoRecorderBlocState(
        isCameraInitialized: true,
        recorderMode: VideoRecorderMode.stopMotion,
      );
      final bloc = buildBloc()..emit(stopMotion);
      addTearDown(bloc.close);
      expect(published.single!.stillShutterCount, equals(0));

      bloc.emit(stopMotion.copyWith(stopMotionShutterTick: 1));

      expect(published, hasLength(2));
      final state = published.last!;
      expect(state.stillShutterCount, equals(1));
      expect(state.isShutterActive, isFalse);
    });

    test('reports an active shutter during the countdown before a take', () {
      stubClips(total: const Duration(seconds: 2));
      final bloc = buildBloc()..emit(openRecorder);
      addTearDown(bloc.close);

      bloc.emit(
        openRecorder.copyWith(
          recordingState: VideoRecorderState.recording,
          isStartingRecording: true,
        ),
      );

      final state = published.last!;
      expect(state.isShutterActive, isTrue);
      expect(state.activeTakeStartedAt, isNull);
    });

    test('counts a take being finalized as recorded time', () {
      stubClips(
        total: const Duration(seconds: 2),
        take: const Duration(seconds: 3),
      );
      final bloc = buildBloc()
        ..emit(
          openRecorder.copyWith(
            recordingState: VideoRecorderState.recording,
            isStoppingRecording: true,
          ),
        );
      addTearDown(bloc.close);

      final state = published.single!;
      expect(state.recorded, equals(const Duration(seconds: 5)));
      expect(state.activeTakeStartedAt, isNull);
      expect(state.toMap()['shutterEnabled'], isFalse);
    });

    test('does not publish again while nothing a remote shows changed', () {
      stubClips(total: const Duration(seconds: 1));
      final bloc = buildBloc()
        ..emit(openRecorder)
        ..emit(openRecorder.copyWith(zoomLevel: 3));
      addTearDown(bloc.close);

      expect(published, hasLength(1));
    });

    test('reports the recorder closed on the Upload tab', () {
      stubClips(total: Duration.zero);
      final bloc = buildBloc()
        ..emit(openRecorder)
        ..emit(openRecorder.copyWith(recorderMode: VideoRecorderMode.upload));
      addTearDown(bloc.close);

      expect(published, hasLength(2));
      expect(published.last, isNull);
    });

    test(
      'reports shutter availability when a sheet opens and closes',
      () async {
        stubClips(total: Duration.zero);
        final bloc = buildBloc()..emit(openRecorder);
        addTearDown(bloc.close);

        bloc.add(const VideoRecorderRemoteRecordPaused());
        await pumpEventQueue();
        expect(published, [isNotNull, isNull]);

        bloc.add(const VideoRecorderRemoteRecordResumed());
        await pumpEventQueue();
        expect(published, [isNotNull, isNull, isNotNull]);
      },
    );

    test('reports the recorder closed while a sound is selected', () async {
      stubClips(total: Duration.zero);
      final bloc = buildBloc()..emit(openRecorder);
      addTearDown(bloc.close);
      expect(published, [isNotNull]);

      editorState = VideoEditorProviderState(
        selectedSound: AudioEvent(
          id: 'sound',
          pubkey: 'a' * 64,
          createdAt: 0,
          url: 'https://example.com/audio.mp3',
        ),
      );
      bloc.add(const VideoRecorderRemoteStateRefreshRequested());
      await pumpEventQueue();
      expect(published, [isNotNull, isNull]);

      editorState = VideoEditorProviderState();
      bloc.add(const VideoRecorderRemoteStateRefreshRequested());
      await pumpEventQueue();
      expect(published, [isNotNull, isNull, isNotNull]);
    });

    test('reports the recorder closed once navigation locks recording', () {
      stubClips(total: Duration.zero);
      final bloc = buildBloc()
        ..emit(openRecorder)
        ..emit(openRecorder.copyWith(recordingLockedForNavigation: true));
      addTearDown(bloc.close);

      expect(published, hasLength(2));
      expect(published.last, isNull);
    });

    test('publishes the new total when the clips changed', () async {
      stubClips(total: const Duration(seconds: 4));
      final bloc = buildBloc()..emit(openRecorder);
      addTearDown(bloc.close);
      stubClips(total: const Duration(seconds: 1));

      bloc.add(const VideoRecorderRemoteStateRefreshRequested());
      await pumpEventQueue();

      expect(published, hasLength(2));
      expect(published.last!.recorded, equals(const Duration(seconds: 1)));
    });

    test('reports the recorder closed when it closes', () {
      fakeAsync((async) {
        stubClips(total: Duration.zero);
        final bloc = buildBloc()..emit(openRecorder);
        expect(published.single, isNotNull);

        unawaited(bloc.close());
        async.flushMicrotasks();

        expect(bloc.isClosed, isTrue);
        expect(published, hasLength(2));
        expect(published.last, isNull);
      });
    });
  });
}
