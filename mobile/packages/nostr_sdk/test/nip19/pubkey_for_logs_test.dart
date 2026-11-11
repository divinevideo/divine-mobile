// ABOUTME: Tests for pubkeyForLogs, the npub+hex renderer used by log sinks.
// ABOUTME: Pins the no-truncation contract and the non-throwing fallbacks.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';

void main() {
  group('pubkeyForLogs', () {
    const hex =
        '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
    const npub =
        'npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6';

    group('valid hex pubkey', () {
      test('renders the full npub followed by the full hex', () {
        expect(pubkeyForLogs(hex), equals('$npub ($hex)'));
      });

      test('carries both identifiers whole', () {
        final rendered = pubkeyForLogs(hex);

        expect(rendered, contains(hex));
        expect(rendered, contains(npub));
      });

      test('accepts uppercase hex and renders the canonical npub', () {
        expect(pubkeyForLogs(hex.toUpperCase()), contains(npub));
      });
    });

    group('npub input', () {
      test('renders the same npub-then-hex pair as the hex input does', () {
        expect(pubkeyForLogs(npub), equals(pubkeyForLogs(hex)));
      });

      test('carries both identifiers whole', () {
        final rendered = pubkeyForLogs(npub);

        expect(rendered, contains(npub));
        expect(rendered, contains(hex));
      });

      test('returns a malformed npub unchanged and whole', () {
        expect(
          pubkeyForLogs('npub1notvalidbech32'),
          equals('npub1notvalidbech32'),
        );
      });
    });

    group('secrets', () {
      test('redacts an nsec whole rather than shortening it', () {
        const nsec =
            'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

        expect(pubkeyForLogs(nsec), equals('<redacted>'));
      });

      test('redacts an ncryptsec whole', () {
        expect(pubkeyForLogs('ncryptsec1abcdef'), equals('<redacted>'));
      });

      // Bech32 also accepts the all-uppercase form, so a pasted NSEC1 is
      // the same secret.
      test('redacts an uppercase nsec whole', () {
        const nsec =
            'NSEC1VL029MGPSPEDVA04G90VLTKH6FVH240ZQTV9K0T9AF8935KE9LAQSNLFE5';

        expect(pubkeyForLogs(nsec), equals('<redacted>'));
      });

      test('redacts an uppercase ncryptsec whole', () {
        expect(pubkeyForLogs('NCRYPTSEC1ABCDEF'), equals('<redacted>'));
      });
    });

    group('values that cannot be encoded', () {
      test('returns a marker for null', () {
        expect(pubkeyForLogs(null), equals('<null>'));
      });

      test('returns the call site wording for null when given one', () {
        expect(
          pubkeyForLogs(null, whenNull: 'null (legacy)'),
          equals('null (legacy)'),
        );
      });

      test('ignores whenNull when the pubkey is present', () {
        expect(pubkeyForLogs(hex, whenNull: 'nope'), contains(npub));
      });

      test('returns a marker for an empty string', () {
        expect(pubkeyForLogs(''), equals('<empty>'));
      });

      test('returns a short hex unchanged and whole', () {
        expect(pubkeyForLogs('3bf0c63f'), equals('3bf0c63f'));
      });

      test('returns a non-hex value unchanged and whole', () {
        expect(pubkeyForLogs('not-a-pubkey'), equals('not-a-pubkey'));
      });

      test('returns a 64-char non-hex value unchanged and whole', () {
        final notHex = 'z' * 64;

        expect(pubkeyForLogs(notHex), equals(notHex));
      });
    });

    group('log-sink safety', () {
      test('never throws for arbitrary input', () {
        const inputs = <String?>[
          null,
          '',
          ' ',
          '0',
          hex,
          npub,
          'npub1invalid',
          'nsec1definitelynotapubkey',
          '////',
        ];

        for (final input in inputs) {
          expect(() => pubkeyForLogs(input), returnsNormally, reason: '$input');
        }
      });

      test('a fallback value is never shortened', () {
        final long = 'q' * 200;

        expect(pubkeyForLogs(long), equals(long));
      });
    });

    group('round trip', () {
      test('the rendered npub decodes back to the hex it was built from', () {
        final rendered = pubkeyForLogs(hex);
        final encoded = rendered.split(' ').first;

        expect(Nip19.decode(encoded), equals(hex));
      });
    });
  });
}
