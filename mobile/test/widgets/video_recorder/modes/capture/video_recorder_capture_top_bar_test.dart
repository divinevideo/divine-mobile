import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_top_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderCaptureTopBar, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    late _MockVideoRecorderBloc recorderBloc;

    setUp(() {
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());
    });

    Widget buildWidget({
      VideoRecorderState recordingState = VideoRecorderState.idle,
      List<DivineVideoClip>? clips,
      Duration activeRecordingDuration = Duration.zero,
      bool showRecordingProgress = true,
    }) {
      when(() => recorderBloc.state).thenReturn(
        VideoRecorderBlocState(
          recordingState: recordingState,
          isCameraInitialized: true,
          canRecord: true,
        ),
      );

      return ProviderScope(
        overrides: [
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
              body: VideoRecorderCaptureTopBar(
                fromEditor: false,
                showRecordingProgress: showRecordingProgress,
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoRecorderCaptureTopBar', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderCaptureTopBar), findsOneWidget);
      });

      testWidgets('uses AnimatedSwitcher', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSwitcher), findsOneWidget);
      });
    });

    group('idle state', () {
      testWidgets('shows close and next buttons when not recording', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(DivineIconButton), findsNWidgets(2));
      });

      testWidgets('close button announces that it closes the recorder', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(l10n.videoRecorderCloseLabel),
          findsOneWidget,
        );
      });

      testWidgets('next button is hidden when no clips exist', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Next button wrapped in AnimatedOpacity with opacity 0
        final opacities = tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .toList();
        // Find the one with opacity 0 (no clips -> next is hidden)
        expect(opacities.any((o) => o.opacity == 0), isTrue);
      });

      testWidgets('next button is visible when clips exist', (tester) async {
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

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pumpAndSettle();

        // AnimatedOpacity around next button should have opacity 1
        final opacities = tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .toList();
        expect(opacities.any((o) => o.opacity == 1), isTrue);
        expect(
          find.bySemanticsLabel(l10n.videoRecorderContinueToEditorLabel),
          findsOneWidget,
        );
      });

      // Anchors for the Maestro capture-mode flow, which drives both buttons
      // by id (e2e/maestro/tests/captureModeOpen.yaml). The labels above stay
      // green if an identifier is dropped, so pin the identifiers too.
      testWidgets('exposes E2E identifiers on close and next', (tester) async {
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

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier(SemanticIds.cameraCloseButton),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.cameraNextButton),
          findsOneWidget,
        );
      });
    });

    group('recording state', () {
      testWidgets('shows progress bar when recording', (tester) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        // Pump a few frames for AnimatedSwitcher
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The progress bar uses Flexible widgets for segments
        expect(find.byType(Flexible), findsWidgets);
      });

      testWidgets('shows time display when recording', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            activeRecordingDuration: const Duration(seconds: 2),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Time text should be shown (e.g. "00:02")
        expect(find.textContaining('00:02'), findsOneWidget);
      });

      testWidgets('shows progress with existing clips', (tester) async {
        final clips = [
          DivineVideoClip(
            id: 'clip1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        ];

        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            clips: clips,
            activeRecordingDuration: const Duration(seconds: 1),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Should show combined duration 3s + 1s = "00:04"
        expect(find.textContaining('00:04'), findsOneWidget);
      });

      testWidgets(
        'hides the recording-progress bar when showRecordingProgress is false',
        (tester) async {
          await tester.pumpWidget(
            buildWidget(
              recordingState: VideoRecorderState.recording,
              activeRecordingDuration: const Duration(seconds: 2),
              showRecordingProgress: false,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // The time display from the progress bar must not be rendered.
          expect(find.textContaining('00:02'), findsNothing);
        },
      );
    });
  });
}

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
