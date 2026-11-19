import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_camera/divine_camera.dart'
    show DivineVideoStabilizationMode;
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart' show DebugSemanticsDumpOrder;
import 'package:flutter/semantics.dart' show OrdinalSortKey;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_actions.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../../../helpers/finders.dart';

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
      bool isIntervalCaptureRunning = false,
      bool isStartingRecording = false,
      bool isStoppingRecording = false,
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
      bool isLiveChromaKeySupported = false,
      bool isChromaKeyEnabled = false,
      DivineVideoStabilizationMode videoStabilizationMode =
          DivineVideoStabilizationMode.off,
      List<DivineVideoStabilizationMode> availableVideoStabilizationModes =
          const [DivineVideoStabilizationMode.off],
      List<DivineVideoClip>? clips,
      bool isDualCameraSupported = false,
      bool isDualCameraEnabled = false,
      // Unfolded by default: most groups below drive a control that only the
      // unfolded rail lists.
      bool isActionRailExpanded = true,
      Locale locale = const Locale('en'),
    }) {
      when(() => recorderBloc.state).thenReturn(
        VideoRecorderBlocState(
          recordingState: recordingState,
          isIntervalCaptureRunning: isIntervalCaptureRunning,
          isStartingRecording: isStartingRecording,
          isStoppingRecording: isStoppingRecording,
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
          isLiveChromaKeySupported: isLiveChromaKeySupported,
          isChromaKeyEnabled: isChromaKeyEnabled,
          videoStabilizationMode: videoStabilizationMode,
          availableVideoStabilizationModes: availableVideoStabilizationModes,
          isCameraInitialized: true,
          canRecord: true,
          isDualCameraSupported: isDualCameraSupported,
          isDualCameraEnabled: isDualCameraEnabled,
          isActionRailExpanded: isActionRailExpanded,
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
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Align(
                alignment: Alignment.centerRight,
                child: VideoRecorderCaptureActions(),
              ),
            ),
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

      testWidgets('renders eight buttons unfolded', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Flash, switch camera, aspect ratio, timer, ghost frame, grid,
        // stabilization, and the button that folds the rail.
        expect(find.byType(InkWell), findsNWidgets(8));
      });

      testWidgets('renders Tooltip for each button', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(Tooltip), findsNWidgets(8));
      });

      testWidgets('renders a baked icon for each button', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Baked once instead of a colour-filtered SVG re-rasterized with
        // every camera frame.
        expect(find.byType(ShadowedDivineIcon), findsNWidgets(8));
      });
    });

    group('folding', () {
      Finder optionsButton() =>
          find.byKey(const ValueKey(SemanticIds.cameraRailOptionsButton));

      double top(WidgetTester tester, Finder finder) =>
          tester.getCenter(finder).dy;

      testWidgets('can reach the fold control on a short viewfinder', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(360, 320));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        await tester.ensureVisible(optionsButton());
        await tester.pumpAndSettle();
        await tester.tap(optionsButton());

        verify(
          () => recorderBloc.add(const VideoRecorderActionRailToggled()),
        ).called(1);
      });

      testWidgets('keeps the icons on the right of RTL captions', (
        tester,
      ) async {
        const locale = Locale('ar');
        final arabic = lookupAppLocalizations(locale);
        await tester.pumpWidget(buildWidget(locale: locale));
        await tester.pumpAndSettle();

        final flash = findByTooltip(arabic.videoRecorderToggleFlashLabel);
        final icon = find.descendant(
          of: flash,
          matching: find.byType(ShadowedDivineIcon),
        );
        expect(
          tester.getCenter(icon).dx,
          greaterThan(
            tester.getCenter(find.text(arabic.videoRecorderRailFlashLabel)).dx,
          ),
        );
        expect(
          tester.getCenter(icon).dx,
          tester.getCenter(optionsButton()).dx,
        );
      });

      testWidgets(
        'folded, offers flash, lens and aspect ratio, then the options button',
        (tester) async {
          await tester.pumpWidget(buildWidget(isActionRailExpanded: false));
          await tester.pumpAndSettle();

          expect(find.byType(InkWell), findsNWidgets(4));
          final flash = top(
            tester,
            findByTooltip(l10n.videoRecorderToggleFlashLabel),
          );
          final lens = top(
            tester,
            findByTooltip(l10n.videoRecorderSwitchCameraLabel),
          );
          final ratio = top(
            tester,
            findByTooltip(l10n.videoRecorderToggleAspectRatioLabel),
          );
          final options = top(tester, optionsButton());
          expect(flash, lessThan(lens));
          expect(lens, lessThan(ratio));
          expect(ratio, lessThan(options));
        },
      );

      testWidgets('folded, shows no names', (tester) async {
        await tester.pumpWidget(buildWidget(isActionRailExpanded: false));
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoRecorderRailFlashLabel), findsNothing);
        expect(find.text(l10n.videoRecorderRailFlipLabel), findsNothing);
        expect(
          find.text(l10n.videoRecorderRailAspectRatioLabel),
          findsNothing,
        );
      });

      testWidgets('unfolded, names every control', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        for (final name in [
          l10n.videoRecorderRailFlashLabel,
          l10n.videoRecorderRailFlipLabel,
          l10n.videoRecorderRailAspectRatioLabel,
          l10n.videoRecorderRailTimerLabel,
          l10n.videoRecorderRailGhostFrameLabel,
          l10n.videoRecorderRailGridLabel,
          l10n.videoRecorderStabilizationLabel,
        ]) {
          expect(find.text(name), findsOneWidget, reason: name);
        }
      });

      testWidgets('unfolded, lists the options button last', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final ratio = top(
          tester,
          findByTooltip(l10n.videoRecorderToggleAspectRatioLabel),
        );
        final timer = top(
          tester,
          findByTooltip(l10n.videoRecorderCycleTimerLabel),
        );
        final stabilization = top(
          tester,
          findByTooltip(l10n.videoRecorderStabilizationLabel),
        );
        final options = top(tester, optionsButton());
        expect(ratio, lessThan(timer));
        expect(stabilization, lessThan(options));
      });

      testWidgets('the options button unfolds the rail', (tester) async {
        await tester.pumpWidget(buildWidget(isActionRailExpanded: false));
        await tester.pumpAndSettle();

        await tester.tap(optionsButton());

        verify(
          () => recorderBloc.add(const VideoRecorderActionRailToggled()),
        ).called(1);
      });

      testWidgets('the options button folds an unfolded rail', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.tap(optionsButton());

        verify(
          () => recorderBloc.add(const VideoRecorderActionRailToggled()),
        ).called(1);
      });

      testWidgets("tapping a control's name triggers it", (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.videoRecorderRailFlashLabel));

        verify(
          () => recorderBloc.add(const VideoRecorderFlashToggled()),
        ).called(1);
      });

      testWidgets('comes back folded after a take', (tester) async {
        final widget = buildWidget();
        final unfolded = recorderBloc.state;
        final states = StreamController<VideoRecorderBlocState>();
        addTearDown(states.close);
        whenListen(recorderBloc, states.stream, initialState: unfolded);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();
        expect(findByTooltip(l10n.videoRecorderCycleTimerLabel), findsOne);

        // What the recorder emits for a take: the start folds the rail.
        states
          ..add(
            unfolded.copyWith(
              recordingState: VideoRecorderState.recording,
              isStartingRecording: true,
              isActionRailExpanded: false,
            ),
          )
          ..add(
            unfolded.copyWith(
              recordingState: VideoRecorderState.recording,
              isStartingRecording: false,
              isActionRailExpanded: false,
            ),
          )
          ..add(unfolded.copyWith(isActionRailExpanded: false));
        await tester.pumpAndSettle();

        expect(find.byType(InkWell), findsNWidgets(4));
        expect(findByTooltip(l10n.videoRecorderCycleTimerLabel), findsNothing);
        expect(find.text(l10n.videoRecorderRailFlashLabel), findsNothing);
      });

      for (final expanded in [false, true]) {
        testWidgets('announces the rail as ${expanded ? '' : 'not '}unfolded', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(buildWidget(isActionRailExpanded: expanded));
          await tester.pumpAndSettle();

          final node = tester.getSemantics(
            find.bySemanticsIdentifier(SemanticIds.cameraRailOptionsButton),
          );
          // VoiceOver does not speak the expanded flag, so the label carries
          // the state as well.
          expect(
            node.label,
            expanded
                ? l10n.videoRecorderRailHideOptionsLabel
                : l10n.videoRecorderRailShowOptionsLabel,
          );
          expect(node.flagsCollection.isButton, isTrue);
          expect(
            node.flagsCollection.isExpanded,
            expanded ? Tristate.isTrue : Tristate.isFalse,
          );

          handle.dispose();
        });
      }

      testWidgets('reads every control in one explicit order', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(
            isDualCameraSupported: true,
            isVideoStabilizationSupported: true,
            isLiveChromaKeySupported: true,
          ),
        );
        await tester.pumpAndSettle();

        final rail = tester
            .getSemantics(
              find.bySemanticsIdentifier(SemanticIds.cameraRailOptionsButton),
            )
            .parent!;
        final controls = rail.debugListChildrenInOrder(
          DebugSemanticsDumpOrder.traversalOrder,
        );

        // Read top to bottom, the order they are drawn in, so VoiceOver's
        // focus box moves down the rail and the options button comes last.
        expect(controls.map((node) => node.identifier), [
          SemanticIds.cameraFlashButton,
          SemanticIds.cameraSwitchCameraButton,
          SemanticIds.cameraAspectRatioButton,
          SemanticIds.cameraTimerButton,
          SemanticIds.cameraGhostFrameButton,
          SemanticIds.cameraGridButton,
          SemanticIds.cameraDualCameraButton,
          SemanticIds.cameraStabilizationButton,
          SemanticIds.cameraColorMaskButton,
          SemanticIds.cameraRailOptionsButton,
        ]);
        // The framework does not keep equal keys in drawn order, and iOS read
        // them out of order, so no two controls may share one.
        expect(
          controls
              .map((node) => (node.sortKey! as OrdinalSortKey).order)
              .toSet(),
          hasLength(controls.length),
        );

        handle.dispose();
      });

      // The stabilization name is its label word for word, so a name leaking
      // into the semantics tree would make it read twice.
      testWidgets('keeps the names out of what a screen reader reads', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(isVideoStabilizationSupported: true),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.videoRecorderStabilizationLabel),
          findsOneWidget,
        );

        final node = tester.getSemantics(
          find.bySemanticsIdentifier(SemanticIds.cameraStabilizationButton),
        );
        expect(node.label, l10n.videoRecorderStabilizationLabel);

        handle.dispose();
      });

      testWidgets('shows the names at once under reduced motion', (
        tester,
      ) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pumpWidget(buildWidget());

        final fade = tester.widget<Opacity>(
          find.ancestor(
            of: find.text(l10n.videoRecorderRailFlashLabel),
            matching: find.byType(Opacity),
          ),
        );
        expect(fade.opacity, 1);
      });

      testWidgets('fades the names in otherwise', (tester) async {
        await tester.pumpWidget(buildWidget());

        final fade = tester.widget<Opacity>(
          find.ancestor(
            of: find.text(l10n.videoRecorderRailFlashLabel),
            matching: find.byType(Opacity),
          ),
        );
        expect(fade.opacity, 0);
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

      testWidgets('fades out while stop-motion captures on its interval', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            recorderMode: VideoRecorderMode.stopMotion,
            isIntervalCaptureRunning: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find
              .bySemanticsIdentifier(SemanticIds.cameraTimerButton)
              .hitTestable(),
          findsNothing,
        );
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
          findByTooltip(l10n.videoRecorderToggleFlashLabel),
          findsOneWidget,
        );
      });

      testWidgets('flash button is disabled when hasFlash is false', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(hasFlash: false));
        await tester.pumpAndSettle();

        // Find the flash tooltip's InkWell — its onTap should be null
        final flashTooltip = findByTooltip(l10n.videoRecorderToggleFlashLabel);
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

        final switchTooltip = findByTooltip(
          l10n.videoRecorderSwitchCameraLabel,
        );
        final inkWell = find.descendant(
          of: switchTooltip,
          matching: find.byType(InkWell),
        );
        final widget = tester.widget<InkWell>(inkWell);
        expect(widget.onTap, isNull);
      });

      InkWell switchButton(WidgetTester tester) => tester.widget<InkWell>(
        find.descendant(
          of: findByTooltip(l10n.videoRecorderSwitchCameraLabel),
          matching: find.byType(InkWell),
        ),
      );

      testWidgets('is enabled when no take is in flight', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(switchButton(tester).onTap, isNotNull);
      });

      // Before the native start, and while an auto-stopped clip is finalized
      // after the recorder already reads idle, the rail is still visible but
      // the recorder refuses a flip.
      testWidgets('is disabled while a take is starting', (tester) async {
        await tester.pumpWidget(buildWidget(isStartingRecording: true));
        await tester.pumpAndSettle();

        expect(switchButton(tester).onTap, isNull);
      });

      testWidgets('is disabled while a take is being finalized', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(isStoppingRecording: true));
        await tester.pumpAndSettle();

        expect(switchButton(tester).onTap, isNull);
      });
    });

    group('dual camera button', () {
      Finder dualButton() => findByTooltip(
        l10n.videoRecorderToggleDualCameraLabel,
      );

      testWidgets('is hidden on a device that cannot run both cameras', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(dualButton(), findsNothing);
      });

      testWidgets('is hidden in a mode without dual-camera capture', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            isDualCameraSupported: true,
            recorderMode: VideoRecorderMode.stopMotion,
          ),
        );
        await tester.pumpAndSettle();

        expect(dualButton(), findsNothing);
      });

      testWidgets('is hidden while the color mask keys the viewfinder', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            isDualCameraSupported: true,
            isLiveChromaKeySupported: true,
            isChromaKeyEnabled: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(dualButton(), findsNothing);
      });

      testWidgets('toggles dual-camera capture', (tester) async {
        await tester.pumpWidget(buildWidget(isDualCameraSupported: true));
        await tester.pumpAndSettle();

        await tester.tap(dualButton());

        verify(
          () => recorderBloc.add(const VideoRecorderDualCameraToggled()),
        ).called(1);
      });

      testWidgets('announces whether dual-camera capture is on', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(isDualCameraSupported: true, isDualCameraEnabled: true),
        );
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(
            find.bySemanticsIdentifier(SemanticIds.cameraDualCameraButton),
          ),
          matchesSemantics(
            identifier: SemanticIds.cameraDualCameraButton,
            label: l10n.videoRecorderToggleDualCameraLabel,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasToggledState: true,
            isToggled: true,
            hasTapAction: true,
            hasFocusAction: true,
            isFocusable: true,
          ),
        );
        semantics.dispose();
      });

      testWidgets('hides stabilization while both cameras run', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(
            isDualCameraSupported: true,
            isDualCameraEnabled: true,
            isVideoStabilizationSupported: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier(SemanticIds.cameraStabilizationButton),
          findsNothing,
        );
        semantics.dispose();
      });

      testWidgets('is disabled while a take is starting', (tester) async {
        await tester.pumpWidget(
          buildWidget(isDualCameraSupported: true, isStartingRecording: true),
        );
        await tester.pumpAndSettle();

        final inkWell = tester.widget<InkWell>(
          find.descendant(of: dualButton(), matching: find.byType(InkWell)),
        );
        expect(inkWell.onTap, isNull);
      });
    });

    group('stabilization button', () {
      testWidgets('is disabled when stabilization is unsupported', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final tooltip = findByTooltip(l10n.videoRecorderStabilizationLabel);
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

        final tooltip = findByTooltip(l10n.videoRecorderStabilizationLabel);
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
          findByTooltip(l10n.videoRecorderStabilizationLabel),
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
          findByTooltip(l10n.videoRecorderStabilizationLabel),
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
          findByTooltip(l10n.videoRecorderStabilizationLabel),
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
      testWidgets('is shown in capture mode', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(
          findByTooltip(l10n.videoRecorderToggleGridLabel),
          findsOneWidget,
        );
      });

      testWidgets('is shown in stop-motion mode', (tester) async {
        await tester.pumpWidget(
          buildWidget(recorderMode: VideoRecorderMode.stopMotion),
        );
        await tester.pumpAndSettle();

        expect(
          findByTooltip(l10n.videoRecorderToggleGridLabel),
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

        await tester.tap(findByTooltip(l10n.videoRecorderToggleGridLabel));
        await tester.pumpAndSettle();

        verify(
          () => recorderBloc.add(const VideoRecorderGridLinesToggled()),
        ).called(1);
      });
    });

    group('ghost frame button', () {
      // The ghost is the raw take, so over the keyed viewfinder it would show
      // the bare backdrop.
      testWidgets('is hidden while the color mask is on', (tester) async {
        await tester.pumpWidget(
          buildWidget(isLiveChromaKeySupported: true, isChromaKeyEnabled: true),
        );
        await tester.pumpAndSettle();

        expect(
          findByTooltip(l10n.videoRecorderToggleGhostFrameLabel),
          findsNothing,
        );
      });

      testWidgets(
        'tap dispatches $VideoRecorderShowLastClipOverlayToggled and '
        'confirms it',
        (tester) async {
          await tester.pumpWidget(buildWidget());
          await tester.pumpAndSettle();

          await tester.tap(
            findByTooltip(l10n.videoRecorderToggleGhostFrameLabel),
          );
          await tester.pump();

          verify(
            () => recorderBloc.add(
              const VideoRecorderShowLastClipOverlayToggled(),
            ),
          ).called(1);
          expect(
            find.text(l10n.videoRecorderGhostFrameEnabled),
            findsOneWidget,
          );
        },
      );
    });

    group('color mask button', () {
      testWidgets('is hidden where the viewfinder cannot be keyed live', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(findByTooltip(l10n.videoEditorChromaKeyLabel), findsNothing);
      });

      testWidgets('is hidden in stop-motion', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recorderMode: VideoRecorderMode.stopMotion,
            isLiveChromaKeySupported: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(findByTooltip(l10n.videoEditorChromaKeyLabel), findsNothing);
      });

      testWidgets('turns the mask on and opens its settings', (tester) async {
        await tester.pumpWidget(buildWidget(isLiveChromaKeySupported: true));
        await tester.pumpAndSettle();

        await tester.tap(findByTooltip(l10n.videoEditorChromaKeyLabel));
        await tester.pumpAndSettle();

        verify(
          () => recorderBloc.add(
            const VideoRecorderChromaKeyEnabledSet(enabled: true),
          ),
        ).called(1);
        expect(find.text(l10n.videoEditorChromaKeyRemove), findsOneWidget);
      });

      testWidgets('reopens the settings of a mask that is already on', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(isLiveChromaKeySupported: true, isChromaKeyEnabled: true),
        );
        await tester.pumpAndSettle();

        await tester.tap(findByTooltip(l10n.videoEditorChromaKeyLabel));
        await tester.pumpAndSettle();

        verifyNever(
          () => recorderBloc.add(
            const VideoRecorderChromaKeyEnabledSet(enabled: true),
          ),
        );
        expect(find.text(l10n.videoEditorChromaKeyRemove), findsOneWidget);
      });

      // Look-ahead stabilization delays the preview the backdrop is
      // composited against.
      testWidgets('hides stabilization while the mask is on', (tester) async {
        await tester.pumpWidget(
          buildWidget(isLiveChromaKeySupported: true, isChromaKeyEnabled: true),
        );
        await tester.pumpAndSettle();

        expect(
          findByTooltip(l10n.videoRecorderStabilizationLabel),
          findsNothing,
        );
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
          findByTooltip(l10n.videoRecorderToggleFlashLabel),
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
          findByTooltip(l10n.videoRecorderCycleTimerLabel),
        );
        expect(node.value, equals(l10n.videoRecorderTimerValueTenSeconds));

        handle.dispose();
      });

      testWidgets('announces the stop-motion interval', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(
            recorderMode: VideoRecorderMode.stopMotion,
            timerDuration: TimerDuration.five,
          ),
        );
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          findByTooltip(l10n.videoRecorderCycleTimerLabel),
        );
        expect(node.value, equals(l10n.videoRecorderTimerValueFiveSeconds));

        handle.dispose();
      });

      testWidgets('announces the active aspect ratio', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(aspectRatio: model.AspectRatio.square),
        );
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          findByTooltip(l10n.videoRecorderToggleAspectRatioLabel),
        );
        expect(node.value, equals(l10n.videoRecorderAspectRatioValueSquare));

        handle.dispose();
      });

      testWidgets('announces which camera is active', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildWidget(isFrontCamera: true));
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          findByTooltip(l10n.videoRecorderSwitchCameraLabel),
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
          findByTooltip(l10n.videoRecorderStabilizationLabel),
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
          SemanticIds.cameraGhostFrameButton,
          SemanticIds.cameraGridButton,
          SemanticIds.cameraAspectRatioButton,
          SemanticIds.cameraSwitchCameraButton,
          SemanticIds.cameraStabilizationButton,
          SemanticIds.cameraRailOptionsButton,
        ]) {
          expect(
            find.bySemanticsIdentifier(identifier),
            findsOneWidget,
            reason: 'missing E2E anchor: $identifier',
          );
        }

        handle.dispose();
      });

      // Same contract for the stop-motion rail, driven by
      // e2e/maestro/tests/stopMotionModeControls.yaml. Asserted separately
      // because the capture-mode rail above has no grid.
      testWidgets('exposes an E2E identifier on the stop-motion controls', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(recorderMode: VideoRecorderMode.stopMotion),
        );
        await tester.pumpAndSettle();

        for (final identifier in const [
          SemanticIds.cameraTimerButton,
          SemanticIds.cameraGhostFrameButton,
          SemanticIds.cameraGridButton,
          SemanticIds.cameraRailOptionsButton,
        ]) {
          expect(
            find.bySemanticsIdentifier(identifier),
            findsOneWidget,
            reason: 'missing E2E anchor: $identifier',
          );
        }

        handle.dispose();
      });

      // assertStopMotionMode pins stabilization absent, so a control that
      // starts rendering in the wrong mode fails an E2E run rather than
      // passing quietly. Nothing else here would catch it — every other test
      // in this file asserts presence.
      testWidgets('keeps stabilization out of stop-motion mode', (
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

        expect(
          find.bySemanticsIdentifier(SemanticIds.cameraStabilizationButton),
          findsNothing,
        );

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
          findByTooltip(l10n.videoRecorderToggleGridLabel),
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
          findByTooltip(l10n.videoRecorderToggleGridLabel),
        );
        expect(node.flagsCollection.isToggled, Tristate.isFalse);

        handle.dispose();
      });

      testWidgets('announces the ghost frame as toggled when on', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildWidget(showLastClipOverlay: true));
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          findByTooltip(l10n.videoRecorderToggleGhostFrameLabel),
        );
        expect(node.flagsCollection.isToggled, Tristate.isTrue);

        handle.dispose();
      });

      testWidgets('marks an unavailable control as disabled', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildWidget(hasFlash: false));
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          findByTooltip(l10n.videoRecorderToggleFlashLabel),
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

        final arTooltip = findByTooltip(
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

        final arTooltip = findByTooltip(
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
