import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/services/live_nostr_codec.dart';

void main() {
  group('LiveNostrCodec', () {
    late LiveNostrCodec codec;

    setUp(() {
      codec = const LiveNostrCodec();
    });

    test('parses a live room event from kind 30312', () async {
      final hostPubkey = await _pubkeyFor('a');
      final event = Event(
        hostPubkey,
        30312,
        [
          ['d', 'room-abc'],
          ['title', 'Divine Live'],
          ['image', 'https://example.com/cover.jpg'],
          ['service', 'livekit'],
          ['status', 'open'],
          ['relays', 'wss://relay-one.example', 'wss://relay-two.example'],
        ],
        'Public room for mobile creators',
        createdAt: 1700000000,
      );

      final room = codec.parseRoom(event);

      expect(room.id, 'room-abc');
      expect(room.hostPubkey, hostPubkey);
      expect(room.title, 'Divine Live');
      expect(room.summary, 'Public room for mobile creators');
      expect(room.imageUrl, 'https://example.com/cover.jpg');
      expect(
        room.relays,
        const ['wss://relay-one.example', 'wss://relay-two.example'],
      );
      expect(room.visibility, LiveRoomVisibility.public);
    });

    test('parses NIP-53 room tags when title is published as room', () async {
      final hostPubkey = await _pubkeyFor('a');
      final event = Event(
        hostPubkey,
        30312,
        [
          ['d', 'room-abc'],
          ['room', 'Main Conference Hall'],
          ['summary', 'Our primary conference space'],
          ['status', 'private'],
        ],
        '',
        createdAt: 1700000000,
      );

      final room = codec.parseRoom(event);

      expect(room.title, 'Main Conference Hall');
      expect(room.summary, 'Our primary conference space');
      expect(room.visibility, LiveRoomVisibility.private);
    });

    test('builds a signed room event from a live room model', () async {
      final signer = LocalNostrSigner(_privateKeyFor('a'));
      final hostPubkey = await signer.getPublicKey();
      final room = LiveRoom(
        id: 'room-abc',
        hostPubkey: hostPubkey!,
        title: 'Divine Live',
        summary: 'Public room for mobile creators',
        imageUrl: 'https://example.com/cover.jpg',
        relays: const ['wss://relay-one.example', 'wss://relay-two.example'],
        visibility: LiveRoomVisibility.public,
      );

      final event = await codec.buildRoomEvent(room, signer);

      expect(event.kind, 30312);
      expect(event.pubkey, hostPubkey);
      expect(_tagValue(event.tags, 'd'), 'room-abc');
      expect(_tagValue(event.tags, 'room'), 'Divine Live');
      expect(_tagValue(event.tags, 'status'), 'open');
      expect(
        _tagValues(event.tags, 'relays'),
        const ['wss://relay-one.example', 'wss://relay-two.example'],
      );
      expect(event.content, 'Public room for mobile creators');
      expect(event.isSigned, isTrue);
    });

    test('parses a live session event from kind 30313', () async {
      final hostPubkey = await _pubkeyFor('a');
      final speakerPubkey = await _pubkeyFor('b');
      final audiencePubkey = await _pubkeyFor('c');
      final event = Event(
        hostPubkey,
        30313,
        [
          ['d', 'session-abc'],
          ['a', '30312:$hostPubkey:room-abc', 'wss://relay.example.com'],
          ['title', 'Divine Live Beta'],
          ['starts', '1700000000'],
          ['ends', '1700003600'],
          ['status', 'live'],
          ['current_participants', '42'],
          ['p', hostPubkey, 'wss://relay.example.com', 'Host'],
          ['p', speakerPubkey, 'wss://relay.example.com', 'Speaker'],
          ['p', audiencePubkey, 'wss://relay.example.com', 'Participant'],
        ],
        '',
        createdAt: 1700000100,
      );

      final session = codec.parseSession(event);

      expect(session.id, 'session-abc');
      expect(session.roomId, 'room-abc');
      expect(session.hostPubkey, hostPubkey);
      expect(session.roomAddress, '30312:$hostPubkey:room-abc');
      expect(session.address, '30313:$hostPubkey:session-abc');
      expect(session.status, LiveSessionStatus.live);
      expect(session.startedAt, _dateTimeFromSeconds(1700000000));
      expect(session.endedAt, _dateTimeFromSeconds(1700003600));
      expect(session.speakerPubkeys, [hostPubkey, speakerPubkey]);
      expect(session.audienceCount, 42);
    });

    test('parses a live presence event from kind 10312', () async {
      final hostPubkey = await _pubkeyFor('a');
      final speakerPubkey = await _pubkeyFor('b');
      final event = Event(
        speakerPubkey,
        10312,
        [
          ['a', '30313:$hostPubkey:session-abc', 'wss://relay.example.com'],
          ['role', 'speaker'],
          ['hand', '1'],
        ],
        '',
        createdAt: 1700000200,
      );

      final presence = codec.parsePresence(event);

      expect(presence.sessionId, 'session-abc');
      expect(presence.sessionHostPubkey, hostPubkey);
      expect(presence.sessionAddress, '30313:$hostPubkey:session-abc');
      expect(presence.pubkey, speakerPubkey);
      expect(presence.role, LiveRole.speaker);
      expect(presence.handRaised, isTrue);
      expect(presence.updatedAt, _dateTimeFromSeconds(1700000200));
    });

    test('parses a live chat message from kind 1311', () async {
      final hostPubkey = await _pubkeyFor('a');
      final audiencePubkey = await _pubkeyFor('c');
      final event = Event(
        audiencePubkey,
        1311,
        [
          [
            'a',
            '30313:$hostPubkey:session-abc',
            'wss://relay.example.com',
            'root',
          ],
        ],
        'Zaps to live streams is beautiful.',
        createdAt: 1700000300,
      );

      final message = codec.parseChatMessage(event);

      expect(message.id, event.id);
      expect(message.sessionAddress, '30313:$hostPubkey:session-abc');
      expect(message.pubkey, audiencePubkey);
      expect(message.content, 'Zaps to live streams is beautiful.');
      expect(message.createdAt, _dateTimeFromSeconds(1700000300));
    });
  });
}

String _privateKeyFor(String char) => List.filled(64, char).join();

Future<String> _pubkeyFor(String char) async {
  final signer = LocalNostrSigner(_privateKeyFor(char));
  return (await signer.getPublicKey())!;
}

DateTime _dateTimeFromSeconds(int seconds) {
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

String? _tagValue(List<List<String>> tags, String name) {
  for (final tag in tags) {
    if (tag.isNotEmpty && tag.first == name && tag.length > 1) {
      return tag[1];
    }
  }
  return null;
}

List<String> _tagValues(List<List<String>> tags, String name) {
  for (final tag in tags) {
    if (tag.isNotEmpty && tag.first == name && tag.length > 1) {
      return tag.sublist(1);
    }
  }
  return const [];
}
