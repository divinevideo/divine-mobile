// ABOUTME: State for ExploreTabsCubit: optional-tab availability plus derived
// ABOUTME: ordered tab names and name<->index conversion helpers.

part of 'explore_tabs_cubit.dart';

/// Internal tab name for the "For You" tab.
const exploreForYouTabName = 'for_you';

/// Public URL slug for the "For You" tab.
const exploreForYouTabSlug = 'for-you';

/// Default tab name selected when no other selection applies.
const exploreDefaultTabName = 'new';

/// Internal tab name for the Classics tab.
const exploreClassicsTabName = 'classics';

/// Internal tab name for the Trending tab.
const explorePopularTabName = 'popular';

/// Internal tab name for the Categories tab.
const exploreCategoriesTabName = 'categories';

/// Internal tab name for the Lists tab.
const exploreListsTabName = 'lists';

/// Internal tab name for curated public badges.
const exploreBadgesTabName = 'badges';

/// Internal tab name for the integrated Apps tab.
const exploreAppsTabName = 'apps';

/// Internal tab name for the server-configured featured tab.
///
/// Deliberately generic: no editorial name is compiled into the app, and
/// analytics keys off the configuration id rather than this constant.
const exploreFeaturedTabName = 'featured';

/// Immutable explore tab configuration derived from feature availability.
class ExploreTabsState extends Equatable {
  /// Creates a tab state with the given optional-tab availability.
  const ExploreTabsState({
    this.classicsAvailable = false,
    this.forYouAvailable = false,
    this.appsAvailable = false,
    this.featuredTab,
  });

  /// Whether the Classics tab is shown.
  final bool classicsAvailable;

  /// Whether the For You tab is shown.
  final bool forYouAvailable;

  /// Whether the integrated Apps tab is shown.
  final bool appsAvailable;

  /// Server-configured featured tab, or `null` when none should render.
  final FeaturedTabConfig? featuredTab;

  /// Ordered tab names based on current availability.
  ///
  /// Canonical order: `classics?`, `new`, `popular`, `categories`,
  /// `for_you?`, `lists`, `badges`, `apps?`, with the configured `featured?` tab
  /// always between `new` and `popular`.
  List<String> get tabNames {
    final names = [
      if (classicsAvailable) exploreClassicsTabName,
      exploreDefaultTabName,
      explorePopularTabName,
      exploreCategoriesTabName,
      if (forYouAvailable) exploreForYouTabName,
      exploreListsTabName,
      exploreBadgesTabName,
      if (appsAvailable) exploreAppsTabName,
    ];
    if (featuredTab == null) return names;
    return names..insert(_featuredInsertIndex(names), exploreFeaturedTabName);
  }

  /// Slot the featured tab occupies, immediately after New.
  ///
  /// The server's `position` object is deliberately ignored: placement is
  /// fixed on mobile so it cannot drift from web, and the payload carries
  /// per-platform anchors that need not name a tab this client has. Resolved
  /// by name rather than a literal index because Classics is optional and
  /// shifts everything below it.
  static int _featuredInsertIndex(List<String> names) =>
      names.indexOf(exploreDefaultTabName) + 1;

  /// Number of visible tabs.
  int get tabCount => tabNames.length;

  /// Index of the New Videos tab.
  int get newVideosIndex => indexForName(exploreDefaultTabName);

  /// Index of the Trending (popular) tab.
  int get trendingIndex => indexForName(explorePopularTabName);

  /// Resolves a tab [name] to its index, falling back to the default tab.
  int indexForName(String name) {
    final index = tabNames.indexOf(name);
    if (index >= 0) return index;
    final fallback = tabNames.indexOf(exploreDefaultTabName);
    return fallback >= 0 ? fallback : 0;
  }

  /// Resolves a tab [index] to its name, falling back to `popular`.
  String nameForIndex(int index) {
    final names = tabNames;
    if (index >= 0 && index < names.length) return names[index];
    return explorePopularTabName;
  }

  /// Returns a copy with the given availability overrides.
  ///
  /// Use [clearFeaturedTab] for the server kill switch; omitting [featuredTab]
  /// otherwise preserves the current tab like the rest of the fields.
  ExploreTabsState copyWith({
    bool? classicsAvailable,
    bool? forYouAvailable,
    bool? appsAvailable,
    FeaturedTabConfig? featuredTab,
    bool clearFeaturedTab = false,
  }) {
    return ExploreTabsState(
      classicsAvailable: classicsAvailable ?? this.classicsAvailable,
      forYouAvailable: forYouAvailable ?? this.forYouAvailable,
      appsAvailable: appsAvailable ?? this.appsAvailable,
      featuredTab: clearFeaturedTab ? null : featuredTab ?? this.featuredTab,
    );
  }

  @override
  List<Object?> get props => [
    classicsAvailable,
    forYouAvailable,
    appsAvailable,
    featuredTab,
  ];
}
