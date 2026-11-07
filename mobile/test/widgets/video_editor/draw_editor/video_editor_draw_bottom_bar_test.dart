// ABOUTME: Tests for VideoEditorDrawBottomBar widget.
// ABOUTME: Validates tool selection, color picker button, and tool interactions.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_brushes.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_eraser.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_marker.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_pencil.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_item_indicator.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockVideoEditorDrawBloc
    extends MockBloc<VideoEditorDrawEvent, VideoEditorDrawState>
    implements VideoEditorDrawBloc {}

class MockPaintEditorState extends Mock implements PaintEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'MockPaintEditorState';
}

/// The button widget of every drawing tool, in the order the bar shows them.
const _toolWidgets = <DrawToolType, Type>{
  .pencil: DrawToolPencil,
  .marker: DrawToolMarker,
  .neon: DrawToolNeon,
  .calligraphy: DrawToolCalligraphy,
  .rainbow: DrawToolRainbow,
  .eraser: DrawToolEraser,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      const VideoEditorDrawToolSelected(DrawToolType.pencil),
    );
    registerFallbackValue(const VideoEditorDrawColorSelected(Colors.red));
    registerFallbackValue(PaintMode.freeStyle);
    registerFallbackValue(Colors.black);
  });

  group('VideoEditorDrawBottomBar', () {
    late MockVideoEditorDrawBloc mockBloc;
    late GlobalKey<ProImageEditorState> editorKey;
    late MockPaintEditorState mockPaintEditor;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockBloc = MockVideoEditorDrawBloc();
      editorKey = GlobalKey<ProImageEditorState>();
      mockPaintEditor = MockPaintEditorState();

      when(() => mockBloc.state).thenReturn(const VideoEditorDrawState());
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());

      // Setup mock paint editor methods
      when(() => mockPaintEditor.setMode(any())).thenReturn(null);
      when(() => mockPaintEditor.setOpacity(any())).thenReturn(null);
      when(() => mockPaintEditor.setStrokeWidth(any())).thenReturn(null);
      when(() => mockPaintEditor.setColor(any())).thenReturn(null);
    });

    Widget buildWidget({
      MockPaintEditorState? paintEditor,
      double width = 400,
      GlobalKey? canvasBodyKey,
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<VideoEditorDrawBloc>.value(
              value: mockBloc,
              child: VideoEditorScope(
                editorKey: editorKey,
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
                child: SizedBox(
                  width: width,
                  height: 600,
                  child: const VideoEditorDrawBottomBar(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    group('Tool buttons', () {
      testWidgets('renders a button for every drawing tool, in order', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(_toolWidgets.keys, DrawToolType.drawingTools);
        final lefts = [
          for (final type in _toolWidgets.values)
            tester.getTopLeft(find.byType(type)).dx,
        ];
        expect(lefts, orderedEquals([...lefts]..sort()));
      });

      testWidgets('scrolls sideways to the tools past the edge', (
        tester,
      ) async {
        // Narrower than a phone, so the tools do not fit.
        await tester.pumpWidget(buildWidget(width: 300));
        await tester.pump();

        final eraser = find.byType(DrawToolEraser);
        final barRight = tester.getTopRight(find.byType(SingleChildScrollView));
        expect(tester.getTopRight(eraser).dx, greaterThan(barRight.dx));

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(-1000, 0),
        );
        await tester.pumpAndSettle();

        expect(tester.getTopRight(eraser).dx, lessThanOrEqualTo(barRight.dx));
      });

      testWidgets('pencil is selected by default', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final pencil = tester.widget<DrawToolPencil>(
          find.byType(DrawToolPencil),
        );
        expect(pencil.isSelected, isTrue);

        final marker = tester.widget<DrawToolMarker>(
          find.byType(DrawToolMarker),
        );
        expect(marker.isSelected, isFalse);
      });

      for (final MapEntry(key: tool, value: widgetType)
          in _toolWidgets.entries) {
        testWidgets('tapping ${tool.name} dispatches ToolSelected event', (
          tester,
        ) async {
          await tester.pumpWidget(buildWidget(paintEditor: mockPaintEditor));
          await tester.pump();

          await tester.ensureVisible(find.byType(widgetType));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(widgetType));
          await tester.pump();

          verify(
            () => mockBloc.add(VideoEditorDrawToolSelected(tool)),
          ).called(1);
        });
      }

      testWidgets('shows correct tool as selected based on state', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoEditorDrawState(selectedTool: DrawToolType.marker),
        );

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final pencil = tester.widget<DrawToolPencil>(
          find.byType(DrawToolPencil),
        );
        expect(pencil.isSelected, isFalse);

        final marker = tester.widget<DrawToolMarker>(
          find.byType(DrawToolMarker),
        );
        expect(marker.isSelected, isTrue);

        final eraser = tester.widget<DrawToolEraser>(
          find.byType(DrawToolEraser),
        );
        expect(eraser.isSelected, isFalse);
      });
    });

    group('Tool indicator', () {
      testWidgets('renders indicator widget', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(VideoEditorDrawItemIndicator), findsOneWidget);
      });
    });

    group('Color picker button', () {
      testWidgets('renders color picker button with semantics', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Color picker',
          ),
          findsOneWidget,
        );
      });

      testWidgets('tapping color picker opens bottom sheet', (tester) async {
        await tester.pumpWidget(buildWidget(paintEditor: mockPaintEditor));
        await tester.pump();

        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Color picker',
          ),
        );
        await tester.pumpAndSettle();

        // Bottom sheet should be shown
        expect(find.byType(BottomSheet), findsOneWidget);
      });
    });

    group('Eyedropper button', () {
      final eyedropper = find.byWidgetPredicate(
        (widget) =>
            widget is DivineIconButton &&
            widget.icon == DivineIconName.eyedropper,
      );

      testWidgets('is not offered without a canvas to pick from', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(eyedropper, findsNothing);
      });

      testWidgets('sits beside the color picker and opens the eyedropper', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(canvasBodyKey: GlobalKey()));
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          tester.widget<DivineIconButton>(eyedropper).semanticLabel,
          l10n.videoEditorEyedropperSemanticLabel,
        );
        final colorPicker = find.bySemanticsLabel(
          l10n.videoEditorColorPickerSemanticLabel,
        );
        expect(
          tester.getCenter(eyedropper).dx,
          lessThan(tester.getCenter(colorPicker).dx),
        );

        await tester.tap(eyedropper);
        await tester.pump();

        verify(
          () => mockBloc.add(const VideoEditorDrawEyedropperStarted()),
        ).called(1);
      });

      testWidgets('closes the eyedropper while it is open', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(isPickingColor: true));
        await tester.pumpWidget(buildWidget(canvasBodyKey: GlobalKey()));
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        final button = tester.widget<DivineIconButton>(eyedropper);
        expect(button.type, DivineIconButtonType.primary);
        expect(
          button.semanticLabel,
          l10n.videoEditorEyedropperCancelSemanticLabel,
        );

        await tester.tap(eyedropper);
        await tester.pump();

        verify(
          () => mockBloc.add(const VideoEditorDrawEyedropperCancelled()),
        ).called(1);
      });
    });

    group('Hide tools', () {
      setUp(() {
        when(() => mockBloc.state).thenReturn(
          const VideoEditorDrawState(
            selectedTool: DrawToolType.blur,
            mode: PaintMode.blur,
          ),
        );
      });

      testWidgets('replace the drawing tools and the color picker', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.byType(DrawToolPencil), findsNothing);
        expect(
          find.bySemanticsLabel(l10n.videoEditorColorPickerSemanticLabel),
          findsNothing,
        );
        expect(find.text(l10n.videoEditorCensorHint), findsOneWidget);
        expect(
          find.bySemanticsLabel(l10n.videoEditorBlurLabel),
          findsOneWidget,
        );
      });

      testWidgets('tapping blur dispatches ToolSelected event', (tester) async {
        await tester.pumpWidget(buildWidget(paintEditor: mockPaintEditor));
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.bySemanticsLabel(l10n.videoEditorBlurLabel));
        await tester.pump();

        verify(
          () => mockBloc.add(
            const VideoEditorDrawToolSelected(DrawToolType.blur),
          ),
        ).called(1);
      });
    });

    group('State updates', () {
      testWidgets('updates tool selection when state changes', (tester) async {
        final controller = StreamController<VideoEditorDrawState>.broadcast();

        when(() => mockBloc.state).thenReturn(const VideoEditorDrawState());
        when(() => mockBloc.stream).thenAnswer((_) => controller.stream);

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Initial state - pencil selected
        var pencil = tester.widget<DrawToolPencil>(find.byType(DrawToolPencil));
        expect(pencil.isSelected, isTrue);

        // Update state
        when(() => mockBloc.state).thenReturn(
          const VideoEditorDrawState(selectedTool: DrawToolType.eraser),
        );
        controller.add(
          const VideoEditorDrawState(selectedTool: DrawToolType.eraser),
        );
        await tester.pumpAndSettle();

        pencil = tester.widget<DrawToolPencil>(find.byType(DrawToolPencil));
        expect(pencil.isSelected, isFalse);

        final eraser = tester.widget<DrawToolEraser>(
          find.byType(DrawToolEraser),
        );
        expect(eraser.isSelected, isTrue);

        await controller.close();
      });
    });
  });
}
