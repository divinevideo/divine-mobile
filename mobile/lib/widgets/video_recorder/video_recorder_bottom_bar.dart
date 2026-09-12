// ABOUTME: Bottom bar widget for video recorder screen
// ABOUTME: Contains mode selector wheel and library button

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_library_button.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_mode_selector.dart';

/// Bottom bar with record button and camera controls.
class VideoRecorderBottomBar extends StatelessWidget {
  /// Creates a video recorder bottom bar widget.
  const VideoRecorderBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select(
      (VideoRecorderBloc b) => (
        isRecording: b.state.isRecording,
        recorderMode: b.state.recorderMode,
      ),
    );

    return SafeArea(
      top: false,
      // The bar fades out while recording — a mode switch there would discard
      // work the user can't get back. Opacity alone still hit-tests, so the
      // gate has to ignore pointers rather than just fade.
      child: IgnorePointer(
        ignoring: state.isRecording,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: state.isRecording ? 0 : 1,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Stack(
              alignment: .center,
              children: [
                VideoRecorderModeSelectorWheel(
                  selectedMode: state.recorderMode,
                  onModeChanged: (mode) => context
                      .read<VideoRecorderBloc>()
                      .add(VideoRecorderRecorderModeSet(mode)),
                ),
                const Align(
                  alignment: .centerLeft,
                  child: VideoRecorderLibraryButton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
