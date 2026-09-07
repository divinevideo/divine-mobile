// ABOUTME: Tests Nostr secret-key validation against complete NIP-19 input.
// ABOUTME: Prefix-only and malformed values must not pass the import gate.

import 'package:bech32/bech32.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

void main() {
  group('NostrKeyUtils.isValidNsec', () {
    const privateKey =
        '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa';
    const publicKey =
        '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

    test('accepts a valid nsec', () {
      expect(
        NostrKeyUtils.isValidNsec(Nip19.encodePrivateKey(privateKey)),
        isTrue,
      );
    });

    test('rejects malformed text', () {
      expect(NostrKeyUtils.isValidNsec('not-a-secret-key'), isFalse);
    });

    test('rejects a valid npub', () {
      expect(NostrKeyUtils.isValidNsec(Nip19.encodePubKey(publicKey)), isFalse);
    });

    test('rejects an nsec with an invalid checksum', () {
      final characters = Nip19.encodePrivateKey(privateKey).split('');
      characters[characters.length - 1] = characters.last == 'q' ? 'p' : 'q';

      expect(NostrKeyUtils.isValidNsec(characters.join()), isFalse);
    });

    test('rejects a foreign HRP whose text starts with nsec1', () {
      final words = Nip19.convertBits(List<int>.filled(32, 0x67), 8, 5, true);
      final foreignHrpKey = Bech32Encoder().convert(Bech32('nsec1abc', words));

      expect(NostrKeyUtils.isValidNsec(foreignHrpKey), isFalse);
    });

    test('accepts a uniformly uppercase nsec', () {
      final uppercaseNsec = Nip19.encodePrivateKey(privateKey).toUpperCase();

      expect(NostrKeyUtils.isValidNsec(uppercaseNsec), isTrue);
    });
  });
}
