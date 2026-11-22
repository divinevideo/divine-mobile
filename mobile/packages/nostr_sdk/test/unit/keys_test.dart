// ABOUTME: Tests private-key validation errors do not disclose key material.
// ABOUTME: Invalid inputs must remain absent from diagnostic representations.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';

void main() {
  group('getPublicKey', () {
    const invalidPrivateKeys = <String, String>{
      'too-short':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'non-hex':
          'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',
    };

    invalidPrivateKeys.forEach((kind, invalidPrivateKey) {
      test('does not include a $kind private key in ArgumentError', () {
        expect(
          () => getPublicKey(invalidPrivateKey),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.name, 'name', 'privateKey')
                .having((error) => error.invalidValue, 'invalidValue', isNull)
                .having(
                  (error) => error.toString(),
                  'diagnostic',
                  isNot(contains(invalidPrivateKey)),
                ),
          ),
        );
      });
    });
  });

  group('pubkeyIsOnCurve', () {
    // x = 5 has no point on secp256k1; its neighbour x = 6 does, so the two
    // differ only in whether the curve passes through them.
    const offCurve =
        '0000000000000000000000000000000000000000000000000000000000000005';
    const onCurveNeighbour =
        '0000000000000000000000000000000000000000000000000000000000000006';

    test('accepts a public key derived from a private key', () {
      expect(pubkeyIsOnCurve(getPublicKey('1' * 63 + '2')), isTrue);
    });

    test("accepts the generator point's x coordinate", () {
      expect(
        pubkeyIsOnCurve(
          '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
        ),
        isTrue,
      );
    });

    test('rejects a well-formed x that no point on the curve has', () {
      expect(keyIsValid(offCurve), isTrue);
      expect(pubkeyIsOnCurve(offCurve), isFalse);
      expect(pubkeyIsOnCurve(onCurveNeighbour), isTrue);
    });

    test('accepts upper-case hex like keyIsValid does', () {
      expect(pubkeyIsOnCurve(onCurveNeighbour.toUpperCase()), isTrue);
    });

    test('rejects an x at or above the field prime', () {
      expect(pubkeyIsOnCurve('f' * 64), isFalse);
    });

    test('rejects zero', () {
      expect(pubkeyIsOnCurve('0' * 64), isFalse);
    });

    test('rejects input that is not 64 hex characters', () {
      expect(pubkeyIsOnCurve(onCurveNeighbour.substring(1)), isFalse);
      expect(pubkeyIsOnCurve('z' * 64), isFalse);
      expect(pubkeyIsOnCurve(''), isFalse);
    });
  });
}
