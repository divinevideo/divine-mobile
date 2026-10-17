import 'package:divine_camera/divine_camera.dart' show DivineCameraLens;
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';

class VideoRecorderClassicActionsBottom extends StatelessWidget {
  const VideoRecorderClassicActionsBottom({super.key});

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(DivineSnackbarContainer.snackBar(message));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.select(
      (VideoRecorderBloc b) => (
        isRecording: b.state.isRecording,
        hasRecordingInFlight: b.state.hasRecordingInFlight,
        canSwitchCamera: b.state.canSwitchCamera,
        isFrontCamera: b.state.isFrontCamera,
        showGridLines: b.state.showGridLines,
        showLastClipOverlay: b.state.showLastClipOverlay,
      ),
    );

    // Faded out is not gone: without this the hidden flip button still takes
    // taps mid-take, and a flip ends the take.
    return IgnorePointer(
      ignoring: state.isRecording,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: state.isRecording ? 0 : 1,
        child: Row(
          spacing: 24,
          mainAxisAlignment: .center,
          children: [
            DivineIconButton(
              icon: .arrowsCounterClockwise,
              semanticLabel: l10n.videoRecorderSwitchCameraLabel,
              semanticIdentifier: SemanticIds.cameraSwitchCameraButton,
              semanticValue: DivineCameraLens.allCamerasFaceUser
                  ? null
                  : state.isFrontCamera
                  ? l10n.videoRecorderCameraValueFront
                  : l10n.videoRecorderCameraValueBack,
              size: .small,
              type: .ghostSecondary,
              // The recorder refuses a flip while a take starts or finishes,
              // and a single usable camera has nothing to flip to, so show it
              // disabled instead of dropping the tap.
              onPressed: state.canSwitchCamera && !state.hasRecordingInFlight
                  ? () => context.read<VideoRecorderBloc>().add(
                      const VideoRecorderCameraSwitched(),
                    )
                  : null,
            ),
            DivineIconButton(
              icon: .gridNine,
              semanticLabel: l10n.videoRecorderToggleGridLabel,
              semanticIdentifier: SemanticIds.cameraGridButton,
              semanticToggled: state.showGridLines,
              size: .small,
              type: .ghostSecondary,
              onPressed: () => context.read<VideoRecorderBloc>().add(
                const VideoRecorderGridLinesToggled(),
              ),
            ),
            DivineIconButton(
              icon: .ghost,
              semanticLabel: l10n.videoRecorderToggleGhostFrameLabel,
              semanticIdentifier: SemanticIds.cameraGhostFrameButton,
              semanticToggled: state.showLastClipOverlay,
              size: .small,
              type: .ghostSecondary,
              onPressed: () {
                final enabled = !state.showLastClipOverlay;
                context.read<VideoRecorderBloc>().add(
                  const VideoRecorderShowLastClipOverlayToggled(),
                );
                _showSnackBar(
                  context,
                  enabled
                      ? l10n.videoRecorderGhostFrameEnabled
                      : l10n.videoRecorderGhostFrameDisabled,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
