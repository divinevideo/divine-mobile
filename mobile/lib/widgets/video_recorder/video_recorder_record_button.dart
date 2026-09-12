import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/config/screenshot_mode.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/widgets/video_recorder/shutter_gesture_detector.dart';

/// Circular record button for starting/stopping video recording.
class RecordButton extends ConsumerWidget {
  const RecordButton({this.onBlockedTap, super.key});

  /// When non-null, the button is shown in a disabled (grayed) state and a tap
  /// invokes this callback instead of starting recording. Lip-sync mode uses
  /// this to require an audio selection before recording.
  final VoidCallback? onBlockedTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onBlockedTap = this.onBlockedTap;
    if (onBlockedTap != null) {
      return _BlockedRecordButton(onTap: onBlockedTap);
    }

    final state = context.select(
      (VideoRecorderBloc b) => (
        isRecording: b.state.isRecording,
        timerDuration: b.state.timerDuration,
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
    final startsRecordingOnPressDown = ref.watch(
      holdToRecordPreferenceServiceProvider.select(
        (service) => service.isHoldToRecordEnabled,
      ),
    );

    // Stop-motion captures a still per tap; long-press / hold-to-record would
    // (wrongly) try to start a video recording, so it is disabled.
    final isLongPressSupported =
        state.timerDuration == .off && !state.recorderMode.capturesStills;
    final canStartRecordingOnPressDown =
        isLongPressSupported && startsRecordingOnPressDown;
    // Screenshot builds run on simulators with no camera hardware; the
    // button must still render in its enabled (prominent) state there.
    final isEnabled =
        ScreenshotMode.enabled ||
        (state.canRecord &&
            state.isCameraInitialized &&
            (hasRemainingDuration || !state.recorderMode.hasRecordingLimit)) ||
        state.isRecording;

    return Semantics(
      identifier: SemanticIds.cameraRecordButton,
      button: true,
      enabled: isEnabled,
      tooltip: state.isRecording
          ? context.l10n.videoRecorderStopRecordingTooltip
          : context.l10n.videoRecorderStartRecordingTooltip,
      child: ShutterGestureDetector(
        isEnabled: isEnabled,
        isRecording: state.isRecording,
        isLongPressSupported: isLongPressSupported,
        startsRecordingOnPressDown: canStartRecordingOnPressDown,
        onTapToggle: () => context.read<VideoRecorderBloc>().add(
          const VideoRecorderRecordingToggleRequested(),
        ),
        onLongPressStartRecording: () => context.read<VideoRecorderBloc>().add(
          const VideoRecorderRecordingStartRequested(),
        ),
        onLongPressStopRecording: () => context.read<VideoRecorderBloc>().add(
          const VideoRecorderRecordingStopRequested(),
        ),
        onLongPressZoomStart: isLongPressSupported
            ? () => context.read<VideoRecorderBloc>().add(
                const VideoRecorderLongPressZoomStarted(),
              )
            : null,
        onLongPressMoveUpdate: state.isRecording && isLongPressSupported
            ? (details) => context.read<VideoRecorderBloc>().add(
                VideoRecorderZoomedByLongPress(details.localOffsetFromOrigin),
              )
            : null,
        child: _RecordButtonVisual(
          isEnabled: isEnabled,
          isRecording: state.isRecording,
        ),
      ),
    );
  }
}

/// Record button shown disabled (grayed) with a tap that reports a reason
/// instead of starting recording. Used by lip-sync mode to require an audio
/// selection before recording.
class _BlockedRecordButton extends StatelessWidget {
  const _BlockedRecordButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: SemanticIds.cameraRecordButton,
      button: true,
      tooltip: context.l10n.videoRecorderStartRecordingTooltip,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const _RecordButtonVisual(isEnabled: false, isRecording: false),
      ),
    );
  }
}

/// The visual chrome of the record button: a 96px ring with an inner shape
/// that morphs between the idle dot and the recording square.
class _RecordButtonVisual extends StatelessWidget {
  const _RecordButtonVisual({
    required this.isEnabled,
    required this.isRecording,
  });

  final bool isEnabled;
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isEnabled ? 1.0 : 0.5,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          border: .all(
            color: isRecording ? VineTheme.error : VineTheme.whiteText,
            width: 4,
          ),
          borderRadius: .circular(36),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            width: isRecording ? 32 : 64,
            height: isRecording ? 32 : 64,
            decoration: ShapeDecoration(
              color: VineTheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: .circular(isRecording ? 6 : 20),
              ),
              shadows: const [
                BoxShadow(
                  color: VineTheme.innerShadow,
                  blurRadius: 1,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
