import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
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

  @override
  void initState() {
    super.initState();
    // Start playback once the rendered clip becomes available.
    ref.listenManual(videoEditorProvider.select((s) => s.finalRenderedClip), (
      _,
      clip,
    ) {
      if (clip != null && _controller == null) {
        clip.requireVideo.safeFilePath().then((path) {
          if (mounted) _initPlayer(path);
        });
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _iconVisible.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_controller == null) return;
    if (_isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
    if (!mounted) return;
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

  Future<void> _initPlayer(String filePath) async {
    // Avoid re-initializing for the same source.
    if (_controller != null) return;

    final controller = DivineVideoPlayerController(
      useTexture: true,
      debugLabel: 'metadata_classic_thumbnail',
    );
    try {
      await controller.initialize();
      if (!mounted) {
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
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(looping: true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.play();
    } catch (e, stackTrace) {
      Log.error(
        'Classic metadata preview player failed to load',
        name: 'VideoMetadataClassicPreviewThumbnail',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      unawaited(controller.dispose());
      return;
    }
    if (!mounted) return;

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
                          key: const ValueKey('player'),
                          controller: _controller,
                        )
                      : Stack(
                          key: const ValueKey('thumbnail'),
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
