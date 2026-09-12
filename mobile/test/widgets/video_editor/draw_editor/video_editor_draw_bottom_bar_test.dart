// ABOUTME: Tests for VideoEditorDrawBottomBar widget.
// ABOUTME: Validates tool selection, color picker button, and tool interactions.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_arrow.dart';
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

    Widget buildWidget({MockPaintEditorState? paintEditor}) {
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
                child: const SizedBox(
                  width: 400,
                  height: 600,
                  child: VideoEditorDrawBottomBar(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    group('Tool buttons', () {
      testWidgets('renders all four tool buttons', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(DrawToolPencil), findsOneWidget);
        expect(find.byType(DrawToolMarker), findsOneWidget);
        expect(find.byType(DrawToolArrow), findsOneWidget);
        expect(find.byType(DrawToolEraser), findsOneWidget);
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

      for (final (tool, widgetType) in [
        (DrawToolType.pencil, DrawToolPencil),
        (DrawToolType.marker, DrawToolMarker),
        (DrawToolType.arrow, DrawToolArrow),
        (DrawToolType.eraser, DrawToolEraser),
      ]) {
        testWidgets('tapping ${tool.name} dispatches ToolSelected event', (
          tester,
        ) async {
          await tester.pumpWidget(buildWidget(paintEditor: mockPaintEditor));
          await tester.pump();

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

        final arrow = tester.widget<DrawToolArrow>(find.byType(DrawToolArrow));
        expect(arrow.isSelected, isFalse);

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
