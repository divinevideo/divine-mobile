part of 'video_editor_main_bloc.dart';

/// An opacity shown on a detached clip's layer while it is being adjusted,
/// before it is written to the editor history.
typedef DetachedClipOpacityPreview = ({String layerId, double opacity});

/// A stretch of the timeline that playback loops over while a sheet plays
/// it; see [VideoEditorAuditionStarted]. One whose `end` lies before its
/// `start` runs across the loop point.
typedef PlaybackAudition = ({Duration start, Duration end});

/// Whether [position] lies within [audition].
bool auditionContains(PlaybackAudition audition, Duration position) =>
    audition.end > audition.start
    ? position >= audition.start && position < audition.end
    : position >= audition.start || position < audition.end;

/// State for the video editor main screen.
class VideoEditorMainState extends Equatable {
  const VideoEditorMainState({
    this.canUndo = false,
    this.canRedo = false,
    this.openSubEditor,
    this.isLayerInteractionActive = false,
    this.isLayerOverRemoveArea = false,
    this.isPlaying = false,
    this.isPlayerReady = false,
    this.isExternalPauseRequested = false,
    this.playbackRestartCounter = 0,
    this.playbackToggleCounter = 0,
    this.seekPosition = Duration.zero,
    this.seekCounter = 0,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.isShortLoop = false,
    this.isVolumeEditMode = false,
    this.isReordering = false,
    this.isTimelineHiddenByUser = false,
    this.isMarkerMode = false,
    this.isPlacingSlidePoint = false,
    this.isEditingMask = false,
    this.isEditingClipMotion = false,
    this.isMarkingTrackRegion = false,
    this.detachedClipOpacityPreview,
    this.audition,
    this.auditionOwner,
    this.pausesAfterAudition = false,
    this.isAuditionSeekPending = false,
    this.isFinishing = false,
    this.finishCounter = 0,
    this.handOverCounter = 0,
  });

  /// Whether the undo action is available.
  final bool canUndo;

  /// Whether the redo action is available.
  final bool canRedo;

  /// The currently open sub-editor, or `null` if none is open.
  final SubEditorType? openSubEditor;

  /// Whether a sub-editor is currently open.
  bool get isSubEditorOpen => openSubEditor != null;

  /// Whether the user is currently interacting with a layer (scaling/rotating).
  final bool isLayerInteractionActive;

  /// Whether the layer is currently positioned over the remove area.
  final bool isLayerOverRemoveArea;

  /// Whether the video is currently playing.
  final bool isPlaying;

  /// Whether the video player is ready for playback.
  final bool isPlayerReady;

  /// Whether an external component has requested playback pause.
  final bool isExternalPauseRequested;

  /// Counter that increments when playback restart is requested.
  ///
  /// Used by BlocListener to trigger video restart from beginning.
  final int playbackRestartCounter;

  /// Counter that increments when playback toggle is requested.
  ///
  /// Used by BlocListener to trigger play/pause toggle.
  final int playbackToggleCounter;

  /// The position to seek to, set by the timeline during scrubbing.
  final Duration seekPosition;

  /// Counter that increments when a seek is requested.
  ///
  /// Used by BlocListener to trigger video player seekTo.
  final int seekCounter;

  /// Current playback position reported by the video player.
  final Duration currentPosition;

  /// Total duration of all clips reported by the video player.
  final Duration totalDuration;

  /// Whether the native preview loop is shorter than the timeline's glide.
  final bool isShortLoop;

  /// Whether the timeline is in volume edit mode.
  final bool isVolumeEditMode;

  /// Whether the timeline is in clip reorder mode.
  final bool isReordering;

  /// Whether timeline visibility was manually toggled off by the user.
  final bool isTimelineHiddenByUser;

  /// Whether the timeline is in marker-placement mode.
  ///
  /// While active, the bottom controls bar shows add/delete-marker actions so
  /// the user can drop markers repeatedly while playback runs.
  final bool isMarkerMode;

  /// Whether a layer's custom slide point is being placed on the canvas.
  ///
  /// While active the timeline and the editor's own actions step aside, so the
  /// video fills the screen and every part of it can be tapped.
  final bool isPlacingSlidePoint;

  /// Whether the shape mask editor is open over the canvas.
  ///
  /// While it is, the timeline and the editor's own actions step aside as for
  /// [isPlacingSlidePoint]; the mask editor brings its own controls.
  final bool isEditingMask;

  /// Whether the motion editor of a timeline clip is open over the canvas.
  ///
  /// While it is, the timeline and the editor's own actions step aside as for
  /// [isEditingMask]; the motion editor brings its own controls.
  final bool isEditingClipMotion;

  /// Whether the object a layer is tracked to is being framed on the canvas.
  ///
  /// While it is, the timeline and the editor's own actions step aside as for
  /// [isPlacingSlidePoint]; the region picker brings its own controls.
  final bool isMarkingTrackRegion;

  /// The opacity a detached clip shows while its slider is being dragged, or
  /// `null` when no clip is being adjusted.
  ///
  /// Kept out of the layer until the change is confirmed: writing every slider
  /// step to the editor history would turn one adjustment into dozens of undo
  /// steps, and cancelling has to put the layer back exactly as it was.
  final DetachedClipOpacityPreview? detachedClipOpacityPreview;

  /// The stretch playback loops over while a sheet plays it, or `null`.
  final PlaybackAudition? audition;

  /// The operation that owns the active audition, when one was supplied.
  final String? auditionOwner;

  /// Whether playback was paused when the [audition] started, and pauses
  /// again when it ends.
  final bool pausesAfterAudition;

  /// Whether the [audition] has asked for a seek back to its start that the
  /// player has not reported yet, so it is not asked for again meanwhile.
  final bool isAuditionSeekPending;

  /// Whether Done was tapped and the edit is being handed to the export,
  /// which first waits for the fonts its stickers draw in; Done is off
  /// meanwhile, so the edit is handed over once.
  final bool isFinishing;

  /// Counts Done requests, so one that was cancelled and replaced while its
  /// fonts loaded does not hand over.
  final int finishCounter;

  /// Incremented when the edit is ready to be handed over to the export; the
  /// editor listens and finishes.
  final int handOverCounter;

  /// Whether the voice-over recorder is open over the editor.
  ///
  /// The preview keeps playing beneath its translucent route so the take can
  /// be timed against the picture, but silently: the editor's own audio would
  /// otherwise play out of the speaker and straight back into the microphone.
  bool get isVoiceOverPreview => openSubEditor == SubEditorType.voiceOver;

  /// Whether the timeline and the editor's own actions step aside so the video
  /// fills the screen: while a slide point is being placed, a shape mask
  /// shaped, a clip's motion set or a tracked object framed, and while the
  /// voice-over recorder shows the preview behind its own controls.
  bool get isCanvasFullscreen =>
      isPlacingSlidePoint ||
      isEditingMask ||
      isEditingClipMotion ||
      isMarkingTrackRegion ||
      isVoiceOverPreview;

  /// Creates a copy with the given fields replaced.
  ///
  /// Use [clearOpenSubEditor] to explicitly close the sub-editor,
  /// [clearDetachedClipOpacityPreview] to end an opacity preview and
  /// [clearAudition] to end an audition. Supplying a replacement [audition]
  /// also replaces its owner, including clearing an omitted owner.
  VideoEditorMainState copyWith({
    bool? canUndo,
    bool? canRedo,
    SubEditorType? openSubEditor,
    bool clearOpenSubEditor = false,
    bool? isLayerInteractionActive,
    bool? isLayerOverRemoveArea,
    bool? isVolumeEditMode,
    bool? isPlaying,
    bool? isPlayerReady,
    bool? isExternalPauseRequested,
    int? playbackRestartCounter,
    int? playbackToggleCounter,
    Duration? seekPosition,
    int? seekCounter,
    Duration? currentPosition,
    Duration? totalDuration,
    bool? isShortLoop,
    bool? isReordering,
    bool? isTimelineHiddenByUser,
    bool? isMarkerMode,
    bool? isPlacingSlidePoint,
    bool? isEditingMask,
    bool? isEditingClipMotion,
    bool? isMarkingTrackRegion,
    DetachedClipOpacityPreview? detachedClipOpacityPreview,
    bool clearDetachedClipOpacityPreview = false,
    PlaybackAudition? audition,
    String? auditionOwner,
    bool clearAudition = false,
    bool? pausesAfterAudition,
    bool? isAuditionSeekPending,
    bool? isFinishing,
    int? finishCounter,
    int? handOverCounter,
  }) {
    return VideoEditorMainState(
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      openSubEditor: clearOpenSubEditor
          ? null
          : (openSubEditor ?? this.openSubEditor),
      isLayerInteractionActive:
          isLayerInteractionActive ?? this.isLayerInteractionActive,
      isLayerOverRemoveArea:
          isLayerOverRemoveArea ?? this.isLayerOverRemoveArea,
      isPlaying: isPlaying ?? this.isPlaying,
      isPlayerReady: isPlayerReady ?? this.isPlayerReady,
      isExternalPauseRequested:
          isExternalPauseRequested ?? this.isExternalPauseRequested,
      playbackRestartCounter:
          playbackRestartCounter ?? this.playbackRestartCounter,
      playbackToggleCounter:
          playbackToggleCounter ?? this.playbackToggleCounter,
      seekPosition: seekPosition ?? this.seekPosition,
      seekCounter: seekCounter ?? this.seekCounter,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      isShortLoop: isShortLoop ?? this.isShortLoop,
      isVolumeEditMode: isVolumeEditMode ?? this.isVolumeEditMode,
      isReordering: isReordering ?? this.isReordering,
      isTimelineHiddenByUser:
          isTimelineHiddenByUser ?? this.isTimelineHiddenByUser,
      isMarkerMode: isMarkerMode ?? this.isMarkerMode,
      isPlacingSlidePoint: isPlacingSlidePoint ?? this.isPlacingSlidePoint,
      isEditingMask: isEditingMask ?? this.isEditingMask,
      isEditingClipMotion: isEditingClipMotion ?? this.isEditingClipMotion,
      isMarkingTrackRegion: isMarkingTrackRegion ?? this.isMarkingTrackRegion,
      detachedClipOpacityPreview: clearDetachedClipOpacityPreview
          ? null
          : (detachedClipOpacityPreview ?? this.detachedClipOpacityPreview),
      audition: clearAudition ? null : (audition ?? this.audition),
      auditionOwner: clearAudition
          ? null
          : (audition != null
                ? auditionOwner
                : auditionOwner ?? this.auditionOwner),
      pausesAfterAudition: pausesAfterAudition ?? this.pausesAfterAudition,
      isAuditionSeekPending:
          isAuditionSeekPending ?? this.isAuditionSeekPending,
      isFinishing: isFinishing ?? this.isFinishing,
      finishCounter: finishCounter ?? this.finishCounter,
      handOverCounter: handOverCounter ?? this.handOverCounter,
    );
  }

  @override
  List<Object?> get props => [
    canUndo,
    canRedo,
    openSubEditor,
    isLayerInteractionActive,
    isLayerOverRemoveArea,
    isPlaying,
    isPlayerReady,
    isExternalPauseRequested,
    playbackRestartCounter,
    playbackToggleCounter,
    seekPosition,
    seekCounter,
    currentPosition,
    totalDuration,
    isShortLoop,
    isVolumeEditMode,
    isReordering,
    isTimelineHiddenByUser,
    isMarkerMode,
    isPlacingSlidePoint,
    isEditingMask,
    isEditingClipMotion,
    isMarkingTrackRegion,
    detachedClipOpacityPreview,
    audition,
    auditionOwner,
    pausesAfterAudition,
    isAuditionSeekPending,
    isFinishing,
    finishCounter,
    handOverCounter,
  ];
}
