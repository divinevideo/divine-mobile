// ABOUTME: State for ExploreTabsCubit: optional-tab availability plus derived
// ABOUTME: ordered tab names and name<->index conversion helpers.

part of 'explore_tabs_cubit.dart';

/// Internal tab name for the "For You" tab.
const exploreForYouTabName = 'for_you';

/// Public URL slug for the "For You" tab.
const exploreForYouTabSlug = 'for-you';

/// Internal tab name for the Latest tab: every public video, newest first.
const exploreLatestTabName = 'latest';

/// Internal tab name for the New tab: videos from creators who debuted in the
/// last 30 days.
///
/// Keeps the `new` slug the publication-ordered feed used before Latest
/// existed, so old `/explore/tab/new` links open this tab.
const exploreNewTabName = 'new';

/// Default tab name selected when no other selection applies.
const String exploreDefaultTabName = exploreLatestTabName;

/// Internal tab name for the Classics tab.
const exploreClassicsTabName = 'classics';

/// Internal tab name for the Trending tab.
const explorePopularTabName = 'popular';

/// Internal tab name for the Categories tab.
const exploreCategoriesTabName = 'categories';

/// Internal tab name for the Lists tab.
const exploreListsTabName = 'lists';

/// Internal tab name for the integrated Apps tab.
const exploreAppsTabName = 'apps';
const exploreChallengesTabName = 'challenges';

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
    this.newCreatorsAvailable = false,
    this.forYouAvailable = false,
    this.appsAvailable = false,
    this.challengesAvailable = challengesTestEnabled,
    this.featuredTab,
  });

  /// Whether the Classics tab is shown.
  final bool classicsAvailable;

  /// Whether the New tab is shown. Only the API knows which creators are
  /// new, so the tab is hidden while it is unavailable.
  final bool newCreatorsAvailable;

  /// Whether the For You tab is shown.
  final bool forYouAvailable;

  /// Whether the integrated Apps tab is shown.
  final bool appsAvailable;
  final bool challengesAvailable;

  /// Server-configured featured tab, or `null` when none should render.
  final FeaturedTabConfig? featuredTab;

  /// Ordered tab names based on current availability.
  ///
  /// Canonical order: `classics?`, `latest`, `new?`, `popular`,
  /// `categories`, `for_you?`, `lists`, `apps?`, with the configured
  /// `featured?` tab always immediately before `popular`.
  List<String> get tabNames {
    final names = [
      if (classicsAvailable) exploreClassicsTabName,
      exploreLatestTabName,
      if (newCreatorsAvailable) exploreNewTabName,
      explorePopularTabName,
      exploreCategoriesTabName,
      if (forYouAvailable) exploreForYouTabName,
      exploreListsTabName,
      if (appsAvailable) exploreAppsTabName,
      if (challengesAvailable) exploreChallengesTabName,
    ];
    if (featuredTab == null) return names;
    return names..insert(_featuredInsertIndex(names), exploreFeaturedTabName);
  }

  /// Slot the featured tab occupies, immediately before Popular: after New
  /// when it is shown, otherwise after Latest.
  ///
  /// The server's `position` object is deliberately ignored: placement is
  /// fixed on mobile so it cannot drift from web, and the payload carries
  /// per-platform anchors that need not name a tab this client has. Resolved
  /// by name rather than a literal index because Classics and New are
  /// optional and shift everything below them.
  static int _featuredInsertIndex(List<String> names) =>
      names.indexOf(explorePopularTabName);

  /// Number of visible tabs.
  int get tabCount => tabNames.length;

  /// Index of the Latest tab.
  int get latestIndex => indexForName(exploreLatestTabName);

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
    bool? newCreatorsAvailable,
    bool? forYouAvailable,
    bool? appsAvailable,
    bool? challengesAvailable,
    FeaturedTabConfig? featuredTab,
    bool clearFeaturedTab = false,
  }) {
    return ExploreTabsState(
      classicsAvailable: classicsAvailable ?? this.classicsAvailable,
      newCreatorsAvailable: newCreatorsAvailable ?? this.newCreatorsAvailable,
      forYouAvailable: forYouAvailable ?? this.forYouAvailable,
      appsAvailable: appsAvailable ?? this.appsAvailable,
      challengesAvailable: challengesAvailable ?? this.challengesAvailable,
      featuredTab: clearFeaturedTab ? null : featuredTab ?? this.featuredTab,
    );
  }

  @override
  List<Object?> get props => [
    classicsAvailable,
    newCreatorsAvailable,
    forYouAvailable,
    appsAvailable,
    challengesAvailable,
    featuredTab,
  ];
}
