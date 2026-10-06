import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';

class LiveRoomCard extends StatelessWidget {
  const LiveRoomCard({
    required this.room,
    required this.onTap,
    this.session,
    super.key,
  });

  final LiveRoom room;
  final LiveSession? session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLive = session?.isLive ?? false;
    final audienceCount = session?.audienceCount ?? 0;
    final speakerCount = session?.speakerPubkeys.length ?? 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        key: Key('live-room-card-${room.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isLive ? VineTheme.primary : VineTheme.outlineMuted,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                          color: isLive
                              ? VineTheme.onPrimary
                              : VineTheme.onSurface,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$speakerCount speakers',
                      style: VineTheme.bodySmallFont(
                        color: VineTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  room.title,
                  style: VineTheme.titleLargeFont(),
                ),
                const SizedBox(height: 8),
                Text(
                  room.summary,
                  style: VineTheme.bodyMediumFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Host: ${room.hostPubkey}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VineTheme.bodySmallFont(
                          color: VineTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$audienceCount listening',
                      style: VineTheme.bodySmallFont(
                        color: VineTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
