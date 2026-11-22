// ABOUTME: Reconciles completed local playthroughs with eventually consistent server totals.
// ABOUTME: Keeps the visible loop count monotonic during active video playback.

import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

/// Count and refresh lifecycle for one mounted video.
class VideoLoopsState extends Equatable {
  const VideoLoopsState({
    this.count,
    this.isActive = false,
    this.isRefreshing = false,
    this.generation = 0,
  });

  /// Latest visible total, or null until playback or server data is known.
  final int? count;

  /// Whether the visible player is playing or transiently buffering.
  final bool isActive;

  /// Prevents overlapping requests within an active playback interval.
  final bool isRefreshing;

  /// Invalidates requests from an earlier active playback interval.
  final int generation;

  VideoLoopsState copyWith({
    int? count,
    bool? isActive,
    bool? isRefreshing,
    int? generation,
  }) => VideoLoopsState(
    count: count ?? this.count,
    isActive: isActive ?? this.isActive,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    generation: generation ?? this.generation,
  );

  @override
  List<Object?> get props => [count, isActive, isRefreshing, generation];
}

/// The display is a high-water mark, not server total plus pending loops:
/// the server cannot identify which local reports its snapshot includes.
/// Adding pending loops to every snapshot would count those reports twice.
class VideoLoopsCubit extends Cubit<VideoLoopsState> {
  /// How long a seeded or previously fetched loop count stays fresh before
  /// reactivation triggers another server lookup.
  static const defaultStaleAfter = Duration(minutes: 5);

  VideoLoopsCubit({
    required VideoEvent video,
    required VideosRepository videosRepository,
    Duration staleAfter = defaultStaleAfter,
    DateTime Function()? clock,
  }) : _video = video,
       _videosRepository = videosRepository,
       _staleAfter = staleAfter,
       _clock = clock ?? DateTime.now,
       _lastSyncedAt = video.loopCountSnapshot?.fetchedAt,
       super(VideoLoopsState(count: _seedCount(video)));

  final VideoEvent _video;
  final VideosRepository _videosRepository;
  final Duration _staleAfter;
  final DateTime Function() _clock;
  DateTime? _lastSyncedAt;

  static int? _seedCount(VideoEvent video) {
    final snapshot = video.loopCountSnapshot;
    if (snapshot != null) return math.max(snapshot.count, video.totalLoops);
    return video.hasLoopMetadata ? video.totalLoops : null;
  }

  bool get _needsRefresh {
    final lastSyncedAt = _lastSyncedAt;
    if (state.count == null || lastSyncedAt == null) return true;
    final age = _clock().difference(lastSyncedAt);
    return age.isNegative || age >= _staleAfter;
  }

  /// Marks playback active and refreshes only when loop metadata is missing or
  /// stale; invalidates any in-flight refresh on pause or cover.
  void setActive(bool active) {
    if (isClosed || active == state.isActive) return;
    emit(
      state.copyWith(
        isActive: active,
        isRefreshing: false,
        generation: state.generation + 1,
      ),
    );
    if (active && _needsRefresh) unawaited(refresh());
  }

  /// Immediately reflects a completed playthrough reported by the player.
  void loopCompleted() {
    if (isClosed || !state.isActive) return;
    emit(state.copyWith(count: (state.count ?? 0) + 1));
  }

  /// Raises the display from server totals without re-adding local loops.
  Future<void> refresh() async {
    if (isClosed || !state.isActive || state.isRefreshing) return;
    final generation = state.generation;
    emit(state.copyWith(isRefreshing: true));
    try {
      final count = await _videosRepository.fetchLoopCount(_video);
      if (isClosed || generation != state.generation) return;
      if (count != null) _lastSyncedAt = _clock();
      emit(
        state.copyWith(
          count: count == null ? null : math.max(state.count ?? 0, count),
          isRefreshing: false,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (isClosed || generation != state.generation) return;
      // Keep the optimistic count while offline and retry on reactivation.
      emit(state.copyWith(isRefreshing: false));
      addError(error, stackTrace);
    }
  }
}
