// ABOUTME: Pins that NIP-19 TLV decoding returns null for a string carrying a
// ABOUTME: malformed entry instead of throwing, and still decodes good ones.

import 'dart:convert';

import 'package:bech32/bech32.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hex/hex.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:nostr_sdk/nip19/tlv_util.dart';

/// Bech32-encodes raw TLV [bytes] under [hrp], so a test can carry entries
/// the encoders here never produce.
String _encode(String hrp, List<int> bytes) => Bech32Encoder().convert(
  Bech32(hrp, Nip19.convertBits(bytes, 8, 5, true)),
  2000,
);

List<int> _entry(int type, List<int> value) => [type, value.length, ...value];

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const eventId =
      'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
  final relay = _entry(TLVType.relay, utf8.encode('wss://relay.example.com'));
  // A relay entry whose one byte cannot appear in well-formed UTF-8.
  const badRelay = [TLVType.relay, 1, 0xff];

  group(NIP19Tlv, () {
    group('decodeNprofile', () {
      test('decodes the pubkey and relays of a well-formed nprofile', () {
        final decoded = NIP19Tlv.decodeNprofile(
          _encode('nprofile', [
            ..._entry(TLVType.defaultType, HEX.decode(pubkey)),
            ...relay,
          ]),
        );

        expect(decoded?.pubkey, equals(pubkey));
        expect(decoded?.relays, equals(['wss://relay.example.com']));
      });

      test('returns null when a relay entry is not valid UTF-8', () {
        final decoded = NIP19Tlv.decodeNprofile(
          _encode('nprofile', [
            ..._entry(TLVType.defaultType, HEX.decode(pubkey)),
            ...badRelay,
          ]),
        );

        expect(decoded, isNull);
      });
    });

    group('decodeNevent', () {
      test('decodes the id, relays and kind of a well-formed nevent', () {
        final decoded = NIP19Tlv.decodeNevent(
          _encode('nevent', [
            ..._entry(TLVType.defaultType, HEX.decode(eventId)),
            ...relay,
            ..._entry(TLVType.kind, [0, 0, 0x85, 0xbc]),
          ]),
        );

        expect(decoded?.id, equals(eventId));
        expect(decoded?.relays, equals(['wss://relay.example.com']));
        expect(decoded?.kind, equals(34236));
      });

      test('returns null when the kind entry is shorter than four bytes', () {
        final decoded = NIP19Tlv.decodeNevent(
          _encode('nevent', [
            ..._entry(TLVType.defaultType, HEX.decode(eventId)),
            ..._entry(TLVType.kind, [0]),
          ]),
        );

        expect(decoded, isNull);
      });

      test('reads the first four bytes of a longer kind entry', () {
        final decoded = NIP19Tlv.decodeNevent(
          _encode('nevent', [
            ..._entry(TLVType.defaultType, HEX.decode(eventId)),
            ..._entry(TLVType.kind, [0, 0, 0x85, 0xbc, 0xff]),
          ]),
        );

        expect(decoded?.kind, equals(34236));
      });

      test('returns null when a relay entry is not valid UTF-8', () {
        final decoded = NIP19Tlv.decodeNevent(
          _encode('nevent', [
            ..._entry(TLVType.defaultType, HEX.decode(eventId)),
            ...badRelay,
          ]),
        );

        expect(decoded, isNull);
      });
    });
  });
}
