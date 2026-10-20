import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

class LiveRoomErrorBanner extends StatelessWidget {
  const LiveRoomErrorBanner({
    required this.message,
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.vineColors.errorContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VineTheme.error),
      ),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

String liveRoomErrorLabel(
  BuildContext context,
  LiveRoomError? error,
) => switch (error) {
  LiveRoomError.requestFailed => context.l10n.liveErrorRequestFailed,
  LiveRoomError.connectionFailed => context.l10n.liveErrorConnectionFailed,
  LiveRoomError.subscriptionFailed => context.l10n.liveErrorSubscriptionFailed,
  LiveRoomError.cameraBlocked => context.l10n.liveErrorCameraBlocked,
  LiveRoomError.cameraRequired => context.l10n.liveErrorCameraRequired,
  LiveRoomError.cameraUnavailable => context.l10n.liveErrorCameraUnavailable,
  LiveRoomError.cameraPromptBlocked =>
    context.l10n.liveErrorCameraPromptBlocked,
  LiveRoomError.microphoneBlocked => context.l10n.liveErrorMicrophoneBlocked,
  LiveRoomError.microphoneRequired => context.l10n.liveErrorMicrophoneRequired,
  LiveRoomError.microphoneUnavailable =>
    context.l10n.liveErrorMicrophoneUnavailable,
  LiveRoomError.microphonePromptBlocked =>
    context.l10n.liveErrorMicrophonePromptBlocked,
  LiveRoomError.speakerCapacityReached =>
    context.l10n.liveErrorSpeakerCapacityReached,
  null => context.l10n.liveUnableToOpenThisLiveRoom,
};
