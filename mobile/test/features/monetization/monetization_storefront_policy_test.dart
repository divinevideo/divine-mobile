import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/features/monetization/monetization_storefront_policy.dart';

void main() {
  tearDown(() {
    debugUsesAppleAppStoreTipPolicyOverride = null;
  });

  group('monetizationProvidersForCurrentStorefront', () {
    test('allows all providers off iOS', () {
      debugUsesAppleAppStoreTipPolicyOverride = false;

      expect(
        monetizationProvidersForCurrentStorefront(),
        MonetizationLinkProvider.values,
      );
    });

    test('limits iOS storefront providers to tips', () {
      debugUsesAppleAppStoreTipPolicyOverride = true;

      expect(
        monetizationProvidersForCurrentStorefront(),
        [
          MonetizationLinkProvider.cashApp,
          MonetizationLinkProvider.paypal,
          MonetizationLinkProvider.venmo,
        ],
      );
    });
  });

  group('monetizationLinksForCurrentStorefront', () {
    test('uses the provider category rather than profile-supplied labels', () {
      debugUsesAppleAppStoreTipPolicyOverride = true;

      final visible = monetizationLinksForCurrentStorefront([
        const MonetizationLink(
          provider: MonetizationLinkProvider.patreon,
          category: MonetizationLinkCategory.tip,
          url: 'https://www.patreon.com/creator',
          enabled: true,
        ),
      ]);

      expect(visible, isEmpty);
    });

    test('filters subscription links on iOS storefronts', () {
      debugUsesAppleAppStoreTipPolicyOverride = true;

      final visible = monetizationLinksForCurrentStorefront([
        const MonetizationLink(
          provider: MonetizationLinkProvider.cashApp,
          category: MonetizationLinkCategory.tip,
          url: r'https://cash.app/$creator',
          enabled: true,
        ),
        const MonetizationLink(
          provider: MonetizationLinkProvider.patreon,
          category: MonetizationLinkCategory.subscription,
          url: 'https://www.patreon.com/creator',
          enabled: true,
        ),
      ]);

      expect(visible, hasLength(1));
      expect(visible.single.provider, MonetizationLinkProvider.cashApp);
    });
  });
}
