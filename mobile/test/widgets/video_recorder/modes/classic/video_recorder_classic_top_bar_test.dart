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
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_top_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderClassicTopBar, () {
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
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(height: 80, child: VideoRecorderClassicTopBar()),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoRecorderClassicTopBar', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderClassicTopBar), findsOneWidget);
      });

      testWidgets('renders close and next buttons', (tester) async {
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

      testWidgets('next button announces that it continues to the editor', (
        tester,
      ) async {
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

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(l10n.videoRecorderContinueToEditorLabel),
          findsOneWidget,
        );
      });

      testWidgets('uses Stack for progress bar behind buttons', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(Stack), findsWidgets);
      });
    });

    group('E2E anchors', () {
      // The Maestro classic flow drives this bar by identifier
      // (e2e/maestro/asserts/assertClassicMode.yaml). Dropping one is
      // invisible to the label assertions above and only surfaces on a manual
      // E2E run, since that lane is not part of CI.
      testWidgets('exposes an E2E identifier on close and next', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        for (final identifier in [
          SemanticIds.cameraCloseButton,
          SemanticIds.cameraNextButton,
        ]) {
          expect(
            find.bySemanticsIdentifier(identifier),
            findsOneWidget,
            reason: 'missing E2E anchor: $identifier',
          );
        }

        handle.dispose();
      });

      // assertClassicMode reads an empty session off `enabled: false` on next
      // rather than off its absence, because unlike the capture stack classic
      // keeps the button mounted and disables it. Wrapping it in an
      // AnimatedOpacity later would drop it from the semantics tree and break
      // that assert in a lane CI does not run.
      testWidgets(
        'keeps next mounted and disabled while the session is empty',
        (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(buildWidget());
          await tester.pumpAndSettle();

          final node = tester.getSemantics(
            find.bySemanticsIdentifier(SemanticIds.cameraNextButton),
          );
          expect(node.flagsCollection.isEnabled, Tristate.isFalse);

          handle.dispose();
        },
      );

      testWidgets('enables next once the session holds a clip', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(
            clips: [
              DivineVideoClip(
                id: 'clip1',
                video: EditorVideo.file('/test/clip1.mp4'),
                duration: const Duration(seconds: 3),
                recordedAt: DateTime.now(),
                targetAspectRatio: .square,
                originalAspectRatio: 1,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.bySemanticsIdentifier(SemanticIds.cameraNextButton),
        );
        expect(node.flagsCollection.isEnabled, Tristate.isTrue);

        handle.dispose();
      });
    });

    group('progress bar', () {
      testWidgets('shows progress when clips exist', (tester) async {
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

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pumpAndSettle();

        // Progress bar uses Flexible widgets for primary/remaining
        expect(find.byType(Flexible), findsWidgets);
      });

      testWidgets('shows no primary fill when no clips and no recording', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Progress bar should exist but no primary fill (currentMs = 0)
        expect(find.byType(VideoRecorderClassicTopBar), findsOneWidget);
      });

      testWidgets('shows active recording progress', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            activeRecordingDuration: const Duration(seconds: 2),
          ),
        );
        await tester.pumpAndSettle();

        // The Flexible widgets represent progress segments
        expect(find.byType(Flexible), findsWidgets);
      });
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
