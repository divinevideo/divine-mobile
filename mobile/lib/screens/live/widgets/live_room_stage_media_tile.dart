import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as widgets show AspectRatio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/livekit_room_service.dart';
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
      participant: participant,
      mediaState: resolvedMediaState,
    );

    return widgets.AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: VineTheme.scrim15,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: VineTheme.outlineMuted),
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Color(0xFF302B1F),
                      Color(0xFF18231B),
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
                  participant.isLocal ? 'You' : 'On stage',
                  style: VineTheme.labelLargeFont(),
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
                        style: VineTheme.bodyMediumFont().copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      UserName.fromPubKey(
                        participant.identity,
                        style: VineTheme.bodyMediumFont().copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Icon(
                          participant.isMicrophoneEnabled
                              ? Icons.mic_rounded
                              : Icons.mic_off_rounded,
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
  required LiveStageParticipant participant,
  required LiveMediaState mediaState,
}) {
  if (participant.isLocal) {
    if (mediaState.cameraBusy &&
        mediaState.requestedCameraEnabled &&
        mediaState.microphoneBusy &&
        mediaState.requestedMicrophoneEnabled) {
      return 'Starting camera and microphone...';
    }
    if (mediaState.cameraBusy && mediaState.requestedCameraEnabled) {
      return 'Starting camera...';
    }
    if (mediaState.microphoneBusy && mediaState.requestedMicrophoneEnabled) {
      return 'Starting microphone...';
    }
  }

  if (participant.hasVideo && participant.isMicrophoneEnabled) {
    return 'Live video and audio';
  }

  if (participant.hasVideo) {
    return 'Live video';
  }

  if (participant.isMicrophoneEnabled) {
    return 'Live audio only';
  }

  if (participant.isLocal) {
    return 'Camera and mic are off';
  }

  return 'Waiting for media';
}
