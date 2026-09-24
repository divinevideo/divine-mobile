// ABOUTME: Animated focus point indicator widget for camera tap-to-focus
// ABOUTME: Shows a circular indicator at tap location with scale and fade animations

import 'package:divine_camera/divine_camera.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';

/// Animated focus point indicator for tap-to-focus functionality.
class VideoRecorderFocusPoint extends StatefulWidget {
  /// Creates a focus point indicator widget.
  const VideoRecorderFocusPoint({super.key});

  /// Size of the focus indicator in pixels.
  static const indicatorSize = 88.0;

  @override
  State<VideoRecorderFocusPoint> createState() =>
      _VideoRecorderFocusPointState();
}

class _VideoRecorderFocusPointState extends State<VideoRecorderFocusPoint> {
  Offset _lastVisiblePosition = .zero;

  /// Whether the preview is currently being mirrored in Flutter.
  /// Used to adjust focus indicator position.
  // coverage:ignore-start
  bool get _isPreviewMirrored {
    if (kIsWeb) return false;
    final camera = DivineCamera.instance;
    if (!camera.lens.facesUser) return false;

    // Must mirror the indicator the same way CameraPreviewWidget mirrors the
    // preview, so the indicator stays under the user's finger.
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return !camera.mirrorFrontCameraOutput;
    }
    // Android: mirrored unless the native producer applies its own transform
    // (the API<29 SurfaceTexture path).
    return !camera.state.previewHandlesTransform;
  }
  // coverage:ignore-end

  /// Transform camera coordinates to display coordinates based on
  /// FittedBox.cover
  Offset _cameraToDisplayCoordinates({
    required double cropAspectRatio,
    required double sensorAspectRatio,
    required Offset cameraPoint,
  }) {
    // SizedBox aspect ratio = (1000 * sensorAR) / 1000 = sensorAR
    // arRatio compares display to sizedbox aspect ratios
    final arRatio = cropAspectRatio / sensorAspectRatio;

    double displayX;
    double displayY;

    if (arRatio > 1) {
      // Display is wider relative to camera - height is cropped
      final visibleHeight = 1 / arRatio;
      final cropY = (1 - visibleHeight) / 2;
      displayX = cameraPoint.dx;
      displayY = (cameraPoint.dy - cropY) * arRatio;
    } else {
      // Display is taller relative to camera - width is cropped
      final visibleWidth = arRatio;
      final cropX = (1 - visibleWidth) / 2;
      displayX = (cameraPoint.dx - cropX) / arRatio;
      displayY = cameraPoint.dy;
    }

    return Offset(displayX.clamp(0, 1), displayY.clamp(0, 1));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.select(
      (VideoRecorderBloc b) => (
        aspectRatio: b.state.aspectRatio.value,
        sensorAspectRatio: b.state.cameraSensorAspectRatio,
        focusPoint: b.state.focusPoint,
      ),
    );

    final isVisible = state.focusPoint != .zero;

    // Remember the last visible position for smooth fade out
    if (isVisible) {
      _lastVisiblePosition = state.focusPoint;
    }

    // Transform camera coordinates to display coordinates
    final cameraPoint = isVisible ? state.focusPoint : _lastVisiblePosition;

    return LayoutBuilder(
      builder: (context, constraints) {
        var displayPosition = _cameraToDisplayCoordinates(
          cropAspectRatio: constraints.biggest.aspectRatio,
          sensorAspectRatio: state.sensorAspectRatio,
          cameraPoint: cameraPoint,
        );

        // When the preview is mirrored, the focus point was flipped for the
        // camera, but we need to show the indicator where the user tapped
        // (which is the mirrored visual position)
        // coverage:ignore-start
        if (_isPreviewMirrored) {
          displayPosition = Offset(1 - displayPosition.dx, displayPosition.dy);
        }
        // coverage:ignore-end

        // Convert normalized coordinates (0.0-1.0) to pixel coordinates
        final x = displayPosition.dx * constraints.maxWidth;
        final y = displayPosition.dy * constraints.maxHeight;

        return IgnorePointer(
          child: Stack(
            children: [
              Positioned(
                left: x - VideoRecorderFocusPoint.indicatorSize / 2,
                top: y - VideoRecorderFocusPoint.indicatorSize / 2,
                child: RepaintBoundary(
                  child: AnimatedOpacity(
                    opacity: isVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('Focus-Point-${state.focusPoint}'),
                      duration: const Duration(milliseconds: 300),
                      tween: Tween(
                        begin: isVisible ? 1.2 : 1.0,
                        end: isVisible ? 1.0 : 0.4,
                      ),
                      curve: Curves.easeOutCubic,
                      builder: (context, scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: const _FocusPoint(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FocusPoint extends StatelessWidget {
  const _FocusPoint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: VideoRecorderFocusPoint.indicatorSize,
      height: VideoRecorderFocusPoint.indicatorSize,
      decoration: BoxDecoration(
        border: .all(color: VineTheme.accentYellow, width: 4),
        borderRadius: .circular(32),
      ),
    );
  }
}
