import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_recording.dart';
import 'package:openvine/models/live/live_session.dart';
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
      backgroundColor: VineTheme.surfaceBackground,
      appBar: AppBar(
        backgroundColor: VineTheme.surfaceBackground,
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }

            context.go(LiveDiscoveryPage.path);
          },
        ),
        title: Text(
          'Room detail',
          style: VineTheme.titleLargeFont(),
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
              gradient: const LinearGradient(
                colors: <Color>[
                  Color(0xFF111A16),
                  Color(0xFF1E2A22),
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
                        : VineTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isLive ? 'Live now' : 'Scheduled',
                    style: VineTheme.labelLargeFont(
                      color: isLive ? VineTheme.onPrimary : VineTheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(room.title, style: VineTheme.headlineSmallFont()),
                const SizedBox(height: 8),
                Text(
                  room.summary,
                  style: VineTheme.bodyLargeFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Host: ${room.hostPubkey}',
                  style: VineTheme.bodyMediumFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${speakerPubkeys.length} speakers · ${currentSession?.audienceCount ?? 0} listeners',
                  style: VineTheme.bodyMediumFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _DetailSection(
            title: 'Schedule',
            child: Text(
              _scheduleLabel(currentSession),
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: 'Speakers',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: speakerPubkeys
                  .map(
                    (pubkey) => Chip(
                      label: Text(pubkey),
                      backgroundColor: VineTheme.surfaceContainerHigh,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 20),
          DivineButton(
            label: isLive ? 'Join live' : 'Open room',
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
            label: 'Share room',
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
        color: VineTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: VineTheme.titleMediumFont()),
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

String _scheduleLabel(LiveSession? session) {
  final currentSession = session;
  if (currentSession == null) {
    return 'No session has been scheduled yet.';
  }

  final formatter = DateFormat('EEE, MMM d • h:mm a');
  final startedAt = formatter.format(currentSession.startedAt.toLocal());
  if (currentSession.isLive) {
    return 'Started $startedAt';
  }
  if (currentSession.hasEnded) {
    final endedAt = currentSession.endedAt == null
        ? startedAt
        : formatter.format(currentSession.endedAt!.toLocal());
    return 'Ended $endedAt';
  }
  return 'Scheduled for $startedAt';
}

Future<void> _shareRoom(BuildContext context, LiveRoom room) async {
  final shareText = '${room.title}\nhttps://divine.video/live/room/${room.id}';
  const subjectPrefix = 'Join';

  try {
    await SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: '$subjectPrefix ${room.title} live on Divine',
      ),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to share room: $error'),
      ),
    );
  }
}
