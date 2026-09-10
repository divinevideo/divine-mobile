import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_actions_bottom.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_actions_top.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_top_bar.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';
import 'package:openvine/widgets/video_recorder/shutter_gesture_detector.dart';

class VideoRecorderClassicStack extends ConsumerWidget {
  const VideoRecorderClassicStack({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = context.select(
      (VideoRecorderBloc b) => (
        isRecording: b.state.isRecording,
        canRecord: b.state.canRecord,
        isCameraInitialized: b.state.isCameraInitialized,
        recorderMode: b.state.recorderMode,
      ),
    );

    final hasRemainingDuration = ref.watch(
      clipManagerProvider.select(
        (p) => p.remainingDuration > const Duration(milliseconds: 30),
      ),
    );

    final isEnabled =
        (state.canRecord &&
            state.isCameraInitialized &&
            (hasRemainingDuration || !state.recorderMode.hasRecordingLimit)) ||
        state.isRecording;

    final startsRecordingOnPressDown = ref.watch(
      holdToRecordPreferenceServiceProvider.select(
        (service) => service.isHoldToRecordEnabled,
      ),
    );

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const VideoRecorderClassicTopBar(),

          Expanded(
            child: Column(
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              spacing: 30,
              children: [
                const VideoRecorderClassicActionsTop(),

                // Camera preview (includes ghost frame)
                Flexible(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Semantics(
                      identifier: SemanticIds.cameraClassicShutter,
                      button: true,
                      // Same value the gesture detector below is gated on, so
                      // the node stops announcing a tappable button once the
                      // shutter is dead — no camera, or the session's 6.3s
                      // budget spent. Mirrors the capture stack's record
                      // button, which has always reported it.
                      enabled: isEnabled,
                      liveRegion: true,
                      label: state.isRecording
                          ? context.l10n.videoRecorderRecordingTapToStopLabel
                          : context.l10n.videoRecorderTapToStartLabel,
                      child: ShutterGestureDetector(
                        isEnabled: isEnabled,
                        isRecording: state.isRecording,
                        behavior: .opaque,
                        startsRecordingOnPressDown: startsRecordingOnPressDown,
                        onTapToggle: () => context
                            .read<VideoRecorderBloc>()
                            .add(const VideoRecorderRecordingToggleRequested()),
                        onLongPressStartRecording: () => context
                            .read<VideoRecorderBloc>()
                            .add(const VideoRecorderRecordingStartRequested()),
                        onLongPressStopRecording: () => context
                            .read<VideoRecorderBloc>()
                            .add(const VideoRecorderRecordingStopRequested()),
                        child: const IgnorePointer(
                          child: VideoRecorderCameraPreview(
                            enableTapToFocus: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const VideoRecorderClassicActionsBottom(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
