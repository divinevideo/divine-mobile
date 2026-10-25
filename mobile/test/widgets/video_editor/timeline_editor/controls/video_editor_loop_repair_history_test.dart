import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/blocs/video_editor/loop_suggestion/loop_suggestion_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_actions_sheet.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_loop_repair_listener.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

import '../../../../helpers/video_editor/loop_repair.dart';

class _Editor extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_Editor';
}

class _Main extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _Draw extends MockBloc<VideoEditorDrawEvent, VideoEditorDrawState>
    implements VideoEditorDrawBloc {}

class _Tune extends MockBloc<VideoEditorTuneEvent, VideoEditorTuneState>
    implements VideoEditorTuneBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      LoopRepairInput(clips: const [], revision: 'fallback'),
    );
    registerFallbackValue(const VideoEditorAuditionEnded());
    registerFallbackValue(const LoopRepairResult(status: .noMatch));
  });
  group('LoopRepairResultListener interactions', () {
    for (final (brightness, foreign, longRecording) in [
      for (final brightness in Brightness.values)
        for (final foreign in [false, true])
          for (final longRecording in [false, true])
            (brightness, foreign, longRecording),
    ]) {
      testWidgets(
        'one history edit releases audio anchors, waits for player and offers Undo in $brightness (foreign preview: $foreign, long recording: $longRecording)',
        (tester) async {
          final clip = DivineVideoClip(
            id: 'a',
            video: EditorVideo.file('/documents/a.mp4'),
            duration: longRecording
                ? const Duration(milliseconds: 8140)
                : const Duration(seconds: 4),
            trimStart: longRecording
                ? Duration.zero
                : const Duration(seconds: 1),
            trimEnd: longRecording ? Duration.zero : const Duration(seconds: 1),
            recordedAt: DateTime(2026),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );
          final clipBloc = ClipEditorBloc(
            onFinalClipInvalidated: () {},
            saveClipToLibrary: ({required clip}) async => false,
          );
          final initialized = clipBloc.stream.firstWhere(
            (s) => s.clips.isNotEmpty,
          );
          clipBloc.add(ClipEditorInitialized([clip]));
          await tester.pump();
          await initialized;
          final main = _Main();
          final draw = _Draw();
          final tune = _Tune();
          when(() => draw.state).thenReturn(const VideoEditorDrawState());
          when(() => tune.state).thenReturn(
            const VideoEditorTuneState(
              adjustments: VideoEditorConstants.tuneAdjustments,
            ),
          );
          final playerStates =
              StreamController<VideoEditorMainState>.broadcast();
          whenListen(
            main,
            playerStates.stream,
            initialState: const VideoEditorMainState(isPlayerReady: true),
          );
          final overlays = TimelineOverlayBloc();
          final editor = _Editor();
          final stateManager = StateManager(
            onStateHistoryChange: () {},
            activeBackgroundImage: null,
          );
          final sound = model.AudioEvent(
            id: 'sound',
            pubkey: 'bundled',
            createdAt: 0,
            url: 'asset://sounds/test.mp3',
            duration: 4,
            startOffset: const Duration(seconds: 1),
            endTime: const Duration(seconds: 2),
            anchorClipId: 'a',
          );
          stateManager.activeMeta = {
            VideoEditorConstants.audioStateHistoryKey: [sound.toJson()],
          };
          when(() => editor.mounted).thenReturn(true);
          when(() => editor.activeLayers).thenReturn([]);
          when(() => editor.stateManager).thenReturn(stateManager);
          when(
            () => editor.setState(any()),
          ).thenAnswer(
            (c) => (c.positionalArguments.single as VoidCallback)(),
          );
          final histories = <Map<String, dynamic>>[];
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
          ).thenAnswer((call) {
            histories.add(
              Map<String, dynamic>.from(call.namedArguments[#meta] as Map),
            );
          });
          final repository = MockLoopAlignmentRepository();
          final gate = Completer<LoopRepairResult>();
          when(
            () => repository.repair(
              any(),
              taskId: any(named: 'taskId'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer((_) => gate.future);
          when(() => repository.cancel(any())).thenAnswer((_) async {});
          when(() => repository.discard(any())).thenAnswer((_) async {});
          final cubit = LoopSuggestionCubit(repository: repository);
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            final closing = Future.wait([
              cubit.close(),
              clipBloc.close(),
              overlays.close(),
              playerStates.close(),
            ]);
            // Bloc shutdown crosses the test and teardown zones in several stages.
            var closed = false;
            unawaited(closing.then((_) => closed = true));
            for (var i = 0; i < 20 && !closed; i++) {
              await tester.pump();
            }
            expect(
              closed,
              isTrue,
              reason: 'Editor blocs must finish shutdown',
            );
            await closing;
          });
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
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
                  playheadAdvancingNotifier: ValueNotifier(false),
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
                      BlocProvider<VideoEditorMainBloc>.value(value: main),
                      BlocProvider<TimelineOverlayBloc>.value(
                        value: overlays,
                      ),
                      BlocProvider.value(value: cubit),
                      BlocProvider<VideoEditorDrawBloc>.value(value: draw),
                      BlocProvider<VideoEditorTuneBloc>.value(value: tune),
                    ],
                    child: LoopRepairResultListener(
                      child: Builder(
                        builder: (context) => Column(
                          children: [
                            TextButton(
                              onPressed: () => alignEditorLoop(context),
                              child: const Text('Align loop'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  VideoEditorMainActionsSheet.show(context),
                              child: const Text('More edit'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('More edit'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label ==
                      lookupAppLocalizations(const Locale('en'))
                          .videoEditorLoopSemanticLabel,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          final input =
              verify(
                    () => repository.repair(
                      captureAny(),
                      taskId: any(named: 'taskId'),
                      onProgress: any(named: 'onProgress'),
                    ),
                  ).captured.single
                  as LoopRepairInput;
          expect(input.capability, LoopRepairCapability.supported);
          expect(
            input.clips.single.sourceEnd,
            longRecording
                ? const Duration(milliseconds: 6300)
                : const Duration(seconds: 3),
          );
          final exportClip = longRecording
              ? clip.copyWith(trimEnd: const Duration(milliseconds: 1840))
              : clip;
          gate.complete(repairedLoopResult([exportClip]));
          await tester.pumpAndSettle();
          expect(histories, hasLength(1));
          expect(
            clipBloc.state.totalDuration,
            longRecording
                ? const Duration(milliseconds: 6300)
                : const Duration(seconds: 2),
          );
          expect(
            clip.duration,
            longRecording
                ? const Duration(milliseconds: 8140)
                : const Duration(seconds: 4),
          );
          final audio =
              (histories.single[VideoEditorConstants.audioStateHistoryKey]
                          as List)
                      .single
                  as Map;
          expect(audio['anchorClipId'], isNull);
          expect(audio['startOffsetMs'], 1000);
          expect(audio['startTimeMs'], isNull);
          expect(audio['endTimeMs'], 2000);
          expect(find.text('Loop smoothed'), findsOneWidget);
          expect(find.text('Keep'), findsNothing);
          verifyNever(
            () => main.add(any(that: isA<VideoEditorAuditionStarted>())),
          );
          playerStates.add(const VideoEditorMainState());
          await tester.pump();
          playerStates.add(const VideoEditorMainState(isPlayerReady: true));
          await tester.pump();
          final recorded = verify(
            () => main.add(captureAny(that: isA<VideoEditorAuditionStarted>())),
          );
          recorded.called(1);
          final started =
              recorded.captured.single as VideoEditorAuditionStarted;
          expect(started.owner, isNotNull);
          await tester.pumpAndSettle();
          final undo = tester
              .widget<SnackBarAction>(find.byType(SnackBarAction))
              .onPressed;
          // Align loop remains available while its own seam preview is playing.
          playerStates.add(
            VideoEditorMainState(
              isPlayerReady: true,
              audition: (start: started.start, end: started.end),
              auditionOwner: started.owner,
            ),
          );
          await tester.pump();
          if (foreign) {
            final screenContext = tester.element(find.text('Align loop'));
            unawaited(
              showModalBottomSheet<void>(
                context: screenContext,
                builder: (_) => const SizedBox(height: 100),
              ),
            );
            // Another feature can own the exact same playback range.
            playerStates.add(
              VideoEditorMainState(
                isPlayerReady: true,
                audition: (start: started.start, end: started.end),
              ),
            );
            await tester.pumpAndSettle();
            verifyNever(
              () => main.add(any(that: isA<VideoEditorAuditionEnded>())),
            );
            Navigator.of(screenContext).pop();
            await tester.pumpAndSettle();
            undo();
            verify(editor.undoAction).called(1);
            return;
          }
          when(
            () => repository.repair(
              any(),
              taskId: any(named: 'taskId'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer(
            (_) async => const LoopRepairResult(status: .alreadySmooth),
          );
          await tester.tap(find.text('Align loop'));
          await tester.pumpAndSettle();
          verify(
            () => repository.repair(
              any(),
              taskId: any(named: 'taskId'),
              onProgress: any(named: 'onProgress'),
            ),
          ).called(1);
          undo();
          verify(editor.undoAction).called(1);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  });
}
