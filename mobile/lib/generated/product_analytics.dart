// @generated from analytics/event-contract.yaml.
// Source contract commit: aa01966dd9ed6596ad61a974c9b3ba715589e0e5
// DO NOT EDIT. Update the contract and run analytics/codegen/generate.py.
const String productAnalyticsV2ContractCommit =
    'aa01966dd9ed6596ad61a974c9b3ba715589e0e5';
const int productAnalyticsV2SchemaVersion = 2;
const String productAnalyticsV2EventIdAlgorithm = 'sha256-rfc8785-v1';
const bool? productAnalyticsV2ConsentDefaultEnabled = null;

const int productAnalyticsV2ContentImpressionRecordedPositionMinimum = 0;
const int productAnalyticsV2ContentImpressionRecordedPositionMaximum = 10000;
const int productAnalyticsV2ContentImpressionRecordedVisibleMsMinimum = 1000;
const int productAnalyticsV2ContentImpressionRecordedVisibleMsMaximum = 3600000;
const int productAnalyticsV2PlaybackSessionRecordedDurationMsMinimum = 0;
const int productAnalyticsV2PlaybackSessionRecordedDurationMsMaximum = 86400000;
const int productAnalyticsV2PlaybackSessionRecordedWatchedMsMinimum = 0;
const int productAnalyticsV2PlaybackSessionRecordedWatchedMsMaximum = 86400000;
const int productAnalyticsV2PlaybackSessionRecordedLoopCountMinimum = 0;
const int productAnalyticsV2PlaybackSessionRecordedLoopCountMaximum = 1000;
const int productAnalyticsV2FeedDepthRecordedDepthMinimum = 1;
const int productAnalyticsV2FeedDepthRecordedDepthMaximum = 1000000;

enum ProductAnalyticsV2Source {
  mobile('mobile'),
  web('web');

  const ProductAnalyticsV2Source(this.wireName);
  final String wireName;
}

enum ProductAnalyticsV2Platform {
  ios('ios'),
  android('android'),
  web('web');

  const ProductAnalyticsV2Platform(this.wireName);
  final String wireName;
}

enum ProductAnalyticsV2ConsentCategory {
  productAnalytics('product_analytics');

  const ProductAnalyticsV2ConsentCategory(this.wireName);
  final String wireName;
}

enum ProductAnalyticsV2Surface {
  feed('feed'),
  following('following'),
  discovery('discovery'),
  profile('profile'),
  searchResults('search_results'),
  onboarding('onboarding'),
  registration('registration'),
  landing('landing'),
  notifications('notifications'),
  settings('settings'),
  unknown('unknown');

  const ProductAnalyticsV2Surface(this.wireName);
  final String wireName;
}

enum ProductAnalyticsV2PlaybackEndReason {
  ended('ended'),
  paused('paused'),
  navigation('navigation'),
  backgrounded('backgrounded'),
  error('error'),
  unknown('unknown');

  const ProductAnalyticsV2PlaybackEndReason(this.wireName);
  final String wireName;
}

enum ProductAnalyticsV2NavigationAction {
  open('open'),
  back('back'),
  tab('tab'),
  deepLink('deep_link'),
  cta('cta'),
  swipe('swipe'),
  unknown('unknown');

  const ProductAnalyticsV2NavigationAction(this.wireName);
  final String wireName;
}

enum ProductAnalyticsV2OnboardingFlow {
  accountSetup('account_setup'),
  viewerSetup('viewer_setup'),
  creatorSetup('creator_setup');

  const ProductAnalyticsV2OnboardingFlow(this.wireName);
  final String wireName;
}

enum ProductAnalyticsV2OnboardingStep {
  welcome('welcome'),
  identity('identity'),
  interests('interests'),
  followSuggestions('follow_suggestions'),
  notifications('notifications'),
  complete('complete');

  const ProductAnalyticsV2OnboardingStep(this.wireName);
  final String wireName;
}

enum ProductAnalyticsV2OnboardingResult {
  viewed('viewed'),
  completed('completed'),
  skipped('skipped'),
  failed('failed');

  const ProductAnalyticsV2OnboardingResult(this.wireName);
  final String wireName;
}

enum ProductAnalyticsV2OnboardingReason {
  none('none'),
  dismissed('dismissed'),
  validation('validation'),
  network('network'),
  unknown('unknown');

  const ProductAnalyticsV2OnboardingReason(this.wireName);
  final String wireName;
}

enum ProductAnalyticsV2AssignmentSource {
  client('client'),
  server('server');

  const ProductAnalyticsV2AssignmentSource(this.wireName);
  final String wireName;
}

enum ProductAnalyticsV2LandingPage {
  home('home'),
  download('download'),
  invite('invite'),
  registration('registration');

  const ProductAnalyticsV2LandingPage(this.wireName);
  final String wireName;
}

enum ProductAnalyticsV2ReferrerClass {
  direct('direct'),
  search('search'),
  social('social'),
  referral('referral'),
  campaign('campaign'),
  unknown('unknown');

  const ProductAnalyticsV2ReferrerClass(this.wireName);
  final String wireName;
}

enum ProductAnalyticsV2RegistrationEntryPoint {
  landing('landing'),
  invite('invite'),
  deepLink('deep_link'),
  downloadPrompt('download_prompt'),
  unknown('unknown');

  const ProductAnalyticsV2RegistrationEntryPoint(this.wireName);
  final String wireName;
}

enum ProductAnalyticsV2EngagementAction {
  reactionSent('reaction_sent'),
  commentSent('comment_sent'),
  shareTapped('share_tapped'),
  followAdded('follow_added');

  const ProductAnalyticsV2EngagementAction(this.wireName);
  final String wireName;
}

enum ProductAnalyticsV2FeedType {
  home('home'),
  forYou('for_you'),
  following('following'),
  list('list'),
  newVines('new_vines'),
  classics('classics'),
  popular('popular'),
  featured('featured'),
  profile('profile'),
  share('share'),
  search('search'),
  unknown('unknown');

  const ProductAnalyticsV2FeedType(this.wireName);
  final String wireName;
}

class ProductAnalyticsV2Envelope {
  const ProductAnalyticsV2Envelope({
    required this.eventId,
    required this.schemaVersion,
    required this.occurredAt,
    required this.anonymousId,
    required this.sessionId,
    required this.source,
    required this.platform,
    required this.release,
    required this.consentCategory,
  });

  final String eventId;
  final int schemaVersion;
  final DateTime occurredAt;
  final String anonymousId;
  final String sessionId;
  final ProductAnalyticsV2Source source;
  final ProductAnalyticsV2Platform platform;
  final String release;
  final ProductAnalyticsV2ConsentCategory consentCategory;

  Map<String, Object?> toJson() => {
    'event_id': eventId,
    'schema_version': schemaVersion,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'anonymous_id': anonymousId,
    'session_id': sessionId,
    'source': source.wireName,
    'platform': platform.wireName,
    'release': release,
    'consent_category': consentCategory.wireName,
  };
}

/// Wire event name: `content_impression_recorded`.
class ProductAnalyticsV2ContentImpressionRecordedProperties {
  const ProductAnalyticsV2ContentImpressionRecordedProperties({
    required this.contentId,
    required this.surface,
    required this.position,
    required this.visibleMs,
    this.recommendationId,
  });

  final String contentId;
  final ProductAnalyticsV2Surface surface;
  final int position;
  final int visibleMs;
  final String? recommendationId;

  Map<String, Object?> toJson() => {
    'content_id': contentId,
    'surface': surface.wireName,
    'position': position,
    'visible_ms': visibleMs,
    if (recommendationId != null) 'recommendation_id': recommendationId,
  };
}

/// Wire event name: `playback_session_recorded`.
class ProductAnalyticsV2PlaybackSessionRecordedProperties {
  const ProductAnalyticsV2PlaybackSessionRecordedProperties({
    required this.playbackSessionId,
    required this.contentId,
    required this.surface,
    required this.durationMs,
    required this.watchedMs,
    required this.loopCount,
    required this.completed,
    required this.endReason,
  });

  final String playbackSessionId;
  final String contentId;
  final ProductAnalyticsV2Surface surface;
  final int durationMs;
  final int watchedMs;
  final int loopCount;
  final bool completed;
  final ProductAnalyticsV2PlaybackEndReason endReason;

  Map<String, Object?> toJson() => {
    'playback_session_id': playbackSessionId,
    'content_id': contentId,
    'surface': surface.wireName,
    'duration_ms': durationMs,
    'watched_ms': watchedMs,
    'loop_count': loopCount,
    'completed': completed,
    'end_reason': endReason.wireName,
  };
}

/// Wire event name: `navigation_context_recorded`.
class ProductAnalyticsV2NavigationContextRecordedProperties {
  const ProductAnalyticsV2NavigationContextRecordedProperties({
    required this.fromSurface,
    required this.toSurface,
    required this.action,
    this.contentId,
    this.recommendationId,
  });

  final ProductAnalyticsV2Surface fromSurface;
  final ProductAnalyticsV2Surface toSurface;
  final ProductAnalyticsV2NavigationAction action;
  final String? contentId;
  final String? recommendationId;

  Map<String, Object?> toJson() => {
    'from_surface': fromSurface.wireName,
    'to_surface': toSurface.wireName,
    'action': action.wireName,
    if (contentId != null) 'content_id': contentId,
    if (recommendationId != null) 'recommendation_id': recommendationId,
  };
}

/// Wire event name: `onboarding_step_recorded`.
class ProductAnalyticsV2OnboardingStepRecordedProperties {
  const ProductAnalyticsV2OnboardingStepRecordedProperties({
    required this.flow,
    required this.step,
    required this.result,
    this.reason,
  });

  final ProductAnalyticsV2OnboardingFlow flow;
  final ProductAnalyticsV2OnboardingStep step;
  final ProductAnalyticsV2OnboardingResult result;
  final ProductAnalyticsV2OnboardingReason? reason;

  Map<String, Object?> toJson() => {
    'flow': flow.wireName,
    'step': step.wireName,
    'result': result.wireName,
    if (reason != null) 'reason': reason?.wireName,
  };
}

/// Wire event name: `experiment_exposure`.
class ProductAnalyticsV2ExperimentExposureProperties {
  const ProductAnalyticsV2ExperimentExposureProperties({
    required this.experimentKey,
    required this.variantKey,
    required this.assignmentSource,
  });

  final String experimentKey;
  final String variantKey;
  final ProductAnalyticsV2AssignmentSource assignmentSource;

  Map<String, Object?> toJson() => {
    'experiment_key': experimentKey,
    'variant_key': variantKey,
    'assignment_source': assignmentSource.wireName,
  };
}

/// Wire event name: `landing_viewed`.
class ProductAnalyticsV2LandingViewedProperties {
  const ProductAnalyticsV2LandingViewedProperties({
    required this.landingPage,
    required this.referrerClass,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmContent,
  });

  final ProductAnalyticsV2LandingPage landingPage;
  final ProductAnalyticsV2ReferrerClass referrerClass;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? utmContent;

  Map<String, Object?> toJson() => {
    'landing_page': landingPage.wireName,
    'referrer_class': referrerClass.wireName,
    if (utmSource != null) 'utm_source': utmSource,
    if (utmMedium != null) 'utm_medium': utmMedium,
    if (utmCampaign != null) 'utm_campaign': utmCampaign,
    if (utmContent != null) 'utm_content': utmContent,
  };
}

/// Wire event name: `registration_started`.
class ProductAnalyticsV2RegistrationStartedProperties {
  const ProductAnalyticsV2RegistrationStartedProperties({
    required this.entryPoint,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmContent,
  });

  final ProductAnalyticsV2RegistrationEntryPoint entryPoint;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? utmContent;

  Map<String, Object?> toJson() => {
    'entry_point': entryPoint.wireName,
    if (utmSource != null) 'utm_source': utmSource,
    if (utmMedium != null) 'utm_medium': utmMedium,
    if (utmCampaign != null) 'utm_campaign': utmCampaign,
    if (utmContent != null) 'utm_content': utmContent,
  };
}

/// Wire event name: `engagement_recorded`.
class ProductAnalyticsV2EngagementRecordedProperties {
  const ProductAnalyticsV2EngagementRecordedProperties({
    required this.action,
    this.contentId,
  });

  final ProductAnalyticsV2EngagementAction action;
  final String? contentId;

  Map<String, Object?> toJson() => {
    'action': action.wireName,
    if (contentId != null) 'content_id': contentId,
  };
}

/// Wire event name: `feed_depth_recorded`.
class ProductAnalyticsV2FeedDepthRecordedProperties {
  const ProductAnalyticsV2FeedDepthRecordedProperties({
    required this.feedSessionId,
    required this.feedType,
    required this.depth,
  });

  final String feedSessionId;
  final ProductAnalyticsV2FeedType feedType;
  final int depth;

  Map<String, Object?> toJson() => {
    'feed_session_id': feedSessionId,
    'feed_type': feedType.wireName,
    'depth': depth,
  };
}

sealed class ProductAnalyticsV2Event {
  const ProductAnalyticsV2Event({required this.envelope});

  final ProductAnalyticsV2Envelope envelope;
  String get eventName;
  Map<String, Object?> get propertiesJson;

  Map<String, Object?> toJson() => {
    ...envelope.toJson(),
    'event_name': eventName,
    'properties': propertiesJson,
  };
}

final class ProductAnalyticsV2ContentImpressionRecordedEvent
    extends ProductAnalyticsV2Event {
  const ProductAnalyticsV2ContentImpressionRecordedEvent({
    required super.envelope,
    required this.properties,
  });

  final ProductAnalyticsV2ContentImpressionRecordedProperties properties;

  @override
  String get eventName => 'content_impression_recorded';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}

final class ProductAnalyticsV2PlaybackSessionRecordedEvent
    extends ProductAnalyticsV2Event {
  const ProductAnalyticsV2PlaybackSessionRecordedEvent({
    required super.envelope,
    required this.properties,
  });

  final ProductAnalyticsV2PlaybackSessionRecordedProperties properties;

  @override
  String get eventName => 'playback_session_recorded';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}

final class ProductAnalyticsV2NavigationContextRecordedEvent
    extends ProductAnalyticsV2Event {
  const ProductAnalyticsV2NavigationContextRecordedEvent({
    required super.envelope,
    required this.properties,
  });

  final ProductAnalyticsV2NavigationContextRecordedProperties properties;

  @override
  String get eventName => 'navigation_context_recorded';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}

final class ProductAnalyticsV2OnboardingStepRecordedEvent
    extends ProductAnalyticsV2Event {
  const ProductAnalyticsV2OnboardingStepRecordedEvent({
    required super.envelope,
    required this.properties,
  });

  final ProductAnalyticsV2OnboardingStepRecordedProperties properties;

  @override
  String get eventName => 'onboarding_step_recorded';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}

final class ProductAnalyticsV2ExperimentExposureEvent
    extends ProductAnalyticsV2Event {
  const ProductAnalyticsV2ExperimentExposureEvent({
    required super.envelope,
    required this.properties,
  });

  final ProductAnalyticsV2ExperimentExposureProperties properties;

  @override
  String get eventName => 'experiment_exposure';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}

final class ProductAnalyticsV2LandingViewedEvent
    extends ProductAnalyticsV2Event {
  const ProductAnalyticsV2LandingViewedEvent({
    required super.envelope,
    required this.properties,
  });

  final ProductAnalyticsV2LandingViewedProperties properties;

  @override
  String get eventName => 'landing_viewed';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}

final class ProductAnalyticsV2RegistrationStartedEvent
    extends ProductAnalyticsV2Event {
  const ProductAnalyticsV2RegistrationStartedEvent({
    required super.envelope,
    required this.properties,
  });

  final ProductAnalyticsV2RegistrationStartedProperties properties;

  @override
  String get eventName => 'registration_started';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}

final class ProductAnalyticsV2EngagementRecordedEvent
    extends ProductAnalyticsV2Event {
  const ProductAnalyticsV2EngagementRecordedEvent({
    required super.envelope,
    required this.properties,
  });

  final ProductAnalyticsV2EngagementRecordedProperties properties;

  @override
  String get eventName => 'engagement_recorded';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}

final class ProductAnalyticsV2FeedDepthRecordedEvent
    extends ProductAnalyticsV2Event {
  const ProductAnalyticsV2FeedDepthRecordedEvent({
    required super.envelope,
    required this.properties,
  });

  final ProductAnalyticsV2FeedDepthRecordedProperties properties;

  @override
  String get eventName => 'feed_depth_recorded';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}
