import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart' as keys;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/collab_room/call/collab_room_call_signal.dart';

const _callKey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _otherKey =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _authorKey =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _samKey =
    '4444444444444444444444444444444444444444444444444444444444444444';
final String _author = keys.getPublicKey(_authorKey);
final String _sam = keys.getPublicKey(_samKey);

void main() {
  group(CollabRoomCallChannel, () {
    final authorSigner = LocalNostrSigner(_authorKey);
    final sender = CollabRoomCallChannel(
      _callKey,
      accountPubkey: _author,
      accountSigner: authorSigner,
    );
    final channel = CollabRoomCallChannel(
      _callKey,
      accountPubkey: _sam,
      accountSigner: LocalNostrSigner(_samKey),
    );
    Future<CollabRoomCallSignal?> open(Event event) =>
        channel.open(event, others: {_author});

    final offer = CollabRoomCallSignal(
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

    test('seals the offer for the intended account', () async {
      final event = await sender.seal(offer, recipient: _sam);

      expect(event.kind, collabRoomCallSignalKind);
      expect(event.pubkey, channel.pubkey);
      expect(event.isSigned, isTrue);
      expect(event.content, isNot(contains('v=0')));
      expect(await open(event), offer);
      expect(await channel.open(event, others: const {}), isNull);
      expect(await sender.open(event, others: {_sam}), isNull);
    });

    test('carries the lobby the author describes', () async {
      final lobby = CollabRoomCallSignal(
        type: CollabRoomCallSignalType.lobby,
        from: _author,
        session: 's1',
        to: _sam,
        layout: 'circleTopLeft',
        seats: [_sam, _author],
        revision: 4,
        sentAt: 1700000000000000,
      );

      expect(await open(await sender.seal(lobby, recipient: _sam)), lobby);
    });

    test('ignores a message of another call', () async {
      final other = CollabRoomCallChannel(
        _otherKey,
        accountPubkey: _author,
        accountSigner: authorSigner,
      );
      final event = await other.seal(offer, recipient: _sam);
      expect(await open(event), isNull);
    });

    test('ignores a tampered message', () async {
      final event = await sender.seal(offer, recipient: _sam);
      final tampered = Event.fromJson({
        ...event.toJson(),
        'content': '${event.content}x',
      });
      expect(await open(tampered), isNull);
    });

    Future<Event> sealRaw(Object json) async {
      final signer = LocalNostrSigner(_callKey);
      final payload = await authorSigner.nip44Encrypt(
        _sam,
        jsonEncode(
          json is Map<String, Object?>
              ? {...json, 'room': channel.pubkey, 'to': _sam}
              : json,
        ),
      );
      final content = await signer.nip44Encrypt(
        channel.pubkey,
        jsonEncode({'from': _author, 'to': _sam, 'body': payload}),
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
        expect(await open(await sealRaw(json)), isNull);
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
      expect(await open(event), isNull);
    });
  });

  group(CollabRoomCallSignal, () {
    test('is read by its recipient, or everyone when it has none', () {
      final toSam = CollabRoomCallSignal(
        type: CollabRoomCallSignalType.answer,
        from: _author,
        session: 's',
        to: _sam,
      );
      final toAll = CollabRoomCallSignal(
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
      final offers = [
        if (collabRoomCallOffers(_author, _sam)) _author,
        if (collabRoomCallOffers(_sam, _author)) _sam,
      ];
      expect(offers, hasLength(1));
    });
  });
}
