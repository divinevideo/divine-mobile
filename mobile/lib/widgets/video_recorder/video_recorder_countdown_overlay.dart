// ABOUTME: Overlay widget that displays a countdown timer before recording starts
// ABOUTME: Shows large countdown numbers (3, 2, 1) with fade animation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';

/// Fullscreen overlay displaying countdown before recording starts.
///
/// Animates in and out based on the countdown value, counting down to 1.
class VideoRecorderCountdownOverlay extends StatelessWidget {
  /// Creates a countdown overlay widget.
  const VideoRecorderCountdownOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final countdownValue = context.select(
      (VideoRecorderBloc b) => b.state.countdownValue,
    );

    final isActive = countdownValue > 0;

    return IgnorePointer(
      ignoring: !isActive,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: isActive ? 1 : 0,
        child: ColoredBox(
          color: VineTheme.scrim70,
          child: Center(
            child: Text(
              countdownValue.toString(),
              style: VineTheme.displayLargeFont(
                color: VineTheme.whiteText,
              ).copyWith(fontSize: 114),
            ),
          ),
        ),
      ),
    );
  }
}
