part of 'video_editor_text_bloc.dart';

/// State for the video editor text overlay screen.
class VideoEditorTextState extends Equatable {
  const VideoEditorTextState({
    this.text = '',
    this.selectedFontIndex = 0,
    this.alignment = .center,
    this.color = VineTheme.backgroundColor,
    this.backgroundStyle = .backgroundAndColor,
    this.showFontSelector = false,
    this.showColorPicker = false,
    this.effects = TextEffects.none,
    this.showEffectsPanel = false,
    this.gradient,
    this.lastGradient,
  });

  /// The current text content.
  final String text;

  /// The index of the selected font in [VideoEditorConstants.textFonts].
  final int selectedFontIndex;

  /// Returns the selected font getter.
  TextFont get selectedFont =>
      VideoEditorConstants.textFonts[selectedFontIndex];

  /// Returns the display name of the selected font.
  String get selectedFontName => selectedFont.displayName;

  /// The text alignment.
  final TextAlign alignment;

  /// The primary color.
  final Color color;

  /// The background style.
  final LayerBackgroundMode backgroundStyle;

  /// Whether the font selector is currently shown (replaces keyboard).
  final bool showFontSelector;

  /// Whether the color picker is currently shown (replaces keyboard).
  final bool showColorPicker;

  /// The outline and shadow drawn around the text.
  final TextEffects effects;

  /// Whether the outline and shadow panel is currently shown (replaces
  /// keyboard).
  final bool showEffectsPanel;

  /// The color gradient that fills the letters in place of [color], or
  /// `null` when they are filled with a single color.
  final TextGradient? gradient;

  /// The gradient the letters had last, kept while they are filled with a
  /// single color so switching back to a gradient brings it back; `null`
  /// before they had one.
  final TextGradient? lastGradient;

  /// The gradient the letters get when the user switches from a single color
  /// to a gradient.
  TextGradient get gradientToRestore =>
      lastGradient ?? TextGradientPreset.initial;

  /// Whether any panel replaces the keyboard.
  bool get showsPanel =>
      showFontSelector || showColorPicker || showEffectsPanel;

  /// Creates a copy with the given fields replaced.
  VideoEditorTextState copyWith({
    String? text,
    int? selectedFontIndex,
    TextAlign? alignment,
    Color? color,
    LayerBackgroundMode? backgroundStyle,
    bool? showFontSelector,
    bool? showColorPicker,
    TextEffects? effects,
    bool? showEffectsPanel,
    TextGradient? gradient,
    bool clearGradient = false,
    TextGradient? lastGradient,
  }) {
    return VideoEditorTextState(
      text: text ?? this.text,
      selectedFontIndex: selectedFontIndex ?? this.selectedFontIndex,
      alignment: alignment ?? this.alignment,
      color: color ?? this.color,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      showFontSelector: showFontSelector ?? this.showFontSelector,
      showColorPicker: showColorPicker ?? this.showColorPicker,
      effects: effects ?? this.effects,
      showEffectsPanel: showEffectsPanel ?? this.showEffectsPanel,
      gradient: clearGradient ? null : gradient ?? this.gradient,
      lastGradient: lastGradient ?? this.lastGradient,
    );
  }

  @override
  List<Object?> get props => [
    text,
    selectedFontIndex,
    alignment,
    color,
    backgroundStyle,
    showFontSelector,
    showColorPicker,
    effects,
    showEffectsPanel,
    gradient,
    lastGradient,
  ];
}
