// ABOUTME: Tests for VideoEditorDrawBloc - tool selection, color selection, capabilities.
// ABOUTME: Covers initial state, draw events, and state transitions.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorDrawBloc', () {
    VideoEditorDrawBloc buildBloc() {
      return VideoEditorDrawBloc();
    }

    test('initial state has correct default values', () {
      final bloc = buildBloc();
      expect(bloc.state.canUndo, isFalse);
      expect(bloc.state.canRedo, isFalse);
      expect(bloc.state.selectedTool, DrawToolType.pencil);
      expect(bloc.state.strokeWidth, 8.0);
      expect(bloc.state.opacity, 1.0);
      expect(bloc.state.selectedColor, VideoEditorConstants.primaryColor);
      expect(bloc.state.mode, PaintMode.freeStyle);
      bloc.close();
    });

    group('VideoEditorDrawCapabilitiesChanged', () {
      blocTest<VideoEditorDrawBloc, VideoEditorDrawState>(
        'emits state with updated canUndo and canRedo',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoEditorDrawCapabilitiesChanged(
            canUndo: true,
            canRedo: false,
          ),
        ),
        expect: () => [
          isA<VideoEditorDrawState>()
              .having((s) => s.canUndo, 'canUndo', isTrue)
              .having((s) => s.canRedo, 'canRedo', isFalse),
        ],
      );

      blocTest<VideoEditorDrawBloc, VideoEditorDrawState>(
        'updates both canUndo and canRedo to true',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoEditorDrawCapabilitiesChanged(
            canUndo: true,
            canRedo: true,
          ),
        ),
        expect: () => [
          isA<VideoEditorDrawState>()
              .having((s) => s.canUndo, 'canUndo', isTrue)
              .having((s) => s.canRedo, 'canRedo', isTrue),
        ],
      );
    });

    group('VideoEditorDrawColorSelected', () {
      blocTest<VideoEditorDrawBloc, VideoEditorDrawState>(
        'emits state with new color when color is selected',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorDrawColorSelected(Colors.red)),
        expect: () => [
          isA<VideoEditorDrawState>().having(
            (s) => s.selectedColor,
            'selectedColor',
            Colors.red,
          ),
        ],
      );

      blocTest<VideoEditorDrawBloc, VideoEditorDrawState>(
        'updates color while preserving other state values',
        build: buildBloc,
        seed: () => const VideoEditorDrawState(
          selectedTool: DrawToolType.marker,
          strokeWidth: 12.0,
          opacity: 0.7,
        ),
        act: (bloc) =>
            bloc.add(const VideoEditorDrawColorSelected(Colors.blue)),
        expect: () => [
          isA<VideoEditorDrawState>()
              .having((s) => s.selectedColor, 'selectedColor', Colors.blue)
              .having(
                (s) => s.selectedTool,
                'selectedTool',
                DrawToolType.marker,
              )
              .having((s) => s.strokeWidth, 'strokeWidth', 12.0)
              .having((s) => s.opacity, 'opacity', 0.7),
        ],
      );

      blocTest<VideoEditorDrawBloc, VideoEditorDrawState>(
        'can select multiple colors in sequence',
        build: buildBloc,
        act: (bloc) {
          bloc
            ..add(const VideoEditorDrawColorSelected(Colors.red))
            ..add(const VideoEditorDrawColorSelected(Colors.green))
            ..add(const VideoEditorDrawColorSelected(Colors.blue));
        },
        expect: () => [
          isA<VideoEditorDrawState>().having(
            (s) => s.selectedColor,
            'selectedColor',
            Colors.red,
          ),
          isA<VideoEditorDrawState>().having(
            (s) => s.selectedColor,
            'selectedColor',
            Colors.green,
          ),
          isA<VideoEditorDrawState>().having(
            (s) => s.selectedColor,
            'selectedColor',
            Colors.blue,
          ),
        ],
      );
    });
  });

  group('VideoEditorDrawState', () {
    test('supports value equality', () {
      const state1 = VideoEditorDrawState();
      const state2 = VideoEditorDrawState();
      expect(state1, equals(state2));
    });

    test('different canUndo values are not equal', () {
      const state1 = VideoEditorDrawState(canUndo: true);
      const state2 = VideoEditorDrawState();
      expect(state1, isNot(equals(state2)));
    });

    test('different canRedo values are not equal', () {
      const state1 = VideoEditorDrawState(canRedo: true);
      const state2 = VideoEditorDrawState();
      expect(state1, isNot(equals(state2)));
    });

    test('different selectedTool values are not equal', () {
      const state1 = VideoEditorDrawState();
      const state2 = VideoEditorDrawState(selectedTool: DrawToolType.marker);
      expect(state1, isNot(equals(state2)));
    });

    test('different strokeWidth values are not equal', () {
      const state1 = VideoEditorDrawState(strokeWidth: 6.0);
      const state2 = VideoEditorDrawState(strokeWidth: 12.0);
      expect(state1, isNot(equals(state2)));
    });

    test('different opacity values are not equal', () {
      const state1 = VideoEditorDrawState();
      const state2 = VideoEditorDrawState(opacity: 0.7);
      expect(state1, isNot(equals(state2)));
    });

    test('different selectedColor values are not equal', () {
      const state1 = VideoEditorDrawState(selectedColor: Colors.red);
      const state2 = VideoEditorDrawState(selectedColor: Colors.blue);
      expect(state1, isNot(equals(state2)));
    });

    test('different mode values are not equal', () {
      const state1 = VideoEditorDrawState();
      const state2 = VideoEditorDrawState(mode: PaintMode.arrow);
      expect(state1, isNot(equals(state2)));
    });

    test(
      'copyWith creates copy with same values when no arguments provided',
      () {
        const original = VideoEditorDrawState(
          canUndo: true,
          canRedo: true,
          selectedTool: DrawToolType.marker,
          strokeWidth: 12.0,
          opacity: 0.7,
          selectedColor: Colors.red,
          mode: PaintMode.arrow,
        );
        final copy = original.copyWith();
        expect(copy, equals(original));
      },
    );

    test('copyWith updates canUndo', () {
      const original = VideoEditorDrawState();
      final copy = original.copyWith(canUndo: true);
      expect(copy.canUndo, isTrue);
      expect(original.canUndo, isFalse);
    });

    test('copyWith updates canRedo', () {
      const original = VideoEditorDrawState();
      final copy = original.copyWith(canRedo: true);
      expect(copy.canRedo, isTrue);
      expect(original.canRedo, isFalse);
    });

    test('copyWith updates selectedTool', () {
      const original = VideoEditorDrawState();
      final copy = original.copyWith(selectedTool: DrawToolType.eraser);
      expect(copy.selectedTool, DrawToolType.eraser);
      expect(original.selectedTool, DrawToolType.pencil);
    });

    test('copyWith updates strokeWidth', () {
      const original = VideoEditorDrawState();
      final copy = original.copyWith(strokeWidth: 16.0);
      expect(copy.strokeWidth, 16.0);
      expect(original.strokeWidth, 8.0);
    });

    test('copyWith updates opacity', () {
      const original = VideoEditorDrawState();
      final copy = original.copyWith(opacity: 0.5);
      expect(copy.opacity, 0.5);
      expect(original.opacity, 1.0);
    });

    test('copyWith updates selectedColor', () {
      const original = VideoEditorDrawState(selectedColor: Colors.white);
      final copy = original.copyWith(selectedColor: Colors.black);
      expect(copy.selectedColor, Colors.black);
      expect(original.selectedColor, Colors.white);
    });

    test('copyWith updates mode', () {
      const original = VideoEditorDrawState();
      final copy = original.copyWith(mode: PaintMode.eraser);
      expect(copy.mode, PaintMode.eraser);
      expect(original.mode, PaintMode.freeStyle);
    });

    test('copyWith can update multiple values at once', () {
      const original = VideoEditorDrawState();
      final copy = original.copyWith(
        canUndo: true,
        canRedo: true,
        selectedTool: DrawToolType.arrow,
        strokeWidth: 10.0,
        opacity: 0.8,
        selectedColor: Colors.green,
        mode: PaintMode.arrow,
      );
      expect(copy.canUndo, isTrue);
      expect(copy.canRedo, isTrue);
      expect(copy.selectedTool, DrawToolType.arrow);
      expect(copy.strokeWidth, 10.0);
      expect(copy.opacity, 0.8);
      expect(copy.selectedColor, Colors.green);
      expect(copy.mode, PaintMode.arrow);
    });

    test('props contains all properties', () {
      const state = VideoEditorDrawState(
        canUndo: true,
        canRedo: true,
        selectedTool: DrawToolType.marker,
        strokeWidth: 12.0,
        opacity: 0.7,
        selectedColor: Colors.red,
        mode: PaintMode.arrow,
      );
      expect(state.props, [
        true, // canUndo
        true, // canRedo
        DrawToolType.marker,
        12.0, // strokeWidth
        0.7, // opacity
        Colors.red,
        PaintMode.arrow,
      ]);
    });
  });

  group('VideoEditorDrawEvent', () {
    test('VideoEditorDrawCapabilitiesChanged supports value equality', () {
      const event1 = VideoEditorDrawCapabilitiesChanged(
        canUndo: true,
        canRedo: false,
      );
      const event2 = VideoEditorDrawCapabilitiesChanged(
        canUndo: true,
        canRedo: false,
      );
      expect(event1, equals(event2));
    });

    test(
      'VideoEditorDrawCapabilitiesChanged is not equal with different values',
      () {
        const event1 = VideoEditorDrawCapabilitiesChanged(
          canUndo: true,
          canRedo: false,
        );
        const event2 = VideoEditorDrawCapabilitiesChanged(
          canUndo: false,
          canRedo: true,
        );
        expect(event1, isNot(equals(event2)));
      },
    );

    test('VideoEditorDrawCapabilitiesChanged props contains values', () {
      const event = VideoEditorDrawCapabilitiesChanged(
        canUndo: true,
        canRedo: false,
      );
      expect(event.props, [true, false]);
    });

    test(
      'VideoEditorDrawToolSelected supports value equality with same tool',
      () {
        const event1 = VideoEditorDrawToolSelected(DrawToolType.pencil);
        const event2 = VideoEditorDrawToolSelected(DrawToolType.pencil);
        expect(event1, equals(event2));
      },
    );

    test('VideoEditorDrawToolSelected is not equal with different tool', () {
      const event1 = VideoEditorDrawToolSelected(DrawToolType.pencil);
      const event2 = VideoEditorDrawToolSelected(DrawToolType.marker);
      expect(event1, isNot(equals(event2)));
    });

    test('VideoEditorDrawToolSelected props contains tool', () {
      const event = VideoEditorDrawToolSelected(DrawToolType.arrow);
      expect(event.props, [DrawToolType.arrow]);
    });

    test(
      'VideoEditorDrawColorSelected supports value equality with same color',
      () {
        const event1 = VideoEditorDrawColorSelected(Colors.red);
        const event2 = VideoEditorDrawColorSelected(Colors.red);
        expect(event1, equals(event2));
      },
    );

    test('VideoEditorDrawColorSelected is not equal with different color', () {
      const event1 = VideoEditorDrawColorSelected(Colors.red);
      const event2 = VideoEditorDrawColorSelected(Colors.blue);
      expect(event1, isNot(equals(event2)));
    });

    test('VideoEditorDrawColorSelected props contains color', () {
      const event = VideoEditorDrawColorSelected(Colors.green);
      expect(event.props, [Colors.green]);
    });
  });
}
