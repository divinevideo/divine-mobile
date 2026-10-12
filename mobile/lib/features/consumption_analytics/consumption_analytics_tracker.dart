// ABOUTME: Governed feed-depth and engagement analytics without relationship identity.
// ABOUTME: Keeps delivery best-effort and separate from product actions.

import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Records deliberate feed navigation and confirmed engagement.
///
/// Playback is owned by the existing governed playback tracker. Consent and
/// identity boundaries are enforced by [AnalyticsService] for every event.
class ConsumptionAnalyticsTracker {
  /// Creates a tracker backed by the governed analytics service.
  ConsumptionAnalyticsTracker({required AnalyticsService Function() analytics})
    : _analytics = analytics;

  final AnalyticsService Function() _analytics;

  /// Changes whenever the governed analytics identity or session changes.
  String get sessionBoundary => _analytics().productAnalyticsSessionId;

  /// Records distinct items deliberately reached in one feed session.
  ///
  /// The initial item contributes to [depth]. Swipes and explicit Skip taps
  /// emit events; automatic navigation does not increase depth.
  Future<void> feedScrolled({
    required ViewTrafficSource trafficSource,
    required String feedSessionId,
    required int depth,
    String? sourceDetail,
  }) => _record(
    () => _analytics().recordFeedDepth(
      feedSessionId: feedSessionId,
      feedType: _feedType(trafficSource, sourceDetail),
      depth: depth,
    ),
  );

  /// Records a successfully published reaction.
  Future<void> reactionSent({required String targetVideoId}) => _engagement(
    ProductAnalyticsV2EngagementAction.reactionSent,
    targetVideoId,
  );

  /// Records a successfully published comment.
  Future<void> commentSent({required String targetVideoId}) => _engagement(
    ProductAnalyticsV2EngagementAction.commentSent,
    targetVideoId,
  );

  /// Records share intent when the share action is tapped.
  Future<void> shareTapped({required String targetVideoId}) => _engagement(
    ProductAnalyticsV2EngagementAction.shareTapped,
    targetVideoId,
  );

  /// Records a confirmed follow without the followed account's identity.
  ///
  /// Video-originated follows include [targetVideoId]; other surfaces omit it.
  Future<void> followAdded({String? targetVideoId}) => _engagement(
    ProductAnalyticsV2EngagementAction.followAdded,
    targetVideoId,
  );

  Future<void> _engagement(
    ProductAnalyticsV2EngagementAction action,
    String? contentId,
  ) => _record(
    () => _analytics().recordEngagement(action: action, contentId: contentId),
  );

  ProductAnalyticsV2FeedType _feedType(
    ViewTrafficSource source,
    String? detail,
  ) {
    if (source == ViewTrafficSource.home) {
      return switch (detail) {
        'foryou' => ProductAnalyticsV2FeedType.forYou,
        'following' => ProductAnalyticsV2FeedType.following,
        'list' => ProductAnalyticsV2FeedType.list,
        'new' => ProductAnalyticsV2FeedType.newVines,
        'classic' => ProductAnalyticsV2FeedType.classics,
        _ => ProductAnalyticsV2FeedType.home,
      };
    }
    return switch (source) {
      ViewTrafficSource.home => ProductAnalyticsV2FeedType.home,
      ViewTrafficSource.discoveryNew => ProductAnalyticsV2FeedType.newVines,
      ViewTrafficSource.discoveryClassic => ProductAnalyticsV2FeedType.classics,
      ViewTrafficSource.discoveryForYou => ProductAnalyticsV2FeedType.forYou,
      ViewTrafficSource.discoveryPopular => ProductAnalyticsV2FeedType.popular,
      ViewTrafficSource.discoveryFeatured =>
        ProductAnalyticsV2FeedType.featured,
      ViewTrafficSource.profile => ProductAnalyticsV2FeedType.profile,
      ViewTrafficSource.share => ProductAnalyticsV2FeedType.share,
      ViewTrafficSource.search => ProductAnalyticsV2FeedType.search,
      ViewTrafficSource.unknown => ProductAnalyticsV2FeedType.unknown,
    };
  }

  Future<void> _record(Future<String?> Function() record) async {
    try {
      await record();
    } catch (error) {
      Log.warning(
        'Failed to record consumption analytics: $error',
        name: 'ConsumptionAnalyticsTracker',
        category: LogCategory.system,
      );
    }
  }
}
