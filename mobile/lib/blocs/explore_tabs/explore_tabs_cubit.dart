// ABOUTME: Cubit owning explore tab availability, ordering, and name<->index
// ABOUTME: mapping, plus the screen's analytics + hashtag-loading side effects.

import 'package:analytics/analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/services/top_hashtags_service.dart';

part 'explore_tabs_state.dart';

/// Coordinates which explore tabs are present and their order.
///
/// Tab availability is dynamic: Classics, For You, Live, and Apps tabs appear
/// based on async feature/platform checks, which shifts the index of every later
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
  }) : _screenAnalytics = screenAnalytics,
       _topHashtags = topHashtags ?? TopHashtagsService(),
       super(const ExploreTabsState());

  static const _screenName = 'explore_screen';

  final ScreenAnalyticsService _screenAnalytics;
  final TopHashtagsLoader _topHashtags;

  /// Updates which optional tabs are available.
  ///
  /// No-ops (and emits nothing) when availability is unchanged so the screen
  /// only rebuilds its [TabController] when the tab set actually changes.
  void updateAvailability({
    required bool classicsAvailable,
    required bool forYouAvailable,
    required bool appsAvailable,
    bool liveAvailable = false,
    FeaturedTabConfig? featuredTab,
  }) {
    if (classicsAvailable == state.classicsAvailable &&
        forYouAvailable == state.forYouAvailable &&
        liveAvailable == state.liveAvailable &&
        appsAvailable == state.appsAvailable &&
        featuredTab == state.featuredTab) {
      return;
    }
    emit(
      state.copyWith(
        classicsAvailable: classicsAvailable,
        forYouAvailable: forYouAvailable,
        appsAvailable: appsAvailable,
        liveAvailable: liveAvailable,
        featuredTab: featuredTab,
        clearFeaturedTab: featuredTab == null,
      ),
    );
  }

  /// Marks the start of the explore screen load for analytics.
  void trackScreenLoad() => _screenAnalytics.startScreenLoad(_screenName);

  /// Records a tab change for analytics.
  void trackTabChange(String tabName) => _screenAnalytics.trackTabChange(
    screenName: _screenName,
    tabName: tabName,
  );

  /// Loads the top hashtags used for trending navigation.
  Future<void> loadHashtags() => _topHashtags.loadTopHashtags();
}
