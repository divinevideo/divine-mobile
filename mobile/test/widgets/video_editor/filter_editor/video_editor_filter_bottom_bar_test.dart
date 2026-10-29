// ABOUTME: Tests for VideoEditorFilterBottomBar: the filter categories, their
// ABOUTME: sync with the grid's scroll, picking a filter and the bar's height.

import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/editor_filter_category.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/filter_editor/video_editor_filter_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_category_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

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

class _Clips extends ClipManagerNotifier {
  _Clips(this._clips);

  final List<DivineVideoClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VideoEditorFilterBottomBar, () {
    late VideoEditorFilterBloc bloc;

    /// [navigationBarHeight] is the height of the system navigation bar the
    /// bar reaches under.
    ///
    /// The bloc is created here, inside the test's zone: one created in
    /// setUp emits outside it, and the bar never hears of a pick.
    Widget buildWidget({
      double navigationBarHeight = 0,
      ProImageEditorState? editor,
      List<DivineVideoClip> clips = const [],
    }) {
      bloc = VideoEditorFilterBloc();
      addTearDown(bloc.close);
      return ProviderScope(
        overrides: [clipManagerProvider.overrideWith(() => _Clips(clips))],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  viewPadding: EdgeInsets.only(bottom: navigationBarHeight),
                ),
                child: VideoEditorScope(
                  editorKey: GlobalKey(),
                  editorOverride: editor,
                  removeAreaKey: GlobalKey(),
                  onOpenCamera: () {},
                  onAddStickers: () {},
                  onOpenClipsEditor: () {},
                  onOpenMusicLibrary: () {},
                  onOpenVoiceOver: () {},
                  onOpenCaptions: () {},
                  onOpenEffects: () {},
                  onAddEditTextLayer: ([_]) async => null,
                  originalClipAspectRatio: 9 / 16,
                  bodySizeNotifier: ValueNotifier(Size.zero),
                  zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
                  playTimeNotifier: ValueNotifier(Duration.zero),
                  playheadAdvancingNotifier: ValueNotifier<bool>(false),
                  fromLibrary: false,
                  child: Align(
                    alignment: .bottomCenter,
                    child: BlocProvider.value(
                      value: bloc,
                      child: const VideoEditorFilterBottomBar(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    void usePhoneSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(402, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    final categoryLabels = {
      EditorFilterCategory.natural: l10n.videoEditorFilterCategoryNatural,
      EditorFilterCategory.vibrant: l10n.videoEditorFilterCategoryVibrant,
      EditorFilterCategory.warm: l10n.videoEditorFilterCategoryWarm,
      EditorFilterCategory.cool: l10n.videoEditorFilterCategoryCool,
      EditorFilterCategory.vintage: l10n.videoEditorFilterCategoryVintage,
      EditorFilterCategory.blackAndWhite:
          l10n.videoEditorFilterCategoryBlackAndWhite,
      EditorFilterCategory.tints: l10n.videoEditorFilterCategoryTints,
    };

    Finder grid() => find.byType(CustomScrollView);

    Finder tab(EditorFilterCategory category) => find.descendant(
      of: find.byType(TabBar),
      matching: find.text(categoryLabels[category]!),
    );

    Finder header(EditorFilterCategory category) => find.descendant(
      of: find.byType(SliverToBoxAdapter, skipOffstage: false),
      matching: find.text(categoryLabels[category]!, skipOffstage: false),
      skipOffstage: false,
    );

    Finder tile(String name) => find.descendant(
      of: find.byType(SliverGrid),
      matching: find.text(name),
    );

    EditorFilterCategory highlighted(WidgetTester tester) =>
        EditorFilterCategory.values[tester
            .widget<TabBar>(find.byType(TabBar))
            .controller!
            .index];

    /// Scrolls the grid by [dy] with a finger that stops before it lifts, so
    /// the grid does not fling on past the target.
    Future<void> scrollGridBy(WidgetTester tester, double dy) async {
      final gesture = await tester.startGesture(tester.getCenter(grid()));
      await gesture.moveBy(Offset(0, dy.sign * kDragSlopDefault));
      await gesture.moveBy(Offset(0, dy));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgets('scrolls on under the system navigation bar, and lets the '
          'last row clear it', (tester) async {
        usePhoneSize(tester);
        await tester.pumpWidget(buildWidget(navigationBarHeight: 48));

        final bar = find.byType(VideoEditorFilterBottomBar);
        expect(
          tester.getSize(bar).height,
          moreOrLessEquals(
            VideoEditorFilterBottomBar.heightOf(tester.element(bar)) + 48,
          ),
        );
        expect(tester.getRect(grid()).bottom, 600);
        await tester.drag(grid(), const Offset(0, -5000));
        await tester.pumpAndSettle();
        final lastRowBottom = [
          for (final filter in EditorFilterCategory.values.last.filters)
            tester.getRect(tile(filter.name)).bottom,
        ].reduce(max);
        expect(lastRowBottom, lessThanOrEqualTo(600 - 48));
      });
    });

    group('navigation', () {
      testWidgets('tapping a category scrolls to its section, highlights it '
          'and shows its filters under its title', (tester) async {
        usePhoneSize(tester);
        await tester.pumpWidget(buildWidget());
        final gridRect = tester.getRect(grid());

        for (final category in EditorFilterCategory.values) {
          await tester.ensureVisible(tab(category));
          await tester.pumpAndSettle();
          await tester.tap(tab(category));
          await tester.pumpAndSettle();

          expect(highlighted(tester), category);
          final title = tester.getRect(header(category));
          final position = tester
              .widget<CustomScrollView>(grid())
              .controller!
              .position;
          // The last sections are too short to scroll to the top: their jump
          // stops at the end of the grid.
          if (position.pixels < position.maxScrollExtent) {
            expect(title.top - gridRect.top, inInclusiveRange(0, 10));
          }
          final nextIndex = category.index + 1;
          final next = nextIndex < EditorFilterCategory.values.length
              ? header(EditorFilterCategory.values[nextIndex])
              : null;
          for (final filter in category.filters) {
            final rect = tester.getRect(tile(filter.name));
            expect(gridRect.contains(rect.center), isTrue, reason: filter.name);
            expect(
              rect.top,
              greaterThanOrEqualTo(title.bottom),
              reason: filter.name,
            );
            if (next != null && tester.any(next)) {
              expect(
                rect.bottom,
                lessThanOrEqualTo(tester.getRect(next).top),
                reason: filter.name,
              );
            }
          }
        }
      });

      testWidgets('scrolling through the grid highlights every category in '
          'turn, the last ones too short to reach the top included', (
        tester,
      ) async {
        usePhoneSize(tester);
        await tester.pumpWidget(buildWidget());
        final position = tester
            .widget<CustomScrollView>(grid())
            .controller!
            .position;

        final seen = [highlighted(tester)];
        while (position.pixels < position.maxScrollExtent) {
          await scrollGridBy(tester, -20);
          if (highlighted(tester) != seen.last) seen.add(highlighted(tester));
        }

        expect(seen, EditorFilterCategory.values);
      });
    });

    group('interactions', () {
      testWidgets('tapping a filter picks it and marks only its tile as '
          'selected for screen readers', (tester) async {
        usePhoneSize(tester);
        final warm = EditorFilterCategory.warm.filters;
        await tester.pumpWidget(buildWidget());
        await tester.ensureVisible(tab(EditorFilterCategory.warm));
        await tester.pumpAndSettle();
        await tester.tap(tab(EditorFilterCategory.warm));
        await tester.pumpAndSettle();
        // Nothing is picked when the picker opens.
        expect(
          tester.getSemantics(find.bySemanticsLabel(warm[1].name)),
          isSemantics(isSelected: false),
        );

        await tester.tap(tile(warm[1].name));
        await tester.pumpAndSettle();

        expect(bloc.state.selectedFilter?.name, warm[1].name);
        expect(
          tester.getSemantics(find.bySemanticsLabel(warm[1].name)),
          isSemantics(isSelected: true, isButton: true),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel(warm[0].name)),
          isSemantics(isSelected: false),
        );
      });

      testWidgets('tapping a filter shows it in the editor', (tester) async {
        usePhoneSize(tester);
        final filterEditor = _MockFilterEditorState();
        final filterEditorKey = _MockFilterEditorKey();
        when(() => filterEditorKey.currentState).thenReturn(filterEditor);
        final editor = _MockProImageEditorState();
        when(() => editor.filterEditor).thenReturn(filterEditorKey);
        when(() => editor.stateManager).thenReturn(_MockStateManager());
        final natural = EditorFilterCategory.natural.filters;
        await tester.pumpWidget(buildWidget(editor: editor));

        await tester.tap(tile(natural[1].name));
        await tester.pump();

        verify(() => filterEditor.setFilter(natural[1])).called(1);
      });
    });

    group('previews', () {
      for (final thumbnailPath in [null, '']) {
        testWidgets('show nothing while the first clip has no thumbnail '
            '(${thumbnailPath == null ? 'null' : 'empty'} path)', (
          tester,
        ) async {
          usePhoneSize(tester);
          final clip = DivineVideoClip(
            id: 'clip-1',
            video: EditorVideo.file('/documents/clip-1.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime(2026),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            thumbnailPath: thumbnailPath,
          );
          await tester.pumpWidget(buildWidget(clips: [clip]));

          expect(find.byType(FilteredWidget), findsNothing);
          expect(find.byType(VideoEditorCategoryPickerTile), findsWidgets);
        });
      }

      testWidgets("show each tile's filter over the applied tune and blur, "
          "on the first clip's thumbnail", (tester) async {
        usePhoneSize(tester);
        final tune = [
          TuneAdjustmentMatrix(
            id: 'brightness',
            value: 0.2,
            matrix: ColorFilterAddons.brightness(0.2),
          ),
        ];
        final stateManager = _MockStateManager();
        when(() => stateManager.activeTuneAdjustments).thenReturn(tune);
        when(() => stateManager.activeBlur).thenReturn(3);
        final editor = _MockProImageEditorState();
        when(() => editor.stateManager).thenReturn(stateManager);
        final clip = DivineVideoClip(
          id: 'clip-1',
          video: EditorVideo.file('/documents/clip-1.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime(2026),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          thumbnailPath: '/documents/clip-1.jpg',
        );
        final filter = EditorFilterCategory.natural.filters[1];
        await tester.pumpWidget(buildWidget(editor: editor, clips: [clip]));

        final preview = tester.widget<FilteredWidget>(
          find.descendant(
            of: find.ancestor(
              of: tile(filter.name),
              matching: find.byType(VideoEditorCategoryPickerTile),
            ),
            matching: find.byType(FilteredWidget),
          ),
        );
        expect(preview.filters, same(filter.filters));
        expect(preview.tuneAdjustments, same(tune));
        expect(preview.blurFactor, 3);
        expect(preview.image?.file?.path, clip.thumbnailPath);
      });
    });
  });
}
