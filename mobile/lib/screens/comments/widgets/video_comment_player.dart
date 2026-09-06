// ABOUTME: Inline video attachment player for video comments.
// ABOUTME: Starts from thumbnail and plays the attached NIP-92 video in-place.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:visibility_detector/visibility_detector.dart';

class VideoCommentPlayer extends StatefulWidget {
  const VideoCommentPlayer({
    required this.videoUrl,
    this.thumbnailUrl,
    this.blurhash,
    this.borderRadius,
    this.onOpenVideo,
    super.key,
  });

  final String videoUrl;
  final String? thumbnailUrl;
  final String? blurhash;
  final BorderRadiusGeometry? borderRadius;
  final VoidCallback? onOpenVideo;

  @override
  State<VideoCommentPlayer> createState() => _VideoCommentPlayerState();
}

class _VideoCommentPlayerState extends State<VideoCommentPlayer>
    with WidgetsBindingObserver {
  DivineVideoPlayerController? _controller;
  // Cancelled in dispose through a local alias, so the field is nulled before
  // the async teardown.
  // ignore: cancel_subscriptions
  StreamSubscription<DivineVideoPlayerState>? _stateSubscription;
  bool _isInitializing = false;
  bool _isPlaying = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Null the fields before the async teardown so any late callback (e.g. a
    // final VisibilityDetector frame after unmount) can't reach the
    // now-disposing controller and drive an operation on it.
    final subscription = _stateSubscription;
    final controller = _controller;
    _stateSubscription = null;
    _controller = null;
    unawaited(subscription?.cancel());
    // divine_video_player tears down its native player safely on dispose and
    // suspends frame delivery when backgrounded, so no manual pause-before-
    // dispose dance is needed (unlike the old video_player/FVP pipeline).
    unawaited(controller?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop decoding when the app leaves the foreground; the native guard keeps
    // frame delivery safe, this just avoids burning battery on a hidden video.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _controller?.pause();
    }
  }

  Future<void> _togglePlay() async {
    if (_isInitializing) return;

    final existing = _controller;
    if (existing != null) {
      if (existing.state.isPlaying) {
        await existing.pause();
      } else {
        await existing.play();
      }
      return;
    }

    setState(() => _isInitializing = true);
    final controller = DivineVideoPlayerController(
      useTexture: true,
      debugLabel: 'comments',
    );
    try {
      await controller.initialize();
      await controller.setSource(VideoClip.network(widget.videoUrl));
      await controller.setLooping(looping: true);
      await controller.setVolume(_isMuted ? 0 : 1);
      // Backgrounding does not unmount an inline comment player, and the
      // lifecycle handler cannot pause a controller that isn't assigned yet.
      // If the app left the foreground while the awaits above ran, abort
      // instead of starting playback in the background.
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      final leftForeground =
          lifecycle == AppLifecycleState.paused ||
          lifecycle == AppLifecycleState.hidden;
      if (!mounted || leftForeground) {
        await controller.dispose();
        if (mounted) setState(() => _isInitializing = false);
        return;
      }
      _stateSubscription = controller.stateStream.listen(_onStateChanged);
      _controller = controller;
      await controller.play();
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isPlaying = true;
        });
      }
    } on Object catch (error) {
      Log.warning(
        'Failed to start comment video: $error',
        name: 'VideoCommentPlayer',
        category: LogCategory.video,
      );
      // Drop the references before tearing the controller down so a later tap
      // starts a fresh controller instead of calling into this disposed one
      // (which would throw StateError from the package's initialized/disposed
      // guard). Teardown is fire-and-forget so the retry affordance returns
      // immediately rather than waiting on the native player to release.
      final subscription = _stateSubscription;
      _stateSubscription = null;
      _controller = null;
      unawaited(subscription?.cancel());
      unawaited(controller.dispose());
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    final nextMuted = !_isMuted;
    await controller.setVolume(nextMuted ? 0 : 1);
    if (mounted) setState(() => _isMuted = nextMuted);
  }

  void _onStateChanged(DivineVideoPlayerState state) {
    if (!mounted) return;
    if (state.isPlaying != _isPlaying) {
      setState(() => _isPlaying = state.isPlaying);
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    // Gate on the optimistic _isPlaying flag, not controller.state.isPlaying:
    // play() does not flip state.isPlaying synchronously, so a visibility drop
    // right after the tap would otherwise skip the pause and keep decoding
    // offscreen until a playing event that never re-checks visibility.
    if (info.visibleFraction < 0.35 && _isPlaying) {
      _controller?.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _controller?.isInitialized ?? false;
    final player = VisibilityDetector(
      key: Key('video-comment-${widget.videoUrl}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.vineColors.containerLow),
          child: GestureDetector(
            onTap: _togglePlay,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DivineVideoPlayer(
                  controller: isReady ? _controller : null,
                  placeholder: _CommentVideoThumbnail(
                    thumbnailUrl: widget.thumbnailUrl,
                  ),
                ),
                if (_isInitializing)
                  Center(
                    child: SizedBox.square(
                      dimension: 28,
                      child: DivineCircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.vineColors.onSurface,
                      ),
                    ),
                  )
                else if (!_isPlaying)
                  const _PlayOverlay(),
                if (isReady)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _MuteButton(isMuted: _isMuted, onTap: _toggleMute),
                  ),
                if (widget.onOpenVideo != null)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _OpenVideoButton(onTap: widget.onOpenVideo!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final borderRadius = widget.borderRadius;
    if (borderRadius == null) {
      return player;
    }

    return ClipRRect(borderRadius: borderRadius, child: player);
  }
}

class _OpenVideoButton extends StatelessWidget {
  const _OpenVideoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DivineIconButton(
      icon: DivineIconName.arrowUpRight,
      semanticLabel: context.l10n.commentsOpenVideoLabel,
      size: DivineIconButtonSize.small,
      type: DivineIconButtonType.ghostOverMedia,
      onPressed: onTap,
    );
  }
}

class _PlayOverlay extends StatelessWidget {
  const _PlayOverlay();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.scrim50,
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: DivineIcon(
              icon: DivineIconName.play,
              color: VineTheme.primaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.isMuted, required this.onTap});

  final bool isMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DivineIconButton(
      icon: isMuted
          ? DivineIconName.speakerSimpleX
          : DivineIconName.speakerHigh,
      semanticLabel: isMuted
          ? context.l10n.commentsUnmuteVideoReplyLabel
          : context.l10n.commentsMuteVideoReplyLabel,
      size: DivineIconButtonSize.small,
      type: DivineIconButtonType.ghostOverMedia,
      onPressed: onTap,
    );
  }
}

class _CommentVideoThumbnail extends StatelessWidget {
  const _CommentVideoThumbnail({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final url = thumbnailUrl;
    if (url != null && url.isNotEmpty) {
      return VineCachedImage(
        imageUrl: url,
        errorWidget: (_, _, _) => const _VideoPlaceholder(),
      );
    }
    return const _VideoPlaceholder();
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.containerLow,
      child: Center(
        child: DivineIcon(
          icon: DivineIconName.videoCamera,
          color: context.vineColors.onSurfaceMuted,
          size: 32,
        ),
      ),
    );
  }
}
