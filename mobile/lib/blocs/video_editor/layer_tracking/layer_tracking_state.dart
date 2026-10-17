part of 'layer_tracking_cubit.dart';

/// Where tracking an object for a layer stands.
enum LayerTrackingStatus {
  /// Nothing is being tracked, or the last result was applied.
  idle,

  /// The object is being followed through the clip.
  tracking,

  /// The object was followed; [LayerTrackingState.track] holds its path.
  followed,

  /// The marked region had too little detail to follow past its own frame.
  notFollowed,

  /// The clip could not be read, or tracking stopped responding.
  failed,
}

/// The state of [LayerTrackingCubit].
class LayerTrackingState extends Equatable {
  const LayerTrackingState({
    this.status = LayerTrackingStatus.idle,
    this.progress = 0,
    this.layerId,
    this.target,
    this.track,
  });

  final LayerTrackingStatus status;

  /// How much of the clip was tracked so far, 0..1.
  final double progress;

  /// The layer the object is tracked for.
  final String? layerId;

  /// The clip and the stretch of the timeline the object is tracked in.
  final LayerTrackTarget? target;

  /// The object's path, once [status] is [LayerTrackingStatus.followed].
  final VideoObjectTrack? track;

  /// Whether an object is being tracked now.
  bool get isTracking => status == LayerTrackingStatus.tracking;

  LayerTrackingState copyWith({double? progress}) => LayerTrackingState(
    status: status,
    progress: progress ?? this.progress,
    layerId: layerId,
    target: target,
    track: track,
  );

  @override
  List<Object?> get props => [status, progress, layerId, target, track];
}
