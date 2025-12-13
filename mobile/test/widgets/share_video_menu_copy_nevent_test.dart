// ABOUTME: Tests for ShareVideoMenu copy event ID functionality using nevent format
// ABOUTME: Validates that copy event ID produces NIP-19 nevent bech32 encoding

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';

void main() {
  group('nevent encoding for video events', () {
    const testEventId =
        'a695f6b60119d9521934a691347d9f78e8770b56da16bb255ee77ac112b4c1f6';
    const testAuthorPubkey =
        '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
    const videoEventKind = 34236;

    test('encodes event ID to nevent format with author', () {
      final nevent = NIP19Tlv.encodeNevent(
        Nevent(id: testEventId, author: testAuthorPubkey),
      );

      expect(nevent, startsWith('nevent1'));
      expect(NIP19Tlv.isNevent(nevent), isTrue);
    });

    test('nevent can be decoded back to original values', () {
      final nevent = NIP19Tlv.encodeNevent(
        Nevent(id: testEventId, author: testAuthorPubkey),
      );

      final decoded = NIP19Tlv.decodeNevent(nevent);

      expect(decoded, isNotNull);
      expect(decoded!.id, equals(testEventId));
      expect(decoded.author, equals(testAuthorPubkey));
    });

    test('nevent with relays includes relay hints', () {
      final nevent = NIP19Tlv.encodeNevent(
        Nevent(
          id: testEventId,
          author: testAuthorPubkey,
          relays: ['wss://relay.damus.io', 'wss://nos.lol'],
        ),
      );

      final decoded = NIP19Tlv.decodeNevent(nevent);

      expect(decoded, isNotNull);
      expect(decoded!.relays, isNotNull);
      expect(decoded.relays!.length, equals(2));
      expect(decoded.relays, contains('wss://relay.damus.io'));
      expect(decoded.relays, contains('wss://nos.lol'));
    });

    test(
      'nevent encoding preserves id and author (kind not encoded by SDK)',
      () {
        // Note: The nostr_sdk encodeNevent doesn't encode kind field,
        // but the important fields for sharing are id and author
        final nevent = NIP19Tlv.encodeNevent(
          Nevent(
            id: testEventId,
            author: testAuthorPubkey,
            kind: videoEventKind,
          ),
        );

        final decoded = NIP19Tlv.decodeNevent(nevent);

        expect(decoded, isNotNull);
        expect(decoded!.id, equals(testEventId));
        expect(decoded.author, equals(testAuthorPubkey));
        // Kind is not encoded by the SDK's encodeNevent implementation
      },
    );

    test('video event nevent includes id, author, and relay hints', () {
      // This tests the full nevent encoding that ShareVideoMenu should produce
      final nevent = NIP19Tlv.encodeNevent(
        Nevent(
          id: testEventId,
          author: testAuthorPubkey,
          relays: ['wss://relay.divine.video'],
        ),
      );

      expect(nevent, startsWith('nevent1'));

      final decoded = NIP19Tlv.decodeNevent(nevent);
      expect(decoded, isNotNull);
      expect(decoded!.id, equals(testEventId));
      expect(decoded.author, equals(testAuthorPubkey));
      expect(decoded.relays, contains('wss://relay.divine.video'));
    });

    test('minimal nevent with only event ID works', () {
      // Sometimes we may only have the event ID
      final nevent = NIP19Tlv.encodeNevent(Nevent(id: testEventId));

      expect(nevent, startsWith('nevent1'));

      final decoded = NIP19Tlv.decodeNevent(nevent);
      expect(decoded, isNotNull);
      expect(decoded!.id, equals(testEventId));
    });
  });
}
