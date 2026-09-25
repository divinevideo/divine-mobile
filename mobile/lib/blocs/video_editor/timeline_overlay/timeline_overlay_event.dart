part of 'timeline_overlay_bloc.dart';

/// Base class for all timeline overlay events.
sealed class TimelineOverlayEvent extends Equatable {
  const TimelineOverlayEvent();

  @override
  List<Object?> get props => [];
}

/// Updates all item to the timeline.
class TimelineOverlayItemsUpdate extends TimelineOverlayEvent {
  const TimelineOverlayItemsUpdate({
    required this.layers,
    required this.filters,
    required this.audioTracks,
    required this.totalVideoDuration,
    this.tuneAdjustments = const [],
    this.timelineMarkers = const [],
    this.captionTrack,
  });

  final List<Layer> layers;
  final List<FilterState> filters;
  final List<TuneAdjustmentMatrix> tuneAdjustments;
  final List<AudioEvent> audioTracks;
  final List<Duration> timelineMarkers;

  /// The session's caption track; overlay-mode cues become captions items.
  final CaptionTrack? captionTrack;

  final Duration totalVideoDuration;

  @override
  List<Object?> get props => [
    layers,
    filters,
    tuneAdjustments,
    audioTracks,
    totalVideoDuration,
    timelineMarkers,
    captionTrack,
  ];
}

/// Move an overlay item to a new start time and/or row.
///
/// When [insertAbove] is `true` and the target row has an overlap,
/// the moved item keeps the target row and existing items shift down.
/// When `false` (default), the moved item shifts to the row below.
class TimelineOverlayItemMoved extends TimelineOverlayEvent {
  const TimelineOverlayItemMoved({
    required this.itemId,
    this.startTime,
    this.row,
    this.insertAbove = false,
  });

  final String itemId;
  final Duration? startTime;
  final int? row;
  final bool insertAbove;

  @override
  List<Object?> get props => [itemId, startTime, row, insertAbove];
}

/// Update the trim of an overlay item.
///
/// A `null` [startTime] or [endTime] keeps that edge where it is.
class TimelineOverlayItemTrimmed extends TimelineOverlayEvent {
  const TimelineOverlayItemTrimmed({
    required this.itemId,
    required this.isStart,
    this.startTime,
    this.endTime,
    this.startOffset,
  });

  final String itemId;
  final bool isStart;
  final Duration? startTime;
  final Duration? endTime;

  /// New source offset for sound items after a left-trim.
  ///
  /// Carries the authoritative offset computed alongside the timeline
  /// move so the live waveform scrolls the trimmed-away head out of view
  /// during the drag. `null` for non-sound items and right-trims (offset
  /// unchanged).
  final Duration? startOffset;

  @override
  List<Object?> get props => [itemId, isStart, startTime, endTime, startOffset];
}

/// Select an overlay item (shows trim handles).
class TimelineOverlayItemSelected extends TimelineOverlayEvent {
  const TimelineOverlayItemSelected(this.itemId);

  final String? itemId;

  @override
  List<Object?> get props => [itemId];
}

/// Signal that a drag gesture started for an item.
class TimelineOverlayDragStarted extends TimelineOverlayEvent {
  const TimelineOverlayDragStarted(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// Live position update during a drag gesture.
///
/// Emitted on every frame while the user moves an item along the
/// timeline so the canvas can mirror the seek preview.
class TimelineOverlayDragMoved extends TimelineOverlayEvent {
  const TimelineOverlayDragMoved(this.position);

  final Duration position;

  @override
  List<Object?> get props => [position];
}

/// Signal that the current drag gesture ended.
class TimelineOverlayDragEnded extends TimelineOverlayEvent {
  const TimelineOverlayDragEnded();
}

/// Signal that a trim gesture started for an item.
class TimelineOverlayTrimStarted extends TimelineOverlayEvent {
  const TimelineOverlayTrimStarted(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// Signal that the current trim gesture ended.
class TimelineOverlayTrimEnded extends TimelineOverlayEvent {
  const TimelineOverlayTrimEnded();
}

/// Toggle collapse / expand for a strip type.
class TimelineOverlayCollapseToggled extends TimelineOverlayEvent {
  const TimelineOverlayCollapseToggled(this.type);

  final TimelineOverlayType type;

  @override
  List<Object?> get props => [type];
}

/// Clamp all overlay items so they fit within [totalDuration].
///
/// Dispatched whenever the clips' total duration changes.
class TimelineOverlayTotalDurationChanged extends TimelineOverlayEvent {
  const TimelineOverlayTotalDurationChanged(
    this.totalDuration, {
    this.isClipTrimDragging = false,
  });

  final Duration totalDuration;

  /// Whether a clip trim drag is still in flight.
  ///
  /// The total changes on every frame of that drag, so a sound bar covering
  /// the end is re-clamped continuously. Re-scheduling the preview player's
  /// native audio each time would churn it per frame, so the handler skips the
  /// player bump while this is set. (Clip trims never re-sync the sound to the
  /// new composition length, drag or not — a separate, pre-existing gap.)
  final bool isClipTrimDragging;

  @override
  List<Object?> get props => [totalDuration, isClipTrimDragging];
}

/// Add a timeline marker at the given playhead [position].
class TimelineMarkerAdded extends TimelineOverlayEvent {
  const TimelineMarkerAdded({
    required this.position,
    required this.totalDuration,
  });

  final Duration position;
  final Duration totalDuration;

  @override
  List<Object?> get props => [position, totalDuration];
}

/// Remove the timeline marker at [position].
class TimelineMarkerRemoved extends TimelineOverlayEvent {
  const TimelineMarkerRemoved(this.position);

  final Duration position;

  @override
  List<Object?> get props => [position];
}

/// Replace marker positions after a clip-order change.
///
/// This intentionally does not bump [TimelineOverlayState.timelineMarkersRevision]:
/// clip reorder writes the rebased markers together with the clip order in one
/// editor-history entry.
class TimelineMarkersRebased extends TimelineOverlayEvent {
  const TimelineMarkersRebased(this.markers);

  final List<Duration> markers;

  @override
  List<Object?> get props => [markers];
}

/// Live-reposition anchored sound items to follow a clip trim in progress.
///
/// Dispatched on every frame of a clip trim drag so the anchored audio bar
/// tracks the clip's left edge in real time (J-Cut). Only the visual sound
/// item positions are updated — the source [AudioEvent] tracks, the native
/// player, and the editor history are reconciled once on release via
/// `setClipState`.
class TimelineOverlayAnchoredAudioRebased extends TimelineOverlayEvent {
  const TimelineOverlayAnchoredAudioRebased(this.audioTracks);

  /// The re-anchored tracks; only their [AudioEvent.startTime] /
  /// [AudioEvent.endTime] are read to move the matching sound items.
  final List<AudioEvent> audioTracks;

  @override
  List<Object?> get props => [audioTracks];
}

/// Attach extracted waveform samples to a sound item.
class TimelineOverlayWaveformLoaded extends TimelineOverlayEvent {
  const TimelineOverlayWaveformLoaded({
    required this.itemId,
    required this.leftChannel,
    this.rightChannel,
    this.sourceDuration,
  });

  final String itemId;
  final Float32List leftChannel;
  final Float32List? rightChannel;

  /// Duration the extractor measured while reading the samples.
  ///
  /// Extraction always covers the whole source, so this is the source
  /// duration — the basis the waveform painter maps samples to time against.
  /// Supplied so a sound whose [AudioEvent.duration] never resolved still gets
  /// one; ignored when the item already has a basis from the track.
  final Duration? sourceDuration;

  @override
  List<Object?> get props => [
    itemId,
    leftChannel,
    rightChannel,
    sourceDuration,
  ];
}

/// Update the volume of a custom audio track by its [AudioEvent.id].
/// [volume] is clamped to [0.0, 1.0] by the handler.
class TimelineOverlayAudioVolumeChanged extends TimelineOverlayEvent {
  const TimelineOverlayAudioVolumeChanged({
    required this.trackId,
    required this.volume,
  });

  final String trackId;
  final double volume;

  @override
  List<Object?> get props => [trackId, volume];
}

/// Set the same [volume] on every audio track except clip-anchored original
/// sound.
/// [volume] is clamped to [0.0, 1.0] by the handler.
class TimelineOverlayAllAudioVolumeChanged extends TimelineOverlayEvent {
  const TimelineOverlayAllAudioVolumeChanged({required this.volume});

  final double volume;

  @override
  List<Object?> get props => [volume];
}

/// Enter draw-layer multi-select mode, seeded with [initialLayerId].
///
/// Clears the single-item selection. The seed id is only added when it maps to
/// an existing mergeable draw layer.
class TimelineOverlayLayerMultiSelectStarted extends TimelineOverlayEvent {
  const TimelineOverlayLayerMultiSelectStarted(this.initialLayerId);

  final String initialLayerId;

  @override
  List<Object?> get props => [initialLayerId];
}

/// Toggle a draw layer's membership in the multi-select set.
///
/// No-op when not in multi-select mode or when [layerId] is not a mergeable
/// draw layer.
class TimelineOverlayLayerMultiSelectToggled extends TimelineOverlayEvent {
  const TimelineOverlayLayerMultiSelectToggled(this.layerId);

  final String layerId;

  @override
  List<Object?> get props => [layerId];
}

/// Exit draw-layer multi-select mode and clear the selection.
class TimelineOverlayLayerMultiSelectCancelled extends TimelineOverlayEvent {
  const TimelineOverlayLayerMultiSelectCancelled();
}
