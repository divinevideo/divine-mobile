import 'package:bloc_test/bloc_test.dart';
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
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_record_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(RecordButton, () {
    late _MockVideoRecorderBloc recorderBloc;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());
    });

    Widget buildWidget({
      VideoRecorderState recordingState = VideoRecorderState.idle,
      bool canRecord = true,
      bool isCameraInitialized = true,
      List<DivineVideoClip>? clips,
      VoidCallback? onBlockedTap,
    }) {
      when(() => recorderBloc.state).thenReturn(
        VideoRecorderBlocState(
          recordingState: recordingState,
          canRecord: canRecord,
          isCameraInitialized: isCameraInitialized,
        ),
      );

      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
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
              body: Center(child: RecordButton(onBlockedTap: onBlockedTap)),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $RecordButton', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(RecordButton), findsOneWidget);
      });

      testWidgets('renders GestureDetector', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(GestureDetector), findsOneWidget);
      });

      testWidgets('renders outer border container', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Two AnimatedContainers: outer border + inner dot
        expect(find.byType(AnimatedContainer), findsNWidgets(2));
      });
    });

    group('idle state', () {
      testWidgets('shows large inner circle when not recording', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Inner AnimatedContainer should have 64x64 size (round dot)
        final containers = tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .toList();
        // The inner container (second one) should be visible
        expect(containers.length, equals(2));
      });

      testWidgets('has semantic identifier', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final semantics = tester.getSemantics(find.byType(RecordButton));
        expect(semantics.tooltip, equals('Start recording'));
      });
    });

    group('recording state', () {
      testWidgets('shows square shape when recording', (tester) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RecordButton), findsOneWidget);
      });

      testWidgets('has semantic tooltip for stop', (tester) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        await tester.pumpAndSettle();

        final semantics = tester.getSemantics(find.byType(RecordButton));
        expect(semantics.tooltip, equals('Stop recording'));
      });
    });

    group('disabled state', () {
      testWidgets('is disabled when camera is not initialized', (tester) async {
        await tester.pumpWidget(buildWidget(isCameraInitialized: false));
        await tester.pumpAndSettle();

        // AnimatedOpacity should have reduced opacity
        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(0.5));
      });

      testWidgets('is disabled when canRecord is false', (tester) async {
        await tester.pumpWidget(buildWidget(canRecord: false));
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(0.5));
      });

      testWidgets('shows full opacity when enabled', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(1.0));
      });
    });

    group('blocked state', () {
      testWidgets('renders grayed out when onBlockedTap is provided', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(onBlockedTap: () {}));
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(0.5));
      });

      testWidgets('tap invokes onBlockedTap instead of starting recording', (
        tester,
      ) async {
        var blockedTaps = 0;
        await tester.pumpWidget(buildWidget(onBlockedTap: () => blockedTaps++));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(RecordButton));
        await tester.pumpAndSettle();

        expect(blockedTaps, equals(1));
        verifyNever(
          () => recorderBloc.add(const VideoRecorderRecordingToggleRequested()),
        );
        verifyNever(
          () => recorderBloc.add(const VideoRecorderRecordingStartRequested()),
        );
      });
    });

    group('accessibility', () {
      testWidgets('has Semantics identifier', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.identifier == SemanticIds.cameraRecordButton,
          ),
        );
        expect(semantics.properties.button, isTrue);
      });
    });

    // Regression tests for issue #4409 ("Phantom click"): an incidental
    // long-touch on the record button while a tap-started recording is
    // in progress must NOT dispatch a stop event on release.
    group('phantom click regression (issue #4409)', () {
      testWidgets('long-press release does not stop a tap-started recording', (
        tester,
      ) async {
        when(() => recorderBloc.state).thenReturn(
          const VideoRecorderBlocState(
            recordingState: VideoRecorderState.recording,
            canRecord: true,
            isCameraInitialized: true,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
              clipManagerProvider.overrideWith(
                () => _TestClipManagerNotifier(clips: const []),
              ),
            ],
            child: BlocProvider<VideoRecorderBloc>.value(
              value: recorderBloc,
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: Center(child: RecordButton())),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Simulate the user resting a finger on the shutter while a
        // tap-started take is already running.
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(RecordButton)),
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
        verifyNever(
          () => recorderBloc.add(const VideoRecorderRecordingToggleRequested()),
        );
      });

      testWidgets(
        'long-press from idle starts recording and release stops it',
        (tester) async {
          // Idle bloc state: ShutterGestureDetector tracks its own
          // _startedByLongPress flag, so the long-press start/stop
          // events both fire on a from-idle long-press regardless of
          // whether the bloc's recording state flips.
          when(() => recorderBloc.state).thenReturn(
            const VideoRecorderBlocState(
              canRecord: true,
              isCameraInitialized: true,
            ),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(sharedPreferences),
                clipManagerProvider.overrideWith(
                  () => _TestClipManagerNotifier(clips: const []),
                ),
              ],
              child: BlocProvider<VideoRecorderBloc>.value(
                value: recorderBloc,
                child: const MaterialApp(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(body: Center(child: RecordButton())),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(RecordButton)),
          );
          await tester.pump(const Duration(seconds: 1));
          await gesture.up();
          await tester.pumpAndSettle();

          verify(
            () =>
                recorderBloc.add(const VideoRecorderRecordingStartRequested()),
          ).called(1);
          verify(
            () => recorderBloc.add(const VideoRecorderRecordingStopRequested()),
          ).called(1);
        },
      );

      testWidgets(
        'hold-to-record preference starts on press-down and stops on release',
        (tester) async {
          await sharedPreferences.setBool('hold_to_record_enabled', true);
          when(() => recorderBloc.state).thenReturn(
            const VideoRecorderBlocState(
              canRecord: true,
              isCameraInitialized: true,
            ),
          );

          await tester.pumpWidget(buildWidget());
          await tester.pumpAndSettle();

          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(RecordButton)),
          );
          await tester.pump();

          verify(
            () =>
                recorderBloc.add(const VideoRecorderRecordingStartRequested()),
          ).called(1);
          verifyNever(
            () =>
                recorderBloc.add(const VideoRecorderRecordingToggleRequested()),
          );

          await gesture.up();
          await tester.pumpAndSettle();

          verify(
            () => recorderBloc.add(const VideoRecorderRecordingStopRequested()),
          ).called(1);
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
