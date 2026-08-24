// ABOUTME: GA4 events for video consumption and engagement behavior.
// ABOUTME: Keeps analytics delivery best-effort and separate from product actions.

import 'package:analytics/analytics.dart';
import 'package:models/models.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:unified_logger/unified_logger.dart';

class ConsumptionAnalyticsTracker {
  ConsumptionAnalyticsTracker({required AnalyticsEventSink analytics})
    : _analytics = analytics;

  final AnalyticsEventSink _analytics;

  Future<void> videoStarted({
    required VideoEvent video,
    required ViewTrafficSource trafficSource,
    required int position,
  }) => _log('video_started', {
    'video_id': video.id,
    'author_pubkey': video.pubkey,
    'feed_type': trafficSource.tagValue,
    'position_in_feed': position,
    'is_archive': video.isOriginalVine ? 1 : 0,
  });

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

  Future<void> videoSkipped({
    required String videoId,
    required int watchMs,
    required int position,
  }) => _log('video_skipped', {
    'video_id': videoId,
    'watch_ms': watchMs,
    'position_in_feed': position,
  });

  Future<void> feedScrolled({
    required ViewTrafficSource trafficSource,
    required int depth,
  }) => _log('feed_scrolled', {
    'feed_type': trafficSource.tagValue,
    'depth': depth,
  });

  Future<void> reactionSent({
    required String targetVideoId,
    required String targetPubkey,
  }) => _targetEvent(
    'reaction_sent',
    targetVideoId: targetVideoId,
    targetPubkey: targetPubkey,
  );

  Future<void> commentSent({
    required String targetVideoId,
    required String targetPubkey,
  }) => _targetEvent(
    'comment_sent',
    targetVideoId: targetVideoId,
    targetPubkey: targetPubkey,
  );

  Future<void> shareTapped({
    required String targetVideoId,
    required String targetPubkey,
  }) => _targetEvent(
    'share_tapped',
    targetVideoId: targetVideoId,
    targetPubkey: targetPubkey,
  );

  Future<void> followAdded({required String targetPubkey}) =>
      _log('follow_added', {'target_pubkey': targetPubkey});

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
