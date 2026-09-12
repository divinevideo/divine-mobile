import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_navigation.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_progress_bar.dart';

/// Top bar for capture mode with close and confirm buttons, replaced by the
/// recording-progress bar while recording.
class VideoRecorderCaptureTopBar extends ConsumerWidget {
  const VideoRecorderCaptureTopBar({
    required this.fromEditor,
    this.center,
    this.showRecordingProgress = true,
    super.key,
  });

  static const _animationDuration = Duration(milliseconds: 220);

  /// Whether the recorder was opened from the video editor.
  final bool fromEditor;

  /// Optional widget rendered between the close and next buttons while not
  /// recording. Lip-sync mode uses this slot for the audio-select chip,
  /// stop-motion for its shot budget.
  final Widget? center;

  /// Whether the thin recording-progress bar is shown while recording.
  ///
  /// Lip-sync mode sets this to `false` because its audio waveform already
  /// conveys recording progress, and the two would overlap.
  final bool showRecordingProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (isRecording, capturesStills, stopMotionFrameCount) = context.select(
      (VideoRecorderBloc b) => (
        b.state.isRecording,
        b.state.recorderMode.capturesStills,
        b.state.stopMotionFrameCount,
      ),
    );
    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));
    // Stop-motion assembles its frames into a clip on "next" rather than
    // navigating straight to the editor.
    final showNext = capturesStills ? stopMotionFrameCount > 0 : hasClips;

    return SafeArea(
      left: false,
      child: AnimatedSwitcher(
        duration: _animationDuration,
        child: isRecording
            ? (showRecordingProgress
                  ? const _RecordingProgressBar()
                  : const SizedBox.shrink())
            : Padding(
                padding: const EdgeInsetsGeometry.fromLTRB(12, 12, 12, 0),
                child: Row(
                  spacing: 12,
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    DivineIconButton(
                      icon: .x,
                      semanticLabel: context.l10n.videoRecorderCloseLabel,
                      semanticIdentifier: SemanticIds.cameraCloseButton,
                      size: .small,
                      type: .ghostOverMedia,
                      onPressed: () => fromEditor
                          ? context.pop(false)
                          : closeVideoRecorder(context, ref),
                    ),
                    ?center,
                    AnimatedOpacity(
                      duration: _animationDuration,
                      opacity: showNext ? 1 : 0,
                      child: DivineIconButton(
                        icon: .caretRight,
                        semanticLabel:
                            context.l10n.videoRecorderContinueToEditorLabel,
                        semanticIdentifier: SemanticIds.cameraNextButton,
                        size: .small,
                        type: .ghostOverMedia,
                        onPressed: capturesStills
                            ? () => context.read<VideoRecorderBloc>().add(
                                const VideoRecorderStopMotionAssembleRequested(),
                              )
                            : () => fromEditor
                                  ? context.pop(true)
                                  : openVideoEditorFromRecorder(context, ref),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _RecordingProgressBar extends ConsumerWidget {
  const _RecordingProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:totalDuration, :activeDuration) = ref.watch(
      clipManagerProvider.select(
        (s) => (
          totalDuration: s.totalDuration,
          activeDuration: s.activeRecordingDuration,
        ),
      ),
    );

    final maxMs = VideoEditorConstants.maxDuration.inMilliseconds;
    final currentMs = (totalDuration + activeDuration).inMilliseconds;
    // Under max: primary fills up, remaining (disabled bg) shrinks.
    // Over max: primary is capped at maxDuration, primaryContainer grows
    // from the right → primary appears to shrink back relatively.
    final primaryMs = currentMs.clamp(0, maxMs);
    final remainingMs = (maxMs - currentMs).clamp(0, maxMs);
    final overflowMs = (currentMs - maxMs).clamp(0, currentMs);

    return Padding(
      padding: const .fromLTRB(18, 16, 18, 0),
      child: VideoRecorderProgressBar(
        filled: primaryMs,
        remaining: remainingMs,
        overflow: overflowMs,
        label: (totalDuration + activeDuration).toMmSs(),
      ),
    );
  }
}
