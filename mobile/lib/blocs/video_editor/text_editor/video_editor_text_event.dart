part of 'video_editor_text_bloc.dart';

/// Base class for all video editor text events.
sealed class VideoEditorTextEvent extends Equatable {
  const VideoEditorTextEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the text content changes.
class VideoEditorTextContentChanged extends VideoEditorTextEvent {
  const VideoEditorTextContentChanged(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// Triggered when a font is selected.
class VideoEditorTextFontSelected extends VideoEditorTextEvent {
  const VideoEditorTextFontSelected(this.fontIndex);

  final int fontIndex;

  @override
  List<Object?> get props => [fontIndex];
}

/// Triggered when text alignment changes.
class VideoEditorTextAlignmentChanged extends VideoEditorTextEvent {
  const VideoEditorTextAlignmentChanged(this.alignment);

  final TextAlign alignment;

  @override
  List<Object?> get props => [alignment];
}

/// Triggered when a text color is selected.
class VideoEditorTextColorSelected extends VideoEditorTextEvent {
  const VideoEditorTextColorSelected(this.color);

  final Color color;

  @override
  List<Object?> get props => [color];
}

/// Triggered when background style changes.
class VideoEditorTextBackgroundStyleChanged extends VideoEditorTextEvent {
  const VideoEditorTextBackgroundStyleChanged(this.backgroundStyle);

  final LayerBackgroundMode backgroundStyle;

  @override
  List<Object?> get props => [backgroundStyle];
}

/// Triggered when the text editor opens for a new layer to reset state.
class VideoEditorTextReset extends VideoEditorTextEvent {
  const VideoEditorTextReset();
}

/// Triggered when the font selector visibility is toggled.
class VideoEditorTextFontSelectorToggled extends VideoEditorTextEvent {
  const VideoEditorTextFontSelectorToggled();
}

/// Triggered when the color picker visibility is toggled.
class VideoEditorTextColorPickerToggled extends VideoEditorTextEvent {
  const VideoEditorTextColorPickerToggled();
}

/// Triggered when the outline or shadow changes.
class VideoEditorTextEffectsChanged extends VideoEditorTextEvent {
  const VideoEditorTextEffectsChanged(this.effects);

  /// The new outline and shadow.
  final TextEffects effects;

  @override
  List<Object?> get props => [effects];
}

/// Triggered when the outline and shadow panel visibility is toggled.
class VideoEditorTextEffectsPanelToggled extends VideoEditorTextEvent {
  const VideoEditorTextEffectsPanelToggled();
}

/// Triggered to close all open panels (font selector, color picker, outline
/// and shadow).
class VideoEditorTextClosePanels extends VideoEditorTextEvent {
  const VideoEditorTextClosePanels();
}

/// Triggered to initialize state from an existing text layer.
class VideoEditorTextInitFromLayer extends VideoEditorTextEvent {
  const VideoEditorTextInitFromLayer({
    required this.text,
    required this.alignment,
    required this.color,
    required this.backgroundStyle,
    required this.selectedFontIndex,
    this.effects = TextEffects.none,
  });

  /// The text content of the layer.
  final String text;

  /// The text alignment.
  final TextAlign alignment;

  /// The primary color (text or background depending on mode).
  final Color color;

  /// The background style mode.
  final LayerBackgroundMode backgroundStyle;

  /// The index of the selected font in [VideoEditorConstants.textFonts].
  final int selectedFontIndex;

  /// The outline and shadow the layer draws.
  final TextEffects effects;

  @override
  List<Object?> get props => [
    text,
    alignment,
    color,
    backgroundStyle,
    selectedFontIndex,
    effects,
  ];
}
