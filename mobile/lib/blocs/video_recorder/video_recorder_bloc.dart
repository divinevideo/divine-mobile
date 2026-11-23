// ABOUTME: Bloc that owns the camera-recorder UI state (port of
// ABOUTME: VideoRecorderNotifier, removing concurrency-flag fields and
// ABOUTME: adding sequential() on recording start/stop).

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:divine_camera/divine_camera.dart'
    show
        CameraLensMetadata,
        DivineCameraLens,
        DivineVideoQuality,
        DivineVideoStabilizationMode,
        PhotoCaptureResult,
        VideoRecordingResult;
import 'package:divine_video_player/divine_video_player.dart'
    show DivineVideoPlayerController, VideoClip;
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' as model show AspectRatio, AudioSourceKind;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/camera_initialization_error.dart';
import 'package:openvine/models/video_recorder/secondary_camera_take.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';
import 'package:openvine/observability/recording_traces.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/front_camera_mirror_preference_service.dart';
import 'package:openvine/services/haptic_service.dart';
import 'package:openvine/services/music_mode_preference_service.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/video_editor/clip_media_duration.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:openvine/services/video_recorder/camera/camera_mobile_service.dart';
import 'package:openvine/services/video_recorder/dual_camera_thumbnail_composer.dart';
import 'package:openvine/services/video_recorder/stop_motion_session_store.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/chroma_key_still_detection.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'video_recorder_event.dart';
part 'video_recorder_state.dart';

/// SharedPreferences key for the last-used camera lens.
const _kLastUsedCameraLensKey = 'camera_last_used_lens';

/// SharedPreferences key for the last-used video stabilization mode.
const _kLastUsedStabilizationModeKey = 'camera_last_used_stabilization';

/// Stabilization for a recorder that has no saved choice yet.
///
/// Not [DivineVideoStabilizationMode.auto]: on iOS it usually resolves to a
/// look-ahead mode that holds every stop ~1.6s before the next take can
/// start, and Android does not offer it at all.
const DivineVideoStabilizationMode _kDefaultStabilizationMode =
    DivineVideoStabilizationMode.standard;

/// SharedPreferences key for the last grid-lines on/off choice.
const _kGridLinesEnabledKey = 'camera_grid_lines_enabled';

/// Factory for creating a [CountdownSoundService].
///
/// Injectable so tests can verify the wiring that protects the
/// camera-owned AVAudioSession (see [defaultCountdownSoundServiceFactory]
/// and #4539).
typedef CountdownSoundServiceFactory = CountdownSoundService Function();

/// Factory for creating an [AudioPlaybackService].
typedef AudioPlaybackServiceFactory = AudioPlaybackService Function();

/// Factory for creating the platform-specific [CameraService].
///
/// Injectable so tests can exercise the callback wiring performed by the
/// bloc constructor instead of bypassing it with a service override.
typedef CameraServiceFactory = CameraService Function({
  required void Function({bool? forceCameraRebuild}) onUpdateState,
  required void Function(EditorVideo? video) onAutoStopped,
  ValueChanged<bool>? onScreenFlashChanged,
});

/// The original Library reaction owns any take finalized after its editor
/// session is replaced.
typedef ReactionRecordingOwner = ({
  ClipManagerNotifier clipManager,
  bool Function() isCurrent,
  Future<void> Function(DivineVideoClip) retain,
});

/// Accessor for the [ClipManagerNotifier] (method-call + public-getter
/// side) living in the surrounding Riverpod scope. The bloc never
/// imports flutter_riverpod; the wiring site passes
/// `() => ref.read(clipManagerProvider.notifier)`.
///
/// Note: state reads use the notifier's existing public getters
/// (`.clips`, `.remainingDuration`, `.totalDuration`), not the
/// protected `.state` accessor.
typedef ReadClipManager = ClipManagerNotifier Function();

/// Accessor for the [VideoEditorNotifier] (method-call side).
typedef ReadVideoEditor = VideoEditorNotifier Function();

/// Accessor for the current [VideoEditorProviderState].
typedef ReadVideoEditorState = VideoEditorProviderState Function();

/// Accessor for the [SharedPreferences] instance.
typedef ReadSharedPreferences = SharedPreferences Function();

/// Reports the recorder mode only after media capture actually starts.
typedef RecordingStartedCallback = void Function(VideoRecorderMode mode);

/// Measures the chroma-key screen in the still at `photoPath`, keeping only the
/// centre shaped like the video (width over height).
///
/// Injectable so tests can stand in a measurement without an image codec; in
/// the app it is [detectChromaKeyInStill].
typedef ChromaKeyStillDetector = Future<ChromaKeyDetection> Function(
  String photoPath, {
  required double visibleAspectRatio,
});

/// Default [CountdownSoundService] factory.
///
/// Forwards `handleAudioSessionActivation: false` to [JustAudioSimplePlayer]
/// so just_audio never calls `setCategory(.playback)` on the shared
/// AVAudioSession — the camera owns it in `.playAndRecord` mode, and a
/// category flip mid-countdown would drop the mic's route and force the
/// native controller through its deactivate/reconfigure/activate cycle on
/// the record tap (#4548). The beeps themselves are kept off the input
/// path by closing the mic around the countdown — see
/// `CameraService.suspendAudioCapture` — which is what stops a countdown
/// clip from starting quiet and growing louder (#4539).
CountdownSoundService defaultCountdownSoundServiceFactory() =>
    CountdownSoundService(
      audioPlayerFactory: () =>
          JustAudioSimplePlayer(handleAudioSessionActivation: false),
    );

/// Default [AudioPlaybackService] factory.
///
/// Forwards `handleAudioSessionActivation: false` for the same reason
/// as [defaultCountdownSoundServiceFactory] — see that function for
/// the full rationale and #4539.
AudioPlaybackService defaultAudioPlaybackServiceFactory() =>
    AudioPlaybackService(handleAudioSessionActivation: false);

/// Bloc that owns the camera-recorder UI state.
///
/// Direct port of `VideoRecorderNotifier`. Differences from the
/// provider:
///
/// 1. [VideoRecorderRecordingStartRequested] and
///    [VideoRecorderRecordingStopRequested] are registered with
///    `transformer: sequential()` so each becomes a FIFO queue
///    (#4787 hazard R1).
/// 2. The provider's `_isStartingRecording`, `_isStoppingRecording`,
///    `_baseZoomLevel`, `_snappedTo1x`, `_lastRawZoom`, and
///    `_snapTime` mutable instance fields now live in
///    [VideoRecorderBlocState] per `state_management.md`.
/// 3. Navigation methods (`closeVideoRecorder`, `openVideoEditor`,
///    `openLibrary`) move to the View. The bloc exposes
///    [VideoRecorderCameraPausedForNavigation] so the View can
///    dispose the camera mid-transition without owning the
///    navigation contract.
/// 4. Sibling Riverpod providers are reached via typedef accessors
///    ([ReadClipManager], [ReadVideoEditor], [ReadVideoEditorState],
///    [ReadSharedPreferences]) so the bloc remains pure Dart.
class VideoRecorderBloc
    extends Bloc<VideoRecorderEvent, VideoRecorderBlocState> {
  /// Creates a video recorder bloc.
  ///
  /// [readClipManager], [readVideoEditor], [readVideoEditorState], and
  /// [readSharedPreferences] bridge the Riverpod-scoped dependencies.
  ///
  /// [cameraService] and [cameraServiceFactory] are test seams. When the
  /// service override is omitted, the factory creates the platform-appropriate
  /// [CameraService] and wires its update / auto-stop / screen-flash callbacks
  /// to internal events.
  ///
  /// [countdownSoundServiceFactory] and [audioPlaybackServiceFactory]
  /// are optional test overrides. Defaults preserve the iOS
  /// audio-session wiring required by #4539.
  ///
  /// [liveChromaKeySupported] says whether the renderer can draw the keyed
  /// viewfinder. Without it the color mask cannot be turned on. Off unless
  /// the caller knows, so a bloc built without asking the renderer never
  /// keys a viewfinder it cannot show.
  /// [detectChromaKeyStill] is a test seam for the wall measurement.
  VideoRecorderBloc({
    required ReadClipManager readClipManager,
    required ReadVideoEditor readVideoEditor,
    required ReadVideoEditorState readVideoEditorState,
    required ReadSharedPreferences readSharedPreferences,
    ReactionRecordingOwner? reactionRecordingOwner,
    CameraService? cameraService,
    CameraServiceFactory cameraServiceFactory = CameraService.create,
    CountdownSoundServiceFactory? countdownSoundServiceFactory,
    AudioPlaybackServiceFactory? audioPlaybackServiceFactory,
    PerformanceTraceMonitor? performanceMonitor,
    RecordingStartedCallback? onRecordingStarted,
    bool liveChromaKeySupported = false,
    ChromaKeyStillDetector detectChromaKeyStill = detectChromaKeyInStill,
  }) : _readClipManager = readClipManager,
       _reactionRecordingOwner = reactionRecordingOwner,
       _readVideoEditor = readVideoEditor,
       _readVideoEditorState = readVideoEditorState,
       _readSharedPreferences = readSharedPreferences,
       _cameraServiceOverride = cameraService,
       _countdownSoundServiceFactory =
           countdownSoundServiceFactory ?? defaultCountdownSoundServiceFactory,
       _audioPlaybackServiceFactory =
           audioPlaybackServiceFactory ?? defaultAudioPlaybackServiceFactory,
       _performanceMonitor =
           performanceMonitor ?? const NoOpPerformanceTraceMonitor(),
       _onRecordingStarted = onRecordingStarted,
       _liveChromaKeySupported = liveChromaKeySupported,
       _detectChromaKeyStill = detectChromaKeyStill,
       super(
         VideoRecorderBlocState(
           isLiveChromaKeySupported: liveChromaKeySupported,
         ),
       ) {
    _cameraService =
        _cameraServiceOverride ??
        cameraServiceFactory(
          onUpdateState: ({forceCameraRebuild}) {
            if (isClosed) return;
            addIfOpen(
              _VideoRecorderCameraStateChanged(
                cameraRebuildCount: (forceCameraRebuild ?? false)
                    ? state.cameraRebuildCount + 1
                    : null,
              ),
            );
          },
          onAutoStopped: (video) {
            if (isClosed) return;
            add(_VideoRecorderAutoStopped(video));
          },
          onScreenFlashChanged: (isActive) =>
              addIfOpen(_VideoRecorderScreenFlashChanged(isActive: isActive)),
        );

    on<VideoRecorderInitializeRequested>(_onInitializeRequested);
    on<VideoRecorderAppLifecycleChanged>(_onAppLifecycleChanged);
    on<VideoRecorderRemoteRecordPaused>(_onRemoteRecordPaused);
    on<VideoRecorderRemoteRecordResumed>(_onRemoteRecordResumed);
    on<VideoRecorderFlashToggled>(_onFlashToggled);
    on<VideoRecorderAspectRatioToggled>(_onAspectRatioToggled);
    on<VideoRecorderAspectRatioSet>(_onAspectRatioSet);
    on<VideoRecorderCameraSwitched>(
      _onCameraSwitched,
      // A switch drives a native rebind and raises isSwitchingCamera for the
      // blur transition; drop taps that arrive mid-switch so a rapid double-tap
      // can't kick off a second rebind (which would just toggle back).
      transformer: droppable(),
    );
    on<VideoRecorderStabilizationModeSet>(
      _onStabilizationModeSet,
      // Each change drives a native reconfigure (a CameraX rebind on Android);
      // process them FIFO so rapid menu picks can't overlap and the last
      // selection wins.
      transformer: sequential(),
    );
    on<VideoRecorderLensSet>(_onLensSet);
    on<VideoRecorderZoomLevelSet>(
      _onZoomLevelSet,
      // A pinch sends one request per pointer update. Only the newest may
      // land: an older platform reply finishing late would otherwise snap
      // the ruler back to a stale zoom.
      transformer: restartable(),
    );
    on<VideoRecorderFocusPointSet>(_onFocusPointSet);
    on<VideoRecorderExposurePointSet>(_onExposurePointSet);
    on<VideoRecorderRecordingToggleRequested>(_onRecordingToggleRequested);
    on<VideoRecorderRecordingStartRequested>(
      _onRecordingStartRequested,
      transformer: sequential(),
    );
    on<VideoRecorderRecordingStopRequested>(
      _onRecordingStopRequested,
      transformer: sequential(),
    );
    on<VideoRecorderLongPressZoomStarted>(_onLongPressZoomStarted);
    on<VideoRecorderZoomedByLongPress>(_onZoomedByLongPress);
    on<VideoRecorderScaleStarted>(_onScaleStarted);
    on<VideoRecorderScaleUpdated>(_onScaleUpdated);
    on<VideoRecorderScaleEnded>(_onScaleEnded);
    on<VideoRecorderRecordingLockedForNavigation>(
      _onRecordingLockedForNavigation,
    );
    on<VideoRecorderCameraPausedForNavigation>(_onCameraPausedForNavigation);
    on<VideoRecorderEditorNavigationStarted>(_onEditorNavigationStarted);
    on<VideoRecorderEditorNavigationEnded>(_onEditorNavigationEnded);
    on<VideoRecorderRecorderModeSet>(_onRecorderModeSet);
    on<VideoRecorderTimerCycled>(_onTimerCycled);
    on<VideoRecorderResetRequested>(_onResetRequested);
    on<VideoRecorderShowLastClipOverlayToggled>(_onShowLastClipOverlayToggled);
    on<VideoRecorderGridLinesToggled>(_onGridLinesToggled);
    on<VideoRecorderActionRailToggled>(_onActionRailToggled);
    on<VideoRecorderDualCameraToggled>(
      _onDualCameraToggled,
      // Each toggle rebuilds the native capture session; a tap that lands
      // while one runs would only undo it.
      transformer: droppable(),
    );
    on<VideoRecorderDualCameraPipChanged>(_onDualCameraPipChanged);
    on<VideoRecorderDualCameraPipShapeToggled>(_onDualCameraPipShapeToggled);
    on<VideoRecorderStopMotionFrameCaptured>(
      _onStopMotionFrameCaptured,
      transformer: droppable(),
    );
    on<VideoRecorderStopMotionFrameUndone>(_onStopMotionFrameUndone);
    on<VideoRecorderStopMotionAssembleRequested>(
      _onStopMotionAssembleRequested,
      transformer: droppable(),
    );
    on<VideoRecorderChromaKeyEnabledSet>(
      _onChromaKeyEnabledSet,
      // Turning the mask on or off points the camera's stabilization at the
      // new setting, a CameraX rebind on Android; process them FIFO so quick
      // taps cannot overlap and the last one wins.
      transformer: sequential(),
    );
    on<VideoRecorderChromaKeyMeasureRequested>(
      _onChromaKeyMeasureRequested,
      transformer: droppable(),
    );
    on<VideoRecorderChromaKeyPresetSelected>(_onChromaKeyPresetSelected);
    on<VideoRecorderChromaKeySettingsChanged>(
      _onChromaKeySettingsChanged,
    );
    on<VideoRecorderChromaKeyPatchPicked>(_onChromaKeyPatchPicked);
    on<VideoRecorderChromaKeyBackdropSet>(_onChromaKeyBackdropSet);
    on<_VideoRecorderCameraStateChanged>(_onCameraStateChanged);
    on<_VideoRecorderRemoteRecordTriggered>(_onRemoteRecordTriggered);
    on<_VideoRecorderAutoStopped>(_onAutoStopped);
    on<_VideoRecorderScreenFlashChanged>(_onScreenFlashChanged);
    on<_VideoRecorderFocusPointTimerFired>(_onFocusPointTimerFired);
    on<_VideoRecorderZoomIndicatorTimerFired>(_onZoomIndicatorTimerFired);
    on<_VideoRecorderIntervalCaptureTicked>(
      _onIntervalCaptureTicked,
      // Only one tick is armed at a time, and the next one only once the
      // still has landed. Dropping guards the one window a stop and a quick
      // restart could open for a second.
      transformer: droppable(),
    );
  }

  final ReadClipManager _readClipManager;
  final ReactionRecordingOwner? _reactionRecordingOwner;
  Stopwatch? _reactionTakeClock;
  Completer<void>? _reactionStartCancellation;
  Completer<void>? _pendingReactionStart;
  Completer<void>? _pendingReactionStop;

  final ReadVideoEditor _readVideoEditor;
  final ReadVideoEditorState _readVideoEditorState;
  final ReadSharedPreferences _readSharedPreferences;
  final CameraService? _cameraServiceOverride;
  final CountdownSoundServiceFactory _countdownSoundServiceFactory;
  final AudioPlaybackServiceFactory _audioPlaybackServiceFactory;
  final PerformanceTraceMonitor _performanceMonitor;

  /// Times each take's start and stop. Telemetry, not UI state: it only
  /// carries the moment a take began over to its stop.
  late final RecordingTraces _recordingTraces = RecordingTraces(
    _performanceMonitor,
  );
  final RecordingStartedCallback? _onRecordingStarted;
  final bool _liveChromaKeySupported;
  final ChromaKeyStillDetector _detectChromaKeyStill;

  late final CameraService _cameraService;

  /// The clip manager holding background chroma-key bakes back for the take
  /// in progress, or `null` while nothing is held. Kept so [close] can let
  /// them go even after the widget that reads the clip manager is gone.
  ClipManagerNotifier? _chromaKeyBakeHolder;

  /// Set once [close] starts. [isClosed] stays false through close's awaits,
  /// while work already in flight keeps running. A countdown tick must not
  /// take a new hold then: nothing would release it. Nor may an event
  /// handler resuming then reconfigure the camera close is disposing.
  bool _isClosing = false;
  Future<void>? _closeFuture;

  /// Set while [_reconcileDualCamera] runs. A second caller leaves the work
  /// to it, since it checks the mode and mask again after every rebuild.
  bool _isReconcilingDualCamera = false;
  AudioPlaybackService? _audioPlaybackService;
  CountdownSoundService? _countdownSoundService;
  Timer? _focusPointTimer;
  Timer? _zoomIndicatorTimer;

  /// The next second of the stop-motion interval countdown, while one runs.
  Timer? _intervalCaptureTimer;
  late final _stopMotionSessions = StopMotionSessionStore(
    readClipManager: _readClipManager,
  );

  /// Whether setup turned remote record control on. A sheet's pause turns it
  /// off natively but leaves this set, so the resume turns it back on.
  bool _remoteRecordControlEnabled = false;

  /// How long the zoom ruler stays visible after the last pinch activity
  /// before the auto-hide timer clears it.
  static const _zoomIndicatorHideDelay = Duration(milliseconds: 1000);

  /// One step of the stop-motion interval countdown.
  static const _intervalCaptureTickInterval = Duration(seconds: 1);

  /// The current active camera lens. Delegates to the camera service.
  DivineCameraLens get currentLens => _cameraService.currentLens;

  /// List of available camera lenses on this device. Delegates to the
  /// camera service.
  List<DivineCameraLens> get availableLenses => _cameraService.availableLenses;

  /// Metadata for the currently active lens, if available.
  CameraLensMetadata? get currentLensMetadata =>
      _cameraService.currentLensMetadata;

  bool get _remoteRecordPausedForSound =>
      _readVideoEditorState().selectedSound != null;

  /// The settings the take being started or stopped runs with.
  RecordingTraceContext get _recordingTraceContext => RecordingTraceContext(
    mode: state.recorderMode,
    stabilization: state.videoStabilizationMode,
    dualCamera: state.isDualCameraEnabled,
    chromaKey: state.isChromaKeyActive,
    reaction: _reactionRecordingOwner != null,
  );

  /// Keeps background chroma-key bakes off the hardware while the camera
  /// encodes: held from the moment a take starts, released once it is over.
  ///
  /// Watched here rather than in the start and stop handlers because a take
  /// can end on many paths — a stop, a failed start, an abort for navigation
  /// — and every one of them leaves the state saying it is no longer
  /// recording.
  @override
  void onChange(Change<VideoRecorderBlocState> change) {
    super.onChange(change);
    final isCapturing =
        change.nextState.isStartingRecording || change.nextState.isRecording;
    if (isCapturing && _chromaKeyBakeHolder == null) {
      if (_isClosing) return;
      _chromaKeyBakeHolder = _readClipManager()..holdCapturedChromaKeyBakes();
    } else if (!isCapturing) {
      _releaseChromaKeyBakes();
    }
  }

  void _releaseChromaKeyBakes() {
    _chromaKeyBakeHolder?.releaseCapturedChromaKeyBakes();
    _chromaKeyBakeHolder = null;
  }

  // === Event handlers ===

  Future<void> _onInitializeRequested(
    VideoRecorderInitializeRequested event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    // Re-initialization marks the end of any navigation teardown, so release
    // the navigation recording lock up front — this covers the camera-init
    // error returns below too, which previously left the recorder locked until
    // a later successful init. The camera isn't usable yet (`canRecord` stays
    // false until initialize() completes), so clearing the lock here cannot let
    // a racing trigger start a recording on a torn-down camera.
    if (state.recordingLockedForNavigation) {
      emit(state.copyWith(recordingLockedForNavigation: false));
    }

    final prefs = _readSharedPreferences();

    // A part recorder stays one for its lifetime: returning from the editor
    // re-initializes without the flag.
    final collabPart = event.collabPart || state.isCollabPart;
    if (collabPart && !state.isCollabPart) {
      emit(state.copyWith(isCollabPart: true));
    }
    final requestedMode = event.fromEditor
        ? null
        : collabPart
        ? VideoRecorderMode.capture
        : event.recorderMode;
    // A room part leaves the last-used mode alone: the next plain open
    // should land where the user left the recorder, not in a part's capture.
    if (requestedMode != null && !collabPart) {
      // Persist before restoring so every later re-init in this session
      // (returning from the editor or the library) lands on this mode rather
      // than the previous session's — that switch would clear the session's
      // clips (see _applyRecorderMode).
      unawaited(
        prefs.setString(VideoRecorderMode.persistenceKey, requestedMode.name),
      );
    }
    final savedMode =
        requestedMode ??
        VideoRecorderMode.fromName(
          prefs.getString(VideoRecorderMode.persistenceKey),
        );
    if (!event.fromEditor && savedMode != state.recorderMode) {
      try {
        await _applyRecorderMode(emit, savedMode, keepAutosavedDraft: true);
      } catch (e, stackTrace) {
        addError(e, stackTrace);
        emit(
          state.copyWith(initializationError: CameraInitializationError.failed),
        );
        return;
      }
    } else if (event.fromEditor &&
        state.recorderMode != VideoRecorderMode.stopMotion &&
        isStopMotionComposition(_readClipManager().clips)) {
      // Opened over a stop-motion composition to add more stills: switch to the
      // stills shutter so the "+" camera captures photos, not a video. Set only
      // the mode field (plus its grid default) — routing through
      // _applyRecorderMode would clear the clip manager (the composition being
      // edited).
      emit(
        state.copyWith(
          recorderMode: VideoRecorderMode.stopMotion,
          showGridLines: _gridLinesEnabledFor(VideoRecorderMode.stopMotion),
          timerDuration: _timerDurationCarriedTo(VideoRecorderMode.stopMotion),
        ),
      );
    } else {
      // The recorder kept its mode, so the switch above did not apply that
      // mode's remembered grid choice. A recorder opened on the default mode
      // would otherwise start without its grid.
      emit(
        state.copyWith(showGridLines: _gridLinesEnabledFor(state.recorderMode)),
      );
    }

    // A completed assemble leaves status at `ready` until it navigates to the
    // editor; backing out re-inits without a mode change, so nothing above
    // clears it and `_emitCameraSync` preserves it — the capture guard would
    // then swallow every shutter tap. Reset to idle (the frames are already
    // saved and cleared) so the shutter starts a fresh session.
    if (state.stopMotionStatus == StopMotionStatus.ready) {
      emit(state.copyWith(stopMotionStatus: StopMotionStatus.idle));
    }

    final savedLensString = prefs.getString(_kLastUsedCameraLensKey);
    final initialLens = savedLensString != null
        ? DivineCameraLens.fromNativeString(savedLensString)
        : DivineCameraLens.back;

    Log.info(
      '📹 Initializing video recorder with quality: '
      '${event.videoQuality.value}, lens: ${initialLens.displayName}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );

    // Operation-scoped trace: this init owns the returned handle, so a
    // concurrent init gets its own trace instead of stopping or re-attributing
    // this one. Start is fire-and-forget so it doesn't add a platform round-trip
    // to the exact startup path this trace measures; stop is fire-and-forget so
    // it doesn't gate preview bring-up. The handle is still stopped in `finally`,
    // tagged with the outcome so the console can filter startups that never
    // reached a live preview.
    final trace = _performanceMonitor.startOperationTrace('camera_startup');

    Object? initError;
    try {
      await _cameraService.initialize(
        videoQuality: event.videoQuality,
        initialLens: initialLens,
        enableAutoLensSwitch: true,
        // Read at init because the audio-session mode is chosen once per
        // capture session; flipping the setting applies to the next open.
        preferUnprocessedAudio:
            prefs.getBool(MusicModePreferenceService.prefsKey) ?? false,
        // Rides the first bind: applying it after init would rebind the
        // whole camera a second time on Android.
        videoStabilizationMode: _stabilizationModeFor(
          stabilizes: state.supportsVideoStabilization,
          prefs: prefs,
        ),
        // Read at init because the outputs' mirroring is fixed when the
        // camera binds them; flipping the setting applies to the next open.
        mirrorFrontCameraOutput:
            prefs.getBool(FrontCameraMirrorPreferenceService.prefsKey) ?? false,
      );
    } catch (e, stackTrace) {
      initError = e;
      addError(e, stackTrace);
    } finally {
      trace
        ..putAttribute('lens', initialLens.name)
        ..putAttribute('quality', event.videoQuality.value)
        ..putAttribute(
          'outcome',
          initError != null
              ? 'error'
              : (_cameraService.isInitialized ? 'success' : 'failed'),
        );
      unawaited(trace.stop());
    }

    if (initError != null) {
      Log.error(
        '📹 Camera service initialization threw exception: $initError',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(initializationError: CameraInitializationError.failed),
      );
      return;
    }

    if (!_cameraService.isInitialized) {
      final error =
          _cameraService.initializationError ??
          CameraInitializationError.failed;
      Log.warning(
        '⚠️ Camera failed to initialize: $error',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(initializationError: error));
      return;
    }

    final clips = _readClipManager().clips;
    _emitCameraSync(
      emit,
      aspectRatio: clips.isNotEmpty ? clips.first.targetAspectRatio : null,
    );

    // A mode switched to while the camera was starting could not reach it,
    // and the camera opens with one camera even where dual capture was left
    // on.
    await _applyCameraForRecorderMode(emit);

    // Opening straight into Upload: the screen's pause for that tab arrived
    // while the camera was still starting and was dropped, so release it now.
    if (!state.recorderMode.recordsVideo) {
      await _cameraService.handleAppLifecycleState(AppLifecycleState.paused);
    }

    await _setupRemoteRecordControl();

    Log.info(
      '✅ Video recorder initialized successfully',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );

    if (event.autoStartRecording) {
      Log.info(
        '🎥 Auto-starting recording after init',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      addIfOpen(const VideoRecorderRecordingStartRequested());
    }
  }

  Future<void> _onAppLifecycleChanged(
    VideoRecorderAppLifecycleChanged event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    // The camera goes with the app, so the loop would only tick on into
    // captures that fail.
    if (event.state != AppLifecycleState.resumed) _stopIntervalCapture(emit);
    try {
      await _cameraService.handleAppLifecycleState(event.state);
    } catch (e, stackTrace) {
      Log.warning(
        '⚠️ Camera failed to handle ${event.state.name}: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      if (event.state != AppLifecycleState.resumed) return;
      // A camera that does not come back would leave a black preview. Show
      // the initialization error instead; the next initialize (leaving and
      // returning to the Upload tab, or reopening the recorder) recovers.
      emit(
        state.copyWith(
          isCameraInitialized: false,
          canRecord: false,
          initializationError: CameraInitializationError.failed,
        ),
      );
      return;
    }

    // Leaving the Upload tab resumes the camera it paused, into whichever
    // mode the user switched to meanwhile.
    if (event.state == AppLifecycleState.resumed) {
      await _applyCameraForRecorderMode(emit, clearRetainedRequest: true);
    }
  }

  Future<void> _onRemoteRecordPaused(
    VideoRecorderRemoteRecordPaused event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    // Recorded even before setup has turned remote control on, so setup
    // can honor it. A sheet opening over another one only adds to the count.
    final pauseCount = state.remoteRecordPauseCount + 1;
    emit(state.copyWith(remoteRecordPauseCount: pauseCount));
    if (pauseCount != 1) return;
    if (_remoteRecordControlEnabled) {
      await _cameraService.setRemoteRecordControlEnabled(enabled: false);
      Log.debug(
        '🎮 Remote record control paused (sheet open)',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _onRemoteRecordResumed(
    VideoRecorderRemoteRecordResumed event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    // An unmatched resume is ignored, and control stays paused until the
    // last open sheet closes.
    if (!state.isRemoteRecordPaused) return;
    final pauseCount = state.remoteRecordPauseCount - 1;
    emit(state.copyWith(remoteRecordPauseCount: pauseCount));
    if (pauseCount != 0) return;
    if (_remoteRecordControlEnabled) {
      await _cameraService.setRemoteRecordControlEnabled(enabled: true);
      if (_isClosing) return;
      Log.debug(
        '🎮 Remote record control resumed',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );

      if (_remoteRecordPausedForSound) {
        await _cameraService.setVolumeKeysEnabled(enabled: false);
        Log.debug(
          '🎮 Volume keys re-disabled (sound is selected)',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }
    }
  }

  Future<void> _onFlashToggled(
    VideoRecorderFlashToggled event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final newMode = switch (state.flashMode) {
      DivineFlashMode.off => DivineFlashMode.torch,
      DivineFlashMode.torch => DivineFlashMode.auto,
      DivineFlashMode.auto => DivineFlashMode.off,
    };
    final success = await _cameraService.setFlashMode(newMode);
    if (!success) {
      Log.warning(
        '⚠️ Failed to toggle flash mode',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }
    emit(state.copyWith(flashMode: newMode));
    Log.debug(
      '🔦 Flash mode changed to: ${newMode.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
  }

  void _onAspectRatioToggled(
    VideoRecorderAspectRatioToggled event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    final newRatio = state.aspectRatio == model.AspectRatio.square
        ? model.AspectRatio.vertical
        : model.AspectRatio.square;
    Log.debug(
      '📱 Aspect ratio changed to: ${newRatio.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(aspectRatio: newRatio));
  }

  void _onAspectRatioSet(
    VideoRecorderAspectRatioSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    emit(state.copyWith(aspectRatio: event.ratio));
  }

  Future<void> _onCameraSwitched(
    VideoRecorderCameraSwitched event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (_refusesRebindMidTake('Camera switch')) return;

    // Flag the switch up front so the preview blurs its frozen last frame
    // while the native camera rebinds. `_emitCameraSync` rebuilds the state
    // from scratch and drops this flag once the new lens is live; the
    // `finally` covers the early-return and error paths.
    emit(state.copyWith(isSwitchingCamera: true));
    try {
      final success = await _cameraService.switchCamera();

      if (!success) {
        Log.warning(
          '⚠️ Camera switch failed - no available cameras to switch',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
        return;
      }

      await _saveCurrentLensPreference();

      Log.info(
        '🔄 Camera switched successfully - zoom reset to 1.0x',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );

      if (!emit.isDone) {
        emit(state.copyWith(zoomLevel: 1, baseZoomLevel: 1));
        _emitCameraSync(emit);
      }
    } finally {
      if (!emit.isDone) {
        emit(state.copyWith(isSwitchingCamera: false));
      }
    }
  }

  Future<void> _onStabilizationModeSet(
    VideoRecorderStabilizationModeSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    // On Android a stabilization change rebinds the camera too.
    if (_refusesRebindMidTake(
      'Stabilization change to ${event.mode.name}',
    )) {
      return;
    }
    if (event.mode == state.videoStabilizationMode) return;
    // Already on a mode that hides the control: keep the pick, but do not
    // start a rebind. Upload's camera is paused, and a rebind would restart it.
    if (!state.supportsVideoStabilization) {
      await _saveStabilizationModePreference(event.mode);
      return;
    }
    final success = await _cameraService.setVideoStabilizationMode(event.mode);
    if (!success) {
      Log.warning(
        '⚠️ Failed to set stabilization mode to ${event.mode.name}',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }
    if (isClosed) return;
    // The picker and a mode or color-mask change run concurrently. That
    // handler may have seen the camera still on the old value and skipped its
    // own apply, and on Android this set rebinds even a camera Upload has
    // paused.
    if (!state.supportsVideoStabilization) {
      await _saveStabilizationModePreference(event.mode);
      if (isClosed) return;
      if (!state.recorderMode.recordsVideo) {
        await _cameraService.handleAppLifecycleState(AppLifecycleState.paused);
      } else {
        await _applyCameraForRecorderMode(emit);
      }
      return;
    }
    emit(state.copyWith(videoStabilizationMode: event.mode));
    await _saveStabilizationModePreference(event.mode);
    Log.debug(
      '🎯 Stabilization mode changed to: ${event.mode.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
  }

  Future<void> _onLensSet(
    VideoRecorderLensSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (_refusesRebindMidTake('Lens change to ${event.lens.displayName}')) {
      return;
    }

    final success = await _cameraService.setLens(event.lens);
    if (!success) {
      Log.warning(
        '⚠️ Failed to set lens to ${event.lens.displayName}',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }

    await _saveCurrentLensPreference();

    Log.info(
      '🔄 Lens switched to ${event.lens.displayName} - zoom reset to 1.0x',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(zoomLevel: 1, baseZoomLevel: 1));
    _emitCameraSync(emit);
  }

  Future<void> _onZoomLevelSet(
    VideoRecorderZoomLevelSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (event.value > _cameraService.maxZoomLevel ||
        event.value < _cameraService.minZoomLevel) {
      Log.debug(
        '⚠️ Zoom level ${event.value} out of bounds '
        '(${_cameraService.minZoomLevel}-${_cameraService.maxZoomLevel})',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }

    final appliedZoom = await _cameraService.setZoomLevel(event.value);
    if (appliedZoom == null) {
      Log.warning(
        '⚠️ Failed to set zoom level to ${event.value}',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }
    // Emit what the camera actually applied, never the request: iOS can
    // silently clamp an in-range request when the available zoom range is
    // restricted at runtime. Mirroring the refreshed bounds keeps the
    // ruler's scale honest (it shrinks under a restriction and heals once
    // the restriction lifts).
    emit(
      state.copyWith(
        zoomLevel: appliedZoom,
        minZoomLevel: _cameraService.minZoomLevel,
        maxZoomLevel: _cameraService.maxZoomLevel,
        showZoomIndicator: true,
      ),
    );
    _armZoomIndicatorHideTimer();
  }

  Future<void> _onFocusPointSet(
    VideoRecorderFocusPointSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final success = await _cameraService.setFocusPoint(event.value);
    if (!success) {
      Log.warning(
        '⚠️ Failed to set focus point at '
        '(${event.value.dx.toStringAsFixed(2)}, '
        '${event.value.dy.toStringAsFixed(2)})',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }

    _focusPointTimer?.cancel();
    emit(state.copyWith(focusPoint: event.value));

    _focusPointTimer = Timer(const Duration(milliseconds: 800), () {
      if (isClosed) return;
      add(const _VideoRecorderFocusPointTimerFired());
    });
  }

  void _onFocusPointTimerFired(
    _VideoRecorderFocusPointTimerFired event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    _focusPointTimer = null;
    emit(state.copyWith(focusPoint: Offset.zero));
  }

  Future<void> _onExposurePointSet(
    VideoRecorderExposurePointSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final success = await _cameraService.setExposurePoint(event.value);
    if (!success) {
      Log.warning(
        '⚠️ Failed to set exposure point at '
        '(${event.value.dx.toStringAsFixed(2)}, '
        '${event.value.dy.toStringAsFixed(2)})',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _onRecordingToggleRequested(
    VideoRecorderRecordingToggleRequested event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (_cameraService.isSwitchingCamera) {
      Log.debug(
        '🎮 toggleRecording ignored - camera switch in progress',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }

    if (state.recordingLockedForNavigation) {
      Log.debug(
        '🎮 toggleRecording ignored - recording locked for navigation',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }

    if (state.recorderMode.capturesStills) {
      if (state.isIntervalCaptureRunning) {
        _stopIntervalCapture(emit);
      } else if (state.timerDuration != TimerDuration.off) {
        _startIntervalCapture(emit);
      } else {
        add(const VideoRecorderStopMotionFrameCaptured());
      }
      return;
    }

    switch (state.recordingState) {
      case VideoRecorderState.idle:
        add(const VideoRecorderRecordingStartRequested());
      case VideoRecorderState.error:
      case VideoRecorderState.recording:
        add(const VideoRecorderRecordingStopRequested());
    }
  }

  Future<void> _onRecordingStartRequested(
    VideoRecorderRecordingStartRequested event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    // Stop-motion captures stills via VideoRecorderStopMotionFrameCaptured;
    // a video-record start here would be a no-op at best and corrupt the
    // session at worst.
    if (_isClosing ||
        _pendingReactionStop != null ||
        state.recorderMode.capturesStills) {
      return;
    }

    final clipManager = _readClipManager();
    final remainingDuration = clipManager.remainingDuration;

    if (state.recordingLockedForNavigation ||
        !_cameraService.canRecord ||
        state.hasRecordingInFlight ||
        (remainingDuration < const Duration(milliseconds: 30) &&
            state.hasRecordingLimit)) {
      Log.debug(
        '🎥 Recording start ignored - '
        'locked: ${state.recordingLockedForNavigation}, '
        'canRecord: ${_cameraService.canRecord}, '
        'recording: ${state.isRecording}, '
        'starting: ${state.isStartingRecording}, '
        'stopping: ${state.isStoppingRecording}, '
        'remaining: ${remainingDuration.inMilliseconds}ms',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }

    final shouldRunCountdown =
        state.recorderMode.supportsCountdownTimer &&
        state.timerDuration != TimerDuration.off;
    final trace = _recordingTraces.start(
      _recordingTraceContext,
      countdown: shouldRunCountdown,
      sound: _readVideoEditorState().selectedSound?.resolvedSource != null,
    );
    try {
      await _startRecordingFromTap(
        emit,
        trace,
        clipManager: clipManager,
        remainingDuration: remainingDuration,
        shouldRunCountdown: shouldRunCountdown,
      );
    } finally {
      // Every path ends the trace itself; this only ends a start that threw.
      trace.errored();
    }
  }

  Future<void> _startRecordingFromTap(
    Emitter<VideoRecorderBlocState> emit,
    RecordingStartTrace trace, {
    required ClipManagerNotifier clipManager,
    required Duration remainingDuration,
    required bool shouldRunCountdown,
  }) async {
    emit(
      state.copyWith(
        isStartingRecording: true,
        baseZoomLevel: state.zoomLevel,
        clearStoppedTakePath: true,
        // The rail hides while the take runs, and comes back folded.
        isActionRailExpanded: false,
      ),
    );
    unawaited(HapticService.recordingFeedback());

    final cancellation = _reactionStartCancellation =
        _reactionRecordingOwner == null ? null : Completer<void>();
    bool shouldAbortStart() =>
        isClosed || _isClosing || cancellation?.isCompleted == true;

    if (shouldRunCountdown) {
      final seconds = state.timerDuration.duration.inSeconds;
      Log.info(
        '⏱️  Starting ${seconds}s countdown before recording',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );

      _countdownSoundService ??= _countdownSoundServiceFactory();
      try {
        await _countdownSoundService!.preload();
      } catch (e) {
        Log.warning(
          '⚠️ Failed to preload countdown sounds: $e',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }

      if (shouldAbortStart()) {
        _finishCancelledStart(emit, trace);
        return;
      }
      await _cameraService.setVolumeKeysEnabled(enabled: false);
      // The beeps play out of the speaker centimetres from the mic. With
      // the mic open through them, iOS takes seconds to recover its input
      // level, so the clip starts quiet and grows louder (#4539). Closing
      // the mic for the countdown keeps the beeps off the input path; it
      // reopens after the last beep, ahead of the recording.
      if (!shouldAbortStart()) await _cameraService.suspendAudioCapture();

      if (!shouldAbortStart()) {
        emit(state.copyWith(recordingState: VideoRecorderState.recording));
      }

      for (var i = seconds; i > 0 && !shouldAbortStart(); i--) {
        emit(state.copyWith(countdownValue: i));

        unawaited(_countdownSoundService!.playShortBeep());
        final delay = i > 1
            ? const Duration(seconds: 1)
            : const Duration(seconds: 1) -
                  CountdownSoundService.longBeepDuration -
                  CountdownSoundService.postPlaybackBuffer;
        final tick = Future<void>.delayed(delay);
        await (cancellation == null
            ? tick
            : Future.any([tick, cancellation.future]));
      }

      if (!shouldAbortStart()) {
        emit(state.copyWith(countdownValue: 0));
        unawaited(HapticService.recordingFeedback());
        await _countdownSoundService!.playLongBeepAndWait();
      }
      // The take is due from here: reopening the mic is part of starting it.
      trace.countdownEnded();

      // Reopen the mic ahead of native recording, if the take is still wanted.
      if (!shouldAbortStart()) await _cameraService.resumeAudioCapture();

      if (!_isClosing && !_remoteRecordPausedForSound) {
        await _cameraService.setVolumeKeysEnabled(enabled: true);
      }
    }

    if (shouldAbortStart()) {
      _finishCancelledStart(emit, trace);
      return;
    }

    if (state.recordingLockedForNavigation) {
      // Navigation released (or is releasing) the camera before the native
      // start ran — abort to idle instead of recording on a camera that is
      // about to be torn down.
      trace.aborted();
      emit(
        state.copyWith(
          isStartingRecording: false,
          pendingStopAfterStart: false,
          recordingState: VideoRecorderState.idle,
        ),
      );
      return;
    }

    await trace.measure(.soundPrep, _prepareSoundForPlayback);
    if (shouldAbortStart()) {
      _finishCancelledStart(emit, trace);
      return;
    }

    _reactionStartCancellation = null;
    final camera = _reactionMobileCamera;
    camera?.holdCaptureForRetention();
    final pendingStart = _pendingReactionStart = _reactionRecordingOwner == null
        ? null
        : Completer<void>();
    try {
      await _startNativeRecording(emit, trace, clipManager, remainingDuration);
    } finally {
      if (!state.hasRecordingInFlight) camera?.releaseRetainedCapture();
      pendingStart?.complete();
      _pendingReactionStart = null;
    }
  }

  Future<void> _startNativeRecording(
    Emitter<VideoRecorderBlocState> emit,
    RecordingStartTrace trace,
    ClipManagerNotifier clipManager,
    Duration remainingDuration,
  ) async {
    emit(state.copyWith(recordingState: VideoRecorderState.recording));

    Log.info(
      '🎥 Starting recording - aspect ratio: ${state.aspectRatio.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );

    unawaited(_playSoundPlayback());
    final success = await trace.measure(
      .nativeStart,
      () => _cameraService.startRecording(
        maxDuration: state.hasRecordingLimit ? remainingDuration : null,
      ),
    );

    if (state.recordingLockedForNavigation) {
      // The camera was released for navigation while the native start was in
      // flight. Don't latch a recording the user can never stop.
      trace.aborted();
      await _abortInFlightStartForLock(emit, sessionStarted: success);
      return;
    }

    if (success) {
      final owner = _reactionRecordingOwner;
      if (owner != null) _reactionTakeClock = Stopwatch()..start();
      Log.info(
        '✅ Recording truly started',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      _onRecordingStarted?.call(state.recorderMode);
      await trace.measure(.wakelock, WakelockPlus.enable);
      if (state.recordingLockedForNavigation) {
        // Navigation locked during the wakelock-enable await, after the native
        // session started. Abort with the same teardown as the in-flight guard
        // above rather than arm a clip manager (60fps timer + stopwatch) that
        // nothing can stop.
        trace.aborted();
        await _abortInFlightStartForLock(emit, sessionStarted: true);
        return;
      }
      trace.succeeded();
      if (owner == null || owner.isCurrent()) clipManager.startRecording();
      if (state.pendingStopAfterStart) {
        // A stop was requested while the native start was still in-flight
        // (brief press in hold-to-record mode).  Dispatch a proper stop now
        // that the camera is actually recording so the clip is finalized.
        Log.info(
          '⏹️  Dispatching pending stop after recording start (brief press)',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
        emit(
          state.copyWith(
            isStartingRecording: false,
            pendingStopAfterStart: false,
          ),
        );
        addIfOpen(const VideoRecorderRecordingStopRequested());
      } else {
        emit(state.copyWith(isStartingRecording: false));
      }
    } else {
      trace.failed();
      Log.warning(
        '⚠️ Recording failed to start or was stopped early',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          isStartingRecording: false,
          pendingStopAfterStart: false,
          recordingState: VideoRecorderState.idle,
        ),
      );
    }
  }

  void _finishCancelledStart(
    Emitter<VideoRecorderBlocState> emit,
    RecordingStartTrace trace,
  ) {
    trace.aborted();
    _reactionStartCancellation = null;
    emit(
      state.copyWith(
        isStartingRecording: false,
        pendingStopAfterStart: false,
        recordingState: VideoRecorderState.idle,
        countdownValue: 0,
      ),
    );
  }

  Future<void> _onRecordingStopRequested(
    VideoRecorderRecordingStopRequested event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final pendingReactionStop = _pendingReactionStop =
        _reactionRecordingOwner == null ? null : Completer<void>();
    try {
      // A native auto-stop may deliver the file before startup settles. Keep
      // that result in the stop pipeline while the reaction finishes starting.
      if (_pendingReactionStart case final startup? when event.result != null) {
        await startup.future;
      }
      await _handleRecordingStop(event, emit);
    } catch (error, stackTrace) {
      if (event._teardown == null) rethrow;
      Log.error(
        'Could not retain the reaction recording during recorder teardown',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      addError(error, stackTrace);
    } finally {
      if (!state.hasRecordingInFlight) {
        _reactionMobileCamera?.releaseRetainedCapture();
      }
      pendingReactionStop?.complete();
      _pendingReactionStop = null;
      event._teardown?.complete();
    }
  }

  Future<void> _handleRecordingStop(
    VideoRecorderRecordingStopRequested event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (state.isStoppingRecording) {
      return;
    }

    if (state.isStartingRecording) {
      if (_reactionStartCancellation case final cancellation?) {
        if (!cancellation.isCompleted) cancellation.complete();
        return;
      }
      // Recording is still starting (isStartingRecording=true).  The native
      // camera hasn't begun capturing yet, so calling stopRecording() here is
      // a no-op that races with startRecording() and can leave the BLoC stuck
      // in the recording state.  Instead, set the pendingStopAfterStart flag
      // and let _onRecordingStartRequested dispatch a proper stop once the
      // native start completes.
      Log.info(
        '⏳ Stop requested during startup - flagging pendingStopAfterStart '
        '(startRecording will dispatch stop after native start)',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(pendingStopAfterStart: true));
      return;
    }

    if (!state.isRecording && event.result == null) return;

    final stoppedTakePath = state.stoppedTakePath;
    if (stoppedTakePath != null &&
        event.result?.file?.path == stoppedTakePath) {
      // The camera reported the take this recorder already stopped a second
      // time. Adding it again would leave two clips on one file (#10194).
      Log.info(
        '⏭️  Ignoring a second stop result for the take already stopped: '
        '$stoppedTakePath',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }

    Log.info(
      '⏹️  Stopping recording and processing clip...',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    final owner = _reactionRecordingOwner;
    final reactionClipManager = owner?.clipManager;
    final reactionGeneration = reactionClipManager?.sessionGeneration;
    final takeClock = _reactionTakeClock?..stop();
    final capturedDuration =
        takeClock?.elapsed ?? reactionClipManager?.recordingElapsed ?? .zero;
    bool ownsOriginalTimeline() =>
        owner == null ||
        (owner.isCurrent() &&
            reactionClipManager!.isSessionCurrent(reactionGeneration!));
    bool ownsTimeline() =>
        owner == null || (!_isClosing && ownsOriginalTimeline());
    final trace = _recordingTraces.stop(
      _recordingTraceContext,
      trigger: event._teardown != null
          ? .teardown
          : event._isAutoStop
          ? .auto
          : .user,
    );
    emit(state.copyWith(isStoppingRecording: true));

    unawaited(HapticService.recordingFeedback());

    final EditorVideo? videoResult;
    VideoRecordingResult? secondaryRecording;
    final ClipManagerNotifier clipManager;
    final Duration remainingDuration;
    try {
      // Freeze the timer at the tap, not when the native stop returns. With a
      // look-ahead stabilization mode iOS waits ~1.6s for the camera to hand
      // over the last frames; a timer still running through that wait reads
      // as a stop that did not take, and counts the wait into the clip.
      if (ownsOriginalTimeline()) {
        (reactionClipManager ?? _readClipManager()).stopRecording();
      }
      await trace.measure(.soundStop, _stopSoundPlayback);
      videoResult =
          event.result ??
          await trace.measure(.nativeStop, _cameraService.stopRecording);
      // The camera parks a second file only beside a main one. A stop that
      // got none lost the race to an auto-stop, which is queued behind this
      // stop with its own file and takes the second one itself.
      if (videoResult != null) {
        secondaryRecording = _dualCamera?.takeSecondaryRecording();
      }
      // Best-effort: a wakelock teardown failure must not abort the stop and
      // discard an already-captured clip (videoResult is assigned above), so
      // it is swallowed rather than thrown into the recovery catch.
      await trace.measure(.wakelock, _disableWakelockSafely);
      clipManager = reactionClipManager ?? _readClipManager();
      remainingDuration = ownsTimeline()
          ? clipManager.remainingDuration
          : .zero;
    } catch (e, stackTrace) {
      // Defense-in-depth recovery. Neither production CameraService throws
      // from stopRecording() (both catch internally and return null),
      // _stopSoundPlayback() swallows its own errors, and the wakelock
      // teardown is guarded above — so this is only reached if that
      // camera/audio/clip-manager contract is violated. If it ever is,
      // anything thrown between setting isStoppingRecording=true and clearing
      // it below would strand the recorder: the flag stays true and every
      // future stop bails at the top of this handler, so the recording could
      // never be stopped again. Run best-effort cleanup so the user can
      // recover.
      trace.errored();
      Log.error(
        '⚠️ Failed to stop recording cleanly - resetting recorder state',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      addError(e, stackTrace);
      // The 60fps duration timer was already stopped at the top of the try;
      // resetRecording only clears the in-progress segment.
      if (ownsOriginalTimeline()) {
        (reactionClipManager ?? _readClipManager()).resetRecording();
      }
      await _disableWakelockSafely();
      emit(
        state.copyWith(
          recordingState: VideoRecorderState.idle,
          isStoppingRecording: false,
        ),
      );
      return;
    }
    trace.finished(
      file: videoResult != null,
      secondaryFile: secondaryRecording != null,
    );

    emit(
      state.copyWith(
        recordingState: VideoRecorderState.idle,
        isStoppingRecording: false,
        stoppedTakePath: videoResult?.file?.path,
      ),
    );
    if (videoResult == null) {
      Log.warning(
        '⚠️ Recording stopped but no video file returned from '
        'camera service',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      addError(const RecordingProducedNoVideoException(), StackTrace.current);
      // Keeps the frozen duration: when the recording limit stopped the take
      // first, the camera refused this stop and still hands the take over,
      // and that clip is measured with it.
      if (ownsOriginalTimeline()) {
        clipManager.clearActiveRecordingDuration();
      }
      return;
    }

    _reactionTakeClock = null;
    // The footage is the raw camera frame. The key the viewfinder showed
    // travels with it as an intent and is baked right after the take.
    final captureChromaKey = state.isChromaKeyActive ? state.chromaKey : null;
    // The clip owns the backdrop image from here; the recorder no longer
    // deletes it when the backdrop changes or the recorder closes.
    if (captureChromaKey?.backgroundImagePath case final imagePath?
        when imagePath == state.unrecordedChromaKeyImagePath) {
      emit(state.copyWith(clearUnrecordedChromaKeyImagePath: true));
    }
    if (owner != null && !ownsTimeline()) {
      // Retain the take under the account that opened the camera. The newer
      // timeline may already contain a different project or account.
      final detached = clipManager.buildRecordedClip(
        video: videoResult,
        duration: capturedDuration,
        originalAspectRatio: _cameraService.cameraAspectRatio,
        targetAspectRatio: state.aspectRatio,
        lensMetadata: _cameraService.currentLensMetadata,
        captureChromaKey: captureChromaKey,
        secondaryRecording: secondaryRecording,
        secondaryPipCenter: state.dualCameraPipCenter,
        secondaryPipScale: state.dualCameraPipScale,
        secondaryPipRotation: state.dualCameraPipRotation,
        secondaryPipAspectRatio: state.dualCameraPipAspectRatio,
      );
      if (ownsOriginalTimeline()) clipManager.resetRecording();
      await owner.retain(detached);
      return;
    }
    final generation = reactionGeneration ?? clipManager.sessionGeneration;
    final clip = clipManager.addClip(
      video: videoResult,
      originalAspectRatio: _cameraService.cameraAspectRatio,
      targetAspectRatio: state.aspectRatio,
      lensMetadata: _cameraService.currentLensMetadata,
      limitClipDuration: state.hasRecordingLimit,
      captureChromaKey: captureChromaKey,
      secondaryRecording: secondaryRecording,
      secondaryPipCenter: state.dualCameraPipCenter,
      secondaryPipScale: state.dualCameraPipScale,
      secondaryPipRotation: state.dualCameraPipRotation,
      secondaryPipAspectRatio: state.dualCameraPipAspectRatio,
    );
    final initialSave = clipManager.saveClipToLibrary(clip).then((saved) async {
      if (saved) return;
      Log.warning(
        '⚠️ Initial clip save to library failed for ${clip.id}',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      if (owner == null) return;
      // The account may disappear before the camera route hands back its
      // takes. Start recovery here using the stores captured by the recorder.
      try {
        await owner.retain(clip);
      } catch (error, stackTrace) {
        Log.error(
          'Could not recover reaction recording ${clip.id}',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
    unawaited(initialSave);
    // The second camera's take travels on its clip: the library lists the
    // clip, with both cameras on its picture.
    Future<void>? secondaryThumbnail;
    if (clip.secondaryCamera case final second?) {
      // Tracked so the editor waits for the poster before it turns the take
      // into a layer.
      secondaryThumbnail =
          _addSecondaryCameraThumbnail(
            clipId: clip.id,
            take: second,
            clipManager: clipManager,
            generation: generation,
          ).then<void>((_) {}).catchError((
            Object error,
            StackTrace stackTrace,
          ) {
            // A failure only costs the take's poster; the take itself is
            // already on its clip.
            Log.error(
              '⚠️ Second camera thumbnail failed for ${clip.id}',
              name: 'VideoRecorderBloc',
              category: LogCategory.video,
              error: error,
              stackTrace: stackTrace,
            );
          });
      clipManager.trackClipEnrichment(second.clip.id, secondaryThumbnail);
    }

    Log.debug(
      '📷 Lens metadata: ${_cameraService.currentLensMetadata?.toMap()}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );

    Log.info(
      '✅ Clip added successfully - ID: ${clip.id}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );

    // Clip post-processing — real duration, thumbnail, ghost frame and the
    // metadata-enriched library save — is deliberately detached (not awaited).
    // This handler runs in the `sequential()` stop bucket, so awaiting the
    // post-processing would serialize it ahead of the *next* stop request: a
    // slow library save or metadata pass (observed in the field taking ~100s)
    // would leave the user unable to stop their next recording until it
    // finished. The work mutates the clip in place on the clip manager (which
    // the UI observes) and re-saves it, so it is safe to run detached. The
    // bare clip was already persisted by the unawaited save above. The clip
    // manager tracks completion so a layout can await it before taking the
    // clip off the timeline, without holding this sequential stop handler.
    final enrichment =
        _enrichAndSaveClip(
          videoResult: videoResult,
          clip: clip,
          clipManager: clipManager,
          generation: generation,
          remainingDuration: remainingDuration,
        ).catchError((Object error, StackTrace stackTrace) {
          // Detached work must not escape as an unhandled async error. The bare
          // clip is already saved, so a failure here only loses the enriched
          // metadata, not the recording.
          Log.error(
            '⚠️ Clip post-processing failed for ${clip.id}',
            name: 'VideoRecorderBloc',
            category: LogCategory.video,
            error: error,
            stackTrace: stackTrace,
          );
        });
    if (owner != null) clipManager.trackClipEnrichment(clip.id, initialSave);
    clipManager.trackClipEnrichment(clip.id, enrichment);
    if (clip.hasPendingCaptureChromaKey) {
      // Bind the bake to this recording now. Let both raw library saves
      // finish first so neither can overwrite a keyed result.
      runDetached(
        clipManager.bakeRecordedTake(
          clip,
          generation: generation,
          after: Future.wait([initialSave, enrichment]),
        ),
        'bake the chroma key of take ${clip.id}',
        logName: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
    if (secondaryThumbnail != null) {
      // Galleries show a dual-camera take as one picture, as the viewfinder
      // showed it; drawn once both cameras' thumbnails exist.
      clipManager.trackClipEnrichment(
        clip.id,
        Future.wait([enrichment, secondaryThumbnail])
            .then(
              (_) => _composeDualCameraThumbnail(
                clip.id,
                clipManager,
                generation: generation,
              ),
            )
            .catchError((Object error, StackTrace stackTrace) {
              Log.error(
                '⚠️ Dual-camera thumbnail failed for ${clip.id}',
                name: 'VideoRecorderBloc',
                category: LogCategory.video,
                error: error,
                stackTrace: stackTrace,
              );
            }),
      );
    }
  }

  /// Draws the second camera's window over the dual-camera clip [clipId]'s
  /// thumbnail, gives the take that picture and saves the clip to the library
  /// again, so the library lists it with both cameras.
  ///
  /// The save waits for the take's proof: a take placed from the library
  /// carries what the library copy holds.
  Future<void> _composeDualCameraThumbnail(
    String clipId,
    ClipManagerNotifier clipManager, {
    required int generation,
  }) async {
    if (!clipManager.isSessionCurrent(generation)) return;
    // The composite and its proof travel together in the library. Wait
    // before writing the file or attaching it to the working timeline.
    await clipManager.waitForSecondaryCameraTakes();
    if (!clipManager.isSessionCurrent(generation)) return;

    final clip = clipManager.getClipById(clipId);
    final take = clip?.secondaryCamera;
    final mainThumbnail = clip?.thumbnailPath;
    final secondThumbnail = take?.clip.thumbnailPath;
    if (clip == null ||
        take == null ||
        mainThumbnail == null ||
        secondThumbnail == null) {
      return;
    }
    final composed = await composeDualCameraThumbnail(
      mainThumbnailPath: mainThumbnail,
      secondaryThumbnailPath: secondThumbnail,
      pipCenter: take.pipCenter,
      pipScale: take.pipScale,
      pipRotation: take.pipRotation,
      pipAspectRatio: take.pipAspectRatio,
      targetAspectRatio: clip.targetAspectRatio.value,
      outputPath: p.join(
        p.dirname(mainThumbnail),
        '${p.basenameWithoutExtension(mainThumbnail)}_dual.jpg',
      ),
    );
    if (composed == null) return;
    if (!clipManager.isSessionCurrent(generation) ||
        !clipManager.setSecondaryCameraThumbnail(
          clipId,
          takeId: take.clip.id,
          path: composed,
        )) {
      _deleteFileQuietly(composed);
      return;
    }
    final current = clipManager.getClipById(clipId);
    if (current == null) return;
    final saved = await clipManager.saveClipToLibrary(current);
    if (!saved) {
      Log.warning(
        '⚠️ Dual-camera clip save to library failed for $clipId',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  /// Gives the second camera's take of the dual-camera clip [clipId] a
  /// thumbnail, and returns the take's clip with it, or null when the take
  /// left its clip in the meantime.
  Future<DivineVideoClip?> _addSecondaryCameraThumbnail({
    required String clipId,
    required SecondaryCameraTake take,
    required ClipManagerNotifier clipManager,
    required int generation,
  }) async {
    if (!clipManager.isSessionCurrent(generation)) return null;
    final videoPath = take.clip.video?.file?.path;
    if (videoPath == null) return null;
    final halfDuration = take.clip.duration ~/ 2;
    final thumbnail = await VideoThumbnailService.extractThumbnail(
      videoPath: videoPath,
      targetTimestamp:
          halfDuration < VideoEditorConstants.defaultThumbnailExtractTime
          ? halfDuration
          : VideoEditorConstants.defaultThumbnailExtractTime,
    );
    if (!clipManager.isSessionCurrent(generation)) {
      if (thumbnail != null) _deleteFileQuietly(thumbnail.path);
      return null;
    }
    final current = clipManager.getClipById(clipId)?.secondaryCamera;
    if (current == null || current.clip.id != take.clip.id) {
      if (thumbnail != null) _deleteFileQuietly(thumbnail.path);
      return null;
    }
    final enriched = thumbnail == null
        ? current.clip
        : current.clip.copyWith(
            thumbnailPath: thumbnail.path,
            thumbnailTimestamp: thumbnail.timestamp,
          );
    clipManager.updateSecondaryCameraClip(clipId, enriched);
    return enriched;
  }

  /// Enriches a freshly recorded [clip] with its real duration, thumbnail and
  /// ghost frame, then re-saves the enriched clip to the library.
  ///
  /// Runs detached (fire-and-forget) from [_onRecordingStopRequested] so the
  /// `sequential()` stop handler returns immediately and never blocks a
  /// following stop request behind this potentially slow work.
  Future<void> _enrichAndSaveClip({
    required EditorVideo videoResult,
    required DivineVideoClip clip,
    required ClipManagerNotifier clipManager,
    required int generation,
    required Duration remainingDuration,
  }) async {
    final videoPath = await videoResult.safeFilePath();
    if (!clipManager.isSessionCurrent(generation)) return;
    final workCopyPath = '$videoPath.work.mp4';
    await File(videoPath).copy(workCopyPath);

    try {
      if (!clipManager.isSessionCurrent(generation)) return;
      final metadata = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(File(workCopyPath)),
      );
      if (!clipManager.isSessionCurrent(generation)) return;
      final clipDuration = commonTrackEnd(metadata) ?? metadata.duration;
      clipManager.updateClipDuration(clip.id, clipDuration);
      Log.debug(
        '📊 Video duration: ${clipDuration.inMilliseconds}ms',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );

      if (clipManager.clips.length == 1) {
        if (clip.processingCompleter != null) {
          unawaited(
            clip.processingCompleter!.future.then(
              (_) => DivineVideoPlayerController.preload([
                VideoClip.file(videoPath),
              ]),
            ),
          );
        } else {
          unawaited(
            DivineVideoPlayerController.preload([VideoClip.file(videoPath)]),
          );
        }
      }

      final effectiveDuration = remainingDuration < metadata.duration
          ? remainingDuration
          : metadata.duration;
      final halfDuration = effectiveDuration ~/ 2;
      final targetTimestamp =
          halfDuration < VideoEditorConstants.defaultThumbnailExtractTime
          ? halfDuration
          : VideoEditorConstants.defaultThumbnailExtractTime;

      final thumbnailResult = await VideoThumbnailService.extractThumbnail(
        videoPath: workCopyPath,
        targetTimestamp: targetTimestamp,
      );
      if (!clipManager.isSessionCurrent(generation)) {
        if (thumbnailResult != null) _deleteFileQuietly(thumbnailResult.path);
        return;
      }

      if (thumbnailResult != null &&
          clipManager.getClipById(clip.id)?.chromaKey != null) {
        // An editor that opened on the take first already keyed it, with a
        // poster of the composite. A frame of the raw wall must not replace it.
        _deleteFileQuietly(thumbnailResult.path);
      } else if (thumbnailResult != null) {
        clipManager.updateThumbnail(
          clipId: clip.id,
          thumbnailPath: thumbnailResult.path,
          thumbnailTimestamp: thumbnailResult.timestamp,
        );
        Log.debug(
          '🖼️  Thumbnail generated: ${thumbnailResult.path}',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      } else {
        Log.warning(
          '⚠️ Thumbnail generation failed',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }

      final ghostFramePath = await VideoThumbnailService.extractLastFrame(
        videoPath: workCopyPath,
        videoDuration: metadata.duration,
      );
      if (!clipManager.isSessionCurrent(generation)) {
        if (ghostFramePath != null) _deleteFileQuietly(ghostFramePath);
        return;
      }

      if (ghostFramePath != null) {
        clipManager.updateGhostFrame(
          clipId: clip.id,
          ghostFramePath: ghostFramePath,
        );
        Log.debug(
          '👻 Ghost frame generated: $ghostFramePath',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      } else {
        Log.warning(
          '⚠️ Ghost frame generation failed',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }

      // firstWhereOrNull, not firstWhere: the clip can be removed mid-
      // enrichment (delete-last-clip undo, capture↔classic switch) while this
      // detached work runs. A swallowed StateError would skip the work-copy
      // cleanup below; here the cleanup always runs in the finally.
      final updatedClip = clipManager.clips.firstWhereOrNull(
        (c) => c.id == clip.id,
      );
      if (updatedClip == null) {
        Log.warning(
          '⚠️ Clip ${clip.id} removed before metadata save — skipping '
          'enriched library save',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
        return;
      }
      final saved = await clipManager.saveClipToLibrary(updatedClip);
      if (!saved) {
        Log.warning(
          '⚠️ Metadata-enriched clip save to library failed for ${clip.id}',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }
    } finally {
      try {
        await File(workCopyPath).delete();
      } catch (e) {
        // Swallowed, but not silent: this runs in a finally, so throwing would
        // replace the enrichment result with a cleanup error. The copy lives
        // beside the recording in the documents directory, which no sweeper
        // covers — the media cache budget is temp-only, storage management
        // clears only the seam dir, and clip recovery deliberately skips
        // `.work.mp4`. A leak is therefore permanent and full clip size, and
        // this method created the file itself, so a failure is unexpected
        // rather than routine.
        Log.warning(
          'Work copy cleanup failed for $workCopyPath: $e',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }
    }
  }

  /// Aborts a native recording session the navigation lock landed on while a
  /// start was still in flight: best-effort stops + discards the just-started
  /// session (when [sessionStarted]) and returns to idle. Shared by the two
  /// lock guards in [_onRecordingStartRequested] — after the native start
  /// returns and after the wakelock-enable await — so neither latches a
  /// recording the user can never stop.
  Future<void> _abortInFlightStartForLock(
    Emitter<VideoRecorderBlocState> emit, {
    required bool sessionStarted,
  }) async {
    if (sessionStarted) {
      final video = await _cameraService.stopRecording();
      if (video != null) {
        if (_dualCamera?.takeSecondaryRecording() case final second?) {
          _deleteFileQuietly(second.filePath);
        }
      }
      await _discardAbortedRecording(video);
    }
    emit(
      state.copyWith(
        isStartingRecording: false,
        pendingStopAfterStart: false,
        recordingState: VideoRecorderState.idle,
      ),
    );
  }

  /// Best-effort deletes the orphaned file from a recording aborted by the
  /// navigation lock. Such a recording is never added to the library or shown
  /// to the user, so without this its file would leak on disk.
  Future<void> _discardAbortedRecording(EditorVideo? video) async {
    if (video == null) return;
    try {
      await File(await video.safeFilePath()).delete();
    } catch (error) {
      Log.debug(
        '⚠️ Failed to delete aborted recording file: $error',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  void _onLongPressZoomStarted(
    VideoRecorderLongPressZoomStarted event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    // Anchor the drag-zoom to the zoom level in effect when the gesture
    // begins. Without this, a long-press on a recording started elsewhere
    // (tap, volume key, BLE remote) — or one resumed after a pinch changed the
    // zoom — would measure from a stale base and snap on the first move.
    emit(state.copyWith(baseZoomLevel: state.zoomLevel));
  }

  Future<void> _onZoomedByLongPress(
    VideoRecorderZoomedByLongPress event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    const maxDragDistance = 240.0;
    // Up is negative dy, so a positive [verticalDrag] is a drag up (zoom in)
    // and a negative one is a drag down (zoom out).
    final verticalDrag = (-event.offsetFromOrigin.dy).clamp(
      -maxDragDistance,
      maxDragDistance,
    );

    // Exponential drag→zoom mapping so perceived sensitivity is uniform in
    // both directions: an equal drag step always multiplies zoom by the same
    // factor, so 1×→2× travels the same distance as 2×→4×. Dragging up
    // approaches the camera max; dragging down approaches the camera min
    // (e.g. an ultra-wide 0.6×). The previous linear, upward-only mapping
    // packed the whole absolute range into a short upward drag — jumpy at the
    // most-used low end — and could never reach sub-1× zoom. Mirrors the
    // multiplicative pinch mapping in _onScaleUpdated.
    final baseZoom = state.baseZoomLevel <= 0 ? 1.0 : state.baseZoomLevel;
    final targetBound = verticalDrag >= 0
        ? _cameraService.maxZoomLevel
        : _cameraService.minZoomLevel;
    final progress = verticalDrag.abs() / maxDragDistance;
    final zoomLevel = (baseZoom * math.pow(targetBound / baseZoom, progress))
        .clamp(_cameraService.minZoomLevel, _cameraService.maxZoomLevel);

    // Re-uses the same camera+state path as ZoomLevelSet.
    add(VideoRecorderZoomLevelSet(zoomLevel));
  }

  void _onScaleStarted(
    VideoRecorderScaleStarted event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    // Only a real pinch (two pointers) summons the ruler. A one-pointer
    // scale start is just a pan and must not flip the ruler interactive —
    // an invisible, fading-in ruler otherwise swallows the second finger
    // of the pinch that follows (its opaque hit-test band sits right where
    // the lower finger lands). isPinchActive additionally blocks the ruler
    // for the whole gesture, so a second finger landing on the (visible)
    // ruler still falls through to the preview and completes the pinch.
    //
    // snapTime is intentionally not reset here: copyWith's null-coalescing
    // semantics make explicit-null a no-op anyway, and the snap-update
    // handler guards every snapTime read with snappedTo1x — which we
    // just cleared. The next snap engagement overwrites snapTime fresh.
    final isPinch = event.details.pointerCount >= 2;
    emit(
      state.copyWith(
        baseZoomLevel: state.zoomLevel,
        snappedTo1x: false,
        lastRawZoom: state.zoomLevel,
        showZoomIndicator: isPinch ? true : null,
        isPinchActive: true,
      ),
    );
    if (isPinch) _armZoomIndicatorHideTimer();
  }

  void _onScaleEnded(
    VideoRecorderScaleEnded event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    emit(state.copyWith(isPinchActive: false));
  }

  Future<void> _onScaleUpdated(
    VideoRecorderScaleUpdated event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    // One-pointer updates with an unchanged scale are pans, not pinches
    // (a single pointer keeps scale at exactly 1.0; trackpad pinches
    // report a scale != 1.0). Skipping them keeps plain preview pans from
    // summoning and re-arming the zoom ruler.
    if (event.details.pointerCount < 2 && event.details.scale == 1.0) {
      return;
    }
    // Multiplicative mapping: the cumulative pinch scale multiplies the zoom
    // captured at gesture start, so the perceived sensitivity is uniform
    // across the whole range (1×→2× feels like 2×→4×). The previous
    // range-proportional mapping made the gain depend on the starting zoom —
    // fast far from a bound, sluggish near max — and differed between
    // zoom-in and zoom-out.
    final newZoom = state.baseZoomLevel * event.details.scale;

    var clampedZoom = newZoom.clamp(
      _cameraService.minZoomLevel,
      _cameraService.maxZoomLevel,
    );

    final hasUltraWideRange =
        _cameraService.minZoomLevel < 1.0 && _cameraService.maxZoomLevel > 1.0;

    if (hasUltraWideRange && !state.snappedTo1x) {
      const gravityRadius = 0.15;
      final distFrom1 = (clampedZoom - 1.0).abs();
      if (distFrom1 < gravityRadius) {
        final t = distFrom1 / gravityRadius;
        final damped = t * t;
        final direction = clampedZoom >= 1.0 ? 1.0 : -1.0;
        clampedZoom = 1.0 + direction * gravityRadius * damped;
      }
    }

    const snapHoldMs = 350;
    final crossedFrom = state.lastRawZoom;
    var snapped = state.snappedTo1x;
    DateTime? snapTime = state.snapTime;

    if (hasUltraWideRange) {
      if (!snapped &&
          (crossedFrom > 1.02 || crossedFrom < 0.98) &&
          (clampedZoom - 1.0).abs() <= 0.02) {
        snapped = true;
        snapTime = DateTime.now();
        clampedZoom = 1.0;
        // Confirm the 1× detent engagement with a light tick.
        unawaited(HapticService.snapFeedback());
      }

      if (snapped) {
        final elapsed = DateTime.now().difference(snapTime!).inMilliseconds;
        if (elapsed < snapHoldMs) {
          clampedZoom = 1.0;
        } else {
          snapped = false;
        }
      }
    }

    emit(
      state.copyWith(
        lastRawZoom: clampedZoom,
        snappedTo1x: snapped,
        snapTime: snapTime,
        showZoomIndicator: true,
        // Re-assert for the whole gesture. A two-finger pinch held stationary
        // for >1s emits no update, so the auto-hide timer fires while the
        // pinch is still down and clears isPinchActive. A resumed update must
        // restore it — otherwise the ruler shows interactive again and
        // swallows the lower pinch finger.
        isPinchActive: true,
      ),
    );
    _armZoomIndicatorHideTimer();

    // Dispatch when the applied zoom actually moved, or when the raw pinch
    // target pushed past a cached bound even though the clamp pinned it to the
    // current zoom. The latter re-runs the platform set so its read-back can
    // widen a stale ceiling a lifted runtime restriction left behind —
    // otherwise a user pinned at a shrunk max stays capped until they first
    // pinch back in.
    final pushedPastBound =
        newZoom > _cameraService.maxZoomLevel ||
        newZoom < _cameraService.minZoomLevel;
    if ((state.zoomLevel - clampedZoom).abs() > 0.01 || pushedPastBound) {
      add(VideoRecorderZoomLevelSet(clampedZoom));
    }
  }

  /// (Re)starts the zoom-ruler auto-hide countdown. Called on every pinch
  /// activity so the ruler stays up while the user is zooming and fades a
  /// short while after the gesture settles.
  void _armZoomIndicatorHideTimer() {
    _zoomIndicatorTimer?.cancel();
    _zoomIndicatorTimer = Timer(_zoomIndicatorHideDelay, () {
      if (isClosed) return;
      add(const _VideoRecorderZoomIndicatorTimerFired());
    });
  }

  void _onZoomIndicatorTimerFired(
    _VideoRecorderZoomIndicatorTimerFired event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    _zoomIndicatorTimer = null;
    // isPinchActive is cleared as a safety net for the timer-armed paths
    // (a real two-pointer pinch, or a programmatic zoom set): the timer only
    // fires after a full second without gesture activity, so a still-set flag
    // there usually means the scale-end callback was lost (e.g. gesture
    // cancelled by navigation) and would otherwise leave the ruler
    // non-interactive. Clearing it is safe even when the pinch is in fact
    // still down (held stationary >1s): _onScaleUpdated re-asserts the flag on
    // the next update, so the ruler can't turn interactive mid-gesture. A pure
    // one-finger pan arms no timer, so if its scale-end is lost the flag
    // instead self-heals on the next pinch or zoom set.
    emit(state.copyWith(showZoomIndicator: false, isPinchActive: false));
  }

  void _onRecordingLockedForNavigation(
    VideoRecorderRecordingLockedForNavigation event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    _lockRecordingForNavigation(emit);
  }

  void _onEditorNavigationStarted(
    VideoRecorderEditorNavigationStarted event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    emit(state.copyWith(editorNavigationInProgress: true));
  }

  void _onEditorNavigationEnded(
    VideoRecorderEditorNavigationEnded event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    emit(state.copyWith(editorNavigationInProgress: false));
  }

  Future<void> _onCameraPausedForNavigation(
    VideoRecorderCameraPausedForNavigation event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    try {
      Log.info(
        '📹 Camera paused for navigation - disposing',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      // Idempotent with VideoRecorderRecordingLockedForNavigation (which the
      // View dispatches first, before the push transition). Re-asserting here
      // keeps the recorder safe even if only the pause event is dispatched.
      _lockRecordingForNavigation(emit);
      await _cameraService.dispose();
    } finally {
      final completion = event.completion;
      if (completion != null && !completion.isCompleted) {
        completion.complete();
      }
    }
  }

  /// Locks recording for a navigation push: sets the lock, detaches the remote
  /// (volume / Bluetooth) trigger, and resets any in-flight / active recording
  /// to idle so a trigger that raced the navigation can't leave a recording the
  /// user can never stop. Runs synchronously while the camera is still live —
  /// the dispose (if any) happens after — so it never races the native start.
  /// The lock is cleared on the next [VideoRecorderInitializeRequested].
  void _lockRecordingForNavigation(Emitter<VideoRecorderBlocState> emit) {
    _cameraService.setOnRemoteRecordTrigger(null);
    _stopIntervalCapture(emit);
    if (state.isRecording || state.isStartingRecording) {
      _readClipManager()
        ..stopRecording()
        ..resetRecording();
      emit(
        state.copyWith(
          recordingLockedForNavigation: true,
          recordingState: VideoRecorderState.idle,
          isStartingRecording: false,
          isStoppingRecording: false,
          pendingStopAfterStart: false,
        ),
      );
    } else {
      emit(state.copyWith(recordingLockedForNavigation: true));
    }
  }

  Future<void> _onRecorderModeSet(
    VideoRecorderRecorderModeSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final previousMode = state.recorderMode;
    await _applyRecorderMode(
      emit,
      event.mode,
      keepAutosavedDraft: event.keepAutosavedDraft,
    );
    if (_isClosing) return;
    // Leaving Upload resumes a paused camera: a rebind while paused would
    // restart it on Android, so the resume applies the mode instead.
    if (previousMode.recordsVideo) {
      await _applyCameraForRecorderMode(emit, clearRetainedRequest: true);
    }
  }

  Future<void> _applyRecorderMode(
    Emitter<VideoRecorderBlocState> emit,
    VideoRecorderMode mode, {
    required bool keepAutosavedDraft,
  }) async {
    // No assembling-status guard: the assemble is synchronous, so a mode switch
    // cannot land inside it.
    _stopIntervalCapture(emit);
    // The recording mode the session's clips belong to. Upload records nothing,
    // so while it shows, that is the mode it was entered from — null when the
    // recorder opened straight into Upload.
    final sessionMode = !state.recorderMode.recordsVideo
        ? state.modeBeforeUpload
        : state.recorderMode;
    emit(
      state.copyWith(
        recorderMode: mode,
        modeBeforeUpload: mode.recordsVideo ? null : sessionMode,
        clearModeBeforeUpload: mode.recordsVideo,
        aspectRatio: mode.defaultAspectRatio,
        showGridLines: _gridLinesEnabledFor(mode),
        timerDuration: _timerDurationCarriedTo(mode),
        countdownValue: 0,
        // Ends an unfinished stop-motion session without deleting it: every
        // still went into the library as it was shot, so the session stays
        // there, as a capture clip does across a switch.
        stopMotionFrames: const [],
        stopMotionStatus: StopMotionStatus.idle,
      ),
    );
    final prefs = _readSharedPreferences();
    await prefs.setString(VideoRecorderMode.persistenceKey, mode.name);

    // A peek at Upload and back keeps the session; any other move between two
    // recording modes discards it, with or without Upload in between.
    final switchesRecordingMode =
        mode.recordsVideo && sessionMode != null && mode != sessionMode;
    if (switchesRecordingMode) {
      await _readClipManager().clearAll(
        keepAutosavedDraft: keepAutosavedDraft,
      );
      await _readVideoEditor().resetForRecorderMode(
        keepAutosavedDraft: keepAutosavedDraft,
      );
    }

    Log.debug(
      '🎬 Recorder mode changed to: ${mode.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
  }

  /// The timer setting to keep when switching to [mode].
  ///
  /// Kept only between modes that use it the same way: a delayed start left
  /// over from a video mode would otherwise turn stop-motion's next shutter
  /// tap into a loop nobody asked for.
  TimerDuration _timerDurationCarriedTo(VideoRecorderMode mode) =>
      mode.capturesStills == state.recorderMode.capturesStills &&
          mode.timerDurations.contains(state.timerDuration)
      ? state.timerDuration
      : TimerDuration.off;

  void _onTimerCycled(
    VideoRecorderTimerCycled event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    final durations = state.recorderMode.timerDurations;
    if (durations.isEmpty) return;

    // A setting the mode does not offer starts the cycle over from off.
    final newTimer =
        durations[(durations.indexOf(state.timerDuration) + 1) %
            durations.length];
    emit(state.copyWith(timerDuration: newTimer));
    Log.debug(
      '⏱️  Timer duration changed to: ${newTimer.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
  }

  void _onResetRequested(
    VideoRecorderResetRequested event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    Log.debug(
      '🔄 Resetting video recorder state',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    _stopIntervalCapture(emit);
    // An unfinished stop-motion session stays in the library, see
    // _applyRecorderMode.
    emit(
      VideoRecorderBlocState(
        isLiveChromaKeySupported: _liveChromaKeySupported,
        // A reset leaves native remote control as it is, so the sheets that
        // paused it still need their resumes to count.
        remoteRecordPauseCount: state.remoteRecordPauseCount,
      ),
    );
  }

  void _onShowLastClipOverlayToggled(
    VideoRecorderShowLastClipOverlayToggled event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    emit(state.copyWith(showLastClipOverlay: !state.showLastClipOverlay));
  }

  Future<void> _onDualCameraToggled(
    VideoRecorderDualCameraToggled event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final dualCamera = _dualCamera;
    if (dualCamera == null || _reactionRecordingOwner != null) return;
    if (_refusesRebindMidTake('Dual camera toggle')) return;
    if (!state.recorderMode.supportsDualCamera) return;
    final enable = !dualCamera.isDualCameraEnabled;
    if (enable && !dualCamera.isDualCameraSupported) return;

    emit(
      state.copyWith(
        isDualCameraChosen: enable,
        // Either way the rail folds and leaves the viewfinder to the change
        // the creator just made.
        isActionRailExpanded: false,
      ),
    );
    await _reconcileDualCamera(emit, dualCamera);
  }

  /// Turns dual-camera capture on or off and re-syncs the state. Returns
  /// whether the requested state is in effect.
  ///
  /// The session is rebuilt; the preview holds its last frame meanwhile,
  /// blurred like during a lens switch.
  Future<bool> _setDualCameraEnabled(
    Emitter<VideoRecorderBlocState> emit, {
    required bool enabled,
  }) async {
    final dualCamera = _dualCamera;
    if (dualCamera == null) return false;
    emit(state.copyWith(isSwitchingCamera: true));
    try {
      final applied = await dualCamera.setDualCameraEnabled(enabled: enabled);
      if (!applied) {
        Log.warning(
          '⚠️ Dual camera ${enabled ? 'on' : 'off'} did not take effect',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }
      if (!emit.isDone) {
        emit(state.copyWith(zoomLevel: 1, baseZoomLevel: 1));
        _emitCameraSync(emit);
      }
      return applied;
    } finally {
      if (!emit.isDone) {
        emit(state.copyWith(isSwitchingCamera: false));
      }
    }
  }

  void _onDualCameraPipChanged(
    VideoRecorderDualCameraPipChanged event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    // Turned into -pi..pi, so a window spun around twice stores the same
    // angle as one turned the short way.
    final turn = event.rotation % (2 * math.pi);
    emit(
      state.copyWith(
        dualCameraPipCenter: Offset(
          event.center.dx.clamp(0.0, 1.0),
          event.center.dy.clamp(0.0, 1.0),
        ),
        // The viewfinder may keep a turned window below the pinch's smallest
        // size so it stays whole; it never grows past the largest.
        dualCameraPipScale: event.scale.clamp(
          0.0,
          SecondaryCameraTake.pipMaxScale,
        ),
        dualCameraPipRotation: turn > math.pi ? turn - 2 * math.pi : turn,
      ),
    );
  }

  void _onDualCameraPipShapeToggled(
    VideoRecorderDualCameraPipShapeToggled event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    emit(
      state.copyWith(
        dualCameraPipAspectRatio: switch (state.dualCameraPipAspectRatio) {
          model.AspectRatio.vertical => model.AspectRatio.square,
          model.AspectRatio.square => model.AspectRatio.vertical,
        },
      ),
    );
  }

  Future<void> _onGridLinesToggled(
    VideoRecorderGridLinesToggled event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final enabled = !state.showGridLines;
    emit(state.copyWith(showGridLines: enabled));
    await _readSharedPreferences().setBool(_kGridLinesEnabledKey, enabled);
  }

  void _onActionRailToggled(
    VideoRecorderActionRailToggled event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    if (state.hasRecordingInFlight || state.isIntervalCaptureRunning) return;
    emit(state.copyWith(isActionRailExpanded: !state.isActionRailExpanded));
  }

  /// Whether a grid-supporting [mode] should show the grid: the user's last
  /// persisted choice, defaulting to on.
  bool _gridLinesEnabledFor(VideoRecorderMode mode) =>
      mode.supportGridLines &&
      (_readSharedPreferences().getBool(_kGridLinesEnabledKey) ?? true);

  // === Chroma-key handlers ===

  /// Turns the color mask on or off.
  ///
  /// Refused mid-take, where it would change what the take carries, and
  /// turning it on is refused where the renderer cannot key the viewfinder
  /// live or the mode has no mask. The camera's stabilization follows, since
  /// the mask runs without it. Turning the mask off writes off a measurement
  /// that is still out.
  Future<void> _onChromaKeyEnabledSet(
    VideoRecorderChromaKeyEnabledSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (event.enabled == state.isChromaKeyEnabled) return;
    if (_refusesRebindMidTake('Color mask change')) return;
    if (event.enabled && !state.offersChromaKey) return;
    emit(
      state.copyWith(
        isChromaKeyEnabled: event.enabled,
        chromaKeyMeasurementStatus: event.enabled
            ? null
            : state.chromaKeyMeasurementWrittenOff,
      ),
    );
    await _applyCameraForRecorderMode(emit, clearRetainedRequest: true);
  }

  /// Measures the wall behind the subject from a still and adopts the
  /// measured screen colour and amount.
  ///
  /// The rest of the key — edge, spill and the backdrop — is the user's and
  /// is kept. A setting changed by hand while this runs writes the
  /// measurement off, and its result is dropped when it lands.
  Future<void> _onChromaKeyMeasureRequested(
    VideoRecorderChromaKeyMeasureRequested event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (!state.isChromaKeyActive ||
        state.isRecording ||
        !_cameraService.isInitialized ||
        _cameraService.isSwitchingCamera) {
      return;
    }
    emit(
      state.copyWith(
        chromaKeyMeasurementStatus: ChromaKeyMeasurementStatus.detecting,
      ),
    );

    final ChromaKeyDetection detection;
    try {
      detection = await _measureChromaKey(
        visibleAspectRatio: state.aspectRatio.value,
      ).timeout(VideoEditorConstants.chromaKeyDetectTimeout);
    } on ChromaKeyDetectionException catch (error) {
      // Expected: plenty of rooms have no plain surface filling the frame.
      // The panel says so and the user sets the key by hand.
      Log.info(
        'Chroma-key measurement found no usable wall: ${error.message}',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      _endChromaKeyMeasurement(emit, ChromaKeyMeasurementStatus.failed);
      return;
    } on TimeoutException {
      Log.warning(
        'Chroma-key measurement gave up after '
        '${VideoEditorConstants.chromaKeyDetectTimeout.inSeconds}s',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      _endChromaKeyMeasurement(emit, ChromaKeyMeasurementStatus.timedOut);
      return;
    } catch (error, stackTrace) {
      addError(switch (error) {
        StateError() || TypeError() || RangeError() => Reportable(
          error,
          context: '_onChromaKeyMeasureRequested',
        ),
        _ => error,
      }, stackTrace);
      _endChromaKeyMeasurement(emit, ChromaKeyMeasurementStatus.failed);
      return;
    }

    // A hand edit while this ran wrote it off: the edit was deliberate and this
    // is a guess.
    if (!state.isMeasuringChromaKey) {
      _endChromaKeyMeasurement(emit, ChromaKeyMeasurementStatus.idle);
      return;
    }
    emit(
      state.copyWith(
        chromaKey: state.chromaKey.withKeySettings(
          color: detection.color,
          similarity: detection.similarity,
        ),
        chromaKeyMeasurementStatus: ChromaKeyMeasurementStatus.idle,
      ),
    );
  }

  /// Reports how a measurement ended. A written-off one only frees Auto-detect
  /// again, because its outcome no longer matters.
  void _endChromaKeyMeasurement(
    Emitter<VideoRecorderBlocState> emit,
    ChromaKeyMeasurementStatus status,
  ) {
    final next = switch (state.chromaKeyMeasurementStatus) {
      ChromaKeyMeasurementStatus.detecting => status,
      ChromaKeyMeasurementStatus.superseded => ChromaKeyMeasurementStatus.idle,
      ChromaKeyMeasurementStatus.idle ||
      ChromaKeyMeasurementStatus.failed ||
      ChromaKeyMeasurementStatus.timedOut => null,
    };
    if (next == null) return;
    emit(state.copyWith(chromaKeyMeasurementStatus: next));
  }

  /// Captures a still, measures the wall in it, and deletes the still again.
  ///
  /// Written to the temp directory rather than documents: the still is a
  /// measurement, not media, and must not outlive a crash mid-measurement.
  ///
  /// Auto flash is held off for the still. A photo in auto fires a burst — or
  /// on the front camera, a white screen — that the video never gets, and
  /// would measure the wall in light the recording will not see. A torch
  /// stays on: it lights the take the same way.
  Future<ChromaKeyDetection> _measureChromaKey({
    required double visibleAspectRatio,
  }) async {
    final restoreAutoFlash =
        state.flashMode == DivineFlashMode.auto &&
        await _cameraService.setFlashMode(DivineFlashMode.off);
    final PhotoCaptureResult? photo;
    try {
      photo = await _cameraService.capturePhoto(
        outputDirectory: Directory.systemTemp.path,
      );
    } finally {
      // Back to the mode the recorder shows, not to `auto`: the user may have
      // changed it while the still was taken, or after a timeout gave up on it.
      if (restoreAutoFlash) {
        await _cameraService.setFlashMode(state.flashMode);
      }
    }
    if (photo == null) {
      throw const ChromaKeyDetectionException('The camera returned no still');
    }
    try {
      return await _detectChromaKeyStill(
        photo.filePath,
        visibleAspectRatio: visibleAspectRatio,
      );
    } finally {
      _deleteFileQuietly(photo.filePath);
    }
  }

  void _onChromaKeyPresetSelected(
    VideoRecorderChromaKeyPresetSelected event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    emit(
      state.copyWith(
        chromaKey: state.chromaKey.withPreset(event.preset),
        chromaKeyMeasurementStatus: state.chromaKeyMeasurementWrittenOff,
      ),
    );
  }

  /// Keys on the tapped patch of the camera picture, writing off a
  /// measurement in flight like any setting changed by hand.
  void _onChromaKeyPatchPicked(
    VideoRecorderChromaKeyPatchPicked event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    final detection = ChromaKeyDetector.fromPatch(event.rgba);
    emit(
      state.copyWith(
        chromaKey: state.chromaKey.withKeySettings(
          color: detection.color,
          similarity: detection.similarity,
        ),
        chromaKeyMeasurementStatus: state.chromaKeyMeasurementWrittenOff,
      ),
    );
  }

  void _onChromaKeySettingsChanged(
    VideoRecorderChromaKeySettingsChanged event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    emit(
      state.copyWith(
        chromaKey: state.chromaKey.withKeySettings(
          color: event.color,
          similarity: event.similarity,
          smoothness: event.smoothness,
          spill: event.spill,
        ),
        chromaKeyMeasurementStatus: state.chromaKeyMeasurementWrittenOff,
      ),
    );
  }

  /// Swaps the backdrop, deleting an image the previous one left behind that
  /// no clip was recorded with.
  void _onChromaKeyBackdropSet(
    VideoRecorderChromaKeyBackdropSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    final key = state.chromaKey;
    final nextKey = switch (event.type) {
      ClipChromaKeyBackgroundType.transparent =>
        key.withTransparentBackground(),
      ClipChromaKeyBackgroundType.color => key.withColorBackground(
        event.color!,
      ),
      ClipChromaKeyBackgroundType.image => key.withImageBackground(event.path!),
      ClipChromaKeyBackgroundType.video => key.withVideoBackground(event.path!),
    };

    final orphan = state.unrecordedChromaKeyImagePath;
    final newImage = event.type == ClipChromaKeyBackgroundType.image
        ? event.path
        : null;
    if (orphan != null && orphan != newImage) _deleteFileQuietly(orphan);
    emit(
      state.copyWith(
        chromaKey: nextKey,
        unrecordedChromaKeyImagePath: newImage,
        clearUnrecordedChromaKeyImagePath: newImage == null,
      ),
    );
  }

  /// Deletes [path], logging rather than throwing: a file that cannot be
  /// removed costs disk, not correctness.
  ///
  /// Synchronous on purpose. Every caller hands over a single small file, such
  /// as a measurement still, a backdrop photo or a poster, and deleting it in
  /// the same turn means a close right after cannot race the cleanup.
  void _deleteFileQuietly(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (e) {
      Log.warning(
        '⚠️ Failed to delete $path: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  // === Stop-motion handlers ===

  /// Queues the library upsert of the session at [framePaths] with the
  /// recorder's current aspect ratio and lens.
  Future<void> _persistStopMotionSession(List<String> framePaths) =>
      _stopMotionSessions.persistSession(
        framePaths,
        aspectRatio: state.aspectRatio,
        lensMetadata: _cameraService.currentLensMetadata,
      );

  /// Takes the still a shutter tap asks for, see [_captureStopMotionFrame].
  Future<void> _onStopMotionFrameCaptured(
    VideoRecorderStopMotionFrameCaptured event,
    Emitter<VideoRecorderBlocState> emit,
  ) => _captureStopMotionFrame(emit);

  /// Captures one still, appends it to [state.stopMotionFrames], and persists
  /// the growing session to the library. Returns whether a still was appended.
  ///
  /// No video is rendered here — encoding one video per tap is far too slow
  /// (seconds per frame). Frames are encoded into a single video only at
  /// publish. The session is upserted to the library on every frame (not just
  /// on the "Next"/assemble tap) so the recording is preserved the instant it
  /// is shot, even if the user backs out before assembling.
  ///
  /// [withHaptic] is off for the hands-free stills of the interval loop: the
  /// phone sits on a stand then, and a vibration as the shutter fires would
  /// shake the very frame it confirms.
  Future<bool> _captureStopMotionFrame(
    Emitter<VideoRecorderBlocState> emit, {
    bool withHaptic = true,
  }) async {
    if (!_cameraService.isInitialized || _cameraService.isSwitchingCamera) {
      return false;
    }

    // An assemble hands the captured stills to the clip manager and clears
    // them; a still appended after that would be re-persisted as a phantom
    // one-frame session. `ready` (assemble done, navigation pending) is what
    // catches it — no assembling-status check, because the assemble is
    // synchronous, so it is never the current state while this runs. Dropping
    // the tap here also skips a native capture the after-await guard below
    // would only delete.
    if (state.stopMotionStatus == StopMotionStatus.ready) return false;

    if (withHaptic) unawaited(HapticService.recordingFeedback());
    // Shutter feedback must fire NOW — the native capture below takes
    // hundreds of ms, and blinking only once the frame lands feels laggy
    // compared to the system camera.
    emit(
      state.copyWith(stopMotionShutterTick: state.stopMotionShutterTick + 1),
    );

    final photo = await _cameraService.capturePhoto();
    if (photo == null) {
      Log.warning(
        '📷 Stop-motion frame capture returned no result',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return false;
    }

    // Only the still that just landed is checked — the ones already in state
    // were checked as they landed. Re-validating the whole list on every tap
    // costs two sync syscalls per existing frame (O(n²) over a session) on the
    // main isolate and can't learn anything new about them.
    if (!StopMotionFrameOps.isReadableImage(photo.filePath)) {
      Log.warning(
        '📷 Stop-motion frame capture wrote an unreadable file',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      await _stopMotionSessions.deleteFrameFile(photo.filePath);
      return false;
    }

    // The recorder can move off this session across the await above. "Next"
    // stays tappable, so an assemble can claim it — synchronously, so `ready`
    // is what it leaves behind, never `assembling`; the mode wheel stays live
    // during an idle capture, so a swipe can end it (_applyRecorderMode
    // clears the frames and leaves stop-motion, status idle). Either way the
    // session this still belonged to has left the recorder, so appending it
    // now would re-persist a phantom one-frame session — on the new mode, for
    // a swipe — so it is dropped with its file. Only idle (still shooting) and
    // failure (assemble bailed, stills retained) while still in stop-motion
    // own the session here.
    if (!state.recorderMode.capturesStills ||
        state.stopMotionStatus == StopMotionStatus.ready) {
      unawaited(_stopMotionSessions.deleteFrameFile(photo.filePath));
      return false;
    }

    final framePaths = [...state.stopMotionFrames, photo.filePath];
    if (state.stopMotionFrames.isEmpty) {
      _onRecordingStarted?.call(state.recorderMode);
    }
    // Back to idle so a retry after a failed assemble re-emits the failure the
    // status listener only fires on transitions.
    emit(
      state.copyWith(
        stopMotionFrames: framePaths,
        stopMotionStatus: StopMotionStatus.idle,
      ),
    );

    // Fire-and-forget so shooting stays instant; the library row is upserted
    // by the stable session id, so an out-of-order write just re-writes it.
    unawaited(_persistStopMotionSession(framePaths));
    return true;
  }

  /// Starts the hands-free loop: one still every [state.timerDuration] until
  /// the shutter is tapped again.
  ///
  /// The first still waits out a whole countdown as well. The tap that starts
  /// the loop is a hand on the phone, and it needs that long to leave the
  /// shot.
  void _startIntervalCapture(Emitter<VideoRecorderBlocState> emit) {
    if (!_cameraService.isInitialized ||
        _cameraService.isSwitchingCamera ||
        state.stopMotionStatus == StopMotionStatus.ready) {
      return;
    }

    final seconds = state.timerDuration.duration.inSeconds;
    Log.info(
      '⏱️  Starting stop-motion interval capture, one still every ${seconds}s',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    emit(
      state.copyWith(
        isIntervalCaptureRunning: true,
        countdownValue: seconds,
        // The rail hides while the loop runs, and comes back folded.
        isActionRailExpanded: false,
      ),
    );
    _armIntervalCaptureTick();
    unawaited(HapticService.recordingFeedback());
    // The first still is a whole countdown away, so the beep and the
    // wakelock have that long to land.
    runDetached(
      _prepareIntervalCapture(),
      'prepare stop-motion interval capture',
      logName: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
  }

  /// Loads the beep and keeps the screen awake for a loop that just started.
  Future<void> _prepareIntervalCapture() async {
    _countdownSoundService ??= _countdownSoundServiceFactory();
    try {
      await _countdownSoundService!.preload();
    } catch (e) {
      Log.warning(
        '⚠️ Failed to preload countdown sounds: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }

    // Nobody touches the phone while the loop runs, so the screen would
    // otherwise lock in the middle of a session.
    await WakelockPlus.enable();
    // A stop or a close that landed meanwhile released the wakelock before
    // it was taken.
    if (_isClosing || !state.isIntervalCaptureRunning) {
      await _disableWakelockSafely();
    }
  }

  /// Ends a running hands-free loop. The stills it captured stay in the
  /// session.
  void _stopIntervalCapture(Emitter<VideoRecorderBlocState> emit) {
    _intervalCaptureTimer?.cancel();
    _intervalCaptureTimer = null;
    if (!state.isIntervalCaptureRunning) return;

    Log.info(
      '⏹️  Stopping stop-motion interval capture after '
      '${state.stopMotionFrameCount} stills',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(isIntervalCaptureRunning: false, countdownValue: 0));
    unawaited(_disableWakelockSafely());
  }

  void _armIntervalCaptureTick() {
    _intervalCaptureTimer?.cancel();
    _intervalCaptureTimer = Timer(
      _intervalCaptureTickInterval,
      () => addIfOpen(const _VideoRecorderIntervalCaptureTicked()),
    );
  }

  /// Counts the interval down by a second, and takes the next still once it
  /// runs out.
  ///
  /// The countdown starts over once the still has landed, not when the
  /// shutter fired: the camera is still taking the picture for a moment after
  /// the blink, and a hand back in the scene by then would be in the frame.
  Future<void> _onIntervalCaptureTicked(
    _VideoRecorderIntervalCaptureTicked event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (!state.isIntervalCaptureRunning) return;

    final secondsLeft = state.countdownValue - 1;
    if (secondsLeft > 0) {
      emit(state.copyWith(countdownValue: secondsLeft));
      _armIntervalCaptureTick();
      return;
    }

    emit(state.copyWith(countdownValue: 0));
    final captured = await _captureStopMotionFrame(emit, withHaptic: false);
    // A stop, a mode switch or the recorder closing can land while the still
    // is out.
    if (_isClosing || !state.isIntervalCaptureRunning) return;

    if (captured) {
      // The loop's only sound: the still is in, so hands can go back into
      // the scene.
      unawaited(_countdownSoundService?.playShortBeep());
      if (!_hasStopMotionBudgetLeft) {
        Log.info(
          '⏹️  Stop-motion interval capture filled the shot budget',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
        _stopIntervalCapture(emit);
        return;
      }
    }

    emit(
      state.copyWith(countdownValue: state.timerDuration.duration.inSeconds),
    );
    _armIntervalCaptureTick();
  }

  /// Whether another still still fits in the session's shot budget.
  ///
  /// The loop stops once it does not. A still past the budget is trimmed off
  /// in the editor anyway, and a loop left running unattended would go on
  /// filling the disk with them.
  bool get _hasStopMotionBudgetLeft {
    final clipManager = _readClipManager();
    final remaining = StopMotionFrameOps.remainingCaptureFrames(
      state.stopMotionFrameCount,
      committed: clipManager.totalDuration,
      framesPerImage: StopMotionFrameOps.captureFramesPerImageFor(
        clipManager.clips,
      ),
    );
    return remaining > 0;
  }

  /// Removes the last captured stop-motion frame, deletes its file, and
  /// re-syncs the session's library row to the remaining frames (dropping the
  /// row entirely once every frame has been undone).
  Future<void> _onStopMotionFrameUndone(
    VideoRecorderStopMotionFrameUndone event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final frames = state.stopMotionFrames;
    if (frames.isEmpty) return;

    final removed = frames.last;
    final remaining = frames.sublist(0, frames.length - 1);
    emit(state.copyWith(stopMotionFrames: remaining));
    unawaited(_stopMotionSessions.deleteFrameFile(removed));

    if (remaining.isEmpty) {
      // Whole session undone — drop its library row. The frame file is deleted
      // above, so a row-only delete is correct here.
      unawaited(_stopMotionSessions.removeSession(frames.first));
    } else {
      unawaited(_persistStopMotionSession(remaining));
    }
  }

  /// Saves the captured frames as a frames-based stop-motion clip in the clip
  /// manager, then emits [StopMotionStatus.ready] for the editor handoff.
  ///
  /// The frames are the source of truth; no mp4 is rendered here. The editor
  /// previews the frames via the stop-motion player and only renders an mp4 at
  /// publish. Synchronous by design: nothing here is worth making the user wait
  /// for (the library save is queued, see [StopMotionSessionStore.ingest]), so
  /// no progress UI ever gets a frame to paint in.
  void _onStopMotionAssembleRequested(
    VideoRecorderStopMotionAssembleRequested event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    _stopIntervalCapture(emit);
    final frames = state.stopMotionFrames;
    if (frames.isEmpty) return;

    // Never painted (the handler is synchronous, so this is superseded before
    // the next frame) — but required: without a distinct state in between, a
    // second assemble of the same failing frame list emits a state equal to the
    // current one, which `emit` drops, and the failure snackbar never re-fires.
    emit(state.copyWith(stopMotionStatus: StopMotionStatus.assembling));

    try {
      _stopMotionSessions.ingest(
        frames,
        aspectRatio: state.aspectRatio,
        lensMetadata: _cameraService.currentLensMetadata,
        appendToComposition: event.appendToComposition,
      );
    } catch (e, stackTrace) {
      Log.warning(
        '⚠️ Stop-motion ingest failed',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(state.copyWith(stopMotionStatus: StopMotionStatus.failure));
      return;
    }

    emit(
      state.copyWith(
        stopMotionStatus: StopMotionStatus.ready,
        stopMotionFrames: const [],
      ),
    );
  }

  void _onCameraStateChanged(
    _VideoRecorderCameraStateChanged event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    Log.debug(
      '🔄 Updating video recorder state',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    _emitCameraSync(emit, cameraRebuildCount: event.cameraRebuildCount);
  }

  void _onScreenFlashChanged(
    _VideoRecorderScreenFlashChanged event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    emit(state.copyWith(isScreenFlashActive: event.isActive));
  }

  /// Rebuilds [state] from the current [CameraService] values.
  ///
  /// Only the rebuild count, aspect ratio, recorder mode (with the mode Upload
  /// was entered from), overlay and grid toggles, the open or folded capture
  /// rail, the timer setting, the take in flight, the navigation lock and the
  /// editor navigation in progress, the remote record pause, the stop-motion
  /// session and interval loop, the chroma-key setup, the dual-camera choice
  /// and window placement, and (while initialized) the screen flash carry over;
  /// flash resets to `off` and every other field to its default.
  ///
  /// A wall measurement survives a re-sync on the same side of the phone, but
  /// not a flip to the other one: its still shows the wall behind the lens it
  /// was taken through, so it is written off and dropped when it lands.
  void _emitCameraSync(
    Emitter<VideoRecorderBlocState> emit, {
    int? cameraRebuildCount,
    model.AspectRatio? aspectRatio,
  }) {
    final isFrontCamera = _cameraService.currentLens.isFrontFacing;
    emit(
      VideoRecorderBlocState(
        cameraRebuildCount: cameraRebuildCount ?? state.cameraRebuildCount,
        aspectRatio: aspectRatio ?? state.aspectRatio,
        flashMode: DivineFlashMode.off,
        minZoomLevel: _cameraService.minZoomLevel,
        maxZoomLevel: _cameraService.maxZoomLevel,
        cameraSensorAspectRatio: _cameraService.cameraAspectRatio,
        canRecord: _cameraService.canRecord,
        isCameraInitialized: _cameraService.isInitialized,
        hasFlash: _cameraService.hasFlash,
        // Only the native camera turns the screen flash on or off, so a
        // re-sync keeps its last report. A disposed camera has restored the
        // brightness, but that report can arrive after the camera callbacks
        // were cleared.
        isScreenFlashActive:
            _cameraService.isInitialized && state.isScreenFlashActive,
        canSwitchCamera: _cameraService.canSwitchCamera,
        isFrontCamera: isFrontCamera,
        previewTextureId: _cameraService.textureId,
        isDualCameraSupported:
            _reactionRecordingOwner == null &&
            (_dualCamera?.isDualCameraSupported ?? false),
        isDualCameraEnabled: _dualCamera?.isDualCameraEnabled ?? false,
        secondaryPreviewTextureId: _dualCamera?.secondaryCamera?.textureId,
        // Where the user dragged, pinched and turned the window outlives a
        // re-sync, a swap included, and so does the choice to film with both
        // cameras.
        dualCameraPipCenter: state.dualCameraPipCenter,
        dualCameraPipScale: state.dualCameraPipScale,
        dualCameraPipRotation: state.dualCameraPipRotation,
        dualCameraPipAspectRatio: state.dualCameraPipAspectRatio,
        isDualCameraChosen: state.isDualCameraChosen,
        videoStabilizationMode: _cameraService.videoStabilizationMode,
        availableVideoStabilizationModes:
            _cameraService.availableVideoStabilizationModes,
        isVideoStabilizationSupported:
            _cameraService.isVideoStabilizationSupported,
        showLastClipOverlay: state.showLastClipOverlay,
        recorderMode: state.recorderMode,
        modeBeforeUpload: state.modeBeforeUpload,
        isCollabPart: state.isCollabPart,
        showGridLines: state.showGridLines,
        // A flip re-syncs, and the rail it was tapped on stays open.
        isActionRailExpanded: state.isActionRailExpanded,
        // The native take outlives a re-sync. Reading idle here would hide the
        // stop button and let the shutter start a second take on top of it.
        recordingState: state.recordingState,
        // A native re-sync must not turn a running interval into a zero-second
        // countdown or change the timer the user selected.
        timerDuration: state.timerDuration,
        countdownValue: state.countdownValue,
        isStartingRecording: state.isStartingRecording,
        isStoppingRecording: state.isStoppingRecording,
        pendingStopAfterStart: state.pendingStopAfterStart,
        // Only the next initialize releases the lock. The camera's own dispose
        // reports through here, right after the lock is set.
        recordingLockedForNavigation: state.recordingLockedForNavigation,
        // The camera is released while the editor is open, and that dispose
        // re-syncs here; the editor navigation only ends when its route returns.
        editorNavigationInProgress: state.editorNavigationInProgress,
        // A sheet that paused remote control can be open across the re-sync
        // that initialize emits, and stays paused until it closes.
        remoteRecordPauseCount: state.remoteRecordPauseCount,
        // Preserve the in-progress stop-motion capture session: a camera-field
        // re-sync must not wipe already-captured frames, or the session would
        // split into several one-frame recordings (and lose frames on
        // assemble).
        stopMotionFrames: state.stopMotionFrames,
        stopMotionStatus: state.stopMotionStatus,
        stopMotionShutterTick: state.stopMotionShutterTick,
        // Its timer outlives the re-sync too. Reading false here would leave
        // the loop capturing behind a shutter that offers to start it.
        isIntervalCaptureRunning: state.isIntervalCaptureRunning,
        // The mask, its key and backdrop are the user's, and the backdrop
        // photo is still this recorder's to delete: a flip, a stabilization
        // rebind or a re-init must not reset them.
        isLiveChromaKeySupported: _liveChromaKeySupported,
        isChromaKeyEnabled: state.isChromaKeyEnabled,
        chromaKey: state.chromaKey,
        chromaKeyMeasurementStatus: isFrontCamera == state.isFrontCamera
            ? state.chromaKeyMeasurementStatus
            : state.chromaKeyMeasurementWrittenOff,
        unrecordedChromaKeyImagePath: state.unrecordedChromaKeyImagePath,
      ),
    );
  }

  void _onRemoteRecordTriggered(
    _VideoRecorderRemoteRecordTriggered event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    // The Upload tab pauses the camera and shows no preview, so a volume or
    // Bluetooth press there must not start a recording the user cannot see.
    if (!state.recorderMode.recordsVideo) {
      Log.debug(
        '🎮 Remote record trigger ignored - no preview on '
        '${state.recorderMode.name}',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }
    // A sheet's pause reaches the camera asynchronously, so a press can land
    // between the sheet opening and remote control going off.
    if (state.isRemoteRecordPaused) {
      Log.debug(
        '🎮 Remote record trigger ignored - a sheet covers the preview',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }
    if (_remoteRecordPausedForSound) {
      Log.debug(
        '🎮 Remote record trigger ignored - sound is selected',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }
    Log.info(
      '🎮 Remote record trigger received! Dispatching toggleRecording…',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    add(const VideoRecorderRecordingToggleRequested());
  }

  Future<void> _onAutoStopped(
    _VideoRecorderAutoStopped event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    // A null video still goes through the stop pipeline: it resets the
    // recorder and reports the empty recording. The camera service already
    // knows the recording ended, so it answers with no file.
    add(VideoRecorderRecordingStopRequested._autoStop(event.video));
  }

  // === Private helpers ===

  CameraMobileService? get _reactionMobileCamera => switch (_cameraService) {
    final CameraMobileService camera when _reactionRecordingOwner != null =>
      camera,
    _ => null,
  };

  /// The camera's dual-camera capture, or null when it has none.
  DualCameraCapture? get _dualCamera => switch (_cameraService) {
    final DualCameraCapture dualCamera => dualCamera,
    _ => null,
  };

  /// Whether [change] must be refused because it rebinds the camera while a
  /// take is in flight. A rebind mid-take ends it without a clip on Android,
  /// and leaves iOS writing a recording the recorder can no longer stop.
  bool _refusesRebindMidTake(String change) {
    if (!state.hasRecordingInFlight) return false;
    Log.debug(
      '🔄 $change ignored - recording in progress',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    return true;
  }

  Future<void> _setupRemoteRecordControl() async {
    _cameraService.setOnRemoteRecordTrigger(() {
      if (isClosed) return;
      add(const _VideoRecorderRemoteRecordTriggered());
    });

    final success = await _cameraService.setRemoteRecordControlEnabled(
      enabled: true,
    );
    _remoteRecordControlEnabled = success;

    if (success) {
      Log.info(
        '🎮 Remote record control enabled (volume buttons / Bluetooth)',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );

      if (state.isRemoteRecordPaused) {
        // A sheet opened while the camera was starting, so its pause could
        // not reach remote control yet. Apply it now; the sheet resumes it
        // on closing.
        await _cameraService.setRemoteRecordControlEnabled(enabled: false);
        Log.debug(
          '🎮 Remote record control paused (sheet opened during startup)',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      } else if (_remoteRecordPausedForSound) {
        await _cameraService.setVolumeKeysEnabled(enabled: false);
        Log.debug(
          '🎮 Volume keys released (sound already selected)',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }
    } else {
      Log.warning(
        '⚠️ Failed to enable remote record control',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _disableRemoteRecordControl() async {
    if (_remoteRecordControlEnabled) {
      await _cameraService.setRemoteRecordControlEnabled(enabled: false);
      _cameraService.setOnRemoteRecordTrigger(null);
      _remoteRecordControlEnabled = false;
      Log.debug(
        '🎮 Remote record control disabled',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _saveCurrentLensPreference() async {
    final lens = _cameraService.currentLens;
    final prefs = _readSharedPreferences();
    await prefs.setString(_kLastUsedCameraLensKey, lens.toNativeString());
    Log.debug(
      '💾 Saved camera lens preference: ${lens.displayName}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
  }

  Future<void> _saveStabilizationModePreference(
    DivineVideoStabilizationMode mode,
  ) async {
    final prefs = _readSharedPreferences();
    await prefs.setString(
      _kLastUsedStabilizationModeKey,
      mode.toNativeString(),
    );
    Log.debug(
      '💾 Saved stabilization preference: ${mode.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
  }

  /// The persisted stabilization mode, as last picked in a mode that shows
  /// the control, or [_kDefaultStabilizationMode] before any pick.
  ///
  /// The native controller is recreated (mode reset to off) on every init, so
  /// the preference travels with each one (see [_stabilizationModeFor]). The
  /// platform opens with off when the active lens does not support it.
  DivineVideoStabilizationMode _savedStabilizationMode(
    SharedPreferences prefs,
  ) {
    final saved = prefs.getString(_kLastUsedStabilizationModeKey);
    if (saved == null) return _kDefaultStabilizationMode;
    return DivineVideoStabilizationMode.fromNativeString(saved);
  }

  /// The stabilization the camera runs: the saved choice where the recorder
  /// [stabilizes] and shows the control, off where it hides it, so Classic,
  /// Stop Motion and the color mask never run a mode picked in Capture. The
  /// saved choice itself stays untouched.
  DivineVideoStabilizationMode _stabilizationModeFor({
    required bool stabilizes,
    required SharedPreferences prefs,
  }) => stabilizes
      ? _savedStabilizationMode(prefs)
      : DivineVideoStabilizationMode.off;

  /// Points the live camera at the current mode and color mask: dual-camera
  /// capture where it is offered and was turned on in this recorder, and the
  /// stabilization [_stabilizationModeFor] them.
  ///
  /// Where dual-camera capture is not offered it is turned off first, so the
  /// stabilization lands on the single-camera session. Where it is offered it
  /// comes back last: dual capture runs without stabilization, and turning it
  /// off later rebinds one camera with the mode set here.
  Future<void> _applyCameraForRecorderMode(
    Emitter<VideoRecorderBlocState> emit, {
    bool clearRetainedRequest = false,
  }) async {
    // Upload pauses the camera and records nothing.
    if (!state.recorderMode.recordsVideo || !_cameraService.isInitialized) {
      return;
    }
    // Where dual capture is not offered — another mode, or the color mask,
    // which keys one camera's footage — one camera runs.
    final dualCamera = _dualCamera;
    if (dualCamera != null && !state.supportsDualCamera) {
      await _reconcileDualCamera(emit, dualCamera);
    }
    await _applyStabilizationForRecorderMode(
      clearRetainedRequest: clearRetainedRequest,
    );
    if (emit.isDone || dualCamera == null) return;
    await _reconcileDualCamera(emit, dualCamera);
  }

  /// Rebuilds the session until dual-camera capture is on exactly where the
  /// mode and color mask offer it and the creator turned it on in this
  /// recorder.
  ///
  /// A rebuild takes a moment, and the camera reports the old state until it
  /// returns. A toggle, mode switch or color mask landing meanwhile only
  /// changes what is wanted: it neither undoes the rebuild in flight nor
  /// starts a second one, and the running loop applies it next.
  Future<void> _reconcileDualCamera(
    Emitter<VideoRecorderBlocState> emit,
    DualCameraCapture dualCamera,
  ) async {
    if (_isReconcilingDualCamera) return;
    _isReconcilingDualCamera = true;
    try {
      while (!emit.isDone && !_isClosing) {
        // The camera's own answer: the state's copy is synced only once the
        // camera has opened.
        final wanted =
            _reactionRecordingOwner == null &&
            dualCamera.isDualCameraSupported &&
            state.recorderMode.supportsDualCamera &&
            !state.isChromaKeyActive &&
            state.isDualCameraChosen;
        if (dualCamera.isDualCameraEnabled == wanted) return;
        if (!await _setDualCameraEnabled(emit, enabled: wanted)) return;
        // Stabilization was set while two cameras ran, which take none.
        if (!wanted) await _applyStabilizationForRecorderMode();
      }
    } finally {
      _isReconcilingDualCamera = false;
    }
  }

  /// Points the live camera at [_stabilizationModeFor] the current mode and
  /// color mask.
  ///
  /// A saved mode the current lens cannot take is left alone: the camera
  /// already opened with off for it, and requesting it again would rebind the
  /// camera for nothing on Android. Explicit mode switches clear any retained
  /// native request when the target is off, even if this lens reports off.
  Future<void> _applyStabilizationForRecorderMode({
    bool clearRetainedRequest = false,
  }) async {
    final mode = state.recorderMode;
    final target = _stabilizationModeFor(
      stabilizes: state.supportsVideoStabilization,
      prefs: _readSharedPreferences(),
    );
    // Off must clear the native request even when this lens already reports
    // off: an unsupported lens can retain a non-off request for the next lens.
    // Otherwise switching to Classic here would enable stabilization again
    // as soon as the user switches to a supported lens.
    final mustClearRequest =
        clearRetainedRequest && target == DivineVideoStabilizationMode.off;
    if ((!mustClearRequest &&
            target == _cameraService.videoStabilizationMode) ||
        !_cameraService.availableVideoStabilizationModes.contains(target)) {
      return;
    }
    final success = await _cameraService.setVideoStabilizationMode(target);
    if (!success) {
      Log.warning(
        '⚠️ Failed to set stabilization to ${target.name} for ${mode.name}',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _prepareSoundForPlayback() async {
    final selectedSound = _readVideoEditorState().selectedSound;
    final source = selectedSound?.resolvedSource;
    if (selectedSound == null || source == null) {
      await _audioPlaybackService?.dispose();
      _audioPlaybackService = null;
      return;
    }

    try {
      _audioPlaybackService ??= _audioPlaybackServiceFactory();

      await _audioPlaybackService!.configureForRecording();
      // Imported audio is an on-disk file; loading it via loadAudio would
      // parse the path as a URL and fail with iOS "unsupported URL".
      if (source.kind == model.AudioSourceKind.file) {
        await _audioPlaybackService!.loadAudioFromFile(source.path);
      } else {
        await _audioPlaybackService!.loadAudio(selectedSound.url!);
      }

      final clipManager = _readClipManager();
      final startPosition =
          clipManager.totalDuration + selectedSound.startOffset;
      if (startPosition > Duration.zero) {
        await _audioPlaybackService!.seek(startPosition);
        Log.debug(
          'Seeking sound to position: '
          '${startPosition.inMilliseconds}ms '
          '(clips: ${clipManager.totalDuration.inMilliseconds}ms, '
          'offset: ${selectedSound.startOffset.inMilliseconds}ms)',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }

      Log.info(
        'Sound prepared for playback: '
        '${selectedSound.title ?? selectedSound.id}',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.warning(
        'Failed to prepare sound for playback: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _playSoundPlayback() async {
    if (_audioPlaybackService == null) return;

    try {
      await _audioPlaybackService!.play();
      Log.info(
        'Started sound playback during recording',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.warning(
        'Failed to start sound playback: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _stopSoundPlayback() async {
    if (_audioPlaybackService == null) return;

    try {
      await _audioPlaybackService!.stop();
      await _audioPlaybackService!.resetAudioSession();
      Log.info(
        'Stopped sound playback',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.warning(
        'Failed to stop sound playback: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  /// Releases the wakelock without letting a failure abort the caller.
  ///
  /// Wakelock teardown is best-effort: a failure only means the screen stays
  /// awake. It must never strand the recorder state or discard a captured
  /// clip, so the error is logged and swallowed.
  Future<void> _disableWakelockSafely() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      Log.warning(
        'Failed to disable wakelock: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  @override
  Future<void> close() async {
    await (_closeFuture ??= switch (_reactionMobileCamera) {
      final camera? => camera.finishCaptureTeardown(_closeRecorder),
      _ => _closeRecorder(),
    });
    if (!isClosed) await super.close();
  }

  Future<void> _closeRecorder() async {
    Log.debug(
      '🧹 Closing VideoRecorderBloc',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    _focusPointTimer?.cancel();
    _focusPointTimer = null;
    _zoomIndicatorTimer?.cancel();
    _zoomIndicatorTimer = null;
    _intervalCaptureTimer?.cancel();
    _intervalCaptureTimer = null;
    // A recorder closed mid-take must not leave the bakes held for good.
    _isClosing = true;
    if (_reactionStartCancellation case final cancellation?) {
      if (!cancellation.isCompleted) cancellation.complete();
    }
    _releaseChromaKeyBakes();
    // Route replacement can bypass Back. Wait for a native start or stop
    // already in flight, or finish the active take before releasing the camera.
    final pendingReactionStart = _pendingReactionStart;
    if (pendingReactionStart != null) await pendingReactionStart.future;
    final pendingReactionStop = _pendingReactionStop;
    if (pendingReactionStop != null) {
      await pendingReactionStop.future;
    } else if (!isClosed &&
        _reactionRecordingOwner != null &&
        state.isCapturingFootage) {
      final teardown = Completer<void>();
      add(VideoRecorderRecordingStopRequested._forTeardown(teardown));
      await teardown.future;
    }
    // A backdrop image no clip was recorded with is referenced by nothing
    // once this recorder is gone. Unless a take is on the camera or being
    // wrapped up: the clip it becomes may yet point at the image. A countdown
    // has put nothing on the camera, so it keeps no image alive.
    if (state.unrecordedChromaKeyImagePath case final orphan?
        when !state.isCapturingFootage && !state.isStoppingRecording) {
      _deleteFileQuietly(orphan);
    }
    try {
      await _stopMotionSessions.idle;
    } catch (e) {
      Log.warning(
        '🧹 Stop-motion session write cleanup failed: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.system,
      );
    }
    try {
      await _audioPlaybackService?.dispose();
      _audioPlaybackService = null;
    } catch (e) {
      Log.warning(
        '🧹 Audio playback service disposal failed: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.system,
      );
    }
    try {
      await _countdownSoundService?.dispose();
      _countdownSoundService = null;
    } catch (e) {
      Log.warning(
        '🧹 Countdown sound service disposal failed: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.system,
      );
    }
    try {
      await _disableRemoteRecordControl();
    } catch (e) {
      Log.warning(
        '🧹 Disable remote record control failed: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.system,
      );
    }
    await _disableWakelockSafely();
    try {
      await _cameraService.dispose();
    } catch (e) {
      Log.warning(
        '🧹 Camera service disposal failed during cleanup: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.system,
      );
    }
  }
}

/// Thrown when the camera service reports a stop with no video file — e.g.
/// the capture session was interrupted before any frame was ever captured,
/// so there was nothing to salvage (#9210). Deliberately not wrapped with
/// `Reportable`: an expected outcome of an interruption, not a
/// programming-invariant violation (`error_handling.md`'s decision matrix
/// says NO). It exists only so this path reaches `addError` instead of
/// failing silently.
class RecordingProducedNoVideoException implements Exception {
  const RecordingProducedNoVideoException();

  @override
  String toString() =>
      'RecordingProducedNoVideoException: camera service stopped recording '
      'but returned no video file';
}
