// ABOUTME: Cubit owning explore tab availability, ordering, and name<->index
// ABOUTME: mapping, plus the screen's analytics + hashtag-loading side effects.

import 'package:analytics/analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/features/challenges/challenge_test_build.dart';
import 'package:openvine/observability/screen_load_telemetry.dart';
import 'package:openvine/services/top_hashtags_service.dart';

part 'explore_tabs_state.dart';

/// Coordinates which explore tabs are present and their order.
///
/// Tab availability is dynamic: Classics, For You, and Apps tabs appear based
/// on async feature/platform checks, which shifts the index of every later
/// tab. To keep callers from reasoning about raw indices, this cubit owns the
/// ordered tab-name list and the name<->index conversion, and treats tab
/// identity as the stable key (never the index).
///
/// It also owns the explore screen's service-touching side effects (screen
/// analytics and top-hashtag loading) so the presentation layer reaches them
/// through the cubit rather than importing services directly.
class ExploreTabsCubit extends Cubit<ExploreTabsState> {
  /// Creates the cubit. Production injects the shared
  /// `screenAnalyticsServiceProvider` and `topHashtagsServiceProvider`
  /// instances (so screen-load sessions and the warmed hashtag cache are
  /// shared), and tests inject fakes. [topHashtags] defaults to a standalone
  /// instance; [screenAnalytics] is required because a private instance would
  /// never see the session the navigator observer started.
  ExploreTabsCubit({
    required ScreenAnalyticsService screenAnalytics,
    TopHashtagsLoader? topHashtags,
    ScreenLoadTelemetry? loadTelemetry,
  }) : _screenAnalytics = screenAnalytics,
       _topHashtags = topHashtags ?? TopHashtagsService(),
       _loadTelemetry = loadTelemetry,
       super(const ExploreTabsState());

  static const _screenName = 'explore_screen';

  /// The feed tabs that report their first grid through [reportFeedTabShown]
  /// and [reportFeedTabFailed], so Explore's load is timed only when it opens
  /// on one of them.
  static const Set<String> _timedTabs = {
    exploreDefaultTabName,
    explorePopularTabName,
  };

  final ScreenAnalyticsService _screenAnalytics;
  final TopHashtagsLoader _topHashtags;

  /// Times Explore from opening until its tab's grid shows; null where
  /// unmeasured.
  final ScreenLoadTelemetry? _loadTelemetry;

  /// Updates which optional tabs are available.
  ///
  /// No-ops (and emits nothing) when availability is unchanged so the screen
  /// only rebuilds its [TabController] when the tab set actually changes.
  void updateAvailability({
    required bool classicsAvailable,
    required bool forYouAvailable,
    required bool appsAvailable,
    FeaturedTabConfig? featuredTab,
  }) {
    if (classicsAvailable == state.classicsAvailable &&
        forYouAvailable == state.forYouAvailable &&
        appsAvailable == state.appsAvailable &&
        featuredTab == state.featuredTab) {
      return;
    }
    emit(
      state.copyWith(
        classicsAvailable: classicsAvailable,
        forYouAvailable: forYouAvailable,
        appsAvailable: appsAvailable,
        featuredTab: featuredTab,
        clearFeaturedTab: featuredTab == null,
      ),
    );
  }

  /// Marks the start of the explore screen load for analytics.
  ///
  /// When Explore opens on [initialTabName] and that is a feed tab that
  /// reports its first grid, the load is timed until the grid shows.
  void trackScreenLoad({String? initialTabName}) {
    _screenAnalytics.startScreenLoad(_screenName);
    if (_timedTabs.contains(initialTabName)) {
      _loadTelemetry?.start(tab: initialTabName);
    }
  }

  /// Records a tab change for analytics.
  ///
  /// Leaving the tab Explore opened on before its grid showed dismisses the
  /// timed load.
  void trackTabChange(String tabName) {
    _screenAnalytics.trackTabChange(
      screenName: _screenName,
      tabName: tabName,
    );
    final timedTab = _loadTelemetry?.timedTab;
    if (timedTab != null && timedTab != tabName) _loadTelemetry?.dismiss();
  }

  /// Reports that the feed tab [tabName] shows [itemCount] videos, or its
  /// empty state when there are none.
  void reportFeedTabShown(
    String tabName, {
    required int itemCount,
    bool? hasMore,
  }) {
    final telemetry = _loadTelemetry;
    if (telemetry == null || telemetry.timedTab != tabName) return;
    telemetry.completeLoaded(itemCount: itemCount, hasMore: hasMore);
  }

  /// Reports that the feed tab [tabName] shows its load error.
  void reportFeedTabFailed(String tabName) {
    final telemetry = _loadTelemetry;
    if (telemetry == null || telemetry.timedTab != tabName) return;
    telemetry.completeFailure();
  }

  @override
  Future<void> close() {
    _loadTelemetry?.dismiss();
    return super.close();
  }

  /// Loads the top hashtags used for trending navigation.
  Future<void> loadHashtags() => _topHashtags.loadTopHashtags();
}
