import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/live/live_room.dart';

void main() {
  group('LiveRoom', () {
    test(
      'builds an addressable room identifier from host pubkey and room id',
      () {
        final hostPubkey = List.filled(64, 'a').join();
        final room = LiveRoom(
          id: 'room-abc',
          hostPubkey: hostPubkey,
          title: 'Divine Live',
          summary: 'Public room for mobile creators',
          imageUrl: 'https://example.com/cover.jpg',
          relays: const ['wss://relay.example.com'],
          visibility: LiveRoomVisibility.public,
        );

        expect(room.address, '30312:$hostPubkey:room-abc');
      },
    );

    test('maps NIP-53 room status values to app visibility', () {
      expect(
        LiveRoomVisibility.fromNostrStatus('open'),
        LiveRoomVisibility.public,
      );
      expect(
        LiveRoomVisibility.fromNostrStatus('private'),
        LiveRoomVisibility.private,
      );
      expect(
        LiveRoomVisibility.fromNostrStatus('closed'),
        LiveRoomVisibility.closed,
      );
    });
  });
}
