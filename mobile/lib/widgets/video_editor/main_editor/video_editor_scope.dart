// ABOUTME: InheritedWidget providing access to the ProImageEditor instance.
// ABOUTME: Allows child widgets to call editor methods directly without callbacks.

import 'package:flutter/widgets.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas_fit.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Provides access to the [ProImageEditorState] for descendant widgets.
///
/// This allows toolbar widgets to directly call editor methods (undo, redo,
/// openTextEditor, etc.) without needing callbacks through a BLoC.
///
/// Usage:
/// ```dart
/// VideoEditorScope.of(context).undo();
/// ```
class VideoEditorScope extends InheritedWidget {
  /// Creates a [VideoEditorScope].
  const VideoEditorScope({
    required this.editorKey,
    required this.removeAreaKey,
    required this.onAddStickers,
    required this.onOpenCamera,
    required this.onOpenClipsEditor,
    required this.onAddEditTextLayer,
    required this.onOpenMusicLibrary,
    required this.onOpenVoiceOver,
    required this.onOpenCaptions,
    required this.originalClipAspectRatio,
    required this.bodySizeNotifier,
    required this.zoomMatrixNotifier,
    required this.playTimeNotifier,
    required this.playheadAdvancingNotifier,
    required this.fromLibrary,
    this.targetClipAspectRatio,
    this.editorOverride,
    this.awaitPushCoverTransition,
    super.child = const SizedBox.shrink(),
    super.key,
  });

  /// Global key to access the [ProImageEditorState].
  final GlobalKey<ProImageEditorState> editorKey;

  /// Direct editor reference, used in tests to inject a mock.
  ///
  /// When non-null this takes precedence over [editorKey.currentState].
  @visibleForTesting
  final ProImageEditorState? editorOverride;

  /// Global key to access the remove area widget.
  final GlobalKey removeAreaKey;

  /// Callback to open the sticker picker.
  final VoidCallback onAddStickers;

  /// Callback to open the in-editor camera recorder.
  final VoidCallback onOpenCamera;

  /// Callback to open the clips editor.
  final VoidCallback onOpenClipsEditor;

  /// Callback to open the music library.
  final VoidCallback onOpenMusicLibrary;

  /// Callback to open the voice-over recorder.
  final VoidCallback onOpenVoiceOver;

  /// Callback to open the captions flow (mode prompt + captions editor).
  final VoidCallback onOpenCaptions;

  /// Original aspect ratio of the clip being edited.
  final double originalClipAspectRatio;

  /// Target crop aspect ratio of the clip being edited.
  final double? targetClipAspectRatio;

  /// Whether the clip was selected from the device library.
  final bool fromLibrary;

  /// Notifier for the body size, updated by [_CanvasFitter].
  final ValueNotifier<Size> bodySizeNotifier;

  /// Notifier for the current editor zoom transform (identity = not zoomed),
  /// driven by the editor's zoom matrix. The letterbox scrim applies the same
  /// transform so the bars move/scale with the magnified frame instead of
  /// dimming it.
  final ValueNotifier<Matrix4> zoomMatrixNotifier;

  /// Notifier for the fine-grained editor play time (timeline space), updated
  /// every playhead tick — the same value that drives the burned-in layers.
  /// Canvas overlays (e.g. the CC caption pill) listen to this so they track
  /// playback smoothly instead of the coarse `VideoEditorMainBloc` position.
  final ValueNotifier<Duration> playTimeNotifier;

  /// Whether [playTimeNotifier] is currently being advanced by playback.
  ///
  /// The notifier only fires on change, so a pause is the *absence* of ticks —
  /// something a listener can only infer from a timeout, and a timeout is
  /// either slow to react or trips on ordinary UI-thread jank. This says it
  /// outright, from the canvas that owns both playback tickers. A scrub moves
  /// the playhead with this `false`: the frame under the finger has to follow,
  /// but nothing should be *playing*.
  final ValueNotifier<bool> playheadAdvancingNotifier;

  /// Callback to open the text editor.
  final Future<TextLayer?> Function([TextLayer? layer]) onAddEditTextLayer;

  /// Awaits the entrance transition of a screen pushed over the editor, using a
  /// context **above** the canvas's nested `Navigator` so the editor route's
  /// `secondaryAnimation` is actually driven by the push. Provided by the
  /// screen; the canvas falls back to its own (nested) context when absent
  /// (e.g. in isolated widget tests that never navigate).
  final Future<void> Function()? awaitPushCoverTransition;

  /// FittedBox scale factor between bodySize and renderSize.
  double get fittedBoxScale => calculateFittedBoxScale(
    bodySizeNotifier.value,
    originalClipAspectRatio,
    targetAspectRatio: targetClipAspectRatio,
  );

  /// The unscaled surface layers are laid out on.
  ///
  /// A layer's `width` is in these coordinates — `LayerWidgetCustomItem` sizes
  /// it as `SizedBox(width: layer.width * layer.scale)` — so a layer as wide as
  /// this exactly spans the video. Deriving a layer width from [bodySize]
  /// instead is off by `targetSize / bodySize`, which is why a "80% of the
  /// canvas" layer came out wider than the video it sat on.
  Size get canvasRenderSize => VideoEditorCanvasGeometry(
    bodySize: bodySizeNotifier.value,
    originalAspectRatio: originalClipAspectRatio,
    targetAspectRatio: targetClipAspectRatio,
  ).renderSize;

  /// Calculates the visible target area fitted inside [bodySize].
  static Size calculateTargetSize(Size bodySize, double targetAspectRatio) =>
      VideoEditorCanvasGeometry.targetSizeFor(bodySize, targetAspectRatio);

  /// Calculates the FittedBox scale factor for a given body size and aspect
  /// ratio.
  ///
  /// Reads the same [VideoEditorCanvasGeometry] the canvas lays itself out
  /// with, so a layer compensating for the transform can never disagree with
  /// the transform the canvas applies.
  static double calculateFittedBoxScale(
    Size bodySize,
    double aspectRatio, {
    double? targetAspectRatio,
  }) => VideoEditorCanvasGeometry(
    bodySize: bodySize,
    originalAspectRatio: aspectRatio,
    targetAspectRatio: targetAspectRatio,
  ).fittedBoxScale;

  /// Returns the [ProImageEditorState] if available.
  ProImageEditorState? get editor => editorOverride ?? editorKey.currentState;

  /// Returns the [ProImageEditorState], throwing a descriptive error if null.
  ///
  /// Use this in gesture handlers and callbacks where the editor is expected
  /// to exist. Provides a clear message instead of a bare null-check failure.
  ProImageEditorState get requireEditor {
    final state = editor;
    assert(
      state != null,
      'VideoEditorScope.requireEditor called but '
      'ProImageEditorState is not mounted. '
      'This can happen if a gesture resolves after a route pop.',
    );
    return state!;
  }

  /// Returns the [FilterEditorState] if available.
  FilterEditorState? get filterEditor => editor?.filterEditor.currentState;

  /// Returns the [TuneEditorState] if available.
  TuneEditorState? get tuneEditor => editor?.tuneEditor.currentState;

  /// Returns the [PaintEditorState] if available.
  PaintEditorState? get paintEditor => editor?.paintEditor.currentState;

  /// Gets the nearest [VideoEditorScope] from the widget tree.
  ///
  /// Throws if no [VideoEditorScope] is found.
  static VideoEditorScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No VideoEditorScope found in context');
    return scope!;
  }

  /// Gets the nearest [VideoEditorScope], or `null` when there is none.
  ///
  /// For widgets that also render outside the editor. A detached clip's layer
  /// widget is one: the draft render path rebuilds every layer from its
  /// exported map, with no editor around it.
  static VideoEditorScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VideoEditorScope>();

  /// Checks if the given position is over the remove area.
  bool isOverRemoveArea(Offset globalPosition) {
    final renderBox =
        removeAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return false;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final rect = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );

    return rect.contains(globalPosition);
  }

  @override
  bool updateShouldNotify(VideoEditorScope oldWidget) =>
      editorKey != oldWidget.editorKey ||
      removeAreaKey != oldWidget.removeAreaKey ||
      originalClipAspectRatio != oldWidget.originalClipAspectRatio ||
      targetClipAspectRatio != oldWidget.targetClipAspectRatio ||
      zoomMatrixNotifier != oldWidget.zoomMatrixNotifier;
}
