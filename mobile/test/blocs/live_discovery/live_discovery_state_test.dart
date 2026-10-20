import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/live_discovery/live_discovery_state.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';

void main() {
  group('LiveDiscoveryState coordinate association', () {
    const host =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const otherHost =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const room = LiveRoom(
      id: 'shared:room',
      hostPubkey: host,
      title: 'Public room',
      summary: '',
      imageUrl: null,
      relays: [],
      visibility: LiveRoomVisibility.public,
    );

    for (final status in [LiveSessionStatus.live, LiveSessionStatus.planned]) {
      for (final sessionHost in [otherHost, null]) {
        test(
          '$status requires the complete room coordinate ($sessionHost)',
          () {
            final session = LiveSession(
              id: 'session',
              roomId: room.id,
              hostPubkey: sessionHost,
              status: status,
              startedAt: DateTime.utc(2026),
              endedAt: null,
              speakerPubkeys: const [],
              audienceCount: 0,
            );
            final state = LiveDiscoveryState(
              rooms: const [room],
              activeSessions: status == LiveSessionStatus.live ? [session] : [],
              upcomingSessions: status == LiveSessionStatus.planned
                  ? [session]
                  : [],
            );
            expect(state.activeRooms, isEmpty);
            expect(state.upcomingRooms, isEmpty);
          },
        );
      }
    }
  });
}
