import 'dart:ui' show Tristate;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_actions_bottom.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_actions_top.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_top_bar.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';
import 'package:pro_video_editor/core/models/video/editor_video_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const VideoRecorderRecordingStopRequested());
  });

  group(VideoRecorderClassicStack, () {
    late _MockVideoRecorderBloc recorderBloc;
    late SharedPreferences testPrefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      testPrefs = await SharedPreferences.getInstance();
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());
    });

    Widget buildWidget({
      VideoRecorderState recordingState = VideoRecorderState.idle,
      List<DivineVideoClip>? clips,
      bool isCameraInitialized = true,
      bool canRecord = true,
    }) {
      when(() => recorderBloc.state).thenReturn(
        VideoRecorderBlocState(
          recordingState: recordingState,
          isCameraInitialized: isCameraInitialized,
          canRecord: canRecord,
          // The state default is `capture`, and this stack only ever renders
          // in classic. It matters for more than tidiness: `hasRecordingLimit`
          // is true only here, and it is what puts the session budget into the
          // shutter's enabled gate.
          recorderMode: VideoRecorderMode.classic,
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
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoRecorderClassicStack()),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoRecorderClassicStack', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderClassicStack), findsOneWidget);
      });

      testWidgets('renders $VideoRecorderClassicTopBar', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderClassicTopBar), findsOneWidget);
      });

      testWidgets('renders $VideoRecorderCameraPreview', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderCameraPreview), findsOneWidget);
      });

      testWidgets('renders $VideoRecorderClassicActionsTop', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderClassicActionsTop), findsOneWidget);
      });

      testWidgets('renders $VideoRecorderClassicActionsBottom', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderClassicActionsBottom), findsOneWidget);
      });
    });

    group('layout', () {
      testWidgets('uses SafeArea', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(SafeArea), findsWidgets);
      });

      testWidgets('uses Column layout', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(Column), findsWidgets);
      });

      testWidgets('shows 1:1 aspect ratio preview', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Should find an AspectRatio widget with ratio 1
        final aspectRatioWidgets = tester.widgetList<AspectRatio>(
          find.byType(AspectRatio),
        );
        expect(aspectRatioWidgets.any((w) => w.aspectRatio == 1.0), isTrue);
      });
    });

    group('interactions', () {
      testWidgets('wraps preview in GestureDetector for tap-to-record', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(GestureDetector), findsWidgets);
      });

      testWidgets('has Semantics for recording state', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.bySemanticsLabel(l10n.videoRecorderTapToStartLabel),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            lookupAppLocalizations(
              const Locale('de'),
            ).videoRecorderTapToStartLabel,
          ),
          findsNothing,
        );
      });

      testWidgets('has Semantics for recording active', (tester) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.bySemanticsLabel(l10n.videoRecorderRecordingTapToStopLabel),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            lookupAppLocalizations(
              const Locale('de'),
            ).videoRecorderRecordingTapToStopLabel,
          ),
          findsNothing,
        );
      });

      // Classic has no record button — the preview is the shutter — so the
      // Maestro flow taps it by this identifier
      // (e2e/maestro/utils/recordClassicClip.yaml). The label assertions above
      // move with the recording state; the anchor must not, or the E2E flow
      // loses its only way to start a classic recording. That only surfaces on
      // a manual run, since the Maestro lane is not part of CI.
      testWidgets('exposes a stable E2E anchor on the shutter in both states', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsIdentifier(SemanticIds.cameraClassicShutter),
          findsOneWidget,
        );

        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsIdentifier(SemanticIds.cameraClassicShutter),
          findsOneWidget,
        );

        handle.dispose();
      });

      // The anchor is stable across recording states, but the node's enabled
      // flag is not meant to be: it carries the same gate the gesture detector
      // runs on, so a screen reader stops offering a button that does nothing
      // and assertClassicMode can tell a live viewfinder from a dead one. The
      // capture stack's record button has always reported this.
      //
      // One pump per state: the bloc is a mock and does not emit, so
      // re-pumping over a live tree leaves `context.select` on the value it
      // already read.
      testWidgets('reports the shutter enabled once the camera is ready', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.bySemanticsIdentifier(SemanticIds.cameraClassicShutter),
        );
        expect(node.flagsCollection.isEnabled, Tristate.isTrue);

        handle.dispose();
      });

      testWidgets('reports the shutter disabled before the camera is ready', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildWidget(isCameraInitialized: false));
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.bySemanticsIdentifier(SemanticIds.cameraClassicShutter),
        );
        expect(node.flagsCollection.isEnabled, Tristate.isFalse);

        handle.dispose();
      });

      testWidgets(
        'reports the shutter disabled when the camera cannot record',
        (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(buildWidget(canRecord: false));
          await tester.pumpAndSettle();

          final node = tester.getSemantics(
            find.bySemanticsIdentifier(SemanticIds.cameraClassicShutter),
          );
          expect(node.flagsCollection.isEnabled, Tristate.isFalse);

          handle.dispose();
        },
      );

      // The third arm of the gate, and the only one specific to this mode:
      // classic is the sole `hasRecordingLimit` mode, so a session that has
      // spent the 6.3s budget cannot start another recording. This is the case
      // classicModeRecordingLimit's readiness wait exists to fail fast on.
      testWidgets('reports the shutter disabled once the budget is spent', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(
            clips: [
              DivineVideoClip(
                id: 'clip1',
                video: EditorVideo.file('/test/clip1.mp4'),
                duration: VideoEditorConstants.maxDuration,
                recordedAt: DateTime.now(),
                targetAspectRatio: .square,
                originalAspectRatio: 1,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.bySemanticsIdentifier(SemanticIds.cameraClassicShutter),
        );
        expect(node.flagsCollection.isEnabled, Tristate.isFalse);

        handle.dispose();
      });
    });

    group('long press', () {
      testWidgets('long press on preview calls startRecording', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.longPress(
          find.ancestor(
            of: find.byType(VideoRecorderCameraPreview),
            matching: find.byType(GestureDetector),
          ),
        );
        await tester.pumpAndSettle();

        verify(
          () => recorderBloc.add(const VideoRecorderRecordingStartRequested()),
        ).called(1);
      });

      testWidgets('long press release on preview calls stopRecording', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.longPress(
          find.ancestor(
            of: find.byType(VideoRecorderCameraPreview),
            matching: find.byType(GestureDetector),
          ),
        );
        await tester.pumpAndSettle();

        verify(
          () => recorderBloc.add(const VideoRecorderRecordingStopRequested()),
        ).called(1);
      });
    });

    // Regression tests for issue #4409 ("Phantom click"): an incidental
    // long-touch on the preview shutter while a tap-started recording is
    // in progress must NOT call stopRecording on release.
    group('phantom click regression (issue #4409)', () {
      testWidgets('long-press release does not stop a tap-started recording', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        await tester.pumpAndSettle();

        final gesture = await tester.startGesture(
          tester.getCenter(
            find.ancestor(
              of: find.byType(VideoRecorderCameraPreview),
              matching: find.byType(GestureDetector),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        await gesture.up();
        await tester.pumpAndSettle();

        verifyNever(
          () => recorderBloc.add(const VideoRecorderRecordingStopRequested()),
        );
        verifyNever(
          () => recorderBloc.add(const VideoRecorderRecordingStartRequested()),
        );
      });
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
