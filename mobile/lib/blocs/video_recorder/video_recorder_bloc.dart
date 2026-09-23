// ABOUTME: Bloc that owns the camera-recorder UI state (port of
// ABOUTME: VideoRecorderNotifier, removing concurrency-flag fields and
// ABOUTME: adding sequential() on recording start/stop).

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:divine_camera/divine_camera.dart'
    show
        CameraLensMetadata,
        DivineCameraLens,
        DivineVideoQuality,
        DivineVideoStabilizationMode;
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
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/camera_initialization_error.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/haptic_service.dart';
import 'package:openvine/services/music_mode_preference_service.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/video_editor/clip_media_duration.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:openvine/services/video_recorder/stop_motion_session_store.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
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

/// Accessor for the current [VideoEditorProviderState]. See
/// [ReadClipManagerState] for the same rationale.
typedef ReadVideoEditorState = VideoEditorProviderState Function();

/// Accessor for the [SharedPreferences] instance.
typedef ReadSharedPreferences = SharedPreferences Function();

/// Reports the recorder mode only after media capture actually starts.
typedef RecordingStartedCallback = void Function(VideoRecorderMode mode);

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
///    ([ReadClipManager], [ReadVideoEditor], [ReadSharedPreferences])
///    so the bloc remains pure Dart.
class VideoRecorderBloc
    extends Bloc<VideoRecorderEvent, VideoRecorderBlocState> {
  /// Creates a video recorder bloc.
  ///
  /// [readClipManager], [readVideoEditor], and [readSharedPreferences]
  /// bridge the Riverpod-scoped dependencies that survive
  /// migration (the sibling providers are out of scope for #4744 —
  /// see `tasks/plan_4744.md` §4 WS-2 PR3).
  ///
  /// [cameraService] and [cameraServiceFactory] are test seams. When the
  /// service override is omitted, the factory creates the platform-appropriate
  /// [CameraService] and wires its update / auto-stop / remote callbacks to
  /// internal events.
  ///
  /// [countdownSoundServiceFactory] and [audioPlaybackServiceFactory]
  /// are optional test overrides. Defaults preserve the iOS
  /// audio-session wiring required by #4539.
  VideoRecorderBloc({
    required ReadClipManager readClipManager,
    required ReadVideoEditor readVideoEditor,
    required ReadVideoEditorState readVideoEditorState,
    required ReadSharedPreferences readSharedPreferences,
    CameraService? cameraService,
    CameraServiceFactory cameraServiceFactory = CameraService.create,
    CountdownSoundServiceFactory? countdownSoundServiceFactory,
    AudioPlaybackServiceFactory? audioPlaybackServiceFactory,
    PerformanceTraceMonitor? performanceMonitor,
    RecordingStartedCallback? onRecordingStarted,
  }) : _readClipManager = readClipManager,
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
       super(const VideoRecorderBlocState()) {
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
    on<VideoRecorderRecorderModeSet>(_onRecorderModeSet);
    on<VideoRecorderTimerCycled>(_onTimerCycled);
    on<VideoRecorderResetRequested>(_onResetRequested);
    on<VideoRecorderShowLastClipOverlayToggled>(_onShowLastClipOverlayToggled);
    on<VideoRecorderGridLinesToggled>(_onGridLinesToggled);
    on<VideoRecorderStopMotionFrameCaptured>(
      _onStopMotionFrameCaptured,
      transformer: droppable(),
    );
    on<VideoRecorderStopMotionFrameUndone>(_onStopMotionFrameUndone);
    on<VideoRecorderStopMotionAssembleRequested>(
      _onStopMotionAssembleRequested,
      transformer: droppable(),
    );
    on<_VideoRecorderCameraStateChanged>(_onCameraStateChanged);
    on<_VideoRecorderRemoteRecordTriggered>(_onRemoteRecordTriggered);
    on<_VideoRecorderAutoStopped>(_onAutoStopped);
    on<_VideoRecorderFocusPointTimerFired>(_onFocusPointTimerFired);
    on<_VideoRecorderZoomIndicatorTimerFired>(_onZoomIndicatorTimerFired);
  }

  final ReadClipManager _readClipManager;
  final ReadVideoEditor _readVideoEditor;
  final ReadVideoEditorState _readVideoEditorState;
  final ReadSharedPreferences _readSharedPreferences;
  final CameraService? _cameraServiceOverride;
  final CountdownSoundServiceFactory _countdownSoundServiceFactory;
  final AudioPlaybackServiceFactory _audioPlaybackServiceFactory;
  final PerformanceTraceMonitor _performanceMonitor;
  final RecordingStartedCallback? _onRecordingStarted;

  late final CameraService _cameraService;
  AudioPlaybackService? _audioPlaybackService;
  CountdownSoundService? _countdownSoundService;
  Timer? _focusPointTimer;
  Timer? _zoomIndicatorTimer;
  late final _stopMotionSessions = StopMotionSessionStore(
    readClipManager: _readClipManager,
  );
  bool _remoteRecordControlEnabled = false;

  /// How long the zoom ruler stays visible after the last pinch activity
  /// before the auto-hide timer clears it.
  static const _zoomIndicatorHideDelay = Duration(milliseconds: 1000);

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

    final requestedMode = event.fromEditor ? null : event.recorderMode;
    if (requestedMode != null) {
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
        ),
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
        videoStabilizationMode: _savedStabilizationMode(prefs),
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

    // Opening straight into Upload: the screen's pause for that tab arrived
    // while the camera was still starting and was dropped, so release it now.
    if (state.recorderMode == VideoRecorderMode.upload) {
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
    }
  }

  Future<void> _onRemoteRecordPaused(
    VideoRecorderRemoteRecordPaused event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (_remoteRecordControlEnabled) {
      await _cameraService.setRemoteRecordControlEnabled(enabled: false);
      Log.debug(
        '🎮 Remote record control paused (for audio playback)',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _onRemoteRecordResumed(
    VideoRecorderRemoteRecordResumed event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (_remoteRecordControlEnabled) {
      await _cameraService.setRemoteRecordControlEnabled(enabled: true);
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
    if (state.isRecording) return;
    if (event.mode == state.videoStabilizationMode) return;
    final success = await _cameraService.setVideoStabilizationMode(event.mode);
    if (!success) {
      Log.warning(
        '⚠️ Failed to set stabilization mode to ${event.mode.name}',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
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
      add(const VideoRecorderStopMotionFrameCaptured());
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
    if (state.recorderMode.capturesStills) return;

    final clipManager = _readClipManager();
    final remainingDuration = clipManager.remainingDuration;

    if (state.recordingLockedForNavigation ||
        !_cameraService.canRecord ||
        state.isRecording ||
        state.isStartingRecording ||
        state.isStoppingRecording ||
        (remainingDuration < const Duration(milliseconds: 30) &&
            state.recorderMode.hasRecordingLimit)) {
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

    emit(
      state.copyWith(isStartingRecording: true, baseZoomLevel: state.zoomLevel),
    );
    unawaited(HapticService.recordingFeedback());

    final shouldRunCountdown =
        state.recorderMode.supportsCountdownTimer &&
        state.timerDuration != TimerDuration.off;
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

      await _cameraService.setVolumeKeysEnabled(enabled: false);
      // The beeps play out of the speaker centimetres from the mic. With
      // the mic open through them, iOS takes seconds to recover its input
      // level, so the clip starts quiet and grows louder (#4539). Closing
      // the mic for the countdown keeps the beeps off the input path; it
      // reopens after the last beep, ahead of the recording.
      await _cameraService.suspendAudioCapture();

      emit(state.copyWith(recordingState: VideoRecorderState.recording));

      for (var i = seconds; i > 0 && !isClosed; i--) {
        if (isClosed) break;
        emit(state.copyWith(countdownValue: i));

        unawaited(_countdownSoundService!.playShortBeep());
        final delay = i > 1
            ? const Duration(seconds: 1)
            : const Duration(seconds: 1) -
                  CountdownSoundService.longBeepDuration -
                  CountdownSoundService.postPlaybackBuffer;
        await Future<void>.delayed(delay);
      }

      if (isClosed) {
        emit(
          state.copyWith(
            isStartingRecording: false,
            recordingState: VideoRecorderState.idle,
          ),
        );
        await _cameraService.setVolumeKeysEnabled(enabled: true);
        return;
      }

      emit(state.copyWith(countdownValue: 0));
      unawaited(HapticService.recordingFeedback());

      await _countdownSoundService!.playLongBeepAndWait();

      // Reopen the mic before the record call so the capture-session
      // restart does not delay the recording itself. A cancelled countdown
      // skips this; the next record tap reopens the mic on its own.
      await _cameraService.resumeAudioCapture();

      if (!_remoteRecordPausedForSound) {
        await _cameraService.setVolumeKeysEnabled(enabled: true);
      }
    }

    if (isClosed) {
      emit(state.copyWith(isStartingRecording: false));
      return;
    }

    if (state.recordingLockedForNavigation) {
      // Navigation released (or is releasing) the camera before the native
      // start ran — abort to idle instead of recording on a camera that is
      // about to be torn down.
      emit(
        state.copyWith(
          isStartingRecording: false,
          pendingStopAfterStart: false,
          recordingState: VideoRecorderState.idle,
        ),
      );
      return;
    }

    await _prepareSoundForPlayback();

    emit(state.copyWith(recordingState: VideoRecorderState.recording));

    Log.info(
      '🎥 Starting recording - aspect ratio: ${state.aspectRatio.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );

    unawaited(_playSoundPlayback());
    final success = await _cameraService.startRecording(
      maxDuration: state.recorderMode.hasRecordingLimit
          ? remainingDuration
          : null,
    );

    if (state.recordingLockedForNavigation) {
      // The camera was released for navigation while the native start was in
      // flight. Don't latch a recording the user can never stop.
      await _abortInFlightStartForLock(emit, sessionStarted: success);
      return;
    }

    if (success) {
      Log.info(
        '✅ Recording truly started',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      _onRecordingStarted?.call(state.recorderMode);
      await WakelockPlus.enable();
      if (state.recordingLockedForNavigation) {
        // Navigation locked during the wakelock-enable await, after the native
        // session started. Abort with the same teardown as the in-flight guard
        // above rather than arm a clip manager (60fps timer + stopwatch) that
        // nothing can stop.
        await _abortInFlightStartForLock(emit, sessionStarted: true);
        return;
      }
      clipManager.startRecording();
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

  Future<void> _onRecordingStopRequested(
    VideoRecorderRecordingStopRequested event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (state.isStoppingRecording) {
      return;
    }

    if (state.isStartingRecording) {
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

    Log.info(
      '⏹️  Stopping recording and processing clip...',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(isStoppingRecording: true));

    unawaited(HapticService.recordingFeedback());

    final EditorVideo? videoResult;
    final ClipManagerNotifier clipManager;
    final Duration remainingDuration;
    try {
      await _stopSoundPlayback();
      videoResult = event.result ?? await _cameraService.stopRecording();
      // Best-effort: a wakelock teardown failure must not abort the stop and
      // discard an already-captured clip (videoResult is assigned above), so
      // it is swallowed rather than thrown into the recovery catch.
      await _disableWakelockSafely();
      clipManager = _readClipManager()..stopRecording();
      remainingDuration = clipManager.remainingDuration;
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
      Log.error(
        '⚠️ Failed to stop recording cleanly - resetting recorder state',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      addError(e, stackTrace);
      // stopRecording() cancels the periodic 60fps duration timer and stops
      // the stopwatch (resetRecording alone would leave that timer running).
      _readClipManager()
        ..stopRecording()
        ..resetRecording();
      await _disableWakelockSafely();
      emit(
        state.copyWith(
          recordingState: VideoRecorderState.idle,
          isStoppingRecording: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        recordingState: VideoRecorderState.idle,
        isStoppingRecording: false,
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
      clipManager.resetRecording();
      return;
    }

    final clip = clipManager.addClip(
      video: videoResult,
      originalAspectRatio: _cameraService.cameraAspectRatio,
      targetAspectRatio: state.aspectRatio,
      lensMetadata: _cameraService.currentLensMetadata,
      limitClipDuration: state.recorderMode.hasRecordingLimit,
    );
    unawaited(
      clipManager.saveClipToLibrary(clip).then((saved) {
        if (!saved) {
          Log.warning(
            '⚠️ Initial clip save to library failed for ${clip.id}',
            name: 'VideoRecorderBloc',
            category: LogCategory.video,
          );
        }
      }),
    );

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
    // bare clip was already persisted by the unawaited save above.
    unawaited(
      _enrichAndSaveClip(
        videoResult: videoResult,
        clip: clip,
        clipManager: clipManager,
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
      }),
    );
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
    required Duration remainingDuration,
  }) async {
    final videoPath = await videoResult.safeFilePath();
    final workCopyPath = '$videoPath.work.mp4';
    await File(videoPath).copy(workCopyPath);

    try {
      final metadata = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(File(workCopyPath)),
      );
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

      if (thumbnailResult != null) {
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
  /// lock guards in [_onRecordingStartRequested] — before the native start and
  /// after the wakelock-enable await — so neither latches a recording the user
  /// can never stop.
  Future<void> _abortInFlightStartForLock(
    Emitter<VideoRecorderBlocState> emit, {
    required bool sessionStarted,
  }) async {
    if (sessionStarted) {
      await _discardAbortedRecording(await _cameraService.stopRecording());
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
    await _applyRecorderMode(
      emit,
      event.mode,
      keepAutosavedDraft: event.keepAutosavedDraft,
    );
  }

  Future<void> _applyRecorderMode(
    Emitter<VideoRecorderBlocState> emit,
    VideoRecorderMode mode, {
    required bool keepAutosavedDraft,
  }) async {
    // No assembling-status guard: the assemble is synchronous, so a mode switch
    // cannot land inside it, and the `ready` it leaves behind already carries an
    // empty frame list — so the discard below is a no-op and the queued library
    // write has nothing to lose.
    final previousMode = state.recorderMode;
    final previousFrames = state.stopMotionFrames;
    emit(
      state.copyWith(
        recorderMode: mode,
        aspectRatio: mode.defaultAspectRatio,
        showGridLines: _gridLinesEnabledFor(mode),
        timerDuration: mode.supportsCountdownTimer
            ? state.timerDuration
            : TimerDuration.off,
        countdownValue: 0,
        stopMotionFrames: const [],
        stopMotionStatus: StopMotionStatus.idle,
      ),
    );
    if (previousFrames.isNotEmpty) {
      unawaited(_stopMotionSessions.discardSession(previousFrames));
    }
    final prefs = _readSharedPreferences();
    await prefs.setString(VideoRecorderMode.persistenceKey, mode.name);

    final touchesRecordingState =
        mode != VideoRecorderMode.upload &&
        previousMode != VideoRecorderMode.upload;
    if (touchesRecordingState) {
      await _readClipManager().clearAll(
        keepAutosavedDraft: keepAutosavedDraft,
      );
      await _readVideoEditor().reset(
        keepAutosavedDraft: keepAutosavedDraft,
      );
    }

    Log.debug(
      '🎬 Recorder mode changed to: ${mode.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
  }

  void _onTimerCycled(
    VideoRecorderTimerCycled event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    if (!state.recorderMode.supportsCountdownTimer) return;

    final newTimer = switch (state.timerDuration) {
      TimerDuration.off => TimerDuration.three,
      TimerDuration.three => TimerDuration.ten,
      TimerDuration.ten => TimerDuration.off,
    };
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
    final frames = state.stopMotionFrames;
    emit(const VideoRecorderBlocState());
    if (frames.isNotEmpty) {
      unawaited(_stopMotionSessions.discardSession(frames));
    }
  }

  void _onShowLastClipOverlayToggled(
    VideoRecorderShowLastClipOverlayToggled event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    emit(state.copyWith(showLastClipOverlay: !state.showLastClipOverlay));
  }

  Future<void> _onGridLinesToggled(
    VideoRecorderGridLinesToggled event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final enabled = !state.showGridLines;
    emit(state.copyWith(showGridLines: enabled));
    await _readSharedPreferences().setBool(_kGridLinesEnabledKey, enabled);
  }

  /// Whether a grid-supporting [mode] should show the grid: the user's last
  /// persisted choice, defaulting to on.
  bool _gridLinesEnabledFor(VideoRecorderMode mode) =>
      mode.supportGridLines &&
      (_readSharedPreferences().getBool(_kGridLinesEnabledKey) ?? true);

  // === Stop-motion handlers ===

  /// Queues the library upsert of the session at [framePaths] with the
  /// recorder's current aspect ratio and lens.
  Future<void> _persistStopMotionSession(List<String> framePaths) =>
      _stopMotionSessions.persistSession(
        framePaths,
        aspectRatio: state.aspectRatio,
        lensMetadata: _cameraService.currentLensMetadata,
      );

  /// Captures one still, appends it to [state.stopMotionFrames], and persists
  /// the growing session to the library.
  ///
  /// No video is rendered here — encoding one video per tap is far too slow
  /// (seconds per frame). Frames are encoded into a single video only at
  /// publish. The session is upserted to the library on every frame (not just
  /// on the "Next"/assemble tap) so the recording is preserved the instant it
  /// is shot, even if the user backs out before assembling.
  Future<void> _onStopMotionFrameCaptured(
    VideoRecorderStopMotionFrameCaptured event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (!_cameraService.isInitialized || _cameraService.isSwitchingCamera) {
      return;
    }

    // An assemble hands the captured stills to the clip manager and clears
    // them; a still appended after that would be re-persisted as a phantom
    // one-frame session. `ready` (assemble done, navigation pending) is what
    // catches it — no assembling-status check, because the assemble is
    // synchronous, so it is never the current state while this runs. Dropping
    // the tap here also skips a native capture the after-await guard below
    // would only delete.
    if (state.stopMotionStatus == StopMotionStatus.ready) return;

    unawaited(HapticService.recordingFeedback());
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
      return;
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
      return;
    }

    // The recorder can move off this session across the await above. "Next"
    // stays tappable, so an assemble can claim it — synchronously, so `ready`
    // is what it leaves behind, never `assembling`; the mode wheel stays live
    // during an idle capture, so a swipe can discard it (_applyRecorderMode
    // clears the frames and leaves stop-motion, status idle). Either way the
    // session this still belonged to is gone, so appending it now would
    // re-persist a phantom one-frame session — on the new mode, for a swipe —
    // so it is dropped with its file. Only idle (still shooting) and failure
    // (assemble bailed, stills retained) while still in stop-motion own the
    // session here.
    if (!state.recorderMode.capturesStills ||
        state.stopMotionStatus == StopMotionStatus.ready) {
      unawaited(_stopMotionSessions.deleteFrameFile(photo.filePath));
      return;
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
  /// for (the library save is queued, see [_ingestStopMotionClip]), so no
  /// progress UI ever gets a frame to paint in.
  void _onStopMotionAssembleRequested(
    VideoRecorderStopMotionAssembleRequested event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
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

  /// Re-synchronizes the camera-derived fields in [state] with the
  /// current [CameraService] values. Matches the legacy
  /// `VideoRecorderNotifier.updateState` semantics: replaces sensor /
  /// capability fields wholesale and resets flash to `off`.
  void _emitCameraSync(
    Emitter<VideoRecorderBlocState> emit, {
    int? cameraRebuildCount,
    model.AspectRatio? aspectRatio,
  }) {
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
        canSwitchCamera: _cameraService.canSwitchCamera,
        isFrontCamera: _cameraService.currentLens.isFrontFacing,
        previewTextureId: _cameraService.textureId,
        videoStabilizationMode: _cameraService.videoStabilizationMode,
        availableVideoStabilizationModes:
            _cameraService.availableVideoStabilizationModes,
        isVideoStabilizationSupported:
            _cameraService.isVideoStabilizationSupported,
        showLastClipOverlay: state.showLastClipOverlay,
        recorderMode: state.recorderMode,
        showGridLines: state.showGridLines,
        // Preserve the in-progress stop-motion capture session: a camera-field
        // re-sync must not wipe already-captured frames, or the session would
        // split into several one-frame recordings (and lose frames on
        // assemble).
        stopMotionFrames: state.stopMotionFrames,
        stopMotionStatus: state.stopMotionStatus,
        stopMotionShutterTick: state.stopMotionShutterTick,
      ),
    );
  }

  void _onRemoteRecordTriggered(
    _VideoRecorderRemoteRecordTriggered event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    // The Upload tab shows no preview and pauses the camera, so a volume or
    // Bluetooth press there must not start a recording the user cannot see.
    if (state.recorderMode == VideoRecorderMode.upload) {
      Log.debug(
        '🎮 Remote record trigger ignored - Upload tab',
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
    add(VideoRecorderRecordingStopRequested(result: event.video));
  }

  // === Private helpers ===

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

      if (_remoteRecordPausedForSound) {
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

  /// The persisted stabilization mode, handed to the camera's initialize.
  ///
  /// The native controller is recreated (mode reset to off) on every init, so
  /// the saved preference travels with each one. The platform opens with off
  /// when the active lens does not support it.
  DivineVideoStabilizationMode _savedStabilizationMode(
    SharedPreferences prefs,
  ) {
    final saved = prefs.getString(_kLastUsedStabilizationModeKey);
    if (saved == null) return DivineVideoStabilizationMode.off;
    return DivineVideoStabilizationMode.fromNativeString(saved);
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
    Log.debug(
      '🧹 Closing VideoRecorderBloc',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    _focusPointTimer?.cancel();
    _focusPointTimer = null;
    _zoomIndicatorTimer?.cancel();
    _zoomIndicatorTimer = null;
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
    return super.close();
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
