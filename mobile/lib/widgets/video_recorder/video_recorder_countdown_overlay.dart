// ABOUTME: Overlay widget that displays the recorder's running countdown
// ABOUTME: Before a delayed take, and between stop-motion's hands-free stills

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/text_scale_limits.dart';

/// Fullscreen overlay displaying the running countdown.
///
/// Before a delayed take it dims the preview and blocks touches until the
/// recording starts. Between the stills of stop-motion's interval loop it
/// does neither: the scene is adjusted against the live preview and the ghost
/// frame then, and the shutter under the overlay is what stops the loop.
class VideoRecorderCountdownOverlay extends StatelessWidget {
  /// Creates a countdown overlay widget.
  const VideoRecorderCountdownOverlay({super.key});

  /// Keeps the number readable over a bright scene once nothing dims it.
  static const _intervalNumberShadows = [
    Shadow(color: VineTheme.scrim70, blurRadius: 16),
  ];

  @override
  Widget build(BuildContext context) {
    final (countdownValue, isIntervalCapture) = context.select(
      (VideoRecorderBloc b) => (
        b.state.countdownValue,
        b.state.isIntervalCaptureRunning,
      ),
    );

    final isActive = countdownValue > 0;

    return IgnorePointer(
      ignoring: !isActive || isIntervalCapture,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: isActive ? 1 : 0,
        child: ColoredBox(
          color: isIntervalCapture ? VineTheme.transparent : VineTheme.scrim70,
          child: Center(
            child: Text(
              countdownValue.toString(),
              textScaler: MediaQuery.textScalerOf(
                context,
              ).clamp(maxScaleFactor: overlayNumeralTextScaleLimit),
              style: VineTheme.displayLargeFont(color: VineTheme.whiteText)
                  .copyWith(
                    fontSize: 114,
                    shadows: isIntervalCapture ? _intervalNumberShadows : null,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
