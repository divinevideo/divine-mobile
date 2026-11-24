// ABOUTME: Tests routeIdentifiesUser normalizes every :npub route encoding
// ABOUTME: so own-profile detection survives hex and nprofile deep links

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';

import '../helpers/test_pubkeys.dart';

void main() {
  const selfHex = syntheticTestPubkey;
  const otherHex =
      '2222222222222222222222222222222222222222222222222222222222222222';
  // Encoded rather than pasted: a bech32 literal that does not decode would
  // make the "another user" case pass because npubToHexOrNull returned null,
  // not because the comparison rejected a real, different identity.
  final selfNpub = NostrKeyUtils.encodePubKey(selfHex);
  final otherNpub = NostrKeyUtils.encodePubKey(otherHex);
  final selfNprofile = NIP19Tlv.encodeNprofile(
    Nprofile(pubkey: selfHex, relays: const ['wss://relay.divine.video']),
  );

  group('routeIdentifiesUser', () {
    test('matches the signed-in user by npub', () {
      expect(routeIdentifiesUser(selfNpub, selfHex), isTrue);
    });

    // The defect: a deep link to /profile/<hex> for your own account rendered
    // you as a stranger, because the route segment was compared raw against
    // the signed-in npub.
    test('matches the signed-in user by bare hex', () {
      expect(routeIdentifiesUser(selfHex, selfHex), isTrue);
    });

    test('matches the signed-in user by uppercase hex', () {
      expect(routeIdentifiesUser(selfHex.toUpperCase(), selfHex), isTrue);
    });

    test('matches the signed-in user by nprofile', () {
      expect(routeIdentifiesUser(selfNprofile, selfHex), isTrue);
    });

    test('treats the relative "me" segment as the signed-in user', () {
      expect(routeIdentifiesUser('me', selfHex), isTrue);
    });

    test('does not match another user', () {
      expect(routeIdentifiesUser(otherNpub, selfHex), isFalse);
      expect(routeIdentifiesUser(otherHex, selfHex), isFalse);
    });

    test('is false for a concrete identifier when nobody is signed in', () {
      expect(routeIdentifiesUser(selfNpub, null), isFalse);
      expect(routeIdentifiesUser(selfNpub, ''), isFalse);
      // Both sides undecodable must not collapse into "equal": null == null
      // would report a garbage segment as the signed-out user's own profile.
      expect(routeIdentifiesUser('not-an-identifier', null), isFalse);
    });

    // `me` is relative, so it names the own-profile route structurally, before
    // auth resolves. Gating it on a signed-in pubkey would flash an app bar and
    // back button over your own profile during cold start — the behaviour
    // app_shell_chrome_freeze_test (#5925) pins.
    test('treats "me" as own profile even before auth resolves', () {
      expect(routeIdentifiesUser('me', null), isTrue);
      expect(routeIdentifiesUser('me', ''), isTrue);
    });

    test('is false for a missing or undecodable segment', () {
      expect(routeIdentifiesUser(null, selfHex), isFalse);
      expect(routeIdentifiesUser('', selfHex), isFalse);
      expect(routeIdentifiesUser('not-an-identifier', selfHex), isFalse);
    });
  });
}
