import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart' as widgets show AspectRatio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/live/live_media_state.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';

class LiveRoomStageMediaTile extends ConsumerWidget {
  const LiveRoomStageMediaTile({
    required this.participant,
    this.mediaState,
    super.key,
  });

  final LiveStageParticipant participant;
  final LiveMediaState? mediaState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedMediaState = mediaState ?? const LiveMediaState();
    final profile = ref
        .watch(userProfileReactiveProvider(participant.identity))
        .value;
    final displayName =
        profile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(participant.identity);
    final stageStatus = _liveStageStatusLabel(
      context: context,
      participant: participant,
      mediaState: resolvedMediaState,
    );

    // Stage labels overlay live video on fixed dark scrims in either theme.
    return widgets.AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: VineTheme.scrim15,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.vineColors.outlineMuted),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (participant.videoTrack != null)
              lk.VideoTrackRenderer(
                participant.videoTrack!,
                autoCenter: false,
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      context.vineColors.surfaceContainerHigh,
                      context.vineColors.surfaceContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: UserAvatar(
                    imageUrl: profile?.picture,
                    name: displayName,
                    size: 84,
                  ),
                ),
              ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: VineTheme.scrim30,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  participant.isLocal
                      ? context.l10n.commentAuthorYouIndicator
                      : context.l10n.liveOnStage,
                  style: VineTheme.labelLargeFont(color: VineTheme.whiteText),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VineTheme.scrim30,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (profile != null)
                      UserName.fromUserProfile(
                        profile,
                        style:
                            VineTheme.bodyMediumFont(color: VineTheme.whiteText)
                                .copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      UserName.fromPubKey(
                        participant.identity,
                        style:
                            VineTheme.bodyMediumFont(color: VineTheme.whiteText)
                                .copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        DivineIcon(
                          icon: participant.isMicrophoneEnabled
                              ? DivineIconName.microphone
                              : DivineIconName.speakerSimpleSlash,
                          size: 16,
                          color: participant.isMicrophoneEnabled
                              ? VineTheme.primary
                              : VineTheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            stageStatus,
                            style: VineTheme.bodySmallFont(
                              color: VineTheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _liveStageStatusLabel({
  required BuildContext context,
  required LiveStageParticipant participant,
  required LiveMediaState mediaState,
}) {
  if (participant.isLocal) {
    if (mediaState.cameraBusy &&
        mediaState.requestedCameraEnabled &&
        mediaState.microphoneBusy &&
        mediaState.requestedMicrophoneEnabled) {
      return context.l10n.liveStartingCameraAndMicrophone;
    }
    if (mediaState.cameraBusy && mediaState.requestedCameraEnabled) {
      return context.l10n.liveStartingCamera;
    }
    if (mediaState.microphoneBusy && mediaState.requestedMicrophoneEnabled) {
      return context.l10n.liveStartingMicrophone;
    }
  }

  if (participant.hasVideo && participant.isMicrophoneEnabled) {
    return context.l10n.liveLiveVideoAndAudio;
  }

  if (participant.hasVideo) {
    return context.l10n.liveLiveVideo;
  }

  if (participant.isMicrophoneEnabled) {
    return context.l10n.liveLiveAudioOnly;
  }

  if (participant.isLocal) {
    return context.l10n.liveCameraAndMicAreOff;
  }

  return context.l10n.liveWaitingForMedia;
}
