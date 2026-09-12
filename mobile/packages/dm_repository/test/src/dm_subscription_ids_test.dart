// ABOUTME: Pins every DM relay subscription id inside NIP-01's 64-character
// ABOUTME: cap, which a full hex pubkey behind a prefix already exceeded.

import 'package:dm_repository/src/dm_subscription_ids.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show nip01MaxSubscriptionIdLength;

const _pubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _otherPubkey =
    '2222222222222222222222222222222222222222222222222222222222222222';

void main() {
  group('DM subscription ids', () {
    test("every id fits NIP-01's 64-character cap", () {
      final ids = <String>[
        dmInboxSubscriptionId(_pubkey),
        for (var page = 0; page < 1000; page++) ...[
          dmHistoryDrainSubscriptionId(_pubkey, page),
          dmNip04DrainSubscriptionId(_pubkey, page),
        ],
      ];

      for (final id in ids) {
        expect(
          id.length,
          lessThanOrEqualTo(nip01MaxSubscriptionIdLength),
          reason:
              '"$id" is ${id.length} chars; a relay refuses the REQ '
              'outright above $nip01MaxSubscriptionIdLength',
        );
        expect(id, isNotEmpty, reason: 'NIP-01 also requires non-empty');
      }
    });

    test('the shape that regressed — a raw pubkey — would have failed', () {
      // The three ids this replaced were 73, 75 and 81 characters.
      expect(
        'dm_inbox_$_pubkey'.length,
        greaterThan(nip01MaxSubscriptionIdLength),
      );
      expect(
        'dm_drain_nip04_${_pubkey}_0'.length,
        greaterThan(nip01MaxSubscriptionIdLength),
      );
    });

    test('ids stay distinct per account', () {
      expect(
        dmInboxSubscriptionId(_pubkey),
        isNot(equals(dmInboxSubscriptionId(_otherPubkey))),
      );
      expect(
        dmHistoryDrainSubscriptionId(_pubkey, 0),
        isNot(equals(dmHistoryDrainSubscriptionId(_otherPubkey, 0))),
      );
    });

    test('ids stay distinct per page and per protocol', () {
      expect(
        dmHistoryDrainSubscriptionId(_pubkey, 0),
        isNot(equals(dmHistoryDrainSubscriptionId(_pubkey, 1))),
      );
      expect(
        dmHistoryDrainSubscriptionId(_pubkey, 0),
        isNot(equals(dmNip04DrainSubscriptionId(_pubkey, 0))),
      );
    });

    test('the same account always yields the same id', () {
      expect(
        dmInboxSubscriptionId(_pubkey),
        equals(dmInboxSubscriptionId(_pubkey)),
        reason: 'stopListening unsubscribes by id, so it must be stable',
      );
    });

    test('the account component is a digest, not a shortened pubkey', () {
      final id = dmInboxSubscriptionId(_pubkey);
      final tag = id.substring('dm_inbox_'.length);

      expect(tag, isNotEmpty);
      expect(
        _pubkey.startsWith(tag),
        isFalse,
        reason:
            'a truncated public identifier looks correlatable and is not; '
            'a digest is honestly opaque',
      );
      expect(
        id.contains(_pubkey),
        isFalse,
        reason: 'the raw pubkey must not appear in the id at all',
      );
    });
  });
}
