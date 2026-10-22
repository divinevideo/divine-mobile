// ABOUTME: Pins that normalizePublicIdentifier rejects a damaged npub or
// ABOUTME: nprofile, that normalizeToHex canonicalizes hex casing so every
// ABOUTME: consumer agrees on identity regardless of deep-link encoding, and
// ABOUTME: that withoutPublicIdentifier excludes by resolved hex, not by text

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';

import '../helpers/test_pubkeys.dart';

void main() {
  const selfHex =
      'abcdef11111111111111111111111111111111111111111111111111111111ff';

  group('normalizePublicIdentifier', () {
    test('decodes an nprofile1 to its pubkey and relay hints', () {
      final nprofile = NIP19Tlv.encodeNprofile(
        Nprofile(pubkey: selfHex, relays: ['wss://relay.example']),
      );

      final normalized = normalizePublicIdentifier(nprofile);

      expect(normalized?.hexPubkey, selfHex);
      expect(normalized?.relayHints, ['wss://relay.example']);
    });

    // A profile link's segment reaches this from route redirects and widget
    // builds, so a damaged reference has to come back as "not a pubkey"
    // rather than as an exception.
    test('returns null for an nprofile1 whose relay entry is malformed', () {
      // Crafted by bech32-encoding the pubkey entry for [selfHex] followed by
      // the relay entry [1, 1, 0xff], whose one byte is not valid UTF-8.
      const nprofile =
          'nprofile1qqs2hn00zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3rlcpq8lsejkj42';

      expect(normalizePublicIdentifier(nprofile), isNull);
    });

    // The decoder answers a failed checksum with an empty string, which is
    // not a pubkey either.
    test('returns null for an npub1 whose checksum does not verify', () {
      expect(normalizePublicIdentifier(syntheticMisspelledNpub), isNull);
    });

    test('returns null for an npub1 that does not carry a 32-byte key', () {
      final shortKey = NostrKeyUtils.encodePubKey('11');

      expect(normalizePublicIdentifier(shortKey), isNull);
    });
  });

  group('normalizeToHex', () {
    // The profile body decides own-vs-other by raw hex equality
    // (profile_screen_router.dart `userIdHex == currentUserHex`), while
    // routeIdentifiesUser compares case-insensitively. Canonicalizing here is
    // what keeps the two from disagreeing on an uppercase-hex deep link.
    test('lowercases an uppercase hex identifier', () {
      expect(normalizeToHex(selfHex.toUpperCase()), selfHex);
    });

    test('returns lowercase hex unchanged', () {
      expect(normalizeToHex(selfHex), selfHex);
    });

    test('decodes an npub to the same canonical hex', () {
      expect(normalizeToHex(NostrKeyUtils.encodePubKey(selfHex)), selfHex);
    });
  });

  group('withoutPublicIdentifier', () {
    const otherHex =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    // A draft written before the collaborator picker excluded the viewer can
    // hold the creator in any encoding it was saved with, so exclusion has to
    // resolve both sides rather than compare the stored text.
    test('removes an entry stored in a different encoding', () {
      expect(
        withoutPublicIdentifier({
          selfHex,
          selfHex.toUpperCase(),
          NostrKeyUtils.encodePubKey(selfHex),
          otherHex,
        }, selfHex),
        {otherHex},
      );
    });

    test('resolves an npub passed as the excluded identifier', () {
      expect(
        withoutPublicIdentifier({
          selfHex,
          otherHex,
        }, NostrKeyUtils.encodePubKey(selfHex)),
        {otherHex},
      );
    });

    test('leaves surviving entries in their original representation', () {
      final npub = NostrKeyUtils.encodePubKey(otherHex);
      expect(withoutPublicIdentifier({npub}, selfHex), {npub});
    });

    // restoreFromDraft passes `currentPublicKeyHex ?? ''`, so a draft restored
    // while signed out must keep every collaborator rather than drop them all.
    test('keeps every entry when the excluded identifier is empty', () {
      expect(withoutPublicIdentifier({selfHex, otherHex}, ''), {
        selfHex,
        otherHex,
      });
    });

    test('keeps every entry when the excluded identifier is unresolvable', () {
      expect(withoutPublicIdentifier({selfHex, otherHex}, 'not-a-pubkey'), {
        selfHex,
        otherHex,
      });
    });

    // Boundary validation belongs to the caller, so an unresolvable entry
    // survives instead of being silently dropped here.
    test('preserves an entry that does not resolve to a pubkey', () {
      expect(withoutPublicIdentifier({'not-a-pubkey', selfHex}, selfHex), {
        'not-a-pubkey',
      });
    });

    test('returns an empty set when every entry is the excluded identity', () {
      expect(
        withoutPublicIdentifier({
          selfHex,
          NostrKeyUtils.encodePubKey(selfHex),
        }, selfHex),
        isEmpty,
      );
    });
  });
}
