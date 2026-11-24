// ABOUTME: Tests monotonic timestamps for replaceable Nostr video events.
// ABOUTME: Covers published_at/raw-created_at split and now clamping.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/utils/nostr_timestamp.dart';
import 'package:openvine/utils/nostr_replacement_timestamp.dart';

void main() {
  group(nextReplacementCreatedAt, () {
    test('uses raw event created_at when published_at is older', () {
      final previous = VideoEvent(
        id: 'event-id',
        pubkey: 'pubkey',
        createdAt: 1700000000,
        content: 'edited video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        eventCreatedAt: 4102444800,
      );

      expect(nextReplacementCreatedAt(previous), 4102444801);
    });

    test('clamps old replacements up toward current Nostr time', () {
      final before = NostrTimestamp.now();
      final previous = VideoEvent(
        id: 'event-id',
        pubkey: 'pubkey',
        createdAt: 1700000000,
        content: 'old video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        eventCreatedAt: 1700000100,
      );

      final replacementCreatedAt = nextReplacementCreatedAt(previous);
      final after = NostrTimestamp.now();

      expect(replacementCreatedAt, greaterThan(1700000101));
      expect(replacementCreatedAt, greaterThanOrEqualTo(before));
      expect(replacementCreatedAt, lessThanOrEqualTo(after));
    });
  });

  group(nextReplacementCreatedAtAfter, () {
    test('stamps one second after a revision stamped in the future', () {
      expect(nextReplacementCreatedAtAfter(4102444800), 4102444801);
    });

    test('stamps current Nostr time after an old revision', () {
      final before = NostrTimestamp.now();

      final stamp = nextReplacementCreatedAtAfter(1700000100);

      expect(stamp, greaterThanOrEqualTo(before));
      expect(stamp, lessThanOrEqualTo(NostrTimestamp.now()));
    });
  });
}
