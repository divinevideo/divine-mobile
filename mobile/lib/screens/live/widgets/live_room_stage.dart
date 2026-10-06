import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/screens/live/widgets/live_room_stage_media_tile.dart';
import 'package:openvine/services/livekit_room_service.dart';

class LiveRoomStage extends StatelessWidget {
  const LiveRoomStage({
    required this.speakerPubkeys,
    required this.audienceCount,
    required this.statusLabel,
    this.mediaState,
    super.key,
  });

  final List<String> speakerPubkeys;
  final int audienceCount;
  final String statusLabel;
  final LiveMediaState? mediaState;

  @override
  Widget build(BuildContext context) {
    final LiveMediaState resolvedMediaState =
        mediaState ??
        context.select((LiveRoomBloc bloc) => bloc.state.mediaState);
    final localParticipantIdentity =
        resolvedMediaState.localParticipantIdentity;
    final hasLocalStagePlaceholder =
        resolvedMediaState.canPublish &&
        localParticipantIdentity != null &&
        speakerPubkeys.contains(localParticipantIdentity);
    final localStageParticipantIdentity = hasLocalStagePlaceholder
        ? localParticipantIdentity
        : null;
    final stageParticipants = resolvedMediaState.stageParticipants.isNotEmpty
        ? resolvedMediaState.stageParticipants
        : <LiveStageParticipant>[
            if (localStageParticipantIdentity != null)
              LiveStageParticipant(
                identity: localStageParticipantIdentity,
                isLocal: true,
              ),
            ...speakerPubkeys
                .where((pubkey) => pubkey != localParticipantIdentity)
                .map(
                  (pubkey) => LiveStageParticipant(
                    identity: pubkey,
                    isLocal: false,
                  ),
                ),
          ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF1B1711),
            Color(0xFF243528),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Stage',
                style: VineTheme.titleLargeFont(),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: VineTheme.scrim15,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: VineTheme.labelLargeFont(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: stageParticipants.isEmpty
                ? <Widget>[
                    Text(
                      'Waiting for speakers to join the stage.',
                      style: VineTheme.bodyMediumFont(
                        color: VineTheme.onSurfaceVariant,
                      ),
                    ),
                  ]
                : stageParticipants
                      .map(
                        (participant) => SizedBox(
                          width: 160,
                          child: LiveRoomStageMediaTile(
                            participant: participant,
                            mediaState: resolvedMediaState,
                          ),
                        ),
                      )
                      .toList(growable: false),
          ),
          const SizedBox(height: 16),
          Text(
            '$audienceCount listeners in the room',
            style: VineTheme.bodyMediumFont(
              color: VineTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
