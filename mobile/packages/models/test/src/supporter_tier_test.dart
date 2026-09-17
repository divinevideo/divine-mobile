// ABOUTME: Tests for SupporterTier, the store-backed supporter offer model.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(SupporterTier, () {
    const annual = SupporterTier(
      productId: 'divine.supporter.annual',
      title: 'Annual Supporter',
      price: r'$69.99',
      currencyCode: 'USD',
      billingPeriod: SupporterBillingPeriod.annual,
    );

    group('toJson', () {
      test('names the billing period when it is known', () {
        expect(annual.toJson()['billingPeriod'], equals('annual'));
      });

      test('omits the billing period when it is unknown', () {
        const tier = SupporterTier(
          productId: 'divine.supporter.unknown',
          title: 'Supporter',
          price: r'$1.00',
        );
        expect(tier.toJson(), isNot(contains('billingPeriod')));
      });
    });

    group('equality', () {
      test('differs by billing period alone', () {
        const monthly = SupporterTier(
          productId: 'divine.supporter.annual',
          title: 'Annual Supporter',
          price: r'$69.99',
          currencyCode: 'USD',
          billingPeriod: SupporterBillingPeriod.monthly,
        );
        expect(annual, isNot(equals(monthly)));
        expect(annual.hashCode, isNot(equals(monthly.hashCode)));
      });
    });
  });
}
