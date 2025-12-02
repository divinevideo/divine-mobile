// ABOUTME: Tests for NIP-19 bech32 encoding and decoding functionality
// ABOUTME: Validates npub, nsec, and note encoding/decoding works correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('NIP-19 Bech32 Encoding Tests', () {
    const testHexPubkey =
        '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
    const testHexPrivateKey =
        '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa';
    const testHexEventId =
        'a695f6b60119d9521934a691347d9f78e8770b56da16bb255ee77ac112b4c1f6';

    test('Encode public key to npub format', () {
      final npub = Nip19.encodePubKey(testHexPubkey);

      expect(npub, startsWith('npub1'));
      expect(npub.length, greaterThan(50));
      expect(Nip19.isPubkey(npub), isTrue);
    });

    test('Decode npub back to hex', () {
      final npub = Nip19.encodePubKey(testHexPubkey);
      final decoded = Nip19.decode(npub);

      expect(decoded, equals(testHexPubkey));
    });

    test('Encode private key to nsec format', () {
      final nsec = Nip19.encodePrivateKey(testHexPrivateKey);

      expect(nsec, startsWith('nsec1'));
      expect(nsec.length, greaterThan(50));
      expect(Nip19.isPrivateKey(nsec), isTrue);
    });

    test('Decode nsec back to hex', () {
      final nsec = Nip19.encodePrivateKey(testHexPrivateKey);
      final decoded = Nip19.decode(nsec);

      expect(decoded, equals(testHexPrivateKey));
    });

    test('Encode event ID to note format', () {
      final note = Nip19.encodeNoteId(testHexEventId);

      expect(note, startsWith('note1'));
      expect(note.length, greaterThan(50));
      expect(Nip19.isNoteId(note), isTrue);
    });

    test('Decode note back to hex', () {
      final note = Nip19.encodeNoteId(testHexEventId);
      final decoded = Nip19.decode(note);

      expect(decoded, equals(testHexEventId));
    });

    test('Simple public key encoding for display', () {
      final simple = Nip19.encodeSimplePubKey(testHexPubkey);

      expect(simple, contains(':'));
      expect(simple.length, lessThan(20));

      // Should start with npub1 prefix and end with last 6 chars
      expect(simple, startsWith('npub1'));
      final parts = simple.split(':');
      expect(parts.length, equals(2));
      expect(parts[0].length, equals(6)); // "npub1" + 2 chars
      expect(parts[1].length, equals(6)); // last 6 chars
    });

    test('Invalid bech32 string detection', () {
      expect(Nip19.isPubkey('invalid'), isFalse);
      expect(Nip19.isPrivateKey('invalid'), isFalse);
      expect(Nip19.isNoteId('invalid'), isFalse);

      expect(Nip19.isPubkey('nsec1...'), isFalse); // Wrong prefix
      expect(Nip19.isPrivateKey('npub1...'), isFalse); // Wrong prefix
    });

    test('Encoding different hex strings produces different results', () {
      final hex1 = '1' * 64;
      final hex2 = '2' * 64;

      final npub1 = Nip19.encodePubKey(hex1);
      final npub2 = Nip19.encodePubKey(hex2);

      expect(npub1, isNot(equals(npub2)));
    });

    test('Round-trip encoding maintains data integrity', () {
      final privateKey = generatePrivateKey();
      final publicKey = getPublicKey(privateKey);

      // Test npub round-trip
      final npub = Nip19.encodePubKey(publicKey);
      final decodedPubkey = Nip19.decode(npub);
      expect(decodedPubkey, equals(publicKey));

      // Test nsec round-trip
      final nsec = Nip19.encodePrivateKey(privateKey);
      final decodedPrivkey = Nip19.decode(nsec);
      expect(decodedPrivkey, equals(privateKey));
    });

    test('Type checking functions work correctly', () {
      final npub = Nip19.encodePubKey(testHexPubkey);
      final nsec = Nip19.encodePrivateKey(testHexPrivateKey);
      final note = Nip19.encodeNoteId(testHexEventId);

      // npub should only be detected as public key
      expect(Nip19.isPubkey(npub), isTrue);
      expect(Nip19.isPrivateKey(npub), isFalse);
      expect(Nip19.isNoteId(npub), isFalse);

      // nsec should only be detected as private key
      expect(Nip19.isPubkey(nsec), isFalse);
      expect(Nip19.isPrivateKey(nsec), isTrue);
      expect(Nip19.isNoteId(nsec), isFalse);

      // note should only be detected as note ID
      expect(Nip19.isPubkey(note), isFalse);
      expect(Nip19.isPrivateKey(note), isFalse);
      expect(Nip19.isNoteId(note), isTrue);
    });

    test('Handle malformed input gracefully', () {
      // decode should handle invalid input gracefully
      final result = Nip19.decode('invalid_bech32');
      expect(result, equals('')); // Should return empty string on error
    });

    test('Bech32 end checking functionality', () {
      // Test the checkBech32End function
      final npub = Nip19.encodePubKey(testHexPubkey);
      final mixedString = '${npub}extra_text';

      final endIndex = Nip19.checkBech32End(mixedString);
      expect(endIndex, isNotNull);
      expect(endIndex!, greaterThan(npub.length));
    });
  });
}
