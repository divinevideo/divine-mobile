// ABOUTME: Live handle to the per-identity broken-video tracker and dead-media
// ABOUTME: guard, so a feed BLoC can ask about unavailable videos without a ref

import 'package:models/models.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/dead_media_feed_guard.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Answers the fullscreen feed's unavailability questions on behalf of the
/// per-identity [BrokenVideoTracker] and [DeadMediaFeedGuard].
///
/// Also routes removals through the current [VideoEventService], which client
/// recovery and identity changes can replace while a confirmation is pending.
/// The tracker and guard are async providers scoped to the signed-in identity,
/// so a BLoC cannot hold either directly: the tracker may not have resolved by the
/// feed's first build, and an account switch replaces both. The gate is the
/// one stable object in between. The provider graph keeps the tracker and
/// guard current through `ref.listen` — the way `videoEventServiceProvider`
/// reattaches the tracker — so a bound method captured once in
/// `BlocProvider.create` reads live state on every call and never touches
/// the launching widget's `ref` after that screen is gone (#9341).
///
/// While a dependency has not resolved, or when its initialization failed,
/// the gate answers conservatively: nothing is filtered and nothing is pruned.
class FeedUnavailabilityGate {
  BrokenVideoTracker? _tracker;
  DeadMediaFeedGuard? _guard;
  late VideoEventService _videoEventService;

  /// Reattaches removals when client recovery or an identity change replaces
  /// the video service. The provider attaches it before exposing this gate.
  void attachVideoEventService(VideoEventService service) =>
      _videoEventService = service;

  /// Removes from the current service, even if a confirmation began before
  /// the previous service was disposed.
  void removeVideoCompletely(String videoId) =>
      _videoEventService.removeVideoCompletely(videoId);

  /// Also removes every version of an addressable video from current caches.
  void removeVideoEventCompletely(VideoEvent video) =>
      _videoEventService.removeVideoEventCompletely(video);

  /// Attaches the current identity's tracker; null while it has not resolved.
  void attachTracker(BrokenVideoTracker? tracker) => _tracker = tracker;

  /// Attaches the current identity's guard; null while it has not resolved.
  void attachGuard(DeadMediaFeedGuard? guard) => _guard = guard;

  /// Whether [videoId] was confirmed unavailable in this or an earlier
  /// session.
  ///
  /// Filters persisted unavailable videos out of the fullscreen list at the
  /// stream boundary. This covers static / by-id sources (liked, saved,
  /// reposts, collabs, curated lists) whose repositories skip the central
  /// feed filters, so a video confirmed unavailable in a previous session
  /// does not reappear when opened fullscreen. See #5237.
  bool isVideoBroken(String videoId) =>
      _tracker?.isVideoBroken(videoId) ?? false;

  /// Classifies a player-reported unavailable video; see
  /// [DeadMediaFeedGuard.isConfirmedUnavailable].
  ///
  /// Fails closed while the guard has not resolved: without a moderation
  /// verdict a bare 404 is not grounds for a prune (#6251).
  Future<FeedUnavailability> confirmVideoUnavailable({
    required String videoId,
    required String? videoUrl,
    String? explicitSha256,
  }) async {
    final guard = _guard;
    if (guard == null) return FeedUnavailability.none;
    return guard.isConfirmedUnavailable(
      videoId: videoId,
      videoUrl: videoUrl,
      explicitSha256: explicitSha256,
    );
  }

  /// Persists [videoId] as unavailable so it stays filtered out of every list
  /// surface across restarts.
  ///
  /// Only reached after [confirmVideoUnavailable] returned a terminal verdict,
  /// which needs the guard and therefore the tracker it wraps. A failure to
  /// persist is logged rather than thrown: the session-only removal has
  /// already happened, and the next confirmation retries the mark.
  Future<void> markVideoBroken(String videoId, String reason) async {
    final tracker = _tracker;
    if (tracker == null) return;
    try {
      await tracker.markVideoBroken(videoId, reason);
    } on Object catch (error) {
      Log.warning(
        'Failed to persist confirmed-unavailable video: $error',
        name: 'FeedUnavailabilityGate',
        category: LogCategory.video,
      );
    }
  }
}
