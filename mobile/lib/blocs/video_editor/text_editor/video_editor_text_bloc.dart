import 'package:divine_ui/divine_ui.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_extensions.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:unified_logger/unified_logger.dart';

part 'video_editor_text_event.dart';
part 'video_editor_text_state.dart';

/// BLoC for managing the video editor text overlay state.
class VideoEditorTextBloc
    extends Bloc<VideoEditorTextEvent, VideoEditorTextState> {
  /// Creates a [VideoEditorTextBloc].
  ///
  /// [initialState] can be provided to pre-populate the state when editing
  /// an existing text layer.
  VideoEditorTextBloc({VideoEditorTextState? initialState})
    : super(initialState ?? const VideoEditorTextState()) {
    on<VideoEditorTextContentChanged>(_onContentChanged);
    on<VideoEditorTextFontSelected>(_onFontSelected);
    on<VideoEditorTextAlignmentChanged>(_onAlignmentChanged);
    on<VideoEditorTextColorSelected>(_onColorSelected);
    on<VideoEditorTextBackgroundStyleChanged>(_onBackgroundStyleChanged);
    on<VideoEditorTextFontSizeChanged>(_onFontSizeChanged);
    on<VideoEditorTextReset>(_onReset);
    on<VideoEditorTextFontSelectorToggled>(_onFontSelectorToggled);
    on<VideoEditorTextColorPickerToggled>(_onColorPickerToggled);
    on<VideoEditorTextClosePanels>(_onClosePanels);
    on<VideoEditorTextInitFromLayer>(_onInitFromLayer);
  }

  /// Updates the text content.
  void _onContentChanged(
    VideoEditorTextContentChanged event,
    Emitter<VideoEditorTextState> emit,
  ) {
    emit(state.copyWith(text: event.text));
  }

  /// Updates the selected font.
  void _onFontSelected(
    VideoEditorTextFontSelected event,
    Emitter<VideoEditorTextState> emit,
  ) {
    Log.debug(
      '✏️ Text font selected: index ${event.fontIndex}',
      name: 'VideoEditorTextBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(selectedFontIndex: event.fontIndex));
  }

  /// Updates the text alignment.
  void _onAlignmentChanged(
    VideoEditorTextAlignmentChanged event,
    Emitter<VideoEditorTextState> emit,
  ) {
    Log.debug(
      '✏️ Text alignment changed: ${event.alignment}',
      name: 'VideoEditorTextBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(alignment: event.alignment));
  }

  /// Updates the text color.
  void _onColorSelected(
    VideoEditorTextColorSelected event,
    Emitter<VideoEditorTextState> emit,
  ) {
    Log.debug(
      '🎨 Text color selected: #${event.color.toARGB32().toRadixString(16).padLeft(8, '0')}',
      name: 'VideoEditorTextBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(color: event.color));
  }

  /// Updates the background style.
  void _onBackgroundStyleChanged(
    VideoEditorTextBackgroundStyleChanged event,
    Emitter<VideoEditorTextState> emit,
  ) {
    emit(state.copyWith(backgroundStyle: event.backgroundStyle));
  }

  /// Updates the font size.
  void _onFontSizeChanged(
    VideoEditorTextFontSizeChanged event,
    Emitter<VideoEditorTextState> emit,
  ) {
    emit(state.copyWith(fontSize: event.fontSize));
  }

  /// Resets the text editor state.
  void _onReset(
    VideoEditorTextReset event,
    Emitter<VideoEditorTextState> emit,
  ) {
    emit(const VideoEditorTextState());
  }

  /// Toggles the font selector visibility.
  void _onFontSelectorToggled(
    VideoEditorTextFontSelectorToggled event,
    Emitter<VideoEditorTextState> emit,
  ) {
    emit(
      state.copyWith(
        showFontSelector: !state.showFontSelector,
        showColorPicker: false, // Close color picker when opening font selector
      ),
    );
  }

  /// Toggles the color picker visibility.
  void _onColorPickerToggled(
    VideoEditorTextColorPickerToggled event,
    Emitter<VideoEditorTextState> emit,
  ) {
    emit(
      state.copyWith(
        showColorPicker: !state.showColorPicker,
        showFontSelector:
            false, // Close font selector when opening color picker
      ),
    );
  }

  /// Closes all open panels (font selector, color picker).
  void _onClosePanels(
    VideoEditorTextClosePanels event,
    Emitter<VideoEditorTextState> emit,
  ) {
    emit(
      state.copyWith(
        fontSize: 0.5,
        showFontSelector: false,
        showColorPicker: false,
      ),
    );
  }

  /// Initializes state from an existing text layer.
  void _onInitFromLayer(
    VideoEditorTextInitFromLayer event,
    Emitter<VideoEditorTextState> emit,
  ) {
    Log.debug(
      '✏️ Text initialized from layer: "${event.text}"',
      name: 'VideoEditorTextBloc',
      category: LogCategory.video,
    );
    emit(
      VideoEditorTextState(
        text: event.text,
        alignment: event.alignment,
        color: event.color,
        backgroundStyle: event.backgroundStyle,
        fontSize: event.fontSize,
        selectedFontIndex: event.selectedFontIndex,
      ),
    );
  }
}
