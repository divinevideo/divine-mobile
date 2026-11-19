import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/collab_room/call/collab_room_call_signal.dart';

const _callKey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _otherKey =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  group(CollabRoomCallChannel, () {
    final channel = CollabRoomCallChannel(_callKey);

    const offer = CollabRoomCallSignal(
      type: CollabRoomCallSignalType.offer,
      from: _author,
      session: 's1',
      to: _sam,
      toSession: 's2',
      sdp: 'v=0',
      sdpType: 'offer',
      micOn: false,
      cameraOn: true,
    );

    test('seals a message only the call key can open', () async {
      final event = await channel.seal(offer);

      expect(event.kind, collabRoomCallSignalKind);
      expect(event.pubkey, channel.pubkey);
      expect(event.isSigned, isTrue);
      expect(event.content, isNot(contains('v=0')));
      expect(await channel.open(event), offer);
    });

    test('carries the lobby the author describes', () async {
      const lobby = CollabRoomCallSignal(
        type: CollabRoomCallSignalType.lobby,
        from: _author,
        session: 's1',
        layout: 'circleTopLeft',
        seats: [_sam, _author],
        revision: 4,
        sentAt: 1700000000000000,
      );

      expect(await channel.open(await channel.seal(lobby)), lobby);
    });

    test('ignores a message of another call', () async {
      final event = await CollabRoomCallChannel(_otherKey).seal(offer);
      expect(await channel.open(event), isNull);
    });

    test('ignores a tampered message', () async {
      final event = await channel.seal(offer);
      final tampered = Event.fromJson({
        ...event.toJson(),
        'content': '${event.content}x',
      });
      expect(await channel.open(tampered), isNull);
    });

    Future<Event> sealRaw(Object json) async {
      final signer = LocalNostrSigner(_callKey);
      final content = await signer.nip44Encrypt(
        channel.pubkey,
        jsonEncode(json),
      );
      return Event(channel.pubkey, collabRoomCallSignalKind, const [], content!)
        ..sign(_callKey);
    }

    for (final (name, json) in [
      ('another version', {'v': 2, 't': 'hello', 'f': _author, 's': 's'}),
      (
        'an unknown type',
        {
          'v': 1,
          't': 'dance',
          'f': _author,
          's': 's',
          'mic': true,
          'cam': false,
        },
      ),
      (
        'a malformed sender',
        {'v': 1, 't': 'hello', 'f': 'x', 's': 's', 'mic': true, 'cam': false},
      ),
      (
        'an offer without a description',
        {
          'v': 1,
          't': 'offer',
          'f': _author,
          's': 's',
          'to': _sam,
          'mic': true,
          'cam': false,
        },
      ),
      ('not an object', ['hello']),
      (
        'a lobby with a malformed seat',
        {
          'v': 1,
          't': 'lobby',
          'f': _author,
          's': 's',
          'mic': true,
          'cam': false,
          'seats': [_author, 'x'],
          'rev': 1,
          'n': 1,
        },
      ),
      (
        'a lobby without a revision',
        {
          'v': 1,
          't': 'lobby',
          'f': _author,
          's': 's',
          'mic': true,
          'cam': false,
          'seats': [_author],
          'n': 1,
        },
      ),
    ]) {
      test('ignores $name', () async {
        expect(await channel.open(await sealRaw(json)), isNull);
      });
    }

    test('ignores a payload that is not JSON', () async {
      final signer = LocalNostrSigner(_callKey);
      final content = await signer.nip44Encrypt(channel.pubkey, 'nope');
      final event = Event(
        channel.pubkey,
        collabRoomCallSignalKind,
        const [],
        content!,
      )..sign(_callKey);
      expect(await channel.open(event), isNull);
    });
  });

  group(CollabRoomCallSignal, () {
    test('is read by its recipient, or everyone when it has none', () {
      const toSam = CollabRoomCallSignal(
        type: CollabRoomCallSignalType.answer,
        from: _author,
        session: 's',
        to: _sam,
      );
      const toAll = CollabRoomCallSignal(
        type: CollabRoomCallSignalType.hello,
        from: _author,
        session: 's',
      );
      expect(toSam.isFor(_sam), isTrue);
      expect(toSam.isFor(_author), isFalse);
      expect(toAll.isFor(_sam), isTrue);
      expect(toAll.isFor(_author), isFalse);
    });
  });

  group('collabRoomCallOffers', () {
    test('lets exactly one of two people offer', () {
      expect(collabRoomCallOffers(_author, _sam), isTrue);
      expect(collabRoomCallOffers(_sam, _author), isFalse);
    });
  });
}
