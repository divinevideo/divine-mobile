// ABOUTME: Tests for UserProfile npub encoding functionality
// ABOUTME: Verifies bech32 npub encoding works correctly for user profiles

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

void main() {
  group('UserProfile npub Encoding', () {
    test('should encode pubkey to npub format', () {
      // Valid 64-character hex pubkey
      const hexPubkey =
          '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';

      final profile = UserProfile(
        pubkey: hexPubkey,
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'test-event',
      );

      // Should return npub1... format
      expect(profile.npub, startsWith('npub1'));

      // Should be decodable back to original hex
      final decodedPubkey = NostrKeyUtils.decode(profile.npub);
      expect(decodedPubkey, equals(hexPubkey));
    });

    test('should fallback to shortPubkey if encoding fails', () {
      // Invalid pubkey (too short)
      const invalidPubkey = 'invalid';

      final profile = UserProfile(
        pubkey: invalidPubkey,
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'test-event',
      );

      // Should fallback to shortPubkey
      expect(profile.npub, equals(profile.shortPubkey));
      expect(profile.npub, equals(invalidPubkey)); // Since it's already short
    });

    test('should handle different valid pubkeys', () {
      const testPubkeys = [
        'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e',
        '70ed6c56d6fb355f102a1e985741b5ee65f6ae9f772e028894b321bc74854082',
        '25315276cbaeb8f2ed998ed55d15ef8c9cf2027baea191d1253d9a5c69a2b856',
      ];

      for (final pubkey in testPubkeys) {
        final profile = UserProfile(
          pubkey: pubkey,
          rawData: const {},
          createdAt: DateTime.now(),
          eventId: 'test-event-$pubkey',
        );

        // All should produce valid npub format
        expect(profile.npub, startsWith('npub1'));

        // All should be reversible
        final decoded = NostrKeyUtils.decode(profile.npub);
        expect(decoded, equals(pubkey));
      }
    });
  });
}
