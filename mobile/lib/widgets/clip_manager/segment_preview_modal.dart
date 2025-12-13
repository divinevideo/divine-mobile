// ABOUTME: Modal overlay for previewing a single clip with looping playback
// ABOUTME: Uses video_player for playback, dark overlay background

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/utils/unified_logger.dart';

class SegmentPreviewModal extends StatefulWidget {
  const SegmentPreviewModal({
    super.key,
    required this.clip,
    required this.onClose,
  });

  final RecordingClip clip;
  final VoidCallback onClose;

  @override
  State<SegmentPreviewModal> createState() => _SegmentPreviewModalState();
}

class _SegmentPreviewModalState extends State<SegmentPreviewModal> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final file = File(widget.clip.filePath);
      if (!file.existsSync()) {
        setState(() {
          _errorMessage = 'Video file not found';
        });
        return;
      }

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      Log.error(
        'Failed to initialize video preview: $e',
        name: 'SegmentPreviewModal',
      );
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load video';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black87,
        child: Stack(
          children: [
            // Video player
            Center(
              child: _buildVideoPlayer(),
            ),

            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                onPressed: widget.onClose,
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),

            // Duration indicator
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.clip.durationInSeconds.toStringAsFixed(1)}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_errorMessage != null) {
      return Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.red),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}
