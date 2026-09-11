// ABOUTME: Widget tests for TimelineOverlayControls.
// ABOUTME: Verifies rendering for each overlay type with proper
// ABOUTME: VideoEditorScope in the tree.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_layer_animation_sheet.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_overlay_controls.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show ChromaKey;

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

void main() {
  group(TimelineOverlayControls, () {
    late _MockTimelineOverlayBloc overlayBloc;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUpAll(() {
      registerFallbackValue(const TimelineOverlayItemSelected(null));
    });

    setUp(() {
      overlayBloc = _MockTimelineOverlayBloc();
      when(
        () => overlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());
      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
    });

    Widget buildWithEditor(
      TimelineOverlayItem item,
      _MockProImageEditorState mockEditor,
      _MockVideoEditorMainBloc mainBloc, {
      _MockClipEditorBloc? clipBloc,
    }) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
                BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
                if (clipBloc != null)
                  BlocProvider<ClipEditorBloc>.value(value: clipBloc),
              ],
              child: VideoEditorScope(
                editorKey: GlobalKey(),
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
                onAddEditTextLayer: ([layer]) async => null,
                onOpenMusicLibrary: () {},
                onOpenVoiceOver: () {},
                onOpenCaptions: () {},
                editorOverride: mockEditor,
                child: TimelineOverlayControls(item: item),
              ),
            ),
          ),
        ),
      );
    }

    Widget build(TimelineOverlayItem item) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorScope(
              editorKey: GlobalKey(),
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
              onAddEditTextLayer: ([layer]) async => null,
              onOpenMusicLibrary: () {},
              onOpenVoiceOver: () {},
              onOpenCaptions: () {},
              child: BlocProvider<TimelineOverlayBloc>.value(
                value: overlayBloc,
                child: TimelineOverlayControls(item: item),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders $VideoEditorTimelineControls for layer', (
      tester,
    ) async {
      const item = TimelineOverlayItem(
        id: 'layer-1',
        type: TimelineOverlayType.layer,
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
      );

      await tester.pumpWidget(build(item));

      expect(find.byType(VideoEditorTimelineControls), findsOneWidget);
      expect(find.text(l10n.videoEditorDeleteLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDuplicateLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorSplitLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDoneLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorEditLabel), findsNothing);
    });

    testWidgets('offers duplicate, split and crop for a detached clip', (
      tester,
    ) async {
      const item = TimelineOverlayItem(
        id: 'detached-layer',
        type: TimelineOverlayType.layer,
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
      );
      const meta = <String, dynamic>{
        detachedClipLayerKindKey: detachedClipLayerKind,
      };
      final layer = WidgetLayer(
        id: item.id,
        widget: const SizedBox.shrink(),
        meta: meta,
        exportConfigs: const WidgetLayerExportConfigs(
          id: 'detached-layer',
          meta: meta,
        ),
      );
      final editor = _MockProImageEditorState();
      final mainBloc = _MockVideoEditorMainBloc();
      when(() => editor.activeLayers).thenReturn([layer]);
      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());

      await tester.pumpWidget(buildWithEditor(item, editor, mainBloc));

      expect(find.text(l10n.videoEditorDuplicateLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorSplitLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorTransformLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorChromaKeyLabel), findsOneWidget);
      // A detached clip is composited as a VideoLayer, which carries no
      // animations field — offering the action would animate it in the editor
      // and drop it silently from the file.
      expect(find.text(l10n.videoEditorLayerAnimationLabel), findsNothing);
    });

    testWidgets('keeps the green screen off every other layer', (
      tester,
    ) async {
      const item = TimelineOverlayItem(
        id: 'text-layer',
        type: TimelineOverlayType.layer,
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
      );
      final editor = _MockProImageEditorState();
      final mainBloc = _MockVideoEditorMainBloc();
      when(
        () => editor.activeLayers,
      ).thenReturn([TextLayer(id: item.id, text: 'hi')]);
      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());

      await tester.pumpWidget(buildWithEditor(item, editor, mainBloc));

      // Only a detached clip carries footage a key can be applied to.
      expect(find.text(l10n.videoEditorChromaKeyLabel), findsNothing);
    });

    testWidgets('highlights the green screen once the layer carries one', (
      tester,
    ) async {
      const item = TimelineOverlayItem(
        id: 'detached-layer',
        type: TimelineOverlayType.layer,
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
      );
      DivineIconButton chromaKeyButton() => tester.widget<DivineIconButton>(
        find.byWidgetPredicate(
          (w) =>
              w is DivineIconButton &&
              w.semanticLabel == l10n.videoEditorChromaKeySemanticLabel,
        ),
      );
      WidgetLayer layerWith(Map<String, dynamic> meta) => WidgetLayer(
        id: item.id,
        widget: const SizedBox.shrink(),
        meta: meta,
        exportConfigs: WidgetLayerExportConfigs(id: item.id, meta: meta),
      );
      final editor = _MockProImageEditorState();
      final mainBloc = _MockVideoEditorMainBloc();
      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());

      when(() => editor.activeLayers).thenReturn([
        layerWith(const {detachedClipLayerKindKey: detachedClipLayerKind}),
      ]);
      await tester.pumpWidget(buildWithEditor(item, editor, mainBloc));
      expect(chromaKeyButton().type, DivineIconButtonType.secondary);

      when(() => editor.activeLayers).thenReturn([
        layerWith({
          detachedClipLayerKindKey: detachedClipLayerKind,
          detachedClipLayerChromaKeyKey: const ClipChromaKey(
            key: ChromaKey.greenScreen(),
          ).toJson(),
        }),
      ]);
      await tester.pumpWidget(buildWithEditor(item, editor, mainBloc));
      // Same treatment the timeline gives a baked key: the effect is visible
      // from the action bar without opening the screen.
      expect(chromaKeyButton().type, DivineIconButtonType.primary);
    });

    testWidgets('renders $VideoEditorTimelineControls for filter', (
      tester,
    ) async {
      const item = TimelineOverlayItem(
        id: 'filter-1',
        type: TimelineOverlayType.filter,
        startTime: Duration.zero,
        endTime: Duration(seconds: 5),
      );

      await tester.pumpWidget(build(item));

      expect(find.byType(VideoEditorTimelineControls), findsOneWidget);
      expect(find.text(l10n.videoEditorDeleteLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDuplicateLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorSplitLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDoneLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorEditLabel), findsNothing);
    });

    testWidgets('renders $VideoEditorTimelineControls for sound', (
      tester,
    ) async {
      const item = TimelineOverlayItem(
        id: 'sound-1',
        type: TimelineOverlayType.sound,
        startTime: Duration.zero,
        endTime: Duration(seconds: 10),
      );

      await tester.pumpWidget(build(item));

      expect(find.byType(VideoEditorTimelineControls), findsOneWidget);
      expect(find.text(l10n.videoEditorDeleteLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorEditLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDuplicateLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorSplitLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDoneLabel), findsOneWidget);
    });

    testWidgets('renders delete/edit/duplicate/split/done for tune', (
      tester,
    ) async {
      const item = TimelineOverlayItem(
        id: 'set-1',
        type: TimelineOverlayType.tune,
        startTime: Duration.zero,
        endTime: Duration(seconds: 5),
      );

      await tester.pumpWidget(build(item));

      expect(find.byType(VideoEditorTimelineControls), findsOneWidget);
      expect(find.text(l10n.videoEditorDeleteLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorEditLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDuplicateLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorSplitLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDoneLabel), findsOneWidget);
    });

    group('behavior', () {
      late _MockProImageEditorState mockEditor;
      late _MockStateManager mockStateManager;
      late _MockVideoEditorMainBloc mainBloc;

      setUp(() {
        mockEditor = _MockProImageEditorState();
        mockStateManager = _MockStateManager();
        mainBloc = _MockVideoEditorMainBloc();
        when(() => mainBloc.stream).thenAnswer(
          (_) => const Stream<VideoEditorMainState>.empty(),
        );
        when(() => mockEditor.stateManager).thenReturn(mockStateManager);
        when(
          () => mockEditor.addHistory(
            layers: any(named: 'layers'),
            filters: any(named: 'filters'),
            meta: any(named: 'meta'),
          ),
        ).thenAnswer((_) {});
      });

      WidgetLayer detachedLayer({
        required String id,
        Duration start = Duration.zero,
        Duration end = const Duration(seconds: 6),
      }) {
        final meta = <String, dynamic>{
          detachedClipLayerKindKey: detachedClipLayerKind,
          detachedClipLayerIdKey: id,
          detachedClipLayerDurationKey: const Duration(
            seconds: 6,
          ).inMicroseconds,
        };
        return WidgetLayer(
          id: id,
          widget: const SizedBox.shrink(),
          meta: meta,
          startTime: start,
          endTime: end,
          exportConfigs: WidgetLayerExportConfigs(id: id, meta: meta),
        );
      }

      testWidgets('duplicating a detached clip re-points its meta', (
        tester,
      ) async {
        final layer = detachedLayer(id: 'detached-1');
        when(() => mockEditor.activeLayers).thenReturn([layer]);
        when(() => mainBloc.state).thenReturn(const VideoEditorMainState());

        const item = TimelineOverlayItem(
          id: 'detached-1',
          type: TimelineOverlayType.layer,
          startTime: Duration.zero,
          endTime: Duration(seconds: 6),
        );
        await tester.pumpWidget(
          buildWithEditor(item, mockEditor, mainBloc),
        );
        await tester.tap(
          find.bySemanticsLabel(
            l10n.videoEditorDuplicateSelectedItemSemanticLabel,
          ),
        );
        await tester.pump();

        final written =
            verify(
                  () => mockEditor.addHistory(
                    layers: captureAny(named: 'layers'),
                  ),
                ).captured.last
                as List<Layer>;
        final copy = written.last;

        // The copy carries its own layer id in the meta too. Leaving the
        // original's there makes the preview read that layer's window off the
        // timeline while the export uses the copy's — they agree only while
        // the copy has not been moved, which is where a duplicate starts.
        expect(copy.id, isNot('detached-1'));
        expect(
          DetachedClipLayerData.layerIdOf(DetachedClipLayerData.metaOf(copy)),
          copy.id,
        );
      });

      testWidgets('splitting a detached clip offsets the tail into the clip', (
        tester,
      ) async {
        final layer = detachedLayer(id: 'detached-1');
        when(() => mockEditor.activeLayers).thenReturn([layer]);
        when(() => mainBloc.state).thenReturn(
          const VideoEditorMainState(currentPosition: Duration(seconds: 2)),
        );

        const item = TimelineOverlayItem(
          id: 'detached-1',
          type: TimelineOverlayType.layer,
          startTime: Duration.zero,
          endTime: Duration(seconds: 6),
        );
        await tester.pumpWidget(
          buildWithEditor(item, mockEditor, mainBloc),
        );
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorSplitSelectedClipSemanticLabel),
        );
        await tester.pump();

        final written =
            verify(
                  () => mockEditor.addHistory(
                    layers: captureAny(named: 'layers'),
                  ),
                ).captured.last
                as List<Layer>;
        final tail = written.last;

        // The tail plays on from the cut. Without the offset it would rewind
        // to the clip's first frame at its own start and replay the head.
        expect(
          DetachedClipLayerData.sourceOffsetOf(
            DetachedClipLayerData.metaOf(tail),
          ),
          const Duration(seconds: 2),
        );
      });

      testWidgets(
        'duplicate inserts a copied layer after the selected item, offsets it, '
        'and selects it',
        (tester) async {
          final layerA = TextLayer(
            text: 'Layer A',
            id: 'layer-a',
            offset: const Offset(10, 20),
            startTime: const Duration(seconds: 1),
            endTime: const Duration(seconds: 5),
          );
          final layerB = TextLayer(
            text: 'Layer B',
            id: 'layer-b',
            offset: const Offset(50, 60),
            startTime: const Duration(seconds: 5),
            endTime: const Duration(seconds: 9),
          );
          when(() => mockEditor.activeLayers).thenReturn([layerA, layerB]);
          when(() => mainBloc.state).thenReturn(
            const VideoEditorMainState(),
          );

          const item = TimelineOverlayItem(
            id: 'layer-a',
            type: TimelineOverlayType.layer,
            startTime: Duration(seconds: 1),
            endTime: Duration(seconds: 5),
          );
          await tester.pumpWidget(
            buildWithEditor(item, mockEditor, mainBloc),
          );

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorDuplicateSelectedItemSemanticLabel,
            ),
          );
          await tester.pump();

          final result = verify(
            () => mockEditor.addHistory(
              layers: captureAny(named: 'layers'),
            ),
          )..called(1);
          final layers = result.captured.single as List<Layer>;
          final inserted = layers[1] as TextLayer;

          expect(layers, hasLength(3));
          expect(inserted.id, startsWith('layer-a_copy_'));
          expect(inserted.offset, equals(const Offset(34, 44)));
          expect(layers[2].id, equals('layer-b'));

          final addEvent = verify(
            () => overlayBloc.add(captureAny()),
          ).captured.whereType<TimelineOverlayItemSelected>().last;
          expect(addEvent.itemId, startsWith('layer-a_copy_'));
        },
      );

      testWidgets(
        'duplicate inserts a copy after the selected filter item and selects it',
        (tester) async {
          final filterA = FilterState(
            id: 'filter-a',
            name: 'test-filter',
            matrices: const [
              [1.0],
            ],
            startTime: const Duration(seconds: 1),
            endTime: const Duration(seconds: 5),
          );
          when(() => mockStateManager.activeFilters).thenReturn([filterA]);
          when(() => mainBloc.state).thenReturn(
            const VideoEditorMainState(),
          );

          const item = TimelineOverlayItem(
            id: 'filter-a',
            type: TimelineOverlayType.filter,
            startTime: Duration(seconds: 1),
            endTime: Duration(seconds: 5),
          );
          await tester.pumpWidget(
            buildWithEditor(item, mockEditor, mainBloc),
          );

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorDuplicateSelectedItemSemanticLabel,
            ),
          );
          await tester.pump();

          final result = verify(
            () => mockEditor.addHistory(
              filters: captureAny(named: 'filters'),
            ),
          )..called(1);
          final filters = result.captured.single as List<FilterState>;
          expect(filters, hasLength(2));
          expect(filters[1].id, startsWith('filter-a_copy_'));

          final addEvent = verify(
            () => overlayBloc.add(captureAny()),
          ).captured.whereType<TimelineOverlayItemSelected>().last;
          expect(addEvent.itemId, startsWith('filter-a_copy_'));
        },
      );

      testWidgets(
        'split layer inserts the second segment after the original and selects '
        'it',
        (tester) async {
          final layerA = TextLayer(
            text: 'Layer A',
            id: 'layer-a',
            offset: const Offset(10, 20),
            startTime: const Duration(seconds: 1),
            endTime: const Duration(seconds: 5),
          );
          final layerB = TextLayer(
            text: 'Layer B',
            id: 'layer-b',
            offset: const Offset(50, 60),
            startTime: const Duration(seconds: 5),
            endTime: const Duration(seconds: 9),
          );
          when(() => mockEditor.activeLayers).thenReturn([layerA, layerB]);
          when(() => mainBloc.state).thenReturn(
            const VideoEditorMainState(
              currentPosition: Duration(seconds: 3),
            ),
          );

          const item = TimelineOverlayItem(
            id: 'layer-a',
            type: TimelineOverlayType.layer,
            startTime: Duration(seconds: 1),
            endTime: Duration(seconds: 5),
          );
          await tester.pumpWidget(
            buildWithEditor(item, mockEditor, mainBloc),
          );

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorSplitSelectedClipSemanticLabel,
            ),
          );
          await tester.pump();

          final result = verify(
            () => mockEditor.addHistory(
              layers: captureAny(named: 'layers'),
            ),
          )..called(1);
          final layers = result.captured.single as List<Layer>;
          final first = layers[0] as TextLayer;
          final second = layers[1] as TextLayer;

          expect(layers, hasLength(3));
          expect(first.endTime, equals(const Duration(seconds: 3)));
          expect(second.id, startsWith('layer-a_copy_'));
          expect(second.startTime, equals(const Duration(seconds: 3)));
          expect(second.endTime, equals(const Duration(seconds: 5)));
          expect(layers[2].id, equals('layer-b'));

          final addEvent = verify(
            () => overlayBloc.add(captureAny()),
          ).captured.whereType<TimelineOverlayItemSelected>().last;
          expect(addEvent.itemId, startsWith('layer-a_copy_'));
        },
      );

      testWidgets(
        'split at valid position creates two segments and selects the second',
        (tester) async {
          final filterA = FilterState(
            id: 'filter-a',
            name: 'test-filter',
            matrices: const [
              [1.0],
            ],
            startTime: const Duration(seconds: 1),
            endTime: const Duration(seconds: 5),
          );
          when(() => mockStateManager.activeFilters).thenReturn([filterA]);
          when(() => mainBloc.state).thenReturn(
            const VideoEditorMainState(
              currentPosition: Duration(seconds: 3),
            ),
          );

          const item = TimelineOverlayItem(
            id: 'filter-a',
            type: TimelineOverlayType.filter,
            startTime: Duration(seconds: 1),
            endTime: Duration(seconds: 5),
          );
          await tester.pumpWidget(
            buildWithEditor(item, mockEditor, mainBloc),
          );

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorSplitSelectedClipSemanticLabel,
            ),
          );
          await tester.pump();

          final result = verify(
            () => mockEditor.addHistory(
              filters: captureAny(named: 'filters'),
            ),
          )..called(1);
          final filters = result.captured.single as List<FilterState>;
          expect(filters, hasLength(2));
          expect(filters[0].endTime, equals(const Duration(seconds: 3)));
          expect(filters[1].startTime, equals(const Duration(seconds: 3)));
          expect(filters[1].endTime, equals(const Duration(seconds: 5)));

          final addEvent = verify(
            () => overlayBloc.add(captureAny()),
          ).captured.whereType<TimelineOverlayItemSelected>().last;
          expect(addEvent.itemId, isNotNull);
        },
      );

      testWidgets(
        'split at invalid position shows snackbar and does not commit history',
        (tester) async {
          final filterA = FilterState(
            id: 'filter-a',
            name: 'test-filter',
            matrices: const [
              [1.0],
            ],
            startTime: const Duration(seconds: 1),
            endTime: const Duration(seconds: 5),
          );
          when(() => mockStateManager.activeFilters).thenReturn([filterA]);
          // currentPosition = 0, which is <= startTime(1s) → invalid
          when(() => mainBloc.state).thenReturn(
            const VideoEditorMainState(),
          );

          const item = TimelineOverlayItem(
            id: 'filter-a',
            type: TimelineOverlayType.filter,
            startTime: Duration(seconds: 1),
            endTime: Duration(seconds: 5),
          );
          await tester.pumpWidget(
            buildWithEditor(item, mockEditor, mainBloc),
          );

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorSplitSelectedClipSemanticLabel,
            ),
          );
          await tester.pump();

          expect(
            find.text(l10n.videoEditorSplitPlayheadOutsideClip),
            findsOneWidget,
          );
          verifyNever(
            () => mockEditor.addHistory(
              layers: any(named: 'layers'),
              filters: any(named: 'filters'),
              meta: any(named: 'meta'),
            ),
          );
        },
      );

      testWidgets(
        'tune delete removes every member of the set and deselects',
        (tester) async {
          when(() => mockStateManager.activeTuneAdjustments).thenReturn([
            TuneAdjustmentMatrix(
              id: 'brightness__set-1',
              value: 0.2,
              matrix: const [],
              meta: const {
                VideoEditorConstants.tuneSetIdMetaKey: 'set-1',
                VideoEditorConstants.tuneKindMetaKey: 'brightness',
              },
            ),
            TuneAdjustmentMatrix(
              id: 'contrast__set-1',
              value: -0.1,
              matrix: const [],
              meta: const {
                VideoEditorConstants.tuneSetIdMetaKey: 'set-1',
                VideoEditorConstants.tuneKindMetaKey: 'contrast',
              },
            ),
            TuneAdjustmentMatrix(
              id: 'brightness__set-2',
              value: 0.3,
              matrix: const [],
              meta: const {
                VideoEditorConstants.tuneSetIdMetaKey: 'set-2',
                VideoEditorConstants.tuneKindMetaKey: 'brightness',
              },
            ),
          ]);
          when(
            () => mockEditor.addHistory(
              tuneAdjustments: any(named: 'tuneAdjustments'),
            ),
          ).thenAnswer((_) {});

          const item = TimelineOverlayItem(
            id: 'set-1',
            type: TimelineOverlayType.tune,
            startTime: Duration.zero,
            endTime: Duration(seconds: 5),
          );
          await tester.pumpWidget(buildWithEditor(item, mockEditor, mainBloc));

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorDeleteSelectedItemSemanticLabel,
            ),
          );
          await tester.pump();

          final result = verify(
            () => mockEditor.addHistory(
              tuneAdjustments: captureAny(named: 'tuneAdjustments'),
            ),
          )..called(1);
          final tunes = result.captured.single as List<TuneAdjustmentMatrix>;
          expect(tunes.map((t) => t.id), ['brightness__set-2']);

          verify(
            () => overlayBloc.add(const TimelineOverlayItemSelected(null)),
          ).called(1);
        },
      );

      testWidgets(
        'tune duplicate copies every member into a new set and selects it',
        (tester) async {
          when(() => mockStateManager.activeTuneAdjustments).thenReturn([
            TuneAdjustmentMatrix(
              id: 'brightness__set-1',
              value: 0.2,
              matrix: const [],
              meta: const {
                VideoEditorConstants.tuneSetIdMetaKey: 'set-1',
                VideoEditorConstants.tuneKindMetaKey: 'brightness',
              },
            ),
            TuneAdjustmentMatrix(
              id: 'contrast__set-1',
              value: -0.1,
              matrix: const [],
              meta: const {
                VideoEditorConstants.tuneSetIdMetaKey: 'set-1',
                VideoEditorConstants.tuneKindMetaKey: 'contrast',
              },
            ),
          ]);
          when(
            () => mockEditor.addHistory(
              tuneAdjustments: any(named: 'tuneAdjustments'),
            ),
          ).thenAnswer((_) {});

          const item = TimelineOverlayItem(
            id: 'set-1',
            type: TimelineOverlayType.tune,
            startTime: Duration.zero,
            endTime: Duration(seconds: 5),
          );
          await tester.pumpWidget(buildWithEditor(item, mockEditor, mainBloc));

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorDuplicateSelectedItemSemanticLabel,
            ),
          );
          await tester.pump();

          final result = verify(
            () => mockEditor.addHistory(
              tuneAdjustments: captureAny(named: 'tuneAdjustments'),
            ),
          )..called(1);
          final tunes = result.captured.single as List<TuneAdjustmentMatrix>;
          // Original two + two copies in a new set.
          expect(tunes, hasLength(4));
          final copySetIds = tunes
              .skip(2)
              .map(
                (t) => t.meta[VideoEditorConstants.tuneSetIdMetaKey] as String?,
              )
              .toSet();
          expect(copySetIds, hasLength(1));
          expect(copySetIds.single, isNot('set-1'));

          final selected = verify(
            () => overlayBloc.add(captureAny()),
          ).captured.whereType<TimelineOverlayItemSelected>().last;
          expect(selected.itemId, copySetIds.single);
        },
      );

      testWidgets(
        'tune split cuts every member and moves the tail into a new set',
        (tester) async {
          when(() => mockStateManager.activeTuneAdjustments).thenReturn([
            TuneAdjustmentMatrix(
              id: 'brightness__set-1',
              value: 0.2,
              matrix: const [],
              startTime: const Duration(seconds: 1),
              endTime: const Duration(seconds: 5),
              meta: const {
                VideoEditorConstants.tuneSetIdMetaKey: 'set-1',
                VideoEditorConstants.tuneKindMetaKey: 'brightness',
              },
            ),
          ]);
          when(() => mainBloc.state).thenReturn(
            const VideoEditorMainState(currentPosition: Duration(seconds: 3)),
          );
          when(
            () => mockEditor.addHistory(
              tuneAdjustments: any(named: 'tuneAdjustments'),
            ),
          ).thenAnswer((_) {});

          const item = TimelineOverlayItem(
            id: 'set-1',
            type: TimelineOverlayType.tune,
            startTime: Duration(seconds: 1),
            endTime: Duration(seconds: 5),
          );
          await tester.pumpWidget(buildWithEditor(item, mockEditor, mainBloc));

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorSplitSelectedClipSemanticLabel,
            ),
          );
          await tester.pump();

          final result = verify(
            () => mockEditor.addHistory(
              tuneAdjustments: captureAny(named: 'tuneAdjustments'),
            ),
          )..called(1);
          final tunes = result.captured.single as List<TuneAdjustmentMatrix>;
          expect(tunes, hasLength(2));
          // Head keeps set-1 and ends at the split.
          expect(
            tunes[0].meta[VideoEditorConstants.tuneSetIdMetaKey],
            'set-1',
          );
          expect(tunes[0].endTime, const Duration(seconds: 3));
          // Tail is a new set spanning split → original end.
          expect(
            tunes[1].meta[VideoEditorConstants.tuneSetIdMetaKey],
            isNot('set-1'),
          );
          expect(tunes[1].startTime, const Duration(seconds: 3));
          expect(tunes[1].endTime, const Duration(seconds: 5));
        },
      );

      testWidgets(
        'sound duplicate serializes updated tracks under the audio history key '
        'and selects the copy',
        (tester) async {
          final trackA = AudioEvent(
            id: 'sound-1',
            pubkey: 'pub',
            createdAt: 0,
            startOffset: const Duration(seconds: 2),
            startTime: const Duration(seconds: 3),
            endTime: const Duration(seconds: 8),
          );
          final trackB = AudioEvent(
            id: 'sound-2',
            pubkey: 'pub',
            createdAt: 1,
            startOffset: const Duration(seconds: 1),
            startTime: const Duration(seconds: 8),
            endTime: const Duration(seconds: 12),
          );
          when(() => mockStateManager.activeMeta).thenReturn({
            VideoEditorConstants.audioStateHistoryKey: [
              trackA.toJson(),
              trackB.toJson(),
            ],
          });
          when(() => mainBloc.state).thenReturn(
            const VideoEditorMainState(),
          );

          const item = TimelineOverlayItem(
            id: 'sound-1',
            type: TimelineOverlayType.sound,
            startTime: Duration(seconds: 3),
            endTime: Duration(seconds: 8),
          );
          await tester.pumpWidget(
            buildWithEditor(item, mockEditor, mainBloc),
          );

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorDuplicateSelectedItemSemanticLabel,
            ),
          );
          await tester.pump();

          final result = verify(
            () => mockEditor.addHistory(meta: captureAny(named: 'meta')),
          )..called(1);
          final meta = result.captured.single as Map<String, dynamic>;
          final tracksJson =
              meta[VideoEditorConstants.audioStateHistoryKey] as List<dynamic>;
          final copied = AudioEvent.fromJson(
            tracksJson[1] as Map<String, dynamic>,
          );
          final trailing = AudioEvent.fromJson(
            tracksJson[2] as Map<String, dynamic>,
          );

          expect(tracksJson, hasLength(3));
          expect(copied.id, startsWith('sound-1_copy_'));
          expect(trailing.id, equals('sound-2'));

          final addEvent = verify(
            () => overlayBloc.add(captureAny()),
          ).captured.whereType<TimelineOverlayItemSelected>().last;
          expect(addEvent.itemId, startsWith('sound-1_copy_'));
        },
      );

      testWidgets(
        'sound split sets startOffset of second segment to '
        'originalOffset + (splitAt - startTime)',
        (tester) async {
          final track = AudioEvent(
            id: 'sound-1',
            pubkey: 'pub',
            createdAt: 0,
            startOffset: const Duration(seconds: 2),
            startTime: const Duration(seconds: 3),
            endTime: const Duration(seconds: 8),
          );
          when(() => mockStateManager.activeMeta).thenReturn({
            VideoEditorConstants.audioStateHistoryKey: [track.toJson()],
          });
          // splitAt = 5s, which is within [3s, 8s)
          when(() => mainBloc.state).thenReturn(
            const VideoEditorMainState(
              currentPosition: Duration(seconds: 5),
            ),
          );

          const item = TimelineOverlayItem(
            id: 'sound-1',
            type: TimelineOverlayType.sound,
            startTime: Duration(seconds: 3),
            endTime: Duration(seconds: 8),
          );
          await tester.pumpWidget(
            buildWithEditor(item, mockEditor, mainBloc),
          );

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorSplitSelectedClipSemanticLabel,
            ),
          );
          await tester.pump();

          final result = verify(
            () => mockEditor.addHistory(meta: captureAny(named: 'meta')),
          )..called(1);
          final meta = result.captured.single as Map<String, dynamic>;
          final tracksJson =
              meta[VideoEditorConstants.audioStateHistoryKey] as List<dynamic>;
          final second = AudioEvent.fromJson(
            tracksJson[1] as Map<String, dynamic>,
          );

          // second.startOffset = originalStartOffset + (splitAt - item.startTime)
          //                     = 2s + (5s - 3s) = 4s
          expect(second.startOffset, equals(const Duration(seconds: 4)));
        },
      );

      testWidgets(
        'animate sources the total duration from ClipEditorBloc, not '
        'VideoEditorMainBloc',
        (tester) async {
          final layer = TextLayer(
            text: 'Layer A',
            id: 'layer-a',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          );
          when(() => mockEditor.activeLayers).thenReturn([layer]);
          when(() => mainBloc.state).thenReturn(const VideoEditorMainState());

          final clipBloc = _MockClipEditorBloc();
          when(
            () => clipBloc.stream,
          ).thenAnswer((_) => const Stream<ClipEditorState>.empty());
          when(() => clipBloc.state).thenReturn(const ClipEditorState());

          const item = TimelineOverlayItem(
            id: 'layer-a',
            type: TimelineOverlayType.layer,
            startTime: Duration.zero,
            endTime: Duration(seconds: 3),
          );
          await tester.pumpWidget(
            buildWithEditor(item, mockEditor, mainBloc, clipBloc: clipBloc),
          );

          // The total is only consulted when animate is tapped.
          verifyNever(() => clipBloc.state);

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorLayerAnimationButtonSemanticLabel,
            ),
          );
          // Bounded pumps rather than pumpAndSettle: the picker preview loops
          // continuously so the tree never settles.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          // The animation sheet opens with the total taken from
          // ClipEditorBloc.totalDuration. If the source were reverted to
          // VideoEditorMainBloc (the transient-zero bug this PR fixes),
          // clipBloc.state would never be read.
          verify(() => clipBloc.state).called(greaterThanOrEqualTo(1));
          expect(find.byType(LayerAnimationPickerView), findsOneWidget);
        },
      );

      testWidgets(
        'tune edit opens the tune sub-editor seeded with the set id',
        (tester) async {
          final tuneBloc = VideoEditorTuneBloc();
          addTearDown(tuneBloc.close);
          when(() => mockEditor.openTuneEditor()).thenAnswer((_) {});
          when(() => mainBloc.state).thenReturn(const VideoEditorMainState());

          const item = TimelineOverlayItem(
            id: 'set-1',
            type: TimelineOverlayType.tune,
            startTime: Duration.zero,
            endTime: Duration(seconds: 5),
          );
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: MultiBlocProvider(
                    providers: [
                      BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
                      BlocProvider<TimelineOverlayBloc>.value(
                        value: overlayBloc,
                      ),
                      BlocProvider<VideoEditorTuneBloc>.value(value: tuneBloc),
                    ],
                    child: VideoEditorScope(
                      editorKey: GlobalKey(),
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
                      onAddEditTextLayer: ([layer]) async => null,
                      onOpenMusicLibrary: () {},
                      onOpenVoiceOver: () {},
                      onOpenCaptions: () {},
                      editorOverride: mockEditor,
                      child: const TimelineOverlayControls(item: item),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorEditSelectedItemSemanticLabel,
            ),
          );
          await tester.pump();

          verify(() => mockEditor.openTuneEditor()).called(1);
          verify(
            () => mainBloc.add(
              const VideoEditorMainOpenSubEditor(SubEditorType.tune),
            ),
          ).called(1);
          expect(tuneBloc.state.editingSetId, 'set-1');
        },
      );

      testWidgets(
        'multi-select entry starts draw-layer multi-select with the tapped id',
        (tester) async {
          final drawA = _buildPaintLayer('draw-a');
          final drawB = _buildPaintLayer('draw-b');
          when(
            () => mockEditor.activeLayers,
          ).thenReturn([drawA, drawB]);
          when(() => mainBloc.state).thenReturn(const VideoEditorMainState());

          const item = TimelineOverlayItem(
            id: 'draw-a',
            type: TimelineOverlayType.layer,
            startTime: Duration.zero,
            endTime: Duration(seconds: 3),
          );
          await tester.pumpWidget(buildWithEditor(item, mockEditor, mainBloc));

          expect(find.text(l10n.videoEditorMultiSelectLabel), findsOneWidget);

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorLayerMultiSelectSemanticLabel,
            ),
          );
          await tester.pump();

          verify(
            () => overlayBloc.add(
              const TimelineOverlayLayerMultiSelectStarted('draw-a'),
            ),
          ).called(1);
        },
      );

      testWidgets(
        'multi-select entry is hidden when a non-draw layer is selected',
        (tester) async {
          final text = TextLayer(text: 'hi', id: 'text-1');
          final drawA = _buildPaintLayer('draw-a');
          final drawB = _buildPaintLayer('draw-b');
          when(
            () => mockEditor.activeLayers,
          ).thenReturn([text, drawA, drawB]);
          when(() => mainBloc.state).thenReturn(const VideoEditorMainState());

          const item = TimelineOverlayItem(
            id: 'text-1',
            type: TimelineOverlayType.layer,
            startTime: Duration.zero,
            endTime: Duration(seconds: 3),
          );
          await tester.pumpWidget(buildWithEditor(item, mockEditor, mainBloc));

          expect(find.text(l10n.videoEditorMultiSelectLabel), findsNothing);
        },
      );

      testWidgets(
        'multi-select entry is hidden when only one draw layer exists',
        (tester) async {
          final drawA = _buildPaintLayer('draw-a');
          when(() => mockEditor.activeLayers).thenReturn([drawA]);
          when(() => mainBloc.state).thenReturn(const VideoEditorMainState());

          const item = TimelineOverlayItem(
            id: 'draw-a',
            type: TimelineOverlayType.layer,
            startTime: Duration.zero,
            endTime: Duration(seconds: 3),
          );
          await tester.pumpWidget(buildWithEditor(item, mockEditor, mainBloc));

          expect(find.text(l10n.videoEditorMultiSelectLabel), findsNothing);
        },
      );
    });
  });
}

PaintLayer _buildPaintLayer(String id) => PaintLayer(
  id: id,
  rawSize: const Size(10, 10),
  opacity: 1,
  item: PaintedModel(
    mode: PaintMode.freeStyle,
    offsets: const [Offset.zero, Offset(10, 10)],
    erasedOffsets: const [],
    color: const Color(0xFFFF0000),
    strokeWidth: 6,
    opacity: 1,
  ),
);
