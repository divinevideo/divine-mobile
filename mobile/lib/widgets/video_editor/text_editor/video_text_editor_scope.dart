// ABOUTME: InheritedWidget providing access to the TextEditorState instance.
// ABOUTME: Allows child widgets to call text editor methods directly.

import 'package:flutter/widgets.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Provides access to the [TextEditorState] for descendant widgets.
///
/// This allows overlay widgets to directly call text editor methods
/// (toggleTextAlign, toggleBackgroundMode, etc.) without needing callbacks.
///
/// Usage:
/// ```dart
/// VideoTextEditorScope.of(context).editor.toggleTextAlign();
/// ```
class VideoTextEditorScope extends InheritedWidget {
  /// Creates a [VideoTextEditorScope].
  const VideoTextEditorScope({
    required this.editorKey,
    required super.child,
    super.key,
  });

  /// The key for the [TextEditorState].
  ///
  /// Access the state lazily via [editor] to avoid null issues during
  /// the first build frame.
  final GlobalKey<TextEditorState> editorKey;

  /// The [TextEditorState] instance.
  TextEditorState get editor => editorKey.currentState!;

  /// Gets the nearest [VideoTextEditorScope] from the widget tree.
  ///
  /// Throws if no [VideoTextEditorScope] is found.
  static VideoTextEditorScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<VideoTextEditorScope>();
    assert(scope != null, 'No VideoTextEditorScope found in context');
    return scope!;
  }

  /// Gets the nearest [VideoTextEditorScope] from the widget tree, or null.
  static VideoTextEditorScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<VideoTextEditorScope>();
  }

  @override
  bool updateShouldNotify(VideoTextEditorScope oldWidget) =>
      editorKey != oldWidget.editorKey;
}
