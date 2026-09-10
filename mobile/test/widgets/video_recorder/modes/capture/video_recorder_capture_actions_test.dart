import 'dart:ui' show Tristate;

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_camera/divine_camera.dart'
    show DivineVideoStabilizationMode;
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_actions.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VideoRecorderCaptureActions, () {
    late _MockVideoRecorderBloc recorderBloc;

    setUp(() {
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.isClosed).thenReturn(false);
    });

    Widget buildWidget({
      VideoRecorderState recordingState = VideoRecorderState.idle,
      VideoRecorderMode recorderMode = VideoRecorderMode.capture,
      DivineFlashMode flashMode = DivineFlashMode.auto,
      TimerDuration timerDuration = TimerDuration.off,
      model.AspectRatio aspectRatio = model.AspectRatio.vertical,
      bool canSwitchCamera = true,
      bool isFrontCamera = false,
      bool hasFlash = true,
      bool showGridLines = false,
      bool showLastClipOverlay = false,
      bool isVideoStabilizationSupported = false,
      DivineVideoStabilizationMode videoStabilizationMode =
          DivineVideoStabilizationMode.off,
      List<DivineVideoStabilizationMode> availableVideoStabilizationModes =
          const [DivineVideoStabilizationMode.off],
      List<DivineVideoClip>? clips,
    }) {
      when(() => recorderBloc.state).thenReturn(
        VideoRecorderBlocState(
          recordingState: recordingState,
          recorderMode: recorderMode,
          flashMode: flashMode,
          timerDuration: timerDuration,
          aspectRatio: aspectRatio,
          canSwitchCamera: canSwitchCamera,
          isFrontCamera: isFrontCamera,
          hasFlash: hasFlash,
          showGridLines: showGridLines,
          showLastClipOverlay: showLastClipOverlay,
          isVideoStabilizationSupported: isVideoStabilizationSupported,
          videoStabilizationMode: videoStabilizationMode,
          availableVideoStabilizationModes: availableVideoStabilizationModes,
          isCameraInitialized: true,
          canRecord: true,
        ),
      );

      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(
            () => _TestClipManagerNotifier(clips: clips ?? []),
          ),
        ],
        child: BlocProvider<VideoRecorderBloc>.value(
          value: recorderBloc,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoRecorderCaptureActions()),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoRecorderCaptureActions', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderCaptureActions), findsOneWidget);
      });

      testWidgets('renders five action buttons', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Flash, timer, aspect ratio, switch camera, stabilization
        expect(find.byType(InkWell), findsNWidgets(5));
      });

      testWidgets('renders Tooltip for each button', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(Tooltip), findsNWidgets(5));
      });

      testWidgets('renders DivineIcon for each button', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(DivineIcon), findsNWidgets(5));
      });
    });

    group('visibility', () {
      testWidgets('is fully opaque when not recording', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(1));
      });

      testWidgets('fades out when recording', (tester) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(0));
      });

      testWidgets('ignores touches while recording', (tester) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        await tester.pumpAndSettle();

        final ignorePointer = tester.widget<IgnorePointer>(
          find.byWidgetPredicate(
            (widget) =>
                widget is IgnorePointer && widget.child is AnimatedOpacity,
          ),
        );
        expect(ignorePointer.ignoring, isTrue);
      });

      testWidgets('allows touches when not recording', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final ignorePointer = tester.widget<IgnorePointer>(
          find.byWidgetPredicate(
            (widget) =>
                widget is IgnorePointer && widget.child is AnimatedOpacity,
          ),
        );
        expect(ignorePointer.ignoring, isFalse);
      });
    });

    group('flash button', () {
      testWidgets('renders flash tooltip', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(
          find.byTooltip(l10n.videoRecorderToggleFlashLabel),
          findsOneWidget,
        );
      });

      testWidgets('flash button is disabled when hasFlash is false', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(hasFlash: false));
        await tester.pumpAndSettle();

        // Find the flash tooltip's InkWell — its onTap should be null
        final flashTooltip = find.byTooltip(l10n.videoRecorderToggleFlashLabel);
        final inkWell = find.descendant(
          of: flashTooltip,
          matching: find.byType(InkWell),
        );
        final widget = tester.widget<InkWell>(inkWell);
        expect(widget.onTap, isNull);
      });
    });

    group('switch camera button', () {
      testWidgets('is disabled when canSwitchCamera is false', (tester) async {
        await tester.pumpWidget(buildWidget(canSwitchCamera: false));
        await tester.pumpAndSettle();

        final switchTooltip = find.byTooltip(
          l10n.videoRecorderSwitchCameraLabel,
        );
        final inkWell = find.descendant(
          of: switchTooltip,
          matching: find.byType(InkWell),
        );
        final widget = tester.widget<InkWell>(inkWell);
        expect(widget.onTap, isNull);
      });
    });

    group('stabilization button', () {
      testWidgets('is disabled when stabilization is unsupported', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final tooltip = find.byTooltip(l10n.videoRecorderStabilizationLabel);
        final inkWell = find.descendant(
          of: tooltip,
          matching: find.byType(InkWell),
        );
        final widget = tester.widget<InkWell>(inkWell);
        expect(widget.onTap, isNull);
      });

      testWidgets('is enabled when stabilization is supported', (tester) async {
        await tester.pumpWidget(
          buildWidget(isVideoStabilizationSupported: true),
        );
        await tester.pumpAndSettle();

        final tooltip = find.byTooltip(l10n.videoRecorderStabilizationLabel);
        final inkWell = find.descendant(
          of: tooltip,
          matching: find.byType(InkWell),
        );
        final widget = tester.widget<InkWell>(inkWell);
        expect(widget.onTap, isNotNull);
      });

      testWidgets('opens the selection menu with available modes', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            isVideoStabilizationSupported: true,
            availableVideoStabilizationModes: const [
              DivineVideoStabilizationMode.off,
              DivineVideoStabilizationMode.standard,
              DivineVideoStabilizationMode.auto,
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byTooltip(l10n.videoRecorderStabilizationLabel),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.videoRecorderStabilizationModeStandard),
          findsOneWidget,
        );
        expect(
          find.text(l10n.videoRecorderStabilizationModeAuto),
          findsOneWidget,
        );
      });

      testWidgets('dispatches the selected mode as an event', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            isVideoStabilizationSupported: true,
            availableVideoStabilizationModes: const [
              DivineVideoStabilizationMode.off,
              DivineVideoStabilizationMode.standard,
              DivineVideoStabilizationMode.auto,
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byTooltip(l10n.videoRecorderStabilizationLabel),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.text(l10n.videoRecorderStabilizationModeAuto),
        );
        await tester.pumpAndSettle();

        verify(
          () => recorderBloc.add(
            const VideoRecorderStabilizationModeSet(
              DivineVideoStabilizationMode.auto,
            ),
          ),
        ).called(1);
      });

      testWidgets('dispatches nothing when the menu is dismissed', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            isVideoStabilizationSupported: true,
            availableVideoStabilizationModes: const [
              DivineVideoStabilizationMode.off,
              DivineVideoStabilizationMode.standard,
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byTooltip(l10n.videoRecorderStabilizationLabel),
        );
        await tester.pumpAndSettle();

        // Dismiss the sheet by tapping the barrier instead of an option.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        verifyNever(
          () => recorderBloc.add(
            const VideoRecorderStabilizationModeSet(
              DivineVideoStabilizationMode.standard,
            ),
          ),
        );
      });
    });

    group('grid lines button', () {
      testWidgets('is hidden in capture mode', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(
          find.byTooltip(l10n.videoRecorderToggleGridLabel),
          findsNothing,
        );
      });

      testWidgets('is shown in stop-motion mode', (tester) async {
        await tester.pumpWidget(
          buildWidget(recorderMode: VideoRecorderMode.stopMotion),
        );
        await tester.pumpAndSettle();

        expect(
          find.byTooltip(l10n.videoRecorderToggleGridLabel),
          findsOneWidget,
        );
      });

      testWidgets('tap dispatches $VideoRecorderGridLinesToggled', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(recorderMode: VideoRecorderMode.stopMotion),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip(l10n.videoRecorderToggleGridLabel));
        await tester.pumpAndSettle();

        verify(
          () => recorderBloc.add(const VideoRecorderGridLinesToggled()),
        ).called(1);
      });
    });

    group('semantics', () {
      testWidgets('announces the active flash mode', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(flashMode: DivineFlashMode.torch),
        );
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.byTooltip(l10n.videoRecorderToggleFlashLabel),
        );
        // The tooltip is excluded from semantics, so the label is announced
        // once and the flash state follows it.
        expect(node.label, equals(l10n.videoRecorderToggleFlashLabel));
        expect(node.value, equals(l10n.videoRecorderFlashValueOn));

        handle.dispose();
      });

      testWidgets('announces the active timer duration', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildWidget(timerDuration: TimerDuration.ten));
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.byTooltip(l10n.videoRecorderCycleTimerLabel),
        );
        expect(node.value, equals(l10n.videoRecorderTimerValueTenSeconds));

        handle.dispose();
      });

      testWidgets('announces the active aspect ratio', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(aspectRatio: model.AspectRatio.square),
        );
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.byTooltip(l10n.videoRecorderToggleAspectRatioLabel),
        );
        expect(node.value, equals(l10n.videoRecorderAspectRatioValueSquare));

        handle.dispose();
      });

      testWidgets('announces which camera is active', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildWidget(isFrontCamera: true));
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.byTooltip(l10n.videoRecorderSwitchCameraLabel),
        );
        expect(node.value, equals(l10n.videoRecorderCameraValueFront));

        handle.dispose();
      });

      testWidgets('announces the active stabilization mode', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(
            isVideoStabilizationSupported: true,
            videoStabilizationMode: DivineVideoStabilizationMode.cinematic,
          ),
        );
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.byTooltip(l10n.videoRecorderStabilizationLabel),
        );
        expect(
          node.value,
          equals(l10n.videoRecorderStabilizationModeCinematic),
        );

        handle.dispose();
      });

      // The Maestro capture-mode flow drives the whole rail by identifier
      // (e2e/maestro/asserts/assertCaptureMode.yaml). Dropping one is
      // invisible to every other test here — the labels would still be
      // correct — and only surfaces on a manual E2E run.
      testWidgets('exposes an E2E identifier on every rail control', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(isVideoStabilizationSupported: true),
        );
        await tester.pumpAndSettle();

        for (final identifier in const [
          SemanticIds.cameraFlashButton,
          SemanticIds.cameraTimerButton,
          SemanticIds.cameraAspectRatioButton,
          SemanticIds.cameraSwitchCameraButton,
          SemanticIds.cameraStabilizationButton,
        ]) {
          expect(
            find.bySemanticsIdentifier(identifier),
            findsOneWidget,
            reason: 'missing E2E anchor: $identifier',
          );
        }

        handle.dispose();
      });

      // Same contract for the two controls only stop-motion renders, driven by
      // e2e/maestro/tests/stopMotionModeControls.yaml. Asserted separately
      // because the capture-mode rail above renders neither.
      testWidgets('exposes an E2E identifier on the stop-motion controls', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(recorderMode: VideoRecorderMode.stopMotion),
        );
        await tester.pumpAndSettle();

        for (final identifier in const [
          SemanticIds.cameraGhostFrameButton,
          SemanticIds.cameraGridButton,
        ]) {
          expect(
            find.bySemanticsIdentifier(identifier),
            findsOneWidget,
            reason: 'missing E2E anchor: $identifier',
          );
        }

        handle.dispose();
      });

      // assertCaptureMode and assertStopMotionMode each pin the other mode's
      // controls absent, so a control that starts rendering in the wrong mode
      // fails an E2E run rather than passing quietly. Nothing else here would
      // catch it — every other test in this file asserts presence.
      testWidgets('keeps the stop-motion controls out of capture mode', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(isVideoStabilizationSupported: true),
        );
        await tester.pumpAndSettle();

        for (final identifier in const [
          SemanticIds.cameraGhostFrameButton,
          SemanticIds.cameraGridButton,
        ]) {
          expect(
            find.bySemanticsIdentifier(identifier),
            findsNothing,
            reason: '$identifier must not render in capture mode',
          );
        }

        handle.dispose();
      });

      testWidgets('keeps the capture-only controls out of stop-motion mode', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(
            recorderMode: VideoRecorderMode.stopMotion,
            isVideoStabilizationSupported: true,
          ),
        );
        await tester.pumpAndSettle();

        for (final identifier in const [
          SemanticIds.cameraTimerButton,
          SemanticIds.cameraStabilizationButton,
        ]) {
          expect(
            find.bySemanticsIdentifier(identifier),
            findsNothing,
            reason: '$identifier must not render in stop-motion mode',
          );
        }

        handle.dispose();
      });

      testWidgets('announces the grid overlay as toggled when on', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(
            recorderMode: VideoRecorderMode.stopMotion,
            showGridLines: true,
          ),
        );
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.byTooltip(l10n.videoRecorderToggleGridLabel),
        );
        expect(node.flagsCollection.isToggled, Tristate.isTrue);

        handle.dispose();
      });

      testWidgets('announces the grid overlay as untoggled when off', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(recorderMode: VideoRecorderMode.stopMotion),
        );
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.byTooltip(l10n.videoRecorderToggleGridLabel),
        );
        expect(node.flagsCollection.isToggled, Tristate.isFalse);

        handle.dispose();
      });

      testWidgets('announces the ghost frame as toggled when on', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(
            recorderMode: VideoRecorderMode.stopMotion,
            showLastClipOverlay: true,
          ),
        );
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.byTooltip(l10n.videoRecorderToggleGhostFrameLabel),
        );
        expect(node.flagsCollection.isToggled, Tristate.isTrue);

        handle.dispose();
      });

      testWidgets('marks an unavailable control as disabled', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildWidget(hasFlash: false));
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.byTooltip(l10n.videoRecorderToggleFlashLabel),
        );
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.flagsCollection.isEnabled, Tristate.isFalse);

        handle.dispose();
      });
    });

    group('aspect ratio button', () {
      testWidgets('is disabled when clips exist', (tester) async {
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

        final arTooltip = find.byTooltip(
          l10n.videoRecorderToggleAspectRatioLabel,
        );
        final inkWell = find.descendant(
          of: arTooltip,
          matching: find.byType(InkWell),
        );
        final widget = tester.widget<InkWell>(inkWell);
        expect(widget.onTap, isNull);
      });

      testWidgets('is enabled when no clips exist', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final arTooltip = find.byTooltip(
          l10n.videoRecorderToggleAspectRatioLabel,
        );
        final inkWell = find.descendant(
          of: arTooltip,
          matching: find.byType(InkWell),
        );
        final widget = tester.widget<InkWell>(inkWell);
        expect(widget.onTap, isNotNull);
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
