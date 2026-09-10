// ABOUTME: Tests Subscription construction: filters parse once, so a bad
// ABOUTME: filter fails at subscribe time, and ids stay inside NIP-01's
// ABOUTME: 64-character cap, since a relay enforcing it refuses the REQ.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group(Subscription, () {
    const pubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const otherPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    test('rejects an unparseable filter at construction', () {
      // `kinds` holding strings is the shape a hand-built filter map takes
      // when it skips Filter.toJson. Parsing per event instead would push the
      // TypeError inside RelayPool's frame handler, whose catch-all would
      // swallow it — every event on the subscription silently dropped, no
      // error anywhere. Failing here names the offending caller instead.
      expect(
        () => Subscription([
          {
            'kinds': ['1'],
          },
        ], (_) {}),
        throwsA(isA<TypeError>()),
      );
    });

    test('matches on any one of several filters', () {
      final event = Event(pubkey, 7, const [], '+', createdAt: 1);

      final subscription = Subscription([
        Filter(kinds: const [1]).toJson(),
        Filter(kinds: const [7], authors: const [pubkey]).toJson(),
      ], (_) {});

      expect(subscription.matchesEvent(event), isTrue);
    });

    test('does not match an event outside every filter', () {
      final event = Event(pubkey, 7, const [], '+', createdAt: 1);

      final subscription = Subscription([
        Filter(kinds: const [1]).toJson(),
        Filter(kinds: const [7], authors: const [otherPubkey]).toJson(),
      ], (_) {});

      expect(subscription.matchesEvent(event), isFalse);
    });

    group('id', () {
      Subscription subscriptionWithId(String? id) => Subscription(
        [
          Filter(kinds: const [1]).toJson(),
        ],
        (_) {},
        id: id,
      );

      test('accepts an id at the NIP-01 cap', () {
        final id = 'a' * nip01MaxSubscriptionIdLength;

        expect(subscriptionWithId(id).id, equals(id));
      });

      test('rejects an id longer than NIP-01 allows', () {
        expect(
          () => subscriptionWithId('a' * (nip01MaxSubscriptionIdLength + 1)),
          throwsA(isA<AssertionError>()),
        );
      });

      test('rejects an empty id', () {
        expect(() => subscriptionWithId(''), throwsA(isA<AssertionError>()));
      });

      test('generates an id inside the cap when none is given', () {
        expect(
          subscriptionWithId(null).id.length,
          inInclusiveRange(1, nip01MaxSubscriptionIdLength),
        );
      });
    });
  });

  group('scopedSubscriptionId', () {
    const scope =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const otherScope =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    test('brings every production prefix inside the NIP-01 cap', () {
      // Each repository's own id test runs only when its package changes, so
      // this list guards a builder change that would push one past the cap.
      const prefixes = [
        'comments_watch',
        'dm_drain',
        'dm_drain_nip04',
        'dm_inbox',
        'follow_repo_contact_list',
        'likes_repo_reactions',
        'reposts_repo_reposts',
      ];

      for (final prefix in prefixes) {
        expect(
          scopedSubscriptionId(prefix, scope).length,
          lessThanOrEqualTo(nip01MaxSubscriptionIdLength),
          reason: prefix,
        );
      }
    });

    test('refuses a prefix that leaves no room under the cap', () {
      expect(
        () => scopedSubscriptionId('p' * nip01MaxSubscriptionIdLength, scope),
        throwsA(isA<AssertionError>()),
      );
    });

    test('returns a different id for a different scope', () {
      expect(
        scopedSubscriptionId('comments_watch', scope),
        isNot(equals(scopedSubscriptionId('comments_watch', otherScope))),
      );
    });

    test('keeps the tag the DM subscription ids already use', () {
      // The first 16 hex characters of sha256(scope), as the DM helper
      // computed them before delegating here, so DM ids do not change.
      expect(
        scopedSubscriptionId('dm_inbox', scope),
        equals('dm_inbox_ffe054fe7ae0cb6d'),
      );
    });
  });
}
