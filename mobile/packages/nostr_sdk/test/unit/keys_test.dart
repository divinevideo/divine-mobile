// ABOUTME: Tests private-key validation errors do not disclose key material.
// ABOUTME: Invalid inputs must remain absent from diagnostic representations.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';

void main() {
  group('getPublicKey', () {
    test('does not include an invalid private key in ArgumentError', () {
      const invalidPrivateKey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      expect(
        () => getPublicKey(invalidPrivateKey),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.toString(),
            'diagnostic',
            isNot(contains(invalidPrivateKey)),
          ),
        ),
      );
    });
  });
}
