// ABOUTME: Tests for VideoEditorDrawItemIndicator widget.
// ABOUTME: Validates indicator position based on selected tool.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_item_indicator.dart';

class MockVideoEditorDrawBloc
    extends MockBloc<VideoEditorDrawEvent, VideoEditorDrawState>
    implements VideoEditorDrawBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorDrawItemIndicator', () {
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
          body: BlocProvider<VideoEditorDrawBloc>.value(
            value: mockBloc,
            child: const SizedBox(
              width: 400,
              height: 100,
              child: VideoEditorDrawItemIndicator(),
            ),
          ),
        ),
      );
    }

    testWidgets('renders AnimatedSlide widget', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.byType(AnimatedSlide), findsOneWidget);
    });

    testWidgets('renders indicator container', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      // The indicator is a Container inside AnimatedSlide
      expect(
        find.descendant(
          of: find.byType(AnimatedSlide),
          matching: find.byType(Container),
        ),
        findsOneWidget,
      );
    });

    group('Position based on tool', () {
      for (final (index, tool) in DrawToolType.drawingTools.indexed) {
        testWidgets('offset is $index when ${tool.name} is selected', (
          tester,
        ) async {
          when(
            () => mockBloc.state,
          ).thenReturn(VideoEditorDrawState(selectedTool: tool));

          await tester.pumpWidget(buildWidget());
          await tester.pump();

          final slide = tester.widget<AnimatedSlide>(
            find.byType(AnimatedSlide),
          );
          expect(slide.offset, Offset(index.toDouble(), 0));
        });
      }

      testWidgets('offset is 0 when a hide tool is selected', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const VideoEditorDrawState(selectedTool: DrawToolType.blur),
        );

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
        expect(slide.offset, Offset.zero);
      });
    });

    group('State updates', () {
      testWidgets('updates position when tool changes', (tester) async {
        final controller = StreamController<VideoEditorDrawState>.broadcast();

        when(() => mockBloc.state).thenReturn(const VideoEditorDrawState());
        when(() => mockBloc.stream).thenAnswer((_) => controller.stream);

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Initial state - pencil selected
        var slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
        expect(slide.offset, Offset.zero);

        // Update state to eraser
        when(() => mockBloc.state).thenReturn(
          const VideoEditorDrawState(selectedTool: DrawToolType.eraser),
        );
        controller.add(
          const VideoEditorDrawState(selectedTool: DrawToolType.eraser),
        );
        await tester.pumpAndSettle();

        slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
        expect(
          slide.offset,
          Offset(DrawToolType.drawingTools.indexOf(.eraser).toDouble(), 0),
        );

        await controller.close();
      });
    });
  });
}
