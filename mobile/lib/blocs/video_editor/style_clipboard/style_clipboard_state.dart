// ABOUTME: State for the editor's style clipboard: the copied clip style and
// ABOUTME: the copied layer style, each absent until something is copied.

part of 'style_clipboard_cubit.dart';

/// What the style clipboard holds.
class StyleClipboardState extends Equatable {
  /// Creates a state.
  const StyleClipboardState({this.clipStyle, this.layerStyle});

  /// The clip style last copied, or `null` when none was.
  final ClipStyle? clipStyle;

  /// The layer style last copied, or `null` when none was.
  final LayerStyle? layerStyle;

  /// A copy with the given styles replaced.
  StyleClipboardState copyWith({
    ClipStyle? clipStyle,
    LayerStyle? layerStyle,
  }) => StyleClipboardState(
    clipStyle: clipStyle ?? this.clipStyle,
    layerStyle: layerStyle ?? this.layerStyle,
  );

  @override
  List<Object?> get props => [clipStyle, layerStyle];
}
