// ABOUTME: Resolves video links with bounded recovery for delayed availability.
// ABOUTME: Owns retry timers, relay readiness, and stale-request cancellation.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'video_detail_state.dart';

/// Searches for a route's video while connections or indexing catch up.
class VideoDetailCubit extends Cubit<VideoDetailState>
    with CloseGuardedEmit<VideoDetailState> {
  VideoDetailCubit({
    required VideosRepository Function() videosRepository,
    required bool Function() isRelayReady,
    required Stream<bool> Function() relayReadyStream,
  }) : _videosRepository = videosRepository,
       _isRelayReady = isRelayReady,
       _relayReadyStream = relayReadyStream,
       super(const VideoDetailState());

  static const _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];
  static const _searchTimeout = Duration(seconds: 30);

  // Resolve per attempt so replacement clients are used without discarding an
  // already-resolved video or remounting its player when filters change.
  final VideosRepository Function() _videosRepository;
  final bool Function() _isRelayReady;
  final Stream<bool> Function() _relayReadyStream;
  StreamSubscription<bool>? _relayReadySubscription;
  Timer? _retryTimer;
  Timer? _timeoutTimer;

  /// Starts a new bounded search, replacing any previous route or request.
  void search({
    required String routeId,
    List<String> fallbackRouteIds = const [],
    VideoEvent? initialVideo,
    bool allowRelayReadyRetry = true,
  }) {
    if (isClosed) return;
    cancelSearch();
    emitIfOpen(
      VideoDetailState(
        routeId: routeId,
        fallbackRouteIds: List.unmodifiable(fallbackRouteIds),
        generation: state.generation,
        status: initialVideo == null
            ? VideoDetailStatus.searching
            : VideoDetailStatus.ready,
        video: initialVideo,
      ),
    );
    if (initialVideo != null) return;
    _timeoutTimer = Timer(_searchTimeout, _showLoadFailure);
    _loadDetached(allowRelayReadyRetry: allowRelayReadyRetry);
  }

  /// Starts a fresh search after the viewer chooses Retry.
  void retry() => search(
    routeId: state.routeId,
    fallbackRouteIds: state.fallbackRouteIds,
    allowRelayReadyRetry: false,
  );

  /// Stops scheduled work and invalidates results already in flight.
  void cancelSearch() {
    _cancelResources();
    if (!isClosed) {
      emitIfOpen(
        state.copyWith(
          generation: state.generation + 1,
          waitingForRelay: false,
        ),
      );
    }
  }

  void _cancelResources() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _cancelRelayReadySubscription();
  }

  /// Overrides the viewer's filter for this already-resolved video only.
  void showHiddenVideoAnyway() {
    final video = state.video;
    if (state.status != VideoDetailStatus.hiddenBySettings || video == null) {
      return;
    }
    emitIfOpen(state.copyWith(status: VideoDetailStatus.ready, video: video));
  }

  @override
  Future<void> close() {
    _cancelResources();
    return super.close();
  }

  bool _isCurrent(int generation) =>
      !isClosed && generation == state.generation;

  void _loadDetached({bool allowRelayReadyRetry = true}) {
    final generation = state.generation + 1;
    emitIfOpen(state.copyWith(generation: generation));
    runDetached(
      _load(generation, allowRelayReadyRetry: allowRelayReadyRetry),
      'search for video',
      logName: 'VideoDetailCubit',
      category: LogCategory.video,
    );
  }

  Future<void> _load(
    int generation, {
    required bool allowRelayReadyRetry,
  }) async {
    try {
      final wasRelayReady = _isRelayReady();
      Log.info(
        'Searching for video: ${state.routeId}',
        name: 'VideoDetailCubit',
        category: LogCategory.video,
      );
      final lookup = await _videosRepository().lookupVideoForRouteId(
        state.routeId,
        fallbackRouteIds: state.fallbackRouteIds,
      );
      if (!_isCurrent(generation)) return;

      switch (lookup) {
        case VideoRouteFound(:final video):
          cancelSearch();
          emitIfOpen(
            state.copyWith(status: VideoDetailStatus.ready, video: video),
          );
        case VideoRouteHiddenByFilter(:final video):
          cancelSearch();
          emitIfOpen(
            state.copyWith(
              status: VideoDetailStatus.hiddenBySettings,
              video: video,
            ),
          );
        case VideoRouteMissing():
          // A connected relay can still lag behind notification delivery.
          if (_scheduleRetry()) {
            if (allowRelayReadyRetry && (!wasRelayReady || !_isRelayReady())) {
              _scheduleRelayReadyRetry();
            }
            return;
          }
          _showLoadFailure();
      }
    } catch (error, stackTrace) {
      if (!_isCurrent(generation)) return;
      addError(error, stackTrace);
      final relayReady = _isRelayReady();
      final transient =
          error is FunnelcakeException ||
          error is RelayReadUnavailableException ||
          error is TimeoutException;
      if (transient && _scheduleRetry()) {
        if (allowRelayReadyRetry && !relayReady) _scheduleRelayReadyRetry();
        return;
      }
      if (allowRelayReadyRetry && !relayReady && _scheduleRelayReadyRetry()) {
        return;
      }
      _showLoadFailure();
    }
  }

  bool _scheduleRetry() {
    if (state.retryCount >= _retryDelays.length) return false;
    final delay = _retryDelays[state.retryCount];
    emitIfOpen(state.copyWith(retryCount: state.retryCount + 1));
    final generation = state.generation;
    Log.info(
      'Video lookup incomplete; searching again in ${delay.inSeconds}s '
      '(retry ${state.retryCount}): ${state.routeId}',
      name: 'VideoDetailCubit',
      category: LogCategory.video,
    );
    _retryTimer = Timer(delay, () {
      if (_isCurrent(generation)) _retryLookup();
    });
    return true;
  }

  void _retryLookup() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _cancelRelayReadySubscription();
    emitIfOpen(state.copyWith(waitingForRelay: false));
    _loadDetached(allowRelayReadyRetry: false);
  }

  bool _scheduleRelayReadyRetry() {
    if (state.waitingForRelay || state.hasRetriedAfterRelayReady) return false;
    emitIfOpen(state.copyWith(waitingForRelay: true));
    _cancelRelayReadySubscription();
    final generation = state.generation;
    void retryWhenReady() {
      if (!_isCurrent(generation)) return;
      emitIfOpen(state.copyWith(hasRetriedAfterRelayReady: true));
      _retryLookup();
    }

    if (_isRelayReady()) {
      retryWhenReady();
      return true;
    }
    _relayReadySubscription = _relayReadyStream().listen((ready) {
      if (ready) retryWhenReady();
    });
    return true;
  }

  void _cancelRelayReadySubscription() {
    final cancelled = _relayReadySubscription?.cancel();
    _relayReadySubscription = null;
    if (cancelled == null) return;
    runDetached(
      cancelled,
      'cancel relay-ready subscription',
      logName: 'VideoDetailCubit',
      category: LogCategory.video,
    );
  }

  void _showLoadFailure() {
    if (isClosed) return;
    Log.warning(
      'Video search exhausted; offering retry: ${state.routeId}',
      name: 'VideoDetailCubit',
      category: LogCategory.video,
    );
    cancelSearch();
    emitIfOpen(state.copyWith(status: VideoDetailStatus.loadFailed));
  }
}
