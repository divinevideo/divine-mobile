import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/feed/feed_mode_switch.dart';
import 'package:openvine/widgets/stop_motion/stop_motion_player.dart';
import 'package:openvine/widgets/video_feed_item/blurred_video_backdrop.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_metadata/metadata_hero_corners.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_preview_thumbnail.dart';
import 'package:unified_logger/unified_logger.dart';

/// Full-screen preview of the recorded video with metadata overlay.
///
/// Displays the video in a hero animation transition and shows
/// how the post will appear with the entered title, description, and tags.
class VideoMetadataPreviewScreen extends ConsumerStatefulWidget {
  /// Creates a video preview screen for the given clip.
  const VideoMetadataPreviewScreen({
    required this.clip,
    this.previewOnly = false,
    super.key,
  });

  /// The recording clip to preview.
  final DivineVideoClip clip;

  /// When `true`, hides the bottom bar and metadata overlay.
  ///
  /// Used when showing a read-only preview outside the editor flow
  /// (e.g. from the upload failure sheet).
  final bool previewOnly;

  @override
  ConsumerState<VideoMetadataPreviewScreen> createState() =>
      _VideoMetadataPreviewScreenState();
}

class _VideoMetadataPreviewScreenState
    extends ConsumerState<VideoMetadataPreviewScreen> {
  /// Video player controller for the clip, null until initialized.
  DivineVideoPlayerController? _controller;

  /// Whether the video player has completed initialization and is ready
  /// to play.
  final _isPreviewReady = ValueNotifier<bool>(false);

  /// The enclosing route's entrance animation, tracked so its status listener
  /// can be detached in [dispose].
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    // Start video playback
    unawaited(_initializePlayer());

    ref.listenManual(
      videoPublishProvider.select((state) => state.publishState),
      (previous, next) {
        if (previous != next && _controller?.state.isPlaying == true) {
          _controller?.pause();
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The overlay waits for the entrance transition so it does not appear
    // mid-hero. ModalRoute is unavailable in initState, and this callback can
    // run again for unrelated inherited-widget changes, so the listener is
    // attached exactly once per route.
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _routeAnimation = animation;

    // No enclosing route means no transition to wait for. A route can report
    // completed briefly before Navigator starts its entrance animation, so
    // mirror every later status instead of treating the first completed value
    // as irreversible readiness.
    if (animation == null) {
      _isPreviewReady.value = true;
      return;
    }
    animation.addStatusListener(_onRouteAnimationStatus);
    _onRouteAnimationStatus(animation.status);
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    _isPreviewReady.value = status == AnimationStatus.completed;
  }

  /// Initializes the video player and starts playback.
  ///
  /// Creates a [DivineVideoPlayerController], initializes it, enables
  /// looping, and starts playback automatically.
  Future<void> _initializePlayer() async {
    // Stop-motion clips play their frames via [StopMotionPlayer]; there is no
    // video to load into the native player.
    if (widget.clip.isStopMotion) return;

    final video = widget.clip.video;
    if (video == null) return;

    final controller = DivineVideoPlayerController(
      useTexture: true,
      debugLabel: 'metadata_preview',
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setSource(
        VideoClip.file(
          await video.safeFilePath(),
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
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      // Rebuild so DivineVideoPlayer receives the now-initialized controller.
      setState(() {});
    } catch (e, stackTrace) {
      Log.error(
        'Metadata preview player failed to load',
        name: 'VideoMetadataPreviewScreen',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      unawaited(controller.dispose());
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    unawaited(_controller?.dispose());
    _isPreviewReady.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stageBorderRadius = widget.previewOnly
        ? BorderRadius.zero
        : const BorderRadius.vertical(
            bottom: Radius.circular(VineTheme.shellCornerRadius),
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: VideoEditorConstants.uiOverlayStyleFor(context.vineColors),
      child: Scaffold(
        backgroundColor: context.vineColors.surfaceContainerHigh,
        body: Column(
          spacing: 16,
          children: [
            // Video preview area with close button
            Expanded(
              child: _PreviewStage(
                borderRadius: stageBorderRadius,
                child: Stack(
                  fit: .expand,
                  children: [
                    _VideoPreviewContent(
                      clip: widget.clip,
                      controller: _controller,
                      stageBorderRadius: stageBorderRadius,
                    ),
                    if (!widget.previewOnly)
                      // The overlay offsets its caption and action column
                      // above the system bottom inset for the feed, where it
                      // spans the whole screen. Here the stage already ends
                      // above the post bar's [SafeArea], so that inset would
                      // be counted twice and float the buttons off the bottom
                      // edge. Same removal the fullscreen feed applies around
                      // its own [FeedVideos].
                      MediaQuery.removePadding(
                        context: context,
                        removeBottom: true,
                        child: _PreviewOverlay(isPreviewReady: _isPreviewReady),
                      ),
                    const _CloseButton(),
                  ],
                ),
              ),
            ),
            // Post button at bottom
            if (!widget.previewOnly)
              const SafeArea(
                top: false,
                child: VideoMetadataCaptureBottomBar(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Rounds the bottom corners of the preview area so it seams into the post
/// bar the way the feed seams into the bottom nav
/// ([VineTheme.shellCornerRadius], via `NavRoundedShell`). The corners reveal
/// the scaffold surface the post bar sits on, so no extra fill is painted
/// behind them.
///
/// The preview-only route has no bottom chrome to seam into and stays edge to
/// edge — the same branch the fullscreen feed takes in `_MaybeRoundFeedBottom`.
class _PreviewStage extends StatelessWidget {
  const _PreviewStage({required this.borderRadius, required this.child});

  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (borderRadius == BorderRadius.zero) return child;
    return ClipRRect(borderRadius: borderRadius, child: child);
  }
}

/// Container widget that wraps the video player in a hero transition.
///
/// Frames the clip to match the feed: non-square clips fill the preview edge to
/// edge and crop like `VideoItemWidget`'s cover branch, square clips stay
/// contain-fit on the blurred poster backdrop the feed paints in their
/// letterbox bars. Without that mirroring the preview showed more of the frame
/// than the feed does, so the metadata overlay sat over a different crop than
/// the published post.
///
/// The video surface is sized from the live decoded ratio when the native
/// player has reported dimensions, with [DivineVideoClip.targetAspectRatio] as
/// the pre-decode fallback. That keeps raw draft previews from squeezing an
/// uncropped source into the target-ratio box while still matching the rendered
/// post path once the render has baked the target crop into the file.
class _VideoPreviewContent extends StatelessWidget {
  /// Creates the video preview content wrapper.
  const _VideoPreviewContent({
    required this.clip,
    required this.controller,
    required this.stageBorderRadius,
  });

  final DivineVideoClip clip;
  final DivineVideoPlayerController? controller;

  /// Shape the stage rests at, which the hero flight morphs into.
  final BorderRadius stageBorderRadius;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = clip.targetAspectRatio.value;
    // The feed leaves portrait expansion on (FeedVideos defaults it to true
    // and no caller overrides it), so the preview mirrors that branch.
    final coversViewport = videoCoversFeedViewport(
      aspectRatio: aspectRatio,
      shouldPortraitExpand: true,
    );
    final fit = coversViewport ? BoxFit.cover : BoxFit.contain;
    final thumbnailPath = clip.thumbnailPath;
    final stopMotionFrames = clip.stopMotionFrames;

    // Hero animation from metadata screen
    return Hero(
      tag: VideoEditorConstants.heroMetaPreviewId,
      // Use linear flight path instead of curved arc
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      flightShuttleBuilder: (_, animation, _, _, toHeroContext) =>
          MetadataHeroCorners(
            animation: animation,
            destinationBorderRadius: stageBorderRadius,
            child: (toHeroContext.widget as Hero).child,
          ),
      child: Stack(
        fit: .expand,
        children: [
          if (!coversViewport && thumbnailPath != null)
            BlurredVideoBackdrop(
              filePath: thumbnailPath,
              videoAspectRatio: aspectRatio,
            ),
          if (stopMotionFrames != null)
            _FittedStopMotion(
              frames: stopMotionFrames,
              aspectRatio: aspectRatio,
              coversViewport: coversViewport,
            )
          else
            _FittedVideoSurface(
              clip: clip,
              controller: controller,
              aspectRatio: aspectRatio,
              fit: fit,
            ),
        ],
      ),
    );
  }
}

/// Inscribes the player surface into the preview the way the feed does.
///
/// The native surface has no intrinsic size and stretches to whatever box it
/// gets, so the video is laid out at the decoded video ratio inside a
/// [FittedBox] — the same construction `VideoItemWidget` uses in the feed.
class _FittedVideoSurface extends StatefulWidget {
  const _FittedVideoSurface({
    required this.clip,
    required this.controller,
    required this.aspectRatio,
    required this.fit,
  });

  final DivineVideoClip clip;
  final DivineVideoPlayerController? controller;
  final double aspectRatio;
  final BoxFit fit;

  @override
  State<_FittedVideoSurface> createState() => _FittedVideoSurfaceState();
}

class _FittedVideoSurfaceState extends State<_FittedVideoSurface> {
  StreamSubscription<DivineVideoPlayerState>? _sub;
  double _videoAspectRatio = 0;

  @override
  void initState() {
    super.initState();
    _subscribeToController(widget.controller);
  }

  @override
  void didUpdateWidget(_FittedVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      unawaited(_sub?.cancel());
      _subscribeToController(widget.controller);
    }
  }

  void _subscribeToController(DivineVideoPlayerController? controller) {
    _videoAspectRatio = controller?.state.aspectRatio ?? 0;
    _sub = controller?.stateStream.listen((state) {
      final aspectRatio = state.aspectRatio;
      if (aspectRatio > 0 && aspectRatio != _videoAspectRatio) {
        setState(() => _videoAspectRatio = aspectRatio);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoAspectRatio = _videoAspectRatio > 0
        ? _videoAspectRatio
        : widget.aspectRatio;
    return ClipRect(
      child: FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: videoAspectRatio * 100,
          height: 100,
          child: DivineVideoPlayer(
            controller: widget.controller,
            placeholder: VideoMetadataCapturePreviewThumbnail(
              clip: widget.clip,
            ),
          ),
        ),
      ),
    );
  }
}

/// Frames a stop-motion clip the way the feed and the export do.
///
/// Export center-crops the raw stills to the target box (`StopMotionFit.cover`
/// in `StopMotionRenderService`) and the feed then fits that already-cropped
/// mp4 per cover/contain. Reproduce both from the stills: [StopMotionPlayer]
/// cover-crops them, and for the letterboxed (square) case they are constrained
/// to the target-ratio box so the blurred backdrop fills the bars — instead of
/// contain-fitting the whole non-square still, which showed more frame than the
/// published post.
class _FittedStopMotion extends StatelessWidget {
  const _FittedStopMotion({
    required this.frames,
    required this.aspectRatio,
    required this.coversViewport,
  });

  final List<StopMotionClipFrame> frames;
  final double aspectRatio;
  final bool coversViewport;

  @override
  Widget build(BuildContext context) {
    // Default fit is BoxFit.cover — the centered crop the export bakes in.
    final player = StopMotionPlayer(
      frames: frames,
      cacheHeight:
          (MediaQuery.sizeOf(context).height *
                  MediaQuery.devicePixelRatioOf(context))
              .round(),
    );
    if (coversViewport) return player;
    return Center(
      child: AspectRatio(aspectRatio: aspectRatio, child: player),
    );
  }
}

/// Semi-transparent overlay showing how the video will appear with metadata.
class _PreviewOverlay extends ConsumerWidget {
  /// Creates a preview overlay.
  const _PreviewOverlay({required this.isPreviewReady});

  final ValueNotifier<bool> isPreviewReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current metadata from editor
    final metadata = ref.watch(
      videoEditorProvider.select(
        (s) => (title: s.title, description: s.description, tags: s.tags),
      ),
    );

    // Get user's public key for preview
    final publicKey = ref.watch(
      nostrServiceProvider.select((s) => s.publicKey),
    );

    // Non-interactive overlay with reduced opacity.
    // Lives in the outer full-screen Stack so it always renders at
    // phone-screen proportions, independent of the video's aspect ratio.
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: 0.5,
          child: Material(
            type: .transparency,
            child: ValueListenableBuilder(
              valueListenable: isPreviewReady,
              builder: (_, isActive, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    const FeedModeSwitch(isPreviewMode: true),
                    VideoOverlayActions.preview(
                      previewData: VideoOverlayPreviewData(
                        pubkey: publicKey,
                        title: metadata.title,
                        description: metadata.description,
                      ),
                      isVisible: true,
                      isActive: isActive,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Close button positioned at the top-left corner.
class _CloseButton extends StatelessWidget {
  /// Creates a close button.
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: 6,
      start: 16,
      child: SafeArea(
        child: Hero(
          tag: VideoEditorConstants.heroBackButtonId,
          child: DivineIconButton(
            icon: .x,
            type: .ghostOverMedia,
            size: .small,
            semanticLabel: context.l10n.videoMetadataClosePreviewSemanticLabel,
            onPressed: () => context.pop(),
          ),
        ),
      ),
    );
  }
}
