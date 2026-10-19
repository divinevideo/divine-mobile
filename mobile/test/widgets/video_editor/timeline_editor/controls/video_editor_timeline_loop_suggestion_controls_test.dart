// ABOUTME: Widget tests for the loop suggestion bar and its result listener:
// ABOUTME: previewing the new end, keeping it as one step, putting it back.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/loop_suggestion/loop_suggestion_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_loop_suggestion_controls.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockMainBloc extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

void main() {
  const s = Duration(seconds: 1);
  const ms = Duration(milliseconds: 1);

  final clip = DivineVideoClip(
    id: 'clip',
    video: EditorVideo.file('/tmp/clip.mp4'),
    duration: s * 3,
    recordedAt: DateTime(2026),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
  );

  group(LoopSuggestionResultListener, () {
    late _MockClipEditorBloc clipBloc;
    late _MockMainBloc mainBloc;
    late _MockTimelineOverlayBloc overlayBloc;
    late _MockProImageEditorState editor;
    late StreamController<ClipEditorState> clipStates;
    late StreamController<VideoEditorMainState> mainStates;
    late LoopSuggestionCubit cubit;

    setUpAll(() {
      registerFallbackValue(const ClipEditorEditingStopped());
      registerFallbackValue(const VideoEditorAuditionEnded());
    });

    setUp(() {
      clipBloc = _MockClipEditorBloc();
      mainBloc = _MockMainBloc();
      overlayBloc = _MockTimelineOverlayBloc();
      editor = _MockProImageEditorState();
      clipStates = StreamController<ClipEditorState>.broadcast();
      mainStates = StreamController<VideoEditorMainState>.broadcast();
      when(() => clipBloc.state).thenReturn(ClipEditorState(clips: [clip]));
      when(() => clipBloc.stream).thenAnswer((_) => clipStates.stream);
      when(
        () => mainBloc.state,
      ).thenReturn(const VideoEditorMainState(isPlayerReady: true));
      when(() => mainBloc.stream).thenAnswer((_) => mainStates.stream);
      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());

      final stateManager = _MockStateManager();
      when(() => editor.mounted).thenReturn(true);
      when(() => editor.stateManager).thenReturn(stateManager);
      when(() => stateManager.activeMeta).thenReturn(const {});
      when(
        () => editor.addHistory(
          layers: any(named: 'layers'),
          filters: any(named: 'filters'),
          meta: any(named: 'meta'),
          newLayer: any(named: 'newLayer'),
          transformConfigs: any(named: 'transformConfigs'),
          tuneAdjustments: any(named: 'tuneAdjustments'),
          blur: any(named: 'blur'),
          heroScreenshotRequired: any(named: 'heroScreenshotRequired'),
          blockCaptureScreenshot: any(named: 'blockCaptureScreenshot'),
        ),
      ).thenAnswer((_) {});
      when(() => editor.setState(any())).thenAnswer((invocation) {
        (invocation.positionalArguments.single as VoidCallback)();
      });

      cubit = LoopSuggestionCubit(
        findLoopPoint: ({required search, required taskId, onProgress}) async =>
            const VideoLoopPoint(
              start: Duration.zero,
              end: Duration(milliseconds: 2500),
              difference: 0.01,
              currentDifference: 0.2,
            ),
      );
    });

    tearDown(() async {
      await cubit.close();
      await clipStates.close();
      await mainStates.close();
    });

    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorScope(
              editorKey: GlobalKey<ProImageEditorState>(),
              editorOverride: editor,
              removeAreaKey: GlobalKey(),
              originalClipAspectRatio: 9 / 16,
              bodySizeNotifier: ValueNotifier(const Size(400, 600)),
              zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
              playTimeNotifier: ValueNotifier(Duration.zero),
              playheadAdvancingNotifier: ValueNotifier<bool>(false),
              fromLibrary: false,
              onOpenCamera: () {},
              onOpenClipsEditor: () {},
              onAddStickers: () {},
              onOpenMusicLibrary: () {},
              onOpenVoiceOver: () {},
              onOpenCaptions: () {},
              onOpenEffects: () {},
              onAddEditTextLayer: ([layer]) async => null,
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<ClipEditorBloc>.value(value: clipBloc),
                  BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
                  BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
                  BlocProvider.value(value: cubit),
                ],
                child: const LoopSuggestionResultListener(
                  child: TimelineLoopSuggestionControls(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    /// Searches, then reports the suggested clip as the clip editor's state,
    /// as the clip update the preview sends would.
    Future<DivineVideoClip> findSuggestion(WidgetTester tester) async {
      await pump(tester);
      await cubit.search([clip]);
      await tester.pump();
      final suggested = cubit.state.suggested!;
      when(
        () => clipBloc.state,
      ).thenReturn(ClipEditorState(clips: [suggested]));
      clipStates.add(ClipEditorState(clips: [suggested]));
      await tester.pump();
      // The player reloads the clips for the new end.
      mainStates
        ..add(const VideoEditorMainState())
        ..add(const VideoEditorMainState(isPlayerReady: true));
      await tester.pump();
      return suggested;
    }

    List<Object?> clipEvents() =>
        verify(() => clipBloc.add(captureAny())).captured;
    List<Object?> mainEvents() =>
        verify(() => mainBloc.add(captureAny())).captured;

    testWidgets('puts the smoother end on the clip and plays its seam', (
      tester,
    ) async {
      await findSuggestion(tester);

      final update = clipEvents().whereType<ClipEditorClipUpdated>().single;
      expect(update.clip.trimEnd, ms * 500);
      final audition = mainEvents()
          .whereType<VideoEditorAuditionStarted>()
          .single;
      // 1.2 s on each side of the seam at 2.5 s.
      expect(audition.start, ms * 1300);
      expect(audition.end, ms * 1200);
      expect(
        find.text('Smoother loop found. It ends 0.5 s earlier.'),
        findsOneWidget,
      );
    });

    testWidgets('waits for the player to load the new end before playing', (
      tester,
    ) async {
      await pump(tester);
      await cubit.search([clip]);
      await tester.pump();

      verifyNever(
        () => mainBloc.add(any(that: isA<VideoEditorAuditionStarted>())),
      );
    });

    testWidgets('Cancel puts the old end back and stops the seam', (
      tester,
    ) async {
      await findSuggestion(tester);
      clearInteractions(clipBloc);

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      final update = clipEvents().whereType<ClipEditorClipUpdated>().single;
      expect(update.clip.trimEnd, Duration.zero);
      expect(cubit.state.status, LoopSuggestionStatus.idle);
      expect(
        mainEvents().whereType<VideoEditorAuditionEnded>(),
        hasLength(1),
      );
    });

    testWidgets('Keep writes the new end as one undo step', (tester) async {
      await findSuggestion(tester);
      clearInteractions(clipBloc);

      await tester.tap(find.text('Keep'));
      await tester.pump();

      final meta =
          verify(
                () => editor.addHistory(
                  layers: any(named: 'layers'),
                  filters: any(named: 'filters'),
                  meta: captureAny(named: 'meta'),
                  newLayer: any(named: 'newLayer'),
                  transformConfigs: any(named: 'transformConfigs'),
                  tuneAdjustments: any(named: 'tuneAdjustments'),
                  blur: any(named: 'blur'),
                  heroScreenshotRequired: any(named: 'heroScreenshotRequired'),
                  blockCaptureScreenshot: any(named: 'blockCaptureScreenshot'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      final clips = meta[VideoEditorConstants.clipsStateHistoryKey] as List;
      expect((clips.single as Map<String, dynamic>)['trimEndMs'], 500);
      verifyNever(() => clipBloc.add(any(that: isA<ClipEditorClipUpdated>())));
      expect(cubit.state.status, LoopSuggestionStatus.idle);
    });

    testWidgets('lets go of the suggestion once the clip is trimmed by hand', (
      tester,
    ) async {
      await findSuggestion(tester);

      clipStates.add(
        ClipEditorState(clips: [clip.copyWith(trimEnd: ms * 900)]),
      );
      await tester.pump();

      expect(cubit.state.status, LoopSuggestionStatus.idle);
    });
  });
}
