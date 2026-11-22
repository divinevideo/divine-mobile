import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Diffused colour cloud derived from a video's own first frame,
/// stretched to cover the entire fullscreen area. Painted behind the
/// video in `_PooledFullscreenItemContent` so contain-fit videos
/// (1 × 1 / landscape) sit on it instead of a flat dark surface —
/// matches the Instagram / TikTok "blurred poster" look.
///
/// When the video carries a [blurhash], the backdrop renders the decoded
/// 32 × 32 blurhash bilinearly stretched — visually equivalent to a heavy
/// gaussian blur of the poster at zero per-frame raster cost. The
/// runtime-blur fallback ([ImageFiltered], sigma 30) only runs for videos
/// without a blurhash; that fullscreen blur pass over the live video
/// texture was a major raster-thread cost (on-device: Impeller janked
/// every frame), so the blurhash path is strongly preferred.
///
/// When [videoAspectRatio] is known, the backdrop paints only in the letterbox
/// bars — one `RepaintBoundary`-isolated fill per bar, from the screen edge up
/// to the video — instead of a single fullscreen layer behind the (opaque)
/// video. That occluded fullscreen fill, composited whole every frame, was the
/// backdrop's per-frame overdraw cost on Skia; the per-bar layers are cached
/// and never re-rastered by the video texture (PR #5957). When the aspect
/// ratio is unknown the backdrop falls back to a fullscreen fill.
class BlurredVideoBackdrop extends StatelessWidget {
  /// Creates a blurred backdrop for a video poster.
  ///
  /// [blurhash] is preferred when non-empty. [url] is the HTTPS poster
  /// thumbnail used for the runtime-blur fallback, [filePath] the local
  /// poster of a clip that has not been published yet (the pre-publish
  /// preview). When none is available, or the image fails to load, the
  /// widget renders as empty ([SizedBox.shrink]) and lets the parent
  /// background show through.
  const BlurredVideoBackdrop({
    super.key,
    this.url,
    this.filePath,
    this.blurhash,
    this.videoAspectRatio,
  });

  /// Largest decoded width or height for the blurred poster fallback. The
  /// heavy blur removes the detail a larger decode would carry, so this saves
  /// decode time and image memory with no visible difference. The blur's own
  /// raster cost scales with the widget, not the image.
  static const int maxBlurredPosterDecodePx = 96;

  final String? url;

  /// Absolute path of a local poster file, used when no [url] is available.
  final String? filePath;

  final String? blurhash;

  /// Intrinsic aspect ratio (width / height) of the video sitting on this
  /// backdrop. Drives the letterbox bar geometry. When null the backdrop
  /// paints fullscreen — the safe fallback when dimensions are unknown.
  final double? videoAspectRatio;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = videoAspectRatio;
    if (aspectRatio == null) {
      return _BackdropContent(
        url: url,
        filePath: filePath,
        blurhash: blurhash,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final bands = letterboxBands(
          letterboxVideoRect(aspectRatio, size),
          size,
        );
        return Stack(
          children: [
            for (final band in bands)
              Positioned.fromRect(
                rect: band,
                // Its own RepaintBoundary per bar: the bar's fill is isolated
                // from the video texture's per-frame markNeedsPaint, so it is
                // rastered once and then only composited — and it never covers
                // the video area, so there is no occluded fullscreen overdraw
                // (PR #5957).
                child: RepaintBoundary(
                  child: _BackdropContent(
                    url: url,
                    filePath: filePath,
                    blurhash: blurhash,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The blurred fill itself, without any letterbox clip. Prefers the cheap
/// stretched-blurhash path and falls back to a runtime gaussian of the poster.
class _BackdropContent extends StatelessWidget {
  const _BackdropContent({this.url, this.filePath, this.blurhash});

  final String? url;
  final String? filePath;
  final String? blurhash;

  @override
  Widget build(BuildContext context) {
    final hash = blurhash;
    if (hash != null && hash.isNotEmpty) {
      // Paint-level 50% alpha — no Opacity saveLayer, no blur pass.
      return BlurhashDisplay(blurhash: hash, opacity: 0.5);
    }
    final posterUrl = url;
    final posterPath = filePath;
    if (posterUrl != null && posterUrl.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final pixelRatio = MediaQuery.devicePixelRatioOf(context);
          final targetWidth =
              constraints.hasBoundedWidth && constraints.maxWidth > 0
              ? (constraints.maxWidth * pixelRatio).ceil().clamp(
                  1,
                  BlurredVideoBackdrop.maxBlurredPosterDecodePx,
                )
              : BlurredVideoBackdrop.maxBlurredPosterDecodePx;
          final targetHeight =
              constraints.hasBoundedHeight && constraints.maxHeight > 0
              ? (constraints.maxHeight * pixelRatio).ceil().clamp(
                  1,
                  BlurredVideoBackdrop.maxBlurredPosterDecodePx,
                )
              : BlurredVideoBackdrop.maxBlurredPosterDecodePx;
          return _blurredPoster(
            VineCachedImage(
              imageUrl: posterUrl,
              memCacheWidth: targetWidth,
              memCacheHeight: targetHeight,
              resizePolicy: ResizeImagePolicy.fit,
              // Fall back to nothing on error — the parent
              // [ColoredBox(VineTheme.surfaceContainerHigh)] shows through.
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          );
        },
      );
    }
    if (posterPath != null && posterPath.isNotEmpty) {
      return _blurredPoster(
        ClipThumbnailImage(
          path: posterPath,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          placeholder: const SizedBox.shrink(),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _blurredPoster(Widget poster) {
    return RepaintBoundary(
      child: ClipRect(
        // `ImageFiltered` applies the blur on the GPU side; `ClipRect`
        // keeps the bleeding edge of the blur kernel from leaking
        // outside the widget's box and over the surrounding chrome.
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Opacity(opacity: 0.5, child: poster),
        ),
      ),
    );
  }
}

/// The letterbox bars a blurred fill covers — the full gap between each box
/// edge and the contain-fit [video], so the blur runs from the screen edge
/// right up to the video with no dark band between. Only the sides where
/// [video] doesn't reach the [box] edge produce a bar. Top/bottom bars span the
/// full width (owning the corners); left/right bars span only the video's
/// height, so bars never overlap and never cover the video area. Each bar is
/// painted in its own `RepaintBoundary`, keeping it isolated from the video
/// texture's per-frame repaint. Exposed for testing the band tiling, which is
/// the seam-risk load-bearing logic.
@visibleForTesting
List<Rect> letterboxBands(Rect video, Size box) {
  final bands = <Rect>[];
  if (video.top > 0) {
    bands.add(Rect.fromLTWH(0, 0, box.width, video.top));
  }
  if (video.bottom < box.height) {
    bands.add(
      Rect.fromLTWH(0, video.bottom, box.width, box.height - video.bottom),
    );
  }
  if (video.left > 0) {
    bands.add(Rect.fromLTWH(0, video.top, video.left, video.height));
  }
  if (video.right < box.width) {
    bands.add(
      Rect.fromLTWH(
        video.right,
        video.top,
        box.width - video.right,
        video.height,
      ),
    );
  }
  return bands;
}

/// The rect a video of [aspectRatio] occupies when `BoxFit.contain`-fitted and
/// centered in [box] — mirrors the player's `FittedBox(fit: contain)`. Locates
/// the letterbox bars the blurred fill covers, and the frame a grid tile's
/// picture flies to when it opens the video.
Rect letterboxVideoRect(double aspectRatio, Size box) {
  final boxAspect = box.width / box.height;
  final double width;
  final double height;
  if (aspectRatio > boxAspect) {
    // Wider than the box → full width, letterbox top and bottom.
    width = box.width;
    height = box.width / aspectRatio;
  } else {
    // Taller/narrower than the box → full height, pillarbox left and right.
    height = box.height;
    width = box.height * aspectRatio;
  }
  return Rect.fromLTWH(
    (box.width - width) / 2,
    (box.height - height) / 2,
    width,
    height,
  );
}

/// The intrinsic aspect ratio (width / height) that drives the backdrop's
/// letterbox geometry, or null when the video's dimensions are unknown — in
/// which case the backdrop paints fullscreen, the safe fallback.
double? backdropAspectRatio(int? width, int? height) {
  if (width == null || height == null || height <= 0) return null;
  return width / height;
}

/// Whether a video of [aspectRatio] fully covers (occludes) the feed viewport,
/// so the backdrop must not be mounted at all. Mirrors the cover branch of
/// `VideoItemWidget._resolveBoxFit`: with [shouldPortraitExpand] every
/// non-square
/// video is `BoxFit.cover`-fitted and hides the backdrop, while square (1:1)
/// and non-expanded videos stay contain-fit and keep their letterbox bars.
bool videoCoversFeedViewport({
  required double? aspectRatio,
  required bool shouldPortraitExpand,
}) => shouldPortraitExpand && aspectRatio != null && aspectRatio != 1.0;

/// The aspect ratio the fullscreen feed letterboxes a [width] by [height]
/// video at, or null when the video fills the screen: it is cropped to cover
/// it, or its dimensions are unknown.
///
/// The fullscreen feed expands portrait videos, so only a square video is
/// letterboxed.
double? fullscreenFeedLetterboxAspectRatio(int? width, int? height) {
  final aspectRatio = backdropAspectRatio(width, height);
  final covers = videoCoversFeedViewport(
    aspectRatio: aspectRatio,
    shouldPortraitExpand: true,
  );
  return covers ? null : aspectRatio;
}
