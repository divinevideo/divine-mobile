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
}
