// ABOUTME: Widget for displaying related videos based on analytics API recommendations
// ABOUTME: Shows related content using hashtag or co-watch algorithms

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_explore_tile.dart';

/// Widget to display related videos for a given video
class RelatedVideosWidget extends ConsumerStatefulWidget {
  final VideoEvent currentVideo;
  final Function(List<VideoEvent>, int) onVideoTap;
  final String algorithm;

  const RelatedVideosWidget({
    super.key,
    required this.currentVideo,
    required this.onVideoTap,
    this.algorithm = 'hashtag',
  });

  @override
  ConsumerState<RelatedVideosWidget> createState() =>
      _RelatedVideosWidgetState();
}

class _RelatedVideosWidgetState extends ConsumerState<RelatedVideosWidget> {
  List<VideoEvent> _relatedVideos = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRelatedVideos();
  }

  @override
  void didUpdateWidget(RelatedVideosWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentVideo.id != widget.currentVideo.id ||
        oldWidget.algorithm != widget.algorithm) {
      _loadRelatedVideos();
    }
  }

  Future<void> _loadRelatedVideos() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(analyticsApiServiceProvider);
      final videos = await service.getRelatedVideos(
        videoId: widget.currentVideo.id,
        algorithm: widget.algorithm,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _relatedVideos = videos;
          _isLoading = false;
        });
      }

      Log.info(
        '📊 Loaded ${videos.length} related videos for ${widget.currentVideo.id}',
        name: 'RelatedVideosWidget',
        category: LogCategory.ui,
      );
    } catch (e) {
      Log.error(
        '❌ Failed to load related videos: $e',
        name: 'RelatedVideosWidget',
        category: LogCategory.ui,
      );

      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              const Text(
                'Failed to load related videos',
                style: TextStyle(
                  color: VineTheme.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Try again later',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_relatedVideos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.video_library_outlined,
                color: VineTheme.secondaryText,
                size: 48,
              ),
              const SizedBox(height: 8),
              const Text(
                'No related videos found',
                style: TextStyle(
                  color: VineTheme.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Explore more content in the app',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Related Videos',
                style: TextStyle(
                  color: VineTheme.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_relatedVideos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: VineTheme.vineGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.algorithm == 'hashtag'
                        ? 'By Hashtags'
                        : 'Co-watched',
                    style: TextStyle(
                      color: VineTheme.vineGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _relatedVideos.length,
            itemBuilder: (context, index) {
              final video = _relatedVideos[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 150,
                  child: VideoExploreTile(
                    video: video,
                    isActive: false,
                    onTap: () {
                      // Play the related video with all related videos as context
                      widget.onVideoTap(_relatedVideos, index);
                    },
                    onClose: () {},
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
