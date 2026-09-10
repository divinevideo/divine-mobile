// ABOUTME: Full-screen crop / rotate / flip editor for one stop-motion still.
// ABOUTME: Hosts pro_image_editor's CropRotateEditor and returns the
// ABOUTME: transformed image bytes to the caller.

import 'dart:io';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/pro_editor_theme.dart';
import 'package:openvine/widgets/video_editor/transform/transform_editor_configs.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Opens the still at [framePath] in an image [CropRotateEditor] and pops the
/// route with the transformed image bytes when the user confirms, or `null`
/// when they cancel.
///
/// Runs the same editor chrome and configuration as the clip-level transform
/// (see `transformEditorConfigs`); only the source and the result differ. The
/// clip screen drives a `ProVideoController` and hands its caller an
/// `ExportTransform` to bake into a re-rendered video — which a frames-only
/// stop-motion clip has no file for. A still needs no render at all: the editor
/// rasterizes it itself, so this returns finished pixels and the caller only
/// has to give them a file.
class StopMotionFrameTransformScreen extends StatefulWidget {
  const StopMotionFrameTransformScreen({
    required this.framePath,
    required this.targetAspectRatio,
    super.key,
  });

  /// Absolute path to the captured still being transformed.
  final String framePath;

  /// The composition's output aspect ratio. The crop starts locked to it
  /// because the stop-motion encoder cover-crops every still into exactly that
  /// frame — cropping to anything else would just be cropped again on render.
  final model.AspectRatio targetAspectRatio;

  @override
  State<StopMotionFrameTransformScreen> createState() =>
      _StopMotionFrameTransformScreenState();
}

class _StopMotionFrameTransformScreenState
    extends State<StopMotionFrameTransformScreen> {
  /// Captured from [ProImageEditorCallbacks.onImageEditingComplete] before the
  /// close callback pops.
  Uint8List? _result;
  bool _popped = false;

  void _close() {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.of(context).pop(_result);
  }

  @override
  Widget build(BuildContext context) {
    return CropRotateEditor.file(
      File(widget.framePath),
      initConfigs: CropRotateEditorInitConfigs(
        theme: proEditorTheme(context),
        // Required so the editor rasterizes the cropped still instead of only
        // reporting the transform — the frame list stores image files, not
        // transforms.
        convertToUint8List: true,
        configs: transformEditorConfigs(
          context,
          initAspectRatio: widget.targetAspectRatio.value,
          // Rasterizing a full-resolution camera still takes long enough to
          // see, so the wait is covered rather than left looking like a hang.
          loadingOverlay: TransformEditorLoadingOverlay(
            label: context.l10n.videoEditorTransformFrameProgressLabel,
          ),
        ),
        callbacks: ProImageEditorCallbacks(
          onImageEditingComplete: (bytes) async {
            _result = bytes;
          },
          // Fires for both Done (after the bytes are captured) and Cancel
          // (with no captured result) — the single pop site for the route.
          onCloseEditor: (_) => _close(),
        ),
      ),
    );
  }
}
