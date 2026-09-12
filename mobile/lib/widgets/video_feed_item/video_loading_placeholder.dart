import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:unified_logger/unified_logger.dart';

/// Loading placeholder shown while a video player initializes.
///
/// Displays the video thumbnail (if available) with a branded loading
/// indicator overlay. Logs thumbnail lifecycle events (start, loaded,
/// failed, missing) for diagnostics.
class VideoLoadingPlaceholder extends StatefulWidget {
  const VideoLoadingPlaceholder({
    required this.videoId,
    required this.index,
    this.feedMode,
    this.thumbnailUrl,
    this.shouldPortraitExpand = true,
    this.isSquare = false,
    super.key,
  });

  final String videoId;
  final int index;
  final String? feedMode;
  final String? thumbnailUrl;

  /// Controls how the thumbnail is fitted into the placeholder.
  ///
  /// When `true`, non-square videos use [BoxFit.cover] while
  /// square (1:1) videos use [BoxFit.contain].
  /// When `false`, all videos use [BoxFit.contain].
  final bool shouldPortraitExpand;

  /// Whether the video has a square (1:1) aspect ratio.
  ///
  /// Provided by the feed widget from the actual video controller
  /// dimensions. When `true` and [shouldPortraitExpand] is `true`,
  /// the thumbnail uses [BoxFit.contain].
  final bool isSquare;

  @override
  State<VideoLoadingPlaceholder> createState() =>
      _VideoLoadingPlaceholderState();
}

class _VideoLoadingPlaceholderState extends State<VideoLoadingPlaceholder> {
  bool _loggedStart = false;
  bool _loggedError = false;

  /// Determines the [BoxFit] for the thumbnail image.
  BoxFit _resolveBoxFit() {
    if (!widget.shouldPortraitExpand) return .contain;
    return widget.isSquare ? .contain : .cover;
  }

  void _logStartIfNeeded() {
    if (_loggedStart) return;
    _loggedStart = true;
    Log.debug(
      'Feed thumbnail load_start: mode=${widget.feedMode ?? 'unknown'}, '
      'index=${widget.index}, eventId=${widget.videoId}, '
      'thumbnailUrl=${widget.thumbnailUrl}',
      name: 'VideoLoadingPlaceholder',
      category: LogCategory.video,
    );
  }

  void _logErrorIfNeeded(Object error) {
    if (_loggedError) return;
    _loggedError = true;
    Log.warning(
      'Feed thumbnail load_failed: mode=${widget.feedMode ?? 'unknown'}, '
      'index=${widget.index}, eventId=${widget.videoId}, '
      'thumbnailUrl=${widget.thumbnailUrl}, error=$error',
      name: 'VideoLoadingPlaceholder',
      category: LogCategory.video,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.thumbnailUrl == null) {
      if (!_loggedStart) {
        _loggedStart = true;
        Log.debug(
          'Feed thumbnail missing: mode=${widget.feedMode ?? 'unknown'}, '
          'index=${widget.index}, eventId=${widget.videoId}',
          name: 'VideoLoadingPlaceholder',
          category: LogCategory.video,
        );
      }
      return const _LoadingIndicator();
    }

    final boxFit = _resolveBoxFit();

    return ColoredBox(
      color: context.vineColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: PassiveAuthThumbnailImage(
              url: widget.thumbnailUrl!,
              videoId: widget.videoId,
              fit: boxFit,
              alignment: Alignment.center,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (context, url) {
                _logStartIfNeeded();
                return const SizedBox.shrink();
              },
              errorWidget: (context, url, error) {
                _logErrorIfNeeded(error);
                return const SizedBox.shrink();
              },
              logName: 'VideoLoadingPlaceholder',
              logPrefix: 'Feed thumbnail',
            ),
          ),
          // Always show the loading indicator on top of the thumbnail so
          // users see immediate feedback that the player is initializing,
          // even after the thumbnail has finished loading.
          const _LoadingIndicator(),
        ],
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    // Excluded like the thumbnail above it: the enclosing "Play video" surface
    // owns this region's semantics, and a buffering placeholder this transient
    // would only leave a stale "Loading" on a button that is already playable.
    return const ExcludeSemantics(
      child: Center(child: BrandedLoadingIndicator(size: 60)),
    );
  }
}
