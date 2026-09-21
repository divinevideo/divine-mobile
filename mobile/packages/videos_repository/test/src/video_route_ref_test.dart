// ABOUTME: Tests VideoRouteRef decoding of every accepted /video/:id form.
// ABOUTME: Pins that bech32 references resolve to an addressable lookup id.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/videos_repository.dart';

void main() {
  const hexId =
      'c218ed9ce99db3c216ca7c70f7a289a3da56fe0b9ba1492b3179db73c8e63a4d';
  const authorHex =
      '81acbb70475b8b715c38d072ce93769ca275783d187990117ec0c01ea849bf95';
  const dTag = 'ip1dd9tAlmw';
  const coordinate = '34236:$authorHex:$dTag';
  // Produced by `nak encode nevent`/`naddr` for the ids above, so these pin
  // the real wire format a shared link carries rather than our own encoder.
  const nevent =
      'nevent1qqsvyx8dnn5emv7zzm98cu8h52y68kjklc9ehg2f9vchnkmnernr5ngvsmkn3';
  const naddr =
      'naddr1qq9kjup3v3jrjazpd3khwq3qsxktkuz8tw9hzhpc6pevaymknj3827parpu'
      'eqyt7crqpa2zfh72sxpqqqzzmcqtynsu';

  group('VideoRouteRef.parse', () {
    test('returns null for an empty or blank reference', () {
      expect(VideoRouteRef.parse(''), isNull);
      expect(VideoRouteRef.parse('   '), isNull);
    });

    test('reads a hex event id as both event id and stable id', () {
      final ref = VideoRouteRef.parse(hexId);

      expect(ref, isNotNull);
      expect(ref!.eventId, equals(hexId));
      expect(ref.stableId, equals(hexId));
      expect(ref.addressableId, isNull);
    });

    test('lowercases an upper-case hex event id', () {
      final ref = VideoRouteRef.parse(hexId.toUpperCase());

      expect(ref!.eventId, equals(hexId));
    });

    test('decodes a note1 reference to its event id', () {
      final ref = VideoRouteRef.parse(Nip19.encodeNoteId(hexId));

      expect(ref, isNotNull);
      expect(ref!.eventId, equals(hexId));
    });

    test('decodes an nevent1 reference to its event id', () {
      final ref = VideoRouteRef.parse(nevent);

      expect(ref, isNotNull);
      expect(ref!.eventId, equals(hexId));
    });

    test('returns null for an nevent1 with a malformed TLV payload', () {
      // Both carry a valid bech32 checksum over a TLV payload that is not:
      // a 1-byte kind entry reaches getInt32, which needs four, and invalid
      // UTF-8 in a relay entry reaches utf8.decode. decodeNevent runs its
      // loop outside any try/catch, so it throws on each — and this parse
      // runs inside a go_router builder, where a throw escapes as Flutter's
      // ErrorWidget instead of the route error screen.
      // Crafted by bech32-encoding the raw TLV bytes [3, 1, 0x00] and
      // [1, 2, 0xff, 0xfe] under the `nevent` HRP.
      expect(VideoRouteRef.parse('nevent1qvqsqxvr2tz'), isNull);
      expect(VideoRouteRef.parse('nevent1qyp0llsk8aj5m'), isNull);
    });

    test('decodes an naddr1 reference to its coordinate and d tag', () {
      final ref = VideoRouteRef.parse(naddr);

      expect(ref, isNotNull);
      expect(ref!.addressableId, equals(coordinate));
      expect(ref.addressablePubkey, equals(authorHex));
      expect(ref.stableId, equals(dTag));
      // An addressable reference names no single version, so there is no
      // event id to carry — the d tag is what the API resolves.
      expect(ref.eventId, isNull);
    });

    test('reads a raw NIP-33 coordinate', () {
      final ref = VideoRouteRef.parse(coordinate);

      expect(ref, isNotNull);
      expect(ref!.addressableId, equals(coordinate));
      expect(ref.addressablePubkey, equals(authorHex));
      expect(ref.stableId, equals(dTag));
    });

    test('treats an unrecognized reference as a first-party stable id', () {
      final ref = VideoRouteRef.parse(dTag);

      expect(ref, isNotNull);
      expect(ref!.stableId, equals(dTag));
      expect(ref.eventId, isNull);
      expect(ref.addressableId, isNull);
    });
  });

  group('VideoRouteRef.lookupId', () {
    test('prefers the event id', () {
      expect(VideoRouteRef.parse(hexId)!.lookupId, equals(hexId));
      expect(VideoRouteRef.parse(nevent)!.lookupId, equals(hexId));
    });

    test('falls back to the stable id for an addressable reference', () {
      // The whole point of the fallback: an naddr carries no event id, and
      // the first-party API resolves the d tag.
      expect(VideoRouteRef.parse(naddr)!.lookupId, equals(dTag));
      expect(VideoRouteRef.parse(coordinate)!.lookupId, equals(dTag));
    });

    test('is null when neither identifier is known', () {
      expect(const VideoRouteRef().lookupId, isNull);
      expect(const VideoRouteRef(eventId: '', stableId: '').lookupId, isNull);
    });
  });
}
