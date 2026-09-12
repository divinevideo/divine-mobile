import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/clip_delete_snackbar.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_actions.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_top_bar.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_shutter_flash.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_countdown_overlay.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_navigation.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_record_button.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_zoom_indicator.dart';

/// Bottom inset that lifts the zoom ruler clear of the record button:
/// the 96px button plus its 24px bottom padding plus a 12px gap.
const double _zoomIndicatorBottomInset = 24.0 + 96.0 + 12.0;

/// Capture-mode stack with viewfinder, controls, and top bar.
class VideoRecorderCaptureStack extends ConsumerWidget {
  const VideoRecorderCaptureStack({
    required this.fromEditor,
    this.topBarCenter,
    this.audioProgressBar,
    this.recordButton = const RecordButton(),
    super.key,
  });

  /// Whether the recorder was opened from the video editor.
  final bool fromEditor;

  /// Optional widget rendered in the top bar between the close and next
  /// buttons. Lip-sync mode uses this slot for the audio-select chip.
  final Widget? topBarCenter;

  /// Optional waveform progress bar overlaid during recording. Lip-sync mode
  /// supplies [VideoRecorderAudioProgressBar]; when set, the top bar's generic
  /// recording-progress bar is suppressed so the two don't overlap.
  final Widget? audioProgressBar;

  /// The record button rendered at the bottom center. Defaults to the standard
  /// [RecordButton]; lip-sync mode supplies one gated on audio selection.
  final Widget recordButton;

  void _deleteLastClip(BuildContext context, WidgetRef ref) {
    unawaited(ref.read(clipManagerProvider.notifier).scheduleDeleteLastClip());
    showClipDeleteSnackbar(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));
    final (
      isRecording,
      recorderMode,
      stopMotionFrameCount,
      stopMotionShutterTick,
    ) = context.select(
      (VideoRecorderBloc b) => (
        b.state.isRecording,
        b.state.recorderMode,
        b.state.stopMotionFrameCount,
        b.state.stopMotionShutterTick,
      ),
    );
    // Stop-motion has no clips during capture; undo removes the last still.
    final canUndo = recorderMode.capturesStills
        ? stopMotionFrameCount > 0
        : hasClips;
    // Fades out (opacity 0) while recording or in the editor-hosted recorder.
    // Opacity alone does not stop hit testing, so the button is also gated
    // with IgnorePointer below — otherwise an invisible tap would silently
    // delete the last still/clip.
    final undoButtonVisible = canUndo && !isRecording && !fromEditor;

    return SafeArea(
      bottom: false,
      child: Stack(
        fit: .expand,
        children: [
          // Camera preview (includes ghost frame)
          const ClipRRect(
            clipBehavior: .hardEdge,
            borderRadius: .vertical(bottom: .circular(32)),
            child: VideoRecorderCameraPreview(),
          ),

          // Shutter blink over the preview so each stop-motion capture is
          // visibly confirmed (the haptic alone is easy to miss).
          if (recorderMode == .stopMotion)
            Positioned.fill(
              child: ClipRRect(
                clipBehavior: .hardEdge,
                borderRadius: const .vertical(bottom: .circular(32)),
                child: VideoRecorderShutterFlash(
                  shutterTick: stopMotionShutterTick,
                ),
              ),
            ),

          // Action buttons
          const Align(
            alignment: .centerRight,
            child: VideoRecorderCaptureActions(),
          ),

          // Zoom ruler — floats above the record button and only appears
          // while the user is pinch-zooming.
          const Align(
            alignment: .bottomCenter,
            child: Padding(
              padding: .fromLTRB(20, 0, 20, _zoomIndicatorBottomInset),
              child: VideoRecorderZoomIndicator(),
            ),
          ),

          /// Record button
          Align(
            alignment: .bottomCenter,
            child: Padding(
              padding: const .fromLTRB(20, 0, 20, 24),
              child: Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: undoButtonVisible ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !undoButtonVisible,
                      child: DivineIconButton(
                        icon: .trash,
                        semanticLabel:
                            context.l10n.videoRecorderDeleteLastClipLabel,
                        semanticIdentifier: SemanticIds.cameraDeleteClipButton,
                        type: .ghostOverMedia,
                        size: .small,
                        onPressed: recorderMode.capturesStills
                            ? () => context.read<VideoRecorderBloc>().add(
                                const VideoRecorderStopMotionFrameUndone(),
                              )
                            : () => _deleteLastClip(context, ref),
                      ),
                    ),
                  ),

                  recordButton,

                  /// Dummy placeholder button
                  const Opacity(
                    opacity: 0,
                    child: IgnorePointer(
                      child: DivineIconButton(
                        icon: .trash,
                        type: .ghostOverMedia,
                        size: .small,
                        onPressed: null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Waveform progress bar overlaid during recording (lip-sync mode).
          ?audioProgressBar,

          // Top bar with close-button and confirm-button
          Align(
            alignment: .topCenter,
            child: VideoRecorderCaptureTopBar(
              fromEditor: fromEditor,
              center: topBarCenter,
              showRecordingProgress: audioProgressBar == null,
            ),
          ),

          // Countdown overlay
          const VideoRecorderCountdownOverlay(),

          // Stop-motion: collects the captured stills into one clip, then opens
          // the editor.
          _StopMotionAssembleListener(fromEditor: fromEditor),
        ],
      ),
    );
  }
}

/// Drives the stop-motion assemble step: navigation to the editor on success,
/// and a snackbar on failure.
///
/// Renders nothing. The assemble collects the captured stills into a clip
/// synchronously and queues the library write, so the `assembling` status never
/// survives a frame — a progress overlay could only ever flash.
class _StopMotionAssembleListener extends ConsumerWidget {
  const _StopMotionAssembleListener({required this.fromEditor});

  final bool fromEditor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocListener<VideoRecorderBloc, VideoRecorderBlocState>(
      listenWhen: (previous, current) =>
          previous.stopMotionStatus != current.stopMotionStatus,
      listener: (context, state) {
        switch (state.stopMotionStatus) {
          case StopMotionStatus.ready:
            if (fromEditor) {
              context.pop(true);
            } else {
              unawaited(openVideoEditorFromRecorder(context, ref));
            }
          case StopMotionStatus.failure:
            ScaffoldMessenger.of(context).showSnackBar(
              DivineSnackbarContainer.snackBar(
                context.l10n.videoRecorderStopMotionAssembleFailed,
                error: true,
              ),
            );
          case StopMotionStatus.idle:
          case StopMotionStatus.assembling:
            break;
        }
      },
      child: const SizedBox.shrink(),
    );
  }
}
