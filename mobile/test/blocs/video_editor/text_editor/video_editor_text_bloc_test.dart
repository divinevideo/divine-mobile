// ABOUTME: Tests for VideoEditorTextBloc - text editing, font selection, color, alignment.
// ABOUTME: Covers initial state, text events, panel toggling, and state transitions.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorTextBloc', () {
    VideoEditorTextBloc buildBloc({VideoEditorTextState? initialState}) {
      return VideoEditorTextBloc(initialState: initialState);
    }

    test('initial state has correct default values', () {
      final bloc = buildBloc();
      expect(bloc.state.text, isEmpty);
      expect(bloc.state.selectedFontIndex, 0);
      expect(bloc.state.alignment, TextAlign.center);
      expect(bloc.state.color, Colors.black);
      expect(
        bloc.state.backgroundStyle,
        LayerBackgroundMode.backgroundAndColor,
      );
      expect(bloc.state.fontSize, 0.5);
      expect(bloc.state.showFontSelector, isFalse);
      expect(bloc.state.showColorPicker, isFalse);
      bloc.close();
    });

    test('can be created with initial state', () {
      final bloc = buildBloc(
        initialState: const VideoEditorTextState(
          text: 'Hello',
          selectedFontIndex: 2,
          alignment: TextAlign.left,
          color: Colors.red,
          backgroundStyle: LayerBackgroundMode.onlyColor,
          fontSize: 0.8,
        ),
      );
      expect(bloc.state.text, 'Hello');
      expect(bloc.state.selectedFontIndex, 2);
      expect(bloc.state.alignment, TextAlign.left);
      expect(bloc.state.color, Colors.red);
      expect(bloc.state.backgroundStyle, LayerBackgroundMode.onlyColor);
      expect(bloc.state.fontSize, 0.8);
      bloc.close();
    });

    group('VideoEditorTextContentChanged', () {
      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'emits state with updated text content',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoEditorTextContentChanged('Hello World')),
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.text,
            'text',
            'Hello World',
          ),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'preserves other state values when text changes',
        build: buildBloc,
        seed: () => const VideoEditorTextState(
          selectedFontIndex: 3,
          alignment: TextAlign.right,
          color: Colors.blue,
        ),
        act: (bloc) => bloc.add(const VideoEditorTextContentChanged('Test')),
        expect: () => [
          isA<VideoEditorTextState>()
              .having((s) => s.text, 'text', 'Test')
              .having((s) => s.selectedFontIndex, 'selectedFontIndex', 3)
              .having((s) => s.alignment, 'alignment', TextAlign.right)
              .having((s) => s.color, 'color', Colors.blue),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'handles empty text',
        build: buildBloc,
        seed: () => const VideoEditorTextState(text: 'Some text'),
        act: (bloc) => bloc.add(const VideoEditorTextContentChanged('')),
        expect: () => [
          isA<VideoEditorTextState>().having((s) => s.text, 'text', isEmpty),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'handles multiline text',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoEditorTextContentChanged('Line 1\nLine 2')),
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.text,
            'text',
            'Line 1\nLine 2',
          ),
        ],
      );
    });

    group('VideoEditorTextFontSelected', () {
      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'emits state with new font index',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorTextFontSelected(5)),
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.selectedFontIndex,
            'selectedFontIndex',
            5,
          ),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'preserves other state values when font changes',
        build: buildBloc,
        seed: () => const VideoEditorTextState(
          text: 'Hello',
          color: Colors.green,
          fontSize: 0.7,
        ),
        act: (bloc) => bloc.add(const VideoEditorTextFontSelected(3)),
        expect: () => [
          isA<VideoEditorTextState>()
              .having((s) => s.selectedFontIndex, 'selectedFontIndex', 3)
              .having((s) => s.text, 'text', 'Hello')
              .having((s) => s.color, 'color', Colors.green)
              .having((s) => s.fontSize, 'fontSize', 0.7),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'can select multiple fonts in sequence',
        build: buildBloc,
        act: (bloc) {
          bloc
            ..add(const VideoEditorTextFontSelected(1))
            ..add(const VideoEditorTextFontSelected(4))
            ..add(const VideoEditorTextFontSelected(2));
        },
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.selectedFontIndex,
            'selectedFontIndex',
            1,
          ),
          isA<VideoEditorTextState>().having(
            (s) => s.selectedFontIndex,
            'selectedFontIndex',
            4,
          ),
          isA<VideoEditorTextState>().having(
            (s) => s.selectedFontIndex,
            'selectedFontIndex',
            2,
          ),
        ],
      );
    });

    group('VideoEditorTextAlignmentChanged', () {
      for (final align in [TextAlign.left, TextAlign.center, TextAlign.right]) {
        blocTest<VideoEditorTextBloc, VideoEditorTextState>(
          'emits state with ${align.name} alignment',
          build: buildBloc,
          act: (bloc) => bloc.add(VideoEditorTextAlignmentChanged(align)),
          expect: () => [
            isA<VideoEditorTextState>().having(
              (s) => s.alignment,
              'alignment',
              align,
            ),
          ],
        );
      }

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'cycles through alignments',
        build: buildBloc,
        act: (bloc) {
          bloc
            ..add(const VideoEditorTextAlignmentChanged(TextAlign.left))
            ..add(const VideoEditorTextAlignmentChanged(TextAlign.center))
            ..add(const VideoEditorTextAlignmentChanged(TextAlign.right));
        },
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.alignment,
            'alignment',
            TextAlign.left,
          ),
          isA<VideoEditorTextState>().having(
            (s) => s.alignment,
            'alignment',
            TextAlign.center,
          ),
          isA<VideoEditorTextState>().having(
            (s) => s.alignment,
            'alignment',
            TextAlign.right,
          ),
        ],
      );
    });

    group('VideoEditorTextColorSelected', () {
      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'emits state with new color',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorTextColorSelected(Colors.red)),
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.color,
            'color',
            Colors.red,
          ),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'preserves other state values when color changes',
        build: buildBloc,
        seed: () => const VideoEditorTextState(
          text: 'Test',
          selectedFontIndex: 2,
          alignment: TextAlign.left,
        ),
        act: (bloc) =>
            bloc.add(const VideoEditorTextColorSelected(Colors.purple)),
        expect: () => [
          isA<VideoEditorTextState>()
              .having((s) => s.color, 'color', Colors.purple)
              .having((s) => s.text, 'text', 'Test')
              .having((s) => s.selectedFontIndex, 'selectedFontIndex', 2)
              .having((s) => s.alignment, 'alignment', TextAlign.left),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'can select multiple colors in sequence',
        build: buildBloc,
        act: (bloc) {
          bloc
            ..add(const VideoEditorTextColorSelected(Colors.red))
            ..add(const VideoEditorTextColorSelected(Colors.green))
            ..add(const VideoEditorTextColorSelected(Colors.blue));
        },
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.color,
            'color',
            Colors.red,
          ),
          isA<VideoEditorTextState>().having(
            (s) => s.color,
            'color',
            Colors.green,
          ),
          isA<VideoEditorTextState>().having(
            (s) => s.color,
            'color',
            Colors.blue,
          ),
        ],
      );
    });

    group('VideoEditorTextBackgroundStyleChanged', () {
      for (final mode in LayerBackgroundMode.values) {
        blocTest<VideoEditorTextBloc, VideoEditorTextState>(
          'emits state with ${mode.name} background style',
          build: buildBloc,
          act: (bloc) => bloc.add(VideoEditorTextBackgroundStyleChanged(mode)),
          expect: () => [
            isA<VideoEditorTextState>().having(
              (s) => s.backgroundStyle,
              'backgroundStyle',
              mode,
            ),
          ],
        );
      }

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'cycles through background styles',
        build: buildBloc,
        act: (bloc) {
          bloc
            ..add(const VideoEditorTextBackgroundStyleChanged(.onlyColor))
            ..add(const VideoEditorTextBackgroundStyleChanged(.background))
            ..add(
              const VideoEditorTextBackgroundStyleChanged(.backgroundAndColor),
            );
        },
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.backgroundStyle,
            'backgroundStyle',
            LayerBackgroundMode.onlyColor,
          ),
          isA<VideoEditorTextState>().having(
            (s) => s.backgroundStyle,
            'backgroundStyle',
            LayerBackgroundMode.background,
          ),
          isA<VideoEditorTextState>().having(
            (s) => s.backgroundStyle,
            'backgroundStyle',
            LayerBackgroundMode.backgroundAndColor,
          ),
        ],
      );
    });

    group('VideoEditorTextFontSizeChanged', () {
      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'emits state with new font size',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorTextFontSizeChanged(0.75)),
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.fontSize,
            'fontSize',
            0.75,
          ),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'handles minimum font size',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorTextFontSizeChanged(0.0)),
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.fontSize,
            'fontSize',
            0.0,
          ),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'handles maximum font size',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorTextFontSizeChanged(1.0)),
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.fontSize,
            'fontSize',
            1.0,
          ),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'preserves other state values when font size changes',
        build: buildBloc,
        seed: () => const VideoEditorTextState(
          text: 'Big Text',
          color: Colors.orange,
          selectedFontIndex: 4,
        ),
        act: (bloc) => bloc.add(const VideoEditorTextFontSizeChanged(0.9)),
        expect: () => [
          isA<VideoEditorTextState>()
              .having((s) => s.fontSize, 'fontSize', 0.9)
              .having((s) => s.text, 'text', 'Big Text')
              .having((s) => s.color, 'color', Colors.orange)
              .having((s) => s.selectedFontIndex, 'selectedFontIndex', 4),
        ],
      );
    });

    group('VideoEditorTextReset', () {
      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'resets state to default values',
        build: buildBloc,
        seed: () => const VideoEditorTextState(
          text: 'Some text',
          selectedFontIndex: 5,
          alignment: TextAlign.right,
          color: Colors.purple,
          backgroundStyle: LayerBackgroundMode.onlyColor,
          fontSize: 0.9,
          showFontSelector: true,
          showColorPicker: true,
        ),
        act: (bloc) => bloc.add(const VideoEditorTextReset()),
        expect: () => [
          isA<VideoEditorTextState>()
              .having((s) => s.text, 'text', isEmpty)
              .having((s) => s.selectedFontIndex, 'selectedFontIndex', 0)
              .having((s) => s.alignment, 'alignment', TextAlign.center)
              .having((s) => s.color, 'color', Colors.black)
              .having(
                (s) => s.backgroundStyle,
                'backgroundStyle',
                LayerBackgroundMode.backgroundAndColor,
              )
              .having((s) => s.fontSize, 'fontSize', 0.5)
              .having((s) => s.showFontSelector, 'showFontSelector', isFalse)
              .having((s) => s.showColorPicker, 'showColorPicker', isFalse),
        ],
      );
    });

    group('VideoEditorTextFontSelectorToggled', () {
      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'opens font selector when closed',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorTextFontSelectorToggled()),
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.showFontSelector,
            'showFontSelector',
            isTrue,
          ),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'closes font selector when open',
        build: buildBloc,
        seed: () => const VideoEditorTextState(showFontSelector: true),
        act: (bloc) => bloc.add(const VideoEditorTextFontSelectorToggled()),
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.showFontSelector,
            'showFontSelector',
            isFalse,
          ),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'closes color picker when opening font selector',
        build: buildBloc,
        seed: () => const VideoEditorTextState(showColorPicker: true),
        act: (bloc) => bloc.add(const VideoEditorTextFontSelectorToggled()),
        expect: () => [
          isA<VideoEditorTextState>()
              .having((s) => s.showFontSelector, 'showFontSelector', isTrue)
              .having((s) => s.showColorPicker, 'showColorPicker', isFalse),
        ],
      );
    });

    group('VideoEditorTextColorPickerToggled', () {
      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'opens color picker when closed',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorTextColorPickerToggled()),
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.showColorPicker,
            'showColorPicker',
            isTrue,
          ),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'closes color picker when open',
        build: buildBloc,
        seed: () => const VideoEditorTextState(showColorPicker: true),
        act: (bloc) => bloc.add(const VideoEditorTextColorPickerToggled()),
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.showColorPicker,
            'showColorPicker',
            isFalse,
          ),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'closes font selector when opening color picker',
        build: buildBloc,
        seed: () => const VideoEditorTextState(showFontSelector: true),
        act: (bloc) => bloc.add(const VideoEditorTextColorPickerToggled()),
        expect: () => [
          isA<VideoEditorTextState>()
              .having((s) => s.showColorPicker, 'showColorPicker', isTrue)
              .having((s) => s.showFontSelector, 'showFontSelector', isFalse),
        ],
      );
    });

    group('VideoEditorTextClosePanels', () {
      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'closes font selector',
        build: buildBloc,
        seed: () => const VideoEditorTextState(showFontSelector: true),
        act: (bloc) => bloc.add(const VideoEditorTextClosePanels()),
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.showFontSelector,
            'showFontSelector',
            isFalse,
          ),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'closes color picker',
        build: buildBloc,
        seed: () => const VideoEditorTextState(showColorPicker: true),
        act: (bloc) => bloc.add(const VideoEditorTextClosePanels()),
        expect: () => [
          isA<VideoEditorTextState>().having(
            (s) => s.showColorPicker,
            'showColorPicker',
            isFalse,
          ),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'closes both panels when both are open',
        build: buildBloc,
        seed: () => const VideoEditorTextState(
          showFontSelector: true,
          showColorPicker: true,
        ),
        act: (bloc) => bloc.add(const VideoEditorTextClosePanels()),
        expect: () => [
          isA<VideoEditorTextState>()
              .having((s) => s.showFontSelector, 'showFontSelector', isFalse)
              .having((s) => s.showColorPicker, 'showColorPicker', isFalse),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'emits unchanged state when both panels already closed',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorTextClosePanels()),
        expect: () => [
          // Emits state with both panels false (unchanged from default)
          isA<VideoEditorTextState>()
              .having((s) => s.showFontSelector, 'showFontSelector', isFalse)
              .having((s) => s.showColorPicker, 'showColorPicker', isFalse),
        ],
      );
    });

    group('VideoEditorTextInitFromLayer', () {
      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'initializes state from layer data',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoEditorTextInitFromLayer(
            text: 'Existing Text',
            alignment: TextAlign.left,
            color: Colors.blue,
            backgroundStyle: LayerBackgroundMode.onlyColor,
            fontSize: 0.8,
            selectedFontIndex: 3,
          ),
        ),
        expect: () => [
          isA<VideoEditorTextState>()
              .having((s) => s.text, 'text', 'Existing Text')
              .having((s) => s.alignment, 'alignment', TextAlign.left)
              .having((s) => s.color, 'color', Colors.blue)
              .having(
                (s) => s.backgroundStyle,
                'backgroundStyle',
                LayerBackgroundMode.onlyColor,
              )
              .having((s) => s.fontSize, 'fontSize', 0.8)
              .having((s) => s.selectedFontIndex, 'selectedFontIndex', 3),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'resets panel visibility when initializing from layer',
        build: buildBloc,
        seed: () => const VideoEditorTextState(
          showFontSelector: true,
          showColorPicker: true,
        ),
        act: (bloc) => bloc.add(
          const VideoEditorTextInitFromLayer(
            text: 'Layer Text',
            alignment: TextAlign.center,
            color: Colors.white,
            backgroundStyle: LayerBackgroundMode.backgroundAndColor,
            fontSize: 0.5,
            selectedFontIndex: 0,
          ),
        ),
        expect: () => [
          isA<VideoEditorTextState>()
              .having((s) => s.showFontSelector, 'showFontSelector', isFalse)
              .having((s) => s.showColorPicker, 'showColorPicker', isFalse),
        ],
      );
    });

    group('complex interactions', () {
      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'handles multiple events in sequence',
        build: buildBloc,
        act: (bloc) {
          bloc
            ..add(const VideoEditorTextContentChanged('Hello'))
            ..add(const VideoEditorTextFontSelected(2))
            ..add(const VideoEditorTextColorSelected(Colors.red))
            ..add(const VideoEditorTextAlignmentChanged(TextAlign.right));
        },
        expect: () => [
          isA<VideoEditorTextState>().having((s) => s.text, 'text', 'Hello'),
          isA<VideoEditorTextState>()
              .having((s) => s.text, 'text', 'Hello')
              .having((s) => s.selectedFontIndex, 'selectedFontIndex', 2),
          isA<VideoEditorTextState>()
              .having((s) => s.text, 'text', 'Hello')
              .having((s) => s.selectedFontIndex, 'selectedFontIndex', 2)
              .having((s) => s.color, 'color', Colors.red),
          isA<VideoEditorTextState>()
              .having((s) => s.text, 'text', 'Hello')
              .having((s) => s.selectedFontIndex, 'selectedFontIndex', 2)
              .having((s) => s.color, 'color', Colors.red)
              .having((s) => s.alignment, 'alignment', TextAlign.right),
        ],
      );

      blocTest<VideoEditorTextBloc, VideoEditorTextState>(
        'panel toggling is mutually exclusive',
        build: buildBloc,
        act: (bloc) {
          bloc
            ..add(const VideoEditorTextFontSelectorToggled())
            ..add(const VideoEditorTextColorPickerToggled())
            ..add(const VideoEditorTextFontSelectorToggled());
        },
        expect: () => [
          // First: open font selector
          isA<VideoEditorTextState>()
              .having((s) => s.showFontSelector, 'showFontSelector', isTrue)
              .having((s) => s.showColorPicker, 'showColorPicker', isFalse),
          // Second: close font selector, open color picker
          isA<VideoEditorTextState>()
              .having((s) => s.showFontSelector, 'showFontSelector', isFalse)
              .having((s) => s.showColorPicker, 'showColorPicker', isTrue),
          // Third: close color picker, open font selector
          isA<VideoEditorTextState>()
              .having((s) => s.showFontSelector, 'showFontSelector', isTrue)
              .having((s) => s.showColorPicker, 'showColorPicker', isFalse),
        ],
      );
    });
  });

  group('VideoEditorTextState', () {
    test('supports value equality', () {
      const state1 = VideoEditorTextState();
      const state2 = VideoEditorTextState();
      expect(state1, equals(state2));
    });

    test('different text values are not equal', () {
      const state1 = VideoEditorTextState(text: 'Hello');
      const state2 = VideoEditorTextState(text: 'World');
      expect(state1, isNot(equals(state2)));
    });

    test('different font index values are not equal', () {
      const state1 = VideoEditorTextState();
      const state2 = VideoEditorTextState(selectedFontIndex: 1);
      expect(state1, isNot(equals(state2)));
    });

    test('different alignment values are not equal', () {
      const state1 = VideoEditorTextState(alignment: TextAlign.left);
      const state2 = VideoEditorTextState(alignment: TextAlign.right);
      expect(state1, isNot(equals(state2)));
    });

    test('different color values are not equal', () {
      const state1 = VideoEditorTextState(color: Colors.red);
      const state2 = VideoEditorTextState(color: Colors.blue);
      expect(state1, isNot(equals(state2)));
    });

    test('different background style values are not equal', () {
      const state1 = VideoEditorTextState(
        backgroundStyle: LayerBackgroundMode.onlyColor,
      );
      const state2 = VideoEditorTextState(
        backgroundStyle: LayerBackgroundMode.background,
      );
      expect(state1, isNot(equals(state2)));
    });

    test('different font size values are not equal', () {
      const state1 = VideoEditorTextState(fontSize: 0.3);
      const state2 = VideoEditorTextState(fontSize: 0.7);
      expect(state1, isNot(equals(state2)));
    });

    test('different showFontSelector values are not equal', () {
      const state1 = VideoEditorTextState(showFontSelector: true);
      const state2 = VideoEditorTextState();
      expect(state1, isNot(equals(state2)));
    });

    test('different showColorPicker values are not equal', () {
      const state1 = VideoEditorTextState(showColorPicker: true);
      const state2 = VideoEditorTextState();
      expect(state1, isNot(equals(state2)));
    });

    test('copyWith creates a copy with updated values', () {
      const original = VideoEditorTextState(text: 'Original');
      final copied = original.copyWith(text: 'Copied');

      expect(copied.text, 'Copied');
      expect(original.text, 'Original');
    });

    test('copyWith preserves values when not specified', () {
      const original = VideoEditorTextState(
        text: 'Test',
        selectedFontIndex: 3,
        alignment: TextAlign.left,
        color: Colors.red,
        backgroundStyle: LayerBackgroundMode.onlyColor,
        fontSize: 0.8,
        showFontSelector: true,
        showColorPicker: true,
      );

      final copied = original.copyWith();

      expect(copied.text, original.text);
      expect(copied.selectedFontIndex, original.selectedFontIndex);
      expect(copied.alignment, original.alignment);
      expect(copied.color, original.color);
      expect(copied.backgroundStyle, original.backgroundStyle);
      expect(copied.fontSize, original.fontSize);
      expect(copied.showFontSelector, original.showFontSelector);
      expect(copied.showColorPicker, original.showColorPicker);
    });
  });

  group('VideoEditorTextEvent', () {
    test('VideoEditorTextContentChanged supports value equality', () {
      const event1 = VideoEditorTextContentChanged('Hello');
      const event2 = VideoEditorTextContentChanged('Hello');
      const event3 = VideoEditorTextContentChanged('World');

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });

    test('VideoEditorTextFontSelected supports value equality', () {
      const event1 = VideoEditorTextFontSelected(1);
      const event2 = VideoEditorTextFontSelected(1);
      const event3 = VideoEditorTextFontSelected(2);

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });

    test('VideoEditorTextAlignmentChanged supports value equality', () {
      const event1 = VideoEditorTextAlignmentChanged(TextAlign.left);
      const event2 = VideoEditorTextAlignmentChanged(TextAlign.left);
      const event3 = VideoEditorTextAlignmentChanged(TextAlign.right);

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });

    test('VideoEditorTextColorSelected supports value equality', () {
      const event1 = VideoEditorTextColorSelected(Colors.red);
      const event2 = VideoEditorTextColorSelected(Colors.red);
      const event3 = VideoEditorTextColorSelected(Colors.blue);

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });

    test('VideoEditorTextBackgroundStyleChanged supports value equality', () {
      const event1 = VideoEditorTextBackgroundStyleChanged(
        LayerBackgroundMode.onlyColor,
      );
      const event2 = VideoEditorTextBackgroundStyleChanged(
        LayerBackgroundMode.onlyColor,
      );
      const event3 = VideoEditorTextBackgroundStyleChanged(
        LayerBackgroundMode.background,
      );

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });

    test('VideoEditorTextFontSizeChanged supports value equality', () {
      const event1 = VideoEditorTextFontSizeChanged(0.5);
      const event2 = VideoEditorTextFontSizeChanged(0.5);
      const event3 = VideoEditorTextFontSizeChanged(0.8);

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });

    test('VideoEditorTextInitFromLayer supports value equality', () {
      const event1 = VideoEditorTextInitFromLayer(
        text: 'Test',
        alignment: TextAlign.center,
        color: Colors.black,
        backgroundStyle: LayerBackgroundMode.backgroundAndColor,
        fontSize: 0.5,
        selectedFontIndex: 0,
      );
      const event2 = VideoEditorTextInitFromLayer(
        text: 'Test',
        alignment: TextAlign.center,
        color: Colors.black,
        backgroundStyle: LayerBackgroundMode.backgroundAndColor,
        fontSize: 0.5,
        selectedFontIndex: 0,
      );
      const event3 = VideoEditorTextInitFromLayer(
        text: 'Different',
        alignment: TextAlign.center,
        color: Colors.black,
        backgroundStyle: LayerBackgroundMode.backgroundAndColor,
        fontSize: 0.5,
        selectedFontIndex: 0,
      );

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });
  });
}
