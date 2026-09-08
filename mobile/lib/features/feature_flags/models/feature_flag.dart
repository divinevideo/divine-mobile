// ABOUTME: Feature flag enum defining available feature flags for Divine
// ABOUTME: Provides type-safe flag definitions with display names and descriptions

enum FeatureFlagAudience { user, internal }

enum FeatureFlag {
  enhancedAnalytics(
    'Enhanced Analytics',
    'Detailed usage tracking and insights',
  ),
  debugTools('Debug Tools', 'Developer debugging utilities and diagnostics'),
  // Named for the share-menu action it used to gate. Video lists (kind 30005)
  // now ship unflagged, so this is the master switch for people lists
  // (NIP-51 kind 30000) only, which profileListFeatures narrows further.
  curatedLists('Curated Lists', 'Master switch for people lists (kind 30000)'),
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
  profileListFeatures(
    'Profile List Features',
    'Enable people list creation from profiles and people list results in search (NIP-51 kind 30000)',
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
  divineSupporters(
    'Divine Supporters',
    'Optional monthly supporter subscription via in-app purchase. '
        'Nothing is gated — it keeps Divine running and recognizes supporters.',
    // Purchases must not be exposed to ordinary users until the build has a
    // configured verification service that can claim and acknowledge them.
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
