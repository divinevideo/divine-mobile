// ABOUTME: Video recorder screen with camera preview and recording controls.
// ABOUTME: Supports classic and capture modes; opened standalone or from the video editor.

import 'dart:async';

import 'package:divine_camera/divine_camera.dart' show DivineCamera;
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/sound_waveform/sound_waveform_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/collab_room/view/collab_room_flow_scopes.dart';
import 'package:openvine/config/screenshot_mode.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/features/creation_analytics/creation_analytics_tracker.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/codec_heavy_surface_guard.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/router/challenge_recording_gate.dart';
import 'package:openvine/router/recorder_sound_selection.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/mounted_post_frame.dart';
import 'package:openvine/widgets/camera_permission_gate.dart';
import 'package:openvine/widgets/screen_frame_trace_scope.dart';
import 'package:openvine/widgets/video_clip/clip_crop_guide.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_shader.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_stop_motion_budget.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/together/video_recorder_together_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/upload/video_recorder_upload_stack.dart';
import 'package:openvine/widgets/video_recorder/remote_record_pause.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_library_button.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_navigation.dart';
import 'package:unified_logger/unified_logger.dart';

const _kWhySixSecondsShownKey = 'why_six_seconds_shown';

abstract final class CreationEntryPoint {
  static const direct = 'direct';
  static const bottomNav = 'bottom_nav';
  static const cameraFab = 'camera_fab';
  static const library = 'library';
  static const videoReply = 'video_reply';
  static const addYours = 'add_yours';
  static const quickAction = 'quick_action';
  static const postPublish = 'post_publish';
  static const editor = 'editor';
  static const collabRoom = 'collab_room';

  static String fromName(String? value) => switch (value) {
    direct ||
    bottomNav ||
    cameraFab ||
    library ||
    videoReply ||
    addYours ||
    quickAction ||
    postPublish ||
    editor ||
    collabRoom => value!,
    _ => direct,
  };
}

/// Route shell for the standalone recorder flow.
///
/// The permission gate renders recorder chrome while permissions are pending,
/// so the [VideoRecorderBloc] must sit above both the gate and recorder view.
class VideoRecorderRoute extends ConsumerWidget {
  const VideoRecorderRoute({
    super.key,
    this.entryPoint = CreationEntryPoint.direct,
    this.autoRecord = false,
    this.initialSound,
    this.challengeRecordingId,
    this.fromEditor = false,
    this.cropGuideAspectRatio,
    this.cropGuideShape = SplitScreenCellShape.rectangle,
    this.analyticsSession,
    this.collabRoomId,
  });

  final String entryPoint;

  final RecorderSoundSelection? initialSound;
  final String? challengeRecordingId;

  /// Uses the return-to-caller controls for a library reaction capture.
  final bool fromEditor;
  final double? cropGuideAspectRatio;

  /// The shape inside [cropGuideAspectRatio] the take is cut to.
  final SplitScreenCellShape cropGuideShape;
  final CreationAnalyticsSession? analyticsSession;

  /// The collaborative room whose part this recorder films, or `null`.
  ///
  /// The part's cell comes from [collabRoomPartProvider], which the room sets
  /// before it opens the camera. Without it — a restored or hand-typed
  /// location — the recorder opens as usual.
  final String? collabRoomId;

  /// See [VideoRecorderView.autoRecord].
  final bool autoRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final part = ref.watch(collabRoomPartProvider);
    final collabPart = part != null && part.roomId == collabRoomId
        ? part
        : null;
    Widget view = VideoRecorderView(
      entryPoint: entryPoint,
      autoRecord: autoRecord,
      fromEditor: fromEditor,
      analyticsSession: analyticsSession,
      collabPart: collabPart != null,
    );
    if (collabPart != null) {
      view = ClipCropGuide(
        aspectRatio: collabPart.cellAspectRatio,
        shape: collabPart.cellShape,
        child: view,
      );
    } else if (cropGuideAspectRatio case final ratio?) {
      view = ClipCropGuide(
        aspectRatio: ratio,
        shape: cropGuideShape,
        child: view,
      );
    }
    Widget recorder = _VideoRecorderBlocScope(
      analyticsSession: analyticsSession,
      isLibraryReaction:
          analyticsSession != null && entryPoint == CreationEntryPoint.library,
      child: CameraPermissionGate(child: view),
    );
    // Wrapped as long as the part has its cell, finished or not, so ending
    // the flow does not rebuild the recorder that is still animating out.
    if (collabPart != null) {
      recorder = CollabRoomPartFlowScope(part: collabPart, child: recorder);
    }
    final recordingId = challengeRecordingId;
    {
      recorder = ChallengeRecordingGate(
        key: ValueKey(recordingId ?? 'unrelated-recording'),
        prepare: () async {
          if (recordingId == null) {
            ref.read(videoEditorProvider.notifier).clearChallengeContext();
            return;
          }
          final session = await ref.read(challengeAppSessionProvider.future);
          final context = await session?.recording(recordingId);
          if (!ref.context.mounted || context == null) {
            throw StateError('Challenge recording unavailable');
          }
          await session!.store.checkLive();
          if (!ref.context.mounted) throw StateError('Recorder closed');
          ref
              .read(videoEditorProvider.notifier)
              .attachChallengeContext(context);
        },
        child: recorder,
      );
    }
    final selection = initialSound;
    if (selection != null) {
      recorder = RecorderSoundSelectionGate(
        selection: selection,
        apply: (value) {
          if (ref.read(authServiceProvider).currentPublicKeyHex !=
              value.ownerPubkey) {
            throw StateError('Recorder sound account changed');
          }
          ref
              .read(videoEditorProvider.notifier)
              .selectRecorderAudioTrack(value.sound);
        },
        child: recorder,
      );
    }
    return ScreenFrameTraceScope(
      screen: .recorder,
      child: recorder,
    );
  }
}

/// Video recorder screen with camera preview and recording controls.
///
/// Owns the [VideoRecorderBloc]: it bridges the sibling Riverpod
/// dependencies the bloc reads (clip manager, video editor, shared
/// preferences) and re-keys the [BlocProvider] on their identity so a
/// runtime dependency swap rebuilds the bloc with fresh wiring (see
/// `state_management.md`).
class VideoRecorderScreen extends ConsumerWidget {
  /// Creates a video recorder screen.
  const VideoRecorderScreen({
    super.key,
    this.fromEditor = false,
    this.entryPoint = CreationEntryPoint.direct,
    this.cropGuideAspectRatio,
    this.cropGuideShape = SplitScreenCellShape.rectangle,
  });

  /// Whether the screen is opened from the video editor.
  ///
  /// When `true`, the bottom bar is hidden and navigation uses `context.pop`
  /// instead of the standard recorder close flow.
  final bool fromEditor;

  final String entryPoint;

  /// The shape the take will be cropped to, drawn over the viewfinder — a
  /// split-screen cell's, when the editor records straight into one. `null`
  /// shows the whole frame.
  final double? cropGuideAspectRatio;

  /// The shape inside [cropGuideAspectRatio] the take is cut to, such as the
  /// circle of a round window.
  final SplitScreenCellShape cropGuideShape;

  /// Route name for this screen.
  static const routeName = 'video-recorder';

  /// Path for this route.
  static const String path = RoutePaths.videoRecorder;

  /// Query parameter that opens the recorder in capture mode and starts
  /// recording as soon as the camera is ready — the bottom-nav hold shortcut.
  /// See [VideoRecorderView.autoRecord].
  static const autoRecordQueryParameter = 'auto_record';

  /// Query parameter carrying the [CreationEntryPoint] the recorder was
  /// opened from.
  static const entryPointQueryParameter = 'entry_point';

  /// Query parameter carrying the id of the challenge a take is recorded for.
  static const challengeRecordingQueryParameter = 'challenge_recording';

  /// Query parameter carrying the id of the collaborative room whose part is
  /// filmed.
  static const collabRoomQueryParameter = 'collab_room';

  static String pathForEntryPoint(
    String entryPoint, {
    bool autoRecord = false,
  }) => Uri(
    path: path,
    queryParameters: {
      entryPointQueryParameter: entryPoint,
      if (autoRecord) autoRecordQueryParameter: 'true',
    },
  ).toString();

  /// Whether a recorder location asks for [autoRecordQueryParameter].
  static bool autoRecordFromQueryParameters(
    Map<String, String> queryParameters,
  ) => queryParameters[autoRecordQueryParameter] == 'true';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final part = fromEditor ? ref.watch(collabRoomPartProvider) : null;
    final collabPart = part?.isActive ?? false;
    final view = ScreenFrameTraceScope(
      screen: .recorder,
      child: VideoRecorderView(
        fromEditor: fromEditor,
        entryPoint: entryPoint,
        collabPart: collabPart,
      ),
    );
    return _VideoRecorderBlocScope(
      child: switch (cropGuideAspectRatio) {
        final aspectRatio? => ClipCropGuide(
          aspectRatio: aspectRatio,
          shape: cropGuideShape,
          child: view,
        ),
        null when collabPart => ClipCropGuide(
          aspectRatio: part!.cellAspectRatio,
          shape: part.cellShape,
          child: view,
        ),
        null => view,
      },
    );
  }
}

class _VideoRecorderBlocScope extends ConsumerWidget {
  const _VideoRecorderBlocScope({
    required this.child,
    this.analyticsSession,
    this.isLibraryReaction = false,
  });

  final Widget child;
  final CreationAnalyticsSession? analyticsSession;
  final bool isLibraryReaction;

  ReactionRecordingOwner _captureReactionOwner(ProviderContainer container) {
    final manager = container.read(clipManagerProvider.notifier);
    final generation = manager.sessionGeneration;
    final authService = container.read(authServiceProvider);
    final pubkey = authService.currentPublicKeyHex;
    final library = container.read(clipLibraryServiceProvider);
    final drafts = container.read(draftStorageServiceProvider);

    Future<void> retain(DivineVideoClip clip) async {
      try {
        await library.retainClip(clip);
      } catch (error, stackTrace) {
        Log.warning(
          'Could not keep a reaction recording in the Library',
          name: 'VideoRecorderScreen',
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
        await drafts.saveDraft(
          DivineVideoDraft.create(
            clips: [clip],
            title: '',
            description: '',
            hashtags: const {},
            selectedApproach: 'video',
          ),
        );
      }
    }

    return (
      clipManager: manager,
      isCurrent: () =>
          manager.isSessionCurrent(generation) &&
          authService.currentPublicKeyHex == pubkey,
      retain: retain,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clipManager = ref.watch(clipManagerProvider.notifier);
    final videoEditor = ref.watch(videoEditorProvider.notifier);
    final sharedPreferences = ref.watch(sharedPreferencesProvider);
    final creationAnalyticsTracker = ref.watch(
      creationAnalyticsTrackerProvider,
    );
    // The bloc finishes events still in flight after this widget unmounts,
    // when its ref throws. The providers are app-scoped, so the readers go
    // through the container instead.
    final container = ProviderScope.containerOf(context, listen: false);

    return BlocProvider<VideoRecorderBloc>(
      key: ValueKey((
        clipManager,
        videoEditor,
        sharedPreferences,
        creationAnalyticsTracker,
        analyticsSession,
      )),
      create: (_) => VideoRecorderBloc(
        readClipManager: () => container.read(clipManagerProvider.notifier),
        reactionRecordingOwner: isLibraryReaction
            ? _captureReactionOwner(container)
            : null,
        readVideoEditor: () => container.read(videoEditorProvider.notifier),
        readVideoEditorState: () => container.read(videoEditorProvider),
        readSharedPreferences: () => container.read(sharedPreferencesProvider),
        performanceMonitor: container.read(
          performanceMonitoringServiceProvider,
        ),
        onRecordingStarted: (mode) => unawaited(
          creationAnalyticsTracker.recordingStarted(
            mode,
            session: analyticsSession,
          ),
        ),
        // Only iOS has a remote that mirrors the recorder: the Apple Watch.
        publishRemoteRecorderState:
            !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
            ? DivineCamera.instance.updateRemoteRecorderState
            : null,
        liveChromaKeySupported: ChromaKeyShader.isBackendSupported,
      ),
      child: child,
    );
  }
}

/// The recorder UI under the [BlocProvider]. Public for widget tests, which
/// pump it directly with a mock [VideoRecorderBloc].
@visibleForTesting
class VideoRecorderView extends ConsumerStatefulWidget {
  const VideoRecorderView({
    super.key,
    this.fromEditor = false,
    this.entryPoint = CreationEntryPoint.direct,
    this.autoRecord = false,
    this.analyticsSession,
    this.collabPart = false,
  });

  /// Whether the screen is opened from the video editor.
  final bool fromEditor;

  final String entryPoint;
  final CreationAnalyticsSession? analyticsSession;

  /// Whether the recorder films someone's part of a collaborative room: no
  /// mode wheel, no autosaved session offered back, and the part capped at
  /// the post length.
  final bool collabPart;

  /// Opens in capture mode and starts recording as soon as the camera is
  /// ready — the bottom-nav hold-to-record shortcut.
  ///
  /// The auto-start is skipped when the open would first show a prompt (the
  /// first-run "why six seconds?" sheet or an autosaved-session offer): the
  /// user is answering a sheet, not holding a shutter, and a recording that
  /// starts underneath it would be a surprise. It is also skipped when the
  /// autosave lookup fails, because the open cannot tell whether an offer
  /// will follow. The camera still opens in capture mode.
  final bool autoRecord;

  @override
  ConsumerState<VideoRecorderView> createState() => _VideoRecorderViewState();
}

class _VideoRecorderViewState extends ConsumerState<VideoRecorderView>
    with WidgetsBindingObserver, CodecHeavySurfaceGuard {
  ProviderSubscription<AudioEvent?>? _soundSubscription;
  OverlayVisibility? _overlayVisibilityNotifier;
  late final CreationAnalyticsTracker _creationAnalyticsTracker;
  VideoRecorderMode? _lastRecorderMode;
  final Object _overlayVisibilityOwner = Object();
  bool _overlayVisibilityPageOpenAsserted = false;
  bool? _reactionExitResult;

  bool get _isLibraryReaction =>
      widget.analyticsSession != null &&
      widget.entryPoint == CreationEntryPoint.library;

  bool _reactionTakeInFlight(VideoRecorderBlocState state) =>
      _isLibraryReaction && state.hasRecordingInFlight;

  void _onRecorderPop(bool didPop, Object? result) {
    if (didPop) {
      // A room part never autosaves, so the autosave slot holds the user's
      // own unfinished work, whatever the editor's flag says: keep it.
      if (!widget.fromEditor) {
        discardRecorderSession(ref, keepAutosavedDraft: widget.collabPart);
      }
      return;
    }
    if (!_isLibraryReaction || _reactionExitResult != null) return;
    final recorder = context.read<VideoRecorderBloc>();
    if (!_reactionTakeInFlight(recorder.state)) return;
    // The Library takes ownership when the camera route returns. Let native
    // Stop hand over the file before returning, even if Back starts the stop.
    _reactionExitResult = result == true;
    if (!recorder.state.isStoppingRecording) {
      recorder.addIfOpen(const VideoRecorderRecordingStopRequested());
    }
  }

  void _leaveAfterReactionTake(BuildContext context, VideoRecorderBlocState _) {
    final result = _reactionExitResult;
    _reactionExitResult = null;
    if (result == null || ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(context).pop(result);
  }

  @override
  void initState() {
    super.initState();

    final initialBlocMode = context
        .read<VideoRecorderBloc>()
        .state
        .recorderMode;
    _lastRecorderMode = initialBlocMode;
    final tracker = ref.read(creationAnalyticsTrackerProvider);
    _creationAnalyticsTracker = tracker;
    final openingMode =
        tracker.activeRecorderMode(
          widget.analyticsSession,
          continuesEditorSession: widget.fromEditor,
        ) ??
        (widget.fromEditor
            ? initialBlocMode
            : _requestedRecorderMode ?? _lastUsedRecorderMode);
    unawaited(
      tracker.cameraOpened(
        mode: openingMode,
        entryPoint: widget.entryPoint,
        session: widget.analyticsSession,
        continuesEditorSession: widget.fromEditor,
      ),
    );

    WidgetsBinding.instance.addObserver(this);
    // The scheduler drops a frame callback's returned future, so runDetached
    // owns the open's failures instead of the app's last-resort zone handler.
    addPostFrameCallbackIfMounted(
      () => runDetached(
        _openRecorder(),
        "run the recorder's first-frame work",
        logName: 'VideoRecorderScreen',
        category: .video,
      ),
    );
    Log.info('📹 Initialized', name: 'VideoRecorderScreen', category: .video);
  }

  /// The open's first-frame work: pause feed playback, initialize the camera,
  /// then show the one-time prompt and offer an autosaved session back.
  Future<void> _openRecorder() async {
    _pauseBackgroundPlayback();
    final autoStartRecording =
        widget.autoRecord && await _opensStraightToPreview();
    if (!mounted) return;
    _initializeCamera(
      recorderMode: _requestedRecorderMode,
      autoStartRecording: autoStartRecording,
    );
    // Capture's sound chip opens the sound picker, and the editor offers it
    // next.
    AudioSelectionBottomSheet.preload(ref);
    await _maybeShowWhySixSeconds();
    // An auto-recording open already found nothing to offer, a Library
    // reaction has already retained the previous session, and a room part is
    // a session of its own.
    if (!mounted ||
        autoStartRecording ||
        _isLibraryReaction ||
        widget.collabPart) {
      return;
    }
    await offerAutosavedSession(context, ref, openEditorOnRestore: true);
  }

  /// The mode the open asks the bloc for, or `null` to restore the
  /// last-used one. The hold-to-record shortcut always opens in capture mode.
  VideoRecorderMode? get _requestedRecorderMode =>
      widget.autoRecord || widget.collabPart ? VideoRecorderMode.capture : null;

  /// The persisted last-used mode, which a plain open restores.
  VideoRecorderMode get _lastUsedRecorderMode => VideoRecorderMode.fromName(
    ref
        .read(sharedPreferencesProvider)
        .getString(VideoRecorderMode.persistenceKey),
  );

  /// Whether the open is known to reach the live preview with no prompt in
  /// between — see [VideoRecorderView.autoRecord].
  Future<bool> _opensStraightToPreview() async {
    if (_isWhySixSecondsPending) return false;
    try {
      return await findOfferableAutosavedDraft(ref) == null;
    } on Exception catch (error, stackTrace) {
      // Explicit invariant failures belong to the detached-work reporter,
      // just like programming errors that bypass this Exception fallback.
      if (error is ReportableError) rethrow;
      // An unreadable autosave cannot rule out the offer, so open the camera
      // without recording instead of not opening it at all.
      Log.warning(
        'Autosave lookup failed; opening without auto-record',
        name: 'VideoRecorderScreen',
        category: .video,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Whether the one-time "Why six seconds?" prompt is still due.
  bool get _isWhySixSecondsPending {
    // Screenshot capture must show a clean recorder, not the first-run
    // education sheet.
    if (ScreenshotMode.enabled) return false;
    final prefs = ref.read(sharedPreferencesProvider);
    return !(prefs.getBool(_kWhySixSecondsShownKey) ?? false);
  }

  /// Shows the "Why six seconds?" prompt only once per user.
  Future<void> _maybeShowWhySixSeconds() async {
    if (!_isWhySixSecondsPending) return;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kWhySixSecondsShownKey, true);
    if (!mounted) return;

    final navigator = Navigator.of(context);
    await showWithRemoteRecordPaused(
      context.read<VideoRecorderBloc>(),
      () => VineBottomSheetPrompt.show<void>(
        context: context,
        sticker: .videoClapBoard,
        title: context.l10n.videoRecorderWhySixSecondsTitle,
        subtitle: context.l10n.videoRecorderWhySixSecondsSubtitle,
        secondaryButtonText: context.l10n.videoRecorderWhySixSecondsButton,
        onSecondaryPressed: navigator.pop,
      ),
    );
  }

  /// Initialize camera.
  ///
  /// [recorderMode] and [autoStartRecording] belong to the open only; a
  /// re-initialization (leaving the Upload tab, returning from the editor)
  /// restores the last-used mode and never starts recording on its own.
  void _initializeCamera({
    VideoRecorderMode? recorderMode,
    bool autoStartRecording = false,
  }) {
    Log.info(
      '📹 _initializeCamera called (autoStartRecording: $autoStartRecording)',
      name: 'VideoRecorderScreen',
      category: LogCategory.video,
    );

    context.read<VideoRecorderBloc>().add(
      VideoRecorderInitializeRequested(
        fromEditor: widget.fromEditor,
        recorderMode: recorderMode,
        autoStartRecording: autoStartRecording,
        collabPart: widget.collabPart,
      ),
    );
  }

  /// Force all background video playback to pause while camera is open.
  void _pauseBackgroundPlayback() {
    if (_overlayVisibilityPageOpenAsserted) return;
    _overlayVisibilityNotifier = ref.read(overlayVisibilityProvider.notifier);
    _overlayVisibilityPageOpenAsserted = true;
    _overlayVisibilityNotifier!.setPageOpenForOwner(
      _overlayVisibilityOwner,
      isOpen: true,
    );
    Log.info(
      '⏸️ Paused background playback for camera',
      name: 'VideoRecorderScreen',
      category: .video,
    );
  }

  void _releaseBackgroundPlaybackAfterDispose() {
    final notifier = _overlayVisibilityNotifier;
    if (!_overlayVisibilityPageOpenAsserted || notifier == null) {
      return;
    }
    _overlayVisibilityPageOpenAsserted = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!notifier.isMounted) return;
      notifier.setPageOpenForOwner(_overlayVisibilityOwner, isOpen: false);
      Log.info(
        '▶️ Released camera background playback hold',
        name: 'VideoRecorderScreen',
        category: .video,
      );
    });
  }

  /// Listens to sound selection changes and extracts waveform data.
  void _setupSoundWaveformListener(SoundWaveformBloc bloc) {
    Log.info(
      '🎵 _setupSoundWaveformListener called',
      name: 'VideoRecorderScreen',
      category: LogCategory.video,
    );

    // Handle initial sound if already selected
    final initialSound = ref.read(videoEditorProvider).selectedSound;
    Log.info(
      '🎵 initialSound: ${initialSound?.id ?? 'null'}',
      name: 'VideoRecorderScreen',
      category: LogCategory.video,
    );
    _triggerWaveformExtraction(bloc, initialSound);

    // Listen for future changes using listenManual (works outside build phase)
    _soundSubscription = ref.listenManual<AudioEvent?>(
      videoEditorProvider.select((s) => s.selectedSound),
      (previous, next) {
        Log.info(
          '🎵 Sound changed: ${previous?.id ?? 'null'} → ${next?.id ?? 'null'}',
          name: 'VideoRecorderScreen',
          category: LogCategory.video,
        );
        _triggerWaveformExtraction(bloc, next);
      },
    );
  }

  /// Triggers waveform extraction for the given sound.
  void _triggerWaveformExtraction(SoundWaveformBloc bloc, AudioEvent? sound) {
    Log.info(
      '🎵 _triggerWaveformExtraction: ${sound?.id ?? 'null'}, '
      'isBundled: ${sound?.isBundled}, url: ${sound?.url}',
      name: 'VideoRecorderScreen',
      category: LogCategory.video,
    );

    if (sound == null) {
      bloc.add(const SoundWaveformClear());
      return;
    }

    final event = SoundWaveformExtract.forSound(sound);
    if (event != null) {
      bloc.add(event);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bloc = context.read<VideoRecorderBloc>();
    bloc.add(VideoRecorderAppLifecycleChanged(state));
  }

  @override
  void dispose() {
    if (!widget.fromEditor) {
      unawaited(
        _creationAnalyticsTracker.creationAbandoned(
          session: widget.analyticsSession,
        ),
      );
    }
    _releaseBackgroundPlaybackAfterDispose();
    _soundSubscription?.close();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();

    Log.info('📹 Disposed', name: 'VideoRecorderScreen', category: .video);
  }

  @override
  Widget build(BuildContext context) {
    final reactionTakeInFlight =
        _isLibraryReaction &&
        context.select(
          (VideoRecorderBloc bloc) => _reactionTakeInFlight(bloc.state),
        );
    // The Apple Watch mirrors the clip budget, and clips are also added,
    // deleted and restored without the recorder bloc changing state.
    ref.listen(
      clipManagerProvider.select(
        (clips) => (
          clips.totalDuration,
          clips.activeRecordingDuration == Duration.zero,
        ),
      ),
      (_, _) => context.read<VideoRecorderBloc>().addIfOpen(
        const VideoRecorderRemoteStateRefreshRequested(),
      ),
    );
    // A selected sound turns the remote off, and it can change without the
    // recorder bloc changing state.
    ref.listen(
      videoEditorProvider.select((editor) => editor.selectedSound != null),
      (_, _) => context.read<VideoRecorderBloc>().addIfOpen(
        const VideoRecorderRemoteStateRefreshRequested(),
      ),
    );
    return BlocProvider<SoundWaveformBloc>(
      // Eager: the create factory installs the selected-sound listener that
      // drives waveform extraction. The only consumer (capture's audio
      // progress bar) mounts during recording, but extraction must already be
      // running when the user picks a sound beforehand so the waveform is
      // ready by the time recording starts.
      lazy: false,
      create: (context) {
        final bloc = SoundWaveformBloc();
        _setupSoundWaveformListener(bloc);

        return bloc;
      },
      // Release the camera while the Upload tab's static explainer is showing,
      // and resume it when the user returns to a recording mode. Reuses the
      // recorder's existing pause/resume lifecycle plumbing so we don't burn
      // battery or trigger the OS recording indicator on a tab with no
      // preview. A camera that never came up is initialized instead.
      child: BlocListener<VideoRecorderBloc, VideoRecorderBlocState>(
        listenWhen: (previous, current) =>
            previous.recorderMode != current.recorderMode,
        listener: (context, state) {
          final previous = _lastRecorderMode;
          _lastRecorderMode = state.recorderMode;
          _creationAnalyticsTracker.modeChanged(
            state.recorderMode,
            session: widget.analyticsSession,
          );
          if (!state.recorderMode.recordsVideo) {
            context.read<VideoRecorderBloc>().add(
              const VideoRecorderAppLifecycleChanged(
                AppLifecycleState.paused,
                isTabTransition: true,
              ),
            );
          } else if (previous != null && !previous.recordsVideo) {
            if (state.isCameraInitialized) {
              context.read<VideoRecorderBloc>().add(
                const VideoRecorderAppLifecycleChanged(
                  AppLifecycleState.resumed,
                  isTabTransition: true,
                ),
              );
            } else {
              _initializeCamera();
            }
          }
        },
        child: BlocListener<VideoRecorderBloc, VideoRecorderBlocState>(
          listenWhen: (previous, current) =>
              _reactionTakeInFlight(previous) &&
              !_reactionTakeInFlight(current),
          listener: _leaveAfterReactionTake,
          child: PopScope<Object?>(
            canPop: !reactionTakeInFlight,
            onPopInvokedWithResult: _onRecorderPop,
            child: _ScreenFlashTheme(
              child: _VideoRecorderScaffold(
                fromEditor: widget.fromEditor,
                lockedMode: widget.fromEditor || widget.collabPart,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lights the area around the camera preview while the front-camera screen
/// flash is on.
///
/// The native camera maxes out the display brightness for the screen flash,
/// but the recorder chrome around the preview stays dark and lights little.
/// While the flash is on, the recorder takes the light theme with a pure white
/// background, so that area glows and the controls on it stay readable.
class _ScreenFlashTheme extends StatelessWidget {
  const _ScreenFlashTheme({required this.child});

  final Widget child;

  /// Built once, so a rebuild hands [Theme] the identical instance instead of
  /// one that needs a deep `ThemeData` comparison.
  static final ThemeData _flashTheme = VineTheme.lightTheme.copyWith(
    extensions: [
      VineTheme.lightColors.copyWith(surfaceContainerHigh: VineTheme.whiteText),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final isScreenFlashActive = context.select(
      (VideoRecorderBloc b) => b.state.isScreenFlashActive,
    );
    // Always wrapped, so turning the flash on or off never remounts the
    // camera preview underneath.
    return Theme(
      data: isScreenFlashActive ? _flashTheme : Theme.of(context),
      child: child,
    );
  }
}

class _VideoRecorderScaffold extends StatelessWidget {
  const _VideoRecorderScaffold({
    required this.fromEditor,
    required this.lockedMode,
  });

  final bool fromEditor;

  /// Whether the mode wheel is hidden: the editor's camera and a room part
  /// record in one mode only.
  final bool lockedMode;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: VideoEditorConstants.uiOverlayStyleFor(context.vineColors),
      child: Scaffold(
        backgroundColor: context.vineColors.surfaceContainerHigh,
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: switch (context.select(
                  (VideoRecorderBloc b) => b.state.recorderMode,
                )) {
                  .upload => const VideoRecorderUploadStack(),
                  .capture => VideoRecorderCaptureStack(fromEditor: fromEditor),
                  // Stop-motion reuses the capture stack — each shutter
                  // tap adds a still to the session, which joins the
                  // clip list as one frames-based clip, so the capture
                  // flow (clips, library, editor, ghost) applies
                  // unchanged. It only fills the top bar's center slot,
                  // where capture mode shows its sound chip, with the
                  // session's remaining-shots budget.
                  .stopMotion => VideoRecorderCaptureStack(
                    fromEditor: fromEditor,
                    topBarCenter: const VideoRecorderStopMotionBudget(),
                  ),
                  .classic => const VideoRecorderClassicStack(),
                  .together => const VideoRecorderTogetherStack(),
                },
              ),
            ),

            if (!lockedMode)
              const Padding(
                padding: .symmetric(vertical: 22),
                child: VideoRecorderBottomBar(),
              )
            else
              // Editor-hosted recorder: no mode wheel and no library
              // navigation, but the library button still renders as a
              // read-only capture counter (last still + count badge).
              const Padding(
                padding: .symmetric(vertical: 22),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      VideoRecorderLibraryButton(interactive: false),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
