// ABOUTME: Widget tests for VoiceOverRecorderView.
// ABOUTME: Covers rendering, record toggle, permission UI, done/close, and
// ABOUTME: how the recorder drives the editor preview behind it.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/voice_over/voice_over_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/video_editor/voice_over_recorder_screen.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:openvine/widgets/video_editor/voice_over/voice_over_video_timeline.dart';

class _MockVoiceOverCubit extends MockCubit<VoiceOverState>
    implements VoiceOverCubit {}

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

// The toolbar also renders DivineIcons (close/done), so match the warning icon
// specifically rather than by widget type.
final Finder _warningIcon = find.byWidgetPredicate(
  (widget) => widget is DivineIcon && widget.icon == DivineIconName.warning,
);

AudioEvent _take(String id, {double duration = 1}) =>
    AudioEvent.fromLocalImport(
      id: 'local_import_voice_over_$id',
      filePath: '/tmp/$id.m4a',
      createdAt: 0,
      title: 'Recorded audio',
      mimeType: 'audio/mp4',
      duration: duration,
    );

const _pause = VideoEditorExternalPauseRequested(isPaused: true);
const _resume = VideoEditorExternalPauseRequested(isPaused: false);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  setUpAll(() {
    registerFallbackValue(const VideoEditorSeekRequested(Duration.zero));
  });

  group(VoiceOverRecorderView, () {
    late _MockVoiceOverCubit cubit;

    setUp(() {
      cubit = _MockVoiceOverCubit();
      when(() => cubit.toggleRecording()).thenAnswer((_) async {});
      when(() => cubit.deleteLastTake()).thenAnswer((_) async {});
      when(() => cubit.discardAll()).thenAnswer((_) async {});
      when(() => cubit.openSettings()).thenAnswer((_) async {});
    });

    void stub(VoiceOverState state) => whenListen(
      cubit,
      const Stream<VoiceOverState>.empty(),
      initialState: state,
    );

    Widget buildSubject() {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<VoiceOverCubit>.value(
          value: cubit,
          child: const VoiceOverRecorderView(),
        ),
      );
    }

    group('renders', () {
      testWidgets('record control and hint when idle', (tester) async {
        stub(const VoiceOverState());

        await tester.pumpWidget(buildSubject());

        expect(
          find.bySemanticsLabel(l10n.videoEditorVoiceOverRecordSemanticLabel),
          findsOneWidget,
        );
        expect(find.text(l10n.videoEditorVoiceOverHint), findsOneWidget);
        expect(
          find.text(l10n.videoEditorVoiceOverRecordingsCount(0)),
          findsOneWidget,
        );
      });

      testWidgets('stop control while recording', (tester) async {
        stub(const VoiceOverState(status: VoiceOverStatus.recording));

        await tester.pumpWidget(buildSubject());

        expect(
          find.bySemanticsLabel(l10n.videoEditorVoiceOverStopSemanticLabel),
          findsOneWidget,
        );
      });

      testWidgets('keeps the stop control while a stopped take lands', (
        tester,
      ) async {
        stub(
          VoiceOverState(
            status: VoiceOverStatus.stopping,
            takes: [_take('a')],
            currentDuration: const Duration(seconds: 1),
            availableDuration: const Duration(seconds: 6),
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(
          find.bySemanticsLabel(l10n.videoEditorVoiceOverStopSemanticLabel),
          findsOneWidget,
        );
        // Done and delete wait for the take too.
        final toolbar = tester.widget<VideoEditorToolbar>(
          find.byType(VideoEditorToolbar),
        );
        expect(toolbar.onDone, isNull);
        expect(find.text(l10n.videoEditorVoiceOverDeleteLast), findsNothing);
        // The in-flight take still counts toward the readout.
        expect(find.text('0:02 / 0:06'), findsOneWidget);
      });

      testWidgets('recording count for captured takes', (tester) async {
        stub(VoiceOverState(takes: [_take('a'), _take('b')]));

        await tester.pumpWidget(buildSubject());

        expect(
          find.text(l10n.videoEditorVoiceOverRecordingsCount(2)),
          findsOneWidget,
        );
        expect(
          find.text(l10n.videoEditorVoiceOverDeleteLast),
          findsOneWidget,
        );
      });

      testWidgets('shows total recorded time over available length', (
        tester,
      ) async {
        stub(
          VoiceOverState(
            takes: [_take('a'), _take('b')],
            availableDuration: const Duration(seconds: 6),
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('0:02 / 0:06'), findsOneWidget);
      });

      testWidgets('marks the time readout red when audio is too long', (
        tester,
      ) async {
        stub(
          VoiceOverState(
            takes: [_take('a'), _take('b')],
            availableDuration: const Duration(seconds: 1),
          ),
        );

        await tester.pumpWidget(buildSubject());

        final readout = tester.widget<Text>(find.text('0:02 / 0:01'));
        expect(readout.style?.color, equals(VineTheme.error));
      });

      testWidgets('shows a non-color warning cue when audio is too long', (
        tester,
      ) async {
        stub(
          VoiceOverState(
            takes: [_take('a'), _take('b')],
            availableDuration: const Duration(seconds: 1),
          ),
        );

        await tester.pumpWidget(buildSubject());

        // Color alone misses color-blind users, so a warning icon accompanies
        // the red readout.
        expect(_warningIcon, findsOneWidget);
      });

      testWidgets('omits the warning cue when audio fits the video', (
        tester,
      ) async {
        stub(
          VoiceOverState(
            takes: [_take('a'), _take('b')],
            availableDuration: const Duration(seconds: 6),
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(_warningIcon, findsNothing);
      });

      testWidgets('count and time ignore voice-over already on the timeline', (
        tester,
      ) async {
        stub(
          const VoiceOverState(
            priorTakeCount: 3,
            availableDuration: Duration(seconds: 6),
          ),
        );

        await tester.pumpWidget(buildSubject());

        // Count and the time readout reset each session — prior takes only
        // affect the take numbering, which is applied in the cubit.
        expect(
          find.text(l10n.videoEditorVoiceOverRecordingsCount(0)),
          findsOneWidget,
        );
        expect(find.text('0:00 / 0:06'), findsOneWidget);
      });

      testWidgets('keeps the panel the same height once recording starts', (
        tester,
      ) async {
        final states = StreamController<VoiceOverState>();
        addTearDown(states.close);
        whenListen(
          cubit,
          states.stream,
          initialState: const VoiceOverState(
            availableDuration: Duration(seconds: 6),
          ),
        );
        await tester.pumpWidget(buildSubject());
        final idleStrip = tester.getRect(find.byType(VoiceOverVideoTimeline));
        expect(find.text(l10n.videoEditorVoiceOverHint), findsOneWidget);

        states.add(
          const VoiceOverState(
            status: VoiceOverStatus.recording,
            availableDuration: Duration(seconds: 6),
          ),
        );
        await tester.pump();

        // The hint goes but keeps its space, and the readout was there all
        // along, so nothing above the strip shifts.
        final hint = tester.widget<Visibility>(
          find.ancestor(
            of: find.text(l10n.videoEditorVoiceOverHint),
            matching: find.byType(Visibility),
          ),
        );
        expect(hint.visible, isFalse);
        expect(hint.maintainSize, isTrue);
        expect(tester.getRect(find.byType(VoiceOverVideoTimeline)), idleStrip);
      });

      testWidgets('the video timeline strip over a translucent scrim', (
        tester,
      ) async {
        stub(const VoiceOverState(availableDuration: Duration(seconds: 6)));

        await tester.pumpWidget(buildSubject());

        expect(find.byType(VoiceOverVideoTimeline), findsOneWidget);
        // The editor's preview plays on beneath the route, so the surface
        // must not cover it.
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(
          scaffold.backgroundColor?.a,
          closeTo(VoiceOverRecorderView.previewScrimAlpha, 0.01),
        );
      });

      testWidgets('keeps the dark palette over the preview in the light '
          'appearance', (tester) async {
        stub(const VoiceOverState(availableDuration: Duration(seconds: 6)));

        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.lightTheme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<VoiceOverCubit>.value(
              value: cubit,
              child: const VoiceOverRecorderView(),
            ),
          ),
        );

        // The ground is the footage, so the chrome stays dark with light
        // text — a light scrim over a video reads as haze.
        final hint = tester.widget<Text>(
          find.text(l10n.videoEditorVoiceOverHint),
        );
        expect(hint.style?.color, VineTheme.darkColors.mutedText);
        expect(
          VineTheme.lightColors.mutedText,
          isNot(VineTheme.darkColors.mutedText),
        );
      });

      testWidgets('no video timeline strip without a video length', (
        tester,
      ) async {
        stub(const VoiceOverState());

        await tester.pumpWidget(buildSubject());

        expect(find.byType(VoiceOverVideoTimeline), findsNothing);
      });

      testWidgets('permission prompt when denied', (tester) async {
        stub(
          const VoiceOverState(status: VoiceOverStatus.permissionDenied),
        );

        await tester.pumpWidget(buildSubject());

        expect(
          find.text(l10n.videoEditorVoiceOverPermissionTitle),
          findsOneWidget,
        );
        expect(
          find.text(l10n.videoEditorVoiceOverOpenSettings),
          findsOneWidget,
        );
      });

      testWidgets('hides the record button while permission is denied', (
        tester,
      ) async {
        stub(
          const VoiceOverState(status: VoiceOverStatus.permissionDenied),
        );

        await tester.pumpWidget(buildSubject());

        // The "Open Settings" CTA is the only action; the record button must
        // not compete with it.
        expect(
          find.bySemanticsLabel(l10n.videoEditorVoiceOverRecordSemanticLabel),
          findsNothing,
        );
        expect(
          find.bySemanticsLabel(l10n.videoEditorVoiceOverStopSemanticLabel),
          findsNothing,
        );
      });
    });

    group('interactions', () {
      testWidgets('tapping the record control toggles recording', (
        tester,
      ) async {
        stub(const VoiceOverState());

        await tester.pumpWidget(buildSubject());
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorVoiceOverRecordSemanticLabel),
        );

        verify(() => cubit.toggleRecording()).called(1);
      });

      testWidgets('tapping delete last removes the last take', (tester) async {
        stub(VoiceOverState(takes: [_take('a')]));

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text(l10n.videoEditorVoiceOverDeleteLast));

        verify(() => cubit.deleteLastTake()).called(1);
      });

      testWidgets('open settings delegates to the cubit', (tester) async {
        stub(
          const VoiceOverState(status: VoiceOverStatus.permissionDenied),
        );

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text(l10n.videoEditorVoiceOverOpenSettings));

        verify(() => cubit.openSettings()).called(1);
      });
    });

    group('waveform', () {
      testWidgets('animates while recording without leaking the ticker', (
        tester,
      ) async {
        final controller = StreamController<VoiceOverState>();
        addTearDown(controller.close);
        whenListen(
          cubit,
          controller.stream,
          initialState: const VoiceOverState(),
        );

        await tester.pumpWidget(buildSubject());

        controller.add(
          const VoiceOverState(
            status: VoiceOverStatus.recording,
            waveformBars: [0.4, 0.8],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);

        controller.add(const VoiceOverState());
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    });

    group('announcements', () {
      // Captures the messages SemanticsService.sendAnnouncement delivers on
      // the platform accessibility channel, mirroring the precedent in
      // conversation_view_test.dart.
      List<Object?> setUpAnnouncementCapture(WidgetTester tester) {
        final announced = <Object?>[];
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              (message) async {
                if (message is Map && message['type'] == 'announce') {
                  announced.add((message['data'] as Map?)?['message']);
                }
                return null;
              },
            );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<Object?>(
                SystemChannels.accessibility,
                null,
              ),
        );
        return announced;
      }

      testWidgets('announces when a take is saved (count grows)', (
        tester,
      ) async {
        final controller = StreamController<VoiceOverState>();
        addTearDown(controller.close);
        whenListen(
          cubit,
          controller.stream,
          initialState: const VoiceOverState(),
        );

        await tester.pumpWidget(buildSubject());
        final announced = setUpAnnouncementCapture(tester);

        controller.add(VoiceOverState(takes: [_take('a')]));
        await tester.pump();

        expect(announced, contains(l10n.videoEditorVoiceOverRecordingSaved));
      });

      testWidgets('does not announce "saved" when a take is deleted', (
        tester,
      ) async {
        final controller = StreamController<VoiceOverState>();
        addTearDown(controller.close);
        whenListen(
          cubit,
          controller.stream,
          initialState: VoiceOverState(takes: [_take('a'), _take('b')]),
        );

        await tester.pumpWidget(buildSubject());
        final announced = setUpAnnouncementCapture(tester);

        controller.add(VoiceOverState(takes: [_take('a')]));
        await tester.pump();

        expect(
          announced,
          isNot(contains(l10n.videoEditorVoiceOverRecordingSaved)),
        );
      });

      testWidgets('announces when recording starts', (tester) async {
        final controller = StreamController<VoiceOverState>();
        addTearDown(controller.close);
        whenListen(
          cubit,
          controller.stream,
          initialState: const VoiceOverState(),
        );

        await tester.pumpWidget(buildSubject());
        final announced = setUpAnnouncementCapture(tester);

        controller.add(
          const VoiceOverState(status: VoiceOverStatus.recording),
        );
        await tester.pump();

        expect(
          announced,
          contains(l10n.videoEditorVoiceOverRecordingStarted),
        );
      });

      testWidgets('announces when the recording first outgrows the video', (
        tester,
      ) async {
        final controller = StreamController<VoiceOverState>();
        addTearDown(controller.close);
        whenListen(
          cubit,
          controller.stream,
          initialState: const VoiceOverState(
            status: VoiceOverStatus.recording,
            availableDuration: Duration(seconds: 1),
          ),
        );

        await tester.pumpWidget(buildSubject());
        final announced = setUpAnnouncementCapture(tester);

        // The recorded time crosses past the 1s clip, flipping isOverAvailable.
        controller.add(
          const VoiceOverState(
            status: VoiceOverStatus.recording,
            availableDuration: Duration(seconds: 1),
            currentDuration: Duration(seconds: 2),
          ),
        );
        await tester.pump();

        expect(announced, contains(l10n.videoEditorVoiceOverTooLong));
      });
    });

    group('reduced motion', () {
      Widget buildReducedMotionSubject() {
        return MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: BlocProvider<VoiceOverCubit>.value(
              value: cubit,
              child: const VoiceOverRecorderView(),
            ),
          ),
        );
      }

      testWidgets('record button morph is instant when animations disabled', (
        tester,
      ) async {
        stub(const VoiceOverState());

        await tester.pumpWidget(buildReducedMotionSubject());

        final animated = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        expect(animated.duration, equals(Duration.zero));
      });

      testWidgets('record button morph animates when animations enabled', (
        tester,
      ) async {
        stub(const VoiceOverState());

        await tester.pumpWidget(buildSubject());

        final animated = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        expect(animated.duration, greaterThan(Duration.zero));
      });
    });

    group('editor preview', () {
      const available = Duration(seconds: 6);
      late _MockVideoEditorMainBloc editor;
      late ValueNotifier<Duration> playTime;

      setUp(() {
        editor = _MockVideoEditorMainBloc();
        whenListen(
          editor,
          const Stream<VideoEditorMainState>.empty(),
          initialState: const VideoEditorMainState(),
        );
        playTime = ValueNotifier(Duration.zero);
        addTearDown(playTime.dispose);
      });

      // Stubs the cubit with [initialState] and feeds it [states] once the
      // view listens, so a recording can be started and stopped from here.
      StreamController<VoiceOverState> stubStates(VoiceOverState initialState) {
        final states = StreamController<VoiceOverState>();
        addTearDown(states.close);
        whenListen(cubit, states.stream, initialState: initialState);
        return states;
      }

      Widget buildPreviewSubject() {
        return MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VoiceOverCubit>.value(value: cubit),
              BlocProvider<VideoEditorMainBloc>.value(value: editor),
            ],
            child: VoiceOverRecorderView(playTime: playTime),
          ),
        );
      }

      testWidgets('shows the frame the first take will open on', (
        tester,
      ) async {
        stub(
          VoiceOverState(
            takes: [_take('a', duration: 2)],
            availableDuration: available,
          ),
        );

        await tester.pumpWidget(buildPreviewSubject());

        verify(
          () =>
              editor.add(const VideoEditorSeekRequested(Duration(seconds: 2))),
        ).called(1);
        verifyNever(() => editor.add(_resume));
      });

      testWidgets("plays the preview from the take's start when recording "
          'begins', (tester) async {
        final states = stubStates(
          VoiceOverState(
            takes: [_take('a', duration: 2)],
            availableDuration: available,
          ),
        );
        await tester.pumpWidget(buildPreviewSubject());
        clearInteractions(editor);

        states.add(
          VoiceOverState(
            status: VoiceOverStatus.recording,
            takes: [_take('a', duration: 2)],
            availableDuration: available,
          ),
        );
        await tester.pump();

        // The pause is re-asserted first so the resume is a real state
        // change even after a request the canvas dropped.
        verifyInOrder([
          () => editor.add(_pause),
          () => editor.add(
            const VideoEditorSeekRequested(Duration(seconds: 2)),
          ),
          () => editor.add(_resume),
        ]);
      });

      testWidgets("catches the preview up when the editor's player comes back "
          'mid-take', (tester) async {
        final editorStates = StreamController<VideoEditorMainState>();
        addTearDown(editorStates.close);
        whenListen(
          editor,
          editorStates.stream,
          initialState: const VideoEditorMainState(),
        );
        final states = stubStates(
          const VoiceOverState(availableDuration: available),
        );
        await tester.pumpWidget(buildPreviewSubject());
        states.add(
          const VoiceOverState(
            status: VoiceOverStatus.recording,
            currentDuration: Duration(milliseconds: 1500),
            availableDuration: available,
          ),
        );
        await tester.pump();
        clearInteractions(editor);

        editorStates.add(const VideoEditorMainState(isPlayerReady: true));
        await tester.pump();

        // Seeks to where the take already is, not to its start.
        verifyInOrder([
          () => editor.add(_pause),
          () => editor.add(
            const VideoEditorSeekRequested(Duration(milliseconds: 1500)),
          ),
          () => editor.add(_resume),
        ]);
      });

      testWidgets("parks the preview when the editor's player comes back "
          'between takes', (tester) async {
        final editorStates = StreamController<VideoEditorMainState>();
        addTearDown(editorStates.close);
        whenListen(
          editor,
          editorStates.stream,
          initialState: const VideoEditorMainState(),
        );
        stub(
          VoiceOverState(
            takes: [_take('a', duration: 2)],
            availableDuration: available,
          ),
        );
        await tester.pumpWidget(buildPreviewSubject());
        clearInteractions(editor);

        editorStates.add(const VideoEditorMainState(isPlayerReady: true));
        await tester.pump();

        verify(
          () =>
              editor.add(const VideoEditorSeekRequested(Duration(seconds: 2))),
        ).called(1);
        verifyNever(() => editor.add(_resume));
      });

      testWidgets('holds the preview the moment a take is stopped, without '
          'seeking', (tester) async {
        final states = stubStates(
          const VoiceOverState(
            status: VoiceOverStatus.recording,
            currentDuration: Duration(seconds: 2),
            availableDuration: available,
          ),
        );
        await tester.pumpWidget(buildPreviewSubject());
        clearInteractions(editor);

        // Stopping comes first, while the recorder is still closing its file.
        states.add(
          const VoiceOverState(
            status: VoiceOverStatus.stopping,
            currentDuration: Duration(seconds: 2),
            availableDuration: available,
          ),
        );
        await tester.pump();

        verify(() => editor.add(_pause)).called(1);

        // The take landing moves the next start, but the preview stays on the
        // frame it stopped on: a corrective seek read as the video jumping
        // back, and the next take seeks to its own start anyway.
        states.add(
          VoiceOverState(
            takes: [_take('a', duration: 2)],
            availableDuration: available,
          ),
        );
        await tester.pump();

        verifyNever(
          () => editor.add(any(that: isA<VideoEditorSeekRequested>())),
        );
        verifyNever(() => editor.add(_resume));
      });

      testWidgets('pauses the preview just before the video runs out', (
        tester,
      ) async {
        final states = stubStates(
          const VoiceOverState(availableDuration: available),
        );
        await tester.pumpWidget(buildPreviewSubject());
        states.add(
          const VoiceOverState(
            status: VoiceOverStatus.recording,
            availableDuration: available,
          ),
        );
        await tester.pump();
        clearInteractions(editor);

        playTime.value = const Duration(seconds: 3);
        await tester.pump();
        verifyNever(() => editor.add(_pause));

        playTime.value = const Duration(milliseconds: 5900);
        await tester.pump();
        verify(() => editor.add(_pause)).called(1);

        // The pause is one-shot: the frames after it are not re-paused.
        playTime.value = const Duration(milliseconds: 5950);
        await tester.pump();
        verifyNever(() => editor.add(_pause));
      });

      testWidgets('leaves the preview alone at the end while not recording', (
        tester,
      ) async {
        stub(const VoiceOverState(availableDuration: available));
        await tester.pumpWidget(buildPreviewSubject());
        clearInteractions(editor);

        playTime.value = const Duration(milliseconds: 5950);
        await tester.pump();

        verifyNever(() => editor.add(_pause));
      });

      testWidgets(
        'parks the preview at the new start after a take is deleted',
        (
          tester,
        ) async {
          final states = stubStates(
            VoiceOverState(
              takes: [_take('a', duration: 2), _take('b')],
              availableDuration: available,
            ),
          );
          await tester.pumpWidget(buildPreviewSubject());
          clearInteractions(editor);

          states.add(
            VoiceOverState(
              takes: [_take('a', duration: 2)],
              availableDuration: available,
            ),
          );
          await tester.pump();

          verify(
            () => editor.add(
              const VideoEditorSeekRequested(Duration(seconds: 2)),
            ),
          ).called(1);
        },
      );

      testWidgets('is inert without an editor behind the route', (
        tester,
      ) async {
        final states = stubStates(
          const VoiceOverState(availableDuration: available),
        );
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<VoiceOverCubit>.value(
              value: cubit,
              child: VoiceOverRecorderView(playTime: playTime),
            ),
          ),
        );

        states.add(
          const VoiceOverState(
            status: VoiceOverStatus.recording,
            availableDuration: available,
          ),
        );
        await tester.pump();
        playTime.value = const Duration(milliseconds: 5950);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(VoiceOverVideoTimeline), findsOneWidget);
      });
    });

    group('navigation', () {
      // Pushes the view and records the pop result into [onResult] when the
      // route completes (after Done/Close pops it).
      Future<void> pushView(
        WidgetTester tester,
        void Function(List<AudioEvent>? result) onResult,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    onResult(
                      await Navigator.of(context).push<List<AudioEvent>>(
                        MaterialPageRoute<List<AudioEvent>>(
                          builder: (_) => BlocProvider<VoiceOverCubit>.value(
                            value: cubit,
                            child: const VoiceOverRecorderView(),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      testWidgets('done returns the recorded takes', (tester) async {
        final takes = [_take('a'), _take('b')];
        stub(VoiceOverState(takes: takes));

        List<AudioEvent>? captured;
        var popped = false;
        await pushView(tester, (result) {
          captured = result;
          popped = true;
        });

        await tester.tap(
          find.bySemanticsLabel(
            l10n.videoEditorApplyToolChangesSemanticLabel(
              l10n.videoEditorVoiceOverLabel,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(popped, isTrue);
        expect(captured, equals(takes));
        // Done commits the takes so the cubit's close() keeps their files.
        verify(() => cubit.markCommitted()).called(1);
      });

      testWidgets('close discards takes and returns nothing', (tester) async {
        stub(VoiceOverState(takes: [_take('a')]));

        List<AudioEvent>? captured;
        var popped = false;
        await pushView(tester, (result) {
          captured = result;
          popped = true;
        });

        await tester.tap(
          find.bySemanticsLabel(
            l10n.videoEditorDiscardToolChangesSemanticLabel(
              l10n.videoEditorVoiceOverLabel,
            ),
          ),
        );
        await tester.pumpAndSettle();

        verify(() => cubit.discardAll()).called(1);
        expect(popped, isTrue);
        expect(captured, isNull);
        expect(find.byType(VoiceOverRecorderView), findsNothing);
      });
    });
  });

  group(VoiceOverRecorderScreen, () {
    testWidgets('builds its own cubit without reading l10n in create', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderScope(
            child: VoiceOverRecorderScreen(
              availableDuration: Duration(seconds: 6),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(VoiceOverRecorderView), findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.videoEditorVoiceOverRecordSemanticLabel),
        findsOneWidget,
      );
    });
  });
}
