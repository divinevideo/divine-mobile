import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/live_discovery/live_discovery_bloc.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/screens/live/go_live_page.dart';
import 'package:openvine/screens/live/live_room_detail_page.dart';
import 'package:openvine/screens/live/live_route_data.dart';
import 'package:openvine/screens/live/widgets/live_room_card.dart';

class LiveDiscoveryView extends StatelessWidget {
  const LiveDiscoveryView({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = BlocBuilder<LiveDiscoveryBloc, LiveDiscoveryState>(
      builder: (context, state) {
        final featuredRooms = _featuredRooms(state);
        return switch (state.status) {
          LiveDiscoveryStatus.initial ||
          LiveDiscoveryStatus.loading => const Center(
            child: CircularProgressIndicator(color: VineTheme.primary),
          ),
          LiveDiscoveryStatus.failure => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                state.errorMessage ?? 'Live rooms are unavailable.',
                style: VineTheme.bodyMediumFont(),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          LiveDiscoveryStatus.success => RefreshIndicator(
            onRefresh: () async {
              context.read<LiveDiscoveryBloc>().add(
                const LiveDiscoveryRequested(force: true),
              );
            },
            child: ListView(
              children: [
                if (embedded) const _EmbeddedLiveHeader(),
                const SizedBox(height: 8),
                if (featuredRooms.isNotEmpty)
                  _FeaturedHostsSection(
                    rooms: featuredRooms,
                    sessions: [
                      ...state.activeSessions,
                      ...state.upcomingSessions,
                    ],
                  ),
                _DiscoverySection(
                  title: 'Live now',
                  subtitle: 'Drop into rooms that are already rolling.',
                  rooms: state.activeRooms,
                  sessions: state.activeSessions,
                ),
                _DiscoverySection(
                  title: 'Upcoming',
                  subtitle: 'See what is lined up next.',
                  rooms: state.upcomingRooms,
                  sessions: state.upcomingSessions,
                ),
                if (state.activeRooms.isEmpty && state.upcomingRooms.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No rooms yet. Start the first one.',
                      style: VineTheme.bodyMediumFont(
                        color: VineTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        };
      },
    );

    if (embedded) {
      return ColoredBox(
        color: VineTheme.surfaceBackground,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: AppBar(
        backgroundColor: VineTheme.surfaceBackground,
        title: Text(
          'Live',
          style: VineTheme.headlineSmallFont(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DivineButton(
              label: 'Go live',
              size: DivineButtonSize.small,
              onPressed: () => context.push(GoLivePage.path),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _EmbeddedLiveHeader extends StatelessWidget {
  const _EmbeddedLiveHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live', style: VineTheme.titleLargeFont()),
                const SizedBox(height: 4),
                Text(
                  'See who is live right now or start your own room.',
                  style: VineTheme.bodyMediumFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          DivineButton(
            label: 'Go live',
            size: DivineButtonSize.small,
            onPressed: () => context.push(GoLivePage.path),
          ),
        ],
      ),
    );
  }
}

List<LiveRoom> _featuredRooms(LiveDiscoveryState state) {
  final featuredByHost = <String, LiveRoom>{};
  for (final room in <LiveRoom>[
    ...state.activeRooms,
    ...state.upcomingRooms,
  ]) {
    featuredByHost.putIfAbsent(room.hostPubkey, () => room);
  }
  return featuredByHost.values.toList(growable: false);
}

class _DiscoverySection extends StatelessWidget {
  const _DiscoverySection({
    required this.title,
    required this.subtitle,
    required this.rooms,
    required this.sessions,
  });

  final String title;
  final String subtitle;
  final List<LiveRoom> rooms;
  final List<LiveSession> sessions;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: VineTheme.titleLargeFont()),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Nothing here yet.',
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(title, style: VineTheme.titleLargeFont()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              subtitle,
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
          ),
          ...rooms.map((room) {
            final session = sessions
                .where(
                  (item) =>
                      item.roomAddressKey == room.address ||
                      item.roomId == room.id,
                )
                .fold(
                  null,
                  (LiveSession? previous, LiveSession next) {
                    return previous == null || next.isLive ? next : previous;
                  },
                );

            return LiveRoomCard(
              room: room,
              session: session,
              onTap: () {
                context.push(
                  LiveRoomDetailPage.pathFor(room.id),
                  extra: LiveRoomDetailRouteData(
                    room: room,
                    session: session,
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

class _FeaturedHostsSection extends StatelessWidget {
  const _FeaturedHostsSection({
    required this.rooms,
    required this.sessions,
  });

  final List<LiveRoom> rooms;
  final List<LiveSession> sessions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Featured hosts', style: VineTheme.titleLargeFont()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'A quick scan of the hosts who are live or lined up next.',
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(
            height: 216,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final room = rooms[index];
                final session = sessions
                    .where(
                      (item) =>
                          item.roomAddressKey == room.address ||
                          item.roomId == room.id,
                    )
                    .fold(
                      null,
                      (LiveSession? previous, LiveSession next) {
                        if (previous == null) {
                          return next;
                        }
                        return next.isLive ? next : previous;
                      },
                    );

                return _FeaturedHostCard(
                  room: room,
                  session: session,
                  onTap: () {
                    context.push(
                      LiveRoomDetailPage.pathFor(room.id),
                      extra: LiveRoomDetailRouteData(
                        room: room,
                        session: session,
                      ),
                    );
                  },
                );
              },
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemCount: rooms.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedHostCard extends StatelessWidget {
  const _FeaturedHostCard({
    required this.room,
    required this.session,
    required this.onTap,
  });

  final LiveRoom room;
  final LiveSession? session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLive = session?.isLive ?? false;

    return SizedBox(
      width: 280,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLive ? VineTheme.primary : VineTheme.outlineMuted,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
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
                const SizedBox(height: 12),
                Text(
                  room.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.titleMediumFont(),
                ),
                const SizedBox(height: 8),
                Text(
                  room.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.bodyMediumFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  'Host: ${room.hostPubkey}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.bodySmallFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
