// ABOUTME: Camera preview widget for Flutter
// ABOUTME: Provides a ready-to-use camera preview with gesture support

import 'dart:io' show Platform;

import 'package:divine_camera/divine_camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// A widget that displays the camera preview with built-in gesture support.
///
/// This widget handles:
/// - Pinch-to-zoom gestures
/// - Tap-to-focus functionality
/// - Proper aspect ratio handling
class CameraPreviewWidget extends StatefulWidget {
  /// Creates a camera preview widget.
  const CameraPreviewWidget({
    this.fit = BoxFit.contain,
    this.onTap,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.loadingWidget,
    this.focusIndicatorBuilder,
    super.key,
  });

  /// How the preview should be fitted.
  final BoxFit fit;

  /// Optional callback when the preview is tapped.
  /// Receives local position and normalized position (0.0 - 1.0).
  final void Function(Offset localPosition, Offset normalizedPosition)? onTap;

  /// Widget to show while loading.
  final Widget? loadingWidget;

  /// Optional builder for the focus indicator widget.
  /// Receives the tap position (local coordinates) and returns a widget.
  final Widget Function(Offset position)? focusIndicatorBuilder;

  /// Optional callback when a scale gesture starts (pinch-to-zoom).
  /// Used to handle zoom gestures on the camera preview.
  final ValueChanged<ScaleStartDetails>? onScaleStart;

  /// Optional callback when a scale gesture updates (pinch-to-zoom).
  /// Used to handle zoom level changes during the gesture.
  final ValueChanged<ScaleUpdateDetails>? onScaleUpdate;

  /// Optional callback when a scale gesture ends (all pointers lifted or
  /// the pointer configuration changed). Lets callers track whether a
  /// preview gesture is currently in progress.
  final ValueChanged<ScaleEndDetails>? onScaleEnd;

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  final ValueNotifier<Offset?> _focusPoint = ValueNotifier(null);
  TapDownDetails? _tapDownDetails;
  final DivineCamera _camera = DivineCamera.instance;

  /// Stores the last valid texture ID to show during camera switch
  int? _lastTextureId;

  /// Whether the preview is currently being mirrored in Flutter.
  /// Used to adjust tap coordinates for focus.
  bool get _isPreviewMirrored {
    if (kIsWeb) return false;
    if (!_camera.lens.isFrontFacing) return false;

    // Platform-specific mirror handling. These branches depend on the host OS
    // via `dart:io` Platform, so they resolve differently under a widget test
    // than on device (a macOS test host takes the Apple branch; Linux CI falls
    // through to Android). They're verified on device, not in host tests, and
    // excluded from coverage the same way across both arms.
    // coverage:ignore-start
    // On iOS/macOS, mirror preview only when native isn't mirroring.
    if (Platform.isIOS || Platform.isMacOS) {
      return !_camera.mirrorFrontCameraOutput;
    }
    // Android: mirror the selfie preview in Flutter only when the native
    // producer doesn't apply its own transform matrix. On the API<29
    // SurfaceTexture path (previewHandlesTransform == true) that matrix already
    // carries the front-camera mirror, so mirroring again would double-flip it.
    // On the API 29+ ImageReader path the matrix is dropped, so mirror here.
    return !_camera.state.previewHandlesTransform;
    // coverage:ignore-end
  }

  @override
  void dispose() {
    _focusPoint.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details, Size previewSize) {
    final localPosition = details.localPosition;

    // Calculate normalized coordinates (0.0 - 1.0) based on actual preview size
    var normalizedX = (localPosition.dx / previewSize.width).clamp(0.0, 1.0);
    var normalizedY = (localPosition.dy / previewSize.height).clamp(0.0, 1.0);

    // When using BoxFit.cover, the camera feed is cropped to fill the display.
    // We need to transform display coordinates to camera sensor coordinates.
    // coverage:ignore-start
    if (widget.fit == BoxFit.cover) {
      final displayAspectRatio = previewSize.width / previewSize.height;
      final sensorAspectRatio = _camera.cameraAspectRatio;
      final arRatio = displayAspectRatio / sensorAspectRatio;

      if (arRatio > 1) {
        // Display is wider than sensor - height is cropped from top/bottom
        final visibleHeight = 1 / arRatio;
        final cropY = (1 - visibleHeight) / 2;
        normalizedY = normalizedY * visibleHeight + cropY;
      } else if (arRatio < 1) {
        // Display is taller than sensor - width is cropped from left/right
        final visibleWidth = arRatio;
        final cropX = (1 - visibleWidth) / 2;
        normalizedX = normalizedX * visibleWidth + cropX;
      }
    }
    // coverage:ignore-end

    // If preview is mirrored in Flutter, flip the X coordinate for the camera
    // The visual focus indicator stays where the user tapped,
    // but the camera needs the un-mirrored coordinate
    // coverage:ignore-start
    if (_isPreviewMirrored) {
      normalizedX = 1.0 - normalizedX;
    }
    // coverage:ignore-end

    // This point stays in the displayed (upright) preview's coordinate space:
    // it drives both the native focus call and the visual focus indicator. The
    // display-rotation undo needed to map it onto the raw sensor axes happens
    // at the native boundary (DivineCamera.setFocusPoint/setExposurePoint), so
    // the indicator can keep positioning itself where the user tapped.
    final normalizedPosition = Offset(normalizedX, normalizedY);

    // Update focus point for indicator
    if (widget.focusIndicatorBuilder != null) {
      _focusPoint.value = localPosition;
    }

    // Call external callback - user decides what to do with the position
    widget.onTap?.call(localPosition, normalizedPosition);
  }

  /// Calculate the actual preview size based on constraints and aspect ratio
  Size _calculatePreviewSize(BoxConstraints constraints, double aspectRatio) {
    final availableWidth = constraints.maxWidth;
    final availableHeight = constraints.maxHeight;

    // For portrait mode, aspectRatio is inverted (e.g., 3/4 instead of 4/3)
    final previewAspectRatio = aspectRatio;

    double previewWidth;
    double previewHeight;

    if (widget.fit == BoxFit.cover) {
      // Cover: fill the entire space
      previewWidth = availableWidth;
      previewHeight = availableHeight;
    } else {
      // Contain: fit within the space while maintaining aspect ratio
      final availableAspectRatio = availableWidth / availableHeight;

      if (previewAspectRatio > availableAspectRatio) {
        // Preview is wider than available space - constrain by width
        previewWidth = availableWidth;
        previewHeight = availableWidth / previewAspectRatio;
      } else {
        // Preview is taller than available space - constrain by height
        previewHeight = availableHeight;
        previewWidth = availableHeight * previewAspectRatio;
      }
    }

    return Size(previewWidth, previewHeight);
  }

  @override
  Widget build(BuildContext context) {
    // Update last known texture ID when available
    if (_camera.textureId != null) {
      _lastTextureId = _camera.textureId;
    }

    // During camera switch, show the last frame (frozen texture)
    final isSwitching = _camera.state.isSwitchingCamera;
    final textureToShow = isSwitching ? _lastTextureId : _camera.textureId;

    if (!_camera.isInitialized || textureToShow == null) {
      return widget.loadingWidget ??
          const ColoredBox(
            color: Color(0xFF000000),
            child: Center(
              child: _CameraLoadingIndicator(),
            ),
          );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = _camera.cameraAspectRatio;
        final previewSize = _calculatePreviewSize(constraints, aspectRatio);

        return Stack(
          children: [
            GestureDetector(
              onTapDown: (details) => _tapDownDetails = details,
              onTap: () {
                if (_tapDownDetails != null) {
                  _handleTap(_tapDownDetails!, previewSize);
                }
              },
              onScaleStart: widget.onScaleStart,
              onScaleUpdate: widget.onScaleUpdate,
              onScaleEnd: widget.onScaleEnd,
              child: _CameraPreview(
                constraints: constraints,
                textureId: textureToShow,
                aspectRatio: aspectRatio,
                fit: widget.fit,
                shouldMirror: _isPreviewMirrored,
                rotationDegrees: _camera.state.previewRotationDegrees,
              ),
            ),
            ValueListenableBuilder<Offset?>(
              valueListenable: _focusPoint,
              builder: (context, focusPoint, _) {
                if (focusPoint != null &&
                    widget.focusIndicatorBuilder != null) {
                  return widget.focusIndicatorBuilder!(focusPoint);
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        );
      },
    );
  }
}

class _CameraLoadingIndicator extends StatelessWidget {
  const _CameraLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      value: MediaQuery.disableAnimationsOf(context) ? 1 : null,
      color: const Color(0xFFFFFFFF),
    );
  }
}

/// Private widget that renders the camera preview texture with proper
/// aspect ratio.
class _CameraPreview extends StatelessWidget {
  const _CameraPreview({
    required this.constraints,
    required this.textureId,
    required this.aspectRatio,
    required this.fit,
    required this.shouldMirror,
    required this.rotationDegrees,
  });

  final BoxConstraints constraints;
  final int textureId;
  final double aspectRatio;
  final BoxFit fit;

  /// Clockwise rotation to apply to the raw preview texture so it renders
  /// upright. Zero when the platform already delivers an oriented frame.
  final int rotationDegrees;

  /// Whether to apply a horizontal flip transform to the preview.
  /// This is determined by the parent widget based on platform and settings.
  final bool shouldMirror;

  @override
  Widget build(BuildContext context) {
    Widget preview = Texture(textureId: textureId);

    // Rotate the raw sensor-oriented frame upright when the platform doesn't
    // orient it itself (Android SurfaceProducer path). Applied before mirror so
    // the horizontal flip stays horizontal on the upright image.
    final quarterTurns = (rotationDegrees ~/ 90) % 4;
    if (quarterTurns != 0) {
      preview = RotatedBox(quarterTurns: quarterTurns, child: preview);
    }

    // Mirror front camera preview (selfie mode)
    // This is a visual-only transform, the actual pixels remain "real-world"
    // coverage:ignore-start
    if (shouldMirror) {
      preview = Transform(
        alignment: .center,
        transform: .diagonal3Values(-1, 1, 1),
        child: preview,
      );
    }
    // coverage:ignore-end

    // Apply aspect ratio and fit
    if (fit == BoxFit.cover) {
      preview = SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxWidth / aspectRatio,
            child: preview,
          ),
        ),
      );
    } else {
      preview = AspectRatio(aspectRatio: aspectRatio, child: preview);
    }

    return preview;
  }
}
