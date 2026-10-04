// ABOUTME: System-wide constants and configuration values for Divine
// ABOUTME: Centralized place for all app constants to avoid magic numbers and scattered values

/// System-wide constants for Divine application
class AppConstants {
  // ============================================================================
  // NOSTR PUBKEYS
  // ============================================================================

  /// Classic Vines curator account pubkey (hex format)
  /// npub: npub1qvu80aqgpq6lzc5gqjp9jpmzczn4pzz3az87zexa3ypgwsu3fkjsj7mxlg
  /// Used as fallback content when users aren't following anyone
  static const String classicVinesPubkey =
      '033877f4080835f162880482590762c0a7508851e88fe164dd89028743914da5';

  /// Divine Team member 1 pubkey (hex format)
  /// npub: npub199wma3u7u7z5jmms8jty3ujxvew5dquur404stqrg269s0d9ej6qzewzu3
  static const String divineTeamPubkey1 =
      '295dbec79ee785496f703c9648f246665d46839c1d5f582c0342b4583da5ccb4';

  /// Divine Team member 2 pubkey (hex format)
  /// npub: npub1m9d23lqwl78y3z2jf9dcqeyer5nlh9hdsef0ztx7m3dyaz66u4qq4stysk
  static const String divineTeamPubkey2 =
      'd95aa8fc0eff8e488952495b8064991d27fb96ed8652f12cdedc5a4e8b5ae540';

  /// List of all Divine Team pubkeys
  static const List<String> divineTeamPubkeys = [
    divineTeamPubkey1,
    divineTeamPubkey2,
  ];

  /// Support email used by account-review and support flows.
  static const String supportEmail = 'support@divine.video';

  /// Divine-hosted family guidance hub for parents and guardians.
  static const String familyResourcesUrl = 'https://divine.video/family';

  /// Divine-hosted kids policy page for under-16 account rules.
  static const String kidsPolicyUrl = 'https://divine.video/kids';

  /// Divine-hosted flagged-account review page for age-review cases.
  static const String ageReviewUrl = 'https://divine.video/age-review';

  /// Divine-hosted account portability flow.
  static const String accountPortabilityUrl = 'https://divine.video/exit';

  /// Divine download page that selects stores for the visitor's platform.
  static const String downloadUrl = 'https://divine.video/download';

  /// Origin of the web app, under which every in-app path is a shareable
  /// link.
  static const String webOrigin = 'https://divine.video';

  // ============================================================================
  // FEED CONFIGURATION
  // ============================================================================

  /// Default limit for following feed subscriptions
  static const int followingFeedLimit = 500;

  /// Default limit for discovery feed subscriptions
  static const int discoveryFeedLimit = 500;

  /// Minimum following videos needed before loading discovery feed
  static const int followingVideoThreshold = 5;

  // ============================================================================
  // FEED PLAYBACK
  // ============================================================================

  /// Hard cap on how long any feed video plays before it loops.
  ///
  /// Nothing in the feed plays longer than a Vine, including kind-34236 events
  /// published by other Nostr clients that point at arbitrarily long files.
  /// The cap is applied as a native clip end (`VideoClip.end`), so the loop
  /// point stays inside the platform player — a Dart-side seek-to-zero is what
  /// produced the audible loop seam in #5544.
  ///
  /// Deliberately above `VideoEditorConstants.maxDuration` (6.3s, the
  /// *recording* limit): classic Vine assets measure 6.500–6.533s, and capping
  /// at the recording limit would clip their musical loop point (#6421).
  static const Duration maxFeedPlaybackDuration = Duration(seconds: 7);

  // ============================================================================
  // VIDEO PROCESSING
  // ============================================================================

  /// Maximum retry attempts for video loading
  static const int maxVideoRetryAttempts = 3;

  /// Retry delay for video operations
  static const Duration videoRetryDelay = Duration(seconds: 10);

  // ============================================================================
  // CURATION SETS
  // ============================================================================

  /// Event ID for the official Editor's Picks curation list (kind 30005)
  /// This is a Nostr event containing the curated video list
  /// Published by: npub1wmrtrwj5f8yms3ekfha8g54flt8ktdtyarc53wfc0c0xvee09nlsqqr9pn
  static const String editorPicksEventId =
      '5e2797304dda04159f8f9f6c36cc5d7f473abe3931f21d7b68fed1ab6a04db3a';

  /// Maximum videos to show in Editor's Picks
  static const int editorPicksLimit = 25;

  /// Maximum videos to show in Trending
  static const int trendingLimit = 25;

  /// Maximum videos to show in Featured
  static const int featuredLimit = 25;

  /// Default pagination size for hashtags and explore sections
  static const int defaultPaginationSize = 25;

  // ============================================================================
  // PAGINATION THRESHOLDS
  // ============================================================================

  /// Minimum video count to consider "has more content" for initial load.
  /// Used by feed providers to determine if loadMore() should be enabled.
  /// If a feed returns fewer than this many videos, hasMoreContent = false.
  static const int hasMoreContentThreshold = 10;

  /// Batch size for loadMore pagination requests.
  /// Used to determine if more content is available based on response size.
  /// If API returns fewer than this many videos, no more content is available.
  static const int paginationBatchSize = 50;

  // ============================================================================
  // PRELOADING CONFIGURATION
  // ============================================================================

  /// Number of videos to preload before current position
  static const int preloadBefore = 2;

  /// Number of videos to preload after current position
  static const int preloadAfter = 3;

  /// Maximum videos to prefetch from grid views (approx 3x3 visible area)
  static const int gridPrefetchLimit = 9;

  /// Minimum bandwidth (Mbps) required for speculative grid prefetching
  static const double gridPrefetchMinBandwidthMbps = 1.5;

  // ============================================================================
  // IMAGE CACHE CONFIGURATION
  // ============================================================================

  /// Byte budget for Flutter's in-memory [ImageCache] (decoded images).
  ///
  /// Flutter's default is 100 MB, which on the thumbnail grids only holds a few
  /// dozen decoded thumbnails — fast scrolling evicts already-loaded thumbnails,
  /// so they flash back through their blurhash placeholder when scrolled into
  /// view again. A larger budget keeps a much bigger working set resident so
  /// scroll-back is an instant (synchronous) cache hit. Per-thumbnail memory is
  /// bounded separately by decoding at display size, so this stays bounded.
  static const int imageCacheMaxBytes = 256 * 1024 * 1024;

  // ============================================================================
  // NETWORK CONFIGURATION
  // ============================================================================

  /// Default Nostr relay URL
  static const String defaultRelayUrl = 'wss://relay.divine.video';

  /// Connection timeout for relay connections
  static const Duration relayConnectionTimeout = Duration(seconds: 30);

  // ============================================================================
  // UI CONFIGURATION
  // ============================================================================

  /// Minimum swipe distance for video navigation
  static const double minSwipeDistance = 50;

  /// Animation duration for video transitions
  static const Duration videoTransitionDuration = Duration(milliseconds: 300);

  // ============================================================================
  // CACHE CONFIGURATION
  // ============================================================================

  /// Maximum number of video states to keep in memory
  static const int maxVideoStatesInMemory = 100;

  /// Maximum size of profile cache
  static const int maxProfileCacheSize = 1000;

  // ============================================================================
  // GEO-BLOCKING CONFIGURATION
  // ============================================================================

  /// Geo-blocking API endpoint URL
  static const String geoBlockApiUrl =
      'https://openvine-geo-blocker.protestnet.workers.dev';

  /// Cache duration for geo-blocking status (24 hours)
  static const Duration geoBlockCacheDuration = Duration(hours: 24);
}
