// ABOUTME: Screen for viewing a specific video by ID (from deep links)
// ABOUTME: Fetches video from Nostr and displays it in full-screen player

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/video_feed_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

class VideoDetailScreen extends ConsumerStatefulWidget {
  const VideoDetailScreen({required this.videoId, super.key});

  final String videoId;

  @override
  ConsumerState<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends ConsumerState<VideoDetailScreen> {
  VideoEvent? _video;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      Log.info(
        '📱 Loading video by ID: ${widget.videoId}',
        name: 'VideoDetailScreen',
        category: LogCategory.video,
      );

      final videoEventService = ref.read(videoEventServiceProvider);

      // Try to find video in existing loaded events first
      final video = videoEventService.getVideoById(widget.videoId);

      if (video != null) {
        Log.info(
          '✅ Found video in cache: ${video.title}',
          name: 'VideoDetailScreen',
          category: LogCategory.video,
        );
        if (mounted) {
          setState(() {
            _video = video;
            _isLoading = false;
          });
        }
        return;
      }

      // Video not in cache, fetch from Nostr
      Log.info(
        '🔍 Video not in cache, fetching from Nostr...',
        name: 'VideoDetailScreen',
        category: LogCategory.video,
      );

      final nostrService = ref.read(nostrServiceProvider);
      final event = await nostrService.fetchEventById(widget.videoId);

      if (event != null) {
        final fetchedVideo = VideoEvent.fromNostrEvent(event);
        Log.info(
          '✅ Fetched video from Nostr: ${fetchedVideo.title}',
          name: 'VideoDetailScreen',
          category: LogCategory.video,
        );
        if (mounted) {
          setState(() {
            _video = fetchedVideo;
            _isLoading = false;
          });
        }
      } else {
        Log.warning(
          '❌ Video not found: ${widget.videoId}',
          name: 'VideoDetailScreen',
          category: LogCategory.video,
        );
        if (mounted) {
          setState(() {
            _error = 'Video not found';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      Log.error(
        'Error loading video: $e',
        name: 'VideoDetailScreen',
        category: LogCategory.video,
      );
      if (mounted) {
        setState(() {
          _error = 'Failed to load video: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                  color: VineTheme.primaryText,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_video == null) {
      return const Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: Center(
          child: Text(
            'Video not found',
            style: TextStyle(color: VineTheme.primaryText),
          ),
        ),
      );
    }

    // Check if video author has muted us (mutual mute blocking)
    final blocklistService = ref.watch(contentBlocklistServiceProvider);
    if (blocklistService.shouldFilterFromFeeds(_video!.pubkey)) {
      return Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'This account is not available',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    // Display video in full-screen player (with navigation disabled to preserve /video/:id route)
    return VideoFeedScreen(startingVideo: _video!, disableNavigation: true);
  }
}
