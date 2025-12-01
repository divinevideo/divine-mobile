// ABOUTME: Smart video thumbnail widget that displays thumbnails or blurhash placeholders
// ABOUTME: Uses existing thumbnail URLs from video events and falls back to blurhash when missing

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/image_cache_manager.dart';
import 'package:openvine/services/thumbnail_api_service.dart'
    show ThumbnailSize;
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/video_icon_placeholder.dart';

/// Smart thumbnail widget that displays thumbnails with blurhash fallback
class VideoThumbnailWidget extends StatefulWidget {
  const VideoThumbnailWidget({
    required this.video,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.timeSeconds = 2.5,
    this.size = ThumbnailSize.medium,
    this.showPlayIcon = false,
    this.borderRadius,
  });
  final VideoEvent video;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double timeSeconds;
  final ThumbnailSize size;
  final bool showPlayIcon;
  final BorderRadius? borderRadius;

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  String? _thumbnailUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if video ID changed
    if (oldWidget.video.id != widget.video.id) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    // Check if we have an existing thumbnail URL
    if (widget.video.thumbnailUrl != null &&
        widget.video.thumbnailUrl!.isNotEmpty) {
      setState(() {
        _thumbnailUrl = widget.video.thumbnailUrl;
        _isLoading = false;
      });
      return;
    }

    // Check if video is hosted on api.openvine.co - only try API thumbnails for those
    final videoUrl = widget.video.videoUrl;
    final shouldTryApiThumbnail =
        videoUrl != null && videoUrl.contains('api.openvine.co');

    if (!shouldTryApiThumbnail) {
      // Video not hosted on api.openvine.co - don't try to generate thumbnail
      // Just show blurhash or placeholder
      if (mounted) {
        setState(() {
          _thumbnailUrl = null;
          _isLoading = false;
        });
      }
      return;
    }

    // Video is on api.openvine.co - try to get API thumbnail
    // Keep in loading state - show blurhash or loading indicator while generating
    setState(() {
      _isLoading = true;
    });

    try {
      final generatedThumbnailUrl = await widget.video.getApiThumbnailUrl();
      if (generatedThumbnailUrl != null && generatedThumbnailUrl.isNotEmpty) {
        if (mounted) {
          setState(() {
            _thumbnailUrl = generatedThumbnailUrl;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      // Silently fail - will use blurhash or placeholder
    }

    // No API thumbnail available - stop loading and show blurhash or placeholder
    if (mounted) {
      setState(() {
        _thumbnailUrl = null;
        _isLoading = false;
      });
    }
  }

  Widget _buildContent(BoxFit fit) {
    // While determining what thumbnail to use, show blurhash if available
    if (_isLoading && widget.video.blurhash != null) {
      return Stack(
        children: [
          BlurhashDisplay(
            blurhash: widget.video.blurhash!,
            width: widget.width,
            height: widget.height,
            fit: fit,
          ),
          if (widget.showPlayIcon)
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
        ],
      );
    }

    if (_isLoading) {
      return VideoIconPlaceholder(
        width: widget.width,
        height: widget.height,
        showLoading: true,
        showPlayIcon: widget.showPlayIcon,
        borderRadius: widget.borderRadius?.topLeft.x ?? 8.0,
      );
    }

    if (_thumbnailUrl != null) {
      // Show the thumbnail with blurhash as placeholder while loading
      return Stack(
        fit: StackFit.expand,
        children: [
          // Show blurhash as background while image loads
          if (widget.video.blurhash != null)
            BlurhashDisplay(
              blurhash: widget.video.blurhash!,
              width: widget.width,
              height: widget.height,
              fit: fit,
            ),
          // Actual thumbnail image with error boundary
          _SafeNetworkImage(
            url: _thumbnailUrl!,
            width: widget.width,
            height: widget.height,
            fit: fit,
            videoId: widget.video.id,
            blurhash: widget.video.blurhash,
            showPlayIcon: widget.showPlayIcon,
            borderRadius: widget.borderRadius,
          ),
          // Play icon overlay if requested
          if (widget.showPlayIcon)
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
        ],
      );
    }

    // No thumbnail URL - show blurhash if available, otherwise placeholder
    if (widget.video.blurhash != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          BlurhashDisplay(
            blurhash: widget.video.blurhash!,
            width: widget.width,
            height: widget.height,
            fit: fit,
          ),
          if (widget.showPlayIcon)
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
        ],
      );
    }

    // Avoid spinning video controllers for thumbnails; fall back to icon
    if (widget.video.videoUrl != null && widget.video.videoUrl!.isNotEmpty) {
      return VideoIconPlaceholder(
        width: widget.width,
        height: widget.height,
        showPlayIcon: widget.showPlayIcon,
        borderRadius: widget.borderRadius?.topLeft.x ?? 8.0,
      );
    }

    // Final fallback - icon placeholder
    return VideoIconPlaceholder(
      width: widget.width,
      height: widget.height,
      showPlayIcon: widget.showPlayIcon,
      borderRadius: widget.borderRadius?.topLeft.x ?? 8.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate aspect ratio from video dimensions if available, fallback to 1:1 square
    final double aspectRatio;
    if (widget.video.width != null &&
        widget.video.height != null &&
        widget.video.height! > 0) {
      aspectRatio = widget.video.width! / widget.video.height!;
    } else {
      // Fallback to square for videos without dimension metadata
      aspectRatio = 1.0;
    }

    // Match video player's BoxFit strategy to prevent visual jump:
    // - Portrait videos (aspectRatio < 0.9): Use BoxFit.cover to fill screen
    // - Square/Landscape videos (aspectRatio >= 0.9): Use BoxFit.contain to show full video
    final bool isPortrait = aspectRatio < 0.9;
    final BoxFit effectiveFit = isPortrait ? BoxFit.cover : BoxFit.contain;

    // Build content with the calculated fit
    var content = _buildContent(effectiveFit);

    if (widget.borderRadius != null) {
      content = ClipRRect(borderRadius: widget.borderRadius!, child: content);
    }

    return AspectRatio(aspectRatio: aspectRatio, child: content);
  }
}

/// Error-safe network image widget that prevents HTTP 404 and other network exceptions
/// Uses CachedNetworkImage which handles network errors more gracefully than Image.network
class _SafeNetworkImage extends StatelessWidget {
  const _SafeNetworkImage({
    required this.url,
    required this.videoId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.blurhash,
    this.showPlayIcon = false,
    this.borderRadius,
  });

  final String url;
  final String videoId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? blurhash;
  final bool showPlayIcon;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      alignment: Alignment.topCenter,
      cacheManager: openVineImageCache,
      placeholder: (context, url) => _buildFallback(),
      errorWidget: (context, url, error) {
        // Log the specific error for debugging
        Log.error(
          '❌ Network image failed: $url',
          name: 'VideoThumbnailWidget',
          category: LogCategory.video,
        );
        Log.error(
          '❌ Error type: ${error.runtimeType}, Details: $error',
          name: 'VideoThumbnailWidget',
          category: LogCategory.video,
        );

        // Log the full stack trace if available
        if (error is Exception) {
          try {
            final stackTrace = StackTrace.current;
            Log.error(
              '❌ Stack trace: $stackTrace',
              name: 'VideoThumbnailWidget',
              category: LogCategory.video,
            );
          } catch (e) {
            // Ignore stack trace errors
          }
        }

        // Check if this is specifically a 404 or HTTP error
        if (error.toString().contains('404') ||
            error.toString().contains('statusCode')) {
          Log.warning(
            '🖼️ HTTP error loading thumbnail for video $videoId (FULL ID), URL: $url',
            name: 'VideoThumbnailWidget',
            category: LogCategory.video,
          );
        }

        return _buildFallback();
      },
    );
  }

  Widget _buildFallback() {
    // Don't show blurhash here - it's already shown as background in the outer Stack
    // Just show a transparent container so the background blurhash is visible
    if (blurhash != null && blurhash!.isNotEmpty) {
      Log.debug(
        '🎨 Image failed, showing transparent container to reveal background blurhash',
        name: 'VideoThumbnailWidget',
        category: LogCategory.video,
      );
      return Container(width: width, height: height, color: Colors.transparent);
    }
    // Fall back to icon placeholder if no blurhash
    Log.debug(
      '📦 Image failed, no blurhash available, showing placeholder',
      name: 'VideoThumbnailWidget',
      category: LogCategory.video,
    );
    return VideoIconPlaceholder(
      width: width,
      height: height,
      showPlayIcon: showPlayIcon,
      borderRadius: borderRadius?.topLeft.x ?? 8.0,
    );
  }
}
