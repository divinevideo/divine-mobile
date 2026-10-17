import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/live/live_media_state.dart';
import 'package:openvine/screens/live/widgets/live_room_stage_media_tile.dart';

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
        gradient: LinearGradient(
          colors: <Color>[
            context.vineColors.surfaceContainerHigh,
            context.vineColors.surfaceContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  context.l10n.liveStage,
                  style: VineTheme.titleLargeFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: VineTheme.scrim15,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      statusLabel,
                      style: VineTheme.labelLargeFont(
                        color: context.vineColors.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: stageParticipants.isEmpty
                ? <Widget>[
                    Text(
                      context.l10n.liveWaitingForSpeakersToJoinTheStage,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.onSurfaceVariant,
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
            context.l10n.liveRoomListenerCount(audienceCount),
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
