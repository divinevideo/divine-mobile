// ABOUTME: The second camera's small window in the viewfinder during
// ABOUTME: dual-camera capture: tap swaps the cameras, drag moves the window

import 'dart:math' as math;

import 'package:divine_camera/divine_camera.dart'
    show SecondaryCameraPreviewWidget;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/extensions/layer_animation_storage.dart'
    show ExportLayerMapping;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_recorder/secondary_camera_take.dart';

/// Shows the second camera in a small window over the viewfinder while
/// dual-camera capture is on.
///
/// Tapping it swaps which camera fills the viewfinder; dragging moves it. Its
/// position is where the editor places the second camera's
/// picture-in-picture layer.
class VideoRecorderDualCameraWindow extends StatefulWidget {
  /// Creates the second camera's window.
  const VideoRecorderDualCameraWindow({super.key});

  /// Portrait aspect ratio (width / height) of the window.
  static const double aspectRatio = 9 / 16;

  @override
  State<VideoRecorderDualCameraWindow> createState() =>
      _VideoRecorderDualCameraWindowState();
}

class _VideoRecorderDualCameraWindowState
    extends State<VideoRecorderDualCameraWindow> {
  /// The window's center while a drag moves it, as fractions of the kept
  /// picture. Reported to the recorder when the drag ends.
  Offset? _dragCenter;

  /// Whether a check of the recorder's window position is queued for after
  /// this frame; see [_keepPositionShown].
  bool _isPositionCheckQueued = false;

  @override
  Widget build(BuildContext context) {
    final state = context.select(
      (VideoRecorderBloc b) => (
        center: b.state.dualCameraPipCenter,
        textureId: b.state.secondaryPreviewTextureId,
        canSwap: b.state.canSwitchCamera && !b.state.hasRecordingInFlight,
        sensorAspectRatio: b.state.cameraSensorAspectRatio,
        keptAspectRatio: b.state.aspectRatio.value,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Offset.zero & constraints.biggest;
        final kept = keptPicture(
          box: box.size,
          sensorAspectRatio: state.sensorAspectRatio,
          keptAspectRatio: state.keptAspectRatio,
        );
        final visible = kept.intersect(box);
        final width = kept.width * SecondaryCameraTake.pipWidthFraction;
        final height = width / VideoRecorderDualCameraWindow.aspectRatio;
        final size = Size(width, height);
        final rect = _windowRect(
          center: _dragCenter ?? state.center,
          kept: kept,
          visible: visible,
          size: size,
        );
        if (_dragCenter == null) {
          _keepPositionShown(kept: kept, visible: visible, size: size);
        }

        return Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: Semantics(
                identifier: SemanticIds.cameraDualCameraWindow,
                button: true,
                enabled: state.canSwap,
                label: context.l10n.videoRecorderDualCameraSwapLabel,
                child: GestureDetector(
                  // The window follows the finger from where it touched it,
                  // not from where the drag was recognized.
                  dragStartBehavior: .down,
                  onTap: state.canSwap
                      ? () => context.read<VideoRecorderBloc>().add(
                          const VideoRecorderCameraSwitched(),
                        )
                      : null,
                  onPanUpdate: (details) => setState(() {
                    // From the latest position, not the one this build saw:
                    // several updates can land before the next build.
                    final moved = _windowRect(
                      center: _dragCenter ?? state.center,
                      kept: kept,
                      visible: visible,
                      size: size,
                    ).shift(details.delta);
                    _dragCenter = _centerIn(
                      _windowRect(
                        center: _centerIn(moved, kept),
                        kept: kept,
                        visible: visible,
                        size: size,
                      ),
                      kept,
                    );
                  }),
                  onPanEnd: (_) => _endDrag(),
                  onPanCancel: _endDrag,
                  child: _WindowFrame(textureId: state.textureId),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _endDrag() {
    final center = _dragCenter;
    if (center == null) return;
    context.read<VideoRecorderBloc>().add(
      VideoRecorderDualCameraPipMoved(center),
    );
    setState(() => _dragCenter = null);
  }

  /// Moves the recorder's window position to where this viewfinder shows it,
  /// when it cannot show the stored one whole: a position kept from the
  /// other aspect ratio, or the default on a viewfinder that cuts more of the
  /// frame off. The take then lands where the window was seen.
  ///
  /// Checked after the frame, against the recorder's state then: a drag that
  /// just ended has landed there by then, and must not be undone.
  void _keepPositionShown({
    required Rect kept,
    required Rect visible,
    required Size size,
  }) {
    if (_isPositionCheckQueued) return;
    _isPositionCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isPositionCheckQueued = false;
      if (!mounted || _dragCenter != null) return;
      final bloc = context.read<VideoRecorderBloc>();
      final stored = bloc.state.dualCameraPipCenter;
      final shown = _centerIn(
        _windowRect(center: stored, kept: kept, visible: visible, size: size),
        kept,
      );
      if ((shown - stored).distance > 0.001) {
        bloc.add(VideoRecorderDualCameraPipMoved(shown));
      }
    });
  }

  /// The window of [size] centered on [center] (fractions of [kept]), kept
  /// whole inside the [visible] part of the kept picture.
  static Rect _windowRect({
    required Offset center,
    required Rect kept,
    required Rect visible,
    required Size size,
  }) {
    final left = (kept.left + center.dx * kept.width - size.width / 2).clamp(
      visible.left,
      math.max<double>(visible.left, visible.right - size.width),
    );
    final top = (kept.top + center.dy * kept.height - size.height / 2).clamp(
      visible.top,
      math.max<double>(visible.top, visible.bottom - size.height),
    );
    return Offset(left, top) & size;
  }

  /// [rect]'s center as fractions of [kept].
  static Offset _centerIn(Rect rect, Rect kept) => Offset(
    (rect.center.dx - kept.left) / kept.width,
    (rect.center.dy - kept.top) / kept.height,
  );
}

/// Where the picture a take keeps sits in a viewfinder [box].
///
/// The preview covers the box with the camera frame of [sensorAspectRatio]
/// (width / height), so the frame can reach past the box; the take keeps the
/// middle of that frame at [keptAspectRatio]. The window is measured against
/// this rect, which is how the editor and the library picture measure it.
/// A camera that has not reported its frame yet counts as filling the box.
@visibleForTesting
Rect keptPicture({
  required Size box,
  required double sensorAspectRatio,
  required double keptAspectRatio,
}) {
  final Rect frame;
  if (sensorAspectRatio <= 0 || box.isEmpty) {
    frame = Offset.zero & box;
  } else {
    final cover = box.aspectRatio > sensorAspectRatio
        ? Size(box.width, box.width / sensorAspectRatio)
        : Size(box.height * sensorAspectRatio, box.height);
    frame = Rect.fromCenter(
      center: box.center(Offset.zero),
      width: cover.width,
      height: cover.height,
    );
  }
  return ExportLayerMapping.keptRect(
    frame.size,
    keptAspectRatio,
  ).shift(frame.topLeft);
}

class _WindowFrame extends StatelessWidget {
  const _WindowFrame({required this.textureId});

  final int? textureId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ClipRRect(
        // The editor masks the layer with the same rounding, so the window
        // shows the take as it will look.
        borderRadius: BorderRadius.circular(
          constraints.biggest.shortestSide /
              2 *
              SecondaryCameraTake.pipCornerRadius,
        ),
        // Keyed on the texture: a swap hands the window the other camera's
        // texture.
        child: SecondaryCameraPreviewWidget(key: ValueKey(textureId)),
      ),
    );
  }
}
