// ABOUTME: The second camera's small window in the viewfinder during
// ABOUTME: dual-camera capture: tap swaps the cameras, drag moves the window

import 'package:divine_camera/divine_camera.dart'
    show SecondaryCameraPreviewWidget;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
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
  /// The window's center while a drag moves it, as fractions of the frame.
  /// Reported to the recorder when the drag ends.
  Offset? _dragCenter;

  @override
  Widget build(BuildContext context) {
    final state = context.select(
      (VideoRecorderBloc b) => (
        center: b.state.dualCameraPipCenter,
        textureId: b.state.secondaryPreviewTextureId,
        canSwap: b.state.canSwitchCamera && !b.state.hasRecordingInFlight,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = constraints.biggest;
        final width = frame.width * SecondaryCameraTake.pipWidthFraction;
        final height = width / VideoRecorderDualCameraWindow.aspectRatio;
        final rect = _windowRect(
          center: _dragCenter ?? state.center,
          frame: frame,
          size: Size(width, height),
        );

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
                      frame: frame,
                      size: rect.size,
                    ).shift(details.delta);
                    _dragCenter = _windowRect(
                      center: Offset(
                        moved.center.dx / frame.width,
                        moved.center.dy / frame.height,
                      ),
                      frame: frame,
                      size: rect.size,
                    ).center.scale(1 / frame.width, 1 / frame.height);
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

  /// The window of [size] centered on [center] (fractions of [frame]), kept
  /// inside the frame.
  static Rect _windowRect({
    required Offset center,
    required Size frame,
    required Size size,
  }) {
    final left = (center.dx * frame.width - size.width / 2).clamp(
      0.0,
      (frame.width - size.width).clamp(0.0, double.infinity),
    );
    final top = (center.dy * frame.height - size.height / 2).clamp(
      0.0,
      (frame.height - size.height).clamp(0.0, double.infinity),
    );
    return Offset(left, top) & size;
  }
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
