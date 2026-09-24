// ABOUTME: Feature flag enum defining available feature flags for Divine
// ABOUTME: Provides type-safe flag definitions with display names and descriptions

enum FeatureFlagAudience { user, internal }

enum FeatureFlag {
  shortLinksSharing(
    'Short Links',
    'Use permanent short URLs for external video and profile sharing. '
        'On by default in native builds; off preserves full URLs. '
        'Overrides are internal only.',
    audience: FeatureFlagAudience.internal,
  ),
  publishingIdeas(
    'Publishing Ideas',
    'Inline title, description, and hashtag ideas.',
    audience: FeatureFlagAudience.internal,
  ),
  enhancedAnalytics(
    'Enhanced Analytics',
    'Detailed usage tracking and insights',
  ),
  debugTools('Debug Tools', 'Developer debugging utilities and diagnostics'),
  blueskyPublishing(
    'Bluesky Publishing',
    'Enable Bluesky crosspost toggle in settings',
  ),
  integratedApps(
    'Integrated Apps',
    'Enable the integrated Nostr apps directory and sandbox',
  ),
  accountSwitching(
    'Account Switching',
    'Enable switching between remembered accounts in Settings',
  ),
  videoReplies(
    'Video Replies',
    'Enable recording and posting short video replies from comment threads',
  ),
  advancedRelaySettings(
    'Advanced Relay Settings',
    'Show Nostr relay configuration and diagnostics in Settings. '
        'Changing relays can break publishing and discovery — only turn '
        'this on if you know what you are doing.',
  ),
  feedTuning(
    'Feed Tuning Swipes',
    'Swipe left/right on the fullscreen feed to send "less/more like this" '
        'signals that personalize recommendations. Off by default until the '
        'relay and recommendation backend are ready.',
    audience: FeatureFlagAudience.internal,
  ),
  profileMonetizationLinks(
    'Profile Monetization Links',
    'Enable outbound tip and subscription links on profiles.',
  ),
  communityContentWarnings(
    'Community Content Warnings',
    'Suggest content-warning labels on videos and blur videos whose labels '
        'crossed the community threshold. Off by default pending T&S '
        'rollout sign-off.',
    audience: FeatureFlagAudience.internal,
  ),
  newPostNotifications(
    'New Post Notifications',
    'Turn on a bell for creators you follow to get notified when they post. '
        'Off by default until the push service fans out kind 34236 to '
        'subscribers — with it off, the bell would publish a subscription '
        'that nothing ever delivers.',
  ),
  clientSeenFiltering(
    'Client Seen-Video Filtering',
    'Demote recently-seen videos in home feeds and drop them from '
        'classics/discovery. Kill-switch for the Aug 2026 campaign load.',
  ),
  postPublishConfirmationExperiment(
    'Post-Publish Confirmation Test',
    'Enable the 50/50 View and Share confirmation test after publishing. '
        'Turn off to use the normal control behavior.',
    audience: FeatureFlagAudience.internal,
  ),
  postPublishConfirmationTreatment(
    'Post-Publish Confirmation Treatment',
    'Show the View and Share confirmation to its assigned group. Turn off '
        'while checking that both identical groups measure the same.',
    audience: FeatureFlagAudience.internal,
  ),
  groupMessages(
    'Group Messages',
    'Start a message with several people from the New message sheet, and '
        'file a group someone else starts as a group. Stays off until group '
        'messaging is ready (#8269).',
    audience: FeatureFlagAudience.internal,
  ),
  b2PlaybackCanary(
    'B2 Playback Canary',
    'Try the B2 mirror for public Divine originals before canonical playback. '
        'Internal per-device test; off restores canonical playback.',
    audience: FeatureFlagAudience.internal,
  ),
  concordChat(
    'Concord Chat (POC)',
    'Show Rooms in Messages, the Concord community chat proof of concept. '
        'Messages are signed with your key into a stream anyone can read. '
        'Stays off outside reviewer builds (#10094).',
    audience: FeatureFlagAudience.internal,
  ),
  minorConsentInAppRecording(
    'In-App Parent Consent Recording',
    'Let a parent record and submit a consent video in the app for a '
        'Divine Greenlight account review. Off by default until the '
        'relay-manager parent-consent route and its request-signing '
        'contract ship.',
    audience: FeatureFlagAudience.internal,
  );

  const FeatureFlag(
    this.displayName,
    this.description, {
    this.audience = FeatureFlagAudience.user,
  });

  final String displayName;
  final String description;
  final FeatureFlagAudience audience;

  bool get isInternal => audience == FeatureFlagAudience.internal;
}
