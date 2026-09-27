// ABOUTME: Tests for MinorAccountReviewStatusStore — whether each account has
// ABOUTME: been seen restricted, gating routing while a fetch runs (#9495).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/services/minor_account_review_status_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(MinorAccountReviewStatusStore, () {
    final pubkey = 'a' * 64;
    final otherPubkey = 'b' * 64;

    late MinorAccountReviewStatusStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = MinorAccountReviewStatusStore(
        prefs: await SharedPreferences.getInstance(),
      );
    });

    MinorAccountReviewStatus restricted() => const MinorAccountReviewStatus(
      restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
    );

    group('lastKnownRestrictedFor', () {
      test('returns null for an account with no recorded fetch', () async {
        await store.remember(otherPubkey, restricted());

        expect(store.lastKnownRestrictedFor(pubkey), isNull);
        expect(store.lastKnownRestrictedFor(null), isNull);
      });
    });

    group('remember', () {
      test('records a restriction for that account only', () async {
        await store.remember(pubkey, restricted());

        expect(store.lastKnownRestrictedFor(pubkey), isTrue);
        expect(store.lastKnownRestrictedFor(otherPubkey), isNull);
      });

      test('records active for an account never seen restricted', () async {
        await store.remember(pubkey, MinorAccountReviewStatus.active());

        expect(store.lastKnownRestrictedFor(pubkey), isFalse);
      });

      test('keeps a restriction when a later fetch returns active', () async {
        await store.remember(pubkey, restricted());
        await store.remember(pubkey, MinorAccountReviewStatus.active());

        expect(store.lastKnownRestrictedFor(pubkey), isTrue);
      });
    });
  });
}
