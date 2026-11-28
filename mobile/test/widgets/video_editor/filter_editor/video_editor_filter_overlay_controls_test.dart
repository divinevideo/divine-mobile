// ABOUTME: Tests for VideoEditorFilterOverlayControls widget.
// ABOUTME: Validates opacity slider visibility, top bar buttons, and animations.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/editor_filter_category.dart';
import 'package:openvine/models/video_editor/filter_settings.dart';
import 'package:openvine/widgets/video_editor/filter_editor/video_editor_filter_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_vertical_slider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class _MockVideoEditorFilterBloc
    extends MockBloc<VideoEditorFilterEvent, VideoEditorFilterState>
    implements VideoEditorFilterBloc {}

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockFilterEditorState extends Mock implements FilterEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockFilterEditorState';
}

class _MockFilterEditorKey extends Mock
    implements GlobalKey<FilterEditorState> {}

class _MockStateManager extends Mock implements StateManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('en'));
  final closeLabel = l10n.videoEditorDiscardToolChangesSemanticLabel(
    l10n.videoEditorFilterLabel,
  );
  final doneLabel = l10n.videoEditorApplyToolChangesSemanticLabel(
    l10n.videoEditorFilterLabel,
  );

  setUpAll(() {
    registerFallbackValue(VideoEditorFilterSelected(presetFiltersList.first));
    registerFallbackValue(const VideoEditorFilterCancelled());
    registerFallbackValue(const VideoEditorFilterConfirmed());
    registerFallbackValue(<FilterState>[]);
    registerFallbackValue(PresetFilters.none);
  });

  group('VideoEditorFilterOverlayControls', () {
    late _MockVideoEditorFilterBloc mockBloc;
    late _MockVideoEditorMainBloc mockMainBloc;
    late GlobalKey<ProImageEditorState> editorKey;

    setUp(() {
      mockBloc = _MockVideoEditorFilterBloc();
      mockMainBloc = _MockVideoEditorMainBloc();
      editorKey = GlobalKey<ProImageEditorState>();

      // Default state - no filter selected
      when(
        () => mockBloc.state,
      ).thenReturn(const VideoEditorFilterState());
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());

      when(() => mockMainBloc.state).thenReturn(const VideoEditorMainState());
      when(() => mockMainBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    Widget buildWidget({
      double height = 600,
      ProImageEditorState? editorOverride,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoEditorScope(
            editorKey: editorKey,
            editorOverride: editorOverride,
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
                BlocProvider<VideoEditorFilterBloc>.value(value: mockBloc),
                BlocProvider<VideoEditorMainBloc>.value(value: mockMainBloc),
              ],
              child: SizedBox(
                width: 400,
                height: height,
                child: const VideoEditorFilterOverlayControls(),
              ),
            ),
          ),
        ),
      );
    }

    group('Opacity Slider', () {
      testWidgets('is hidden when no filter is selected', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoEditorVerticalSlider), findsNothing);
      });

      testWidgets('is visible when a filter is selected', (tester) async {
        when(() => mockBloc.state).thenReturn(
          VideoEditorFilterState(
            selectedFilter: presetFiltersList[1],
            opacity: 0.8,
          ),
        );

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoEditorVerticalSlider), findsOneWidget);
      });

      testWidgets('passes current opacity value to slider', (tester) async {
        const testOpacity = 0.65;
        when(() => mockBloc.state).thenReturn(
          VideoEditorFilterState(
            selectedFilter: presetFiltersList[1],
            opacity: testOpacity,
          ),
        );

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final slider = tester.widget<VideoEditorVerticalSlider>(
          find.byType(VideoEditorVerticalSlider),
        );
        expect(slider.value, testOpacity);
      });

      testWidgets('stays below the toolbar over a short preview', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          VideoEditorFilterState(selectedFilter: presetFiltersList[1]),
        );
        // The preview left above the filter picker on a phone.
        await tester.pumpWidget(buildWidget(height: 380));
        await tester.pumpAndSettle();

        expect(
          tester.getRect(find.byType(VideoEditorVerticalSlider)).top,
          greaterThanOrEqualTo(
            tester.getRect(find.bySemanticsLabel(doneLabel)).bottom,
          ),
        );
      });

      testWidgets('shows slider during animation', (tester) async {
        // Start with a filter selected
        when(() => mockBloc.state).thenReturn(
          VideoEditorFilterState(
            selectedFilter: presetFiltersList[1],
          ),
        );

        await tester.pumpWidget(buildWidget());
        // Pump some frames of animation
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(VideoEditorVerticalSlider), findsOneWidget);
      });
    });

    group('Top Bar', () {
      testWidgets('renders Close and Done buttons', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Close button carries the discard-changes semantics label.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == closeLabel,
          ),
          findsOneWidget,
        );

        // Done button carries the apply-changes semantics label.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == doneLabel,
          ),
          findsOneWidget,
        );
      });

      testWidgets('tapping Close dispatches Cancelled event', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == closeLabel,
          ),
        );
        await tester.pump();

        verify(
          () => mockBloc.add(const VideoEditorFilterCancelled()),
        ).called(1);
      });

      group('Done', () {
        late _MockProImageEditorState editor;
        late _MockFilterEditorState filterEditor;

        setUp(() {
          editor = _MockProImageEditorState();
          filterEditor = _MockFilterEditorState();
          final filterEditorKey = _MockFilterEditorKey();
          when(() => editor.filterEditor).thenReturn(filterEditorKey);
          when(() => filterEditorKey.currentState).thenReturn(filterEditor);
        });

        Future<void> tapDone(WidgetTester tester) async {
          await tester.pumpWidget(buildWidget(editorOverride: editor));
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(doneLabel));
          await tester.pump();
        }

        void verifyClosedWithoutCommitting() {
          verify(
            () => mockBloc.add(const VideoEditorFilterCancelled()),
          ).called(1);
          verifyNever(() => mockBloc.add(const VideoEditorFilterConfirmed()));
          verify(() => filterEditor.close()).called(1);
          verifyNever(() => filterEditor.done());
          verifyNever(
            () => editor.addHistory(filters: any(named: 'filters')),
          );
        }

        testWidgets('commits the picked filter with its settings, after '
            'the others', (tester) async {
          final picked = editorFilterNamed('Crema')!;
          final other = FilterState(id: 'other', name: 'Ludwig');
          final stateManager = _MockStateManager();
          final matrices = [ColorFilterAddons.sepia(0.5)];
          when(() => editor.stateManager).thenReturn(stateManager);
          when(() => stateManager.activeFilters).thenReturn([other]);
          when(() => filterEditor.filterMatrix).thenReturn(matrices);
          when(() => mockBloc.state).thenReturn(
            VideoEditorFilterState(
              selectedFilter: picked,
              opacity: 0.5,
              settingValues: const {'temperature': -0.1},
            ),
          );
          when(() => filterEditor.selectedFilter).thenReturn(picked);

          await tapDone(tester);

          verify(
            () => mockBloc.add(const VideoEditorFilterConfirmed()),
          ).called(1);
          verify(() => filterEditor.close()).called(1);
          verifyNever(() => filterEditor.done());
          final committed =
              verify(
                    () => editor.addHistory(
                      filters: captureAny(named: 'filters'),
                    ),
                  ).captured.single
                  as List<FilterState>;
          expect(committed.first, other);
          expect(committed.last.name, 'Crema');
          expect(committed.last.matrices, matrices);
          expect(
            EditedFilter.fromMeta(committed.last.meta),
            EditedFilter(
              preset: picked,
              values: const {'temperature': -0.1},
              opacity: 0.5,
            ),
          );
        });

        testWidgets('replaces the filter an edit started on, in place', (
          tester,
        ) async {
          final picked = editorFilterNamed('Crema')!;
          final edited = FilterState(
            id: 'edited',
            name: 'Ludwig',
            startTime: const Duration(seconds: 2),
          );
          final stateManager = _MockStateManager();
          when(() => editor.stateManager).thenReturn(stateManager);
          when(() => stateManager.activeFilters).thenReturn([edited]);
          when(() => filterEditor.filterMatrix).thenReturn(picked.filters);
          when(() => mockBloc.state).thenReturn(
            VideoEditorFilterState(
              selectedFilter: picked,
              editingFilterId: 'edited',
            ),
          );
          when(() => filterEditor.selectedFilter).thenReturn(picked);

          await tapDone(tester);

          final committed =
              verify(
                    () => editor.addHistory(
                      filters: captureAny(named: 'filters'),
                    ),
                  ).captured.single
                  as List<FilterState>;
          expect(committed.single.id, 'edited');
          expect(committed.single.name, 'Crema');
          expect(committed.single.startTime, const Duration(seconds: 2));
        });

        testWidgets('with nothing picked closes without committing', (
          tester,
        ) async {
          when(
            () => filterEditor.selectedFilter,
          ).thenReturn(PresetFilters.none);

          await tapDone(tester);

          verifyClosedWithoutCommitting();
        });

        testWidgets('closes without committing when the editor has nothing '
            'picked, even if the bloc still holds an earlier pick', (
          tester,
        ) async {
          when(() => mockBloc.state).thenReturn(
            VideoEditorFilterState(selectedFilter: presetFiltersList[1]),
          );
          when(
            () => filterEditor.selectedFilter,
          ).thenReturn(PresetFilters.none);

          await tapDone(tester);

          verifyClosedWithoutCommitting();
        });
      });
    });

    group('Settings button', () {
      final settingsLabel = l10n.videoEditorFilterSettingsOpen;

      testWidgets('is hidden while no filter is picked', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.bySemanticsLabel(settingsLabel), findsNothing);
      });

      testWidgets('opens the settings of the picked filter', (tester) async {
        when(() => mockBloc.state).thenReturn(
          VideoEditorFilterState(selectedFilter: editorFilterNamed('Crema')),
        );
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        await tester.tap(find.bySemanticsLabel(settingsLabel));
        await tester.pump();

        verify(
          () =>
              mockBloc.add(const VideoEditorFilterSettingsToggled(open: true)),
        ).called(1);
      });

      testWidgets('closes the settings while they are open', (tester) async {
        when(() => mockBloc.state).thenReturn(
          VideoEditorFilterState(
            selectedFilter: editorFilterNamed('Crema'),
            isSettingsOpen: true,
          ),
        );
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          tester.getSemantics(find.bySemanticsLabel(settingsLabel)),
          isSemantics(isToggled: true, hasToggledState: true),
        );
        await tester.tap(find.bySemanticsLabel(settingsLabel));
        await tester.pump();

        verify(
          () =>
              mockBloc.add(const VideoEditorFilterSettingsToggled(open: false)),
        ).called(1);
      });
    });

    group('Preview', () {
      testWidgets('shows the picked filter with its settings at its opacity', (
        tester,
      ) async {
        final editor = _MockProImageEditorState();
        final filterEditor = _MockFilterEditorState();
        final filterEditorKey = _MockFilterEditorKey();
        when(() => editor.filterEditor).thenReturn(filterEditorKey);
        when(() => filterEditorKey.currentState).thenReturn(filterEditor);
        final crema = editorFilterNamed('Crema')!;
        final changed = VideoEditorFilterState(
          selectedFilter: crema,
          opacity: 0.4,
          settingValues: const {'temperature': -0.1},
        );
        whenListen(
          mockBloc,
          Stream.value(changed),
          initialState: VideoEditorFilterState(selectedFilter: crema),
        );

        await tester.pumpWidget(buildWidget(editorOverride: editor));
        await tester.pump();

        final shown =
            verify(() => filterEditor.setFilter(captureAny())).captured.single
                as FilterModel;
        expect(shown.steps, changed.edited!.filter.steps);
        verify(() => filterEditor.setFilterOpacity(0.4)).called(1);
      });
    });
  });
}
