import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_recording.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/live/live_discovery_page.dart';
import 'package:openvine/screens/live/live_route_data.dart';
import 'package:openvine/screens/live/widgets/live_replay_banner.dart';
import 'package:share_plus/share_plus.dart';

class LiveRoomDetailView extends StatelessWidget {
  const LiveRoomDetailView({
    required this.room,
    this.session,
    this.recording,
    super.key,
  });

  final LiveRoom room;
  final LiveSession? session;
  final LiveRoomRecording? recording;

  @override
  Widget build(BuildContext context) {
    final currentSession = session;
    final isLive = currentSession?.isLive ?? false;
    final sessionId = currentSession?.id ?? room.id;
    final speakerPubkeys = _speakerPubkeys(room, currentSession);

    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: AppBar(
        backgroundColor: context.vineColors.surface,
        leading: DivineIconButton(
          icon: DivineIconName.arrowLeft,
          tooltip: context.l10n.commonBack,
          type: DivineIconButtonType.ghostSecondary,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }

            context.go(LiveDiscoveryPage.path);
          },
        ),
        title: Text(
          context.l10n.liveRoomDetail,
          style: VineTheme.titleLargeFont(color: context.vineColors.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (currentSession?.hasEnded == true && recording != null) ...[
            LiveReplayBanner(recording: recording!),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                colors: <Color>[
                  context.vineColors.surfaceContainerHigh,
                  context.vineColors.surfaceContainer,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isLive
                        ? VineTheme.primary
                        : context.vineColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isLive
                        ? context.l10n.liveLiveNow
                        : context.l10n.libraryScheduledSectionTitle,
                    style: VineTheme.labelLargeFont(
                      color: isLive
                          ? VineTheme.onPrimary
                          : context.vineColors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  room.title,
                  style: VineTheme.headlineSmallFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  room.summary,
                  style: VineTheme.bodyLargeFont(
                    color: context.vineColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.liveHostLabel(room.hostPubkey),
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.liveParticipantCounts(
                    speakerPubkeys.length,
                    currentSession?.audienceCount ?? 0,
                  ),
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _DetailSection(
            title: context.l10n.videoMetadataScheduleButton,
            child: Text(
              _scheduleLabel(context, currentSession),
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: context.l10n.liveSpeakers,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: speakerPubkeys
                  .map(
                    (pubkey) => Chip(
                      label: Text(pubkey),
                      backgroundColor: context.vineColors.surfaceContainerHigh,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 20),
          DivineButton(
            label: isLive
                ? context.l10n.liveJoinLive
                : context.l10n.liveOpenRoom,
            expanded: true,
            onPressed: () {
              context.push(
                '/live/room/${room.id}/session/$sessionId',
                extra: LiveRoomRouteData(
                  room: room,
                  session: currentSession,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          DivineButton(
            label: context.l10n.liveShareRoom,
            expanded: true,
            type: DivineButtonType.secondary,
            onPressed: () => _shareRoom(context, room),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.vineColors.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

List<String> _speakerPubkeys(LiveRoom room, LiveSession? session) {
  final speakers = <String>[room.hostPubkey];
  final currentSession = session;
  if (currentSession != null) {
    for (final speakerPubkey in currentSession.speakerPubkeys) {
      if (!speakers.contains(speakerPubkey)) {
        speakers.add(speakerPubkey);
      }
    }
  }
  return speakers;
}

String _scheduleLabel(BuildContext context, LiveSession? session) {
  final currentSession = session;
  if (currentSession == null) {
    return context.l10n.liveNoSessionHasBeenScheduledYet;
  }

  final formatter = DateFormat.yMMMEd(
    Localizations.localeOf(context).toLanguageTag(),
  ).add_jm();
  final startedAt = formatter.format(currentSession.startedAt.toLocal());
  if (currentSession.isLive) {
    return context.l10n.liveStartedAt(startedAt);
  }
  if (currentSession.hasEnded) {
    final endedAt = currentSession.endedAt == null
        ? startedAt
        : formatter.format(currentSession.endedAt!.toLocal());
    return context.l10n.liveEndedAt(endedAt);
  }
  return context.l10n.liveScheduledFor(startedAt);
}

Future<void> _shareRoom(BuildContext context, LiveRoom room) async {
  final shareText =
      '${room.title}\nhttps://divine.video${RoutePaths.liveRoomDetailFor(room.id)}';

  try {
    await SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: context.l10n.liveShareSubject(room.title),
      ),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.liveShareFailed),
      ),
    );
  }
}
