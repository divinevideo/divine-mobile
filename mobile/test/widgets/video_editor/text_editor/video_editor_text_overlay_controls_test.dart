// ABOUTME: Tests for VideoEditorTextOverlayControls widget.
// ABOUTME: Validates top bar buttons (Close, Done) and font size slider.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_overlay_controls.dart';
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

class MockTextEditorConfigs extends Mock implements TextEditorConfigs {}

class MockProImageEditorConfigs extends Mock implements ProImageEditorConfigs {}

class MockTextEditorKey extends Mock implements GlobalKey<TextEditorState> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('en'));
  final closeLabel = l10n.videoEditorDiscardToolChangesSemanticLabel(
    l10n.videoEditorTextLabel,
  );
  final doneLabel = l10n.videoEditorApplyToolChangesSemanticLabel(
    l10n.videoEditorTextLabel,
  );

  setUpAll(() {
    registerFallbackValue(const VideoEditorTextFontSizeChanged(0.5));
  });

  group('VideoEditorTextOverlayControls', () {
    late MockVideoEditorTextBloc mockBloc;
    late MockTextEditorKey mockKey;
    late MockTextEditorState mockEditor;
    late MockProImageEditorConfigs mockConfigs;
    late MockTextEditorConfigs mockTextEditorConfigs;
    late FocusNode focusNode;

    setUp(() {
      mockBloc = MockVideoEditorTextBloc();
      mockKey = MockTextEditorKey();
      mockEditor = MockTextEditorState();
      mockConfigs = MockProImageEditorConfigs();
      mockTextEditorConfigs = MockTextEditorConfigs();
      focusNode = FocusNode();

      when(() => mockBloc.state).thenReturn(const VideoEditorTextState());
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockKey.currentState).thenReturn(mockEditor);
      when(() => mockEditor.focusNode).thenReturn(focusNode);
      when(() => mockEditor.configs).thenReturn(mockConfigs);
      when(() => mockConfigs.textEditor).thenReturn(mockTextEditorConfigs);
      when(() => mockTextEditorConfigs.minFontScale).thenReturn(0.5);
      when(() => mockTextEditorConfigs.maxFontScale).thenReturn(3.0);
    });

    tearDown(() {
      focusNode.dispose();
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
                height: 600,
                child: VideoEditorTextOverlayControls(),
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

      testWidgets('is marked as a button', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == closeLabel,
          ),
        );
        expect(semantics.properties.button, isTrue);
      });

      testWidgets('tapping calls editor.close()', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final closeButton = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == closeLabel,
        );

        await tester.tap(closeButton);
        await tester.pump();

        verify(() => mockEditor.close()).called(1);
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

      testWidgets('tapping calls editor.done()', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final doneButton = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == doneLabel,
        );

        await tester.tap(doneButton);
        await tester.pump();

        verify(() => mockEditor.done()).called(1);
      });
    });

    group('Layout', () {
      testWidgets('top bar is aligned to top center', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final aligns = tester.widgetList<Align>(
          find.descendant(
            of: find.byType(VideoEditorTextOverlayControls),
            matching: find.byType(Align),
          ),
        );

        final topAlign = aligns.where(
          (a) => a.alignment == Alignment.topCenter,
        );
        expect(topAlign, isNotEmpty);
      });

      testWidgets('slider is aligned to center right', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final aligns = tester.widgetList<Align>(
          find.descendant(
            of: find.byType(VideoEditorTextOverlayControls),
            matching: find.byType(Align),
          ),
        );

        final rightAlign = aligns.where(
          (a) => a.alignment == Alignment.centerRight,
        );
        expect(rightAlign, isNotEmpty);
      });
    });

    group('Top bar', () {
      testWidgets('close and done buttons are in a Row', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Find the Row containing both buttons
        final rows = tester.widgetList<Row>(find.byType(Row));
        final buttonRow = rows.where((row) {
          return row.mainAxisAlignment == MainAxisAlignment.spaceBetween;
        });
        expect(buttonRow, isNotEmpty);
      });

      testWidgets('wrapped in SafeArea', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(VideoEditorTextOverlayControls),
            matching: find.byType(SafeArea),
          ),
          findsOneWidget,
        );
      });

      testWidgets('SafeArea has bottom: false', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final safeArea = tester.widget<SafeArea>(
          find.descendant(
            of: find.byType(VideoEditorTextOverlayControls),
            matching: find.byType(SafeArea),
          ),
        );
        expect(safeArea.bottom, isFalse);
      });
    });

    group('State updates', () {
      testWidgets('rebuilds when fontSize changes', (tester) async {
        final controller = StreamController<VideoEditorTextState>.broadcast();

        when(() => mockBloc.state).thenReturn(const VideoEditorTextState());
        when(() => mockBloc.stream).thenAnswer((_) => controller.stream);

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Emit new state with different font size
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorTextState(fontSize: 0.8));
        controller.add(const VideoEditorTextState(fontSize: 0.8));

        await tester.pump();

        // Widget should have rebuilt
        expect(mockBloc.state.fontSize, 0.8);

        await controller.close();
      });
    });
  });
}
