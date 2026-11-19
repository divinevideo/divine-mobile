// ABOUTME: Resolves one post's stats by event id or by address, and says only
// ABOUTME: what is known: on their way, nothing yet, can't find, or the counts.

import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/aid.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:openvine/features/creator_analytics/video_performance.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'post_analytics_detail_state.dart';

/// Loads one post's stats for the post stats screen.
///
/// Before the settle point (`postedAt` + [settleDelay]) Funnelcake may not
/// have caught up, so a missing post or a zero count reads as unknown, and a
/// single reload is scheduled for the settle point. "Nothing yet" is a
/// first-hour state: past [windowLength] confirmed zeros show as zeros.
class PostAnalyticsDetailCubit extends Cubit<PostAnalyticsDetailState>
    with CloseGuardedEmit<PostAnalyticsDetailState> {
  /// Creates the cubit. With [initialPerformance] it starts resolved from
  /// the video alone, so the screen draws its stats on the first frame, and
  /// [load] only adds what the Live Activity knows.
  PostAnalyticsDetailCubit({
    required CreatorAnalyticsRepository repository,
    required String? ownerPubkey,
    required String videoId,
    String? coordinate,
    VideoPerformance? initialPerformance,
    PostLiveActivityRepository? liveActivity,
    DateTime Function()? now,
  }) : _repository = repository,
       _ownerPubkey = ownerPubkey,
       _videoId = videoId,
       _routeCoordinate = (coordinate?.isEmpty ?? true) ? null : coordinate,
       _initialPerformance = initialPerformance,
       _liveActivity = liveActivity,
       _now = now ?? DateTime.now,
       super(
         initialPerformance == null
             ? const PostAnalyticsDetailState()
             : _stateFor(
                 initialPerformance,
                 hasEngagementData: initialPerformance.hasEngagementData,
                 coordinate:
                     ((coordinate?.isEmpty ?? true) ? null : coordinate) ??
                     _coordinateOf(initialPerformance.video),
                 postedAt: _createdAt(initialPerformance.video),
                 running: false,
                 now: (now ?? DateTime.now)(),
               ),
       );

  /// How long after publishing Funnelcake's counts are trusted, past the
  /// relay's worst-case write delay.
  static const settleDelay = Duration(minutes: 10);

  /// How long after publishing "nothing yet" applies: the Live Activity's
  /// window. Later, a post's confirmed zeros are just its stats.
  static const windowLength = Duration(minutes: 60);

  static const _logName = 'PostAnalyticsDetailCubit';

  final CreatorAnalyticsRepository _repository;
  final String? _ownerPubkey;
  final String _videoId;
  final String? _routeCoordinate;
  final VideoPerformance? _initialPerformance;
  final PostLiveActivityRepository? _liveActivity;
  final DateTime Function() _now;

  /// The reload at the settle point; cancelled on [close].
  Timer? _settleReload;

  /// Resolves the post: from the warm performance when given, adding the
  /// Live Activity's answers once they return, else by fetching the owner's
  /// analytics.
  Future<void> load() async {
    final initial = _initialPerformance;
    if (initial != null) {
      await _resolve(initial, hasEngagementData: initial.hasEngagementData);
      return;
    }
    await _fetch();
  }

  /// Loads again after a failure.
  Future<void> retry() async {
    emit(state.copyWith(status: PostAnalyticsDetailStatus.loading));
    await _fetch();
  }

  /// Ends the post's Lock Screen Live Activity.
  Future<void> stop() async {
    final liveActivity = _liveActivity;
    final coordinate = state.coordinate;
    if (liveActivity == null ||
        coordinate == null ||
        !_ownsCoordinate(coordinate)) {
      return;
    }
    try {
      await liveActivity.stopForPost(coordinate);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      return;
    }
    emitIfOpen(state.copyWith(liveActivityRunning: false));
  }

  @override
  Future<void> close() {
    _settleReload?.cancel();
    return super.close();
  }

  Future<void> _fetch() async {
    final owner = _ownerPubkey;
    if (owner == null || owner.isEmpty) {
      emitIfOpen(
        state.copyWith(status: PostAnalyticsDetailStatus.couldNotLoad),
      );
      return;
    }
    final CreatorAnalyticsSnapshot snapshot;
    try {
      snapshot = await _repository.fetchCreatorAnalytics(owner);
    } on CreatorAnalyticsLoadException catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(status: PostAnalyticsDetailStatus.couldNotLoad),
      );
      return;
    } catch (error, stackTrace) {
      addError(
        Reportable(error, context: 'PostAnalyticsDetailCubit._fetch'),
        stackTrace,
      );
      emitIfOpen(
        state.copyWith(status: PostAnalyticsDetailStatus.couldNotLoad),
      );
      return;
    }
    final hasEngagementData = !snapshot.diagnostics.failedSources.contains(
      AnalyticsDataSource.bulkVideoStats,
    );
    final video = _findPost(snapshot.videos, owner);
    await _resolve(
      video == null
          ? null
          : VideoPerformance.fromVideo(
              video,
              hasEngagementData: hasEngagementData,
            ),
      hasEngagementData: hasEngagementData,
    );
  }

  /// Matches the event id first; after an edit retired it, the address's `d`
  /// tag, held to the signed-in owner.
  VideoEvent? _findPost(List<VideoEvent> videos, String owner) {
    for (final video in videos) {
      if (video.id == _videoId) return video;
    }
    final routeCoordinate = _routeCoordinate;
    final address = routeCoordinate == null
        ? null
        : AId.fromString(routeCoordinate);
    if (address == null || address.pubkey != owner) return null;
    for (final video in videos) {
      if (video.pubkey == owner && video.stableId == address.dTag) {
        return video;
      }
    }
    return null;
  }

  /// Whether [coordinate] addresses a post of the signed-in owner, the only
  /// account whose Live Activity this screen may read or stop.
  bool _ownsCoordinate(String? coordinate) {
    final owner = _ownerPubkey;
    if (coordinate == null || owner == null || owner.isEmpty) return false;
    return AId.fromString(coordinate)?.pubkey == owner;
  }

  Future<void> _resolve(
    VideoPerformance? performance, {
    required bool hasEngagementData,
  }) async {
    final video = performance?.video;
    final coordinate = _routeCoordinate ?? _coordinateOf(video);
    // Only the signed-in owner's own activity may answer, as in _findPost.
    final ownCoordinate = _ownsCoordinate(coordinate) ? coordinate : null;
    final activityPostedAt = ownCoordinate == null
        ? null
        : await _activityPostedAt(ownCoordinate);
    final running =
        ownCoordinate != null && await _activityRunning(ownCoordinate);
    final postedAt = activityPostedAt ?? _createdAt(video);
    final now = _now();
    final next = _stateFor(
      performance,
      hasEngagementData: hasEngagementData,
      coordinate: coordinate,
      postedAt: postedAt,
      running: running,
      now: now,
    );
    final emitted = emitIfOpen(next);
    if (emitted &&
        postedAt != null &&
        next.status == PostAnalyticsDetailStatus.onTheirWay) {
      _scheduleSettleReload(postedAt.add(settleDelay).difference(now));
    }
  }

  static PostAnalyticsDetailState _stateFor(
    VideoPerformance? performance, {
    required bool hasEngagementData,
    required String? coordinate,
    required DateTime? postedAt,
    required bool running,
    required DateTime now,
  }) {
    final video = performance?.video;
    final beforeSettle =
        postedAt != null && now.isBefore(postedAt.add(settleDelay));
    final inWindow =
        postedAt != null && now.isBefore(postedAt.add(windowLength));
    final counts = video == null
        ? const PostCounts()
        : _countsOf(
            video,
            hasEngagementData: hasEngagementData,
            beforeSettle: beforeSettle,
          );
    return PostAnalyticsDetailState(
      status: _statusFor(
        found: video != null,
        counts: counts,
        beforeSettle: beforeSettle,
        inWindow: inWindow,
      ),
      performance: performance,
      counts: counts,
      postedAt: postedAt,
      liveMinutes: postedAt == null
          ? 0
          : math.max(0, now.difference(postedAt).inMinutes),
      coordinate: coordinate,
      liveActivityRunning: running,
    );
  }

  static PostAnalyticsDetailStatus _statusFor({
    required bool found,
    required PostCounts counts,
    required bool beforeSettle,
    required bool inWindow,
  }) {
    if (!found) {
      return beforeSettle
          ? PostAnalyticsDetailStatus.onTheirWay
          : PostAnalyticsDetailStatus.cantFind;
    }
    if (beforeSettle) {
      return counts.anyAboveZero
          ? PostAnalyticsDetailStatus.ready
          : PostAnalyticsDetailStatus.onTheirWay;
    }
    return inWindow && counts.confirmedEmpty
        ? PostAnalyticsDetailStatus.nothingYet
        : PostAnalyticsDetailStatus.ready;
  }

  void _scheduleSettleReload(Duration delay) {
    _settleReload?.cancel();
    _settleReload = Timer(delay, () => unawaited(_fetch()));
  }

  /// Unknown counts stay null; before the settle point a zero is not
  /// confirmed yet, so it is null too.
  static PostCounts _countsOf(
    VideoEvent video, {
    required bool hasEngagementData,
    required bool beforeSettle,
  }) {
    int? known(int? count) =>
        count == null || (beforeSettle && count == 0) ? null : count;
    int? engagement(int? count) => hasEngagementData ? known(count) : null;
    return PostCounts(
      views: known(extractVideoViews(video)),
      uniqueViewers: known(extractUniqueViewers(video)),
      likes: engagement(liveLikeCountSeed(video)),
      comments: engagement(liveCommentCountSeed(video)),
      reposts: engagement(liveRepostCountSeed(video)),
    );
  }

  /// The address the post's Live Activity was started with, built the way
  /// the publish and edit paths build it. Null for a video without a `d` tag.
  static String? _coordinateOf(VideoEvent? video) {
    if (video == null || video.vineId == null) return null;
    return '${video.shareKind}:${video.pubkey}:${video.stableId}';
  }

  static DateTime? _createdAt(VideoEvent? video) {
    if (video == null || video.createdAt <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      video.createdAt * 1000,
      isUtc: true,
    );
  }

  // The Live Activity only enriches the screen: when it cannot answer, the
  // video's own time and a hidden Stop are the honest fallback.
  Future<DateTime?> _activityPostedAt(String coordinate) async {
    final liveActivity = _liveActivity;
    if (liveActivity == null) return null;
    try {
      return await liveActivity.postedAtFor(coordinate);
    } on Object catch (error, stackTrace) {
      _logActivityFailure(
        'read when the post was published',
        error,
        stackTrace,
      );
      return null;
    }
  }

  Future<bool> _activityRunning(String coordinate) async {
    final liveActivity = _liveActivity;
    if (liveActivity == null) return false;
    try {
      return await liveActivity.isRunningFor(coordinate);
    } on Object catch (error, stackTrace) {
      _logActivityFailure('check the Live Activity', error, stackTrace);
      return false;
    }
  }

  void _logActivityFailure(String what, Object error, StackTrace stackTrace) {
    Log.warning(
      'Could not $what for ${_routeCoordinate ?? _videoId}',
      name: _logName,
      category: LogCategory.ui,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
