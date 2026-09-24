part of 'video_recorder_bloc.dart';

/// Base event type for [VideoRecorderBloc].
sealed class VideoRecorderEvent extends Equatable {
  const VideoRecorderEvent();

  @override
  List<Object?> get props => [];
}

/// Initializes the camera. Restores last-used recorder mode and lens
/// from preferences.
final class VideoRecorderInitializeRequested extends VideoRecorderEvent {
  const VideoRecorderInitializeRequested({
    this.videoQuality = VideoEditorConstants.quality,
    this.fromEditor = false,
    this.recorderMode,
    this.autoStartRecording = false,
  });

  final DivineVideoQuality videoQuality;

  /// Whether the recorder was opened as an overlay from the video editor.
  ///
  /// When `true`, the persisted recorder mode is NOT restored on init, so
  /// reopening the camera from the editor cannot wipe in-memory editor state
  /// (title, description, clips) via a stale `classic`/`upload` mode.
  final bool fromEditor;

  /// Mode to open in instead of the persisted last-used one.
  ///
  /// Persisted as the new last-used mode before the camera starts, so a
  /// re-initialization later in the session (returning from the editor or
  /// the library) restores this mode rather than the previous session's —
  /// which would clear the clips recorded in it. Ignored when [fromEditor]
  /// is `true`: the editor reopens the camera in the session's current mode.
  final VideoRecorderMode? recorderMode;

  /// Starts recording as soon as the camera is ready.
  ///
  /// Dispatches [VideoRecorderRecordingStartRequested] at the end of a
  /// successful initialization; a camera that fails to initialize never
  /// starts recording. Used by the bottom-nav hold-to-record shortcut.
  final bool autoStartRecording;

  @override
  List<Object?> get props => [
    videoQuality,
    fromEditor,
    recorderMode,
    autoStartRecording,
  ];
}

/// Forwarded from `WidgetsBindingObserver.didChangeAppLifecycleState`.
final class VideoRecorderAppLifecycleChanged extends VideoRecorderEvent {
  const VideoRecorderAppLifecycleChanged(this.state);

  final AppLifecycleState state;

  @override
  List<Object?> get props => [state];
}

/// Temporarily pauses remote record control (volume buttons / Bluetooth).
///
/// Call when opening screens that need to play audio (e.g. Sounds picker)
/// to release MediaSession to the system audio session.
final class VideoRecorderRemoteRecordPaused extends VideoRecorderEvent {
  const VideoRecorderRemoteRecordPaused();
}

/// Resumes remote record control after [VideoRecorderRemoteRecordPaused].
final class VideoRecorderRemoteRecordResumed extends VideoRecorderEvent {
  const VideoRecorderRemoteRecordResumed();
}

/// Cycles flash mode `off → torch → auto → off`.
final class VideoRecorderFlashToggled extends VideoRecorderEvent {
  const VideoRecorderFlashToggled();
}

/// Toggles aspect ratio between square (1:1) and vertical (9:16).
final class VideoRecorderAspectRatioToggled extends VideoRecorderEvent {
  const VideoRecorderAspectRatioToggled();
}

/// Sets aspect ratio directly.
final class VideoRecorderAspectRatioSet extends VideoRecorderEvent {
  const VideoRecorderAspectRatioSet(this.ratio);

  final model.AspectRatio ratio;

  @override
  List<Object?> get props => [ratio];
}

/// Switches between front and back camera.
final class VideoRecorderCameraSwitched extends VideoRecorderEvent {
  const VideoRecorderCameraSwitched();
}

/// Sets the video stabilization mode.
final class VideoRecorderStabilizationModeSet extends VideoRecorderEvent {
  const VideoRecorderStabilizationModeSet(this.mode);

  final DivineVideoStabilizationMode mode;

  @override
  List<Object?> get props => [mode];
}

/// Switches to a specific camera lens.
final class VideoRecorderLensSet extends VideoRecorderEvent {
  const VideoRecorderLensSet(this.lens);

  final DivineCameraLens lens;

  @override
  List<Object?> get props => [lens];
}

/// Sets camera zoom level (ignored outside the camera's min/max).
final class VideoRecorderZoomLevelSet extends VideoRecorderEvent {
  const VideoRecorderZoomLevelSet(this.value);

  final double value;

  @override
  List<Object?> get props => [value];
}

/// Sets camera focus point (normalized 0..1 coordinates). The point is
/// auto-hidden ~800ms later.
final class VideoRecorderFocusPointSet extends VideoRecorderEvent {
  const VideoRecorderFocusPointSet(this.value);

  final Offset value;

  @override
  List<Object?> get props => [value];
}

/// Sets camera exposure point (normalized 0..1 coordinates).
final class VideoRecorderExposurePointSet extends VideoRecorderEvent {
  const VideoRecorderExposurePointSet(this.value);

  final Offset value;

  @override
  List<Object?> get props => [value];
}

/// Record-button tap. Dispatches start or stop depending on current
/// recording state.
final class VideoRecorderRecordingToggleRequested extends VideoRecorderEvent {
  const VideoRecorderRecordingToggleRequested();
}

/// Starts recording, including the optional countdown timer.
///
/// Registered with `transformer: sequential()` so start requests are
/// handled FIFO, one at a time.
final class VideoRecorderRecordingStartRequested extends VideoRecorderEvent {
  const VideoRecorderRecordingStartRequested();
}

/// Stops recording and processes the resulting clip (metadata,
/// thumbnail, ghost frame). When [result] is supplied, the camera
/// auto-stopped (e.g. recording limit reached, or the capture session
/// was interrupted and native salvaged what it could) and the recording
/// itself is already finalized. Without one, the camera service is asked
/// for the file: after a Stop tap, or after an auto-stop that captured
/// nothing, in which case the service reports no file.
///
/// Registered with `transformer: sequential()` — see
/// [VideoRecorderRecordingStartRequested].
final class VideoRecorderRecordingStopRequested extends VideoRecorderEvent {
  const VideoRecorderRecordingStopRequested({this.result});

  final EditorVideo? result;

  @override
  List<Object?> get props => [result];
}

/// A long-press gesture began — captures the current zoom as the base that
/// subsequent [VideoRecorderZoomedByLongPress] drags are measured from.
///
/// Recording-start already anchors the base for hold-to-record, but a
/// long-press that lands on a recording started elsewhere (tap, volume key,
/// BLE remote) never re-runs that path, so it needs its own capture.
final class VideoRecorderLongPressZoomStarted extends VideoRecorderEvent {
  const VideoRecorderLongPressZoomStarted();
}

/// Adjusts zoom by vertical drag offset during a long-press gesture.
final class VideoRecorderZoomedByLongPress extends VideoRecorderEvent {
  const VideoRecorderZoomedByLongPress(this.offsetFromOrigin);

  final Offset offsetFromOrigin;

  @override
  List<Object?> get props => [offsetFromOrigin];
}

/// Pinch-to-zoom gesture started — captures the base zoom level.
final class VideoRecorderScaleStarted extends VideoRecorderEvent {
  const VideoRecorderScaleStarted(this.details);

  final ScaleStartDetails details;

  @override
  List<Object?> get props => [details];
}

/// Pinch-to-zoom gesture update — drives the snap-to-1x detent.
final class VideoRecorderScaleUpdated extends VideoRecorderEvent {
  const VideoRecorderScaleUpdated(this.details);

  final ScaleUpdateDetails details;

  @override
  List<Object?> get props => [details];
}

/// Scale gesture on the preview ended (all pointers lifted or the pointer
/// configuration changed) — releases the zoom ruler's pinch guard.
final class VideoRecorderScaleEnded extends VideoRecorderEvent {
  const VideoRecorderScaleEnded();
}

/// Disposes the camera service so the next route can take over the
/// AVAudioSession cleanly. The View dispatches this while navigating
/// away from the recorder, once the push transition is past the visible
/// frame. Pair with [VideoRecorderInitializeRequested] on return.
final class VideoRecorderCameraPausedForNavigation extends VideoRecorderEvent {
  const VideoRecorderCameraPausedForNavigation({this.completion});

  /// Optional completion signal for callers that must run after camera dispose.
  final Completer<void>? completion;

  @override
  List<Object?> get props => [completion];
}

/// Locks recording and detaches the remote (volume / Bluetooth) trigger the
/// moment a navigation push away from the recorder begins — while the camera is
/// still live, before [VideoRecorderCameraPausedForNavigation] disposes it.
///
/// Dispatched at the start of a navigation flow so a remote trigger that races
/// the push can't start (or leave) a recording on a camera that is about to be
/// torn down, which would otherwise strand the recorder. Cleared by
/// [VideoRecorderInitializeRequested] on return.
final class VideoRecorderRecordingLockedForNavigation
    extends VideoRecorderEvent {
  const VideoRecorderRecordingLockedForNavigation();
}

/// Sets the recorder mode. Switching between recording modes clears
/// recorded clips and resets the editor; transitions involving
/// [VideoRecorderMode.upload] preserve both.
final class VideoRecorderRecorderModeSet extends VideoRecorderEvent {
  const VideoRecorderRecorderModeSet(
    this.mode, {
    this.keepAutosavedDraft = false,
  });

  final VideoRecorderMode mode;

  /// When true the autosaved draft in the database is preserved.
  final bool keepAutosavedDraft;

  @override
  List<Object?> get props => [mode, keepAutosavedDraft];
}

/// Cycles timer duration `off → 3s → 10s → off`.
final class VideoRecorderTimerCycled extends VideoRecorderEvent {
  const VideoRecorderTimerCycled();
}

/// Resets recorder state to its initial values.
final class VideoRecorderResetRequested extends VideoRecorderEvent {
  const VideoRecorderResetRequested();
}

/// Toggles the ghost-frame overlay of the last clip on the preview.
final class VideoRecorderShowLastClipOverlayToggled extends VideoRecorderEvent {
  const VideoRecorderShowLastClipOverlayToggled();
}

/// Toggles the rule-of-thirds grid overlay on the preview.
final class VideoRecorderGridLinesToggled extends VideoRecorderEvent {
  const VideoRecorderGridLinesToggled();
}

// === Stop-motion events ===

/// Captures a single still in stop-motion mode and appends it to
/// [VideoRecorderBlocState.stopMotionFrames]. No video is rendered here —
/// frames are encoded into one video only at publish, so capture stays
/// instant.
///
/// Registered with `transformer: droppable()` so rapid taps can't fire
/// overlapping captures.
final class VideoRecorderStopMotionFrameCaptured extends VideoRecorderEvent {
  const VideoRecorderStopMotionFrameCaptured();
}

/// Removes the most recently captured stop-motion frame and deletes its file.
final class VideoRecorderStopMotionFrameUndone extends VideoRecorderEvent {
  const VideoRecorderStopMotionFrameUndone();
}

/// Adds all captured stop-motion frames to the clip manager as one
/// frames-based clip, and signals the UI (via [StopMotionStatus.ready]) to
/// open the editor.
final class VideoRecorderStopMotionAssembleRequested
    extends VideoRecorderEvent {
  const VideoRecorderStopMotionAssembleRequested();
}

// === Internal events dispatched from service callbacks ===

/// Internal event: camera service reported a state change
/// (capabilities, sensor, force rebuild). Dispatched from the
/// `CameraService.onUpdateState` callback.
final class _VideoRecorderCameraStateChanged extends VideoRecorderEvent {
  const _VideoRecorderCameraStateChanged({this.cameraRebuildCount});

  final int? cameraRebuildCount;

  @override
  List<Object?> get props => [cameraRebuildCount];
}

/// Internal event: a remote-record trigger fired (volume button /
/// Bluetooth media key). Dispatched from the
/// `CameraService.setOnRemoteRecordTrigger` callback.
final class _VideoRecorderRemoteRecordTriggered extends VideoRecorderEvent {
  const _VideoRecorderRemoteRecordTriggered();
}

/// Internal event: the camera auto-stopped recording on its own, without a
/// user Stop tap — e.g. it hit the recording limit, or the capture session
/// was interrupted (the app was backgrounded mid-recording) and the native
/// layer salvaged whatever was captured before the interruption. [video] is
/// null when nothing was captured. Dispatched from the
/// `CameraService.onAutoStopped` callback.
final class _VideoRecorderAutoStopped extends VideoRecorderEvent {
  const _VideoRecorderAutoStopped(this.video);

  final EditorVideo? video;

  @override
  List<Object?> get props => [video];
}

/// Internal event: the focus-point auto-hide timer fired. Resets
/// [VideoRecorderBlocState.focusPoint] back to [Offset.zero].
final class _VideoRecorderFocusPointTimerFired extends VideoRecorderEvent {
  const _VideoRecorderFocusPointTimerFired();
}

/// Internal event: the zoom-indicator auto-hide timer fired. Clears
/// [VideoRecorderBlocState.showZoomIndicator] once the pinch settles.
final class _VideoRecorderZoomIndicatorTimerFired extends VideoRecorderEvent {
  const _VideoRecorderZoomIndicatorTimerFired();
}
