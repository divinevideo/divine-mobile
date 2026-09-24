part of 'video_recorder_bloc.dart';

/// Lifecycle of the stop-motion "collect captured stills into one clip" step.
enum StopMotionStatus {
  /// No assembly in progress.
  idle,

  /// The assemble has claimed the captured stills.
  ///
  /// Transient by construction: the assemble is synchronous (no mp4 is encoded
  /// — the stills are the clip), so this is emitted and superseded within one
  /// handler and never survives to a build. It is not a "show a spinner" state;
  /// it exists so consecutive assembles of the same frame list are distinct
  /// emissions, since [Bloc.emit] drops a state equal to the current one and a
  /// repeated failure would otherwise never reach the UI.
  assembling,

  /// Assembly finished; the clip is in the manager and the editor can open.
  ready,

  /// Assembly failed.
  failure,
}

/// State for [VideoRecorderBloc].
class VideoRecorderBlocState extends Equatable {
  const VideoRecorderBlocState({
    this.recorderMode = VideoRecorderMode.capture,
    this.recordingState = VideoRecorderState.idle,
    this.zoomLevel = 1.0,
    this.minZoomLevel = 1.0,
    this.maxZoomLevel = 1.0,
    this.cameraSensorAspectRatio = 1.0,
    this.focusPoint = Offset.zero,
    this.canRecord = false,
    this.isCameraInitialized = false,
    this.canSwitchCamera = true,
    this.isFrontCamera = false,
    this.isSwitchingCamera = false,
    this.previewTextureId,
    this.hasFlash = true,
    this.countdownValue = 0,
    this.cameraRebuildCount = 0,
    this.aspectRatio = model.AspectRatio.vertical,
    this.flashMode = DivineFlashMode.auto,
    this.videoStabilizationMode = DivineVideoStabilizationMode.off,
    this.availableVideoStabilizationModes = const [
      DivineVideoStabilizationMode.off,
    ],
    this.isVideoStabilizationSupported = false,
    this.timerDuration = TimerDuration.off,
    this.initializationError,
    this.showLastClipOverlay = false,
    this.showGridLines = false,
    this.isStartingRecording = false,
    this.isStoppingRecording = false,
    this.pendingStopAfterStart = false,
    this.recordingLockedForNavigation = false,
    this.baseZoomLevel = 1.0,
    this.snappedTo1x = false,
    this.lastRawZoom = 1.0,
    this.snapTime,
    this.showZoomIndicator = false,
    this.isPinchActive = false,
    this.stopMotionFrames = const [],
    this.stopMotionStatus = StopMotionStatus.idle,
    this.stopMotionShutterTick = 0,
  });

  /// Recorder mode from the camera.
  final VideoRecorderMode recorderMode;

  /// Camera focus point in normalized coordinates (0.0-1.0).
  final Offset focusPoint;

  /// Whether recording is allowed.
  final bool canRecord;

  /// Whether the camera is initialized.
  final bool isCameraInitialized;

  /// Whether camera switching is available.
  final bool canSwitchCamera;

  /// Whether the active lens is front-facing.
  ///
  /// Drives the stop-motion onion-skin overlay: the live preview is mirrored
  /// for the front camera, so the ghost of the last still is flipped to match
  /// it (see [VideoRecorderGhostFrame]).
  final bool isFrontCamera;

  /// Whether a front/back lens switch is currently in progress.
  ///
  /// True from the moment the switch is dispatched until the native camera
  /// has rebound. The preview freezes on its last frame during this window;
  /// the UI overlays a brief blur over that frozen frame to soften the cut.
  final bool isSwitchingCamera;

  /// Flutter texture id backing the live preview, or null before the camera
  /// is ready. A lens switch rebinds the incoming camera onto a fresh texture,
  /// so this changes on switch; the preview is keyed on it to pick up the new
  /// camera's frames.
  final int? previewTextureId;

  /// Whether the camera has flash capability.
  final bool hasFlash;

  /// Current zoom level (user-facing, e.g. 0.5× ultra-wide, 1.0× wide).
  final double zoomLevel;

  /// Minimum zoom level supported by the active camera.
  ///
  /// With auto lens switching this is < 1.0 on devices with an ultra-wide
  /// lens (e.g. 0.5×); otherwise it equals 1.0.
  final double minZoomLevel;

  /// Maximum zoom level supported by the active camera.
  final double maxZoomLevel;

  /// Aspect ratio of the camera sensor.
  final double cameraSensorAspectRatio;

  /// Current countdown value before recording starts.
  final int countdownValue;

  /// Count of camera rebuilds for forcing UI updates.
  final int cameraRebuildCount;

  /// Current recording aspect ratio.
  final model.AspectRatio aspectRatio;

  /// Current flash mode.
  final DivineFlashMode flashMode;

  /// Current video stabilization mode.
  final DivineVideoStabilizationMode videoStabilizationMode;

  /// Stabilization modes supported by the active camera/lens.
  /// Always contains at least [DivineVideoStabilizationMode.off].
  final List<DivineVideoStabilizationMode> availableVideoStabilizationModes;

  /// Whether the active camera supports video stabilization beyond off.
  final bool isVideoStabilizationSupported;

  /// Timer duration before recording starts.
  final TimerDuration timerDuration;

  /// Current recording state.
  final VideoRecorderState recordingState;

  /// Why camera initialization failed, or null if it has not.
  ///
  /// A reason code, not a message — the UI localizes it. See
  /// [CameraInitializationError].
  final CameraInitializationError? initializationError;

  /// Whether to show a semi-transparent overlay of the last recorded clip
  /// on the camera preview (ghost frame).
  final bool showLastClipOverlay;

  /// Whether to show the rule-of-thirds grid overlay on the camera preview.
  final bool showGridLines;

  /// True while [VideoRecorderRecordingStartRequested] is in-flight (between
  /// pressing record and the camera reporting the first keyframe).
  final bool isStartingRecording;

  /// True while [VideoRecorderRecordingStopRequested] is finalizing.
  final bool isStoppingRecording;

  /// True when a stop was requested while [isStartingRecording] was true.
  ///
  /// [_onRecordingStartRequested] checks this flag after the native
  /// [CameraService.startRecording] call completes and, if set, dispatches a
  /// proper [VideoRecorderRecordingStopRequested] so that a very brief
  /// press-and-release in hold-to-record mode always produces a short clip
  /// rather than an indefinite recording (#hold-to-record-brief-press).
  final bool pendingStopAfterStart;

  /// True while the camera is released for a navigation push (editor, metadata,
  /// library) and cleared on the next re-initialization.
  ///
  /// Gates recording start/toggle so a volume / Bluetooth trigger that races
  /// the navigation can't begin a recording on a camera that is being torn
  /// down — which would otherwise strand the recorder, since an in-flight
  /// native start hung behind the disposed camera permanently occupies the
  /// `sequential()` start bucket. Held in the state stream (not a private
  /// field) per `state_management.md`, alongside the other recording-lifecycle
  /// flags.
  final bool recordingLockedForNavigation;

  /// Zoom level captured at the start of the current pinch gesture.
  ///
  /// Used to compute relative zoom from pinch scale.
  final double baseZoomLevel;

  /// Whether the zoom is currently locked at 1.0x via the snap detent.
  final bool snappedTo1x;

  /// Last zoom value computed by the scale update handler, after damping
  /// and the 1x snap — feeds the detent edge detector.
  final double lastRawZoom;

  /// Time the snap-to-1x detent engaged. Used to enforce the snap
  /// hold duration before releasing back to free-scrubbing.
  final DateTime? snapTime;

  /// Whether the Android-style zoom ruler should be visible.
  ///
  /// Driven by pinch activity: set true while zooming and for a short
  /// hold afterwards, then cleared by the auto-hide timer so the ruler
  /// only shows up while the user is actively changing the zoom.
  final bool showZoomIndicator;

  /// True while a scale gesture is in progress on the camera preview.
  ///
  /// The zoom ruler stops accepting pointers while this is set, so the
  /// second finger of a pinch landing on the ruler strip falls through
  /// to the preview and completes the pinch instead of being swallowed
  /// by the ruler's drag scrubber.
  final bool isPinchActive;

  /// Captured stop-motion frame file paths, in capture order.
  ///
  /// Each shutter tap in stop-motion mode appends one still here; they are
  /// encoded into a single video only at publish, so capture stays instant.
  final List<String> stopMotionFrames;

  /// Lifecycle of the stop-motion assemble step.
  final StopMotionStatus stopMotionStatus;

  /// Number of captured stop-motion frames.
  int get stopMotionFrameCount => stopMotionFrames.length;

  /// Incremented the instant a stop-motion shutter fires — before the native
  /// photo capture resolves — so shutter feedback (blink) is immediate rather
  /// than delayed by the capture write (~400ms).
  final int stopMotionShutterTick;

  /// Path of the most recently captured stop-motion frame, if any.
  String? get stopMotionLastFrame => stopMotionFrames.lastOrNull;

  /// Whether currently recording.
  bool get isRecording => recordingState == VideoRecorderState.recording;

  /// Whether camera is initialized and not in error state.
  bool get isInitialized =>
      isCameraInitialized && recordingState != VideoRecorderState.error;

  /// Whether in error state.
  bool get isError => recordingState == VideoRecorderState.error;

  /// Creates a copy of this state with updated values.
  VideoRecorderBlocState copyWith({
    VideoRecorderMode? recorderMode,
    VideoRecorderState? recordingState,
    double? zoomLevel,
    double? minZoomLevel,
    double? maxZoomLevel,
    double? cameraSensorAspectRatio,
    Offset? focusPoint,
    bool? canRecord,
    bool? isCameraInitialized,
    bool? canSwitchCamera,
    bool? isFrontCamera,
    bool? isSwitchingCamera,
    int? previewTextureId,
    bool? hasFlash,
    int? countdownValue,
    int? cameraRebuildCount,
    model.AspectRatio? aspectRatio,
    DivineFlashMode? flashMode,
    DivineVideoStabilizationMode? videoStabilizationMode,
    List<DivineVideoStabilizationMode>? availableVideoStabilizationModes,
    bool? isVideoStabilizationSupported,
    TimerDuration? timerDuration,
    CameraInitializationError? initializationError,
    bool? showLastClipOverlay,
    bool? showGridLines,
    bool? isStartingRecording,
    bool? isStoppingRecording,
    bool? pendingStopAfterStart,
    bool? recordingLockedForNavigation,
    double? baseZoomLevel,
    bool? snappedTo1x,
    double? lastRawZoom,
    DateTime? snapTime,
    bool? showZoomIndicator,
    bool? isPinchActive,
    List<String>? stopMotionFrames,
    StopMotionStatus? stopMotionStatus,
    int? stopMotionShutterTick,
  }) {
    return VideoRecorderBlocState(
      recorderMode: recorderMode ?? this.recorderMode,
      recordingState: recordingState ?? this.recordingState,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      minZoomLevel: minZoomLevel ?? this.minZoomLevel,
      maxZoomLevel: maxZoomLevel ?? this.maxZoomLevel,
      cameraSensorAspectRatio:
          cameraSensorAspectRatio ?? this.cameraSensorAspectRatio,
      focusPoint: focusPoint ?? this.focusPoint,
      canRecord: canRecord ?? this.canRecord,
      isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
      canSwitchCamera: canSwitchCamera ?? this.canSwitchCamera,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isSwitchingCamera: isSwitchingCamera ?? this.isSwitchingCamera,
      previewTextureId: previewTextureId ?? this.previewTextureId,
      hasFlash: hasFlash ?? this.hasFlash,
      countdownValue: countdownValue ?? this.countdownValue,
      cameraRebuildCount: cameraRebuildCount ?? this.cameraRebuildCount,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      flashMode: flashMode ?? this.flashMode,
      videoStabilizationMode:
          videoStabilizationMode ?? this.videoStabilizationMode,
      availableVideoStabilizationModes:
          availableVideoStabilizationModes ??
          this.availableVideoStabilizationModes,
      isVideoStabilizationSupported:
          isVideoStabilizationSupported ?? this.isVideoStabilizationSupported,
      timerDuration: timerDuration ?? this.timerDuration,
      initializationError: initializationError ?? this.initializationError,
      showLastClipOverlay: showLastClipOverlay ?? this.showLastClipOverlay,
      showGridLines: showGridLines ?? this.showGridLines,
      isStartingRecording: isStartingRecording ?? this.isStartingRecording,
      isStoppingRecording: isStoppingRecording ?? this.isStoppingRecording,
      pendingStopAfterStart:
          pendingStopAfterStart ?? this.pendingStopAfterStart,
      recordingLockedForNavigation:
          recordingLockedForNavigation ?? this.recordingLockedForNavigation,
      baseZoomLevel: baseZoomLevel ?? this.baseZoomLevel,
      snappedTo1x: snappedTo1x ?? this.snappedTo1x,
      lastRawZoom: lastRawZoom ?? this.lastRawZoom,
      snapTime: snapTime ?? this.snapTime,
      showZoomIndicator: showZoomIndicator ?? this.showZoomIndicator,
      isPinchActive: isPinchActive ?? this.isPinchActive,
      stopMotionFrames: stopMotionFrames ?? this.stopMotionFrames,
      stopMotionStatus: stopMotionStatus ?? this.stopMotionStatus,
      stopMotionShutterTick:
          stopMotionShutterTick ?? this.stopMotionShutterTick,
    );
  }

  @override
  List<Object?> get props => [
    recorderMode,
    recordingState,
    zoomLevel,
    minZoomLevel,
    maxZoomLevel,
    cameraSensorAspectRatio,
    focusPoint,
    canRecord,
    isCameraInitialized,
    canSwitchCamera,
    isFrontCamera,
    isSwitchingCamera,
    previewTextureId,
    hasFlash,
    countdownValue,
    cameraRebuildCount,
    aspectRatio,
    flashMode,
    videoStabilizationMode,
    availableVideoStabilizationModes,
    isVideoStabilizationSupported,
    timerDuration,
    initializationError,
    showLastClipOverlay,
    showGridLines,
    isStartingRecording,
    isStoppingRecording,
    pendingStopAfterStart,
    recordingLockedForNavigation,
    baseZoomLevel,
    snappedTo1x,
    lastRawZoom,
    snapTime,
    showZoomIndicator,
    isPinchActive,
    stopMotionFrames,
    stopMotionStatus,
    stopMotionShutterTick,
  ];
}
