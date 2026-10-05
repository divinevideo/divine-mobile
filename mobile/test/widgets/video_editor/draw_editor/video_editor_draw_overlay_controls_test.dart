// ABOUTME: Tests for VideoEditorDrawOverlayControls widget.
// ABOUTME: Validates top bar buttons (Close, Undo, Redo, Done) and their state.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
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

    Widget buildWidget() {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
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
            onOpenMusicLibrary: () {},
            onOpenVoiceOver: () {},
            onOpenCaptions: () {},
            onOpenEffects: () {},
            onAddEditTextLayer: ([layer]) async => null,
            child: BlocProvider<VideoEditorDrawBloc>.value(
              value: mockBloc,
              child: const SizedBox(
                width: 400,
                height: 600,
                child: VideoEditorDrawOverlayControls(),
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

    group('Strength slider', () {
      testWidgets('is hidden while drawing', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(VideoEditorVerticalSlider), findsNothing);
      });

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
