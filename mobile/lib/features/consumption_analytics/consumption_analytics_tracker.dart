// ABOUTME: GA4 events for video consumption and engagement behavior.
// ABOUTME: Keeps analytics delivery best-effort and separate from product actions.

import 'package:analytics/analytics.dart';
import 'package:models/models.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:unified_logger/unified_logger.dart';

/// Records best-effort video consumption and engagement events.
///
/// Delivery failures are absorbed so analytics never changes product actions.
/// Feed types use the normalized `for_you`, `following`, `list`, `new_vines`,
/// `classics`, `popular`, and `featured` vocabulary.
class ConsumptionAnalyticsTracker {
  /// Creates a tracker backed by [analytics].
  ConsumptionAnalyticsTracker({required AnalyticsEventSink analytics})
    : _analytics = analytics;

  final AnalyticsEventSink _analytics;

  /// Records that playback started for [video] at [position].
  Future<void> videoStarted({
    required VideoEvent video,
    required ViewTrafficSource trafficSource,
    required int position,
    String? sourceDetail,
  }) => _log('video_started', {
    'video_id': video.id,
    'author_pubkey': video.pubkey,
    'feed_type': _feedType(trafficSource, sourceDetail),
    'position_in_feed': position,
    'is_archive': video.isOriginalVine ? 1 : 0,
  });

  /// Records a playback session that completed or looped.
  Future<void> videoCompleted({
    required String videoId,
    required int watchMs,
    required double pctWatched,
    required int loops,
  }) => _log('video_completed', {
    'video_id': videoId,
    'watch_ms': watchMs,
    'pct_watched': pctWatched,
    'loops': loops,
  });

  /// Records a playback session that ended before completion.
  Future<void> videoSkipped({
    required String videoId,
    required int watchMs,
    required int position,
  }) => _log('video_skipped', {
    'video_id': videoId,
    'watch_ms': watchMs,
    'position_in_feed': position,
  });

  /// Records a real user swipe at the unique-video [depth] for one feed session.
  Future<void> feedScrolled({
    required ViewTrafficSource trafficSource,
    required int depth,
    String? sourceDetail,
  }) => _log('feed_scrolled', {
    'feed_type': _feedType(trafficSource, sourceDetail),
    'depth': depth,
  });

  /// Records a successfully published reaction.
  Future<void> reactionSent({
    required String targetVideoId,
    required String targetPubkey,
  }) => _targetEvent(
    'reaction_sent',
    targetVideoId: targetVideoId,
    targetPubkey: targetPubkey,
  );

  /// Records a successfully published comment.
  Future<void> commentSent({
    required String targetVideoId,
    required String targetPubkey,
  }) => _targetEvent(
    'comment_sent',
    targetVideoId: targetVideoId,
    targetPubkey: targetPubkey,
  );

  /// Records share intent when the share surface is opened.
  Future<void> shareTapped({
    required String targetVideoId,
    required String targetPubkey,
  }) => _targetEvent(
    'share_tapped',
    targetVideoId: targetVideoId,
    targetPubkey: targetPubkey,
  );

  /// Records a confirmed follow.
  ///
  /// [targetVideoId] is present only when the follow originated from a video's
  /// author overlay. Profile, list, and notification follows omit it.
  Future<void> followAdded({
    required String targetPubkey,
    String? targetVideoId,
  }) => _log('follow_added', {
    'target_pubkey': targetPubkey,
    'target_video_id': ?targetVideoId,
  });

  String _feedType(ViewTrafficSource trafficSource, String? sourceDetail) {
    if (trafficSource == ViewTrafficSource.home) {
      return switch (sourceDetail) {
        'foryou' => 'for_you',
        'following' => 'following',
        'list' => 'list',
        'new' => 'new_vines',
        'classic' => 'classics',
        _ => trafficSource.tagValue,
      };
    }

    return switch (trafficSource) {
      ViewTrafficSource.discoveryNew => 'new_vines',
      ViewTrafficSource.discoveryClassic => 'classics',
      ViewTrafficSource.discoveryForYou => 'for_you',
      ViewTrafficSource.discoveryPopular => 'popular',
      ViewTrafficSource.discoveryFeatured => 'featured',
      _ => trafficSource.tagValue,
    };
  }

  Future<void> _targetEvent(
    String name, {
    required String targetVideoId,
    required String targetPubkey,
  }) => _log(name, {
    'target_video_id': targetVideoId,
    'target_pubkey': targetPubkey,
  });

  Future<void> _log(String name, Map<String, Object> parameters) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (error) {
      Log.warning(
        'Failed to record $name analytics: $error',
        name: 'ConsumptionAnalyticsTracker',
        category: LogCategory.system,
      );
    }
  }
}
