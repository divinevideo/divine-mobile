// ABOUTME: Maps discovery UI actions to consent-gated canonical analytics.
// ABOUTME: Suggested account identities never enter discovery measurements.
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/services/analytics_service.dart';

Future<void> recordPeopleDiscoveryAction(
  AnalyticsService analytics, {
  required String source,
  required String action,
  required int position,
}) async {
  final eventAction = switch (action) {
    'exposed' => ProductAnalyticsV2PeopleSuggestionAction.exposed,
    'followed' => ProductAnalyticsV2PeopleSuggestionAction.followed,
    'dismissed' => ProductAnalyticsV2PeopleSuggestionAction.dismissed,
    _ => null,
  };
  if (eventAction == null) return;
  await analytics.peopleSuggestionRecorded(
    discoverySource: switch (source) {
      'onboarding' => ProductAnalyticsV2PeopleDiscoverySource.onboarding,
      'feed' => ProductAnalyticsV2PeopleDiscoverySource.feedCard,
      _ => ProductAnalyticsV2PeopleDiscoverySource.findPeople,
    },
    action: eventAction,
    position: position,
  );
}

Future<void> recordPeopleDiscoveryOnboardingSkip(
  AnalyticsService analytics,
) async {
  await analytics.recordOnboardingStep(
    flow: ProductAnalyticsV2OnboardingFlow.viewerSetup,
    step: ProductAnalyticsV2OnboardingStep.followSuggestions,
    result: ProductAnalyticsV2OnboardingResult.skipped,
    reason: ProductAnalyticsV2OnboardingReason.dismissed,
  );
}
