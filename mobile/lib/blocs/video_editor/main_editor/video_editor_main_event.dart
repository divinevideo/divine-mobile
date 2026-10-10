part of 'video_editor_main_bloc.dart';

/// Base class for all video editor main events.
sealed class VideoEditorMainEvent extends Equatable {
  const VideoEditorMainEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when editor capabilities change (undo/redo availability).
///
/// This event carries the current state from the editor widget, allowing the
/// BLoC to update its state without directly accessing the widget.
class VideoEditorMainCapabilitiesChanged extends VideoEditorMainEvent {
  const VideoEditorMainCapabilitiesChanged({
    required this.canUndo,
    required this.canRedo,
    this.layers,
  });

  final bool canUndo;
  final bool canRedo;

  /// The current list of active layers, or `null` if unchanged.
  final List<Layer>? layers;

  @override
  List<Object?> get props => [canUndo, canRedo, layers];
}

/// Triggered when layer interaction (scaling/rotating) starts.
class VideoEditorLayerInteractionStarted extends VideoEditorMainEvent {
  const VideoEditorLayerInteractionStarted();
}

/// Triggered when layer interaction (scaling/rotating) ends.
class VideoEditorLayerInteractionEnded extends VideoEditorMainEvent {
  const VideoEditorLayerInteractionEnded();
}

/// Triggered when the layer position relative to the remove area changes.
class VideoEditorLayerOverRemoveAreaChanged extends VideoEditorMainEvent {
  const VideoEditorLayerOverRemoveAreaChanged({required this.isOver});

  final bool isOver;

  @override
  List<Object?> get props => [isOver];
}

/// Triggered when a sub-editor (text, paint, filter) should be opened.
class VideoEditorMainOpenSubEditor extends VideoEditorMainEvent {
  const VideoEditorMainOpenSubEditor(this.type);

  final SubEditorType type;

  @override
  List<Object?> get props => [type];
}

/// Triggered when a sub-editor is closed.
class VideoEditorMainSubEditorClosed extends VideoEditorMainEvent {
  const VideoEditorMainSubEditorClosed();
}

/// Triggered when the video playback state changes.
class VideoEditorPlaybackChanged extends VideoEditorMainEvent {
  const VideoEditorPlaybackChanged({required this.isPlaying});

  final bool isPlaying;

  @override
  List<Object?> get props => [isPlaying];
}

/// Triggered when the video player readiness state changes.
class VideoEditorPlayerReady extends VideoEditorMainEvent {
  const VideoEditorPlayerReady({this.isReady = true});

  /// Whether the player is ready for playback.
  final bool isReady;

  @override
  List<Object?> get props => [isReady];
}

/// Triggered when an external component requests playback pause/resume.
class VideoEditorExternalPauseRequested extends VideoEditorMainEvent {
  const VideoEditorExternalPauseRequested({required this.isPaused});

  final bool isPaused;

  @override
  List<Object?> get props => [isPaused];
}

/// Triggered when playback restart is requested (video + audio sync).
class VideoEditorPlaybackRestartRequested extends VideoEditorMainEvent {
  const VideoEditorPlaybackRestartRequested();
}

/// Triggered when playback toggle (play/pause) is requested.
class VideoEditorPlaybackToggleRequested extends VideoEditorMainEvent {
  const VideoEditorPlaybackToggleRequested();
}

/// Triggered when the timeline requests a seek to a specific position.
class VideoEditorSeekRequested extends VideoEditorMainEvent {
  const VideoEditorSeekRequested(this.position);

  final Duration position;

  @override
  List<Object?> get props => [position];
}

/// Plays [start] to [end] on the timeline in a loop until
/// [VideoEditorAuditionEnded], starting playback if it was paused: a sheet
/// that changes how that stretch sounds plays it while it is open.
class VideoEditorAuditionStarted extends VideoEditorMainEvent {
  const VideoEditorAuditionStarted({required this.start, required this.end});

  final Duration start;
  final Duration end;

  @override
  List<Object?> get props => [start, end];
}

/// Ends the audition started by [VideoEditorAuditionStarted], pausing
/// playback again if the audition started it.
class VideoEditorAuditionEnded extends VideoEditorMainEvent {
  const VideoEditorAuditionEnded();
}

/// Triggered when the video player reports a new playback position.
class VideoEditorPositionChanged extends VideoEditorMainEvent {
  const VideoEditorPositionChanged(this.position);

  final Duration position;

  @override
  List<Object?> get props => [position];
}

/// Triggered when the video player reports total duration.
class VideoEditorDurationChanged extends VideoEditorMainEvent {
  const VideoEditorDurationChanged(this.duration, {this.isShortLoop = false});

  final Duration duration;

  /// Whether the native player's looping composition is shorter than the
  /// timeline chase animation. This uses player duration, which can differ
  /// from the editor duration when a rendered transition seam is present.
  final bool isShortLoop;

  @override
  List<Object?> get props => [duration, isShortLoop];
}

/// Types of sub-editors that can be opened.
enum SubEditorType {
  text,
  draw,
  filter,
  tune,

  /// The video effects editor (glitch, VHS, pixelate). App-owned: it is not a
  /// pro_image_editor sub-editor, so the canvas stays the main editor's.
  effects,
  stickers,
  music,
  clips,
  captions,

  /// The voice-over recorder. It sits over the editor as a translucent route,
  /// so the preview plays on beneath it — muted, with the timeline and the
  /// editor's own controls stepped aside.
  voiceOver,
}

/// Triggered when the user toggles volume edit mode in the timeline.
class VideoEditorVolumeEditModeToggled extends VideoEditorMainEvent {
  const VideoEditorVolumeEditModeToggled();
}

/// Triggered when clip reorder mode is toggled.
class VideoEditorReorderingChanged extends VideoEditorMainEvent {
  const VideoEditorReorderingChanged({required this.isReordering});

  final bool isReordering;

  @override
  List<Object?> get props => [isReordering];
}

/// Triggered when the timeline visibility should be toggled.
class VideoEditorTimelineVisibilityToggled extends VideoEditorMainEvent {
  const VideoEditorTimelineVisibilityToggled();
}

/// Enters or exits marker-placement mode.
class VideoEditorMarkerModeChanged extends VideoEditorMainEvent {
  const VideoEditorMarkerModeChanged({required this.isActive});

  final bool isActive;

  @override
  List<Object?> get props => [isActive];
}

/// Enters or exits the mode that places a layer's custom slide point.
///
/// While active the editor gives the canvas the whole screen: the timeline and
/// the editor's own actions step aside so the video is as large as it can be
/// and no chrome sits between the finger and the frame.
class VideoEditorSlidePointPlacementChanged extends VideoEditorMainEvent {
  const VideoEditorSlidePointPlacementChanged({required this.isPlacing});

  final bool isPlacing;

  @override
  List<Object?> get props => [isPlacing];
}

/// Shows [preview] on a detached clip's layer without touching the editor
/// history, or ends the preview when it is `null`.
class VideoEditorDetachedClipOpacityPreviewChanged
    extends VideoEditorMainEvent {
  const VideoEditorDetachedClipOpacityPreviewChanged(this.preview);

  final DetachedClipOpacityPreview? preview;

  @override
  List<Object?> get props => [preview];
}
