// ABOUTME: Shutter-blink overlay confirming a stop-motion still was captured
// ABOUTME: Flashes dark briefly whenever the capture count increases

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// A brief dark blink over the camera preview, fired whenever [shutterTick]
/// increases.
///
/// Stop-motion captures stills without any recording UI change, so without
/// this the only shutter feedback is haptic — easy to miss. A dark blink
/// (rather than white) mirrors hardware camera shutters and is safer for
/// photosensitive users.
class VideoRecorderShutterFlash extends StatefulWidget {
  const VideoRecorderShutterFlash({required this.shutterTick, super.key});

  /// Monotonic shutter counter, bumped the instant the shutter fires (before
  /// the native capture resolves); every increase triggers one blink.
  final int shutterTick;

  @override
  State<VideoRecorderShutterFlash> createState() =>
      _VideoRecorderShutterFlashState();
}

class _VideoRecorderShutterFlashState extends State<VideoRecorderShutterFlash>
    with SingleTickerProviderStateMixin {
  static const _blinkDuration = Duration(milliseconds: 160);
  static const _peakOpacity = 0.85;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _blinkDuration,
  );

  @override
  void didUpdateWidget(VideoRecorderShutterFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shutterTick > oldWidget.shutterTick) {
      _controller
        ..value = 1
        ..reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _controller.value == 0
            ? const SizedBox.shrink()
            : ColoredBox(
                // Flashes over the live camera preview, so it stays dark in
                // both appearance modes.
                color: VineTheme.backgroundCamera.withValues(
                  alpha: _peakOpacity * _controller.value,
                ),
              ),
      ),
    );
  }
}
