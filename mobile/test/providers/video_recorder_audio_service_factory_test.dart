import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_service/sound_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import '../mocks/mock_camera_service.dart';

class _MockAudioPlaybackService extends Mock implements AudioPlaybackService {}

class _MockClipManager extends Mock implements ClipManagerNotifier {}

class _MockVideoEditor extends Mock implements VideoEditorNotifier {}

class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    wakelockPlusPlatformInstance = _FakeWakelockPlatform();
  });

  group('VideoRecorderBloc - Audio Playback Service Factory (#4539)', () {
    test(
      'RecordingStartRequested uses the injected AudioPlaybackService '
      'factory when a sound is selected',
      () async {
        final mockAudioPlaybackService = _MockAudioPlaybackService();
        when(
          mockAudioPlaybackService.configureForRecording,
        ).thenAnswer((_) async {});
        when(
          () => mockAudioPlaybackService.loadAudio(any()),
        ).thenAnswer((_) async => const Duration(seconds: 6));
        when(mockAudioPlaybackService.play).thenAnswer((_) async {});
        when(mockAudioPlaybackService.stop).thenAnswer((_) async {});
        when(
          mockAudioPlaybackService.resetAudioSession,
        ).thenAnswer((_) async {});
        when(mockAudioPlaybackService.dispose).thenAnswer((_) async {});

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final mockCamera = MockCameraService.create(
          onUpdateState: ({forceCameraRebuild}) {},
          onAutoStopped: (_) {},
        );
        await mockCamera.initialize();

        final selectedSound = AudioEvent(
          id: 'sound_123',
          pubkey: 'test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          createdAt: 1700000000,
          title: 'Test Sound',
          duration: 6.0,
          url: 'https://example.com/audio/sound_123.m4a',
          mimeType: 'audio/mp4',
        );

        final clipManager = _MockClipManager();
        when(() => clipManager.remainingDuration).thenReturn(
          const Duration(seconds: 6),
        );
        when(() => clipManager.totalDuration).thenReturn(Duration.zero);
        when(clipManager.startRecording).thenReturn(null);
        when(clipManager.stopRecording).thenReturn(null);
        when(clipManager.resetRecording).thenReturn(null);

        final videoEditor = _MockVideoEditor();
        final editorState = VideoEditorProviderState(
          selectedSound: selectedSound,
        );

        var factoryCalls = 0;
        final bloc = VideoRecorderBloc(
          cameraService: mockCamera,
          readClipManager: () => clipManager,
          readVideoEditor: () => videoEditor,
          readVideoEditorState: () => editorState,
          readSharedPreferences: () => prefs,
          audioPlaybackServiceFactory: () {
            factoryCalls++;
            return mockAudioPlaybackService;
          },
        );
        addTearDown(bloc.close);

        bloc.add(const VideoRecorderRecordingStartRequested());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(factoryCalls, equals(1));
        verify(mockAudioPlaybackService.configureForRecording).called(1);
        verify(
          () => mockAudioPlaybackService.loadAudio(selectedSound.url!),
        ).called(1);
        verify(mockAudioPlaybackService.play).called(1);

        bloc.add(const VideoRecorderRecordingStopRequested());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        verify(mockAudioPlaybackService.stop).called(1);
        verify(mockAudioPlaybackService.resetAudioSession).called(1);
      },
    );
  });
}
