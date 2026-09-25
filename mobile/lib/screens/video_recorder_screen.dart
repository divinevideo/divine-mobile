// ABOUTME: Video recorder screen with camera preview and recording controls.
// ABOUTME: Supports classic and capture modes; opened standalone or from the video editor.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/sound_waveform/sound_waveform_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/config/screenshot_mode.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/features/creation_analytics/creation_analytics_tracker.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/codec_heavy_surface_guard.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/widgets/camera_permission_gate.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_stop_motion_budget.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/lip_sync/video_recorder_lip_sync_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/upload/video_recorder_upload_stack.dart';
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
  static const quickAction = 'quick_action';
  static const postPublish = 'post_publish';
  static const editor = 'editor';

  static String fromName(String? value) => switch (value) {
    direct ||
    bottomNav ||
    cameraFab ||
    library ||
    videoReply ||
    quickAction ||
    postPublish ||
    editor => value!,
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
  });

  final String entryPoint;

  /// See [VideoRecorderView.autoRecord].
  final bool autoRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _VideoRecorderBlocScope(
      child: CameraPermissionGate(
        child: VideoRecorderView(
          entryPoint: entryPoint,
          autoRecord: autoRecord,
        ),
      ),
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
  });

  /// Whether the screen is opened from the video editor.
  ///
  /// When `true`, the bottom bar is hidden and navigation uses `context.pop`
  /// instead of the standard recorder close flow.
  final bool fromEditor;

  final String entryPoint;

  /// Route name for this screen.
  static const routeName = 'video-recorder';

  /// Path for this route.
  static const String path = RoutePaths.videoRecorder;

  /// Query parameter that opens the recorder in capture mode and starts
  /// recording as soon as the camera is ready — the bottom-nav hold shortcut.
  /// See [VideoRecorderView.autoRecord].
  static const autoRecordQueryParameter = 'auto_record';

  static String pathForEntryPoint(
    String entryPoint, {
    bool autoRecord = false,
  }) => Uri(
    path: path,
    queryParameters: {
      'entry_point': entryPoint,
      if (autoRecord) autoRecordQueryParameter: 'true',
    },
  ).toString();

  /// Whether a recorder location asks for [autoRecordQueryParameter].
  static bool autoRecordFromQueryParameters(
    Map<String, String> queryParameters,
  ) => queryParameters[autoRecordQueryParameter] == 'true';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _VideoRecorderBlocScope(
      child: VideoRecorderView(fromEditor: fromEditor, entryPoint: entryPoint),
    );
  }
}

class _VideoRecorderBlocScope extends ConsumerWidget {
  const _VideoRecorderBlocScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clipManager = ref.watch(clipManagerProvider.notifier);
    final videoEditor = ref.watch(videoEditorProvider.notifier);
    final sharedPreferences = ref.watch(sharedPreferencesProvider);
    final creationAnalyticsTracker = ref.watch(
      creationAnalyticsTrackerProvider,
    );

    return BlocProvider<VideoRecorderBloc>(
      key: ValueKey((
        clipManager,
        videoEditor,
        sharedPreferences,
        creationAnalyticsTracker,
      )),
      create: (_) => VideoRecorderBloc(
        readClipManager: () => ref.read(clipManagerProvider.notifier),
        readVideoEditor: () => ref.read(videoEditorProvider.notifier),
        readVideoEditorState: () => ref.read(videoEditorProvider),
        readSharedPreferences: () => ref.read(sharedPreferencesProvider),
        performanceMonitor: ref.read(performanceMonitoringServiceProvider),
        onRecordingStarted: (mode) =>
            unawaited(creationAnalyticsTracker.recordingStarted(mode)),
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
  });

  /// Whether the screen is opened from the video editor.
  final bool fromEditor;

  final String entryPoint;

  /// Opens in capture mode and starts recording as soon as the camera is
  /// ready — the bottom-nav hold-to-record shortcut.
  ///
  /// The auto-start is skipped when the open would first show a prompt (the
  /// first-run "why six seconds?" sheet or an autosaved-session offer): the
  /// user is answering a sheet, not holding a shutter, and a recording that
  /// starts underneath it would be a surprise. The camera still opens in
  /// capture mode.
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
        tracker.activeMode ??
        (widget.fromEditor
            ? initialBlocMode
            : _requestedRecorderMode ?? _lastUsedRecorderMode);
    unawaited(
      tracker.cameraOpened(mode: openingMode, entryPoint: widget.entryPoint),
    );

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _pauseBackgroundPlayback();
      final autoStartRecording =
          widget.autoRecord && await _opensStraightToPreview();
      if (!mounted) return;
      _initializeCamera(
        recorderMode: _requestedRecorderMode,
        autoStartRecording: autoStartRecording,
      );
      await _maybeShowWhySixSeconds();
      if (!mounted) return;
      _checkAutosavedChanges();
    });
    Log.info('📹 Initialized', name: 'VideoRecorderScreen', category: .video);
  }

  /// The mode the open asks the bloc for, or `null` to restore the
  /// last-used one. The hold-to-record shortcut always opens in capture mode.
  VideoRecorderMode? get _requestedRecorderMode =>
      widget.autoRecord ? VideoRecorderMode.capture : null;

  /// The persisted last-used mode, which a plain open restores.
  VideoRecorderMode get _lastUsedRecorderMode => VideoRecorderMode.fromName(
    ref
        .read(sharedPreferencesProvider)
        .getString(VideoRecorderMode.persistenceKey),
  );

  /// Whether the open reaches the live preview with no prompt in between —
  /// see [VideoRecorderView.autoRecord].
  Future<bool> _opensStraightToPreview() async {
    if (_isWhySixSecondsPending) return false;
    return await findOfferableAutosavedDraft(ref) == null;
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
    await VineBottomSheetPrompt.show(
      context: context,
      sticker: .grandfather,
      title: context.l10n.videoRecorderWhySixSecondsTitle,
      subtitle: context.l10n.videoRecorderWhySixSecondsSubtitle,
      secondaryButtonText: context.l10n.videoRecorderWhySixSecondsButton,
      onSecondaryPressed: navigator.pop,
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
      ),
    );
  }

  Future<void> _checkAutosavedChanges() =>
      offerAutosavedSession(context, ref, openEditorOnRestore: true);

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
    // The Upload tab keeps the camera paused; coming back to the app must not
    // restart it behind the static explainer.
    if (state == AppLifecycleState.resumed &&
        bloc.state.recorderMode == VideoRecorderMode.upload) {
      return;
    }
    bloc.add(VideoRecorderAppLifecycleChanged(state));
  }

  @override
  void dispose() {
    if (!widget.fromEditor) {
      unawaited(_creationAnalyticsTracker.creationAbandoned());
    }
    _releaseBackgroundPlaybackAfterDispose();
    _soundSubscription?.close();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();

    Log.info('📹 Disposed', name: 'VideoRecorderScreen', category: .video);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SoundWaveformBloc>(
      // Eager: the create factory installs the selected-sound listener that
      // drives waveform extraction. The only consumer (the lip-sync audio
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
          ref
              .read(creationAnalyticsTrackerProvider)
              .modeChanged(state.recorderMode);
          if (state.recorderMode == VideoRecorderMode.upload) {
            context.read<VideoRecorderBloc>().add(
              const VideoRecorderAppLifecycleChanged(AppLifecycleState.paused),
            );
          } else if (previous == VideoRecorderMode.upload) {
            if (state.isCameraInitialized) {
              context.read<VideoRecorderBloc>().add(
                const VideoRecorderAppLifecycleChanged(
                  AppLifecycleState.resumed,
                ),
              );
            } else {
              _initializeCamera();
            }
          }
        },
        child: PopScope(
          onPopInvokedWithResult: (didPop, value) {
            if (didPop && !widget.fromEditor) {
              discardRecorderSession(ref);
            }
          },
          child: _ScreenFlashTheme(
            child: _VideoRecorderScaffold(fromEditor: widget.fromEditor),
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
  const _VideoRecorderScaffold({required this.fromEditor});

  final bool fromEditor;

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
                  // which capture mode leaves empty, with the session's
                  // remaining-shots budget.
                  .stopMotion => VideoRecorderCaptureStack(
                    fromEditor: fromEditor,
                    topBarCenter: const VideoRecorderStopMotionBudget(),
                  ),
                  .lipSync => const VideoRecorderLipSyncStack(),
                  .classic => const VideoRecorderClassicStack(),
                },
              ),
            ),

            if (!fromEditor)
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
