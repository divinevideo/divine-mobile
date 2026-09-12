// ABOUTME: Video recorder screen with camera preview and recording controls.
// ABOUTME: Supports classic and capture modes; opened standalone or from the video editor.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
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
  });

  final String entryPoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _VideoRecorderBlocScope(
      child: CameraPermissionGate(
        child: VideoRecorderView(entryPoint: entryPoint),
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

  static String pathForEntryPoint(String entryPoint) =>
      Uri(path: path, queryParameters: {'entry_point': entryPoint}).toString();

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
        onRecordingStarted: (mode) => unawaited(
          creationAnalyticsTracker.recordingStarted(mode),
        ),
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
  });

  /// Whether the screen is opened from the video editor.
  final bool fromEditor;

  final String entryPoint;

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
            : VideoRecorderMode.fromName(
                ref
                    .read(sharedPreferencesProvider)
                    .getString(VideoRecorderMode.persistenceKey),
              ));
    unawaited(
      tracker.cameraOpened(
        mode: openingMode,
        entryPoint: widget.entryPoint,
      ),
    );

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _pauseBackgroundPlayback();
      _initializeCamera();
      await _maybeShowWhySixSeconds();
      if (!mounted) return;
      _checkAutosavedChanges();
    });
    Log.info('📹 Initialized', name: 'VideoRecorderScreen', category: .video);
  }

  /// Shows the "Why six seconds?" prompt only once per user.
  Future<void> _maybeShowWhySixSeconds() async {
    // Screenshot capture must show a clean recorder, not the first-run
    // education sheet.
    if (ScreenshotMode.enabled) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kWhySixSecondsShownKey) ?? false) return;
    await prefs.setBool(_kWhySixSecondsShownKey, true);
    if (!mounted) return;

    await VineBottomSheetPrompt.show(
      context: context,
      sticker: .grandfather,
      title: context.l10n.videoRecorderWhySixSecondsTitle,
      subtitle: context.l10n.videoRecorderWhySixSecondsSubtitle,
      secondaryButtonText: context.l10n.videoRecorderWhySixSecondsButton,
      onSecondaryPressed: context.pop,
    );
  }

  /// Initialize camera and free background video resources.
  void _initializeCamera() {
    Log.info(
      '📹 _initializeCamera called',
      name: 'VideoRecorderScreen',
      category: LogCategory.video,
    );

    context.read<VideoRecorderBloc>().add(
      VideoRecorderInitializeRequested(fromEditor: widget.fromEditor),
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
    context.read<VideoRecorderBloc>().add(
      VideoRecorderAppLifecycleChanged(state),
    );
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
      // and re-initialize it when the user returns to a recording mode. Reuses
      // the recorder's existing pause/resume lifecycle plumbing so we don't
      // burn battery or trigger the OS recording indicator on a tab with no
      // preview.
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
            _initializeCamera();
          }
        },
        child: PopScope(
          onPopInvokedWithResult: (didPop, value) {
            if (didPop && !widget.fromEditor) {
              discardRecorderSession(ref);
            }
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                        .capture => VideoRecorderCaptureStack(
                          fromEditor: widget.fromEditor,
                        ),
                        // Stop-motion reuses the capture stack — each shutter
                        // tap captures a still that becomes a 1-frame video
                        // clip, so the capture flow (clips, library, editor,
                        // ghost) applies unchanged. It only fills the top
                        // bar's center slot, which capture mode leaves empty,
                        // with the session's remaining-shots budget.
                        .stopMotion => VideoRecorderCaptureStack(
                          fromEditor: widget.fromEditor,
                          topBarCenter: const VideoRecorderStopMotionBudget(),
                        ),
                        .lipSync => const VideoRecorderLipSyncStack(),
                        .classic => const VideoRecorderClassicStack(),
                      },
                    ),
                  ),

                  if (!widget.fromEditor)
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
          ),
        ),
      ),
    );
  }
}
