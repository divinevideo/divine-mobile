// ABOUTME: Unit tests for Filter's NIP-50 search field and for checkEvent,
// ABOUTME: which backs the RelayPool and NostrClient inbound admission gates.
// ABOUTME: Covers search serialization plus id/author/kind matching rules.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('Filter event matching', () {
    const pubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    test('matches an event by exact id and author', () {
      final event = Event(pubkey, 1, const [], 'hello', createdAt: 1);

      final filter = Filter(ids: [event.id], authors: const [pubkey]);

      expect(filter.checkEvent(event), isTrue);
    });

    test('a blank id or author entry matches nothing', () {
      final event = Event(pubkey, 1, const [], 'hello', createdAt: 1);

      // The discriminator against prefix matching. NIP-01 requires exact
      // 64-character lowercase hex and dropped prefixes from the spec, and
      // every string starts with '' — so under a prefix compare one blank
      // entry silently turns the constraint, and the RelayPool and
      // NostrClient gates built on checkEvent, into pass-throughs. Filter
      // admits whatever it is handed, so this is where that is caught.
      expect(Filter(ids: const ['']).checkEvent(event), isFalse);
      expect(Filter(authors: const ['']).checkEvent(event), isFalse);
    });

    test('rejects a non-matching event id and author', () {
      final event = Event(pubkey, 1, const [], 'hello', createdAt: 1);

      final filter = Filter(ids: const ['bbbb'], authors: const ['cccc']);

      expect(filter.checkEvent(event), isFalse);
    });

    test('matches #t tags exactly and case-sensitively', () {
      final lowercaseEvent = Event(
        pubkey,
        1,
        const [
          ['t', 'skateboarding'],
        ],
        'hello',
        createdAt: 1,
      );
      final mixedCaseEvent = Event(
        pubkey,
        1,
        const [
          ['t', 'Skateboarding'],
        ],
        'hello',
        createdAt: 1,
      );

      final filter = Filter(t: const ['skateboarding']);

      expect(filter.checkEvent(lowercaseEvent), isTrue);
      expect(filter.checkEvent(mixedCaseEvent), isFalse);
    });

    test('matches #m tags exactly', () {
      final audioEvent = Event(
        pubkey,
        1063,
        const [
          ['m', 'audio/wav'],
        ],
        '',
        createdAt: 1,
      );
      final pdfEvent = Event(
        pubkey,
        1063,
        const [
          ['m', 'application/pdf'],
        ],
        '',
        createdAt: 1,
      );
      final untypedEvent = Event(pubkey, 1063, const [], '', createdAt: 1);

      final filter = Filter(m: const ['audio/wav', 'audio/mpeg']);

      expect(filter.checkEvent(audioEvent), isTrue);
      expect(filter.checkEvent(pdfEvent), isFalse);
      expect(filter.checkEvent(untypedEvent), isFalse);
    });
  });

  group('Filter #m serialization', () {
    test('round trips the m tag filter through JSON as #m', () {
      final filter = Filter(kinds: [1063], m: const ['audio/wav']);

      final json = filter.toJson();
      expect(json['#m'], equals(['audio/wav']));

      expect(Filter.fromJson(json).m, equals(['audio/wav']));
    });

    test('omits #m when no m tag filter is set', () {
      final json = Filter(kinds: [1063]).toJson();

      expect(json.containsKey('#m'), isFalse);
      expect(Filter.fromJson(json).m, isNull);
    });
  });

  group('Filter Search Tests', () {
    test('Should serialize search field to JSON', () {
      final filter = Filter(kinds: [1], limit: 10, search: 'bitcoin');

      final json = filter.toJson();

      expect(json['search'], equals('bitcoin'));
      expect(json['kinds'], equals([1]));
      expect(json['limit'], equals(10));
    });

    test('Should deserialize search field from JSON', () {
      final json = {
        'kinds': [1],
        'limit': 20,
        'search': 'nostr protocol',
      };

      final filter = Filter.fromJson(json);

      expect(filter.search, equals('nostr protocol'));
      expect(filter.kinds, equals([1]));
      expect(filter.limit, equals(20));
    });

    test('Should handle null search field', () {
      final filter = Filter(kinds: [1], limit: 10);

      final json = filter.toJson();

      expect(json.containsKey('search'), isFalse);
    });

    test('Should serialize complex search queries', () {
      final filter = Filter(
        kinds: [1, 30023],
        authors: ['pubkey1', 'pubkey2'],
        search: 'bitcoin AND lightning OR "layer 2"',
        since: 1234567890,
        until: 1234567999,
        limit: 50,
      );

      final json = filter.toJson();

      expect(json['search'], equals('bitcoin AND lightning OR "layer 2"'));
      expect(json['kinds'], equals([1, 30023]));
      expect(json['authors'], equals(['pubkey1', 'pubkey2']));
      expect(json['since'], equals(1234567890));
      expect(json['until'], equals(1234567999));
      expect(json['limit'], equals(50));
    });

    test('Round trip serialization preserves search field', () {
      final originalFilter = Filter(
        kinds: [1],
        search: 'test search query',
        limit: 25,
      );

      final json = originalFilter.toJson();
      final deserializedFilter = Filter.fromJson(json);

      expect(deserializedFilter.search, equals(originalFilter.search));
      expect(deserializedFilter.kinds, equals(originalFilter.kinds));
      expect(deserializedFilter.limit, equals(originalFilter.limit));
    });
  });
}
