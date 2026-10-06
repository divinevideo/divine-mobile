// ABOUTME: Pins the people-list author policy independently of profile rules.
// ABOUTME: Covers complete public identifiers, casing and rejected inputs.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/people_list_owner.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';

void main() {
  final owner = 'abcdef' * 10 + 'abcd';
  final npub = NostrKeyUtils.encodePubKey(owner);
  final nprofile = NIP19Tlv.encodeNprofile(
    Nprofile(pubkey: owner, relays: const ['wss://example.invalid']),
  );

  group('normalizePeopleListOwner', () {
    for (final (label, identifier) in [
      ('hex', owner),
      ('uppercase hex', owner.toUpperCase()),
      ('npub', npub),
      ('uppercase npub', npub.toUpperCase()),
      ('nprofile', nprofile),
      ('uppercase nprofile', nprofile.toUpperCase()),
    ]) {
      test('resolves $label to the complete lowercase author', () {
        expect(normalizePeopleListOwner(identifier), owner);
      });
    }

    for (final (label, identifier) in [
      ('empty', ''),
      ('relative profile', 'me'),
      ('malformed', 'not-a-key'),
      ('short hex', 'a' * 63),
      ('non-hex', 'g' * 64),
      ('short npub payload', NostrKeyUtils.encodePubKey('11')),
      (
        'short nprofile payload',
        NIP19Tlv.encodeNprofile(Nprofile(pubkey: '11')),
      ),
      ('mixed-case npub', npub.replaceFirst('npub', 'Npub')),
      ('mixed-case nprofile', nprofile.replaceFirst('nprofile', 'Nprofile')),
      ('private key', 'nsec1invalid'),
    ]) {
      test('rejects $label as a people-list author', () {
        expect(normalizePeopleListOwner(identifier), isNull);
      });
    }

    test('keeps generic profile normalization separate', () {
      expect(
        normalizePublicIdentifier('me', currentUserHex: owner)?.hexPubkey,
        owner,
      );
      expect(normalizePeopleListOwner('me'), isNull);
      final shortNpub = NostrKeyUtils.encodePubKey('11');
      expect(normalizeToHex(shortNpub), '11');
      expect(normalizePeopleListOwner(shortNpub), isNull);
    });
  });
}
