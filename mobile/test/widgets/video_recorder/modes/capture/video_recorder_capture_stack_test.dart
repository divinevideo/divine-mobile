import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_top_bar.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_record_button.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderCaptureStack, () {
    late _MockVideoRecorderBloc recorderBloc;
    late SharedPreferences testPrefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      testPrefs = await SharedPreferences.getInstance();
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(
        const VideoRecorderBlocState(
          isCameraInitialized: true,
          canRecord: true,
        ),
      );
    });

    Widget buildWidget({
      VideoRecorderState recordingState = VideoRecorderState.idle,
      List<DivineVideoClip>? clips,
      bool fromEditor = false,
      VideoRecorderMode recorderMode = VideoRecorderMode.capture,
      List<String> stopMotionFrames = const [],
    }) {
      when(() => recorderBloc.state).thenReturn(
        VideoRecorderBlocState(
          recordingState: recordingState,
          isCameraInitialized: true,
          canRecord: true,
          recorderMode: recorderMode,
          stopMotionFrames: stopMotionFrames,
        ),
      );

      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(testPrefs),
          clipManagerProvider.overrideWith(
            () => _TestClipManagerNotifier(clips: clips ?? []),
          ),
        ],
        child: BlocProvider<VideoRecorderBloc>.value(
          value: recorderBloc,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoRecorderCaptureStack(fromEditor: fromEditor),
            ),
          ),
        ),
      );
    }

    // The real (non-dummy) undo button is the trash icon button with a live
    // onPressed; the sibling placeholder passes onPressed: null.
    final undoButtonFinder = find.byWidgetPredicate(
      (w) =>
          w is DivineIconButton &&
          w.icon == DivineIconName.trash &&
          w.onPressed != null,
    );

    group('renders', () {
      testWidgets('renders $VideoRecorderCaptureStack', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderCaptureStack), findsOneWidget);
      });

      testWidgets('renders $VideoRecorderCameraPreview', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderCameraPreview), findsOneWidget);
      });

      testWidgets('renders $RecordButton', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(RecordButton), findsOneWidget);
      });

      testWidgets('renders $VideoRecorderCaptureTopBar', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderCaptureTopBar), findsOneWidget);
      });
    });

    group('undo button', () {
      testWidgets('undo button is hidden when no clips', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Undo button is wrapped in AnimatedOpacity with opacity 0
        final opacities = tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .toList();
        expect(opacities.any((o) => o.opacity == 0), isTrue);
      });

      testWidgets('undo button is visible when clips exist and not recording', (
        tester,
      ) async {
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

        // AnimatedOpacity around undo button should be 1
        final opacities = tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .toList();
        expect(opacities.any((o) => o.opacity == 1), isTrue);
      });

      // Anchor for the Maestro capture-mode flow, which deletes the recorded
      // clip by id as its teardown (e2e/maestro/tests/captureModeDeleteClip
      // .yaml). Nothing else in this file would notice the id going missing.
      testWidgets('exposes an E2E identifier on the undo button', (
        tester,
      ) async {
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
          find.bySemanticsIdentifier(SemanticIds.cameraDeleteClipButton),
          findsOneWidget,
        );
      });

      testWidgets('undo button is hidden during recording even with clips', (
        tester,
      ) async {
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
            clips: clips,
          ),
        );
        await tester.pumpAndSettle();

        // Should have opacity 0 for the undo button
        final opacities = tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .toList();
        expect(opacities.any((o) => o.opacity == 0), isTrue);
      });

      testWidgets(
        'invisible undo button ignores taps in editor-hosted recorder',
        (tester) async {
          await tester.pumpWidget(
            buildWidget(
              fromEditor: true,
              recorderMode: VideoRecorderMode.stopMotion,
              stopMotionFrames: const ['/test/frame1.jpg'],
            ),
          );
          await tester.pumpAndSettle();

          // Hidden (opacity 0) but present; tap must not reach onPressed.
          await tester.tap(undoButtonFinder, warnIfMissed: false);
          await tester.pump();

          verifyNever(
            () => recorderBloc.add(const VideoRecorderStopMotionFrameUndone()),
          );
        },
      );

      testWidgets(
        'visible undo button deletes the last still when tapped',
        (tester) async {
          await tester.pumpWidget(
            buildWidget(
              recorderMode: VideoRecorderMode.stopMotion,
              stopMotionFrames: const ['/test/frame1.jpg'],
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(undoButtonFinder);
          await tester.pump();

          verify(
            () => recorderBloc.add(const VideoRecorderStopMotionFrameUndone()),
          ).called(1);
        },
      );
    });

    group('layout', () {
      testWidgets('uses SafeArea', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(SafeArea), findsWidgets);
      });

      testWidgets('uses Stack for layering', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(Stack), findsWidgets);
      });

      testWidgets('$RecordButton is horizontally centered', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final stackRect = tester.getRect(
          find.byType(VideoRecorderCaptureStack),
        );
        final recordButtonRect = tester.getRect(find.byType(RecordButton));

        expect(recordButtonRect.center.dx, closeTo(stackRect.center.dx, 2.0));
      });
    });

    group('stop-motion assemble', () {
      testWidgets(
        'shows a DivineSnackbarContainer error when assembly fails',
        (tester) async {
          final states = StreamController<VideoRecorderBlocState>.broadcast();
          addTearDown(states.close);

          final widget = buildWidget();
          // whenListen overrides the state stub from buildWidget so the
          // BlocConsumer reacts to the emitted status transition.
          whenListen(
            recorderBloc,
            states.stream,
            initialState: const VideoRecorderBlocState(
              isCameraInitialized: true,
              canRecord: true,
            ),
          );
          await tester.pumpWidget(widget);
          await tester.pump();

          states.add(
            const VideoRecorderBlocState(
              isCameraInitialized: true,
              canRecord: true,
              stopMotionStatus: StopMotionStatus.failure,
            ),
          );
          await tester.pump();
          await tester.pump();

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(
            find.widgetWithText(
              DivineSnackbarContainer,
              l10n.videoRecorderStopMotionAssembleFailed,
            ),
            findsOneWidget,
          );
          final container = tester.widget<DivineSnackbarContainer>(
            find.byType(DivineSnackbarContainer),
          );
          expect(container.error, isTrue);
        },
      );
    });
  });
}

class _TestClipManagerNotifier extends ClipManagerNotifier {
  _TestClipManagerNotifier({required this.clips});

  @override
  final List<DivineVideoClip> clips;

  @override
  ClipManagerState build() {
    return ClipManagerState(clips: clips);
  }
}
