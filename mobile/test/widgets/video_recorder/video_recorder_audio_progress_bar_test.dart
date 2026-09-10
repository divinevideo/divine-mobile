// ABOUTME: Tests for VideoRecorderAudioProgressBar widget
// ABOUTME: Validates waveform rendering, visibility, and progress states

import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/sound_waveform/sound_waveform_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_audio_progress_bar.dart';
import 'package:pro_video_editor/core/models/video/editor_video_model.dart';

class _MockSoundWaveformBloc
    extends MockBloc<SoundWaveformEvent, SoundWaveformState>
    implements SoundWaveformBloc {}

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

/// Helper to create test AudioEvent instances
AudioEvent _createTestAudioEvent({
  String id = 'test-sound-id',
  String pubkey = 'test-pubkey',
  int createdAt = 1704067200,
  String? url,
  String? title,
  double? duration,
}) {
  return AudioEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    url: url ?? 'https://example.com/audio/$id.mp3',
    title: title ?? 'Test Sound',
    duration: duration ?? 5.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderAudioProgressBar, () {
    late _MockSoundWaveformBloc mockBloc;
    late _MockVideoRecorderBloc recorderBloc;

    final testWaveformData = Float32List.fromList([
      0.1,
      0.3,
      0.5,
      0.8,
      0.6,
      0.4,
      0.2,
      0.9,
      0.7,
      0.5,
    ]);

    setUp(() {
      mockBloc = _MockSoundWaveformBloc();
      recorderBloc = _MockVideoRecorderBloc();
      when(
        () => recorderBloc.state,
      ).thenReturn(const VideoRecorderBlocState());
    });

    Widget buildWidget({
      VideoRecorderState recordingState = VideoRecorderState.idle,
      AudioEvent? selectedSound,
      SoundWaveformState? waveformState,
      List<DivineVideoClip>? clips,
      Duration activeRecordingDuration = Duration.zero,
    }) {
      when(
        () => mockBloc.state,
      ).thenReturn(waveformState ?? const SoundWaveformInitial());
      when(
        () => recorderBloc.state,
      ).thenReturn(VideoRecorderBlocState(recordingState: recordingState));

      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(
            () => _TestVideoEditorNotifier(selectedSound: selectedSound),
          ),
          clipManagerProvider.overrideWith(
            () => _TestClipManagerNotifier(
              clips: clips ?? [],
              activeRecordingDuration: activeRecordingDuration,
            ),
          ),
        ],
        child: BlocProvider<VideoRecorderBloc>.value(
          value: recorderBloc,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Stack(
                children: [
                  BlocProvider<SoundWaveformBloc>.value(
                    value: mockBloc,
                    child: const VideoRecorderAudioProgressBar(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    group('Visibility', () {
      testWidgets('shows SizedBox.shrink when not recording', (tester) async {
        await tester.pumpWidget(
          buildWidget(selectedSound: _createTestAudioEvent()),
        );
        await tester.pumpAndSettle();

        // Should show empty SizedBox with specific key
        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsOneWidget,
        );
      });

      testWidgets('shows SizedBox.shrink when no sound selected', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsOneWidget,
        );
      });

      testWidgets('shows SizedBox.shrink when not recording and no sound', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsOneWidget,
        );
      });
    });

    group('Loading state', () {
      testWidgets('shows placeholder when waveform is loading', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: const SoundWaveformLoading(),
          ),
        );
        await tester.pumpAndSettle();

        // Should find at least one CustomPaint (the waveform placeholder)
        expect(find.byType(CustomPaint), findsWidgets);
        // And importantly NOT the empty state key
        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsNothing,
        );
      });

      testWidgets('shows placeholder when waveform has error', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: const SoundWaveformError(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CustomPaint), findsWidgets);
        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsNothing,
        );
      });
    });

    group('Loaded state', () {
      testWidgets('renders waveform when loaded', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: SoundWaveformLoaded(
              leftChannel: testWaveformData,
              rightChannel: testWaveformData,
              duration: const Duration(seconds: 5),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show the waveform (CustomPaint used for rendering)
        expect(find.byType(CustomPaint), findsWidgets);
        // And NOT the empty state
        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsNothing,
        );
      });

      testWidgets('aligns its content to the top', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: SoundWaveformLoaded(
              leftChannel: testWaveformData,
              duration: const Duration(seconds: 5),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final align = tester.widget<Align>(
          find
              .descendant(
                of: find.byType(VideoRecorderAudioProgressBar),
                matching: find.byType(Align),
              )
              .first,
        );
        expect(align.alignment, Alignment.topCenter);
      });

      testWidgets('uses SafeArea for status bar padding', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: SoundWaveformLoaded(
              leftChannel: testWaveformData,
              duration: const Duration(seconds: 5),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SafeArea), findsOneWidget);
      });
    });

    group('Progress tracking', () {
      testWidgets('renders with existing clips progress', (tester) async {
        final clips = [
          DivineVideoClip(
            id: 'clip1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        ];

        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: SoundWaveformLoaded(
              leftChannel: testWaveformData,
              duration: const Duration(seconds: 5),
            ),
            clips: clips,
          ),
        );
        await tester.pumpAndSettle();

        // Should render the waveform with clip progress
        expect(find.byType(CustomPaint), findsWidgets);
        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsNothing,
        );
      });

      testWidgets('renders with active recording duration', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: SoundWaveformLoaded(
              leftChannel: testWaveformData,
              duration: const Duration(seconds: 5),
            ),
            activeRecordingDuration: const Duration(seconds: 3),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CustomPaint), findsWidgets);
        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsNothing,
        );
      });
    });

    group('Animation', () {
      testWidgets('uses AnimatedSwitcher for transitions', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
          ),
        );

        expect(find.byType(AnimatedSwitcher), findsOneWidget);
      });
    });

    group('Initial state', () {
      testWidgets('shows empty content when waveform is in initial state', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: const SoundWaveformInitial(),
          ),
        );
        await tester.pumpAndSettle();

        // Initial state shows SizedBox.shrink (no waveform data yet)
        // but NOT the "not recording" empty state
        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsNothing,
        );
        // The VideoRecorderAudioProgressBar renders
        expect(find.byType(VideoRecorderAudioProgressBar), findsOneWidget);
      });
    });
  });
}

/// Test notifier for VideoEditorProvider
class _TestVideoEditorNotifier extends VideoEditorNotifier {
  _TestVideoEditorNotifier({this.selectedSound});

  final AudioEvent? selectedSound;

  @override
  VideoEditorProviderState build() {
    return VideoEditorProviderState(selectedSound: selectedSound);
  }
}

/// Test notifier for ClipManagerProvider
class _TestClipManagerNotifier extends ClipManagerNotifier {
  _TestClipManagerNotifier({
    required this.clips,
    required this.activeRecordingDuration,
  });

  @override
  final List<DivineVideoClip> clips;
  final Duration activeRecordingDuration;

  @override
  ClipManagerState build() {
    return ClipManagerState(
      clips: clips,
      activeRecordingDuration: activeRecordingDuration,
    );
  }
}
