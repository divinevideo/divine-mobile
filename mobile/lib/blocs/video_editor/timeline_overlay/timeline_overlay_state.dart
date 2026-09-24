part of 'timeline_overlay_bloc.dart';

/// State for the timeline overlay editor.
class TimelineOverlayState extends Equatable {
  const TimelineOverlayState({
    this.items = const [],
    this.audioTracks = const [],
    this.audioTracksRevision = 0,
    this.audioTracksPlayerRevision = 0,
    this.timelineMarkersRevision = 0,
    this.selectedItemId,
    this.draggingItemId,
    this.dragPosition,
    this.trimmingItemId,
    this.trimPosition,
    this.collapsedTypes = const {},
    this.timelineMarkers = const [],
    this.isLayerMultiSelectMode = false,
    this.multiSelectedLayerIds = const {},
    this.captionsBurnIn = false,
  });

  /// All overlay items across all strip types.
  final List<TimelineOverlayItem> items;

  /// Source audio events for the current sound items.
  ///
  /// Stored so the presentation layer can build native [AudioTrack]s
  /// with the correct URL / asset path without reaching into Riverpod.
  final List<AudioEvent> audioTracks;

  /// Incremented each time any audio track's volume changes.
  ///
  /// Because [AudioEvent] equality intentionally excludes [AudioEvent.volume]
  /// (identity-based semantics), Equatable cannot detect volume-only changes
  /// via the [audioTracks] list. This counter forces a distinct state whenever
  /// [TimelineOverlayAudioVolumeChanged] is handled, ensuring [BlocListener]s
  /// in the canvas observe the volume update and call `_syncAudioTracks()`.
  final int audioTracksRevision;

  /// Incremented in [TimelineOverlayItemsUpdate] when any audio track's
  /// volume differs from the previously stored volume, and in
  /// [TimelineOverlayTotalDurationChanged] when a re-clamp moves a sound
  /// window outside a clip trim drag.
  ///
  /// This handles undo/redo restores: after an undo the ProImageEditor's
  /// `activeMeta` reverts to the old volumes, `_syncMainCapabilities`
  /// dispatches a [TimelineOverlayItemsUpdate] with those old volumes, and
  /// this counter makes the resulting state distinct from the current state
  /// so that Equatable does not suppress the `emit` and the player-sync
  /// listener fires.
  ///
  /// Deliberately separate from [audioTracksRevision] — the write-to-history
  /// [BlocListener] only watches [audioTracksRevision], so incrementing
  /// [audioTracksPlayerRevision] does NOT trigger a new [ProImageEditor]
  /// history entry (which would corrupt the undo stack).
  final int audioTracksPlayerRevision;

  /// Incremented when marker changes should be persisted to editor history.
  final int timelineMarkersRevision;

  /// The currently selected item (shows trim handles), or `null`.
  final String? selectedItemId;

  /// The item being dragged, or `null`.
  final String? draggingItemId;

  /// The live startTime of the item currently being dragged.
  ///
  /// Set to the dragged item's `startTime` while a move gesture is
  /// active; `null` when no drag is in progress.
  final Duration? dragPosition;

  /// The item being trimmed, or `null`.
  final String? trimmingItemId;

  /// The live position of the trim handle currently being dragged.
  ///
  /// Set to the dragged item's `startTime` or `endTime` while a trim gesture
  /// is active; `null` when no trim is in progress.
  final Duration? trimPosition;

  /// Strip types that are in collapsed view.
  final Set<TimelineOverlayType> collapsedTypes;

  /// Timeline marker positions used for visual guides and snapping.
  final List<Duration> timelineMarkers;

  /// Whether the timeline is in draw-layer multi-select mode.
  ///
  /// While active, tapping a mergeable draw-layer overlay toggles its
  /// membership in [multiSelectedLayerIds] instead of single-selecting it, and
  /// the multi-select control bar (Combine / Done) replaces the per-layer one.
  final bool isLayerMultiSelectMode;

  /// The layer ids currently selected for combining. Only meaningful while
  /// [isLayerMultiSelectMode] is `true`.
  final Set<String> multiSelectedLayerIds;

  /// Whether the caption track is burned into the video.
  ///
  /// When `true`, the burned-in caption layers render on the canvas and the
  /// CC preview pill is suppressed. Tracked in state (rather than read live
  /// from the editor) so the pill hides reactively the moment burn-in is
  /// toggled, not on the next scroll-driven rebuild.
  final bool captionsBurnIn;

  TimelineOverlayState copyWith({
    List<TimelineOverlayItem>? items,
    List<AudioEvent>? audioTracks,
    int? audioTracksRevision,
    int? audioTracksPlayerRevision,
    int? timelineMarkersRevision,
    String? selectedItemId,
    bool clearSelectedItemId = false,
    String? draggingItemId,
    bool clearDraggingItemId = false,
    Duration? dragPosition,
    bool clearDragPosition = false,
    String? trimmingItemId,
    bool clearTrimmingItemId = false,
    Duration? trimPosition,
    bool clearTrimPosition = false,
    Set<TimelineOverlayType>? collapsedTypes,
    List<Duration>? timelineMarkers,
    bool? isLayerMultiSelectMode,
    Set<String>? multiSelectedLayerIds,
    bool? captionsBurnIn,
  }) {
    return TimelineOverlayState(
      items: items ?? this.items,
      audioTracks: audioTracks ?? this.audioTracks,
      audioTracksRevision: audioTracksRevision ?? this.audioTracksRevision,
      audioTracksPlayerRevision:
          audioTracksPlayerRevision ?? this.audioTracksPlayerRevision,
      timelineMarkersRevision:
          timelineMarkersRevision ?? this.timelineMarkersRevision,
      selectedItemId: clearSelectedItemId
          ? null
          : (selectedItemId ?? this.selectedItemId),
      draggingItemId: clearDraggingItemId
          ? null
          : (draggingItemId ?? this.draggingItemId),
      dragPosition: clearDragPosition
          ? null
          : (dragPosition ?? this.dragPosition),
      trimmingItemId: clearTrimmingItemId
          ? null
          : (trimmingItemId ?? this.trimmingItemId),
      trimPosition: clearTrimPosition
          ? null
          : (trimPosition ?? this.trimPosition),
      collapsedTypes: collapsedTypes ?? this.collapsedTypes,
      timelineMarkers: timelineMarkers ?? this.timelineMarkers,
      isLayerMultiSelectMode:
          isLayerMultiSelectMode ?? this.isLayerMultiSelectMode,
      multiSelectedLayerIds:
          multiSelectedLayerIds ?? this.multiSelectedLayerIds,
      captionsBurnIn: captionsBurnIn ?? this.captionsBurnIn,
    );
  }

  @override
  List<Object?> get props => [
    items,
    audioTracks,
    audioTracksRevision,
    audioTracksPlayerRevision,
    timelineMarkersRevision,
    selectedItemId,
    draggingItemId,
    dragPosition,
    trimmingItemId,
    trimPosition,
    collapsedTypes,
    timelineMarkers,
    isLayerMultiSelectMode,
    multiSelectedLayerIds,
    captionsBurnIn,
  ];
}
