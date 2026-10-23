// ABOUTME: Keeps monetization event categories aligned with known providers.
// ABOUTME: Profile-supplied category labels cannot reclassify a destination.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/monetization/monetization_analytics.dart';

class _Analytics extends Mock implements AnalyticsEventSink {}

void main() {
  test('uses the provider category for mismatched profile labels', () {
    final analytics = _Analytics();
    when(
      () => analytics.logEvent(
        name: any(named: 'name'),
        parameters: any(named: 'parameters'),
      ),
    ).thenAnswer((_) async {});
    const link = MonetizationLink(
      provider: MonetizationLinkProvider.cashApp,
      category: MonetizationLinkCategory.subscription,
      url: r'https://cash.app/$creator',
      enabled: true,
    );

    trackMonetizationLinkConfigured(analytics: analytics, link: link);
    trackMonetizationOutboundClicked(analytics: analytics, link: link);
    trackMonetizationAffordanceTapped(analytics: analytics, links: [link]);

    for (final name in [
      'monetization_link_configured',
      'monetization_outbound_clicked',
    ]) {
      verify(
        () => analytics.logEvent(
          name: name,
          parameters: {'provider': 'cash_app', 'category': 'tip'},
        ),
      ).called(1);
    }
    verify(
      () => analytics.logEvent(
        name: 'monetization_affordance_tapped',
        parameters: {'link_count': 1, 'tip_count': 1, 'subscription_count': 0},
      ),
    ).called(1);
  });
}
