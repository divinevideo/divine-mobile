import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/live/live_room_recording.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveReplayBanner extends StatelessWidget {
  const LiveReplayBanner({
    required this.recording,
    super.key,
  });

  final LiveRoomRecording recording;

  @override
  Widget build(BuildContext context) {
    final isReady = recording.isReady;
    final statusLabel = switch (recording.status) {
      RecordingStatus.ready => context.l10n.liveReplayReady,
      RecordingStatus.processing => context.l10n.liveReplayProcessing,
      RecordingStatus.pending => context.l10n.liveReplayQueued,
      RecordingStatus.failed => context.l10n.liveReplayUnavailable,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.vineColors.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statusLabel,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isReady
                ? context.l10n.liveReplayReadyDescription
                : context.l10n.liveReplayProcessingDescription,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
          if (isReady) ...[
            const SizedBox(height: 12),
            DivineButton(
              label: context.l10n.liveOpenReplay,
              size: DivineButtonSize.small,
              onPressed: () {
                launchUrl(
                  Uri.parse(recording.playbackUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
