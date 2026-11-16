import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';
import 'package:openvine/widgets/video_editor/video_editor_processing_overlay.dart';
import 'package:unified_logger/unified_logger.dart';

class VideoMetadataClassicPreviewThumbnail extends ConsumerStatefulWidget {
  const VideoMetadataClassicPreviewThumbnail({super.key});

  @override
  ConsumerState<VideoMetadataClassicPreviewThumbnail> createState() =>
      _VideoMetadataClassicPreviewThumbnailState();
}

class _VideoMetadataClassicPreviewThumbnailState
    extends ConsumerState<VideoMetadataClassicPreviewThumbnail> {
  static const double _iconSize = 32;
  static const _hideDelay = Duration(seconds: 1);

  DivineVideoPlayerController? _controller;
  bool _isPlayerReady = false;
  bool _isPlaying = false;
  Timer? _hideTimer;
  final _iconVisible = ValueNotifier<bool>(false);

  /// Id of the finished video the preview follows, kept even when its player
  /// failed to load.
  String? _playerClipId;

  /// Bumped whenever the finished video changes or the widget goes away, so a
  /// load it superseded disposes its player instead of showing it.
  int _loadGeneration = 0;

  /// How many players were released for a discarded video. Keys the thumbnail
  /// that replaces each one: a release can land while the previous thumbnail
  /// is still fading out under that player. With a shared key the
  /// [AnimatedSwitcher] drops that thumbnail and fades the new one in from
  /// transparent, so the preview blinks instead of staying covered.
  int _releasedPlayers = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      videoEditorProvider.select((s) => s.finalRenderedClip),
      (_, clip) => _followFinishedVideo(clip),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _loadGeneration++;
    _hideTimer?.cancel();
    _iconVisible.dispose();
    final controller = _controller;
    if (controller != null) {
      runDetached(
        controller.dispose(),
        'dispose classic metadata preview player',
        logName: 'VideoMetadataClassicPreviewThumbnail',
        category: LogCategory.video,
      );
    }
    super.dispose();
  }

  /// Plays the finished video, and only that one.
  ///
  /// An edit that changes after the export, most often a take's proof landing,
  /// discards the finished video and renders again at once. Its player is
  /// released right away: on a device with few hardware codecs the looping
  /// decoder leaves that render no encoder, and it fails on every retry.
  ///
  /// Keyed on the clip's id, new for every render, so a cover picked on the
  /// same video does not reload it.
  void _followFinishedVideo(DivineVideoClip? clip) {
    if (clip?.id == _playerClipId) return;
    _playerClipId = clip?.id;
    final generation = ++_loadGeneration;

    final previous = _controller;
    if (previous != null) {
      _hideTimer?.cancel();
      setState(() {
        _controller = null;
        _isPlayerReady = false;
        _isPlaying = false;
        _releasedPlayers++;
      });
      _iconVisible.value = false;
      runDetached(
        previous.dispose(),
        'release the preview of a discarded video',
        logName: 'VideoMetadataClassicPreviewThumbnail',
        category: LogCategory.video,
      );
    }

    if (clip == null) return;
    runDetached(
      _loadPlayer(clip, generation),
      'load classic metadata preview',
      logName: 'VideoMetadataClassicPreviewThumbnail',
      category: LogCategory.video,
    );
  }

  bool _isCurrentLoad(int generation) =>
      mounted && generation == _loadGeneration;

  Future<void> _loadPlayer(DivineVideoClip clip, int generation) async {
    final path = await clip.requireVideo.safeFilePath();
    if (!_isCurrentLoad(generation)) return;
    await _initPlayer(path, generation);
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null) return;
    if (_isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    // The video was discarded meanwhile and its player released.
    if (!mounted || !identical(controller, _controller)) return;
    setState(() => _isPlaying = !_isPlaying);

    _hideTimer?.cancel();
    if (_isPlaying) {
      _iconVisible.value = true;
      _hideTimer = Timer(_hideDelay, () {
        if (mounted) _iconVisible.value = false;
      });
    } else {
      _iconVisible.value = true;
    }
  }

  Future<void> _initPlayer(String filePath, int generation) async {
    final controller = DivineVideoPlayerController(
      useTexture: true,
      debugLabel: 'metadata_classic_thumbnail',
    );
    try {
      await controller.initialize();
      if (!_isCurrentLoad(generation)) {
        await controller.dispose();
        return;
      }
      await controller.setSource(
        VideoClip.file(
          filePath,
          // Match the loop boundary used when the same file reaches the feed.
          trimToCommonTrackEnd: true,
        ),
      );
      if (!_isCurrentLoad(generation)) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(looping: true);
      if (!_isCurrentLoad(generation)) {
        await controller.dispose();
        return;
      }
      await controller.play();
      if (!_isCurrentLoad(generation)) {
        await controller.dispose();
        return;
      }
    } catch (e, stackTrace) {
      Log.error(
        'Classic metadata preview player failed to load',
        name: 'VideoMetadataClassicPreviewThumbnail',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      runDetached(
        controller.dispose(),
        'dispose failed classic metadata preview player',
        logName: 'VideoMetadataClassicPreviewThumbnail',
        category: LogCategory.video,
      );
      return;
    }

    setState(() {
      _controller = controller;
      _isPlayerReady = true;
      _isPlaying = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final clips = ref.watch(clipManagerProvider).clips;
    if (clips.isEmpty) return const SizedBox.shrink();
    final clip = clips.first;

    final (finalRenderedClip, isProcessing, renderFailed) = ref.watch(
      videoEditorProvider.select(
        (s) => (s.finalRenderedClip, s.isProcessing, s.renderFailed),
      ),
    );

    return AspectRatio(
      aspectRatio: 1,
      child: clip.thumbnailPath == null
          ? Center(
              child: DivineIcon(
                icon: .warning,
                size: 32,
                color: context.vineColors.mutedText,
              ),
            )
          : Stack(
              alignment: .center,
              fit: .expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _isPlayerReady && _controller != null
                      ? DivineVideoPlayer(
                          // One key per player: the players of two renders
                          // must never share one in the cross-fade.
                          key: ObjectKey(_controller),
                          controller: _controller,
                        )
                      : Stack(
                          key: ValueKey(('thumbnail', _releasedPlayers)),
                          fit: StackFit.expand,
                          children: [
                            ClipThumbnailImage(
                              path: clip.thumbnailPath!,
                              fit: .cover,
                            ),
                            VideoEditorProcessingOverlay(
                              clip: clip,
                              isProcessing:
                                  finalRenderedClip == null && isProcessing,
                              hasFailed: renderFailed,
                              onRetry: () => ref
                                  .read(videoEditorProvider.notifier)
                                  .startRenderVideo(),
                            ),
                          ],
                        ),
                ),
                if (_isPlayerReady && _controller != null)
                  Semantics(
                    identifier: 'preview_play_pause_button',
                    label: _isPlaying
                        ? context.l10n.videoMetadataPausePreviewSemanticLabel
                        : context.l10n.videoMetadataPlayPreviewSemanticLabel,
                    button: true,
                    child: GestureDetector(
                      onTap: _togglePlayPause,
                      behavior: HitTestBehavior.translucent,
                      child: Center(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _iconVisible,
                          builder: (_, visible, child) => AnimatedOpacity(
                            opacity: visible ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: child,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: VineTheme.scrim65,
                              borderRadius: .circular(24),
                            ),
                            padding: const .all(16),
                            child: DivineIcon(
                              icon: _isPlaying ? .pauseFill : .playFill,
                              size: _iconSize,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // A re-sign over an already-rendered clip (retryC2paSigning)
                // keeps the looping player up, so overlay a progress indicator
                // on top of it — otherwise classic mode looks idle while
                // capture mode shows a spinner (#6058).
                if (finalRenderedClip != null && isProcessing)
                  VideoEditorProcessingOverlay(
                    clip: clip,
                    isProcessing: true,
                  ),
              ],
            ),
    );
  }
}
