// ABOUTME: Bottom bar widget for video recorder screen
// ABOUTME: Contains mode selector wheel and library button

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_library_button.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_mode_selector.dart';

/// The modes the wheel offers when the account may not send private
/// messages: Together rooms run on them, so every invite would fail.
final List<VideoRecorderMode> _modesWithoutTogether = [
  for (final mode in VideoRecorderMode.values)
    if (mode != VideoRecorderMode.together) mode,
];

/// Bottom bar with the recorder mode selector wheel and library button.
class VideoRecorderBottomBar extends ConsumerWidget {
  /// Creates a video recorder bottom bar widget.
  const VideoRecorderBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = context.select(
      (VideoRecorderBloc b) => (
        isShutterActive: b.state.isShutterActive,
        recorderMode: b.state.recorderMode,
      ),
    );
    final dmRestricted = ref.watch(isDmRestrictedProvider);
    if (dmRestricted && state.recorderMode == VideoRecorderMode.together) {
      // Together as the last mode used, before the account was restricted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.read<VideoRecorderBloc>().addIfOpen(
          const VideoRecorderRecorderModeSet(VideoRecorderMode.capture),
        );
      });
    }

    return SafeArea(
      top: false,
      // The bar fades out while recording or capturing on an interval — a mode
      // switch there would discard work the user can't get back. Opacity alone
      // still hit-tests, so the gate has to ignore pointers rather than just
      // fade.
      child: IgnorePointer(
        ignoring: state.isShutterActive,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: state.isShutterActive ? 0 : 1,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Stack(
              alignment: .center,
              children: [
                VideoRecorderModeSelectorWheel(
                  modes: dmRestricted
                      ? _modesWithoutTogether
                      : VideoRecorderMode.values,
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
