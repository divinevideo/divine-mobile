// ABOUTME: Pins that every shared fixture pubkey is a point on secp256k1, so a
// ABOUTME: test that copies one gets an identity an account could own (#8706).

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';

import 'test_pubkeys.dart';

void main() {
  group('test_pubkeys', () {
    test('every shared constant is a point on the curve', () {
      for (final pubkey in [syntheticTestPubkey, syntheticOtherTestPubkey]) {
        expect(pubkeyIsOnCurve(pubkey), isTrue, reason: pubkey);
      }
    });

    group('testPubkeyFromSeed', () {
      test('returns distinct keys on the curve', () {
        final keys = [
          for (var seed = 1; seed <= 8; seed++) testPubkeyFromSeed(seed),
        ];

        expect(keys.every(pubkeyIsOnCurve), isTrue);
        expect(keys.toSet(), hasLength(keys.length));
      });

      test('returns the same key for the same seed', () {
        expect(testPubkeyFromSeed(3), testPubkeyFromSeed(3));
      });
    });
  });
}
