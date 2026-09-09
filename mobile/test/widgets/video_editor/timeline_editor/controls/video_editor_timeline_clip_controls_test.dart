// ABOUTME: Widget tests for TimelineClipControls.
// ABOUTME: Verifies visible actions and done-event dispatch.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_clip_speed_sheet.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_clip_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_controls.dart';
import 'package:pro_image_editor/features/main_editor/services/sizes_manager.dart'
    show SizesManager;
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

class _MockSizesManager extends Mock implements SizesManager {}

void main() {
  group(TimelineClipControls, () {
    late _MockClipEditorBloc bloc;

    setUpAll(() {
      registerFallbackValue(const ClipEditorEditingStopped());
    });

    setUp(() {
      bloc = _MockClipEditorBloc();
      when(() => bloc.state).thenReturn(const ClipEditorState());
      when(
        () => bloc.stream,
      ).thenAnswer((_) => const Stream<ClipEditorState>.empty());
      // The save dispatch guards on `bloc.isClosed` after the capture await.
      when(() => bloc.isClosed).thenReturn(false);
    });

    Widget build() {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<ClipEditorBloc>.value(
              value: bloc,
              child: TimelineClipControls(
                playheadPosition: ValueNotifier(Duration.zero),
              ),
            ),
          ),
        ),
      );
    }

    DivineVideoClip clip(String id) => DivineVideoClip(
      id: id,
      video: EditorVideo.file('/tmp/$id.mp4'),
      duration: const Duration(seconds: 3),
      recordedAt: DateTime(2025),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
    );

    DivineVideoClip stopMotionClip(String id) => DivineVideoClip(
      id: id,
      duration: const Duration(milliseconds: 200),
      recordedAt: DateTime(2025),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
      stopMotionFrames: const [
        StopMotionClipFrame(
          path: '/tmp/frame-0.jpg',
          duration: Duration(milliseconds: 100),
        ),
        StopMotionClipFrame(
          path: '/tmp/frame-1.jpg',
          duration: Duration(milliseconds: 100),
        ),
      ],
    );

    Future<VideoEditorTimelineControls> pumpWithMissingEditorScope(
      WidgetTester tester, {
      ClipEditorState? state,
    }) async {
      when(() => bloc.state).thenReturn(
        state ?? ClipEditorState(clips: [clip('clip-1'), clip('clip-2')]),
      );
      final overlayBloc = _MockTimelineOverlayBloc();
      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
      when(
        () => overlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              // An unattached editorKey => VideoEditorScope.editor is null,
              // reproducing a gesture that resolves after the editor route
              // was popped.
              body: VideoEditorScope(
                editorKey: GlobalKey<ProImageEditorState>(),
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
                onAddEditTextLayer: ([layer]) async => null,
                child: MultiBlocProvider(
                  providers: [
                    BlocProvider<ClipEditorBloc>.value(value: bloc),
                    BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
                  ],
                  child: TimelineClipControls(
                    playheadPosition: ValueNotifier(Duration.zero),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      return tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
    }

    // Stubs an editor whose history writes are captured rather than applied.
    // [activeMeta] seeds the editor's current history entry, so a test that
    // needs an existing sound passes its serialized audio key here.
    void stubEditor({
      required _MockProImageEditorState editor,
      required _MockTimelineOverlayBloc overlayBloc,
      Map<String, dynamic> activeMeta = const {},
    }) {
      final stateManager = _MockStateManager();
      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
      when(
        () => overlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());
      when(() => editor.stateManager).thenReturn(stateManager);
      when(() => stateManager.activeMeta).thenReturn(activeMeta);
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
    }

    // Pumps the controls inside a VideoEditorScope backed by [editor]. Routed
    // rather than a plain MaterialApp because the speed sheet confirms via
    // `context.pop`.
    Future<VideoEditorTimelineControls> pumpWithEditor(
      WidgetTester tester, {
      required _MockProImageEditorState editor,
      required _MockTimelineOverlayBloc overlayBloc,
      required ClipEditorState state,
    }) async {
      when(() => bloc.state).thenReturn(state);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, routerState) => Scaffold(
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
                      onAddEditTextLayer: ([layer]) async => null,
                      child: MultiBlocProvider(
                        providers: [
                          BlocProvider<ClipEditorBloc>.value(value: bloc),
                          BlocProvider<TimelineOverlayBloc>.value(
                            value: overlayBloc,
                          ),
                        ],
                        child: TimelineClipControls(
                          playheadPosition: ValueNotifier(Duration.zero),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
    }

    // The meta of the single history entry [editor] was asked to commit.
    Map<String, dynamic> capturedHistoryMeta(
      _MockProImageEditorState editor,
    ) =>
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

    testWidgets('renders expected labels for single-clip state', (
      tester,
    ) async {
      await tester.pumpWidget(build());

      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Split'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('offers Detach on an ordinary clip', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(ClipEditorState(clips: [clip('clip-1')]));

      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      expect(controls.onDetach, isNotNull);
    });

    testWidgets('hides Detach on a placeholder clip', (tester) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [clip('clip-1').copyWith(isPlaceholder: true)],
        ),
      );

      await tester.pumpWidget(build());

      // A placeholder is the still that already stands in for a detached clip.
      // Detaching it would put a frozen frame on the canvas and ask for a
      // second still to take its place.
      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      expect(controls.onDetach, isNull);
      expect(find.text('Detach'), findsNothing);
    });

    testWidgets('dispatches ClipEditorEditingStopped when done pressed', (
      tester,
    ) async {
      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      controls.onDone!();
      await tester.pump();

      verify(() => bloc.add(const ClipEditorEditingStopped())).called(1);
    });

    testWidgets(
      'dispatches ClipEditorClipReverseRequested when reverse pressed',
      (tester) async {
        final state = ClipEditorState(
          clips: [
            DivineVideoClip(
              id: 'clip-1',
              video: EditorVideo.file('/tmp/clip-1.mp4'),
              duration: const Duration(seconds: 3),
              recordedAt: DateTime(2025),
              targetAspectRatio: model.AspectRatio.vertical,
              originalAspectRatio: 9 / 16,
            ),
          ],
        );
        final l10n = lookupAppLocalizations(const Locale('en'));
        when(() => bloc.state).thenReturn(state);

        await tester.pumpWidget(build());

        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorReverseClipSemanticLabel),
        );
        await tester.pump();

        verify(
          () =>
              bloc.add(const ClipEditorClipReverseRequested(clipId: 'clip-1')),
        ).called(1);
      },
    );

    // Done stays tappable during a render — leaving edit mode is safe because
    // the extraction result is committed by an editor-session-level listener
    // (VideoEditorScaffold) that survives these controls unmounting.
    testWidgets('Done stays enabled and dispatches stop while extracting', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [clip('clip-1')],
          isExtractingAudio: true,
          extractingAudioClipId: 'clip-1',
        ),
      );
      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      expect(controls.onDone, isNotNull);

      controls.onDone!();
      await tester.pump();

      verify(() => bloc.add(const ClipEditorEditingStopped())).called(1);
    });

    // Regression: the Speed action must stay mounted (disabled), not vanish,
    // while the *current* clip's audio is extracting — the disappearing
    // control confused users.
    testWidgets(
      "Speed stays mounted and is disabled while the current clip's audio "
      'extracts',
      (tester) async {
        when(() => bloc.state).thenReturn(
          ClipEditorState(
            clips: [clip('clip-1'), clip('clip-2')],
            isExtractingAudio: true,
            extractingAudioClipId: 'clip-1',
          ),
        );
        await tester.pumpWidget(build());

        final controls = tester.widget<VideoEditorTimelineControls>(
          find.byType(VideoEditorTimelineControls),
        );
        // Action stays wired; the child renders it disabled via
        // isExtractingAudio.
        expect(controls.onSpeed, isNotNull);
        expect(controls.isExtractingAudio, isTrue);
      },
    );

    // A render on a *different* clip must not block the current clip's Speed.
    testWidgets(
      "Speed stays enabled while a different clip's audio extracts",
      (tester) async {
        when(() => bloc.state).thenReturn(
          ClipEditorState(
            clips: [clip('clip-1'), clip('clip-2')],
            currentClipIndex: 1,
            isExtractingAudio: true,
            extractingAudioClipId: 'clip-1',
          ),
        );
        await tester.pumpWidget(build());

        final controls = tester.widget<VideoEditorTimelineControls>(
          find.byType(VideoEditorTimelineControls),
        );
        expect(controls.onSpeed, isNotNull);
        expect(controls.isExtractingAudio, isFalse);
      },
    );

    testWidgets('Green screen shows as busy while the current clip bakes', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [clip('clip-1'), clip('clip-2')],
          isChromaKeying: true,
          chromaKeyingClipId: 'clip-1',
          chromaKeyingRenderId: 'clip-1_chromakey',
        ),
      );
      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      // `chromaKeyingClipId` is the clip's own id, not the render id the bake
      // runs under — comparing against the latter silently never matches.
      expect(controls.isChromaKeying, isTrue);
    });

    testWidgets('Green screen stays enabled while a different clip bakes', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [clip('clip-1'), clip('clip-2')],
          currentClipIndex: 1,
          isChromaKeying: true,
          chromaKeyingClipId: 'clip-1',
          chromaKeyingRenderId: 'clip-1_chromakey',
        ),
      );
      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      expect(controls.onChromaKey, isNotNull);
      expect(controls.isChromaKeying, isFalse);
    });

    testWidgets(
      'Green screen is highlighted when the clip already carries one',
      (tester) async {
        when(() => bloc.state).thenReturn(
          ClipEditorState(
            clips: [
              clip('clip-1').copyWith(
                chromaKey: const ClipChromaKey(key: ChromaKey.greenScreen()),
                chromaKeySourcePath: '/tmp/original.mp4',
              ),
            ],
          ),
        );
        await tester.pumpWidget(build());

        final controls = tester.widget<VideoEditorTimelineControls>(
          find.byType(VideoEditorTimelineControls),
        );
        expect(controls.hasChromaKey, isTrue);
      },
    );

    testWidgets('Split stays mounted and is disabled while splitting the '
        'current clip', (tester) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [clip('clip-1'), clip('clip-2')],
          isSplitting: true,
          splittingClipId: 'clip-1',
        ),
      );
      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      expect(controls.onSplit, isNotNull);
      expect(controls.isSplitting, isTrue);
    });

    testWidgets('Split stays enabled while a different clip splits', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [clip('clip-1'), clip('clip-2')],
          currentClipIndex: 1,
          isSplitting: true,
          splittingClipId: 'clip-1',
        ),
      );
      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      expect(controls.onSplit, isNotNull);
      expect(controls.isSplitting, isFalse);
    });

    testWidgets('Select button is hidden for a single clip', (tester) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [
            DivineVideoClip(
              id: 'clip-1',
              video: EditorVideo.file('/tmp/clip-1.mp4'),
              duration: const Duration(seconds: 3),
              recordedAt: DateTime(2025),
              targetAspectRatio: model.AspectRatio.vertical,
              originalAspectRatio: 9 / 16,
            ),
          ],
        ),
      );
      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      expect(controls.onMultiSelect, isNull);
    });

    final staleEditorActions =
        <
          ({
            String actionLabel,
            VoidCallback? Function(VideoEditorTimelineControls controls)
            callback,
          })
        >[
          (actionLabel: 'delete', callback: (controls) => controls.onDelete),
          (
            actionLabel: 'duplicate',
            callback: (controls) => controls.onDuplicated,
          ),
          (
            actionLabel: 'speed change',
            callback: (controls) => controls.onSpeed,
          ),
        ];

    for (final action in staleEditorActions) {
      testWidgets(
        '${action.actionLabel} is a no-op when the editor scope is gone',
        (tester) async {
          final controls = await pumpWithMissingEditorScope(tester);

          final callback = action.callback(controls);
          expect(callback, isNotNull);
          callback!.call();
          await tester.pump();

          expect(tester.takeException(), isNull);
          verifyNever(() => bloc.add(any()));
        },
      );
    }

    // The frames path reaches the same commit through _StopMotionClipControls,
    // and its clip id always resolves — so the index guard never short-circuits
    // it before the editor is dereferenced.
    final staleEditorFrameActions =
        <
          ({
            String actionLabel,
            VoidCallback? Function(VideoEditorTimelineControls controls)
            callback,
          })
        >[
          (
            actionLabel: 'frame delete',
            callback: (controls) => controls.onDelete,
          ),
          (
            actionLabel: 'frame duplicate',
            callback: (controls) => controls.onDuplicated,
          ),
        ];

    for (final action in staleEditorFrameActions) {
      testWidgets(
        '${action.actionLabel} is a no-op when the editor scope is gone',
        (tester) async {
          final controls = await pumpWithMissingEditorScope(
            tester,
            state: ClipEditorState(
              clips: [stopMotionClip('clip-1')],
              selectedFrameIndex: 0,
            ),
          );

          final callback = action.callback(controls);
          expect(callback, isNotNull);
          callback!.call();
          await tester.pump();

          expect(tester.takeException(), isNull);
          verifyNever(() => bloc.add(any()));
        },
      );
    }

    testWidgets('offers Transform for the selected still', (tester) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [stopMotionClip('clip-1')],
          selectedFrameIndex: 0,
        ),
      );

      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      expect(controls.onTransform, isNotNull);
      // A still is not a clip, so the button must not announce itself as one.
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        controls.transformSemanticLabel,
        l10n.videoEditorTransformSelectedFrameSemanticLabel,
      );
      expect(
        find.bySemanticsLabel(
          l10n.videoEditorTransformSelectedFrameSemanticLabel,
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides Transform when no still is selected', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(ClipEditorState(clips: [stopMotionClip('clip-1')]));

      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      expect(controls.onTransform, isNull);
    });

    testWidgets('Select button starts multi-select with multiple clips', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(ClipEditorState(clips: [clip('clip-1'), clip('clip-2')]));

      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      controls.onMultiSelect?.call();
      await tester.pump();

      verify(
        () => bloc.add(const ClipEditorMultiSelectStarted('clip-1')),
      ).called(1);
    });

    testWidgets('library save is a no-op when the editor scope is gone', (
      tester,
    ) async {
      final controls = await pumpWithMissingEditorScope(tester);

      controls.onSaveToLibrary?.call();
      await tester.pumpAndSettle();

      // The overlays over the clip can only be read off the editor. With it
      // gone they are unreachable, and saving the bare video would hand the
      // user a clip missing the text/filters they were looking at.
      verifyNever(
        () => bloc.add(any(that: isA<ClipEditorSaveClipToLibraryRequested>())),
      );
    });

    testWidgets(
      'captures overlays and dispatches a save for the current clip',
      (tester) async {
        when(() => bloc.state).thenReturn(
          ClipEditorState(clips: [clip('clip-1'), clip('clip-2')]),
        );
        final overlayBloc = _MockTimelineOverlayBloc();
        when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
        when(
          () => overlayBloc.stream,
        ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());

        final editor = _MockProImageEditorState();
        final stateManager = _MockStateManager();
        final sizesManager = _MockSizesManager();
        when(
          () => editor.captureAllLayersWithMeta(
            basePixelRatio: any(named: 'basePixelRatio'),
          ),
        ).thenAnswer((_) async => <ExportedLayer>[]);
        when(() => editor.stateManager).thenReturn(stateManager);
        when(() => editor.sizesManager).thenReturn(sizesManager);
        when(() => editor.configs).thenReturn(const ProImageEditorConfigs());
        when(() => stateManager.activeFilters).thenReturn(const []);
        when(() => stateManager.activeTuneAdjustments).thenReturn(const []);
        when(() => stateManager.activeBlur).thenReturn(0);
        when(() => sizesManager.bodySize).thenReturn(const Size(400, 600));

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
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
                  onAddEditTextLayer: ([layer]) async => null,
                  child: MultiBlocProvider(
                    providers: [
                      BlocProvider<ClipEditorBloc>.value(value: bloc),
                      BlocProvider<TimelineOverlayBloc>.value(
                        value: overlayBloc,
                      ),
                    ],
                    child: TimelineClipControls(
                      playheadPosition: ValueNotifier(Duration.zero),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final controls = tester.widget<VideoEditorTimelineControls>(
          find.byType(VideoEditorTimelineControls),
        );
        controls.onSaveToLibrary!();
        await tester.pumpAndSettle();

        // The dispatch binds the *current* clip and carries a captured (never
        // null) overlay snapshot, so a regression that binds the wrong clip or
        // drops the overlays fails here.
        final captured = verify(
          () => bloc.add(
            captureAny(that: isA<ClipEditorSaveClipToLibraryRequested>()),
          ),
        ).captured;
        final event = captured.single as ClipEditorSaveClipToLibraryRequested;
        expect(event.clipId, equals('clip-1'));
        expect(event.overlays, isNotNull);
      },
    );

    // The copy lands next to the clip it was made from, not at the end of the
    // timeline: repeating a clip is the common case, and appending made the
    // user drag the copy back past every following clip.
    testWidgets('inserts the copy directly after the duplicated clip', (
      tester,
    ) async {
      final editor = _MockProImageEditorState();
      final overlayBloc = _MockTimelineOverlayBloc();
      // No audio key in the meta => no sound tracks, so the commit takes the
      // plain clip-state path.
      stubEditor(
        editor: editor,
        overlayBloc: overlayBloc,
      );

      final controls = await pumpWithEditor(
        tester,
        editor: editor,
        overlayBloc: overlayBloc,
        state: ClipEditorState(
          clips: [clip('clip-1'), clip('clip-2'), clip('clip-3')],
          currentClipIndex: 1,
        ),
      );

      controls.onDuplicated!();
      await tester.pump();

      final inserted =
          verify(
                () => bloc.add(captureAny(that: isA<ClipEditorClipInserted>())),
              ).captured.single
              as ClipEditorClipInserted;
      expect(inserted.index, equals(2));
      expect(inserted.clip.id, startsWith('clip-2_copy_'));

      // The editor commit has to agree with the bloc event, or undo/redo and
      // the render would replay a different clip order than the timeline shows.
      final meta = capturedHistoryMeta(editor);
      final committed =
          (meta[VideoEditorConstants.clipsStateHistoryKey] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map((json) => json['id'] as String)
              .toList();
      expect(committed[0], equals('clip-1'));
      expect(committed[1], equals('clip-2'));
      expect(committed[2], startsWith('clip-2_copy_'));
      expect(committed[3], equals('clip-3'));
    });

    // #6401 on the clip-edit paths: duplicate and speed-down lengthen the
    // composition, and a sound clamped to the old end has to follow it.
    group('sound follows composition growth', () {
      late _MockProImageEditorState editor;
      late _MockTimelineOverlayBloc overlayBloc;

      final coveringSound = AudioEvent(
        id: 'sound-1',
        pubkey: 'bundled',
        createdAt: 0,
        url: 'asset://sounds/loop.mp3',
        duration: 30,
        endTime: const Duration(seconds: 3),
      );

      setUp(() {
        editor = _MockProImageEditorState();
        overlayBloc = _MockTimelineOverlayBloc();
        stubEditor(
          editor: editor,
          overlayBloc: overlayBloc,
          activeMeta: {
            VideoEditorConstants.audioStateHistoryKey: [coveringSound.toJson()],
          },
        );
      });

      List<AudioEvent> capturedAudio() {
        final meta = capturedHistoryMeta(editor);
        return (meta[VideoEditorConstants.audioStateHistoryKey]
                as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(AudioEvent.fromJson)
            .toList();
      }

      testWidgets('duplicate grows a sound that covered the composition onto '
          'the copy', (tester) async {
        final controls = await pumpWithEditor(
          tester,
          editor: editor,
          overlayBloc: overlayBloc,
          state: ClipEditorState(clips: [clip('clip-1')]),
        );

        controls.onDuplicated!();
        await tester.pump();

        expect(capturedAudio().single.endTime, const Duration(seconds: 6));
      });

      testWidgets('slowing a clip down grows a sound that covered the '
          'composition onto the stretched end', (tester) async {
        final controls = await pumpWithEditor(
          tester,
          editor: editor,
          overlayBloc: overlayBloc,
          state: ClipEditorState(clips: [clip('clip-1')]),
        );

        controls.onSpeed!();
        await tester.pumpAndSettle();

        // Drag the sheet's slider to half speed and confirm.
        tester.widget<DivineSlider>(find.byType(DivineSlider)).onChanged!(0.5);
        await tester.pump();
        await tester.tap(
          find.descendant(
            of: find.byType(VideoEditorClipSpeedSheet),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is DivineIconButton &&
                  widget.icon == DivineIconName.check,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(capturedAudio().single.endTime, const Duration(seconds: 6));
      });
    });

    testWidgets('Save shows a spinner while this clip is being saved', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [clip('clip-1')],
          isSavingClipToLibrary: true,
          savingClipToLibraryClipId: 'clip-1',
        ),
      );

      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      expect(controls.isSavingToLibrary, isTrue);
    });

    testWidgets('Save is disabled without a spinner while another clip saves', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [clip('clip-1'), clip('clip-2')],
          currentClipIndex: 1,
          isSavingClipToLibrary: true,
          savingClipToLibraryClipId: 'clip-1',
        ),
      );

      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      // Only one re-encode runs at a time, so Save on clip-2 is greyed rather
      // than tappable-but-ignored: no spinner (that clip isn't the one saving),
      // but disabled so the tap can't be silently dropped by the bloc.
      expect(controls.isSavingToLibrary, isFalse);
      expect(controls.isSaveToLibraryDisabled, isTrue);
    });
  });
}
