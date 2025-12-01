// ABOUTME: Debug screen to test video playback issues
// ABOUTME: Simple test of VideoFeedItem without feed updates

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_feed_item.dart';

class DebugVideoTestScreen extends ConsumerStatefulWidget {
  const DebugVideoTestScreen({super.key});

  @override
  ConsumerState<DebugVideoTestScreen> createState() =>
      _DebugVideoTestScreenState();
}

class _DebugVideoTestScreenState extends ConsumerState<DebugVideoTestScreen> {
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // No longer using default video - get videos from feed instead

    // NOTE: Videos are now automatically synced from the video feed
    // Manual video addition not supported in new Riverpod architecture
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Log.info(
        'Debug video test initialized - videos come from feed',
        name: 'DebugVideoTest',
        category: LogCategory.ui,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final videoEventService = ref.watch(videoEventServiceProvider);
    final videos = videoEventService.discoveryVideos;
    final testVideo = videos.isNotEmpty ? videos.first : null;

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        title: const Text('Debug Video Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              testVideo != null
                  ? 'Video URL: ${testVideo.videoUrl}'
                  : 'No videos available in feed',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Fixed size container for video
            Container(
              width: 300,
              height: 400,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: VineTheme.vineGreen, width: 2),
              ),
              child: (_isPlaying && testVideo != null)
                  ? VideoFeedItem(
                      video: testVideo,
                      index: 0, // Single test video
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 64,
                            color: Colors.white54,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Tap Play to test video',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isPlaying = !_isPlaying;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(_isPlaying ? 'Stop' : 'Play'),
            ),
          ],
        ),
      ),
    );
  }
}
