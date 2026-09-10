import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/lip_sync/video_recorder_lip_sync_stack.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_audio_progress_bar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_record_button.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderLipSyncStack, () {
    late _MockVideoRecorderBloc recorderBloc;
    late SharedPreferences testPrefs;
    late _TestClipManagerNotifier clipNotifier;
    late _TestVideoEditorNotifier editorNotifier;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      testPrefs = await SharedPreferences.getInstance();
      recorderBloc = _MockVideoRecorderBloc();
    });

    Widget buildWidget({
      VideoRecorderState recordingState = VideoRecorderState.idle,
      AudioEvent? selectedSound,
      List<DivineVideoClip>? clips,
    }) {
      when(() => recorderBloc.state).thenReturn(
        VideoRecorderBlocState(
          recordingState: recordingState,
          isCameraInitialized: true,
          canRecord: true,
        ),
      );

      clipNotifier = _TestClipManagerNotifier(clips: clips ?? []);
      editorNotifier = _TestVideoEditorNotifier(selectedSound: selectedSound);

      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(testPrefs),
          clipManagerProvider.overrideWith(() => clipNotifier),
          videoEditorProvider.overrideWith(() => editorNotifier),
        ],
        child: BlocProvider<VideoRecorderBloc>.value(
          value: recorderBloc,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoRecorderLipSyncStack()),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoRecorderLipSyncStack', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderLipSyncStack), findsOneWidget);
      });

      testWidgets('reuses $VideoRecorderCaptureStack', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderCaptureStack), findsOneWidget);
      });

      testWidgets('renders the $VideoEditorAudioChip in the top bar', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoEditorAudioChip), findsOneWidget);
      });

      testWidgets('wires in the $VideoRecorderAudioProgressBar', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderAudioProgressBar), findsOneWidget);
      });

      testWidgets('shows the add-audio label when no sound selected', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoEditorAudioAddAudio), findsOneWidget);
      });

      testWidgets('shows the selected sound title when a sound is selected', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            selectedSound: AudioEvent(
              id: 'sound-1',
              pubkey: 'pubkey',
              createdAt: 1704067200,
              url: 'https://example.com/audio/sound-1.mp3',
              title: 'My Sound',
              duration: 5,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('My Sound'), findsOneWidget);
      });
    });

    group('record button gating', () {
      AudioEvent sound(String id) => AudioEvent(
        id: id,
        pubkey: 'pubkey',
        createdAt: 1704067200,
        url: 'https://example.com/audio/$id.mp3',
        title: id,
        duration: 5,
      );

      testWidgets('blocks the record button when no sound is selected', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final recordButton = tester.widget<RecordButton>(
          find.byType(RecordButton),
        );
        expect(recordButton.onBlockedTap, isNotNull);
      });

      testWidgets('shows a snackbar when tapping the blocked record button', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(RecordButton));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.videoRecorderLipSyncAddAudioFirst),
          findsOneWidget,
        );
      });

      testWidgets('does not block the record button when a sound is selected', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(selectedSound: sound('a')));
        await tester.pumpAndSettle();

        final recordButton = tester.widget<RecordButton>(
          find.byType(RecordButton),
        );
        expect(recordButton.onBlockedTap, isNull);
      });
    });

    group('recording', () {
      testWidgets('hides the audio chip while recording', (tester) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(VideoEditorAudioChip), findsNothing);
      });
    });

    group('changing the sound selection', () {
      AudioEvent sound(String id) => AudioEvent(
        id: id,
        pubkey: 'pubkey',
        createdAt: 1704067200,
        url: 'https://example.com/audio/$id.mp3',
        title: id,
        duration: 5,
      );

      DivineVideoClip clip() => DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('/test/clip1.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      Future<void> changeSound(WidgetTester tester, AudioEvent? next) async {
        final chip = tester.widget<VideoEditorAudioChip>(
          find.byType(VideoEditorAudioChip),
        );
        chip.onSoundChanged(next);
        await tester.pumpAndSettle();
      }

      testWidgets('clears recorded clips when a different sound is selected', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(selectedSound: sound('a'), clips: [clip()]),
        );
        await tester.pumpAndSettle();

        await changeSound(tester, sound('b'));

        expect(clipNotifier.clearAllCallCount, 1);
        expect(editorNotifier.selectRecorderAudioTrackCalls, [sound('b')]);
      });

      testWidgets('does not clear clips when the same sound is reselected', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(selectedSound: sound('a'), clips: [clip()]),
        );
        await tester.pumpAndSettle();

        await changeSound(tester, sound('a'));

        expect(clipNotifier.clearAllCallCount, 0);
        expect(editorNotifier.selectRecorderAudioTrackCalls, [sound('a')]);
      });

      testWidgets('does not clear when there are no recorded clips', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(selectedSound: sound('a')));
        await tester.pumpAndSettle();

        await changeSound(tester, sound('b'));

        expect(clipNotifier.clearAllCallCount, 0);
        expect(editorNotifier.selectRecorderAudioTrackCalls, [sound('b')]);
      });
    });
  });
}

class _TestClipManagerNotifier extends ClipManagerNotifier {
  _TestClipManagerNotifier({required this.clips});

  @override
  final List<DivineVideoClip> clips;

  int clearAllCallCount = 0;

  @override
  ClipManagerState build() {
    return ClipManagerState(clips: clips);
  }

  @override
  Future<void> clearAll({bool keepAutosavedDraft = false}) async {
    clearAllCallCount++;
  }
}

class _TestVideoEditorNotifier extends VideoEditorNotifier {
  _TestVideoEditorNotifier({this.selectedSound});

  final AudioEvent? selectedSound;
  final List<AudioEvent?> selectRecorderAudioTrackCalls = [];

  @override
  VideoEditorProviderState build() {
    return VideoEditorProviderState(selectedSound: selectedSound);
  }

  @override
  void selectRecorderAudioTrack(AudioEvent? sound) {
    selectRecorderAudioTrackCalls.add(sound);
    state = state.copyWith(
      selectedSound: sound,
      clearSelectedSound: sound == null,
      seedSelectedSoundAsAudioTrack: sound != null,
    );
  }
}
