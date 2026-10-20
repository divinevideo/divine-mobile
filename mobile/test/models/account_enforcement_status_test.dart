// ABOUTME: Tests mapping Funnelcake account status into client enforcement state.
// ABOUTME: Only recognized API statuses become account enforcement state.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/services/account_status_api_client.dart';

void main() {
  group('AccountEnforcementStatus.fromFunnelcake', () {
    test('active reports no restriction', () {
      final status = AccountEnforcementStatus.fromFunnelcake(
        FunnelcakeAccountStatus.active,
      );
      expect(status.kind, AccountEnforcementKind.noRestrictionReported);
      expect(status.isEnforced, isFalse);
    });

    test('suspended and banned are enforced', () {
      expect(
        AccountEnforcementStatus.fromFunnelcake(
          FunnelcakeAccountStatus.suspended,
        ).kind,
        AccountEnforcementKind.suspended,
      );
      expect(
        AccountEnforcementStatus.fromFunnelcake(
          FunnelcakeAccountStatus.banned,
        ).kind,
        AccountEnforcementKind.banned,
      );
    });

    // Funnelcake's self-status API carries no category yet, so nothing it
    // returns may claim one. A category reaching the screen from here would
    // show age-review copy to an account banned for something else.
    test('carries no category, whatever the status', () {
      for (final status in FunnelcakeAccountStatus.values) {
        expect(
          AccountEnforcementStatus.fromFunnelcake(status).category,
          isNull,
          reason: '$status',
        );
      }
    });
  });

  group('AccountEnforcementStatus.isAgeReviewClosure', () {
    test('is a ban in the age-review category', () {
      const status = AccountEnforcementStatus(
        kind: AccountEnforcementKind.banned,
        category: AccountEnforcementCategory.ageReview,
      );
      expect(status.isAgeReviewClosure, isTrue);
    });

    test('is not a ban without a category', () {
      const status = AccountEnforcementStatus(
        kind: AccountEnforcementKind.banned,
      );
      expect(status.isAgeReviewClosure, isFalse);
    });

    // An open case suspends the account and is handled by the review screens,
    // so only the closed (banned) state gets closure copy.
    test('is not a suspension in the age-review category', () {
      const status = AccountEnforcementStatus(
        kind: AccountEnforcementKind.suspended,
        category: AccountEnforcementCategory.ageReview,
      );
      expect(status.isAgeReviewClosure, isFalse);
    });
  });
}
