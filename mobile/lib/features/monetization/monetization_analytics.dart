// ABOUTME: Privacy-safe analytics helpers for profile monetization actions.
// ABOUTME: Records provider/category metadata without logging outbound URLs.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:models/models.dart';

void trackMonetizationLinkConfigured({
  required AnalyticsEventSink analytics,
  required MonetizationLink link,
}) {
  unawaited(
    analytics.logEvent(
      name: 'monetization_link_configured',
      parameters: _linkParameters(link),
    ),
  );
}

void trackMonetizationAffordanceTapped({
  required AnalyticsEventSink analytics,
  required Iterable<MonetizationLink> links,
}) {
  final enabledLinks = links.where((link) => link.enabled).toList();
  unawaited(
    analytics.logEvent(
      name: 'monetization_affordance_tapped',
      parameters: {
        'link_count': enabledLinks.length,
        'tip_count': enabledLinks
            .where(
              (link) => link.provider.category == MonetizationLinkCategory.tip,
            )
            .length,
        'subscription_count': enabledLinks
            .where(
              (link) =>
                  link.provider.category ==
                  MonetizationLinkCategory.subscription,
            )
            .length,
      },
    ),
  );
}

void trackMonetizationOutboundClicked({
  required AnalyticsEventSink analytics,
  required MonetizationLink link,
}) {
  unawaited(
    analytics.logEvent(
      name: 'monetization_outbound_clicked',
      parameters: _linkParameters(link),
    ),
  );
}

Map<String, Object> _linkParameters(MonetizationLink link) => {
  'provider': link.provider.value,
  'category': link.provider.category.value,
};
