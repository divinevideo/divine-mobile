// ABOUTME: Dims the letterbox band outside the editor's target crop rect
// ABOUTME: Marks which layers sit outside the frame that will be exported

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas_fit.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Maps the editor's zoom [editorMatrix] (expressed in the editor's
/// render-space, where pinch translation is in render pixels) into the
/// body-space transform for the letterbox scrim, so the bars track the
/// magnified video instead of lagging behind it.
///
/// The editor content is cover-fitted from its render size into
/// [targetSize] and centered in [boxSize]. With that fit+centre affine
/// `A`, the on-screen effect of `editorMatrix` (`M`) in body coordinates is
/// `A · M · A⁻¹`. For a zoom-only `M` (uniform scale `k`, translation `t`),
/// that reduces to: same scale `k`, translation `coverScale·t + (1-k)·d`,
/// where `d` is the body-space offset of the render origin. Without the
/// `coverScale` factor the bars move too little.
///
/// Assumes a scale+translate matrix (pinch zoom on the canvas); any
/// rotation/skew is collapsed to a uniform scale by
/// [Matrix4.getMaxScaleOnAxis]. Returns the identity transform for a
/// degenerate (zero-area) box so the scrim renders untransformed.
@visibleForTesting
Matrix4 scrimZoomTransform({
  required Matrix4 editorMatrix,
  required Size boxSize,
  required Size targetSize,
  required double originalAspectRatio,
}) {
  final renderSize = VideoEditorCanvasGeometry.renderSizeFor(
    boxSize,
    originalAspectRatio,
  );
  if (renderSize.width <= 0 || renderSize.height <= 0) {
    return Matrix4.identity();
  }

  final coverScale = max(
    targetSize.width / renderSize.width,
    targetSize.height / renderSize.height,
  );
  final dx = (boxSize.width - coverScale * renderSize.width) / 2;
  final dy = (boxSize.height - coverScale * renderSize.height) / 2;

  final k = editorMatrix.getMaxScaleOnAxis();
  final t = editorMatrix.getTranslation();

  return Matrix4.identity()
    ..setEntry(0, 0, k)
    ..setEntry(1, 1, k)
    ..setEntry(0, 3, coverScale * t.x + (1 - k) * dx)
    ..setEntry(1, 3, coverScale * t.y + (1 - k) * dy);
}

/// Overlays [child] with the letterbox scrim that dims everything outside the
/// clip's target crop rect.
///
/// The video is already clipped to the target rect, so the only thing the
/// scrim ever darkens is an editor layer (sticker, text, drawing) dragged past
/// the frame edge — which is exactly the signal it exists to give: that layer
/// will be cropped away on export.
class VideoEditorCutAreaOverlay extends ConsumerWidget {
  /// Creates a [VideoEditorCutAreaOverlay].
  const VideoEditorCutAreaOverlay({required this.child, super.key});

  /// The editor canvas the scrim is layered on top of.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetAspectRatio = ref.watch(
      clipManagerProvider.select((s) => s.firstClipOrNull?.targetAspectRatio),
    );
    if (targetAspectRatio == null) return const SizedBox.shrink();

    // Dims the area outside the target aspect ratio toward the canvas
    // backdrop, so the two stay in step across appearance modes.
    final overlayColor = context.vineColors.surfaceContainerHigh.withAlpha(166);
    final safeArea = MediaQuery.paddingOf(context);
    final scope = VideoEditorScope.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = constraints.biggest;
        final targetSize = VideoEditorCanvasGeometry.targetSizeFor(
          boxSize,
          targetAspectRatio.value,
        );
        final verticalGap = (boxSize.height - targetSize.height) / 2;
        final horizontalGap = (boxSize.width - targetSize.width) / 2;

        final scrimBars = _ScrimBars(
          overlayColor: overlayColor,
          verticalGap: verticalGap,
          horizontalGap: horizontalGap,
          safeAreaTop: safeArea.top,
        );

        return Stack(
          fit: StackFit.expand,
          clipBehavior: .none,
          children: [
            child,

            ValueListenableBuilder<Matrix4>(
              valueListenable: scope.zoomMatrixNotifier,
              builder: (context, matrix, child) => Transform(
                transform: scrimZoomTransform(
                  editorMatrix: matrix,
                  boxSize: boxSize,
                  targetSize: targetSize,
                  originalAspectRatio: scope.originalClipAspectRatio,
                ),
                child: child,
              ),
              child: scrimBars,
            ),
          ],
        );
      },
    );
  }
}

/// The dark letterbox bars that frame the visible target rect. The bars sit
/// outside the [verticalGap] / [horizontalGap] cut area and are non-
/// interactive; [VideoEditorCutAreaOverlay] applies the zoom transform around
/// them.
class _ScrimBars extends StatelessWidget {
  const _ScrimBars({
    required this.overlayColor,
    required this.verticalGap,
    required this.horizontalGap,
    required this.safeAreaTop,
  });

  final Color overlayColor;
  final double verticalGap;
  final double horizontalGap;
  final double safeAreaTop;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: .none,
        children: [
          // Top bar — extends up into the safe area so there is no
          // uncovered strip above the scrim when the canvas is padded
          // below the status bar.
          if (verticalGap > 0 || safeAreaTop > 0)
            Positioned(
              top: -safeAreaTop,
              left: 0,
              right: 0,
              height: verticalGap + safeAreaTop,
              child: ColoredBox(color: overlayColor),
            ),
          // Bottom bar
          if (verticalGap > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: verticalGap,
              child: ColoredBox(color: overlayColor),
            ),
          // Left bar
          if (horizontalGap > 0)
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: horizontalGap,
              child: ColoredBox(color: overlayColor),
            ),
          // Right bar
          if (horizontalGap > 0)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: horizontalGap,
              child: ColoredBox(color: overlayColor),
            ),
        ],
      ),
    );
  }
}
