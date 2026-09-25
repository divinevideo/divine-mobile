// ABOUTME: Fetches, caches, and gates the server-driven featured Explore tab.
// ABOUTME: Owns TTL/staleness policy so the BLoC consumes a resolved answer.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';

/// Resolved featured-tab answer for one refresh.
class FeaturedTabsSnapshot {
  /// Creates a snapshot carrying the renderable tab, if any.
  const FeaturedTabsSnapshot({
    this.tab,
    this.pollInterval = FeaturedTabsResponse.defaultPollInterval,
  });

  /// The single tab that should render, or `null` when none is eligible.
  final FeaturedTabConfig? tab;

  /// Cadence at which the caller should refresh.
  final Duration pollInterval;

  /// Whether a tab should render.
  bool get hasTab => tab != null;
}

/// One page of featured tab videos, in server order.
class FeaturedTabVideosPage {
  /// Creates a page of featured tab videos.
  const FeaturedTabVideosPage({
    required this.videos,
    this.nextCursor,
    this.hasMore = false,
  });

  /// Videos for this page, in the order the server returned them.
  final List<VideoEvent> videos;

  /// Opaque cursor for the following page.
  final String? nextCursor;

  /// Whether another page exists.
  final bool hasMore;
}

/// Composes the featured-tab config source with cache and eligibility rules.
///
/// Owns three policies the layers above must not reimplement:
///
/// * **Staleness.** A successful response is cached; a later failure serves
///   that cache until [cacheTtl] elapses, then drops the tab. The window is
///   deliberately the five minutes funnelcake's own API contract asks for
///   ("drop a cached config after 5 minutes without a successful refresh"), so
///   an outage cannot strand a killed tab on screen. Note the consequence: at
///   a poll cadence of five minutes or slower the cache is already at or past
///   that age whenever a scheduled poll fails, so the first transient failure
///   does drop the tab rather than riding through it. Closing that needs a
///   cadence below the TTL or a retry policy, both of which are the
///   configuration owner's call, not something to buy by quietly serving
///   staler config than the contract allows.
/// * **Eligibility.** A tab renders only when it is enabled, inside its
///   window, has server-side content, and passes the viewer audience rule.
/// * **Selection.** The payload is a list; v1 renders at most one tab, so the
///   first eligible entry wins.
class FeaturedTabsRepository {
  /// Creates a repository over [apiClient].
  ///
  /// [now] is injectable so tests can drive the window and TTL clocks.
  FeaturedTabsRepository({
    required FunnelcakeApiClient apiClient,
    DateTime Function()? now,
    this.cacheTtl = defaultCacheTtl,
  }) : _apiClient = apiClient,
       _now = now ?? (() => DateTime.now().toUtc());

  /// The five minutes funnelcake's API contract specifies for this cache.
  static const defaultCacheTtl = Duration(minutes: 5);

  final FunnelcakeApiClient _apiClient;
  final DateTime Function() _now;

  /// How long a cached config keeps being served after a failed refresh.
  final Duration cacheTtl;

  FeaturedTabsResponse? _cached;
  DateTime? _cachedAt;

  /// Sequence number of the newest started [refresh].
  ///
  /// Request bookkeeping, not cached data: it decides which response is
  /// allowed to become the cache, and nothing reads it back out.
  int _refreshSequence = 0;

  /// Fetches and resolves the featured tab for the current viewer.
  ///
  /// Never throws: a failed fetch degrades to the cached config while it is
  /// fresher than [cacheTtl], and to an empty snapshot once that has elapsed.
  /// Callers get a resolved answer, not an error to interpret.
  ///
  /// [gateAgeRestrictedContent] hides tabs whose dashboard configuration does
  /// not allow viewers under 18. The public config endpoint is shared-cacheable
  /// and therefore not personalized, so this gate is the client's
  /// responsibility.
  Future<FeaturedTabsSnapshot> refresh({
    required bool gateAgeRestrictedContent,
  }) async {
    final sequence = ++_refreshSequence;
    try {
      final response = await _apiClient.getFeaturedTabs();
      // Callers can have several refreshes in flight — a poll, a foreground
      // resume, an age-gate change. Only the newest may become the cache:
      // otherwise a request issued before a server kill can land after the one
      // that removed the tab, and the stale config it leaves behind is served
      // to the next failed refresh, putting the killed tab back on screen.
      if (sequence == _refreshSequence) {
        _cached = response;
        _cachedAt = _now();
      }
      return _resolve(
        response,
        gateAgeRestrictedContent: gateAgeRestrictedContent,
      );
    } on FunnelcakeException {
      return _fromCache(gateAgeRestrictedContent: gateAgeRestrictedContent);
    }
  }

  /// Loads one page of videos for the featured tab identified by [tabId].
  ///
  /// The returned order is the server's and is preserved exactly: curated
  /// entries first, then approved newest-first. Callers must not re-sort or
  /// re-filter — the server has already applied audience and moderation
  /// gating. Expired NIP-40 events are the one exception, dropped here at the
  /// REST ingress boundary like every other feed.
  ///
  /// Throws [FunnelcakeException] subclasses on failure; unlike [refresh],
  /// paging errors are surfaced so the tab can show a retry affordance. A
  /// failed lookup of classic Vines' archived loops does not fail the page.
  Future<FeaturedTabVideosPage> loadVideos({
    required String tabId,
    String? cursor,
  }) async {
    final response = await _apiClient.getFeaturedTabVideos(
      id: tabId,
      cursor: cursor,
    );
    return FeaturedTabVideosPage(
      videos: await _withVineArchives(response.videos.toVideoEvents()),
      nextCursor: response.nextCursor,
      hasMore: response.hasMore ?? response.nextCursor != null,
    );
  }

  /// Fills in the archived loop count of the classic Vines on a page.
  ///
  /// Featured-tab rows carry no event tags and their `loops` is a live count,
  /// so a Vine's archive arrives only as bulk stats' `embedded_loops`
  /// (#9554). A failed lookup serves the page as it came.
  Future<List<VideoEvent>> _withVineArchives(List<VideoEvent> videos) async {
    final vineIds = [
      for (final video in videos)
        if (video.isOriginalVine && video.originalLoops == null) video.id,
    ];
    if (vineIds.isEmpty) return videos;

    final BulkVideoStatsResponse bulk;
    try {
      bulk = await _apiClient.getBulkVideoStats(vineIds);
    } on FunnelcakeException {
      return videos;
    }
    return [
      for (final video in videos)
        switch (bulk.stats[video.id]?.embeddedLoops) {
          final int archived => video.copyWith(originalLoops: archived),
          null => video,
        },
    ];
  }

  /// Drops any cached config, so the next [refresh] must reach the network.
  void clearCache() {
    _cached = null;
    _cachedAt = null;
  }

  FeaturedTabsSnapshot _fromCache({required bool gateAgeRestrictedContent}) {
    final cached = _cached;
    final cachedAt = _cachedAt;
    if (cached == null || cachedAt == null) {
      return const FeaturedTabsSnapshot();
    }
    if (_now().difference(cachedAt) >= cacheTtl) {
      clearCache();
      return const FeaturedTabsSnapshot();
    }
    return _resolve(cached, gateAgeRestrictedContent: gateAgeRestrictedContent);
  }

  FeaturedTabsSnapshot _resolve(
    FeaturedTabsResponse response, {
    required bool gateAgeRestrictedContent,
  }) {
    final now = _now();
    FeaturedTabConfig? eligible;
    for (final tab in response.tabs) {
      if (_isEligible(
        tab,
        now: now,
        gateAgeRestrictedContent: gateAgeRestrictedContent,
      )) {
        eligible = tab;
        break;
      }
    }
    return FeaturedTabsSnapshot(
      tab: eligible,
      pollInterval: response.pollInterval,
    );
  }

  bool _isEligible(
    FeaturedTabConfig tab, {
    required DateTime now,
    required bool gateAgeRestrictedContent,
  }) {
    if (!tab.enabled) return false;
    if (!tab.hasContent) return false;
    if (!tab.isWithinWindow(now)) return false;
    if (gateAgeRestrictedContent && !tab.visibleToMinors) return false;
    // The tab bar's label is compiled client-side, so the renderability floor
    // is an id to fetch and attribute the tab with.
    return tab.id.isNotEmpty;
  }
}
