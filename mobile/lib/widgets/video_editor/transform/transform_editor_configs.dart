// ABOUTME: The single ProImageEditorConfigs both transform screens run on
// ABOUTME: Keeps the clip (video) and stop-motion still (image) editors in step

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/transform/transform_editor_chrome.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show
        CropRotateEditorConfigs,
        CropRotateEditorStyle,
        CropRotateEditorWidgets,
        DialogConfigs,
        DialogWidgets,
        ProImageEditorConfigs,
        ProgressIndicatorConfigs,
        ProgressIndicatorWidgets,
        ReactiveAppbar,
        ReactiveWidget;

/// Hero tag for the crop-rotate editors, deliberately *not* the package
/// default the main video editor runs on.
///
/// Sharing a tag makes Flutter fly a hero between the two routes, which
/// re-parents the main editor's content into the navigator overlay for the
/// duration of the flight — above the route that owns `BlocProvider<
/// ClipEditorBloc>`. `VideoEditorClipPreview` reads that bloc for a
/// stop-motion clip, so the flight threw `ProviderNotFoundException` mid-build
/// and the global error widget took over the screen. A distinct tag means no
/// flight is ever attempted; the routes fade, which is the transition they
/// already used.
const transformEditorHeroTag = 'divine-transform-editor-hero';

/// The [transformEditorConfigs] `initAspectRatio` that leaves the crop box
/// unconstrained, so the user can drag it to any shape.
///
/// pro_image_editor spells "free" as `-1` (and "original" as `0`); naming it
/// keeps that magic number out of call sites.
const double freeCropAspectRatio = -1;

/// Builds the crop-rotate editor configuration shared by
/// `VideoClipTransformScreen` and `StopMotionFrameTransformScreen`.
///
/// The two screens cannot share a widget — one drives `CropRotateEditor.video`
/// off a `ProVideoController` and returns an `ExportTransform` to bake into a
/// re-rendered clip, the other drives `CropRotateEditor.file` on a still and
/// returns finished pixels — but everything the user actually sees is the same,
/// so it lives here rather than being written twice.
///
/// [initAspectRatio] locks the crop to the composition's output ratio — or
/// leaves it unconstrained when it is [freeCropAspectRatio], which is what a
/// detached clip wants: it floats on the canvas rather than filling the frame,
/// so its shape is the user's to choose.
/// [bottomBarLeading] is the extra action before Rotate (the clip editor's
/// play/pause; a still has nothing to play). [loadingOverlay] covers the editor
/// while Done rasterizes; omit it to leave the wait uncovered.
ProImageEditorConfigs transformEditorConfigs(
  BuildContext context, {
  required double initAspectRatio,
  Widget? bottomBarLeading,
  Widget? loadingOverlay,
}) {
  return ProImageEditorConfigs(
    heroTag: transformEditorHeroTag,
    // `imageGeneration` is left at the package default, whose `outputFormat`
    // is JPEG — the format `StopMotionFrameTransformService` names its file
    // after. Setting it here trips `avoid_redundant_argument_values`, so the
    // configs test pins it instead; a package bump that flips the default
    // fails there rather than silently putting PNG bytes behind a `.jpg`.
    cropRotateEditor: CropRotateEditorConfigs(
      enableKeepAspectRatioOnRotate: true,
      initAspectRatio: initAspectRatio,
      style: CropRotateEditorStyle(
        background: context.vineColors.surfaceContainerHigh,
        cropCornerColor: VineTheme.primary,
      ),
      widgets: CropRotateEditorWidgets(
        appBar: (editorState, rebuildStream) => ReactiveAppbar(
          stream: rebuildStream,
          builder: (_) => TransformEditorAppBar(editorState: editorState),
        ),
        bottomBar: (editorState, rebuildStream) => ReactiveWidget(
          stream: rebuildStream,
          builder: (_) => TransformEditorBottomBar(
            editorState: editorState,
            leading: bottomBarLeading,
          ),
        ),
      ),
    ),
    dialogConfigs: DialogConfigs(
      widgets: DialogWidgets(
        // The editor hosts this in an `OverlayEntry`, which sits outside every
        // route's `Material` — so text there inherits `MaterialApp`'s red-on-
        // yellow "unstyled text" fallback. `TransformEditorLoadingOverlay`
        // carries the `Material` that fixes it; anything passed here must too.
        loadingDialog: (message, configs) =>
            loadingOverlay ?? const SizedBox.shrink(),
      ),
    ),
    // Replace the editor's brief internal spinner (shown while it decodes the
    // resolution-sized background) with the branded indicator.
    progressIndicatorConfigs: const ProgressIndicatorConfigs(
      widgets: ProgressIndicatorWidgets(
        circularProgressIndicator: BrandedLoadingIndicator(size: 48),
      ),
    ),
  );
}

/// Full-screen cover shown while the editor rasterizes the result of Done.
///
/// Lives in an `OverlayEntry` with no `Material` above it, so it brings its own
/// — without it every `Text` here renders in `MaterialApp`'s unstyled-text
/// fallback: red monospace under a yellow double underline.
class TransformEditorLoadingOverlay extends StatelessWidget {
  const TransformEditorLoadingOverlay({required this.label, super.key});

  /// What the user is waiting for, already localized.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      // `ColoredBox` already absorbs pointers, but semantics travel their own
      // path: without `BlockSemantics` the editor's actions underneath stay
      // reachable to a screen reader, and taps there are silently dropped —
      // Done captured the result before this went up.
      child: BlockSemantics(
        child: ColoredBox(
          color: VineTheme.backgroundCamera.withValues(alpha: 0.85),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                // The label below already announces the wait.
                const ExcludeSemantics(
                  child: BrandedLoadingIndicator(size: 44),
                ),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: VineTheme.titleSmallFont(color: VineTheme.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
