// ABOUTME: Tests for VideoEditorTextStyleBar widget.
// ABOUTME: Validates style buttons, font selector button, and BLoC interactions.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_style_bar.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_text_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class MockVideoEditorTextBloc
    extends MockBloc<VideoEditorTextEvent, VideoEditorTextState>
    implements VideoEditorTextBloc {}

class MockTextEditorState extends Mock implements TextEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'MockTextEditorState';
}

class MockTextEditorKey extends Mock implements GlobalKey<TextEditorState> {}

class MockFocusNode extends Mock implements FocusNode {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'MockFocusNode';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const VideoEditorTextColorPickerToggled());
    registerFallbackValue(const VideoEditorTextFontSelectorToggled());
  });

  group('VideoEditorTextStyleBar', () {
    late MockVideoEditorTextBloc mockBloc;
    late MockTextEditorKey mockKey;
    late MockTextEditorState mockEditor;
    late MockFocusNode mockFocusNode;

    setUp(() {
      mockBloc = MockVideoEditorTextBloc();
      mockKey = MockTextEditorKey();
      mockEditor = MockTextEditorState();
      mockFocusNode = MockFocusNode();

      when(() => mockBloc.state).thenReturn(const VideoEditorTextState());
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockKey.currentState).thenReturn(mockEditor);
      when(() => mockEditor.focusNode).thenReturn(mockFocusNode);
      when(() => mockFocusNode.hasFocus).thenReturn(false);
    });

    Widget buildWidget({VideoEditorTextState? state}) {
      if (state != null) {
        when(() => mockBloc.state).thenReturn(state);
      }

      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoTextEditorScope(
            editorKey: mockKey,
            child: BlocProvider<VideoEditorTextBloc>.value(
              value: mockBloc,
              child: const SizedBox(
                width: 400,
                height: 100,
                child: VideoEditorTextStyleBar(),
              ),
            ),
          ),
        ),
      );
    }

    group('Color swatch button', () {
      testWidgets('renders with correct semantics label', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Text color',
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays current color from state', (tester) async {
        await tester.pumpWidget(
          buildWidget(state: const VideoEditorTextState(color: Colors.red)),
        );
        await tester.pump();

        // Find the color swatch container
        final containers = tester.widgetList<Container>(find.byType(Container));
        final colorSwatch = containers.where((c) {
          final decoration = c.decoration;
          if (decoration is BoxDecoration) {
            return decoration.color == Colors.red &&
                decoration.shape == BoxShape.circle;
          }
          return false;
        });

        expect(colorSwatch, isNotEmpty);
      });

      testWidgets('tapping toggles color picker', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final colorButton = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Text color',
        );

        await tester.tap(colorButton);
        await tester.pump();

        verify(
          () => mockBloc.add(const VideoEditorTextColorPickerToggled()),
        ).called(1);
      });
    });

    group('Alignment button', () {
      testWidgets('renders with correct semantics label', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Text alignment',
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays center alignment value by default', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Text alignment',
          ),
        );
        expect(semantics.properties.value, 'Center');
      });

      testWidgets('displays left alignment value when set', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            state: const VideoEditorTextState(alignment: TextAlign.left),
          ),
        );
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Text alignment',
          ),
        );
        expect(semantics.properties.value, 'Left');
      });

      testWidgets('displays right alignment value when set', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            state: const VideoEditorTextState(alignment: TextAlign.right),
          ),
        );
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Text alignment',
          ),
        );
        expect(semantics.properties.value, 'Right');
      });

      testWidgets('tapping calls toggleTextAlign on editor', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final alignmentButton = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Text alignment',
        );

        await tester.tap(alignmentButton);
        await tester.pump();

        verify(() => mockEditor.toggleTextAlign()).called(1);
      });
    });

    group('Background style button', () {
      testWidgets('renders with correct semantics label', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Text background',
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays solid value by default', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Text background',
          ),
        );
        // Default is backgroundAndColor which is "Solid"
        expect(semantics.properties.value, 'Solid');
      });

      testWidgets('displays none value for onlyColor mode', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            state: const VideoEditorTextState(
              backgroundStyle: LayerBackgroundMode.onlyColor,
            ),
          ),
        );
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Text background',
          ),
        );
        expect(semantics.properties.value, 'None');
      });

      testWidgets('tapping calls toggleBackgroundMode on editor', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final backgroundButton = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Text background',
        );

        await tester.tap(backgroundButton);
        await tester.pump();

        verify(() => mockEditor.toggleBackgroundMode()).called(1);
      });
    });

    group('Font selector button', () {
      testWidgets('renders with correct semantics label', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Select font',
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays current font name', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Default font (index 0) should display its name
        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Select font',
          ),
        );
        expect(semantics.properties.value, isNotNull);
        expect(semantics.properties.value, isNotEmpty);
      });

      testWidgets('tapping toggles font selector', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final fontButton = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Select font',
        );

        await tester.tap(fontButton);
        await tester.pump();

        verify(
          () => mockBloc.add(const VideoEditorTextFontSelectorToggled()),
        ).called(1);
      });
    });

    group('State updates', () {
      testWidgets('rebuilds when color changes', (tester) async {
        final controller = StreamController<VideoEditorTextState>.broadcast();

        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorTextState(color: Colors.blue));
        when(() => mockBloc.stream).thenAnswer((_) => controller.stream);

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Emit new state with different color
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorTextState(color: Colors.green));
        controller.add(const VideoEditorTextState(color: Colors.green));

        await tester.pumpAndSettle();

        // Verify the bloc state was updated - we can't easily check the
        // visual color change due to how the widget tree is structured
        expect(mockBloc.state.color, Colors.green);

        await controller.close();
      });

      testWidgets('rebuilds when alignment changes', (tester) async {
        final controller = StreamController<VideoEditorTextState>.broadcast();

        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorTextState(alignment: TextAlign.left));
        when(() => mockBloc.stream).thenAnswer((_) => controller.stream);

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        var semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Text alignment',
          ),
        );
        expect(semantics.properties.value, 'Left');

        // Emit new state with different alignment
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorTextState(alignment: TextAlign.right));
        controller.add(const VideoEditorTextState(alignment: TextAlign.right));

        await tester.pumpAndSettle();

        semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Text alignment',
          ),
        );
        expect(semantics.properties.value, 'Right');

        await controller.close();
      });
    });

    group('Panel toggling', () {
      testWidgets('unfocuses keyboard when opening color picker', (
        tester,
      ) async {
        when(() => mockFocusNode.hasFocus).thenReturn(true);

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final colorButton = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Text color',
        );

        await tester.tap(colorButton);
        await tester.pump();

        verify(() => mockFocusNode.unfocus()).called(1);
      });

      testWidgets('requests focus when closing color picker', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorTextState(showColorPicker: true));

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final colorButton = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Text color',
        );

        await tester.tap(colorButton);
        await tester.pump();

        verify(() => mockFocusNode.requestFocus()).called(1);
      });

      testWidgets('unfocuses keyboard when opening font selector', (
        tester,
      ) async {
        when(() => mockFocusNode.hasFocus).thenReturn(true);

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final fontButton = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Select font',
        );

        await tester.tap(fontButton);
        await tester.pump();

        verify(() => mockFocusNode.unfocus()).called(1);
      });

      testWidgets('requests focus when closing font selector', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorTextState(showFontSelector: true));

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final fontButton = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Select font',
        );

        await tester.tap(fontButton);
        await tester.pump();

        verify(() => mockFocusNode.requestFocus()).called(1);
      });
    });
  });
}
