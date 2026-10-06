import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
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
      RecordingStatus.ready => 'Replay ready',
      RecordingStatus.processing => 'Replay processing',
      RecordingStatus.pending => 'Replay queued',
      RecordingStatus.failed => 'Replay unavailable',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statusLabel,
            style: VineTheme.titleMediumFont(),
          ),
          const SizedBox(height: 8),
          Text(
            isReady
                ? 'The live ended, but the replay is ready to watch.'
                : 'The live ended. We are still processing the replay handoff.',
            style: VineTheme.bodyMediumFont(
              color: VineTheme.onSurfaceVariant,
            ),
          ),
          if (isReady) ...[
            const SizedBox(height: 12),
            DivineButton(
              label: 'Open replay',
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
