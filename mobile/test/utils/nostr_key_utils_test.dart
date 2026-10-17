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

  group('NostrKeyUtils.normalizePrivateKeyInput', () {
    final nsec = Nip19.encodePrivateKey(
      '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa',
    );

    test('lowercases an nsec saved with a capitalised first letter', () {
      final capitalised = 'N${nsec.substring(1)}';

      expect(NostrKeyUtils.normalizePrivateKeyInput(capitalised), equals(nsec));
    });

    test('removes line breaks and zero-width characters inside a key', () {
      final pasted =
          ' ${nsec.substring(0, 20)}\u200D${nsec.substring(20, 30)}\n'
          '${nsec.substring(30)}\u2060\u200B\n';

      expect(NostrKeyUtils.normalizePrivateKeyInput(pasted), equals(nsec));
    });

    test('keeps the case of a bunker URL secret', () {
      const bunkerUrl =
          'bunker://3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d'
          '?relay=wss://relay.example.com&secret=AbC123';

      expect(
        NostrKeyUtils.normalizePrivateKeyInput(' $bunkerUrl '),
        equals(bunkerUrl),
      );
    });
  });

  group('NostrKeyUtils.containsPrivateKey', () {
    final nsec = Nip19.encodePrivateKey(
      '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa',
    );
    const publicKey =
        '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

    test('matches a complete nsec', () {
      expect(NostrKeyUtils.containsPrivateKey(nsec), isTrue);
    });

    test('matches an nsec in uppercase or with a capitalised first letter', () {
      expect(NostrKeyUtils.containsPrivateKey(nsec.toUpperCase()), isTrue);
      expect(
        NostrKeyUtils.containsPrivateKey('N${nsec.substring(1)}'),
        isTrue,
      );
    });

    test('matches an nsec among other words', () {
      expect(
        NostrKeyUtils.containsPrivateKey('find my account $nsec please'),
        isTrue,
      );
    });

    test('matches an nsec behind a nostr: prefix', () {
      expect(NostrKeyUtils.containsPrivateKey('nostr:$nsec'), isTrue);
    });

    test('matches an incomplete nsec', () {
      expect(
        NostrKeyUtils.containsPrivateKey(nsec.substring(0, 20)),
        isTrue,
      );
    });

    test('matches an nsec split by zero-width characters', () {
      final pasted =
          'nsec\u200B${nsec.substring(4, 30)}\u2060${nsec.substring(30)}';

      expect(NostrKeyUtils.containsPrivateKey(pasted), isTrue);
    });

    test('matches an ncryptsec', () {
      expect(
        NostrKeyUtils.containsPrivateKey(
          'ncryptsec1qgg9947rlpvqu76pj5ecreduf9j',
        ),
        isTrue,
      );
    });

    test('does not match ordinary search text', () {
      expect(NostrKeyUtils.containsPrivateKey(''), isFalse);
      expect(NostrKeyUtils.containsPrivateKey('nsec'), isFalse);
      expect(NostrKeyUtils.containsPrivateKey('insecure'), isFalse);
      expect(NostrKeyUtils.containsPrivateKey('#nostr'), isFalse);
    });

    test('does not match a public key', () {
      expect(
        NostrKeyUtils.containsPrivateKey(Nip19.encodePubKey(publicKey)),
        isFalse,
      );
      expect(NostrKeyUtils.containsPrivateKey(publicKey), isFalse);
    });
  });
}
