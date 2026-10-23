// ABOUTME: Video route search state, without user-facing strings or exceptions.

part of 'video_detail_cubit.dart';

/// The progress or outcome of resolving a video link.
enum VideoDetailStatus { searching, ready, hiddenBySettings, loadFailed }

/// The search target, recovery progress, and resolved video.
class VideoDetailState extends Equatable {
  const VideoDetailState({
    this.status = VideoDetailStatus.searching,
    this.video,
    this.routeId = '',
    this.fallbackRouteIds = const [],
    this.retryCount = 0,
    this.generation = 0,
    this.waitingForRelay = false,
    this.hasRetriedAfterRelayReady = false,
  });

  final VideoDetailStatus status;
  final VideoEvent? video;
  final String routeId;
  final List<String> fallbackRouteIds;
  final int retryCount;
  final int generation;
  final bool waitingForRelay;
  final bool hasRetriedAfterRelayReady;

  VideoDetailState copyWith({
    VideoDetailStatus? status,
    VideoEvent? video,
    int? retryCount,
    int? generation,
    bool? waitingForRelay,
    bool? hasRetriedAfterRelayReady,
  }) => VideoDetailState(
    status: status ?? this.status,
    video: video ?? this.video,
    routeId: routeId,
    fallbackRouteIds: fallbackRouteIds,
    retryCount: retryCount ?? this.retryCount,
    generation: generation ?? this.generation,
    waitingForRelay: waitingForRelay ?? this.waitingForRelay,
    hasRetriedAfterRelayReady:
        hasRetriedAfterRelayReady ?? this.hasRetriedAfterRelayReady,
  );

  @override
  List<Object?> get props => [
    status,
    video,
    routeId,
    fallbackRouteIds,
    retryCount,
    generation,
    waitingForRelay,
    hasRetriedAfterRelayReady,
  ];
}
