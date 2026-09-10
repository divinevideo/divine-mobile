// ABOUTME: Full-screen crop / rotate / flip editor for a single video clip.
// ABOUTME: Hosts pro_image_editor's CropRotateEditor.video and returns the
// resulting ExportTransform to the caller.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/utils/pro_editor_theme.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/transform/transform_editor_chrome.dart';
import 'package:openvine/widgets/video_editor/transform/transform_editor_configs.dart';
// Hide `VideoClip`: divine_video_player defines the player's clip type, which
// is the one this screen drives.
import 'package:pro_image_editor/pro_image_editor.dart' hide VideoClip;
import 'package:pro_video_editor/pro_video_editor.dart'
    show ExportTransform, ProVideoEditor;
import 'package:unified_logger/unified_logger.dart';

/// Opens [clip] in a video-based [CropRotateEditor] and pops the route with
/// the resulting [ExportTransform] when the user confirms, or `null` when they
/// cancel or make no change.
class VideoClipTransformScreen extends StatefulWidget {
  const VideoClipTransformScreen({
    required this.clip,
    this.initAspectRatio,
    super.key,
  });

  final DivineVideoClip clip;

  /// Crop ratio the editor opens locked to, defaulting to the composition's
  /// output ratio.
  ///
  /// Pass [freeCropAspectRatio] for a clip that is not bound to the
  /// composition — a detached clip sits on the canvas as its own object, so
  /// cropping it to a different shape is a valid thing to want.
  final double? initAspectRatio;

  @override
  State<VideoClipTransformScreen> createState() =>
      _VideoClipTransformScreenState();
}

class _VideoClipTransformScreenState extends State<VideoClipTransformScreen> {
  DivineVideoPlayerController? _playerController;
  ProVideoController? _videoController;
  StreamSubscription<DivineVideoPlayerState>? _playerSubscription;

  /// Captured from [onCompleteWithParameters] before the close callback pops.
  ExportTransform? _result;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final path = widget.clip.requireVideo.file?.path;
    if (path == null) {
      Log.warning(
        '⚠️ Transform preview skipped: clip ${widget.clip.id} has no file',
        name: 'VideoClipTransformScreen',
        category: LogCategory.video,
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }

    try {
      final metadata = await ProVideoEditor.instance.getMetadata(
        widget.clip.requireVideo,
      );

      final player = DivineVideoPlayerController(
        useTexture: true,
        debugLabel: 'editor_transform',
      );
      await player.initialize();
      await player.setSource(
        VideoClip(
          uri: path,
          start: widget.clip.trimStart,
          end: widget.clip.duration - widget.clip.trimEnd,
          volume: widget.clip.volume,
          playbackSpeed: widget.clip.playbackSpeed ?? 1.0,
        ),
      );
      await player.setLooping(looping: true);

      final videoController =
          ProVideoController(
            videoPlayer: DivineVideoPlayer(controller: player),
            videoDuration: widget.clip.trimmedDuration,
            fileSize: 0,
            initialResolution: metadata.resolution,
          )..initialize(
            callbacksAudioFunction: () => const AudioEditorCallbacks(),
            callbacksFunction: () => VideoEditorCallbacks(
              onPlay: player.play,
              onPause: player.pause,
              onMuteToggle: (isMuted) =>
                  player.setVolume(isMuted ? 0 : widget.clip.volume),
            ),
            configsFunction: () => const VideoEditorConfigs(),
          );

      _playerSubscription = player.stateStream.listen((state) {
        videoController
          ..setPlayTime(state.position)
          ..isPlayingNotifier.value = state.isPlaying;
      });

      if (!mounted) {
        await player.dispose();
        videoController.dispose();
        return;
      }

      setState(() {
        _playerController = player;
        _videoController = videoController;
      });
    } catch (e, stackTrace) {
      Log.error(
        '❌ Failed to set up clip transform preview: $e',
        name: 'VideoClipTransformScreen',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      if (mounted) {
        // The route closes without a result (treated as a cancel); surface a
        // snackbar so the failed open isn't silent to the user.
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorTransformFailed,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  /// Maps the editor's [CompleteParameters] into an [ExportTransform] in the
  /// clip's pixel space, or `null` when the user made no spatial change.
  ExportTransform? _toExportTransform(CompleteParameters params) {
    if (!params.isTransformed) return null;
    return ExportTransform(
      x: params.cropX,
      y: params.cropY,
      width: params.cropWidth,
      height: params.cropHeight,
      rotateTurns: params.rotateTurns,
      flipX: params.flipX,
      flipY: params.flipY,
    );
  }

  void _close() {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.of(context).pop(_result);
  }

  @override
  void dispose() {
    unawaited(_playerSubscription?.cancel());
    _videoController?.dispose();
    unawaited(_playerController?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoController = _videoController;
    final playerController = _playerController;
    if (videoController == null || playerController == null) {
      return ColoredBox(
        color: context.vineColors.surfaceContainerHigh,
        child: const Center(child: BrandedLoadingIndicator(size: 48)),
      );
    }

    return CropRotateEditor.video(
      videoController,
      initConfigs: CropRotateEditorInitConfigs(
        theme: proEditorTheme(context),
        // Required so the editor builds the resolution-sized background that
        // gives the crop area its dimensions and renders the live video.
        convertToUint8List: true,
        configs: transformEditorConfigs(
          context,
          initAspectRatio:
              widget.initAspectRatio ?? widget.clip.targetAspectRatio.value,
          bottomBarLeading: _PlayPauseAction(controller: playerController),
          // No overlay: nothing is rasterized here. Done only reads the crop
          // parameters back out and hands the render to the bloc, which puts
          // its own progress UI over the timeline.
        ),
        callbacks: ProImageEditorCallbacks(
          onCompleteWithParameters: (params) async {
            _result = _toExportTransform(params);
          },
          // Fires for both Done (after parameters are captured) and Cancel
          // (with no captured result) — the single pop site for the route.
          onCloseEditor: (_) => _close(),
        ),
      ),
    );
  }
}

/// Play/pause toggle driven directly by the [DivineVideoPlayerController];
/// the icon and label reflect the live playback state.
class _PlayPauseAction extends StatelessWidget {
  const _PlayPauseAction({required this.controller});

  final DivineVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DivineVideoPlayerState>(
      stream: controller.stateStream,
      initialData: controller.state,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data?.isPlaying ?? false;
        return TransformEditorAction(
          icon: isPlaying ? .pause : .play,
          label: isPlaying
              ? context.l10n.videoEditorTransformPauseLabel
              : context.l10n.videoEditorTransformPlayLabel,
          onPressed: () => isPlaying ? controller.pause() : controller.play(),
        );
      },
    );
  }
}
