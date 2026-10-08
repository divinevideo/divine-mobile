// ABOUTME: Tests for VideoEditorDrawOverlayControls widget.
// ABOUTME: Validates top bar buttons (Close, Undo, Redo, Done), the sliders
// ABOUTME: and the brush preview.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_brush_preview.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_vertical_slider.dart';

class MockVideoEditorDrawBloc
    extends MockBloc<VideoEditorDrawEvent, VideoEditorDrawState>
    implements VideoEditorDrawBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('en'));
  final closeLabel = l10n.videoEditorDiscardToolChangesSemanticLabel(
    l10n.videoEditorDrawLabel,
  );
  final doneLabel = l10n.videoEditorApplyToolChangesSemanticLabel(
    l10n.videoEditorDrawLabel,
  );

  group('VideoEditorDrawOverlayControls', () {
    late MockVideoEditorDrawBloc mockBloc;

    setUp(() {
      mockBloc = MockVideoEditorDrawBloc();

      when(() => mockBloc.state).thenReturn(const VideoEditorDrawState());
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    Widget buildWidget({
      GlobalKey? canvasBodyKey,
      Widget canvas = const SizedBox.shrink(),
      bool disableAnimations = false,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: Scaffold(
          body: VideoEditorScope(
            editorKey: GlobalKey(),
            removeAreaKey: GlobalKey(),
            canvasBodyKey: canvasBodyKey,
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
            child: BlocProvider<VideoEditorDrawBloc>.value(
              value: mockBloc,
              child: Stack(
                children: [
                  canvas,
                  const SizedBox(
                    width: 400,
                    height: 600,
                    child: VideoEditorDrawOverlayControls(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    group('Close button', () {
      testWidgets('renders with correct semantics', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == closeLabel,
          ),
          findsOneWidget,
        );
      });

      testWidgets('names the censor tool while hiding areas', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(selectedTool: .blur));
        await tester.pumpWidget(buildWidget());

        final censorCloseLabel = l10n
            .videoEditorDiscardToolChangesSemanticLabel(
              l10n.videoEditorCensorLabel,
            );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == censorCloseLabel,
          ),
          findsOneWidget,
        );
      });
    });

    group('Undo button', () {
      testWidgets('renders with correct semantics', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Undo',
          ),
          findsOneWidget,
        );
      });

      testWidgets('is disabled when canUndo is false', (tester) async {
        when(() => mockBloc.state).thenReturn(const VideoEditorDrawState());

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Undo',
          ),
        );
        expect(semantics.properties.enabled, isFalse);
      });

      testWidgets('is enabled when canUndo is true', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(canUndo: true));

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Undo',
          ),
        );
        expect(semantics.properties.enabled, isTrue);
      });
    });

    group('Redo button', () {
      testWidgets('renders with correct semantics', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Redo',
          ),
          findsOneWidget,
        );
      });

      testWidgets('is disabled when canRedo is false', (tester) async {
        when(() => mockBloc.state).thenReturn(const VideoEditorDrawState());

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Redo',
          ),
        );
        expect(semantics.properties.enabled, isFalse);
      });

      testWidgets('is enabled when canRedo is true', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(canRedo: true));

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Redo',
          ),
        );
        expect(semantics.properties.enabled, isTrue);
      });
    });

    group('Done button', () {
      testWidgets('renders with correct semantics', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == doneLabel,
          ),
          findsOneWidget,
        );
      });

      testWidgets('is marked as a button', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == doneLabel,
          ),
        );
        expect(semantics.properties.button, isTrue);
      });
    });

    group('Brush size slider', () {
      testWidgets('shows the brush size of the selected drawing tool', (
        tester,
      ) async {
        const state = VideoEditorDrawState(
          selectedTool: DrawToolType.marker,
          strokeWidths: {DrawToolType.marker: 20.0},
        );
        when(() => mockBloc.state).thenReturn(state);
        await tester.pumpWidget(buildWidget());

        final slider = tester.widget<VideoEditorVerticalSlider>(
          find.byType(VideoEditorVerticalSlider),
        );
        expect(slider.value, state.brushSize);
        expect(slider.semanticLabel, l10n.videoEditorBrushSizeSemanticLabel);
      });

      testWidgets('reports a new brush size', (tester) async {
        await tester.pumpWidget(buildWidget());

        tester
            .widget<VideoEditorVerticalSlider>(
              find.byType(VideoEditorVerticalSlider),
            )
            .onChanged(0.3);

        verify(
          () => mockBloc.add(const VideoEditorDrawBrushSizeChanged(0.3)),
        ).called(1);
      });
    });

    group('Brush preview', () {
      final preview = find.byType(VideoEditorDrawBrushPreview);

      Future<TestGesture> dragSlider(WidgetTester tester) async {
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(VideoEditorVerticalSlider)),
        );
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump();
        return gesture;
      }

      BoxDecoration previewDecoration(WidgetTester tester) =>
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: preview,
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;

      testWidgets(
        'shows a dot as thick as the next stroke in the middle of the canvas',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const VideoEditorDrawState(
              selectedTool: DrawToolType.marker,
              selectedColor: VineTheme.vineGreen,
              strokeWidths: {DrawToolType.marker: 20.0},
            ),
          );
          final canvasBodyKey = GlobalKey();
          // Laid out apart from the controls, as in the editor.
          final canvas = Positioned(
            top: 80,
            width: 400,
            height: 600,
            child: SizedBox.expand(key: canvasBodyKey),
          );
          await tester.pumpWidget(
            buildWidget(canvasBodyKey: canvasBodyKey, canvas: canvas),
          );
          expect(preview, findsNothing);

          final gesture = await dragSlider(tester);

          expect(tester.getSize(preview), const Size.square(20));
          expect(
            tester.getCenter(preview),
            tester.getCenter(find.byKey(canvasBodyKey)),
          );
          expect(
            previewDecoration(tester).color,
            VineTheme.vineGreen.withValues(alpha: 0.7),
          );
          await gesture.up();
        },
      );

      testWidgets('outlines the area the eraser erases', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const VideoEditorDrawState(selectedTool: DrawToolType.eraser),
        );
        await tester.pumpWidget(buildWidget());

        final gesture = await dragSlider(tester);

        final decoration = previewDecoration(tester);
        expect(decoration.color, isNull);
        expect(decoration.border, isNotNull);
        await gesture.up();
      });

      testWidgets('fades out after the slider is released', (tester) async {
        await tester.pumpWidget(buildWidget());
        final gesture = await dragSlider(tester);

        await gesture.up();
        await tester.pump();
        expect(preview, findsOneWidget);

        await tester.pumpAndSettle();
        expect(preview, findsNothing);
      });

      testWidgets('disappears at once under reduced motion', (tester) async {
        await tester.pumpWidget(buildWidget(disableAnimations: true));
        final gesture = await dragSlider(tester);
        expect(preview, findsOneWidget);

        await gesture.up();
        await tester.pump();

        expect(preview, findsNothing);
      });

      testWidgets('is not shown while the censor strength changes', (
        tester,
      ) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(selectedTool: .blur));
        await tester.pumpWidget(buildWidget());

        final gesture = await dragSlider(tester);

        expect(preview, findsNothing);
        await gesture.up();
      });
    });

    group('Strength slider', () {
      testWidgets('shows the intensity of the selected censor tool', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoEditorDrawState(
            selectedTool: DrawToolType.pixelate,
            pixelateIntensity: 0.8,
          ),
        );
        await tester.pumpWidget(buildWidget());

        final slider = tester.widget<VideoEditorVerticalSlider>(
          find.byType(VideoEditorVerticalSlider),
        );
        expect(slider.value, 0.8);
        expect(slider.semanticLabel, isNull);
      });

      testWidgets('reports a new intensity', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(selectedTool: .blur));
        await tester.pumpWidget(buildWidget());

        tester
            .widget<VideoEditorVerticalSlider>(
              find.byType(VideoEditorVerticalSlider),
            )
            .onChanged(0.3);

        verify(
          () => mockBloc.add(const VideoEditorDrawCensorIntensityChanged(0.3)),
        ).called(1);
      });
    });

    group('State updates', () {
      testWidgets('updates when canUndo changes', (tester) async {
        final controller = StreamController<VideoEditorDrawState>.broadcast();

        when(() => mockBloc.state).thenReturn(const VideoEditorDrawState());
        when(() => mockBloc.stream).thenAnswer((_) => controller.stream);

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Initial state - undo disabled
        var semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Undo',
          ),
        );
        expect(semantics.properties.enabled, isFalse);

        // Update state
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(canUndo: true));
        controller.add(const VideoEditorDrawState(canUndo: true));
        await tester.pumpAndSettle();

        semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Undo',
          ),
        );
        expect(semantics.properties.enabled, isTrue);

        await controller.close();
      });

      testWidgets('updates when canRedo changes', (tester) async {
        final controller = StreamController<VideoEditorDrawState>.broadcast();

        when(() => mockBloc.state).thenReturn(const VideoEditorDrawState());
        when(() => mockBloc.stream).thenAnswer((_) => controller.stream);

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Initial state - redo disabled
        var semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Redo',
          ),
        );
        expect(semantics.properties.enabled, isFalse);

        // Update state
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(canRedo: true));
        controller.add(const VideoEditorDrawState(canRedo: true));
        await tester.pumpAndSettle();

        semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Redo',
          ),
        );
        expect(semantics.properties.enabled, isTrue);

        await controller.close();
      });
    });
  });
}
