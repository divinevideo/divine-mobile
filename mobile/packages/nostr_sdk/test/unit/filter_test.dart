// ABOUTME: Unit tests for Filter's lowercase k tag filter, which matches the
// ABOUTME: target kind on a NIP-09 deletion request (and the parent kind on a
// ABOUTME: NIP-22 comment): serialization, parsing and checkEvent matching.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group(Filter, () {
    group('k tag', () {
      const pubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      Event deletionRequest(List<List<String>> tags) =>
          Event(pubkey, EventKind.eventDeletion, tags, '', createdAt: 1000);

      test('serializes k as the #k tag filter', () {
        expect(
          Filter(
            kinds: const [EventKind.eventDeletion],
            k: const ['1111'],
          ).toJson(),
          equals({
            'kinds': [EventKind.eventDeletion],
            '#k': ['1111'],
          }),
        );
      });

      test('parses #k from JSON', () {
        expect(
          Filter.fromJson(const {
            '#k': ['1111'],
          }).k,
          equals(['1111']),
        );
      });

      test('matches an event whose k tag is listed', () {
        final filter = Filter(k: const ['1111', '34236']);

        expect(
          filter.checkEvent(
            deletionRequest([
              ['e', 'x'],
              ['k', '34236'],
            ]),
          ),
          isTrue,
        );
      });

      test('rejects an event whose k tag is not listed', () {
        expect(
          Filter(k: const ['1111']).checkEvent(
            deletionRequest([
              ['k', '7'],
            ]),
          ),
          isFalse,
        );
      });

      test('rejects an event with no k tag', () {
        expect(
          Filter(k: const ['1111']).checkEvent(
            deletionRequest([
              ['e', 'x'],
            ]),
          ),
          isFalse,
        );
      });

      test('does not read an uppercase K tag as k', () {
        expect(
          Filter(k: const ['1111']).checkEvent(
            deletionRequest([
              ['K', '1111'],
            ]),
          ),
          isFalse,
        );
      });
    });
  });
}
