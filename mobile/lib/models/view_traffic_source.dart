// ABOUTME: Traffic source attributed to a video view, plus its tag mapping.
// ABOUTME: A domain value type, so presentation may import it directly.

/// Traffic source for video views
enum ViewTrafficSource {
  /// Video viewed from home/following feed
  home,

  /// Video viewed from explore/discovery — new videos tab
  discoveryNew,

  /// Video viewed from explore/discovery — classic vines tab
  discoveryClassic,

  /// Video viewed from explore/discovery — for you (personalized) tab
  discoveryForYou,

  /// Video viewed from explore/discovery — popular videos tab
  discoveryPopular,

  /// Video viewed from a user's profile page
  profile,

  /// Video viewed via shared link
  share,

  /// Video viewed from search results or hashtag feed
  search,

  /// Video viewed from explore/discovery — a server-configured featured tab.
  ///
  /// Deliberately generic: the tag never names the editorial theme, so
  /// dashboards do not inherit a schema per campaign. The configuration id
  /// travels separately as the source detail.
  discoveryFeatured,

  /// Video viewed from an accepted badge-holder collection.
  discoveryBadges,

  /// Unknown/unspecified source
  unknown,
}

extension ViewTrafficSourceTags on ViewTrafficSource {
  String get tagValue {
    return switch (this) {
      ViewTrafficSource.home => 'home',
      ViewTrafficSource.discoveryNew => 'discovery:new',
      ViewTrafficSource.discoveryClassic => 'discovery:classic',
      ViewTrafficSource.discoveryForYou => 'discovery:foryou',
      ViewTrafficSource.discoveryPopular => 'discovery:popular',
      ViewTrafficSource.discoveryFeatured => 'discovery:featured',
      ViewTrafficSource.discoveryBadges => 'discovery:badges',
      ViewTrafficSource.profile => 'profile',
      ViewTrafficSource.share => 'share',
      ViewTrafficSource.search => 'search',
      ViewTrafficSource.unknown => 'unknown',
    };
  }
}

ViewTrafficSource viewTrafficSourceFromTag(String raw) {
  return switch (raw) {
    'home' => ViewTrafficSource.home,
    'profile' => ViewTrafficSource.profile,
    'search' => ViewTrafficSource.search,
    'share' => ViewTrafficSource.share,
    'discovery:new' || 'discovery_new' => ViewTrafficSource.discoveryNew,
    'discovery:popular' ||
    'discovery_popular' => ViewTrafficSource.discoveryPopular,
    'discovery:classic' ||
    'discovery_classic' => ViewTrafficSource.discoveryClassic,
    'discovery:foryou' ||
    'discovery_for_you' => ViewTrafficSource.discoveryForYou,
    'discovery:featured' ||
    'discovery_featured' => ViewTrafficSource.discoveryFeatured,
    'discovery:badges' ||
    'discovery_badges' => ViewTrafficSource.discoveryBadges,
    _ => ViewTrafficSource.unknown,
  };
}
