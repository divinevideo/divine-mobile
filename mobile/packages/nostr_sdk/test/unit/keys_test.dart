// ABOUTME: Tests private-key validation errors do not disclose key material.
// ABOUTME: Invalid inputs must remain absent from diagnostic representations.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';

void main() {
  group('getPublicKey', () {
    test('does not include a too-short private key in ArgumentError', () {
      const tooShort =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      expect(
        () => getPublicKey(tooShort),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'privateKey')
              .having((error) => error.invalidValue, 'invalidValue', isNull)
              .having(
                (error) => error.toString(),
                'diagnostic',
                isNot(contains(tooShort)),
              ),
        ),
      );
    });

    test('does not include a non-hex private key in ArgumentError', () {
      const nonHex =
          'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz';

      expect(
        () => getPublicKey(nonHex),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'privateKey')
              .having((error) => error.invalidValue, 'invalidValue', isNull)
              .having(
                (error) => error.toString(),
                'diagnostic',
                isNot(contains(nonHex)),
              ),
        ),
      );
    });
  });
}
