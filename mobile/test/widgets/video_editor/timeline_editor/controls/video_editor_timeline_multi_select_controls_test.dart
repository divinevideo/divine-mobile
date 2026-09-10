// ABOUTME: Widget tests for the clip and stop-motion-frame multi-select bars.
// ABOUTME: Verifies the count label, action gating, and event dispatch.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_multi_select_controls.dart';
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

DivineVideoClip _stopMotionClip(String id, int frameCount) {
  return DivineVideoClip(
    id: id,
    duration: Duration(milliseconds: 500 * frameCount),
    recordedAt: DateTime(2025),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    stopMotionFrames: [
      for (var i = 0; i < frameCount; i++)
        StopMotionClipFrame(
          path: '/tmp/$id-$i.png',
          duration: const Duration(milliseconds: 500),
        ),
    ],
  );
}

DivineVideoClip _clip(String id) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/tmp/$id.mp4'),
    duration: const Duration(seconds: 2),
    recordedAt: DateTime(2025),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
  );
}

void main() {
  group(TimelineMultiSelectControls, () {
    late _MockClipEditorBloc bloc;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      bloc = _MockClipEditorBloc();
      when(
        () => bloc.stream,
      ).thenAnswer((_) => const Stream<ClipEditorState>.empty());
    });

    Widget build() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<ClipEditorBloc>.value(
            value: bloc,
            child: const TimelineMultiSelectControls(),
          ),
        ),
      );
    }

    DivineIconButton buttonWithLabel(WidgetTester tester, String label) {
      return tester
          .widgetList<DivineIconButton>(find.byType(DivineIconButton))
          .firstWhere((b) => b.semanticLabel == label);
    }

    testWidgets('renders the selection count and Merge/Delete/Done', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_clip('a'), _clip('b'), _clip('c')],
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'b'},
        ),
      );

      await tester.pumpWidget(build());

      expect(
        find.text(l10n.videoEditorMultiSelectCountLabel(2)),
        findsOneWidget,
      );
      expect(find.text(l10n.videoEditorMergeLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDeleteLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDoneLabel), findsOneWidget);
    });

    testWidgets('Merge is disabled with fewer than two clips selected', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_clip('a'), _clip('b')],
          isMultiSelectMode: true,
          selectedClipIds: const {'a'},
        ),
      );

      await tester.pumpWidget(build());

      final merge = buttonWithLabel(
        tester,
        l10n.videoEditorMergeSelectedClipsSemanticLabel,
      );
      expect(merge.onPressed, isNull);
    });

    testWidgets('Merge dispatches a merge request when enabled', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_clip('a'), _clip('b'), _clip('c')],
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'b'},
        ),
      );

      await tester.pumpWidget(build());

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorMergeSelectedClipsSemanticLabel),
      );
      await tester.pump();

      verify(
        () => bloc.add(const ClipEditorSelectedClipsMergeRequested()),
      ).called(1);
    });

    testWidgets('Delete is disabled when every clip is selected', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_clip('a'), _clip('b')],
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'b'},
        ),
      );

      await tester.pumpWidget(build());

      final delete = buttonWithLabel(
        tester,
        l10n.videoEditorDeleteSelectedClipsSemanticLabel,
      );
      expect(delete.onPressed, isNull);
    });

    testWidgets('Merge and Delete are disabled while merging', (tester) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_clip('a'), _clip('b'), _clip('c')],
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'b'},
          isMerging: true,
        ),
      );

      await tester.pumpWidget(build());

      expect(
        buttonWithLabel(
          tester,
          l10n.videoEditorMergeSelectedClipsSemanticLabel,
        ).onPressed,
        isNull,
      );
      expect(
        buttonWithLabel(
          tester,
          l10n.videoEditorDeleteSelectedClipsSemanticLabel,
        ).onPressed,
        isNull,
      );
    });

    testWidgets('Done dispatches a cancel event', (tester) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_clip('a'), _clip('b')],
          isMultiSelectMode: true,
          selectedClipIds: const {'a'},
        ),
      );

      await tester.pumpWidget(build());

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorMultiSelectDoneSemanticLabel),
      );
      await tester.pump();

      verify(() => bloc.add(const ClipEditorMultiSelectCancelled())).called(1);
    });

    testWidgets('Delete dispatches a remove event when enabled', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_clip('a'), _clip('b'), _clip('c')],
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'b'},
        ),
      );

      await tester.pumpWidget(build());

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorDeleteSelectedClipsSemanticLabel),
      );
      await tester.pump();

      verify(() => bloc.add(const ClipEditorSelectedClipsRemoved())).called(1);
    });
  });

  group(TimelineFrameMultiSelectControls, () {
    late _MockClipEditorBloc bloc;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      bloc = _MockClipEditorBloc();
      when(
        () => bloc.stream,
      ).thenAnswer((_) => const Stream<ClipEditorState>.empty());
    });

    Widget build() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<ClipEditorBloc>.value(
            value: bloc,
            child: const TimelineFrameMultiSelectControls(),
          ),
        ),
      );
    }

    DivineIconButton buttonWithLabel(WidgetTester tester, String label) {
      return tester
          .widgetList<DivineIconButton>(find.byType(DivineIconButton))
          .firstWhere((b) => b.semanticLabel == label);
    }

    testWidgets('offers Duplicate on the selected stills', (tester) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_stopMotionClip('a', 4)],
          isMultiSelectMode: true,
          selectedFrameIndexes: const {1, 2},
        ),
      );

      await tester.pumpWidget(build());

      expect(
        buttonWithLabel(
          tester,
          l10n.videoEditorDuplicateSelectedFramesSemanticLabel,
        ).onPressed,
        isNotNull,
      );
    });

    testWidgets('disables Duplicate with nothing selected', (tester) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_stopMotionClip('a', 4)],
          isMultiSelectMode: true,
        ),
      );

      await tester.pumpWidget(build());

      expect(
        buttonWithLabel(
          tester,
          l10n.videoEditorDuplicateSelectedFramesSemanticLabel,
        ).onPressed,
        isNull,
      );
    });

    // Duplicate goes through `commitStopMotionFrames`, which bails without a
    // live editor — so the behaviour tests below need one mounted in scope.
    group('Duplicate', () {
      late _MockTimelineOverlayBloc overlayBloc;
      late _MockProImageEditorState editor;

      setUpAll(() {
        registerFallbackValue(const ClipEditorEditingStopped());
      });

      setUp(() {
        overlayBloc = _MockTimelineOverlayBloc();
        when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
        when(
          () => overlayBloc.stream,
        ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());

        editor = _MockProImageEditorState();
        final stateManager = _MockStateManager();
        when(() => editor.stateManager).thenReturn(stateManager);
        when(() => stateManager.activeMeta).thenReturn(<String, dynamic>{});
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
      });

      Future<void> pressDuplicate(
        WidgetTester tester, {
        required Set<int> selected,
        int frameCount = 4,
        bool hasEditor = true,
      }) async {
        when(() => bloc.state).thenReturn(
          ClipEditorState(
            clips: [_stopMotionClip('a', frameCount)],
            isMultiSelectMode: true,
            selectedFrameIndexes: selected,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoEditorScope(
                editorKey: GlobalKey<ProImageEditorState>(),
                editorOverride: hasEditor ? editor : null,
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
                  child: const TimelineFrameMultiSelectControls(),
                ),
              ),
            ),
          ),
        );

        buttonWithLabel(
          tester,
          l10n.videoEditorDuplicateSelectedFramesSemanticLabel,
        ).onPressed!();
        await tester.pump();
      }

      List<String> committedFramePaths() {
        final updated =
            verify(
                  () =>
                      bloc.add(captureAny(that: isA<ClipEditorClipUpdated>())),
                ).captured.single
                as ClipEditorClipUpdated;
        return [for (final frame in updated.clip.stopMotionFrames!) frame.path];
      }

      Set<int> reselected() {
        final event =
            verify(
                  () => bloc.add(
                    captureAny(that: isA<ClipEditorFrameMultiSelectionSet>()),
                  ),
                ).captured.single
                as ClipEditorFrameMultiSelectionSet;
        return event.frameIndexes;
      }

      testWidgets('repeats the selected run right after its last still', (
        tester,
      ) async {
        await pressDuplicate(tester, selected: const {1, 2});

        expect(committedFramePaths(), [
          '/tmp/a-0.png',
          '/tmp/a-1.png',
          '/tmp/a-2.png',
          '/tmp/a-1.png',
          '/tmp/a-2.png',
          '/tmp/a-3.png',
        ]);
      });

      // The highlight has to show what was just created: a follow-up hold
      // change or block drag acts on the selection, and leaving it on the
      // sources would silently edit the originals instead.
      testWidgets('moves the selection onto the copies', (tester) async {
        await pressDuplicate(tester, selected: const {1, 2});

        expect(reselected(), {3, 4});
      });

      testWidgets('a single still duplicates in place, like the per-still '
          'action', (tester) async {
        await pressDuplicate(tester, selected: const {1});

        expect(committedFramePaths(), [
          '/tmp/a-0.png',
          '/tmp/a-1.png',
          '/tmp/a-1.png',
          '/tmp/a-2.png',
          '/tmp/a-3.png',
        ]);
        expect(reselected(), {2});
      });

      // Gaps collapse: the copies land as one repeat, not each beside its own
      // source, so the selection that follows them is contiguous too.
      testWidgets('gathers a non-contiguous selection into one block', (
        tester,
      ) async {
        await pressDuplicate(tester, selected: const {0, 2});

        expect(committedFramePaths(), [
          '/tmp/a-0.png',
          '/tmp/a-1.png',
          '/tmp/a-2.png',
          '/tmp/a-0.png',
          '/tmp/a-2.png',
          '/tmp/a-3.png',
        ]);
        expect(reselected(), {3, 4});
      });

      testWidgets('does not move the selection when the editor is gone', (
        tester,
      ) async {
        await pressDuplicate(tester, selected: const {0}, hasEditor: false);

        verifyNever(() => bloc.add(any(that: isA<ClipEditorClipUpdated>())));
        verifyNever(
          () => bloc.add(any(that: isA<ClipEditorFrameMultiSelectionSet>())),
        );
      });
    });
  });
}
