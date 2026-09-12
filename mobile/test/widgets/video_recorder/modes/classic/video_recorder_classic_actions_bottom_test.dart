import 'dart:ui' show Tristate;

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
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_actions_bottom.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderClassicActionsBottom, () {
    late _MockVideoRecorderBloc recorderBloc;

    setUp(() {
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
      bool showLastClipOverlay = false,
      bool showGridLines = false,
      bool isFrontCamera = false,
    }) {
      when(() => recorderBloc.state).thenReturn(
        VideoRecorderBlocState(
          recordingState: recordingState,
          isCameraInitialized: true,
          canRecord: true,
          showLastClipOverlay: showLastClipOverlay,
          showGridLines: showGridLines,
          isFrontCamera: isFrontCamera,
        ),
      );
      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(_TestClipManagerNotifier.new),
        ],
        child: BlocProvider<VideoRecorderBloc>.value(
          value: recorderBloc,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoRecorderClassicActionsBottom()),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoRecorderClassicActionsBottom', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderClassicActionsBottom), findsOneWidget);
      });

      testWidgets('renders three action buttons', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(DivineIconButton), findsNWidgets(3));
      });
    });

    group('visibility', () {
      testWidgets('is fully opaque when not recording', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byType(Row),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        );
        expect(opacity.opacity, equals(1));
      });

      testWidgets('fades out when recording', (tester) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byType(Row),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        );
        expect(opacity.opacity, equals(0));
      });
    });

    group('semantics', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      testWidgets('announces which camera is active', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildWidget(isFrontCamera: true));
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.bySemanticsLabel(l10n.videoRecorderSwitchCameraLabel),
        );
        expect(node.value, equals(l10n.videoRecorderCameraValueFront));

        handle.dispose();
      });

      testWidgets('announces the grid overlay as toggled when on', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildWidget(showGridLines: true));
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.bySemanticsLabel(l10n.videoRecorderToggleGridLabel),
        );
        expect(node.flagsCollection.isToggled, Tristate.isTrue);

        handle.dispose();
      });

      testWidgets('announces the ghost frame as untoggled when off', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.bySemanticsLabel(l10n.videoRecorderToggleGhostFrameLabel),
        );
        expect(node.flagsCollection.isToggled, Tristate.isFalse);

        handle.dispose();
      });

      // The Maestro classic flow drives this row by identifier
      // (e2e/maestro/tests/classicModeControls.yaml). Dropping one is
      // invisible to every other test here — the labels and toggled flags
      // above would still be correct — and only surfaces on a manual E2E run,
      // since that lane is not part of CI.
      testWidgets('exposes an E2E identifier on every action', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        for (final identifier in const [
          SemanticIds.cameraSwitchCameraButton,
          SemanticIds.cameraGridButton,
          SemanticIds.cameraGhostFrameButton,
        ]) {
          expect(
            find.bySemanticsIdentifier(identifier),
            findsOneWidget,
            reason: 'missing E2E anchor: $identifier',
          );
        }

        handle.dispose();
      });
    });

    group('interactions', () {
      testWidgets('shows snackbar when ghost frame is toggled', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // The ghost button is the third DivineIconButton
        final ghostButtons = tester
            .widgetList<DivineIconButton>(find.byType(DivineIconButton))
            .toList();
        expect(ghostButtons.length, equals(3));

        // Tap the ghost button (third one)
        await tester.tap(find.byType(DivineIconButton).at(2));
        await tester.pump();

        // Should dispatch the ghost-frame toggle event
        verify(
          () => recorderBloc.add(
            const VideoRecorderShowLastClipOverlayToggled(),
          ),
        ).called(1);

        // Should show snackbar
        expect(find.byType(SnackBar), findsOneWidget);
      });

      // Guards the async-ordering fix: the bloc event is async, so the snackbar
      // copy must be derived from the negated CURRENT state (the new value),
      // not re-read after dispatching (which would show the stale, inverted
      // copy). With a MockBloc the state never changes on add(), so a regression
      // to reading state post-dispatch flips these assertions.
      testWidgets('snackbar shows the enabled copy when the overlay was off', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DivineIconButton).at(2));
        await tester.pump();

        expect(find.text(l10n.videoRecorderGhostFrameEnabled), findsOneWidget);
        expect(find.text(l10n.videoRecorderGhostFrameDisabled), findsNothing);
      });

      testWidgets('snackbar shows the disabled copy when the overlay was on', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(buildWidget(showLastClipOverlay: true));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DivineIconButton).at(2));
        await tester.pump();

        expect(find.text(l10n.videoRecorderGhostFrameDisabled), findsOneWidget);
        expect(find.text(l10n.videoRecorderGhostFrameEnabled), findsNothing);
      });
    });
  });
}

class _TestClipManagerNotifier extends ClipManagerNotifier {
  @override
  ClipManagerState build() {
    return ClipManagerState();
  }
}
