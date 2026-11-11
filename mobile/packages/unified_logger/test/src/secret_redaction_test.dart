// ABOUTME: Tests for the Nostr private-key patterns and redactNostrPrivateKeys
// ABOUTME: that the log sink and the export sanitizer share (#10385).

import 'package:flutter_test/flutter_test.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  group('redactNostrPrivateKeys', () {
    // NIP-19's published test vectors; they control no real account.
    const nsec =
        'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';
    const npub =
        'npub10elfcs4fr0l0r8af98jlmgdh9c8tcxjvz9qkw038js35mp4dma8qzvjptg';
    const hex =
        '7e7e9c42a91bfef19fa929e5fda1b72e0ebc1a4c1141673e2794234d86addf4e';

    test('removes private keys and keeps every other word as written', () {
      final ncryptsec = 'ncryptsec1${'p' * 40}';

      expect(
        redactNostrPrivateKeys(
          'mail someone@example.com, api_key=abc, $nsec and $ncryptsec',
        ),
        'mail someone@example.com, api_key=abc, [REDACTED] and [REDACTED]',
      );
    });

    test('redacts an uppercase key, which bech32 also accepts', () {
      expect(
        redactNostrPrivateKeys('key ${nsec.toUpperCase()} here'),
        'key [REDACTED] here',
      );
      expect(
        redactNostrPrivateKeys('key NCRYPTSEC1QGQEYAFQWZ here'),
        'key [REDACTED] here',
      );
    });

    // The 52 data characters already hold the whole key; the last six are
    // checksum, so a paste cut short is still the secret.
    test('redacts an nsec missing its checksum', () {
      expect(
        redactNostrPrivateKeys('opened /profile/${nsec.substring(0, 57)}'),
        'opened /profile/[REDACTED]',
      );
    });

    test('leaves public ids whole', () {
      expect(
        redactNostrPrivateKeys('author $npub ($hex)'),
        'author $npub ($hex)',
      );
    });

    test('returns text with no key unchanged', () {
      const text = 'Router redirect: location=/home/0';

      expect(redactNostrPrivateKeys(text), same(text));
    });
  });
}
